import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

HELPER = Path(__file__).resolve().parents[1] / "lib/runtime-secret-environment.py"
spec = importlib.util.spec_from_file_location("secret_environment", HELPER)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class RuntimeSecretEnvironmentTests(unittest.TestCase):
    def test_searx_yaml_substitution_preserves_the_complete_key(self):
        import yaml

        for value in (
            "x8K6pqD3aZ # C9zvW1Q7sT",
            ": YAML value",
            '"quoted" \\ $HOME `literal` æ',
        ):
            with self.subTest(value=value), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                source, output = root / "key", root / "environment"
                source.write_text(value + "\n")
                helper.render("SEARX_SECRET_KEY", source, output, json_scalar=True)
                subprocess.run(
                    [
                        "bash",
                        "-c",
                        'set -a; source "$1"; exec bash "$2"',
                        "fixture",
                        str(output),
                        os.environ["SEARX_INIT_SCRIPT"],
                    ],
                    env=os.environ | {"SEARX_FIXTURE_DIR": str(root)},
                    check=True,
                    text=True,
                    capture_output=True,
                )
                settings = yaml.safe_load((root / "settings.yml").read_text())
                self.assertEqual(settings["server"]["secret_key"], value)

    def test_secret_bytes_roundtrip_without_shell_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, output = root / "key", root / "environment"
            value = 'a secret "quoted" \\ key $HOME $(touch pwned) `touch pwned`'
            source.write_text(value + "\n")
            helper.render("APP_SECRET", source, output)
            result = subprocess.run(
                [
                    "bash",
                    "-c",
                    'source "$1"; printf %s "$APP_SECRET"',
                    "fixture",
                    str(output),
                ],
                cwd=root,
                check=True,
                text=True,
                capture_output=True,
            )
            self.assertEqual(result.stdout, value)
            self.assertFalse((root / "pwned").exists())
            self.assertEqual(output.stat().st_mode & 0o777, 0o640)
            self.assertFalse(list(root.glob(".environment-*")))

    def test_invalid_secret_keeps_previous_environment(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, output = root / "key", root / "environment"
            output.write_text("previous")
            for value in ("", "two\nlines", "two\rparts", "nul\0byte", "extra\n\n"):
                source.write_text(value)
                with self.assertRaises(ValueError):
                    helper.render("APP_SECRET", source, output)
                self.assertEqual(output.read_text(), "previous")


if __name__ == "__main__":
    unittest.main()
