"""Durable bulk inventory and bounded import orchestration."""

from collections import Counter
from contextlib import closing
from dataclasses import asdict
import errno
import json
from pathlib import Path
import sqlite3
import subprocess
import sys
from urllib.parse import quote

import cli
from metadata import Approval, sha256, source_metadata
from beetsplug.import_policy import SINGLETON_POLICY_VERSION


OUTCOMES = (
    "pending",
    "imported",
    "moved",
    "duplicate_awaiting_review",
    "unidentified",
    "failed",
)


def outcome_for(row):
    if row.get("cleanup_error"):
        return "failed"
    phase = row["status"]
    if phase == "moved":
        return "moved"
    if phase in {"imported", "already_imported", "exact_duplicate"}:
        return "imported"
    if row.get("review_kind") == "failed" and row.get("reason"):
        return "failed"
    if phase in {"discovered", "ready"}:
        return "pending"
    if (
        phase in {"duplicate_pending", "skipped"}
        or row.get("review_kind") == "duplicate"
    ):
        return "duplicate_awaiting_review"
    return (
        "failed"
        if phase == "changed" or row.get("review_kind") == "failed"
        else "unidentified"
    )


def pending_cleanup_ids(rows, cleanups, enabled):
    if not enabled:
        return set()
    done = {record["source_id"] for record in cleanups if record["phase"] == "done"}
    return {
        row["id"]
        for row in rows
        if row["status"] in {"imported", "already_imported"} and row["id"] not in done
    } | {record["source_id"] for record in cleanups if record["phase"] != "done"}


def progress_for(rows, cleanup_ids=()):
    result = {
        "total_files": len(rows),
        "total_bytes": sum(row["bytes"] for row in rows),
    }
    for outcome in OUTCOMES:
        selected = [
            row for row in rows if row.get("outcome", outcome_for(row)) == outcome
        ]
        result[outcome + "_files"] = len(selected)
        result[outcome + "_bytes"] = sum(row["bytes"] for row in selected)
    result["cleanup_pending_files"] = (
        sum(row["id"] in cleanup_ids for row in rows) if cleanup_ids else 0
    )
    result["cleanup_pending_bytes"] = (
        sum(row["bytes"] for row in rows if row["id"] in cleanup_ids)
        if cleanup_ids
        else 0
    )
    return result


def registered_source_proofs(data):
    database = cli.no_symlinks(Path(data["database"]))
    if not database.exists():
        return set()
    cli.check_binding(database, Path(data["root"]))
    # Library opens initialize schema/logs; status uses the pinned schema read-only.
    with closing(
        sqlite3.connect("file:" + quote(str(database), safe="/") + "?mode=ro", uri=True)
    ) as connection:
        if not connection.execute(
            "SELECT 1 FROM sqlite_master WHERE name='item_attributes'"
        ).fetchone():
            return set()
        return set(
            connection.execute("""
            SELECT source.value, digest.value, job.value
            FROM items i
            JOIN item_attributes source ON source.entity_id=i.id AND source.key='beets_import_source_path'
            JOIN item_attributes digest ON digest.entity_id=i.id AND digest.key='beets_import_source_sha256'
            JOIN item_attributes job ON job.entity_id=i.id AND job.key='beets_import_job'
            JOIN item_attributes output ON output.entity_id=i.id AND output.key='beets_import_sha256'
            WHERE length(digest.value)=64 AND length(output.value)=64
        """)
        )


def status_report(job: Path):
    data = cli.load_job(job)
    if data.get("kind") != "bulk":
        raise ValueError(
            "Per-source status requires a bulk job; ordinary jobs can still resume"
        )
    path = cli.no_symlinks(job / "bulk.sqlite3")
    with closing(
        sqlite3.connect("file:" + quote(str(path), safe="/") + "?mode=ro", uri=True)
    ) as connection:
        connection.row_factory = sqlite3.Row
        rows = [
            dict(row)
            for row in connection.execute(
                "SELECT s.*,u.job unit_job FROM sources s LEFT JOIN units u ON s.unit_id=u.id ORDER BY s.id"
            )
        ]
        proofs = registered_source_proofs(data)
        for row in rows:
            if (
                row.get("outcome", outcome_for(row)) in {"pending", "unidentified"}
                and (row["path"], row["sha256"], row["unit_job"]) in proofs
            ):
                row["outcome"] = "imported"
                row["reason"] = (
                    "Publication registered; parent checkpoint still pending"
                )
        cleanups = {}
        if connection.execute(
            "SELECT 1 FROM sqlite_master WHERE name='cleanups'"
        ).fetchone():
            cleanups = {
                row["source_id"]: dict(row)
                for row in connection.execute("SELECT * FROM cleanups")
            }
            for row in rows:
                record = cleanups.get(row["id"])
                if (
                    record
                    and record["phase"] == "done"
                    and not record["error"]
                    and not row.get("cleanup_error")
                ):
                    row["outcome"] = "moved"
        cleanup_ids = pending_cleanup_ids(
            rows, cleanups.values(), data.get("working_source")
        )
        sources = [
            {
                "id": row["id"],
                "source": row["path"],
                "sha256": row["sha256"],
                "bytes": row["bytes"],
                "status": row.get("outcome", outcome_for(row)),
                "phase": row["status"],
                "reason": row.get("cleanup_error") or row["reason"],
                "skipped": row["status"] == "skipped",
                "cleanup_pending": row["id"] in cleanup_ids,
            }
            for row in rows
        ]
        if cleanups:
            for source in sources:
                if source["id"] in cleanups:
                    cleanup = cleanups[source["id"]]
                    plan = json.loads(cleanup["data"])
                    source["cleanup"] = {
                        "phase": cleanup["phase"],
                        "error": cleanup["error"],
                        **{
                            key: plan[key]
                            for key in ("recovery", "captured", "destination")
                        },
                    }
        return {
            "job": str(job),
            "progress": progress_for(rows, cleanup_ids),
            "sources": sources,
        }


