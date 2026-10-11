-- ============================================================================
-- 06_INTELLIGENCE.SQL - search, anomaly detection, semantic view, agent,
-- live-POS alert and on-demand refresh DAG.
-- Run with snowflake/run_intelligence.py (substitutes checked __DEMO_DB__ /
-- __DEMO_WH__ / __ALERT_EMAIL__). Requires 00-05, plus 08 (Snowflake only) or
-- aws/setup_aws.py (AWS build) for RAW.LIVE_POS.
-- Alerts and tasks are created SUSPENDED; run them with EXECUTE ALERT / EXECUTE TASK.
-- ============================================================================
USE DATABASE __DEMO_DB__;
CREATE SCHEMA IF NOT EXISTS SEARCH;
CREATE SCHEMA IF NOT EXISTS APP;

-- ---------- Synthetic pricing-exception knowledge base (clearly synthetic SOPs) ----------
CREATE OR REPLACE TABLE SEARCH.EXCEPTION_DOCS AS
WITH types AS (
  SELECT DISTINCT r.EXCEPTION_TYPE, a.CATEGORY
  FROM RAW.LINE_DAILY r JOIN RAW.MERCH_LINES a ON a.ID = r.ENTITY_ID
  WHERE r.MARKDOWN_COUNT > 0
)
SELECT
  'SOP-' || LPAD(ROW_NUMBER() OVER (ORDER BY CATEGORY, EXCEPTION_TYPE)::VARCHAR, 3, '0') AS DOC_ID,
  'SOP' AS DOC_TYPE,
  CATEGORY,
  EXCEPTION_TYPE,
  CATEGORY || ' - ' || EXCEPTION_TYPE || ' pricing exception handling' AS TITLE,
  'Synthetic demo SOP. Product category: ' || CATEGORY || '. Pricing exception type: ' || EXCEPTION_TYPE || '. '
  || 'Step 1: open a pricing case against the merchandise line, notify the category manager and store cluster lead, and freeze further price changes on the line until a pricing analyst triages the case. '
  || 'Step 2: ' || CASE
       WHEN EXCEPTION_TYPE = 'Shelf price mismatch' THEN 'compare the shelf label with the system price for every affected item, reprint and replace labels in the store cluster, and honour the lower price at the register until the labels are fixed.'
       WHEN EXCEPTION_TYPE = 'Promo price not loaded' THEN 'confirm the promotion calendar entry, load the promotional price to the point-of-sale system, and run a test scan before the promotion window opens.'
       WHEN EXCEPTION_TYPE = 'Margin floor breach' THEN 'recalculate the line margin with the current cost price, restore the regular price if no supplier funding is on file, and record the decision in the pricing log.'
       WHEN EXCEPTION_TYPE = 'Supplier cost increase' THEN 'check the new cost price against the cost price confirmation, request supplier support for the current promotion, and schedule a regular price review.'
       WHEN EXCEPTION_TYPE = 'Overstock after promo' THEN 'compare post-promotion stock cover with the plan, move surplus stock between stores in the cluster, and apply a staged clearance price only if cover stays above four weeks.'
       WHEN EXCEPTION_TYPE = 'Short-dated stock' THEN 'list the affected batches by best-before date, apply the category markdown ladder, and adjust the next replenishment order.'
       ELSE 'review the exception against the line history and escalate to the category manager if the cause is unclear.'
     END
  || ' Step 3: keep the case open and schedule a line pricing review when, after triage, the average markdown depth is above 12% or the price change lead time is above 40 hours. '
  || 'Step 4: close the case with the outcome; for an unplanned markdown or a delayed promotion, record the margin impact and add the case to the weekly merchandising review.' AS CONTENT
FROM types;

CREATE OR REPLACE CORTEX SEARCH SERVICE SEARCH.EXCEPTION_SOP_SEARCH
  ON CONTENT
  ATTRIBUTES CATEGORY, EXCEPTION_TYPE
  WAREHOUSE = __DEMO_WH__
  TARGET_LAG = '7 days'
AS (SELECT DOC_ID, TITLE, CATEGORY, EXCEPTION_TYPE, CONTENT FROM SEARCH.EXCEPTION_DOCS);

