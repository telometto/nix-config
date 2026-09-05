"""Exercise Traefik's real forwarded-header handling and JSON access logger.

The Nix check supplies the effective Blizzard access-log and entrypoint
settings. All requests, credentials, hostnames, and upstreams here are synthetic.
This does not exercise Cloudflare, the CrowdSec parser/bouncer, or journald.
"""

import argparse
import copy
import http.client
import json
import socket
import subprocess
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


TOKEN = "Bearer synthetic-crowdsec-http-token"
COOKIE = "session=synthetic-crowdsec-http-cookie"
RESPONSE_COOKIE = "session=synthetic-crowdsec-http-response-cookie"
USER_AGENT = "crowdsec-http-regression/1.0"
FORGED_IP = "198.51.100.44"
CLIENT_IP = "203.0.113.17"
CLIENT_IPV6 = "2001:db8::17"
ACCESS_ASSERTION = "synthetic-cloudflare-access-assertion"
MAX_STARTUP_ATTEMPTS = 3


class Backend(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps(
            {key.lower(): value for key, value in self.headers.items()}
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Set-Cookie", RESPONSE_COOKIE)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass


def request(host, port, path, source, forwarded=None):
    headers = {
        "Host": "fixture.example.invalid",
        "User-Agent": USER_AGENT,
        "Authorization": TOKEN,
        "Cookie": COOKIE,
        "X-Test-Private": "synthetic-private-header",
        "Cf-Access-Jwt-Assertion": ACCESS_ASSERTION,
    }
    if forwarded is not None:
        headers.update(
            {
                "X-Forwarded-For": forwarded,
                "X-Real-IP": FORGED_IP,
                "X-Forwarded-Proto": "https",
                "CF-Connecting-IP": FORGED_IP,
            }
        )
    connection = http.client.HTTPConnection(
        host, port, timeout=2, source_address=(source, 0)
    )
    try:
        connection.request("GET", path, headers=headers)
        response = connection.getresponse()
        body = response.read()
        if response.status != 200:
            raise RuntimeError(
                f"{path}: expected 200, received {response.status}: {body!r}"
            )
        assert response.getheader("Set-Cookie") == RESPONSE_COOKIE
        return json.loads(body)
    finally:
        connection.close()


def access_records(path):
    records = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict) and value.get("RequestPath", "").startswith(
            "/case/"
        ):
            records[value["RequestPath"]] = value
    return records


class FixtureStartupFailure(RuntimeError):
    def __init__(self, message, bind_collision):
        super().__init__(message)
        self.bind_collision = bind_collision


def is_bind_collision(output):
    normalized = output.casefold()
    return "bind:" in normalized and (
        "address already in use" in normalized
        or "only one usage of each socket address" in normalized
    )


def stop_process(process):
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def start_traefik(traefik, production, dynamic_file, config_file, output, errors):
    for attempt in range(1, MAX_STARTUP_ATTEMPTS + 1):
        reservations = []
        listeners = []
        process = None
        try:
            # Reservations must be released before Traefik starts; retry only
            # the resulting, explicitly reported bind-collision race.
            settings = {
                "accessLog": copy.deepcopy(production["accessLog"]),
                "entryPoints": {},
            }
            # Access logs must continue to use stdout, the production journald path.
            assert not settings["accessLog"].get("filePath")
            assert not settings["accessLog"].get("bufferingSize")
            for name, entrypoint in production["entryPoints"].items():
                for family, host, suffix in [
                    (socket.AF_INET, "127.0.0.1", "v4"),
                    (socket.AF_INET6, "::1", "v6"),
                ]:
                    reservation = socket.socket(family, socket.SOCK_STREAM)
                    reservation.bind((host, 0))
                    reservations.append(reservation)
                    port = reservation.getsockname()[1]
                    fixture_name = f"{name}-{suffix}"
                    fixture = copy.deepcopy(entrypoint)
                    fixture["address"] = (
                        f"[{host}]:{port}"
                        if family == socket.AF_INET6
                        else f"{host}:{port}"
                    )
                    settings["entryPoints"][fixture_name] = fixture
                    listeners.append((fixture_name, host, port))

            settings["providers"] = {
                "file": {"filename": str(dynamic_file), "watch": False}
            }
            settings["global"] = {
                "checkNewVersion": False,
                "sendAnonymousUsage": False,
            }
            settings["log"] = {"level": "ERROR"}
            # JSON is valid YAML; this avoids a test-only YAML dependency.
            config_file.write_text(json.dumps(settings), encoding="utf-8")
            for reservation in reservations:
                reservation.close()
            reservations.clear()

            with (
                output.open("w", encoding="utf-8") as stdout,
                errors.open("w", encoding="utf-8") as stderr,
            ):
                process = subprocess.Popen(
                    [traefik, f"--configFile={config_file}"],
                    stdout=stdout,
                    stderr=stderr,
                )

            for name, host, port in listeners:
                deadline = time.monotonic() + 15
                while True:
                    if process.poll() is not None:
                        startup_output = "\n".join(
                            path.read_text(encoding="utf-8")
                            for path in (output, errors)
                            if path.exists()
                        )
                        raise FixtureStartupFailure(
                            "Traefik exited before the fixture became ready",
                            is_bind_collision(startup_output),
                        )
                    try:
                        request(host, port, "/ready", host)
                        break
                    except (OSError, RuntimeError):
                        if time.monotonic() >= deadline:
                            raise
                        time.sleep(0.05)
            return process, listeners
        except FixtureStartupFailure as failure:
            stop_process(process)
            if not failure.bind_collision or attempt == MAX_STARTUP_ATTEMPTS:
                raise
            print(
                f"Traefik listener bind collision on startup attempt {attempt}; "
                "retrying with fresh ports"
            )
        except Exception:
            stop_process(process)
            raise
        finally:
            for reservation in reservations:
                reservation.close()


def exercise(traefik, production, directory):
    backend = ThreadingHTTPServer(("127.0.0.1", 0), Backend)
    backend_thread = threading.Thread(target=backend.serve_forever, daemon=True)
    backend_thread.start()
    process = None
    output = directory / "traefik.stdout"
    errors = directory / "traefik.stderr"
    try:
        entry_points = [
            f"{name}-{suffix}"
            for name in production["entryPoints"]
            for suffix in ("v4", "v6")
        ]
        dynamic = {
            "http": {
                "routers": {
                    "fixture": {
                        "entryPoints": entry_points,
                        "rule": "Host(`fixture.example.invalid`)",
                        "service": "fixture",
                    }
                },
                "services": {
                    "fixture": {
                        "loadBalancer": {
                            "servers": [
                                {"url": f"http://127.0.0.1:{backend.server_port}"}
                            ]
                        }
                    }
                },
            }
        }
        dynamic_file = directory / "dynamic.yaml"
        dynamic_file.write_text(json.dumps(dynamic), encoding="utf-8")
        config_file = directory / "static.yaml"
        process, listeners = start_traefik(
            traefik, production, dynamic_file, config_file, output, errors
        )

        expected = {}
        for name, host, port in listeners:
            # A trusted local cloudflared-style hop supplies the client IP.
            # ClientHost intentionally retains the complete XFF chain: the
            # CrowdSec Traefik parser is responsible for selecting its end.
            for case, forwarded in [
                ("trusted", CLIENT_IP),
                ("trusted-chain", f"{FORGED_IP}, {CLIENT_IP}"),
                ("trusted-ipv6", CLIENT_IPV6),
                ("trusted-chain-ipv6", f"{FORGED_IP}, {CLIENT_IPV6}"),
                ("direct", None),
            ]:
                path = f"/case/{name}/{case}"
                echo = request(host, port, path, host, forwarded)
                incoming_chain = [] if forwarded is None else forwarded.split(", ")
                assert echo["x-forwarded-for"].split(", ") == incoming_chain + [
                    host
                ], echo
                assert echo["authorization"] == TOKEN
                assert echo["cookie"] == COOKIE
                assert echo["x-test-private"] == "synthetic-private-header"
                assert echo["cf-access-jwt-assertion"] == ACCESS_ASSERTION
                expected[path] = (forwarded or host, host, name)
            if host == "127.0.0.1":
                # Linux treats 127/8 as loopback, so this real socket peer
                # tests the untrusted path without namespaces or privileges.
                # It is outside the exact trusted 127.0.0.1/32 contract.
                path = f"/case/{name}/untrusted-forgery"
                echo = request(host, port, path, "127.0.0.2", FORGED_IP)
                assert echo["x-forwarded-for"] == "127.0.0.2", echo
                assert echo["x-real-ip"] == "127.0.0.2", echo
                assert echo["x-forwarded-proto"] == "http", echo
                expected[path] = ("127.0.0.2", "127.0.0.2", name)

        deadline = time.monotonic() + 5
        while True:
            records = access_records(output)
            if set(expected) <= set(records):
                break
            if time.monotonic() >= deadline:
                raise AssertionError(
                    f"Missing access logs: {set(expected) - set(records)}"
                )
            time.sleep(0.05)

        for path, (client, peer, entrypoint) in expected.items():
            record = records[path]
            assert record["ClientHost"] == client, record
            # ClientAddr remains transport provenance, separate from XFF.
            prefix = f"[{peer}]:" if ":" in peer else f"{peer}:"
            assert record["ClientAddr"].startswith(prefix), record
            assert record["entryPointName"] == entrypoint, record
            assert record["RequestHost"] == "fixture.example.invalid", record
            assert record["RequestAddr"] == "fixture.example.invalid", record
            assert record["RequestMethod"] == "GET", record
            assert record["RequestProtocol"] == "HTTP/1.1", record
            assert record["DownstreamStatus"] == 200, record
            assert record["DownstreamContentSize"] > 0, record
            assert record["Duration"] >= 0, record
            assert record["RouterName"] == "fixture@file", record
            assert record["ServiceName"] == "fixture@file", record
            assert record["ServiceAddr"] == f"127.0.0.1:{backend.server_port}", record
            assert record["time"], record
            assert record["request_User-Agent"] == USER_AGENT, record
            logged_headers = {
                key
                for key in record
                if key.startswith(("request_", "origin_", "downstream_"))
            }
            assert logged_headers == {"request_User-Agent"}, logged_headers
            encoded = json.dumps(record)
            for private_value in (
                TOKEN,
                COOKIE,
                RESPONSE_COOKIE,
                "synthetic-private-header",
                ACCESS_ASSERTION,
            ):
                assert private_value not in encoded, record
        print(
            f"Passed {len(expected)} real Traefik access-log "
            "and forwarded-header cases"
        )
    except Exception:
        for path in (output, errors):
            if path.exists():
                print(f"{path.name}:\n{path.read_text(encoding='utf-8')}")
        raise
    finally:
        stop_process(process)
        backend.shutdown()
        backend.server_close()
        backend_thread.join(timeout=5)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--traefik", required=True)
    parser.add_argument("--settings", type=Path, required=True)
    args = parser.parse_args()
    production = json.loads(args.settings.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory(prefix="crowdsec-http-") as temporary:
        exercise(args.traefik, production, Path(temporary))


if __name__ == "__main__":
    main()
