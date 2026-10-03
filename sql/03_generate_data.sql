-- ==============================================================================
-- 03_generate_data.sql
-- Deterministic Synthetic Data Generator Stored Procedure for Apex Industrial
-- ==============================================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA RAW;
USE WAREHOUSE HACK_WH;

CREATE OR REPLACE PROCEDURE RAW.SP_GENERATE_SYNTHETIC_SUPPLY_CHAIN_DATA()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    -- 1. Truncate all raw tables to ensure deterministic and idempotent execution
    TRUNCATE TABLE RAW.FX_RATES;
    TRUNCATE TABLE RAW.UOM_CONVERSIONS;
    TRUNCATE TABLE RAW.ERP_PLANTS;
    TRUNCATE TABLE RAW.ERP_SUPPLIERS;
    TRUNCATE TABLE RAW.ERP_PARTS;
    TRUNCATE TABLE RAW.ERP_PRODUCTS;
    TRUNCATE TABLE RAW.ERP_CUSTOMERS;
    TRUNCATE TABLE RAW.LOGISTICS_CARRIERS;
    TRUNCATE TABLE RAW.ERP_BILL_OF_MATERIALS;
    TRUNCATE TABLE RAW.ERP_PURCHASE_ORDERS;
    TRUNCATE TABLE RAW.ERP_GOODS_RECEIPTS;
    TRUNCATE TABLE RAW.ERP_SALES_ORDERS;
    TRUNCATE TABLE RAW.ERP_SALES_ORDER_LINES;
    TRUNCATE TABLE RAW.ERP_INVENTORY_SNAPSHOTS;
    TRUNCATE TABLE RAW.LOGISTICS_SHIPMENTS;
    TRUNCATE TABLE RAW.LOGISTICS_SHIPMENT_LINES;
    TRUNCATE TABLE RAW.SUPPLIER_PORTAL_COMMITS;
    TRUNCATE TABLE RAW.IOT_TELEMETRY;
    TRUNCATE TABLE RAW.SUPPLIER_CONTRACTS;

    -- 2. Populate FX Reference Rates (Oct 2025 - Sep 2026)
    INSERT INTO RAW.FX_RATES (YEAR_MONTH, BASE_CURRENCY, TARGET_CURRENCY, EXCHANGE_RATE)
    SELECT m.ym, c.curr, 'USD',
           CASE 
             WHEN c.curr = 'USD' THEN 1.000000
             WHEN c.curr = 'EUR' THEN 1.085000 + (ROW_NUMBER() OVER (PARTITION BY c.curr ORDER BY m.ym) * 0.002)
             WHEN c.curr = 'VND' THEN 0.000040 + (ROW_NUMBER() OVER (PARTITION BY c.curr ORDER BY m.ym) * 0.0000001)
           END
    FROM (
        SELECT TO_VARCHAR(DATEADD('month', SEQ4(), '2025-10-01'::DATE), 'YYYY-MM') AS ym
        FROM TABLE(GENERATOR(ROWCOUNT => 12))
    ) m
    CROSS JOIN (
        SELECT 'USD' AS curr UNION ALL SELECT 'EUR' UNION ALL SELECT 'VND'
    ) c;

    -- 3. Populate UOM Conversions
    INSERT INTO RAW.UOM_CONVERSIONS (FROM_UOM, TO_UOM, CONVERSION_FACTOR, CATEGORY) VALUES
        ('KG', 'LBS', 2.204620, 'WEIGHT'),
        ('LBS', 'KG', 0.453592, 'WEIGHT'),
        ('PCS', 'EA', 1.000000, 'COUNT'),
        ('EA', 'PCS', 1.000000, 'COUNT'),
        ('BOX10', 'EA', 10.000000, 'COUNT'),
        ('BOX100', 'EA', 100.000000, 'COUNT');

    -- 4. Populate Master Plants (4 Plants in 3 Countries)
    INSERT INTO RAW.ERP_PLANTS (PLANT_CODE, PLANT_NAME, CITY, COUNTRY_CODE, REGION, TZ_OFFSET) VALUES
        ('US-TX-01', 'Austin Advanced Manufacturing Site', 'Austin', 'USA', 'AMER', 'UTC-5'),
        ('DE-BY-02', 'Munich Precision Engineering Plant', 'Munich', 'DEU', 'EMEA', 'UTC+1'),
        ('VN-BD-03', 'Binh Duong High-Volume Assembly Site', 'Binh Duong', 'VNM', 'APAC', 'UTC+7'),
        ('US-OH-04', 'Columbus Heavy Components Facility', 'Columbus', 'USA', 'AMER', 'UTC-5');

    -- 5. Populate Master Suppliers (30 Suppliers, including SUP-104 Titan Micro-Foundry)
    INSERT INTO RAW.ERP_SUPPLIERS (VENDOR_ID, VENDOR_NAME, TIER_CODE, COUNTRY, STATUS_FLAG)
    SELECT 
        'SUP-' || LPAD(100 + seq, 3, '0') AS VENDOR_ID,
        CASE 
            WHEN seq = 4 THEN 'Titan Micro-Foundry'
            WHEN seq = 1 THEN 'Global Precision Alloys'
            WHEN seq = 2 THEN 'Silicon Motion Technologies'
            WHEN seq = 3 THEN 'Rheinland Machining GmbH'
            WHEN seq = 5 THEN 'Saigon Fasteners Co'
            WHEN seq = 6 THEN 'Nordic Sensor Systems'
            WHEN seq = 7 THEN 'Bavaria Hydraulics AG'
            WHEN seq = 8 THEN 'Texas Power Components'
            ELSE 'Apex Approved Vendor ' || seq
        END AS VENDOR_NAME,
        CASE WHEN seq <= 5 THEN 'Tier-1 Strategic' WHEN seq <= 20 THEN 'Tier-2 Preferred' ELSE 'Tier-3 Tactical' END AS TIER_CODE,
        CASE WHEN seq IN (1, 8, 12, 16, 25) THEN 'USA' WHEN seq IN (3, 7, 9, 14, 21) THEN 'Germany' WHEN seq IN (4, 5, 10, 18, 28) THEN 'Vietnam' ELSE 'Japan' END AS COUNTRY,
        'ACTIVE' AS STATUS_FLAG
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY 1) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 30)));

    -- 6. Populate Master Parts (200 Parts)
    INSERT INTO RAW.ERP_PARTS (MATERIAL_NO, DESCRIPTION, COMMODITY_GROUP, BASE_UOM, STD_COST_LOCAL, LOCAL_CURR, IS_CRITICAL_FLAG)
    SELECT 
        CASE 
            WHEN seq = 88 THEN 'PART-TF-88'
            WHEN seq = 2 THEN 'PART-MC-02'
            ELSE 'PART-' || LPAD(seq, 3, '0')
        END AS MATERIAL_NO,
        CASE 
            WHEN seq = 88 THEN 'Titanium High-Tensile Fastener M12'
            WHEN seq = 2 THEN 'Advanced Microcontroller IC Chipset 32-bit'
            ELSE 'Industrial Component Spec ' || seq
        END AS DESCRIPTION,
        CASE 
            WHEN seq <= 40 THEN 'Electronics'
            WHEN seq <= 100 THEN 'Fasteners'
            WHEN seq <= 160 THEN 'Precision Mechanical'
            ELSE 'Raw Metals'
        END AS COMMODITY_GROUP,
        CASE WHEN seq <= 40 THEN 'EA' WHEN seq <= 100 THEN 'PCS' ELSE 'KG' END AS BASE_UOM,
        ROUND(10.0 + (MOD(seq * 17, 450) + 0.5), 2) AS STD_COST_LOCAL,
        CASE WHEN MOD(seq, 3) = 0 THEN 'EUR' WHEN MOD(seq, 3) = 1 THEN 'USD' ELSE 'VND' END AS LOCAL_CURR,
        CASE WHEN seq IN (2, 88, 15, 45, 120, 150) THEN 'Y' ELSE 'N' END AS IS_CRITICAL_FLAG
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY 1) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 200)));

    -- 7. Populate Master Products (50 Finished Products)
    INSERT INTO RAW.ERP_PRODUCTS (MATNR_FG, PRODUCT_NAME, PROD_FAMILY, LIST_PRICE_USD)
    SELECT 
        CASE WHEN seq = 1 THEN 'APEX-ROBOTIC-ARM-V2' ELSE 'PROD-' || LPAD(seq, 3, '0') END AS MATNR_FG,
        CASE WHEN seq = 1 THEN 'Apex 6-Axis Articulated Industrial Robotic Arm' ELSE 'Apex Industrial Machine Model ' || seq END AS PRODUCT_NAME,
        CASE WHEN seq <= 15 THEN 'Industrial Robotics' WHEN seq <= 35 THEN 'Fluid Automation' ELSE 'Industrial Power Drives' END AS PROD_FAMILY,
        ROUND(500.0 + (seq * 85.5), 2) AS LIST_PRICE_USD
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY 1) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 50)));

    -- 8. Populate Master Customers (100 Customers)
    INSERT INTO RAW.ERP_CUSTOMERS (KUNNR, NAME_ORG, INDUSTRY_SECTOR, COUNTRY, REGION)
    SELECT 
        'CUST-' || LPAD(seq, 3, '0') AS KUNNR,
        'Enterprise Client ' || seq || ' Corp' AS NAME_ORG,
        CASE WHEN MOD(seq, 3) = 0 THEN 'Automotive OEM' WHEN MOD(seq, 3) = 1 THEN 'Aerospace Systems' ELSE 'Heavy Machinery' END AS INDUSTRY_SECTOR,
        CASE WHEN MOD(seq, 4) = 0 THEN 'USA' WHEN MOD(seq, 4) = 1 THEN 'Germany' WHEN MOD(seq, 4) = 2 THEN 'Vietnam' ELSE 'United Kingdom' END AS COUNTRY,
        CASE WHEN MOD(seq, 4) IN (0, 3) THEN 'AMER' WHEN MOD(seq, 4) = 1 THEN 'EMEA' ELSE 'APAC' END AS REGION
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY 1) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 100)));

    -- 9. Populate Carriers (8 Carriers, including CARR-04 Pacific Express)
    INSERT INTO RAW.LOGISTICS_CARRIERS (CARRIER_CODE, CARRIER_NAME, TRANSPORT_MODE, RELIABILITY_RATING) VALUES
        ('CARR-01', 'Apex Air Express', 'Air', 0.96),
        ('CARR-02', 'Continental Freightways', 'Road', 0.92),
        ('CARR-03', 'Trans-Europa Logistics', 'Rail', 0.89),
        ('CARR-04', 'Pacific Express Ocean Lines', 'Ocean', 0.72),
        ('CARR-05', 'Atlantic Cargo Express', 'Ocean', 0.91),
        ('CARR-06', 'Vanguard Fast Roadways', 'Road', 0.94),
        ('CARR-07', 'Global Intermodal Systems', 'Intermodal', 0.88),
        ('CARR-08', 'Mekong Regional Express', 'Road', 0.87);

    -- 10. Populate Bill of Materials (BOM) linking Products to Parts
    INSERT INTO RAW.ERP_BILL_OF_MATERIALS (BOM_ID, PARENT_MATNR, CHILD_MATNR, COMPONENT_QTY, UOM, SCRAP_PCT)
    SELECT 
        'BOM-' || p.seq || '-' || c.seq AS BOM_ID,
        CASE WHEN p.seq = 1 THEN 'APEX-ROBOTIC-ARM-V2' ELSE 'PROD-' || LPAD(p.seq, 3, '0') END AS PARENT_MATNR,
        CASE 
            WHEN p.seq = 1 AND c.seq = 1 THEN 'PART-MC-02'
            WHEN p.seq = 1 AND c.seq = 2 THEN 'PART-TF-88'
            WHEN (1 + MOD(p.seq * 7 + c.seq * 13, 199)) = 2 THEN 'PART-MC-02'
            WHEN (1 + MOD(p.seq * 7 + c.seq * 13, 199)) = 88 THEN 'PART-TF-88'
            ELSE 'PART-' || LPAD(1 + MOD(p.seq * 7 + c.seq * 13, 199), 3, '0')
        END AS CHILD_MATNR,
        ROUND(1.0 + (c.seq * 0.5), 1) AS COMPONENT_QTY,
        'EA' AS UOM,
        0.02 AS SCRAP_PCT
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY 1) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 50))) p
    CROSS JOIN (SELECT ROW_NUMBER() OVER (ORDER BY 1) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 5))) c;

    -- 11. Populate Supplier Contracts & SLA Documents (30 Contracts)
    INSERT INTO RAW.SUPPLIER_CONTRACTS (CONTRACT_ID, SUPPLIER_CODE, SUPPLIER_NAME, CONTRACT_TITLE, EFFECTIVE_DATE, EXPIRATION_DATE, TARGET_OTIF_PCT, CONTRACT_LEAD_TIME_DAYS, PENALTY_TERMS, FULL_CONTRACT_TEXT)
    SELECT 
        'CTR-2025-' || LPAD(seq, 3, '0') AS CONTRACT_ID,
        'SUP-' || LPAD(100 + seq, 3, '0') AS SUPPLIER_CODE,
        CASE WHEN seq = 4 THEN 'Titan Micro-Foundry' ELSE 'Apex Approved Vendor ' || seq END AS SUPPLIER_NAME,
        'Master Goods and Services Supply Agreement 2025-2026' AS CONTRACT_TITLE,
        '2025-10-01'::DATE AS EFFECTIVE_DATE,
        '2027-09-30'::DATE AS EXPIRATION_DATE,
        CASE WHEN seq = 4 THEN 95.00 ELSE 92.00 END AS TARGET_OTIF_PCT,
        CASE WHEN seq = 4 THEN 21 ELSE 14 END AS CONTRACT_LEAD_TIME_DAYS,
        CASE 
            WHEN seq = 4 THEN 'Section 4.2: Supplier agrees to maintain ≥95.0% Inbound OTIF. Inbound OTIF falling below 80.0% incurs an automatic 5.0% invoice rebate penalty across all impacted purchase orders and triggers mandatory executive review within 48 hours.'
            ELSE 'Standard SLA Terms: Supplier warrants minimum 90.0% OTIF. Chronic non-compliance subject to 2.0% billing penalty.'
        END AS PENALTY_TERMS,
        'MASTER SUPPLY AGREEMENT - CONTRACT ' || 'CTR-2025-' || LPAD(seq, 3, '0') || '\n\n' ||
        'PARTIES: Apex Industrial Components and ' || (CASE WHEN seq = 4 THEN 'Titan Micro-Foundry' ELSE 'Apex Approved Vendor ' || seq END) || '.\n' ||
        '1. SCOPE: Supply of certified components across global manufacturing plants.\n' ||
        '2. LEAD TIME: Agreed standard delivery lead time is ' || (CASE WHEN seq = 4 THEN 21 ELSE 14 END) || ' calendar days from PO dispatch.\n' ||
        '3. QUALITY & INSPECTION: All shipments subject to ISO 9001 receiving inspection standards.\n' ||
        '4. DELIVERY SLA & PERFORMANCE PENALTIES:\n' ||
        CASE 
            WHEN seq = 4 THEN 'Section 4.2: Supplier shall maintain a minimum of 95.0% On-Time In-Full (OTIF) rate. If monthly Inbound OTIF drops below 80.0%, Buyer reserves the right to apply an immediate 5.0% invoice credit penalty and initiate Level-2 Supplier Escalation.'
            ELSE 'Section 4.1: Supplier shall target 92.0% OTIF delivery compliance. Failure to meet standards over two consecutive quarters triggers commercial review.'
        END || '\n5. GOVERNING LAW: Jurisdiction of Singapore International Arbitration Centre.' AS FULL_CONTRACT_TEXT
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY 1) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 30)));

    -- 12. Populate Purchase Orders & Goods Receipts (5,000 Inbound Lines)
    -- Deterministic generation across 365 days (2025-10-01 to 2026-09-30)
    INSERT INTO RAW.ERP_PURCHASE_ORDERS (PO_LINE_ID, PO_HEADER_NO, VENDOR_CODE, MATERIAL_NUM, PLANT_CODE, ORDER_DATE_STR, PROMISED_DATE_STR, ORDER_QTY, UNIT_COST_LOCAL, CURR_CODE)
    SELECT 
        'POL-' || LPAD(seq, 5, '0') AS PO_LINE_ID,
        'PO-' || LPAD(1000 + FLOOR(seq / 2), 5, '0') AS PO_HEADER_NO,
        CASE 
            WHEN MOD(seq, 10) = 4 THEN 'SUP-104' -- Exactly 500 lines for Titan Micro-Foundry
            ELSE 'SUP-' || LPAD(101 + MOD(seq * 3, 28) + CASE WHEN (101 + MOD(seq * 3, 28)) >= 104 THEN 1 ELSE 0 END, 3, '0')
        END AS VENDOR_CODE,
        CASE 
            WHEN MOD(seq, 10) = 4 THEN 'PART-TF-88' -- Titan Fasteners
            WHEN MOD(seq, 20) = 2 OR (1 + MOD(seq * 7, 199)) = 2 THEN 'PART-MC-02'
            WHEN (1 + MOD(seq * 7, 199)) = 88 THEN 'PART-TF-88'
            ELSE 'PART-' || LPAD(1 + MOD(seq * 7, 199), 3, '0')
        END AS MATERIAL_NUM,
        CASE WHEN MOD(seq, 4) = 0 THEN 'US-TX-01' WHEN MOD(seq, 4) = 1 THEN 'DE-BY-02' WHEN MOD(seq, 4) = 2 THEN 'VN-BD-03' ELSE 'US-OH-04' END AS PLANT_CODE,
        TO_VARCHAR(DATEADD('day', MOD(seq * 13, 360), '2025-10-01'::DATE), 'YYYY-MM-DD') AS ORDER_DATE_STR,
        TO_VARCHAR(DATEADD('day', MOD(seq * 13, 360) + 14, '2025-10-01'::DATE), 'YYYY-MM-DD') AS PROMISED_DATE_STR,
        ROUND(50 + MOD(seq * 19, 450), 0) AS ORDER_QTY,
        ROUND(15.0 + MOD(seq * 11, 200), 2) AS UNIT_COST_LOCAL,
        CASE WHEN MOD(seq, 4) = 1 THEN 'EUR' WHEN MOD(seq, 4) = 2 THEN 'VND' ELSE 'USD' END AS CURR_CODE
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY 1) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 5000)));

    -- Goods Receipts (conforms inbound delivery, injects Titan Micro-Foundry OTIF = 64.0% & +14.0d delay)
    INSERT INTO RAW.ERP_GOODS_RECEIPTS (GR_LINE_ID, PO_LINE_REF, RECEIPT_DATE_STR, QUANTITY_RCVD, INSPECTION_CODE, INBOUND_FREIGHT_LOCAL, HANDLING_COST_LOCAL, DUTY_COST_LOCAL)
    SELECT 
        'GRL-' || LPAD(seq, 5, '0') AS GR_LINE_ID,
        'POL-' || LPAD(seq, 5, '0') AS PO_LINE_REF,
        CASE 
            -- Open/in-transit orders (1%)
            WHEN MOD(seq, 100) = 0 THEN NULL 
            -- Titan Micro-Foundry (SUP-104): Exactly 36% late delivery (180 out of 500 lines) with +14 days delay
            WHEN MOD(seq, 10) = 4 AND MOD(FLOOR(seq / 10), 100) < 36 THEN 
                TO_VARCHAR(DATEADD('day', MOD(seq * 13, 360) + 28, '2025-10-01'::DATE), 'YYYY-MM-DD')
            -- Titan Micro-Foundry on-time (64%)
            WHEN MOD(seq, 10) = 4 THEN 
                TO_VARCHAR(DATEADD('day', MOD(seq * 13, 360) + 13, '2025-10-01'::DATE), 'YYYY-MM-DD')
            -- Normal supplier minor delay (8% late)
            WHEN MOD(seq, 12) = 0 THEN 
                TO_VARCHAR(DATEADD('day', MOD(seq * 13, 360) + 18, '2025-10-01'::DATE), 'YYYY-MM-DD')
            -- Normal supplier on-time
            ELSE 
                TO_VARCHAR(DATEADD('day', MOD(seq * 13, 360) + 12, '2025-10-01'::DATE), 'YYYY-MM-DD')
        END AS RECEIPT_DATE_STR,
        CASE 
            WHEN MOD(seq, 100) = 0 THEN 0
            -- Titan Micro-Foundry partial delivery on 2% of lines (lines ending in 4 with index 30..31)
            WHEN MOD(seq, 10) = 4 AND MOD(FLOOR(seq / 10), 100) BETWEEN 30 AND 31 THEN ROUND((50 + MOD(seq * 19, 450)) * 0.85, 0)
            ELSE (50 + MOD(seq * 19, 450))
        END AS QUANTITY_RCVD,
        'PASS' AS INSPECTION_CODE,
        ROUND(150.0 + MOD(seq * 7, 300), 2) AS INBOUND_FREIGHT_LOCAL,
        ROUND(40.0 + MOD(seq * 3, 80), 2) AS HANDLING_COST_LOCAL,
        ROUND(60.0 + MOD(seq * 5, 120), 2) AS DUTY_COST_LOCAL
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY 1) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 5000)));

    -- 13. Populate Supplier Portal Commits (Messy vendor codes & ACK dates)
    INSERT INTO RAW.SUPPLIER_PORTAL_COMMITS (COMMIT_ID, PORTAL_SUPP_ID, PO_LINE_REF, ACKNOWLEDGED_DATE_STR, SUPPLIER_PROMISED_DATE, COMMITTED_QTY)
    SELECT 
        'COM-' || LPAD(seq, 5, '0') AS COMMIT_ID,
        CASE WHEN MOD(seq, 10) = 4 THEN 'VEND_PORTAL_104' ELSE 'VEND_PORTAL_' || LPAD(100 + MOD(seq * 3, 30), 3, '0') END AS PORTAL_SUPP_ID,
        'POL-' || LPAD(seq, 5, '0') AS PO_LINE_REF,
        TO_VARCHAR(DATEADD('day', MOD(seq * 13, 360) + 2, '2025-10-01'::DATE), 'DD/MM/YYYY') AS ACKNOWLEDGED_DATE_STR,
        TO_VARCHAR(DATEADD('day', MOD(seq * 13, 360) + 15, '2025-10-01'::DATE), 'YYYY-MM-DD') AS SUPPLIER_PROMISED_DATE,
        (50 + MOD(seq * 19, 450)) AS COMMITTED_QTY
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY 1) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 5000)));

    -- 14. Populate Daily Inventory Snapshots (73,000 rows across 365 days)
    -- Injects August 10-13 Stockout for PART-MC-02 at Plant US-TX-01
    INSERT INTO RAW.ERP_INVENTORY_SNAPSHOTS (INV_SNAP_ID, SNAP_DATE_STR, PLANT_CODE, MATERIAL_NO, STOCK_ON_HAND, SAFETY_STOCK_MIN, DAILY_USAGE_30D)
    SELECT 
        'INV-' || p.plant_code || '-' || m.mat_no || '-' || d.d_str AS INV_SNAP_ID,
        d.d_str AS SNAP_DATE_STR,
        p.plant_code,
        m.mat_no,
        CASE 
            -- AUGUST STOCKOUT: PART-MC-02 at US-TX-01 between Aug 10 and Aug 13, 2026
            WHEN p.plant_code = 'US-TX-01' AND m.mat_no = 'PART-MC-02' AND d.d_date BETWEEN '2026-08-10'::DATE AND '2026-08-13'::DATE THEN 0.00
            ELSE ROUND(200.0 + MOD(ABS(HASH(p.plant_code, m.mat_no, d.d_str)), 800), 2)
        END AS STOCK_ON_HAND,
        150.00 AS SAFETY_STOCK_MIN,
        ROUND(25.0 + MOD(ABS(HASH(m.mat_no)), 30), 2) AS DAILY_USAGE_30D
    FROM (
        SELECT 'US-TX-01' AS plant_code UNION ALL SELECT 'DE-BY-02' UNION ALL SELECT 'VN-BD-03' UNION ALL SELECT 'US-OH-04'
    ) p
    CROSS JOIN (
        SELECT CASE WHEN seq = 2 THEN 'PART-MC-02' WHEN seq = 88 THEN 'PART-TF-88' ELSE 'PART-' || LPAD(seq, 3, '0') END AS mat_no
        FROM (SELECT ROW_NUMBER() OVER (ORDER BY 1) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 50)))
    ) m
    CROSS JOIN (
        SELECT 
            TO_VARCHAR(DATEADD('day', SEQ4(), '2025-10-01'::DATE), 'YYYY-MM-DD') AS d_str,
            DATEADD('day', SEQ4(), '2025-10-01'::DATE) AS d_date
        FROM TABLE(GENERATOR(ROWCOUNT => 365))
    ) d;

    -- 15. Populate Sales Orders & Sales Order Lines (5,000 Orders, 15,000 Lines)
    INSERT INTO RAW.ERP_SALES_ORDERS (SO_NUMBER, CUST_ID, SO_DATE_STR, REQ_DELIV_DATE_STR, PROMISED_DELIV_DATE_STR, HEADER_STATUS, TOTAL_VAL_USD)
    SELECT 
        'SO-' || LPAD(seq, 5, '0') AS SO_NUMBER,
        'CUST-' || LPAD(1 + MOD(seq * 7, 100), 3, '0') AS CUST_ID,
        TO_VARCHAR(DATEADD('day', MOD(seq * 17, 355), '2025-10-01'::DATE), 'YYYY-MM-DD') AS SO_DATE_STR,
        TO_VARCHAR(DATEADD('day', MOD(seq * 17, 355) + 10, '2025-10-01'::DATE), 'YYYY-MM-DD') AS REQ_DELIV_DATE_STR,
        TO_VARCHAR(DATEADD('day', MOD(seq * 17, 355) + 12, '2025-10-01'::DATE), 'YYYY-MM-DD') AS PROMISED_DELIV_DATE_STR,
        'CLOSED' AS HEADER_STATUS,
        ROUND(1200.0 + MOD(seq * 23, 15000), 2) AS TOTAL_VAL_USD
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY 1) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 5000)));

    INSERT INTO RAW.ERP_SALES_ORDER_LINES (SO_LINE_ID, SO_NUMBER, PRODUCT_SKU, ORDER_QTY, UNIT_PRICE_USD, PLANT_FULFILL)
    SELECT 
        'SOL-' || LPAD(seq, 5, '0') AS SO_LINE_ID,
        'SO-' || LPAD(1 + FLOOR((seq - 1) / 3), 5, '0') AS SO_NUMBER,
        CASE 
            WHEN MOD(seq, 10) = 1 OR (1 + MOD(seq * 3, 50)) = 1 THEN 'APEX-ROBOTIC-ARM-V2' 
            ELSE 'PROD-' || LPAD(1 + MOD(seq * 3, 50), 3, '0') 
        END AS PRODUCT_SKU,
        ROUND(2.0 + MOD(seq * 5, 20), 0) AS ORDER_QTY,
        ROUND(450.0 + MOD(seq * 17, 1500), 2) AS UNIT_PRICE_USD,
        CASE WHEN MOD(seq, 4) = 0 THEN 'US-TX-01' WHEN MOD(seq, 4) = 1 THEN 'DE-BY-02' WHEN MOD(seq, 4) = 2 THEN 'VN-BD-03' ELSE 'US-OH-04' END AS PLANT_FULFILL
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY 1) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 15000)));

    -- 16. Populate Logistics Shipments & Shipment Lines (5,000 Shipments, 15,000 Lines)
    INSERT INTO RAW.LOGISTICS_SHIPMENTS (SHIPMENT_NO, SO_HEADER_REF, CARRIER_ID, ORIGIN_PLANT, DEST_CUSTOMER, DISPATCH_TS_STR, DELIVERY_TS_STR, STATUS, FREIGHT_CHARGE_USD, HANDLING_CHARGE_USD, IS_BACKORDERED_FLAG)
    SELECT 
        'SHP-' || LPAD(seq, 5, '0') AS SHIPMENT_NO,
        'SO-' || LPAD(seq, 5, '0') AS SO_HEADER_REF,
        CASE 
            WHEN MOD(seq, 8) = 4 THEN 'CARR-04'
            ELSE 'CARR-0' || (1 + MOD(seq, 8))
        END AS CARRIER_ID,
        CASE WHEN MOD(seq, 4) = 0 THEN 'US-TX-01' WHEN MOD(seq, 4) = 1 THEN 'DE-BY-02' WHEN MOD(seq, 4) = 2 THEN 'VN-BD-03' ELSE 'US-OH-04' END AS ORIGIN_PLANT,
        'CUST-' || LPAD(1 + MOD(seq * 7, 100), 3, '0') AS DEST_CUSTOMER,
        CASE 
            WHEN MOD(seq, 6) = 0 THEN TO_VARCHAR(DATEADD('day', MOD(seq * 17, 355) + 14, '2025-10-01'::DATE), 'YYYY-MM-DD HH24:MI:SS')
            ELSE TO_VARCHAR(DATEADD('day', MOD(seq * 17, 355) + 3, '2025-10-01'::DATE), 'YYYY-MM-DD HH24:MI:SS')
        END AS DISPATCH_TS_STR,
        CASE 
            WHEN MOD(seq, 100) = 0 THEN NULL
            WHEN MOD(seq, 6) = 0 THEN TO_VARCHAR(DATEADD('day', MOD(seq * 17, 355) + 17, '2025-10-01'::DATE), 'YYYY-MM-DD HH24:MI:SS')
            WHEN MOD(seq, 8) = 4 AND MOD(seq * 17, 355) BETWEEN 273 AND 334 AND MOD(FLOOR(seq / 8), 100) < 42 THEN
                TO_VARCHAR(DATEADD('day', MOD(seq * 17, 355) + 18, '2025-10-01'::DATE), 'YYYY-MM-DD HH24:MI:SS')
            WHEN MOD(seq, 10) <= 7 THEN 
                TO_VARCHAR(DATEADD('day', MOD(seq * 17, 355) + 10, '2025-10-01'::DATE), 'YYYY-MM-DD HH24:MI:SS')
            ELSE 
                TO_VARCHAR(DATEADD('day', MOD(seq * 17, 355) + 16, '2025-10-01'::DATE), 'YYYY-MM-DD HH24:MI:SS')
        END AS DELIVERY_TS_STR,
        CASE WHEN MOD(seq, 100) = 0 THEN 'IN_TRANSIT' ELSE 'DELIVERED' END AS STATUS,
        ROUND(250.0 + MOD(seq * 31, 800), 2) AS FREIGHT_CHARGE_USD,
        ROUND(45.0 + MOD(seq * 11, 100), 2) AS HANDLING_CHARGE_USD,
        CASE 
            WHEN MOD(seq, 4) = 0 AND MOD(seq * 17, 355) BETWEEN 313 AND 320 AND MOD(seq, 10) = 1 THEN 'Y'
            ELSE 'N'
        END AS IS_BACKORDERED_FLAG
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY 1) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 5000)));

    INSERT INTO RAW.LOGISTICS_SHIPMENT_LINES (SHIP_LINE_ID, SHIPMENT_NO, SO_LINE_REF, PRODUCT_ID, QTY_SHIPPED, QTY_DELIVERED)
    SELECT 
        'SHL-' || LPAD(seq, 5, '0') AS SHIP_LINE_ID,
        'SHP-' || LPAD(1 + FLOOR((seq - 1) / 3), 5, '0') AS SHIPMENT_NO,
        'SOL-' || LPAD(seq, 5, '0') AS SO_LINE_REF,
        CASE 
            WHEN MOD(seq, 10) = 1 OR (1 + MOD(seq * 3, 50)) = 1 THEN 'APEX-ROBOTIC-ARM-V2' 
            ELSE 'PROD-' || LPAD(1 + MOD(seq * 3, 50), 3, '0') 
        END AS PRODUCT_ID,
        ROUND(2.0 + MOD(seq * 5, 20), 0) AS QTY_SHIPPED,
        CASE 
            WHEN MOD(1 + FLOOR((seq - 1) / 3), 100) = 0 THEN 0.00
            ELSE ROUND(2.0 + MOD(seq * 5, 20), 0)
        END AS QTY_DELIVERED
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY 1) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 15000)));

    -- 17. Populate IoT Telemetry Events
    INSERT INTO RAW.IOT_TELEMETRY (EVENT_ID, DEVICE_ID, SHIPMENT_NO, LATITUDE, LONGITUDE, TEMPERATURE_C, SHOCK_G, EVENT_TIMESTAMP)
    SELECT 
        'EVT-' || LPAD(seq, 5, '0') AS EVENT_ID,
        'DEV-TRK-' || LPAD(1 + MOD(seq, 50), 3, '0') AS DEVICE_ID,
        'SHP-' || LPAD(1 + MOD(seq * 7, 5000), 5, '0') AS SHIPMENT_NO,
        ROUND(10.0 + (MOD(seq * 13, 4000) / 100.0), 6) AS LATITUDE,
        ROUND(70.0 + (MOD(seq * 17, 6000) / 100.0), 6) AS LONGITUDE,
        CASE WHEN MOD(seq, 80) = 0 THEN 28.50 ELSE ROUND(18.0 + (MOD(seq, 60) / 10.0), 2) END AS TEMPERATURE_C,
        CASE WHEN MOD(seq, 150) = 0 THEN 6.80 ELSE ROUND(1.0 + (MOD(seq, 30) / 10.0), 2) END AS SHOCK_G,
        DATEADD('hour', seq, '2025-10-01 08:00:00'::TIMESTAMP_NTZ) AS EVENT_TIMESTAMP
    FROM (SELECT ROW_NUMBER() OVER (ORDER BY 1) AS seq FROM TABLE(GENERATOR(ROWCOUNT => 2500)));

    RETURN 'SUCCESS: Deterministic synthetic data generated for 1 Oct 2025 to 30 Sep 2026.';
END;
$$;
