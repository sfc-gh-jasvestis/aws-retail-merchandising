import streamlit as st
import pandas as pd
import json
import plotly.express as px
import plotly.graph_objects as go
from snowflake.snowpark.context import get_active_session

session = get_active_session()

NUMERIC_COLS_MARGIN = ["GROSS_MARGIN_PCT", "TOTAL_REVENUE", "BASE_PRICE", "COST", "PRICE_INDEX_VS_COMPETITOR"]
NUMERIC_COLS_PROMO = ["DISCOUNT_PCT", "PRODUCTS_IN_PROMO", "PROMO_UNITS_SOLD", "PROMO_REVENUE", "REVENUE_PER_PRODUCT"]
NUMERIC_COLS_COMP = ["BASE_PRICE", "COMPETITOR_PRICE", "PRICE_INDEX"]
NUMERIC_COLS_ABC = ["PRODUCT_COUNT", "REVENUE_30D"]
NUMERIC_COLS_FORECAST = ["FORECAST_REVENUE"]

def ensure_float(df, cols):
    for col in cols:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col].astype(str), errors="coerce")
    return df

st.set_page_config(page_title="Merchandising & Pricing", layout="wide", page_icon="🏷️")

page = st.sidebar.radio("Navigation", ["Margins", "Promotions", "Competitive", "Assortment"], label_visibility="collapsed")

st.sidebar.divider()
st.sidebar.markdown("### Merchandising & Pricing")
st.sidebar.caption("Multi-page app — Plotly visualizations")
st.sidebar.caption("AWS: S3 competitor feeds + QuickSight+Q")
st.sidebar.divider()
category_filter = st.sidebar.multiselect("Category", ["Beverages", "Dairy", "Pantry", "Confectionery", "Fresh", "Frozen", "Health & Wellness", "Snacks"])
cat_clause = "','".join(category_filter) if category_filter else ""
cat_sql = f"WHERE CATEGORY IN ('{cat_clause}')" if category_filter else ""

if page == "Margins":
    st.title("Margin Analysis")
    st.caption("Interactive treemap: size = revenue, color = gross margin %")

    margin_df = session.sql(f"""
        SELECT PRODUCT_NAME, BRAND, CATEGORY, SUB_CATEGORY,
               GROSS_MARGIN_PCT::FLOAT AS GROSS_MARGIN_PCT,
               TOTAL_REVENUE::FLOAT AS TOTAL_REVENUE,
               BASE_PRICE::FLOAT AS BASE_PRICE,
               COST::FLOAT AS COST,
               PRICE_INDEX_VS_COMPETITOR::FLOAT AS PRICE_INDEX_VS_COMPETITOR
        FROM RETAIL_MERCHANDISING.CURATED.PRODUCT_MARGIN_ANALYSIS
        {cat_sql}
        ORDER BY TOTAL_REVENUE DESC
        LIMIT 200
    """).to_pandas()
    margin_df = ensure_float(margin_df, NUMERIC_COLS_MARGIN)

    if not margin_df.empty:
        positive = margin_df[margin_df["TOTAL_REVENUE"] > 0].copy()

        if not positive.empty:
            positive["_hover"] = positive.apply(
                lambda r: f"<b>{r['PRODUCT_NAME']}</b><br>Brand: {r['BRAND']}<br>Revenue: ${r['TOTAL_REVENUE']:,.0f}<br>Gross Margin: {r['GROSS_MARGIN_PCT']:.1f}%",
                axis=1
            )
            try:
                fig = px.treemap(
                    positive,
                    path=["CATEGORY", "BRAND", "PRODUCT_NAME"],
                    values="TOTAL_REVENUE",
                    color="GROSS_MARGIN_PCT",
                    color_continuous_scale="RdYlGn",
                    color_continuous_midpoint=40,
                    range_color=[0, 80],
                    title="Product Margin Treemap (size=revenue, color=margin%)"
                )
                hover_map = dict(zip(positive["PRODUCT_NAME"], positive["_hover"]))
                texts = []
                for label, parent in zip(fig.data[0].labels, fig.data[0].parents):
                    if label in hover_map:
                        texts.append(hover_map[label])
                    else:
                        texts.append(f"<b>{label}</b>")
                fig.data[0].hovertext = texts
                fig.data[0].hoverinfo = "text"
                fig.data[0].hovertemplate = None
                fig.update_layout(height=500, margin=dict(t=40, l=10, r=10, b=10))
                st.plotly_chart(fig, use_container_width=True)
            except Exception as e:
                st.error(f"Treemap error: {e}")

        st.divider()
        c1, c2, c3, c4 = st.columns(4)
        c1.metric("Avg Margin", f"{margin_df['GROSS_MARGIN_PCT'].mean():.1f}%")
        c2.metric("Total Revenue", f"${margin_df['TOTAL_REVENUE'].sum():,.0f}")
        c3.metric("Products", f"{len(margin_df)}")
        c4.metric("Avg Price Index", f"{margin_df['PRICE_INDEX_VS_COMPETITOR'].dropna().mean():.0f}%")

        st.divider()
        st.subheader("Margin by Category")
        cat_margin = margin_df.groupby("CATEGORY").agg({"GROSS_MARGIN_PCT": "mean", "TOTAL_REVENUE": "sum"}).reset_index()
        try:
            fig2 = px.scatter(cat_margin, x="GROSS_MARGIN_PCT", y="TOTAL_REVENUE", text="CATEGORY", size="TOTAL_REVENUE",
                             title="Category: Margin % vs Revenue")
            fig2.update_traces(textposition="top center")
            fig2.update_layout(height=400)
            st.plotly_chart(fig2, use_container_width=True)
        except Exception as e:
            st.error(f"Scatter chart error: {e}")

        st.divider()
        st.subheader("Detailed Product Margins")
        st.dataframe(margin_df[["PRODUCT_NAME", "BRAND", "CATEGORY", "BASE_PRICE", "COST", "GROSS_MARGIN_PCT", "TOTAL_REVENUE", "PRICE_INDEX_VS_COMPETITOR"]].sort_values("GROSS_MARGIN_PCT", ascending=True).head(30), use_container_width=True)

