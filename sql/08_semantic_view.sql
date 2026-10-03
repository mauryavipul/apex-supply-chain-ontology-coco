-- ==============================================================================
-- 08_semantic_view.sql
-- Snowflake-Native Semantic View for Apex Supply Chain Intelligence
-- ==============================================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA SEMANTIC;
USE WAREHOUSE HACK_WH;

CREATE OR REPLACE SEMANTIC VIEW SC_ONTOLOGY.SEMANTIC.SV_SUPPLY_CHAIN_INTELLIGENCE
  TABLES (
    dim_date AS SC_ONTOLOGY.CURATED.DIM_DATE
      PRIMARY KEY (date_key)
      WITH SYNONYMS ('calendar', 'time dimension', 'date')
      COMMENT = 'Conformed calendar date dimension',
    dim_plant AS SC_ONTOLOGY.CURATED.DIM_PLANT
      PRIMARY KEY (plant_key)
      WITH SYNONYMS ('facility', 'manufacturing plant', 'site', 'factory')
      COMMENT = 'Manufacturing and assembly plant locations',
    dim_supplier AS SC_ONTOLOGY.CURATED.DIM_SUPPLIER
      PRIMARY KEY (supplier_key)
      WITH SYNONYMS ('vendor', 'seller', 'parts supplier')
      COMMENT = 'Direct materials and components supplier dimension',
    dim_part AS SC_ONTOLOGY.CURATED.DIM_PART
      PRIMARY KEY (part_key)
      WITH SYNONYMS ('component', 'raw material', 'item', 'part sku')
      COMMENT = 'Bill of materials components and direct raw materials',
    dim_product AS SC_ONTOLOGY.CURATED.DIM_PRODUCT
      PRIMARY KEY (product_key)
      WITH SYNONYMS ('finished good', 'product model', 'machine sku')
      COMMENT = 'Finished industrial machinery and equipment products',
    dim_customer AS SC_ONTOLOGY.CURATED.DIM_CUSTOMER
      PRIMARY KEY (customer_key)
      WITH SYNONYMS ('client', 'buyer', 'account', 'customer account')
      COMMENT = 'Enterprise industrial B2B customer accounts',
    dim_carrier AS SC_ONTOLOGY.CURATED.DIM_CARRIER
      PRIMARY KEY (carrier_key)
      WITH SYNONYMS ('logistics provider', 'transporter', 'freight carrier')
      COMMENT = 'Multimodal logistics transportation carriers',
    bridge_bom AS SC_ONTOLOGY.CURATED.BRIDGE_BILL_OF_MATERIALS
      PRIMARY KEY (bom_key)
      COMMENT = 'Bill of Materials hierarchical bridge linking finished goods to component parts',
    dim_supplier_part_sla AS SC_ONTOLOGY.CURATED.DIM_SUPPLIER_PART_SLA
      PRIMARY KEY (sla_key)
      COMMENT = 'Supplier contractual SLA commitments and lead time targets',
    fact_sales_orders AS SC_ONTOLOGY.CURATED.FACT_SALES_ORDERS
      PRIMARY KEY (sales_order_key)
      COMMENT = 'Customer sales order header transactions',
    fact_purchase_orders AS SC_ONTOLOGY.CURATED.FACT_PURCHASE_ORDERS
      PRIMARY KEY (po_line_key)
      WITH SYNONYMS ('inbound procurement', 'supplier orders', 'goods receipts')
      COMMENT = 'Inbound purchase orders, receipts, lead times, and landed costs',
    fact_outbound_shipments AS SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS
      PRIMARY KEY (shipment_line_key)
      WITH SYNONYMS ('customer deliveries', 'outbound fulfillment', 'freight shipments')
      COMMENT = 'Outbound customer shipments, line deliveries, transit times, and OTD',
    fact_inventory_daily AS SC_ONTOLOGY.CURATED.FACT_INVENTORY_DAILY
      PRIMARY KEY (inv_snapshot_key)
      COMMENT = 'Daily stock level snapshots and safety stock balances',
    inventory_position_current AS SC_ONTOLOGY.CURATED.INVENTORY_POSITION_CURRENT
      PRIMARY KEY (inv_position_key)
      WITH SYNONYMS ('current stock', 'inventory coverage', 'doi position')
      COMMENT = 'Current inventory balance, trailing 30-day consumption, and Days of Inventory (DOI)'
  )

  RELATIONSHIPS (
    po_to_supplier AS fact_purchase_orders(supplier_key) REFERENCES dim_supplier(supplier_key),
    po_to_part AS fact_purchase_orders(part_key) REFERENCES dim_part(part_key),
    po_to_plant AS fact_purchase_orders(plant_key) REFERENCES dim_plant(plant_key),
    po_to_order_date AS fact_purchase_orders(order_date_key) REFERENCES dim_date(date_key),
    shipment_to_customer AS fact_outbound_shipments(customer_key) REFERENCES dim_customer(customer_key),
    shipment_to_plant AS fact_outbound_shipments(plant_key) REFERENCES dim_plant(plant_key),
    shipment_to_product AS fact_outbound_shipments(product_key) REFERENCES dim_product(product_key),
    shipment_to_carrier AS fact_outbound_shipments(carrier_key) REFERENCES dim_carrier(carrier_key),
    shipment_to_order_date AS fact_outbound_shipments(order_date_key) REFERENCES dim_date(date_key),
    inv_to_plant AS fact_inventory_daily(plant_key) REFERENCES dim_plant(plant_key),
    inv_to_part AS fact_inventory_daily(part_key) REFERENCES dim_part(part_key),
    inv_to_date AS fact_inventory_daily(snapshot_date_key) REFERENCES dim_date(date_key),
    inv_curr_to_plant AS inventory_position_current(plant_key) REFERENCES dim_plant(plant_key),
    inv_curr_to_part AS inventory_position_current(part_key) REFERENCES dim_part(part_key),
    bom_to_product AS bridge_bom(product_key) REFERENCES dim_product(product_key),
    bom_to_part AS bridge_bom(part_key) REFERENCES dim_part(part_key),
    sla_to_supplier AS dim_supplier_part_sla(supplier_key) REFERENCES dim_supplier(supplier_key),
    sla_to_part AS dim_supplier_part_sla(part_key) REFERENCES dim_part(part_key)
  )

  FACTS (
    fact_outbound_shipments.ordered_qty AS fact_outbound_shipments.ordered_qty,
    fact_outbound_shipments.qty_delivered AS fact_outbound_shipments.qty_delivered,
    fact_outbound_shipments.freight_cost_usd AS fact_outbound_shipments.freight_cost_usd,
    fact_outbound_shipments.handling_cost_usd AS fact_outbound_shipments.handling_cost_usd,
    fact_purchase_orders.order_qty AS fact_purchase_orders.order_qty,
    fact_purchase_orders.received_qty AS fact_purchase_orders.received_qty,
    fact_purchase_orders.unit_price_usd AS fact_purchase_orders.unit_price_usd,
    fact_purchase_orders.extended_purchase_cost_usd AS fact_purchase_orders.extended_purchase_cost_usd,
    fact_purchase_orders.inbound_freight_usd AS fact_purchase_orders.inbound_freight_usd,
    fact_purchase_orders.duty_cost_usd AS fact_purchase_orders.duty_cost_usd,
    fact_purchase_orders.handling_cost_usd AS fact_purchase_orders.handling_cost_usd,
    fact_purchase_orders.extended_landed_cost_usd AS fact_purchase_orders.extended_purchase_cost_usd + fact_purchase_orders.inbound_freight_usd + fact_purchase_orders.duty_cost_usd + fact_purchase_orders.handling_cost_usd,
    fact_purchase_orders.lead_time_variance_days_row AS fact_purchase_orders.lead_time_actual_days - fact_purchase_orders.lead_time_contract_days,
    inventory_position_current.on_hand_qty AS inventory_position_current.on_hand_qty,
    inventory_position_current.safety_stock_qty AS inventory_position_current.safety_stock_qty,
    inventory_position_current.inventory_value_usd AS inventory_position_current.inventory_value_usd,
    inventory_position_current.avg_daily_consumption_30d AS inventory_position_current.avg_daily_consumption_30d
  )

  DIMENSIONS (
    dim_date.full_date AS dim_date.full_date
      WITH SYNONYMS = ('calendar date', 'date')
      COMMENT = 'Full calendar date',
    dim_date.year AS dim_date.year
      WITH SYNONYMS = ('fiscal year', 'year')
      COMMENT = 'Calendar year',
    dim_date.quarter AS dim_date.quarter
      WITH SYNONYMS = ('quarter', 'fiscal quarter')
      COMMENT = 'Calendar quarter (e.g. Q1, Q2, Q3, Q4)',
    dim_date.quarter_year AS dim_date.quarter_year
      WITH SYNONYMS = ('quarter label', 'quarter year')
      COMMENT = 'Formatted quarter and year (e.g. Q3 2026)',
    dim_date.month_name AS dim_date.month_name
      WITH SYNONYMS = ('month', 'month name')
      COMMENT = 'Full month name',
    dim_date.year_month AS dim_date.year_month
      WITH SYNONYMS = ('period', 'year month')
      COMMENT = 'Year and month format YYYY-MM',
    dim_plant.plant_code AS dim_plant.plant_code
      WITH SYNONYMS = ('facility id', 'plant id')
      COMMENT = 'Plant identifier (US-TX-01, DE-BY-02, VN-BD-03, US-OH-04)',
    dim_plant.plant_name AS dim_plant.plant_name
      WITH SYNONYMS = ('facility name', 'factory name', 'plant location')
      COMMENT = 'Full descriptive name of manufacturing or assembly plant',
    dim_plant.city AS dim_plant.city
      WITH SYNONYMS = ('plant city', 'city')
      COMMENT = 'City where the manufacturing facility is located',
    dim_plant.country AS dim_plant.country
      WITH SYNONYMS = ('plant country', 'manufacturing country')
      COMMENT = 'Country of the plant location',
    dim_plant.region AS dim_plant.region
      WITH SYNONYMS = ('plant region', 'operating theater')
      COMMENT = 'Global region of plant (AMER, EMEA, APAC)',
    dim_supplier.supplier_id AS dim_supplier.supplier_id
      WITH SYNONYMS = ('vendor id', 'vendor code', 'supplier code')
      COMMENT = 'Unique supplier code (e.g. SUP-104)',
    dim_supplier.supplier_name AS dim_supplier.supplier_name
      WITH SYNONYMS = ('vendor name', 'supplier title', 'vendor')
      COMMENT = 'Legal corporate name of the direct supplier',
    dim_supplier.supplier_tier AS dim_supplier.supplier_tier
      WITH SYNONYMS = ('vendor tier', 'supplier tier rating')
      COMMENT = 'Supplier classification (Tier-1 Strategic, Tier-2 Preferred, Tier-3 Tactical)',
    dim_supplier.country AS dim_supplier.country
      WITH SYNONYMS = ('supplier country', 'vendor origin')
      COMMENT = 'Country of supplier origin',
    dim_supplier.region AS dim_supplier.region
      WITH SYNONYMS = ('supplier region', 'vendor geography')
      COMMENT = 'Geographic region of supplier (AMER, EMEA, APAC)',
    dim_part.part_number AS dim_part.part_number
      WITH SYNONYMS = ('material number', 'item code', 'component sku')
      COMMENT = 'Unique part number (e.g. PART-TF-88, PART-MC-02)',
    dim_part.part_name AS dim_part.part_name
      WITH SYNONYMS = ('material description', 'component name')
      COMMENT = 'Descriptive specification of the component or raw material',
    dim_part.part_category AS dim_part.part_category
      WITH SYNONYMS = ('commodity group', 'material group', 'part family')
      COMMENT = 'Part commodity category (Electronics, Fasteners, Precision Mechanical, Raw Metals)',
    dim_part.unit_of_measure AS dim_part.unit_of_measure
      WITH SYNONYMS = ('uom', 'base unit')
      COMMENT = 'Base unit of measure (EA, PCS, KG)',
    dim_part.is_critical AS dim_part.is_critical
      WITH SYNONYMS = ('critical component flag', 'is critical')
      COMMENT = 'Flag indicating whether the part is mission-critical for production',
    dim_product.product_sku AS dim_product.product_sku
      WITH SYNONYMS = ('finished good sku', 'product code', 'model number')
      COMMENT = 'Finished good product SKU (e.g. APEX-ROBOTIC-ARM-V2)',
    dim_product.product_name AS dim_product.product_name
      WITH SYNONYMS = ('machine name', 'product description', 'finished good name')
      COMMENT = 'Descriptive name of the finished industrial product',
    dim_product.product_family AS dim_product.product_family
      WITH SYNONYMS = ('product line', 'equipment family')
      COMMENT = 'Product family line (Industrial Robotics, Fluid Automation, Industrial Power Drives)',
    dim_customer.customer_id AS dim_customer.customer_id
      WITH SYNONYMS = ('client id', 'account number')
      COMMENT = 'Unique customer account identifier (e.g. CUST-001)',
    dim_customer.customer_name AS dim_customer.customer_name
      WITH SYNONYMS = ('client name', 'account name', 'buyer name')
      COMMENT = 'Enterprise client corporate name',
    dim_customer.customer_segment AS dim_customer.customer_segment
      WITH SYNONYMS = ('industry sector', 'vertical', 'customer industry')
      COMMENT = 'Customer industry vertical (Automotive OEM, Aerospace Systems, Heavy Machinery)',
    dim_customer.country AS dim_customer.country
      WITH SYNONYMS = ('customer country', 'destination country')
      COMMENT = 'Customer country',
    dim_customer.region AS dim_customer.region
      WITH SYNONYMS = ('customer region', 'market theater')
      COMMENT = 'Customer geographic region (AMER, EMEA, APAC)',
    dim_carrier.carrier_code AS dim_carrier.carrier_code
      WITH SYNONYMS = ('transporter id', 'carrier id')
      COMMENT = 'Unique freight carrier code (e.g. CARR-04)',
    dim_carrier.carrier_name AS dim_carrier.carrier_name
      WITH SYNONYMS = ('logistics carrier', 'freight line', 'shipping company')
      COMMENT = 'Carrier corporate name (e.g. Pacific Express Ocean Lines)',
    dim_carrier.transport_mode AS dim_carrier.transport_mode
      WITH SYNONYMS = ('freight mode', 'shipping mode', 'transit mode')
      COMMENT = 'Transportation modality (Air, Ocean, Road, Rail, Intermodal)',
    inventory_position_current.inventory_health_status AS inventory_position_current.inventory_health_status
      WITH SYNONYMS = ('stock status', 'inventory condition')
      COMMENT = 'Inventory health category (STOCKOUT, CRITICAL_LOW, OPTIMAL, EXCESS)'
  )

  METRICS (
    fact_outbound_shipments.outbound_otd_pct AS 
      100.0 * COUNT(CASE WHEN fact_outbound_shipments.is_on_time_outbound = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN fact_outbound_shipments.is_delivered = TRUE THEN 1 END), 0)
      WITH SYNONYMS = ('outbound on-time delivery', 'customer otd', 'delivery punctuality', 'shipping schedule adherence')
      COMMENT = 'Percentage of customer shipment lines delivered on or before promised delivery date among delivered lines',
    
    fact_outbound_shipments.outbound_otif_pct AS 
      100.0 * COUNT(CASE WHEN fact_outbound_shipments.is_on_time_outbound = TRUE AND fact_outbound_shipments.is_in_full_outbound = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN fact_outbound_shipments.is_delivered = TRUE THEN 1 END), 0)
      WITH SYNONYMS = ('outbound otif', 'customer on-time in-full', 'perfect order fulfillment rate')
      COMMENT = 'Percentage of customer order lines delivered both on time and 100% in full among delivered lines',

    fact_outbound_shipments.fill_rate_pct AS 
      100.0 * SUM(fact_outbound_shipments.qty_delivered) / NULLIF(SUM(fact_outbound_shipments.ordered_qty), 0)
      WITH SYNONYMS = ('order fill rate', 'customer fill rate', 'fulfillment volume percentage')
      COMMENT = 'Percentage of customer ordered product volume successfully delivered',

    fact_outbound_shipments.backorder_rate_pct AS 
      100.0 * COUNT(CASE WHEN fact_outbound_shipments.is_backordered = TRUE THEN 1 END) / NULLIF(COUNT(fact_outbound_shipments.shipment_line_key), 0)
      WITH SYNONYMS = ('backorder percentage', 'stockout backlog rate', 'unfulfilled line rate')
      COMMENT = 'Percentage of shipment lines delayed due to product or component backorders',

    fact_outbound_shipments.average_freight_cost_usd AS 
      SUM(fact_outbound_shipments.freight_cost_usd) / NULLIF(COUNT(fact_outbound_shipments.shipment_line_key), 0)
      WITH SYNONYMS = ('avg freight cost', 'freight expense per shipment line')
      COMMENT = 'Average freight shipping cost per shipment line in USD',

    fact_purchase_orders.inbound_otd_pct AS 
      100.0 * COUNT(CASE WHEN fact_purchase_orders.is_on_time_inbound = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN fact_purchase_orders.is_delivered = TRUE THEN 1 END), 0)
      WITH SYNONYMS = ('inbound on-time delivery', 'supplier otd', 'vendor punctuality')
      COMMENT = 'Percentage of supplier purchase order lines received on or before promised date among received lines',

    fact_purchase_orders.inbound_otif_pct AS 
      100.0 * COUNT(CASE WHEN fact_purchase_orders.is_on_time_inbound = TRUE AND fact_purchase_orders.is_in_full_inbound = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN fact_purchase_orders.is_delivered = TRUE THEN 1 END), 0)
      WITH SYNONYMS = ('inbound otif', 'supplier otif', 'supplier perfect order rate')
      COMMENT = 'Percentage of supplier purchase order lines received both on time and in full among received lines',

    fact_purchase_orders.total_landed_cost_usd AS 
      SUM(fact_purchase_orders.extended_landed_cost_usd)
      WITH SYNONYMS = ('total landed spend', 'total procurement spend')
      COMMENT = 'Total all-in landed spend (extended purchase price + inbound freight + customs duty + receiving handling)',

    fact_purchase_orders.landed_cost_per_unit_usd AS 
      SUM(fact_purchase_orders.extended_landed_cost_usd) / NULLIF(SUM(fact_purchase_orders.received_qty), 0)
      WITH SYNONYMS = ('unit landed cost', 'all-in unit cost', 'average landed cost per part')
      COMMENT = 'All-in landed procurement cost per received unit in USD',

    fact_purchase_orders.lead_time_variance_days AS 
      SUM(CASE WHEN fact_purchase_orders.is_delivered = TRUE THEN fact_purchase_orders.lead_time_variance_days_row END) / NULLIF(COUNT(CASE WHEN fact_purchase_orders.is_delivered = TRUE THEN 1 END), 0)
      WITH SYNONYMS = ('supplier lead time variance', 'average lead time delay', 'delivery overrun days')
      COMMENT = 'Average difference in calendar days between actual delivery lead time and agreed contractual SLA lead time',

    inventory_position_current.days_of_inventory AS 
      SUM(inventory_position_current.on_hand_qty) / NULLIF(SUM(inventory_position_current.avg_daily_consumption_30d), 0)
      WITH SYNONYMS = ('doi', 'days forward cover', 'stock cover duration', 'inventory runway')
      COMMENT = 'Days of Inventory calculated as total on-hand quantity divided by total trailing 30-day daily consumption',

    inventory_position_current.total_inventory_valuation_usd AS 
      SUM(inventory_position_current.inventory_value_usd)
      WITH SYNONYMS = ('total inventory value', 'stock value', 'inventory balance usd')
      COMMENT = 'Total current inventory asset valuation in USD'
  )

  COMMENT = 'Governed Enterprise Supply Chain Semantic View for Apex Industrial Components'

  AI_SQL_GENERATION 'Instructions for Cortex Analyst:
  1. When asked about Outbound On-Time Delivery (OTD), use outbound_otd_pct, which measures customer shipment lines delivered on or before promised delivery date among delivered lines.
  2. When asked about Inbound On-Time Delivery or Supplier OTD, use inbound_otd_pct.
  3. When asked about Landed Cost, use landed_cost_per_unit_usd or total_landed_cost_usd. Landed cost incorporates extended purchase price, inbound freight, customs duty, and dock handling.
  4. When asked about Days of Inventory (DOI), use days_of_inventory from inventory_position_current (total on-hand qty divided by total trailing daily consumption).
  5. Titan Micro-Foundry is supplier SUP-104.
  6. August 2026 stockout of PART-MC-02 occurred at Plant US-TX-01.
  7. Carrier Pacific Express is CARR-04.'

  AI_VERIFIED_QUERIES (
    vqr_01_monthly_outbound_otd AS (
      QUESTION 'What was our monthly Outbound OTD by plant?'
      SQL 'SELECT d.YEAR_MONTH, p.PLANT_NAME, 100.0 * COUNT(CASE WHEN s.IS_ON_TIME_OUTBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END), 0) AS OUTBOUND_OTD_PCT FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS s JOIN SC_ONTOLOGY.CURATED.DIM_DATE d ON s.ORDER_DATE_KEY = d.DATE_KEY JOIN SC_ONTOLOGY.CURATED.DIM_PLANT p ON s.PLANT_KEY = p.PLANT_KEY GROUP BY 1, 2 ORDER BY 1, 2'
    ),
    vqr_02_inbound_otif_by_tier AS (
      QUESTION 'What is our Inbound OTIF and lead time variance by supplier tier?'
      SQL 'SELECT s.SUPPLIER_TIER, 100.0 * COUNT(CASE WHEN po.IS_ON_TIME_INBOUND = TRUE AND po.IS_IN_FULL_INBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN po.IS_DELIVERED = TRUE THEN 1 END), 0) AS INBOUND_OTIF_PCT, ROUND(AVG(CASE WHEN po.IS_DELIVERED = TRUE THEN po.LEAD_TIME_ACTUAL_DAYS - po.LEAD_TIME_CONTRACT_DAYS END), 2) AS AVG_LEAD_TIME_VARIANCE_DAYS FROM SC_ONTOLOGY.CURATED.FACT_PURCHASE_ORDERS po JOIN SC_ONTOLOGY.CURATED.DIM_SUPPLIER s ON po.SUPPLIER_KEY = s.SUPPLIER_KEY GROUP BY 1 ORDER BY 1'
    ),
    vqr_03_top_5_parts_landed_cost AS (
      QUESTION 'What are the top 5 parts by total unit landed cost?'
      SQL 'SELECT p.PART_NUMBER, p.PART_NAME, p.PART_CATEGORY, ROUND(SUM(po.EXTENDED_PURCHASE_COST_USD + po.INBOUND_FREIGHT_USD + po.DUTY_COST_USD + po.HANDLING_COST_USD) / NULLIF(SUM(po.RECEIVED_QTY), 0), 2) AS UNIT_LANDED_COST_USD, SUM(po.RECEIVED_QTY) AS TOTAL_RECEIVED_UNITS FROM SC_ONTOLOGY.CURATED.FACT_PURCHASE_ORDERS po JOIN SC_ONTOLOGY.CURATED.DIM_PART p ON po.PART_KEY = p.PART_KEY WHERE po.IS_DELIVERED = TRUE GROUP BY 1, 2, 3 ORDER BY UNIT_LANDED_COST_USD DESC LIMIT 5'
    ),
    vqr_04_doi_by_plant_and_category AS (
      QUESTION 'What is our Days of Inventory (DOI) by plant and part category?'
      SQL 'SELECT i.PLANT_CODE, p.PART_CATEGORY, ROUND(SUM(i.ON_HAND_QTY) / NULLIF(SUM(i.AVG_DAILY_CONSUMPTION_30D), 0), 1) AS DAYS_OF_INVENTORY, ROUND(SUM(i.INVENTORY_VALUE_USD), 2) AS TOTAL_INVENTORY_VALUE_USD FROM SC_ONTOLOGY.CURATED.INVENTORY_POSITION_CURRENT i JOIN SC_ONTOLOGY.CURATED.DIM_PART p ON i.PART_KEY = p.PART_KEY GROUP BY 1, 2 ORDER BY 1, 2'
    ),
    vqr_05_backorder_rate_by_family AS (
      QUESTION 'What is the backorder rate by finished product family?'
      SQL 'SELECT p.PRODUCT_FAMILY, COUNT(s.SHIPMENT_LINE_KEY) AS TOTAL_SHIPMENT_LINES, COUNT(CASE WHEN s.IS_BACKORDERED = TRUE THEN 1 END) AS BACKORDERED_LINES, ROUND(100.0 * COUNT(CASE WHEN s.IS_BACKORDERED = TRUE THEN 1 END) / NULLIF(COUNT(s.SHIPMENT_LINE_KEY), 0), 2) AS BACKORDER_RATE_PCT FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS s JOIN SC_ONTOLOGY.CURATED.DIM_PRODUCT p ON s.PRODUCT_KEY = p.PRODUCT_KEY GROUP BY 1 ORDER BY BACKORDER_RATE_PCT DESC'
    ),
    vqr_06_carrier_performance_and_cost AS (
      QUESTION 'What is carrier delivery performance and average freight cost?'
      SQL 'SELECT c.CARRIER_NAME, c.TRANSPORT_MODE, COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END) AS TOTAL_DELIVERIES, ROUND(100.0 * COUNT(CASE WHEN s.IS_ON_TIME_OUTBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS OUTBOUND_OTD_PCT, ROUND(AVG(s.FREIGHT_COST_USD), 2) AS AVG_FREIGHT_COST_USD FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS s JOIN SC_ONTOLOGY.CURATED.DIM_CARRIER c ON s.CARRIER_KEY = c.CARRIER_KEY GROUP BY 1, 2 ORDER BY OUTBOUND_OTD_PCT DESC'
    ),
    vqr_07_bottom_5_suppliers_inbound_otd AS (
      QUESTION 'Which are the bottom 5 suppliers by Inbound OTD over the last 90 days?'
      SQL 'SELECT s.SUPPLIER_ID, s.SUPPLIER_NAME, s.SUPPLIER_TIER, COUNT(CASE WHEN po.IS_DELIVERED = TRUE THEN 1 END) AS RECEIVED_LINES, ROUND(100.0 * COUNT(CASE WHEN po.IS_ON_TIME_INBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN po.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS INBOUND_OTD_PCT, ROUND(100.0 * COUNT(CASE WHEN po.IS_ON_TIME_INBOUND = TRUE AND po.IS_IN_FULL_INBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN po.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS INBOUND_OTIF_PCT FROM SC_ONTOLOGY.CURATED.FACT_PURCHASE_ORDERS po JOIN SC_ONTOLOGY.CURATED.DIM_SUPPLIER s ON po.SUPPLIER_KEY = s.SUPPLIER_KEY WHERE po.ORDER_DATE >= DATEADD(\'day\', -90, \'2026-09-30\'::DATE) GROUP BY 1, 2, 3 HAVING COUNT(CASE WHEN po.IS_DELIVERED = TRUE THEN 1 END) >= 10 ORDER BY INBOUND_OTD_PCT ASC LIMIT 5'
    ),
    vqr_08_inventory_value_vs_safety_stock AS (
      QUESTION 'What is the inventory valuation versus safety stock surplus or deficit by plant?'
      SQL 'SELECT PLANT_CODE, ROUND(SUM(INVENTORY_VALUE_USD), 2) AS TOTAL_INVENTORY_VALUE_USD, ROUND(SUM(ON_HAND_QTY), 0) AS TOTAL_ON_HAND_QTY, ROUND(SUM(SAFETY_STOCK_QTY), 0) AS TOTAL_SAFETY_STOCK_QTY, ROUND(SUM(ON_HAND_QTY - SAFETY_STOCK_QTY), 0) AS NET_SAFETY_STOCK_VARIANCE_QTY, COUNT(CASE WHEN INVENTORY_HEALTH_STATUS = \'STOCKOUT\' THEN 1 END) AS STOCKOUT_ITEM_COUNT, COUNT(CASE WHEN INVENTORY_HEALTH_STATUS = \'CRITICAL_LOW\' THEN 1 END) AS CRITICAL_LOW_ITEM_COUNT FROM SC_ONTOLOGY.CURATED.INVENTORY_POSITION_CURRENT GROUP BY 1 ORDER BY 1'
    ),
    vqr_09_customer_segment_otif_by_quarter AS (
      QUESTION 'What is customer segment Outbound OTIF across quarters?'
      SQL 'SELECT d.QUARTER_YEAR, c.CUSTOMER_SEGMENT, COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END) AS DELIVERED_LINES, ROUND(100.0 * COUNT(CASE WHEN s.IS_ON_TIME_OUTBOUND = TRUE AND s.IS_IN_FULL_OUTBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS OUTBOUND_OTIF_PCT, ROUND(100.0 * COUNT(CASE WHEN s.IS_ON_TIME_OUTBOUND = TRUE THEN 1 END) / NULLIF(COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS OUTBOUND_OTD_PCT FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS s JOIN SC_ONTOLOGY.CURATED.DIM_CUSTOMER c ON s.CUSTOMER_KEY = c.CUSTOMER_KEY JOIN SC_ONTOLOGY.CURATED.DIM_DATE d ON s.ORDER_DATE_KEY = d.DATE_KEY GROUP BY 1, 2 ORDER BY 1, 2'
    ),
    vqr_10_carrier_delay_vs_shipping_cost AS (
      QUESTION 'What is the relationship between carrier delays and outbound shipping costs?'
      SQL 'SELECT c.CARRIER_NAME, c.TRANSPORT_MODE, COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END) AS DELIVERED_LINES, COUNT(CASE WHEN s.IS_DELIVERED = TRUE AND s.IS_ON_TIME_OUTBOUND = FALSE THEN 1 END) AS DELAYED_LINES, ROUND(100.0 * COUNT(CASE WHEN s.IS_DELIVERED = TRUE AND s.IS_ON_TIME_OUTBOUND = FALSE THEN 1 END) / NULLIF(COUNT(CASE WHEN s.IS_DELIVERED = TRUE THEN 1 END), 0), 2) AS DELAY_RATE_PCT, ROUND(SUM(s.FREIGHT_COST_USD), 2) AS TOTAL_FREIGHT_COST_USD, ROUND(AVG(s.FREIGHT_COST_USD), 2) AS AVG_FREIGHT_COST_PER_LINE FROM SC_ONTOLOGY.CURATED.FACT_OUTBOUND_SHIPMENTS s JOIN SC_ONTOLOGY.CURATED.DIM_CARRIER c ON s.CARRIER_KEY = c.CARRIER_KEY GROUP BY 1, 2 ORDER BY DELAY_RATE_PCT DESC'
    )
  );
