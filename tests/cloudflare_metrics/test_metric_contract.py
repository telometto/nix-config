from __future__ import annotations

import importlib.util
import json
import re
import unittest
from collections.abc import Iterable
from pathlib import Path


ROOT = Path(__file__).parents[2]
SOURCE = ROOT / "modules" / "services" / "scripts" / "cloudflare_metrics.py"
DASHBOARD = ROOT / "dashboards" / "host" / "blizzard" / "cloudflare-overview.json"
ALERTS = ROOT / "hosts" / "blizzard" / "monitoring" / "cloudflare-alerts.nix"
GOLDEN = Path(__file__).with_name("fixtures") / "metric_contract.openmetrics"

SPEC = importlib.util.spec_from_file_location("cloudflare_metrics_contract", SOURCE)
assert SPEC is not None and SPEC.loader is not None
cloudflare_metrics = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cloudflare_metrics)

METRIC_RE = re.compile(r"\b(cloudflare_[A-Za-z_:][A-Za-z0-9_:]*)\b")
SELECTOR_RE = re.compile(r"\b(cloudflare_[A-Za-z_:][A-Za-z0-9_:]*)\s*\{([^{}]*)\}")
SELECTOR_LABEL_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*(?:=~|!~|!=|=)")
VECTOR_LABEL_RE = re.compile(r"\b(?:by|without|on|ignoring)\s*\(([^()]*)\)")
LABEL_VALUES_RE = re.compile(
    r"\blabel_values\(\s*(cloudflare_[A-Za-z_:][A-Za-z0-9_:]*)"
    r"(?:\s*\{[^{}]*\})?\s*,\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)"
)
SAMPLE_RE = re.compile(
    r"^(cloudflare_[A-Za-z_:][A-Za-z0-9_:]*)(?:\{([^{}]*)\})?\s+[-+0-9.eE]+$"
)
SAMPLE_LABEL_RE = re.compile(r'\b([A-Za-z_][A-Za-z0-9_]*)="(?:\\.|[^"\\])*"')


def _dashboard_promql() -> Iterable[tuple[str, str]]:
    dashboard = json.loads(DASHBOARD.read_text(encoding="utf-8"))

    def visit(value: object, path: str = "dashboard") -> Iterable[tuple[str, str]]:
        if isinstance(value, dict):
            for key, child in value.items():
                child_path = f"{path}.{key}"
                # Grafana stores panel PromQL under expr and variable PromQL under
                # definition/query. Other strings (titles, descriptions, links)
                # are deliberately outside this contract parser's boundary.
                if (
                    key in {"expr", "definition", "query"}
                    and isinstance(child, str)
                    and "cloudflare_" in child
                ):
                    yield child_path, child
                else:
                    yield from visit(child, child_path)
        elif isinstance(value, list):
            for index, child in enumerate(value):
                yield from visit(child, f"{path}[{index}]")

    yield from visit(dashboard)


def _alert_promql() -> Iterable[tuple[str, str]]:
    source = ALERTS.read_text(encoding="utf-8")
    # Alert expressions in this module are Nix indented strings assigned to the
    # expr attribute. This intentionally avoids pretending to be a general Nix
    # parser; changing that representation must update this explicit boundary.
    expressions = re.findall(r"\bexpr\s*=\s*''(.*?)''\s*;", source, re.DOTALL)
    for index, expression in enumerate(expressions):
        if "cloudflare_" in expression:
            yield f"alerts.expr[{index}]", expression


def _alert_rule_source(uid: str) -> str:
    source = ALERTS.read_text(encoding="utf-8")
    marker = f'uid = "{uid}";'
    marker_index = source.index(marker)
    start = source.rfind("(mkPrometheusRule {", 0, marker_index)
    end = source.index("\n          })", marker_index)
    if start < 0:
        raise AssertionError(f"could not find start of alert rule {uid}")
    return source[start:end]


def _normal_labels(metric: str) -> frozenset[str]:
    return frozenset().union(*cloudflare_metrics.METRIC_LABEL_SCHEMAS[metric])


def _sample_labels(rendered: str) -> dict[str, set[frozenset[str]]]:
    samples: dict[str, set[frozenset[str]]] = {}
    for line in rendered.splitlines():
        if line.startswith("#"):
            continue
        match = SAMPLE_RE.fullmatch(line)
        if match is None:
            raise AssertionError(f"unparseable OpenMetrics sample: {line}")
        metric, selector = match.groups()
        labels = frozenset(SAMPLE_LABEL_RE.findall(selector or ""))
        samples.setdefault(metric, set()).add(labels)
    return samples


