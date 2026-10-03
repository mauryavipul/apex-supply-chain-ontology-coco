-- ==============================================================================
-- 23_v2_validation_tests.sql
-- Validation Test Suite for SC_ONTOLOGY v2 Additive Enhancement (T1 - T8)
-- ==============================================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA APP;
USE WAREHOUSE HACK_WH;

-- Baseline Pre-Check: Record APP.ACTIONS Count
SELECT 'BASELINE_APP_ACTIONS_COUNT' AS CHECK_NAME, COUNT(*) AS ACTIONS_COUNT 
FROM SC_ONTOLOGY.APP.ACTIONS;

-- ------------------------------------------------------------------------------
-- T1: Governance Registry & Provenance Function
-- Expected: 8 active metrics; F_METRIC_PROVENANCE returns 'Verified' & 'CURATED.FACT_OUTBOUND_SHIPMENTS'
-- ------------------------------------------------------------------------------
SELECT 'T1_ACTIVE_METRICS_COUNT' AS TEST_ID, COUNT(*) AS ACTUAL_COUNT
FROM SC_ONTOLOGY.GOVERNANCE.METRIC_REGISTRY
WHERE IS_ACTIVE = TRUE;

SELECT 
    'T1_PROVENANCE_CHECK' AS TEST_ID,
    METRIC_KEY,
    METRIC_NAME,
    CONFIDENCE_TIER,
    PRIMARY_SOURCE_TABLE,
    PRIMARY_SOURCE_ROW_COUNT,
    APPROVED_BY
FROM TABLE(SC_ONTOLOGY.GOVERNANCE.F_METRIC_PROVENANCE('MTR-OUTBOUND-OTD'));

-- ------------------------------------------------------------------------------
-- T2: Drift Sentinel (Read-Only)
-- Expected: Latest row STATUS = 'ALIGNED', Canonical = 64.12, Planning = 83.51, Procurement = 96.65, Logistics = 64.12
-- ------------------------------------------------------------------------------
SELECT 
    'T2_GOVERNANCE_HEALTH' AS TEST_ID,
    METRIC_NAME,
    CANONICAL_VALUE,
    LEGACY_PLANNING_VAL,
    LEGACY_PROCUREMENT_VAL,
    LEGACY_LOGISTICS_VAL,
    DELTA_MAX,
    STATUS,
    LAST_CHECKED
FROM SC_ONTOLOGY.GOVERNANCE.V_GOVERNANCE_HEALTH
ORDER BY LAST_CHECKED DESC
LIMIT 1;

-- ------------------------------------------------------------------------------
-- T3: Persona Consistency via DATA_AGENT_RUN
-- Expected: Planner, Procurement, and Logistics all return 64.12%, cite registry, and do NOT ask clarifying question
-- ------------------------------------------------------------------------------
-- (T3.1) Planner Persona
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'SC_ONTOLOGY.APP.SC_ONTOLOGY_AGENT',
    '{"messages": [{"role": "user", "content": [{"type": "text", "text": "What was our promised-date delivery performance for orders placed in Q3 2026?"}]}], "tool_choice": {"type": "auto", "name": ["Analyst", "Search"]}}',
    TRUE
) AS PLANNER_AGENT_RESPONSE;

-- (T3.2) Procurement Persona
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'SC_ONTOLOGY.APP.SC_ONTOLOGY_AGENT',
    '{"messages": [{"role": "user", "content": [{"type": "text", "text": "How timely were customer deliveries for orders placed in Q3 2026?"}]}], "tool_choice": {"type": "auto", "name": ["Analyst", "Search"]}}',
    TRUE
) AS PROCUREMENT_AGENT_RESPONSE;

-- (T3.3) Logistics Persona
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'SC_ONTOLOGY.APP.SC_ONTOLOGY_AGENT',
    '{"messages": [{"role": "user", "content": [{"type": "text", "text": "What percentage of delivered order lines met the promised date for orders placed in Q3 2026?"}]}], "tool_choice": {"type": "auto", "name": ["Analyst", "Search"]}}',
    TRUE
) AS LOGISTICS_AGENT_RESPONSE;

