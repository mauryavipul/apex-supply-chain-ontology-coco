-- ==============================================================================
-- 20_decision_engine.sql
-- Decision Center (Prescriptive Engine): Risk Signals View, Candidates & Recommendations
-- ==============================================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA APP;
USE WAREHOUSE HACK_WH;

-- ------------------------------------------------------------------------------
-- 1. APP.V_RISK_SIGNALS
-- Unified Supplier and Carrier Risk Scoring View (Additive & Read-Only)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW APP.V_RISK_SIGNALS
COMMENT = 'Unified risk signals view for suppliers and carriers over the active history window (2025-10-01 to 2026-10-07). Evaluates late delivery rate, lead-time/delay volatility, SLA breach rate, and stockout risk to compute composite risk score and priority tier.'
AS
WITH supplier_po_metrics AS (
    SELECT 
        s.SUPPLIER_ID,
        s.SUPPLIER_NAME,
        COUNT(po.PO_LINE_KEY) AS TOTAL_EVENTS,
        -- 1. Raw Late Delivery Rate %: % of delivered POs not on time
        ROUND(COALESCE(AVG(CASE WHEN po.IS_DELIVERED = TRUE AND po.IS_ON_TIME_INBOUND = FALSE THEN 1.0 WHEN po.IS_DELIVERED = TRUE THEN 0.0 END) * 100.0, 0.0), 2) AS LATE_RATE_RAW_PCT,
        -- 2. Raw Lead Time Volatility: Standard deviation of (actual lead time - contract lead time) in calendar days on delivered POs
        ROUND(COALESCE(STDDEV(CASE WHEN po.IS_DELIVERED = TRUE THEN po.LEAD_TIME_ACTUAL_DAYS - po.LEAD_TIME_CONTRACT_DAYS END), 0.0), 2) AS LEAD_TIME_VOLATILITY_RAW_DAYS,
        -- Actual Inbound OTIF % across delivered PO lines
        ROUND(100.0 * COUNT(CASE WHEN po.IS_DELIVERED = TRUE AND po.DELIVERY_DATE_KEY <= po.PROMISED_DATE_KEY AND po.RECEIVED_QTY >= po.ORDER_QTY THEN 1 END) / NULLIF(COUNT(CASE WHEN po.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS ACTUAL_INBOUND_OTIF_PCT,
        -- Illustrative Heuristic Penalty Exposure: 5% penalty clause estimate on spend of SLA-breached PO lines (actual lead time > contract)
        ROUND(COALESCE(SUM(CASE WHEN po.IS_DELIVERED = TRUE AND po.LEAD_TIME_ACTUAL_DAYS > po.LEAD_TIME_CONTRACT_DAYS THEN po.EXTENDED_PURCHASE_COST_USD * 0.05 ELSE 0 END), 0.0), 2)::NUMBER(12,2) AS PENALTY_EXPOSURE_USD_EST
    FROM CURATED.DIM_SUPPLIER s
    LEFT JOIN CURATED.FACT_PURCHASE_ORDERS po 
        ON s.SUPPLIER_KEY = po.SUPPLIER_KEY
    GROUP BY s.SUPPLIER_ID, s.SUPPLIER_NAME
),
supplier_sla AS (
    SELECT 
        s.SUPPLIER_ID,
        ROUND(AVG(sla.TARGET_OTIF_PCT), 2) AS AVG_TARGET_OTIF_PCT
    FROM CURATED.DIM_SUPPLIER s
    LEFT JOIN CURATED.DIM_SUPPLIER_PART_SLA sla ON s.SUPPLIER_KEY = sla.SUPPLIER_KEY
    GROUP BY s.SUPPLIER_ID
),
supplier_distinct_part_plants AS (
    -- Derive supplier -> part -> plant from DISTINCT combinations in FACT_PURCHASE_ORDERS
    SELECT DISTINCT 
        s.SUPPLIER_ID,
        po.PART_KEY,
        po.PLANT_KEY
    FROM CURATED.DIM_SUPPLIER s
    JOIN CURATED.FACT_PURCHASE_ORDERS po ON s.SUPPLIER_KEY = po.SUPPLIER_KEY
),
supplier_stockout_metrics AS (
    -- Supplier Stockout Risk: % of supplied part-plant combinations where Days of Inventory < 15 days buffer
    SELECT 
        spp.SUPPLIER_ID,
        ROUND(COALESCE(AVG(CASE WHEN inv.DAYS_OF_INVENTORY < 15.0 THEN 100.0 ELSE 0.0 END), 0.0), 2) AS STOCKOUT_RISK_RAW_PCT
    FROM supplier_distinct_part_plants spp
    LEFT JOIN CURATED.INVENTORY_POSITION_CURRENT inv 
        ON spp.PART_KEY = inv.PART_KEY 
       AND spp.PLANT_KEY = inv.PLANT_KEY
    GROUP BY spp.SUPPLIER_ID
),
supplier_unified AS (
    SELECT 
        'SUPPLIER' AS ENTITY_TYPE,
        p.SUPPLIER_ID AS ENTITY_ID,
        p.SUPPLIER_NAME AS ENTITY_NAME,
        p.TOTAL_EVENTS,
        p.LATE_RATE_RAW_PCT,
        p.LEAD_TIME_VOLATILITY_RAW_DAYS,
        -- SLA Breach Rate: Shortfall of actual inbound OTIF % below contract target OTIF % (scaled 0-100)
        GREATEST(0.0, ROUND(COALESCE(sla.AVG_TARGET_OTIF_PCT - p.ACTUAL_INBOUND_OTIF_PCT, 0.0), 2)) AS SLA_BREACH_RATE_RAW_PCT,
        COALESCE(stk.STOCKOUT_RISK_RAW_PCT, 0.0) AS STOCKOUT_RISK_RAW_PCT,
        p.PENALTY_EXPOSURE_USD_EST
    FROM supplier_po_metrics p
    LEFT JOIN supplier_sla sla ON p.SUPPLIER_ID = sla.SUPPLIER_ID
    LEFT JOIN supplier_stockout_metrics stk ON p.SUPPLIER_ID = stk.SUPPLIER_ID
),
carrier_metrics AS (
    SELECT 
        'CARRIER' AS ENTITY_TYPE,
        c.CARRIER_CODE AS ENTITY_ID,
        c.CARRIER_NAME AS ENTITY_NAME,
        COUNT(s.SHIPMENT_LINE_KEY) AS TOTAL_EVENTS,
        -- 1. Raw Late Rate %: % of delivered outbound shipments not on time
        ROUND(COALESCE(AVG(CASE WHEN s.IS_DELIVERED = TRUE AND s.IS_ON_TIME_OUTBOUND = FALSE THEN 1.0 WHEN s.IS_DELIVERED = TRUE THEN 0.0 END) * 100.0, 0.0), 2) AS LATE_RATE_RAW_PCT,
        -- 2. Carrier Delay Volatility: Standard deviation of (actual delivery date - promised delivery date) in days
        ROUND(COALESCE(STDDEV(CASE WHEN s.IS_DELIVERED = TRUE THEN DATEDIFF('day', s.PROMISED_DELIVERY_DATE, s.ACTUAL_DELIVERY_DATE) END), 0.0), 2) AS LEAD_TIME_VOLATILITY_RAW_DAYS,
        -- 3. Severe Delay Rate % (SLA Breach component): % of delivered shipments delayed by >= 5 days
        ROUND(COALESCE(AVG(CASE WHEN s.IS_DELIVERED = TRUE AND DATEDIFF('day', s.PROMISED_DELIVERY_DATE, s.ACTUAL_DELIVERY_DATE) >= 5 THEN 1.0 WHEN s.IS_DELIVERED = TRUE THEN 0.0 END) * 100.0, 0.0), 2) AS SLA_BREACH_RATE_RAW_PCT,
        -- 4. Backorder Rate % (Stockout substitute): % of assigned shipments with backorders (IS_BACKORDERED = TRUE)
        ROUND(COALESCE(AVG(CASE WHEN s.IS_BACKORDERED = TRUE THEN 1.0 ELSE 0.0 END) * 100.0, 0.0), 2) AS STOCKOUT_RISK_RAW_PCT,
        -- Illustrative Heuristic Penalty Exposure: 5% of freight cost on delayed shipments
        ROUND(COALESCE(SUM(CASE WHEN s.IS_DELIVERED = TRUE AND DATEDIFF('day', s.PROMISED_DELIVERY_DATE, s.ACTUAL_DELIVERY_DATE) > 0 THEN s.FREIGHT_COST_USD * 0.05 ELSE 0 END), 0.0), 2)::NUMBER(12,2) AS PENALTY_EXPOSURE_USD_EST
    FROM CURATED.DIM_CARRIER c
    LEFT JOIN CURATED.FACT_OUTBOUND_SHIPMENTS s 
        ON c.CARRIER_KEY = s.CARRIER_KEY
    GROUP BY c.CARRIER_CODE, c.CARRIER_NAME
),
all_entities AS (
    SELECT * FROM supplier_unified
    UNION ALL
    SELECT * FROM carrier_metrics
),
scored AS (
    SELECT 
        ENTITY_TYPE,
        ENTITY_ID,
        ENTITY_NAME,
        TOTAL_EVENTS,
        LATE_RATE_RAW_PCT,
        LEAD_TIME_VOLATILITY_RAW_DAYS,
        SLA_BREACH_RATE_RAW_PCT,
        STOCKOUT_RISK_RAW_PCT,
        -- Normalization (0-100 scale):
        -- 1. Late Rate is already a % (0-100)
        LATE_RATE_RAW_PCT AS NORM_LATE_RATE,
        -- 2. Volatility: days stddev scaled with 10 days = 100 score, capped at 100
        LEAST(100.0, ROUND(LEAD_TIME_VOLATILITY_RAW_DAYS * 10.0, 2)) AS NORM_LEAD_TIME_VOLATILITY,
        -- 3. SLA Breach Rate is already a % (0-100)
        SLA_BREACH_RATE_RAW_PCT AS NORM_SLA_BREACH_RATE,
        -- 4. Stockout Risk is already a % (0-100)
        STOCKOUT_RISK_RAW_PCT AS NORM_STOCKOUT_RISK,
        -- Composite Risk Score = 0.35*LateRate + 0.25*Volatility + 0.20*SlaBreach + 0.20*StockoutRisk
        ROUND(
            0.35 * LATE_RATE_RAW_PCT + 
            0.25 * LEAST(100.0, LEAD_TIME_VOLATILITY_RAW_DAYS * 10.0) + 
            0.20 * SLA_BREACH_RATE_RAW_PCT + 
            0.20 * STOCKOUT_RISK_RAW_PCT, 
            2
        ) AS RISK_SCORE,
        PENALTY_EXPOSURE_USD_EST
    FROM all_entities
)
SELECT 
    ENTITY_TYPE,
    ENTITY_ID,
    ENTITY_NAME,
    TOTAL_EVENTS,
    LATE_RATE_RAW_PCT,
    LEAD_TIME_VOLATILITY_RAW_DAYS,
    SLA_BREACH_RATE_RAW_PCT,
    STOCKOUT_RISK_RAW_PCT,
    NORM_LATE_RATE,
    NORM_LEAD_TIME_VOLATILITY,
    NORM_SLA_BREACH_RATE,
    NORM_STOCKOUT_RISK,
    RISK_SCORE,
    CASE 
        WHEN RISK_SCORE >= 80.0 THEN 'Critical'
        WHEN RISK_SCORE >= 60.0 THEN 'High'
        WHEN RISK_SCORE >= 40.0 THEN 'Medium'
        ELSE 'Low'
    END AS PRIORITY,
    PENALTY_EXPOSURE_USD_EST
FROM scored;

-- ------------------------------------------------------------------------------
-- 2. APP.V_RECOMMENDATION_CANDIDATES
-- Rule-Based Prescriptive Candidate Generation View
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW APP.V_RECOMMENDATION_CANDIDATES
COMMENT = 'Candidate prescriptive recommendations evaluated dynamically against APP.V_RISK_SIGNALS based on deterministic threshold rules.'
AS
-- Rule 1: High Lead-Time Volatility -> Dual-source & Expedite partial volume (SUPPLIER ONLY)
SELECT 
    'REC-' || ENTITY_ID || '-HIGH_LEAD_TIME_VOLATILITY' AS RECOMMENDATION_ID,
    ENTITY_TYPE,
    ENTITY_ID,
    'HIGH_LEAD_TIME_VOLATILITY' AS ISSUE_TYPE,
    'Dual-source allocation and expedite partial order volumes to mitigate high lead-time volatility (' || TO_VARCHAR(NORM_LEAD_TIME_VOLATILITY) || ' / 100).' AS RECOMMENDATION_TEXT,
    12.50::NUMBER(5,2) AS EXPECTED_OTD_UPLIFT_PCT,
    15000.00::NUMBER(12,2) AS EXPECTED_COST_CHANGE_USD,
    ROUND(PENALTY_EXPOSURE_USD_EST * 0.40, 2)::NUMBER(12,2) AS EXPECTED_PENALTY_REDUCTION_USD,
    'Procurement Lead' AS OWNER_ROLE,
    PRIORITY,
    'PROPOSED' AS STATUS,
    OBJECT_CONSTRUCT(
        'entity_type', ENTITY_TYPE,
        'entity_id', ENTITY_ID,
        'lead_time_volatility_raw_days', LEAD_TIME_VOLATILITY_RAW_DAYS,
        'norm_lead_time_volatility', NORM_LEAD_TIME_VOLATILITY,
        'risk_score', RISK_SCORE
    ) AS SOURCE_SIGNALS,
    TRUE AS IS_ILLUSTRATIVE
FROM APP.V_RISK_SIGNALS
WHERE ENTITY_TYPE = 'SUPPLIER'
  AND NORM_LEAD_TIME_VOLATILITY >= 50.0

UNION ALL

-- Rule 2: High SLA Breach + High Penalty Exposure -> Supplier Executive Recovery Plan (SUPPLIER ONLY)
SELECT 
    'REC-' || ENTITY_ID || '-SLA_BREACH_PENALTY_RISK' AS RECOMMENDATION_ID,
    ENTITY_TYPE,
    ENTITY_ID,
    'SLA_BREACH_PENALTY_RISK' AS ISSUE_TYPE,
    'Execute supplier executive recovery plan and enforce contractual SLA rebate clawback of estimated penalty exposure.' AS RECOMMENDATION_TEXT,
    8.00::NUMBER(5,2) AS EXPECTED_OTD_UPLIFT_PCT,
    0.00::NUMBER(12,2) AS EXPECTED_COST_CHANGE_USD,
    ROUND(PENALTY_EXPOSURE_USD_EST * 0.50, 2)::NUMBER(12,2) AS EXPECTED_PENALTY_REDUCTION_USD,
    'Vendor Management' AS OWNER_ROLE,
    PRIORITY,
    'PROPOSED' AS STATUS,
    OBJECT_CONSTRUCT(
        'entity_type', ENTITY_TYPE,
        'entity_id', ENTITY_ID,
        'sla_breach_rate_pct', SLA_BREACH_RATE_RAW_PCT,
        'penalty_exposure_usd_est', PENALTY_EXPOSURE_USD_EST,
        'risk_score', RISK_SCORE
    ) AS SOURCE_SIGNALS,
    TRUE AS IS_ILLUSTRATIVE
FROM APP.V_RISK_SIGNALS
WHERE ENTITY_TYPE = 'SUPPLIER'
  AND NORM_SLA_BREACH_RATE >= 30.0 
  AND PENALTY_EXPOSURE_USD_EST > 10000.0

UNION ALL

-- Rule 3: Buffer / Stockout Risk -> Safety-Stock Uplift (SUPPLIER ONLY)
SELECT 
    'REC-' || ENTITY_ID || '-BUFFER_STOCKOUT_RISK' AS RECOMMENDATION_ID,
    ENTITY_TYPE,
    ENTITY_ID,
    'BUFFER_STOCKOUT_RISK' AS ISSUE_TYPE,
    'Implement temporary safety-stock buffer uplift (+7 days) and dynamically adjust reorder threshold.' AS RECOMMENDATION_TEXT,
    5.00::NUMBER(5,2) AS EXPECTED_OTD_UPLIFT_PCT,
    17500.00::NUMBER(12,2) AS EXPECTED_COST_CHANGE_USD,
    ROUND(PENALTY_EXPOSURE_USD_EST * 0.20, 2)::NUMBER(12,2) AS EXPECTED_PENALTY_REDUCTION_USD,
    'Supply Chain Planning' AS OWNER_ROLE,
    PRIORITY,
    'PROPOSED' AS STATUS,
    OBJECT_CONSTRUCT(
        'entity_type', ENTITY_TYPE,
        'entity_id', ENTITY_ID,
        'stockout_risk_pct', STOCKOUT_RISK_RAW_PCT,
        'risk_score', RISK_SCORE
    ) AS SOURCE_SIGNALS,
    TRUE AS IS_ILLUSTRATIVE
FROM APP.V_RISK_SIGNALS
WHERE ENTITY_TYPE = 'SUPPLIER'
  AND NORM_STOCKOUT_RISK >= 15.0

UNION ALL

-- Rule 4: Chronic Carrier Delays -> Route Swap / Split Shipment (CARRIER ONLY, dynamic relative threshold >= delivered-weighted avg + 5.0 pts)
SELECT 
    'REC-' || ENTITY_ID || '-CARRIER_CHRONIC_DELAY' AS RECOMMENDATION_ID,
    ENTITY_TYPE,
    ENTITY_ID,
    'CARRIER_CHRONIC_DELAY' AS ISSUE_TYPE,
    'Enact route swap to secondary logistics provider and split high-priority shipment lanes.' AS RECOMMENDATION_TEXT,
    14.00::NUMBER(5,2) AS EXPECTED_OTD_UPLIFT_PCT,
    8500.00::NUMBER(12,2) AS EXPECTED_COST_CHANGE_USD,
    ROUND(PENALTY_EXPOSURE_USD_EST * 0.60, 2)::NUMBER(12,2) AS EXPECTED_PENALTY_REDUCTION_USD,
    'Logistics Operations' AS OWNER_ROLE,
    PRIORITY,
    'PROPOSED' AS STATUS,
    OBJECT_CONSTRUCT(
        'entity_type', ENTITY_TYPE,
        'entity_id', ENTITY_ID,
        'carrier_late_rate_pct', LATE_RATE_RAW_PCT,
        'risk_score', RISK_SCORE
    ) AS SOURCE_SIGNALS,
    TRUE AS IS_ILLUSTRATIVE
FROM APP.V_RISK_SIGNALS
WHERE ENTITY_TYPE = 'CARRIER' 
  AND NORM_LATE_RATE >= (
      SELECT (100.0 * COUNT_IF(IS_DELIVERED AND NOT IS_ON_TIME_OUTBOUND) / NULLIF(COUNT_IF(IS_DELIVERED), 0)) + 5.0 
      FROM CURATED.FACT_OUTBOUND_SHIPMENTS
  );

-- ------------------------------------------------------------------------------
-- 3. APP.RECOMMENDATIONS TABLE
-- Prescriptive Decision Actions & Heuristic Uplift Estimates
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS APP.RECOMMENDATIONS (
    RECOMMENDATION_ID VARCHAR(100) PRIMARY KEY COMMENT 'Unique deterministic recommendation key (REC-<ENTITY_ID>-<ISSUE_TYPE>)',
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'Timestamp when recommendation was initially proposed',
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'Timestamp of most recent rule evaluation refresh',
    ENTITY_TYPE VARCHAR(50) NOT NULL COMMENT 'Target entity domain (SUPPLIER or CARRIER)',
    ENTITY_ID VARCHAR(50) NOT NULL COMMENT 'Identifier of entity (e.g., SUP-104, CARR-01)',
    ISSUE_TYPE VARCHAR(100) NOT NULL COMMENT 'Deterministic issue classification',
    RECOMMENDATION_TEXT VARCHAR(1000) NOT NULL COMMENT 'Prescriptive action description',
    EXPECTED_OTD_UPLIFT_PCT NUMBER(5,2) COMMENT 'Estimated OTD improvement % (illustrative, per-entity, not additive across rows)',
    EXPECTED_COST_CHANGE_USD NUMBER(12,2) COMMENT 'Estimated implementation cost delta in USD (illustrative, per-entity)',
    EXPECTED_PENALTY_REDUCTION_USD NUMBER(12,2) COMMENT 'Estimated SLA penalty avoidance in USD (illustrative, per-entity)',
    OWNER_ROLE VARCHAR(100) NOT NULL COMMENT 'Responsible functional stakeholder role',
    PRIORITY VARCHAR(50) NOT NULL COMMENT 'Priority rating (Critical, High, Medium, Low)',
    STATUS VARCHAR(50) DEFAULT 'PROPOSED' COMMENT 'Lifecycle status (PROPOSED, APPROVED, EXECUTED, REJECTED)',
    SOURCE_SIGNALS VARIANT COMMENT 'Snapshot of risk metrics and triggers that prompted this recommendation',
    IS_ILLUSTRATIVE BOOLEAN DEFAULT TRUE COMMENT 'Flag confirming estimates are illustrative heuristic projections'
)
COMMENT = 'Prescriptive recommendations table populated deterministically by APP.SP_GENERATE_RECOMMENDATIONS(). Estimates are illustrative, per-entity heuristics and not additive across rows.';

-- ------------------------------------------------------------------------------
-- 4. APP.SP_GENERATE_RECOMMENDATIONS()
-- Deterministic, Idempotent Prescriptive Engine
-- ------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE APP.SP_GENERATE_RECOMMENDATIONS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    V_PROPOSED_COUNT NUMBER;
    V_TOTAL_COUNT NUMBER;
BEGIN
    -- 1. Prune stale PROPOSED recommendations that no longer meet candidate thresholds
    -- Never modifies or deletes APPROVED, EXECUTED, or REJECTED items
    DELETE FROM SC_ONTOLOGY.APP.RECOMMENDATIONS
    WHERE STATUS = 'PROPOSED'
      AND RECOMMENDATION_ID NOT IN (SELECT RECOMMENDATION_ID FROM SC_ONTOLOGY.APP.V_RECOMMENDATION_CANDIDATES);

    -- 2. Merge candidate recommendations into APP.RECOMMENDATIONS
    MERGE INTO SC_ONTOLOGY.APP.RECOMMENDATIONS tgt
    USING SC_ONTOLOGY.APP.V_RECOMMENDATION_CANDIDATES src
    ON tgt.RECOMMENDATION_ID = src.RECOMMENDATION_ID
    WHEN MATCHED AND tgt.STATUS = 'PROPOSED' THEN
        UPDATE SET 
            tgt.RECOMMENDATION_TEXT = src.RECOMMENDATION_TEXT,
            tgt.EXPECTED_OTD_UPLIFT_PCT = src.EXPECTED_OTD_UPLIFT_PCT,
            tgt.EXPECTED_COST_CHANGE_USD = src.EXPECTED_COST_CHANGE_USD,
            tgt.EXPECTED_PENALTY_REDUCTION_USD = src.EXPECTED_PENALTY_REDUCTION_USD,
            tgt.PRIORITY = src.PRIORITY,
            tgt.SOURCE_SIGNALS = src.SOURCE_SIGNALS,
            tgt.UPDATED_AT = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN
        INSERT (
            RECOMMENDATION_ID, CREATED_AT, UPDATED_AT, ENTITY_TYPE, ENTITY_ID, ISSUE_TYPE, 
            RECOMMENDATION_TEXT, EXPECTED_OTD_UPLIFT_PCT, EXPECTED_COST_CHANGE_USD, 
            EXPECTED_PENALTY_REDUCTION_USD, OWNER_ROLE, PRIORITY, STATUS, SOURCE_SIGNALS, IS_ILLUSTRATIVE
        ) VALUES (
            src.RECOMMENDATION_ID, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP(), src.ENTITY_TYPE, src.ENTITY_ID, src.ISSUE_TYPE,
            src.RECOMMENDATION_TEXT, src.EXPECTED_OTD_UPLIFT_PCT, src.EXPECTED_COST_CHANGE_USD,
            src.EXPECTED_PENALTY_REDUCTION_USD, src.OWNER_ROLE, src.PRIORITY, src.STATUS, src.SOURCE_SIGNALS, src.IS_ILLUSTRATIVE
        );

    -- 3. Return summary counts
    SELECT COUNT(CASE WHEN STATUS = 'PROPOSED' THEN 1 END), COUNT(*)
    INTO :V_PROPOSED_COUNT, :V_TOTAL_COUNT
    FROM SC_ONTOLOGY.APP.RECOMMENDATIONS;

    RETURN 'SUCCESS: Generated recommendations. Total: ' || TO_VARCHAR(:V_TOTAL_COUNT) || ', Proposed: ' || TO_VARCHAR(:V_PROPOSED_COUNT);
END;
$$;
