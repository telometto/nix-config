"""Exercise the generated updater with a fake HTTP boundary and synthetic keys."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class CloudflareUpdaterTests(unittest.TestCase):
    def run_updater(self, include, previous=None):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        for name, value in (
            ("account", "fixture-account"),
            ("policy", "fixture-policy"),
            ("token", "fixture-token"),
        ):
            (root / name).write_text(value)
        (root / "response.json").write_text(
            json.dumps(
                {
                    "result": {
                        "name": "fixture",
                        "decision": "allow",
                        "precedence": 1,
                        "include": include,
                    }
                }
            )
        )
        if previous:
            (root / "last-ip").write_text(previous)
        fake = root / "curl"
        fake.write_text(
            f"#!{sys.executable}\n"
            + r"""
import json, sys
from pathlib import Path
root = Path(__file__).parent
args = sys.argv[1:]
with (root / "calls").open("a") as log:
    log.write(json.dumps(args) + "\n")
if args[-1] == "https://ip.fixture":
    print("203.0.113.20")
else:
    assert "fixture-token" not in " ".join(args)
    assert sys.stdin.read() == "Authorization: Bearer fixture-token\n"
    if "-X" in args:
        payload = args[args.index("--data-binary") + 1]
        (root / "updated.json").write_text(Path(payload[1:]).read_text())
        print('{"success":true}')
    else:
        print((root / "response.json").read_text())
"""
        )
        fake.chmod(0o700)
        source = Path(os.environ["UPDATER_SCRIPT"]).read_text()
        source = source.replace(os.environ["CURL_BIN"], str(fake))
        source = source.replace("@@FIXTURE@@", str(root))
        source = source.replace(
            "/var/lib/cloudflare-access-ip-updater/last-ip", str(root / "last-ip")
        )
        result = subprocess.run(["bash"], input=source, text=True, capture_output=True)
        self.assertNotIn("fixture-token", result.stdout + result.stderr)
        return root, result

    def test_known_rule_rotation_keeps_unmanaged_authorization(self):
        other = {"ip": {"ip": "198.51.100.0/24"}}
        email = {"email": {"email": "fixture@example.test"}}
        root, result = self.run_updater(
            [{"ip": {"ip": "203.0.113.10/32"}}, other, email], "203.0.113.10"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads((root / "updated.json").read_text())["include"],
            [{"ip": {"ip": "203.0.113.20/32"}}, other, email],
        )
        self.assertEqual((root / "last-ip").read_text().strip(), "203.0.113.20")

    def test_missing_history_refuses_to_preserve_unknown_ip_rules(self):
        root, result = self.run_updater([{"ip": {"ip": "203.0.113.10/32"}}])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Managed-IP history is missing", result.stderr)
        self.assertFalse((root / "updated.json").exists())
        self.assertFalse((root / "last-ip").exists())

    def test_empty_policy_can_be_bootstrapped_without_argv_credentials(self):
        root, result = self.run_updater([])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("fixture-token", (root / "calls").read_text())
        self.assertTrue((root / "updated.json").exists())

    def test_inconsistent_history_cannot_add_a_new_authorization(self):
        root, result = self.run_updater(
            [{"ip": {"ip": "203.0.113.10/32"}}], "203.0.113.99"
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Managed-IP history disagrees", result.stderr)
        self.assertFalse((root / "updated.json").exists())


if __name__ == "__main__":
    unittest.main()
