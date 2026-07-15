#!/usr/bin/env python3
"""Cloudflare analytics and Access Prometheus collector.

The collector intentionally uses only the Python standard library. Cloudflare's
adaptive GraphQL values are already estimates; they are exported without
applying the reported sample interval a second time.
"""

from __future__ import annotations

import copy
import hashlib
import json
import logging
import math
import os
import re
import signal
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable, Iterable, Mapping
from datetime import UTC, datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


LOG = logging.getLogger("cloudflare-metrics")

API_BASE = "https://api.cloudflare.com/client/v4"
GRAPHQL_URL = "https://api.cloudflare.com/client/v4/graphql"

ANALYTICS_DELAY_SECONDS = 10 * 60
ANALYTICS_BUCKET_SECONDS = 5 * 60
ANALYTICS_OVERLAP_SECONDS = 10 * 60
ANALYTICS_WINDOW_SECONDS = 8 * 24 * 60 * 60
ANALYTICS_CHUNK_SECONDS = 6 * 60 * 60
ANALYTICS_ROW_LIMIT = 10_000
ACCESS_OVERLAP_SECONDS = 5 * 60
ACCESS_SEEN_SECONDS = 8 * 24 * 60 * 60

ANALYTICS_QUERY = r"""
query CloudflareMetrics($zoneTag: string, $start: Time, $end: Time) {
  viewer {
    zones(filter: {zoneTag: $zoneTag}) {
      status: httpRequestsAdaptiveGroups(
        limit: 10000
        orderBy: [datetimeFiveMinutes_ASC]
        filter: {
          datetime_geq: $start
          datetime_lt: $end
          requestSource: "eyeball"
        }
      ) {
        count
        avg { sampleInterval }
        sum { clientRequestBytes edgeResponseBytes }
        dimensions {
          datetimeFiveMinutes
          clientRequestHTTPHost
          edgeResponseStatus
        }
      }
      cache: httpRequestsAdaptiveGroups(
        limit: 10000
        orderBy: [datetimeFiveMinutes_ASC]
        filter: {
          datetime_geq: $start
          datetime_lt: $end
          requestSource: "eyeball"
        }
      ) {
        count
        dimensions {
          datetimeFiveMinutes
          clientRequestHTTPHost
          cacheStatus
        }
      }
      country: httpRequestsAdaptiveGroups(
        limit: 10000
        orderBy: [datetimeFiveMinutes_ASC]
        filter: {
          datetime_geq: $start
          datetime_lt: $end
          requestSource: "eyeball"
        }
      ) {
        count
        dimensions { datetimeFiveMinutes clientCountryName }
      }
      security: httpRequestsAdaptiveGroups(
        limit: 10000
        orderBy: [datetimeFiveMinutes_ASC]
        filter: {
          datetime_geq: $start
          datetime_lt: $end
          requestSource: "eyeball"
        }
      ) {
        count
        dimensions {
          datetimeFiveMinutes
          clientRequestHTTPHost
          securityAction
          securitySource
        }
      }
      visits: httpRequestsAdaptiveGroups(
        limit: 10000
        orderBy: [datetimeFiveMinutes_ASC]
        filter: {
          datetime_geq: $start
          datetime_lt: $end
          requestSource: "eyeball"
        }
      ) {
        sum { visits }
        dimensions { datetimeFiveMinutes clientRequestHTTPHost }
      }
    }
  }
}
"""


