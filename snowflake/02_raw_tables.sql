-- Synthetic line-day observations for Tembusu Fresh Mart, a fictional Singapore supermarket chain.
-- A merchandise line is one product category ranged in the store cluster of one real
-- Singapore planning area (HDB town). Prices are in SGD.
-- Nothing is seeded as a prediction. Randomness is HASH-seeded, so every rebuild
-- is reproducible: per-line markdown propensity, shelf price drift between
-- price audits, missed price audits, category-weighted pricing exception types,
-- exceptions resolved without a markdown, and two town-wide competitor price campaigns.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

CREATE TABLE RAW.MERCH_LINES AS
WITH lines AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS LINE_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 48))
), draws AS (
  SELECT LINE_INDEX,
         MOD(ABS(HASH(LINE_INDEX, 'sg-merch-age')), 1000000) / 1e6 AS U_AGE,
         MOD(ABS(HASH(LINE_INDEX, 'sg-merch-rate')), 1000000) / 1e6 AS U_RATE,
         MOD(ABS(HASH(LINE_INDEX, 'sg-merch-audit')), 1000000) / 1e6 AS U_SYNC,
         MOD(ABS(HASH(LINE_INDEX, 'sg-merch-discipline')), 1000000) / 1e6 AS U_DISCIPLINE,
         MOD(ABS(HASH(LINE_INDEX, 'sg-merch-tier')), 1000000) / 1e6 AS U_TIER
  FROM lines
)
SELECT 'MLN-' || LPAD(LINE_INDEX::VARCHAR, 4, '0') AS ID,
       'Synthetic merchandise line ' || LPAD(LINE_INDEX::VARCHAR, 4, '0') AS NAME,
       -- Deterministic spread (5 and 8 are coprime): every planning area and category is present.
       CASE MOD(LINE_INDEX, 5) WHEN 0 THEN 'Bukit Batok' WHEN 1 THEN 'Sengkang'
            WHEN 2 THEN 'Toa Payoh' WHEN 3 THEN 'Bedok' ELSE 'Yishun' END AS REGION,
       CASE MOD(LINE_INDEX, 8) WHEN 0 THEN 'Fresh produce' WHEN 1 THEN 'Fresh produce'
            WHEN 2 THEN 'Snacks and beverages' WHEN 3 THEN 'Snacks and beverages'
            WHEN 4 THEN 'Dairy and chilled' WHEN 5 THEN 'Dairy and chilled'
            WHEN 6 THEN 'Household care' ELSE 'Personal care' END AS CATEGORY,
       LINE_INDEX,
       1 + FLOOR(U_TIER * 3) AS RISK_TIER,
       ROUND(0.5 + U_AGE * 7.5, 1) AS RANGE_AGE_YEARS,
       -- Base daily probability of an unplanned markdown 0.5%-2.9%; ~12% of lines
       -- are chronically weak (x2.6).
       (0.005 + U_RATE * 0.024) * IFF(U_RATE > 0.88, 2.6, 1) AS BASE_MARKDOWN_RATE,
       7 * (1 + FLOOR(U_SYNC * 2)) AS PRICE_AUDIT_INTERVAL_DAYS,
       0.6 + U_DISCIPLINE * 0.4 AS PRICE_AUDIT_COMPLETION_PROB,
       'Active' AS STATUS
FROM draws;

