"""Exercise the runtime writer with synthetic public keys only."""

from pathlib import Path
import resource
import signal
import subprocess
import sys
import tempfile
import unittest


WRITER = Path(sys.argv.pop(1))
SERVER = "blizzard.example.invalid"


class ServerConfigTest(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.directory = Path(self.scratch.name)
        self.path = self.directory / "server-options"

    def write(self, key="synthetic-public-key", **kwargs):
        return subprocess.run(
            [sys.executable, str(WRITER), str(self.path), SERVER],
            input=key,
            text=True,
            capture_output=True,
            **kwargs,
        )

    def test_fresh_settings_are_readable_in_every_context(self):
        result = self.write()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.path.read_text(), f"{SERVER}\nsynthetic-public-key\n")
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o644)

    def test_replaces_only_the_runtime_file(self):
        self.path.write_text("obsolete runtime data, not valid TOML")
        profile = self.directory / "RustDesk2.toml"
        profile.write_text("a broken desktop profile [")
        result = self.write()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(profile.read_text(), "a broken desktop profile [")
        self.assertEqual(self.path.read_text(), f"{SERVER}\nsynthetic-public-key\n")

    def test_repeat_and_rotation(self):
        for key in ("first-key", "first-key", "replacement-key"):
            result = self.write(key)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.path.read_text(), f"{SERVER}\n{key}\n")
            self.assertEqual(list(self.directory.iterdir()), [self.path])

    def test_rejects_empty_and_multiline_keys_without_replacing_settings(self):
        self.path.write_text("# previous settings\n")
        for key in ("", " \n", "first\nsecond"):
            with self.subTest(key=key):
                result = self.write(key)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.path.read_text(), "# previous settings\n")
                self.assertEqual(list(self.directory.iterdir()), [self.path])

    def test_close_failure_cleans_up_staging_file(self):
        self.path.write_text("# previous settings\n")

        def limit_file_size():
            signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
            resource.setrlimit(resource.RLIMIT_FSIZE, (1, 1))

        result = self.write(preexec_fn=limit_file_size)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.path.read_text(), "# previous settings\n")
        self.assertEqual(list(self.directory.iterdir()), [self.path])

    def test_rename_failure_cleans_up_staging_file(self):
        self.path.mkdir()
        result = self.write()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.path.is_dir())
        self.assertEqual(list(self.directory.iterdir()), [self.path])

    def test_write_failure_cleans_up_staging_file(self):
        self.path.write_text("# previous settings\n")

        def limit_file_size():
            signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
            resource.setrlimit(resource.RLIMIT_FSIZE, (1, 1))

        result = self.write("x" * 20000, preexec_fn=limit_file_size)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.path.read_text(), "# previous settings\n")
        self.assertEqual(list(self.directory.iterdir()), [self.path])

    def test_refuses_symlink(self):
        target = self.directory / "other-settings"
        target.write_text("leave this alone")
        self.path.symlink_to(target)
        result = self.write()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.path.is_symlink())
        self.assertEqual(target.read_text(), "leave this alone")


if __name__ == "__main__":
    unittest.main()
