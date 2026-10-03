-- ==============================================================================
-- 11_escalation_tool.sql
-- Enhanced Custom Tool Procedure with Input Validation for Supplier Escalations
-- ==============================================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA APP;
USE WAREHOUSE HACK_WH;

CREATE OR REPLACE PROCEDURE APP.SP_CREATE_ACTION_ITEM(
    P_ACTION_TYPE VARCHAR,
    P_TARGET_ENTITY_TYPE VARCHAR,
    P_TARGET_ENTITY_ID VARCHAR,
    P_SEVERITY VARCHAR,
    P_DESCRIPTION VARCHAR
)
COPY GRANTS
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    V_ACTION_ID VARCHAR;
    V_UPPER_ACTION_TYPE VARCHAR;
    V_UPPER_ENTITY_TYPE VARCHAR;
    V_UPPER_SEVERITY VARCHAR;
BEGIN
    -- 1. Validate Null or Empty inputs
    IF (P_ACTION_TYPE IS NULL OR TRIM(P_ACTION_TYPE) = '' OR
        P_TARGET_ENTITY_TYPE IS NULL OR TRIM(P_TARGET_ENTITY_TYPE) = '' OR
        P_TARGET_ENTITY_ID IS NULL OR TRIM(P_TARGET_ENTITY_ID) = '' OR
        P_SEVERITY IS NULL OR TRIM(P_SEVERITY) = '' OR
        P_DESCRIPTION IS NULL OR TRIM(P_DESCRIPTION) = '') THEN
        RETURN 'ERROR: All input parameters (action_type, target_entity_type, target_entity_id, severity, description) are required and cannot be empty.';
    END IF;

    V_UPPER_ACTION_TYPE := UPPER(TRIM(P_ACTION_TYPE));
    V_UPPER_ENTITY_TYPE := UPPER(TRIM(P_TARGET_ENTITY_TYPE));
    V_UPPER_SEVERITY := UPPER(TRIM(P_SEVERITY));

    -- 2. Validate Allowed Action Types
    IF (V_UPPER_ACTION_TYPE NOT IN ('SUPPLIER_ESCALATION', 'IOT_ALERT', 'INVENTORY_REORDER', 'CARRIER_REVIEW', 'PROCESS_AUDIT')) THEN
        RETURN 'ERROR: Invalid action_type: ' || :P_ACTION_TYPE || '. Allowed values: SUPPLIER_ESCALATION, IOT_ALERT, INVENTORY_REORDER, CARRIER_REVIEW, PROCESS_AUDIT.';
    END IF;

    -- 3. Validate Allowed Target Entity Types
    IF (V_UPPER_ENTITY_TYPE NOT IN ('SUPPLIER', 'SHIPMENT', 'PART', 'CARRIER', 'PLANT', 'PRODUCT', 'CUSTOMER')) THEN
        RETURN 'ERROR: Invalid target_entity_type: ' || :P_TARGET_ENTITY_TYPE || '. Allowed values: SUPPLIER, SHIPMENT, PART, CARRIER, PLANT, PRODUCT, CUSTOMER.';
    END IF;

    -- 4. Validate Allowed Severity Levels
    IF (V_UPPER_SEVERITY NOT IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')) THEN
        RETURN 'ERROR: Invalid severity: ' || :P_SEVERITY || '. Allowed values: LOW, MEDIUM, HIGH, CRITICAL.';
    END IF;

    -- 5. Validate Description Length (5 to 1000 characters)
    IF (LENGTH(TRIM(P_DESCRIPTION)) < 5 OR LENGTH(TRIM(P_DESCRIPTION)) > 1000) THEN
        RETURN 'ERROR: Description length must be between 5 and 1000 characters. Provided length: ' || TO_VARCHAR(LENGTH(TRIM(P_DESCRIPTION)));
    END IF;

    -- 6. Generate Unique Ticket ID and Insert Governed Action Item
    V_ACTION_ID := 'ACT-' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD-HH24MISS') || '-' || SUBSTRING(UUID_STRING(), 1, 4);

    INSERT INTO APP.ACTIONS (
        ACTION_ID, ACTION_TYPE, TARGET_ENTITY_TYPE, TARGET_ENTITY_ID, 
        SEVERITY, DESCRIPTION, STATUS, CREATED_BY, CREATED_AT
    ) VALUES (
        :V_ACTION_ID, :V_UPPER_ACTION_TYPE, :V_UPPER_ENTITY_TYPE, TRIM(:P_TARGET_ENTITY_ID),
        :V_UPPER_SEVERITY, TRIM(:P_DESCRIPTION), 'OPEN_PENDING_REVIEW', 'CORTEX_AGENT_USER', CURRENT_TIMESTAMP()
    );

    RETURN 'SUCCESS: Created Action Item ' || :V_ACTION_ID || ' [' || :V_UPPER_ACTION_TYPE || '] for ' || :V_UPPER_ENTITY_TYPE || ' ' || TRIM(:P_TARGET_ENTITY_ID) || ' with Severity ' || :V_UPPER_SEVERITY;
END;
$$;
