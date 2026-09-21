"""Archive bounded, allowlisted local alert metadata."""

import json
import sqlite3
import subprocess
import sys
import time
from urllib.parse import urlsplit


MAX_ALERTS_PER_QUERY = 500
MAX_LOOKBACK_SECONDS = 24 * 60 * 60
OVERLAP_SECONDS = 5 * 60
SEEN_RETENTION_SECONDS = 31 * 24 * 60 * 60


def normalize(alert):
    source = alert.get("source") or {}
    context = {item["key"]: item.get("value", "") for item in alert.get("meta", [])}
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
    result["target_uri"] = [urlsplit(str(path)).path for path in paths][:50]
    return result


def duration(seconds):
    return f"{max(1, int(seconds + 0.999))}s"


def query_arguments(binary, config, since_seconds):
    return [
        binary,
        "-c=" + config,
        "alerts",
        "list",
        "--since",
        duration(since_seconds),
        "--limit",
        str(MAX_ALERTS_PER_QUERY + 1),
        "-o",
        "json",
    ]


def fetch_alerts(binary, config, since_seconds):
    output = subprocess.check_output(
        query_arguments(binary, config, since_seconds),
        timeout=45,
    )
    alerts = json.loads(output) or []
    if len(alerts) > MAX_ALERTS_PER_QUERY:
        raise RuntimeError(
            "CrowdSec alert query exceeded the bounded page; "
            "reduce the polling gap or add time-window pagination"
        )
    return alerts


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
    with sqlite3.connect(database) as db:
        ensure_schema(db)
        cursor = last_cursor(db)
        if cursor is None:
            since_seconds = MAX_LOOKBACK_SECONDS
        else:
            since_seconds = min(
                MAX_LOOKBACK_SECONDS,
                max(1, now - cursor + OVERLAP_SECONDS),
            )
        alerts = fetch_alerts(binary, config, since_seconds)
        for alert in alerts:
            identity = alert.get("uuid") or str(alert["id"])
            if db.execute("SELECT 1 FROM seen WHERE id=?", (identity,)).fetchone():
                continue
            print(json.dumps(normalize(alert)), flush=True)
            db.execute(
                "INSERT OR REPLACE INTO seen (id, seen_at) VALUES (?, ?)",
                (identity, int(now)),
            )
        db.execute(
            "DELETE FROM seen WHERE COALESCE(seen_at, 0) < ?",
            (int(now) - SEEN_RETENTION_SECONDS,),
        )
        # Advance only after the bounded query and all projections succeeded.
        save_cursor(db, now)


if __name__ == "__main__":
    main()
