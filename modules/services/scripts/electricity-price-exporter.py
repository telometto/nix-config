#!/usr/bin/env python3
"""Norwegian electricity price Prometheus exporter.

Fetches hourly spot prices from hvakosterstrommen.no API and exposes them
as Prometheus metrics. Includes:
- Spot prices from hvakosterstrommen.no
- Norgespris (fixed price scheme from NVE)
- Grid tariff (nettleie) from Fagne AS via fri-nettleie data
- Government taxes (Enova-avgift, elavgift)

Prices are cached for the entire day.
"""

import os
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler

import requests

# Configuration from environment variables
PRICE_AREA = os.environ.get("PRICE_AREA", "NO2")
LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "9101"))
USE_NORGESPRIS = os.environ.get("USE_NORGESPRIS", "true").lower() == "true"
GRID_OWNER = os.environ.get("GRID_OWNER", "fagne")

# Norgespris: Fixed price of 50 øre/kWh with MVA (40 øre without)
# Valid from October 1, 2025 to December 31, 2026
# Cap: 5000 kWh/month for households, 1000 kWh/month for cabins
NORGESPRIS_NOK_PER_KWH_EXCL_MVA = 0.40  # 40 øre = 0.40 NOK
NORGESPRIS_NOK_PER_KWH_INCL_MVA = 0.50  # 50 øre = 0.50 NOK

# Government taxes (2026 rates)
# Enova-avgift: 1 øre/kWh (1.25 øre with MVA)
ENOVA_AVGIFT_ORE_PER_KWH = 1.0

# Elavgift (forbruksavgift) 2026: varies by season
# January-March: 9.51 øre/kWh, April-December: 16.69 øre/kWh
# Tiltakssonen (Finnmark and Nord-Troms) has exemption
ELAVGIFT_WINTER_ORE_PER_KWH = 9.51  # January-March
ELAVGIFT_SUMMER_ORE_PER_KWH = 16.69  # April-December

# Fagne AS grid tariff (nettleie) - from fri-nettleie
# Prices in øre/kWh (without taxes/MVA)
# energiledd grunnpris: 20 øre/kWh
# Ukedager 06:00-21:00: 28 øre/kWh (peak hours)
FAGNE_ENERGILEDD_BASE_ORE = 20.0  # Night/weekend
FAGNE_ENERGILEDD_PEAK_ORE = 28.0  # Weekdays 06:00-21:00

# Cache prices for the entire day (only re-fetch when date changes)
price_cache = {"prices": None, "date": None}


def is_mva_exempt_area(price_area: str) -> bool:
    """Check if price area is exempt from MVA (North Norway)."""
    # NO4 = Nord-Norge (Tromsø area) - no MVA on electricity
    # Also applies to: Nordland, Troms, Finnmark
    return price_area == "NO4"


def is_tiltakssonen(price_area: str) -> bool:
    """Check if area is in tiltakssonen (Finnmark and Nord-Troms) - exempt from elavgift."""
    # Simplified: NO4 roughly covers this area
    # In reality, this is municipality-based
    return price_area == "NO4"


def get_current_elavgift_ore() -> float:
    """Get current elavgift based on season (winter/summer rates)."""
    month = datetime.now().month
    if 1 <= month <= 3:  # January-March: reduced winter rate
        return ELAVGIFT_WINTER_ORE_PER_KWH
    return ELAVGIFT_SUMMER_ORE_PER_KWH


def is_peak_hour() -> bool:
    """Check if current time is during peak hours for Fagne AS.

    Peak hours: Weekdays (Monday-Friday) 06:00-21:00
    Off-peak: Nights (21:00-06:00) and weekends (Saturday-Sunday)
    """
    now = datetime.now()
    hour = now.hour
    weekday = now.weekday()  # 0=Monday, 6=Sunday

    is_weekday = weekday < 5  # Monday-Friday
    is_peak_time = 6 <= hour < 21  # 06:00-21:00

    return is_weekday and is_peak_time


