-- ==============================================================================
-- 01_setup.sql
-- Setup Database, Schemas, and Warehouse for Supply Chain Ontology
-- ==============================================================================

USE ROLE ACCOUNTADMIN;

CREATE WAREHOUSE IF NOT EXISTS HACK_WH 
WITH 
    WAREHOUSE_SIZE = 'XSMALL' 
    AUTO_SUSPEND = 60 
    AUTO_RESUME = TRUE 
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Hackathon XSMALL compute warehouse for Supply Chain Ontology';

USE WAREHOUSE HACK_WH;

CREATE DATABASE IF NOT EXISTS SC_ONTOLOGY
    COMMENT = 'Supply Chain Ontology & Governed Conversational Analytics Database';

USE DATABASE SC_ONTOLOGY;

CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Raw messy landing layer for source systems (ERP, Logistics, Portals, IoT, Contracts)';

CREATE SCHEMA IF NOT EXISTS LEGACY
    COMMENT = 'Legacy conflicting reporting views representing the Before state';

CREATE SCHEMA IF NOT EXISTS CURATED
    COMMENT = 'Conformed dimensional and fact layer with unified supply chain ontology';

CREATE SCHEMA IF NOT EXISTS SEMANTIC
    COMMENT = 'Governed semantic views, Cortex Search services, and models';

CREATE SCHEMA IF NOT EXISTS APP
    COMMENT = 'Application layer for action tracking, alerts, and Streamlit state';
