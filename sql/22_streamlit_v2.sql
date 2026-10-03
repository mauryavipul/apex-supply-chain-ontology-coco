-- ==============================================================================
-- 22_streamlit_v2.sql
-- Deployment Script for Supply Chain Control Tower Streamlit v2 (6-Nav Layout)
-- ==============================================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA APP;
USE WAREHOUSE HACK_WH;

-- 1. Ensure Streamlit Stage Exists
CREATE STAGE IF NOT EXISTS SC_ONTOLOGY.APP.STREAMLIT_STAGE
    COMMENT = 'Stage for Supply Chain Control Tower Streamlit application files';

-- 2. Stage upload command (executed via Python upload_app.py or PUT command):
-- PUT 'file://<PATH_TO_FILE>/streamlit_app.py' @SC_ONTOLOGY.APP.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- 3. Create or Replace Streamlit Application Object
CREATE OR REPLACE STREAMLIT SC_ONTOLOGY.APP.SUPPLY_CHAIN_CONTROL_TOWER
    ROOT_LOCATION = '@SC_ONTOLOGY.APP.STREAMLIT_STAGE'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = 'HACK_WH'
    COMMENT = 'Apex Industrial Components Governed Supply Chain Control Tower v2 (6-Nav Prescriptive & Simulation)';
