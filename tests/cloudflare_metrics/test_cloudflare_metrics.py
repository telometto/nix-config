from __future__ import annotations

import copy
import importlib.util
import json
import os
import random
import re
import stat
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path
from unittest import mock


SOURCE = (
    Path(__file__).parents[2]
    / "modules"
    / "services"
    / "scripts"
    / "cloudflare_metrics.py"
)
FIXTURES = Path(__file__).with_name("fixtures")
SPEC = importlib.util.spec_from_file_location("cloudflare_metrics", SOURCE)
assert SPEC is not None and SPEC.loader is not None
cloudflare_metrics = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cloudflare_metrics)


def analytics_fixture() -> dict:
    bucket = "2026-07-15T10:00:00Z"
    return {
        "status": [
            {
                "count": 42,
                "avg": {"sampleInterval": 10},
                "sum": {
                    "clientRequestBytes": 123,
                    "edgeResponseBytes": 456,
                },
                "dimensions": {
                    "datetimeFiveMinutes": bucket,
                    "clientRequestHTTPHost": "WWW.Example.COM.:443",
                    "edgeResponseStatus": 200,
                },
            }
        ],
        "cache": [
            {
                "count": 40,
                "dimensions": {
                    "datetimeFiveMinutes": bucket,
                    "clientRequestHTTPHost": "www.example.com",
                    "cacheStatus": "hit",
                },
            }
        ],
        "country": [
            {
                "count": 42,
                "dimensions": {
                    "datetimeFiveMinutes": bucket,
                    "clientCountryName": "no",
                },
            }
        ],
        "security": [
            {
                "count": 3,
                "dimensions": {
                    "datetimeFiveMinutes": bucket,
                    "clientRequestHTTPHost": "www.example.com",
                    "securityAction": "block",
                    "securitySource": "waf",
                },
            }
        ],
        "visits": [
            {
                "sum": {"visits": 7},
                "dimensions": {
                    "datetimeFiveMinutes": bucket,
                    "clientRequestHTTPHost": "www.example.com",
                },
            }
        ],
    }


def nonidentity_access_fixture() -> list[dict]:
    return json.loads(
        (FIXTURES / "access_nonidentity.json").read_text(encoding="utf-8")
    )


