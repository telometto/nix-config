"""Test the real bootstrap script without starting Grafana or reading secrets."""

import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


class GrafanaBootstrapTests(unittest.TestCase):
    def test_fresh_bootstrap_is_private_random_and_persistent(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            script = Path(os.environ["GRAFANA_BOOTSTRAP_SCRIPT"]).read_text()
            script = script.replace("/var/lib/grafana", str(root))
            password = root / "bootstrap-admin-password"
            subprocess.run(["bash"], input=script, text=True, check=True)
            first = password.read_bytes()
            self.assertEqual(len(first.strip()), 64)
            self.assertTrue(all(byte in b"0123456789abcdef" for byte in first.strip()))
            self.assertEqual(stat.S_IMODE(password.stat().st_mode), 0o600)
            subprocess.run(["bash"], input=script, text=True, check=True)
            self.assertEqual(password.read_bytes(), first)
            self.assertEqual(list(root.iterdir()), [password])


if __name__ == "__main__":
    unittest.main()
