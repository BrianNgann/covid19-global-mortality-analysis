#!/usr/bin/env python3
"""
Download the approved Johns Hopkins CSSE COVID-19 files.

This script is intentionally limited to the three files approved in
DATA_INGESTION_PLAN.md:

- Global confirmed time series
- Global deaths time series
- JHU UID/ISO/FIPS lookup table

It does not upload anything to GCP and does not create BigQuery tables.
Run it only when the project is ready to begin data extraction.
"""

from __future__ import annotations

import argparse
import sys
import urllib.error
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT_DIR = REPO_ROOT / "data" / "raw" / "jhu"

BASE_RAW_URL = (
    "https://raw.githubusercontent.com/"
    "CSSEGISandData/COVID-19/master/csse_covid_19_data"
)

APPROVED_JHU_FILES = {
    "time_series_covid19_confirmed_global.csv": (
        f"{BASE_RAW_URL}/csse_covid_19_time_series/"
        "time_series_covid19_confirmed_global.csv"
    ),
    "time_series_covid19_deaths_global.csv": (
        f"{BASE_RAW_URL}/csse_covid_19_time_series/"
        "time_series_covid19_deaths_global.csv"
    ),
    "UID_ISO_FIPS_LookUp_Table.csv": (
        f"{BASE_RAW_URL}/UID_ISO_FIPS_LookUp_Table.csv"
    ),
}


def download_file(url: str, output_path: Path, overwrite: bool) -> None:
    """Download one URL to one local output path."""
    if output_path.exists() and not overwrite:
        print(f"Skipping existing file: {output_path}")
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {url}")
    try:
        with urllib.request.urlopen(url, timeout=60) as response:
            data = response.read()
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Failed to download {url}: {exc}") from exc

    output_path.write_bytes(data)
    print(f"Wrote {output_path} ({len(data):,} bytes)")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download approved JHU COVID-19 CSV files."
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Directory where JHU CSV files should be saved.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing files instead of skipping them.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    for filename, url in APPROVED_JHU_FILES.items():
        download_file(url, args.output_dir / filename, args.overwrite)

    print("JHU file download complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
