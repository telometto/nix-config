"""Regression checks for context ownership and safe alert projection."""

import importlib.util
import io
import json
import tempfile
import unittest
from contextlib import closing, redirect_stdout
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import Mock, patch

import crowdsec_bouncer_runtime as runtime

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(
        name, ROOT / "packages/crowdsec-observability" / (name + ".py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class Observability(unittest.TestCase):
    def test_runtime_waits_for_delayed_security_logs(self):
        decision = json.dumps({"event": "crowdsec_remediation", "kind": "decision"})
        failure = json.dumps(
            {"event": "crowdsec_remediation", "kind": "enforcement_error"}
        )
        output = Mock()
        output.read_text.side_effect = [
            decision + '\n{"event":',
            decision + "\n" + failure,
        ]
        proc = Mock()
        proc.poll.return_value = None
        with patch.object(runtime.time, "sleep") as sleep:
            records = runtime.wait_security_records(proc, output)
        self.assertEqual(len(records), 2)
        sleep.assert_called_once_with(0.05)

    def test_runtime_wait_reports_timeout_and_process_exit(self):
        for exit_code, timeout in ((7, 5), (None, 0)):
            with self.subTest(exit_code=exit_code):
                proc = Mock()
                proc.poll.return_value = exit_code
                output = Mock()
                output.read_text.return_value = "fixture diagnostics"
                with self.assertRaisesRegex(AssertionError, "fixture diagnostics"):
                    runtime.wait_security_records(proc, output, timeout=timeout)

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
        self.assertEqual(arguments[arguments.index("--limit") + 1], "501")

    def test_alert_archive_advances_cursor_and_deduplicates_overlap(self):
        alerts = load("alerts")
        payload = json.dumps(
            [{"id": 42, "kind": "waf", "start_at": "1970-01-01T00:16:30Z"}]
        ).encode()
        with tempfile.TemporaryDirectory() as tmp:
            database = Path(tmp) / "seen.sqlite"
            argv = ["alerts.py", str(database), "cscli", "crowdsec.yaml"]
            output = io.StringIO()
            with (
                patch.object(
                    alerts.subprocess, "check_output", return_value=payload
                ) as query,
                patch.object(alerts.time, "time", return_value=1000) as clock,
                patch("sys.argv", argv),
                redirect_stdout(output),
            ):
                alerts.main()
                clock.return_value = 1005
                alerts.main()

            self.assertEqual(len(output.getvalue().splitlines()), 1)
            first_query = query.call_args_list[0].args[0]
            second_query = query.call_args_list[1].args[0]
            self.assertIn("86445s", first_query)
            self.assertIn("350s", second_query)

            with closing(alerts.sqlite3.connect(database)) as db:
                self.assertEqual(
                    db.execute("SELECT count(*) FROM seen").fetchone()[0], 1
                )
                self.assertEqual(
                    db.execute("SELECT value FROM state WHERE key='cursor'").fetchone()[
                        0
                    ],
                    "1005",
                )

    def test_malformed_path_metadata_does_not_abort_projection(self):
        event = load("alerts").normalize(
            {
                "id": 1,
                "source": "invalid",
                "meta": [
                    None,
                    {},
                    {"key": [], "value": "SECRET"},
                    {
                        "key": "target_uri",
                        "value": '["//[?token=SECRET", "//example/foo#SECRET", null, {"SECRET": 1}]',
                    },
                ],
            }
        )
        self.assertEqual(event["target_uri"], ["//[", "//example/foo"])
        self.assertNotIn("SECRET", json.dumps(event))

    def test_archive_recovers_overflow_and_checkpoints_failed_pages(self):
        alerts = load("alerts")
        # More than a page at one timestamp must not truncate or stall.
        payload = [
            {
                "id": identity,
                "start_at": datetime.fromtimestamp(
                    800 if identity < 600 else 950, timezone.utc
                ).isoformat(),
                "meta": [{"key": "target_uri", "value": "//[?SECRET"}],
            }
            for identity in range(1201)
        ]
        fail_newer = True
        unlimited_queries = []

        def query(arguments, **kwargs):
            since = float(arguments[arguments.index("--since") + 1][:-1])
            until = float(arguments[arguments.index("--until") + 1][:-1])
            limit = int(arguments[arguments.index("--limit") + 1])
            if fail_newer and until < 100 and since < 200:
                raise alerts.subprocess.TimeoutExpired(arguments, 45)
            selected = [
                item
                for item in payload
                if 1000 - since
                <= datetime.fromisoformat(item["start_at"]).timestamp()
                <= 1000 - until
            ]
            if limit == 0:
                unlimited_queries.append(arguments)
            return json.dumps(selected[:limit] if limit else selected).encode()

        with tempfile.TemporaryDirectory() as tmp:
            database = Path(tmp) / "seen.sqlite"
            output = io.StringIO()
            with (
                patch.object(alerts.subprocess, "check_output", side_effect=query),
                patch.object(alerts.time, "time", return_value=1000),
                patch("sys.argv", ["alerts.py", str(database), "cscli", "config"]),
                redirect_stdout(output),
            ):
                with self.assertRaises(alerts.subprocess.TimeoutExpired):
                    alerts.main()
                with closing(alerts.sqlite3.connect(database)) as db:
                    self.assertEqual(
                        db.execute("SELECT count(*) FROM seen").fetchone()[0], 600
                    )
                    self.assertLess(alerts.last_cursor(db), 950)
                    self.assertIsNotNone(
                        db.execute(
                            "SELECT value FROM state WHERE key='pending'"
                        ).fetchone()
                    )
                fail_newer = False
                alerts.main()
                alerts.main()  # A fresh overlapping sweep must not duplicate records.
            records = [json.loads(line) for line in output.getvalue().splitlines()]
            self.assertEqual(len(records), 1201)
            self.assertEqual({item["alert_id"] for item in records}, set(range(1201)))
            self.assertTrue(all(item["target_uri"] == ["//["] for item in records))
            self.assertTrue(unlimited_queries)
            with closing(alerts.sqlite3.connect(database)) as db:
                self.assertEqual(alerts.last_cursor(db), 1000)
                self.assertIsNone(
                    db.execute("SELECT value FROM state WHERE key='pending'").fetchone()
                )


if __name__ == "__main__":
    unittest.main()
