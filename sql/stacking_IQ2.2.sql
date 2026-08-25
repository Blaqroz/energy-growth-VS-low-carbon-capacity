-- EQ13: What percentage of all country-years had both fossil
-- consumption AND low-carbon consumption increasing in the
-- same year?
SELECT
    COUNT(CASE
        WHEN fossil_cons_change_twh > 0
         AND low_carbon_cons_change_twh > 0
        THEN 1
    END) * 100.0 / COUNT(*) AS stacking_percentage
FROM EnergyX
WHERE fossil_cons_change_twh IS NOT NULL
  AND low_carbon_cons_change_twh IS NOT NULL;
GO

-- EQ14: What is the average fossil-fuel consumption change (TWh)
-- during those "stacking" years (i.e. years identified in EQ13)?
SELECT
    AVG(fossil_cons_change_twh) AS avg_fossil_change_during_stacking_twh,
    COUNT(*) AS stacking_years
FROM EnergyX
WHERE fossil_cons_change_twh > 0
  AND low_carbon_cons_change_twh > 0;
GO
