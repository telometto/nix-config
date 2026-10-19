"""Actual restic/rclone append-only protocol and independent recovery fixture."""

import argparse
import json
import shutil
import socket
import subprocess
import tempfile
import time
import unittest
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

from security_log_archive_test import archive, record


class ProtocolTests(unittest.TestCase):
    def test_successful_retention_preserves_full_year_boundary(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            password = root / "password"
            password.write_text("disposable-fixture-password")
            cfg = {
                "host": "blizzard",
                "state_dir": str(root / "source"),
                "staging_dir": str(root / "staging"),
                "buffer_bytes": 1024**3,
                "min_free_bytes": 0,
                "repository": str(root / "repository"),
                "admin_repository": str(root / "repository"),
                "credentials": {"password": str(password)},
            }
            client = archive.Restic(cfg, admin=True)
            client.run("init")
            cfg["repository_id"] = client.run("cat", "config", json_result=True)["id"]
            spool = archive.spool_for(cfg)
            spool.append([record()], "cursor-1")
            staging = root / "batch"
            archive.stage_batch(spool, spool.pending(), staging, cfg)
            now = 1800000000
            identities = []
            # --time is interpreted in the restic process's local timezone.
            for age in (archive.YEAR + 1, archive.YEAR, archive.YEAR - 1):
                created = datetime.fromtimestamp(now - age, timezone.utc).strftime(
                    "%Y-%m-%d %H:%M:%S"
                )
                with patch.dict("os.environ", {"TZ": "UTC"}):
                    output = client.run(
                        "backup",
                        "--json",
                        "--force",
                        "--host",
                        cfg["host"],
                        "--tag",
                        archive.PROFILE,
                        "--time",
                        created,
                        str(staging),
                    )
                summary = json.loads(output.splitlines()[-1])
                identities.append(summary["snapshot_id"])
            plan = root / "plan.json"
            args = argparse.Namespace(
                action="retention-preview", plan=str(plan), uploads_paused=True
            )
            operations = []
            original = archive.Restic.run

            def run(instance, *command, **kwargs):
                operations.append(command)
                return original(instance, *command, **kwargs)

            with (
                patch("archive.time.time", return_value=now),
                patch.object(archive.Restic, "run", run),
            ):
                archive.admin(cfg, args)
                self.assertEqual(
                    json.loads(plan.read_bytes())["snapshot_ids"], [identities[0]]
                )
                self.assertEqual(
                    len(client.run("snapshots", "--json", json_result=True)), 3
                )
                operations.clear()
                args.action = "retention-apply"
                archive.admin(cfg, args)
            commands = [command[0] for command in operations]
            self.assertLess(commands.index("check"), commands.index("restore"))
            self.assertLess(commands.index("restore"), commands.index("forget"))
            self.assertLess(commands.index("forget"), commands.index("prune"))
            self.assertEqual(
                next(command for command in operations if command[0] == "forget"),
                ("forget", identities[0]),
            )
            remaining = client.run("snapshots", "--json", json_result=True)
            self.assertEqual(
                {snapshot["id"] for snapshot in remaining}, set(identities[1:])
            )
            client.run("check", "--read-data")

    def test_append_only_protocol_and_source_independent_restore(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            password = root / "password"
            password.write_text("disposable-fixture-password")
            repo = root / "repository"
            admin = ["restic", "--repo", str(repo), "--password-file", str(password)]
            subprocess.run([*admin, "init"], check=True, capture_output=True)
            identity = json.loads(subprocess.check_output([*admin, "cat", "config"]))[
                "id"
            ]
            with socket.socket() as sock:
                sock.bind(("127.0.0.1", 0))
                port = sock.getsockname()[1]
            url = f"http://127.0.0.1:{port}"
            server = subprocess.Popen(
                [
                    "rclone",
                    "serve",
                    "restic",
                    "--addr",
                    f"127.0.0.1:{port}",
                    "--append-only",
                    str(repo),
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            try:
                for _ in range(100):
                    try:
                        urllib.request.urlopen(url + "/config", timeout=1).close()
                        break
                    except OSError:
                        time.sleep(0.05)
                else:
                    self.fail("fixture receiver did not start")
                cfg = {
                    "host": "blizzard",
                    "state_dir": str(root / "source"),
                    "staging_dir": str(root / "staging"),
                    "buffer_bytes": 1024**3,
                    "min_free_bytes": 0,
                    "repository": "rest:" + url,
                    "repository_id": identity,
                    "admin_repository": str(repo),
                    "credentials": {"password": str(password)},
                }
                spool = archive.spool_for(cfg)
                for index in range(2):
                    spool.append([record(f"cursor-{index}")], f"cursor-{index}")
                    with patch("archive.heartbeat") as heartbeat:
                        archive.upload(cfg)
                    heartbeat.assert_called_once()
                    self.assertEqual(spool.pending(), [])
                snapshots = json.loads(
                    subprocess.check_output([*admin, "snapshots", "--json"])
                )
                self.assertEqual(len(snapshots), 2)
                first = snapshots[0]["id"]
                original = (repo / "snapshots" / first).read_bytes()
                for method, payload in (("POST", b"corrupt"), ("DELETE", None)):
                    request = urllib.request.Request(
                        url + "/snapshots/" + first, data=payload, method=method
                    )
                    with self.assertRaises(urllib.error.HTTPError) as rejected:
                        urllib.request.urlopen(request, timeout=3)
                    self.assertEqual(rejected.exception.code, 403)
                    self.assertEqual(
                        (repo / "snapshots" / first).read_bytes(), original
                    )
                # Losing the source, its cursor and local receipts must not
                # prevent interval recovery from the receiver and recovery key.
                shutil.rmtree(root / "source")
                shutil.rmtree(root / "staging")
                target = root / "recovered"
                archive.restore(
                    cfg,
                    archive.Restic(cfg, admin=True),
                    argparse.Namespace(
                        target=str(target),
                        since="2020-01-01T00:00:00Z",
                        until="2040-01-01T00:00:00Z",
                    ),
                )
                events = [
                    json.loads(line)
                    for line in (target / "events.jsonl").read_bytes().splitlines()
                ]
                self.assertEqual(len(events), 2)
                self.assertNotIn(b"SECRET", (target / "events.jsonl").read_bytes())
                subprocess.run(
                    [*admin, "check", "--read-data"], check=True, capture_output=True
                )
            finally:
                server.terminate()
                server.wait(timeout=5)


if __name__ == "__main__":
    unittest.main()
