-- ==============================================================================
-- 16_metric_registry.sql
-- Governed Metric Registry (Single Source of Truth)
-- ==============================================================================

USE DATABASE SC_ONTOLOGY;
CREATE SCHEMA IF NOT EXISTS GOVERNANCE;
USE SCHEMA GOVERNANCE;
USE WAREHOUSE HACK_WH;

CREATE OR REPLACE TABLE GOVERNANCE.METRIC_REGISTRY (
    METRIC_KEY VARCHAR(50) PRIMARY KEY,
    METRIC_NAME VARCHAR(100) NOT NULL,
    BUSINESS_DEFINITION VARCHAR(1000) NOT NULL,
    EXACT_SQL_FORMULA VARCHAR(2000) NOT NULL,
    GRAIN VARCHAR(100) NOT NULL,
    OWNER_TEAM VARCHAR(100) NOT NULL,
    SOURCE_TABLES ARRAY NOT NULL,
    VERIFIED_QUERY_REF VARCHAR(100),
    DEFINITION_VERSION NUMBER(3,0) DEFAULT 1,
    APPROVED_BY VARCHAR(100) DEFAULT 'Data Governance Council',
    APPROVED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    IS_ACTIVE BOOLEAN DEFAULT TRUE
);

-- Seed the 8 Canonical Metrics from Glossary / Semantic View
INSERT INTO GOVERNANCE.METRIC_REGISTRY (
    METRIC_KEY, METRIC_NAME, BUSINESS_DEFINITION, EXACT_SQL_FORMULA, GRAIN, OWNER_TEAM, SOURCE_TABLES, VERIFIED_QUERY_REF, DEFINITION_VERSION, APPROVED_BY, APPROVED_AT, IS_ACTIVE
)
SELECT 'MTR-OUTBOUND-OTD', 'Outbound OTD %', 
       '% of completed customer shipment lines delivered on or before promised delivery date among delivered lines',
       '100.0 * COUNT(CASE WHEN is_delivered = TRUE AND actual_delivery_date_key <= promised_delivery_date_key THEN 1 END) / NULLIF(COUNT(CASE WHEN is_delivered = TRUE THEN 1 END), 0)',
       'Customer / Plant / Month', 'Logistics', ARRAY_CONSTRUCT('CURATED.FACT_OUTBOUND_SHIPMENTS', 'CURATED.DIM_DATE', 'CURATED.DIM_PLANT'), 'vqr_01_monthly_outbound_otd', 1, 'Data Governance Council', CURRENT_TIMESTAMP(), TRUE
UNION ALL
SELECT 'MTR-INBOUND-OTIF', 'Inbound OTIF %', 
       '% of received purchase order lines delivered both On-Time and 100% In-Full',
       '100.0 * COUNT(CASE WHEN is_delivered = TRUE AND delivery_date_key <= promised_date_key AND received_qty >= order_qty THEN 1 END) / NULLIF(COUNT(CASE WHEN is_delivered = TRUE THEN 1 END), 0)',
       'Supplier / Part / Month', 'Procurement', ARRAY_CONSTRUCT('CURATED.FACT_PURCHASE_ORDERS', 'CURATED.DIM_SUPPLIER', 'CURATED.DIM_PART'), 'vqr_02_inbound_otif_by_tier', 1, 'Data Governance Council', CURRENT_TIMESTAMP(), TRUE
UNION ALL
SELECT 'MTR-OUTBOUND-OTIF', 'Outbound OTIF %', 
       '% of customer order lines delivered both On-Time and 100% In-Full',
       '100.0 * COUNT(CASE WHEN is_delivered = TRUE AND actual_delivery_date_key <= promised_delivery_date_key AND delivered_qty >= ordered_qty THEN 1 END) / NULLIF(COUNT(CASE WHEN is_delivered = TRUE THEN 1 END), 0)',
       'Customer / Product / Month', 'Planning', ARRAY_CONSTRUCT('CURATED.FACT_OUTBOUND_SHIPMENTS', 'CURATED.DIM_CUSTOMER', 'CURATED.DIM_PRODUCT'), 'vqr_09_customer_segment_otif_by_quarter', 1, 'Data Governance Council', CURRENT_TIMESTAMP(), TRUE
UNION ALL
SELECT 'MTR-INBOUND-OTD', 'Inbound OTD %', 
       '% of received purchase order lines delivered on or before agreed promised date',
       '100.0 * COUNT(CASE WHEN is_delivered = TRUE AND delivery_date_key <= promised_date_key THEN 1 END) / NULLIF(COUNT(CASE WHEN is_delivered = TRUE THEN 1 END), 0)',
       'Supplier / Plant / Month', 'Procurement', ARRAY_CONSTRUCT('CURATED.FACT_PURCHASE_ORDERS', 'CURATED.DIM_SUPPLIER', 'CURATED.DIM_PLANT'), 'vqr_07_bottom_5_suppliers_inbound_otd', 1, 'Data Governance Council', CURRENT_TIMESTAMP(), TRUE
UNION ALL
SELECT 'MTR-DAYS-INVENTORY', 'Days of Inventory', 
       'Number of days current inventory will sustain trailing 30-day consumption rate',
       'SUM(on_hand_qty) / NULLIF(SUM(avg_daily_consumption_30d), 0)',
       'Plant / Part', 'Planning', ARRAY_CONSTRUCT('CURATED.INVENTORY_POSITION_CURRENT', 'CURATED.FACT_INVENTORY_DAILY', 'CURATED.DIM_PART'), 'vqr_04_doi_by_plant_and_category', 1, 'Data Governance Council', CURRENT_TIMESTAMP(), TRUE
UNION ALL
SELECT 'MTR-UNIT-LANDED-COST', 'Unit Landed Cost', 
       'All-in unit procurement cost including extended purchase price, inbound freight, customs duty, and receiving handling',
       '(SUM(extended_purchase_cost_usd) + SUM(inbound_freight_usd) + SUM(duty_cost_usd) + SUM(handling_cost_usd)) / NULLIF(SUM(received_qty), 0)',
       'Part / Plant / Quarter', 'Procurement', ARRAY_CONSTRUCT('CURATED.FACT_PURCHASE_ORDERS', 'CURATED.DIM_PART'), 'vqr_03_top_5_parts_landed_cost', 1, 'Data Governance Council', CURRENT_TIMESTAMP(), TRUE
UNION ALL
SELECT 'MTR-LEAD-TIME-VAR', 'Supplier Lead Time Variance', 
       'Average calendar days variance between actual delivery lead time and agreed contractual SLA lead time',
       'AVG(CASE WHEN is_delivered = TRUE THEN lead_time_actual_days - lead_time_contract_days END)',
       'Supplier / Part', 'Procurement', ARRAY_CONSTRUCT('CURATED.FACT_PURCHASE_ORDERS', 'CURATED.DIM_SUPPLIER_PART_SLA'), 'vqr_02_inbound_otif_by_tier', 1, 'Data Governance Council', CURRENT_TIMESTAMP(), TRUE
UNION ALL
SELECT 'MTR-BACKORDER-RATE', 'Backorder Rate %', 
       '% of customer shipment lines delayed due to product or component backorders',
       '100.0 * COUNT(CASE WHEN is_backordered = TRUE THEN 1 END) / NULLIF(COUNT(shipment_line_key), 0)',
       'Product / Plant / Month', 'Planning', ARRAY_CONSTRUCT('CURATED.FACT_OUTBOUND_SHIPMENTS', 'CURATED.DIM_PRODUCT'), 'vqr_05_backorder_rate_by_family', 1, 'Data Governance Council', CURRENT_TIMESTAMP(), TRUE;
