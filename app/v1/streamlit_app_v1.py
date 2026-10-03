import streamlit as st
import pandas as pd
import json
from snowflake.snowpark.context import get_active_session

# Set Streamlit page config
st.set_page_config(
    page_title="Apex Supply Chain Control Tower",
    page_icon="🏭",
    layout="wide",
    initial_sidebar_state="expanded"
)

session = get_active_session()

# App Header
st.title("🏭 Apex Industrial Components — Supply Chain Control Tower")
st.caption("Governed Conversational Analytics & Supply Chain Ontology | Powered by Snowflake Cortex")

# Sidebar Navigation
st.sidebar.title("Control Tower Navigation")
page = st.sidebar.radio(
    "Select View:",
    [
        "📊 1. Executive KPIs",
        "⚡ 2. Before vs After Consistency",
        "💬 3. Multi-Persona Chat (Live Agent)",
        "🕸️ 4. Ontology & Lineage Explorer",
        "📖 5. Canonical Metric Glossary",
        "🚨 6. Actions & Escalation Log"
    ]
)

st.sidebar.divider()
st.sidebar.info("Compute Warehouse: **HACK_WH (XSMALL)**\n\nDatabase: **SC_ONTOLOGY**\n\nRole: **ACCOUNTADMIN**")

# ==============================================================================
# VIEW 1: EXECUTIVE KPIS
# ==============================================================================
if page == "📊 1. Executive KPIs":
    st.header("📊 Executive KPI Control Tower")
    st.markdown("Real-time executive metrics across manufacturing plants, suppliers, and customer fulfillment.")

    # Filter row
    col_f1, col_f2 = st.columns(2)
    with col_f1:
        plants_df = session.sql("SELECT DISTINCT PLANT_NAME FROM SC_ONTOLOGY.CURATED.DIM_PLANT ORDER BY 1").to_pandas()
        selected_plants = st.multiselect("Filter by Manufacturing Plant:", options=plants_df["PLANT_NAME"].tolist(), default=plants_df["PLANT_NAME"].tolist())
    with col_f2:
        quarters_df = session.sql("SELECT DISTINCT QUARTER_YEAR FROM SC_ONTOLOGY.CURATED.DIM_DATE ORDER BY 1").to_pandas()
        selected_quarters = st.multiselect("Filter by Order Quarter:", options=quarters_df["QUARTER_YEAR"].tolist(), default=["Q3 2026"])

    # Build safe SQL filters using parameter lists or escaped strings
    plant_filter_sql = "1=1"
    if selected_plants:
        plants_escaped = "','".join([p.replace("'", "''") for p in selected_plants])
        plant_filter_sql = f"p.PLANT_NAME IN ('{plants_escaped}')"

    quarter_filter_sql = "1=1"
    if selected_quarters:
        quarters_escaped = "','".join([q.replace("'", "''") for q in selected_quarters])
        quarter_filter_sql = f"d.QUARTER_YEAR IN ('{quarters_escaped}')"

    # Query Executive Metrics
    kpi_sql = f"""
    SELECT 
        -- Outbound OTD
        (SELECT ROUND(100.0 * COUNT(CASE WHEN s.IS_ON_TIME_OUTBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END), 0), 2)
         FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS s
         JOIN SC_ONTOLOGY.CURATED.DIM_PLANT p ON s.PLANT_KEY = p.PLANT_KEY
         JOIN SC_ONTOLOGY.CURATED.DIM_DATE d ON s.ORDER_DATE_KEY = d.DATE_KEY
         WHERE {plant_filter_sql} AND {quarter_filter_sql}) AS OUTBOUND_OTD_PCT,
        
        -- Inbound OTIF
        (SELECT ROUND(100.0 * COUNT(CASE WHEN po.IS_ON_TIME_INBOUND = TRUE AND po.IS_IN_FULL_INBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN po.IS_DELIVERED = TRUE THEN 1 END), 0), 2)
         FROM SC_ONTOLOGY.CURATED.FACT_PURCHASE_ORDERS po
         JOIN SC_ONTOLOGY.CURATED.DIM_PLANT p ON po.PLANT_KEY = p.PLANT_KEY
         JOIN SC_ONTOLOGY.CURATED.DIM_DATE d ON po.ORDER_DATE_KEY = d.DATE_KEY
         WHERE {plant_filter_sql} AND {quarter_filter_sql}) AS INBOUND_OTIF_PCT,

        -- Days of Inventory (DOI)
        (SELECT ROUND(SUM(i.ON_HAND_QTY) / NULLIF(SUM(i.AVG_DAILY_CONSUMPTION_30D), 0), 1)
         FROM SC_ONTOLOGY.CURATED.INVENTORY_POSITION_CURRENT i
         JOIN SC_ONTOLOGY.CURATED.DIM_PLANT p ON i.PLANT_KEY = p.PLANT_KEY
         WHERE {plant_filter_sql}) AS GLOBAL_DOI_DAYS,

        -- Landed Cost per Unit
        (SELECT ROUND(SUM(po.EXTENDED_PURCHASE_COST_USD + po.INBOUND_FREIGHT_USD + po.DUTY_COST_USD + po.HANDLING_COST_USD) / NULLIF(SUM(po.RECEIVED_QTY), 0), 2)
         FROM SC_ONTOLOGY.CURATED.FACT_PURCHASE_ORDERS po
         JOIN SC_ONTOLOGY.CURATED.DIM_PLANT p ON po.PLANT_KEY = p.PLANT_KEY
         JOIN SC_ONTOLOGY.CURATED.DIM_DATE d ON po.ORDER_DATE_KEY = d.DATE_KEY
         WHERE {plant_filter_sql} AND {quarter_filter_sql} AND po.IS_DELIVERED = TRUE) AS AVG_LANDED_COST_USD
    """
    kpis = session.sql(kpi_sql).to_pandas().iloc[0]

    # Render KPI Cards
    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Outbound OTD (Customer)", f"{kpis['OUTBOUND_OTD_PCT']}%", "Promised Date Basis")
    col2.metric("Inbound OTIF (Suppliers)", f"{kpis['INBOUND_OTIF_PCT']}%", "Target: ≥92%")
    col3.metric("Days of Inventory (DOI)", f"{kpis['GLOBAL_DOI_DAYS']} Days", "Total On-Hand / Daily Use")
    col4.metric("Avg Landed Cost / Unit", f"${kpis['AVG_LANDED_COST_USD']}", "All-in Procurement")

    st.caption("Note: Metrics dynamically reflect the selected plant and order quarter filters.")
    st.divider()

    # Visual Breakdown charts
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
        
        # Runtime-compatible pivoted chart across all Streamlit versions
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