-- ---------- Markdown depth anomaly detection (train first 75 days, detect last 15) ----------
CREATE OR REPLACE VIEW ML.MARKDOWN_DEPTH_SERIES AS
SELECT ENTITY_ID, EVENT_DATE::TIMESTAMP_NTZ AS TS, MARKDOWN_DEPTH_PCT::FLOAT AS MARKDOWN_DEPTH
FROM RAW.LINE_DAILY;
CREATE OR REPLACE VIEW ML.MARKDOWN_DEPTH_TRAIN AS
SELECT * FROM ML.MARKDOWN_DEPTH_SERIES WHERE TS < (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.MARKDOWN_DEPTH_SERIES);
CREATE OR REPLACE VIEW ML.MARKDOWN_DEPTH_DETECT AS
SELECT * FROM ML.MARKDOWN_DEPTH_SERIES WHERE TS >= (SELECT DATEADD(day, -15, MAX(TS)) FROM ML.MARKDOWN_DEPTH_SERIES);

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ML.MARKDOWN_DEPTH_ANOMALY_MODEL(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.MARKDOWN_DEPTH_TRAIN'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'MARKDOWN_DEPTH',
  LABEL_COLNAME => '');

CREATE OR REPLACE TABLE ML.MARKDOWN_DEPTH_ANOMALIES AS
SELECT SERIES::VARCHAR AS ENTITY_ID, TS::DATE AS EVENT_DATE, Y AS MARKDOWN_DEPTH, FORECAST AS EXPECTED,
       LOWER_BOUND, UPPER_BOUND, IS_ANOMALY, PERCENTILE
FROM TABLE(ML.MARKDOWN_DEPTH_ANOMALY_MODEL!DETECT_ANOMALIES(
  INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'ML.MARKDOWN_DEPTH_DETECT'),
  SERIES_COLNAME => 'ENTITY_ID', TIMESTAMP_COLNAME => 'TS', TARGET_COLNAME => 'MARKDOWN_DEPTH'));

-- ---------- Semantic view ----------
CREATE OR REPLACE SEMANTIC VIEW APP.MERCHANDISING_ANALYTICS
  TABLES (
    lines AS CURATED.PERFORMANCE_SUMMARY PRIMARY KEY (ENTITY_ID)
      WITH SYNONYMS = ('entities', 'merchandise lines', 'category lines')
      COMMENT = 'One row per merchandise line (planning area and product category), 90-day totals',
    risk AS ML.MARKDOWN_RISK_SCORES PRIMARY KEY (ENTITY_ID)
      COMMENT = 'Latest next-7-day unplanned-markdown probability per line',
    exceptions AS CURATED.EXCEPTION_SUMMARY PRIMARY KEY (EXCEPTION_TYPE)
      COMMENT = 'Pricing exceptions, unplanned markdowns and promo setup delays by exception type, 90 days',
    daily AS CURATED.TREND_ANALYSIS PRIMARY KEY (METRIC_DATE)
      COMMENT = 'Network-wide totals per day'
  )
  RELATIONSHIPS (risk_line AS risk (ENTITY_ID) REFERENCES lines)
  FACTS (
    lines.exceptions_f AS EXCEPTION_COUNT,
    lines.markdowns_f AS MARKDOWN_COUNT,
    lines.delay_f AS PROMO_DELAY_COUNT,
    lines.units_f AS UNITS_SOLD,
    lines.sales_f AS NET_SALES_SGD,
    lines.audit_due_f AS PRICE_AUDIT_DUE,
    lines.audit_done_f AS PRICE_AUDIT_DONE,
    risk.markdown_prob_f AS MARKDOWN_PROB_7D,
    exceptions.type_exceptions_f AS EXCEPTION_COUNT,
    exceptions.type_markdowns_f AS MARKDOWN_COUNT,
    exceptions.type_delay_f AS PROMO_DELAY_COUNT,
    exceptions.type_sales_f AS EXPOSED_SALES_SGD,
    daily.day_exceptions_f AS EXCEPTION_COUNT,
    daily.day_markdowns_f AS MARKDOWN_COUNT,
    daily.day_sales_f AS NET_SALES_SGD
  )
  DIMENSIONS (
    lines.line_id AS ENTITY_ID WITH SYNONYMS = ('line', 'merchandise line', 'entity', 'category line'),
    lines.line_name AS ENTITY_NAME,
    lines.city AS REGION WITH SYNONYMS = ('planning area', 'town', 'region', 'location')
      COMMENT = 'Singapore planning area (HDB town) of the store cluster the line is ranged in',
    lines.category AS CATEGORY WITH SYNONYMS = ('product category', 'department'),
    lines.risk_tier AS RISK_TIER COMMENT = 'Line pricing risk tier 1 (low) to 3 (high)',
    risk.risk_band AS RISK_BAND COMMENT = 'High >= 0.5, Medium >= 0.25, else Low',
    risk.scored_as_of AS SCORED_AS_OF,
    exceptions.exception_type AS EXCEPTION_TYPE WITH SYNONYMS = ('exception', 'pricing exception type', 'exception reason'),
    daily.metric_date AS METRIC_DATE
  )
  METRICS (
    lines.line_count AS COUNT(lines.line_id) WITH SYNONYMS = ('number of lines', 'number of entities', 'how many merchandise lines'),
    lines.price_integrity_rate_pct AS 100 * (SUM(lines.units_f) - SUM(lines.exceptions_f)) / NULLIF(SUM(lines.units_f), 0)
      WITH SYNONYMS = ('price integrity rate', 'exception-free unit rate')
      COMMENT = 'Units sold without a pricing exception / units sold',
    lines.exception_markdown_pct AS 100 * SUM(lines.markdowns_f) / NULLIF(SUM(lines.exceptions_f), 0)
      COMMENT = 'Unplanned markdowns / pricing exceptions raised',
    lines.exceptions_raised AS SUM(lines.exceptions_f) WITH SYNONYMS = ('pricing exceptions', 'price exceptions'),
    lines.unplanned_markdowns AS SUM(lines.markdowns_f) WITH SYNONYMS = ('markdowns', 'unplanned markdowns'),
    lines.promo_delays AS SUM(lines.delay_f) WITH SYNONYMS = ('promo delays', 'promotion setup delays'),
    lines.units_sold_total AS SUM(lines.units_f) WITH SYNONYMS = ('units', 'unit volume'),
    lines.total_net_sales_sgd AS SUM(lines.sales_f) WITH SYNONYMS = ('net sales', 'revenue', 'sales in SGD'),
    lines.price_audit_compliance_pct AS 100 * SUM(lines.audit_done_f) / NULLIF(SUM(lines.audit_due_f), 0)
      COMMENT = 'Price audits completed / price audits due',
    risk.avg_markdown_prob AS AVG(risk.markdown_prob_f),
    exceptions.type_exceptions AS SUM(exceptions.type_exceptions_f),
    exceptions.type_markdowns AS SUM(exceptions.type_markdowns_f),
    exceptions.type_delays AS SUM(exceptions.type_delay_f),
    exceptions.type_markdown_share_pct AS 100 * SUM(exceptions.type_markdowns_f) / NULLIF(SUM(exceptions.type_exceptions_f), 0),
    daily.daily_exceptions AS SUM(daily.day_exceptions_f),
    daily.daily_markdowns AS SUM(daily.day_markdowns_f),
    daily.daily_net_sales_sgd AS SUM(daily.day_sales_f)
  )
  COMMENT = 'Synthetic Singapore retail merchandising and pricing analytics (demo)';

