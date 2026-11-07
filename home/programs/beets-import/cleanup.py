"""Journaled retirement of explicitly selected working sources after publication."""

from dataclasses import asdict
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile

import cli
from metadata import Approval, SourceRecord, sha256, verify_candidate


def signature(path):
    info = path.stat()
    if not stat.S_ISREG(info.st_mode):
        raise ValueError("Cleanup source is not a regular file")
    return info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns


def unchanged(path, digest):
    cli.no_symlinks(path)
    before = signature(path)
    if sha256(path) != digest or before != signature(path):
        raise ValueError(f"Cleanup source/recovery changed: {path}")


def capture_source(source, captured):
    if captured.exists() or captured.is_symlink():
        raise ValueError("Cleanup capture path already exists")
    os.rename(source, captured)
    cli.sync_directory(source.parent)
    cli.sync_directory(captured.parent)


def remove_captured(captured):
    captured.unlink()
    cli.sync_directory(captured.parent)


def checkpoint(ledger, source_id, phase, plan):
    with ledger.connection:
        ledger.connection.execute(
            "INSERT INTO cleanups(source_id,phase,data,error) VALUES (?,?,?,'') ON CONFLICT(source_id) DO UPDATE SET phase=excluded.phase,data=excluded.data,error=''",
            (source_id, phase, json.dumps(plan, default=str)),
        )
        ledger.connection.execute(
            "UPDATE sources SET cleanup_error='' WHERE id=?", (source_id,)
        )


def catalogue_proof(ledger, row, destination=None):
    matches = [
        entry
        for entry in cli.catalogue_entries(ledger.database, ledger.root)
        if entry["source_sha256"] == row["sha256"]
        and entry.get("source") == row["path"]
        and (destination is None or entry["path"] == destination)
    ]
    if len(matches) != 1:
        raise ValueError(
            "Cleanup requires one registered output with exact source provenance"
        )
    entry = matches[0]
    path = cli.no_symlinks(Path(entry["path"]))
    if (
        not path.is_relative_to(ledger.root)
        or not entry["sha256"]
        or sha256(path) != entry["sha256"]
    ):
        raise ValueError("Cleanup catalogue output is missing or changed")
    return entry


def make_plan(ledger, row):
    source = cli.no_symlinks(Path(row["path"]))
    if not source.is_relative_to(cli.no_symlinks(Path(ledger.data["working_source"]))):
        raise ValueError("Cleanup source is outside the selected working directory")
    unchanged(source, row["sha256"])
    entry = catalogue_proof(ledger, row)
    provenance = cli.load_job(cli.no_symlinks(Path(entry["job"])))
    files = provenance.get("files", []) + [
        file for batch in provenance.get("publication_history", []) for file in batch
    ]
    approved = next(
        (
            file
            for file in files
            if file["source_sha256"] == row["sha256"]
            and str(ledger.root / file["relative_destination"]) == entry["path"]
            and file.get("status") == "registered"
        ),
        None,
    )
    record = next(
        (
            record
            for record in cli.source_records(provenance)
            if str(record.source) == row["path"] and record.sha256 == row["sha256"]
        ),
        None,
    )
    if approved is None or record is None:
        raise ValueError(
            "Cleanup lacks the original preservation/approval journal; original retained"
        )
    recovery = record.staged
    if not recovery.is_relative_to(ledger.job) or not recovery.exists():
        directory = cli.no_symlinks(ledger.job / "recovery")
        directory.mkdir(mode=0o700, exist_ok=True)
        recovery = cli.no_symlinks(directory / (str(row["id"]) + source.suffix))
        if not recovery.exists():
            descriptor, temporary = tempfile.mkstemp(prefix=".copy-", dir=directory)
            os.close(descriptor)
            shutil.copy2(source, temporary)
            unchanged(Path(temporary), row["sha256"])
            unchanged(source, row["sha256"])
            with open(temporary, "rb") as stream:
                os.fsync(stream.fileno())
            os.replace(temporary, recovery)
            cli.sync_directory(directory)
    unchanged(recovery, row["sha256"])
    if source.samefile(recovery) or Path(entry["path"]).samefile(recovery):
        raise ValueError("Cleanup recovery must be an independent original-byte copy")
    # Capture is on the source filesystem; cross-filesystem publication is safe.
    directory = Path(
        tempfile.mkdtemp(prefix=".beets-import-retire-", dir=source.parent)
    )
    cli.save_json(
        directory / "owner.json", {"job": str(ledger.job), "source_id": row["id"]}
    )
    cli.sync_directory(source.parent)
    return {
        "source": str(source),
        "source_sha256": row["sha256"],
        "destination": entry["path"],
        "destination_sha256": entry["sha256"],
        "recovery": str(recovery),
        "captured": str(directory / ("original" + source.suffix)),
        "metadata": record.metadata,
        "approval": asdict(cli.file_approval(cli.file_record(approved))),
    }


