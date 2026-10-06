#!/usr/bin/env python3
"""Conservative dependency selection and the stable Flake Check gate."""

import argparse
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path

SYSTEM = "x86_64-linux"
LIFECYCLE = "microvm-lifecycle"
CROWDSEC = {"crowdsec-http", "crowdsec-observability"}
MATRIX = {
    "matrix-baseline",
    "matrix-whatsapp-bridge",
    "microvm-publication",
    "blackbox-observability",
    "microvm-network-policy",
}
JELLYFIN = {"jellyfin-firewall", "jellyfin-microvm"}
# This inventory supports selective mappings. Full builds discover Nix attributes.
CHECKS = {
    "formatting",
    "cloudflare-metrics",
    "microvm-publication",
    "matrix-baseline",
    "matrix-whatsapp-bridge",
    "blackbox-observability",
    "crowdsec-http",
    "crowdsec-observability",
    LIFECYCLE,
    "microvm-network-policy",
    "jellyfin-firewall",
    "jellyfin-microvm",
    "libvirt-firmware",
    "sandfly-target",
    "sandfly-runtime",
    "scrutiny",
    "user-accounts",
    "victoriametrics",
}
# Exact file mappings only: new files under auto-loaded trees default to full.
# Shared Traefik, Cloudflared, Prometheus, Grafana, loaders, lib helpers, and
# common VM infrastructure deliberately remain unmapped.
DEPENDENCIES = {
    "modules/services/scripts/cloudflare_metrics.py": {"cloudflare-metrics"},
    "modules/services/cloudflare-metrics.nix": {"cloudflare-metrics"},
    "hosts/blizzard/monitoring/cloudflare-alerts.nix": {"cloudflare-metrics"},
    "dashboards/host/blizzard/cloudflare-overview.json": {"cloudflare-metrics"},
    "modules/services/crowdsec.nix": CROWDSEC | MATRIX,
    "hosts/blizzard/security/crowdsec.nix": CROWDSEC | MATRIX,
    "hosts/blizzard/monitoring/crowdsec.nix": CROWDSEC,
    "hosts/blizzard/monitoring/crowdsec-alerts.nix": CROWDSEC,
    "dashboards/host/blizzard/crowdsec.json": CROWDSEC,
    "modules/services/matrix-synapse.nix": MATRIX,
    "modules/services/matrix-authentication-service.nix": MATRIX,
    "vms/matrix-synapse.nix": MATRIX,
    "vms/matrix-whatsapp.nix": MATRIX,
    "vms/matrix-storage.nix": MATRIX,
    "modules/services/blackbox.nix": {"blackbox-observability"},
    "hosts/blizzard/monitoring/blackbox.nix": {"blackbox-observability"},
    "dashboards/shared/service-availability.json": {"blackbox-observability"},
    "modules/services/jellyfin.nix": JELLYFIN,
    "modules/programs/jellyfin-gpu.nix": JELLYFIN,
    "modules/programs/jellyfin-web-skip-intro.nix": JELLYFIN,
    "vms/jellyfin.nix": JELLYFIN,
    "vms/jellyfin-settings.nix": JELLYFIN,
    "tests/jellyfin-firewall-test.py": {"jellyfin-firewall"},
    "tests/sandfly-ssh-test.py": {"sandfly-target"},
    "tests/sandfly-ssh-validator-test.py": {"sandfly-target"},
    "tests/sandfly-firewall-test.py": {"sandfly-target"},
}
# A check definition is consumed only by that check. CrowdSec definitions and
# Python fixtures select both contracts plus all three external runtime fixtures.
for check in CHECKS - {"formatting", "cloudflare-metrics"}:
    DEPENDENCIES[f"tests/{check}.nix"] = CROWDSEC if check in CROWDSEC else {check}
for fixture in (
    "http",
    "observability",
    "bouncer_runtime",
    "logs_runtime",
    "appsec_runtime",
):
    DEPENDENCIES[f"tests/crowdsec_{fixture}.py"] = CROWDSEC

PREFIX_DEPENDENCIES = {
    "tests/cloudflare_metrics/": {"cloudflare-metrics"},
    "packages/crowdsec-bouncer/": CROWDSEC,
    "packages/crowdsec-observability/": CROWDSEC,
}
# CI control changes are full even if a file extension looks like documentation.
CI_CONTROL = (
    ".github/scripts/",
    ".github/tests/",
    ".github/workflows/flake-check.yml",
    ".github/workflows/flake-check.yaml",
)


