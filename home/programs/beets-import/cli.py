"""Stage and review music without exposing retained sources to the importer."""

from collections import defaultdict
from contextlib import contextmanager, redirect_stdout
from dataclasses import asdict, replace
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unicodedata

import metadata as media_checks
from metadata import (
    Approval,
    SourceRecord,
    VerifiedFile,
    sha256,
    source_metadata,
    plan_destination,
    prepare_candidate,
    verify_candidate,
)
from beetsplug.import_policy import SINGLETON_POLICY_VERSION


def read_json(path: Path) -> dict:
    return json.loads(path.read_text())


def no_symlinks(path: Path) -> Path:
    path = Path(os.path.abspath(path.expanduser()))
    if any(p.is_symlink() for p in (path, *path.parents)):
        raise ValueError(
            f"Symlink path is not an independent source/destination: {path}"
        )
    return path


def album_group(metadata: dict):
    fields = metadata["fields"]
    artist = fields.get("albumartist") or (
        "Various Artists" if fields.get("comp") else fields.get("artist")
    )
    album = fields.get("album")
    if not artist or not album:
        return None
    return (artist, album, fields.get("year"), fields.get("mb_albumid"))


def discover_sources(
    sources: list[Path], root: Path, job: Path, allow_links=False
) -> list[Path]:
    paths = [no_symlinks(p) for p in sources]
    for index, path in enumerate(paths):
        if not path.exists():
            raise ValueError(f"Source does not exist: {path}")
        for forbidden in [root, job]:
            if path.is_relative_to(forbidden) or forbidden.is_relative_to(path):
                raise ValueError(f"Source overlaps job or destination: {path}")
        if any(path.is_relative_to(p) or p.is_relative_to(path) for p in paths[:index]):
            raise ValueError(f"Overlapping source selections: {path}")
    files = []
    for path in paths:
        if path.is_dir():
            for directory, dirs, names in os.walk(path, followlinks=False):
                dirs[:] = [
                    name
                    for name in dirs
                    if not name.startswith(".beets-import-retire-")
                ]
                for name in [*dirs, *names]:
                    entry = Path(directory) / name
                    if allow_links and entry.is_symlink():
                        if name in dirs:
                            files.append(entry)
                    else:
                        no_symlinks(entry)
                files.extend(Path(directory) / name for name in sorted(names))
        elif path.is_file():
            files.append(path)
        else:
            raise ValueError(f"Not a regular source: {path}")
    return sorted(files)


def stage_inputs(
    sources: list[Path], job: Path, *, checkpoint=False, expected_hashes=None
) -> list[SourceRecord]:
    data = load_job(job)
    root = no_symlinks(Path(data["root"]))
    files = discover_sources(sources, root, job)
    saved = (
        {entry.source: entry for entry in source_records(data)} if checkpoint else {}
    )
    records, pending = [], []
    for index, path in enumerate(files):
        if not path.is_file():
            raise ValueError(f"Not a regular source: {path}")
        before = sha256(path)
        if expected_hashes is not None and before != expected_hashes.get(str(path)):
            raise ValueError(f"Source changed since inventory: {path}")
        if path in saved:
            record = saved[path]
            if before != record.sha256 or sha256(record.staged) != before:
                raise ValueError(f"Source or staged copy changed: {path}")
            records.append(record)
            continue
        try:
            metadata = source_metadata(path)
        except Exception as exc:
            pending.append({"source": str(path), "reason": str(exc)})
            continue
        group = album_group(metadata)
        name = (
            hashlib.sha256(json.dumps(group).encode()).hexdigest()[:20]
            if group
            else f"single-{index}"
        )
        destination = job / "input" / name / f"{index:06d}-{path.name}"
        destination.parent.mkdir(parents=True, exist_ok=True)
        no_symlinks(destination)
        if destination.exists() and sha256(destination) != before:
            raise ValueError(f"Staged copy changed: {destination}")
        if not destination.exists():
            fd, temporary = tempfile.mkstemp(prefix=".copy-", dir=destination.parent)
            os.close(fd)
            shutil.copy2(path, temporary)
            if sha256(path) != before or sha256(Path(temporary)) != before:
                raise ValueError(
                    f"Source changed during staging; keep job pending: {path}"
                )
            with open(temporary, "rb") as stream:
                os.fsync(stream.fileno())
            os.replace(temporary, destination)
            sync_directory(destination.parent)
        if sha256(path) != before or sha256(destination) != before:
            raise ValueError(f"Source changed during staging; keep job pending: {path}")
        records.append(SourceRecord(path, destination, before, metadata))
        if checkpoint:
            saved[path] = records[-1]
            data["sources"] = [asdict(record) for record in saved.values()]
            save_json(job / "job.json", data)
    (job / "pending-inputs.json").write_text(json.dumps(pending, indent=2) + "\n")
    return records


def partition_sources(
    sources: list[SourceRecord],
) -> list[tuple[bool, list[SourceRecord]]]:
    groups = defaultdict(list)
    for source in sources:
        key = album_group(source.metadata)
        groups[(True, key) if key else (False, str(source.staged))].append(source)
    return [(key[0], values) for key, values in groups.items()]