-- ---------- Cortex Agent ----------
CREATE OR REPLACE AGENT APP.MERCHANDISING_AGENT
  COMMENT = 'Merchandising and pricing assistant over a synthetic Singapore supermarket chain'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5
instructions:
  response: "Answer only from tool results. State that data is synthetic. Give merchandise line IDs and numbers with units (SGD, %)."
  orchestration: "Use merchandising_analyst for units sold, net sales, pricing exceptions, unplanned markdowns, promo setup delays, price integrity rate, price audit compliance, merchandise lines, planning areas, categories, exception types and markdown risk. Use sop_search for pricing exception handling procedures."
tools:
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: merchandising_analyst
      description: "Units sold, net sales in SGD, pricing exceptions, unplanned markdowns, promo setup delays, price integrity rate, price audit compliance, exception types and unplanned-markdown risk scores by merchandise line, city and category"
  - tool_spec:
      type: cortex_search
      name: sop_search
      description: "Synthetic pricing exception handling SOPs by product category and exception type"
tool_resources:
  merchandising_analyst:
    semantic_view: __DEMO_DB__.APP.MERCHANDISING_ANALYTICS
    execution_environment:
      type: warehouse
      warehouse: __DEMO_WH__
  sop_search:
    name: __DEMO_DB__.SEARCH.EXCEPTION_SOP_SEARCH
    max_results: 3
    id_column: DOC_ID
    title_column: TITLE
$$;

-- ---------- Live-POS alert ----------
CREATE TABLE IF NOT EXISTS APP.ALERT_LOG (
  ALERTED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(), LINE_ID VARCHAR,
  EVENT_TS TIMESTAMP_NTZ, AMOUNT_SGD FLOAT, PRICE_GAP_BPS FLOAT, SOP_HINT VARCHAR);

CREATE OR REPLACE NOTIFICATION INTEGRATION SG_RETAIL_MERCHANDISING_EMAIL_INT
  TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = ('__ALERT_EMAIL__');

