-- BigQuery Standard SQL
-- Create country-level COVID outcomes from JHU raw confirmed/deaths tables.
--
-- This table uses the final JHU cumulative date column: d_2023_03_09.
-- It maps JHU country/province rows to ISO3 using jhu_lookup_raw, then sums
-- confirmed cases and deaths to one row per ISO3 country.

CREATE OR REPLACE TABLE `covid_wdi_final.jhu_country_covid` AS
WITH lookup_clean AS (
  -- Use non-Admin2 lookup rows because the global time-series files are not
  -- county-level. Normalize blank province names to the empty string.
  SELECT
    LOWER(TRIM(Country_Region)) AS country_key,
    LOWER(COALESCE(NULLIF(TRIM(Province_State), ''), '')) AS province_key,
    ANY_VALUE(TRIM(iso3)) AS iso3,
    ANY_VALUE(TRIM(Country_Region)) AS country_name
  FROM `covid_wdi_final.jhu_lookup_raw`
  WHERE COALESCE(TRIM(Admin2), '') = ''
    AND COALESCE(TRIM(iso3), '') != ''
  GROUP BY
    country_key,
    province_key
),
confirmed_mapped AS (
  SELECT
    -- Manual mapping from the transformation plan. This row is in the JHU
    -- time-series file but not in the lookup table.
    CASE
      WHEN c.country_region = 'Canada'
        AND c.province_state = 'Repatriated Travellers'
      THEN 'CAN'
      ELSE l.iso3
    END AS iso3,
    CASE
      WHEN c.country_region = 'Canada'
        AND c.province_state = 'Repatriated Travellers'
      THEN 'Canada'
      ELSE COALESCE(l.country_name, c.country_region)
    END AS country_name,
    SAFE_CAST(c.d_2023_03_09 AS INT64) AS confirmed_final
  FROM `covid_wdi_final.jhu_confirmed_global_raw` AS c
  LEFT JOIN lookup_clean AS l
    ON LOWER(TRIM(c.country_region)) = l.country_key
   AND LOWER(COALESCE(NULLIF(TRIM(c.province_state), ''), '')) = l.province_key
),
deaths_mapped AS (
  SELECT
    CASE
      WHEN d.country_region = 'Canada'
        AND d.province_state = 'Repatriated Travellers'
      THEN 'CAN'
      ELSE l.iso3
    END AS iso3,
    CASE
      WHEN d.country_region = 'Canada'
        AND d.province_state = 'Repatriated Travellers'
      THEN 'Canada'
      ELSE COALESCE(l.country_name, d.country_region)
    END AS country_name,
    SAFE_CAST(d.d_2023_03_09 AS INT64) AS deaths_final
  FROM `covid_wdi_final.jhu_deaths_global_raw` AS d
  LEFT JOIN lookup_clean AS l
    ON LOWER(TRIM(d.country_region)) = l.country_key
   AND LOWER(COALESCE(NULLIF(TRIM(d.province_state), ''), '')) = l.province_key
),
confirmed_country AS (
  SELECT
    iso3,
    ANY_VALUE(country_name) AS country_name,
    SUM(COALESCE(confirmed_final, 0)) AS confirmed_cases
  FROM confirmed_mapped
  WHERE COALESCE(TRIM(iso3), '') != ''
  GROUP BY iso3
),
deaths_country AS (
  SELECT
    iso3,
    ANY_VALUE(country_name) AS country_name,
    SUM(COALESCE(deaths_final, 0)) AS deaths
  FROM deaths_mapped
  WHERE COALESCE(TRIM(iso3), '') != ''
  GROUP BY iso3
)
SELECT
  COALESCE(c.iso3, d.iso3) AS iso3,
  COALESCE(c.country_name, d.country_name) AS country_name,
  COALESCE(c.confirmed_cases, 0) AS confirmed_cases,
  COALESCE(d.deaths, 0) AS deaths
FROM confirmed_country AS c
FULL OUTER JOIN deaths_country AS d
  ON c.iso3 = d.iso3;