def stamp(path: Path):
    info = path.stat()
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


class CommittedIndex:
    def __init__(self, database: Path, root: Path):
        self.root = root
        self.entries = {}
        self.hashes = {}
        self.checked = {}
        self.add(cli.catalogue_entries(database, root))

    def add(self, entries):
        for entry in entries:
            if entry["path"] in self.entries:
                continue
            self.entries[entry["path"]] = entry
            for digest in {entry.get("source_sha256"), entry.get("sha256")} - {
                None,
                "",
            }:
                self.hashes.setdefault(digest, []).append(entry)

    def lookup(self, source: Path, digest: str):
        candidates = self.hashes.get(digest, [])
        for entry in candidates:
            path = cli.no_symlinks(Path(entry["path"]))
            if not path.is_relative_to(self.root):
                continue
            try:
                signature = stamp(path)
                cached = self.checked.get(str(path))
                if cached is None or cached[0] != signature:
                    good = bool(entry.get("sha256")) and sha256(path) == entry["sha256"]
                    self.checked[str(path)] = (signature, good)
                if self.checked[str(path)][1]:
                    status = (
                        "already_imported"
                        if str(source) == entry.get("source")
                        else "exact_duplicate"
                    )
                    return status, f"Verified committed output: {path}"
            except (OSError, ValueError):
                continue
        if candidates:
            return (
                "review",
                "Matching catalogue output is missing, changed, or unsafe; review before importing",
            )
        return None


class BulkLedger:
    def __init__(self, job: Path, root: Path, database: Path):
        self.job = cli.no_symlinks(job)
        self.data = cli.load_job(job)
        if (
            self.data.get("kind") != "bulk"
            or self.data["root"] != str(root)
            or self.data["database"] != str(database)
        ):
            raise ValueError(
                "Bulk job root/database or kind differs from configuration"
            )
        self.root, self.database = root, database
        self.connection = sqlite3.connect(cli.no_symlinks(job / "bulk.sqlite3"))
        self.connection.row_factory = sqlite3.Row
        with self.connection:
            self.connection.executescript("""
                CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS sources (
                    id INTEGER PRIMARY KEY, path TEXT NOT NULL UNIQUE, sha256 TEXT,
                    bytes INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'discovered',
                    metadata TEXT, duplicate_of INTEGER, unit_id INTEGER,
                    reason TEXT NOT NULL DEFAULT '', signature TEXT
                );
                CREATE TABLE IF NOT EXISTS units (
                    id INTEGER PRIMARY KEY, group_key TEXT NOT NULL UNIQUE,
                    album INTEGER NOT NULL, job TEXT, status TEXT NOT NULL DEFAULT 'ready',
                    reason TEXT NOT NULL DEFAULT ''
                );
                CREATE TABLE IF NOT EXISTS cleanups (
                    source_id INTEGER PRIMARY KEY, phase TEXT NOT NULL,
                    data TEXT NOT NULL, error TEXT NOT NULL DEFAULT ''
                );
                CREATE INDEX IF NOT EXISTS source_hash ON sources(sha256);
                CREATE INDEX IF NOT EXISTS source_status ON sources(status);
                CREATE INDEX IF NOT EXISTS source_unit ON sources(unit_id);
                CREATE INDEX IF NOT EXISTS source_duplicate ON sources(duplicate_of);
            """)
            if "signature" not in {
                row[1] for row in self.connection.execute("PRAGMA table_info(sources)")
            }:
                self.connection.execute("ALTER TABLE sources ADD COLUMN signature TEXT")
            columns = {
                row[1] for row in self.connection.execute("PRAGMA table_info(sources)")
            }
            for name, declaration in {
                "outcome": "TEXT NOT NULL DEFAULT 'pending'",
                "review_kind": "TEXT NOT NULL DEFAULT 'unidentified'",
                "cleanup_error": "TEXT NOT NULL DEFAULT ''",
            }.items():
                if name not in columns:
                    self.connection.execute(
                        f"ALTER TABLE sources ADD COLUMN {name} {declaration}"
                    )
        self.refresh_outcomes()

    def refresh_outcomes(self, *, unit_id=None, ids=None):
        sql, arguments = (
            "SELECT id,status,outcome,review_kind,cleanup_error,reason FROM sources",
            (),
        )
        if unit_id is not None:
            sql += " WHERE unit_id=?"
            arguments = (unit_id,)
        elif ids is not None:
            if not ids:
                return
            arguments = tuple(ids)
            sql += " WHERE id IN (" + ",".join("?" for _ in arguments) + ")"
        changed = [
            (outcome_for(row), row["id"])
            for row in self.rows(sql, arguments)
            if row["outcome"] != outcome_for(row)
        ]
        with self.connection:
            self.connection.executemany(
                "UPDATE sources SET outcome=? WHERE id=?", changed
            )

    def close(self):
        self.connection.close()

    def rows(self, sql, args=()):
        return [dict(row) for row in self.connection.execute(sql, args)]

    def source_entries(self):
        rows = self.rows("SELECT * FROM sources ORDER BY id")
        for row in rows:
            row["metadata"] = json.loads(row["metadata"]) if row["metadata"] else None
        return rows

    def summary(self):
        rows = self.rows("SELECT id,status,outcome,bytes FROM sources")
        cleanup_ids = pending_cleanup_ids(
            rows,
            self.rows("SELECT source_id,phase FROM cleanups"),
            self.data.get("working_source"),
        )
        counts = Counter(
            {
                row["status"]: row["n"]
                for row in self.rows(
                    "SELECT status, count(*) n FROM sources GROUP BY status"
                )
            }
        )
        return {
            "job": str(self.job),
            "inventoried": sum(counts.values()) - counts["discovered"],
            "ready": counts["ready"],
            "committed": counts["already_imported"]
            + counts["imported"]
            + counts["moved"],
            "exact_duplicates": counts["exact_duplicate"],
            "duplicate_pending": counts["duplicate_pending"],
            "review": counts["review"] + counts["changed"] + counts["skipped"],
            "skipped": counts["skipped"],
            "unscanned": counts["discovered"],
            "input_bytes": self.connection.execute(
                "SELECT coalesce(sum(bytes),0) FROM sources"
            ).fetchone()[0],
            "progress": progress_for(rows, cleanup_ids),
        }