-- ------------------------------------------------------------------------------
-- T4: Agent Guardrails (Ambiguity Disambiguation & Out-of-Scope Refusal)
-- Expected: (a) Ambiguous "on-time rate" -> asks ONE clarifying question (Inbound vs Outbound)
--           (b) "Weather in Munich" -> polite out-of-scope refusal; zero action tools called
-- ------------------------------------------------------------------------------
-- (T4.a) Ambiguous Query
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'SC_ONTOLOGY.APP.SC_ONTOLOGY_AGENT',
    '{"messages": [{"role": "user", "content": [{"type": "text", "text": "What is our on-time rate?"}]}], "tool_choice": {"type": "auto", "name": ["Analyst", "Search"]}}',
    TRUE
) AS AMBIGUOUS_AGENT_RESPONSE;

-- (T4.b) Out-of-Scope Query
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'SC_ONTOLOGY.APP.SC_ONTOLOGY_AGENT',
    '{"messages": [{"role": "user", "content": [{"type": "text", "text": "What is the weather in Munich tomorrow?"}]}], "tool_choice": {"type": "auto", "name": ["Analyst", "Search"]}}',
    TRUE
) AS OUT_OF_SCOPE_AGENT_RESPONSE;

-- ------------------------------------------------------------------------------
-- T5: Risk Signals + Recommendations Validation
-- Expected: 38 rows in V_RISK_SIGNALS, all 'Low' priority, max RISK_SCORE < 40, top entity = SUP-104;
--           CARR-01, CARR-03, CARR-07 > avg + 5 pts (38.88%) & CARR-04 is NOT flagged;
--           APP.RECOMMENDATIONS = 13 rows, all 'PROPOSED'; V_RECOMMENDATION_CANDIDATES = same 13 IDs
-- ------------------------------------------------------------------------------
-- (T5.1) V_RISK_SIGNALS Aggregate Checks
SELECT 
    'T5_RISK_SIGNALS_SUMMARY' AS TEST_ID,
    COUNT(*) AS TOTAL_ENTITIES,
    COUNT_IF(PRIORITY = 'Low') AS LOW_PRIORITY_COUNT,
    MAX(RISK_SCORE) AS MAX_RISK_SCORE,
    (SELECT ENTITY_ID FROM SC_ONTOLOGY.APP.V_RISK_SIGNALS ORDER BY RISK_SCORE DESC LIMIT 1) AS TOP_RISK_ENTITY
FROM SC_ONTOLOGY.APP.V_RISK_SIGNALS;

-- (T5.2) Carrier Late Rate Checks vs Network Threshold
WITH carrier_avg AS (
    SELECT (100.0 * COUNT_IF(IS_DELIVERED AND NOT IS_ON_TIME_OUTBOUND) / NULLIF(COUNT_IF(IS_DELIVERED), 0)) + 5.0 AS THRESHOLD_PCT
    FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS
)
SELECT 
    c.ENTITY_ID,
    c.ENTITY_NAME,
    c.LATE_RATE_RAW_PCT,
    a.THRESHOLD_PCT,
    CASE WHEN c.LATE_RATE_RAW_PCT >= a.THRESHOLD_PCT THEN 'FLAGGED' ELSE 'NOT_FLAGGED' END AS STATUS
FROM SC_ONTOLOGY.APP.V_RISK_SIGNALS c
CROSS JOIN carrier_avg a
WHERE c.ENTITY_TYPE = 'CARRIER'
ORDER BY c.LATE_RATE_RAW_PCT DESC;

-- (T5.3) APP.RECOMMENDATIONS vs APP.V_RECOMMENDATION_CANDIDATES Parity Check
SELECT 
    'T5_RECOMMENDATIONS_PARITY' AS TEST_ID,
    (SELECT COUNT(*) FROM SC_ONTOLOGY.APP.RECOMMENDATIONS WHERE STATUS = 'PROPOSED') AS STORED_PROPOSED_COUNT,
    (SELECT COUNT(*) FROM SC_ONTOLOGY.APP.V_RECOMMENDATION_CANDIDATES) AS CANDIDATE_VIEW_COUNT,
    (SELECT COUNT(*) FROM (
        SELECT RECOMMENDATION_ID FROM SC_ONTOLOGY.APP.RECOMMENDATIONS WHERE STATUS = 'PROPOSED'
        MINUS
        SELECT RECOMMENDATION_ID FROM SC_ONTOLOGY.APP.V_RECOMMENDATION_CANDIDATES
    )) AS DIFF_STORED_MINUS_CANDIDATES,
    (SELECT COUNT(*) FROM (
        SELECT RECOMMENDATION_ID FROM SC_ONTOLOGY.APP.V_RECOMMENDATION_CANDIDATES
        MINUS
        SELECT RECOMMENDATION_ID FROM SC_ONTOLOGY.APP.RECOMMENDATIONS WHERE STATUS = 'PROPOSED'
    )) AS DIFF_CANDIDATES_MINUS_STORED;

