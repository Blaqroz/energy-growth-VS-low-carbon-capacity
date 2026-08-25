-- EQ10: What coverage band -- Low, Medium, or High -- does each
-- country-year fall into?
SELECT
    country,
    year,
    coverage_pct AS coverage_percentage,
    coverage_band
FROM EnergyX
WHERE energy_cons_change_twh > 10
  AND coverage_band IS NOT NULL
  AND coverage_pct > 0
ORDER BY country, year;
GO

-- EQ11: What is the average fossil-fuel consumption change (TWh)
-- for country-years in each coverage band?
SELECT
    coverage_band,
    AVG(fossil_cons_change_twh) AS avg_fossil_change_twh,
    COUNT(*) AS country_years_in_band
FROM EnergyX
WHERE energy_cons_change_twh > 10
  AND coverage_band IS NOT NULL
  AND fossil_cons_change_twh IS NOT NULL
GROUP BY coverage_band
ORDER BY
    CASE coverage_band
        WHEN 'Low' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'High' THEN 3
    END;
GO

-- EQ12: What is the average fossil share of energy for
-- country-years in each coverage band?
SELECT
    coverage_band,
    AVG(fossil_share_energy) AS avg_fossil_share,
    COUNT(*) AS country_years_in_band
FROM EnergyX
WHERE energy_cons_change_twh > 10
  AND coverage_band IS NOT NULL
  AND fossil_share_energy IS NOT NULL
GROUP BY coverage_band
ORDER BY
    CASE coverage_band
        WHEN 'Low' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'High' THEN 3
    END;
GO
