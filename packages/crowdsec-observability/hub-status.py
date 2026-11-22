"""Fail the daily check when installed Hub items need a reviewed upgrade."""

import json
import subprocess
import sys


def pending(items):
    return [
        item["name"]
        for group in items.values()
        for item in group
        if {"enabled", "update-available"} <= set(item["status"].split(","))
    ]


if __name__ == "__main__":
    binary, config = sys.argv[1:]
    items = json.loads(
        subprocess.check_output(
            [binary, "-c=" + config, "hub", "list", "-o", "json"], timeout=60
        )
    )
    outdated = pending(items)
    if outdated:
        print("CrowdSec rules need review: " + ", ".join(outdated), flush=True)
        sys.exit(2)
    print("Installed CrowdSec Hub rules are current.")
