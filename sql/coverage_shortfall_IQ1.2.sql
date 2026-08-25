-- EQ6: Which country-years didn't reach 100% coverage?
-- (Row-level result -- shows individual years, not a ranking.)
SELECT
    country,
    year,
    energy_cons_change_twh,
    low_carbon_cons_change_twh,
    (low_carbon_cons_change_twh / NULLIF(energy_cons_change_twh, 0)) * 100.0
        AS coverage_percentage
FROM EnergyX
WHERE energy_cons_change_twh > 10
  AND low_carbon_cons_change_twh IS NOT NULL
  AND (low_carbon_cons_change_twh / NULLIF(energy_cons_change_twh, 0)) * 100.0 < 100
ORDER BY coverage_percentage DESC;
GO

-- EQ7: How many percentage points away from 100% were they?
-- A value over 100 here means coverage was actually NEGATIVE
-- that year (low-carbon energy fell while total energy rose) --
-- that is a real result, not an error, and is kept in.
SELECT
    country,
    year,
    energy_cons_change_twh,
    low_carbon_cons_change_twh,
    (low_carbon_cons_change_twh / NULLIF(energy_cons_change_twh, 0)) * 100.0
        AS coverage_percentage,
    100.0 - (low_carbon_cons_change_twh / NULLIF(energy_cons_change_twh, 0)) * 100.0
        AS shortfall_percentage_points
FROM EnergyX
WHERE energy_cons_change_twh > 10
  AND low_carbon_cons_change_twh IS NOT NULL
  AND (low_carbon_cons_change_twh / NULLIF(energy_cons_change_twh, 0)) * 100.0 < 100
ORDER BY shortfall_percentage_points DESC;
GO

-- EQ8: Which countries have the highest average shortfall,
-- measured across their below-100%-coverage years?
-- METHOD: pool (add up) the raw TWh values across a country's
-- below-100% years, then compute ONE shortfall percentage from
-- the pooled totals -- rather than averaging each year's
-- separate percentage. A TWh-based shortfall figure is included
-- alongside as supporting context, not as a competing headline.
-- ELIGIBILITY: a country needs at least 10 qualifying years
-- overall (any coverage level) before it's included here.
WITH CountryYearCounts AS (
    SELECT country, COUNT(*) AS qualifying_years
    FROM EnergyX
    WHERE energy_cons_change_twh > 10
    GROUP BY country
    HAVING COUNT(*) >= 10
),
BelowTargetYears AS (
    SELECT
        e.country,
        e.energy_cons_change_twh,
        e.low_carbon_cons_change_twh
    FROM EnergyX e
    INNER JOIN CountryYearCounts c ON e.country = c.country
    WHERE e.energy_cons_change_twh > 10
      AND e.low_carbon_cons_change_twh IS NOT NULL
      AND (e.low_carbon_cons_change_twh / e.energy_cons_change_twh) * 100.0 < 100
)
SELECT
    country,
    SUM(energy_cons_change_twh) AS pooled_energy_change_twh,
    SUM(low_carbon_cons_change_twh) AS pooled_low_carbon_change_twh,
    100.0 - (
        SUM(low_carbon_cons_change_twh)
        / NULLIF(SUM(energy_cons_change_twh), 0)
    ) * 100.0 AS pooled_shortfall_percentage_points,
    SUM(energy_cons_change_twh) - SUM(low_carbon_cons_change_twh)
        AS pooled_shortfall_twh                       -- supporting context only
FROM BelowTargetYears
GROUP BY country
ORDER BY pooled_shortfall_percentage_points DESC;
GO
