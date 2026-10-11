# Singapore Retail Merchandising and Pricing

**Singapore - Supermarket Retail**
Use case: pricing exceptions, unplanned markdowns, promo setup and supplier funding controls

> Merchandising and pricing control for 48 fictional merchandise lines of Tembusu Fresh Mart, a fictional Singapore supermarket chain, ranged in the store clusters of five HDB towns: Bukit Batok, Sengkang, Toa Payoh, Bedok and Yishun. The demo covers dynamic tables, an unplanned-markdown classifier evaluated on a time-based holdout, a pricing-exception forecast, markdown depth anomaly detection, a Cortex Agent that cites SOPs, a live POS feed with an alert, and an SPCS app.

## Why Snowflake

- **Dynamic tables** turn line-day rows into units sold, pricing exceptions, unplanned markdowns, promo setup delays and price audit compliance; `run_core.py` reconciles them against RAW on every build
- **Unplanned-markdown classification** gives each merchandise line a next-7-day probability, evaluated on a time-based holdout
- **Pricing-exception forecast** projects 14 days of pricing exceptions across all five towns with prediction intervals, to plan pricing desk cover
- **Grounded AI**: the Cortex Agent (Analyst over a semantic view, Search over SOPs) shows the SQL it ran and the SOPs it cited
- **Live POS**: a native simulator (Snowflake only) or Firehose, S3 and Snowpipe (AWS build), feeding an alert and email

## What is built

| | |
|---|---|
| Dimension table | `RAW.MERCH_LINES` (48 rows) |
| Fact table | `RAW.LINE_DAILY` (4,320 line-days, 90 days) |
| Curated layer | `CURATED.KPI_SUMMARY`, `PERFORMANCE_SUMMARY`, `EXCEPTION_SUMMARY`, `TREND_ANALYSIS` |
| ML | `ML.MARKDOWN_RISK_SCORES`, `ML.MARKDOWN_RISK_HOLDOUT_METRICS`, `ML.EXCEPTION_FORECAST`, `ML.MARKDOWN_DEPTH_ANOMALIES` |

Currency: SGD. Planning areas (HDB towns): Bukit Batok, Sengkang, Toa Payoh, Bedok, Yishun.
Categories: Fresh produce, Snacks and beverages, Dairy and chilled, Household care, Personal care.

## KPI cards (live from `CURATED.KPI_SUMMARY`; no fallback values)

| Card | Value from the seeded data |
|---|---|
| Price Integrity Rate | 99.97% |
| Pricing Exceptions Raised | 768 |
| Unplanned Markdowns | 208 |
| Exception Markdown Rate | 27.1% |
| Promo Setup Delays | 89 |
| Net Sales (SGD K) | 12,026 |
| Units Sold | 2,530,925 |
| Price Audit Compliance | 79.6% |
| Merchandise Lines Monitored | 48 |
| Funding Agreement Coverage | 65.5% |
| Funding Agreements Pending | 21 |

Values are synthetic. The data is HASH-seeded, so a rebuild reproduces them; dates are relative to the build day.

## Demo flow

1. Executive Cockpit: KPI cards, daily pricing exceptions against unplanned markdowns, exceptions and markdowns by exception type, and the merchandise line table
2. Predictive: holdout metrics, risk bands, the 14-day pricing-exception forecast and markdown depth anomalies
3. Controls: price audit compliance, supplier funding agreement coverage and pending agreements, price audit compliance against unplanned markdowns, then the action memo
4. Live POS: run `CALL APP.SIMULATE_POS(20)` (Snowflake only) or `python aws/publish_pos.py --count 20` (AWS build), then `EXECUTE ALERT APP.LIVE_POS_ALERT`, and show the alert log and email
5. Ask AI: the Cortex Agent answers metric questions through the semantic view, cites SOPs from Cortex Search and shows its SQL
6. QuickSight (AWS build): the same Snowflake tables through DIRECT_QUERY
7. Architecture: both builds side by side

## Talking points

- 99.97% of units sell without a pricing exception. The 768 pricing exceptions are where Farah Aziz's pricing team spends its time, and 27.1% of them end in an unplanned markdown.
- Promo price not loaded is the biggest source of unplanned markdowns (42 of 101 exceptions), ahead of margin floor breaches (40 of 77). The competitor price campaigns in Sengkang and Yishun hit every line in the town on one day, and all 19 were answered with a price match, without a markdown.
- Yishun lines have the most unplanned markdowns (58); Bedok has the fewest (32).
- On a time-based holdout the risk model reaches precision 0.51 and recall 0.39 at 0.5, against a 0.20 base rate. Use it to decide which lines Daniel Koh reviews first, not as a verdict on a category team.
- Competitor price campaigns are left out of model training because the line did not cause them.

## Business impact

Use only the sourced references in `README.md` (Business Impact).
