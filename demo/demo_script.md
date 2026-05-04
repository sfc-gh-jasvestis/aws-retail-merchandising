# Demo Script: Merchandising & Pricing — "The Executive Dashboard"
## 3.5-Minute Recorded Walkthrough
**Format**: Screen recording with voiceover
**Target**: Customer meeting / booth loop / social share
**Pre-requisites**: Data loaded, Streamlit deployed, QuickSight dashboard published

---

## The Story

A regional grocery retailer operates 50 stores across APJ — supermarkets, express formats, hypermarkets, and online. Margins are compressing. FairPrice and Cold Storage are undercutting on key SKUs. The Category Manager needs to pinpoint which products are losing money and why. The VP Merchandising needs to know which promotions to kill and which to double down on — without opening a spreadsheet.

Two personas. One data platform. The Category Manager explores a Plotly treemap in Streamlit. The VP opens QuickSight and asks Amazon Q "Which promotions had negative ROI?" Same governed Snowflake data, two consumption experiences.

---

## Two Personas

| Persona | Role | Tool | What they care about |
|---|---|---|---|
| **Category Manager** | Day-to-day pricing & assortment | Streamlit in Snowflake (multi-page) | Margin treemap, promotion scatter plots, competitive price index, ABC assortment |
| **VP Merchandising** | Executive decisions & board reporting | Amazon QuickSight + Amazon Q | Category margin trends, promotion ROI, brand revenue ranking, NLP queries |

---

## What's Built

| Layer | Component | Detail |
|---|---|---|
| **Ingest (AWS)** | Amazon S3 | Competitor price feeds from FairPrice, Cold Storage, Giant, Sheng Siong, Amazon Fresh |
| **RAW** | 7 tables | PRODUCTS (1K), STORES (50), SALES (200K), PROMOTIONS (500), PROMO_PRODUCTS (2K), COMPETITOR_PRICES (50K), PRICING_POLICIES (50) |
| **CURATED** | 3 Dynamic Tables | PRODUCT_MARGIN_ANALYSIS (margin + competitor index), PROMOTION_EFFECTIVENESS (revenue per promo), ASSORTMENT_SCORE (ABC by store) |
| **AI** | Cortex Search | Semantic search over 50 category-specific pricing policy documents |
| **ML** | FORECAST | 14-day revenue prediction by category |
| **Consumption** | Streamlit | 4-page multi-page app with Plotly treemap, scatter, grouped bar, stacked bar |
| | QuickSight | 2-sheet dashboard (Margin Overview + Promotion ROI) + Q Topic |

**Current data**: 1,000 products | 15 brands | 8 categories | 5 competitors | 500 promotions (BOGO, percentage, bundle, loyalty, gift)

---

## Pre-Recording Checklist

- [ ] Verify Dynamic Tables: `SHOW DYNAMIC TABLES IN DATABASE RETAIL_MERCHANDISING` (all 3 ACTIVE)
- [ ] Open Streamlit: `RETAIL_MERCHANDISING.APP.MERCHANDISING_PRICING_APP`
- [ ] Test treemap: Margins page loads, treemap renders with red/green gradient
- [ ] Test Cortex Search: Competitive page, search "maximum markup for beverages" — confirm result with "45% above cost"
- [ ] Open QuickSight: https://us-west-2.quicksight.aws.amazon.com/
- [ ] Test Amazon Q: ask "Which category has the lowest average margin?"
- [ ] Audio: quiet room, external mic
- [ ] Resolution: 1920x1080

---

## Script

### [0:00–0:30] THE PROBLEM (Show: Architecture or Streamlit sidebar)

> *"A grocery retailer with 50 stores across APJ is losing margin. FairPrice, Cold Storage, Giant, Sheng Siong, and Amazon Fresh are all competing on price — and competitor pricing data flows in from S3 daily. 1,000 products, 200,000 transactions, 50,000 competitive price observations. The Category Manager needs to know: which products are we losing money on, and why? The VP needs to know: which promotions should we kill?*
>
> *Two personas, one platform. Let me show you both."*

---

### [0:30–1:10] MARGINS PAGE — Plotly Treemap (Show: Streamlit Margins page)

> *"The Category Manager opens the Margins page. This treemap shows every product — size is revenue, color is gross margin percentage. Green is healthy, red is trouble. Immediately I can see Beverages is a large category but trending orange — margins are compressing across the board. Let me click in."*

**Action**: Point to Beverages section in treemap. Note the orange/red coloring.

