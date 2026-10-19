"""Journal collection, append-only uploads, and independent archive recovery."""

import argparse
import fcntl
import json
import os
import re
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import urllib.request
from datetime import datetime
from pathlib import Path

from model import (
    JOURNAL_MATCHES,
    MAX_SEGMENT,
    NAME,
    VERSION,
    BufferFull,
    Spool,
    atomic_write,
    digest,
    encoded,
    normalize,
)

PROFILE = "security-log-archive-v1"
YEAR = 365 * 86400


def timestamp(value):
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("timestamps must include a timezone")
    return parsed.timestamp()


def credential(cfg, name):
    directory = os.environ.get("CREDENTIALS_DIRECTORY")
    if directory:
        return str(Path(directory) / name)
    return cfg["credentials"][name]


def spool_for(cfg):
    return Spool(
        cfg["state_dir"], cfg["buffer_bytes"], cfg["min_free_bytes"], cfg["host"]
    )


def write_metrics(cfg, spool):
    if cfg.get("metrics_file"):
        data = "".join(
            f"security_log_archive_{key} {value}\n"
            for key, value in spool.metric_values().items()
        )
        atomic_write(cfg["metrics_file"], data.encode(), 0o644)


def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def collect(cfg):
    spool = spool_for(cfg)
    stopping = False

    def finish(*_):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, finish)
    signal.signal(signal.SIGINT, finish)
    replay_all = False
    while not stopping:
        saved = spool.state().get("cursor")
        args = [
            "journalctl",
            "--output=json",
            "--all",
            "--no-pager",
            "--follow",
            "--no-tail",
            "--output-fields=__CURSOR,__REALTIME_TIMESTAMP,_BOOT_ID,_UID,_PID,_SYSTEMD_UNIT,SYSLOG_IDENTIFIER,_TRANSPORT,MESSAGE",
        ]
        if saved:
            args.append("--cursor=" + saved)
        elif not replay_all:
            args.append("--since=-24h")
        args += JOURNAL_MATCHES
        process = subprocess.Popen(args, stdout=subprocess.PIPE)
        cursor, records, length = saved, [], 0
        first, lost = True, False
        last_seal = time.monotonic()
        pending = b""

        def seal(last_cursor):
            nonlocal records, length, last_seal
            now = time.time()
            watermark = {
                "version": VERSION,
                "host": cfg["host"],
                "source": "archive",
                "event": "archive_watermark",
                "id": digest(encoded([cfg["host"], "watermark", now])),
                "journal_time_us": str(int(now * 1e6)),
                "data": {},
            }
            spool.append([*records, watermark], last_cursor, now)
            records, length, last_seal = [], 0, time.monotonic()
            write_metrics(cfg, spool)

        try:
            while not stopping:
                readable, _, _ = select.select([process.stdout], [], [], 1)
                if readable:
                    chunk = os.read(process.stdout.fileno(), 65536)
                    if not chunk:
                        if first and saved:
                            # journalctl exits before producing a record when
                            # the saved cursor can no longer be sought.
                            lost = True
                        else:
                            raise RuntimeError("journal reader stopped")
                    pending += chunk
                    if len(pending) > 32 * 1024**2:
                        raise ValueError(
                            "journal line exceeds the bounded reader limit"
                        )
                    while b"\n" in pending:
                        line, pending = pending.split(b"\n", 1)
                        entry = json.loads(line)
                        entry_cursor = entry.get("__CURSOR")
                        if first and saved:
                            first = False
                            if entry_cursor != saved:
                                lost = True
                                break
                            continue
                        first = False
                        record = normalize(entry, cfg["host"])
                        if record is not None:
                            size = len(encoded(record)) + 1
                            if length + size > MAX_SEGMENT - 65536:
                                seal(cursor)
                            records.append(record)
                            length += size
                        # Advance ignored, selected journal entries too, but only
                        # persist this cursor together with a durable seal.
                        cursor = entry_cursor
                    if lost:
                        gap = {
                            "version": VERSION,
                            "host": cfg["host"],
                            "source": "archive",
                            "event": "archive_gap",
                            "id": digest(encoded([saved, time.time()])),
                            "journal_time_us": str(int(time.time() * 1e6)),
                            "data": {
                                "reason": "journal_cursor_unavailable",
                                "previous_cursor": saved,
                            },
                        }
                        spool.append([gap], None, gap=True)
                        replay_all = True
                        write_metrics(cfg, spool)
                        break
                if time.monotonic() - last_seal >= cfg.get("seal_seconds", 30):
                    if process.poll() is not None:
                        raise RuntimeError("journal reader stopped")
                    seal(cursor)
            if records and not lost:
                seal(cursor)
        except BufferFull:
            # The durable cursor did not advance. Replay memory-only records
            # after space returns; source services never wait for this process.
            write_metrics(cfg, spool)
            time.sleep(5)
        finally:
            stop(process)


