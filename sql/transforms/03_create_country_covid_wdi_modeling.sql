-- BigQuery Standard SQL
-- Create the final country-level modeling table.
--
-- This table joins country-level JHU COVID outcomes to WDI predictors and
-- region labels, then creates rates, quartiles, and the high_mortality target.

CREATE OR REPLACE TABLE `covid_wdi_final.country_covid_wdi_modeling` AS
WITH region_lookup_normalized AS (
  -- Support both the intended region schema and a generic BigQuery CSV-load
  -- schema. The generic schema can happen if the CSV header row was not used
  -- as field names during load.
  SELECT
    COALESCE(
      JSON_VALUE(TO_JSON_STRING(r), '$.iso3'),
      JSON_VALUE(TO_JSON_STRING(r), '$.string_field_0')
    ) AS iso3,
    COALESCE(
      JSON_VALUE(TO_JSON_STRING(r), '$.world_bank_region'),
      JSON_VALUE(TO_JSON_STRING(r), '$.string_field_2')
    ) AS world_bank_region,
    COALESCE(
      JSON_VALUE(TO_JSON_STRING(r), '$.broad_region'),
      JSON_VALUE(TO_JSON_STRING(r), '$.string_field_3')
    ) AS broad_region
  FROM `covid_wdi_final.region_lookup_raw` AS r
),
region_lookup_clean AS (
  SELECT
    TRIM(iso3) AS iso3,
    TRIM(world_bank_region) AS world_bank_region,
    TRIM(broad_region) AS broad_region
  FROM region_lookup_normalized
  WHERE COALESCE(TRIM(iso3), '') != ''
    AND LOWER(TRIM(iso3)) != 'iso3'
),
joined AS (
  SELECT
    c.iso3,
    COALESCE(w.country_name, c.country_name) AS country_name,
    r.broad_region AS region,
    r.world_bank_region,
    w.population,
    w.gdp_per_capita,
    w.life_expectancy,
    w.population_density,
    w.health_expenditure_per_capita,
    w.health_expenditure_pct_gdp,
    w.pct_age_65_plus,
    w.urban_population_pct,
    c.confirmed_cases,
    c.deaths
  FROM `covid_wdi_final.jhu_country_covid` AS c
  INNER JOIN `covid_wdi_final.wdi_country_features` AS w
    ON c.iso3 = w.iso3
  LEFT JOIN region_lookup_clean AS r
    ON c.iso3 = r.iso3
),
rates AS (
  SELECT
    *,
    SAFE_DIVIDE(CAST(confirmed_cases AS FLOAT64), population) * 100000 AS cases_per_100k,
    SAFE_DIVIDE(CAST(deaths AS FLOAT64), population) * 100000 AS deaths_per_100k,
    SAFE_DIVIDE(CAST(deaths AS FLOAT64), CAST(confirmed_cases AS FLOAT64)) AS case_fatality_ratio
  FROM joined
),
quartiles AS (
  SELECT
    *,
    NTILE(4) OVER (ORDER BY population ASC) AS population_quartile_num,
    NTILE(4) OVER (ORDER BY deaths_per_100k ASC) AS mortality_quartile_num
  FROM rates
  WHERE population IS NOT NULL
    AND population > 0
    AND deaths_per_100k IS NOT NULL
)
SELECT
  iso3,
  country_name,
  region,
  world_bank_region,
  population,
  gdp_per_capita,
  life_expectancy,
  population_density,
  health_expenditure_per_capita,
  health_expenditure_pct_gdp,
  pct_age_65_plus,
  urban_population_pct,
  confirmed_cases,
  deaths,
  cases_per_100k,
  deaths_per_100k,
  case_fatality_ratio,
  CONCAT('Q', CAST(population_quartile_num AS STRING)) AS population_quartile,
  CONCAT('Q', CAST(mortality_quartile_num AS STRING)) AS mortality_quartile,
  CASE
    WHEN mortality_quartile_num = 4 THEN 1
    ELSE 0
  END AS high_mortality
FROM quartiles;
