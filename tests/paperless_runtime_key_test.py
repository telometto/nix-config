"""Exercise the actual web launcher with a synthetic runtime key and app stub."""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HELPER = Path(__file__).resolve().parents[1] / "lib/runtime-secret-environment.py"
spec = importlib.util.spec_from_file_location("secret_environment", HELPER)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class PaperlessRuntimeKeyTests(unittest.TestCase):
    def fixture(self, root):
        (root / "data").mkdir()
        launcher = root / "granian"
        launcher.write_text(
            f"#!{sys.executable}\n"
            "import json, os, sys\n"
            "from pathlib import Path\n"
            "root = Path(__file__).parent\n"
            '(root / "captured-key").write_text(os.environ["PAPERLESS_SECRET_KEY"])\n'
            '(root / "captured-args").write_text(json.dumps(sys.argv[1:]))\n'
        )
        launcher.chmod(0o700)
        return (
            Path(os.environ["PAPERLESS_WEB_SCRIPT"])
            .read_text()
            .replace("@@PAPERLESS_FIXTURE@@", str(root))
            .replace("/var/lib/paperless", str(root / "data"))
        )

    def test_custom_key_reaches_web_without_a_generated_replacement(self):
        for value in ("fixture-random-key", 'quotes " \\ $HOME `literal` 🔐'):
            with self.subTest(value=value), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                script = self.fixture(root)
                source, environment = root / "key", root / "environment"
                source.write_text(value + "\n")
                helper.render("PAPERLESS_SECRET_KEY", source, environment)
                script = f'set -a; source "{environment}"\n' + script
                result = subprocess.run(
                    ["bash"], input=script, text=True, capture_output=True, check=False
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((root / "captured-key").read_text(), value)
                self.assertEqual(
                    json.loads((root / "captured-args").read_text()),
                    ["--interface", "asginl", "--ws", "paperless.asgi:application"],
                )
                self.assertFalse((root / "data/nixos-paperless-secret-key").exists())

    def test_missing_or_empty_key_refuses_to_launch(self):
        for value in (None, ""):
            with self.subTest(value=value), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                script = self.fixture(root)
                environment = os.environ.copy()
                environment.pop("PAPERLESS_SECRET_KEY", None)
                if value is not None:
                    environment["PAPERLESS_SECRET_KEY"] = value
                result = subprocess.run(
                    ["bash"],
                    input=script,
                    text=True,
                    capture_output=True,
                    env=environment,
                    check=False,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((root / "captured-key").exists())
                self.assertFalse((root / "data/nixos-paperless-secret-key").exists())


if __name__ == "__main__":
    unittest.main()
