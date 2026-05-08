-- Apply Pareto SKU revenue skew: top 5% bestsellers (12x volume), bottom 30% near-dead.
-- Recreates RAW.SALES with hash-based deterministic per-SKU multiplier.
-- After: PRODUCT_MARGIN_ANALYSIS dynamic table re-aggregates with realistic 200x+ revenue spread.

USE SCHEMA RETAIL_MERCHANDISING.RAW;

CREATE OR REPLACE TABLE SALES AS
WITH ranked AS (
  SELECT PRODUCT_ID, ROW_NUMBER() OVER (ORDER BY ABS(HASH(PRODUCT_ID,'rank'))) AS rk FROM PRODUCTS
), tiered AS (
  SELECT PRODUCT_ID,
    CASE WHEN rk <= 50  THEN 12.0    -- top 5% bestsellers
         WHEN rk <= 150 THEN 5.0
         WHEN rk <= 350 THEN 2.0
         WHEN rk <= 700 THEN 0.7
         ELSE 0.15                    -- bottom 30% slow
    END AS volume_mult
  FROM ranked
)
SELECT s.SALE_ID, s.PRODUCT_ID, s.STORE_ID, s.SALE_DATE,
  ROUND(s.QUANTITY * t.volume_mult * (50 + ABS(HASH(s.SALE_ID,'qj'))%101)/100.0)::NUMBER AS QUANTITY,
  s.UNIT_PRICE, s.DISCOUNT_PCT,
  (ROUND(s.QUANTITY * t.volume_mult * (50 + ABS(HASH(s.SALE_ID,'qj'))%101)/100.0) * s.UNIT_PRICE * (1 - s.DISCOUNT_PCT/100.0))::FLOAT AS REVENUE,
  s.LOADED_AT
FROM SALES s JOIN tiered t ON s.PRODUCT_ID = t.PRODUCT_ID;
