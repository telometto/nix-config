"""Synthetic enrollment and real Linux PAM tests; never open a real wallet."""

import importlib.util
import io
import json
import os
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "packages" / "kwallet-tpm"


class EnrollmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location(
            "kwallet_enroll", PACKAGE / "enroll.py"
        )
        cls.enroll = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.enroll)

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="kwallet-enroll-test-")
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name) / "credentials"
        self.directory.mkdir(mode=0o700)
        self.config = {
            "users": ["fixture"],
            "pcrs": [4, 7],
            "credentialDirectory": str(self.directory),
            "systemdCreds": "/fixture/systemd-creds",
            "systemdAnalyze": "/fixture/systemd-analyze",
        }
        self.credential = self.directory / "fixture.cred"

    def run_enrollment(self, prompts=("fixture-only-password",) * 2, **kwargs):
        with (
            mock.patch.object(self.enroll, "preflight"),
            mock.patch.object(self.enroll.os, "geteuid", return_value=os.getuid()),
            mock.patch.object(self.enroll.subprocess, "run") as run,
        ):
            run.return_value = subprocess.CompletedProcess(
                [], 0, b"fixture-ciphertext", b""
            )
            prompt = mock.Mock(side_effect=prompts)
            self.enroll.enroll("fixture", self.config, prompt=prompt, **kwargs)
            return run.call_args

    def test_enrollment_binds_tpm_and_explicit_pcrs_without_password_in_arguments(self):
        call = self.run_enrollment()
        argv = call.args[0]
        self.assertIn("--with-key=host+tpm2", argv)
        self.assertIn("--tpm2-pcrs=4+7", argv)
        self.assertIn("--name=kwallet-tpm-fixture", argv)
        self.assertNotIn("fixture-only-password", " ".join(argv))
        self.assertEqual(call.kwargs["input"], b"fixture-only-password")
        self.assertEqual(self.credential.read_bytes(), b"fixture-ciphertext")
        self.assertEqual(self.credential.stat().st_mode & 0o777, 0o600)

    def test_empty_and_mismatched_passwords_do_not_write_a_credential(self):
        for values in (("", ""), ("one", "two")):
            with self.subTest(values=values):
                with self.assertRaises(self.enroll.EnrollmentError):
                    self.run_enrollment(values)
                self.assertFalse(self.credential.exists())

    def test_unauthorized_user_is_rejected_before_prompting(self):
        prompt = mock.Mock()
        with self.assertRaises(self.enroll.EnrollmentError):
            self.enroll.enroll("unlisted", self.config, prompt=prompt)
        prompt.assert_not_called()

    def test_encryption_failure_preserves_previous_credential_and_hides_stderr(self):
        self.credential.write_bytes(b"previous-fixture")
        self.credential.chmod(0o600)
        with (
            mock.patch.object(self.enroll, "preflight"),
            mock.patch.object(self.enroll.os, "geteuid", return_value=os.getuid()),
            mock.patch.object(self.enroll.subprocess, "run") as run,
        ):
            run.return_value = subprocess.CompletedProcess(
                [], 1, b"", b"fixture-only-password"
            )
            with self.assertRaises(self.enroll.EnrollmentError) as error:
                self.enroll.enroll(
                    "fixture",
                    self.config,
                    prompt=mock.Mock(return_value="fixture-only-password"),
                )
        self.assertNotIn("fixture-only-password", str(error.exception))
        self.assertEqual(self.credential.read_bytes(), b"previous-fixture")

    def test_write_failure_preserves_previous_credential_and_removes_temporary_file(
        self,
    ):
        self.credential.write_bytes(b"previous-fixture")
        self.credential.chmod(0o600)
        with (
            mock.patch.object(
                self.enroll.os, "replace", side_effect=OSError("fixture failure")
            ),
            self.assertRaises(self.enroll.EnrollmentError),
        ):
            self.run_enrollment()
        self.assertEqual(self.credential.read_bytes(), b"previous-fixture")
        self.assertEqual(
            sorted(p.name for p in self.directory.iterdir()), ["fixture.cred"]
        )

    def test_insecure_or_symlink_directory_is_refused(self):
        self.directory.chmod(0o755)
        with self.assertRaises(self.enroll.EnrollmentError):
            self.run_enrollment()
        link = Path(self.tmp.name) / "link"
        link.symlink_to(self.directory, target_is_directory=True)
        self.config["credentialDirectory"] = str(link)
        with self.assertRaises(self.enroll.EnrollmentError):
            self.run_enrollment()

    def test_existing_symlink_credential_is_not_replaced(self):
        target = Path(self.tmp.name) / "unrelated"
        target.write_bytes(b"keep")
        self.credential.symlink_to(target)
        with self.assertRaises(self.enroll.EnrollmentError):
            self.run_enrollment()
        self.assertTrue(self.credential.is_symlink())
        self.assertEqual(target.read_bytes(), b"keep")

    def test_preflight_refuses_noninteractive_and_nonroot(self):
        with (
            mock.patch.object(self.enroll.os, "geteuid", return_value=1000),
            self.assertRaises(self.enroll.EnrollmentError),
        ):
            self.enroll.preflight("fixture", self.config)
        with (
            mock.patch.object(self.enroll.os, "geteuid", return_value=0),
            mock.patch.object(self.enroll.sys.stdin, "isatty", return_value=False),
            self.assertRaises(self.enroll.EnrollmentError),
        ):
            self.enroll.preflight("fixture", self.config)

    def test_preflight_checks_secure_boot_tpm_and_booted_generation(self):
        good = b"\x06\x00\x00\x00\x01"
        cases = [
            (b"\x06\x00\x00\x00\x00", [Path("/fixture/new")] * 2, 0),
            (good, [Path("/fixture/new"), Path("/fixture/old")], 0),
            (good, [Path("/fixture/new")] * 2, 1),
        ]
        for boot, generations, status in cases:
            with (
                self.subTest(boot=boot, generations=generations, status=status),
                mock.patch.object(self.enroll.os, "geteuid", return_value=0),
                mock.patch.object(self.enroll.sys.stdin, "isatty", return_value=True),
                mock.patch.object(self.enroll.pwd, "getpwnam") as account,
                mock.patch.object(self.enroll, "SECURE_BOOT") as secure_boot,
                mock.patch.object(self.enroll.Path, "resolve", side_effect=generations),
                mock.patch.object(self.enroll.subprocess, "run") as run,
            ):
                account.return_value.pw_uid = 1000
                secure_boot.read_bytes.return_value = boot
                run.return_value = subprocess.CompletedProcess([], status)
                with self.assertRaises(self.enroll.EnrollmentError):
                    self.enroll.preflight("fixture", self.config)

    def test_encryption_timeout_and_empty_ciphertext_preserve_previous_file(self):
        self.credential.write_bytes(b"previous-fixture")
        self.credential.chmod(0o600)
        for outcome in (
            subprocess.TimeoutExpired("fixture", 30),
            subprocess.CompletedProcess([], 0, b"", b""),
        ):
            with (
                self.subTest(outcome=type(outcome).__name__),
                mock.patch.object(self.enroll, "preflight"),
                mock.patch.object(self.enroll.subprocess, "run") as run,
            ):
                if isinstance(outcome, Exception):
                    run.side_effect = outcome
                else:
                    run.return_value = outcome
                with self.assertRaises(self.enroll.EnrollmentError):
                    self.enroll.enroll(
                        "fixture",
                        self.config,
                        prompt=mock.Mock(return_value="fixture-only-password"),
                    )
            self.assertEqual(self.credential.read_bytes(), b"previous-fixture")

    def test_strict_umask_still_produces_readable_private_credential(self):
        previous = os.umask(0o777)
        try:
            self.run_enrollment()
        finally:
            os.umask(previous)
        self.assertEqual(self.credential.stat().st_mode & 0o777, 0o600)

    def test_cli_refuses_password_prompt_without_echo_control(self):
        with (
            mock.patch.object(
                self.enroll.sys, "argv", ["kwallet-tpm-enroll", "fixture"]
            ),
            mock.patch.object(
                self.enroll.Path, "read_text", return_value=json.dumps(self.config)
            ),
            mock.patch.object(self.enroll.resource, "setrlimit"),
            mock.patch.object(
                self.enroll,
                "enroll",
                side_effect=self.enroll.getpass.GetPassWarning(
                    "fixture echo unavailable"
                ),
            ),
            mock.patch.object(self.enroll.sys, "stderr", new_callable=io.StringIO),
        ):
            self.assertEqual(self.enroll.main(), 1)

    def test_unsafe_policy_is_rejected_before_prompting(self):
        for pcrs in ([], [7], [4], [4, 7, 24]):
            with self.subTest(pcrs=pcrs):
                self.config["pcrs"] = pcrs
                with self.assertRaises(self.enroll.EnrollmentError):
                    self.run_enrollment()


class PamTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="kwallet-pam-test-")
        cls.addClassCleanup(cls.tmp.cleanup)
        cls.base = Path(cls.tmp.name)
        cls.directory = cls.base / "credentials"
        cls.directory.mkdir(mode=0o700)
        cls.helper = cls.base / "fake-creds"
        cls.helper.write_text(
            "#!" + shutil.which("python3") + "\n"
            "import json, os, sys, time\n"
            "from pathlib import Path\n"
            f"Path({str(cls.base / 'call')!r}).write_text(json.dumps(sys.argv[1:]))\n"
            "mode = sys.stdin.read().strip()\n"
            "if mode == 'fail':\n"
            "    print('fixture-only-password', file=sys.stderr)\n"
            "    sys.exit(1)\n"
            "if mode == 'hang': time.sleep(20)\n"
            "data = {'success': b'fixture-only-password', 'empty': b'',\n"
            "        'nul': b'fixture-only-password\\x00tail', 'large': b'x' * 4097,\n"
            "        'hang': b''}[mode]\n"
            "sys.stdout.buffer.write(data)\n"
        )
        cls.helper.chmod(0o755)
        prefix = Path(os.environ["PAM_PREFIX"])
        cc = os.environ.get("CC", "cc")
        flags = ["-Wall", "-Wextra", "-Werror", "-I" + str(prefix / "include")]
        links = [
            "-L" + str(prefix / "lib"),
            "-Wl,-rpath," + str(prefix / "lib"),
            "-lpam",
        ]
        fixture = ROOT / "tests" / "kwallet_tpm_pam_fixture.c"
        cls.bridge = cls.base / "pam_kwallet_tpm.so"
        cls.capture = cls.base / "pam_fixture.so"
        cls.driver = cls.base / "pam-driver"
        header = cls.base / "config.h"
        header.write_text(
            "#define CREDENTIAL_OWNER_UID geteuid()\n"
            f"#define CREDENTIAL_DIRECTORY {json.dumps(str(cls.directory))}\n"
            f"#define SYSTEMD_CREDS {json.dumps(str(cls.helper))}\n"
            '#define ALLOWED_USERS { "fixture", NULL }\n'
            "#define DECRYPT_TIMEOUT_MS 250\n"
        )
        for argv in (
            [
                cc,
                *flags,
                "-shared",
                "-fPIC",
                "-include",
                str(header),
                str(PACKAGE / "pam_kwallet_tpm.c"),
                "-o",
                str(cls.bridge),
                *links,
            ],
            [
                cc,
                *flags,
                "-shared",
                "-fPIC",
                "-DPAM_FIXTURE_MODULE",
                str(fixture),
                "-o",
                str(cls.capture),
                *links,
            ],
            [cc, *flags, str(fixture), "-o", str(cls.driver), *links],
        ):
            subprocess.run(argv, check=True, capture_output=True)
        cls.permit = prefix / "lib/security/pam_permit.so"
        cls.deny = prefix / "lib/security/pam_deny.so"

    def setUp(self):
        self.credential = self.directory / "fixture.cred"
        self.credential.unlink(missing_ok=True)
        (self.base / "call").unlink(missing_ok=True)

    def attempt(
        self,
        mode=None,
        *,
        user="fixture",
        service="sddm-autologin",
        denied=False,
        seed=False,
    ):
        if mode:
            self.credential.write_text(mode)
            self.credential.chmod(0o600)
        lines = [f"auth required {self.deny if denied else self.permit}"]
        if seed:
            lines.append(f"auth optional {self.capture} seed")
        lines += [
            f"auth [success=ok default=1] {self.bridge}",
            f"auth optional {self.capture} wallet",
            f"auth optional {self.bridge} clear",
            f"auth optional {self.capture} after",
        ]
        (self.base / service).write_text("\n".join(lines) + "\n")
        result = subprocess.run(
            [str(self.driver), str(self.base), service, user],
            capture_output=True,
            text=True,
            check=True,
            timeout=3,
        )
        self.assertNotIn("fixture-only-password", result.stdout + result.stderr)
        self.assertIn("prompts=0", result.stdout)
        return result.stdout

    def test_success_reaches_wallet_and_clears_token(self):
        output = self.attempt("success")
        self.assertIn("result=0", output)
        self.assertIn("seen=yes after=clear", output)
        argv = json.loads((self.base / "call").read_text())
        self.assertEqual(argv[:2], ["decrypt", "--no-ask-password"])
        self.assertIn("--name=kwallet-tpm-fixture", argv)
        self.assertNotIn("fixture-only-password", " ".join(argv))

    def test_unavailable_credential_skips_wallet_without_prompting(self):
        self.assertIn("seen=- after=clear", self.attempt())
        self.assertFalse((self.base / "call").exists())

    def test_failed_malformed_and_oversized_output_fall_back(self):
        for mode in ("fail", "empty", "nul", "large"):
            with self.subTest(mode=mode):
                output = self.attempt(mode)
                self.assertIn("result=0", output)
                self.assertIn("seen=- after=clear", output)

    def test_timeout_is_bounded_and_falls_back(self):
        start = time.monotonic()
        self.assertIn("seen=- after=clear", self.attempt("hang"))
        self.assertLess(time.monotonic() - start, 2)

    def test_unauthorized_user_or_service_never_decrypts(self):
        for args in ({"user": "unlisted"}, {"service": "login"}):
            with self.subTest(args=args):
                output = self.attempt("success", **args)
                self.assertIn("seen=- after=clear", output)
                self.assertFalse((self.base / "call").exists())

    def test_existing_token_is_preserved(self):
        self.assertIn("seen=- after=existing", self.attempt("success", seed=True))
        self.assertFalse((self.base / "call").exists())

    def test_deny_decision_cannot_be_changed_by_successful_unlock(self):
        output = self.attempt("success", denied=True)
        self.assertNotIn("result=0", output)
        self.assertIn("after=clear", output)

    def test_insecure_or_symlink_credential_is_not_decrypted(self):
        self.credential.write_text("success")
        self.credential.chmod(0o644)
        self.assertIn("seen=- after=clear", self.attempt())
        self.assertFalse((self.base / "call").exists())
        self.credential.unlink()
        target = self.base / "unrelated"
        target.write_text("success")
        target.chmod(0o600)
        self.credential.symlink_to(target)
        self.assertIn("seen=- after=clear", self.attempt())
        self.assertFalse((self.base / "call").exists())


if __name__ == "__main__":
    unittest.main()
