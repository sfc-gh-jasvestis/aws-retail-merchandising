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
- [ ] Clear Amazon Q history: click "+" (New conversation) in Q panel before recording
- [ ] Test Amazon Q: ask "Which category has the lowest average gross margin?"
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

> *"The Category Manager opens the Margins page. This treemap shows every product — size is revenue, color is gross margin percentage. Green is healthy, red is trouble. Immediately I can see Fresh and Beverages are red — margins under 25%. Confectionery and Snacks are green — healthy margins above 50%. Let me scroll down."*

**Action**: Point to Fresh and Beverages sections in treemap. Note the red coloring vs green Confectionery.

> *"Below the treemap, a scatter plot: each dot is a category. Fresh sits at the far left — only 19% margins. Beverages is next at 25%. Confectionery is on the right — 58% margins with strong revenue. The Category Manager now knows exactly where to focus."*

**Action**: Point to scatter plot showing Category: Margin % vs Revenue.

> *"And the detailed table confirms it — sorted worst-to-best. The bottom rows are all Fresh and Beverages products with margins in the teens and low twenties. Notice the price index column — values above 100 mean we're more expensive than competitors. Wagyu Beef Strips at 113, Avocado Oil at 55 — these are the margin leaks. The Category Manager can now take action on the worst offenders."*

---

### [1:10–1:40] PROMOTIONS PAGE — Scatter Plot (Show: Streamlit Promotions page)

> *"Navigate to Promotions. Every promotion plotted: discount percentage on X-axis, revenue generated on Y-axis, bubble size is units sold. This BOGO campaign gave away 50% margin but generated only moderate revenue — bottom right. Meanwhile, this 20% Off Selected campaign outperformed it with half the discount. The lesson: BOGO is destroying margin without proportional volume lift."*

**Action**: Point to BOGO bubbles vs PERCENTAGE bubbles in the scatter.

> *"Grouped by promotion type — BOGO campaigns collectively generated less revenue than simple percentage discounts. Data-driven decision: reduce BOGO frequency, increase targeted percentage offers."*

---

### [1:40–2:10] COMPETITIVE PAGE — Price Index + Policy Search (Show: Streamlit Competitive page)

> *"The competitive radar. Everything above the red line means we're more expensive than competitors. We're priced above parity on dozens of products — some by nearly 3x. That's a risk: competitors are offering the same products for less, and volume could shift.*
>
> *But can we adjust? Let me search the pricing policy."*

**Action**: Type "maximum markup for beverages" in the search box.

> *"Cortex Search finds the policy instantly: maximum markup is 45% above cost for Beverages. Our actual average markup is 34%. Some room to move — but the constraint is clear. The Category Manager now knows the policy boundary before adjusting any prices. Cortex Search just saved a 2-hour policy review."*

---

### [2:10–2:30] ASSORTMENT PAGE — ABC + Forecast (Show: Streamlit Assortment page)

> *"Assortment planning. Every product with sales in the last 30 days, classified A through C by store. A-class products are the stars — highest revenue per store. C-class is the long tail. The Category Manager can spot which stores have a thin A-class and need assortment changes.*
>
> *And the 14-day revenue forecast by category — Snowflake ML, no Python, no SageMaker. Beverages are predicted flat, but Dairy is trending up 9% and Fresh up 14%. Shift shelf space accordingly."*

---

### [2:30–3:00] QUICKSIGHT — VP Persona (Show: QuickSight Dashboard)

> *"Now we shift persona. The VP Merchandising opens QuickSight. Same data, executive view. Sheet 1: margin by category — immediately sees Beverages at the bottom. Sheet 2: promotion ROI by type — confirms BOGO underperformance. Clean, board-ready, no configuration needed."*

**Action**: Click through both dashboard sheets.

---

### [3:00–3:20] AMAZON Q (Show: QuickSight Q bar)

> *"And the VP's secret weapon — Amazon Q. 'Which category has the lowest average gross margin?' Q pulls the data and answers instantly: Fresh at 19.3%, Beverages at 25.4%. The VP glances at the Promotion ROI sheet — BOGO is the weakest performer at $3.2 million. Two insights, two sheets, one conversation. No SQL. No pivot tables. Just ask."*

**Action**: Type "Which category has the lowest average gross margin?" in the Q bar. Wait for response.

---

### [3:20–3:30] CLOSE

> *"One platform. Two personas. The Category Manager knows which overpriced SKUs to adjust and which tail products to review. The VP knows BOGO is destroying margin. No data copies, no Excel exports, no waiting for the analyst. Snowflake for the foundation. Amazon Q for the conversation. Merchandising intelligence at scale."*

---

## Key Demo Questions to Anticipate

1. **"How often does competitor pricing update?"**
   → S3 feeds ingest daily. Dynamic Tables refresh every 5 minutes. Price index is always within 24 hours of market.

2. **"Can this connect to our existing POS system?"**
   → Yes. Snowpipe for real-time, S3 for batch, Kafka connector for streaming POS data. Same Dynamic Table pipeline handles all.

3. **"How do you handle private label vs branded pricing differently?"**
   → Pricing policies in Cortex Search are category-specific. Policy POL-005 explicitly states "private label must be priced 20-30% below branded equivalent."

4. **"What about seasonal pricing?"**
   → ML FORECAST captures seasonal patterns automatically. Category Manager can see predicted spikes and adjust assortment in advance.

5. **"Why Plotly treemap instead of standard charts?"**
   → 1,000 products across 8 categories and 15 brands — a bar chart can't show that hierarchy. The treemap lets you drill from category to brand to product in one visual.
