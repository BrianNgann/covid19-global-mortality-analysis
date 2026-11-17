#!/usr/bin/env python3
"""
Extract selected World Bank WDI indicators for the COVID project.

The output is a long-format CSV with one row per country, year, and
indicator. The approved years are 2019 and 2020 so later BigQuery SQL can
prefer 2019 pre-pandemic values and use 2020 only as fallback.

This script does not upload anything to GCP and does not create BigQuery
tables. Run it only when the project is ready to begin data extraction.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Iterable


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT_FILE = (
    REPO_ROOT / "data" / "raw" / "wdi" / "wdi_selected_indicators_2019_2020.csv"
)

WORLD_BANK_API_BASE = "https://api.worldbank.org/v2"
YEARS = (2019, 2020)

APPROVED_WDI_INDICATORS = {
    "SP.POP.TOTL": "Population, total",
    "NY.GDP.PCAP.CD": "GDP per capita, current US$",
    "SP.DYN.LE00.IN": "Life expectancy at birth",
    "EN.POP.DNST": "Population density",
    "SH.XPD.CHEX.PC.CD": "Current health expenditure per capita",
    "SH.XPD.CHEX.GD.ZS": "Current health expenditure as % of GDP",
    "SP.POP.65UP.TO.ZS": "Population ages 65+ (% of total)",
    "SP.URB.TOTL.IN.ZS": "Urban population (% of total)",
}

OUTPUT_COLUMNS = [
    "iso3",
    "country_name",
    "year",
    "indicator_code",
    "indicator_name",
    "value",
]


def fetch_indicator(indicator_code: str, years: Iterable[int]) -> list[dict]:
    """Fetch all-country WDI records for one indicator and selected years."""
    selected_years = sorted(years)
    date_param = f"{selected_years[0]}:{selected_years[-1]}"
    query = urllib.parse.urlencode(
        {
            "format": "json",
            "per_page": 20000,
            "date": date_param,
        }
    )
    url = f"{WORLD_BANK_API_BASE}/country/all/indicator/{indicator_code}?{query}"

    print(f"Fetching {indicator_code}")
    try:
        with urllib.request.urlopen(url, timeout=60) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Failed to fetch {indicator_code}: {exc}") from exc

    if not isinstance(payload, list) or len(payload) < 2:
        raise RuntimeError(f"Unexpected World Bank API response for {indicator_code}")

    return payload[1] or []


def normalize_record(record: dict, indicator_code: str) -> dict:
    """Convert one World Bank API record into the project CSV schema."""
    country = record.get("country") or {}
    indicator = record.get("indicator") or {}

    return {
        "iso3": record.get("countryiso3code") or "",
        "country_name": country.get("value") or "",
        "year": record.get("date") or "",
        "indicator_code": indicator.get("id") or indicator_code,
        "indicator_name": indicator.get("value")
        or APPROVED_WDI_INDICATORS[indicator_code],
        "value": "" if record.get("value") is None else record.get("value"),
    }


def write_csv(rows: list[dict], output_file: Path) -> None:
    """Write normalized WDI records to a long-format CSV."""
    output_file.parent.mkdir(parents=True, exist_ok=True)
    with output_file.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=OUTPUT_COLUMNS)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {output_file} ({len(rows):,} rows)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract approved World Bank WDI indicators."
    )
    parser.add_argument(
        "--output-file",
        type=Path,
        default=DEFAULT_OUTPUT_FILE,
        help="CSV file where selected WDI records should be saved.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    rows: list[dict] = []

    for indicator_code in APPROVED_WDI_INDICATORS:
        records = fetch_indicator(indicator_code, YEARS)
        rows.extend(normalize_record(record, indicator_code) for record in records)

    write_csv(rows, args.output_file)
    print("WDI extraction complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
