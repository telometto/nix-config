"""Regression coverage for key overlap and rejection of incomplete restrictions."""

import importlib.util
import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest


checker_path = (
    Path(sys.argv.pop(1))
    if len(sys.argv) > 1
    else Path(__file__).with_name("sandfly-ssh-test.py")
)
spec = importlib.util.spec_from_file_location("sandfly_ssh_checker", checker_path)
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class ScannerKeyContract(unittest.TestCase):
    target = "100.67.190.43"
    scanner = "100.116.146.113"
    keys = ["ssh-ed25519 AAAA old-test-key", "ssh-ed25519 BBBB new-test-key"]

    def check(self, declared, rendered, port=22022):
        settings = {
            "addressfamily": "inet",
            "port": str(port),
            "listenaddress": f"{self.target}:{port}",
            "allowusers": f"sandfly@{self.scanner}",
            "authenticationmethods": "publickey",
            "pubkeyauthentication": "yes",
            "authorizedkeysfile": "/etc/ssh/sandfly-authorized_keys",
            "authorizedkeyscommand": "none",
            "trustedusercakeys": "none",
            "passwordauthentication": "no",
            "kbdinteractiveauthentication": "no",
            "permitrootlogin": "no",
            "usepam": "yes",
            "strictmodes": "yes",
            "disableforwarding": "yes",
            "permittunnel": "no",
            "permituserrc": "no",
            "permituserenvironment": "no",
            "forcecommand": "none",
            "subsystem": "sftp internal-sftp",
        }
        with TemporaryDirectory() as directory:
            root = Path(directory)
            effective, keys, expected = [
                root / name for name in ("sshd", "keys", "expected")
            ]
            effective.write_text(
                "\n".join(f"{key} {value}" for key, value in settings.items())
            )
            keys.write_text("\n".join(rendered) + "\n" if rendered else "")
            expected.write_text(json.dumps(declared))
            checker.main(effective, keys, self.target, self.scanner, port, expected)

    def restricted(self, keys):
        return [
            f'from="{self.scanner}",no-agent-forwarding,no-port-forwarding,'
            f"no-X11-forwarding,no-user-rc {key}"
            for key in keys
        ]

    def test_single_key_and_rotation_overlap(self):
        for keys in (self.keys[:1], self.keys):
            with self.subTest(count=len(keys)):
                self.check(keys, self.restricted(keys))

    def test_missing_extra_or_empty_keys_fail(self):
        for declared, rendered in (
            ([], []),
            (self.keys, self.keys[:1]),
            (self.keys[:1], self.keys),
        ):
            with self.subTest(declared=declared, rendered=rendered):
                with self.assertRaises(AssertionError):
                    self.check(declared, self.restricted(rendered))

    def test_every_key_requires_all_restrictions_and_exact_identity(self):
        for index in range(len(self.keys)):
            for replacement in (
                self.keys[index],
                self.restricted(self.keys)[index].replace("no-port-forwarding,", ""),
                self.restricted(self.keys)[index].replace(self.scanner, "100.90.0.1"),
                self.restricted(self.keys)[index]
                .replace("AAAA", "CCCC")
                .replace("BBBB", "CCCC"),
            ):
                with self.subTest(index=index, replacement=replacement):
                    rendered = self.restricted(self.keys)
                    rendered[index] = replacement
                    with self.assertRaises(AssertionError):
                        self.check(self.keys, rendered)


if __name__ == "__main__":
    unittest.main()
