-- BigQuery Standard SQL
-- Validate raw tables before running any transformation SQL.
--
-- This script creates a small validation-results table. It does not alter
-- source raw tables.

CREATE OR REPLACE TABLE `covid_wdi_final.raw_table_validation` AS
WITH region_lookup_normalized AS (
  -- Some BigQuery CSV loads may create generic column names such as
  -- string_field_0 instead of using the CSV header row. Read through JSON so
  -- this validation works with either schema:
  --   expected:       iso3, country_name, world_bank_region, broad_region
  --   generic schema: string_field_0, string_field_1, string_field_2, string_field_3
  SELECT
    COALESCE(
      JSON_VALUE(TO_JSON_STRING(r), '$.iso3'),
      JSON_VALUE(TO_JSON_STRING(r), '$.string_field_0')
    ) AS iso3
  FROM `covid_wdi_final.region_lookup_raw` AS r
),
checks AS (
  -- Expected raw table row counts.
  SELECT
    'jhu_confirmed_global_raw row count' AS check_name,
    CAST((SELECT COUNT(*) FROM `covid_wdi_final.jhu_confirmed_global_raw`) AS STRING) AS actual_value,
    '289' AS expected_value,
    (SELECT COUNT(*) FROM `covid_wdi_final.jhu_confirmed_global_raw`) = 289 AS passed,
    'Expected one row per JHU global time-series location.' AS notes

  UNION ALL
  SELECT
    'jhu_deaths_global_raw row count',
    CAST((SELECT COUNT(*) FROM `covid_wdi_final.jhu_deaths_global_raw`) AS STRING),
    '289',
    (SELECT COUNT(*) FROM `covid_wdi_final.jhu_deaths_global_raw`) = 289,
    'Deaths table should have same row count as confirmed table.'

  UNION ALL
  SELECT
    'jhu_lookup_raw row count',
    CAST((SELECT COUNT(*) FROM `covid_wdi_final.jhu_lookup_raw`) AS STRING),
    '4321',
    (SELECT COUNT(*) FROM `covid_wdi_final.jhu_lookup_raw`) = 4321,
    'JHU ISO lookup table row count from local inspection.'

  UNION ALL
  SELECT
    'wdi_indicators_raw row count',
    CAST((SELECT COUNT(*) FROM `covid_wdi_final.wdi_indicators_raw`) AS STRING),
    '4256',
    (SELECT COUNT(*) FROM `covid_wdi_final.wdi_indicators_raw`) = 4256,
    'Selected WDI indicators for 2019 and 2020.'

  UNION ALL
  SELECT
    'region_lookup_raw row count',
    CAST((SELECT COUNT(*) FROM `covid_wdi_final.region_lookup_raw`) AS STRING),
    '217',
    (SELECT COUNT(*) FROM `covid_wdi_final.region_lookup_raw`) = 217,
    'World Bank country metadata with broad regions.'

  UNION ALL
  SELECT
    'confirmed final date column exists',
    CAST((
      SELECT COUNT(*)
      FROM `covid_wdi_final.INFORMATION_SCHEMA.COLUMNS`
      WHERE table_name = 'jhu_confirmed_global_raw'
        AND column_name = 'd_2023_03_09'
    ) AS STRING),
    '1',
    (
      SELECT COUNT(*)
      FROM `covid_wdi_final.INFORMATION_SCHEMA.COLUMNS`
      WHERE table_name = 'jhu_confirmed_global_raw'
        AND column_name = 'd_2023_03_09'
    ) = 1,
    'Final cumulative confirmed cases date column.'

  UNION ALL
  SELECT
    'deaths final date column exists',
    CAST((
      SELECT COUNT(*)
      FROM `covid_wdi_final.INFORMATION_SCHEMA.COLUMNS`
      WHERE table_name = 'jhu_deaths_global_raw'
        AND column_name = 'd_2023_03_09'
    ) AS STRING),
    '1',
    (
      SELECT COUNT(*)
      FROM `covid_wdi_final.INFORMATION_SCHEMA.COLUMNS`
      WHERE table_name = 'jhu_deaths_global_raw'
        AND column_name = 'd_2023_03_09'
    ) = 1,
    'Final cumulative deaths date column.'

  UNION ALL
  SELECT
    'JHU lookup missing ISO3 rows',
    CAST((
      SELECT COUNT(*)
      FROM `covid_wdi_final.jhu_lookup_raw`
      WHERE COALESCE(TRIM(iso3), '') = ''
    ) AS STRING),
    '4',
    (
      SELECT COUNT(*)
      FROM `covid_wdi_final.jhu_lookup_raw`
      WHERE COALESCE(TRIM(iso3), '') = ''
    ) = 4,
    'Expected missing ISO3 rows are non-country entities.'

  UNION ALL
  SELECT
    'WDI approved indicator count',
    CAST((
      SELECT COUNT(DISTINCT indicator_code)
      FROM `covid_wdi_final.wdi_indicators_raw`
    ) AS STRING),
    '8',
    (
      SELECT COUNT(DISTINCT indicator_code)
      FROM `covid_wdi_final.wdi_indicators_raw`
    ) = 8,
    'All eight approved WDI indicators should be present.'

  UNION ALL
  SELECT
    'WDI year count',
    CAST((
      SELECT COUNT(DISTINCT year)
      FROM `covid_wdi_final.wdi_indicators_raw`
    ) AS STRING),
    '2',
    (
      SELECT COUNT(DISTINCT year)
      FROM `covid_wdi_final.wdi_indicators_raw`
    ) = 2,
    'Expected years are 2019 and 2020.'

  UNION ALL
  SELECT
    'Region missing ISO3 rows',
    CAST((
      SELECT COUNT(*)
      FROM region_lookup_normalized
      WHERE COALESCE(TRIM(iso3), '') = ''
         OR LOWER(TRIM(iso3)) = 'iso3'
    ) AS STRING),
    '0',
    (
      SELECT COUNT(*)
      FROM region_lookup_normalized
      WHERE COALESCE(TRIM(iso3), '') = ''
         OR LOWER(TRIM(iso3)) = 'iso3'
    ) = 0,
    'Region lookup should have complete ISO3 coverage. If this fails with iso3 header row, reload with one header row skipped.'
)
SELECT
  check_name,
  actual_value,
  expected_value,
  passed,
  notes
FROM checks;
