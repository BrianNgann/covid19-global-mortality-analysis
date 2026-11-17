#!/usr/bin/env python3
"""
Create BigQuery-ready copies of the JHU global time-series files.

This preprocessing is intentionally minimal:

- All data values are preserved exactly as strings from the source CSV.
- Only column names are changed.
- Identifier columns are renamed to simple snake_case names.
- Date columns such as "1/22/20" are converted to names such as
  "d_2020_01_22".

The output files are intended for later Cloud Storage upload and BigQuery raw
table loading. This script does not upload anything and does not create
BigQuery tables.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from datetime import datetime
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_INPUT_DIR = REPO_ROOT / "data" / "raw" / "jhu"
DEFAULT_OUTPUT_DIR = REPO_ROOT / "data" / "processed" / "jhu_bigquery"

INPUT_OUTPUT_FILES = {
    "time_series_covid19_confirmed_global.csv": "jhu_confirmed_global_bq_raw.csv",
    "time_series_covid19_deaths_global.csv": "jhu_deaths_global_bq_raw.csv",
}

IDENTIFIER_COLUMN_MAP = {
    "Province/State": "province_state",
    "Country/Region": "country_region",
    "Lat": "lat",
    "Long": "long",
}

DATE_COLUMN_PATTERN = re.compile(r"^\d{1,2}/\d{1,2}/\d{2}$")


def sanitize_column_name(column_name: str) -> str:
    """Convert one source column name to its BigQuery-safe output name."""
    if column_name in IDENTIFIER_COLUMN_MAP:
        return IDENTIFIER_COLUMN_MAP[column_name]

    if DATE_COLUMN_PATTERN.match(column_name):
        parsed_date = datetime.strptime(column_name, "%m/%d/%y")
        return f"d_{parsed_date:%Y_%m_%d}"

    normalized = re.sub(r"[^A-Za-z0-9_]+", "_", column_name.strip()).strip("_")
    normalized = normalized.lower()
    if normalized and normalized[0].isdigit():
        normalized = f"c_{normalized}"
    return normalized


def preprocess_file(input_file: Path, output_file: Path) -> dict:
    """Write a copy of one CSV with sanitized headers and unchanged values."""
    output_file.parent.mkdir(parents=True, exist_ok=True)

    with input_file.open("r", newline="", encoding="utf-8-sig") as source:
        reader = csv.reader(source)
        try:
            original_headers = next(reader)
        except StopIteration as exc:
            raise ValueError(f"Input file is empty: {input_file}") from exc

        sanitized_headers = [sanitize_column_name(header) for header in original_headers]
        if len(sanitized_headers) != len(set(sanitized_headers)):
            duplicates = sorted(
                {
                    header
                    for header in sanitized_headers
                    if sanitized_headers.count(header) > 1
                }
            )
            raise ValueError(f"Duplicate sanitized columns in {input_file}: {duplicates}")

        row_count = 0
        with output_file.open("w", newline="", encoding="utf-8") as target:
            writer = csv.writer(target)
            writer.writerow(sanitized_headers)
            for row in reader:
                writer.writerow(row)
                row_count += 1

    return {
        "input_file": str(input_file),
        "output_file": str(output_file),
        "rows": row_count,
        "columns": len(sanitized_headers),
        "first_columns": sanitized_headers[:8],
        "last_columns": sanitized_headers[-5:],
        "example_mappings": list(zip(original_headers[:8], sanitized_headers[:8]))
        + list(zip(original_headers[-5:], sanitized_headers[-5:])),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sanitize JHU time-series CSV headers for BigQuery loading."
    )
    parser.add_argument(
        "--input-dir",
        type=Path,
        default=DEFAULT_INPUT_DIR,
        help="Directory containing raw JHU time-series CSV files.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Directory where BigQuery-ready CSV files should be written.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    for input_name, output_name in INPUT_OUTPUT_FILES.items():
        input_file = args.input_dir / input_name
        output_file = args.output_dir / output_name
        if not input_file.exists():
            raise FileNotFoundError(f"Required input file not found: {input_file}")

        result = preprocess_file(input_file, output_file)
        print(
            f"Wrote {result['output_file']} "
            f"({result['rows']:,} rows, {result['columns']:,} columns)"
        )

    print("JHU BigQuery preprocessing complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
