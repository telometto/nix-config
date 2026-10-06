"""Executable contracts for selective CI, diff retrieval, and gate failures."""

import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "flake_ci", ROOT / ".github/scripts/flake_ci.py"
)
ci = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ci)


class SelectionTests(unittest.TestCase):
    def selected(self, *paths):
        plan = ci.classify(paths)
        ci.validate_plan(plan)
        return plan

    def test_docs_only_select_formatting_without_global_evaluation(self):
        plan = self.selected("README.md", "docs/reference-ci.md", "vms/README.md")
        self.assertEqual(plan["checks"], ["formatting"])
        self.assertFalse(plan["evaluate"])
        self.assertFalse(plan["lifecycle"])

    def test_mapped_python_and_fixtures_avoid_global_evaluation(self):
        for path in (
            "modules/services/scripts/cloudflare_metrics.py",
            "tests/cloudflare_metrics/fixtures/state_v1.json",
        ):
            with self.subTest(path=path):
                plan = self.selected(path)
                self.assertEqual(
                    set(plan["checks"]), {"cloudflare-metrics", "formatting"}
                )
                self.assertFalse(plan["full"])
                self.assertFalse(plan["evaluate"])

    def test_mapped_nix_keeps_global_evaluation(self):
        plan = self.selected("hosts/blizzard/monitoring/cloudflare-alerts.nix")
        self.assertTrue(plan["evaluate"])
        self.assertFalse(plan["full"])
        self.assertEqual(set(plan["checks"]), {"cloudflare-metrics", "formatting"})

    def test_mixed_changes_union_requirements(self):
        plan = self.selected(
            "vms/matrix-storage.nix", "tests/crowdsec_http.py", "README.md"
        )
        self.assertTrue(plan["evaluate"])
        self.assertTrue(plan["crowdsec"])
        self.assertEqual(set(plan["checks"]), ci.MATRIX | ci.CROWDSEC | {"formatting"})

    def test_shared_and_unknown_inputs_require_full(self):
        for path in (
            "flake.lock",
            "flake.nix",
            "treefmt.nix",
            "system-loader.nix",
            "lib/traefik.nix",
            "lib/microvm-install-services.nix",
            "vms/base.nix",
            "modules/core/users.nix",
            "home/programs/fastfetch.nix",
            "hosts/blizzard/services/media.nix",
            "modules/services/prometheus.nix",
            "modules/services/grafana.nix",
            "modules/services/traefik.nix",
            "tests/new-test.py",
            ".github/scripts/flake_ci.py",
            ".github/tests/test_flake_ci.py",
            ".github/workflows/flake-check.yml",
            "assets/runtime.conf",
            "../README.md",
            "unmapped\nfile.py",
        ):
            with self.subTest(path=path):
                plan = self.selected(path)
                self.assertTrue(plan["full"])
                self.assertTrue(plan["evaluate"])
                self.assertTrue(plan["lifecycle"])
                self.assertTrue(plan["crowdsec"])

    def test_crowdsec_inputs_select_runtime_fixtures(self):
        for path in (
            "packages/crowdsec-bouncer/attribution.patch",
            "packages/crowdsec-observability/alerts.py",
            "tests/crowdsec_logs_runtime.py",
            "tests/crowdsec-observability.nix",
        ):
            plan = self.selected(path)
            self.assertTrue(plan["crowdsec"])
            self.assertTrue(ci.CROWDSEC.issubset(plan["checks"]))

    def test_crowdsec_configuration_includes_publication_and_matrix(self):
        plan = self.selected("hosts/blizzard/security/crowdsec.nix")
        self.assertTrue((ci.CROWDSEC | ci.MATRIX).issubset(plan["checks"]))

    def test_jellyfin_builds_both_contracts(self):
        plan = self.selected("vms/jellyfin-settings.nix")
        self.assertTrue(ci.JELLYFIN.issubset(plan["checks"]))
        self.assertTrue(plan["evaluate"])

    def test_lifecycle_definition_selects_both_runners(self):
        plan = self.selected("tests/microvm-lifecycle.nix")
        self.assertTrue(plan["lifecycle"])
        self.assertTrue(plan["grouped"])
        self.assertTrue(plan["evaluate"])
        self.assertEqual(set(plan["checks"]), {"formatting", ci.LIFECYCLE})

    def test_sandfly_checks_select_their_consumers(self):
        for path in (
            "tests/sandfly-ssh-test.py",
            "tests/sandfly-ssh-validator-test.py",
            "tests/sandfly-firewall-test.py",
        ):
            with self.subTest(path=path):
                plan = self.selected(path)
                self.assertEqual(set(plan["checks"]), {"formatting", "sandfly-target"})
                self.assertFalse(plan["evaluate"])
                self.assertFalse(plan["full"])
        plan = self.selected("tests/sandfly-runtime.nix")
        self.assertEqual(set(plan["checks"]), {"formatting", "sandfly-runtime"})
        self.assertTrue(plan["evaluate"])
        self.assertFalse(plan["full"])

    def test_full_run_discovers_future_checks(self):
        with patch.object(
            ci,
            "nix",
            return_value=json.dumps(
                [
                    "formatting",
                    ci.LIFECYCLE,
                    "future-contract",
                ]
            ),
        ):
            self.assertEqual(
                ci.grouped_checks(ci.make_plan(full=True)),
                ["formatting", "future-contract"],
            )

    def test_selective_builds_do_not_discover_unselected_outputs(self):
        plan = self.selected("tests/crowdsec_http.py")
        with patch.object(
            ci, "nix", side_effect=AssertionError("unnecessary evaluation")
        ):
            self.assertEqual(set(ci.grouped_checks(plan)), ci.CROWDSEC | {"formatting"})

    def test_manual_nightly_and_missing_event_history_are_full(self):
        for event_name in (
            "workflow_dispatch",
            "schedule",
            "push",
            "pull_request",
            "unknown",
        ):
            self.assertTrue(ci.event_plan(event_name, {})["full"])

    def test_no_changed_files_can_skip_both_workers(self):
        plan = self.selected()
        self.assertFalse(plan["grouped"])
        self.assertFalse(plan["lifecycle"])

    def test_exact_mappings_exist_and_reference_declared_checks(self):
        for path, checks in ci.DEPENDENCIES.items():
            with self.subTest(path=path):
                self.assertTrue((ROOT / path).is_file(), path)
                self.assertTrue(checks <= ci.CHECKS)
        source = (ROOT / "flake.nix").read_text()
        block = source.split("checks.${system} = {", 1)[1].split("devShells.", 1)[0]
        declared = set(re.findall(r"^        ([a-z0-9-]+)\s*=", block, re.MULTILINE))
        self.assertTrue(ci.CHECKS <= declared, ci.CHECKS - declared)