class AnalyticsTests(unittest.TestCase):
    def test_graphql_aliases_match_analytics_dataset_registry(self) -> None:
        query_aliases = dict(
            re.findall(
                r"^\s+([A-Za-z_]\w*):\s*([A-Za-z_]\w*)\(",
                cloudflare_metrics.ANALYTICS_QUERY,
                flags=re.MULTILINE,
            )
        )

        self.assertEqual(query_aliases, cloudflare_metrics.ANALYTICS_DATASETS)

    def test_graphql_aggregation_preserves_estimated_values(self) -> None:
        state = cloudflare_metrics.new_state()

        added = cloudflare_metrics.apply_analytics_response(
            state, "zone-id", "example.com", analytics_fixture()
        )

        self.assertEqual(added, 5)
        self.assertEqual(
            cloudflare_metrics.get_series(
                state,
                "cloudflare_http_requests_total",
                {"zone": "example.com", "host": "www.example.com", "status": "200"},
            ),
            42,
        )
        self.assertEqual(
            cloudflare_metrics.get_series(
                state,
                "cloudflare_http_request_bytes_total",
                {"zone": "example.com", "host": "www.example.com"},
            ),
            123,
        )
        self.assertEqual(
            cloudflare_metrics.get_series(
                state,
                "cloudflare_http_response_bytes_total",
                {"zone": "example.com", "host": "www.example.com"},
            ),
            456,
        )
        self.assertEqual(
            cloudflare_metrics.get_series(
                state,
                "cloudflare_collector_sample_interval",
                {"zone": "example.com"},
            ),
            10,
        )
        # Cloudflare already estimated 42 requests. The sample interval is not
        # applied again (which would incorrectly produce 420).
        self.assertNotEqual(
            cloudflare_metrics.get_series(
                state,
                "cloudflare_http_requests_total",
                {"zone": "example.com", "host": "www.example.com", "status": "200"},
            ),
            420,
        )

    def test_overlapping_analytics_rows_are_deduplicated(self) -> None:
        state = cloudflare_metrics.new_state()
        fixture = analytics_fixture()

        cloudflare_metrics.apply_analytics_response(
            state, "zone-id", "example.com", fixture
        )
        second_added = cloudflare_metrics.apply_analytics_response(
            state, "zone-id", "example.com", fixture
        )

        self.assertEqual(second_added, 0)
        self.assertEqual(
            cloudflare_metrics.get_series(
                state,
                "cloudflare_http_requests_total",
                {"zone": "example.com", "host": "www.example.com", "status": "200"},
            ),
            42,
        )

    def test_restart_recovers_counters_and_deduplication_state(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            store = cloudflare_metrics.StateStore(
                Path(temporary_directory) / "state.json"
            )
            state = cloudflare_metrics.new_state()
            cloudflare_metrics.apply_analytics_response(
                state, "zone-id", "example.com", analytics_fixture()
            )
            store.save(state)

            restarted = store.load()
            added = cloudflare_metrics.apply_analytics_response(
                restarted, "zone-id", "example.com", analytics_fixture()
            )

            self.assertEqual(added, 0)
            self.assertEqual(
                cloudflare_metrics.get_series(
                    restarted,
                    "cloudflare_http_requests_total",
                    {
                        "zone": "example.com",
                        "host": "www.example.com",
                        "status": "200",
                    },
                ),
                42,
            )


class CardinalityBoundTests(unittest.TestCase):
    def test_hostile_label_values_are_safely_bounded_and_stable(self) -> None:
        first = "host\x00\t" + ("x" * 500) + "-one.example"
        second = "host\x00\t" + ("x" * 500) + "-two.example"

        normalized_first = cloudflare_metrics.normalize_label_value(first)
        normalized_second = cloudflare_metrics.normalize_label_value(second)

        self.assertLessEqual(
            len(normalized_first), cloudflare_metrics.MAX_LABEL_VALUE_LENGTH
        )
        self.assertNotIn("\x00", normalized_first)
        self.assertNotIn("\t", normalized_first)
        self.assertEqual(
            normalized_first, cloudflare_metrics.normalize_label_value(first)
        )
        self.assertNotEqual(normalized_first, normalized_second)

    def test_random_host_series_are_collapsed_and_overflow_is_observable(self) -> None:
        state = cloudflare_metrics.new_state()
        hosts = [
            f"{random.Random(seed).getrandbits(64):016x}.example"
            for seed in range(20)
        ]
        metric = "cloudflare_http_requests_total"

        with mock.patch.object(cloudflare_metrics, "MAX_SERIES_PER_METRIC", 4):
            for host in hosts:
                cloudflare_metrics.add_series(
                    state,
                    metric,
                    {"zone": "example.com", "host": host, "status": "200"},
                    1,
                )

            series = state["series"][metric]
            rendered = cloudflare_metrics.render_metrics(state)

        self.assertEqual(len(series), 4)
        self.assertEqual(sum(series.values()), len(hosts))
        self.assertIn(cloudflare_metrics._series_key({"overflow": "true"}), series)
        self.assertGreater(
            cloudflare_metrics.get_series(
                state,
                cloudflare_metrics.OVERFLOW_METRIC,
                {"metric": metric},
            ),
            0,
        )
        samples = [
            line
            for line in rendered.splitlines()
            if line.startswith(f"{metric}{'{'}")
        ]
        self.assertEqual(len(samples), 4)
        self.assertIn(cloudflare_metrics.OVERFLOW_METRIC, rendered)
        # Per-metric overflow cannot crowd out unrelated health series.
        self.assertEqual(
            cloudflare_metrics.get_series(
                state, "cloudflare_collector_catch_up", {"poll": "analytics"}
            ),
            0,
        )

    def test_oversized_current_state_is_compacted_and_persisted_once(self) -> None:
        metric = "cloudflare_http_requests_total"
        state = cloudflare_metrics.new_state()
        state["series"][metric] = {
            json.dumps(
                sorted(
                    {
                        "zone": "example.com",
                        "host": f"host-{index}.example" + ("x" * 400),
                        "status": "200",
                    }.items()
                ),
                separators=(",", ":"),
            ): index + 1
            for index in range(6)
        }

        with tempfile.TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "state.json"
            path.write_text(json.dumps(state), encoding="utf-8")
            store = cloudflare_metrics.StateStore(path)
            with (
                mock.patch.object(cloudflare_metrics, "MAX_SERIES_PER_METRIC", 4),
                mock.patch.object(cloudflare_metrics, "_fsync_directory"),
                mock.patch.object(store, "save", wraps=store.save) as save,
            ):
                first = store.load()
                second = store.load()
                rendered = cloudflare_metrics.render_metrics(first)

        first_series = first["series"][metric]
        self.assertEqual(first_series, second["series"][metric])
        self.assertEqual(len(first_series), 4)
        self.assertEqual(sum(first_series.values()), 21)
        for key in first_series:
            for label in cloudflare_metrics._series_labels(key).values():
                self.assertLessEqual(
                    len(label), cloudflare_metrics.MAX_LABEL_VALUE_LENGTH
                )
        samples = [
            line
            for line in rendered.splitlines()
            if line.startswith(f"{metric}{'{'}")
        ]
        self.assertEqual(len(samples), 4)
        self.assertEqual(
            cloudflare_metrics.get_series(
                first,
                cloudflare_metrics.OVERFLOW_METRIC,
                {"metric": metric},
            ),
            3,
        )
        self.assertEqual(save.call_count, 1)


class StateMigrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = (FIXTURES / "state_v1.json").read_bytes()

    def _write_v1_state(self, directory: str) -> Path:
        path = Path(directory) / "state.json"
        path.write_bytes(self.fixture)
        return path

    def test_v1_golden_migration_sanitizes_and_compacts_state(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = self._write_v1_state(temporary_directory)
            store = cloudflare_metrics.StateStore(path)
            with (
                mock.patch.object(cloudflare_metrics, "MAX_SERIES_PER_METRIC", 4),
                mock.patch.object(cloudflare_metrics, "_fsync_directory"),
            ):
                migrated = store.load()

        self.assertEqual(migrated["version"], cloudflare_metrics.STATE_VERSION)
        access_total = migrated["series"][
            "cloudflare_access_authentications_total"
        ]
        self.assertEqual(len(access_total), 1)
        self.assertEqual(next(iter(access_total.values())), 5)
        for metric in cloudflare_metrics.ACCESS_METRICS:
            for key in migrated["series"][metric]:
                labels = cloudflare_metrics._series_labels(key)
                self.assertNotIn("principal", labels)
                self.assertEqual(labels["principal_type"], "user")

        request_series = migrated["series"]["cloudflare_http_requests_total"]
        self.assertEqual(len(request_series), 4)
        self.assertEqual(sum(request_series.values()), 21)
        self.assertIn(
            cloudflare_metrics._series_key(cloudflare_metrics.OVERFLOW_LABELS),
            request_series,
        )

    def test_v1_backup_is_restrictive_and_repeated_load_is_idempotent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = self._write_v1_state(temporary_directory)
            store = cloudflare_metrics.StateStore(path)
            backup_path = store.migration_backup_path(1)
            with mock.patch.object(cloudflare_metrics, "_fsync_directory"):
                first = store.load()
            migrated_bytes = path.read_bytes()
            backup_bytes = backup_path.read_bytes()
            backup_mode = stat.S_IMODE(backup_path.stat().st_mode)

            with (
                mock.patch.object(cloudflare_metrics, "_fsync_directory"),
                mock.patch.object(store, "save", wraps=store.save) as save,
            ):
                second = store.load()

            self.assertEqual(first, second)
            self.assertEqual(path.read_bytes(), migrated_bytes)
            self.assertEqual(backup_path.read_bytes(), backup_bytes)
            save.assert_not_called()

        self.assertEqual(backup_bytes, self.fixture)
        if os.name != "nt":
            self.assertEqual(backup_mode & 0o077, 0)

    def test_newer_state_fails_closed_without_backup_or_rewrite(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "state.json"
            future = cloudflare_metrics.new_state()
            future["version"] = cloudflare_metrics.STATE_VERSION + 1
            original = json.dumps(future, sort_keys=True).encode()
            path.write_bytes(original)
            store = cloudflare_metrics.StateStore(path)

            with self.assertRaisesRegex(ValueError, "newer than supported"):
                store.load()

            self.assertEqual(path.read_bytes(), original)
            self.assertEqual(list(path.parent.glob("state.json.v*.bak")), [])

    def test_v1_backup_restores_previous_schema_for_documented_rollback(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = self._write_v1_state(temporary_directory)
            store = cloudflare_metrics.StateStore(path)
            with mock.patch.object(cloudflare_metrics, "_fsync_directory"):
                store.load()
            backup_path = store.migration_backup_path(1)

            # This mirrors the runbook's stopped-service install step. The v1
            # backup is byte-for-byte usable by the previous collector release.
            path.write_bytes(backup_path.read_bytes())
            restored = json.loads(path.read_text(encoding="utf-8"))

        self.assertEqual(restored["version"], 1)
        legacy_labels = [
            cloudflare_metrics._series_labels(key)
            for key in restored["series"][
                "cloudflare_access_authentications_total"
            ]
        ]
        self.assertTrue(all("principal" in labels for labels in legacy_labels))


class StateRecoveryTests(unittest.TestCase):
    def test_corrupt_json_and_utf8_are_quarantined_and_replaced(self) -> None:
        for name, payload in (("json", b"{broken"), ("utf8", b"\xff\xfe")):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "state.json"
                path.write_bytes(payload)

                state = cloudflare_metrics.StateStore(path).load()

                quarantines = list(path.parent.glob("state.json.corrupt-*"))
                self.assertEqual(len(quarantines), 1)
                self.assertEqual(quarantines[0].read_bytes(), payload)
                if os.name != "nt":
                    self.assertEqual(
                        stat.S_IMODE(quarantines[0].stat().st_mode) & 0o077,
                        0,
                    )
                self.assertEqual(state["version"], cloudflare_metrics.STATE_VERSION)
                self.assertEqual(
                    json.loads(path.read_text(encoding="utf-8")),
                    state,
                )

    def test_invalid_supported_state_shapes_are_quarantined(self) -> None:
        invalid_states: dict[str, dict] = {}

        invalid_states["series-container"] = cloudflare_metrics.new_state()
        invalid_states["series-container"]["series"] = []

        invalid_states["label-key"] = cloudflare_metrics.new_state()
        invalid_states["label-key"]["series"] = {
            "cloudflare_http_requests_total": {"not-json": 1}
        }

        invalid_states["nonfinite"] = cloudflare_metrics.new_state()
        invalid_states["nonfinite"]["series"] = {
            "cloudflare_http_requests_total": {
                cloudflare_metrics._series_key({"host": "example.com"}): float("nan")
            }
        }

        invalid_states["access-seen"] = cloudflare_metrics.new_state()
        invalid_states["access-seen"]["access"]["seen"] = []

        invalid_states["analytics-high-water"] = cloudflare_metrics.new_state()
        invalid_states["analytics-high-water"]["analytics"]["zone"] = {
            "name": "example.com",
            "high_water": "yesterday",
            "seen": {},
            "gap": False,
        }

        for name, invalid in invalid_states.items():
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "state.json"
                original = json.dumps(invalid, allow_nan=True).encode()
                path.write_bytes(original)

                recovered = cloudflare_metrics.StateStore(path).load()

                quarantine = next(path.parent.glob("state.json.corrupt-*"))
                self.assertEqual(quarantine.read_bytes(), original)
                self.assertEqual(
                    recovered["version"], cloudflare_metrics.STATE_VERSION
                )
                cloudflare_metrics.validate_state(recovered)

    def test_quarantine_names_are_unique_without_overwriting_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            store = cloudflare_metrics.StateStore(path)
            with mock.patch.object(cloudflare_metrics.time, "time_ns", return_value=42):
                path.write_bytes(b"{first")
                store.load()
                path.write_bytes(b"{second")
                store.load()

            quarantines = sorted(path.parent.glob("state.json.corrupt-*"))
            self.assertEqual(
                [item.name for item in quarantines],
                ["state.json.corrupt-42", "state.json.corrupt-42-1"],
            )
            self.assertEqual(
                [item.read_bytes() for item in quarantines],
                [b"{first", b"{second"],
            )


class FakeAPI:
    def __init__(
        self,
        *,
        response: dict | None = None,
        fail: bool = False,
        fail_operation: str | None = None,
        access_logs: list[dict] | None = None,
        nonidentity_logs: list[dict] | None = None,
    ):
        self.response = response or {
            "status": [],
            "cache": [],
            "country": [],
            "security": [],
            "visits": [],
        }
        self.fail = fail
        self.fail_operation = fail_operation
        self.access_logs = access_logs or []
        self.nonidentity_logs = nonidentity_logs or []
        self.analytics_calls: list[tuple[str, float, float]] = []
        self.nonidentity_calls: list[tuple[float, float]] = []

    def list_zones(self) -> list[dict]:
        return [{"id": "zone-id", "name": "example.com"}]

    def list_access_apps(self) -> list[dict]:
        return [{"id": "app-id", "name": "Example app"}]

    def query_analytics(self, zone_id: str, start: float, end: float) -> dict:
        self.analytics_calls.append((zone_id, start, end))
        if self.fail:
            raise cloudflare_metrics.CloudflareError("fixture failure")
        return self.response

    def list_access_logs(self, start: float, end: float) -> list[dict]:
        if self.fail or self.fail_operation == "rest-access":
            raise cloudflare_metrics.CloudflareError("fixture failure")
        return self.access_logs

    def query_nonidentity_access_logs(
        self, start: float, end: float
    ) -> list[dict]:
        self.nonidentity_calls.append((start, end))
        if self.fail or self.fail_operation == "graphql-access":
            raise cloudflare_metrics.CloudflareError("fixture failure")
        return self.nonidentity_logs


class MemoryStore:
    def __init__(self, state: dict | None = None):
        self.state = copy.deepcopy(state or cloudflare_metrics.new_state())

    def load(self) -> dict:
        return copy.deepcopy(self.state)

    def save(self, state: dict) -> None:
        self.state = copy.deepcopy(state)


class RecoveryTests(unittest.TestCase):
    def test_truncation_checks_the_registered_analytics_datasets(self) -> None:
        api = FakeAPI(response={"synthetic": [{}, {}]})

        with mock.patch.dict(
            cloudflare_metrics.ANALYTICS_DATASETS,
            {"synthetic": "syntheticAdaptiveGroups"},
            clear=True,
        ):
            with self.assertRaisesRegex(
                cloudflare_metrics.CloudflareError,
                "row limit reached within one five-minute bucket",
            ):
                cloudflare_metrics.query_complete_analytics(
                    api,
                    "zone-id",
                    0,
                    cloudflare_metrics.ANALYTICS_BUCKET_SECONDS,
                    row_limit=2,
                )

    def test_truncated_analytics_ranges_are_bisected(self) -> None:
        class TruncatingAPI(FakeAPI):
            def query_analytics(self, zone_id: str, start: float, end: float) -> dict:
                self.analytics_calls.append((zone_id, start, end))
                response = {
                    "status": [],
                    "cache": [],
                    "country": [],
                    "security": [],
                    "visits": [],
                }
                if end - start > cloudflare_metrics.ANALYTICS_BUCKET_SECONDS:
                    response["status"] = [{}, {}]
                return response

        api = TruncatingAPI()
        start = 0
        end = 4 * cloudflare_metrics.ANALYTICS_BUCKET_SECONDS

        responses = cloudflare_metrics.query_complete_analytics(
            api, "zone-id", start, end, row_limit=2
        )

        self.assertEqual(len(responses), 4)
        leaf_ranges = [
            (call_start, call_end)
            for _zone_id, call_start, call_end in api.analytics_calls
            if call_end - call_start == cloudflare_metrics.ANALYTICS_BUCKET_SECONDS
        ]
        self.assertEqual(len(leaf_ranges), 4)

    def test_single_bucket_truncation_does_not_advance_high_water(self) -> None:
        class LimitedAPI(FakeAPI):
            def query_analytics(self, zone_id: str, start: float, end: float) -> dict:
                self.analytics_calls.append((zone_id, start, end))
                return {
                    "status": [{}, {}],
                    "cache": [],
                    "country": [],
                    "security": [],
                    "visits": [],
                }

        with tempfile.TemporaryDirectory() as temporary_directory:
            store = cloudflare_metrics.StateStore(
                Path(temporary_directory) / "state.json"
            )
            collector = cloudflare_metrics.Collector(
                LimitedAPI(),
                store,
                {"owner@example.com"},
                analytics_row_limit=2,
            )
            collector.zones = [{"id": "zone-id", "name": "example.com"}]

            collector.poll_analytics(12_000)

            snapshot = collector.snapshot()
            self.assertNotIn("zone-id", snapshot["analytics"])
            self.assertEqual(
                cloudflare_metrics.get_series(
                    snapshot,
                    "cloudflare_collector_api_errors_total",
                    {"operation": "analytics"},
                ),
                1,
            )

    def test_truncated_nonidentity_access_ranges_are_bisected(self) -> None:
        class TruncatingAccessAPI(FakeAPI):
            def query_nonidentity_access_logs(
                self, start: float, end: float
            ) -> list[dict]:
                self.nonidentity_calls.append((start, end))
                if end - start > 1:
                    return [{}, {}]
                return []

        api = TruncatingAccessAPI()

        rows = cloudflare_metrics.query_complete_nonidentity_access(
            api, 0, 4, row_limit=2
        )

        self.assertEqual(rows, [])
        self.assertEqual(
            sorted(
                call
                for call in api.nonidentity_calls
                if call[1] - call[0] == 1
            ),
            [(0, 1), (1, 2), (2, 3), (3, 4)],
        )

    def test_history_gap_is_latched_and_query_is_bounded(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            store = cloudflare_metrics.StateStore(
                Path(temporary_directory) / "state.json"
            )
            state = cloudflare_metrics.new_state()
            state["analytics"]["zone-id"] = {
                "name": "example.com",
                "high_water": 1000,
                "seen": {},
                "gap": False,
            }
            store.save(state)
            api = FakeAPI()
            collector = cloudflare_metrics.Collector(
                api, store, {"owner@example.com"}, analytics_window=1800
            )
            collector.zones = [{"id": "zone-id", "name": "example.com"}]
            now = 10_000.0
            expected_end = cloudflare_metrics.floor_timestamp(
                now - cloudflare_metrics.ANALYTICS_DELAY_SECONDS,
                cloudflare_metrics.ANALYTICS_BUCKET_SECONDS,
            )

            collector.poll_analytics(now)

            snapshot = collector.snapshot()
            self.assertEqual(
                cloudflare_metrics.get_series(
                    snapshot,
                    "cloudflare_collector_state_gap",
                    {"zone": "example.com"},
                ),
                1,
            )
            self.assertTrue(snapshot["analytics"]["zone-id"]["gap"])
            self.assertEqual(api.analytics_calls[0][1], expected_end - 1800)

    def test_api_failure_keeps_counters_and_high_water(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            store = cloudflare_metrics.StateStore(
                Path(temporary_directory) / "state.json"
            )
            state = cloudflare_metrics.new_state()
            state["analytics"]["zone-id"] = {
                "name": "example.com",
                "high_water": 9000,
                "seen": {},
                "gap": False,
            }
            cloudflare_metrics.add_series(
                state,
                "cloudflare_http_requests_total",
                {"zone": "example.com", "host": "www.example.com", "status": "200"},
                99,
            )
            store.save(state)
            collector = cloudflare_metrics.Collector(
                FakeAPI(fail=True), store, {"owner@example.com"}
            )
            collector.zones = [{"id": "zone-id", "name": "example.com"}]

            collector.poll_analytics(12_000)

            snapshot = collector.snapshot()
            self.assertEqual(snapshot["analytics"]["zone-id"]["high_water"], 9000)
            self.assertEqual(
                cloudflare_metrics.get_series(
                    snapshot,
                    "cloudflare_http_requests_total",
                    {
                        "zone": "example.com",
                        "host": "www.example.com",
                        "status": "200",
                    },
                ),
                99,
            )
            self.assertEqual(
                cloudflare_metrics.get_series(
                    snapshot,
                    "cloudflare_collector_api_errors_total",
                    {"operation": "analytics"},
                ),
                1,
            )


class AccessTests(unittest.TestCase):
    def test_graphql_query_is_limited_to_nonidentity_rows(self) -> None:
        class CapturingAPI(cloudflare_metrics.CloudflareAPI):
            def __init__(self) -> None:
                super().__init__("token", "account-id")
                self.payload: dict | None = None

            def _request_json(self, method: str, url: str, **kwargs) -> dict:
                self.payload = kwargs["payload"]
                return {
                    "data": {
                        "viewer": {
                            "accounts": [
                                {"accessLoginRequestsAdaptiveGroups": []}
                            ]
                        }
                    }
                }

        api = CapturingAPI()

        self.assertEqual(api.query_nonidentity_access_logs(60, 120), [])
        self.assertIsNotNone(api.payload)
        assert api.payload is not None
        self.assertIn('identityProvider: "nonidentity"', api.payload["query"])
        self.assertEqual(api.payload["variables"]["accountTag"], "account-id")

    def test_missing_allowed_result_is_an_error(self) -> None:
        self.assertEqual(
            cloudflare_metrics.normalize_decision({"action": "login"}), "error"
        )

    def test_owner_classification_is_case_insensitive(self) -> None:
        self.assertEqual(
            cloudflare_metrics.classify_principal(
                "Owner@Example.COM", {"owner@example.com"}
            ),
            ("owner", "true"),
        )

    def test_non_owner_email_is_classified_without_exposing_the_email(
        self,
    ) -> None:
        self.assertEqual(
            cloudflare_metrics.classify_principal(
                "Guest@Example.COM", {"owner@example.com"}
            ),
            ("user", "false"),
        )

    def test_empty_principal_is_unknown(self) -> None:
        self.assertEqual(
            cloudflare_metrics.classify_principal("", {"owner@example.com"}),
            ("unknown", "false"),
        )

    def test_access_events_are_deduplicated_and_keep_last_timestamp(self) -> None:
        state = cloudflare_metrics.new_state()
        events = [
            {
                "ray_id": "ray-one",
                "created_at": "2026-07-15T10:00:00Z",
                "app_uid": "app-id",
                "allowed": True,
                "user_email": "Guest@Example.com",
            },
            {
                "ray_id": "ray-two",
                "created_at": "2026-07-15T10:01:00Z",
                "app_uid": "app-id",
                "allowed": False,
                "user_email": "",
            },
        ]

        added = cloudflare_metrics.apply_access_events(
            state, events, {"app-id": "Example app"}, {"owner@example.com"}
        )
        duplicate_added = cloudflare_metrics.apply_access_events(
            state, events, {"app-id": "Example app"}, {"owner@example.com"}
        )

        self.assertEqual(added, 2)
        self.assertEqual(duplicate_added, 0)
        self.assertEqual(
            cloudflare_metrics.get_series(
                state,
                "cloudflare_access_authentications_total",
                {
                    "app": "Example app",
                    "decision": "allowed",
                    "principal_type": "user",
                    "owner": "false",
                },
            ),
            1,
        )
        self.assertEqual(
            cloudflare_metrics.get_series(
                state,
                "cloudflare_access_authentications_total",
                {
                    "app": "Example app",
                    "decision": "denied",
                    "principal_type": "unknown",
                    "owner": "false",
                },
            ),
            1,
        )

    def test_nonidentity_fixture_classifies_service_tokens_and_unknown_context(
        self,
    ) -> None:
        state = cloudflare_metrics.new_state()
        events = nonidentity_access_fixture()

        added = cloudflare_metrics.apply_nonidentity_access_events(state, events)
        duplicate_added = cloudflare_metrics.apply_nonidentity_access_events(
            state, events
        )

        self.assertEqual(added, 2)
        self.assertEqual(duplicate_added, 0)
        self.assertEqual(
            cloudflare_metrics.get_series(
                state,
                "cloudflare_access_authentications_total",
                {
                    "app": "unknown",
                    "decision": "allowed",
                    "principal_type": "service-token",
                    "owner": "false",
                },
            ),
            1,
        )
        self.assertEqual(
            cloudflare_metrics.get_series(
                state,
                "cloudflare_access_authentications_total",
                {
                    "app": "unknown",
                    "decision": "denied",
                    "principal_type": "unknown",
                    "owner": "false",
                },
            ),
            1,
        )

    def test_graphql_ray_is_not_counted_again_if_rest_returns_it(self) -> None:
        state = cloudflare_metrics.new_state()
        graphql_event = nonidentity_access_fixture()[0]
        rest_event = {
            "ray_id": "ray-service-token",
            "created_at": "2026-07-15T10:02:00Z",
            "app_uid": "app-id",
            "allowed": True,
            "user_email": "",
        }

        self.assertEqual(
            cloudflare_metrics.apply_nonidentity_access_events(
                state, [graphql_event]
            ),
            1,
        )
        self.assertEqual(
            cloudflare_metrics.apply_access_events(
                state,
                [rest_event],
                {"app-id": "Example app"},
                {"owner@example.com"},
            ),
            0,
        )
        self.assertEqual(
            cloudflare_metrics.get_series(
                state,
                "cloudflare_access_authentications_total",
                {
                    "app": "unknown",
                    "decision": "allowed",
                    "principal_type": "service-token",
                    "owner": "false",
                },
            ),
            1,
        )

    def test_identity_graphql_row_fails_closed(self) -> None:
        state = cloudflare_metrics.new_state()
        row = copy.deepcopy(nonidentity_access_fixture()[1])
        row["dimensions"]["identityProvider"] = "google"

        with self.assertRaisesRegex(
            cloudflare_metrics.CloudflareError, "identity-based row"
        ):
            cloudflare_metrics.apply_nonidentity_access_events(state, [row])

        self.assertEqual(
            state["series"].get("cloudflare_access_authentications_total", {}), {}
        )

    def test_access_high_water_does_not_advance_when_either_api_fails(self) -> None:
        for operation in ("graphql-access", "rest-access"):
            with self.subTest(operation=operation):
                state = cloudflare_metrics.new_state()
                state["access"]["high_water"] = 9000
                collector = cloudflare_metrics.Collector(
                    FakeAPI(fail_operation=operation),
                    MemoryStore(state),
                    {"owner@example.com"},
                )
                collector.apps = {"app-id": "Example app"}

                collector.poll_access(12_000)

                snapshot = collector.snapshot()
                self.assertEqual(snapshot["access"]["high_water"], 9000)
                self.assertEqual(
                    cloudflare_metrics.get_series(
                        snapshot,
                        "cloudflare_collector_api_errors_total",
                        {"operation": "access"},
                    ),
                    1,
                )

    def test_legacy_principal_series_are_aggregated_without_identity_labels(
        self,
    ) -> None:
        state = cloudflare_metrics.new_state()
        authentications = state["series"].setdefault(
            "cloudflare_access_authentications_total", {}
        )
        for principal in ("first@example.com", "second@example.com"):
            key = cloudflare_metrics._series_key(
                {
                    "app": "Example app",
                    "decision": "allowed",
                    "principal": principal,
                    "owner": "false",
                }
            )
            authentications[key] = 1
        last_authentication = state["series"].setdefault(
            "cloudflare_access_last_authentication_timestamp_seconds", {}
        )
        last_authentication[
            cloudflare_metrics._series_key(
                {
                "app": "Example app",
                "decision": "allowed",
                "principal": "owner@example.com",
                "owner": "true",
                }
            )
        ] = 1_700_000_000

        rendered = cloudflare_metrics.render_metrics(state)

        self.assertNotIn("principal=", rendered)
        self.assertNotIn("@example.com", rendered)
        self.assertIn(
            "cloudflare_access_authentications_total"
            '{app="Example app",decision="allowed",owner="false",'
            'principal_type="user"} 2',
            rendered,
        )
        self.assertIn(
            "cloudflare_access_last_authentication_timestamp_seconds"
            '{app="Example app",decision="allowed",owner="true",'
            'principal_type="owner"} 1700000000',
            rendered,
        )

        self.assertTrue(cloudflare_metrics.sanitize_legacy_access_series(state))
        for metric in cloudflare_metrics.ACCESS_METRICS:
            for key in state["series"].get(metric, {}):
                self.assertNotIn("principal", cloudflare_metrics._series_labels(key))


class RuntimeCollector:
    def __init__(self, fail: str | None = None) -> None:
        self.fail = fail
        self.calls: list[tuple[str, float]] = []
        self.errors: list[str] = []
        self.started = threading.Event()

    def _call(self, operation: str, now: float) -> None:
        self.calls.append((operation, now))
        self.started.set()
        if self.fail == operation:
            raise RuntimeError(f"fixture {operation} failure")

    def refresh_inventory(self, now: float) -> None:
        self._call("inventory", now)

    def poll_analytics(self, now: float) -> None:
        self._call("analytics", now)

    def poll_access(self, now: float) -> None:
        self._call("access", now)

    def record_error(self, operation: str) -> None:
        self.errors.append(operation)


class RuntimeTests(unittest.TestCase):
    def test_run_once_schedules_due_polls_without_sleeping(self) -> None:
        collector = RuntimeCollector()
        service = cloudflare_metrics.CollectorService(
            collector, analytics_interval=300, access_interval=60
        )

        deadlines = service.run_once(100, 0, 0)
        service.run_once(120, *deadlines)

        self.assertEqual(
            collector.calls,
            [("inventory", 100), ("analytics", 100), ("access", 100)],
        )
        self.assertEqual(deadlines, (400, 160))

    def test_run_once_contains_loop_exceptions_and_runs_other_poll(self) -> None:
        collector = RuntimeCollector(fail="inventory")
        service = cloudflare_metrics.CollectorService(
            collector, analytics_interval=300, access_interval=60
        )

        deadlines = service.run_once(100, 0, 0)

        self.assertEqual(deadlines, (400, 160))
        self.assertEqual(collector.errors, ["analytics-loop"])
        self.assertIn(("access", 100), collector.calls)

    def test_stop_wakes_waiting_worker_promptly(self) -> None:
        collector = RuntimeCollector()
        service = cloudflare_metrics.CollectorService(
            collector,
            analytics_interval=3600,
            access_interval=3600,
            clock=lambda: 100,
        )
        worker = threading.Thread(target=service.run, daemon=True)
        worker.start()
        self.assertTrue(collector.started.wait(timeout=1))

        service.stop()
        worker.join(timeout=1)

        self.assertFalse(worker.is_alive())

    def test_threaded_http_endpoints_concurrency_and_shutdown(self) -> None:
        class HTTPCollector:
            def __init__(self) -> None:
                self.lock = threading.Lock()
                self.active = 0
                self.concurrent = False
                self.release = threading.Event()

            def metrics(self) -> str:
                with self.lock:
                    self.active += 1
                    if self.active > 1:
                        self.concurrent = True
                        self.release.set()
                try:
                    if not self.release.wait(timeout=1):
                        raise AssertionError("second metrics request did not overlap")
                    return "fixture_metric 1\n"
                finally:
                    with self.lock:
                        self.active -= 1

        collector = HTTPCollector()
        server = ThreadingHTTPServer(
            ("127.0.0.1", 0), cloudflare_metrics.make_handler(collector)
        )
        server_thread = threading.Thread(
            target=server.serve_forever,
            kwargs={"poll_interval": 0.01},
            daemon=True,
        )
        server_thread.start()
        base = f"http://127.0.0.1:{server.server_address[1]}"
        try:
            with urllib.request.urlopen(f"{base}/-/healthy", timeout=2) as response:
                self.assertEqual(response.status, 200)
                self.assertEqual(response.read(), b"ok\n")
            with self.assertRaises(urllib.error.HTTPError) as missing:
                urllib.request.urlopen(f"{base}/missing", timeout=2)
            self.assertEqual(missing.exception.code, 404)

            payloads: list[bytes] = []
            failures: list[BaseException] = []

            def fetch_metrics() -> None:
                try:
                    with urllib.request.urlopen(
                        f"{base}/metrics", timeout=2
                    ) as response:
                        payloads.append(response.read())
                except BaseException as error:
                    failures.append(error)

            clients = [threading.Thread(target=fetch_metrics) for _ in range(2)]
            for client in clients:
                client.start()
            for client in clients:
                client.join(timeout=2)

            self.assertTrue(all(not client.is_alive() for client in clients))
            self.assertEqual(failures, [])
            self.assertEqual(payloads, [b"fixture_metric 1\n"] * 2)
            self.assertTrue(collector.concurrent)
        finally:
            server.shutdown()
            server.server_close()
            server_thread.join(timeout=2)

        self.assertFalse(server_thread.is_alive())


class PaginationAPI(cloudflare_metrics.CloudflareAPI):
    def __init__(self) -> None:
        super().__init__("token", "account")
        self.pages: list[int] = []

    def _request_json(self, method: str, url: str, **kwargs) -> dict:
        page = kwargs["params"]["page"]
        self.pages.append(page)
        results = {
            1: [{"id": "one"}, {"id": "two"}],
            2: [{"id": "three"}],
        }[page]
        return {
            "success": True,
            "result": results,
            "result_info": {"page": page, "total_pages": 2},
        }


class UtilityTests(unittest.TestCase):
    def test_rest_pagination_collects_every_page(self) -> None:
        api = PaginationAPI()

        results = api._paginate("/fixture", per_page=2)

        self.assertEqual([item["id"] for item in results], ["one", "two", "three"])
        self.assertEqual(api.pages, [1, 2])

    def test_hostname_normalization(self) -> None:
        self.assertEqual(
            cloudflare_metrics.normalize_hostname("HTTPS://WWW.Example.COM.:443/path"),
            "www.example.com",
        )
        self.assertEqual(
            cloudflare_metrics.normalize_hostname("BÜCHER.example."),
            "xn--bcher-kva.example",
        )

    def test_prometheus_label_escaping(self) -> None:
        escaped = cloudflare_metrics.escape_label('line one\\two\n"quoted"')
        self.assertEqual(escaped, 'line one\\\\two\\n\\"quoted\\"')
        state = cloudflare_metrics.new_state()
        cloudflare_metrics.set_series(
            state,
            "cloudflare_collector_state_gap",
            {"zone": 'bad"zone\nname'},
            1,
        )
        rendered = cloudflare_metrics.render_metrics(state)
        self.assertIn('zone="bad\\"zone\\nname"', rendered)

    def test_duration_parser(self) -> None:
        self.assertEqual(cloudflare_metrics.parse_duration("5m"), 300)
        self.assertEqual(cloudflare_metrics.parse_duration("1min"), 60)
        with self.assertRaises(ValueError):
            cloudflare_metrics.parse_duration("tomorrow")


if __name__ == "__main__":
    unittest.main()
