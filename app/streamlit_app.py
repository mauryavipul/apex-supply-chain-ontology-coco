import streamlit as st
import pandas as pd
import json
import altair as alt
from snowflake.snowpark.context import get_active_session
_rerun = getattr(st, "rerun", None) or st.experimental_rerun

# Set Streamlit page config
st.set_page_config(
    page_title="Apex Supply Chain Control Tower",
    page_icon="🏭",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom Injected CSS (Card styling & whitelisted status pills)
st.markdown("""
<style>
/* Card-style metric tiles */
div[data-testid="stMetric"], div[data-testid="metric-container"] {
    background-color: rgba(128, 128, 128, 0.06);
    border: 1px solid rgba(128, 128, 128, 0.25);
    border-radius: 10px;
    padding: 12px 16px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}

/* Status pills */
.status-pill {
    display: inline-block;
    padding: 3px 10px;
    border-radius: 12px;
    font-size: 0.82rem;
    font-weight: 600;
    line-height: 1.3;
    text-align: center;
}
.status-pill-aligned {
    background-color: #DEF7EC;
    color: #03543F;
    border: 1px solid #31C48D;
}
.status-pill-drift {
    background-color: #FDE8E8;
    color: #9B1C1C;
    border: 1px solid #F98080;
}
.status-pill-illustrative {
    background-color: #FEF08A;
    color: #713F12;
    border: 1px solid #FACC15;
}
.status-pill-unknown {
    background-color: #F3F4F6;
    color: #374151;
    border: 1px solid #D1D5DB;
}
</style>
""", unsafe_allow_html=True)

def render_status_pill(status_key: str) -> str:
    """Return a sanitized HTML status pill for fixed whitelisted status keys only."""
    k = str(status_key).strip().upper()
    if k in ("ALIGNED", "HEALTHY", "OK"):
        return '<span class="status-pill status-pill-aligned">● ALIGNED</span>'
    elif k in ("DRIFT", "DRIFT_DETECTED", "WARNING", "CRITICAL"):
        return '<span class="status-pill status-pill-drift">▲ DRIFT</span>'
    elif k in ("ILLUSTRATIVE", "SIMULATION"):
        return '<span class="status-pill status-pill-illustrative">⚡ Illustrative</span>'
    else:
        return '<span class="status-pill status-pill-unknown">ℹ️ UNKNOWN</span>'

session = get_active_session()

# App Header
st.title("🏭 Apex Industrial Components — Supply Chain Control Tower")
st.caption("Governed Conversational Analytics & Supply Chain Ontology | Powered by Snowflake Cortex")

# Sidebar Navigation (EXACTLY 6 views)
st.sidebar.title("Control Tower Navigation")
page = st.sidebar.radio(
    "Select View:",
    [
        "🎯 1. Command Center",
        "📊 2. Monitor",
        "💬 3. Ask",
        "🛡️ 4. Govern",
        "💡 5. Decide",
        "🚨 6. Act"
    ]
)

st.sidebar.divider()
st.sidebar.info("Compute Warehouse: **HACK_WH (XSMALL)**\n\nDatabase: **SC_ONTOLOGY**\n\nRole: **ACCOUNTADMIN**")

# ==============================================================================
# VIEW 1: COMMAND CENTER
# ==============================================================================
if page == "🎯 1. Command Center":
    st.header("🎯 Supply Chain Command Center")
    st.caption("Executive overview of governance health, data freshness, active risk signals, and prescriptive recommendations.")

    # 1. Top Governance Status Line (Rule: Never claim '8/8 aligned')
    try:
        gov_health_df = session.sql("""
            SELECT STATUS, METRIC_NAME, CANONICAL_VALUE, LAST_CHECKED 
            FROM SC_ONTOLOGY.GOVERNANCE.V_GOVERNANCE_HEALTH 
            ORDER BY LAST_CHECKED DESC 
            LIMIT 1
        """).to_pandas()
        reg_cnt_df = session.sql("SELECT COUNT(*) AS CNT FROM SC_ONTOLOGY.GOVERNANCE.METRIC_REGISTRY WHERE IS_ACTIVE = TRUE").to_pandas()
        total_gov_metrics = int(reg_cnt_df.iloc[0]["CNT"]) if not reg_cnt_df.empty else 8
        gov_status = gov_health_df.iloc[0]["STATUS"] if not gov_health_df.empty else "ALIGNED"
        pill_html = render_status_pill(gov_status)
        st.info(f"🛡️ **Governance Status**: **{total_gov_metrics} metrics governed · 1 drift-monitored (Outbound OTD, Q3 2026 order cohort) · {gov_status}**")
    except Exception as e:
        st.warning(f"Governance status check: {str(e)}")

    st.markdown("---")

    # 2. Key Operational Metrics Summary Cards
    c1, c2, c3, c4 = st.columns(4)
    with c1:
        act_cnt_df = session.sql("SELECT COUNT(*) AS CNT FROM SC_ONTOLOGY.APP.ACTIONS WHERE STATUS = 'OPEN_PENDING_REVIEW'").to_pandas()
        open_actions = int(act_cnt_df.iloc[0]["CNT"]) if not act_cnt_df.empty else 0
        st.metric("Open Action Items", f"{open_actions}", "Awaiting Review", delta_color="inverse")
    with c2:
        rec_cnt_df = session.sql("SELECT COUNT(*) AS CNT FROM SC_ONTOLOGY.APP.RECOMMENDATIONS WHERE STATUS = 'PROPOSED'").to_pandas()
        proposed_recs = int(rec_cnt_df.iloc[0]["CNT"]) if not rec_cnt_df.empty else 0
        st.metric("Proposed Recommendations", f"{proposed_recs}", "Prescriptive Engine")
    with c3:
        net_otd_df = session.sql("""
            SELECT ROUND(100.0 * COUNT_IF(IS_DELIVERED AND IS_ON_TIME_OUTBOUND) / NULLIF(COUNT_IF(IS_DELIVERED), 0), 2) AS OTD_PCT
            FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS
        """).to_pandas()
        net_otd = float(net_otd_df.iloc[0]["OTD_PCT"]) if not net_otd_df.empty else 66.12
        st.metric("Network Outbound OTD", f"{net_otd}%", "12-Month History Window")
    with c4:
        q3_otd_df = session.sql("""
            SELECT ROUND(100.0 * COUNT_IF(s.IS_DELIVERED AND s.IS_ON_TIME_OUTBOUND) / NULLIF(COUNT_IF(s.IS_DELIVERED), 0), 2) AS OTD_PCT
            FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS s
            JOIN SC_ONTOLOGY.CURATED.DIM_DATE d ON s.ORDER_DATE_KEY = d.DATE_KEY
            WHERE d.QUARTER_YEAR = 'Q3 2026'
        """).to_pandas()
        q3_otd = float(q3_otd_df.iloc[0]["OTD_PCT"]) if not q3_otd_df.empty else 64.12
        st.metric("Q3 2026 Cohort OTD", f"{q3_otd}%", "Governed Benchmark")

    st.markdown("---")

    col_left, col_right = st.columns([3, 2])

    with col_left:
        # Dynamic Risk Priority Breakdown
        prio_df = session.sql("""
            SELECT PRIORITY, COUNT(*) AS CNT 
            FROM SC_ONTOLOGY.APP.V_RISK_SIGNALS 
            GROUP BY PRIORITY 
            ORDER BY CNT DESC
        """).to_pandas()
        prio_summary = " · ".join([f"{r['PRIORITY']}: {r['CNT']}" for _, r in prio_df.iterrows()]) if not prio_df.empty else "Low: 38"
        
        st.subheader("⚠️ Top 5 Risk Signals (Ranked by Risk Score)")
        st.caption(f"Evaluated over 12-month history (Priority distribution: **{prio_summary}** on absolute 0–100 scale).")
        
        top_risks_df = session.sql("""
            SELECT 
                ENTITY_TYPE,
                ENTITY_ID,
                ENTITY_NAME,
                TOTAL_EVENTS,
                LATE_RATE_RAW_PCT AS "LATE_RATE_%",
                NORM_LEAD_TIME_VOLATILITY AS "VOLATILITY_SCORE",
                NORM_SLA_BREACH_RATE AS "SLA_BREACH_%",
                NORM_STOCKOUT_RISK AS "STOCKOUT_RISK_%",
                RISK_SCORE,
                PRIORITY,
                PENALTY_EXPOSURE_USD_EST AS "EST_PENALTY_USD"
            FROM SC_ONTOLOGY.APP.V_RISK_SIGNALS
            ORDER BY RISK_SCORE DESC
            LIMIT 10
        """).to_pandas()
        st.dataframe(top_risks_df.head(5), use_container_width=True)

        if not top_risks_df.empty:
            chart_df = top_risks_df.copy()
            chart_df["ENTITY_LABEL"] = chart_df["ENTITY_NAME"] + " (" + chart_df["ENTITY_ID"] + ")"
            
            bars = alt.Chart(chart_df).mark_bar(color="#29B5E8").encode(
                x=alt.X("RISK_SCORE:Q", scale=alt.Scale(domain=[0, 100]), title="Risk Score (0–100 Scale)"),
                y=alt.Y("ENTITY_LABEL:N", sort="-x", title=None),
                tooltip=[
                    alt.Tooltip("ENTITY_ID:N", title="Entity ID"),
                    alt.Tooltip("ENTITY_NAME:N", title="Entity Name"),
                    alt.Tooltip("ENTITY_TYPE:N", title="Entity Type"),
                    alt.Tooltip("RISK_SCORE:Q", title="Risk Score", format=".2f"),
                    alt.Tooltip("PRIORITY:N", title="Priority")
                ]
            )
            
            rule_df = pd.DataFrame({"threshold": [40], "label": ["Low band < 40"]})
            rule = alt.Chart(rule_df).mark_rule(strokeDash=[4, 4], color="#6B7280", strokeWidth=1.5).encode(
                x="threshold:Q"
            )
            rule_text = alt.Chart(rule_df).mark_text(
                align="left",
                baseline="bottom",
                dx=5,
                dy=-5,
                color="#6B7280",
                fontSize=11,
                fontWeight="bold"
            ).encode(
                x="threshold:Q",
                text="label:N"
            )
            
            st.altair_chart((bars + rule + rule_text).properties(
                title="Top 10 Risk Exposure Signals",
                height=280
            ), use_container_width=True)

    with col_right:
        st.subheader("💡 Proposed Recommendations by Issue")
        st.caption("Active candidate breakdown from prescriptive rules.")
        rec_by_issue_df = session.sql("""
            SELECT 
                ISSUE_TYPE,
                COUNT(*) AS CANDIDATE_COUNT,
                MIN(OWNER_ROLE) AS PRIMARY_OWNER
            FROM SC_ONTOLOGY.APP.RECOMMENDATIONS
            WHERE STATUS = 'PROPOSED'
            GROUP BY ISSUE_TYPE
            ORDER BY CANDIDATE_COUNT DESC
        """).to_pandas()
        st.dataframe(rec_by_issue_df, use_container_width=True)

    st.markdown("---")
    st.subheader("📦 Curated Data Layer Freshness")
    st.caption("Metadata audit of Curated storage footprint and latest data date from `SC_ONTOLOGY.GOVERNANCE.V_DATA_FRESHNESS`.")
    fresh_df = session.sql("""
        SELECT 
            TABLE_NAME,
            ROW_COUNT,
            SIZE_KB,
            LAST_REFRESH_TIME,
            LATEST_DATA_DATE
        FROM SC_ONTOLOGY.GOVERNANCE.V_DATA_FRESHNESS
        ORDER BY ROW_COUNT DESC
        LIMIT 6
    """).to_pandas()
    st.dataframe(fresh_df, use_container_width=True)

# ==============================================================================
# VIEW 2: MONITOR (TABS: Executive KPIs, Before vs After)
# ==============================================================================
elif page == "📊 2. Monitor":
    st.header("📊 Performance Monitor")
    st.caption("Real-time operational KPIs and cross-departmental consistency analytics.")
    tab_kpi, tab_bva = st.tabs(["📊 Executive KPIs", "⚡ Before vs After Consistency"])

    with tab_kpi:
        st.subheader("📊 Executive KPI Control Tower")
        st.markdown("Real-time executive metrics across manufacturing plants, suppliers, and customer fulfillment.")

        # Filter row (Preserve prototype logic unchanged)
        col_f1, col_f2 = st.columns(2)
        with col_f1:
            plants_df = session.sql("SELECT DISTINCT PLANT_NAME FROM SC_ONTOLOGY.CURATED.DIM_PLANT ORDER BY 1").to_pandas()
            selected_plants = st.multiselect("Filter by Manufacturing Plant:", options=plants_df["PLANT_NAME"].tolist(), default=plants_df["PLANT_NAME"].tolist())
        with col_f2:
            quarters_df = session.sql("SELECT DISTINCT QUARTER_YEAR FROM SC_ONTOLOGY.CURATED.DIM_DATE ORDER BY 1").to_pandas()
            selected_quarters = st.multiselect("Filter by Order Quarter:", options=quarters_df["QUARTER_YEAR"].tolist(), default=["Q3 2026"])

        plant_filter_sql = "1=1"
        if selected_plants:
            plants_escaped = "','".join([p.replace("'", "''") for p in selected_plants])
            plant_filter_sql = f"p.PLANT_NAME IN ('{plants_escaped}')"

        quarter_filter_sql = "1=1"
        if selected_quarters:
            quarters_escaped = "','".join([q.replace("'", "''") for q in selected_quarters])
            quarter_filter_sql = f"d.QUARTER_YEAR IN ('{quarters_escaped}')"

        kpi_sql = f"""
        SELECT 
            (SELECT ROUND(100.0 * COUNT(CASE WHEN s.IS_ON_TIME_OUTBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END), 0), 2)
             FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS s
             JOIN SC_ONTOLOGY.CURATED.DIM_PLANT p ON s.PLANT_KEY = p.PLANT_KEY
             JOIN SC_ONTOLOGY.CURATED.DIM_DATE d ON s.ORDER_DATE_KEY = d.DATE_KEY
             WHERE {plant_filter_sql} AND {quarter_filter_sql}) AS OUTBOUND_OTD_PCT,
            
            (SELECT ROUND(100.0 * COUNT(CASE WHEN po.IS_ON_TIME_INBOUND = TRUE AND po.IS_IN_FULL_INBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN po.IS_DELIVERED = TRUE THEN 1 END), 0), 2)
             FROM SC_ONTOLOGY.CURATED.FACT_PURCHASE_ORDERS po
             JOIN SC_ONTOLOGY.CURATED.DIM_PLANT p ON po.PLANT_KEY = p.PLANT_KEY
             JOIN SC_ONTOLOGY.CURATED.DIM_DATE d ON po.ORDER_DATE_KEY = d.DATE_KEY
             WHERE {plant_filter_sql} AND {quarter_filter_sql}) AS INBOUND_OTIF_PCT,

            (SELECT ROUND(SUM(i.ON_HAND_QTY) / NULLIF(SUM(i.AVG_DAILY_CONSUMPTION_30D), 0), 1)
             FROM SC_ONTOLOGY.CURATED.INVENTORY_POSITION_CURRENT i
             JOIN SC_ONTOLOGY.CURATED.DIM_PLANT p ON i.PLANT_KEY = p.PLANT_KEY
             WHERE {plant_filter_sql}) AS GLOBAL_DOI_DAYS,

            (SELECT ROUND(SUM(po.EXTENDED_PURCHASE_COST_USD + po.INBOUND_FREIGHT_USD + po.DUTY_COST_USD + po.HANDLING_COST_USD) / NULLIF(SUM(po.RECEIVED_QTY), 0), 2)
             FROM SC_ONTOLOGY.CURATED.FACT_PURCHASE_ORDERS po
             JOIN SC_ONTOLOGY.CURATED.DIM_PLANT p ON po.PLANT_KEY = p.PLANT_KEY
             JOIN SC_ONTOLOGY.CURATED.DIM_DATE d ON po.ORDER_DATE_KEY = d.DATE_KEY
             WHERE {plant_filter_sql} AND {quarter_filter_sql} AND po.IS_DELIVERED = TRUE) AS AVG_LANDED_COST_USD
        """
        kpis = session.sql(kpi_sql).to_pandas().iloc[0]

        col1, col2, col3, col4 = st.columns(4)
        col1.metric("Outbound OTD (Customer)", f"{kpis['OUTBOUND_OTD_PCT']}%", "Promised Date Basis")
        col2.metric("Inbound OTIF (Suppliers)", f"{kpis['INBOUND_OTIF_PCT']}%", "Target: ≥92%", delta_color="off")
        col3.metric("Days of Inventory (DOI)", f"{kpis['GLOBAL_DOI_DAYS']} Days", "Total On-Hand / Daily Use")
        col4.metric("Avg Landed Cost / Unit", f"${kpis['AVG_LANDED_COST_USD']}", "All-in Procurement")

        st.caption("Note: Metrics dynamically reflect the selected plant and order quarter filters.")
        st.divider()

        c1, c2 = st.columns(2)
        with c1:
            st.subheader("Monthly Outbound OTD Trend by Plant")
            trend_df = session.sql(f"""
                SELECT d.YEAR_MONTH, p.PLANT_NAME, 
                       ROUND(100.0 * COUNT(CASE WHEN s.IS_ON_TIME_OUTBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS OTD_PCT
                FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS s
                JOIN SC_ONTOLOGY.CURATED.DIM_PLANT p ON s.PLANT_KEY = p.PLANT_KEY
                JOIN SC_ONTOLOGY.CURATED.DIM_DATE d ON s.ORDER_DATE_KEY = d.DATE_KEY
                WHERE {plant_filter_sql} AND {quarter_filter_sql}
                GROUP BY 1, 2 ORDER BY 1, 2
            """).to_pandas()
            if not trend_df.empty:
                trend_pivot = trend_df.pivot(index="YEAR_MONTH", columns="PLANT_NAME", values="OTD_PCT")
                st.line_chart(trend_pivot)
            else:
                st.info("No shipment trend data available for selected filter combination.")

        with c2:
            st.subheader("Inventory Valuation by Plant ($ USD)")
            inv_df = session.sql(f"""
                SELECT p.PLANT_NAME, ROUND(SUM(i.INVENTORY_VALUE_USD), 2) AS TOTAL_VALUE_USD
                FROM SC_ONTOLOGY.CURATED.INVENTORY_POSITION_CURRENT i
                JOIN SC_ONTOLOGY.CURATED.DIM_PLANT p ON i.PLANT_KEY = p.PLANT_KEY
                WHERE {plant_filter_sql}
                GROUP BY 1 ORDER BY 2 DESC
            """).to_pandas()
            if not inv_df.empty:
                inv_plot_df = inv_df.set_index("PLANT_NAME")["TOTAL_VALUE_USD"]
                st.bar_chart(inv_plot_df)

    with tab_bva:
        st.header("⚡ The Consistency Lab: Before vs After")
        st.markdown("""
        **The Problem Illustrated**: Prior to the unified supply chain ontology, Planning, Procurement, and Logistics 
        used conflicting legacy views with distinct formulas. Leadership received 3 conflicting numbers for orders placed in the same quarter.
        """)

        comp_df = session.sql("""
            SELECT 
                '1. LEGACY Planning View' AS PERSPECTIVE,
                'Plant Dispatch Date <= Promised Date (ignores customer transit time)' AS DEFINITION_RULE,
                '1,152 orders' AS VOLUME_EVALUATED,
                '83.51%' AS REPORTED_OTD,
                '❌ Ignores transit delays' AS EVALUATION
            UNION ALL
            SELECT 
                '2. LEGACY Procurement View',
                'Goods Receipt Date <= Supplier Commit Date + 3d Grace',
                '1,194 receipts',
                '96.65%',
                '❌ Lenient grace window'
            UNION ALL
            SELECT 
                '3. LEGACY Logistics View',
                'Actual POD Timestamp <= Customer Requested Date',
                '1,140 deliveries',
                '64.12%',
                '⚠️ Penalizes early customer asks'
            UNION ALL
            SELECT 
                '⭐ GOVERNED CURATED ONTOLOGY',
                'Actual Delivery Date <= Promised Delivery Date (Delivered Lines)',
                '3,420 shipment lines',
                '64.12%',
                '✅ Traceable canonical truth'
        """).to_pandas()
        st.dataframe(comp_df, use_container_width=True)

        st.info(r"""
        **Methodological Transparency & Analytical Disclosure:**
        * In the synthetic dataset, **Governed Curated Outbound OTD** (64.12%) numerically equals **Legacy Logistics** (64.12%) because on-time deliveries occurred at `order_date + 10d` (<= both requested and promised dates) and delays occurred at >= `order_date + 16d` (> both dates).
        * **Crucially, the definitions are NOT equivalent**:
          * *Legacy Logistics* evaluates against **Customer Requested Date** at the shipment header grain (731 / 1,140 = 64.12%).
          * *Governed Canonical OTD* measures contractual adherence against **Promised Delivery Date** at the delivered line grain (2,193 / 3,420 = 64.12%), preserving plant, product, and carrier lineage for orders placed in Q3 2026.
        """)

# ==============================================================================
# VIEW 3: ASK (LIVE AGENT + TRUST/PROVENANCE BADGE)
# ==============================================================================
elif page == "💬 3. Ask":
    st.header("💬 Governed Conversational Analytics (Ask Cortex)")
    st.markdown("""
    Interact with **`SC_ONTOLOGY.APP.SC_ONTOLOGY_AGENT`** using natural language or persona quick-action buttons. 
    Notice how disparate departmental phrasing routes to the **same canonical metric and verified provenance**.
    """)

    # Active Guardrails Notice
    st.caption("🛡️ **Guardrails Active**: Automatic ambiguous-metric disambiguation, out-of-scope intent refusal, read-only analytical execution, and citation of `SC_ONTOLOGY.GOVERNANCE.METRIC_REGISTRY`.")

    PERSONA_QUESTIONS = {
        "Planner": "What was our promised-date delivery performance for orders placed in Q3 2026?",
        "Procurement": "How timely were customer deliveries for orders placed in Q3 2026?",
        "Logistics": "What percentage of delivered order lines met the promised date for orders placed in Q3 2026?"
    }

    if "ask_q" not in st.session_state:
        st.session_state["ask_q"] = PERSONA_QUESTIONS["Planner"]

    col_btn1, col_btn2, col_btn3 = st.columns(3)
    if col_btn1.button("📋 Planner Persona Question"):
        st.session_state["ask_q"] = PERSONA_QUESTIONS["Planner"]
    if col_btn2.button("📦 Procurement Persona Question"):
        st.session_state["ask_q"] = PERSONA_QUESTIONS["Procurement"]
    if col_btn3.button("🚚 Logistics Persona Question"):
        st.session_state["ask_q"] = PERSONA_QUESTIONS["Logistics"]

    user_query = st.text_input("Enter a supply chain question:", key="ask_q")

    if st.button("🚀 Ask Cortex Agent", type="primary"):
        with st.spinner("Submitting query to SC_ONTOLOGY_AGENT via DATA_AGENT_RUN..."):
            agent_payload = {
                "messages": [
                    {
                        "role": "user",
                        "content": [{"type": "text", "text": user_query}]
                    }
                ],
                "tool_choice": {
                    "type": "auto",
                    "name": ["Analyst", "Search"]
                }
            }
            try:
                agent_sql = "SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN('SC_ONTOLOGY.APP.SC_ONTOLOGY_AGENT', ?, TRUE)"
                raw_response = session.sql(agent_sql, params=[json.dumps(agent_payload)]).collect()[0][0]
                resp_obj = json.loads(raw_response) if isinstance(raw_response, str) else raw_response

                st.subheader("🤖 Cortex Agent Response")
                
                warnings = resp_obj.get("warnings", []) if isinstance(resp_obj, dict) else []
                if warnings:
                    for w in warnings:
                        st.warning(f"⚠️ {w.get('message', str(w))}")

                content_blocks = []
                if isinstance(resp_obj, dict):
                    if "content" in resp_obj and isinstance(resp_obj["content"], list):
                        content_blocks = resp_obj["content"]
                    elif "choices" in resp_obj and len(resp_obj["choices"]) > 0:
                        choice_msg = resp_obj["choices"][0].get("message", {})
                        choice_content = choice_msg.get("content", "")
                        if isinstance(choice_content, list):
                            content_blocks = choice_content
                        elif isinstance(choice_content, str) and choice_content.strip():
                            content_blocks = [{"type": "text", "text": choice_content}]

                agent_texts = []
                agent_sqls = []

                for block in content_blocks:
                    if isinstance(block, dict):
                        b_type = block.get("type")
                        if b_type == "text" and "text" in block:
                            agent_texts.append(block["text"])
                        elif b_type == "tool_use" and "tool_use" in block:
                            tu = block["tool_use"]
                            tu_input = tu.get("input", {})
                            if isinstance(tu_input, dict) and "query" in tu_input:
                                agent_sqls.append((tu.get("name", "Tool"), tu_input["query"]))

                if agent_texts:
                    for t in agent_texts:
                        st.markdown(t)
                elif isinstance(resp_obj, dict) and "message" in resp_obj and isinstance(resp_obj["message"], str):
                    st.markdown(resp_obj["message"])

                if agent_sqls:
                    for tool_name, sql_code in agent_sqls:
                        with st.expander(f"🔍 View {tool_name}-Generated SQL"):
                            st.code(sql_code, language="sql")

                # Determine if question or generated SQL is about Outbound OTD
                all_sql_text = " ".join([sql for _, sql in agent_sqls]).upper()
                is_otd_query = any(k in user_query.lower() for k in [
                    "otd", "delivery", "timely", "promised", "customer deliveries", "outbound"
                ]) or ("IS_ON_TIME_OUTBOUND" in all_sql_text)

                st.divider()

                if is_otd_query:
                    # Render Provenance Badge for Outbound OTD
                    st.markdown("#### 🛡️ Metric Provenance: Outbound OTD")
                    try:
                        prov_df = session.sql("SELECT * FROM TABLE(SC_ONTOLOGY.GOVERNANCE.F_METRIC_PROVENANCE('MTR-OUTBOUND-OTD'))").to_pandas()
                        if not prov_df.empty:
                            p_row = prov_df.iloc[0]
                            st.success(f"**Verified Metric Provenance**: `{p_row['METRIC_KEY']}` ({p_row['METRIC_NAME']}) · **Confidence Tier**: {p_row['CONFIDENCE_TIER']} · **Approved By**: {p_row['APPROVED_BY']}")
                            st.markdown(f"""
                            * **Exact Governed Formula**: `{p_row['EXACT_SQL_FORMULA']}`
                            * **Evaluation Grain**: {p_row['GRAIN']} | **Owner Team**: {p_row['OWNER_TEAM']}
                            * **Primary Source Table**: `{p_row['PRIMARY_SOURCE_TABLE']}` ({p_row['PRIMARY_SOURCE_ROW_COUNT']:,} rows, refreshed {p_row['PRIMARY_SOURCE_LAST_REFRESH']})
                            * **Semantic View Lineage**: `SC_ONTOLOGY.SEMANTIC.SV_SUPPLY_CHAIN_INTELLIGENCE` $\\rightarrow$ `CURATED.FACT_OUTBOUND_SHIPMENTS`
                            """)
                    except Exception as e:
                        st.caption(f"Metric Provenance lookup: {str(e)}")
                else:
                    st.caption("ℹ️ For lineage and mathematical definitions of other canonical supply chain metrics, explore **🛡️ 4. Govern > Metric Glossary**.")

                # Deterministic Q3 OTD Parity Verification for Q3 persona questions
                is_q3_persona_query = any(q.lower() in user_query.lower() for q in [
                    PERSONA_QUESTIONS["Planner"].lower(),
                    PERSONA_QUESTIONS["Procurement"].lower(),
                    PERSONA_QUESTIONS["Logistics"].lower(),
                    "promised-date delivery performance for orders placed in q3 2026",
                    "how timely were customer deliveries for orders placed in q3 2026",
                    "percentage of delivered order lines met the promised date for orders placed in q3 2026"
                ])

                if is_q3_persona_query:
                    st.markdown("##### 📐 Deterministic Cohort Parity Check (Q3 2026 Orders)")
                    parity_sql = """
                    SELECT 
                        d.QUARTER_YEAR,
                        COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END) AS DELIVERED_LINES,
                        COUNT(CASE WHEN s.IS_ON_TIME_OUTBOUND = TRUE THEN 1 END) AS ON_TIME_LINES,
                        ROUND(100.0 * COUNT(CASE WHEN s.IS_ON_TIME_OUTBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS OUTBOUND_OTD_PCT
                    FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS s
                    JOIN SC_ONTOLOGY.CURATED.DIM_DATE d ON s.ORDER_DATE_KEY = d.DATE_KEY
                    WHERE d.QUARTER_YEAR = 'Q3 2026'
                    GROUP BY 1
                    """
                    res_df = session.sql(parity_sql).to_pandas()
                    st.info(f"**Calculated Outbound OTD (Q3 2026 Orders)**: **{res_df.iloc[0]['OUTBOUND_OTD_PCT']}%** ({res_df.iloc[0]['ON_TIME_LINES']:,} on-time / {res_df.iloc[0]['DELIVERED_LINES']:,} delivered lines)")

            except Exception as e:
                st.error(f"Execution Error: {str(e)}")

# ==============================================================================
# VIEW 4: GOVERN (TABS: Governance Health, Metric Glossary, Ontology & Lineage)
# ==============================================================================
elif page == "🛡️ 4. Govern":
    st.header("🛡️ Metric Governance & Lineage")
    st.caption("Semantic drift monitoring, canonical metric glossary, and knowledge graph architecture.")
    # Spacer gives this page's st.tabs a unique position so the selected tab doesn't carry over between pages.
    st.empty()
    tab_gov, tab_glo, tab_ont = st.tabs(["🛡️ Governance Health", "📖 Metric Glossary", "🕸️ Ontology & Lineage"])

    with tab_gov:
        st.subheader("🛡️ Metric Drift Sentinel & Governance Health")
        st.markdown("Monitors semantic drift between canonical Curated metrics and legacy department views.")

        # Display Flash Message from Session State
        if "drift_flash_msg" in st.session_state:
            st.success(st.session_state["drift_flash_msg"])
            del st.session_state["drift_flash_msg"]

        gov_health_df = session.sql("SELECT * FROM SC_ONTOLOGY.GOVERNANCE.V_GOVERNANCE_HEALTH").to_pandas()
        if not gov_health_df.empty:
            g_status = str(gov_health_df.iloc[0]["STATUS"])
            st.markdown(f"**Current Sentinel Status**: &nbsp; {render_status_pill(g_status)}", unsafe_allow_html=True)
        st.dataframe(gov_health_df, use_container_width=True)

        st.caption("Note: Running drift check evaluates consistency and writes exactly one execution record to `SC_ONTOLOGY.APP.CONSISTENCY_LOG`.")

        if st.button("🔄 Run Live Drift Check (SP_RUN_DRIFT_CHECK)"):
            with st.spinner("Executing GOVERNANCE.SP_RUN_DRIFT_CHECK()..."):
                drift_res = session.sql("CALL SC_ONTOLOGY.GOVERNANCE.SP_RUN_DRIFT_CHECK()").collect()[0][0]
                st.session_state["drift_flash_msg"] = f"Drift Check Result: {drift_res}"
                _rerun()

    with tab_glo:
        st.subheader("📖 Governed Canonical Metric Glossary")
        st.caption("Loaded dynamically from `SC_ONTOLOGY.GOVERNANCE.METRIC_REGISTRY`.")
        reg_df = session.sql("""
            SELECT 
                METRIC_KEY,
                METRIC_NAME,
                BUSINESS_DEFINITION,
                EXACT_SQL_FORMULA,
                GRAIN,
                OWNER_TEAM,
                VERIFIED_QUERY_REF,
                DEFINITION_VERSION,
                APPROVED_BY
            FROM SC_ONTOLOGY.GOVERNANCE.METRIC_REGISTRY
            WHERE IS_ACTIVE = TRUE
            ORDER BY METRIC_KEY
        """).to_pandas()
        st.dataframe(reg_df, use_container_width=True)

    with tab_ont:
        st.header("🕸️ Supply Chain Ontology & Lineage Graph")
        st.markdown("Visual architecture of core entities, relationships, hierarchies, and semantic mappings.")
        st.graphviz_chart("""
        digraph SC_ONTOLOGY {
            rankdir=LR;
            node [shape=box, style="rounded,filled", fillcolor="#E1F5FE", fontname="Helvetica"];
            edge [fontname="Helvetica", fontsize=10];

            Supplier [fillcolor="#FFF9C4", label="DIM_SUPPLIER\n(Tier-1/2/3, Country)"];
            Part [fillcolor="#FFF9C4", label="DIM_PART\n(Commodity, Std Cost USD)"];
            Plant [fillcolor="#FFF9C4", label="DIM_PLANT\n(Austin, Munich, VN, OH)"];
            Product [fillcolor="#FFF9C4", label="DIM_PRODUCT\n(SKU, Family, List Price)"];
            Customer [fillcolor="#FFF9C4", label="DIM_CUSTOMER\n(Segment, Region)"];
            Carrier [fillcolor="#FFF9C4", label="DIM_CARRIER\n(Air, Ocean, Road, Rail)"];

            PO [fillcolor="#C8E6C9", label="FACT_PURCHASE_ORDERS\n(Landed Cost, Inbound OTIF)"];
            Shipment [fillcolor="#C8E6C9", label="FACT_OUTBOUND_SHIPMENTS\n(Outbound OTD, OTIF, Freight)"];
            Inventory [fillcolor="#C8E6C9", label="INVENTORY_POSITION_CURRENT\n(Stock On Hand, DOI)"];
            BOM [fillcolor="#E1BEE7", label="BRIDGE_BOM\n(Components, Scrap %)"];

            Supplier -> PO [label="issues to"];
            Part -> PO [label="specifies"];
            Plant -> PO [label="received at"];
            Part -> BOM [label="component"];
            Product -> BOM [label="assembly"];
            Plant -> Inventory [label="stores"];
            Part -> Inventory [label="tracked"];
            Customer -> Shipment [label="delivered to"];
            Product -> Shipment [label="contains"];
            Carrier -> Shipment [label="transported by"];
            Plant -> Shipment [label="dispatched from"];
        }
        """)

# ==============================================================================
# VIEW 5: DECIDE (TABS: Recommendations, What-If Lab)
# ==============================================================================
elif page == "💡 5. Decide":
    st.header("💡 Prescriptive Decision Center")
    st.caption("Active risk signals, candidate recommendations, and what-if prescriptive intervention simulator.")
    # Spacers give this page's st.tabs a unique position so the selected tab doesn't carry over between pages.
    st.empty()
    st.empty()
    tab_rec, tab_sim = st.tabs(["💡 Prescriptive Recommendations", "🧪 What-If Simulation Lab"])

    with tab_rec:
        st.subheader("💡 Prescriptive Decision Engine (`APP.RECOMMENDATIONS`)")
        st.caption("Active risk signals, candidate recommendations, and governed escalation pathway.")

        # Display Flash Message from Session State
        if "rec_flash_msg" in st.session_state:
            st.success(st.session_state["rec_flash_msg"])
            del st.session_state["rec_flash_msg"]

        if "esc_flash_msg" in st.session_state:
            st.success(st.session_state["esc_flash_msg"])
            del st.session_state["esc_flash_msg"]

        # Risk Signals Header with Dynamic Priority Counts
        prio_df = session.sql("SELECT PRIORITY, COUNT(*) AS CNT FROM SC_ONTOLOGY.APP.V_RISK_SIGNALS GROUP BY PRIORITY ORDER BY CNT DESC").to_pandas()
        prio_summary = " · ".join([f"{r['PRIORITY']}: {r['CNT']}" for _, r in prio_df.iterrows()]) if not prio_df.empty else "Low: 38"

        c_top1, c_top2 = st.columns([3, 1])
        with c_top1:
            st.markdown("##### ⚠️ Active Risk Signals (`APP.V_RISK_SIGNALS`)")
            st.caption(f"Evaluated over 12-month history. Ranked by RISK_SCORE descending (Priority breakdown: **{prio_summary}** on absolute 0–100 scale).")
        with c_top2:
            if st.button("🔄 Generate Recommendations"):
                with st.spinner("Running APP.SP_GENERATE_RECOMMENDATIONS()..."):
                    gen_res = session.sql("CALL SC_ONTOLOGY.APP.SP_GENERATE_RECOMMENDATIONS()").collect()[0][0]
                    st.session_state["rec_flash_msg"] = gen_res
                    _rerun()

        risk_signals_df = session.sql("""
            SELECT 
                ENTITY_TYPE,
                ENTITY_ID,
                ENTITY_NAME,
                TOTAL_EVENTS,
                LATE_RATE_RAW_PCT AS "LATE_RATE_%",
                NORM_LEAD_TIME_VOLATILITY AS "VOLATILITY_SCORE",
                NORM_SLA_BREACH_RATE AS "SLA_BREACH_%",
                NORM_STOCKOUT_RISK AS "STOCKOUT_RISK_%",
                RISK_SCORE,
                PRIORITY,
                PENALTY_EXPOSURE_USD_EST AS "EST_PENALTY_USD"
            FROM SC_ONTOLOGY.APP.V_RISK_SIGNALS
            ORDER BY RISK_SCORE DESC
        """).to_pandas()
        st.dataframe(risk_signals_df, use_container_width=True)

        st.divider()
        st.subheader("📋 Governed Recommendations Table")
        st.caption("Illustrative per-entity estimates. Expected uplift and penalty reductions are non-additive across rows.")

        recs_df = session.sql("""
            SELECT 
                RECOMMENDATION_ID,
                ENTITY_TYPE,
                ENTITY_ID,
                ISSUE_TYPE,
                RECOMMENDATION_TEXT,
                EXPECTED_OTD_UPLIFT_PCT AS "OTD_UPLIFT_% (ILLUSTRATIVE)",
                EXPECTED_COST_CHANGE_USD AS "COST_DELTA_$ (ILLUSTRATIVE)",
                EXPECTED_PENALTY_REDUCTION_USD AS "PENALTY_AVOID_$ (ILLUSTRATIVE)",
                OWNER_ROLE,
                PRIORITY,
                STATUS,
                SOURCE_SIGNALS
            FROM SC_ONTOLOGY.APP.RECOMMENDATIONS
            ORDER BY ENTITY_TYPE, ENTITY_ID
        """).to_pandas()
        st.dataframe(recs_df, use_container_width=True)

        with st.expander("🔍 View Recommendation Trigger Signals (SOURCE_SIGNALS)"):
            for idx, r in recs_df.iterrows():
                st.markdown(f"**`{r['RECOMMENDATION_ID']}`** — *{r['ISSUE_TYPE']}* for `{r['ENTITY_ID']}` ({r['ENTITY_TYPE']})")
                st.json(r["SOURCE_SIGNALS"] if isinstance(r["SOURCE_SIGNALS"], dict) else json.loads(str(r["SOURCE_SIGNALS"])))

        st.divider()
        st.subheader("🚨 Escalate Recommendation to Operational Action (`APP.ACTIONS`)")
        st.caption("A recommendation may be escalated into `APP.ACTIONS` ONLY via parameterized `APP.SP_CREATE_ACTION_ITEM` with explicit user confirmation.")

        rec_options = recs_df["RECOMMENDATION_ID"].tolist() if not recs_df.empty else []
        if rec_options:
            # FIX 1: Selectbox and Preview OUTSIDE st.form so preview updates dynamically on selection
            sel_rec_id = st.selectbox("Select Recommendation to Escalate:", options=rec_options)
            selected_rec = recs_df[recs_df["RECOMMENDATION_ID"] == sel_rec_id].iloc[0]

            col_p1, col_p2 = st.columns(2)
            with col_p1:
                st.info(f"**Target Entity**: `{selected_rec['ENTITY_TYPE']}` — `{selected_rec['ENTITY_ID']}`\n\n**Issue Type**: `{selected_rec['ISSUE_TYPE']}`")
            with col_p2:
                st.markdown(f"**Prescriptive Recommendation**:\n*{selected_rec['RECOMMENDATION_TEXT']}*")

            esc_action_type = "SUPPLIER_ESCALATION" if selected_rec["ENTITY_TYPE"] == "SUPPLIER" else "CARRIER_REVIEW"
            esc_severity = "HIGH" if selected_rec["PRIORITY"] in ["High", "Critical"] else "MEDIUM"
            esc_desc = f"Escalated from {selected_rec['RECOMMENDATION_ID']}: {selected_rec['RECOMMENDATION_TEXT']}"

            # Only confirmation checkbox and submit button inside the form
            with st.form("escalate_rec_form"):
                confirm_escalate = st.checkbox(f"I explicitly confirm creating this governed operational action item in APP.ACTIONS for {selected_rec['ENTITY_ID']}")
                esc_submit = st.form_submit_button("🚀 Escalate to Action Item")

                if esc_submit:
                    if not confirm_escalate:
                        st.warning("⚠️ Please check the confirmation checkbox before escalating.")
                    else:
                        sp_esc_sql = "CALL SC_ONTOLOGY.APP.SP_CREATE_ACTION_ITEM(?, ?, ?, ?, ?)"
                        esc_res = session.sql(sp_esc_sql, params=[
                            esc_action_type,
                            selected_rec["ENTITY_TYPE"],
                            selected_rec["ENTITY_ID"],
                            esc_severity,
                            esc_desc[:950]
                        ]).collect()[0][0]
                        st.session_state["esc_flash_msg"] = esc_res
                        _rerun()

    with tab_sim:
        st.header("🧪 Prescriptive What-If Simulation Lab")
        st.caption("Simulate intervention levers on OTD uplift, inventory stockout risk, and net cost. Pure table function reading `APP.SIM_COEFFICIENTS`.")
        st.warning("⚠️ **ILLUSTRATIVE MODEL - assumptions shown below**. Model parameters are illustrative linear heuristics and not calibrated to historical elasticity.")

        # Read Base Stockout Risk from SIM_COEFFICIENTS
        base_stockout_df = session.sql("SELECT COEFFICIENT_VALUE FROM SC_ONTOLOGY.APP.SIM_COEFFICIENTS WHERE COEFFICIENT_NAME = 'BASE_STOCKOUT_RISK_PCT'").to_pandas()
        base_stockout_val = float(base_stockout_df.iloc[0]["COEFFICIENT_VALUE"]) if not base_stockout_df.empty else 40.0

        # Sliders
        col_s1, col_s2 = st.columns(2)
        with col_s1:
            baseline_val = st.number_input("Governed Baseline Outbound OTD % (Q3 2026 Cohort):", value=64.12, min_value=0.0, max_value=100.0, step=0.1)
            expedite_slider = st.slider("Premium Freight Expedite Allocation (% of order volume):", min_value=0.0, max_value=30.0, value=15.0, step=1.0)
            alt_supp_slider = st.slider("Dual-Sourced Secondary Supplier Allocation (% of volume split):", min_value=0.0, max_value=50.0, value=20.0, step=1.0)
        with col_s2:
            ss_slider = st.slider("Safety Stock Buffer Increase (additional days):", min_value=0.0, max_value=14.0, value=7.0, step=1.0)
            shock_slider = st.slider("Unanticipated Demand Surge Shock (%):", min_value=-20.0, max_value=20.0, value=10.0, step=1.0)

        # Call F_WHATIF_PROJECTION with explicit FLOAT typed parameters
        sim_sql = """
            SELECT * FROM TABLE(SC_ONTOLOGY.APP.F_WHATIF_PROJECTION(
                ?::FLOAT, ?::FLOAT, ?::FLOAT, ?::FLOAT, ?::FLOAT
            ))
        """
        sim_res_df = session.sql(sim_sql, params=[
            float(baseline_val),
            float(expedite_slider),
            float(alt_supp_slider),
            float(ss_slider),
            float(shock_slider)
        ]).to_pandas()

        if not sim_res_df.empty:
            proj = sim_res_df.iloc[0]

            st.markdown("---")
            st.subheader("📊 Projected Scenario Results")

            m1, m2, m3, m4 = st.columns(4)
            otd_delta = round(proj["PROJECTED_OTD_PCT"] - proj["BASELINE_OTD_PCT"], 2)
            m1.metric("Projected Outbound OTD", f"{proj['PROJECTED_OTD_PCT']}%", f"{otd_delta:+0.2f}% vs Baseline")
            m2.metric("Projected Stockout Risk", f"{proj['PROJECTED_STOCKOUT_RISK_PCT']}%", f"Assumed base {base_stockout_val}% (illustrative)")
            m3.metric("Projected Penalty Exposure", f"${proj['PROJECTED_PENALTY_EXPOSURE_USD']:,.2f}", f"-${proj['PENALTY_AVOIDED_USD']:,.2f} Avoided")
            
            net_cost = float(proj["NET_COST_IMPACT_USD"])
            m4.metric("Net Cost Impact", f"${net_cost:,.2f}", "Cost - Avoidance")

            if net_cost > 0:
                st.info(f"💡 **Financial Analysis**: Direct intervention costs (\\${proj['INTERVENTION_COST_USD']:,.2f}) exceed penalty avoidance (\\${proj['PENALTY_AVOIDED_USD']:,.2f}). **This scenario does not pay back** on penalty savings alone, but provides +{otd_delta}% service level protection.")
            else:
                st.success(f"🎉 **Financial Analysis**: Penalty avoidance (\\${proj['PENALTY_AVOIDED_USD']:,.2f}) covers intervention costs (\\${proj['INTERVENTION_COST_USD']:,.2f}). Net positive ROI of \\${abs(net_cost):,.2f}.")

            # Side-by-side What-If Charts
            c_sim1, c_sim2 = st.columns(2)
            
            with c_sim1:
                df_pct = pd.DataFrame([
                    {"Metric": "Outbound OTD (%)", "Scenario": "Baseline", "Percentage": float(proj["BASELINE_OTD_PCT"])},
                    {"Metric": "Outbound OTD (%)", "Scenario": "Projected", "Percentage": float(proj["PROJECTED_OTD_PCT"])},
                    {"Metric": "Stockout Risk (%)", "Scenario": "Baseline", "Percentage": float(base_stockout_val)},
                    {"Metric": "Stockout Risk (%)", "Scenario": "Projected", "Percentage": float(proj["PROJECTED_STOCKOUT_RISK_PCT"])}
                ])
                
                # Grouped bars: use xOffset if Altair >= 5, else column facet
                if hasattr(alt, "XOffset") or hasattr(alt, "xoffset"):
                    chart_pct = alt.Chart(df_pct).mark_bar().encode(
                        x=alt.X("Metric:N", title=None),
                        xOffset=alt.XOffset("Scenario:N", sort=["Baseline", "Projected"]),
                        y=alt.Y("Percentage:Q", scale=alt.Scale(domain=[0, 100]), title="Rate (%)"),
                        color=alt.Color("Scenario:N", scale=alt.Scale(domain=["Baseline", "Projected"], range=["#94A3B8", "#29B5E8"])),
                        tooltip=[alt.Tooltip("Metric:N"), alt.Tooltip("Scenario:N"), alt.Tooltip("Percentage:Q", format=".2f")]
                    ).properties(title="Baseline vs Projected (%)", height=240)
                else:
                    chart_pct = alt.Chart(df_pct).mark_bar().encode(
                        x=alt.X("Scenario:N", title=None, axis=alt.Axis(labels=True)),
                        y=alt.Y("Percentage:Q", scale=alt.Scale(domain=[0, 100]), title="Rate (%)"),
                        color=alt.Color("Scenario:N", scale=alt.Scale(domain=["Baseline", "Projected"], range=["#94A3B8", "#29B5E8"])),
                        tooltip=[alt.Tooltip("Metric:N"), alt.Tooltip("Scenario:N"), alt.Tooltip("Percentage:Q", format=".2f")]
                    ).facet(
                        column=alt.Column("Metric:N", header=alt.Header(title=None, labelOrient="bottom"))
                    ).properties(title="Baseline vs Projected (%)")
                
                st.altair_chart(chart_pct, use_container_width=True)

            with c_sim2:
                df_pen = pd.DataFrame([
                    {"Scenario": "Baseline", "Exposure ($)": float(proj["BASELINE_PENALTY_USD"])},
                    {"Scenario": "Projected", "Exposure ($)": float(proj["PROJECTED_PENALTY_EXPOSURE_USD"])}
                ])
                chart_pen = alt.Chart(df_pen).mark_bar().encode(
                    x=alt.X("Scenario:N", sort=["Baseline", "Projected"], title=None),
                    y=alt.Y("Exposure ($):Q", title="Penalty Exposure ($ USD)", axis=alt.Axis(format="$,.0f")),
                    color=alt.Color("Scenario:N", scale=alt.Scale(domain=["Baseline", "Projected"], range=["#94A3B8", "#10B981"]), legend=None),
                    tooltip=[alt.Tooltip("Scenario:N"), alt.Tooltip("Exposure ($):Q", format="$,.2f")]
                ).properties(title="Penalty Exposure (USD)", height=240)
                st.altair_chart(chart_pen, use_container_width=True)

            st.dataframe(sim_res_df, use_container_width=True)

        st.divider()
        st.subheader("⚙️ Simulation Model Parameter Registry (`APP.SIM_COEFFICIENTS`)")
        st.caption("Underlying linear model coefficients and documented assumptions.")
        coeffs_df = session.sql("SELECT COEFFICIENT_NAME, COEFFICIENT_VALUE, UNIT, DESCRIPTION, ASSUMPTIONS_NOTE FROM SC_ONTOLOGY.APP.SIM_COEFFICIENTS ORDER BY COEFFICIENT_NAME").to_pandas()
        st.dataframe(coeffs_df, use_container_width=True)

# ==============================================================================
# VIEW 6: ACT (ACTIONS & ESCALATION LOG)
# ==============================================================================
elif page == "🚨 6. Act":
    st.header("🚨 Actions & Escalation Tracker (`APP.ACTIONS`)")
    st.markdown("Live audit log of automated IoT watchdog alerts and governed operational action items.")

    # Display Flash Message from Session State
    if "act_flash_msg" in st.session_state:
        st.success(st.session_state["act_flash_msg"])
        del st.session_state["act_flash_msg"]

    actions_df = session.sql("SELECT * FROM SC_ONTOLOGY.APP.ACTIONS ORDER BY CREATED_AT DESC").to_pandas()
    st.dataframe(actions_df, use_container_width=True)

    st.divider()
    st.subheader("➕ Create Governed Action Item / Supplier Escalation")
    st.caption("Action items are created ONLY upon explicit user submission through parameterized `APP.SP_CREATE_ACTION_ITEM`.")

    with st.form("action_create_form"):
        c1, c2 = st.columns(2)
        with c1:
            f_action_type = st.selectbox("Action Type:", ["SUPPLIER_ESCALATION", "IOT_ALERT", "INVENTORY_REORDER", "CARRIER_REVIEW", "PROCESS_AUDIT"])
            f_entity_type = st.selectbox("Target Entity Type:", ["SUPPLIER", "SHIPMENT", "PART", "CARRIER", "PLANT", "PRODUCT", "CUSTOMER"])
            f_entity_id = st.text_input("Target Entity ID:", value="SUP-104")
        with c2:
            f_severity = st.selectbox("Severity Level:", ["HIGH (Level-2)", "CRITICAL (Level-1)", "MEDIUM (Level-3)", "LOW (Level-4)"])
            f_description = st.text_area("Detailed Action Description:", value="Initiate Level-2 Supplier Escalation for Titan Micro-Foundry regarding delivery delays and 5% SLA penalty review.")

        confirmed = st.checkbox("I confirm this governed operational ticket should be created in APP.ACTIONS")
        submit_btn = st.form_submit_button("🚀 Submit Action Item")

        if submit_btn:
            if not confirmed:
                st.warning("⚠️ Please check the confirmation checkbox before creating an action item.")
            else:
                sev_clean = f_severity.split(" ")[0]
                sp_sql = "CALL SC_ONTOLOGY.APP.SP_CREATE_ACTION_ITEM(?, ?, ?, ?, ?)"
                res = session.sql(sp_sql, params=[f_action_type, f_entity_type, f_entity_id, sev_clean, f_description]).collect()[0][0]
                st.session_state["act_flash_msg"] = res
                _rerun()