def inventory_sources(ledger: BulkLedger, paths: list[Path], index=None):
    index = index or CommittedIndex(ledger.database, ledger.root)
    if not ledger.rows("SELECT 1 FROM meta WHERE key='discovery_complete'"):
        files = cli.discover_sources(paths, ledger.root, ledger.job, allow_links=True)
        with ledger.connection:
            ledger.connection.executemany(
                "INSERT OR IGNORE INTO sources(path) VALUES (?)",
                [(str(path),) for path in files],
            )
            ledger.connection.execute(
                "INSERT OR REPLACE INTO meta VALUES ('discovery_complete','1')"
            )
    progress = ledger.summary()
    for row in ledger.rows(
        "SELECT * FROM sources WHERE status='discovered' ORDER BY id"
    ):
        path = Path(row["path"])
        digest, metadata, size, duplicate_of, signature = None, None, 0, None, None
        try:
            cli.no_symlinks(path)
            if not path.is_file():
                raise ValueError("Source is not an independent regular file")
            before = stamp(path)
            size = before[2]
            digest = sha256(path)
            if before != stamp(path):
                raise ValueError("Source changed during inventory")
            signature = json.dumps(before)
            committed = index.lookup(path, digest)
            previous = ledger.rows(
                "SELECT id FROM sources WHERE sha256=? AND duplicate_of IS NULL AND status NOT IN ('discovered','already_imported','exact_duplicate') ORDER BY id LIMIT 1",
                (digest,),
            )
            if committed:
                status, reason = committed
            elif previous:
                status, reason, duplicate_of = (
                    "duplicate_pending",
                    "Exact input copy; representative is not committed yet",
                    previous[0]["id"],
                )
            else:
                metadata = source_metadata(path)
                metadata = {"fields": metadata["fields"], "format": metadata["format"]}
                if before != stamp(path):
                    raise ValueError("Source changed while reading metadata")
                status, reason = "ready", ""
        except Exception as exc:
            status, reason = "review", str(exc)
        with ledger.connection:
            ledger.connection.execute(
                "UPDATE sources SET sha256=?, bytes=?, status=?, metadata=?, duplicate_of=?, reason=?, signature=?,review_kind=? WHERE id=?",
                (
                    digest,
                    size,
                    status,
                    json.dumps(metadata) if metadata else None,
                    duplicate_of,
                    reason,
                    signature,
                    "failed" if status == "review" else "unidentified",
                    row["id"],
                ),
            )
        ledger.refresh_outcomes(ids=[row["id"]])
        progress["inventoried"] += 1
        progress["input_bytes"] += size
        progress["committed"] += status == "already_imported"
        progress["exact_duplicates"] += status == "exact_duplicate"
        print(
            f"Inventoried {progress['inventoried']} files / {progress['input_bytes']} bytes; "
            f"{progress['committed']} already imported, {progress['exact_duplicates']} exact duplicates",
            flush=True,
        )


def queue_entries(job: Path) -> list[dict]:
    data = cli.load_job(job)
    if data.get("kind") != "bulk":
        return data.get("review_queue", []) + data.get("pending", [])
    path = cli.no_symlinks(job / "bulk.sqlite3")
    with closing(
        sqlite3.connect("file:" + quote(str(path), safe="/") + "?mode=ro", uri=True)
    ) as connection:
        connection.row_factory = sqlite3.Row
        rows = connection.execute(
            "SELECT s.*, u.reason unit_reason, u.job unit_job FROM sources s LEFT JOIN units u ON u.id=s.unit_id WHERE s.status IN ('review','changed','skipped') OR u.status='retry' ORDER BY s.id"
        ).fetchall()
        result, evidence = [], {}
        for row in rows:
            if row["status"] in {
                "imported",
                "already_imported",
                "exact_duplicate",
                "duplicate_pending",
            }:
                continue
            if row["duplicate_of"] is not None:
                continue
            child = row["unit_job"]
            if child and child not in evidence:
                child_path = cli.no_symlinks(Path(child))
                if not child_path.is_relative_to(job / "batches"):
                    raise ValueError("Review unit points outside this bulk job")
                child_data = cli.load_job(child_path)
                matching_aliases = child_data.get("matching_aliases", {})
                originals = {
                    str(record.staged): str(record.source)
                    for record in cli.source_records(child_data)
                }
                evidence[child] = [
                    (
                        event,
                        {
                            originals.get(
                                matching_aliases.get(item["path"], item["path"])
                            )
                            for item in event["items"]
                        },
                    )
                    for event in cli.current_decisions(
                        cli.read_events(child_path), child_data
                    )
                    if event["action"] in {"AUTO", "REVIEW"} and event["items"]
                ]
            aliases = [
                entry[0]
                for entry in connection.execute(
                    "SELECT path FROM sources WHERE duplicate_of=?", (row["id"],)
                )
            ]
            result.append(
                {
                    "id": row["id"],
                    "source": row["path"],
                    "sha256": row["sha256"],
                    "bytes": row["bytes"],
                    "reason": row["reason"] or row["unit_reason"] or "Needs review",
                    "aliases": aliases,
                    "evidence": [
                        event
                        for event, paths in evidence.get(child, [])
                        if row["path"] in paths
                    ],
                }
            )
        return result


