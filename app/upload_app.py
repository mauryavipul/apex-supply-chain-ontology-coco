import snowflake.connector
import os

# Uses a named connection from your local ~/.snowflake/connections.toml
conn = snowflake.connector.connect(
    connection_name=os.environ.get('SNOWFLAKE_CONNECTION_NAME', 'default')
)
cur = conn.cursor()
cur.execute('USE DATABASE SC_ONTOLOGY')
cur.execute('USE SCHEMA APP')
cur.execute('USE WAREHOUSE HACK_WH')

file_path = os.path.abspath('streamlit_app.py').replace('\\', '/')
put_sql = f"PUT 'file://{file_path}' @SC_ONTOLOGY.APP.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
print(f"Executing: {put_sql}")
cur.execute(put_sql)
for row in cur.fetchall():
    print(row)

cfg_path = os.path.abspath('.streamlit/config.toml').replace('\\', '/')
put_cfg_sql = f"PUT 'file://{cfg_path}' @SC_ONTOLOGY.APP.STREAMLIT_STAGE/.streamlit/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
print(f"Executing: {put_cfg_sql}")
cur.execute(put_cfg_sql)
for row in cur.fetchall():
    print(row)

print("Upload completed successfully.")
cur.close()
conn.close()