def matcher_configuration(job: Path, automatic=False) -> tuple[dict, dict]:
    cfg = {
        "directory": str(job / "unused-matcher-output"),
        "library": str(job / "matching.db"),
        "statefile": str(job / "matching-state.pickle"),
        "plugins": ["musicbrainz", "chroma", "import_audit"],
        "pluginpath": [str(Path(__file__).parent / "beetsplug")],
        "threaded": False,
        "original_date": False,
        "per_disc_numbering": False,
        "import": {
            "copy": False,
            "move": False,
            "write": False,
            "link": False,
            "hardlink": False,
            "reflink": False,
            "quiet": False,
            "timid": True,
            "none_rec_action": "ask",
            "from_scratch": False,
            "group_albums": True,
            "resume": False,
            "incremental": False,
            "duplicate_action": "ask",
            "log": str(job / "import.log"),
        },
        "import_audit": {"log": str(job / "decisions.jsonl"), "automatic": automatic},
    }
    if automatic:
        cfg["import"].update(
            quiet=True,
            timid=False,
            quiet_fallback="skip",
            none_rec_action="skip",
            duplicate_action="skip",
        )
    cache = (
        Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "codex/beets"
    )
    env = dict(
        os.environ,
        BEETSDIR=str(job / "config"),
        XDG_CACHE_HOME=str(cache),
        PYTHONDONTWRITEBYTECODE="1",
    )
    return cfg, env


def read_approvals(
    events: list[dict], sources: list[SourceRecord], aliases=None
) -> list[Approval]:
    by_path = {str(source.staged): source for source in sources}
    approved = {}
    for event in events:
        for item in event["items"]:
            path = (aliases or {}).get(item["path"], item["path"])
            if path not in by_path:
                raise ValueError(
                    f"Matcher returned a path outside the selected copies: {path}"
                )
            if event["action"] != "APPLY":
                approved.pop(path, None)
                continue
            fields = item["fields"]
            album_key = fields.get("mb_albumid") if event["album"] else None
            if event["album"] and not album_key:
                raise ValueError("Approved album lacks a verified release identifier")
            approved[path] = Approval(by_path[path].sha256, fields, album_key)
    return list(approved.values())


def read_events(job: Path) -> list[dict]:
    path = job / "decisions.jsonl"
    lines = path.read_text().splitlines(keepends=True) if path.exists() else []
    events = []
    for index, line in enumerate(lines):
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            if index != len(lines) - 1 or line.endswith("\n"):
                raise ValueError("Corrupted importer decision journal")
    return events


def job_approvals(job: Path, sources: list[SourceRecord]) -> list[Approval]:
    data = read_json(job / "job.json")
    return read_approvals(
        current_decisions(read_events(job), data),
        sources,
        data.get("matching_aliases", {}),
    )


def current_decisions(events: list[dict], data: dict) -> list[dict]:
    aliases = data.get("matching_aliases", {})
    starts = data.get("decision_starts", {})
    return [
        {
            **event,
            "items": [
                item
                for item in event["items"]
                if index >= starts.get(aliases.get(item["path"], item["path"]), 0)
            ],
        }
        for index, event in enumerate(events)
    ]