elif page == "Promotions":
    st.title("Promotion Effectiveness")
    st.caption("Select a promotion to see performance metrics")

    promo_df = session.sql("""
        SELECT PROMO_NAME, PROMO_TYPE,
               DISCOUNT_PCT::FLOAT AS DISCOUNT_PCT,
               PRODUCTS_IN_PROMO::FLOAT AS PRODUCTS_IN_PROMO,
               PROMO_UNITS_SOLD::FLOAT AS PROMO_UNITS_SOLD,
               PROMO_REVENUE::FLOAT AS PROMO_REVENUE,
               REVENUE_PER_PRODUCT::FLOAT AS REVENUE_PER_PRODUCT,
               START_DATE, END_DATE
        FROM RETAIL_MERCHANDISING.CURATED.PROMOTION_EFFECTIVENESS
        WHERE PROMO_REVENUE > 0
        ORDER BY PROMO_REVENUE DESC LIMIT 50
    """).to_pandas()
    promo_df = ensure_float(promo_df, NUMERIC_COLS_PROMO)

    if not promo_df.empty:
        try:
            fig = px.scatter(promo_df, x="DISCOUNT_PCT", y="PROMO_REVENUE", color="PROMO_TYPE",
                            size="PROMO_UNITS_SOLD", hover_name="PROMO_NAME",
                            title="Promotion: Discount % vs Revenue (size = units sold)")
            fig.update_layout(height=450)
            st.plotly_chart(fig, use_container_width=True)
        except Exception as e:
            st.error(f"Promotion scatter error: {e}")

        st.divider()
        st.subheader("By Promotion Type")
        type_agg = promo_df.groupby("PROMO_TYPE").agg({"PROMO_REVENUE": "sum", "PROMO_UNITS_SOLD": "sum"}).reset_index()
        try:
            fig2 = px.bar(type_agg, x="PROMO_TYPE", y="PROMO_REVENUE", color="PROMO_TYPE", title="Revenue by Promotion Type")
            st.plotly_chart(fig2, use_container_width=True)
        except Exception as e:
            st.error(f"Bar chart error: {e}")

        st.divider()
        st.subheader("All Promotions")
        st.dataframe(promo_df, use_container_width=True)