# ==============================================================================
# VIEW 2: BEFORE VS AFTER CONSISTENCY
# ==============================================================================
elif page == "⚡ 2. Before vs After Consistency":
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
# VIEW 3: MULTI-PERSONA CHAT (LIVE AGENT & SEMANTIC VIEW)
# ==============================================================================
elif page == "💬 3. Multi-Persona Chat (Live Agent)":
    st.header("💬 Multi-Persona Conversational Analytics")
    st.markdown("""
    Interact with **`SC_ONTOLOGY.APP.SC_ONTOLOGY_AGENT`** using natural language or persona quick-action buttons. 
    Notice how disparate departmental phrasing routes to the **same canonical metric and lineage** for orders placed in Q3 2026.
    """)

    PERSONA_QUESTIONS = {
        "Planner": "What was our promised-date delivery performance for orders placed in Q3 2026?",
        "Procurement": "How timely were customer deliveries for orders placed in Q3 2026?",
        "Logistics": "What percentage of delivered order lines met the promised date for orders placed in Q3 2026?"
    }

    col_btn1, col_btn2, col_btn3 = st.columns(3)
    p_choice = None
    if col_btn1.button("📋 Planner Persona Question"):
        p_choice = PERSONA_QUESTIONS["Planner"]
    if col_btn2.button("📦 Procurement Persona Question"):
        p_choice = PERSONA_QUESTIONS["Procurement"]
    if col_btn3.button("🚚 Logistics Persona Question"):
        p_choice = PERSONA_QUESTIONS["Logistics"]

    user_query = st.text_input("Enter a supply chain question:", value=p_choice or PERSONA_QUESTIONS["Planner"])

    if st.button("🚀 Ask Cortex Agent", type="primary"):
        with st.spinner("Submitting query to SC_ONTOLOGY_AGENT via DATA_AGENT_RUN..."):
            # Enforce tool allowlist programmatically: allow only Analyst and Search (exclude create_action_item)
            agent_payload = {
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "text", 
                                "text": user_query
                            }
                        ]
                    }
                ],
                "tool_choice": {
                    "type": "auto",
                    "name": ["Analyst", "Search"]
                }
            }
            try:
                # Invoke live Cortex Agent via Snowpark SQL
                agent_sql = "SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN('SC_ONTOLOGY.APP.SC_ONTOLOGY_AGENT', ?, TRUE)"
                raw_response = session.sql(agent_sql, params=[json.dumps(agent_payload)]).collect()[0][0]
                resp_obj = json.loads(raw_response) if isinstance(raw_response, str) else raw_response

                st.subheader("🤖 Cortex Agent Response")
                
                # Surface any top-level warnings from DATA_AGENT_RUN
                warnings = resp_obj.get("warnings", []) if isinstance(resp_obj, dict) else []
                if warnings:
                    for w in warnings:
                        st.warning(f"⚠️ {w.get('message', str(w))}")

                # Parse the documented DATA_AGENT_RUN content array
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

                # Display text response
                if agent_texts:
                    for t in agent_texts:
                        st.markdown(t)
                elif isinstance(resp_obj, dict) and "message" in resp_obj and isinstance(resp_obj["message"], str):
                    st.markdown(resp_obj["message"])

                # Display Agent-generated SQL if present in tool calls
                if agent_sqls:
                    for tool_name, sql_code in agent_sqls:
                        with st.expander(f"🔍 View {tool_name}-Generated SQL"):
                            st.code(sql_code, language="sql")

                # Deterministic Q3 OTD Parity Verification: run ONLY for the three Q3 persona questions
                is_q3_persona_query = any(q.lower() in user_query.lower() for q in [
                    PERSONA_QUESTIONS["Planner"].lower(),
                    PERSONA_QUESTIONS["Procurement"].lower(),
                    PERSONA_QUESTIONS["Logistics"].lower(),
                    "promised-date delivery performance for orders placed in q3 2026",
                    "how timely were customer deliveries for orders placed in q3 2026",
                    "percentage of delivered order lines met the promised date for orders placed in q3 2026"
                ])

                if is_q3_persona_query:
                    st.divider()
                    st.markdown("#### 📐 Deterministic Metric Parity Verification Query")
                    st.caption("Verifying canonical formula and line-level granularity for orders placed in Q3 2026.")
                    
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
                    st.success(f"**Canonical Outbound OTD (Q3 2026 Orders)**: **{res_df.iloc[0]['OUTBOUND_OTD_PCT']}%**")
                    
                    st.markdown(f"""
                    * **Evaluated Cohort**: Sales orders placed in Q3 2026 (`2026-07-01` to `2026-09-30`)
                    * **Delivered Lines Analyzed**: {res_df.iloc[0]['DELIVERED_LINES']:,} lines
                    * **On-Time Delivered Lines**: {res_df.iloc[0]['ON_TIME_LINES']:,} lines
                    * **Governed Formula**: `100.0 * COUNT(CASE WHEN is_on_time_outbound = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN is_delivered = TRUE THEN 1 END), 0)`
                    * **Semantic View Lineage**: `SC_ONTOLOGY.SEMANTIC.SV_SUPPLY_CHAIN_INTELLIGENCE` $\\rightarrow$ `CURATED.FACT_OUTBOUND_SHIPMENTS`
                    """)

                    with st.expander("🔍 View Parity Verification SQL"):
                        st.code(parity_sql, language="sql")

            except Exception as e:
                st.error(f"Execution Error: {str(e)}")

