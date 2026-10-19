"""Allowlisted investigation records and a crash-recoverable, bounded spool."""

import contextlib
import fcntl
import hashlib
import ipaddress
import json
import math
import os
import re
import shlex
import shutil
import sqlite3
import tempfile
import time
from enum import Enum
from pathlib import Path

VERSION = 1
GIB = 1024**3
MAX_SEGMENT = 16 * 1024**2
MAX_BATCH = 128 * 1024**2
NAME = re.compile(r"[0-9]{20}-[0-9a-f]{64}\.jsonl\Z")
SECURITY_EVENTS = {
    "crowdsec_alert",
    "crowdsec_remediation",
    "crowdsec_remediation_log_drop",
}
JOURNAL_MATCHES = [
    "_SYSTEMD_UNIT=traefik.service",
    "+",
    "_SYSTEMD_UNIT=crowdsec-alert-archive.service",
    "+",
    "_SYSTEMD_UNIT=sshd.service",
    "+",
    "SYSLOG_IDENTIFIER=sshd",
    "+",
    "SYSLOG_IDENTIFIER=sshd-session",
    "+",
    "SYSLOG_IDENTIFIER=sudo",
    "+",
    "SYSLOG_IDENTIFIER=sudo-rs",
    "+",
    "_SYSTEMD_UNIT=tailscaled.service",
    "+",
    "_TRANSPORT=kernel",
]


class ErrorReason(Enum):
    """Only these constant messages and codes may enter failure diagnostics."""

    CURSOR_INVALID = "journal record has no valid cursor"
    SPOOL_ENTRY_INVALID = "unexpected entry in archive spool"
    CHECKPOINT_MISMATCH = "orphaned archive segment does not follow durable checkpoint"
    SEGMENT_INTEGRITY = "archive segment integrity check failed"
    SEGMENT_TOO_LARGE = "archive segment exceeds size limit"
    SNAPSHOT_ID_INVALID = "invalid restic snapshot ID"
    ACKNOWLEDGEMENT_MISMATCH = "archive acknowledgement does not match pending batch"
    ACKNOWLEDGED_NAME_INVALID = "invalid acknowledged archive filename"
    TIMESTAMP_TIMEZONE_MISSING = "timestamps must include a timezone"
    JOURNAL_LINE_TOO_LARGE = "journal line exceeds the bounded reader limit"
    REPOSITORY_ID_MISMATCH = (
        "archive repository ID differs from the provisioned repository"
    )
    SEALED_METADATA_CHANGED = "sealed archive metadata changed"
    HEARTBEAT_URL_INVALID = "invalid Healthchecks success URL"
    UPLOAD_SNAPSHOT_UNVERIFIED = "uploaded snapshot could not be verified"
    UPLOAD_MANIFEST_MISMATCH = "uploaded archive manifest differs from the sealed batch"
    SNAPSHOT_PROFILE_INVALID = (
        "unexpected snapshot profile in dedicated archive repository"
    )
    SNAPSHOT_TIME_FUTURE = "future snapshot timestamp requires manual investigation"
    ARCHIVE_SNAPSHOT_ID_INVALID = "invalid archive snapshot ID"
    RESTORE_MANIFEST_MISSING = "restored snapshot has no archive manifest"
    RESTORE_MANIFEST_NOT_REGULAR = "restored manifest must be a regular file"
    RESTORE_MANIFEST_UNSUPPORTED = "unsupported archive manifest"
    RESTORE_SEGMENTS_NOT_DIRECTORY = (
        "restored segment directory must be a real directory"
    )
    RESTORE_SEGMENT_NAME_INVALID = "invalid restored segment name"
    RESTORE_SEGMENT_NOT_REGULAR = "restored segment must be a regular file"
    RESTORE_SEGMENT_MISMATCH = "restored manifest and segment differ"
    RESTORE_RECORD_CONFLICT = (
        "conflicting records share an event ID; recover known-good snapshot IDs"
    )
    RECOVERY_TARGET_NOT_EMPTY = "recovery target must be empty"
    RECOVERY_INTERVAL_REVERSED = "recovery interval is reversed"
    RECOVERY_SNAPSHOT_ID_INVALID = "recovery snapshot IDs must be full hexadecimal IDs"
    RECOVERY_SNAPSHOT_MISSING = "requested recovery snapshot was not found"
    SNAPSHOT_RANGE_MISSING = "snapshot is missing the archive event-range contract"
    RECOVERY_ID_INVALID = "invalid recovery snapshot ID"
    RETENTION_UPLOADS_ACTIVE = (
        "pause uploads and wait for active uploads before applying retention"
    )
    RETENTION_PLAN_STALE = (
        "retention preview is stale or does not match this repository"
    )
    RETENTION_SNAPSHOT_PROTECTED = "retention preview contains a protected snapshot"
    RETENTION_WOULD_EMPTY = "refusing to remove every archive snapshot"
    BACKEND_FAILED = "archive backend returned a failure status"
    BACKEND_TIMEOUT = "archive backend exceeded its operation timeout"
    BACKEND_UNAVAILABLE = "archive backend could not be started"
    BACKEND_RESPONSE_INVALID = "archive backend returned invalid JSON"


