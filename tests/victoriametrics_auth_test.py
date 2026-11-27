"""Exercise the runtime auth renderer and real vmauth with synthetic credentials.

VMAUTH_BINARY must point at the VictoriaMetrics package being deployed. The
backend intentionally accepts every path when its own credential is present:
any missing vmauth route restriction therefore becomes observable here.
"""

import base64
import http.client
import os
from pathlib import Path
import queue
import shlex
import shutil
import socket
import stat
import subprocess
import tempfile
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qsl, urlsplit


RENDERER = Path(
    os.environ.get(
        "VICTORIAMETRICS_AUTH_RENDERER",
        Path(__file__).resolve().parents[1] / "lib/victoriametrics-auth.py",
    )
)
VMAUTH = os.environ.get("VMAUTH_BINARY", "vmauth")
WRITER_PASSWORD = "synthetic-writer-password"
QUERY_PASSWORD = 'synthetic-query-"\\:# %{DO_NOT_EXPAND} 🔐æ\u0085\u2028\u2029 password'
BACKEND_PASSWORD = "synthetic-backend-password"


def authorization(username, password):
    token = base64.b64encode(f"{username}:{password}".encode()).decode()
    return f"Basic {token}"


class RuntimeFixture(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="victoriametrics-auth-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.credentials = self.root / "credentials"
        self.credentials.mkdir(mode=0o700)
        self.runtime = self.root / "runtime"
        self.runtime.mkdir(mode=0o700)
        self.output = self.runtime / "auth.json"
        for name, value in (
            ("writer-password", WRITER_PASSWORD),
            ("query-password", QUERY_PASSWORD),
            ("backend-password", BACKEND_PASSWORD),
        ):
            path = self.credentials / name
            path.write_text(value + "\n")
            path.chmod(0o400)
        self.environment = {
            **os.environ,
            "CREDENTIALS_DIRECTORY": str(self.credentials),
            "DO_NOT_EXPAND": "incorrect-expanded-password",
        }
        self.backend_url = "http://127.0.0.1:8428"

    def render(self, *extra):
        prestart = os.environ.get("VICTORIAMETRICS_AUTH_PRESTART")
        if prestart:
            # Exercise the actual module-generated startup command in the Nix
            # fixture, changing only its temporary output and backend endpoint.
            command = [
                str(self.output)
                if arg == "/run/victoriametrics-vmauth/auth.json"
                else self.backend_url
                if arg == "http://127.0.0.1:11008"
                else arg
                for arg in shlex.split(Path(prestart).read_text())
            ]
        else:
            command = [
                os.sys.executable,
                str(RENDERER),
                "render",
                "--writer-username",
                "writer",
                "--query-username",
                "reader",
                "--backend-username",
                "backend",
                "--backend-url",
                self.backend_url,
                "--output",
                str(self.output),
                "--vmauth-bin",
                VMAUTH,
            ]
        return subprocess.run(
            [*command, *extra],
            env=self.environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def assertRenderSucceeded(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "")


class RendererTest(RuntimeFixture):
    def test_only_service_user_can_read_generated_configuration(self):
        self.assertRenderSucceeded(self.render())
        self.assertEqual(stat.S_IMODE(self.output.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.runtime.stat().st_mode), 0o700)
        self.assertEqual(list(self.runtime.iterdir()), [self.output])

    def test_bad_passwords_leave_previous_valid_configuration_untouched(self):
        self.assertRenderSucceeded(self.render())
        original = self.output.read_bytes()
        original_inode = self.output.stat().st_ino
        for name in ("writer-password", "query-password", "backend-password"):
            path = self.credentials / name
            valid = path.read_bytes()
            for invalid in (
                b"",
                b"\n",
                b"\x00secret",
                b"two\nlines\n",
                b" space",
                b"\xff",
                "bad-\ufdd0-key".encode(),
                "bad-\ufffe-key".encode(),
                "bad-\U0010ffff-key".encode(),
            ):
                with self.subTest(name=name, invalid=invalid):
                    path.chmod(0o600)
                    path.write_bytes(invalid)
                    result = self.render()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(self.output.read_bytes(), original)
                    self.assertEqual(self.output.stat().st_ino, original_inode)
                    self.assertEqual(list(self.runtime.iterdir()), [self.output])
                    self.assertNotIn("secret", result.stderr)
            path.write_bytes(valid)
            path.chmod(0o400)
        path.unlink()
        self.assertNotEqual(self.render().returncode, 0)
        self.assertEqual(self.output.read_bytes(), original)

    def test_invalid_user_configuration_cannot_replace_valid_configuration(self):
        self.assertRenderSucceeded(self.render())
        original = self.output.read_bytes()
        for option, value in (
            ("--writer-username", ""),
            ("--query-username", "writer"),
            ("--backend-username", "reader"),
            ("--backend-username", "bad:name"),
            ("--backend-url", "http://example.invalid:8428"),
        ):
            with self.subTest(option=option, value=value):
                self.assertNotEqual(self.render(option, value).returncode, 0)
                self.assertEqual(self.output.read_bytes(), original)

    def test_reused_role_passwords_cannot_replace_valid_configuration(self):
        self.assertRenderSucceeded(self.render())
        original = self.output.read_bytes()
        for source, target in (
            ("writer-password", "query-password"),
            ("writer-password", "backend-password"),
            ("query-password", "backend-password"),
        ):
            with self.subTest(source=source, target=target):
                path = self.credentials / target
                valid = path.read_bytes()
                path.chmod(0o600)
                path.write_bytes((self.credentials / source).read_bytes())
                try:
                    result = self.render()
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(self.output.read_bytes(), original)
                finally:
                    path.write_bytes(valid)
                    path.chmod(0o400)

    def test_failed_binary_validation_preserves_previous_configuration(self):
        self.assertRenderSucceeded(self.render())
        original = self.output.read_bytes()
        # An unavailable or incompatible validator must never publish a candidate.
        result = self.render("--vmauth-bin", str(self.root / "absent-vmauth"))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.output.read_bytes(), original)
        self.assertEqual(list(self.runtime.iterdir()), [self.output])
        incompatible = str(Path(shutil.which(VMAUTH)).with_name("victoria-metrics"))
        result = self.render("--vmauth-bin", incompatible)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.output.read_bytes(), original)
        self.assertEqual(list(self.runtime.iterdir()), [self.output])
        for value in (WRITER_PASSWORD, QUERY_PASSWORD, BACKEND_PASSWORD):
            self.assertNotIn(value, result.stdout + result.stderr)

    def test_insecure_output_directory_is_rejected(self):
        self.runtime.chmod(0o755)
        self.assertNotEqual(self.render().returncode, 0)
        self.assertFalse(self.output.exists())

    def test_backend_password_validation_rejects_empty_and_malformed_files(self):
        path = self.credentials / "basic_auth_password"
        for value, expected in (("valid\n", 0), ("", 1), ("\n", 1), ("two\nlines", 1)):
            with self.subTest(value=value):
                path.write_text(value)
                prestart = os.environ.get("VICTORIAMETRICS_BACKEND_PRESTART")
                command = (
                    ["bash", prestart]
                    if prestart
                    else [
                        os.sys.executable,
                        str(RENDERER),
                        "validate-password",
                        str(path),
                    ]
                )
                result = subprocess.run(
                    command,
                    env=self.environment,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(result.returncode, expected)
                self.assertEqual(result.stdout, "")

    def test_backend_cannot_start_with_a_reused_frontend_password(self):
        path = self.credentials / "basic_auth_password"
        prestart = os.environ.get("VICTORIAMETRICS_BACKEND_PRESTART")
        for password in (WRITER_PASSWORD, QUERY_PASSWORD):
            with self.subTest(password=password):
                path.write_text(password + "\n")
                command = (
                    ["bash", prestart]
                    if prestart
                    else [
                        os.sys.executable,
                        str(RENDERER),
                        "validate-password",
                        str(self.credentials / "writer-password"),
                        str(self.credentials / "query-password"),
                        str(path),
                    ]
                )
                result = subprocess.run(
                    command,
                    env=self.environment,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn(password, result.stdout + result.stderr)


class Backend(BaseHTTPRequestHandler):
    def do_GET(self):
        self.handle_request()

    def do_POST(self):
        self.handle_request()

    def do_DELETE(self):
        self.handle_request()

    def handle_request(self):
        self.rfile.read(int(self.headers.get("Content-Length", 0)))
        self.server.requests.put((self.path, self.headers.get_all("Authorization")))
        if self.headers.get_all("Authorization") != [
            authorization("backend", BACKEND_PASSWORD)
        ]:
            self.send_response(401)
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"status":"success","data":[]}')

    def log_message(self, *_args):
        pass


class AuthorityTest(RuntimeFixture):
    def setUp(self):
        super().setUp()
        self.backend = ThreadingHTTPServer(("127.0.0.1", 0), Backend)
        self.backend.requests = queue.Queue()
        thread = threading.Thread(target=self.backend.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(self.backend.server_close)
        self.addCleanup(self.backend.shutdown)
        self.backend_url = f"http://127.0.0.1:{self.backend.server_port}"
        self.assertRenderSucceeded(self.render())
        with socket.socket() as port_socket:
            port_socket.bind(("127.0.0.1", 0))
            self.port = port_socket.getsockname()[1]
        self.internal_socket = self.runtime / "internal.sock"
        self.log = (self.runtime / "vmauth.log").open("w+")
        self.addCleanup(self.log.close)
        self.process = subprocess.Popen(
            [
                VMAUTH,
                f"-auth.config={self.output}",
                f"-httpListenAddr=127.0.0.1:{self.port}",
                "-httpInternalListenAddr=unix:internal.sock",
                "-http.maxGracefulShutdownDuration=1s",
                "-loggerLevel=ERROR",
            ],
            stdout=self.log,
            stderr=self.log,
            env=self.environment,
            umask=0o077,
            cwd=self.runtime,
        )
        self.addCleanup(self.stop_vmauth)
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                self.log.seek(0)
                self.fail(f"vmauth exited during startup: {self.log.read()}")
            try:
                if (
                    self.request("/api/v1/query", None)[0] == 401
                    and self.internal_socket.exists()
                ):
                    return
            except OSError:
                pass
            time.sleep(0.02)
        self.fail("vmauth did not become ready")

    def stop_vmauth(self):
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=5)

    def request(self, path, role="writer", method="GET", headers=(), body=None):
        connection = http.client.HTTPConnection("127.0.0.1", self.port, timeout=3)
        try:
            connection.putrequest(method, path)
            if role is not None:
                password = {
                    "writer": WRITER_PASSWORD,
                    "reader": QUERY_PASSWORD,
                    "backend": BACKEND_PASSWORD,
                }[role]
                connection.putheader("Authorization", authorization(role, password))
            for name, value in headers:
                connection.putheader(name, value)
            if body is not None:
                connection.putheader("Content-Length", str(len(body)))
            connection.endheaders(body)
            response = connection.getresponse()
            return response.status, response.read()
        finally:
            connection.close()

    def assertAllowed(self, path, role, **kwargs):
        status, _body = self.request(path, role, **kwargs)
        self.assertEqual(status, 200, (role, path, status))
        backend_path, headers = self.backend.requests.get_nowait()
        self.assertEqual(urlsplit(backend_path).path, urlsplit(path).path)
        self.assertEqual(
            sorted(parse_qsl(urlsplit(backend_path).query)),
            sorted(parse_qsl(urlsplit(path).query)),
        )
        self.assertEqual(headers, [authorization("backend", BACKEND_PASSWORD)])

    def assertDenied(self, path, role, **kwargs):
        self.assertTrue(self.backend.requests.empty())
        status, _body = self.request(path, role, **kwargs)
        self.assertIn(status, (400, 401, 403, 404), (role, path, status))
        self.assertTrue(self.backend.requests.empty(), (role, path))

    def test_writer_can_only_remote_write(self):
        self.assertAllowed(
            "/api/v1/write", "writer", method="POST", body=b"synthetic-remote-write"
        )
        for path in (
            "/api/v1/query?query=up",
            "/api/v1/query_range?query=up&start=1&end=2&step=1",
            "/api/v1/labels",
            "/api/v1/label/job/values",
            "/api/v1/series?match%5B%5D=up",
            "/api/v1/metadata",
            "/api/v1/status/buildinfo",
            "/api/v1/import",
        ):
            with self.subTest(path=path):
                self.assertDenied(path, "writer")

    def test_grafana_query_label_series_and_metadata_endpoints_work(self):
        for path in (
            "/api/v1/query?query=up",
            "/api/v1/query_range?query=up&start=1&end=2&step=1",
            "/api/v1/labels?match%5B%5D=up",
            "/api/v1/label/__name__/values",
            "/api/v1/label/job/values?match%5B%5D=up",
            "/api/v1/series?match%5B%5D=up",
            "/api/v1/metadata?metric=up",
            "/api/v1/status/buildinfo",
        ):
            for method in ("GET", "POST"):
                with self.subTest(path=path, method=method):
                    self.assertAllowed(path, "reader", method=method)
        self.assertDenied("/api/v1/write", "reader", method="POST")
        self.assertDenied("/api/v1/import", "reader", method="POST")

    def test_neither_frontend_role_can_administrate_the_backend(self):
        for role in ("writer", "reader"):
            for path in (
                "/",
                "/vmui/",
                "/snapshot/create",
                "/snapshot/delete_all",
                "/api/v1/admin/tsdb/delete_series?match%5B%5D=up",
                "/internal/resetRollupResultCache",
                "/api/v1/status/tsdb",
                "/api/v1/status/active_queries",
                "/api/v1/export",
                "/api/v1/query/extra",
            ):
                with self.subTest(role=role, path=path):
                    self.assertDenied(path, role, method="POST")

    def test_internal_endpoints_are_closed_on_the_frontend(self):
        for role in (None, "writer", "reader", "backend"):
            for path in (
                "/-/reload",
                "/flags",
                "/debug/pprof/",
                "/metrics",
                "/health",
                "/ready",
            ):
                with self.subTest(role=role, path=path):
                    self.assertDenied(path, role)
        connection = http.client.HTTPConnection("localhost", timeout=3)
        connection.sock = socket.socket(socket.AF_UNIX)
        connection.sock.settimeout(3)
        # Managed evidence directories may exceed the Unix socket path limit.
        connection.sock.connect(f"/proc/{self.process.pid}/cwd/internal.sock")
        try:
            connection.request("GET", "/metrics")
            response = connection.getresponse()
            self.assertEqual(response.status, 200)
            self.assertIn(b"vmauth_", response.read())
        finally:
            connection.close()
        self.assertEqual(stat.S_IMODE(self.runtime.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE(self.internal_socket.stat().st_mode) & 0o077, 0)

    def test_backend_only_credential_is_invalid_on_the_frontend(self):
        for path in ("/api/v1/write", "/api/v1/query"):
            self.assertDenied(path, "backend", method="POST")
            self.assertDenied(path, None, method="POST")

    def test_header_overrides_cannot_skip_routing_or_pass_frontend_auth_upstream(self):
        for headers in (
            (("Connection", "Authorization"),),
            (("Authorization", authorization("backend", BACKEND_PASSWORD)),),
            (("Authorization", "Basic invalid"),),
            (
                ("X-Original-URL", "/snapshot/create"),
                ("X-Rewrite-URL", "/api/v1/query"),
            ),
        ):
            with self.subTest(headers=headers):
                self.assertAllowed(
                    "/api/v1/write", "writer", method="POST", headers=headers
                )
                self.assertDenied("/api/v1/query", "writer", headers=headers)
        self.assertDenied(
            "/snapshot/create",
            None,
            headers=(("X-Forwarded-User", "reader"), ("X-Auth-Request-User", "reader")),
        )

    def test_path_encodings_cannot_expand_authority(self):
        for role in ("writer", "reader"):
            for path in (
                "/api/v1/write/../admin/tsdb/delete_series",
                "/api/v1/write%2f..%2fadmin%2ftsdb%2fdelete_series",
                "/api/v1/write%252f..%252fadmin%252ftsdb%252fdelete_series",
                "/api/v1/query/../../../snapshot/create",
                "/api/v1/label/..%2f..%2fadmin%2ftsdb%2fdelete_series/values",
                "/api/v1/label/job%2f..%2f..%2f..%2fsnapshot%2fcreate/values",
                "/api/v1/label/%252f..%252fsnapshot%252fcreate/values",
                "/api/v1/label/job;anything/values",
                "/api/v1/query%00/snapshot/create",
                "/api/v1/query%3f/snapshot/create",
                "/api/v1/query%23/snapshot/create",
                "/api/v1/query%5c..%5csnapshot%5ccreate",
                "/API/v1/query",
            ):
                with self.subTest(role=role, path=path):
                    self.assertDenied(path, role)
        self.assertDenied("/api/v1/%71uery", "writer")
        self.assertDenied("/api/v1/%77rite", "reader", method="POST")


if __name__ == "__main__":
    if shutil.which(VMAUTH) is None:
        raise SystemExit("Set VMAUTH_BINARY to the pinned vmauth executable")
    unittest.main()
