-- EQ15: Which years, for each country, count as "unusually
-- rapid" energy-consumption growth?
-- Definition: a year is "unusually rapid" for a country if its
-- percentage growth that year sits in that country's OWN top 10%
-- of positive-growth years. This is relative to each country's
-- own history, not one global bar -- a fast year for a small,
-- stable economy isn't the same as a fast year for a rapidly
-- industrializing one.
WITH QualifyingYears AS (
    SELECT country, year, energy_cons_change_pct
    FROM EnergyX
    WHERE energy_cons_change_twh > 10   -- floor: ignore tiny/noisy years
      AND energy_cons_change_pct > 0    -- only positive-growth years set the bar
),
CountryThreshold AS (
    SELECT
        country,
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY energy_cons_change_pct)
            OVER (PARTITION BY country) AS rapid_growth_threshold
    FROM QualifyingYears
)
SELECT DISTINCT
    q.country,
    q.year,
    q.energy_cons_change_pct,
    t.rapid_growth_threshold
FROM QualifyingYears q
JOIN CountryThreshold t ON q.country = t.country
WHERE q.energy_cons_change_pct >= t.rapid_growth_threshold
ORDER BY q.country, q.year;
GO

-- EQ16: For each eligible country, what is the pooled coverage
-- percentage during its "unusually rapid" years, compared to its
-- pooled coverage during its "normal" years?
WITH QualifyingYears AS (
    SELECT
        country, year, energy_cons_change_pct,
        energy_cons_change_twh, low_carbon_cons_change_twh
    FROM EnergyX
    WHERE energy_cons_change_twh > 10
),
CountryThreshold AS (
    SELECT
        country,
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY energy_cons_change_pct)
            OVER (PARTITION BY country) AS rapid_growth_threshold
    FROM QualifyingYears
    WHERE energy_cons_change_pct > 0     -- same population as EQ15
),
ClassifiedYears AS (
    SELECT DISTINCT
        q.country, q.year, q.energy_cons_change_twh, q.low_carbon_cons_change_twh,
        CASE WHEN q.energy_cons_change_pct >= t.rapid_growth_threshold
             THEN 'Unusually Rapid' ELSE 'Normal' END AS growth_class
    FROM QualifyingYears q
    JOIN CountryThreshold t ON q.country = t.country
),
EligibleCountries AS (
    SELECT country
    FROM ClassifiedYears
    GROUP BY country
    HAVING COUNT(*) >= 10                                              -- 10+ total years
       AND SUM(CASE WHEN growth_class = 'Unusually Rapid' THEN 1 ELSE 0 END) >= 3   -- 3+ stress years
)
SELECT
    c.country,
    100.0 * SUM(CASE WHEN c.growth_class = 'Normal' THEN c.low_carbon_cons_change_twh ELSE 0 END)
        / NULLIF(SUM(CASE WHEN c.growth_class = 'Normal' THEN c.energy_cons_change_twh ELSE 0 END), 0)
        AS pooled_coverage_normal_pct,
    100.0 * SUM(CASE WHEN c.growth_class = 'Unusually Rapid' THEN c.low_carbon_cons_change_twh ELSE 0 END)
        / NULLIF(SUM(CASE WHEN c.growth_class = 'Unusually Rapid' THEN c.energy_cons_change_twh ELSE 0 END), 0)
        AS pooled_coverage_rapid_pct
FROM ClassifiedYears c
INNER JOIN EligibleCountries e ON c.country = e.country
GROUP BY c.country
ORDER BY c.country;
GO

-- EQ17: Which countries show the largest DROP in coverage
-- between their normal years and their unusually rapid years?
-- Builds directly on EQ16's pooled figures.
WITH QualifyingYears AS (
    SELECT
        country, year, energy_cons_change_pct,
        energy_cons_change_twh, low_carbon_cons_change_twh
    FROM EnergyX
    WHERE energy_cons_change_twh > 10
),
CountryThreshold AS (
    SELECT
        country,
        PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY energy_cons_change_pct)
            OVER (PARTITION BY country) AS rapid_growth_threshold
    FROM QualifyingYears
    WHERE energy_cons_change_pct > 0
),
ClassifiedYears AS (
    SELECT DISTINCT
        q.country, q.year, q.energy_cons_change_twh, q.low_carbon_cons_change_twh,
        CASE WHEN q.energy_cons_change_pct >= t.rapid_growth_threshold
             THEN 'Unusually Rapid' ELSE 'Normal' END AS growth_class
    FROM QualifyingYears q
    JOIN CountryThreshold t ON q.country = t.country
),
EligibleCountries AS (
    SELECT country
    FROM ClassifiedYears
    GROUP BY country
    HAVING COUNT(*) >= 10
       AND SUM(CASE WHEN growth_class = 'Unusually Rapid' THEN 1 ELSE 0 END) >= 3
),
PooledCoverage AS (
    SELECT
        c.country,
        100.0 * SUM(CASE WHEN c.growth_class = 'Normal' THEN c.low_carbon_cons_change_twh ELSE 0 END)
            / NULLIF(SUM(CASE WHEN c.growth_class = 'Normal' THEN c.energy_cons_change_twh ELSE 0 END), 0)
            AS pooled_coverage_normal_pct,
        100.0 * SUM(CASE WHEN c.growth_class = 'Unusually Rapid' THEN c.low_carbon_cons_change_twh ELSE 0 END)
            / NULLIF(SUM(CASE WHEN c.growth_class = 'Unusually Rapid' THEN c.energy_cons_change_twh ELSE 0 END), 0)
            AS pooled_coverage_rapid_pct
    FROM ClassifiedYears c
    INNER JOIN EligibleCountries e ON c.country = e.country
    GROUP BY c.country
)
SELECT
    country,
    pooled_coverage_normal_pct,
    pooled_coverage_rapid_pct,
    pooled_coverage_normal_pct - pooled_coverage_rapid_pct AS coverage_decrease_pct
FROM PooledCoverage
WHERE pooled_coverage_normal_pct IS NOT NULL
  AND pooled_coverage_rapid_pct IS NOT NULL
ORDER BY coverage_decrease_pct DESC;
GO
