"""Exercise the SSH phase with synthetic files and a real sshd parser.

Run with python3 tests/prepare-ubuntu-test.py. Set SSHD to an absolute sshd
path if it is not on PATH. No daemon, account, package or firewall is changed.
"""

import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = (Path(__file__).resolve().parents[1] / "prepare-ubuntu.sh").read_text()
SSHD = os.environ.get("SSHD") or shutil.which("sshd")
KEYGEN = shutil.which("ssh-keygen")


def function(name):
    match = re.search(rf"^{name}\(\) [{{(]\n.*?^[}})]$", SCRIPT, re.M | re.S)
    if not match:
        raise AssertionError(f"Missing script helper: {name}")
    return match.group()


@unittest.skipUnless(SSHD and KEYGEN, "requires sshd and ssh-keygen")
class SshHardeningTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.dropins = self.root / "sshd_config.d"
        self.dropins.mkdir()
        self.managed = self.dropins / "00-prepare-ubuntu-hardening.conf"
        self.config = self.root / "sshd_config"
        self.key = self.root / "host-key"
        subprocess.run(
            [KEYGEN, "-q", "-t", "ed25519", "-N", "", "-f", str(self.key)],
            check=True,
        )
        self.public_key = self.key.with_suffix(".pub").read_text()
        self.config.write_text(
            f"Include {self.dropins}/*.conf\nHostKey {self.key}\nPort 2222\n"
        )
        self.home = self.root / "admin-home"
        (self.home / ".ssh").mkdir(parents=True)
        (self.home / ".ssh/authorized_keys").write_text(self.public_key)
        self.staging = self.root / "staging"
        self.staging.mkdir()

    def bash(self, code):
        return subprocess.run(
            ["bash", "-c", "set -Eeuo pipefail\n" + code],
            text=True,
            capture_output=True,
        )

    def install_hardening(self):
        start = SCRIPT.index('if ((HARDEN_SSH)); then\n  log "Hardening OpenSSH"')
        end = SCRIPT.index("\nif ((ENABLE_UFW)); then", start)
        code = (
            "\n".join(
                function(name)
                for name in (
                    "ssh_hardening_has_precedence",
                    "restore_ssh_config",
                    "ssh_config_is_hardened",
                )
            )
            + "\n"
            + SCRIPT[start:end]
        )
        code = code.replace("/etc/ssh/sshd_config.d", str(self.dropins))
        code = code.replace("/etc/ssh/sshd_config", str(self.config))
        code = code.replace(
            "/usr/sbin/sshd", f"{shlex.quote(SSHD)} -f {shlex.quote(str(self.config))}"
        )
        # The primary group is deliberately different from the administrator.
        # Only file ownership and service operations are mocked.
        prelude = f"""
HARDEN_SSH=1
ADMIN_USER={shlex.quote(os.environ.get("USER", "root"))}
SSH_CONNECTION='198.51.100.7 50000 127.0.0.1 2222'
TMP_DIR={shlex.quote(str(self.staging))}
SSH_HARDENING_FILE={shlex.quote(str(self.managed))}
log() {{ :; }}
info() {{ :; }}
warn() {{ :; }}
die() {{ printf '%s\\n' "$*" >&2; exit 1; }}
getent() {{ printf 'fixture:x:1000:1000::%s:/bin/bash\\n' {shlex.quote(str(self.home))}; }}
id() {{ test "$1" = -gn; printf 'shared-admin-group\\n'; }}
chown() {{ test "$1" = "$ADMIN_USER:shared-admin-group"; }}
systemctl() {{ printf '%s\\n' "$*" >> {shlex.quote(str(self.root / "service-calls"))}; }}
"""
        return self.bash(prelude + code)

    def effective(self, user="root", address="203.0.113.7"):
        result = subprocess.run(
            [
                SSHD,
                "-T",
                "-f",
                str(self.config),
                "-C",
                f"user={user},host=client.example,addr={address},laddr=127.0.0.1,lport=2222",
            ],
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return dict(line.lower().split(" ", 1) for line in result.stdout.splitlines())

    def test_root_exception_reproducer_and_fix(self):
        self.managed.write_text(
            "PubkeyAuthentication yes\nPasswordAuthentication no\n"
            "KbdInteractiveAuthentication no\nPermitRootLogin no\n"
        )
        (self.dropins / "50-local.conf").write_text(
            "Match User root\n PermitRootLogin yes\n PasswordAuthentication yes\n"
        )
        self.assertEqual(self.effective()["permitrootlogin"], "yes")
        result = self.install_hardening()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.effective()["permitrootlogin"], "no")
        self.assertEqual(self.effective()["passwordauthentication"], "no")

    def test_other_match_contexts_and_unrelated_policies(self):
        nested = self.root / "nested.conf"
        nested.write_text("PermitRootLogin yes\nPasswordAuthentication yes\n")
        (self.dropins / "50-local.conf").write_text(
            f"Match Group root\n Include {nested}\n"
            "Match Address 203.0.113.0/24,2001:db8::/32\n"
            " PermitRootLogin yes\n PasswordAuthentication yes\n"
            " KbdInteractiveAuthentication yes\n HostbasedAuthentication yes\n"
            " PubkeyAuthentication no\n PermitEmptyPasswords yes\n"
            "Match User nobody\n ForceCommand internal-sftp\n"
        )
        with self.config.open("a") as config:
            config.write(
                "Match LocalPort 2222\nPermitRootLogin yes\n"
                "PasswordAuthentication yes\n"
                "Match Host client.example\nKbdInteractiveAuthentication yes\n"
            )
        result = self.install_hardening()
        self.assertEqual(result.returncode, 0, result.stderr)
        for user in ("root", "nobody"):
            for address in ("203.0.113.7", "2001:db8::7", "198.51.100.7"):
                with self.subTest(user=user, address=address):
                    policy = self.effective(user, address)
                    for option in (
                        "permitrootlogin",
                        "passwordauthentication",
                        "kbdinteractiveauthentication",
                        "hostbasedauthentication",
                        "permitemptypasswords",
                    ):
                        self.assertEqual(policy[option], "no")
                    self.assertEqual(policy["pubkeyauthentication"], "yes")
                    if user == "nobody":
                        self.assertEqual(policy["forcecommand"], "internal-sftp")

    def test_custom_order_is_rejected_before_installation(self):
        (self.dropins / "00-earlier.conf").write_text("PermitRootLogin yes\n")
        result = self.install_hardening()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.managed.exists())
        self.assertFalse((self.root / "service-calls").exists())

    def test_main_directive_before_include_is_rejected(self):
        self.config.write_text("Port 2222\n" + self.config.read_text())
        result = self.install_hardening()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.managed.exists())

    def test_invalid_config_restores_existing_or_absent_file(self):
        (self.dropins / "50-invalid.conf").write_text("InvalidSshDirective yes\n")
        for previous in (None, "# previous managed settings\n"):
            with self.subTest(previous=previous):
                if previous is not None:
                    self.managed.write_text(previous)
                result = self.install_hardening()
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((self.root / "service-calls").exists())
                if previous is None:
                    self.assertFalse(self.managed.exists())
                else:
                    self.assertEqual(self.managed.read_text(), previous)

    def test_existing_authentication_requirements_are_not_weakened(self):
        (self.dropins / "50-local.conf").write_text(
            "AuthenticationMethods publickey,publickey\n"
        )
        result = self.install_hardening()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.effective()["authenticationmethods"], "publickey,publickey"
        )

    def test_explicit_keys_accept_public_and_reject_restricted_or_private(self):
        fixture = self.root / "admin-keys"
        cases = (
            ("# fixture\n\n" + self.public_key, True),
            ('command="exit 142" ' + self.public_key, False),
            ('restrict,command="echo redirect" ' + self.public_key, False),
            ("no-pty " + self.public_key, False),
            (self.key.read_text(), False),
            ("ssh-ed25519 invalid\n", False),
            ("# no key\n", False),
        )
        for contents, accepted in cases:
            with self.subTest(accepted=accepted, prefix=contents.split()[0]):
                fixture.write_text(contents)
                result = self.bash(
                    function("admin_key_file_is_usable")
                    + f"\nadmin_key_file_is_usable {shlex.quote(str(fixture))}\n"
                )
                self.assertEqual(result.returncode == 0, accepted, result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
