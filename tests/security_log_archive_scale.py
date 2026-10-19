"""Measure disposable restic metadata growth; never open a production repository."""

import argparse
import json
import os
import statistics
import subprocess
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", type=Path, required=True)
    parser.add_argument("--snapshots", type=int, default=100)
    parser.add_argument("--bytes-per-snapshot", type=int, default=32768)
    args = parser.parse_args()
    if args.snapshots < 1 or args.bytes_per_snapshot < 1:
        parser.error("snapshot count and payload size must be positive")
    target = args.target.resolve()
    if target.exists() and any(target.iterdir()):
        parser.error("target must be a new or empty disposable directory")
    target.mkdir(mode=0o700, parents=True, exist_ok=True)
    password = target / "password"
    password.write_text(os.urandom(32).hex())
    password.chmod(0o600)
    base = [
        "restic",
        "--repo",
        str(target / "repository"),
        "--password-file",
        str(password),
    ]
    subprocess.run([*base, "init"], check=True, capture_output=True)
    durations, parent = [], None
    for index in range(args.snapshots):
        payload = target / "payload"
        payload.write_bytes(os.urandom(args.bytes_per_snapshot))
        command = [*base, "backup", "--json", "--host", "archive-scale-fixture"]
        if parent:
            command += ["--parent", parent]
        started = time.monotonic()
        output = subprocess.check_output([*command, str(payload)])
        durations.append(time.monotonic() - started)
        summary = next(
            row
            for row in reversed([json.loads(line) for line in output.splitlines()])
            if row.get("message_type") == "summary"
        )
        parent = summary["snapshot_id"]
        if (index + 1) % 1000 == 0:
            print(json.dumps({"completed": index + 1}), flush=True)
    started = time.monotonic()
    snapshots = json.loads(subprocess.check_output([*base, "snapshots", "--json"]))
    listing_seconds = time.monotonic() - started
    size = sum(
        path.stat().st_size
        for path in (target / "repository").rglob("*")
        if path.is_file()
    )
    report = {
        "verified_snapshot_count": len(snapshots),
        "annual_snapshot_count": 262800,
        "annual_count_exercised": args.snapshots >= 262800,
        "repository_bytes": size,
        "estimated_annual_bytes_at_this_payload": int(size / args.snapshots * 262800),
        "upload_median_seconds": statistics.median(durations),
        "last_ten_upload_max_seconds": max(durations[-10:]),
        "snapshot_listing_seconds": listing_seconds,
        "limitation": "Local metadata benchmark only; measure real compression, source volume and rsync.net latency separately.",
    }
    (target / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