def make_plan(checks=(), *, full=False, evaluate=False, reason="changed files"):
    checks = sorted(CHECKS if full else checks)
    return {
        "full": full,
        "evaluate": full or evaluate,
        "checks": checks,
        "grouped": full or evaluate or bool(set(checks) - {LIFECYCLE}),
        "lifecycle": full or LIFECYCLE in checks,
        "crowdsec": full or bool(CROWDSEC.intersection(checks)),
        "reason": reason,
    }


def formattable(path):
    # Keep aligned with treefmt.nix. Workflows and lockfiles are excluded.
    if path.startswith(".github/workflows/") or path.endswith(".lock"):
        return False
    return Path(path).suffix in {
        ".nix",
        ".py",
        ".sh",
        ".bash",
        ".json",
        ".md",
        ".yml",
        ".yaml",
    }


def classify(paths):
    checks = set()
    evaluate = False
    for path in paths:
        if not path or path.startswith("/") or "\\" in path or ".." in path.split("/"):
            return make_plan(full=True, reason="unusable changed path")
        if path == "flake.lock" or path.startswith(CI_CONTROL):
            return make_plan(full=True, reason=f"shared CI/input: {path}")
        if formattable(path):
            checks.add("formatting")
        evaluate |= path.endswith(".nix")
        if path.endswith(".md"):
            # No checks consume Markdown as a runtime input.
            continue
        mapped = DEPENDENCIES.get(path)
        if mapped is None:
            for prefix, dependencies in PREFIX_DEPENDENCIES.items():
                if path.startswith(prefix):
                    mapped = dependencies
                    break
        if mapped is not None:
            checks.update(mapped)
        else:
            return make_plan(full=True, reason=f"unmapped runtime/shared input: {path}")
    return make_plan(checks, evaluate=evaluate)


def git(*args, repo="."):
    return subprocess.check_output(
        ["git", "-C", str(repo), *args], stderr=subprocess.DEVNULL
    ).decode("utf-8")


def changed_paths(event_name, event, repo="."):
    if event_name == "pull_request":
        base = event["pull_request"]["base"]["sha"]
        head = event["pull_request"]["head"]["sha"]
    elif event_name == "push":
        base, head = event["before"], event["after"]
    else:
        raise ValueError("event requires full coverage")
    for sha in (base, head):
        if not re.fullmatch(r"[0-9a-f]{40}", sha) or sha == "0" * 40:
            raise ValueError("missing or invalid diff endpoint")
        git("cat-file", "-e", f"{sha}^{{commit}}", repo=repo)
    if event_name == "pull_request":
        base = git("merge-base", base, head, repo=repo).strip()
    # Disable rename detection: a rename becomes a deletion and an addition,
    # preserving both dependency sets. NUL delimiters preserve unusual filenames.
    output = git(
        "diff", "--no-renames", "--name-only", "-z", base, head, "--", repo=repo
    )
    return output.rstrip("\0").split("\0") if output else []


def event_plan(event_name, event, repo="."):
    if event_name in {"workflow_dispatch", "schedule"}:
        return make_plan(full=True, reason=event_name)
    try:
        paths = changed_paths(event_name, event, repo)
    except (KeyError, TypeError, ValueError, OSError, subprocess.SubprocessError):
        return make_plan(full=True, reason="missing/unusable complete diff")
    return classify(paths)


def validate_plan(plan):
    for key in ("full", "evaluate", "grouped", "lifecycle", "crowdsec"):
        if type(plan.get(key)) is not bool:
            raise ValueError(f"missing/invalid plan field: {key}")
    checks = plan.get("checks")
    if not isinstance(checks, list) or any(
        not isinstance(check, str) or check not in CHECKS for check in checks
    ):
        raise ValueError("invalid selected checks")
    expected = make_plan(checks, full=plan["full"], evaluate=plan["evaluate"])
    for key in ("checks", "grouped", "lifecycle", "crowdsec", "evaluate"):
        if plan[key] != expected[key]:
            raise ValueError(f"inconsistent plan: {key}")


def gate_errors(needs):
    classifier = needs.get("classify", {})
    if classifier.get("result") != "success":
        return ["classifier did not succeed"]
    try:
        plan = json.loads(classifier.get("outputs", {}).get("plan", ""))
        validate_plan(plan)
    except (ValueError, TypeError, AttributeError):
        return ["classifier returned an invalid plan"]
    errors = []
    for job in ("grouped", "lifecycle"):
        expected = "success" if plan[job] else "skipped"
        actual = needs.get(job, {}).get("result", "missing")
        if actual != expected:
            errors.append(f"{job}: expected {expected}, got {actual}")
    return errors


