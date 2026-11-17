# SQL Execution Guide

## Scope

This guide explains the order for running the generated BigQuery SQL files.

No SQL was executed while creating this guide. No BigQuery tables were created or modified by this file-generation step.

## Dataset

All SQL files use the dataset:

```text
covid_wdi_final
```

The SQL assumes these raw tables already exist:

- `covid_wdi_final.jhu_confirmed_global_raw`
- `covid_wdi_final.jhu_deaths_global_raw`
- `covid_wdi_final.jhu_lookup_raw`
- `covid_wdi_final.region_lookup_raw`
- `covid_wdi_final.wdi_indicators_raw`

## Run Order

Run the SQL files in this exact order:

1. `sql/validation/01_validate_raw_tables.sql`
2. `sql/transforms/01_create_jhu_country_covid.sql`
3. `sql/transforms/02_create_wdi_country_features.sql`
4. `sql/transforms/03_create_country_covid_wdi_modeling.sql`
5. `sql/validation/02_validate_transformed_tables.sql`

## What Each File Does

### 1. `01_validate_raw_tables.sql`

Creates:

```text
covid_wdi_final.raw_table_validation
```

Purpose:

- Checks raw table row counts.
- Confirms the final JHU date column exists.
- Checks expected ISO3 and WDI indicator coverage.

Review this table before continuing.

### 2. `01_create_jhu_country_covid.sql`

Creates:

```text
covid_wdi_final.jhu_country_covid
```

Purpose:

- Maps JHU confirmed/deaths rows to ISO3.
- Applies the manual Canada `Repatriated Travellers` mapping.
- Aggregates final cumulative confirmed cases and deaths to one row per country.

### 3. `02_create_wdi_country_features.sql`

Creates:

```text
covid_wdi_final.wdi_country_features
```

Purpose:

- Filters out WDI aggregate rows with missing ISO3.
- Uses 2019 WDI values when available.
- Uses 2020 values only as fallback.
- Pivots selected WDI indicators into country-level feature columns.

### 4. `03_create_country_covid_wdi_modeling.sql`

Creates:

```text
covid_wdi_final.country_covid_wdi_modeling
```

Purpose:

- Joins COVID outcomes, WDI predictors, and region labels.
- Creates `cases_per_100k`, `deaths_per_100k`, and `case_fatality_ratio`.
- Creates `population_quartile`, `mortality_quartile`, and `high_mortality`.

### 5. `02_validate_transformed_tables.sql`

Creates:

```text
covid_wdi_final.transformed_table_validation
```

Purpose:

- Checks uniqueness of ISO3 keys.
- Checks approximate expected row counts.
- Checks nonnegative values.
- Checks region completeness.
- Checks that `high_mortality` matches mortality quartile Q4.

## Expected Row Counts

Approximate expected counts:

| Table | Expected Rows |
|---|---:|
| `jhu_country_covid` | about 231 |
| `wdi_country_features` | up to 261 |
| `country_covid_wdi_modeling` | about 209 |

Small differences should be investigated before moving into analysis.

## Notes

- These scripts use `CREATE OR REPLACE TABLE`, so rerunning them will overwrite the generated validation or transformation tables.
- The raw source tables are not modified by the transform scripts.
- Run validation after table creation and inspect failed checks before proceeding.
- Do not begin machine learning until `country_covid_wdi_modeling` has passed validation.