# ==============================================================================
# VIEW 4: ONTOLOGY & LINEAGE EXPLORER
# ==============================================================================
elif page == "🕸️ 4. Ontology & Lineage Explorer":
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
# VIEW 5: CANONICAL METRIC GLOSSARY
# ==============================================================================
elif page == "📖 5. Canonical Metric Glossary":
    st.header("📖 Governed Canonical Metric Glossary")
    st.markdown("Approved enterprise metrics, exact mathematical Boolean SQL formulas, and organizational ownership.")

    glossary_df = pd.DataFrame([
        {
            "Metric Name": "Outbound OTD %",
            "Business Definition": "% of customer order lines delivered on or before promised delivery date among delivered lines",
            "Exact SQL Formula": "100.0 * COUNT(CASE WHEN is_on_time_outbound = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN is_delivered = TRUE THEN 1 END), 0)",
            "Grain": "Customer / Product / Month",
            "Owner": "Logistics"
        },
        {
            "Metric Name": "Inbound OTIF %",
            "Business Definition": "% of purchase order lines delivered both on time and 100% in full among received lines",
            "Exact SQL Formula": "100.0 * COUNT(CASE WHEN is_on_time_inbound = TRUE AND is_in_full_inbound = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN is_delivered = TRUE THEN 1 END), 0)",
            "Grain": "Supplier / Part / Month",
            "Owner": "Procurement"
        },
        {
            "Metric Name": "Outbound OTIF %",
            "Business Definition": "% of customer order lines delivered both on time and 100% in full among delivered lines",
            "Exact SQL Formula": "100.0 * COUNT(CASE WHEN is_on_time_outbound = TRUE AND is_in_full_outbound = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN is_delivered = TRUE THEN 1 END), 0)",
            "Grain": "Customer / Product / Month",
            "Owner": "Planning"
        },
        {
            "Metric Name": "Inbound OTD %",
            "Business Definition": "% of supplier purchase order lines received on or before promised date among received lines",
            "Exact SQL Formula": "100.0 * COUNT(CASE WHEN is_on_time_inbound = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN is_delivered = TRUE THEN 1 END), 0)",
            "Grain": "Supplier / Plant / Month",
            "Owner": "Procurement"
        },
        {
            "Metric Name": "Days of Inventory (DOI)",
            "Business Definition": "Total current on-hand quantity divided by total trailing 30-day daily consumption",
            "Exact SQL Formula": "SUM(on_hand_qty) / NULLIF(SUM(avg_daily_consumption_30d), 0)",
            "Grain": "Plant / Part Category",
            "Owner": "Planning"
        },
        {
            "Metric Name": "Unit Landed Cost ($)",
            "Business Definition": "All-in unit procurement cost including extended purchase price, inbound freight, duty, and handling",
            "Exact SQL Formula": "SUM(extended_purchase_cost_usd + inbound_freight_usd + duty_cost_usd + handling_cost_usd) / NULLIF(SUM(received_qty), 0)",
            "Grain": "Part / Plant / Quarter",
            "Owner": "Procurement"
        },
        {
            "Metric Name": "Supplier Lead Time Var",
            "Business Definition": "Average difference in calendar days between actual delivery lead time and agreed SLA lead time",
            "Exact SQL Formula": "AVG(CASE WHEN is_delivered = TRUE THEN lead_time_actual_days - lead_time_contract_days END)",
            "Grain": "Supplier / Part",
            "Owner": "Procurement"
        },
        {
            "Metric Name": "Backorder Rate %",
            "Business Definition": "% of shipment lines delayed due to product or component backorders",
            "Exact SQL Formula": "100.0 * COUNT(CASE WHEN is_backordered = TRUE THEN 1 END) / NULLIF(COUNT(shipment_line_key), 0)",
            "Grain": "Product / Plant / Month",
            "Owner": "Planning"
        }
    ])
    st.dataframe(glossary_df, use_container_width=True)