def nix(*args):
    """Capture Nix diagnostics and pass them through the existing redactor."""
    redactor = Path(__file__).with_name("redact-secrets.sh")
    with tempfile.TemporaryFile() as diagnostics:
        try:
            result = subprocess.run(
                ["nix", *args],
                stdout=subprocess.PIPE,
                stderr=diagnostics,
                timeout=60 * 60,
                check=False,
            )
        except subprocess.TimeoutExpired:
            result = None
        diagnostics.seek(0)
        subprocess.run(["bash", str(redactor)], stdin=diagnostics, check=True)
    if result is None or result.returncode:
        raise RuntimeError("Nix command failed or timed out; see redacted diagnostics")
    return result.stdout.decode("utf-8")


def grouped_checks(plan):
    validate_plan(plan)
    if plan["full"]:
        # Build future declarations too, without editing a workflow step list.
        checks = json.loads(
            nix("eval", "--json", f".#checks.{SYSTEM}", "--apply", "builtins.attrNames")
        )
        if (
            not isinstance(checks, list)
            or not checks
            or any(
                not isinstance(check, str) or not re.fullmatch(r"[A-Za-z0-9_-]+", check)
                for check in checks
            )
        ):
            raise ValueError("invalid declared check inventory")
    else:
        checks = plan["checks"]
    return sorted(set(checks) - {LIFECYCLE})


def prepare_crowdsec():
    outputs = {}
    attributes = {
        "traefik": "nixosConfigurations.blizzard.config.services.traefik.package",
        "bouncer": f"checks.{SYSTEM}.crowdsec-observability.bouncer",
        "alloy": "nixosConfigurations.blizzard.config.services.alloy.package",
        "vlogs": "nixosConfigurations.blizzard.config.services.victorialogs.package",
        "crowdsec": "nixosConfigurations.blizzard.config.services.crowdsec.package",
        "settings": f"checks.{SYSTEM}.crowdsec-observability.runtimeSettings",
    }
    for key, attribute in attributes.items():
        path = nix("build", f".#{attribute}", "--no-link", "--print-out-paths").strip()
        if not re.fullmatch(r"/nix/store/[a-z0-9]{32}-[A-Za-z0-9+._?=-]+", path):
            raise ValueError(f"invalid fixture path: {key}")
        outputs[key] = path
    config = nix(
        "eval",
        "--raw",
        '.#nixosConfigurations.blizzard.config.environment.etc."alloy/crowdsec.alloy".text',
    )
    Path(os.environ["RUNNER_TEMP"], "crowdsec.alloy").write_text(
        config, encoding="utf-8"
    )
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        for key, path in outputs.items():
            output.write(f"{key}={path}\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command",
        choices=("classify", "build", "prepare-crowdsec", "lifecycle", "gate"),
    )
    args = parser.parse_args()
    if args.command == "classify":
        event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
        plan = event_plan(os.environ["GITHUB_EVENT_NAME"], event)
        encoded = json.dumps(plan, separators=(",", ":"))
        print(encoded)
        if os.environ.get("GITHUB_OUTPUT"):
            with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
                output.write(f"plan={encoded}\n")
                output.writelines(
                    f"{key}={str(plan[key]).lower()}\n"
                    for key in ("grouped", "lifecycle", "evaluate", "crowdsec")
                )
        if os.environ.get("GITHUB_STEP_SUMMARY"):
            with open(
                os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8"
            ) as summary:
                summary.write(
                    "## Flake Check selection\n\n"
                    f"- Full suite: {plan['full']} ({plan['reason']})\n"
                    f"- Global evaluation: {plan['evaluate']}\n"
                    f"- Checks: {', '.join(plan['checks']) or 'none'}\n"
                    f"- CrowdSec runtime fixtures: {plan['crowdsec']}\n"
                    "Full runs discover all declared checks at build time.\n"
                )
    elif args.command == "build":
        plan = json.loads(os.environ["PLAN"])
        for check in grouped_checks(plan):
            print(f"::group::Build {check}", flush=True)
            nix(
                "build", f".#checks.{SYSTEM}.{check}", "--no-link", "--print-build-logs"
            )
            print("::endgroup::", flush=True)
    elif args.command == "prepare-crowdsec":
        prepare_crowdsec()
    elif args.command == "lifecycle":
        nix(
            "build", f".#checks.{SYSTEM}.{LIFECYCLE}", "--no-link", "--print-build-logs"
        )
    else:
        errors = gate_errors(json.loads(os.environ["NEEDS"]))
        if errors:
            raise SystemExit("\n".join(errors))
        print("Every selected Flake Check job succeeded.")


if __name__ == "__main__":
    main()
