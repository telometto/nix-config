"""Exercise rendered Jellyfin firewall scripts with a secretless iptables model.

The model records actual command effects so reload and failure behavior can be
checked without CAP_NET_ADMIN. It only implements the operations these scripts
use; unsupported commands fail the test.
"""

import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
from tempfile import TemporaryDirectory


def empty_state():
    return {"ip4": {"PREROUTING": []}, "ip6": {"PREROUTING": []}}


def command(family, args):
    if args[:3] != ["-w", "-t", "raw"]:
        raise ValueError(f"unexpected iptables flags: {args}")
    action, chain, *rest = args[3:]
    state_path = Path(os.environ["JELLYFIN_TEST_STATE"])
    state = json.loads(state_path.read_text())
    chains = state[family]

    if action == "-N":
        if chain in chains:
            return 1
        chains[chain] = []
    elif action == "-S":
        if chain not in chains:
            return 1
        print(f"-N {chain}")
        for rule in chains[chain]:
            print(f"-A {chain} {' '.join(rule)}")
    elif action == "-F":
        chains[chain] = []
    elif action == "-A":
        chains[chain].append(rest)
    elif action == "-I":
        index = int(rest.pop(0)) - 1 if rest and rest[0].isdigit() else 0
        chains[chain].insert(index, rest)
    elif action == "-C":
        return 0 if rest in chains[chain] else 1
    elif action == "-D":
        try:
            chains[chain].remove(rest)
        except ValueError:
            return 1
    else:
        raise ValueError(f"unexpected iptables action: {action}")

    state_path.write_text(json.dumps(state))
    return 0


def target(rule):
    return rule[rule.index("-j") + 1]


def verdict(state, family, source, *, local=True, destination="100.85.254.99"):
    def walk(chain):
        for rule in state[family][chain]:
            if "-i" in rule and rule[rule.index("-i") + 1] != "tailscale0":
                continue
            if (
                "--dst-type" in rule
                and (rule[rule.index("--dst-type") + 1] == "LOCAL") != local
            ):
                continue
            if "-s" in rule and rule[rule.index("-s") + 1] != f"{source}/32":
                continue
            if "-d" in rule and rule[rule.index("-d") + 1] != f"{destination}/32":
                continue
            jump_target = target(rule)
            if jump_target == "DROP":
                return "DROP"
            if jump_target == "RETURN":
                return "RETURN"
            result = walk(jump_target)
            if result == "DROP":
                return result
        return "RETURN"

    return "DROP" if walk("PREROUTING") == "DROP" else "ACCEPT"


def verify(state, allowed=None):
    for peer in ("100.116.146.113", "100.99.88.77", "100.100.100.100"):
        expected = "ACCEPT" if peer == allowed else "DROP"
        assert verdict(state, "ip4", peer) == expected, (peer, state)
        assert verdict(state, "ip6", peer) == "DROP", (peer, state)
    # Tailscale's subnet SNAT makes every routed peer appear as 10.100.0.1
    # at the guest, so the host must reject this path before forwarding.
    for peer in ("100.116.146.113", "100.99.88.77", "100.100.100.100"):
        assert (
            verdict(state, "ip4", peer, local=False, destination="10.100.0.72")
            == "DROP"
        ), (peer, state)
    assert verdict(state, "ip4", "100.100.100.100", local=False) == "ACCEPT"


def run(script, env):
    result = subprocess.run(
        ["bash", "-e", script], env=env, capture_output=True, text=True
    )
    assert result.returncode == 0, result.stderr
    return result


def main(paths):
    current, stop, next_peer, disabled = paths
    with TemporaryDirectory() as directory:
        root = Path(directory)
        state_path = root / "state.json"
        state_path.write_text(json.dumps(empty_state()))
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
            "JELLYFIN_TEST_STATE": str(state_path),
        }

        def state():
            return json.loads(state_path.read_text())

        run(disabled, env)
        verify(state())  # first installation stays private
        run(current, env)
        verify(state(), "100.116.146.113")  # peer enabled after private setup
        run(stop, env)
        verify(state())  # firewall reload closes ingress before replacement
        run(current, env)
        run(current, env)
        verify(state(), "100.116.146.113")  # repeated reload is idempotent
        assert len(state()["ip4"]["JELLYFIN_VPS"]) == 2
        assert len(state()["ip4"]["PREROUTING"]) == 2

        run(next_peer, env)
        verify(state(), "100.99.88.77")  # old peer loses access
        run(disabled, env)
        verify(state())  # a stale listener remains blocked
        assert state()["ip4"]["JELLYFIN_VPS"] == [["-j", "DROP"]]

        run(current, env)
        modified = state()
        modified["ip4"]["JELLYFIN_VPS"].insert(0, ["-j", "LOG"])
        state_path.write_text(json.dumps(modified))
        warning = run(current, env)
        assert "Unexpected rule in JELLYFIN_VPS" in warning.stderr
        assert "Jellyfin VPS ingress remains blocked" in warning.stderr
        assert ["-j", "LOG"] in state()["ip4"]["JELLYFIN_VPS"]
        verify(state())  # unexpected logging rule is preserved and denied

        modified = state()
        modified["ip4"]["JELLYFIN_VPS"].remove(["-j", "LOG"])
        modified["ip4"]["JELLYFIN_VPS"].insert(
            0, ["-s", "100.100.100.100/32", "-j", "RETURN"]
        )
        state_path.write_text(json.dumps(modified))
        warning = run(current, env)
        assert "JELLYFIN_VPS has more than one peer rule" in warning.stderr
        assert "Jellyfin VPS ingress remains blocked" in warning.stderr
        assert (
            len([r for r in state()["ip4"]["JELLYFIN_VPS"] if target(r) == "RETURN"])
            == 2
        )
        verify(state())  # unexpected second peer is preserved and denied

        modified = state()
        modified["ip4"]["JELLYFIN_VPS"].remove(
            ["-s", "100.100.100.100/32", "-j", "RETURN"]
        )
        state_path.write_text(json.dumps(modified))
        run(current, env)
        verify(state(), "100.116.146.113")  # recovery clears stale DROP guards
        assert len(state()["ip4"]["PREROUTING"]) == 2


if __name__ == "__main__":
    if sys.argv[1] == "mock":
        sys.exit(command(sys.argv[2], sys.argv[3:]))
    main(sys.argv[1:])
