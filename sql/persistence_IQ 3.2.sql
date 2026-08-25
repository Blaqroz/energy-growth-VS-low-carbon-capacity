-- EQ18: What is the longest run of consecutive years in which a
-- country's coverage ratio was at least 100%?
WITH QualifyingYears AS (
    SELECT
        country,
        year,
        (low_carbon_cons_change_twh / NULLIF(energy_cons_change_twh, 0)) * 100.0
            AS coverage_percentage
    FROM EnergyX
    WHERE energy_cons_change_twh > 10
      AND low_carbon_cons_change_twh IS NOT NULL
),
QualifyingStreakYears AS (
    SELECT
        country,
        year,
        year - ROW_NUMBER() OVER (PARTITION BY country ORDER BY year) AS streak_group
    FROM QualifyingYears
    WHERE coverage_percentage >= 100
),
StreakLengths AS (
    SELECT country, streak_group, COUNT(*) AS streak_length
    FROM QualifyingStreakYears
    GROUP BY country, streak_group
)
SELECT country, MAX(streak_length) AS longest_consecutive_years
FROM StreakLengths
GROUP BY country
ORDER BY longest_consecutive_years DESC;
GO

-- EQ19: What share of each country's qualifying years achieved
-- at least 100% coverage?
WITH QualifyingYears AS (
    SELECT
        country,
        (low_carbon_cons_change_twh / NULLIF(energy_cons_change_twh, 0)) * 100.0
            AS coverage_percentage
    FROM EnergyX
    WHERE energy_cons_change_twh > 10
      AND low_carbon_cons_change_twh IS NOT NULL
)
SELECT
    country,
    COUNT(*) AS qualifying_years,
    COUNT(CASE WHEN coverage_percentage >= 100 THEN 1 END) * 100.0 / COUNT(*)
        AS percentage_of_years_at_or_above_100
FROM QualifyingYears
GROUP BY country
HAVING COUNT(*) >= 10
ORDER BY percentage_of_years_at_or_above_100 DESC;
GO
