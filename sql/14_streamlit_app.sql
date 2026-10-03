-- ==============================================================================
-- 14_streamlit_app.sql
-- Deployment Script for Streamlit in Snowflake (SiS) Control Tower App
-- ==============================================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA APP;
USE WAREHOUSE HACK_WH;

-- 1. Create Streamlit Application Stage
CREATE STAGE IF NOT EXISTS SC_ONTOLOGY.APP.STREAMLIT_STAGE
    COMMENT = 'Stage for Supply Chain Control Tower Streamlit application files';

-- 2. Create Streamlit Object
CREATE STREAMLIT IF NOT EXISTS SC_ONTOLOGY.APP.SUPPLY_CHAIN_CONTROL_TOWER
    ROOT_LOCATION = '@SC_ONTOLOGY.APP.STREAMLIT_STAGE'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = 'HACK_WH'
    COMMENT = 'Apex Industrial Components Governed Supply Chain Control Tower';