METRIC_SPECS: dict[str, tuple[str, str]] = {
    "cloudflare_http_requests_total": (
        "counter",
        "Estimated Cloudflare HTTP requests collected from adaptive analytics.",
    ),
    "cloudflare_http_request_bytes_total": (
        "counter",
        "Estimated HTTP request bytes collected from Cloudflare adaptive analytics.",
    ),
    "cloudflare_http_response_bytes_total": (
        "counter",
        "Estimated HTTP response bytes collected from Cloudflare adaptive analytics.",
    ),
    "cloudflare_http_cache_requests_total": (
        "counter",
        "Estimated Cloudflare HTTP requests by cache status.",
    ),
    "cloudflare_http_requests_country_total": (
        "counter",
        "Estimated Cloudflare HTTP requests by client country.",
    ),
    "cloudflare_http_security_actions_total": (
        "counter",
        "Estimated Cloudflare HTTP requests by aggregate security action.",
    ),
    "cloudflare_http_visits_total": (
        "counter",
        "Estimated Cloudflare visits collected from adaptive analytics.",
    ),
    "cloudflare_access_authentications_total": (
        "counter",
        "Cloudflare Access authentication events.",
    ),
    "cloudflare_access_last_authentication_timestamp_seconds": (
        "gauge",
        "Unix timestamp of the latest Cloudflare Access authentication event.",
    ),
    "cloudflare_collector_last_success_timestamp_seconds": (
        "gauge",
        "Unix timestamp of the collector's latest successful poll.",
    ),
    "cloudflare_collector_api_errors_total": (
        "counter",
        "Cloudflare API or collector state errors by operation.",
    ),
    "cloudflare_collector_sample_interval": (
        "gauge",
        "Largest Cloudflare adaptive sample interval observed in the latest query.",
    ),
    "cloudflare_collector_state_gap": (
        "gauge",
        "Whether an irreversible analytics history gap has been detected.",
    ),
    "cloudflare_collector_catch_up": (
        "gauge",
        "Number of completed intervals awaiting catch-up when a poll began.",
    ),
}


class CloudflareError(RuntimeError):
    """Raised when Cloudflare returns an unsuccessful response."""


def parse_duration(value: str) -> int:
    """Parse a compact duration such as 30s, 5m, 2h, or 1d."""
    match = re.fullmatch(r"\s*(\d+)\s*(s|sec|m|min|h|hr|d|day)s?\s*", value, re.I)
    if not match:
        raise ValueError(f"unsupported duration: {value!r}")
    amount = int(match.group(1))
    unit = match.group(2).lower()
    multiplier = {
        "s": 1,
        "sec": 1,
        "m": 60,
        "min": 60,
        "h": 3600,
        "hr": 3600,
        "d": 86400,
        "day": 86400,
    }[unit]
    if amount <= 0:
        raise ValueError("duration must be positive")
    return amount * multiplier


def parse_timestamp(value: str | None) -> float:
    if not value:
        raise ValueError("missing timestamp")
    normalized = value.strip()
    if normalized.endswith("Z"):
        normalized = normalized[:-1] + "+00:00"
    parsed = datetime.fromisoformat(normalized)
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=UTC)
    return parsed.timestamp()


def format_timestamp(value: float) -> str:
    return (
        datetime.fromtimestamp(value, UTC)
        .isoformat(timespec="seconds")
        .replace("+00:00", "Z")
    )


def floor_timestamp(value: float, interval: int) -> float:
    return math.floor(value / interval) * interval


def normalize_hostname(value: Any, fallback: str = "unknown") -> str:
    """Normalize a host or URL into a stable lower-case hostname label."""
    text = str(value or "").strip().lower()
    if not text:
        return fallback
    candidate = text if "://" in text else f"//{text}"
    try:
        hostname = urllib.parse.urlsplit(candidate).hostname
    except ValueError:
        hostname = None
    normalized = (hostname or text).rstrip(".")
    try:
        normalized = normalized.encode("idna").decode("ascii")
    except UnicodeError:
        pass
    return normalized or fallback


def normalize_word(value: Any, fallback: str = "unknown") -> str:
    normalized = str(value or "").strip().lower()
    return normalized or fallback


def classify_principal(email: Any, owner_emails: set[str]) -> tuple[str, str]:
    principal = str(email or "").strip().lower()
    if not principal:
        return "service-token", "false"
    return principal, "true" if principal in owner_emails else "false"


def normalize_decision(event: Mapping[str, Any]) -> str:
    allowed = event.get("allowed")
    if allowed is True:
        return "allowed"
    if allowed is False:
        return "denied"
    # Cloudflare documents ``action`` as the event type and ``allowed`` as the
    # authentication result. Do not turn an ambiguous login event into a
    # successful authentication when the result is absent.
    return "error"