CREATE OR REPLACE PROCEDURE APP.LOG_LIVE_ALERTS()
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
DECLARE
  n NUMBER;
BEGIN
  INSERT INTO APP.ALERT_LOG (LINE_ID, EVENT_TS, AMOUNT_SGD, PRICE_GAP_BPS, SOP_HINT)
    SELECT p.LINE_ID, p.EVENT_TS, p.AMOUNT_SGD, p.PRICE_GAP_BPS,
           'Check ' || r.CATEGORY || ' pricing exception SOPs; current risk band ' || COALESCE(s.RISK_BAND, 'n/a')
    FROM RAW.LIVE_POS p
    JOIN RAW.MERCH_LINES r ON r.ID = p.LINE_ID
    LEFT JOIN ML.MARKDOWN_RISK_SCORES s ON s.ENTITY_ID = p.LINE_ID
    WHERE p.STATUS = 'EXCEPTION'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.LINE_ID = p.LINE_ID AND l.EVENT_TS = p.EVENT_TS);
  n := SQLROWCOUNT;
  IF (n > 0) THEN
    CALL SYSTEM$SEND_EMAIL('SG_RETAIL_MERCHANDISING_EMAIL_INT', '__ALERT_EMAIL__',
      '[Demo] Pricing exception alert',
      'New live pricing exceptions logged in APP.ALERT_LOG: ' || :n || '. Data is synthetic.');
  END IF;
  RETURN n;
END;
$$;

CREATE OR REPLACE ALERT APP.LIVE_POS_ALERT
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '5 MINUTE'
  IF (EXISTS (
    SELECT 1 FROM RAW.LIVE_POS p
    WHERE p.STATUS = 'EXCEPTION'
      AND NOT EXISTS (SELECT 1 FROM APP.ALERT_LOG l WHERE l.LINE_ID = p.LINE_ID AND l.EVENT_TS = p.EVENT_TS)))
  THEN CALL APP.LOG_LIVE_ALERTS();

-- ---------- On-demand refresh DAG (suspended; run with EXECUTE TASK APP.TASK_REFRESH_CURATED) ----------
CREATE OR REPLACE PROCEDURE APP.REFRESH_CURATED()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  ALTER DYNAMIC TABLE CURATED.PERFORMANCE_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.TREND_ANALYSIS REFRESH;
  ALTER DYNAMIC TABLE CURATED.EXCEPTION_SUMMARY REFRESH;
  ALTER DYNAMIC TABLE CURATED.KPI_SUMMARY REFRESH;
  RETURN 'refreshed';
END;
$$;

CREATE OR REPLACE TASK APP.TASK_REFRESH_CURATED
  WAREHOUSE = __DEMO_WH__
AS
  CALL APP.REFRESH_CURATED();

CREATE OR REPLACE TASK APP.TASK_RESCORE_RISK
  WAREHOUSE = __DEMO_WH__
  AFTER APP.TASK_REFRESH_CURATED
AS
  CREATE OR REPLACE TABLE ML.MARKDOWN_RISK_SCORES COPY GRANTS AS
  WITH latest AS (
    SELECT * FROM ML.MARKDOWN_FEATURES QUALIFY ROW_NUMBER() OVER (PARTITION BY ENTITY_ID ORDER BY EVENT_DATE DESC) = 1
  ), p AS (
    SELECT ENTITY_ID, EVENT_DATE,
           ML.MARKDOWN_RISK_MODEL!PREDICT(INPUT_DATA => OBJECT_CONSTRUCT(
             'CATEGORY', CATEGORY, 'RISK_TIER', RISK_TIER, 'RANGE_AGE_YEARS', RANGE_AGE_YEARS,
             'MARKDOWN_DEPTH_PCT', MARKDOWN_DEPTH_PCT, 'PRICE_CHANGE_LEAD_HRS', PRICE_CHANGE_LEAD_HRS,
             'MARKDOWN_DEPTH_7D', MARKDOWN_DEPTH_7D, 'MARKDOWNS_30D', MARKDOWNS_30D)) AS PRED
    FROM latest
  )
  SELECT ENTITY_ID, EVENT_DATE AS SCORED_AS_OF, ROUND(PRED:probability:MARKDOWN::FLOAT, 4) AS MARKDOWN_PROB_7D,
         CASE WHEN PRED:probability:MARKDOWN::FLOAT >= 0.5 THEN 'High'
              WHEN PRED:probability:MARKDOWN::FLOAT >= 0.25 THEN 'Medium' ELSE 'Low' END AS RISK_BAND,
         CURRENT_TIMESTAMP() AS SCORED_AT
  FROM p;
