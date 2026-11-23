"""Create missing Flux seed objects; leave all existing desired state to Git."""

import argparse
import json
import subprocess
from pathlib import Path

import yaml


def documents(text):
    result = []
    identities = set()
    for document in yaml.safe_load_all(text):
        if not document:
            continue
        items = (
            document.get("items", []) if document.get("kind") == "List" else [document]
        )
        for item in items:
            metadata = item["metadata"]
            identity = (
                item["apiVersion"],
                item["kind"],
                metadata.get("namespace"),
                metadata["name"],
            )
            if identity in identities:
                raise ValueError(f"duplicate seed identity: {identity}")
            identities.add(identity)
            result.append(item)
    return result


class Kubectl:
    def run(self, *args, document=None, timeout=210):
        return subprocess.run(
            [
                "kubectl",
                "--cache-dir=/var/cache/actual-pilot/kubectl",
                "--request-timeout=30s",
                *args,
            ],
            input=None if document is None else json.dumps(document),
            text=True,
            capture_output=True,
            check=True,
            timeout=timeout,
        ).stdout

    def exists(self, document):
        return bool(
            self.run(
                "get", "-f", "-", "--ignore-not-found", "-o", "name", document=document
            ).strip()
        )

    def create(self, document):
        self.run("create", "-f", "-", document=document)

    def wait_crd(self, name):
        self.run("wait", "--for=condition=Established", f"crd/{name}", "--timeout=120s")


def seed_documents(items, api):
    priority = {"Namespace": 0, "CustomResourceDefinition": 1}
    for item in sorted(items, key=lambda d: priority.get(d["kind"], 2)):
        if not api.exists(item):
            try:
                api.create(item)
            except subprocess.CalledProcessError:
                # Flux may have created it between discovery and create. Never apply
                # the older host seed over the object that won this race.
                if not api.exists(item):
                    raise
            print(f"seeded {item['kind']}/{item['metadata']['name']}", flush=True)
        if item["kind"] == "CustomResourceDefinition":
            api.wait_crd(item["metadata"]["name"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("components", type=Path)
    parser.add_argument("sync", type=Path)
    args = parser.parse_args()
    api = Kubectl()
    api.run("wait", "--for=condition=Ready", "node/blizzard", "--timeout=180s")
    seed_documents(documents(args.components.read_text()), api)
    for name in (
        "source-controller",
        "kustomize-controller",
        "helm-controller",
        "notification-controller",
    ):
        api.run(
            "-n",
            "flux-system",
            "rollout",
            "status",
            f"deployment/{name}",
            "--timeout=180s",
        )
    seed_documents(documents(args.sync.read_text()), api)
    print(
        "Flux seed ready; reconciliation and application readiness are separate checks.",
        flush=True,
    )


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit(
            f"kubectl failed ({error.returncode}): {error.stderr or error}"
        ) from error