class GateTests(unittest.TestCase):
    def needs(self, plan):
        return {
            "classify": {"result": "success", "outputs": {"plan": json.dumps(plan)}},
            "grouped": {"result": "success" if plan["grouped"] else "skipped"},
            "lifecycle": {"result": "success" if plan["lifecycle"] else "skipped"},
        }

    def test_full_targeted_and_noop_expected_results_succeed(self):
        for plan in (
            ci.make_plan(full=True),
            ci.classify(["README.md"]),
            ci.classify([]),
        ):
            self.assertEqual(ci.gate_errors(self.needs(plan)), [])

    def test_selected_skips_failures_cancellations_and_missing_jobs_fail(self):
        for job in ("grouped", "lifecycle"):
            for result in ("skipped", "failure", "cancelled", "missing"):
                with self.subTest(job=job, result=result):
                    needs = self.needs(ci.make_plan(full=True))
                    if result == "missing":
                        del needs[job]
                    else:
                        needs[job]["result"] = result
                    self.assertTrue(ci.gate_errors(needs))

    def test_classifier_non_success_always_fails(self):
        for result in ("failure", "skipped", "cancelled", "missing"):
            needs = self.needs(ci.classify([]))
            needs["classify"]["result"] = result
            self.assertTrue(ci.gate_errors(needs))

    def test_malformed_and_inconsistent_plans_fail(self):
        for encoded in ("", "{}", "null", "[]", '{"grouped":"false"}'):
            needs = self.needs(ci.classify([]))
            needs["classify"]["outputs"]["plan"] = encoded
            self.assertTrue(ci.gate_errors(needs))
        plan = ci.make_plan(full=True)
        plan["lifecycle"] = False
        self.assertTrue(ci.gate_errors(self.needs(plan)))

    def test_unselected_worker_must_skip(self):
        needs = self.needs(ci.classify([]))
        needs["lifecycle"]["result"] = "success"
        self.assertTrue(ci.gate_errors(needs))


class DiffTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.git("init", "-q")
        self.git("config", "user.email", "ci-test@example.invalid")
        self.git("config", "user.name", "CI test")
        self.write("README.md", "initial")
        self.initial = self.commit()
        self.git("branch", "base")

    def git(self, *args):
        return (
            subprocess.check_output(
                ["git", "-C", str(self.repo), *args], stderr=subprocess.DEVNULL
            )
            .decode()
            .strip()
        )

    def write(self, path, text):
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)

    def commit(self):
        self.git("add", "-A")
        self.git("commit", "-qm", "fixture")
        return self.git("rev-parse", "HEAD")

    def test_push_covers_every_commit_and_deleted_inputs(self):
        self.write("tests/crowdsec_http.py", "one")
        self.commit()
        (self.repo / "README.md").unlink()
        self.write("vms/matrix-storage.nix", "two")
        head = self.commit()
        paths = ci.changed_paths(
            "push", {"before": self.initial, "after": head}, self.repo
        )
        self.assertEqual(
            set(paths),
            {"README.md", "tests/crowdsec_http.py", "vms/matrix-storage.nix"},
        )
        self.assertTrue(ci.classify(paths)["crowdsec"])

    def test_pr_uses_merge_base_and_complete_branch_diff(self):
        self.write("tests/crowdsec_http.py", "one")
        self.commit()
        self.write("vms/matrix-storage.nix", "two")
        head = self.commit()
        self.git("checkout", "-q", "base")
        self.write("flake.lock", "base-only change")
        base = self.commit()
        event = {"pull_request": {"base": {"sha": base}, "head": {"sha": head}}}
        paths = ci.changed_paths("pull_request", event, self.repo)
        self.assertEqual(
            set(paths), {"tests/crowdsec_http.py", "vms/matrix-storage.nix"}
        )
        self.assertFalse(ci.event_plan("pull_request", event, self.repo)["full"])

    def test_rename_preserves_both_dependency_sets(self):
        old = "tests/cloudflare_metrics/test_original.py"
        new = "tests/crowdsec_http.py"
        self.write(old, "same content")
        base = self.commit()
        (self.repo / old).rename(self.repo / new)
        head = self.commit()
        paths = ci.changed_paths("push", {"before": base, "after": head}, self.repo)
        self.assertEqual(set(paths), {old, new})
        plan = ci.classify(paths)
        self.assertTrue((ci.CROWDSEC | {"cloudflare-metrics"}).issubset(plan["checks"]))

    def test_deletion_of_nix_input_retains_global_evaluation(self):
        path = "vms/jellyfin-settings.nix"
        self.write(path, "{}")
        base = self.commit()
        (self.repo / path).unlink()
        head = self.commit()
        plan = ci.event_plan("push", {"before": base, "after": head}, self.repo)
        self.assertTrue(plan["evaluate"])
        self.assertTrue(ci.JELLYFIN.issubset(plan["checks"]))

    def test_cli_outputs_and_gate_use_the_same_selection(self):
        self.write("docs/new-guide.md", "documentation")
        head = self.commit()
        event_file = self.repo / "event.json"
        event_file.write_text(json.dumps({"before": self.initial, "after": head}))
        output_file = self.repo / "outputs"
        summary_file = self.repo / "summary"
        env = os.environ | {
            "GITHUB_EVENT_NAME": "push",
            "GITHUB_EVENT_PATH": str(event_file),
            "GITHUB_OUTPUT": str(output_file),
            "GITHUB_STEP_SUMMARY": str(summary_file),
        }
        subprocess.run(
            [
                sys.executable,
                "-B",
                str(ROOT / ".github/scripts/flake_ci.py"),
                "classify",
            ],
            cwd=self.repo,
            env=env,
            check=True,
            capture_output=True,
        )
        outputs = dict(
            line.split("=", 1) for line in output_file.read_text().splitlines()
        )
        plan = json.loads(outputs["plan"])
        self.assertEqual(plan["checks"], ["formatting"])
        for key in ("grouped", "lifecycle", "evaluate", "crowdsec"):
            self.assertEqual(outputs[key], str(plan[key]).lower())
        needs = {
            "classify": {"result": "success", "outputs": outputs},
            "grouped": {"result": "success"},
            "lifecycle": {"result": "skipped"},
        }
        env["NEEDS"] = json.dumps(needs)
        command = [
            sys.executable,
            "-B",
            str(ROOT / ".github/scripts/flake_ci.py"),
            "gate",
        ]
        self.assertEqual(
            subprocess.run(
                command, env=env, capture_output=True, check=False
            ).returncode,
            0,
        )
        needs["grouped"]["result"] = "skipped"
        env["NEEDS"] = json.dumps(needs)
        self.assertNotEqual(
            subprocess.run(
                command, env=env, capture_output=True, check=False
            ).returncode,
            0,
        )

    def test_unavailable_history_and_new_branch_fail_closed(self):
        for base in ("f" * 40, "0" * 40, "--help"):
            plan = ci.event_plan(
                "push", {"before": base, "after": self.initial}, self.repo
            )
            self.assertTrue(plan["full"])


class FixturePreparationTests(unittest.TestCase):
    def test_preparation_failure_propagates(self):
        with (
            patch.object(ci, "nix", side_effect=RuntimeError("fixture failed")),
            self.assertRaises(RuntimeError),
        ):
            ci.prepare_crowdsec()


if __name__ == "__main__":
    unittest.main()
