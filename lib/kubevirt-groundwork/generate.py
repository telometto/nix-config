#!/usr/bin/env python3
"""Generate one inert, canonical host disk registration from public metadata."""

import argparse
import json
import re
from pathlib import Path

CATALOG = Path(__file__).with_name("catalog.json")
RESERVED = {"actual", "actual-pilot", "restore-tests", "searx-preview"}


def safe_name(value):
    return (
        isinstance(value, str)
        and len(value) <= 63
        and bool(re.fullmatch(r"[a-z0-9](?:[a-z0-9-]*[a-z0-9])?", value))
    )


def load_catalog(path=CATALOG):
    catalog = json.loads(Path(path).read_text())
    if catalog.get("schemaVersion") != 1:
        raise ValueError("unsupported catalog version")
    services = catalog["services"]
    if len({s["id"] for s in services}) != len(services):
        raise ValueError("duplicate service IDs")
    for service in services:
        disk_names(service)
    return catalog


def select(catalog, service_id):
    for service in catalog["services"]:
        if service["id"] == service_id:
            return service
    raise ValueError(f"unknown groundwork service: {service_id}")


def disk_names(profile):
    service_id, namespace = profile["id"], profile["namespace"]
    if (
        not safe_name(service_id)
        or namespace != service_id + "-preview"
        or namespace in RESERVED
    ):
        raise ValueError("invalid or reserved service namespace")
    disks = ["root"] + [volume["name"] for volume in profile["stateVolumes"]]
    if len(disks) != len(set(disks)) or not all(safe_name(d) for d in disks):
        raise ValueError("disk names must be unique DNS labels")
    return disks


def render(profile):
    disks = "".join(f"      {json.dumps(d)}\n" for d in disk_names(profile))
    return (
        "# Fresh preview disks only; runtime and Flux stay gated separately.\n"
        "{ lib, ... }:\n"
        "{\n"
        f"  sys.virtualisation.actualPilot.previewVMs.{profile['namespace']} = {{\n"
        "    enable = lib.mkDefault false;\n"
        "    disks = [\n"
        f"{disks}"
        "    ];\n"
        "  };\n"
        "}\n"
    )


def write(profile, output):
    text = render(profile)
    with Path(output).open("x") as destination:
        destination.write(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("service")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    write(select(load_catalog(), args.service), args.output)


if __name__ == "__main__":
    main()
