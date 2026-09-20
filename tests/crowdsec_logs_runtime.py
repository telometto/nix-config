"""Validate the effective Alloy processing pipeline and Grafana queries locally."""

import argparse
import json
from pathlib import Path
import re
import socket
import subprocess
import tempfile
import time
import urllib.parse
import urllib.request


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--alloy", required=True)
    parser.add_argument("--victorialogs", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("--settings", required=True)
    args = parser.parse_args()
    port, alloy_port = free_port(), free_port()
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        events = root / "events.jsonl"
        records = [
            {
                "event": "crowdsec_remediation",
                "kind": "decision",
                "source_ip": "198.51.100.42",
                "origin": "lists:test",
                "scenario": "test",
                "target_host": "example.test",
                "target_uri": "/probe",
                "decision_id": 42,
            },
            {
                "event": "crowdsec_alert",
                "kind": "local_detection",
                "source_ip": "198.51.100.42",
                "scenario": "http-probing",
                "alert_id": 12,
                "country": "NO",
            },
            {
                "event": "crowdsec_remediation",
                "kind": "enforcement_error",
                "source_ip": "198.51.100.43",
            },
            {
                "event": "crowdsec_alert",
                "kind": "appsec_observation",
                "source_ip": "198.51.100.44",
                "scenario": "crowdsecurity/vpatch-fixture",
                "target_host": "example.test",
            },
            {
                "event": "crowdsec_alert",
                "kind": "local_detection",
                "scenario": "crowdsecurity/ssh-bf",
                "simulated": False,
            },
            {
                "event": "crowdsec_alert",
                "kind": "local_detection",
                "scenario": "crowdsecurity/ssh-bf",
                "simulated": True,
            },
            {"RequestPath": "/private", "Authorization": "SECRET"},
        ]
        events.write_text("\n".join(map(json.dumps, records)) + "\n")
        config = Path(args.config).read_text()
        config = re.sub(r"(?ms)^loki.source.journal.*?^}\n", "", config)
        config = f'''loki.source.file "fixture" {{
 targets = [{{__path__ = "{events}", service = "crowdsec"}}]
 forward_to = [loki.process.crowdsec.receiver]
}}
''' + config.replace("127.0.0.1:9428", f"127.0.0.1:{port}")
        (root / "config.alloy").write_text(config)
        with (
            (root / "vl.log").open("w") as vl_log,
            (root / "alloy.log").open("w") as alloy_log,
        ):
            vl = subprocess.Popen(
                [
                    args.victorialogs,
                    f"-storageDataPath={root}/vl",
                    f"-httpListenAddr=127.0.0.1:{port}",
                    "-retentionPeriod=90d",
                    "-retention.maxDiskSpaceUsageBytes=10GiB",
                    "-storage.minFreeDiskSpaceBytes=1MiB",
                ],
                stdout=vl_log,
                stderr=subprocess.STDOUT,
            )
            alloy = subprocess.Popen(
                [
                    args.alloy,
                    "run",
                    str(root / "config.alloy"),
                    f"--storage.path={root}/alloy",
                    f"--server.http.listen-addr=127.0.0.1:{alloy_port}",
                    "--disable-reporting",
                ],
                stdout=alloy_log,
                stderr=subprocess.STDOUT,
            )

            def query(expr):
                data = urllib.parse.urlencode({"query": expr}).encode()
                with urllib.request.urlopen(
                    f"http://127.0.0.1:{port}/select/logsql/query", data=data, timeout=3
                ) as response:
                    return response.read().decode()

            try:
                for _ in range(100):
                    if vl.poll() is not None or alloy.poll() is not None:
                        raise AssertionError(
                            (root / "vl.log").read_text()
                            + (root / "alloy.log").read_text()
                        )
                    try:
                        output = query('_stream:{service="crowdsec"} | unpack_json')
                        if len(output.strip().splitlines()) == 6:
                            break
                    except OSError:
                        pass
                    time.sleep(0.2)
                else:
                    raise AssertionError(
                        "Events not delivered: " + (root / "alloy.log").read_text()
                    )
                assert "SECRET" not in output, output
                dashboard = json.loads(
                    (
                        Path(__file__).parent.parent
                        / "dashboards/host/blizzard/crowdsec.json"
                    ).read_text()
                )
                for panel in dashboard["panels"][:4] + [dashboard["panels"][-1]]:
                    result = query(panel["targets"][0]["expr"])
                    assert result.strip(), panel["title"]
                for expression in json.loads(Path(args.settings).read_text())[
                    "logAlertQueries"
                ]:
                    result = [json.loads(row) for row in query(expression).splitlines()]
                    assert result, expression
                    counts = result[0]
                    assert (
                        float(counts["failures"]) == 1
                        if "failures" in counts
                        else float(counts["detections"]) == 2
                    ), result
                print(
                    "PASS: Alloy delivers only security events; investigation and notification queries return expected records"
                )
            finally:
                alloy.terminate()
                vl.terminate()
                alloy.wait(timeout=10)
                vl.wait(timeout=10)


if __name__ == "__main__":
    main()