elif page == "Competitive":
    st.title("Competitive Pricing Radar")
    st.caption("Price index vs competitors + policy search")

    comp_df = session.sql(f"""
        SELECT p.CATEGORY, p.BRAND, p.NAME AS PRODUCT_NAME,
               p.BASE_PRICE::FLOAT AS BASE_PRICE,
               cp.COMPETITOR,
               cp.PRICE::FLOAT AS COMPETITOR_PRICE,
               ROUND(p.BASE_PRICE / NULLIF(cp.PRICE, 0) * 100, 1)::FLOAT AS PRICE_INDEX
        FROM RETAIL_MERCHANDISING.RAW.PRODUCTS p
        JOIN RETAIL_MERCHANDISING.RAW.COMPETITOR_PRICES cp ON p.PRODUCT_ID = cp.PRODUCT_ID
        WHERE cp.OBSERVED_DATE >= DATEADD('day', -7, CURRENT_DATE())
          AND p.BASE_PRICE / NULLIF(cp.PRICE, 0) BETWEEN 0.3 AND 3.0
          {"AND p.CATEGORY IN ('" + cat_clause + "')" if category_filter else ''}
        ORDER BY PRICE_INDEX DESC
        LIMIT 100
    """).to_pandas()
    comp_df = ensure_float(comp_df, NUMERIC_COLS_COMP)

    if not comp_df.empty:
        try:
            fig = px.bar(comp_df.head(30), x="PRODUCT_NAME", y="PRICE_INDEX", color="COMPETITOR",
                        title="Price Index vs Competitors (100 = parity, >100 = we're more expensive)",
                        barmode="group")
            fig.add_hline(y=100, line_dash="dash", line_color="red", annotation_text="Parity")
            fig.update_layout(height=450, xaxis_tickangle=-45)
            st.plotly_chart(fig, use_container_width=True)
        except Exception as e:
            st.error(f"Competitive chart error: {e}")

    st.divider()
    st.subheader("Pricing Policy Search")
    search_q = st.text_input("Search pricing policies:", placeholder="e.g., maximum markup for beverages")
    if search_q:
        try:
            safe_q = search_q.replace('"', '\\"').replace("'", "''")
            raw = session.sql(f"""
                SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                    'RETAIL_MERCHANDISING.SEARCH.PRICING_POLICY_SEARCH',
                    '{{"query": "{safe_q}", "columns": ["POLICY_TEXT", "CATEGORY"], "limit": 3}}'
                ) AS RESULTS
            """).collect()[0][0]
            results = json.loads(raw) if isinstance(raw, str) else raw
            hits = results.get("results", [])
            for hit in hits:
                st.info(f"**{hit.get('CATEGORY', '')}**: {hit.get('POLICY_TEXT', '')[:400]}")
        except Exception as e:
            st.error(f"Search error: {e}")

elif page == "Assortment":
    st.title("Assortment Planner")
    st.caption("ABC classification by store — sell-through performance")

    abc_df = session.sql(f"""
        SELECT STORE_NAME, REGION, ABC_CLASS,
               COUNT(*)::FLOAT AS PRODUCT_COUNT,
               SUM(REVENUE_30D)::FLOAT AS REVENUE_30D
        FROM RETAIL_MERCHANDISING.CURATED.ASSORTMENT_SCORE
        WHERE REVENUE_30D > 0
          {"AND CATEGORY IN ('" + cat_clause + "')" if category_filter else ''}
        GROUP BY STORE_NAME, REGION, ABC_CLASS
        ORDER BY STORE_NAME, ABC_CLASS
    """).to_pandas()
    abc_df = ensure_float(abc_df, NUMERIC_COLS_ABC)

    if not abc_df.empty:
        try:
            fig = px.bar(abc_df, x="STORE_NAME", y="PRODUCT_COUNT", color="ABC_CLASS",
                        title="Product ABC Classification by Store",
                        color_discrete_map={"A": "#2ecc71", "B": "#f39c12", "C": "#e74c3c", "D": "#95a5a6"},
                        barmode="stack")
            fig.update_layout(height=450, xaxis_tickangle=-45)
            st.plotly_chart(fig, use_container_width=True)
        except Exception as e:
            st.error(f"ABC chart error: {e}")

        st.divider()
        c1, c2, c3, c4 = st.columns(4)
        a_count = abc_df[abc_df["ABC_CLASS"] == "A"]["PRODUCT_COUNT"].sum()
        b_count = abc_df[abc_df["ABC_CLASS"] == "B"]["PRODUCT_COUNT"].sum()
        c_count = abc_df[abc_df["ABC_CLASS"] == "C"]["PRODUCT_COUNT"].sum()
        d_count = abc_df[abc_df["ABC_CLASS"] == "D"]["PRODUCT_COUNT"].sum()
        c1.metric("A (Star)", f"{a_count:,.0f}")
        c2.metric("B (Core)", f"{b_count:,.0f}")
        c3.metric("C (Tail)", f"{c_count:,.0f}")
        c4.metric("D (Dead)", f"{d_count:,.0f}")

        st.divider()
        st.subheader("Revenue Forecast by Category")
        try:
            forecast_df = session.sql("""
                SELECT SERIES AS CATEGORY, TS AS FORECAST_DATE,
                       FORECAST::FLOAT AS FORECAST_REVENUE
                FROM RETAIL_MERCHANDISING.ML.CATEGORY_FORECAST_RESULTS
                ORDER BY SERIES, TS
            """).to_pandas()
            forecast_df = ensure_float(forecast_df, NUMERIC_COLS_FORECAST)
            forecast_df["CATEGORY"] = forecast_df["CATEGORY"].astype(str).str.strip('"')
            if not forecast_df.empty:
                fig2 = px.line(forecast_df, x="FORECAST_DATE", y="FORECAST_REVENUE", color="CATEGORY",
                              title="14-Day Revenue Forecast by Category")
                fig2.update_layout(height=400)
                st.plotly_chart(fig2, use_container_width=True)
        except Exception as e:
            st.error(f"Forecast chart error: {e}")
