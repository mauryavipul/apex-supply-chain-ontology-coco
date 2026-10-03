-- ==============================================================================
-- 09_verified_queries.sql
-- 10 Verified Query Tests & 3 Persona Consistency Queries
-- ==============================================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA SEMANTIC;
USE WAREHOUSE HACK_WH;

-- ==============================================================================
-- TEST 1: Monthly Outbound OTD by Plant
-- ==============================================================================
SELECT 
    d.YEAR_MONTH,
    p.PLANT_NAME,
    COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END) AS DELIVERED_LINES,
    COUNT(CASE WHEN s.IS_ON_TIME_OUTBOUND = TRUE THEN 1 END) AS ON_TIME_LINES,
    ROUND(100.0 * COUNT(CASE WHEN s.IS_ON_TIME_OUTBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS OUTBOUND_OTD_PCT
FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS s
JOIN SC_ONTOLOGY.CURATED.DIM_DATE d ON s.ORDER_DATE_KEY = d.DATE_KEY
JOIN SC_ONTOLOGY.CURATED.DIM_PLANT p ON s.PLANT_KEY = p.PLANT_KEY
GROUP BY 1, 2
ORDER BY 1, 2;

-- ==============================================================================
-- TEST 2: Inbound OTIF & Lead-Time Variance by Supplier Tier
-- ==============================================================================
SELECT 
    s.SUPPLIER_TIER,
    COUNT(CASE WHEN po.IS_DELIVERED = TRUE THEN 1 END) AS TOTAL_RECEIVED_LINES,
    ROUND(100.0 * COUNT(CASE WHEN po.IS_ON_TIME_INBOUND = TRUE AND po.IS_IN_FULL_INBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN po.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS INBOUND_OTIF_PCT,
    ROUND(100.0 * COUNT(CASE WHEN po.IS_ON_TIME_INBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN po.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS INBOUND_OTD_PCT,
    ROUND(AVG(CASE WHEN po.IS_DELIVERED = TRUE THEN po.LEAD_TIME_ACTUAL_DAYS - po.LEAD_TIME_CONTRACT_DAYS END), 2) AS AVG_LEAD_TIME_VARIANCE_DAYS
FROM SC_ONTOLOGY.CURATED.FACT_PURCHASE_ORDERS po
JOIN SC_ONTOLOGY.CURATED.DIM_SUPPLIER s ON po.SUPPLIER_KEY = s.SUPPLIER_KEY
GROUP BY 1
ORDER BY 1;

-- ==============================================================================
-- TEST 3: Top 5 Parts by Unit Landed Cost
-- ==============================================================================
SELECT 
    p.PART_NUMBER,
    p.PART_NAME,
    p.PART_CATEGORY,
    ROUND(SUM(po.EXTENDED_PURCHASE_COST_USD + po.INBOUND_FREIGHT_USD + po.DUTY_COST_USD + po.HANDLING_COST_USD) / NULLIF(SUM(po.RECEIVED_QTY), 0), 2) AS UNIT_LANDED_COST_USD,
    SUM(po.RECEIVED_QTY) AS TOTAL_RECEIVED_UNITS
FROM SC_ONTOLOGY.CURATED.FACT_PURCHASE_ORDERS po
JOIN SC_ONTOLOGY.CURATED.DIM_PART p ON po.PART_KEY = p.PART_KEY
WHERE po.IS_DELIVERED = TRUE
GROUP BY 1, 2, 3
ORDER BY UNIT_LANDED_COST_USD DESC
LIMIT 5;

-- ==============================================================================
-- TEST 4: Days of Inventory (DOI) by Plant and Part Category (Total On-Hand / Total Daily Consumption)
-- ==============================================================================
SELECT 
    i.PLANT_CODE,
    p.PART_CATEGORY,
    ROUND(SUM(i.ON_HAND_QTY) / NULLIF(SUM(i.AVG_DAILY_CONSUMPTION_30D), 0), 1) AS DAYS_OF_INVENTORY,
    ROUND(SUM(i.INVENTORY_VALUE_USD), 2) AS TOTAL_INVENTORY_VALUE_USD
FROM SC_ONTOLOGY.CURATED.INVENTORY_POSITION_CURRENT i
JOIN SC_ONTOLOGY.CURATED.DIM_PART p ON i.PART_KEY = p.PART_KEY
GROUP BY 1, 2
ORDER BY 1, 2;

-- ==============================================================================
-- TEST 5: Backorder Rate by Finished Product Family
-- ==============================================================================
SELECT 
    p.PRODUCT_FAMILY,
    COUNT(s.SHIPMENT_LINE_KEY) AS TOTAL_SHIPMENT_LINES,
    COUNT(CASE WHEN s.IS_BACKORDERED = TRUE THEN 1 END) AS BACKORDERED_LINES,
    ROUND(100.0 * COUNT(CASE WHEN s.IS_BACKORDERED = TRUE THEN 1 END) / NULLIF(COUNT(s.SHIPMENT_LINE_KEY), 0), 2) AS BACKORDER_RATE_PCT
FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS s
JOIN SC_ONTOLOGY.CURATED.DIM_PRODUCT p ON s.PRODUCT_KEY = p.PRODUCT_KEY
GROUP BY 1
ORDER BY BACKORDER_RATE_PCT DESC;

-- ==============================================================================
-- TEST 6: Carrier Delivery Performance and Average Freight Cost
-- ==============================================================================
SELECT 
    c.CARRIER_NAME,
    c.TRANSPORT_MODE,
    COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END) AS TOTAL_DELIVERIES,
    ROUND(100.0 * COUNT(CASE WHEN s.IS_ON_TIME_OUTBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS OUTBOUND_OTD_PCT,
    ROUND(AVG(s.FREIGHT_COST_USD), 2) AS AVG_FREIGHT_COST_USD
FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS s
JOIN SC_ONTOLOGY.CURATED.DIM_CARRIER c ON s.CARRIER_KEY = c.CARRIER_KEY
GROUP BY 1, 2
ORDER BY OUTBOUND_OTD_PCT DESC;

-- ==============================================================================
-- TEST 7: Bottom 5 Suppliers by Inbound OTD (Last 90 Days)
-- ==============================================================================
SELECT 
    s.SUPPLIER_ID,
    s.SUPPLIER_NAME,
    s.SUPPLIER_TIER,
    COUNT(CASE WHEN po.IS_DELIVERED = TRUE THEN 1 END) AS RECEIVED_LINES,
    ROUND(100.0 * COUNT(CASE WHEN po.IS_ON_TIME_INBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN po.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS INBOUND_OTD_PCT,
    ROUND(100.0 * COUNT(CASE WHEN po.IS_ON_TIME_INBOUND = TRUE AND po.IS_IN_FULL_INBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN po.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS INBOUND_OTIF_PCT
FROM SC_ONTOLOGY.CURATED.FACT_PURCHASE_ORDERS po
JOIN SC_ONTOLOGY.CURATED.DIM_SUPPLIER s ON po.SUPPLIER_KEY = s.SUPPLIER_KEY
WHERE po.ORDER_DATE >= DATEADD('day', -90, '2026-09-30'::DATE)
GROUP BY 1, 2, 3
HAVING COUNT(CASE WHEN po.IS_DELIVERED = TRUE THEN 1 END) >= 10
ORDER BY INBOUND_OTD_PCT ASC
LIMIT 5;

-- ==============================================================================
-- TEST 8: Inventory Value vs Safety Stock Surplus/Deficit by Plant
-- ==============================================================================
SELECT 
    PLANT_CODE,
    ROUND(SUM(INVENTORY_VALUE_USD), 2) AS TOTAL_INVENTORY_VALUE_USD,
    ROUND(SUM(ON_HAND_QTY), 0) AS TOTAL_ON_HAND_QTY,
    ROUND(SUM(SAFETY_STOCK_QTY), 0) AS TOTAL_SAFETY_STOCK_QTY,
    ROUND(SUM(ON_HAND_QTY - SAFETY_STOCK_QTY), 0) AS NET_SAFETY_STOCK_VARIANCE_QTY,
    COUNT(CASE WHEN INVENTORY_HEALTH_STATUS = 'STOCKOUT' THEN 1 END) AS STOCKOUT_ITEM_COUNT,
    COUNT(CASE WHEN INVENTORY_HEALTH_STATUS = 'CRITICAL_LOW' THEN 1 END) AS CRITICAL_LOW_ITEM_COUNT
FROM SC_ONTOLOGY.CURATED.INVENTORY_POSITION_CURRENT
GROUP BY 1
ORDER BY 1;

-- ==============================================================================
-- TEST 9: Customer Segment Outbound OTIF Across Quarters
-- ==============================================================================
SELECT 
    d.QUARTER_YEAR,
    c.CUSTOMER_SEGMENT,
    COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END) AS DELIVERED_LINES,
    ROUND(100.0 * COUNT(CASE WHEN s.IS_ON_TIME_OUTBOUND = TRUE AND s.IS_IN_FULL_OUTBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS OUTBOUND_OTIF_PCT,
    ROUND(100.0 * COUNT(CASE WHEN s.IS_ON_TIME_OUTBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS OUTBOUND_OTD_PCT
FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS s
JOIN SC_ONTOLOGY.CURATED.DIM_CUSTOMER c ON s.CUSTOMER_KEY = c.CUSTOMER_KEY
JOIN SC_ONTOLOGY.CURATED.DIM_DATE d ON s.ORDER_DATE_KEY = d.DATE_KEY
GROUP BY 1, 2
ORDER BY 1, 2;

-- ==============================================================================
-- TEST 10: Carrier Delay Rate vs Freight Shipping Cost (Delivered-Only Denominator & Strict Delayed Numerator)
-- ==============================================================================
SELECT 
    c.CARRIER_NAME,
    c.TRANSPORT_MODE,
    COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END) AS DELIVERED_LINES,
    COUNT(CASE WHEN s.IS_DELIVERED = TRUE AND s.IS_ON_TIME_OUTBOUND = FALSE THEN 1 END) AS DELAYED_LINES,
    ROUND(100.0 * COUNT(CASE WHEN s.IS_DELIVERED = TRUE AND s.IS_ON_TIME_OUTBOUND = FALSE THEN 1 END) / NULLIF(COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS DELAY_RATE_PCT,
    ROUND(SUM(s.FREIGHT_COST_USD), 2) AS TOTAL_FREIGHT_COST_USD,
    ROUND(AVG(s.FREIGHT_COST_USD), 2) AS AVG_FREIGHT_COST_PER_LINE
FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS s
JOIN SC_ONTOLOGY.CURATED.DIM_CARRIER c ON s.CARRIER_KEY = c.CARRIER_KEY
GROUP BY 1, 2
ORDER BY DELAY_RATE_PCT DESC;

-- ==============================================================================
-- 3 PERSONA SQL LOGIC & METRIC DEFINITION PARITY CHECK (Orders Placed in Q3 2026)
-- ==============================================================================

-- Persona 1: Planner ("What was our promised-date delivery performance in Q3?")
SELECT 
    'Planner Persona' AS PERSONA,
    'Promised-date delivery performance in Q3' AS QUESTION_PHRASING,
    'outbound_otd_pct' AS CANONICAL_METRIC,
    '100.0 * COUNT(is_on_time_outbound) / COUNT(is_delivered)' AS FORMULA,
    'CURATED.FACT_OUTBOUND_SHIPMENTS (Orders placed in Q3 2026)' AS LINEAGE_SCOPE,
    COUNT(CASE WHEN IS_DELIVERED = TRUE THEN 1 END) AS DELIVERED_LINES,
    COUNT(CASE WHEN IS_ON_TIME_OUTBOUND = TRUE THEN 1 END) AS ON_TIME_LINES,
    ROUND(100.0 * COUNT(CASE WHEN IS_ON_TIME_OUTBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS RESULT_PCT
FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS
WHERE ORDER_DATE BETWEEN '2026-07-01' AND '2026-09-30'

UNION ALL

-- Persona 2: Procurement ("How timely were customer deliveries last quarter?")
SELECT 
    'Procurement Persona',
    'Customer delivery timeliness last quarter',
    'outbound_otd_pct',
    '100.0 * COUNT(is_on_time_outbound) / COUNT(is_delivered)',
    'CURATED.FACT_OUTBOUND_SHIPMENTS (Orders placed in Q3 2026)',
    COUNT(CASE WHEN IS_DELIVERED = TRUE THEN 1 END),
    COUNT(CASE WHEN IS_ON_TIME_OUTBOUND = TRUE THEN 1 END),
    ROUND(100.0 * COUNT(CASE WHEN IS_ON_TIME_OUTBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN IS_DELIVERED = TRUE THEN 1 END), 0), 2)
FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS
WHERE ORDER_DATE BETWEEN '2026-07-01' AND '2026-09-30'

UNION ALL

-- Persona 3: Logistics ("What percentage of delivered order lines met the promised date in Q3?")
SELECT 
    'Logistics Persona',
    'Percentage of delivered order lines meeting promised date in Q3',
    'outbound_otd_pct',
    '100.0 * COUNT(is_on_time_outbound) / COUNT(is_delivered)',
    'CURATED.FACT_OUTBOUND_SHIPMENTS (Orders placed in Q3 2026)',
    COUNT(CASE WHEN IS_DELIVERED = TRUE THEN 1 END),
    COUNT(CASE WHEN IS_ON_TIME_OUTBOUND = TRUE THEN 1 END),
    ROUND(100.0 * COUNT(CASE WHEN IS_ON_TIME_OUTBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN IS_DELIVERED = TRUE THEN 1 END), 0), 2)
FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS
WHERE ORDER_DATE BETWEEN '2026-07-01' AND '2026-09-30';
