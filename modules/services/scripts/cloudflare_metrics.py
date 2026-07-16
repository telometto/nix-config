#!/usr/bin/env python3
"""Cloudflare analytics and Access Prometheus collector.

The collector intentionally uses only the Python standard library. Cloudflare's
adaptive GraphQL values are already estimates; they are exported without
applying the reported sample interval a second time.
"""

from __future__ import annotations

import copy
import errno
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
import unicodedata
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
STATE_VERSION = 2

ANALYTICS_DELAY_SECONDS = 10 * 60
ANALYTICS_BUCKET_SECONDS = 5 * 60
ANALYTICS_OVERLAP_SECONDS = 10 * 60
ANALYTICS_WINDOW_SECONDS = 8 * 24 * 60 * 60
ANALYTICS_CHUNK_SECONDS = 6 * 60 * 60
ANALYTICS_ROW_LIMIT = 10_000
ACCESS_OVERLAP_SECONDS = 5 * 60
ACCESS_SEEN_SECONDS = 8 * 24 * 60 * 60
ACCESS_GRAPHQL_ROW_LIMIT = 10_000
ACCESS_METRICS = frozenset(
    {
        "cloudflare_access_authentications_total",
        "cloudflare_access_last_authentication_timestamp_seconds",
    }
)
ACCESS_PRINCIPAL_TYPES = frozenset({"owner", "user", "service-token", "unknown"})

# Keep durable state and the Prometheus exposition bounded even when Cloudflare
# returns attacker-controlled or unexpectedly high-cardinality dimensions. One
# slot per metric is reserved for the fixed overflow bucket.
MAX_SERIES_PER_METRIC = 512
MAX_LABEL_VALUE_LENGTH = 256
OVERFLOW_LABELS = {"overflow": "true"}
OVERFLOW_METRIC = "cloudflare_collector_series_overflow_total"

ANALYTICS_DATASETS: dict[str, str] = {
    "status": "httpRequestsAdaptiveGroups",
    "cache": "httpRequestsAdaptiveGroups",
    "country": "httpRequestsAdaptiveGroups",
    "security": "httpRequestsAdaptiveGroups",
    "visits": "httpRequestsAdaptiveGroups",
}

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

