#!/usr/bin/env python3
"""
Create an ISO3-to-region lookup file from World Bank country metadata.

The output provides both the original World Bank region and a broad region
used for descriptive analysis and visualization. Region is not intended to be
used as a primary predictor in the main classification models.

This script does not upload anything to GCP and does not create BigQuery
tables. Run it only when the project is ready to begin data extraction.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT_FILE = (
    REPO_ROOT / "data" / "raw" / "region" / "iso3_region_lookup.csv"
)

WORLD_BANK_COUNTRY_URL = (
    "https://api.worldbank.org/v2/country?format=json&per_page=400"
)

OUTPUT_COLUMNS = [
    "iso3",
    "country_name",
    "world_bank_region",
    "broad_region",
]

WORLD_BANK_TO_BROAD_REGION = {
    "East Asia & Pacific": "Asia",
    "Europe & Central Asia": "Europe",
    "Latin America & Caribbean": "South America",
    "Latin America & Caribbean ": "South America",
    "Middle East & North Africa": "Asia",
    "Middle East, North Africa, Afghanistan & Pakistan": "Asia",
    "North America": "North America",
    "South Asia": "Asia",
    "Sub-Saharan Africa": "Africa",
    "Sub-Saharan Africa ": "Africa",
}

MANUAL_BROAD_REGION_OVERRIDES = {
    # World Bank's Latin America & Caribbean region includes island countries
    # that are geographically in North America. These overrides make broad
    # region labels easier to interpret in maps and descriptive plots.
    "ATG": "North America",
    "ABW": "North America",
    "BHS": "North America",
    "BRB": "North America",
    "BLZ": "North America",
    "CRI": "North America",
    "CUB": "North America",
    "CUW": "North America",
    "CYM": "North America",
    "DMA": "North America",
    "DOM": "North America",
    "GTM": "North America",
    "GRD": "North America",
    "HND": "North America",
    "HTI": "North America",
    "JAM": "North America",
    "KNA": "North America",
    "LCA": "North America",
    "MEX": "North America",
    "NIC": "North America",
    "PAN": "North America",
    "SLV": "North America",
    "SXM": "North America",
    "TCA": "North America",
    "TTO": "North America",
    "VCT": "North America",
    "VGB": "North America",
    # North African countries are grouped into MENA by the World Bank, but the
    # broad project categories use a geographic Africa/Asia split.
    "DZA": "Africa",
    "DJI": "Africa",
    "EGY": "Africa",
    "LBY": "Africa",
    "MAR": "Africa",
    "TUN": "Africa",
    # Pacific/Oceania countries and territories are grouped with East Asia by
    # the World Bank but should be visible as Oceania in project summaries.
    "ASM": "Oceania",
    "AUS": "Oceania",
    "FJI": "Oceania",
    "FSM": "Oceania",
    "GUM": "Oceania",
    "KIR": "Oceania",
    "MHL": "Oceania",
    "MNP": "Oceania",
    "NCL": "Oceania",
    "NRU": "Oceania",
    "NZL": "Oceania",
    "PLW": "Oceania",
    "PNG": "Oceania",
    "PYF": "Oceania",
    "SLB": "Oceania",
    "TON": "Oceania",
    "TUV": "Oceania",
    "VUT": "Oceania",
    "WSM": "Oceania",
}


def fetch_country_metadata() -> list[dict]:
    """Fetch country metadata from the World Bank API."""
    print("Fetching World Bank country metadata")
    try:
        with urllib.request.urlopen(WORLD_BANK_COUNTRY_URL, timeout=60) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Failed to fetch country metadata: {exc}") from exc

    if not isinstance(payload, list) or len(payload) < 2:
        raise RuntimeError("Unexpected World Bank country metadata response")

    return payload[1] or []


def broad_region_for(iso3: str, world_bank_region: str) -> str:
    """Collapse World Bank region labels into broad project regions."""
    if iso3 in MANUAL_BROAD_REGION_OVERRIDES:
        return MANUAL_BROAD_REGION_OVERRIDES[iso3]
    return WORLD_BANK_TO_BROAD_REGION.get(world_bank_region.strip(), "")


def normalize_country(record: dict) -> dict | None:
    """Convert one World Bank country metadata record into project schema."""
    region = record.get("region") or {}
    world_bank_region = region.get("value") or ""

    # Exclude aggregate records such as "World" and income groups.
    if region.get("id") == "NA" or world_bank_region == "Aggregates":
        return None

    iso3 = record.get("id") or ""
    country_name = record.get("name") or ""

    return {
        "iso3": iso3,
        "country_name": country_name,
        "world_bank_region": world_bank_region,
        "broad_region": broad_region_for(iso3, world_bank_region),
    }


def write_csv(rows: list[dict], output_file: Path) -> None:
    """Write the ISO3 region lookup to CSV."""
    output_file.parent.mkdir(parents=True, exist_ok=True)
    with output_file.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=OUTPUT_COLUMNS)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {output_file} ({len(rows):,} rows)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create ISO3 region lookup from World Bank metadata."
    )
    parser.add_argument(
        "--output-file",
        type=Path,
        default=DEFAULT_OUTPUT_FILE,
        help="CSV file where the region lookup should be saved.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    metadata = fetch_country_metadata()
    rows = [
        normalized
        for record in metadata
        if (normalized := normalize_country(record)) is not None
    ]
    write_csv(rows, args.output_file)
    print("Region lookup creation complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
