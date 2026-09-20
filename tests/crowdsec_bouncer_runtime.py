"""Exercise the actual Traefik/Yaegi plugin with synthetic LAPI and HTTP traffic.
Run outside the Nix build sandbox (requires loopback sockets).
"""

import argparse
import http.server
import json
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.request


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--traefik", required=True)
    parser.add_argument("--plugin", required=True)
    args = parser.parse_args()
    metrics = []
    appsec_requests = []
    backend_bodies = []
    appsec_failure = threading.Event()
    unavailable = threading.Event()

    class API(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_GET(self):
            if self.path == "/appsec":
                appsec_requests.append(dict(self.headers))
                self.send_response(500 if appsec_failure.is_set() else 200)
                self.end_headers()
                return
            if unavailable.is_set():
                self.send_error(503)
                return
            self.send_response(200)
            self.end_headers()
            self.wfile.write(
                json.dumps(
                    {
                        "new": [
                            {
                                "id": 42,
                                "origin": "lists",
                                "scenario": "fixture-list",
                                "type": "ban",
                                "scope": "Ip",
                                "value": "198.51.100.42",
                                "duration": "1h",
                            }
                        ],
                        "deleted": [],
                    }
                ).encode()
            )

        def do_POST(self):
            if self.path.startswith("/probe"):
                backend_bodies.append(
                    self.rfile.read(int(self.headers["Content-Length"]))
                )
                self.send_response(200)
                self.end_headers()
                return
            metrics.append(
                json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            )
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"{}")

    api = http.server.ThreadingHTTPServer(("127.0.0.1", 0), API)
    thread = threading.Thread(target=api.serve_forever, daemon=True)
    thread.start()
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        plugin = (
            root
            / "plugins-local/src/github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin"
        )
        plugin.parent.mkdir(parents=True)
        plugin.symlink_to(args.plugin)
        dynamic = {
            "http": {
                "routers": {
                    "fixture": {
                        "rule": "PathPrefix(`/`)",
                        "entryPoints": ["web"],
                        "service": "fixture",
                        "middlewares": ["crowdsec"],
                    }
                },
                "services": {
                    "fixture": {
                        "loadBalancer": {
                            "servers": [{"url": f"http://127.0.0.1:{api.server_port}"}]
                        }
                    }
                },
                "middlewares": {
                    "crowdsec": {
                        "plugin": {
                            "bouncer": {
                                "enabled": True,
                                "crowdsecMode": "stream",
                                "crowdsecLapiHost": f"127.0.0.1:{api.server_port}",
                                "crowdsecLapiKey": "fixture",
                                "crowdsecAppsecEnabled": True,
                                "crowdsecAppsecHost": f"127.0.0.1:{api.server_port}",
                                "crowdsecAppsecPath": "/appsec",
                                "crowdsecAppsecBodyLimit": 0,
                                "crowdsecAppsecFailureBlock": False,
                                "crowdsecAppsecUnreachableBlock": False,
                                "forwardedHeadersTrustedIPs": ["127.0.0.1/32"],
                                "updateIntervalSeconds": 1,
                                "metricsUpdateIntervalSeconds": 1,
                            }
                        }
                    }
                },
            }
        }
        (root / "dynamic.yaml").write_text(json.dumps(dynamic))
        static = {
            "entryPoints": {
                "web": {
                    "address": f"127.0.0.1:{port}",
                    "forwardedHeaders": {"trustedIPs": ["127.0.0.1/32"]},
                }
            },
            "experimental": {
                "localPlugins": {
                    "bouncer": {
                        "moduleName": "github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin"
                    }
                }
            },
            "providers": {"file": {"filename": str(root / "dynamic.yaml")}},
        }
        (root / "static.json").write_text(json.dumps(static))
        with (root / "output").open("w") as log:
            proc = subprocess.Popen(
                [args.traefik, "--configfile=" + str(root / "static.json")],
                cwd=root,
                stdout=log,
                stderr=subprocess.STDOUT,
            )

            def request(ip, data=None):
                req = urllib.request.Request(
                    f"http://127.0.0.1:{port}/probe?token=SECRET",
                    headers={"X-Forwarded-For": ip, "User-Agent": "fixture-agent"},
                    data=data,
                )
                try:
                    with urllib.request.urlopen(req, timeout=2) as response:
                        return response.status
                except urllib.error.HTTPError as exc:
                    return exc.code

            try:
                for _ in range(100):
                    if proc.poll() is not None:
                        raise AssertionError((root / "output").read_text())
                    try:
                        if request("198.51.100.43") == 200:
                            break
                    except (OSError, urllib.error.URLError):
                        pass
                    time.sleep(0.1)
                else:
                    raise AssertionError(
                        "Traefik not ready: " + (root / "output").read_text()
                    )
                upload = b"fixture-upload" * 10000
                assert request("198.51.100.43", upload) == 200
                assert backend_bodies[-1] == upload, "AppSec changed the upload body"
                assert appsec_requests, "No requests reached AppSec"
                headers = {k.lower(): v for k, v in appsec_requests[-1].items()}
                assert headers["x-crowdsec-appsec-ip"] == "198.51.100.43", headers
                appsec_failure.set()
                assert request("198.51.100.43") == 200, (
                    "Observation outage blocked traffic"
                )
                appsec_failure.clear()
                assert request("198.51.100.42") == 403
                for _ in range(50):
                    if "lists:fixture-list" in json.dumps(metrics):
                        break
                    time.sleep(0.1)
                else:
                    raise AssertionError(
                        "No attributed metrics: " + json.dumps(metrics)
                    )
                unavailable.set()
                for _ in range(50):
                    if request("198.51.100.43") == 403:
                        break
                    time.sleep(0.1)
                else:
                    raise AssertionError("Expected fail-closed denial")
                records = []
                for line in (root / "output").read_text().splitlines():
                    try:
                        value = json.loads(line)
                    except ValueError:
                        continue
                    if value.get("event") == "crowdsec_remediation":
                        records.append(value)
                assert any(
                    r["kind"] == "decision"
                    and r["source_ip"] == "198.51.100.42"
                    and r["scenario"] == "fixture-list"
                    for r in records
                ), (records, (root / "output").read_text())
                assert any(r["kind"] == "enforcement_error" for r in records), (
                    records,
                    (root / "output").read_text(),
                )
                assert "SECRET" not in json.dumps(records), (
                    records,
                    (root / "output").read_text(),
                )
                print(
                    "PASS: real Traefik plugin loads, blocks, attributes decisions, reports metrics, distinguishes outages, and omits query secrets"
                )
            finally:
                proc.terminate()
                proc.wait(timeout=10)
                api.shutdown()


if __name__ == "__main__":
    main()