ACCESS_NONIDENTITY_QUERY = r"""
query CloudflareAccessNonIdentity(
  $accountTag: string
  $start: string
  $end: string
) {
  viewer {
    accounts(filter: {accountTag: $accountTag}) {
      accessLoginRequestsAdaptiveGroups(
        limit: 10000
        orderBy: [datetime_ASC]
        filter: {
          datetime_geq: $start
          datetime_leq: $end
          identityProvider: "nonidentity"
        }
      ) {
        dimensions {
          datetime
          isSuccessfulLogin
          approvingPolicyId
          cfRayId
          ipAddress
          userUuid
          identityProvider
          country
          deviceId
          mtlsStatus
          mtlsCertSerialId
          mtlsCommonName
          serviceTokenId
        }
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
    OVERFLOW_METRIC: (
        "counter",
        "Series updates redirected to a bounded overflow bucket by source metric.",
    ),
}

# This is the producer contract consumed by Prometheus alerts and Grafana. Each
# entry declares the exact labels on a normal sample. Every bounded metric may
# additionally emit the fixed ``overflow="true"`` sample when its series budget
# is exhausted; mixing overflow with normal labels is deliberately forbidden.
METRIC_LABEL_SCHEMAS: dict[str, tuple[frozenset[str], ...]] = {
    "cloudflare_http_requests_total": (frozenset({"zone", "host", "status"}),),
    "cloudflare_http_request_bytes_total": (frozenset({"zone", "host"}),),
    "cloudflare_http_response_bytes_total": (frozenset({"zone", "host"}),),
    "cloudflare_http_cache_requests_total": (
        frozenset({"zone", "host", "cache_status"}),
    ),
    "cloudflare_http_requests_country_total": (frozenset({"zone", "country"}),),
    "cloudflare_http_security_actions_total": (
        frozenset({"zone", "host", "action", "source"}),
    ),
    "cloudflare_http_visits_total": (frozenset({"zone", "host"}),),
    "cloudflare_access_authentications_total": (
        frozenset({"app", "decision", "principal_type", "owner"}),
    ),
    "cloudflare_access_last_authentication_timestamp_seconds": (
        frozenset({"app", "decision", "principal_type", "owner"}),
    ),
    "cloudflare_collector_last_success_timestamp_seconds": (frozenset({"poll"}),),
    "cloudflare_collector_api_errors_total": (frozenset({"operation"}),),
    "cloudflare_collector_sample_interval": (frozenset({"zone"}),),
    "cloudflare_collector_state_gap": (frozenset({"zone"}),),
    "cloudflare_collector_catch_up": (frozenset({"poll"}),),
    OVERFLOW_METRIC: (frozenset({"metric"}),),
}

OVERFLOW_LABEL_SCHEMA = frozenset(OVERFLOW_LABELS)

if METRIC_LABEL_SCHEMAS.keys() != METRIC_SPECS.keys():
    raise RuntimeError(
        "metric specifications and label schemas must have identical keys"
    )


class CloudflareError(RuntimeError):
    """Raised when Cloudflare returns an unsuccessful response."""


class StateValidationError(ValueError):
    """Raised when a supported collector state file has an invalid shape."""


class UnsupportedStateVersion(ValueError):
    """Raised when state requires collector code that is not available."""


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
    normalized_email = str(email or "").strip().lower()
    if not normalized_email:
        return "unknown", "false"
    is_owner = normalized_email in owner_emails
    return ("owner" if is_owner else "user"), ("true" if is_owner else "false")


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


def normalize_label_value(value: Any) -> str:
    """Return a printable, length-bounded Prometheus label value."""
    normalized = unicodedata.normalize("NFKC", str(value))
    # Newlines are valid once escaped by ``escape_label``; replace the other
    # control bytes so they cannot corrupt the text exposition format.
    normalized = re.sub(r"[\x00-\x09\x0b-\x1f\x7f-\x9f]", " ", normalized).strip()
    if len(normalized) <= MAX_LABEL_VALUE_LENGTH:
        return normalized
    digest = hashlib.sha256(normalized.encode("utf-8")).hexdigest()[:16]
    prefix_length = max(0, MAX_LABEL_VALUE_LENGTH - len(digest) - 1)
    return f"{normalized[:prefix_length]}~{digest}"


def _normalized_labels(labels: Mapping[str, Any]) -> dict[str, str]:
    return {str(name): normalize_label_value(value) for name, value in labels.items()}


def _series_key(labels: Mapping[str, str]) -> str:
    return json.dumps(
        sorted(_normalized_labels(labels).items()),
        separators=(",", ":"),
        ensure_ascii=True,
    )


def _series_labels(key: str) -> dict[str, str]:
    return dict(json.loads(key))


def _private_access_labels(labels: Mapping[str, str]) -> dict[str, str]:
    """Return the bounded Access label contract without identity material."""
    if frozenset(labels) == OVERFLOW_LABEL_SCHEMA:
        return dict(labels)
    private_labels = dict(labels)
    legacy_principal = private_labels.pop("principal", None)
    owner = str(private_labels.get("owner", "false")).lower() == "true"
    principal_type = str(private_labels.get("principal_type", "")).lower()

    if principal_type not in ACCESS_PRINCIPAL_TYPES:
        if owner:
            principal_type = "owner"
        elif legacy_principal == "service-token":
            principal_type = "service-token"
        elif legacy_principal:
            principal_type = "user"
        else:
            principal_type = "unknown"

    # Keep the redundant owner label internally consistent so consumers can
    # use the simple owner=true|false contract without inspecting identity data.
    owner = principal_type == "owner"
    private_labels["principal_type"] = principal_type
    private_labels["owner"] = "true" if owner else "false"
    return private_labels


def _private_access_series(metric: str, series: Mapping[str, Any]) -> dict[str, float]:
    if metric not in ACCESS_METRICS:
        return dict(series)

    sanitized: dict[str, float] = {}
    for key, value in series.items():
        private_key = _series_key(_private_access_labels(_series_labels(key)))
        number = float(value)
        if metric == "cloudflare_access_authentications_total":
            sanitized[private_key] = sanitized.get(private_key, 0.0) + number
        else:
            sanitized[private_key] = max(sanitized.get(private_key, number), number)
    return sanitized


def sanitize_legacy_access_series(state: dict[str, Any]) -> bool:
    """Remove raw principals from persisted v1 state before it is exposed."""
    changed = False
    all_series = state.setdefault("series", {})
    for metric in ACCESS_METRICS:
        existing = all_series.get(metric)
        if not existing:
            continue
        sanitized = _private_access_series(metric, existing)
        if sanitized != existing:
            all_series[metric] = sanitized
            changed = True
    return changed


def _metric_type(metric: str) -> str:
    spec = METRIC_SPECS.get(metric)
    if spec is not None:
        return spec[0]
    return "counter" if metric.endswith("_total") else "gauge"


def _merge_metric_value(metric: str, current: float | None, value: float) -> float:
    if current is None:
        return value
    if _metric_type(metric) == "counter":
        return current + value
    return max(current, value)


def _record_series_overflow(
    state: dict[str, Any], metric: str, amount: float = 1
) -> None:
    """Increment bounded overflow telemetry without recursively instrumenting it."""
    if metric == OVERFLOW_METRIC or metric not in METRIC_SPECS:
        return
    telemetry = state.setdefault("series", {}).setdefault(OVERFLOW_METRIC, {})
    key = _series_key({"metric": metric})
    overflow_key = _series_key(OVERFLOW_LABELS)
    if key not in telemetry and len(telemetry) >= MAX_SERIES_PER_METRIC:
        key = overflow_key
    telemetry[key] = float(telemetry.get(key, 0)) + amount


def _redirect_new_series(
    state: dict[str, Any], metric: str, series: dict[str, float], key: str
) -> str:
    """Choose a bounded target, retaining deterministic smallest label keys."""
    overflow_key = _series_key(OVERFLOW_LABELS)
    if key in series or key == overflow_key:
        return key

    regular_capacity = max(1, MAX_SERIES_PER_METRIC - 1)
    regular_keys = sorted(existing for existing in series if existing != overflow_key)
    if len(regular_keys) < regular_capacity:
        return key

    largest = regular_keys[-1]
    _record_series_overflow(state, metric)
    if key > largest:
        return overflow_key

    evicted = float(series.pop(largest))
    current = series.get(overflow_key)
    series[overflow_key] = _merge_metric_value(metric, current, evicted)
    return key


def compact_series_state(state: dict[str, Any]) -> bool:
    """Normalize and deterministically compact oversized persisted series maps."""
    changed = False
    all_series = state.setdefault("series", {})
    metrics = sorted(metric for metric in all_series if metric != OVERFLOW_METRIC)
    if OVERFLOW_METRIC in all_series:
        metrics.append(OVERFLOW_METRIC)

    for metric in metrics:
        existing = all_series.get(metric)
        if not isinstance(existing, Mapping):
            continue
        normalized: dict[str, float] = {}
        for raw_key, raw_value in sorted(existing.items()):
            labels = _series_labels(raw_key)
            key = _series_key(labels)
            number = float(raw_value)
            if not math.isfinite(number):
                continue
            normalized[key] = _merge_metric_value(metric, normalized.get(key), number)

        overflow_key = _series_key(OVERFLOW_LABELS)
        regular_keys = sorted(key for key in normalized if key != overflow_key)
        regular_capacity = max(1, MAX_SERIES_PER_METRIC - 1)
        overflowed = regular_keys[regular_capacity:]
        compacted = {key: normalized[key] for key in regular_keys[:regular_capacity]}
        overflow_value = normalized.get(overflow_key)
        for key in overflowed:
            overflow_value = _merge_metric_value(
                metric, overflow_value, normalized[key]
            )
        if overflow_value is not None:
            compacted[overflow_key] = overflow_value
        if compacted != existing:
            all_series[metric] = compacted
            changed = True
        if overflowed:
            _record_series_overflow(state, metric, len(overflowed))

    return changed


def _state_version(state: Mapping[str, Any]) -> int:
    version = state.get("version")
    if isinstance(version, bool) or not isinstance(version, int):
        raise StateValidationError("collector state version must be an integer")
    return version


def _finite_state_number(value: Any, path: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise StateValidationError(f"collector state {path} must be numeric")
    try:
        number = float(value)
    except OverflowError as error:
        raise StateValidationError(f"collector state {path} must be finite") from error
    if not math.isfinite(number):
        raise StateValidationError(f"collector state {path} must be finite")
    return number


def _validate_seen_map(value: Any, path: str) -> None:
    if not isinstance(value, Mapping):
        raise StateValidationError(f"collector state {path} must be an object")
    for identity, timestamp in value.items():
        if not isinstance(identity, str):
            raise StateValidationError(f"collector state {path} keys must be strings")
        _finite_state_number(timestamp, f"{path}.{identity}")


def _validate_optional_timestamp(value: Any, path: str) -> None:
    if value is not None:
        _finite_state_number(value, path)


def _validate_series_key(key: Any, path: str) -> None:
    if not isinstance(key, str):
        raise StateValidationError(f"collector state {path} key must be a string")
    try:
        labels = json.loads(key)
    except json.JSONDecodeError as error:
        raise StateValidationError(
            f"collector state {path} contains an invalid label key"
        ) from error
    if not isinstance(labels, list):
        raise StateValidationError(
            f"collector state {path} label key must be a list of pairs"
        )
    for pair in labels:
        if not isinstance(pair, list) or len(pair) != 2:
            raise StateValidationError(
                f"collector state {path} label key must contain pairs"
            )
        name, value = pair
        if (
            not isinstance(name, str)
            or re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name) is None
        ):
            raise StateValidationError(
                f"collector state {path} contains an invalid label name"
            )
        if not isinstance(value, str):
            raise StateValidationError(
                f"collector state {path} label values must be strings"
            )


def validate_state(state: Any) -> None:
    """Validate the persisted containers consumed by the collector."""
    if not isinstance(state, Mapping):
        raise StateValidationError("collector state root must be an object")
    _state_version(state)

    series = state.get("series")
    if not isinstance(series, Mapping):
        raise StateValidationError("collector state series must be an object")
    for metric, samples in series.items():
        if (
            not isinstance(metric, str)
            or re.fullmatch(r"[A-Za-z_:][A-Za-z0-9_:]*", metric) is None
        ):
            raise StateValidationError(
                "collector state contains an invalid metric name"
            )
        if not isinstance(samples, Mapping):
            raise StateValidationError(
                f"collector state series.{metric} must be an object"
            )
        for key, value in samples.items():
            _validate_series_key(key, f"series.{metric}")
            _finite_state_number(value, f"series.{metric}")

    analytics = state.get("analytics")
    if not isinstance(analytics, Mapping):
        raise StateValidationError("collector state analytics must be an object")
    for zone_id, zone in analytics.items():
        if not isinstance(zone_id, str) or not isinstance(zone, Mapping):
            raise StateValidationError(
                "collector state analytics entries must be named objects"
            )
        if not isinstance(zone.get("name"), str):
            raise StateValidationError(
                f"collector state analytics.{zone_id}.name must be a string"
            )
        _validate_optional_timestamp(
            zone.get("high_water"), f"analytics.{zone_id}.high_water"
        )
        _validate_seen_map(zone.get("seen"), f"analytics.{zone_id}.seen")
        if not isinstance(zone.get("gap"), bool):
            raise StateValidationError(
                f"collector state analytics.{zone_id}.gap must be boolean"
            )

    access = state.get("access")
    if not isinstance(access, Mapping):
        raise StateValidationError("collector state access must be an object")
    _validate_optional_timestamp(access.get("high_water"), "access.high_water")
    _validate_seen_map(access.get("seen"), "access.seen")


def _migrate_v1_to_v2(state: dict[str, Any]) -> dict[str, Any]:
    """Remove identity labels and bound durable metric series."""
    sanitize_legacy_access_series(state)
    compact_series_state(state)
    state["version"] = 2
    return state


STATE_MIGRATIONS: dict[int, Callable[[dict[str, Any]], dict[str, Any]]] = {
    1: _migrate_v1_to_v2,
}


def _validate_migration_path(version: int) -> None:
    if version > STATE_VERSION:
        raise UnsupportedStateVersion(
            f"collector state version {version} is newer than supported "
            f"version {STATE_VERSION}"
        )
    if version < 1:
        raise StateValidationError(f"collector state version {version} is invalid")
    cursor = version
    while cursor < STATE_VERSION:
        if cursor not in STATE_MIGRATIONS:
            raise RuntimeError(
                f"unsupported collector state migration from version {cursor}"
            )
        cursor += 1


def migrate_state(state: Mapping[str, Any]) -> dict[str, Any]:
    """Apply every registered migration in order without mutating the input."""
    version = _state_version(state)
    _validate_migration_path(version)
    migrated = copy.deepcopy(dict(state))
    while version < STATE_VERSION:
        migrated = STATE_MIGRATIONS[version](migrated)
        next_version = _state_version(migrated)
        if next_version != version + 1:
            raise ValueError(
                f"collector state migration {version} did not produce "
                f"version {version + 1}"
            )
        version = next_version
    return migrated


def new_state() -> dict[str, Any]:
    state: dict[str, Any] = {
        "version": STATE_VERSION,
        "series": {},
        "analytics": {},
        "access": {"high_water": None, "seen": {}},
    }
    set_series(state, "cloudflare_collector_catch_up", {"poll": "analytics"}, 0)
    set_series(state, "cloudflare_collector_catch_up", {"poll": "access"}, 0)
    return state


def _validate_metric_labels(metric: str, labels: Mapping[str, str]) -> None:
    schemas = METRIC_LABEL_SCHEMAS.get(metric)
    if schemas is None:
        raise ValueError(f"unknown metric: {metric}")
    actual = frozenset(labels)
    if actual not in (*schemas, OVERFLOW_LABEL_SCHEMA):
        expected = " or ".join(
            "{" + ", ".join(sorted(schema)) + "}"
            for schema in (*schemas, OVERFLOW_LABEL_SCHEMA)
        )
        rendered = "{" + ", ".join(sorted(str(label) for label in actual)) + "}"
        raise ValueError(
            f"invalid labels for {metric}: got {rendered}, expected {expected}"
        )


def add_series(
    state: dict[str, Any], metric: str, labels: Mapping[str, str], value: Any
) -> None:
    _validate_metric_labels(metric, labels)
    number = float(value or 0)
    if not math.isfinite(number):
        return
    series = state.setdefault("series", {}).setdefault(metric, {})
    key = _series_key(labels)
    target = _redirect_new_series(state, metric, series, key)
    series[target] = float(series.get(target, 0)) + number


def set_series(
    state: dict[str, Any], metric: str, labels: Mapping[str, str], value: Any
) -> None:
    _validate_metric_labels(metric, labels)
    number = float(value or 0)
    if not math.isfinite(number):
        return
    series = state.setdefault("series", {}).setdefault(metric, {})
    key = _series_key(labels)
    target = _redirect_new_series(state, metric, series, key)
    if target == _series_key(OVERFLOW_LABELS):
        series[target] = _merge_metric_value(metric, series.get(target), number)
    else:
        series[target] = number


def get_series(
    state: Mapping[str, Any], metric: str, labels: Mapping[str, str]
) -> float:
    return float(state.get("series", {}).get(metric, {}).get(_series_key(labels), 0))


def render_metrics(state: Mapping[str, Any]) -> str:
    lines: list[str] = []
    render_state = {"series": copy.deepcopy(state.get("series", {}))}
    sanitize_legacy_access_series(render_state)
    compact_series_state(render_state)
    all_series = render_state["series"]
    for metric, (metric_type, help_text) in METRIC_SPECS.items():
        lines.append(f"# HELP {metric} {help_text}")
        lines.append(f"# TYPE {metric} {metric_type}")
        metric_series = _private_access_series(metric, all_series.get(metric, {}))
        for key, value in sorted(metric_series.items()):
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


def _fsync_directory(path: Path) -> None:
    if os.name != "posix" or not hasattr(os, "O_DIRECTORY"):
        return
    directory_fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        try:
            os.fsync(directory_fd)
        except OSError as error:
            unsupported = {
                errno.EINVAL,
                getattr(errno, "ENOTSUP", errno.EINVAL),
                getattr(errno, "EOPNOTSUPP", errno.EINVAL),
            }
            if error.errno not in unsupported:
                raise
            LOG.warning("directory fsync is unsupported for %s", path)
    finally:
        os.close(directory_fd)


class StateStore:
    def __init__(self, path: str | Path):
        self.path = Path(path)

    def load(self) -> dict[str, Any]:
        if not self.path.exists():
            return new_state()
        try:
            with self.path.open(encoding="utf-8") as handle:
                state = json.load(handle)
            if not isinstance(state, Mapping):
                raise StateValidationError("collector state root must be an object")
            version = _state_version(state)
            _validate_migration_path(version)
            validate_state(state)
        except (
            UnicodeDecodeError,
            json.JSONDecodeError,
            StateValidationError,
        ) as error:
            return self._recover_invalid_state(error)

        changed = False
        if version < STATE_VERSION:
            self._create_migration_backup(version)
            state = migrate_state(state)
            changed = True
        if sanitize_legacy_access_series(state):
            changed = True
        if compact_series_state(state):
            changed = True
        validate_state(state)
        if changed:
            self.save(state)
        return state

    def _next_quarantine_path(self) -> Path:
        suffix = time.time_ns()
        candidate = self.path.with_name(f"{self.path.name}.corrupt-{suffix}")
        counter = 1
        while candidate.exists():
            candidate = self.path.with_name(
                f"{self.path.name}.corrupt-{suffix}-{counter}"
            )
            counter += 1
        return candidate

    def _recover_invalid_state(self, error: Exception) -> dict[str, Any]:
        quarantine = self._next_quarantine_path()
        os.replace(self.path, quarantine)
        os.chmod(quarantine, 0o600)
        _fsync_directory(self.path.parent)
        state = new_state()
        self.save(state)
        LOG.error(
            "quarantined invalid collector state as %s: %s",
            quarantine.name,
            error,
        )
        return state

    def migration_backup_path(self, version: int) -> Path:
        return self.path.with_name(f"{self.path.name}.v{version}.bak")

    def _create_migration_backup(self, version: int) -> Path:
        """Durably preserve the original state once without overwriting it."""
        backup_path = self.migration_backup_path(version)
        if backup_path.exists():
            return backup_path

        temporary_name: str | None = None
        try:
            with tempfile.NamedTemporaryFile(
                "wb",
                dir=self.path.parent,
                prefix=f".{backup_path.name}.",
                delete=False,
            ) as handle:
                temporary_name = handle.name
                with self.path.open("rb") as source:
                    while chunk := source.read(1024 * 1024):
                        handle.write(chunk)
                handle.flush()
                os.fsync(handle.fileno())

            os.chmod(temporary_name, 0o600)
            try:
                os.link(temporary_name, backup_path)
            except FileExistsError:
                pass
            else:
                os.chmod(backup_path, 0o600)
                _fsync_directory(self.path.parent)
            return backup_path
        finally:
            if temporary_name is not None:
                try:
                    os.unlink(temporary_name)
                except FileNotFoundError:
                    pass

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
            _fsync_directory(self.path.parent)
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

    def query_nonidentity_access_logs(
        self, start: float, end: float
    ) -> list[dict[str, Any]]:
        response = self._request_json(
            "POST",
            GRAPHQL_URL,
            payload={
                "query": ACCESS_NONIDENTITY_QUERY,
                "variables": {
                    "accountTag": self.account_id,
                    "start": format_timestamp(start),
                    "end": format_timestamp(end),
                },
            },
        )
        try:
            accounts = response["data"]["viewer"]["accounts"]
            account = accounts[0]
            rows = account["accessLoginRequestsAdaptiveGroups"]
        except (KeyError, IndexError, TypeError) as error:
            raise CloudflareError(
                "Cloudflare GraphQL response omitted Access login data"
            ) from error
        if not isinstance(rows, list) or not all(isinstance(row, dict) for row in rows):
            raise CloudflareError("Cloudflare GraphQL Access login data was invalid")
        return rows


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

    for alias in ANALYTICS_DATASETS:
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


def _record_access_event(
    state: dict[str, Any],
    *,
    identity: str,
    event_time: float,
    app: str,
    decision: str,
    principal_type: str,
    owner: str,
) -> bool:
    access_state = state.setdefault("access", {"high_water": None, "seen": {}})
    seen: dict[str, float] = access_state.setdefault("seen", {})
    if identity in seen:
        return False
    labels = {
        "app": app,
        "decision": decision,
        "principal_type": principal_type,
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
    return True


def apply_access_events(
    state: dict[str, Any],
    events: Iterable[Mapping[str, Any]],
    apps: Mapping[str, str],
    owner_emails: set[str],
) -> int:
    added = 0
    for event in events:
        event_time = parse_timestamp(event.get("created_at"))
        identity = _access_identity(event)
        principal_type, owner = classify_principal(
            event.get("user_email"), owner_emails
        )
        app_id = str(event.get("app_uid") or "")
        app = apps.get(app_id)
        if not app:
            app = normalize_hostname(event.get("app_domain"), app_id or "unknown")
        added += int(
            _record_access_event(
                state,
                identity=identity,
                event_time=event_time,
                app=app,
                decision=normalize_decision(event),
                principal_type=principal_type,
                owner=owner,
            )
        )
    return added


def _nonidentity_access_identity(dimensions: Mapping[str, Any]) -> str:
    if dimensions.get("cfRayId"):
        return str(dimensions["cfRayId"])
    return hashlib.sha256(
        json.dumps(
            ["graphql-nonidentity", dimensions],
            sort_keys=True,
            separators=(",", ":"),
        ).encode()
    ).hexdigest()


def apply_nonidentity_access_events(
    state: dict[str, Any], rows: Iterable[Mapping[str, Any]]
) -> int:
    """Apply GraphQL rows explicitly identified by Cloudflare as non-identity."""
    added = 0
    for row in rows:
        dimensions = row.get("dimensions")
        if not isinstance(dimensions, Mapping):
            raise CloudflareError("Cloudflare GraphQL Access row omitted dimensions")
        if normalize_word(dimensions.get("identityProvider")) != "nonidentity":
            raise CloudflareError(
                "Cloudflare GraphQL non-identity query returned an identity-based row"
            )
        successful = dimensions.get("isSuccessfulLogin")
        if successful is True or successful == 1:
            decision = "allowed"
        elif successful is False or successful == 0:
            decision = "denied"
        else:
            decision = "error"
        service_token_id = str(dimensions.get("serviceTokenId") or "").strip()
        added += int(
            _record_access_event(
                state,
                identity=_nonidentity_access_identity(dimensions),
                event_time=parse_timestamp(dimensions.get("datetime")),
                # Cloudflare's published dataset does not expose an Access
                # application identifier or domain for this event.
                app="unknown",
                decision=decision,
                principal_type="service-token" if service_token_id else "unknown",
                owner="false",
            )
        )
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
    for alias in ANALYTICS_DATASETS:
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


def query_complete_nonidentity_access(
    api: CloudflareAPI,
    start: float,
    end: float,
    *,
    row_limit: int = ACCESS_GRAPHQL_ROW_LIMIT,
) -> list[dict[str, Any]]:
    """Fetch non-identity Access rows without advancing past truncation."""
    rows = api.query_nonidentity_access_logs(start, end)
    if len(rows) < row_limit:
        return rows
    if end - start <= 1:
        raise CloudflareError(
            "Cloudflare non-identity Access row limit reached within one second"
        )
    split = floor_timestamp(start + (end - start) / 2, 1)
    if split <= start:
        split = start + 1
    if split >= end:
        raise CloudflareError(
            "unable to bisect a truncated non-identity Access response"
        )
    return query_complete_nonidentity_access(
        api, start, split, row_limit=row_limit
    ) + query_complete_nonidentity_access(api, split, end, row_limit=row_limit)


class Collector:
    def __init__(
        self,
        api: CloudflareAPI,
        store: StateStore,
        owner_emails: set[str],
        *,
        analytics_window: int = ANALYTICS_WINDOW_SECONDS,
        analytics_row_limit: int = ANALYTICS_ROW_LIMIT,
        access_graphql_row_limit: int = ACCESS_GRAPHQL_ROW_LIMIT,
    ):
        self.api = api
        self.store = store
        self.owner_emails = {
            email.strip().lower() for email in owner_emails if email.strip()
        }
        self.analytics_window = analytics_window
        self.analytics_row_limit = analytics_row_limit
        self.access_graphql_row_limit = access_graphql_row_limit
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
            nonidentity_events = query_complete_nonidentity_access(
                self.api,
                start,
                now,
                row_limit=self.access_graphql_row_limit,
            )
            events = self.api.list_access_logs(start, now)
        except CloudflareError:
            self.record_error("access")
            LOG.exception("Cloudflare Access log poll failed")
            return

        def apply(state: dict[str, Any]) -> None:
            # Apply GraphQL first so a ray unexpectedly present in both sources
            # retains the schema-backed non-identity classification.
            apply_nonidentity_access_events(state, nonidentity_events)
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

        try:
            self._commit(apply)
        except (CloudflareError, TypeError, ValueError):
            self.record_error("access")
            LOG.exception("Cloudflare Access log response was invalid")


class CollectorService:
    def __init__(
        self,
        collector: Collector,
        analytics_interval: int,
        access_interval: int,
        *,
        clock: Callable[[], float] = time.time,
    ):
        self.collector = collector
        self.analytics_interval = analytics_interval
        self.access_interval = access_interval
        self.clock = clock
        self.stop_event = threading.Event()

    def stop(self) -> None:
        self.stop_event.set()

    def run_once(
        self, now: float, next_analytics: float, next_access: float
    ) -> tuple[float, float]:
        """Run due polls once and return their next monotonic deadlines."""
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
        return next_analytics, next_access

    def run(self) -> None:
        next_analytics = 0.0
        next_access = 0.0
        while not self.stop_event.is_set():
            now = self.clock()
            next_analytics, next_access = self.run_once(
                now, next_analytics, next_access
            )
            wait_for = max(0.1, min(next_analytics, next_access) - self.clock())
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