def plan_units(ledger: BulkLedger):
    groups = {}
    for row in ledger.source_entries():
        if row["status"] != "ready" or row["unit_id"] is not None:
            continue
        group = cli.album_group(row["metadata"])
        key = json.dumps(
            ["album", group] if group else ["single", row["id"]], sort_keys=True
        )
        groups.setdefault(key, (bool(group), []))[1].append(row)
    with ledger.connection:
        for key, (album, rows) in groups.items():
            ledger.connection.execute(
                "INSERT OR IGNORE INTO units(group_key,album) VALUES (?,?)",
                (key, album),
            )
            unit_id = ledger.connection.execute(
                "SELECT id FROM units WHERE group_key=?", (key,)
            ).fetchone()[0]
            ledger.connection.executemany(
                "UPDATE sources SET unit_id=? WHERE id=?",
                [(unit_id, row["id"]) for row in rows],
            )
        ledger.connection.execute(
            "UPDATE sources SET unit_id=(SELECT representative.unit_id FROM sources representative WHERE representative.id=sources.duplicate_of) WHERE duplicate_of IS NOT NULL"
        )


def reconcile_committed(ledger: BulkLedger, index: CommittedIndex, *, digests=None):
    if digests is not None and not digests:
        return
    sql = "SELECT id,path,sha256,status,reason,unit_id,signature FROM sources WHERE sha256 IS NOT NULL AND status NOT IN ('discovered','changed','moved') AND id NOT IN (SELECT source_id FROM cleanups WHERE phase IN ('capturing','captured','removing','done'))"
    arguments = ()
    if digests is not None:
        arguments = tuple(digests)
        sql += " AND sha256 IN (" + ",".join("?" for _ in arguments) + ")"
    updates, signatures, detached, units = [], [], [], []
    for row in ledger.rows(sql, arguments):
        try:
            path = cli.no_symlinks(Path(row["path"]))
            before = stamp(path)
            signature = json.dumps(before)
            if row["signature"] != signature:
                if sha256(path) != row["sha256"] or before != stamp(path):
                    raise ValueError(
                        "Source changed since inventory; start a new job for its current version"
                    )
                signatures.append((signature, row["id"]))
        except (ValueError, OSError) as exc:
            updates.append(
                (
                    "changed",
                    f"Source changed or unavailable since inventory: {exc}",
                    row["id"],
                )
            )
            detached.append((row["id"],))
            continue
        result = index.lookup(Path(row["path"]), row["sha256"])
        if result and result[0] != "review":
            status = "imported" if row["status"] == "imported" else result[0]
        elif row["status"] in {"imported", "already_imported", "exact_duplicate"}:
            status, result = (
                "review",
                ("review", "Previously committed output is missing or changed"),
            )
        else:
            continue
        if (status, result[1]) != (row["status"], row["reason"]):
            updates.append((status, result[1], row["id"]))
        if status == "review" and row["unit_id"]:
            units.append((result[1], row["unit_id"]))
    with ledger.connection:
        ledger.connection.executemany(
            "UPDATE sources SET status=?,reason=? WHERE id=?", updates
        )
        ledger.connection.executemany(
            "UPDATE sources SET signature=? WHERE id=?", signatures
        )
        ledger.connection.executemany(
            "UPDATE sources SET unit_id=NULL,duplicate_of=NULL WHERE id=?", detached
        )
        ledger.connection.executemany(
            "UPDATE units SET status='review',reason=? WHERE id=?", units
        )
        if detached:
            ledger.connection.execute(
                "UPDATE sources SET status='review',unit_id=NULL,duplicate_of=NULL,reason='Representative changed since inventory; select this retained copy in a new job' WHERE status='duplicate_pending' AND duplicate_of IN (SELECT id FROM sources WHERE status='changed')"
            )
        if digests is None:
            ledger.connection.execute(
                "UPDATE sources SET status='skipped',reason='Exact copy of an explicitly skipped candidate' WHERE status='duplicate_pending' AND duplicate_of IN (SELECT id FROM sources WHERE status='skipped')"
            )


