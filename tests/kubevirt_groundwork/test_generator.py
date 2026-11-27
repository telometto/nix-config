"""Public metadata and disabled host-registration generation contracts."""

import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "groundwork", ROOT / "lib/kubevirt-groundwork/generate.py"
)
groundwork = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(groundwork)


class RegistrationTests(unittest.TestCase):
    def setUp(self):
        self.catalog = groundwork.load_catalog()

    def test_every_profile_generates_only_disabled_fresh_disk_registration(self):
        names = set()
        for profile in self.catalog["services"]:
            with self.subTest(service=profile["id"]):
                text = groundwork.render(profile)
                self.assertIn("lib.mkDefault false", text)
                self.assertIn(profile["namespace"], text)
                self.assertEqual(text.count("previewVMs."), 1)
                self.assertNotIn("/rpool/", text)
                self.assertNotIn("systemd", text)
                disks = groundwork.disk_names(profile)
                self.assertEqual(disks[0], "root")
                self.assertEqual(len(disks), len(set(disks)))
                paths = {
                    f"/flash/enc/vms/kubevirt-pilot/{profile['namespace']}/{d}"
                    for d in disks
                }
                self.assertFalse(names.intersection(paths))
                names.update(paths)

    def test_groundwork_inventory_and_dependencies(self):
        services = {s["id"]: s for s in self.catalog["services"]}
        self.assertEqual(len(services), 16)
        self.assertNotIn("tautulli", services)
        self.assertEqual(services["seerr"]["legacyVm"], "overseerr")
        self.assertIn("whatsapp", groundwork.disk_names(services["matrix-synapse"]))
        self.assertEqual(groundwork.disk_names(services["wireguard"]), ["root"])
        self.assertEqual(services["wireguard"]["protocol"], "UDP")
        self.assertEqual(services["immich"]["stateVolumes"][0]["sizeMiB"], 1048576)

    def test_generator_refuses_unknown_duplicate_or_unsafe_names(self):
        with self.assertRaises(ValueError):
            groundwork.select(self.catalog, "tautulli")
        for key, value in (("id", "../actual"), ("namespace", "actual-pilot")):
            profile = dict(self.catalog["services"][0], **{key: value})
            with self.subTest(key=key), self.assertRaises(ValueError):
                groundwork.render(profile)
        profile = json.loads(json.dumps(self.catalog["services"][0]))
        profile["stateVolumes"].append(dict(profile["stateVolumes"][0]))
        with self.assertRaises(ValueError):
            groundwork.render(profile)

    def test_writer_refuses_existing_file_or_symlink(self):
        profile = self.catalog["services"][0]
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "bazarr-preview.nix"
            groundwork.write(profile, target)
            before = target.read_bytes()
            with self.assertRaises(FileExistsError):
                groundwork.write(profile, target)
            self.assertEqual(target.read_bytes(), before)
            link = Path(tmp) / "link.nix"
            link.symlink_to(target)
            with self.assertRaises(FileExistsError):
                groundwork.write(profile, link)


class ModuleBoundaryTests(unittest.TestCase):
    def inspect(self, root):
        expression = (
            'let lib = { mkDefault = content: { _type = "override"; priority = 1000; inherit content; }; }; '
            f"catalog = builtins.fromJSON (builtins.readFile {json.dumps(str(groundwork.CATALOG))}); "
            f"registry = import {json.dumps(str(ROOT / 'lib/kubevirt-groundwork/contract.nix'))} {{ inherit lib catalog; }}; "
            f"in (registry.inspect (builtins.toPath {json.dumps(str(root))})).valid"
        )
        with tempfile.TemporaryDirectory() as state:
            result = subprocess.run(
                [
                    "nix-instantiate",
                    "--eval",
                    "--strict",
                    "--json",
                    "--expr",
                    expression,
                ],
                check=True,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    "NIX_REMOTE": "local",
                    "NIX_STATE_DIR": state,
                    "NIX_CONF_DIR": state,
                    "NIX_CONFIG": "build-users-group =",
                },
            )
        return json.loads(result.stdout)

    def test_context_dependent_host_side_effect_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            module = root / "hosts/blizzard/virtualisation/bazarr-preview.nix"
            module.parent.mkdir(parents=True)
            profile = groundwork.select(groundwork.load_catalog(), "bazarr")
            module.write_text(groundwork.render(profile))
            self.assertTrue(self.inspect(root))
            text = module.read_text().replace("{ lib, ... }:", "{ lib, ... }@args:")
            text += '\n// lib.optionalAttrs (args ? config) { environment.variables.HIDDEN_EFFECT = "active"; }\n'
            # Supply optionalAttrs in the malicious function itself so the
            # old lib-only call hides the same effect as a real NixOS context.
            text = text.replace(
                "lib.optionalAttrs (args ? config)",
                "(if args ? config then (x: x) else (_: {}))",
            )
            module.write_text(text)
            self.assertFalse(self.inspect(root))

    def test_leaf_and_parent_symlinks_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            real = root / "real"
            real.mkdir()
            profile = groundwork.select(groundwork.load_catalog(), "bazarr")
            target = real / "bazarr-preview.nix"
            target.write_text(groundwork.render(profile))
            parent = root / "hosts/blizzard/virtualisation"
            parent.mkdir(parents=True)
            link = parent / target.name
            link.symlink_to(target)
            self.assertFalse(self.inspect(root))
            link.unlink()
            parent.rmdir()
            parent.symlink_to(real, target_is_directory=True)
            self.assertFalse(self.inspect(root))


if __name__ == "__main__":
    unittest.main()
