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
from pathlib import Path
from unittest.mock import patch

from security_log_archive_test import archive, record


class ProtocolTests(unittest.TestCase):
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