class Restic:
    def __init__(self, cfg, admin=False):
        self.cfg = cfg
        self.base = [
            "restic",
            "--cache-dir",
            str(Path(cfg["staging_dir"]) / "cache"),
            "--repo",
            cfg["admin_repository"] if admin else cfg["repository"],
            "--password-file",
            credential(cfg, "password"),
        ]
        options = cfg.get("admin_options" if admin else "upload_options", {})
        for key, value in options.items():
            self.base += ["-o", key + "=" + value]

    def run(self, *args, json_result=False, timeout=None):
        result = subprocess.run(
            [*self.base, *args],
            check=True,
            capture_output=True,
            stdin=subprocess.DEVNULL,
            timeout=timeout,
        )
        return json.loads(result.stdout) if json_result else result.stdout

    def identity(self):
        repository = self.run("cat", "config", json_result=True)
        if repository.get("id") != self.cfg["repository_id"]:
            raise ValueError(
                "archive repository ID differs from the provisioned repository"
            )


def event_time(record):
    try:
        return int(record["journal_time_us"]) / 1e6
    except (KeyError, TypeError, ValueError):
        return 0


def stage_batch(spool, batches, target, cfg):
    target = Path(target)
    target.mkdir(mode=0o700, parents=True, exist_ok=True)
    segments = target / "segments"
    segments.mkdir(mode=0o700)
    times, manifests = [], []
    for name, expected in batches:
        header, payload = spool.read_segment(spool.ready / name)
        if header != expected:
            raise ValueError("sealed archive metadata changed")
        for line in payload.splitlines():
            value = event_time(json.loads(line))
            if value > 0:
                times.append(value)
        shutil.copyfile(spool.ready / name, segments / name)
        manifests.append({"name": name, "header": header})
    manifest = {
        "version": VERSION,
        "profile": PROFILE,
        "host": cfg["host"],
        "segments": manifests,
        "event_start": min(times, default=0),
        "event_end": max(times, default=0),
        "provenance": cfg.get("provenance", {}),
    }
    atomic_write(target / "manifest.json", encoded(manifest) + b"\n", 0o600)
    return manifest


def heartbeat(cfg):
    url = Path(credential(cfg, "heartbeat-url")).read_text().strip()
    if not re.fullmatch(r"https://hc-ping\.com/[0-9a-f-]{36}", url):
        raise ValueError("invalid Healthchecks success URL")
    request = urllib.request.Request(url, data=b"", method="POST")
    with urllib.request.urlopen(request, timeout=10) as response:
        # Healthchecks can return HTTP 200 for unknown or rate-limited UUIDs.
        if response.status != 200 or response.read(64).strip() != b"OK":
            raise RuntimeError("heartbeat was not accepted")


