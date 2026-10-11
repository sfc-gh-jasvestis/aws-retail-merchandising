-- Validate the producer contract before building downstream objects.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

EXECUTE IMMEDIATE $$
DECLARE
  violations INTEGER;
  invalid_source EXCEPTION (-20001, 'Synthetic source failed grain or measure validation');
BEGIN
  SELECT COUNT(*) INTO :violations FROM (
    SELECT ENTITY_ID, EVENT_DATE
    FROM RAW.LINE_DAILY
    GROUP BY ENTITY_ID, EVENT_DATE HAVING COUNT(*) <> 1
    UNION ALL
    SELECT observation.ENTITY_ID, observation.EVENT_DATE
    FROM RAW.LINE_DAILY observation
    LEFT JOIN RAW.MERCH_LINES line ON line.ID = observation.ENTITY_ID
    WHERE line.ID IS NULL OR observation.UNITS_SOLD < 0
       OR observation.NET_SALES_SGD < 0
       OR observation.MARKDOWN_COUNT < 0 OR observation.MARKDOWN_COUNT > observation.EXCEPTION_COUNT
       OR observation.EXCEPTION_COUNT > observation.UNITS_SOLD
       OR observation.PROMO_DELAY > observation.MARKDOWN_COUNT
       OR observation.PRICE_AUDIT_DONE > observation.PRICE_AUDIT_DUE
  );
  IF (violations > 0) THEN
    RAISE invalid_source;
  END IF;
END;
$$;
