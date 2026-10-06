"""Run rendered firewall scripts against a packet and iptables command model.

This verifies reload/rotation/failure behavior before Tailscale's unconditional
input acceptance, without claiming live kernel or Tailscale validation.
"""

import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
from tempfile import TemporaryDirectory


def verdict(
    state,
    family="ip4",
    source="100.116.146.113",
    interface="tailscale0",
    destination="100.67.190.43",
    port=None,
    local=True,
):
    if port is None:
        port = int(os.environ["SANDFLY_PORT"])

    def walk(chain):
        for rule in state[family][chain]:
            matches = {
                "-i": interface,
                "-s": f"{source}/32",
                "-d": f"{destination}/32",
                "--dport": str(port),
                "-p": "tcp",
            }
            if any(
                flag in rule and rule[rule.index(flag) + 1] != value
                for flag, value in matches.items()
            ):
                continue
            if "--dst-type" in rule and not local:
                continue
            target = rule[rule.index("-j") + 1]
            if target in ("DROP", "RETURN"):
                return target
            if walk(target) == "DROP":
                return "DROP"
        return "RETURN"

    # Model Tailscale accepting a packet after it passes raw PREROUTING.
    return "DROP" if walk("PREROUTING") == "DROP" else "ACCEPT"


def command(family, args):
    assert args[:3] == ["-w", "-t", "raw"], args
    action, chain, *rule = args[3:]
    if os.environ.get("SANDFLY_FAIL") == f"{action} {chain}":
        return 1
    path = Path(os.environ["SANDFLY_STATE"])
    state = json.loads(path.read_text())
    chains = state[family]
    if action == "-N":
        if chain in chains:
            return 1
        chains[chain] = []
    elif action == "-F":
        chains[chain] = []
    elif action == "-A":
        chains[chain].append(rule)
    elif action == "-I":
        position = int(rule.pop(0)) - 1
        chains[chain].insert(position, rule)
    elif action == "-C":
        return 0 if rule in chains[chain] else 1
    elif action == "-D":
        if rule not in chains[chain]:
            return 1
        chains[chain].remove(rule)
    else:
        raise ValueError(args)
    path.write_text(json.dumps(state))
    # Inspect every mutation, including intermediate chain construction:
    # unauthorized sources must never get past Tailscale's earlier acceptance.
    allowed = os.environ["SANDFLY_ALLOWED"]
    for peer in ("100.116.146.113", "100.99.88.77", "100.90.0.1"):
        if peer != allowed:
            assert verdict(state, source=peer) == "DROP", (args, peer, state)
    assert verdict(state, interface="eth0") == "DROP", (args, state)
    return 0


def main(current, stop, rotated, port):
    os.environ["SANDFLY_PORT"] = str(port)
    with TemporaryDirectory() as directory:
        root = Path(directory)
        state_path = root / "state.json"
        unrelated = ["-p", "tcp", "--dport", "8096", "-j", "DROP"]
        state_path.write_text(
            json.dumps({"ip4": {"PREROUTING": [unrelated]}, "ip6": {"PREROUTING": []}})
        )
        for family, name in (("ip4", "iptables"), ("ip6", "ip6tables")):
            wrapper = root / name
            wrapper.write_text(
                "#!/bin/sh\nexec python3 "
                + shlex.quote(str(Path(__file__).resolve()))
                + f' mock {family} "$@"\n'
            )
            wrapper.chmod(0o755)
        env = os.environ | {
            "PATH": f"{root}:{os.environ['PATH']}",
            "SANDFLY_STATE": str(state_path),
            "SANDFLY_ALLOWED": "100.116.146.113",
        }

        def state():
            return json.loads(state_path.read_text())

        def run(script, *, allowed="100.116.146.113", failure=None):
            effective_env = env | {"SANDFLY_ALLOWED": allowed}
            if failure:
                effective_env["SANDFLY_FAIL"] = failure
            result = subprocess.run(
                ["bash", "-e", script],
                env=effective_env,
                capture_output=True,
                text=True,
            )
            assert (result.returncode != 0) == bool(failure), result.stderr

        def verify(allowed=None):
            actual = state()
            for peer in ("100.116.146.113", "100.99.88.77", "100.90.0.1"):
                assert verdict(actual, source=peer) == (
                    "ACCEPT" if peer == allowed else "DROP"
                )
                assert verdict(actual, family="ip6", source=peer) == "DROP"
            assert verdict(actual, interface="eth0") == "DROP"
            assert verdict(actual, destination="192.168.2.10") == "DROP"
            assert verdict(actual, port=22) == "ACCEPT"
            assert verdict(actual, local=False, source="100.90.0.1") == "ACCEPT"
            assert unrelated in actual["ip4"]["PREROUTING"]

        run(current)
        verify("100.116.146.113")
        run(stop)
        verify()
        run(current)
        run(current)
        verify("100.116.146.113")
        assert len(state()["ip4"]["PREROUTING"]) == 2
        assert len(state()["ip6"]["PREROUTING"]) == 1
        run(rotated, allowed="100.99.88.77")
        verify("100.99.88.77")
        run(current, failure="-A SANDFLY_SSH")
        verify()
        run(current)
        verify("100.116.146.113")
        run(stop)
        run(stop)
        verify()
        run(current)
        verify("100.116.146.113")


if __name__ == "__main__":
    if sys.argv[1] == "mock":
        sys.exit(command(sys.argv[2], sys.argv[3:]))
    main(*sys.argv[1:])