def upload(cfg, restic=None):
    spool = spool_for(cfg)
    root = Path(cfg["staging_dir"])
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (root / "upload.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        batches = spool.pending()
        if not batches:
            write_metrics(cfg, spool)
            return
        staging = root / "batch"
        if staging.exists():
            shutil.rmtree(staging)
        try:
            manifest = stage_batch(spool, batches, staging, cfg)
            client = restic or Restic(cfg)
            client.identity()
            args = [
                "backup",
                "--json",
                "--host",
                cfg["host"],
                "--tag",
                PROFILE,
                "--tag",
                f"event-start:{manifest['event_start']}",
                "--tag",
                f"event-end:{manifest['event_end']}",
            ]
            parent = spool.state().get("parent_snapshot")
            if parent:
                args += ["--parent", parent]
            else:
                args += ["--force"]
            output = client.run(*args, str(staging), timeout=50)
            summaries = [json.loads(line) for line in output.splitlines()]
            summary = next(
                item
                for item in reversed(summaries)
                if item.get("message_type") == "summary"
            )
            snapshot = summary["snapshot_id"]
            snapshots = client.run(
                "snapshots", "--json", snapshot, json_result=True, timeout=10
            )
            if len(snapshots) != 1 or snapshots[0]["id"] != snapshot:
                raise ValueError("uploaded snapshot could not be verified")
            remote_manifest = client.run(
                "dump", snapshot, str(staging / "manifest.json"), timeout=10
            )
            if json.loads(remote_manifest) != manifest:
                raise ValueError(
                    "uploaded archive manifest differs from the sealed batch"
                )
            spool.acknowledge(batches, snapshot)
        except Exception:
            spool.count("upload_failures")
            write_metrics(cfg, spool)
            raise
        finally:
            shutil.rmtree(staging, ignore_errors=True)
        state = spool.state()
        if (
            time.time() - state.get("last_uploaded_watermark", 0) < 300
            and time.time() - state.get("last_collect", 0) < 90
            and not state.get("paused", False)
        ):
            try:
                heartbeat(cfg)
            except (OSError, ValueError, RuntimeError):
                spool.count("heartbeat_failures")
                # The archive is already committed. A failed heartbeat never
                # invalidates that receipt or causes another copy of the data.
                print("Archive committed; external heartbeat failed", file=sys.stderr)
        write_metrics(cfg, spool)


def retention_candidates(snapshots, host, now):
    result = []
    for snapshot in snapshots:
        if snapshot.get("hostname") != host or PROFILE not in snapshot.get("tags", []):
            raise ValueError(
                "unexpected snapshot profile in dedicated archive repository"
            )
        created = timestamp(snapshot["time"])
        if created > now + 300:
            raise ValueError("future snapshot timestamp requires manual investigation")
        identity = snapshot["id"]
        if not re.fullmatch(r"[0-9a-f]{64}", identity):
            raise ValueError("invalid archive snapshot ID")
        if created < now - YEAR:
            result.append(identity)
    return sorted(result)


def verify_tree(root, output, since=0, until=float("inf"), seen=None):
    """Verify restored segment hashes and export stable-ID-deduplicated records."""
    import sqlite3

    database = sqlite3.connect(seen or ":memory:")
    database.execute(
        "CREATE TABLE IF NOT EXISTS records (id TEXT PRIMARY KEY, sha256 TEXT NOT NULL)"
    )
    try:
        manifests = list(Path(root).rglob("manifest.json"))
        if not manifests:
            raise ValueError("restored snapshot has no archive manifest")
        for path in manifests:
            if path.is_symlink() or not path.is_file():
                raise ValueError("restored manifest must be a regular file")
            manifest = json.loads(path.read_bytes())
            if manifest.get("version") != VERSION or manifest.get("profile") != PROFILE:
                raise ValueError("unsupported archive manifest")
            segments = path.parent / "segments"
            if segments.is_symlink() or not segments.is_dir():
                raise ValueError("restored segment directory must be a real directory")
            for segment in manifest["segments"]:
                name = segment["name"]
                if not NAME.fullmatch(name):
                    raise ValueError("invalid restored segment name")
                file = segments / name
                if file.is_symlink() or not file.is_file():
                    raise ValueError("restored segment must be a regular file")
                header, payload = Spool.read_segment(file)
                if header != segment["header"]:
                    raise ValueError("restored manifest and segment differ")
                for line in payload.splitlines():
                    record = json.loads(line)
                    if since <= event_time(record) <= until:
                        content = encoded(record)
                        checksum = digest(content)
                        previous = database.execute(
                            "SELECT sha256 FROM records WHERE id=?", (record["id"],)
                        ).fetchone()
                        if previous and previous[0] != checksum:
                            raise ValueError(
                                "conflicting records share an event ID; recover known-good snapshot IDs"
                            )
                        if previous is None:
                            database.execute(
                                "INSERT INTO records VALUES (?,?)",
                                (record["id"], checksum),
                            )
                            output.write(content + b"\n")
                database.commit()
    finally:
        database.close()


def restore(cfg, client, args):
    target = Path(args.target).resolve()
    if target.exists() and any(target.iterdir()):
        raise ValueError("recovery target must be empty")
    target.mkdir(mode=0o700, parents=True, exist_ok=True)
    since, until = timestamp(args.since), timestamp(args.until)
    if since > until:
        raise ValueError("recovery interval is reversed")
    snapshots = client.run("snapshots", "--json", json_result=True)
    selected = set(getattr(args, "snapshot", None) or [])
    if any(not re.fullmatch(r"[0-9a-f]{64}", item) for item in selected):
        raise ValueError("recovery snapshot IDs must be full hexadecimal IDs")
    if selected - {snapshot["id"] for snapshot in snapshots}:
        raise ValueError("requested recovery snapshot was not found")
    with (target / "events.jsonl.partial").open("wb") as output:
        for snapshot in snapshots:
            if selected and snapshot["id"] not in selected:
                continue
            tags = snapshot.get("tags", [])
            start = next(
                (float(t[12:]) for t in tags if t.startswith("event-start:")), None
            )
            end = next(
                (float(t[10:]) for t in tags if t.startswith("event-end:")), None
            )
            if (
                start is None
                or end is None
                or snapshot.get("hostname") != cfg["host"]
                or PROFILE not in tags
            ):
                raise ValueError("snapshot is missing the archive event-range contract")
            if start > until or end < since:
                continue
            identity = snapshot["id"]
            if not re.fullmatch(r"[0-9a-f]{64}", identity):
                raise ValueError("invalid recovery snapshot ID")
            directory = target / identity
            client.run("restore", identity, "--verify", "--target", str(directory))
            verify_tree(directory, output, since, until, target / "seen.sqlite")
            output.flush()
            os.fsync(output.fileno())
    os.replace(target / "events.jsonl.partial", target / "events.jsonl")
    print(f"Verified records exported to {target / 'events.jsonl'}")


def admin(cfg, args):
    client = Restic(cfg, admin=True)
    client.identity()
    if args.action == "inspect":
        print(client.run("stats", "--mode", "raw-data", "--json").decode())
    elif args.action == "restore":
        restore(cfg, client, args)
    elif args.action == "retention-preview":
        now = time.time()
        snapshots = client.run("snapshots", "--json", json_result=True)
        plan = {
            "version": VERSION,
            "repository_id": cfg["repository_id"],
            "generated_at": now,
            "cutoff": now - YEAR,
            "snapshot_ids": retention_candidates(snapshots, cfg["host"], now),
        }
        atomic_write(args.plan, encoded(plan) + b"\n", 0o600)
        print(
            f"Preview contains {len(plan['snapshot_ids'])} expired snapshots; no records deleted"
        )
    elif args.action == "retention-apply":
        if not args.uploads_paused:
            raise ValueError(
                "pause uploads and wait for active uploads before applying retention"
            )
        plan = json.loads(Path(args.plan).read_bytes())
        now = time.time()
        if (
            plan.get("version") != VERSION
            or plan.get("repository_id") != cfg["repository_id"]
            or not 0 <= now - plan["generated_at"] <= 900
            or plan["cutoff"] > now - YEAR
        ):
            raise ValueError(
                "retention preview is stale or does not match this repository"
            )
        snapshots = client.run("snapshots", "--json", json_result=True)
        eligible = set(
            retention_candidates(snapshots, cfg["host"], plan["generated_at"])
        )
        identities = plan["snapshot_ids"]
        if not set(identities) <= eligible:
            raise ValueError("retention preview contains a protected snapshot")
        client.run("check", "--read-data")
        remaining = [s for s in snapshots if s["id"] not in identities]
        if not remaining:
            raise ValueError("refusing to remove every archive snapshot")
        # Exercise an independent restore before any destructive command.
        with tempfile.TemporaryDirectory(
            prefix="security-archive-restore-"
        ) as directory:
            sample = min(remaining, key=lambda s: timestamp(s["time"]))
            client.run("restore", sample["id"], "--verify", "--target", directory)
            with open(os.devnull, "wb") as output:
                verify_tree(directory, output)
        for offset in range(0, len(identities), 100):
            client.run("forget", *identities[offset : offset + 100])
        if identities:
            after = client.run("snapshots", "--json", json_result=True)
            if set(identities) & {snapshot["id"] for snapshot in after}:
                raise RuntimeError(
                    "expired snapshots remain after the forget operation"
                )
            client.run("prune")


def size(cfg, args):
    command = [
        "journalctl",
        "--output=json",
        "--all",
        "--no-pager",
        "--since=" + args.since,
        *JOURNAL_MATCHES,
    ]
    process = subprocess.Popen(command, stdout=subprocess.PIPE)
    counts, byte_counts = {}, {}
    try:
        for line in process.stdout:
            record = normalize(json.loads(line), cfg["host"])
            if record:
                source = record["source"]
                counts[source] = counts.get(source, 0) + 1
                byte_counts[source] = (
                    byte_counts.get(source, 0) + len(encoded(record)) + 1
                )
        if process.wait() != 0:
            raise RuntimeError("journal sizing read failed")
    finally:
        stop(process)
    print(
        json.dumps(
            {
                "records": counts,
                "normalized_bytes": byte_counts,
                "snapshot_count_per_year": 262800,
            }
        )
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True)
    sub = parser.add_subparsers(dest="action", required=True)
    for action in ("collect", "upload", "inspect"):
        sub.add_parser(action)
    sizing = sub.add_parser("size")
    sizing.add_argument("--since", default="24 hours ago")
    recovery = sub.add_parser("restore")
    recovery.add_argument("--since", required=True)
    recovery.add_argument("--until", required=True)
    recovery.add_argument("--target", required=True)
    recovery.add_argument(
        "--snapshot",
        action="append",
        help="Full known-good snapshot ID; repeat to bypass unrelated malformed snapshots",
    )
    for action in ("retention-preview", "retention-apply"):
        maintenance = sub.add_parser(action)
        maintenance.add_argument("--plan", required=True)
        if action == "retention-apply":
            maintenance.add_argument("--uploads-paused", action="store_true")
    args = parser.parse_args()
    cfg = json.loads(Path(args.config).read_bytes())
    try:
        if args.action == "collect":
            collect(cfg)
        elif args.action == "upload":
            upload(cfg)
        elif args.action == "size":
            size(cfg, args)
        else:
            admin(cfg, args)
    except Exception as error:  # noqa: BLE001 - Never log raw command or credential errors.
        # Command stderr can contain private paths, URLs, or server responses.
        # Keep payloads and credential values out of the service journal.
        print(
            f"Security-log archive failed ({type(error).__name__}); inspect state and the runbook",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