# ==============================================================================
# VIEW 6: ACTIONS & ESCALATION LOG
# ==============================================================================
elif page == "🚨 6. Actions & Escalation Log":
    st.header("🚨 Actions & Escalation Tracker (`APP.ACTIONS`)")
    st.markdown("Live audit log of automated IoT watchdog alerts and governed supplier escalation tickets.")

    # Read-only display of APP.ACTIONS
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
            # Default aligned to Level-2 = HIGH matching description
            f_severity = st.selectbox("Severity Level:", ["HIGH (Level-2)", "CRITICAL (Level-1)", "MEDIUM (Level-3)", "LOW (Level-4)"])
            f_description = st.text_area("Detailed Action Description:", value="Initiate Level-2 Supplier Escalation for Titan Micro-Foundry regarding delivery delays and 5% SLA penalty review.")

        confirmed = st.checkbox("I confirm this governed operational ticket should be created in APP.ACTIONS")
        submit_btn = st.form_submit_button("🚀 Submit Action Item")

        if submit_btn:
            if not confirmed:
                st.warning("⚠️ Please check the confirmation checkbox before creating an action item.")
            else:
                sev_clean = f_severity.split(" ")[0]
                # Fully parameterized procedure call avoiding string interpolation
                sp_sql = "CALL SC_ONTOLOGY.APP.SP_CREATE_ACTION_ITEM(?, ?, ?, ?, ?)"
                res = session.sql(sp_sql, params=[f_action_type, f_entity_type, f_entity_id, sev_clean, f_description]).collect()[0][0]
                st.success(res)
                st.rerun()