CREATE TABLE RAW.LINE_DAILY AS
WITH days AS (
  SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1 AS DAY_INDEX
  FROM TABLE(GENERATOR(ROWCOUNT => 90))
), city_events AS (
  -- Two town-wide competitor price campaigns; every line in the planning area raises a pricing
  -- exception that is resolved with a price match instead of a markdown.
  SELECT * FROM VALUES (27, 'Sengkang'), (64, 'Yishun') AS o(DAY_INDEX, REGION)
), base AS (
  SELECT s.ID AS ENTITY_ID, s.LINE_INDEX, s.CATEGORY, s.REGION, s.RANGE_AGE_YEARS,
         s.BASE_MARKDOWN_RATE, s.PRICE_AUDIT_INTERVAL_DAYS, s.PRICE_AUDIT_COMPLETION_PROB,
         d.DAY_INDEX,
         DATEADD('day', d.DAY_INDEX - 89, CURRENT_DATE()) AS EVENT_DATE,
         MOD(d.DAY_INDEX + s.LINE_INDEX * 3, s.PRICE_AUDIT_INTERVAL_DAYS) AS DAYS_SINCE_AUDIT,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-merch-markdown')), 1000000) / 1e6 AS U_MARKDOWN,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-merch-detect')), 1000000) / 1e6 AS U_DETECT,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-merch-resolve')), 1000000) / 1e6 AS U_RESOLVE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-merch-type')), 1000000) / 1e6 AS U_TYPE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-merch-done')), 1000000) / 1e6 AS U_DONE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-merch-volume')), 1000000) / 1e6 AS U_VOLUME,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-merch-noise')), 1000000) / 1e6 AS U_NOISE,
         MOD(ABS(HASH(s.ID, d.DAY_INDEX, 'sg-merch-delay')), 1000000) / 1e6 AS U_LATE,
         e.REGION IS NOT NULL AS CITY_EVENT
  FROM RAW.MERCH_LINES s CROSS JOIN days d
  LEFT JOIN city_events e ON e.DAY_INDEX = d.DAY_INDEX AND e.REGION = s.REGION
), audit AS (
  SELECT *,
         IFF(DAYS_SINCE_AUDIT = 0, 1, 0) AS PRICE_AUDIT_DUE,
         IFF(DAYS_SINCE_AUDIT = 0 AND U_DONE < PRICE_AUDIT_COMPLETION_PROB, 1, 0) AS PRICE_AUDIT_DONE,
         -- Shelf price drift (shelf label versus system price) rises between price
         -- audits; weak audit discipline carries it over.
         DAYS_SINCE_AUDIT / PRICE_AUDIT_INTERVAL_DAYS + (1 - PRICE_AUDIT_COMPLETION_PROB) AS DRIFT
  FROM base
),
markdowns AS (
  SELECT *,
         CASE WHEN U_MARKDOWN < LEAST(0.5, BASE_MARKDOWN_RATE * (0.5 + 1.5 * DRIFT) * (1 + 1 / (1 + RANGE_AGE_YEARS))) / 4 THEN 2
              WHEN U_MARKDOWN < LEAST(0.5, BASE_MARKDOWN_RATE * (0.5 + 1.5 * DRIFT) * (1 + 1 / (1 + RANGE_AGE_YEARS))) THEN 1
              ELSE 0 END AS MARKDOWN_RISK_COUNT
  FROM audit
), exceptions AS (
  SELECT *,
         -- About 82% of at-risk line-days raise a pricing exception and end in an
         -- unplanned markdown; the rest only delay the next promotion.
         IFF(CITY_EVENT, 0, IFF(U_DETECT < 0.82, MARKDOWN_RISK_COUNT, 0)) AS MARKDOWN_COUNT,
         -- Exceptions resolved without a markdown: higher for perishable categories.
         IFF(CITY_EVENT, 1, IFF(U_RESOLVE < CASE CATEGORY WHEN 'Fresh produce' THEN 0.22
                                                          WHEN 'Dairy and chilled' THEN 0.15
                                                          WHEN 'Snacks and beverages' THEN 0.12 ELSE 0.07 END, 1, 0)) AS RESOLVED_COUNT
  FROM markdowns
), measured AS (
  SELECT *,
         MARKDOWN_COUNT + RESOLVED_COUNT AS EXCEPTION_COUNT,
         ROUND(CASE CATEGORY WHEN 'Fresh produce' THEN 900 WHEN 'Snacks and beverages' THEN 650
                             WHEN 'Dairy and chilled' THEN 520 WHEN 'Household care' THEN 180 ELSE 240 END
               * (0.7 + 0.6 * U_VOLUME) * (1 + 0.5 * MARKDOWN_RISK_COUNT)) AS UNITS_SOLD,
         CASE CATEGORY WHEN 'Fresh produce' THEN 3.2 WHEN 'Snacks and beverages' THEN 4.2
                       WHEN 'Dairy and chilled' THEN 5.1 WHEN 'Household care' THEN 10.7 ELSE 13.0 END
           * (0.85 + 0.3 * U_NOISE) AS AVG_UNIT_PRICE_SGD
  FROM exceptions
)
SELECT ENTITY_ID || '-' || TO_CHAR(EVENT_DATE, 'YYYYMMDD') AS EVENT_ID,
       ENTITY_ID, EVENT_DATE,
       UNITS_SOLD,
       ROUND(UNITS_SOLD * AVG_UNIT_PRICE_SGD, 0) AS NET_SALES_SGD,
       EXCEPTION_COUNT, MARKDOWN_COUNT,
       IFF(MARKDOWN_COUNT > 0 AND U_LATE < 0.55, 1, 0) AS PROMO_DELAY,
       CASE WHEN EXCEPTION_COUNT = 0 THEN 'None'
            WHEN CITY_EVENT THEN 'Competitor price campaign'
            WHEN CATEGORY = 'Fresh produce' THEN IFF(U_TYPE < 0.5, 'Short-dated stock', IFF(U_TYPE < 0.8, 'Shelf price mismatch', 'Overstock after promo'))
            WHEN CATEGORY = 'Snacks and beverages' THEN IFF(U_TYPE < 0.45, 'Promo price not loaded', IFF(U_TYPE < 0.8, 'Overstock after promo', 'Margin floor breach'))
            WHEN CATEGORY = 'Dairy and chilled' THEN IFF(U_TYPE < 0.5, 'Short-dated stock', 'Supplier cost increase')
            WHEN CATEGORY = 'Household care' THEN IFF(U_TYPE < 0.45, 'Margin floor breach', IFF(U_TYPE < 0.8, 'Supplier cost increase', 'Shelf price mismatch'))
            ELSE IFF(U_TYPE < 0.5, 'Promo price not loaded', IFF(U_TYPE < 0.75, 'Shelf price mismatch', 'Overstock after promo')) END AS EXCEPTION_TYPE,
       PRICE_AUDIT_DUE, PRICE_AUDIT_DONE,
       ROUND(4 + 3.0 * DRIFT + 6.0 * MARKDOWN_RISK_COUNT + U_NOISE * 1.5, 2) AS MARKDOWN_DEPTH_PCT,
       ROUND(20 + 10 * DRIFT + 12 * MARKDOWN_RISK_COUNT + U_NOISE * 5, 1) AS PRICE_CHANGE_LEAD_HRS,
       CURRENT_TIMESTAMP() AS LOADED_AT
FROM measured;

-- Supplier funding agreement coverage per line (snapshot).
CREATE TABLE RAW.FUNDING_AGREEMENTS AS
SELECT ID AS ENTITY_ID,
       CASE CATEGORY WHEN 'Fresh produce' THEN 'Markdown support agreement'
                     WHEN 'Snacks and beverages' THEN 'Promotional funding agreement'
                     WHEN 'Dairy and chilled' THEN 'Cost price confirmation'
                     WHEN 'Household care' THEN 'Volume rebate agreement'
                     ELSE 'Promotional funding agreement' END AS DOC_TYPE,
       1 + MOD(ABS(HASH(ID, 'sg-merch-req')), 4) AS REQUIRED_QTY,
       MOD(ABS(HASH(ID, 'sg-merch-file')), 5) AS ON_FILE_QTY,
       IFF(MOD(ABS(HASH(ID, 'sg-merch-file')), 5) < 1 + MOD(ABS(HASH(ID, 'sg-merch-req')), 4),
           MOD(ABS(HASH(ID, 'sg-merch-pending')), 3), 0) AS PENDING_QTY,
       CURRENT_DATE() AS SNAPSHOT_DATE
FROM RAW.MERCH_LINES;