def _representative_state() -> dict:
    state = {
        "version": cloudflare_metrics.STATE_VERSION,
        "series": {},
        "analytics": {},
        "access": {
            "high_water": None,
            "nonidentity_high_water": None,
            "seen": {},
            "gap": False,
            "nonidentity_gap": False,
        },
    }
    values = {
        "action": "block",
        "app": "example-app",
        "cache_status": "hit",
        "country": "NO",
        "decision": "allowed",
        "host": "www.example.com",
        "metric": "cloudflare_http_requests_total",
        "operation": "analytics",
        "owner": "false",
        "poll": "analytics",
        "principal_type": "user",
        "source": "waf",
        "status": "200",
        "zone": "example.com",
    }
    for index, (metric, schemas) in enumerate(
        cloudflare_metrics.METRIC_LABEL_SCHEMAS.items(), start=1
    ):
        for schema in schemas:
            cloudflare_metrics.set_series(
                state,
                metric,
                {label: values[label] for label in schema},
                index,
            )
        cloudflare_metrics.set_series(
            state,
            metric,
            cloudflare_metrics.OVERFLOW_LABELS,
            100 + index,
        )
    return state


class MetricContractTests(unittest.TestCase):
    def test_alerts_separate_missing_telemetry_from_confirmed_history_gaps(
        self,
    ) -> None:
        failure_rule = _alert_rule_source("cf-collector-failure")
        gap_rule = _alert_rule_source("cf-history-gap")

        self.assertNotIn("absent(cloudflare_collector_state_gap)", gap_rule)
        self.assertNotIn('noDataState = "Alerting";', gap_rule)
        self.assertIn("max(cloudflare_collector_state_gap) > 0", gap_rule)
        self.assertIn(
            'absent(sum(cloudflare_collector_last_success_timestamp_seconds{poll="analytics"}))',
            failure_rule,
        )
        self.assertIn(
            'absent(sum(cloudflare_collector_last_success_timestamp_seconds{poll="access"}))',
            failure_rule,
        )
        self.assertIn(
            'cloudflare_collector_poll_enabled{poll="access_nonidentity"}',
            failure_rule,
        )
        self.assertIn(
            'absent(sum(cloudflare_collector_last_success_timestamp_seconds{poll="access_nonidentity"}))',
            failure_rule,
        )
        self.assertIn('absent(sum(up{job="cloudflare"}))', failure_rule)
        self.assertNotIn(
            "or absent(cloudflare_collector_last_success_timestamp_seconds",
            failure_rule,
        )

    def test_runtime_rejects_unknown_metrics_and_label_shapes(self) -> None:
        state = cloudflare_metrics.new_state()
        with self.assertRaisesRegex(ValueError, "unknown metric"):
            cloudflare_metrics.add_series(state, "cloudflare_unknown_total", {}, 1)
        with self.assertRaisesRegex(ValueError, "invalid labels"):
            cloudflare_metrics.set_series(
                state,
                "cloudflare_collector_state_gap",
                {"zone": "example.com", "unexpected": "value"},
                1,
            )

    def test_dashboard_and_alert_promql_match_collector_schema(self) -> None:
        expressions = [*_dashboard_promql(), *_alert_promql()]
        self.assertTrue(
            any(source.startswith("dashboard") for source, _ in expressions)
        )
        self.assertTrue(any(source.startswith("alerts") for source, _ in expressions))

        for source, expression in expressions:
            metrics = set(METRIC_RE.findall(expression))
            self.assertTrue(metrics, f"{source} did not contain a Cloudflare metric")
            for metric in metrics:
                self.assertIn(metric, cloudflare_metrics.METRIC_LABEL_SCHEMAS, source)

            for metric, selector in SELECTOR_RE.findall(expression):
                referenced = set(SELECTOR_LABEL_RE.findall(selector))
                self.assertLessEqual(referenced, _normal_labels(metric), source)

            vector_labels = {
                label.strip()
                for group in VECTOR_LABEL_RE.findall(expression)
                for label in group.split(",")
                if label.strip()
            }
            for metric in metrics:
                self.assertLessEqual(vector_labels, _normal_labels(metric), source)

            for metric, label in LABEL_VALUES_RE.findall(expression):
                self.assertIn(label, _normal_labels(metric), source)

    def test_rendered_openmetrics_matches_golden_type_and_label_contract(self) -> None:
        rendered = cloudflare_metrics.render_metrics(_representative_state())
        self.assertEqual(rendered, GOLDEN.read_text(encoding="utf-8"))

        types = dict(
            re.findall(
                r"^# TYPE (cloudflare_[A-Za-z_:][A-Za-z0-9_:]*) (\w+)$",
                rendered,
                re.MULTILINE,
            )
        )
        self.assertEqual(
            types,
            {
                metric: spec[0]
                for metric, spec in cloudflare_metrics.METRIC_SPECS.items()
            },
        )

        expected_labels = {
            metric: set(schemas) | {cloudflare_metrics.OVERFLOW_LABEL_SCHEMA}
            for metric, schemas in cloudflare_metrics.METRIC_LABEL_SCHEMAS.items()
        }
        self.assertEqual(_sample_labels(rendered), expected_labels)


if __name__ == "__main__":
    unittest.main()