def validate_plan(ledger, row, plan):
    source = cli.no_symlinks(Path(plan["source"]))
    working = cli.no_symlinks(Path(ledger.data["working_source"]))
    if (
        str(source) != row["path"]
        or plan["source_sha256"] != row["sha256"]
        or not source.is_relative_to(working)
    ):
        raise ValueError("Cleanup journal differs from the selected working source")
    recovery, captured = (
        cli.no_symlinks(Path(plan[key])) for key in ("recovery", "captured")
    )
    if (
        not recovery.is_relative_to(ledger.job)
        or captured.parent.parent != source.parent
        or not captured.parent.name.startswith(".beets-import-retire-")
    ):
        raise ValueError("Cleanup recovery/capture path is outside its owned location")
    if captured.parent.exists():
        info = captured.parent.stat()
        if (
            info.st_uid != os.getuid()
            or info.st_mode & 0o077
            or cli.read_json(captured.parent / "owner.json")
            != {"job": str(ledger.job), "source_id": row["id"]}
        ):
            raise ValueError(
                "Cleanup capture directory is not private and owned by this job"
            )
    unchanged(recovery, row["sha256"])
    entry = catalogue_proof(ledger, row, plan["destination"])
    if entry["sha256"] != plan["destination_sha256"]:
        raise ValueError("Cleanup destination differs from the publication journal")
    return source, recovery, captured


def preservation(ledger, row, plan, original):
    source, recovery, captured = validate_plan(ledger, row, plan)
    unchanged(original, row["sha256"])
    if original != recovery and original.samefile(recovery):
        raise ValueError("Cleanup recovery is hardlinked to the source")
    approval = Approval(**plan["approval"])
    destination = cli.no_symlinks(Path(plan["destination"]))
    if cli.plan_destination(approval, destination) != destination.relative_to(
        ledger.root
    ):
        raise ValueError("Cleanup output path differs from the approved layout")
    verification = verify_candidate(
        SourceRecord(original, recovery, row["sha256"], plan["metadata"]),
        destination,
        approval,
    )
    if verification["sha256"] != plan["destination_sha256"]:
        raise ValueError("Cleanup destination changed during preservation checks")
    unchanged(original, row["sha256"])


def advance(ledger, row, phase, plan):
    source, recovery, captured = validate_plan(ledger, row, plan)
    if phase in {"pending", "capturing"}:
        if not captured.exists():
            preservation(ledger, row, plan, source)
            checkpoint(ledger, row["id"], "capturing", plan)
            capture_source(source, captured)
        preservation(ledger, row, plan, captured)
        checkpoint(ledger, row["id"], "captured", plan)
        phase = "captured"
    if captured.exists():
        preservation(ledger, row, plan, captured)
        checkpoint(ledger, row["id"], "removing", plan)
        unchanged(captured, row["sha256"])
        remove_captured(captured)
    elif phase == "removing":
        # An interrupted unlink can complete only with canonical and recovery proof.
        preservation(ledger, row, plan, recovery)
    else:
        raise ValueError("Cleanup captured source is missing without a removal intent")
    checkpoint(ledger, row["id"], "done", plan)
    with ledger.connection:
        ledger.connection.execute(
            "UPDATE sources SET status='moved',outcome='moved',cleanup_error='',reason='Working source removed after verification; recovery retained' WHERE id=?",
            (row["id"],),
        )
    try:
        (captured.parent / "owner.json").unlink()
        captured.parent.rmdir()
        cli.sync_directory(source.parent)
    except OSError:
        pass  # Empty private capture-directory cleanup is not source retirement.


def run_cleanups(ledger, index, *, source_ids=None, include_completed=False):
    if not ledger.data.get("working_source"):
        return
    sql = "SELECT * FROM sources WHERE (status IN ('imported','already_imported') OR id IN (SELECT source_id FROM cleanups WHERE phase!='done') OR (status='moved' AND ?))"
    arguments = [include_completed]
    if source_ids is not None:
        if not source_ids:
            return
        sql += " AND id IN (" + ",".join("?" for _ in source_ids) + ")"
        arguments.extend(source_ids)
    for row in ledger.rows(sql + " ORDER BY id", arguments):
        try:
            existing = ledger.rows(
                "SELECT * FROM cleanups WHERE source_id=?", (row["id"],)
            )
            if existing:
                phase, plan = existing[0]["phase"], json.loads(existing[0]["data"])
            else:
                plan, phase = make_plan(ledger, row), "pending"
                checkpoint(ledger, row["id"], phase, plan)
            if phase == "done":
                validate_plan(ledger, row, plan)
                with ledger.connection:
                    ledger.connection.execute(
                        "UPDATE sources SET status='moved',outcome='moved',cleanup_error='' WHERE id=?",
                        (row["id"],),
                    )
            else:
                advance(ledger, row, phase, plan)
        except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as exc:
            with ledger.connection:
                ledger.connection.execute(
                    "UPDATE sources SET cleanup_error=?,outcome='failed' WHERE id=?",
                    (str(exc), row["id"]),
                )
                ledger.connection.execute(
                    "UPDATE cleanups SET error=? WHERE source_id=?",
                    (str(exc), row["id"]),
                )
