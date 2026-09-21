"""Test the production observation config against a real isolated CrowdSec engine."""

import argparse
import json
from datetime import datetime, timezone
import re
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import urllib.request


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", required=True)
    parser.add_argument("--settings", required=True)
    args = parser.parse_args()
    settings = json.loads(Path(args.settings).read_text())
    lapi, waf = free_port(), free_port()
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        for directory in (
            "data",
            "hub",
            "patterns",
            "parsers/s00-raw",
            "parsers/s01-parse",
            "parsers/s02-enrich",
            "scenarios",
            "postoverflows/s01-whitelist",
            "appsec-configs",
            "appsec-rules",
            "contexts",
        ):
            (root / directory).mkdir(parents=True, exist_ok=True)

        def write(name, value):
            (root / name).write_text(json.dumps(value))

        (root / "appsec-configs/observe.yaml").write_text(
            Path(settings["appsec"]).read_text()
        )
        write(
            "appsec-rules/base.yaml",
            {
                "name": "crowdsecurity/base-config",
                "seclang_rules": ["SecRuleEngine On\nSecRequestBodyAccess Off"],
            },
        )
        write(
            "appsec-rules/probe.yaml",
            {
                "name": "crowdsecurity/vpatch-fixture",
                "seclang_rules": [
                    'SecRule REQUEST_URI "@beginsWith /crowdsec-fixture" "id:1001,phase:1,deny,status:403,msg:\'fixture\'"'
                ],
            },
        )
        for i, context in enumerate(settings["contexts"]):
            write(f"contexts/{i}.yaml", context)
        # Profiles are YAML documents. JSON is valid YAML for each document.
        (root / "profiles.yaml").write_text(
            "\n---\n".join(map(json.dumps, settings["profiles"]))
        )
        write(
            "acquis.yaml",
            {
                "source": "appsec",
                "listen_addr": f"127.0.0.1:{waf}",
                "appsec_configs": ["local/blizzard-observe"],
                "labels": {"type": "appsec"},
            },
        )
        write(
            "config.yaml",
            {
                "common": {
                    "daemonize": False,
                    "log_media": "stdout",
                    "log_level": "info",
                },
                "config_paths": {
                    "config_dir": tmp,
                    "data_dir": str(root / "data"),
                    "hub_dir": str(root / "hub"),
                    "index_path": str(root / "hub/.index.json"),
                },
                "crowdsec_service": {
                    "acquisition_path": str(root / "acquis.yaml"),
                    "console_context_path": str(root / "context.yaml"),
                },
                "db_config": {
                    "type": "sqlite",
                    "db_path": str(root / "data/crowdsec.db"),
                },
                "api": {
                    "client": {"credentials_path": str(root / "credentials.yaml")},
                    "server": {
                        "listen_uri": f"127.0.0.1:{lapi}",
                        "profiles_path": str(root / "profiles.yaml"),
                        "console_path": str(root / "console.yaml"),
                    },
                },
                "prometheus": {"enabled": False},
            },
        )
        write(
            "console.yaml",
            {
                "share_context": False,
                "share_custom": False,
                "share_tainted": False,
                "share_manual_decisions": False,
            },
        )
        write("context.yaml", {})
        write("simulation.yaml", {"simulation": False})
        write("hub/.index.json", {})

        def cli(*arguments):
            return subprocess.check_output(
                [
                    args.package + "/bin/cscli",
                    "-c",
                    str(root / "config.yaml"),
                    *arguments,
                ],
                stderr=subprocess.STDOUT,
            ).decode()

        try:
            cli(
                "machines",
                "add",
                "fixture",
                "--password",
                "fixture-local-only",
                "--file",
                str(root / "credentials.yaml"),
                "--url",
                f"http://127.0.0.1:{lapi}",
            )
            key = cli("bouncers", "add", "fixture", "-o", "raw").strip()
            with (root / "engine.log").open("w") as log:
                proc = subprocess.Popen(
                    [args.package + "/bin/crowdsec", "-c", str(root / "config.yaml")],
                    stdout=log,
                    stderr=subprocess.STDOUT,
                )
                try:
                    for _ in range(100):
                        if proc.poll() is not None:
                            raise AssertionError("Engine exited")
                        try:
                            req = urllib.request.Request(
                                f"http://127.0.0.1:{waf}/",
                                headers={
                                    "X-Crowdsec-Appsec-Api-Key": key,
                                    "X-Crowdsec-Appsec-Ip": "198.51.100.42",
                                    "X-Crowdsec-Appsec-Uri": "/crowdsec-fixture?token=SECRET",
                                    "X-Crowdsec-Appsec-Host": "example.test",
                                    "X-Crowdsec-Appsec-Verb": "GET",
                                },
                            )
                            with urllib.request.urlopen(req, timeout=2) as response:
                                assert response.status == 200
                            break
                        except OSError:
                            time.sleep(0.1)
                    else:
                        raise AssertionError("AppSec did not become ready")
                    for _ in range(150):
                        alerts = json.loads(cli("alerts", "list", "-o", "json")) or []
                        if alerts:
                            break
                        time.sleep(0.1)
                    assert alerts, "Expected retained WAF observation"
                    assert alerts[0]["kind"] == "waf", alerts
                    assert not (
                        json.loads(cli("decisions", "list", "-o", "json")) or []
                    ), "Observation created an IP decision"
                    context = {m["key"]: m["value"] for m in alerts[0].get("meta", [])}
                    assert "example.test" in context.get("target_host", ""), context
                    assert "SECRET" not in context.get("target_uri", ""), context

                    def api(path, payload=None, headers=None):
                        req = urllib.request.Request(
                            f"http://127.0.0.1:{lapi}{path}",
                            data=json.dumps(payload).encode()
                            if payload is not None
                            else None,
                            headers={
                                "Content-Type": "application/json",
                                **(headers or {}),
                            },
                        )
                        with urllib.request.urlopen(req, timeout=5) as response:
                            return json.load(response)

                    token = api(
                        "/v1/watchers/login",
                        {"machine_id": "fixture", "password": "fixture-local-only"},
                    )["token"]
                    for expected_hours in (4, 8, 12, 16, 20, 24, 24):
                        now = datetime.now(timezone.utc).isoformat()
                        api(
                            "/v1/alerts",
                            [
                                {
                                    "scenario": "local/fixture",
                                    "scenario_hash": "fixture",
                                    "scenario_version": "1",
                                    "message": "fixture",
                                    "events_count": 1,
                                    "capacity": 1,
                                    "leakspeed": "1s",
                                    "start_at": now,
                                    "stop_at": now,
                                    "simulated": False,
                                    "remediation": True,
                                    "source": {
                                        "scope": "Ip",
                                        "value": "198.51.100.43",
                                        "ip": "198.51.100.43",
                                    },
                                    "events": [],
                                }
                            ],
                            {"Authorization": "Bearer " + token},
                        )
                        decisions = api(
                            "/v1/decisions?ip=198.51.100.43", headers={"X-Api-Key": key}
                        )
                        durations = [
                            sum(
                                float(n) * {"h": 3600, "m": 60, "s": 1}[u]
                                for n, u in re.findall(
                                    r"([0-9.]+)([hms])", d["duration"]
                                )
                            )
                            for d in decisions
                        ]
                        assert (
                            expected_hours * 3600 - 15
                            <= max(durations)
                            <= expected_hours * 3600
                        ), (expected_hours, decisions)
                    print(
                        "PASS: AppSec observation permits matches without bans; production profile escalates 4h to a 24h ceiling"
                    )
                finally:
                    proc.terminate()
                    proc.wait(timeout=10)
        except Exception:
            if (root / "engine.log").exists():
                print((root / "engine.log").read_text())
            raise


if __name__ == "__main__":
    main()
