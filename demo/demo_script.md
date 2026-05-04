# Demo Script: Merchandising & Pricing
## 3.5-Minute Recorded Walkthrough — Dual Persona
**Format**: Screen recording with voiceover
**App**: Multi-page Streamlit with Plotly treemap + QuickSight+Q

---

## The Story

A retail chain across APJ is losing margin. Competitor pricing data flows in from S3 daily. The Category Manager investigates in Streamlit — drilling from treemap to individual products. The VP Merchandising opens QuickSight and asks Amazon Q "Which promotions had negative ROI?" Same data, two experiences.

---

## Two Personas

| Persona | Tool | What they see |
|---|---|---|
| **Category Manager** | Streamlit (multi-page) | Plotly treemap, promotion scatter, competitive radar, assortment ABC |
| **VP Merchandising** | QuickSight + Amazon Q | Margin by category, revenue by brand, promo ROI, NLP queries |

---

## Script

### [0:00–0:30] PROBLEM + ARCHITECTURE

> "Two personas, one platform. The Category Manager digs into margins in Streamlit. The VP asks Amazon Q 'Which promos actually worked?' Same governed Snowflake data, two consumption layers. Competitor pricing flows in from S3 daily."

### [0:30–1:00] MARGINS PAGE — Plotly Treemap

**Show**: Margins page, treemap loads

> "This is the treemap. Size is revenue, color is margin percentage. Red means low margin. I can see Beverages is a big category but trending orange — margins are compressing. Let me click in."

**Action**: Click into Beverages category in treemap

### [1:00–1:30] PROMOTIONS PAGE — Scatter Plot

**Show**: Navigate to Promotions page

> "Here's every promotion plotted: discount percentage on X, revenue on Y, sized by units sold. This BOGO campaign — 50% discount but only moderate revenue. The 20% Off Selected outperformed it with less discount. Better ROI."

### [1:30–2:00] COMPETITIVE PAGE — Price Index

**Show**: Navigate to Competitive page

> "Competitor price index. Anything above the red line means we're more expensive. FairPrice undercut us on 8 products last week. That explains the Beverage margin pressure."

**Action**: Search pricing policies: "maximum markup for beverages"

> "Policy says max 45% markup. We're at 42%. Not much room."

### [2:00–2:15] ASSORTMENT PAGE — ABC + Forecast

**Show**: Navigate to Assortment page

> "ABC classification by store. 60% of revenue from 15% of products. These D-class items haven't sold in 30 days — candidates for delisting. And here's the 14-day revenue forecast by category."

### [2:15–2:45] QUICKSIGHT — VP Persona

**Show**: Switch to QuickSight dashboard

> "Now the VP opens their dashboard. Same data, executive view. Margin by category, revenue by brand — clean, board-ready."

### [2:45–3:15] AMAZON Q

**Show**: Open Amazon Q, type query

> "Which promotions had negative ROI last quarter?"

**Action**: Wait for Q response

> "Q pulls the data and answers. No SQL, no pivot tables. Just ask."

### [3:15–3:30] CLOSE

> "One platform. Two personas. The Category Manager knows which SKUs to reprice. The VP knows which promotions to kill. No data copies."
