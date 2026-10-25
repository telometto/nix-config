"""Run generated Codex activation blocks against disposable, public fixtures."""

import json
import os
from pathlib import Path
import shlex
import stat
import subprocess
import sys
import tempfile
import tomllib
import unittest


MANIFEST = json.loads(Path(sys.argv.pop(1)).read_text())
LOCAL = """model = "local-model"
[mcp_servers.keep]
url = "https://example.invalid/keep"
bearer_token = "public-placeholder"
[mcp_servers.to_stdio]
url = "https://example.invalid/old"
bearer_token = "public-placeholder"
[mcp_servers.to_http]
command = "old-command"
env = { TOKEN = "public-placeholder" }
[projects."/public-fixture"]
trust_level = "trusted"
"""


class CodexActivationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="codex-activation-")
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)

    def config(self, fixture, text=LOCAL, mode=0o640):
        target = self.home / fixture["prefix"] / "config.toml"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)
        target.chmod(mode)
        return target

    def run_block(self, block, *, dry_run=False):
        script = (
            "set -euo pipefail\n"
            f"source {shlex.quote(MANIFEST['bashLibrary'])}\n"
            + block.replace(MANIFEST["home"], str(self.home))
        )
        environment = {
            key: value
            for key, value in os.environ.items()
            if key not in {"DRY_RUN", "VERBOSE"}
        }
        environment["HOME"] = str(self.home)
        if dry_run:
            environment["DRY_RUN"] = "1"
        return subprocess.run(
            ["bash", "-c", script],
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def acl(self, path):
        return subprocess.check_output(["getfacl", "-cpn", str(path)], text=True)

    def set_acl(self, path, value):
        result = subprocess.run(
            ["setfacl", "-m", value, str(path)],
            capture_output=True,
            text=True,
            check=False,
            env={**os.environ, "LC_ALL": "C"},
        )
        if result.returncode and "Operation not supported" in result.stderr:
            self.skipTest("test filesystem does not support POSIX ACLs")
        self.assert_success(result)

    def test_merge_preserves_local_state_and_transport_rules(self):
        for name, fixture in MANIFEST["fixtures"].items():
            with self.subTest(directory=name):
                target = self.config(fixture, mode=0o600)
                self.assert_success(self.run_block(fixture["merge"]))
                merged = tomllib.loads(target.read_text())
                self.assertEqual(merged["model"], "declared-model")
                self.assertEqual(
                    merged["mcp_servers"]["keep"]["bearer_token"],
                    "public-placeholder",
                )
                self.assertEqual(
                    merged["projects"]["/public-fixture"]["trust_level"], "trusted"
                )
                self.assertNotIn("bearer_token", merged["mcp_servers"]["to_stdio"])
                self.assertNotIn("url", merged["mcp_servers"]["to_stdio"])
                self.assertNotIn("env", merged["mcp_servers"]["to_http"])
                self.assertNotIn("command", merged["mcp_servers"]["to_http"])
                self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)

    def test_restricted_group_is_preserved(self):
        groups = [gid for gid in os.getgroups() if gid != os.getegid()]
        if not groups:
            self.skipTest(
                "requires a supplementary group; rerun outside Nix's build sandbox"
            )
        for fixture in MANIFEST["fixtures"].values():
            with self.subTest(directory=fixture["prefix"]):
                target = self.config(fixture)
                os.chown(target, -1, groups[0])
                self.assert_success(self.run_block(fixture["merge"]))
                self.assertEqual(target.stat().st_gid, groups[0])
                self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o640)

    def test_parent_default_acl_does_not_broaden_access(self):
        for fixture in MANIFEST["fixtures"].values():
            with self.subTest(directory=fixture["prefix"]):
                target = self.config(fixture)
                before = self.acl(target)
                self.set_acl(
                    target.parent, "d:u::rwx,d:u:65533:r-x,d:g::r-x,d:m::r-x,d:o::---"
                )
                self.assert_success(self.run_block(fixture["merge"]))
                self.assertEqual(self.acl(target), before)

    def test_existing_acl_is_preserved(self):
        fixture = MANIFEST["fixtures"]["legacy"]
        target = self.config(fixture)
        self.set_acl(target, "u:65533:r--,m::r--")
        before = self.acl(target)
        self.assert_success(self.run_block(fixture["merge"]))
        self.assertEqual(self.acl(target), before)

    def test_acl_conflict_keeps_the_newer_file(self):
        fixture = MANIFEST["fixtures"]["legacy"]
        target = self.config(fixture)
        self.set_acl(target, "u:65533:r--,m::r--")
        block = fixture["merge"]
        self.assertEqual(block.count("conflict=\n"), 1)
        block = block.replace(
            "conflict=\n",
            'setfacl -m u:65533:---,m::r-- "$settings_path"\nconflict=\n',
        )
        result = self.run_block(block)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("changed during activation", result.stdout + result.stderr)
        self.assertEqual(target.read_text(), LOCAL)
        self.assertIn("user:65533:---", self.acl(target))

    def test_rename_failure_fallback_preserves_access(self):
        fixture = MANIFEST["fixtures"]["legacy"]
        target = self.config(fixture)
        self.set_acl(target, "u:65533:r--,m::r--")
        before = (target.stat().st_ino, self.acl(target))
        block = fixture["merge"]
        self.assertEqual(block.count(MANIFEST["mv"] + " -fT"), 1)
        block = block.replace(MANIFEST["mv"] + " -fT", "false")
        self.assert_success(self.run_block(block))
        self.assertEqual((target.stat().st_ino, self.acl(target)), before)
        self.assertEqual(tomllib.loads(target.read_text())["model"], "declared-model")

    def test_new_file_symlink_and_failure_paths(self):
        fixture = MANIFEST["fixtures"]["legacy"]
        target = self.home / fixture["prefix"] / "config.toml"
        self.assert_success(self.run_block(fixture["merge"]))
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)
        backing = target.with_name("backing.toml")
        target.rename(backing)
        target.symlink_to(backing)
        self.assert_success(self.run_block(fixture["merge"]))
        self.assertTrue(target.is_symlink())
        target.unlink()
        target.symlink_to(MANIFEST["storeTarget"])
        result = self.run_block(fixture["merge"])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Nix store", result.stdout + result.stderr)
        self.assertTrue(target.is_symlink())
        target.unlink()
        target.write_text("invalid TOML [")
        result = self.run_block(fixture["merge"])
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(target.read_text(), "invalid TOML [")
        self.assertFalse(list(target.parent.glob("*.candidate.*")))
        self.assertFalse(list(target.parent.glob("*.snapshot.*")))

    def test_merge_dry_run_preserves_contents_and_permissions(self):
        for fixture in MANIFEST["fixtures"].values():
            with self.subTest(directory=fixture["prefix"]):
                target = self.config(fixture)
                before = (target.read_bytes(), target.stat(), self.acl(target))
                self.assert_success(self.run_block(fixture["merge"], dry_run=True))
                self.assertEqual(
                    (target.read_bytes(), target.stat(), self.acl(target)), before
                )

    def test_plugin_cleanup_respects_dry_run_and_symlinks(self):
        for fixture in MANIFEST["fixtures"].values():
            for kind in ("staticCleanup", "derivedCleanup"):
                with self.subTest(directory=fixture["prefix"], kind=kind):
                    plugin = (
                        self.home
                        / fixture["prefix"]
                        / "plugins/cache/home-manager/fixture/1.0.0"
                    )
                    plugin.mkdir(parents=True)
                    sentinel = plugin / "sentinel"
                    sentinel.write_text("public fixture")
                    self.assert_success(self.run_block(fixture[kind], dry_run=True))
                    self.assertEqual(sentinel.read_text(), "public fixture")
                    self.assert_success(self.run_block(fixture[kind]))
                    self.assertFalse(plugin.exists())
                    plugin.symlink_to(self.home, target_is_directory=True)
                    self.assert_success(self.run_block(fixture[kind]))
                    self.assertTrue(plugin.is_symlink())
                    plugin.unlink()

    def test_metadata_preservation_failure_leaves_original_unchanged(self):
        fixture = MANIFEST["fixtures"]["legacy"]
        target = self.config(fixture)
        before = (target.read_bytes(), target.stat().st_gid, self.acl(target))
        for command in (
            MANIFEST["cp"] + " --preserve=mode,ownership",
            MANIFEST["chown"] + ' --reference="$snapshot_path"',
            MANIFEST["setfacl"]
            + ''' --set-file=<(printf '%s\\n' "$snapshot_acl") -- "$snapshot_path"''',
            MANIFEST["setfacl"]
            + ''' --set-file=<(printf '%s\\n' "$snapshot_acl") -- "$candidate_path"''',
        ):
            with self.subTest(command=command):
                block = fixture["merge"]
                self.assertEqual(block.count(command), 1)
                result = self.run_block(block.replace(command, "false"))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(
                    "Cannot preserve access controls", result.stdout + result.stderr
                )
                self.assertEqual(
                    (target.read_bytes(), target.stat().st_gid, self.acl(target)),
                    before,
                )
                self.assertFalse(list(target.parent.glob("*.candidate.*")))
                self.assertFalse(list(target.parent.glob("*.snapshot.*")))


if __name__ == "__main__":
    unittest.main(verbosity=2)
