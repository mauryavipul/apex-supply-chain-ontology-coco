-- ==============================================================================
-- 15_upload_helper_definition.sql
-- Definition and DDL of the Helper Procedure Used to Stage Streamlit Code
-- ==============================================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA APP;
USE WAREHOUSE HACK_WH;

CREATE OR REPLACE PROCEDURE SC_ONTOLOGY.APP.SP_UPLOAD_STREAMLIT_FILE(
    P_CONTENT VARCHAR, 
    P_FILENAME VARCHAR
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'main'
EXECUTE AS OWNER
AS
$$
import os

def main(session, content, filename):
    stage_path = f"/tmp/{filename}"
    with open(stage_path, "w", encoding="utf-8") as f:
        f.write(content)
    session.file.put(f"file://{stage_path}", "@SC_ONTOLOGY.APP.STREAMLIT_STAGE", auto_compress=False, overwrite=True)
    return f"Successfully staged {filename} to @SC_ONTOLOGY.APP.STREAMLIT_STAGE"
$$;
