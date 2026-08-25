-- EQ1: For each country, how much did its total energy
-- consumption increase, added up across all its qualifying years?
-- "Qualifying year" = a year where energy consumption grew by
-- MORE than 10 TWh. Smaller increases are excluded up front
-- because they can make later percentages explode meaninglessly.
SELECT
    country,
    SUM(energy_cons_change_twh) AS total_energy_change_twh,
    COUNT(*) AS qualifying_years
FROM EnergyX
WHERE energy_cons_change_twh > 10
GROUP BY country
HAVING COUNT(*) >= 10
ORDER BY total_energy_change_twh DESC;
GO

-- EQ2: For each country, how much did its low-carbon energy
-- consumption increase, added up across those SAME qualifying
-- years used in EQ1? Using the same year-set lets EQ1 and EQ2
-- be compared directly.
SELECT
    country,
    SUM(low_carbon_cons_change_twh) AS total_low_carbon_change_twh,
    COUNT(*) AS qualifying_years
FROM EnergyX
WHERE energy_cons_change_twh > 10
  AND low_carbon_cons_change_twh IS NOT NULL
GROUP BY country
HAVING COUNT(*) >= 10
ORDER BY total_low_carbon_change_twh DESC;
GO

-- EQ3: For each country, what percentage of its total added
-- energy consumption (EQ1) was matched by its total added
-- low-carbon energy (EQ2)? This is the headline "coverage ratio."
--
-- METHOD NOTE: we add up all the raw TWh values FIRST, then
-- divide ONCE. We do not average each year's individual
-- percentage -- averaging percentages would let one freak year
-- count exactly as much as ten ordinary years and quietly
-- distort the answer.
SELECT
    country,
    SUM(energy_cons_change_twh) AS total_energy_change_twh,
    SUM(low_carbon_cons_change_twh) AS total_low_carbon_change_twh,
    (
        SUM(low_carbon_cons_change_twh)
        / NULLIF(SUM(energy_cons_change_twh), 0)
    ) * 100.0 AS total_coverage_percentage
FROM EnergyX
WHERE energy_cons_change_twh > 10
  AND low_carbon_cons_change_twh IS NOT NULL
GROUP BY country
HAVING COUNT(*) >= 10
ORDER BY total_coverage_percentage DESC;
GO

-- EQ4: For every individual country-year, what percentage of
-- THAT year's added energy consumption came from added
-- low-carbon energy? This is the raw, year-by-year version --
-- no averaging and no country-level eligibility rule, because
-- it's meant to show individual data points, not to rank
-- countries against each other.
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
ORDER BY country, year;
GO

-- EQ5: Across every qualifying country-year in the whole dataset
-- what does a "typical" coverage percentage look like?
-- We report the minimum, the median (the middle value -- more
-- reliable than an average because it isn't skewed by a
-- handful of extreme years), and the maximum.
SELECT DISTINCT
    MIN(coverage_percentage) OVER () AS min_coverage_pct,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY coverage_percentage) OVER ()
        AS median_coverage_pct,
    MAX(coverage_percentage) OVER () AS max_coverage_pct
FROM (
    SELECT
        (low_carbon_cons_change_twh / NULLIF(energy_cons_change_twh, 0)) * 100.0
            AS coverage_percentage
    FROM EnergyX
    WHERE energy_cons_change_twh > 10
      AND low_carbon_cons_change_twh IS NOT NULL
) AS YearlyCoverage;
GO