def escape_label(value: Any) -> str:
    return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


def _series_key(labels: Mapping[str, str]) -> str:
    return json.dumps(sorted(labels.items()), separators=(",", ":"), ensure_ascii=True)


def _series_labels(key: str) -> dict[str, str]:
    return dict(json.loads(key))


def new_state() -> dict[str, Any]:
    state: dict[str, Any] = {
        "version": 1,
        "series": {},
        "analytics": {},
        "access": {"high_water": None, "seen": {}},
    }
    set_series(state, "cloudflare_collector_catch_up", {"poll": "analytics"}, 0)
    set_series(state, "cloudflare_collector_catch_up", {"poll": "access"}, 0)
    return state


def add_series(
    state: dict[str, Any], metric: str, labels: Mapping[str, str], value: Any
) -> None:
    number = float(value or 0)
    if not math.isfinite(number):
        return
    series = state.setdefault("series", {}).setdefault(metric, {})
    key = _series_key(labels)
    series[key] = float(series.get(key, 0)) + number


def set_series(
    state: dict[str, Any], metric: str, labels: Mapping[str, str], value: Any
) -> None:
    number = float(value or 0)
    if not math.isfinite(number):
        return
    state.setdefault("series", {}).setdefault(metric, {})[_series_key(labels)] = number


def get_series(
    state: Mapping[str, Any], metric: str, labels: Mapping[str, str]
) -> float:
    return float(state.get("series", {}).get(metric, {}).get(_series_key(labels), 0))


def render_metrics(state: Mapping[str, Any]) -> str:
    lines: list[str] = []
    all_series = state.get("series", {})
    for metric, (metric_type, help_text) in METRIC_SPECS.items():
        lines.append(f"# HELP {metric} {help_text}")
        lines.append(f"# TYPE {metric} {metric_type}")
        for key, value in sorted(all_series.get(metric, {}).items()):
            labels = _series_labels(key)
            suffix = ""
            if labels:
                rendered = ",".join(
                    f'{name}="{escape_label(label)}"'
                    for name, label in sorted(labels.items())
                )
                suffix = "{" + rendered + "}"
            number = float(value)
            output = str(int(number)) if number.is_integer() else repr(number)
            lines.append(f"{metric}{suffix} {output}")
    return "\n".join(lines) + "\n"


