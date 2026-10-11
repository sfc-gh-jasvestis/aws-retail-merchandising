-- ============================================================================
-- 08_native_pos.sql - Snowflake-only build: live point-of-sale feed without AWS.
-- Creates RAW.LIVE_POS (same columns as the Snowpipe target created by
-- aws/setup_aws.py) and APP.SIMULATE_POS(N), which inserts synthetic
-- point-of-sale events with the same value ranges and ~8% EXCEPTION rate as
-- aws/publish_pos.py. Rows are inserted directly; this simulates a POS
-- feed and is not Snowpipe Streaming.
-- Run before 06_intelligence.sql (the alert reads RAW.LIVE_POS).
-- Idempotent: safe to run in the AWS build too.
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS APP;

CREATE TABLE IF NOT EXISTS RAW.LIVE_POS (
  LINE_ID VARCHAR, EVENT_TS TIMESTAMP_NTZ, AMOUNT_SGD FLOAT, PRICE_GAP_BPS FLOAT,
  STATUS VARCHAR, SENT_TS TIMESTAMP_NTZ, SOURCE_FILE VARCHAR,
  LOADED_AT TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP());

CREATE OR REPLACE PROCEDURE APP.SIMULATE_POS(N NUMBER)
RETURNS NUMBER
LANGUAGE SQL
EXECUTE AS OWNER
AS
$$
BEGIN
  IF (N < 1 OR N > 1000) THEN
    RETURN 0;
  END IF;
  INSERT INTO RAW.LIVE_POS (LINE_ID, EVENT_TS, AMOUNT_SGD, PRICE_GAP_BPS, STATUS, SENT_TS, SOURCE_FILE)
    WITH g AS (
      SELECT 'MLN-' || LPAD(UNIFORM(0, 47, RANDOM())::VARCHAR, 4, '0') AS LINE_ID,
             UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.08 AS IS_EXCEPTION,
             SYSDATE() AS TS, SEQ4() AS I
      FROM TABLE(GENERATOR(ROWCOUNT => 1000))
    )
    -- NORMAL() needs constant arguments, so the exception offset is applied outside it.
    SELECT LINE_ID, TS,
           ROUND(IFF(IS_EXCEPTION, 65, 28) * EXP(NORMAL(0, 0.5, RANDOM())), 2),
           ROUND(IFF(IS_EXCEPTION, 950, 120) * EXP(NORMAL(0, 0.4, RANDOM())), 0),
           IFF(IS_EXCEPTION, 'EXCEPTION', 'OK'), TS, 'APP.SIMULATE_POS'
    FROM g
    WHERE I < :N;
  RETURN SQLROWCOUNT;
END;
$$;

-- Optional continuous feed for longer demos (suspended; RESUME to start, SUSPEND after).
CREATE OR REPLACE TASK APP.TASK_SIMULATE_POS
  WAREHOUSE = __DEMO_WH__
  SCHEDULE = '1 MINUTE'
AS
  CALL APP.SIMULATE_POS(5);