> *"Below the treemap, a scatter plot: each dot is a category. Beverages is high revenue but low margin — bottom right. Confectionery is the opposite — smaller but 50% margins. The Category Manager now knows exactly where to focus."*

**Action**: Point to scatter plot showing Category: Margin % vs Revenue.

> *"And the detailed table confirms it — sorted worst-to-best. Look at the bottom: Premium Lager 6pk from Tiger — low margin, price index well above 100 vs competitors. We're significantly more expensive than FairPrice on this SKU. That's the margin leak."*

---

### [1:10–1:40] PROMOTIONS PAGE — Scatter Plot (Show: Streamlit Promotions page)

> *"Navigate to Promotions. Every promotion plotted: discount percentage on X-axis, revenue generated on Y-axis, bubble size is units sold. This BOGO campaign gave away 50% margin but generated only moderate revenue — bottom right. Meanwhile, this 20% Off Selected campaign outperformed it with half the discount. The lesson: BOGO is destroying margin without proportional volume lift."*

**Action**: Point to BOGO bubbles vs PERCENTAGE bubbles in the scatter.

> *"Grouped by promotion type — BOGO campaigns collectively generated less revenue than simple percentage discounts. Data-driven decision: reduce BOGO frequency, increase targeted percentage offers."*

---

### [1:40–2:10] COMPETITIVE PAGE — Price Index + Policy Search (Show: Streamlit Competitive page)

> *"The competitive radar. Everything above the red line means we're more expensive than competitors. FairPrice undercut us on 8 Beverage products last week — by up to 15%. That's the direct cause of our margin pressure: we haven't adjusted, and volume is shifting to competitors.*
>
> *But can we adjust? Let me search the pricing policy."*

**Action**: Type "maximum markup for beverages" in the search box.

> *"Cortex Search finds the policy instantly: maximum markup is 45% above cost. We're at 42%. Only 3 points of room. The Category Manager now knows: reprice the 8 undercut SKUs to match FairPrice, absorb the 3% margin hit, and recover volume. Cortex Search just saved a 2-hour policy review."*

---

### [2:10–2:30] ASSORTMENT PAGE — ABC + Forecast (Show: Streamlit Assortment page)

> *"Assortment planning. Every product classified A through D by store. 60% of revenue comes from 15% of products — the A class. These D-class items at the bottom haven't sold a single unit in 30 days. Candidates for delisting.*
>
> *And the 14-day revenue forecast by category — Snowflake ML, no Python, no SageMaker. Beverages are predicted flat, but Confectionery is trending up 8%. Shift shelf space accordingly."*

---

### [2:30–3:00] QUICKSIGHT — VP Persona (Show: QuickSight Dashboard)

> *"Now we shift persona. The VP Merchandising opens QuickSight. Same data, executive view. Sheet 1: margin by category — immediately sees Beverages at the bottom. Sheet 2: promotion ROI by type — confirms BOGO underperformance. Clean, board-ready, no configuration needed."*

**Action**: Click through both dashboard sheets.

---

### [3:00–3:20] AMAZON Q (Show: QuickSight Q bar)

> *"And the VP's secret weapon — Amazon Q. 'Which promotions had negative ROI last quarter?' Q pulls the data and answers. No SQL. No pivot tables. Just ask."*

**Action**: Type the question in the Q bar. Wait for response.

---

### [3:20–3:30] CLOSE

> *"One platform. Two personas. The Category Manager knows which 8 SKUs to reprice and which D-class products to delist. The VP knows BOGO is destroying margin. No data copies, no Excel exports, no waiting for the analyst. Snowflake for the foundation. Amazon Q for the conversation. Merchandising intelligence at scale."*

---

## Key Demo Questions to Anticipate

1. **"How often does competitor pricing update?"**
   → S3 feeds ingest daily. Dynamic Tables refresh every 5 minutes. Price index is always within 24 hours of market.

2. **"Can this connect to our existing POS system?"**
   → Yes. Snowpipe for real-time, S3 for batch, Kafka connector for streaming POS data. Same Dynamic Table pipeline handles all.

3. **"How do you handle private label vs branded pricing differently?"**
   → Pricing policies in Cortex Search are category-specific. Policy POL-006 explicitly states "private label must be priced 20-30% below branded equivalent."

4. **"What about seasonal pricing?"**
   → ML FORECAST captures seasonal patterns automatically. Category Manager can see predicted spikes and adjust assortment in advance.

5. **"Why Plotly treemap instead of standard charts?"**
   → 1,000 products across 8 categories and 15 brands — a bar chart can't show that hierarchy. The treemap lets you drill from category to brand to product in one visual.
