from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


SOURCE = (
    Path(__file__).parents[2]
    / "modules"
    / "services"
    / "scripts"
    / "cloudflare_metrics.py"
)
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


class AnalyticsTests(unittest.TestCase):
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


class FakeAPI:
    def __init__(self, *, response: dict | None = None, fail: bool = False):
        self.response = response or {
            "status": [],
            "cache": [],
            "country": [],
            "security": [],
            "visits": [],
        }
        self.fail = fail
        self.analytics_calls: list[tuple[str, float, float]] = []

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
        if self.fail:
            raise cloudflare_metrics.CloudflareError("fixture failure")
        return []


class RecoveryTests(unittest.TestCase):
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
    def test_missing_allowed_result_is_an_error(self) -> None:
        self.assertEqual(
            cloudflare_metrics.normalize_decision({"action": "login"}), "error"
        )

    def test_owner_classification_is_case_insensitive(self) -> None:
        self.assertEqual(
            cloudflare_metrics.classify_principal(
                "Owner@Example.COM", {"owner@example.com"}
            ),
            ("owner@example.com", "true"),
        )

    def test_empty_principal_is_a_non_owner_service_token(self) -> None:
        self.assertEqual(
            cloudflare_metrics.classify_principal("", {"owner@example.com"}),
            ("service-token", "false"),
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
                    "principal": "guest@example.com",
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
                    "principal": "service-token",
                    "owner": "false",
                },
            ),
            1,
        )


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
