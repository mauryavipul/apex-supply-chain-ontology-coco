-- ==============================================================================
-- 12_cortex_agent.sql
-- Governed Cortex Agent Definition Orchestrating Analyst, Search, and Action Tools
-- ==============================================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA APP;
USE WAREHOUSE HACK_WH;

CREATE AGENT SC_ONTOLOGY.APP.SC_ONTOLOGY_AGENT
  COMMENT = 'Governed Supply Chain Intelligence Agent for Apex Industrial Components'
  PROFILE = '{"display_name": "Apex Supply Chain Agent", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  orchestration:
    tool_not_accessible: accept
    budget:
      seconds: 60
      tokens: 16000

  instructions:
    response: "You are the Governed Supply Chain Intelligence Agent for Apex Industrial Components. Always display canonical metric formulas and lineage. If asked for OTD without specifying inbound vs outbound, ask for clarification. If asked about supplier contracts or SLAs, use the Search tool. If the user explicitly asks to create an escalation ticket or action item, use the custom tool create_action_item."
    orchestration: "For quantitative metric and dimensional analytics (OTD, OTIF, DOI, Landed Cost), use the Analyst tool. For contract terms, SLAs, penalty clauses, and legal agreements, use the Search tool. When the user explicitly requests creating an escalation ticket or action item, call the custom tool create_action_item. When an escalation level is mentioned (e.g. Level-1, Level-2), map Level-1 to CRITICAL, Level-2 to HIGH, Level-3 to MEDIUM, and Level-4 to LOW. If severity is unspecified or ambiguous, prompt the user to choose from LOW, MEDIUM, HIGH, or CRITICAL."
    sample_questions:
      - question: "What was our promised-date Outbound OTD in Q3 across all plants?"
      - question: "What are the contractual SLA terms and penalty clauses for Titan Micro-Foundry?"
      - question: "Create a Level-2 Supplier Escalation ticket for Titan Micro-Foundry regarding delivery delays."

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "Analyst"
        description: "Converts natural language supply chain questions to SQL against the governed semantic view"
    - tool_spec:
        type: "cortex_search"
        name: "Search"
        description: "Searches supplier master supply agreements, SLAs, and penalty clauses"
    - tool_spec:
        type: "generic"
        name: "create_action_item"
        description: "Creates a governed action ticket or supplier escalation item in APP.ACTIONS"
        input_schema:
          type: "object"
          properties:
            action_type:
              type: "string"
              description: "Allowed values: SUPPLIER_ESCALATION, IOT_ALERT, INVENTORY_REORDER, CARRIER_REVIEW, PROCESS_AUDIT"
            target_entity_type:
              type: "string"
              description: "Allowed values: SUPPLIER, SHIPMENT, PART, CARRIER, PLANT, PRODUCT, CUSTOMER"
            target_entity_id:
              type: "string"
              description: "Identifier of the entity (e.g. SUP-104, SHP-00104, PART-MC-02)"
            severity:
              type: "string"
              description: "Severity level: LOW, MEDIUM, HIGH, CRITICAL. If user specifies Level-1 map to CRITICAL, Level-2 to HIGH, Level-3 to MEDIUM, Level-4 to LOW."
            description:
              type: "string"
              description: "Detailed description of the issue and required action (5-1000 characters)"
          required:
            - action_type
            - target_entity_type
            - target_entity_id
            - severity
            - description

  tool_resources:
    Analyst:
      semantic_view: "SC_ONTOLOGY.SEMANTIC.SV_SUPPLY_CHAIN_INTELLIGENCE"
    Search:
      search_service: "SC_ONTOLOGY.SEMANTIC.CSS_SUPPLIER_CONTRACTS"
      max_results: "5"
    create_action_item:
      type: "procedure"
      execution_environment:
        type: "warehouse"
        warehouse: "HACK_WH"
      identifier: "SC_ONTOLOGY.APP.SP_CREATE_ACTION_ITEM"
  $$;
