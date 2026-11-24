"""Metadata-only first-start/recovery guards must preserve existing files."""

import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = (
    Path(__file__).resolve().parents[2]
    / "modules/virtualisation/scripts/actual_pilot_preflight.py"
)
spec = importlib.util.spec_from_file_location("pilot_preflight", SCRIPT)
preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preflight)


class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.state = self.root / "state"
        self.state.mkdir()
        self.disk = self.root / "data"
        self.disk.mkdir()
        self.legacy = self.root / "legacy-kubeconfig"
        self.pilot = self.root / "new-kubeconfig"
        self.shared = self.root / "device-plugins"
        self.paths = {
            "stateDir": str(self.state),
            "diskDirs": [str(self.disk)],
            "defaultKubeconfig": str(self.legacy),
            "pilotKubeconfig": str(self.pilot),
            "firstStartFiles": [
                str(self.root / "node-password"),
                str(self.root / "runtime.sock"),
            ],
            "firstStartDirectories": [str(self.shared)],
            "absentAlways": [str(self.root / "disabled-provider-config")],
        }

    def owned(self):
        (self.state / "runtime-owner").touch()
        database = self.state / "server/db/state.db"
        database.parent.mkdir(parents=True)
        database.touch()

    def test_clean_first_start_claims_only_new_state(self):
        preflight.claim(self.paths)
        self.assertTrue((self.state / "runtime-owner").is_file())
        self.assertEqual(list(self.disk.iterdir()), [])

    def test_existing_regular_default_kubeconfig_is_never_opened_or_replaced(self):
        self.legacy.write_text("retained fixture")
        self.legacy.chmod(0)
        with self.assertRaises(RuntimeError):
            preflight.claim(self.paths)
        self.legacy.chmod(0o600)
        self.assertEqual(self.legacy.read_text(), "retained fixture")

    def test_preexisting_node_password_and_runtime_block_initial_start(self):
        for filename in ("node-password", "runtime.sock"):
            path = self.root / filename
            path.touch()
            with self.assertRaises(RuntimeError):
                preflight.claim(self.paths)
            self.assertTrue(path.exists())
            path.unlink()

    def test_canonical_device_plugin_checkpoint_is_not_cleaned(self):
        self.shared.mkdir()
        checkpoint = self.shared / "kubelet_internal_checkpoint"
        checkpoint.write_text("retained device allocation")
        with self.assertRaises(RuntimeError):
            preflight.claim(self.paths)
        self.assertEqual(checkpoint.read_text(), "retained device allocation")

    def test_foreign_cluster_state_is_not_adopted(self):
        (self.state / "foreign-state").touch()
        with self.assertRaises(RuntimeError):
            preflight.claim(self.paths)
        self.assertFalse((self.state / "runtime-owner").exists())

    def test_fresh_cluster_cannot_reimport_over_retained_disk(self):
        image = self.disk / "disk.img"
        image.write_text("retained image")
        with self.assertRaises(RuntimeError):
            preflight.claim(self.paths)
        self.assertEqual(image.read_text(), "retained image")

    def test_lost_database_is_fresh_even_when_owner_marker_survives(self):
        self.owned()
        (self.state / "server/db/state.db").unlink()
        (self.disk / "disk.img").write_text("retained image")
        with self.assertRaises(RuntimeError):
            preflight.claim(self.paths)
        self.assertTrue((self.disk / "disk.img").exists())

    def test_owned_database_can_reuse_its_images_and_default_link(self):
        self.owned()
        self.legacy.symlink_to(self.pilot)
        (self.disk / "disk.img").write_text("pilot image")
        self.shared.mkdir()
        (self.shared / "kubelet_internal_checkpoint").touch()
        preflight.claim(self.paths)
        self.assertTrue(self.legacy.is_symlink())
        self.assertEqual((self.disk / "disk.img").read_text(), "pilot image")

    def test_owned_marker_does_not_authorize_foreign_kubeconfig_or_provider(self):
        self.owned()
        self.legacy.write_text("foreign fixture")
        with self.assertRaises(RuntimeError):
            preflight.claim(self.paths)
        self.legacy.unlink()
        (self.root / "disabled-provider-config").touch()
        with self.assertRaises(RuntimeError):
            preflight.claim(self.paths)


if __name__ == "__main__":
    unittest.main()
