#!/usr/bin/env python3
"""Norwegian electricity price Prometheus exporter.

Fetches hourly spot prices from hvakosterstrommen.no API and exposes them
as Prometheus metrics. Prices are cached for the entire day.
"""

import os
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler

import requests

PRICE_AREA = os.environ.get("PRICE_AREA", "NO2")
LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "9101"))

# Cache prices for the entire day (only re-fetch when date changes)
price_cache = {"prices": None, "date": None}


def fetch_prices():
    """Fetch today's prices from hvakosterstrommen.no API (cached per day)."""
    today = datetime.now().strftime("%Y-%m-%d")

    # Return cached data if we already have today's prices
    if price_cache["date"] == today and price_cache["prices"]:
        return price_cache["prices"]

    date_path = datetime.now().strftime("%Y/%m-%d")
    url = (
        f"https://www.hvakosterstrommen.no/api/v1/prices/{date_path}_{PRICE_AREA}.json"
    )

    try:
        resp = requests.get(url, timeout=10)
        resp.raise_for_status()
        prices = resp.json()
        price_cache["prices"] = prices
        price_cache["date"] = today
        print(f"Fetched {len(prices)} hourly prices for {today} ({PRICE_AREA})")
        return prices
    except Exception as e:
        print(f"Error fetching prices: {e}")
        # Return stale cache if available
        return price_cache.get("prices") or []


def get_current_price():
    """Get the current hour's price."""
    prices = fetch_prices()
    if not prices:
        return 0.0

    current_hour = datetime.now().hour
    if current_hour < len(prices):
        return float(prices[current_hour].get("NOK_per_kWh", 0))
    return 0.0


class MetricsHandler(BaseHTTPRequestHandler):
    """HTTP handler that serves Prometheus metrics."""

    def do_GET(self):
        """Handle GET requests for metrics."""
        if self.path not in ("/metrics", "/"):
            self.send_response(404)
            self.end_headers()
            return

        price = get_current_price()
        # Add 25% MVA for areas that pay it (all except NO4)
        if PRICE_AREA != "NO4":
            price_with_mva = price * 1.25
        else:
            price_with_mva = price

        response = f"""# HELP electricity_price_nok_per_kwh Current electricity price in NOK per kWh
# TYPE electricity_price_nok_per_kwh gauge
electricity_price_nok_per_kwh{{area="{PRICE_AREA}",tax="excl_mva"}} {price:.6f}
electricity_price_nok_per_kwh{{area="{PRICE_AREA}",tax="incl_mva"}} {price_with_mva:.6f}
"""
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(response.encode())

    def log_message(self, format, *args):
        """Suppress request logging."""


if __name__ == "__main__":
    print(
        f"Starting electricity price exporter on port {LISTEN_PORT} for area {PRICE_AREA}"
    )
    server = HTTPServer(("", LISTEN_PORT), MetricsHandler)
    server.serve_forever()
