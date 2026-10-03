-- ==============================================================================
-- 10_cortex_search.sql
-- Cortex Search Service for Supplier Contracts, SLAs, and Penalty Clauses
-- ==============================================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA SEMANTIC;
USE WAREHOUSE HACK_WH;

CREATE CORTEX SEARCH SERVICE SC_ONTOLOGY.SEMANTIC.CSS_SUPPLIER_CONTRACTS
  ON FULL_CONTRACT_TEXT
  ATTRIBUTES SUPPLIER_CODE, SUPPLIER_NAME, CONTRACT_ID
  WAREHOUSE = HACK_WH
  TARGET_LAG = '1 day'
  AS (
    SELECT 
      CONTRACT_ID,
      SUPPLIER_CODE,
      SUPPLIER_NAME,
      CONTRACT_TITLE,
      TARGET_OTIF_PCT,
      CONTRACT_LEAD_TIME_DAYS,
      PENALTY_TERMS,
      FULL_CONTRACT_TEXT
    FROM SC_ONTOLOGY.RAW.SUPPLIER_CONTRACTS
  );
