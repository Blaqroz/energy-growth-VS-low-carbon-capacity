# Energy Growth vs. Low-Carbon Capacity

**An investigative analysis of whether low-carbon energy growth can keep pace with rising energy consumption across countries**

When a country's energy consumption increases, there's a simple question behind the numbers: where does that additional energy come from? This investigation looks specifically at whether growth in low-carbon energy is large enough to cover increases in total energy consumption — and follows the evidence into fossil-fuel behavior, simultaneous fossil and low-carbon growth, performance during unusually rapid demand growth, sustained coverage, and long-term trends.

---

## Table of Contents

- [Energy Growth vs. Low-Carbon Capacity](#energy-growth-vs-low-carbon-capacity)
  - [Table of Contents](#table-of-contents)
  - [Critical Question](#critical-question)
  - [Executive Summary](#executive-summary)
  - [Investigative Hierarchy](#investigative-hierarchy)
  - [Problem Statement](#problem-statement)
  - [Dataset and Scope](#dataset-and-scope)
  - [Methodology](#methodology)
  - [Data Preparation](#data-preparation)
  - [SQL Investigation](#sql-investigation)
  - [EQ-to-Evidence Structure](#eq-to-evidence-structure)
  - [Key Findings](#key-findings)
  - [Power BI Storytelling](#power-bi-storytelling)
  - [Interpretation](#interpretation)
  - [Limitations](#limitations)
  - [Final Answer to the URQ](#final-answer-to-the-urq)
  - [Tools Used](#tools-used)
  - [Repository Structure](#repository-structure)
  - [Reproducibility](#reproducibility)

---

## Critical Question

**To what extent can low-carbon energy growth keep pace with increases in total energy consumption across countries?**

Not "is low-carbon energy growing" — almost everywhere, it is. The harder question is whether that growth is large enough, relative to a country's own rising energy consumption, to actually matter.

## Executive Summary

Low-carbon energy growth can cover a large share of rising energy consumption in some countries, but it does so unevenly, and the pattern doesn't hold up well under pressure. Norway's low-carbon growth covered 92.71% of its energy-consumption increase; China added more low-carbon energy than any other country studied (8,672.4 TWh) but that covered only 18.80% of its 46,123.3 TWh increase. The amount of low-carbon energy a country adds and how well that growth keeps pace with its own rising consumption are two different things, and the investigation treats them as such throughout.

Stronger coverage is associated with weaker fossil-fuel growth, but low-carbon expansion doesn't automatically mean fossil displacement — fossil and low-carbon consumption rose together in 41% of country-years studied. Coverage also weakens under stress: during unusually rapid consumption growth, most countries examined saw coverage decline. But the long-term picture isn't just decline — most countries with an improving trend kept improving even after removing their single best year, meaning the improvement is generally not a fluke.

## Investigative Hierarchy

This project does not start from a dataset and look for patterns. It follows a fixed investigative chain, and every number in this README can be traced back through it:

```
URQ  →  CQ  →  IQ  →  EQ  →  Evidence  →  Finding  →  Interpretation  →  Final Answer
```

- **URQ** — the single question the whole project answers
- **CQ** — three core dimensions of that question (coverage, fossil response, performance over time)
- **IQ** — eight specific investigative angles inside those three dimensions
- **EQ** — 21 concrete, SQL-answerable questions, one or more per IQ
- **Evidence → Finding → Interpretation** — what the query returned, what it means on its own, and what it means once weighed against everything else

Nothing in the findings below skips a link in that chain.

## Problem Statement

Energy transition narratives often stop at "renewable energy is growing." That statement is true almost everywhere and explains very little — a country can add thousands of TWh of low-carbon energy and still fall further behind its own rising consumption, while a smaller country adding far less can fully cover its growth. This investigation reframes the question: not whether low-carbon energy is expanding, but whether its expansion is *adequate relative to the energy growth it needs to absorb*.

This matters to energy planners, policymakers, and any organization assessing energy-transition claims at the country level, because "growth" and "adequacy" are being treated as the same thing when the evidence shows they frequently are not.

## Dataset and Scope

- **Source:** Energy Consumption Dataset by Our World in Data (OWID), via Kaggle
- **Unit of analysis:** country-year
- **Core measure:** change in low-carbon energy consumption relative to change in total energy consumption (both in TWh, using OWID's substitution-method primary-energy accounting — nuclear and renewables summed on a comparable energy basis to fossil fuels, not raw electricity output)
- **Working columns:** identity fields (country, year, iso_code) plus energy, fossil, and low-carbon consumption changes, their percentage equivalents, per-capita figures, and fossil/low-carbon share of energy. Electricity-system columns, per-source breakdowns (coal/gas/oil/solar/wind/etc.), and the `renewables_*` aggregate were deliberately excluded — the last because it excludes nuclear while `low_carbon_*` includes it, and mixing the two would silently create two different definitions of "clean energy" inside one investigation.

## Methodology

The coverage ratio behind every CQ is:

```
Coverage % = (change in low-carbon consumption) ÷ (change in total energy consumption) × 100
```

Several rules govern how that ratio is used, all fixed before the results were seen:

- **Growth floor (10 TWh):** a year only counts if total energy consumption grew by more than 10 TWh. Below that, a normal-sized low-carbon change can produce a mathematically correct but meaningless percentage (a 0.1 TWh demand increase can turn into a 500%+ "coverage" reading).
- **Minimum valid years (10):** a country needs at least 10 qualifying years before it appears in any ranking or aggregate — a country with 2–3 data points isn't comparable to one with decades of history.
- **Minimum stress-years (3):** for the stress-performance comparison specifically, a country also needs at least 3 years flagged as "unusually rapid" growth, in addition to the 10-year minimum, before its normal-vs-rapid comparison is treated as meaningful.
- **Pooled aggregation, not averaged percentages:** country- and group-level summaries add up the raw TWh values first and divide once, rather than averaging each year's individual percentage. Averaging percentages lets one extreme year count exactly as much as several ordinary ones and distorts the summary.
- **Negative coverage is kept, not filtered:** when low-carbon consumption falls while total energy consumption rises, coverage goes negative. That's a real backslide finding, not an error, and it stays in the dataset.
- **Coverage bands:** Low (<50%), Medium (50%–<100%), High (≥100%).
- **"Unusually rapid" growth** is defined relative to each country's own historical distribution (its own top 10% of growth years), not a single global threshold — a fast year for a small, stable economy isn't the same as a fast year for a rapidly industrializing one.
- **"Sustained" improvement** is a predetermined test, fixed before any result was seen: a country's positive coverage trend only counts as sustained if it remains positive after excluding that country's single best year. This was decided in advance specifically so "sustained" couldn't be defined after the fact to fit whatever looked best.

## Data Preparation

Cleaning was done in Excel before the dataset reached SQL. Based on the workbook and the analyst's own notes, the steps taken were:

- Rows with irrelevant null cells were removed
- Rows without an ISO country code were removed
- Irrelevant columns were dropped
- The data was checked for duplicate rows — none were found
- Several derived columns (`coverage_ratio_twh`, `coverage_pct`, `coverage_band`, `shortfall_twh`) were built with Excel formulas before the file was handed to SQL

**One issue was found and corrected during the SQL audit, not before:** for country-years where low-carbon consumption data doesn't exist yet (a country before low-carbon tracking began there), Excel's `coverage_pct` and `coverage_band` columns didn't stay blank — they read as a literal 0% / "Low," indistinguishable from a genuine zero-coverage finding. Most of the SQL queries guard against this by filtering directly on the raw low-carbon column, but the fossil-response-by-band query (IQ 2.1) initially didn't. It was corrected to filter out these no-data rows explicitly. The fix moved the Low-band fossil share figure from 89.18% to roughly 88.7% — a small change, which is itself useful evidence that the rest of the methodology was already sound going into this fix.

## SQL Investigation

All analysis was run in T-SQL against the cleaned dataset. The query set is organized one file per IQ (8 files, 21 EQs total) and follows the locked methodology above throughout — the same growth floor, eligibility minimums, and pooled-aggregation approach are applied consistently rather than varying file to file. Each file is commented in plain language explaining what each query retrieves and why, so the SQL is legible to someone without a deep analytics background.

This README doesn't reproduce every query — see [`/sql`](./sql) for the full, commented set. What matters here is the evidence each one produced and what that evidence means.

## EQ-to-Evidence Structure

| IQ | Representative EQ | What It Answers | Headline Evidence |
|---|---|---|---|
| 1.1 — Coverage Magnitude | EQ3 | Country-level coverage ratio | Norway 92.71% · China 18.80% |
| 1.2 — Coverage Shortfall | EQ8 | Which countries fall shortest, on average | Shortfalls exceeding 100 and, in extreme years, 300+ percentage points |
| 1.3 — Demand-Growth Scale | EQ9 | Does the size of growth predict coverage | r = −0.021 (TWh), r = −0.124 (%) — essentially no relationship |
| 2.1 — Fossil Response | EQ11/EQ12 | Fossil behavior across coverage bands | Low: +90.3 TWh avg fossil growth · High: −22.1 TWh avg decline |
| 2.2 — Stacking | EQ13/EQ14 | Do fossil and low-carbon grow together | 41.36% of country-years; 1,352 stacking years, +69.87 TWh avg fossil growth |
| 3.1 — Performance Under Pressure | EQ16/EQ17 | Coverage under unusually rapid growth | 28 of 44 eligible countries lost coverage; France's decline was largest (−49.82 pts) |
| 3.2 — Persistence | EQ18/EQ19 | Is ≥100% coverage sustained | France: 6-year longest streak, 36.11% of years ≥100% — the best case found |
| 3.3 — Sustained Improvement | EQ20/EQ21 | Is the long-term trend real | 36 countries improving, 17 declining; 34 of 36 positive trends survive removing the best year |

## Key Findings

**CQ1 — Demand Coverage:** Low-carbon growth has covered a highly uneven share of rising energy consumption across countries. How much low-carbon energy a country adds is not a reliable indicator of how well it's keeping pace — China added the most in absolute terms but covered the least, proportionally. The scale of a country's energy-consumption growth doesn't explain the difference either (correlation near zero either way).

**CQ2 — Fossil Response:** Weak coverage tends to occur alongside continued fossil-fuel growth; strong coverage is associated with flat or declining fossil consumption. But the two aren't the same process — in 41% of country-years, fossil and low-carbon consumption grew together. Adding clean energy does not, on its own, mean fossil energy is being displaced.

**CQ3 — Performance Over Time:** Coverage weakens under pressure for most countries — unusually rapid consumption growth reduced coverage in 28 of 44 eligible countries — but the response wasn't universal, and the long-run trend is not simply decline. More countries are improving than declining, and most of that improvement holds up even after removing each country's best single year, meaning it's generally a real trend rather than one good year.

## Power BI Storytelling

The dashboard is built directly from the EQ structure above, not as a separate visualization exercise. Each proposed visual was checked against the final 21-EQ set before being built — all of the following map cleanly to real, executed queries:

- **EQ3 — Overall coverage ratio per country:** the dashboard's central, country-level answer to the URQ. Best served as a ranked view or map.
- **EQ4 — Coverage by country-year:** a line chart with a country slicer, for inspecting individual trajectories rather than a single summary number.
- **EQ8 — Highest average shortfall by country:** a ranked bar, directly companion to the overall coverage result.
- **EQ5 — Min/median/max coverage:** used as a KPI/reference statistic (median shown as a benchmark line) rather than its own chart — a distribution doesn't need a full visual to be useful context.
- **EQ11 (fossil consumption change by band)** was chosen over EQ12 (fossil share by band) as the primary CQ2 visual — the swing from a 90.3 TWh average increase to a 22.1 TWh average decline tells a clearer, more immediate story than a share percentage. EQ12 is retained as supporting detail.
- **EQ13 — Stacking percentage:** a single KPI card (41.36%), supporting evidence rather than a standalone chart.
- **EQ16 — Coverage in normal vs. unusually rapid years:** the core stress-performance visual, shown as a clustered comparison per country.
- **EQ17 — Largest coverage decline under pressure:** a ranked bar, drilling down from EQ16.
- **EQ19 — Share of years at ≥100% coverage:** measures consistency rather than any single year's magnitude.
- **EQ20 — Coverage trend direction:** shown categorically (Increasing / Decreasing / Flat) rather than as raw slope values.
- **EQ21 — Sustained vs. outlier-driven trends:** used as a filter/classification rather than its own chart — it qualifies EQ20's result rather than standing alone.

The current dashboard (`Global Energy Transition Dashboard`) already reflects this structure: a median coverage benchmark KPI, a fossil + low-carbon simultaneous-growth KPI, a coverage-bands distribution view, a year-by-year trajectory line, and a rapid-vs-normal comparison bar chart by country.

## Interpretation

The investigation's contribution isn't measuring whether low-carbon energy is growing — it almost always is. It's measuring whether that growth is large enough relative to the energy growth it's meant to absorb, and the evidence says that adequacy varies sharply by country, weakens under pressure, and doesn't automatically translate into fossil-fuel decline. A single number like "global renewable capacity is up X%" hides all of this — the same headline could describe a country closing the gap or one falling further behind it.

## Limitations

- The dataset's low-carbon series has denser coverage from roughly 2000 onward; countries with a long pre-2000 history and a country with a short but complete post-2000 history are not treated as equivalently reliable just because both cross the 10-year minimum. This distinction — historically available data vs. analytically comparable data — is a known open item, not fully resolved.
- All fossil-response findings (CQ2) describe association, not causation. The dataset is observational.
- The percentage-growth relationship in IQ 1.3 (r = −0.124) is weak; it's reported because it's the actual result, not treated as a strong effect.
- High-coverage country-years are a much smaller sample than Low or Medium — the High-band fossil figures should be read as suggestive, not representative.

## Final Answer to the URQ

**Low-carbon energy growth has demonstrated the capacity to cover a large share of increasing total energy consumption in some countries, but that capacity is uneven, difficult to sustain, and frequently insufficient elsewhere.** The decisive distinction is not how much low-carbon energy a country adds in absolute terms, but whether that growth is large enough relative to its own additional energy consumption. Stronger coverage is associated with lower fossil-fuel growth, yet low-carbon expansion frequently occurs alongside continued fossil expansion — growth of clean energy does not automatically constitute fossil displacement. Over time, many countries are improving their coverage, but unusually rapid increases in energy consumption commonly weaken that performance, and persistent full coverage remains uncommon.

## Tools Used

- **Excel** — initial cleaning, validation, and derived-column construction
- **T-SQL (Microsoft SQL Server)** — the full 21-EQ investigation
- **Power BI** — visual communication layer, built directly from the EQ structure
- **OWID / Kaggle** — source dataset [Energy Consumption Dataset by Our World in Data](https://www.kaggle.com/datasets/whisperingkahuna/energy-consumption-dataset-by-our-world-in-data)

## Repository Structure

```
├── README.md
├── sql/
│   └── analysis_queries.sql 
├── data/
│   └── cleaned_dataset.xlsx
├── powerbi/
│   └── energy_transition_dashboard.pbix
└── docs/
    └── Energy_Analytics_Master_Archive-1.docx
```

## Reproducibility

1. Load `data/cleaned_dataset.xlsx` into a SQL Server instance as `EnergyX`.
2. Run the eight `.sql` files in `/sql`, in IQ order — later queries (IQ 3.1, 3.3) depend on the same growth-floor and eligibility logic established in earlier files.
3. Open `powerbi/energy_transition_dashboard.pbix` and point its data source at the same table used for step 2.
4. All thresholds (10 TWh floor, 10-year minimum, 3-year stress minimum, coverage bands) are documented inline in the SQL comments — they are not hardcoded silently anywhere without an explanation next to them.
5. The original dataset can be obtained from []