def run_matcher(
    job: Path,
    sources: list[SourceRecord],
    beet: str = "beet",
    *,
    automatic=False,
    retry_review=False,
) -> list[Approval]:
    from beets import __version__

    cfg, env = matcher_configuration(job, automatic)
    data = load_job(job)
    all_sources = source_records(data) or sources
    aliases = data.setdefault("matching_aliases", {})
    decided = set()
    events = read_events(job)
    for event in current_decisions(events, data):
        if event["action"] in {"APPLY", "SKIP", "ASIS"} or (
            event["action"] == "REVIEW"
            and event.get("album") is False
            and event.get("policy") == SINGLETON_POLICY_VERSION
        ):
            decided.update(
                aliases.get(item["path"], item["path"]) for item in event["items"]
            )
    if not retry_review:
        sources = [source for source in sources if str(source.staged) not in decided]
    # Each invocation sees only its remaining owned copies, including after an
    # as-tracks interruption. Hardlinks never involve retained originals.
    views = job / "matching"
    views.mkdir(exist_ok=True)
    session = Path(
        subprocess.run(
            ["mktemp", "-d", str(views / "session.XXXXXXXX")],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    )
    cfg["library"] = str(session / "matching.db")
    log = job / "decisions.jsonl"
    if log.exists():
        # Discard only a torn final record before appending new complete events.
        with log.open("w") as stream:
            stream.writelines(
                json.dumps(event, ensure_ascii=True) + "\n" for event in events
            )
            stream.flush()
            os.fsync(stream.fileno())
    (job / "config").mkdir(exist_ok=True)
    (job / "config/config.yaml").write_text(json.dumps(cfg, indent=2))
    version = subprocess.run(
        [beet, "version"], env=env, capture_output=True, text=True, check=True
    )
    if f"beets version {__version__}" not in version.stdout.splitlines():
        raise ValueError("Matcher and helper beets versions differ")
    for index, (album, records) in enumerate(partition_sources(sources)):
        print(
            f"{'Album group' if album else 'Individual track'}: {len(records)} files; "
            f"{album_group(records[0].metadata) or records[0].source.name}",
            flush=True,
        )
        if album and len(records) > 100:
            print(
                "Group exceeds 100 tracks: retained pending a smaller selection or singleton import."
            )
            continue
        view = session / f"group-{index}"
        view.mkdir()
        matched_paths = []
        for record in records:
            if (
                sha256(record.staged) != record.sha256
                or sha256(record.source) != record.sha256
            ):
                raise ValueError("Source changed before matching")
            alias = view / record.staged.name
            os.link(record.staged, alias, follow_symlinks=False)
            aliases[str(alias)] = str(record.staged)
            matched_paths.append(str(alias))
        save_json(job / "job.json", data)
        # Avoid the ID-only early return for loose tracks, and collect the full
        # fingerprint response once before chroma resolves its recording candidates.
        if automatic:
            cfg["chroma"] = {"auto": album}
            cfg["import_audit"]["collect_recording_evidence"] = not album
            (job / "config/config.yaml").write_text(json.dumps(cfg, indent=2))
        paths = [str(view)] if album else matched_paths
        args = (
            [beet, "import", "--group-albums"]
            if album
            else [beet, "import", "--singletons"]
        )
        subprocess.run([*args, "--", *paths], env=env, check=True)
    return job_approvals(job, all_sources)


def sync_directory(path: Path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def save_json(path: Path, data: dict):
    """Replace only an owned job/state record, durably and on its filesystem."""
    fd, temporary = tempfile.mkstemp(prefix=".journal-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(data, stream, default=str, indent=2, ensure_ascii=True)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        sync_directory(path.parent)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


@contextmanager
def import_lock(state: Path, label: str):
    state = no_symlinks(state)
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd = os.open(state / "import.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "r+") as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise ValueError(
                f"Another guided import is active: {stream.read().strip()}"
            ) from exc
        stream.seek(0)
        stream.truncate()
        stream.write(label + "\n")
        stream.flush()
        try:
            yield stream
        finally:
            fcntl.flock(stream, fcntl.LOCK_UN)


def check_binding(database: Path, root: Path):
    database, root = no_symlinks(database), no_symlinks(root)
    binding = database.with_name(database.name + ".root.json")
    if binding.exists():
        no_symlinks(binding)
        if read_json(binding) != {"version": 1, "root": str(root)}:
            raise ValueError(
                "Catalogue root binding differs; do not rebase an existing catalogue"
            )
    elif database.exists():
        raise ValueError(
            "Existing catalogue has no guided-import root binding; review it before use"
        )
    return binding


@contextmanager
def open_catalogue(database: Path, root: Path, create=False):
    from beets import config
    from beets.library import Library

    binding = check_binding(database, root)
    if not database.exists() and not create:
        yield None
        return
    database.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if not binding.exists():
        with binding.open("x") as stream:
            json.dump({"version": 1, "root": str(root)}, stream)
            stream.flush()
            os.fsync(stream.fileno())
        sync_directory(binding.parent)
    # Defaults only: API operations must not inherit ordinary user plugins/settings.
    config.clear()
    config.read(user=False)
    config.set({"directory": str(root), "library": str(database)})
    with (
        (database.parent / "catalogue-initialization.log").open("a") as log,
        redirect_stdout(log),
    ):
        library = Library(database, directory=str(root))
    try:
        yield library
    finally:
        library._close()  # Verified in the pinned beets API; close every connection.


def catalogue_entries(database: Path, root: Path) -> list[dict]:
    with open_catalogue(database, root) as library:
        if library is None:
            return []
        return [
            {
                "path": os.fsdecode(item.path),
                "fields": {
                    key: item.get(key)
                    for key in [
                        "artist",
                        "title",
                        "album",
                        "year",
                        "mb_trackid",
                        "mb_albumid",
                        "format",
                        "bitrate",
                        "edition",
                        "album_id",
                    ]
                },
                "source_sha256": item.get("beets_import_source_sha256", ""),
                "source": item.get("beets_import_source_path", ""),
                "job": item.get("beets_import_job", ""),
                "sha256": item.get("beets_import_sha256", ""),
            }
            for item in library.items()
        ]


def find_duplicates(files: list[VerifiedFile], existing: list[dict]) -> list[dict]:
    entries = list(existing)
    duplicates = []
    for file in files:
        new_path = str(file.relative_destination)
        for entry in entries:
            other = entry["fields"]
            same_hash = file.source_sha256 == entry.get("source_sha256")
            same_id = bool(file.fields.get("mb_trackid")) and file.fields[
                "mb_trackid"
            ] == other.get("mb_trackid")
            same_name = all(
                str(file.fields.get(key, "")).strip().casefold()
                == str(other.get(key, "")).strip().casefold()
                for key in ["artist", "title"]
            )
            if same_hash or same_id or same_name:
                duplicates.append(
                    {
                        "new": new_path,
                        "existing": entry["path"],
                        "source_sha256": file.source_sha256,
                        "reason": "same source hash"
                        if same_hash
                        else "same recording ID"
                        if same_id
                        else "same artist/title",
                        "new_fields": file.fields,
                        "existing_fields": other,
                    }
                )
        entries.append(
            {
                "path": new_path,
                "fields": file.fields,
                "source_sha256": file.source_sha256,
            }
        )
    return duplicates


def checked_destination(root: Path, relative: Path) -> Path:
    if (
        relative.is_absolute()
        or ".." in relative.parts
        or len(relative.parts) not in {3, 5}
    ):
        raise ValueError("Invalid destination outside the agreed library layout")
    if relative.parts[0] not in {"Albums", "Unsorted"}:
        raise ValueError("Invalid destination branch")
    cursor = no_symlinks(root)
    for part in relative.parts:
        if cursor.exists():
            wanted = unicodedata.normalize("NFC", part).casefold()
            if any(
                unicodedata.normalize("NFC", entry.name).casefold() == wanted
                and entry.name != part
                for entry in cursor.iterdir()
            ):
                raise ValueError(
                    f"Case or Unicode destination collision: {cursor / part}"
                )
        cursor = no_symlinks(cursor / part)
    return cursor


def load_job(job: Path) -> dict:
    job = no_symlinks(job)
    if (
        not job.is_dir()
        or job.stat().st_uid != os.getuid()
        or job.stat().st_mode & 0o077
    ):
        raise ValueError(
            "Import job must be a private directory owned by the current user"
        )
    data = read_json(no_symlinks(job / "job.json"))
    if data.get("version") != 1 or data.get("job") != str(job):
        raise ValueError("Unsupported or inconsistent job journal")
    root = no_symlinks(Path(data["root"]))
    if root.is_relative_to(job) or job.is_relative_to(root):
        raise ValueError("Library root and job overlap")
    for entry in data.get("sources", []):
        source, staged = (
            no_symlinks(Path(entry["source"])),
            no_symlinks(Path(entry["staged"])),
        )
        if (
            not staged.is_relative_to(job / "input")
            or source.is_relative_to(job)
            or source.is_relative_to(root)
            or root.is_relative_to(source)
        ):
            raise ValueError("Source record overlaps the job or library")
        if source.exists() and staged.exists() and source.samefile(staged):
            raise ValueError("Job input is hardlinked to a retained source")
    for entry in data.get("files", []):
        candidate = no_symlinks(Path(entry["candidate"]))
        if not candidate.is_relative_to(job / "candidates"):
            raise ValueError("Candidate path is outside this job")
        checked_destination(root, Path(entry["relative_destination"]))
    return data


def source_records(data: dict) -> list[SourceRecord]:
    return [
        SourceRecord(Path(s["source"]), Path(s["staged"]), s["sha256"], s["metadata"])
        for s in data.get("sources", [])
    ]


def file_record(entry: dict) -> VerifiedFile:
    return VerifiedFile(
        entry["source_sha256"],
        Path(entry["candidate"]),
        Path(entry["relative_destination"]),
        entry["fields"],
        entry["album_key"],
        entry["verification"],
    )


def file_approval(file: VerifiedFile) -> Approval:
    return Approval(
        file.source_sha256, file.fields, file.album_key, file.fields.get("edition", "")
    )


def register_files(data: dict):
    """Register published bytes without invoking any tag writer."""
    from beets.library import Item

    root, database = Path(data["root"]), Path(data["database"])
    with open_catalogue(database, root, create=True) as library:
        existing = {os.fsdecode(item.path): item for item in library.items()}
        album_ids = defaultdict(set)
        for path, item in existing.items():
            if item.album_id:
                album_ids[str(Path(path).parent)].add(item.album_id)
        groups = defaultdict(list)
        for entry in data["files"]:
            path = str(root / entry["relative_destination"])
            if path in existing:
                item = existing[path]
                if (
                    item.get("beets_import_job") != data["job"]
                    or item.get("beets_import_sha256")
                    != entry["verification"]["sha256"]
                ):
                    raise ValueError(
                        f"Existing catalogue entry has different provenance: {path}"
                    )
                continue
            item = Item.from_path(path)
            core = media_checks.read_media(Path(path))
            for field in (
                media_checks.IDENTITY | media_checks.RELEASE | media_checks.MB_FIELDS
            ) & item._fields.keys():
                item[field] = getattr(core, field)
            item["beets_import_job"] = data["job"]
            item["beets_import_source_sha256"] = entry["source_sha256"]
            item["beets_import_source_path"] = next(
                str(source.source)
                for source in source_records(data)
                if source.sha256 == entry["source_sha256"]
            )
            item["beets_import_sha256"] = entry["verification"]["sha256"]
            item["edition"] = entry["fields"].get("edition", "")
            groups[(entry["album_key"], str(Path(path).parent))].append(item)
        with library.transaction() as tx:
            # Beets commits even when its context exits with an exception.
            tx.mutate("SAVEPOINT guided_import")
            try:
                for (key, directory), items in groups.items():
                    if key:
                        ids = album_ids[directory]
                        if len(ids) > 1:
                            raise ValueError(
                                "Multiple album records share an edition directory; review required"
                            )
                        if ids:
                            album = library.get_album(next(iter(ids)))
                            if album.mb_albumid != items[0].mb_albumid or album.get(
                                "edition", ""
                            ) != items[0].get("edition", ""):
                                raise ValueError(
                                    "Conflicting release identity in album directory"
                                )
                            for item in items:
                                item.album_id = album.id
                                library.add(item)
                        else:
                            album = library.add_album(items)
                            album["edition"] = items[0].get("edition", "")
                            album["beets_import_job"] = data["job"]
                            album.store()
                            ids.add(album.id)
                    else:
                        for item in items:
                            library.add(item)
                tx.mutate("RELEASE SAVEPOINT guided_import")
            except BaseException:
                tx.mutate("ROLLBACK TO SAVEPOINT guided_import")
                tx.mutate("RELEASE SAVEPOINT guided_import")
                raise


def check_album_targets(files: list[VerifiedFile], root: Path, existing: list[dict]):
    by_directory = defaultdict(list)
    for entry in existing:
        by_directory[str(Path(entry["path"]).parent)].append(entry["fields"])
    for file in files:
        if not file.album_key:
            continue
        directory = str(root / file.relative_destination.parent)
        entries = by_directory[directory]
        if any(
            other.get("mb_albumid") != file.fields.get("mb_albumid")
            or other.get("edition", "") != file.fields.get("edition", "")
            for other in entries
        ):
            raise ValueError(
                f"Conflicting release/edition identity in directory: {directory}"
            )
        if entries and (
            any(not e.get("album_id") for e in entries)
            or len({e["album_id"] for e in entries}) > 1
        ):
            raise ValueError(
                f"Conflicting album records in edition directory: {directory}"
            )


def _publish_verified(
    files: list[VerifiedFile], root: Path, database: Path, job: Path
) -> dict:
    data = load_job(job)
    if data["root"] != str(root) or data.get("database", str(database)) != str(
        database
    ):
        raise ValueError("Job root/database differs from requested publication")
    check_binding(database, root)
    if not data.get("files"):
        data["files"] = [{**asdict(file), "status": "verified"} for file in files]
    elif [f.relative_destination for f in files] != [
        Path(e["relative_destination"]) for e in data["files"]
    ]:
        raise ValueError("Job already has a different publication plan")
    data["database"] = str(database)
    records = {s.sha256: s for s in source_records(data)}
    paths = set()
    existing = catalogue_entries(database, root)
    check_album_targets(files, root, existing)
    remaining = []
    for entry in data["files"]:
        file = file_record(entry)
        if file.source_sha256 not in records:
            raise ValueError("Verified file has no source record in this job")
        destination = checked_destination(root, file.relative_destination)
        key = unicodedata.normalize("NFC", str(file.relative_destination)).casefold()
        if key in paths:
            raise ValueError(f"Conflicting destination paths: {destination}")
        paths.add(key)
        if file.relative_destination != plan_destination(
            file_approval(file), file.candidate
        ):
            raise ValueError("Job destination differs from its approved metadata")
        if destination.exists():
            if (
                entry["status"] == "publishing"
                and file.candidate.exists()
                and destination.samefile(file.candidate)
            ):
                entry["status"] = "published"
            elif entry["status"] not in {"published", "registered"}:
                raise ValueError(
                    f"Existing destination will not be replaced: {destination}"
                )
            if sha256(destination) != file.verification["sha256"]:
                raise ValueError(f"Published file changed: {destination}")
            verify_candidate(
                records[file.source_sha256], destination, file_approval(file)
            )
        else:
            if entry["status"] in {"published", "registered"}:
                raise ValueError(f"Published destination is missing: {destination}")
            if (
                not file.candidate.exists()
                or sha256(file.candidate) != file.verification["sha256"]
            ):
                raise ValueError(f"Candidate changed in job: {file.candidate}")
            verify_candidate(
                records[file.source_sha256], file.candidate, file_approval(file)
            )
            remaining.append(file)
    duplicates = find_duplicates(
        remaining, [e for e in existing if e["job"] != str(job)]
    )
    reviews = {
        (r["new"], r["existing"], r["source_sha256"])
        for r in data.get("distinct_editions", [])
    }
    conflicts = [
        d
        for d in duplicates
        if (d["new"], d["existing"], d["source_sha256"]) not in reviews
    ]
    if conflicts:
        raise ValueError(
            "Possible duplicate requires review: "
            + json.dumps(conflicts, ensure_ascii=True)
        )
    save_json(job / "job.json", data)
    for entry in data["files"]:
        file = file_record(entry)
        destination = checked_destination(root, file.relative_destination)
        if entry["status"] in {"published", "registered"}:
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        checked_destination(root, file.relative_destination)
        entry["status"] = "publishing"
        save_json(job / "job.json", data)
        with file.candidate.open("rb") as stream:
            os.fsync(stream.fileno())
        os.link(file.candidate, destination, follow_symlinks=False)
        sync_directory(destination.parent)
        entry["status"] = "published"
        save_json(job / "job.json", data)
        file.candidate.unlink()
        sync_directory(file.candidate.parent)
    register_files(data)
    for entry in data["files"]:
        entry["status"] = "registered"
    data["phase"] = "complete"
    save_json(job / "job.json", data)
    # Keep inputs/candidates for audit/recovery; no implicit data cleanup.
    return {
        "job": str(job),
        "registered": len(data["files"]),
        "verified_files": len(data["files"]),
        "already_registered": sum(e["job"] == str(job) for e in existing),
        "published_files": len(data["files"]),
        "published_bytes": sum(
            (root / e["relative_destination"]).stat().st_size for e in data["files"]
        ),
        "pending": len(
            {
                entry.get("source_sha256") or entry.get("source")
                for entry in data.get("pending", []) + data.get("review_queue", [])
            }
        ),
        "staged_inputs": len(source_records(data)),
        "input_bytes": sum(
            s.staged.stat().st_size for s in source_records(data) if s.staged.is_file()
        ),
    }


def publish_verified(
    files: list[VerifiedFile], root: Path, database: Path, job: Path
) -> dict:
    state = Path(read_json(job / "job.json").get("state_directory", database.parent))
    with import_lock(state, str(job)):
        return _publish_verified(files, root, database, job)


def resume_job(job: Path) -> dict:
    data = load_job(job)
    database = Path(data["database"])
    state = Path(data.get("state_directory", database.parent))
    with import_lock(state, str(job)):
        return _publish_verified(
            [file_record(e) for e in data["files"]], Path(data["root"]), database, job
        )


def prepare_approved(
    job: Path,
    sources: list[SourceRecord],
    approvals: list[Approval],
    *,
    automatic=False,
    checkpoint=False,
) -> list[VerifiedFile]:
    data = load_job(job)
    skipped_hashes = {
        entry["source_sha256"] for entry in data.get("skipped_candidates", [])
    }
    sources = [source for source in sources if source.sha256 not in skipped_hashes]
    approvals = [
        approval
        for approval in approvals
        if approval.source_sha256 not in skipped_hashes
    ]
    by_hash = {s.sha256: s for s in sources}
    active_paths = {str(source.source) for source in sources}
    files, pending, edition_labels = (
        [],
        [
            entry
            for entry in data.get("pending", [])
            if entry.get("source") not in active_paths
        ],
        data.get("edition_labels", {}),
    )
    prepared = (
        {entry["source_sha256"]: entry for entry in data.get("prepared_files", [])}
        if checkpoint
        else {}
    )
    for approval in approvals:
        source = by_hash[approval.source_sha256]
        if approval.album_key:
            if approval.album_key not in edition_labels:
                print(
                    f"Album: {approval.fields.get('album')} ({approval.fields.get('year')}); "
                    f"release {approval.fields.get('mb_albumid')}"
                )
                suggested = approval.fields.get("albumdisambig") or ""
                label = (
                    suggested
                    if automatic
                    else input(
                        f"Edition label [{suggested}] (enter '-' for none): "
                    ).strip()
                )
                edition_labels[approval.album_key] = (
                    "" if label == "-" else label or suggested
                )
                data["edition_labels"] = edition_labels
                save_json(job / "job.json", data)
            approval = replace(approval, edition=edition_labels[approval.album_key])
        try:
            fields = {**approval.fields, "edition": approval.edition}
            cached = prepared.get(source.sha256)
            if cached and cached["fields"] == fields:
                previous = file_record(cached)
                if (
                    previous.candidate.exists()
                    and sha256(previous.candidate) == previous.verification["sha256"]
                    and sha256(source.source) == source.sha256
                    and sha256(source.staged) == source.sha256
                ):
                    files.append(previous)
                    continue
            destination = plan_destination(approval, source.staged)
            candidate = prepare_candidate(source, approval, job)
            # Normalize extension to the actual retained audio container.
            destination = plan_destination(approval, candidate)
            verification = verify_candidate(source, candidate, approval)
            files.append(
                VerifiedFile(
                    source.sha256,
                    candidate,
                    destination,
                    fields,
                    approval.album_key,
                    verification,
                )
            )
            if checkpoint:
                prepared[source.sha256] = asdict(files[-1])
                data["prepared_files"] = list(prepared.values())
                save_json(job / "job.json", data)
        except (ValueError, OSError, subprocess.CalledProcessError) as exc:
            pending.append({"source": str(source.source), "reason": str(exc)})
    approved_hashes = {a.source_sha256 for a in approvals}
    pending.extend(
        {"source": str(s.source), "reason": "unmatched, skipped, or unchanged"}
        for s in sources
        if s.sha256 not in approved_hashes
    )
    pending.extend(read_json(job / "pending-inputs.json"))
    data["pending"] = pending
    save_json(job / "job.json", data)
    return files


def review_publication(
    files: list[VerifiedFile], database: Path, root: Path, job: Path, *, automatic=False
) -> bool:
    for file in files:
        print(root / file.relative_destination)
    data = load_job(job)
    if data.pop("publication_aborted", None):
        save_json(job / "job.json", data)
    existing = catalogue_entries(database, root)
    reviews, selected = [], []
    active_hashes = {file.source_sha256 for file in files}
    queued = [
        entry
        for entry in data.get("review_queue", [])
        if entry["source_sha256"] not in active_hashes
    ]
    skipped = [
        entry
        for entry in data.get("skipped_candidates", [])
        if entry["source_sha256"] not in active_hashes
    ]
    skipped_albums = set()
    for file in list(files):
        if file.album_key and file.album_key in skipped_albums:
            continue
        previous = existing + [
            {
                "path": str(kept.relative_destination),
                "fields": kept.fields,
                "source_sha256": kept.source_sha256,
            }
            for kept in selected
        ]
        duplicates = find_duplicates([file], previous)
        conflict = ""
        try:
            destination = checked_destination(root, file.relative_destination)
            if destination.exists():
                conflict = f"Destination already exists: {destination}"
            check_album_targets([file], root, existing)
        except ValueError as exc:
            conflict = str(exc)
        if duplicates or conflict:
            print(
                "Candidate needs review:",
                json.dumps(duplicates, ensure_ascii=False, indent=2),
                conflict,
            )
            action = (
                "q"
                if automatic
                else input(
                    "[k]eep distinct edition, [s]kip candidate, skip a[l]bum, [q]ueue candidate, [a]bort batch [q]: "
                )
                .strip()
                .casefold()
                or "q"
            )
            if action == "a":
                data["publication_aborted"] = True
                data["review_queue"], data["skipped_candidates"] = queued, skipped
                save_json(job / "job.json", data)
                return False
            if action == "l" and file.album_key:
                skipped_albums.add(file.album_key)
                selected[:] = [
                    entry for entry in selected if entry.album_key != file.album_key
                ]
                for entry in files:
                    if entry.album_key == file.album_key:
                        skipped.append(
                            {
                                "source_sha256": entry.source_sha256,
                                "destination": str(entry.relative_destination),
                                "reason": "Album explicitly skipped",
                                "duplicates": duplicates if entry == file else [],
                            }
                        )
                continue
            if action not in {"k", "y", "yes"} or conflict:
                record = {
                    "source_sha256": file.source_sha256,
                    "destination": str(file.relative_destination),
                    "reason": conflict
                    or "Possible duplicate requires recording/edition review",
                    "duplicates": duplicates,
                }
                (skipped if action == "s" else queued).append(record)
                continue
            reviews.extend(
                {key: duplicate[key] for key in ["new", "existing", "source_sha256"]}
                for duplicate in duplicates
            )
        selected.append(file)
    files[:] = selected
    data["review_queue"], data["skipped_candidates"] = queued, skipped
    data["distinct_editions"] = reviews
    save_json(job / "job.json", data)
    return bool(files) and (
        automatic
        or input(f"Publish {len(files)} checked files? [y/N] ").strip().casefold()
        == "y"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Review copies with beets, preserve metadata/audio, and publish checked files."
    )
    parser.add_argument("--library-root", required=True, type=Path)
    parser.add_argument("--database", required=True, type=Path)
    parser.add_argument("--state-directory", required=True, type=Path)
    parser.add_argument("--beet", default="beet")
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--ffprobe", default="ffprobe")
    parser.add_argument("--unsorted", action="store_true")
    parser.add_argument("--artist")
    parser.add_argument("--title")
    parser.add_argument("--resume", type=Path, metavar="JOB")
    parser.add_argument(
        "--move-after-verification",
        type=Path,
        metavar="WORKING_DIRECTORY",
        help="retire verified originals only inside this explicit working source; retain recovery copies",
    )
    parser.add_argument(
        "--status",
        type=Path,
        metavar="JOB",
        help="show persistent per-source status and file/byte progress",
    )
    parser.add_argument(
        "--retry", type=Path, metavar="JOB", help="retry failed or unidentified sources"
    )
    parser.add_argument(
        "--source",
        dest="select_sources",
        action="append",
        type=Path,
        default=[],
        help="limit retry to an inventoried source path (repeatable)",
    )
    parser.add_argument(
        "--max-units",
        type=int,
        default=25,
        help="maximum album/track groups per invocation (default: 25)",
    )
    parser.add_argument(
        "--bulk",
        action="store_true",
        help="checkpoint a collection in coherent album/track units",
    )
    parser.add_argument(
        "--auto",
        action="store_true",
        help="opt into conservative unattended bulk matching",
    )
    parser.add_argument(
        "--only-singletons",
        action="store_true",
        help="limit existing-job retry/resume/review to loose-track units",
    )
    parser.add_argument(
        "--refresh-evidence",
        action="store_true",
        help="explicitly retry current-policy singleton uncertainty",
    )
    parser.add_argument(
        "--queue",
        type=Path,
        metavar="JOB",
        help="list the review queue without changing it",
    )
    parser.add_argument(
        "--review",
        type=Path,
        metavar="JOB",
        help="review queued bulk units interactively",
    )
    parser.add_argument("sources", nargs="*", type=Path)
    args = parser.parse_args(argv)
    root, database, state = (
        no_symlinks(p) for p in [args.library_root, args.database, args.state_directory]
    )
    operations = [args.resume, args.queue, args.review, args.status, args.retry]
    if args.move_after_verification:
        if any(operations):
            parser.error(
                "move mode must be selected when creating a job; resume retains it"
            )
        if not args.sources:
            args.sources = [args.move_after_verification]
        args.bulk = True
    if sum(bool(value) for value in operations) > 1:
        parser.error(
            "choose one job operation: --resume, --queue, --review, --status, or --retry"
        )
    if args.max_units < 1:
        parser.error("--max-units must be positive")
    if args.select_sources and not args.retry:
        parser.error("--source requires --retry JOB")
    if args.only_singletons and not (args.retry or args.resume or args.review):
        parser.error("--only-singletons requires --retry, --resume, or --review JOB")
    if args.refresh_evidence and not (
        args.retry and args.only_singletons and args.auto
    ):
        parser.error("--refresh-evidence requires --retry JOB --only-singletons --auto")
    if any(operations) and (args.sources or args.unsorted or args.artist or args.title):
        parser.error(
            "job operations cannot be combined with source/identification arguments"
        )
    if not any(operations) and not args.sources:
        parser.error("provide sources or a job operation")
    if args.unsorted and (args.bulk or args.auto):
        parser.error("manual --unsorted identification is separate from bulk mode")
    if args.unsorted != bool(args.artist and args.title) or (
        args.unsorted and len(args.sources) != 1
    ):
        parser.error(
            "manual identification requires --unsorted --artist ARTIST --title TITLE FILE"
        )
    media_checks.FFMPEG, media_checks.FFPROBE = args.ffmpeg, args.ffprobe
    job = None
    try:
        import bulk

        if args.status:
            print(json.dumps(bulk.status_report(no_symlinks(args.status)), indent=2))
            return 0
        if args.queue:
            print(
                json.dumps(
                    {
                        "job": str(args.queue),
                        "review": bulk.queue_entries(no_symlinks(args.queue)),
                    },
                    indent=2,
                )
            )
            return 0
        resumed = load_job(no_symlinks(args.resume)) if args.resume else None
        if resumed and resumed.get("kind") == "bulk-unit":
            args.resume = Path(resumed["parent_job"])
            resumed = load_job(no_symlinks(args.resume))
        if (
            args.bulk
            or args.auto
            or args.review
            or args.retry
            or (not args.unsorted and not args.resume)
            or (resumed and resumed.get("kind") == "bulk")
        ):
            return bulk.run_bulk(args)
        with import_lock(state, str(args.resume or "starting a job")) as lock:
            check_binding(database, root)
            if args.resume:
                job = no_symlinks(args.resume)
                data = load_job(job)
                if data["root"] != str(root) or data["database"] != str(database):
                    raise ValueError(
                        "Resume root/database differs from configured library"
                    )
                if data.get("files"):
                    result = _publish_verified(
                        [file_record(e) for e in data["files"]], root, database, job
                    )
                    print(json.dumps(result, indent=2))
                    return 2 if result["pending"] else 0
                sources = source_records(data)
                approvals = (
                    [Approval(**a) for a in data["approvals"]]
                    if "approvals" in data
                    else job_approvals(job, sources)
                )
            else:
                root.parent.mkdir(parents=True, exist_ok=True)
                created = subprocess.run(
                    ["mktemp", "-d", str(root.parent / ".beets-import.XXXXXXXX")],
                    check=True,
                    capture_output=True,
                    text=True,
                )
                job = Path(created.stdout.strip())
                data = {
                    "version": 1,
                    "job": str(job),
                    "root": str(root),
                    "database": str(database),
                    "state_directory": str(state),
                    "phase": "staging",
                    "sources": [],
                }
                save_json(job / "job.json", data)
                save_json(state / "latest-job.json", {"job": str(job)})
                lock.seek(0)
                lock.truncate()
                lock.write(str(job) + "\n")
                lock.flush()
                print(f"Import job: {job}", flush=True)
                sources = stage_inputs(args.sources, job)
                if not sources:
                    print(f"No supported inputs. Review {job / 'pending-inputs.json'}")
                    return 2
                data["sources"] = [asdict(s) for s in sources]
                data["phase"] = "matching"
                save_json(job / "job.json", data)
                if args.unsorted:
                    if len(sources) != 1:
                        raise ValueError(
                            "Manual identification requires one ordinary song file"
                        )
                    print(
                        f"Confirmed identity: {args.artist} — {args.title}; no verified album/date."
                    )
                    if input("Use this identity? [y/N] ").strip().casefold() != "y":
                        return 2
                    approvals = [
                        Approval(
                            sources[0].sha256,
                            {"artist": args.artist, "title": args.title},
                            None,
                        )
                    ]
                else:
                    approvals = run_matcher(job, sources, args.beet)
                data = load_job(job)
                data["approvals"] = [asdict(a) for a in approvals]
                save_json(job / "job.json", data)
            files = prepare_approved(job, sources, approvals)
            if not files:
                print(f"No verified candidates; pending results retained in {job}")
                return 2
            if not review_publication(files, database, root, job):
                return 2
            result = _publish_verified(files, root, database, job)
            print(json.dumps(result, indent=2))
            return 2 if result["pending"] else 0
    except (ValueError, OSError, sqlite3.Error, subprocess.CalledProcessError) as exc:
        print(f"Import incomplete: {exc}", file=sys.stderr)
        if job:
            print(
                f"Retained job: {job}; use --resume after reviewing the cause.",
                file=sys.stderr,
            )
        return 1
    except (KeyboardInterrupt, EOFError):
        print(f"Import interrupted; copies retained in {job or state}", file=sys.stderr)
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