-- ------------------------------------------------------------------------------
-- T6: What-If Simulation Function (Pure, ::FLOAT args)
-- Expected: (1) Baseline (64.12, 0, 0, 0, 0) -> Projected OTD = 64.12, Net Cost = 0
--           (2) Scenario (64.12, 15, 20, 7, 10) -> OTD = 68.37, Stockout = 26.50, Penalty = 75,705, Net Cost = +36,625
--           (3) Extreme (64.12, 30, 50, 14, -20) -> Projected OTD <= 100, Stockout >= 0 (Clamping works)
-- ------------------------------------------------------------------------------
SELECT 'T6_BASELINE' AS TEST_CASE, * 
FROM TABLE(SC_ONTOLOGY.APP.F_WHATIF_PROJECTION(64.12::FLOAT, 0.0::FLOAT, 0.0::FLOAT, 0.0::FLOAT, 0.0::FLOAT))
UNION ALL
SELECT 'T6_SCENARIO' AS TEST_CASE, * 
FROM TABLE(SC_ONTOLOGY.APP.F_WHATIF_PROJECTION(64.12::FLOAT, 15.0::FLOAT, 20.0::FLOAT, 7.0::FLOAT, 10.0::FLOAT))
UNION ALL
SELECT 'T6_EXTREME' AS TEST_CASE, * 
FROM TABLE(SC_ONTOLOGY.APP.F_WHATIF_PROJECTION(64.12::FLOAT, 30.0::FLOAT, 50.0::FLOAT, 14.0::FLOAT, -20.0::FLOAT));

-- ------------------------------------------------------------------------------
-- T7: Escalation Guardrail (Negative Test)
-- Expected: Rejected by validation: returns 'ERROR: Invalid severity...'; APP.ACTIONS count remains 1
-- ------------------------------------------------------------------------------
CALL SC_ONTOLOGY.APP.SP_CREATE_ACTION_ITEM(
    'SUPPLIER_ESCALATION',
    'SUPPLIER',
    'SUP-104',
    'URGENT',
    'validation test - must be rejected'
);

SELECT 'T7_POST_CHECK_APP_ACTIONS_COUNT' AS CHECK_NAME, COUNT(*) AS ACTIONS_COUNT 
FROM SC_ONTOLOGY.APP.ACTIONS;

-- ------------------------------------------------------------------------------
-- T8: App + Safety State Verification
-- Expected: SHOW STREAMLITS lists SUPPLY_CHAIN_CONTROL_TOWER on HACK_WH;
--           LIST @SC_ONTOLOGY.APP.STREAMLIT_STAGE shows streamlit_app.py;
--           12-Month Outbound OTD = 66.12; All 3 tasks = suspended; APP.ACTIONS = 1
-- ------------------------------------------------------------------------------
SHOW STREAMLITS IN SCHEMA SC_ONTOLOGY.APP;

LIST @SC_ONTOLOGY.APP.STREAMLIT_STAGE;

SELECT 
    'T8_NETWORK_12M_OTD' AS TEST_ID,
    ROUND(100.0 * COUNT_IF(IS_DELIVERED AND IS_ON_TIME_OUTBOUND) / NULLIF(COUNT_IF(IS_DELIVERED), 0), 2) AS NETWORK_12M_OUTBOUND_OTD_PCT
FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS;

SHOW TASKS IN DATABASE SC_ONTOLOGY;
SELECT "name", "state" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

SELECT 'FINAL_APP_ACTIONS_COUNT' AS CHECK_NAME, COUNT(*) AS ACTIONS_COUNT 
FROM SC_ONTOLOGY.APP.ACTIONS;
