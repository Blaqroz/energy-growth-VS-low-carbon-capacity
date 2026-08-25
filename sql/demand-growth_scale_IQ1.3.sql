-- EQ9: Is there a relationship between the size of a country-
-- year's energy-consumption growth (in both TWh and %) and its
-- coverage ratio? This uses a correlation coefficient: a value
-- near 0 means "no meaningful relationship," near +1 means
-- "bigger growth years tend to have higher coverage," and near
-- -1 means the opposite.
WITH CountryYearData AS (
    SELECT
        country,
        year,
        CAST(energy_cons_change_twh AS FLOAT) AS energy_cons_change_twh,
        CAST(energy_cons_change_pct AS FLOAT) AS energy_cons_change_pct,
        CAST(
            (low_carbon_cons_change_twh / NULLIF(energy_cons_change_twh, 0)) * 100.0
            AS FLOAT
        ) AS coverage_ratio
    FROM EnergyX
    WHERE energy_cons_change_twh > 10
      AND low_carbon_cons_change_twh IS NOT NULL
),
Aggregates AS (
    SELECT
        COUNT(*) AS n,
        SUM(energy_cons_change_twh) AS sum_x1,
        SUM(energy_cons_change_twh * energy_cons_change_twh) AS sum_x1_sq,
        SUM(energy_cons_change_pct) AS sum_x2,
        SUM(energy_cons_change_pct * energy_cons_change_pct) AS sum_x2_sq,
        SUM(coverage_ratio) AS sum_y,
        SUM(coverage_ratio * coverage_ratio) AS sum_y_sq,
        SUM(energy_cons_change_twh * coverage_ratio) AS sum_x1_y,
        SUM(energy_cons_change_pct * coverage_ratio) AS sum_x2_y
    FROM CountryYearData
)
SELECT
    (n * sum_x1_y - sum_x1 * sum_y)
    / NULLIF(SQRT((n * sum_x1_sq - sum_x1 * sum_x1) * (n * sum_y_sq - sum_y * sum_y)), 0)
        AS twh_growth_coverage_relationship,
    (n * sum_x2_y - sum_x2 * sum_y)
    / NULLIF(SQRT((n * sum_x2_sq - sum_x2 * sum_x2) * (n * sum_y_sq - sum_y * sum_y)), 0)
        AS pct_growth_coverage_relationship
FROM Aggregates;
GO
