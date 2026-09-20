"""Regression checks for context ownership and safe alert projection."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

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


if __name__ == "__main__":
    unittest.main()
