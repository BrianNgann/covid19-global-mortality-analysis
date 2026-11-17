-- BigQuery Standard SQL
-- Validate transformed analytics tables after transformation SQL is run.
--
-- This script creates a validation-results table. It does not alter the
-- transformed analytics tables.

CREATE OR REPLACE TABLE `covid_wdi_final.transformed_table_validation` AS
WITH checks AS (
  SELECT
    'jhu_country_covid one row per ISO3' AS check_name,
    CAST((
      SELECT COUNT(*) - COUNT(DISTINCT iso3)
      FROM `covid_wdi_final.jhu_country_covid`
    ) AS STRING) AS actual_value,
    '0' AS expected_value,
    (
      SELECT COUNT(*) = COUNT(DISTINCT iso3)
      FROM `covid_wdi_final.jhu_country_covid`
    ) AS passed,
    'Country COVID table should have unique ISO3 rows.' AS notes

  UNION ALL
  SELECT
    'jhu_country_covid approximate row count',
    CAST((SELECT COUNT(*) FROM `covid_wdi_final.jhu_country_covid`) AS STRING),
    'about 231',
    (SELECT COUNT(*) FROM `covid_wdi_final.jhu_country_covid`) BETWEEN 225 AND 235,
    'Expected from local join-key audit.'

  UNION ALL
  SELECT
    'jhu_country_covid negative totals',
    CAST((
      SELECT COUNT(*)
      FROM `covid_wdi_final.jhu_country_covid`
      WHERE confirmed_cases < 0 OR deaths < 0
    ) AS STRING),
    '0',
    (
      SELECT COUNT(*)
      FROM `covid_wdi_final.jhu_country_covid`
      WHERE confirmed_cases < 0 OR deaths < 0
    ) = 0,
    'COVID totals should be nonnegative.'

  UNION ALL
  SELECT
    'wdi_country_features one row per ISO3',
    CAST((
      SELECT COUNT(*) - COUNT(DISTINCT iso3)
      FROM `covid_wdi_final.wdi_country_features`
    ) AS STRING),
    '0',
    (
      SELECT COUNT(*) = COUNT(DISTINCT iso3)
      FROM `covid_wdi_final.wdi_country_features`
    ),
    'WDI feature table should have unique ISO3 rows.'

  UNION ALL
  SELECT
    'wdi_country_features positive population',
    CAST((
      SELECT COUNT(*)
      FROM `covid_wdi_final.wdi_country_features`
      WHERE population IS NULL OR population <= 0
    ) AS STRING),
    '0',
    (
      SELECT COUNT(*)
      FROM `covid_wdi_final.wdi_country_features`
      WHERE population IS NULL OR population <= 0
    ) = 0,
    'Population is required for per-capita rates.'

  UNION ALL
  SELECT
    'country_covid_wdi_modeling approximate row count',
    CAST((SELECT COUNT(*) FROM `covid_wdi_final.country_covid_wdi_modeling`) AS STRING),
    'about 209',
    (SELECT COUNT(*) FROM `covid_wdi_final.country_covid_wdi_modeling`) BETWEEN 200 AND 215,
    'Expected overlap among JHU, WDI, and region data.'

  UNION ALL
  SELECT
    'country_covid_wdi_modeling one row per ISO3',
    CAST((
      SELECT COUNT(*) - COUNT(DISTINCT iso3)
      FROM `covid_wdi_final.country_covid_wdi_modeling`
    ) AS STRING),
    '0',
    (
      SELECT COUNT(*) = COUNT(DISTINCT iso3)
      FROM `covid_wdi_final.country_covid_wdi_modeling`
    ),
    'Final modeling table should have unique ISO3 rows.'

  UNION ALL
  SELECT
    'missing region labels',
    CAST((
      SELECT COUNT(*)
      FROM `covid_wdi_final.country_covid_wdi_modeling`
      WHERE region IS NULL OR TRIM(region) = ''
    ) AS STRING),
    '0',
    (
      SELECT COUNT(*)
      FROM `covid_wdi_final.country_covid_wdi_modeling`
      WHERE region IS NULL OR TRIM(region) = ''
    ) = 0,
    'Region should be complete for retained rows.'

  UNION ALL
  SELECT
    'negative rate values',
    CAST((
      SELECT COUNT(*)
      FROM `covid_wdi_final.country_covid_wdi_modeling`
      WHERE cases_per_100k < 0 OR deaths_per_100k < 0 OR case_fatality_ratio < 0
    ) AS STRING),
    '0',
    (
      SELECT COUNT(*)
      FROM `covid_wdi_final.country_covid_wdi_modeling`
      WHERE cases_per_100k < 0 OR deaths_per_100k < 0 OR case_fatality_ratio < 0
    ) = 0,
    'Rates should be nonnegative.'

  UNION ALL
  SELECT
    'high_mortality target values',
    CAST((
      SELECT COUNT(*)
      FROM `covid_wdi_final.country_covid_wdi_modeling`
      WHERE high_mortality NOT IN (0, 1)
    ) AS STRING),
    '0',
    (
      SELECT COUNT(*)
      FROM `covid_wdi_final.country_covid_wdi_modeling`
      WHERE high_mortality NOT IN (0, 1)
    ) = 0,
    'high_mortality should be binary.'

  UNION ALL
  SELECT
    'high_mortality matches Q4',
    CAST((
      SELECT COUNT(*)
      FROM `covid_wdi_final.country_covid_wdi_modeling`
      WHERE (mortality_quartile = 'Q4' AND high_mortality != 1)
         OR (mortality_quartile != 'Q4' AND high_mortality != 0)
    ) AS STRING),
    '0',
    (
      SELECT COUNT(*)
      FROM `covid_wdi_final.country_covid_wdi_modeling`
      WHERE (mortality_quartile = 'Q4' AND high_mortality != 1)
         OR (mortality_quartile != 'Q4' AND high_mortality != 0)
    ) = 0,
    'Target must be 1 exactly for highest mortality quartile.'
)
SELECT
  check_name,
  actual_value,
  expected_value,
  passed,
  notes
FROM checks;