def child_job(ledger: BulkLedger, unit: dict) -> Path:
    batches = cli.no_symlinks(ledger.job / "batches")
    batches.mkdir(exist_ok=True)
    if unit["job"]:
        child = cli.no_symlinks(Path(unit["job"]))
        if not child.is_relative_to(batches):
            raise ValueError("Unit journal points outside the bulk job")
    else:
        child = Path(
            subprocess.run(
                ["mktemp", "-d", str(batches / "unit.XXXXXXXX")],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
        )
        with ledger.connection:
            ledger.connection.execute(
                "UPDATE units SET job=? WHERE id=?", (str(child), unit["id"])
            )
    if not (child / "job.json").exists():
        cli.save_json(
            child / "job.json",
            {
                "version": 1,
                "kind": "bulk-unit",
                "parent_job": str(ledger.job),
                "job": str(child),
                "root": str(ledger.root),
                "database": str(ledger.database),
                "state_directory": ledger.data["state_directory"],
                "sources": [],
            },
        )
    cli.load_job(child)
    return child


def finish_unit(
    ledger: BulkLedger, unit: dict, child: Path, index: CommittedIndex, active_ids=None
):
    data = cli.load_job(child)
    imported = {
        entry["source_sha256"]: entry
        for entry in data.get("files", [])
        if entry["status"] == "registered"
    }
    skipped = {entry["source_sha256"] for entry in data.get("skipped_candidates", [])}
    reasons = {
        entry["source_sha256"]: entry["reason"]
        for entry in data.get("review_queue", [])
    }
    by_path = {
        entry.get("source"): entry["reason"] for entry in data.get("pending", [])
    }
    events = cli.read_events(child)
    aliases = data.get("matching_aliases", {})
    originals = {
        str(record.staged): str(record.source) for record in cli.source_records(data)
    }
    review_reasons = {}
    for event in cli.current_decisions(events, data):
        if event["action"] == "REVIEW":
            for item in event["items"]:
                staged = aliases.get(item["path"], item["path"])
                if staged in originals:
                    review_reasons[originals[staged]] = event.get(
                        "reason", "Recording requires review"
                    )
    automatic_reason = next(
        (
            event.get("reason", "Needs review")
            for event in reversed(events)
            if event["action"] == "REVIEW"
        ),
        "Unmatched or deferred recording/edition",
    )
    entries = []
    with ledger.connection:
        for row in ledger.rows(
            "SELECT * FROM sources WHERE unit_id=? AND status NOT IN ('already_imported','exact_duplicate','duplicate_pending','imported','moved','skipped')",
            (unit["id"],),
        ):
            if active_ids is not None and row["id"] not in active_ids:
                continue
            if row["sha256"] in imported:
                status, reason = "imported", "Verified and registered"
                file = imported[row["sha256"]]
                entries.append(
                    {
                        "path": str(ledger.root / file["relative_destination"]),
                        "sha256": file["verification"]["sha256"],
                        "source_sha256": row["sha256"],
                        "source": row["path"],
                        "fields": file["fields"],
                        "job": str(child),
                    }
                )
            elif row["sha256"] in skipped:
                status, reason = "skipped", "Candidate explicitly skipped"
            else:
                pending_reason = by_path.get(row["path"])
                if pending_reason == "unmatched, skipped, or unchanged":
                    pending_reason = None
                status, reason = (
                    "review",
                    reasons.get(
                        row["sha256"],
                        pending_reason
                        or review_reasons.get(row["path"], automatic_reason),
                    ),
                )
            ledger.connection.execute(
                "UPDATE sources SET status=?, reason=?,review_kind=? WHERE id=?",
                (
                    status,
                    reason,
                    "duplicate"
                    if row["sha256"] in reasons or status == "skipped"
                    else "failed"
                    if row["path"] in by_path
                    and by_path[row["path"]] != "unmatched, skipped, or unchanged"
                    else "unidentified",
                    row["id"],
                ),
            )
        unresolved = ledger.connection.execute(
            "SELECT count(*) FROM sources WHERE unit_id=? AND status IN ('review','skipped') AND duplicate_of IS NULL",
            (unit["id"],),
        ).fetchone()[0]
        ledger.connection.execute(
            "UPDATE units SET status=?, reason=? WHERE id=?",
            (
                "review" if unresolved else "done",
                "Unresolved candidates" if unresolved else "",
                unit["id"],
            ),
        )
        ledger.connection.execute(
            "UPDATE sources SET status='skipped',reason='Exact copy of an explicitly skipped candidate' WHERE unit_id=? AND status='duplicate_pending' AND duplicate_of IN (SELECT id FROM sources WHERE unit_id=? AND status='skipped')",
            (unit["id"], unit["id"]),
        )
    index.add(entries)
    reconcile_committed(
        ledger,
        index,
        digests={
            digest
            for entry in entries
            for digest in (entry["source_sha256"], entry["sha256"])
        },
    )
    ledger.refresh_outcomes(unit_id=unit["id"])


def plan_cleanup_units(ledger, index):
    if not ledger.data.get("working_source"):
        return
    groups = {}
    for row in ledger.rows(
        "SELECT * FROM sources WHERE unit_id IS NULL AND (status IN ('imported','already_imported') OR id IN (SELECT source_id FROM cleanups WHERE phase!='done')) ORDER BY id"
    ):
        entry = next(
            (
                entry
                for entry in index.hashes.get(row["sha256"], [])
                if entry.get("source") == row["path"]
            ),
            None,
        )
        album = bool(entry and entry["fields"].get("album_id"))
        key = json.dumps(
            ["cleanup", entry["fields"]["album_id"], str(Path(entry["path"]).parent)]
            if album
            else ["cleanup-single", row["id"]]
        )
        groups.setdefault(key, (album, []))[1].append(row["id"])
    with ledger.connection:
        for key, (album, ids) in groups.items():
            if len(ids) > 100:
                ledger.connection.executemany(
                    "UPDATE sources SET cleanup_error='Cleanup album exceeds 100 tracks; select a smaller working set',outcome='failed' WHERE id=?",
                    [(source_id,) for source_id in ids],
                )
                continue
            ledger.connection.execute(
                "INSERT OR IGNORE INTO units(group_key,album,status) VALUES (?,?,'done')",
                (key, album),
            )
            unit_id = ledger.connection.execute(
                "SELECT id FROM units WHERE group_key=?", (key,)
            ).fetchone()[0]
            ledger.connection.executemany(
                "UPDATE sources SET unit_id=? WHERE id=?",
                [(unit_id, source_id) for source_id in ids],
            )


def current_singleton_rejection(child, row):
    data = cli.load_job(child)
    paths = {
        str(record.staged)
        for record in cli.source_records(data)
        if str(record.source) == row["path"] and record.sha256 == row["sha256"]
    }
    aliases = data.get("matching_aliases", {})
    latest = None
    for event in cli.current_decisions(cli.read_events(child), data):
        if event["action"] in {"AUTO", "REVIEW"} and any(
            aliases.get(item["path"], item["path"]) in paths for item in event["items"]
        ):
            latest = event
    return bool(
        latest
        and latest["action"] == "REVIEW"
        and latest.get("policy") == SINGLETON_POLICY_VERSION
    )


def retry_sources(ledger, args):
    selected = {
        str(cli.no_symlinks(path)) for path in getattr(args, "select_sources", [])
    }
    rows = ledger.rows("SELECT * FROM sources ORDER BY id")
    if selected - {row["path"] for row in rows}:
        raise ValueError("Retry selection is outside this job's inventory")
    args.retry_ids = set()
    only_singletons = getattr(args, "only_singletons", False)
    bounded_units = set()
    eligible = 0
    units = {unit["id"]: unit for unit in ledger.rows("SELECT * FROM units")}
    for row in rows:
        if selected and row["path"] not in selected:
            continue
        if row["outcome"] not in {"failed", "unidentified"}:
            continue
        unit = units.get(row["unit_id"])
        if only_singletons:
            if unit is None or unit["album"]:
                continue
            if (
                args.auto
                and row["outcome"] == "unidentified"
                and not getattr(args, "refresh_evidence", False)
                and unit["job"]
                and current_singleton_rejection(cli.no_symlinks(Path(unit["job"])), row)
            ):
                continue
        cleanup_pending = row["cleanup_error"] or ledger.rows(
            "SELECT 1 FROM cleanups WHERE source_id=? AND phase!='done'", (row["id"],)
        )
        if not cleanup_pending:
            try:
                path = cli.no_symlinks(Path(row["path"]))
                if row["sha256"] and sha256(path) != row["sha256"]:
                    continue
            except (OSError, ValueError):
                continue
        if only_singletons:
            # Reserve capacity only after verifying eligibility. Missing/changed
            # sources cannot starve later retries; captured cleanup sources need
            # their journal replay even when their original pathname is absent.
            eligible += 1
            if unit["id"] not in bounded_units and len(bounded_units) >= getattr(
                args, "max_units", 25
            ):
                continue
            bounded_units.add(unit["id"])
        if cleanup_pending:
            args.retry_ids.add(row["id"])
            continue
        if row["unit_id"]:
            if unit["job"] and row["review_kind"] != "failed":
                child = cli.no_symlinks(Path(unit["job"]))
                data = cli.load_job(child)
                records = [
                    record
                    for record in cli.source_records(data)
                    if str(record.source) == row["path"]
                ]
                start = len(cli.read_events(child))
                data.setdefault("decision_starts", {}).update(
                    {str(record.staged): start for record in records}
                )
                data["approvals"] = [
                    entry
                    for entry in data.get("approvals", [])
                    if entry["source_sha256"] != row["sha256"]
                ]
                data["prepared_files"] = [
                    entry
                    for entry in data.get("prepared_files", [])
                    if entry["source_sha256"] != row["sha256"]
                ]
                data["rematch_pending"] = True
                cli.save_json(child / "job.json", data)
        with ledger.connection:
            ledger.connection.execute(
                "UPDATE sources SET status=?,reason='',outcome='pending',review_kind='unidentified' WHERE id=?",
                ("ready" if row["unit_id"] else "discovered", row["id"]),
            )
            if row["unit_id"]:
                ledger.connection.execute(
                    "UPDATE units SET status='ready',reason='' WHERE id=?",
                    (row["unit_id"],),
                )
        args.retry_ids.add(row["id"])
    if only_singletons:
        print(
            f"Singleton policy {SINGLETON_POLICY_VERSION}: {eligible} eligible queued sources, {len(args.retry_ids)} selected for this invocation",
            flush=True,
        )


def process_unit(
    ledger: BulkLedger, unit: dict, index: CommittedIndex, args, *, reviewing=False
):
    rows = ledger.rows(
        "SELECT * FROM sources WHERE unit_id=? AND (status IN ('ready','review') OR (status='skipped' AND ?)) AND duplicate_of IS NULL ORDER BY id",
        (unit["id"], reviewing),
    )
    if getattr(args, "retry_ids", None) is not None:
        rows = [row for row in rows if row["id"] in args.retry_ids]
    active_ids = {row["id"] for row in rows}
    if reviewing:
        with ledger.connection:
            ledger.connection.execute(
                "UPDATE sources SET status='review' WHERE unit_id=? AND status='skipped' AND duplicate_of IS NULL",
                (unit["id"],),
            )
    if not rows:
        with ledger.connection:
            ledger.connection.execute(
                "UPDATE units SET status='done' WHERE id=?", (unit["id"],)
            )
        return
    if unit["album"] and len(rows) > 100:
        with ledger.connection:
            ledger.connection.execute(
                "UPDATE sources SET status='review',reason='Album group exceeds 100 tracks; select a smaller coherent batch' WHERE unit_id=? AND status='ready'",
                (unit["id"],),
            )
            ledger.connection.execute(
                "UPDATE units SET status='review',reason='Oversized album group' WHERE id=?",
                (unit["id"],),
            )
        return
    with ledger.connection:
        ledger.connection.execute(
            "UPDATE units SET status='processing' WHERE id=?", (unit["id"],)
        )
    for row in rows:
        path = cli.no_symlinks(Path(row["path"]))
        roots = [Path(root) for root in ledger.data["source_roots"]]
        if not any(path == root or path.is_relative_to(root) for root in roots):
            raise ValueError("Inventory source is outside the selected roots")
        if sha256(path) != row["sha256"]:
            raise ValueError(
                f"Source changed since inventory: {path}; start a new job for its current version"
            )
        result = index.lookup(path, row["sha256"])
        if result:
            with ledger.connection:
                ledger.connection.execute(
                    "UPDATE sources SET status=?,reason=? WHERE id=?",
                    (result[0], result[1], row["id"]),
                )
    rows = ledger.rows(
        "SELECT * FROM sources WHERE unit_id=? AND status IN ('ready','review') ORDER BY id",
        (unit["id"],),
    )
    rows = [row for row in rows if row["id"] in active_ids]
    if any(
        "catalogue output" in row["reason"] or "committed output" in row["reason"]
        for row in rows
    ):
        with ledger.connection:
            ledger.connection.execute(
                "UPDATE units SET status='review' WHERE id=?", (unit["id"],)
            )
        return
    if not rows:
        return
    child = child_job(ledger, unit)
    data = cli.load_job(child)
    if reviewing:
        hashes = {row["sha256"] for row in rows}
        data["skipped_candidates"] = [
            entry
            for entry in data.get("skipped_candidates", [])
            if entry["source_sha256"] not in hashes
        ]
        cli.save_json(child / "job.json", data)
    if (
        data.get("files")
        and data.get("publication_confirmed")
        and not data.get("publication_done")
    ):
        cli._publish_verified(
            [cli.file_record(entry) for entry in data["files"]],
            ledger.root,
            ledger.database,
            child,
        )
        data = cli.load_job(child)
        data["publication_done"] = True
        cli.save_json(child / "job.json", data)
        finish_unit(ledger, unit, child, index)
        return
    if data.get("publication_done"):
        data.setdefault("publication_history", []).append(data.pop("files", []))
        data.pop("publication_confirmed", None)
        data.pop("publication_done", None)
        cli.save_json(child / "job.json", data)
    sources = cli.stage_inputs(
        [Path(row["path"]) for row in rows],
        child,
        checkpoint=True,
        expected_hashes={row["path"]: row["sha256"] for row in rows},
    )
    automatic = bool(ledger.data.get("automatic")) and not reviewing
    if getattr(args, "retry", None):
        automatic = bool(args.auto)
    data = cli.load_job(child)
    active_hashes = {source.sha256 for source in sources}
    prepared = [
        cli.file_record(entry)
        for entry in data.get("prepared_files", [])
        if entry["source_sha256"] in active_hashes and Path(entry["candidate"]).exists()
    ]
    reuse = bool(prepared) and len(prepared) == len(sources)
    if reuse and reviewing:
        action = (
            input("[r]euse checked proposal or [m]atch again [r]: ").strip().casefold()
            or "r"
        )
        if action not in {"r", "m"}:
            raise ValueError("Choose reuse or match again")
        reuse = action == "r"
        if reuse:
            labels = data.setdefault("edition_labels", {})
            seen = set()
            for file in prepared:
                if file.album_key and file.album_key not in seen:
                    seen.add(file.album_key)
                    current = labels.get(file.album_key, file.fields.get("edition", ""))
                    print(
                        f"Album: {file.fields.get('album')}; release {file.fields.get('mb_albumid')}"
                    )
                    label = input(
                        f"Edition label [{current}] (enter '-' for none): "
                    ).strip()
                    labels[file.album_key] = "" if label == "-" else label or current
            cli.save_json(child / "job.json", data)
            files = cli.prepare_approved(
                child,
                sources,
                [
                    Approval(
                        file.source_sha256,
                        {
                            key: value
                            for key, value in file.fields.items()
                            if key != "edition"
                        },
                        file.album_key,
                        file.fields.get("edition", ""),
                    )
                    for file in prepared
                ],
                checkpoint=True,
            )
    elif reuse:
        files = prepared
    if not reuse:
        if reviewing and not data.get("rematch_pending"):
            old_approvals = data.get("approvals", [])
            album_keys = {file.album_key for file in prepared} | {
                entry["album_key"]
                for entry in old_approvals
                if entry["source_sha256"] in active_hashes
            }
            data["prepared_files"] = [
                entry
                for entry in data.get("prepared_files", [])
                if entry["source_sha256"] not in active_hashes
            ]
            data["approvals"] = [
                entry
                for entry in old_approvals
                if entry["source_sha256"] not in active_hashes
            ]
            for key in album_keys:
                data.get("edition_labels", {}).pop(key, None)
            start = len(cli.read_events(child))
            data.setdefault("decision_starts", {}).update(
                {str(source.staged): start for source in sources}
            )
            data["rematch_pending"] = True
            cli.save_json(child / "job.json", data)
        if data.get("approvals") and not reviewing and not data.get("rematch_pending"):
            approvals = [Approval(**entry) for entry in data["approvals"]]
        else:
            approvals = cli.run_matcher(
                child, sources, args.beet, automatic=automatic, retry_review=reviewing
            )
            data = cli.load_job(child)
            data["approvals"] = [asdict(approval) for approval in approvals]
            data.pop("rematch_pending", None)
            cli.save_json(child / "job.json", data)
        approvals = [
            approval
            for approval in approvals
            if approval.source_sha256 in active_hashes
        ]
        files = cli.prepare_approved(
            child, sources, approvals, automatic=automatic, checkpoint=True
        )
    if files and cli.review_publication(
        files, ledger.database, ledger.root, child, automatic=automatic
    ):
        data = cli.load_job(child)
        data["publication_confirmed"] = True
        cli.save_json(child / "job.json", data)
        cli._publish_verified(files, ledger.root, ledger.database, child)
        data = cli.load_job(child)
        data["publication_done"] = True
        cli.save_json(child / "job.json", data)
    finish_unit(ledger, unit, child, index, active_ids={row["id"] for row in rows})
    if cli.load_job(child).get("publication_aborted"):
        raise KeyboardInterrupt


def run_bulk(args) -> int:
    root, database, state = (
        cli.no_symlinks(path)
        for path in [args.library_root, args.database, args.state_directory]
    )
    job, ledger = None, None
    try:
        working = getattr(args, "move_after_verification", None)
        if working:
            working = cli.no_symlinks(working)
            if not working.is_dir():
                raise ValueError(
                    "Move mode requires an independent working source directory"
                )
            if not args.sources and not (
                args.resume or args.review or getattr(args, "retry", None)
            ):
                args.sources = [working]
            if any(
                not cli.no_symlinks(path).is_relative_to(working)
                for path in args.sources
            ):
                raise ValueError(
                    "Every move-mode source must be inside the selected working directory"
                )
        with cli.import_lock(
            state,
            str(
                args.review
                or args.resume
                or getattr(args, "retry", None)
                or "starting bulk inventory"
            ),
        ) as lock:
            cli.check_binding(database, root)
            if args.review or args.resume or getattr(args, "retry", None):
                job = cli.no_symlinks(args.review or args.resume or args.retry)
                ledger = BulkLedger(job, root, database)
                if working and ledger.data.get("working_source") != str(working):
                    raise ValueError(
                        "Move mode cannot be added or changed when resuming a job"
                    )
                if args.auto and not args.review and not getattr(args, "retry", None):
                    ledger.data["automatic"] = True
                    cli.save_json(job / "job.json", ledger.data)
            else:
                root.parent.mkdir(parents=True, exist_ok=True)
                job = Path(
                    subprocess.run(
                        ["mktemp", "-d", str(root.parent / ".beets-import.XXXXXXXX")],
                        check=True,
                        capture_output=True,
                        text=True,
                    ).stdout.strip()
                )
                cli.save_json(
                    job / "job.json",
                    {
                        "version": 1,
                        "kind": "bulk",
                        "job": str(job),
                        "root": str(root),
                        "database": str(database),
                        "state_directory": str(state),
                        "source_roots": [
                            str(cli.no_symlinks(path)) for path in args.sources
                        ],
                        "automatic": bool(args.auto),
                        "sources": [],
                        "working_source": str(working) if working else None,
                    },
                )
                ledger = BulkLedger(job, root, database)
            cli.save_json(state / "latest-job.json", {"job": str(job)})
            lock.seek(0)
            lock.truncate()
            lock.write(str(job) + "\n")
            lock.flush()
            print(f"Bulk import job: {job}", flush=True)
            index = CommittedIndex(database, root)
            import cleanup

            if getattr(args, "retry", None):
                retry_sources(ledger, args)
            cleanup_ids = getattr(args, "retry_ids", None)
            completed_ids = {
                row["source_id"]
                for row in ledger.rows(
                    "SELECT source_id FROM cleanups WHERE phase='done'"
                )
            }
            if cleanup_ids is not None:
                completed_ids &= cleanup_ids
            cleanup.run_cleanups(
                ledger, index, source_ids=completed_ids, include_completed=True
            )
            inventory_sources(
                ledger, [Path(path) for path in ledger.data["source_roots"]], index
            )
            plan_units(ledger)
            reconcile_committed(ledger, index)
            ledger.refresh_outcomes()
            plan_cleanup_units(ledger, index)
            statuses = ("review",) if args.review else ("ready", "processing", "retry")
            units = ledger.rows(
                "SELECT * FROM units WHERE status IN ("
                + ",".join("?" for _ in statuses)
                + ") ORDER BY id",
                statuses,
            )
            if getattr(args, "retry_ids", None) is not None:
                retry_units = {
                    row["unit_id"]
                    for row in ledger.rows("SELECT id,unit_id FROM sources")
                    if row["id"] in args.retry_ids
                }
                units = [unit for unit in units if unit["id"] in retry_units]
            work_ids = {unit["id"] for unit in units}
            cleanup_pending = pending_cleanup_ids(
                ledger.rows("SELECT id,status FROM sources"),
                ledger.rows("SELECT source_id,phase FROM cleanups"),
                ledger.data.get("working_source"),
            )
            if cleanup_ids is not None:
                cleanup_pending &= cleanup_ids
            cleanup_units = {
                row["unit_id"]
                for row in ledger.rows("SELECT id,unit_id FROM sources")
                if row["id"] in cleanup_pending and row["unit_id"] is not None
            }
            by_id = {unit["id"]: unit for unit in units}
            for unit in ledger.rows("SELECT * FROM units"):
                if unit["id"] in cleanup_units:
                    by_id[unit["id"]] = unit
            in_progress = {
                row["unit_id"]
                for row in ledger.rows(
                    "SELECT s.unit_id FROM sources s JOIN cleanups c ON c.source_id=s.id WHERE c.phase IN ('capturing','captured','removing')"
                )
            }
            units = sorted(
                [
                    unit
                    for unit in by_id.values()
                    if not getattr(args, "only_singletons", False) or not unit["album"]
                ],
                key=lambda unit: (unit["id"] not in in_progress, unit["id"]),
            )[: getattr(args, "max_units", 25)]
            for unit in units:
                try:
                    unit_ids = {
                        row["id"]
                        for row in ledger.rows(
                            "SELECT id FROM sources WHERE unit_id=?", (unit["id"],)
                        )
                    }
                    if cleanup_ids is not None:
                        unit_ids &= cleanup_ids
                    cleanup.run_cleanups(ledger, index, source_ids=unit_ids)
                    if unit["id"] in work_ids:
                        process_unit(
                            ledger, unit, index, args, reviewing=bool(args.review)
                        )
                    cleanup.run_cleanups(
                        ledger,
                        index,
                        source_ids=unit_ids,
                    )
                except (ValueError, OSError, subprocess.CalledProcessError) as exc:
                    systemic = isinstance(exc, OSError) and exc.errno in {
                        errno.ENOSPC,
                        errno.EDQUOT,
                        errno.EROFS,
                        errno.EIO,
                        errno.EACCES,
                    }
                    with ledger.connection:
                        ledger.connection.execute(
                            "UPDATE units SET status=?,reason=? WHERE id=?",
                            ("retry" if systemic else "review", str(exc), unit["id"]),
                        )
                        if not systemic:
                            ledger.connection.execute(
                                "UPDATE sources SET status='review',review_kind='failed',reason=? WHERE unit_id=? AND status IN ('ready','review')",
                                (str(exc), unit["id"]),
                            )
                    if systemic:
                        with ledger.connection:
                            ledger.connection.execute(
                                "UPDATE sources SET review_kind='failed',outcome='failed',reason=? WHERE unit_id=? AND status IN ('ready','review')",
                                (str(exc), unit["id"]),
                            )
                        raise
                    print(
                        f"Unit {unit['id']} retained in review: {exc}", file=sys.stderr
                    )
                ledger.refresh_outcomes(unit_id=unit["id"])
                print(json.dumps(ledger.summary(), sort_keys=True), flush=True)
            summary = ledger.summary()
            print(json.dumps(summary, indent=2), flush=True)
            return (
                2
                if summary["review"]
                or summary["unscanned"]
                or summary["ready"]
                or summary["duplicate_pending"]
                or summary["progress"]["failed_files"]
                or summary["progress"]["cleanup_pending_files"]
                else 0
            )
    except (KeyboardInterrupt, EOFError):
        print(f"Bulk import interrupted; resume {job}", file=sys.stderr)
        return 130
    except (ValueError, OSError, sqlite3.Error, subprocess.CalledProcessError) as exc:
        print(f"Bulk import incomplete: {exc}; retained job {job}", file=sys.stderr)
        return 1
    finally:
        if ledger:
            ledger.close()