class ArchiveError(ValueError):
    def __init__(self, reason, operation=None, exit_status=None):
        if not isinstance(reason, ErrorReason):
            raise TypeError("unsupported archive failure reason")
        super().__init__(reason.value)
        self.reason = reason
        self.operation = operation
        self.exit_status = exit_status


def encoded(value):
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sync_dir(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def atomic_write(path, data, mode=0o660):
    path = Path(path)
    fd, temporary_name = tempfile.mkstemp(
        prefix=path.name + ".", suffix=".tmp", dir=path.parent
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(fd, "wb") as stream:
            os.fchmod(stream.fileno(), mode)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        sync_dir(path.parent)
    finally:
        temporary.unlink(missing_ok=True)


def normalize(entry, host):
    """Unknown messages retain metadata only, never an unfiltered MESSAGE."""
    cursor = entry.get("__CURSOR")
    if not isinstance(cursor, str) or not cursor or len(cursor) > 4096:
        raise ArchiveError(ErrorReason.CURSOR_INVALID)
    record = {
        "version": VERSION,
        "host": host,
        "cursor": cursor,
        "id": digest(encoded([host, cursor])),
        "source": "unparsed",
        "event": "unparsed",
        "data": {},
    }
    unsupported = False
    for key, field, limit in (
        ("boot_id", "_BOOT_ID", 128),
        ("journal_time_us", "__REALTIME_TIMESTAMP", 32),
        ("uid", "_UID", 16),
        ("pid", "_PID", 16),
        ("unit", "_SYSTEMD_UNIT", 256),
    ):
        value = entry.get(field, "")
        if isinstance(value, str):
            record[key] = value[:limit]
        else:
            record[key] = ""
            unsupported = True

    message = entry.get("MESSAGE", "")
    identifier = entry.get("SYSLOG_IDENTIFIER", "")
    transport = entry.get("_TRANSPORT", "")
    # journalctl JSON can represent repeated/binary fields as arrays. Keep
    # selected unsupported shapes visible without interpreting or copying them.
    if unsupported or not all(
        isinstance(value, str) for value in (message, identifier, transport)
    ):
        return record
    data, truncated = record["data"], []

    def text(key, value, limit=4096, uri=False):
        if not isinstance(value, str):
            return
        if uri:
            value = value.split("?", 1)[0].split("#", 1)[0]
        if len(value) > limit:
            truncated.append(key)
        data[key] = value[:limit]

    def fields(values, strings, numbers=()):
        for key in strings:
            text(key, values.get(key))
        for key in numbers:
            value = values.get(key)
            if (
                isinstance(value, (int, float))
                and not isinstance(value, bool)
                and math.isfinite(value)
            ):
                data[key] = value

    unit = record["unit"]
    if unit in {"traefik.service", "crowdsec-alert-archive.service"}:
        try:
            event = json.loads(message)
        except (ValueError, RecursionError):
            return record
        if not isinstance(event, dict):
            return record
        if "event" in event and not isinstance(event["event"], str):
            return record
        if event.get("event") in SECURITY_EVENTS:
            record.update(source="crowdsec", event=event["event"])
            fields(
                event,
                [
                    "kind",
                    "source_ip",
                    "origin",
                    "scenario",
                    "target_host",
                    "country",
                    "asn",
                    "as_name",
                    "time",
                    "http_method",
                    "http_status",
                    "remediation",
                    "user_agent",
                ],
                ["alert_id", "decision_id", "events_count", "dropped", "count"],
            )
            # The alert archiver emits a string; the bouncer emits an integer.
            status = event.get("http_status")
            if isinstance(status, int) and not isinstance(status, bool):
                data["http_status"] = status
            if isinstance(event.get("simulated"), bool):
                data["simulated"] = event["simulated"]
            paths = event.get("target_uri", [])
            if isinstance(paths, str):
                paths = [paths]
            if isinstance(paths, list):
                data["target_uri"] = [
                    p.split("?", 1)[0].split("#", 1)[0][:4096]
                    for p in paths[:50]
                    if isinstance(p, str)
                ]
        elif unit == "traefik.service" and "ClientHost" in event:
            record.update(source="http", event="http_access")
            fields(
                event,
                [
                    "ClientAddr",
                    "ClientHost",
                    "RequestHost",
                    "RequestMethod",
                    "RequestProtocol",
                    "RouterName",
                ],
                [
                    "DownstreamStatus",
                    "DownstreamContentSize",
                    "Duration",
                    "OriginStatus",
                ],
            )
            text("RequestPath", event.get("RequestPath"), uri=True)
            text("User-Agent", event.get("request_User-Agent"), 1024)
    elif unit == "sshd.service" or identifier in {"sshd", "sshd-session"}:
        record.update(source="ssh", event="ssh_other")
        match = re.search(
            r"(Accepted|Failed) (\S+) for (?:invalid user )?(\S+) from (\S+) port (\d+)",
            message,
        )
        if match:
            result, method, user, address, port = match.groups()
            record["event"] = "ssh_" + result.lower()
            text("method", method, 64)
            text("user", user, 256)
            try:
                data["source_ip"] = str(ipaddress.ip_address(address))
                data["source_port"] = int(port)
            except ValueError:
                pass
    elif identifier in {"sudo", "sudo-rs"}:
        record.update(source="sudo", event="sudo_activity")
        for key in ("USER", "TTY"):
            match = re.search(r"(?:^|[; ])" + key + r"=([^;\s]+)", message)
            if match:
                text(key.lower(), match[1], 256)
        actor = re.match(r"\s*([\w.-]+)\s*:", message)
        if actor:
            text("actor", actor[1], 256)
        command = re.search(r"(?:^|[; ])COMMAND=(.*)", message)
        if command:
            try:
                executable = shlex.split(command[1])[0]
                if re.fullmatch(r"/[\w./+@:-]+", executable):
                    text("executable", executable)
            except (ValueError, IndexError):
                pass
        if "session opened" in message:
            record["event"] = "sudo_session_opened"
        elif "session closed" in message:
            record["event"] = "sudo_session_closed"
    elif unit == "tailscaled.service":
        if "ssh-conn-" not in message:
            return None
        record.update(source="ssh", event="tailscale_ssh")
        # Tailscale's free-form logs are not a stable authentication schema.
        # Preserve trusted journal metadata; never archive URLs or raw messages.
    elif transport == "kernel":
        if 'apparmor="DENIED"' in message:
            record.update(source="kernel", event="apparmor_denied")
            allowed = {
                "operation",
                "profile",
                "name",
                "comm",
                "requested_mask",
                "denied_mask",
                "pid",
                "uid",
                "fsuid",
                "error",
            }
        elif re.search(r"microvm-policy (?:audit|[a-z-]+): ", message):
            record.update(source="kernel", event="microvm_policy")
            text("action", re.search(r"microvm-policy ([a-z-]+):", message)[1], 64)
            allowed = {
                "IN",
                "OUT",
                "SRC",
                "DST",
                "PROTO",
                "SPT",
                "DPT",
                "LEN",
                "UID",
                "GID",
            }
        else:
            return None
        for key, quoted, plain in re.findall(r'(\w+)=(?:"([^"\n]*)"|(\S+))', message):
            if key in allowed:
                text(key, quoted or plain)
    else:
        return None
    if truncated:
        record["truncated_fields"] = truncated
    return record


class BufferFull(Exception):
    pass


class Spool:
    """Seal before checkpoint; recover an orphaned seal after a crash.

    SQLite contains only state and batch metadata. Payloads are immutable JSONL
    files. A remote acknowledgement commits before local garbage collection.
    """

    def __init__(self, root, max_bytes=20 * GIB, min_free=5 * GIB, host="blizzard"):
        self.root = Path(root)
        self.ready = self.root / "ready"
        self.ready.mkdir(parents=True, exist_ok=True)
        self.max_bytes, self.min_free, self.host = max_bytes, min_free, host
        self.db_path = self.root / "state.sqlite"
        with self.locked() as db:
            db.execute(
                "CREATE TABLE IF NOT EXISTS state (key TEXT PRIMARY KEY, value TEXT NOT NULL)"
            )
            db.execute(
                "CREATE TABLE IF NOT EXISTS batches (name TEXT PRIMARY KEY, header TEXT NOT NULL, ack TEXT)"
            )
            db.commit()
            self.recover(db)

    @contextlib.contextmanager
    def locked(self):
        with (self.root / "spool.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            db = sqlite3.connect(self.db_path, timeout=10)
            # SQLite creates databases with 0644 before umask, so umask alone
            # does not grant the separate uploader account group write access.
            if self.db_path.stat().st_mode & 0o777 != 0o660:
                os.chmod(self.db_path, 0o660)
            db.execute("PRAGMA synchronous=FULL")
            try:
                yield db
            finally:
                db.close()

    @staticmethod
    def get(db, key, default=None):
        row = db.execute("SELECT value FROM state WHERE key=?", (key,)).fetchone()
        return json.loads(row[0]) if row else default

    @staticmethod
    def put(db, key, value):
        db.execute(
            "INSERT OR REPLACE INTO state VALUES (?,?)", (key, json.dumps(value))
        )

    def state(self):
        with self.locked() as db:
            return {
                k: json.loads(v) for k, v in db.execute("SELECT key,value FROM state")
            }

    def recover(self, db):
        known = {r[0] for r in db.execute("SELECT name FROM batches")}
        for path in sorted(self.ready.iterdir()):
            if path.name.endswith(".tmp"):
                path.unlink()
                continue
            if not NAME.fullmatch(path.name) or path.is_symlink() or not path.is_file():
                raise ArchiveError(ErrorReason.SPOOL_ENTRY_INVALID)
            if path.name not in known:
                header = self.read_segment(path)[0]
                if header["sequence"] != self.get(db, "sequence", 0) + 1 or header[
                    "previous_cursor"
                ] != self.get(db, "cursor"):
                    raise ArchiveError(ErrorReason.CHECKPOINT_MISMATCH)
                self.register(db, path.name, header)
                db.commit()
        self.gc(db)

    @staticmethod
    def read_segment(path):
        with Path(path).open("rb") as stream:
            header = json.loads(stream.readline(65537))
            payload = stream.read(MAX_SEGMENT + 1)
        if len(payload) > MAX_SEGMENT or header.get("payload_sha256") != digest(
            payload
        ):
            raise ArchiveError(ErrorReason.SEGMENT_INTEGRITY)
        return header, payload

    def register(self, db, name, header):
        db.execute("INSERT INTO batches VALUES (?,?,NULL)", (name, json.dumps(header)))
        self.put(db, "sequence", header["sequence"])
        self.put(db, "cursor", header["cursor"])
        self.put(db, "last_collect", header["sealed_at"])
        self.put(db, "paused", False)
        for key, delta in header["counters"].items():
            self.put(db, key, self.get(db, key, 0) + delta)
        if header["counters"]["gaps"] or header["counters"]["upstream_loss_reports"]:
            self.put(db, "last_loss", header["sealed_at"])

    def append(self, records, cursor, now=None, gap=False):
        now = time.time() if now is None else now
        payload = b"".join(encoded(r) + b"\n" for r in records)
        if len(payload) > MAX_SEGMENT:
            raise ArchiveError(ErrorReason.SEGMENT_TOO_LARGE)
        with self.locked() as db:
            self.recover(db)
            size = sum(p.stat().st_size for p in self.ready.iterdir())
            size += sum(p.stat().st_size for p in self.root.iterdir() if p.is_file())
            # Reserve staging, metadata, SQLite rollback journal, and one seal.
            reserve = MAX_BATCH + 4 * 1024**2
            if (
                size + len(payload) + reserve + 65536 > self.max_bytes
                or shutil.disk_usage(self.root).free
                < self.min_free + len(payload) + 65536
            ):
                self.put(db, "paused", True)
                db.commit()
                raise BufferFull("archive buffer or free-space reserve exhausted")
            sequence = self.get(db, "sequence", 0) + 1
            header = {
                "version": VERSION,
                "host": self.host,
                "sequence": sequence,
                "previous_cursor": self.get(db, "cursor"),
                "cursor": cursor,
                "sealed_at": now,
                "payload_sha256": digest(payload),
                "records": len(records),
                "bytes": len(payload),
                "counters": {
                    "gaps": int(gap),
                    "unparsed": sum(r.get("source") == "unparsed" for r in records),
                    "upstream_loss_reports": sum(
                        r.get("event") == "crowdsec_remediation_log_drop"
                        for r in records
                    ),
                },
            }
            name = f"{sequence:020d}-{digest(encoded(header) + payload)}.jsonl"
            atomic_write(self.ready / name, encoded(header) + b"\n" + payload)
            self.register(db, name, header)
            db.commit()
            return name

    def pending(self, limit=MAX_BATCH):
        with self.locked() as db:
            self.recover(db)
            rows = [
                (name, json.loads(header))
                for name, header in db.execute(
                    "SELECT name,header FROM batches WHERE ack IS NULL ORDER BY name"
                )
            ]
        if not rows:
            return []
        # Reserve a current segment first so catch-up does not starve freshness.
        ordered = [rows[-1], *rows[:-1]]
        result, size = [], 0
        for name, header in ordered:
            file_size = (self.ready / name).stat().st_size
            if size + file_size <= limit:
                result.append((name, header))
                size += file_size
        return sorted(result)

    def acknowledge(self, batches, snapshot, now=None):
        if not re.fullmatch(r"[0-9a-f]{64}", snapshot):
            raise ArchiveError(ErrorReason.SNAPSHOT_ID_INVALID)
        with self.locked() as db:
            for name, header in batches:
                row = db.execute(
                    "SELECT header FROM batches WHERE name=? AND ack IS NULL", (name,)
                ).fetchone()
                if row is None or json.loads(row[0]) != header:
                    raise ArchiveError(ErrorReason.ACKNOWLEDGEMENT_MISMATCH)
                db.execute("UPDATE batches SET ack=? WHERE name=?", (snapshot, name))
            self.put(db, "last_upload", time.time() if now is None else now)
            self.put(
                db, "last_uploaded_watermark", max(h["sealed_at"] for _, h in batches)
            )
            self.put(db, "parent_snapshot", snapshot)
            db.commit()
            self.gc(db)

    def gc(self, db):
        rows = db.execute("SELECT name FROM batches WHERE ack IS NOT NULL").fetchall()
        for (name,) in rows:
            if not NAME.fullmatch(name):
                raise ArchiveError(ErrorReason.ACKNOWLEDGED_NAME_INVALID)
            (self.ready / name).unlink(missing_ok=True)
        sync_dir(self.ready)
        db.execute("DELETE FROM batches WHERE ack IS NOT NULL")
        db.commit()

    def metric_values(self, now=None):
        now = time.time() if now is None else now
        with self.locked() as db:
            state = {
                key: json.loads(value)
                for key, value in db.execute("SELECT key,value FROM state")
            }
            headers = [
                json.loads(row[0])
                for row in db.execute("SELECT header FROM batches WHERE ack IS NULL")
            ]
            # Garbage collection removes files under the same lock. Measure
            # while holding it so a concurrent acknowledgement cannot race stat.
            buffer_bytes = sum(
                path.stat().st_size
                for path in self.ready.iterdir()
                if NAME.fullmatch(path.name)
            )
        return {
            "collector_timestamp_seconds": state.get("last_collect", 0),
            "upload_timestamp_seconds": state.get("last_upload", 0),
            "uploaded_watermark_seconds": state.get("last_uploaded_watermark", 0),
            "buffer_bytes": buffer_bytes,
            "buffer_limit_bytes": self.max_bytes,
            "oldest_pending_age_seconds": max(
                0, now - min(h["sealed_at"] for h in headers)
            )
            if headers
            else 0,
            "paused": int(state.get("paused", False)),
            "gaps_total": state.get("gaps", 0),
            "loss_timestamp_seconds": state.get("last_loss", 0),
            "unparsed_total": state.get("unparsed", 0),
            "upstream_loss_reports_total": state.get("upstream_loss_reports", 0),
            "upload_failures_total": state.get("upload_failures", 0),
            "heartbeat_failures_total": state.get("heartbeat_failures", 0),
        }

    def count(self, key):
        with self.locked() as db:
            self.put(db, key, self.get(db, key, 0) + 1)
            db.commit()
