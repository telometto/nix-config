"""Existing Flux objects are never replaced by host bootstrap."""

import importlib.util
import subprocess
import unittest
from pathlib import Path

SCRIPT = (
    Path(__file__).resolve().parents[2]
    / "modules/virtualisation/scripts/actual_pilot_bootstrap.py"
)
spec = importlib.util.spec_from_file_location("pilot_bootstrap", SCRIPT)
bootstrap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bootstrap)


def resource(kind, name, version="seed"):
    return {
        "apiVersion": "v1",
        "kind": kind,
        "metadata": {"name": name},
        "spec": {"version": version},
    }


class Api:
    def __init__(self, objects=()):
        self.objects = {(d["kind"], d["metadata"]["name"]): d for d in objects}
        self.established = []

    def exists(self, document):
        return (document["kind"], document["metadata"]["name"]) in self.objects

    def create(self, document):
        key = document["kind"], document["metadata"]["name"]
        if key in self.objects:
            raise subprocess.CalledProcessError(1, "create")
        self.objects[key] = document

    def wait_crd(self, name):
        self.established.append(name)


class BootstrapTests(unittest.TestCase):
    def test_fresh_seed_creates_resources_and_establishes_crds(self):
        docs = [
            resource("Deployment", "source-controller"),
            resource("CustomResourceDefinition", "sources.example"),
            resource("Namespace", "flux-system"),
        ]
        api = Api()
        bootstrap.seed_documents(docs, api)
        self.assertEqual(len(api.objects), 3)
        self.assertEqual(api.established, ["sources.example"])

    def test_newer_existing_controller_and_root_are_unchanged(self):
        newer = resource("Deployment", "source-controller", "newer-from-git")
        root = resource("Kustomization", "actual-pilot", "review-branch")
        api = Api([newer, root])
        bootstrap.seed_documents(
            [
                resource("Deployment", "source-controller"),
                resource("Kustomization", "actual-pilot"),
            ],
            api,
        )
        self.assertIs(api.objects[("Deployment", "source-controller")], newer)
        self.assertIs(api.objects[("Kustomization", "actual-pilot")], root)

    def test_partial_bootstrap_only_supplies_missing_resources(self):
        newer = resource("Deployment", "source-controller", "newer")
        api = Api([newer])
        docs = [
            resource("Deployment", "source-controller"),
            resource("Deployment", "kustomize-controller"),
        ]
        bootstrap.seed_documents(docs, api)
        self.assertIs(api.objects[("Deployment", "source-controller")], newer)
        self.assertIn(("Deployment", "kustomize-controller"), api.objects)

    def test_discovery_failure_is_not_treated_as_absence(self):
        class Offline(Api):
            def exists(self, document):
                raise subprocess.CalledProcessError(1, "get")

        api = Offline()
        with self.assertRaises(subprocess.CalledProcessError):
            bootstrap.seed_documents([resource("Namespace", "flux-system")], api)
        self.assertEqual(api.objects, {})

    def test_create_race_preserves_winning_object(self):
        class Race(Api):
            def create(self, document):
                self.objects[(document["kind"], document["metadata"]["name"])] = (
                    resource("Deployment", "source-controller", "winner")
                )
                raise subprocess.CalledProcessError(1, "create")

        api = Race()
        bootstrap.seed_documents([resource("Deployment", "source-controller")], api)
        self.assertEqual(
            api.objects[("Deployment", "source-controller")]["spec"]["version"],
            "winner",
        )

    def test_failed_create_without_an_object_fails_bootstrap(self):
        class Denied(Api):
            def create(self, document):
                raise subprocess.CalledProcessError(1, "create")

        with self.assertRaises(subprocess.CalledProcessError):
            bootstrap.seed_documents(
                [resource("Deployment", "source-controller")], Denied()
            )

    def test_yaml_list_is_flattened_and_duplicate_identity_rejected(self):
        doc = resource("Namespace", "flux-system")
        self.assertEqual(
            bootstrap.documents(
                "kind: List\nitems:\n- apiVersion: v1\n  kind: Namespace\n  metadata: {name: flux-system}\n"
            ),
            [{k: doc[k] for k in ("apiVersion", "kind", "metadata")}],
        )
        with self.assertRaises(ValueError):
            bootstrap.documents(
                "apiVersion: v1\nkind: Namespace\nmetadata: {name: flux-system}\n---\napiVersion: v1\nkind: Namespace\nmetadata: {name: flux-system}\n"
            )


if __name__ == "__main__":
    unittest.main()
