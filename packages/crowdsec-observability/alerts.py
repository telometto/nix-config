"""Archive allowlisted local alert metadata; never forward raw event payloads."""

import json
import sqlite3
import subprocess
import sys
from urllib.parse import urlsplit


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


def main():
    database, binary, config = sys.argv[1:]
    # Fetch all retained alerts; a default limit could silently lose busy bursts.
    output = subprocess.check_output(
        [binary, "-c=" + config, "alerts", "list", "--limit", "0", "-o", "json"],
        timeout=45,
    )
    alerts = json.loads(output) or []
    with sqlite3.connect(database) as db:
        db.execute("CREATE TABLE IF NOT EXISTS seen (id TEXT PRIMARY KEY)")
        for alert in alerts:
            identity = alert.get("uuid") or str(alert["id"])
            if db.execute("SELECT 1 FROM seen WHERE id=?", (identity,)).fetchone():
                continue
            print(json.dumps(normalize(alert)), flush=True)
            db.execute("INSERT INTO seen VALUES (?)", (identity,))
        # Keep the dedup ledger bounded by the engine's retained alert set.
        db.execute("CREATE TEMP TABLE current (id TEXT PRIMARY KEY)")
        db.executemany(
            "INSERT OR IGNORE INTO current VALUES (?)",
            [(a.get("uuid") or str(a["id"]),) for a in alerts],
        )
        db.execute("DELETE FROM seen WHERE id NOT IN (SELECT id FROM current)")


if __name__ == "__main__":
    main()
