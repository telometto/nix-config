"""Regression checks for context ownership and safe alert projection."""

import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(
        name, ROOT / "packages/crowdsec-observability" / (name + ".py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Observability(unittest.TestCase):
    def test_hub_status_only_flags_installed_outdated_items(self):
        items = {
            "scenarios": [
                {"name": "old", "status": "enabled,update-available"},
                {"name": "unused", "status": "disabled,update-available"},
                {"name": "current", "status": "enabled"},
                {"name": "custom", "status": "enabled,local"},
            ]
        }
        self.assertEqual(load("hub-status").pending(items), ["old"])

    def test_appsec_observation_is_not_a_manual_decision(self):
        event = load("alerts").normalize({"id": 43, "kind": "waf"})
        self.assertEqual(event["kind"], "appsec_observation")

    def test_context_cleanup_preserves_unowned_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            stale = "/nix/store/" + "a" * 32 + "-context.yaml"
            current = "/nix/store/" + "b" * 32 + "-context.yaml"
            (root / Path(stale).name).symlink_to(stale)
            (root / Path(current).name).symlink_to(current)
            (root / "custom.yaml").write_text("custom")
            (root / "admin.yaml").symlink_to(stale)
            load("contexts").clean(root, [current])
            self.assertFalse((root / Path(stale).name).is_symlink())
            self.assertTrue((root / Path(current).name).is_symlink())
            self.assertTrue((root / "admin.yaml").is_symlink())
            self.assertEqual((root / "custom.yaml").read_text(), "custom")

    def test_alert_projection(self):
        event = load("alerts").normalize(
            {
                "id": 42,
                "scenario": "crowdsecurity/http-probing",
                "events_count": 50,
                "source": {"ip": "198.51.100.42", "cn": "NO", "as_number": "123"},
                "meta": [
                    {"key": "target_uri", "value": '["/probe?token=SECRET"]'},
                    {"key": "target_host", "value": "example.test"},
                ],
                "events": [{"authorization": "SECRET"}],
                "message": "SECRET",
            }
        )
        self.assertEqual(event["source_ip"], "198.51.100.42")
        self.assertEqual(event["country"], "NO")
        self.assertEqual(event["target_uri"], ["/probe"])
        self.assertEqual(event["target_host"], "example.test")
        self.assertNotIn("SECRET", json.dumps(event))
        self.assertNotIn("events", event)

    def test_alert_archive_query_is_bounded_and_incremental(self):
        alerts = load("alerts")
        arguments = alerts.query_arguments("cscli", "crowdsec.yaml", 60)
        self.assertIn("--since", arguments)
        self.assertIn("60s", arguments)
        self.assertIn(str(alerts.MAX_ALERTS_PER_QUERY + 1), arguments)
        self.assertNotIn("0", arguments)

    def test_alert_archive_advances_cursor_and_deduplicates_overlap(self):
        alerts = load("alerts")
        payload = json.dumps([{"id": 42, "kind": "waf"}]).encode()
        with tempfile.TemporaryDirectory() as tmp:
            database = Path(tmp) / "seen.sqlite"
            argv = ["alerts.py", str(database), "cscli", "crowdsec.yaml"]
            output = io.StringIO()
            with (
                patch.object(
                    alerts.subprocess, "check_output", return_value=payload
                ) as query,
                patch.object(alerts.time, "time", side_effect=[1000, 1005]),
                patch("sys.argv", argv),
                redirect_stdout(output),
            ):
                alerts.main()
                alerts.main()

            self.assertEqual(len(output.getvalue().splitlines()), 1)
            first_query = query.call_args_list[0].args[0]
            second_query = query.call_args_list[1].args[0]
            self.assertIn("86400s", first_query)
            self.assertIn("305s", second_query)

            with alerts.sqlite3.connect(database) as db:
                self.assertEqual(
                    db.execute("SELECT count(*) FROM seen").fetchone()[0], 1
                )
                self.assertEqual(
                    db.execute("SELECT value FROM state WHERE key='cursor'").fetchone()[
                        0
                    ],
                    "1005",
                )


if __name__ == "__main__":
    unittest.main()
