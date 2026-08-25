-- EQ20: Is a country's coverage ratio generally increasing,
-- decreasing, or flat across its qualifying years?
-- Method: fit a straight line (linear trend) through each
-- country's yearly coverage values; a positive slope = increasing,
-- negative = decreasing, exactly zero = flat.
WITH ValidYears AS (
    SELECT
        country, iso_code, year,
        (low_carbon_cons_change_twh / NULLIF(energy_cons_change_twh, 0)) * 100.0
            AS coverage_ratio
    FROM EnergyX
    WHERE energy_cons_change_twh > 10
      AND low_carbon_cons_change_twh IS NOT NULL
),
TrendCalc AS (
    SELECT
        country, iso_code,
        COUNT(*) AS n,
        SUM(CAST(year AS FLOAT)) AS sum_x,
        SUM(coverage_ratio) AS sum_y,
        SUM(CAST(year AS FLOAT) * coverage_ratio) AS sum_xy,
        SUM(CAST(year AS FLOAT) * CAST(year AS FLOAT)) AS sum_x2
    FROM ValidYears
    GROUP BY country, iso_code
    HAVING COUNT(*) >= 10                 -- need 10+ years to call anything a "trend"
)
SELECT
    country, iso_code,
    (n * sum_xy - sum_x * sum_y) / NULLIF(n * sum_x2 - sum_x * sum_x, 0)
        AS coverage_slope,
    CASE
        WHEN (n * sum_xy - sum_x * sum_y) / NULLIF(n * sum_x2 - sum_x * sum_x, 0) > 0
            THEN 'Increasing'
        WHEN (n * sum_xy - sum_x * sum_y) / NULLIF(n * sum_x2 - sum_x * sum_x, 0) < 0
            THEN 'Decreasing'
        ELSE 'Flat'
    END AS trend_direction
FROM TrendCalc
ORDER BY coverage_slope DESC;
GO

-- EQ21: Among countries with an overall positive coverage trend
-- (from EQ20), which ones remain positive after excluding their
-- single best year? ("Sustained" = still positive without that
-- one standout year. "Outlier-driven" = the positive trend
-- disappears once that one year is removed.)
WITH ValidYears AS (
    SELECT
        country, iso_code, year,
        (low_carbon_cons_change_twh / NULLIF(energy_cons_change_twh, 0)) * 100.0
            AS coverage_ratio
    FROM EnergyX
    WHERE energy_cons_change_twh > 10
      AND low_carbon_cons_change_twh IS NOT NULL
),
EligibleCountries AS (
    SELECT country, iso_code
    FROM ValidYears
    GROUP BY country, iso_code
    HAVING COUNT(*) >= 10
),
CoverageData AS (
    SELECT v.*
    FROM ValidYears v
    INNER JOIN EligibleCountries e ON v.iso_code = e.iso_code
),
PositiveTrendCountries AS (
    SELECT country, iso_code
    FROM (
        SELECT
            country, iso_code,
            COUNT(*) AS n,
            SUM(CAST(year AS FLOAT)) AS sum_x,
            SUM(coverage_ratio) AS sum_y,
            SUM(CAST(year AS FLOAT) * coverage_ratio) AS sum_xy,
            SUM(CAST(year AS FLOAT) * CAST(year AS FLOAT)) AS sum_x2
        FROM CoverageData
        GROUP BY country, iso_code
    ) t
    WHERE (n * sum_xy - sum_x * sum_y) / NULLIF(n * sum_x2 - sum_x * sum_x, 0) > 0
),
BestYearFlag AS (
    SELECT
        c.*,
        ROW_NUMBER() OVER (
            PARTITION BY c.iso_code
            ORDER BY c.coverage_ratio DESC, c.year DESC
        ) AS rn
    FROM CoverageData c
    INNER JOIN PositiveTrendCountries p ON c.iso_code = p.iso_code
),
ExcludedBestYear AS (
    SELECT * FROM BestYearFlag WHERE rn > 1     -- drop each country's single best year
),
RecomputedTrend AS (
    SELECT
        country, iso_code,
        COUNT(*) AS n,
        SUM(CAST(year AS FLOAT)) AS sum_x,
        SUM(coverage_ratio) AS sum_y,
        SUM(CAST(year AS FLOAT) * coverage_ratio) AS sum_xy,
        SUM(CAST(year AS FLOAT) * CAST(year AS FLOAT)) AS sum_x2
    FROM ExcludedBestYear
    GROUP BY country, iso_code
)
SELECT
    country, iso_code,
    (n * sum_xy - sum_x * sum_y) / NULLIF(n * sum_x2 - sum_x * sum_x, 0)
        AS slope_excluding_best_year,
    CASE
        WHEN (n * sum_xy - sum_x * sum_y) / NULLIF(n * sum_x2 - sum_x * sum_x, 0) > 0
            THEN 'Sustained'
        ELSE 'Outlier-driven'
    END AS sustained_flag
FROM RecomputedTrend
ORDER BY slope_excluding_best_year DESC;
GO
