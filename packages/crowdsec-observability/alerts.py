"""Archive bounded, allowlisted local alert metadata."""

import json
import sqlite3
import subprocess
import sys
import time
from contextlib import closing
from datetime import datetime

MAX_ALERTS_PER_QUERY = 500
MAX_LOOKBACK_SECONDS = 24 * 60 * 60
OVERLAP_SECONDS = 5 * 60
SEEN_RETENTION_SECONDS = 31 * 24 * 60 * 60


def normalize(alert):
    source = alert.get("source") or {}
    if not isinstance(source, dict):
        source = {}
    metadata = alert.get("meta") or []
    if not isinstance(metadata, list):
        metadata = []
    context = {
        item["key"]: item.get("value", "")
        for item in metadata
        if isinstance(item, dict) and isinstance(item.get("key"), str)
    }
    result = {
        "event": "crowdsec_alert",
        "kind": {
            "crowdsec": "local_detection",
            "waf": "appsec_observation",
        }.get(alert.get("kind"), "manual_decision"),
        "alert_id": alert["id"],
        "scenario": alert.get("scenario", ""),
        "source_ip": source.get("ip", source.get("value", "")),
        "country": source.get("cn", ""),
        "asn": source.get("as_number", ""),
        "as_name": source.get("as_name", ""),
        "time": alert.get("created_at", ""),
        "events_count": alert.get("events_count", 0),
        "simulated": alert.get("simulated", False),
    }
    for name in ("target_host", "http_method", "http_status", "user_agent"):
        result[name] = context.get(name, "")
    # Context values can contain a JSON array of paths. Remove query strings.
    paths = context.get("target_uri", "")
    try:
        paths = json.loads(paths)
    except (ValueError, TypeError):
        pass
    if not isinstance(paths, list):
        paths = [paths]
    result["target_uri"] = [
        path.split("?", 1)[0].split("#", 1)[0]
        for path in paths[:50]
        if isinstance(path, str)
    ]
    return result


def duration(seconds):
    return f"{max(1, int(seconds + 0.999))}s"


def query_arguments(binary, config, since_seconds, until_seconds=0, limit=None):
    return [
        binary,
        "-c=" + config,
        "alerts",
        "list",
        "--since",
        duration(since_seconds),
        "--until",
        f"{max(0, int(until_seconds))}s",
        "--limit",
        str(MAX_ALERTS_PER_QUERY + 1 if limit is None else limit),
        "-o",
        "json",
    ]


def fetch_alerts(binary, config, start, end):
    # cscli has relative time filters, but no offset/ID pagination. Pad the
    # lower bound by the subprocess timeout, then filter the fixed interval
    # locally so CLI/LAPI latency cannot leave gaps between adjacent windows.
    now = time.time()
    dense = end - start <= 1
    output = subprocess.check_output(
        query_arguments(
            binary,
            config,
            now - start + 45,
            now - end,
            limit=0 if dense else None,
        ),
        timeout=45,
    )
    alerts = json.loads(output) or []
    if not dense and len(alerts) > MAX_ALERTS_PER_QUERY:
        middle = (start + end) / 2
        yield from fetch_alerts(binary, config, start, middle)
        yield from fetch_alerts(binary, config, middle, end)
        return
    # Time filters use start_at, not created_at. Overlapping boundaries are
    # deliberate; the durable identity ledger removes duplicates.
    page = []
    for alert in alerts:
        timestamp = datetime.fromisoformat(alert["start_at"].replace("Z", "+00:00"))
        if start <= timestamp.timestamp() <= end:
            page.append(alert)
    yield end, page


def ensure_schema(db):
    db.execute("CREATE TABLE IF NOT EXISTS seen (id TEXT PRIMARY KEY, seen_at INTEGER)")
    columns = {row[1] for row in db.execute("PRAGMA table_info(seen)")}
    if "seen_at" not in columns:
        db.execute("ALTER TABLE seen ADD COLUMN seen_at INTEGER")
    db.execute("CREATE TABLE IF NOT EXISTS state (key TEXT PRIMARY KEY, value TEXT)")


def last_cursor(db):
    row = db.execute("SELECT value FROM state WHERE key='cursor'").fetchone()
    return float(row[0]) if row else None


def save_cursor(db, cursor):
    db.execute(
        "INSERT OR REPLACE INTO state (key, value) VALUES ('cursor', ?)",
        (str(cursor),),
    )


def main():
    database, binary, config = sys.argv[1:]
    now = time.time()
    with closing(sqlite3.connect(database)) as db, db:
        ensure_schema(db)
        cursor = last_cursor(db)
        if cursor is None:
            since_seconds = MAX_LOOKBACK_SECONDS
        else:
            since_seconds = min(
                MAX_LOOKBACK_SECONDS,
                max(1, now - cursor + OVERLAP_SECONDS),
            )
        pending = db.execute("SELECT value FROM state WHERE key='pending'").fetchone()
        start, end = json.loads(pending[0]) if pending else (now - since_seconds, now)
        db.execute(
            "INSERT OR REPLACE INTO state (key, value) VALUES ('pending', ?)",
            (json.dumps([start, end]),),
        )
        db.commit()
        for completed, page in fetch_alerts(binary, config, start, end):
            for alert in page:
                identity = alert.get("uuid") or str(alert["id"])
                if db.execute("SELECT 1 FROM seen WHERE id=?", (identity,)).fetchone():
                    continue
                print(json.dumps(normalize(alert)), flush=True)
                db.execute(
                    "INSERT OR REPLACE INTO seen (id, seen_at) VALUES (?, ?)",
                    (identity, int(now)),
                )
            # Preserve completed windows even when a later query fails. Resume
            # the pending interval before opening another overlapping sweep.
            save_cursor(db, completed)
            db.execute(
                "UPDATE state SET value=? WHERE key='pending'",
                (json.dumps([completed, end]),),
            )
            db.commit()
        db.execute(
            "DELETE FROM seen WHERE COALESCE(seen_at, 0) < ?",
            (int(now) - SEEN_RETENTION_SECONDS,),
        )
        db.execute("DELETE FROM state WHERE key='pending'")


if __name__ == "__main__":
    main()