def get_grid_tariff_energiledd_ore() -> float:
    """Get current grid tariff energy component (energiledd) in øre/kWh.

    Based on Fagne AS tariff from fri-nettleie:
    - Base price (off-peak): 20 øre/kWh
    - Peak price (weekdays 06:00-21:00): 28 øre/kWh
    """
    if is_peak_hour():
        return FAGNE_ENERGILEDD_PEAK_ORE
    return FAGNE_ENERGILEDD_BASE_ORE


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


def get_current_spot_price() -> float:
    """Get the current hour's spot price in NOK/kWh (excl. MVA)."""
    prices = fetch_prices()
    if not prices:
        return 0.0

    current_hour = datetime.now().hour
    if current_hour < len(prices):
        return float(prices[current_hour].get("NOK_per_kWh", 0))
    return 0.0


def calculate_electricity_price() -> float:
    """Calculate the electricity price component in NOK/kWh (excl. MVA).

    If Norgespris is enabled, returns the fixed Norgespris rate.
    Otherwise, returns the spot price.
    """
    if USE_NORGESPRIS:
        return NORGESPRIS_NOK_PER_KWH_EXCL_MVA
    return get_current_spot_price()


def calculate_total_price() -> dict:
    """Calculate all price components and total cost per kWh.

    Returns a dictionary with all price components in NOK/kWh.
    """
    # Get base electricity price
    spot_price = get_current_spot_price()
    electricity_price = calculate_electricity_price()

    # Grid tariff (energiledd) - convert from øre to NOK
    grid_energiledd_nok = get_grid_tariff_energiledd_ore() / 100.0

    # Enova-avgift - convert from øre to NOK
    enova_avgift_nok = ENOVA_AVGIFT_ORE_PER_KWH / 100.0

    # Elavgift - exempt in tiltakssonen, convert from øre to NOK
    if is_tiltakssonen(PRICE_AREA):
        elavgift_nok = 0.0
    else:
        elavgift_nok = get_current_elavgift_ore() / 100.0

    # Calculate totals excluding MVA
    total_excl_mva = (
        electricity_price + grid_energiledd_nok + enova_avgift_nok + elavgift_nok
    )

    # Add MVA (25%) if not exempt
    if is_mva_exempt_area(PRICE_AREA):
        mva_multiplier = 1.0
    else:
        mva_multiplier = 1.25

    total_incl_mva = total_excl_mva * mva_multiplier

    return {
        "spot_price_excl_mva": spot_price,
        "spot_price_incl_mva": spot_price * mva_multiplier,
        "electricity_price_excl_mva": electricity_price,
        "electricity_price_incl_mva": electricity_price * mva_multiplier,
        "grid_energiledd_excl_mva": grid_energiledd_nok,
        "grid_energiledd_incl_mva": grid_energiledd_nok * mva_multiplier,
        "enova_avgift_excl_mva": enova_avgift_nok,
        "enova_avgift_incl_mva": enova_avgift_nok * mva_multiplier,
        "elavgift_excl_mva": elavgift_nok,
        "elavgift_incl_mva": elavgift_nok * mva_multiplier,
        "total_excl_mva": total_excl_mva,
        "total_incl_mva": total_incl_mva,
        "is_peak_hour": is_peak_hour(),
        "uses_norgespris": USE_NORGESPRIS,
    }


