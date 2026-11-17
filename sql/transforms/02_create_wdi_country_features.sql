-- BigQuery Standard SQL
-- Create one WDI feature row per ISO3 country.
--
-- Year rule:
--   1. Prefer 2019 non-missing values.
--   2. Use 2020 only when 2019 is unavailable.

CREATE OR REPLACE TABLE `covid_wdi_final.wdi_country_features` AS
WITH cleaned AS (
  SELECT
    TRIM(iso3) AS iso3,
    TRIM(country_name) AS country_name,
    SAFE_CAST(year AS INT64) AS year_int,
    TRIM(indicator_code) AS indicator_code,
    SAFE_CAST(value AS FLOAT64) AS value_num
  FROM `covid_wdi_final.wdi_indicators_raw`
  WHERE COALESCE(TRIM(iso3), '') != ''
    AND TRIM(indicator_code) IN (
      'SP.POP.TOTL',
      'NY.GDP.PCAP.CD',
      'SP.DYN.LE00.IN',
      'EN.POP.DNST',
      'SH.XPD.CHEX.PC.CD',
      'SH.XPD.CHEX.GD.ZS',
      'SP.POP.65UP.TO.ZS',
      'SP.URB.TOTL.IN.ZS'
    )
),
preferred AS (
  -- Keep one preferred non-missing value for each ISO3 and indicator.
  SELECT
    iso3,
    country_name,
    indicator_code,
    value_num
  FROM (
    SELECT
      *,
      ROW_NUMBER() OVER (
        PARTITION BY iso3, indicator_code
        ORDER BY
          CASE
            WHEN year_int = 2019 AND value_num IS NOT NULL THEN 1
            WHEN year_int = 2020 AND value_num IS NOT NULL THEN 2
            ELSE 3
          END
      ) AS rn
    FROM cleaned
    WHERE year_int IN (2019, 2020)
      AND value_num IS NOT NULL
  )
  WHERE rn = 1
),
pivoted AS (
  SELECT
    iso3,
    ARRAY_AGG(country_name IGNORE NULLS ORDER BY country_name LIMIT 1)[SAFE_OFFSET(0)] AS country_name,
    MAX(IF(indicator_code = 'SP.POP.TOTL', value_num, NULL)) AS population,
    MAX(IF(indicator_code = 'NY.GDP.PCAP.CD', value_num, NULL)) AS gdp_per_capita,
    MAX(IF(indicator_code = 'SP.DYN.LE00.IN', value_num, NULL)) AS life_expectancy,
    MAX(IF(indicator_code = 'EN.POP.DNST', value_num, NULL)) AS population_density,
    MAX(IF(indicator_code = 'SH.XPD.CHEX.PC.CD', value_num, NULL)) AS health_expenditure_per_capita,
    MAX(IF(indicator_code = 'SH.XPD.CHEX.GD.ZS', value_num, NULL)) AS health_expenditure_pct_gdp,
    MAX(IF(indicator_code = 'SP.POP.65UP.TO.ZS', value_num, NULL)) AS pct_age_65_plus,
    MAX(IF(indicator_code = 'SP.URB.TOTL.IN.ZS', value_num, NULL)) AS urban_population_pct
  FROM preferred
  GROUP BY iso3
)
SELECT
  iso3,
  country_name,
  population,
  gdp_per_capita,
  life_expectancy,
  population_density,
  health_expenditure_per_capita,
  health_expenditure_pct_gdp,
  pct_age_65_plus,
  urban_population_pct
FROM pivoted;