class StateStore:
    def __init__(self, path: str | Path):
        self.path = Path(path)

    def load(self) -> dict[str, Any]:
        if not self.path.exists():
            return new_state()
        with self.path.open(encoding="utf-8") as handle:
            state = json.load(handle)
        if state.get("version") != 1:
            raise ValueError("unsupported collector state version")
        return state

    def save(self, state: Mapping[str, Any]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temporary_name: str | None = None
        try:
            with tempfile.NamedTemporaryFile(
                "w",
                encoding="utf-8",
                dir=self.path.parent,
                prefix=f".{self.path.name}.",
                delete=False,
            ) as handle:
                temporary_name = handle.name
                json.dump(state, handle, sort_keys=True, separators=(",", ":"))
                handle.write("\n")
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary_name, self.path)
            temporary_name = None
            directory_fd = os.open(self.path.parent, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
        finally:
            if temporary_name is not None:
                try:
                    os.unlink(temporary_name)
                except FileNotFoundError:
                    pass


class CloudflareAPI:
    def __init__(self, api_token: str, account_id: str, timeout: int = 30):
        self.api_token = api_token
        self.account_id = account_id
        self.timeout = timeout

    def _request_json(
        self,
        method: str,
        url: str,
        *,
        params: Mapping[str, Any] | None = None,
        payload: Mapping[str, Any] | None = None,
    ) -> dict[str, Any]:
        if params:
            url = f"{url}?{urllib.parse.urlencode(params, doseq=True)}"
        data = None
        headers = {
            "Accept": "application/json",
            "Authorization": f"Bearer {self.api_token}",
            "User-Agent": "cloudflare-metrics/1",
        }
        if payload is not None:
            data = json.dumps(payload).encode()
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                body = json.load(response)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
            raise CloudflareError(f"Cloudflare request failed: {error}") from error
        if not isinstance(body, dict):
            raise CloudflareError("Cloudflare returned a non-object response")
        if body.get("success") is False or body.get("errors"):
            raise CloudflareError(f"Cloudflare API error: {body.get('errors')}")
        return body

    def _paginate(
        self, path: str, params: Mapping[str, Any] | None = None, per_page: int = 100
    ) -> list[dict[str, Any]]:
        results: list[dict[str, Any]] = []
        page = 1
        while True:
            page_params = dict(params or {})
            page_params.update({"page": page, "per_page": per_page})
            response = self._request_json(
                "GET", f"{API_BASE}{path}", params=page_params
            )
            batch = response.get("result") or []
            if not isinstance(batch, list):
                raise CloudflareError("Cloudflare paginated result was not a list")
            results.extend(item for item in batch if isinstance(item, dict))
            result_info = response.get("result_info") or {}
            total_pages = int(result_info.get("total_pages") or 0)
            if (total_pages and page >= total_pages) or len(batch) < per_page:
                break
            page += 1
        return results

    def list_zones(self) -> list[dict[str, Any]]:
        return self._paginate(
            "/zones",
            {"account.id": self.account_id, "status": "active"},
            per_page=50,
        )

    def list_access_apps(self) -> list[dict[str, Any]]:
        return self._paginate(f"/accounts/{self.account_id}/access/apps", per_page=50)

    def query_analytics(self, zone_id: str, start: float, end: float) -> dict[str, Any]:
        response = self._request_json(
            "POST",
            GRAPHQL_URL,
            payload={
                "query": ANALYTICS_QUERY,
                "variables": {
                    "zoneTag": zone_id,
                    "start": format_timestamp(start),
                    "end": format_timestamp(end),
                },
            },
        )
        try:
            zones = response["data"]["viewer"]["zones"]
            zone = zones[0]
        except (KeyError, IndexError, TypeError) as error:
            raise CloudflareError(
                "Cloudflare GraphQL response omitted zone data"
            ) from error
        if not isinstance(zone, dict):
            raise CloudflareError("Cloudflare GraphQL zone data was invalid")
        return zone

    def list_access_logs(self, start: float, end: float) -> list[dict[str, Any]]:
        return self._paginate(
            f"/accounts/{self.account_id}/access/logs/access_requests",
            {
                "direction": "asc",
                "since": format_timestamp(start),
                "until": format_timestamp(end),
            },
            per_page=1000,
        )


def _analytics_identity(alias: str, row: Mapping[str, Any]) -> tuple[str, float]:
    dimensions = row.get("dimensions") or {}
    bucket = parse_timestamp(dimensions.get("datetimeFiveMinutes"))
    identity = hashlib.sha256(
        json.dumps(
            [alias, dimensions.get("datetimeFiveMinutes"), dimensions],
            sort_keys=True,
            separators=(",", ":"),
        ).encode()
    ).hexdigest()
    return identity, bucket


def apply_analytics_response(
    state: dict[str, Any], zone_id: str, zone_name: str, response: Mapping[str, Any]
) -> int:
    """Apply one GraphQL response and return the number of new grouped rows."""
    zone_state = state.setdefault("analytics", {}).setdefault(
        zone_id, {"name": zone_name, "high_water": None, "seen": {}, "gap": False}
    )
    zone_state["name"] = zone_name
    seen: dict[str, float] = zone_state.setdefault("seen", {})
    added = 0
    sample_intervals: list[float] = []

    for alias in ("status", "cache", "country", "security", "visits"):
        rows = response.get(alias) or []
        if not isinstance(rows, list):
            raise CloudflareError(f"GraphQL field {alias} was not a list")
        for row in rows:
            if not isinstance(row, dict):
                raise CloudflareError(f"GraphQL field {alias} contained an invalid row")
            identity, bucket = _analytics_identity(alias, row)
            avg = row.get("avg") or {}
            if avg.get("sampleInterval") is not None:
                sample_intervals.append(float(avg["sampleInterval"]))
            if identity in seen:
                continue

            dimensions = row.get("dimensions") or {}
            host = normalize_hostname(
                dimensions.get("clientRequestHTTPHost"), zone_name
            )
            count = float(row.get("count") or 0)
            sums = row.get("sum") or {}

            if alias == "status":
                status = str(dimensions.get("edgeResponseStatus") or "unknown")
                add_series(
                    state,
                    "cloudflare_http_requests_total",
                    {"zone": zone_name, "host": host, "status": status},
                    count,
                )
                add_series(
                    state,
                    "cloudflare_http_request_bytes_total",
                    {"zone": zone_name, "host": host},
                    sums.get("clientRequestBytes", 0),
                )
                add_series(
                    state,
                    "cloudflare_http_response_bytes_total",
                    {"zone": zone_name, "host": host},
                    sums.get("edgeResponseBytes", 0),
                )
            elif alias == "cache":
                add_series(
                    state,
                    "cloudflare_http_cache_requests_total",
                    {
                        "zone": zone_name,
                        "host": host,
                        "cache_status": normalize_word(dimensions.get("cacheStatus")),
                    },
                    count,
                )
            elif alias == "country":
                country = str(dimensions.get("clientCountryName") or "unknown").upper()
                add_series(
                    state,
                    "cloudflare_http_requests_country_total",
                    {"zone": zone_name, "country": country},
                    count,
                )
            elif alias == "security":
                add_series(
                    state,
                    "cloudflare_http_security_actions_total",
                    {
                        "zone": zone_name,
                        "host": host,
                        "action": normalize_word(dimensions.get("securityAction")),
                        "source": normalize_word(dimensions.get("securitySource")),
                    },
                    count,
                )
            elif alias == "visits":
                add_series(
                    state,
                    "cloudflare_http_visits_total",
                    {"zone": zone_name, "host": host},
                    sums.get("visits", 0),
                )

            seen[identity] = bucket
            added += 1

    if sample_intervals:
        set_series(
            state,
            "cloudflare_collector_sample_interval",
            {"zone": zone_name},
            max(sample_intervals),
        )
    return added


def _access_identity(event: Mapping[str, Any]) -> str:
    if event.get("ray_id"):
        return str(event["ray_id"])
    material = [
        event.get("created_at"),
        event.get("app_uid"),
        event.get("app_domain"),
        event.get("user_email"),
        event.get("action"),
        event.get("allowed"),
    ]
    return hashlib.sha256(
        json.dumps(material, separators=(",", ":"), sort_keys=True).encode()
    ).hexdigest()


def apply_access_events(
    state: dict[str, Any],
    events: Iterable[Mapping[str, Any]],
    apps: Mapping[str, str],
    owner_emails: set[str],
) -> int:
    access_state = state.setdefault("access", {"high_water": None, "seen": {}})
    seen: dict[str, float] = access_state.setdefault("seen", {})
    added = 0
    for event in events:
        event_time = parse_timestamp(event.get("created_at"))
        identity = _access_identity(event)
        if identity in seen:
            continue
        principal, owner = classify_principal(event.get("user_email"), owner_emails)
        app_id = str(event.get("app_uid") or "")
        app = apps.get(app_id)
        if not app:
            app = normalize_hostname(event.get("app_domain"), app_id or "unknown")
        labels = {
            "app": app,
            "decision": normalize_decision(event),
            "principal": principal,
            "owner": owner,
        }
        add_series(state, "cloudflare_access_authentications_total", labels, 1)
        last = get_series(
            state, "cloudflare_access_last_authentication_timestamp_seconds", labels
        )
        set_series(
            state,
            "cloudflare_access_last_authentication_timestamp_seconds",
            labels,
            max(last, event_time),
        )
        seen[identity] = event_time
        added += 1
    return added


def chunk_ranges(start: float, end: float, size: int) -> Iterable[tuple[float, float]]:
    cursor = start
    while cursor < end:
        chunk_end = min(cursor + size, end)
        yield cursor, chunk_end
        cursor = chunk_end


def query_complete_analytics(
    api: CloudflareAPI,
    zone_id: str,
    start: float,
    end: float,
    *,
    row_limit: int = ANALYTICS_ROW_LIMIT,
) -> list[dict[str, Any]]:
    """Fetch a range without silently accepting GraphQL row-limit truncation.

    Cloudflare's analytics GraphQL API has no cursors. Time-filter bisection is
    therefore used until every response is below the configured dataset page
    limit. A single overfull five-minute bucket is rejected so the caller does
    not advance its durable high-water mark past missing data.
    """
    response = api.query_analytics(zone_id, start, end)
    limited = False
    for alias in ("status", "cache", "country", "security", "visits"):
        rows = response.get(alias) or []
        if not isinstance(rows, list):
            raise CloudflareError(f"GraphQL field {alias} was not a list")
        limited = limited or len(rows) >= row_limit
    if not limited:
        return [response]

    if end - start <= ANALYTICS_BUCKET_SECONDS:
        raise CloudflareError(
            "Cloudflare analytics row limit reached within one five-minute bucket"
        )

    bucket_count = int((end - start) // ANALYTICS_BUCKET_SECONDS)
    split = start + max(1, bucket_count // 2) * ANALYTICS_BUCKET_SECONDS
    if split <= start or split >= end:
        raise CloudflareError("unable to bisect a truncated analytics response")

    return query_complete_analytics(
        api, zone_id, start, split, row_limit=row_limit
    ) + query_complete_analytics(api, zone_id, split, end, row_limit=row_limit)


class Collector:
    def __init__(
        self,
        api: CloudflareAPI,
        store: StateStore,
        owner_emails: set[str],
        *,
        analytics_window: int = ANALYTICS_WINDOW_SECONDS,
        analytics_row_limit: int = ANALYTICS_ROW_LIMIT,
    ):
        self.api = api
        self.store = store
        self.owner_emails = {
            email.strip().lower() for email in owner_emails if email.strip()
        }
        self.analytics_window = analytics_window
        self.analytics_row_limit = analytics_row_limit
        self.lock = threading.RLock()
        self.state = store.load()
        self.zones: list[dict[str, Any]] = []
        self.apps: dict[str, str] = {}

    def _commit(self, change: Callable[[dict[str, Any]], None]) -> None:
        with self.lock:
            pending = copy.deepcopy(self.state)
            change(pending)
            self.store.save(pending)
            self.state = pending

    def snapshot(self) -> dict[str, Any]:
        with self.lock:
            return copy.deepcopy(self.state)

    def metrics(self) -> str:
        with self.lock:
            return render_metrics(self.state)

    def record_error(self, operation: str) -> None:
        try:
            self._commit(
                lambda state: add_series(
                    state,
                    "cloudflare_collector_api_errors_total",
                    {"operation": operation},
                    1,
                )
            )
        except OSError:
            LOG.exception("failed to persist collector error state")

    def refresh_inventory(self, now: float) -> None:
        try:
            zones = self.api.list_zones()
            apps = self.api.list_access_apps()
            normalized_zones = [
                {"id": str(zone["id"]), "name": normalize_hostname(zone.get("name"))}
                for zone in zones
                if zone.get("id")
            ]
            normalized_apps = {
                str(app["id"]): str(app.get("name") or app.get("domain") or app["id"])
                for app in apps
                if app.get("id")
            }
        except (CloudflareError, KeyError, TypeError, ValueError):
            self.record_error("inventory")
            raise

        self.zones = normalized_zones
        self.apps = normalized_apps
        self._commit(
            lambda state: set_series(
                state,
                "cloudflare_collector_last_success_timestamp_seconds",
                {"poll": "inventory"},
                now,
            )
        )

    def poll_analytics(self, now: float | None = None) -> None:
        now = time.time() if now is None else now
        end = floor_timestamp(now - ANALYTICS_DELAY_SECONDS, ANALYTICS_BUCKET_SECONDS)
        if end <= 0:
            return
        if not self.zones:
            try:
                self.refresh_inventory(now)
            except (CloudflareError, KeyError, TypeError, ValueError):
                return

        all_succeeded = True
        maximum_catch_up = 0
        for zone in self.zones:
            zone_id = zone["id"]
            zone_name = zone["name"]
            snapshot = self.snapshot()
            saved_zone = snapshot.get("analytics", {}).get(zone_id)
            first_poll = saved_zone is None or saved_zone.get("high_water") is None
            if first_poll:
                start = end - ANALYTICS_BUCKET_SECONDS
                catch_up = 0
                gap = False
            else:
                high_water = float(saved_zone["high_water"])
                oldest = end - self.analytics_window
                gap = high_water < oldest
                start = max(high_water - ANALYTICS_OVERLAP_SECONDS, oldest)
                missing = max(0, int((end - high_water) / ANALYTICS_BUCKET_SECONDS))
                catch_up = max(0, missing - 1)
            maximum_catch_up = max(maximum_catch_up, catch_up)

            try:
                responses = []
                for chunk_start, chunk_end in chunk_ranges(
                    start, end, ANALYTICS_CHUNK_SECONDS
                ):
                    responses.extend(
                        query_complete_analytics(
                            self.api,
                            zone_id,
                            chunk_start,
                            chunk_end,
                            row_limit=self.analytics_row_limit,
                        )
                    )
            except CloudflareError:
                all_succeeded = False
                self.record_error("analytics")
                LOG.exception("Cloudflare analytics poll failed for zone %s", zone_name)
                continue

            def apply_zone(state: dict[str, Any]) -> None:
                for response in responses:
                    apply_analytics_response(state, zone_id, zone_name, response)
                zone_state = state.setdefault("analytics", {}).setdefault(
                    zone_id,
                    {"name": zone_name, "high_water": None, "seen": {}, "gap": False},
                )
                zone_state["name"] = zone_name
                zone_state["high_water"] = end
                zone_state["gap"] = bool(zone_state.get("gap")) or gap
                cutoff = end - self.analytics_window - ANALYTICS_OVERLAP_SECONDS
                zone_state["seen"] = {
                    identity: timestamp
                    for identity, timestamp in zone_state.get("seen", {}).items()
                    if float(timestamp) >= cutoff
                }
                set_series(
                    state,
                    "cloudflare_collector_state_gap",
                    {"zone": zone_name},
                    1 if zone_state["gap"] else 0,
                )

            self._commit(apply_zone)

        def finish(state: dict[str, Any]) -> None:
            set_series(
                state,
                "cloudflare_collector_catch_up",
                {"poll": "analytics"},
                maximum_catch_up,
            )
            if all_succeeded and self.zones:
                set_series(
                    state,
                    "cloudflare_collector_last_success_timestamp_seconds",
                    {"poll": "analytics"},
                    now,
                )

        self._commit(finish)

    def poll_access(self, now: float | None = None) -> None:
        now = time.time() if now is None else now
        if not self.zones and not self.apps:
            try:
                self.refresh_inventory(now)
            except (CloudflareError, KeyError, TypeError, ValueError):
                return

        snapshot = self.snapshot()
        high_water = snapshot.get("access", {}).get("high_water")
        if high_water is None:
            start = now - 60
            catch_up = 0
        else:
            high_water = float(high_water)
            start = high_water - ACCESS_OVERLAP_SECONDS
            catch_up = max(0, int((now - high_water) / 60) - 1)
        try:
            events = self.api.list_access_logs(start, now)
        except CloudflareError:
            self.record_error("access")
            LOG.exception("Cloudflare Access log poll failed")
            return

        def apply(state: dict[str, Any]) -> None:
            apply_access_events(state, events, self.apps, self.owner_emails)
            access_state = state.setdefault("access", {"high_water": None, "seen": {}})
            access_state["high_water"] = now
            cutoff = now - ACCESS_SEEN_SECONDS
            access_state["seen"] = {
                identity: timestamp
                for identity, timestamp in access_state.get("seen", {}).items()
                if float(timestamp) >= cutoff
            }
            set_series(
                state,
                "cloudflare_collector_catch_up",
                {"poll": "access"},
                catch_up,
            )
            set_series(
                state,
                "cloudflare_collector_last_success_timestamp_seconds",
                {"poll": "access"},
                now,
            )

        self._commit(apply)


class CollectorService:
    def __init__(
        self, collector: Collector, analytics_interval: int, access_interval: int
    ):
        self.collector = collector
        self.analytics_interval = analytics_interval
        self.access_interval = access_interval
        self.stop_event = threading.Event()

    def stop(self) -> None:
        self.stop_event.set()

    def run(self) -> None:
        next_analytics = 0.0
        next_access = 0.0
        while not self.stop_event.is_set():
            now = time.time()
            if now >= next_analytics:
                try:
                    self.collector.refresh_inventory(now)
                    self.collector.poll_analytics(now)
                except Exception:  # keep serving the last durable metrics snapshot
                    self.collector.record_error("analytics-loop")
                    LOG.exception("unexpected analytics loop failure")
                next_analytics = now + self.analytics_interval
            if now >= next_access:
                try:
                    self.collector.poll_access(now)
                except Exception:  # keep serving the last durable metrics snapshot
                    self.collector.record_error("access-loop")
                    LOG.exception("unexpected Access loop failure")
                next_access = now + self.access_interval
            wait_for = max(0.1, min(next_analytics, next_access) - time.time())
            self.stop_event.wait(min(wait_for, 5.0))


def make_handler(collector: Collector) -> type[BaseHTTPRequestHandler]:
    class MetricsHandler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802
            if self.path == "/metrics":
                payload = collector.metrics().encode()
                self.send_response(200)
                self.send_header(
                    "Content-Type", "text/plain; version=0.0.4; charset=utf-8"
                )
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
                return
            if self.path == "/-/healthy":
                payload = b"ok\n"
                self.send_response(200)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
                return
            self.send_error(404)

        def log_message(self, format: str, *args: Any) -> None:
            LOG.debug(format, *args)

    return MetricsHandler


def _read_secret(path: Path) -> str:
    value = path.read_text(encoding="utf-8").strip()
    if not value:
        raise ValueError(f"credential {path.name} is empty")
    return value


def main() -> None:
    logging.basicConfig(
        level=os.environ.get("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(message)s",
    )
    credentials = Path(os.environ["CREDENTIALS_DIRECTORY"])
    state_directory = Path(os.environ["STATE_DIRECTORY"])
    api_token = _read_secret(credentials / "api-token")
    account_id = _read_secret(credentials / "account-id")
    owner_emails = {
        line.strip().lower()
        for line in (credentials / "owner-emails")
        .read_text(encoding="utf-8")
        .splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }
    if not owner_emails:
        raise ValueError(
            "owner-emails credential must contain at least one email address"
        )

    listen_address = os.environ.get("LISTEN_ADDRESS", "127.0.0.1")
    listen_port = int(os.environ.get("LISTEN_PORT", "11015"))
    analytics_interval = parse_duration(os.environ.get("ANALYTICS_INTERVAL", "5m"))
    access_interval = parse_duration(os.environ.get("ACCESS_INTERVAL", "1m"))

    collector = Collector(
        CloudflareAPI(api_token, account_id),
        StateStore(state_directory / "state.json"),
        owner_emails,
    )
    service = CollectorService(collector, analytics_interval, access_interval)
    worker = threading.Thread(target=service.run, name="cloudflare-poller", daemon=True)
    worker.start()

    server = ThreadingHTTPServer((listen_address, listen_port), make_handler(collector))

    def shutdown(_signum: int, _frame: Any) -> None:
        service.stop()
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    try:
        server.serve_forever(poll_interval=0.5)
    finally:
        service.stop()
        worker.join(timeout=10)
        server.server_close()


if __name__ == "__main__":
    main()