class MetricsHandler(BaseHTTPRequestHandler):
    """HTTP handler that serves Prometheus metrics."""

    def do_GET(self):
        """Handle GET requests for metrics."""
        if self.path not in ("/metrics", "/"):
            self.send_response(404)
            self.end_headers()
            return

        prices = calculate_total_price()
        peak_label = "peak" if prices["is_peak_hour"] else "off_peak"
        norgespris_label = "norgespris" if prices["uses_norgespris"] else "spot"

        response = f"""# HELP electricity_spot_price_nok_per_kwh Current spot price from Nord Pool in NOK per kWh
# TYPE electricity_spot_price_nok_per_kwh gauge
electricity_spot_price_nok_per_kwh{{area="{PRICE_AREA}",tax="excl_mva"}} {prices["spot_price_excl_mva"]:.6f}
electricity_spot_price_nok_per_kwh{{area="{PRICE_AREA}",tax="incl_mva"}} {prices["spot_price_incl_mva"]:.6f}

# HELP electricity_price_nok_per_kwh Current electricity price (spot or Norgespris) in NOK per kWh
# TYPE electricity_price_nok_per_kwh gauge
electricity_price_nok_per_kwh{{area="{PRICE_AREA}",tax="excl_mva",type="{norgespris_label}"}} {prices["electricity_price_excl_mva"]:.6f}
electricity_price_nok_per_kwh{{area="{PRICE_AREA}",tax="incl_mva",type="{norgespris_label}"}} {prices["electricity_price_incl_mva"]:.6f}

# HELP grid_tariff_energiledd_nok_per_kwh Grid tariff energy component (energiledd) in NOK per kWh
# TYPE grid_tariff_energiledd_nok_per_kwh gauge
grid_tariff_energiledd_nok_per_kwh{{grid_owner="{GRID_OWNER}",tax="excl_mva",period="{peak_label}"}} {prices["grid_energiledd_excl_mva"]:.6f}
grid_tariff_energiledd_nok_per_kwh{{grid_owner="{GRID_OWNER}",tax="incl_mva",period="{peak_label}"}} {prices["grid_energiledd_incl_mva"]:.6f}

# HELP enova_avgift_nok_per_kwh Enova-avgift in NOK per kWh
# TYPE enova_avgift_nok_per_kwh gauge
enova_avgift_nok_per_kwh{{tax="excl_mva"}} {prices["enova_avgift_excl_mva"]:.6f}
enova_avgift_nok_per_kwh{{tax="incl_mva"}} {prices["enova_avgift_incl_mva"]:.6f}

# HELP elavgift_nok_per_kwh Elavgift (forbruksavgift) in NOK per kWh
# TYPE elavgift_nok_per_kwh gauge
elavgift_nok_per_kwh{{area="{PRICE_AREA}",tax="excl_mva"}} {prices["elavgift_excl_mva"]:.6f}
elavgift_nok_per_kwh{{area="{PRICE_AREA}",tax="incl_mva"}} {prices["elavgift_incl_mva"]:.6f}

# HELP electricity_total_cost_nok_per_kwh Total electricity cost including all fees and taxes in NOK per kWh
# TYPE electricity_total_cost_nok_per_kwh gauge
electricity_total_cost_nok_per_kwh{{area="{PRICE_AREA}",grid_owner="{GRID_OWNER}",tax="excl_mva",type="{norgespris_label}",period="{peak_label}"}} {prices["total_excl_mva"]:.6f}
electricity_total_cost_nok_per_kwh{{area="{PRICE_AREA}",grid_owner="{GRID_OWNER}",tax="incl_mva",type="{norgespris_label}",period="{peak_label}"}} {prices["total_incl_mva"]:.6f}

# HELP electricity_is_peak_hour Whether current hour is peak pricing (1) or off-peak (0)
# TYPE electricity_is_peak_hour gauge
electricity_is_peak_hour{{grid_owner="{GRID_OWNER}"}} {1 if prices["is_peak_hour"] else 0}

# HELP electricity_uses_norgespris Whether Norgespris pricing is enabled (1) or spot pricing (0)
# TYPE electricity_uses_norgespris gauge
electricity_uses_norgespris {1 if prices["uses_norgespris"] else 0}
"""
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(response.encode())

    def log_message(self, format, *args):
        """Suppress request logging."""


if __name__ == "__main__":
    print(f"Starting electricity price exporter on port {LISTEN_PORT}")
    print(f"  Price area: {PRICE_AREA}")
    print(f"  Norgespris enabled: {USE_NORGESPRIS}")
    print(f"  Grid owner: {GRID_OWNER}")
    server = HTTPServer(("", LISTEN_PORT), MetricsHandler)
    server.serve_forever()
