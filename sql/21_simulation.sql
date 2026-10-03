-- ==============================================================================
-- 21_simulation.sql
-- Decision Center (Prescriptive Engine): What-If Simulation Model & Coefficients
-- ==============================================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA APP;
USE WAREHOUSE HACK_WH;

-- ------------------------------------------------------------------------------
-- 1. APP.SIM_COEFFICIENTS TABLE
-- Parameter Registry for What-If Prescriptive Simulation
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS APP.SIM_COEFFICIENTS (
    COEFFICIENT_NAME VARCHAR(100) PRIMARY KEY COMMENT 'Unique parameter identifier',
    COEFFICIENT_VALUE FLOAT NOT NULL COMMENT 'Numerical coefficient value',
    UNIT VARCHAR(50) NOT NULL COMMENT 'Engineering or financial unit of measure',
    DESCRIPTION VARCHAR(500) NOT NULL COMMENT 'Functional description of the lever or target',
    ASSUMPTIONS_NOTE VARCHAR(1000) NOT NULL COMMENT 'Documented heuristic assumption (illustrative, not calibrated)',
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP() COMMENT 'Timestamp of last coefficient update'
)
COMMENT = 'Governed coefficient registry for what-if simulation model. All coefficients are illustrative heuristic assumptions.';

-- Seed Simulation Coefficients (Illustrative Linear Model)
MERGE INTO APP.SIM_COEFFICIENTS tgt
USING (
    SELECT 'EXPEDITE_OTD_UPLIFT_PER_PCT' AS COEFFICIENT_NAME, 0.25::FLOAT AS COEFFICIENT_VALUE, '% OTD per % expedite' AS UNIT,
           'OTD % improvement per 1% premium expedite freight allocation' AS DESCRIPTION,
           'Assumed (illustrative, not calibrated): Air and express expedited lanes achieve high transit reliability for expedited share' AS ASSUMPTIONS_NOTE
    UNION ALL
    SELECT 'EXPEDITE_COST_USD_PER_PCT', 1200.0::FLOAT, 'USD per % expedite',
           'Additional logistics premium cost per 1% order volume expedited',
           'Assumed (illustrative, not calibrated): Average expedited freight surcharge across Tier-1 lanes'
    UNION ALL
    SELECT 'ALT_SUPPLIER_OTD_UPLIFT_PER_PCT', 0.20::FLOAT, '% OTD per % volume split',
           'OTD % improvement per 1% dual-sourced volume shifted to backup supplier',
           'Assumed (illustrative, not calibrated): Secondary supplier operates at benchmark baseline delivery adherence'
    UNION ALL
    SELECT 'ALT_SUPPLIER_COST_USD_PER_PCT', 800.0::FLOAT, 'USD per % volume split',
           'Procurement price delta and onboarding overhead per 1% dual-source split',
           'Assumed (illustrative, not calibrated): Higher piece price and management overhead from secondary supplier'
    UNION ALL
    SELECT 'SAFETY_STOCK_RISK_REDUCTION_PER_DAY', 2.50::FLOAT, '% stockout reduction per day',
           'Stockout risk reduction % per additional day of safety stock buffer',
           'Assumed (illustrative, not calibrated): Linear risk mitigation around standard days-of-inventory operating band'
    UNION ALL
    SELECT 'SAFETY_STOCK_HOLDING_COST_PER_DAY', 2500.0::FLOAT, 'USD per day buffer',
           'Working capital carrying cost per additional day of network-wide safety stock',
           'Assumed (illustrative, not calibrated): Annual inventory carrying rate across active finished goods and parts'
    UNION ALL
    SELECT 'DEMAND_SHOCK_OTD_DRAG_PER_PCT', 0.35::FLOAT, '% OTD loss per % demand shock',
           'OTD % degradation per 1% unanticipated surge in customer demand',
           'Assumed (illustrative, not calibrated): Plant dispatch schedule adherence degrades under demand surges'
    UNION ALL
    SELECT 'DEMAND_SHOCK_STOCKOUT_RISK_PER_PCT', 0.40::FLOAT, '% risk increase per % demand shock',
           'Stockout risk increase % per 1% unanticipated surge in customer demand',
           'Assumed (illustrative, not calibrated): Accelerates buffer depletion before replenishment cycle completes'
    UNION ALL
    SELECT 'BASE_STOCKOUT_RISK_PCT', 40.0::FLOAT, '% base risk',
           'Baseline network stockout vulnerability under unmitigated disruption',
           'Assumed (illustrative, not calibrated): Heuristic baseline stockout risk score'
    UNION ALL
    SELECT 'BASE_PENALTY_PER_OTD_POINT_USD', 3500.0::FLOAT, 'USD per OTD point below target',
           'Estimated SLA breach penalty exposure per OTD percentage point deficit below target OTD',
           'Assumed (illustrative, not calibrated): Contractual rebate exposure rate across commercial agreements'
    UNION ALL
    SELECT 'OTD_TARGET_PCT', 90.0::FLOAT, '% OTD target',
           'Contractual baseline OTD service level target threshold',
           'Assumed (illustrative, not calibrated): Standard corporate supply chain OTD target benchmark'
) src
ON tgt.COEFFICIENT_NAME = src.COEFFICIENT_NAME
WHEN MATCHED THEN
    UPDATE SET 
        tgt.COEFFICIENT_VALUE = src.COEFFICIENT_VALUE,
        tgt.UNIT = src.UNIT,
        tgt.DESCRIPTION = src.DESCRIPTION,
        tgt.ASSUMPTIONS_NOTE = src.ASSUMPTIONS_NOTE,
        tgt.UPDATED_AT = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN
    INSERT (COEFFICIENT_NAME, COEFFICIENT_VALUE, UNIT, DESCRIPTION, ASSUMPTIONS_NOTE, UPDATED_AT)
    VALUES (src.COEFFICIENT_NAME, src.COEFFICIENT_VALUE, src.UNIT, src.DESCRIPTION, src.ASSUMPTIONS_NOTE, CURRENT_TIMESTAMP());

-- ------------------------------------------------------------------------------
-- 2. APP.F_WHATIF_PROJECTION TABLE FUNCTION
-- Pure Prescriptive Simulation Function (Illustrative Linear Projection)
-- 
-- NOTE: In Snowflake SQL, callers must explicitly pass FLOAT typed arguments:
--       SELECT * FROM TABLE(SC_ONTOLOGY.APP.F_WHATIF_PROJECTION(
--           64.12::FLOAT, 15.0::FLOAT, 20.0::FLOAT, 7.0::FLOAT, 10.0::FLOAT
--       ));
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION APP.F_WHATIF_PROJECTION(
    P_BASELINE_OTD FLOAT,
    P_EXPEDITE_PCT FLOAT,
    P_ALT_SUPPLIER_PCT FLOAT,
    P_SAFETY_STOCK_DAYS FLOAT,
    P_DEMAND_SHOCK_PCT FLOAT
)
RETURNS TABLE (
    BASELINE_OTD_PCT NUMBER(5,2),
    EXPEDITE_PCT NUMBER(5,2),
    ALT_SUPPLIER_PCT NUMBER(5,2),
    SAFETY_STOCK_DAYS NUMBER(5,2),
    DEMAND_SHOCK_PCT NUMBER(5,2),
    PROJECTED_OTD_PCT NUMBER(5,2),
    PROJECTED_STOCKOUT_RISK_PCT NUMBER(5,2),
    BASELINE_PENALTY_USD NUMBER(12,2),
    PROJECTED_PENALTY_EXPOSURE_USD NUMBER(12,2),
    PENALTY_AVOIDED_USD NUMBER(12,2),
    INTERVENTION_COST_USD NUMBER(12,2),
    NET_COST_IMPACT_USD NUMBER(12,2),
    IS_ILLUSTRATIVE BOOLEAN,
    ASSUMPTIONS_SUMMARY VARCHAR(1000)
)
COMMENT = 'Pure SQL table function simulating OTD uplift, stockout risk reduction, penalty exposure, and net cost under what-if supply chain intervention levers. Illustrative linear model parameterized by APP.SIM_COEFFICIENTS. NET_COST_IMPACT_USD = INTERVENTION_COST_USD - PENALTY_AVOIDED_USD.'
AS
$$
    WITH coeffs AS (
        SELECT 
            MAX(CASE WHEN COEFFICIENT_NAME = 'EXPEDITE_OTD_UPLIFT_PER_PCT' THEN COEFFICIENT_VALUE END) AS C_EXP_OTD,
            MAX(CASE WHEN COEFFICIENT_NAME = 'EXPEDITE_COST_USD_PER_PCT' THEN COEFFICIENT_VALUE END) AS C_EXP_COST,
            MAX(CASE WHEN COEFFICIENT_NAME = 'ALT_SUPPLIER_OTD_UPLIFT_PER_PCT' THEN COEFFICIENT_VALUE END) AS C_ALT_OTD,
            MAX(CASE WHEN COEFFICIENT_NAME = 'ALT_SUPPLIER_COST_USD_PER_PCT' THEN COEFFICIENT_VALUE END) AS C_ALT_COST,
            MAX(CASE WHEN COEFFICIENT_NAME = 'SAFETY_STOCK_RISK_REDUCTION_PER_DAY' THEN COEFFICIENT_VALUE END) AS C_SS_RISK,
            MAX(CASE WHEN COEFFICIENT_NAME = 'SAFETY_STOCK_HOLDING_COST_PER_DAY' THEN COEFFICIENT_VALUE END) AS C_SS_COST,
            MAX(CASE WHEN COEFFICIENT_NAME = 'DEMAND_SHOCK_OTD_DRAG_PER_PCT' THEN COEFFICIENT_VALUE END) AS C_SHOCK_OTD,
            MAX(CASE WHEN COEFFICIENT_NAME = 'DEMAND_SHOCK_STOCKOUT_RISK_PER_PCT' THEN COEFFICIENT_VALUE END) AS C_SHOCK_RISK,
            MAX(CASE WHEN COEFFICIENT_NAME = 'BASE_STOCKOUT_RISK_PCT' THEN COEFFICIENT_VALUE END) AS C_BASE_RISK,
            MAX(CASE WHEN COEFFICIENT_NAME = 'BASE_PENALTY_PER_OTD_POINT_USD' THEN COEFFICIENT_VALUE END) AS C_PENALTY_RATE,
            MAX(CASE WHEN COEFFICIENT_NAME = 'OTD_TARGET_PCT' THEN COEFFICIENT_VALUE END) AS C_OTD_TARGET
        FROM APP.SIM_COEFFICIENTS
    ),
    calc AS (
        SELECT 
            P_BASELINE_OTD AS B_OTD,
            P_EXPEDITE_PCT AS EXP_P,
            P_ALT_SUPPLIER_PCT AS ALT_P,
            P_SAFETY_STOCK_DAYS AS SS_D,
            P_DEMAND_SHOCK_PCT AS SHOCK_P,
            
            -- Raw Projected OTD = Baseline + (Expedite * coeff) + (AltSupplier * coeff) - (DemandShock * coeff)
            B_OTD + (EXP_P * C_EXP_OTD) + (ALT_P * C_ALT_OTD) - (SHOCK_P * C_SHOCK_OTD) AS RAW_PROJ_OTD,
            
            -- Raw Projected Stockout Risk = Base Risk + (DemandShock * coeff) - (SafetyStock * coeff)
            C_BASE_RISK + (SHOCK_P * C_SHOCK_RISK) - (SS_D * C_SS_RISK) AS RAW_PROJ_STOCKOUT,
            
            -- Baseline Penalty Exposure (Levers = 0)
            GREATEST(0.0, (C_OTD_TARGET - B_OTD) * C_PENALTY_RATE) AS BASE_PENALTY,
            
            -- Direct Intervention Costs
            (EXP_P * C_EXP_COST) + (ALT_P * C_ALT_COST) + (SS_D * C_SS_COST) AS TOTAL_INTERVENTION_COST,
            
            C_PENALTY_RATE,
            C_OTD_TARGET
        FROM coeffs
    ),
    projected AS (
        SELECT 
            B_OTD,
            EXP_P,
            ALT_P,
            SS_D,
            SHOCK_P,
            -- Clamped Projected OTD [0.0, 100.0]
            GREATEST(0.0, LEAST(100.0, RAW_PROJ_OTD)) AS CLAMPED_OTD,
            -- Clamped Projected Stockout Risk [0.0, 100.0]
            GREATEST(0.0, LEAST(100.0, RAW_PROJ_STOCKOUT)) AS CLAMPED_STOCKOUT,
            -- Baseline Penalty USD
            BASE_PENALTY,
            -- Projected Penalty Exposure: penalty rate * max(0, OTD_TARGET - Clamped OTD)
            GREATEST(0.0, (C_OTD_TARGET - GREATEST(0.0, LEAST(100.0, RAW_PROJ_OTD))) * C_PENALTY_RATE) AS PROJ_PENALTY,
            -- Penalty Avoided USD
            BASE_PENALTY - GREATEST(0.0, (C_OTD_TARGET - GREATEST(0.0, LEAST(100.0, RAW_PROJ_OTD))) * C_PENALTY_RATE) AS PENALTY_AVOIDED,
            TOTAL_INTERVENTION_COST,
            -- Net Cost Impact = Intervention Cost - Penalty Avoided
            TOTAL_INTERVENTION_COST - (BASE_PENALTY - GREATEST(0.0, (C_OTD_TARGET - GREATEST(0.0, LEAST(100.0, RAW_PROJ_OTD))) * C_PENALTY_RATE)) AS NET_COST
        FROM calc
    )
    SELECT 
        ROUND(B_OTD, 2)::NUMBER(5,2) AS BASELINE_OTD_PCT,
        ROUND(EXP_P, 2)::NUMBER(5,2) AS EXPEDITE_PCT,
        ROUND(ALT_P, 2)::NUMBER(5,2) AS ALT_SUPPLIER_PCT,
        ROUND(SS_D, 2)::NUMBER(5,2) AS SAFETY_STOCK_DAYS,
        ROUND(SHOCK_P, 2)::NUMBER(5,2) AS DEMAND_SHOCK_PCT,
        ROUND(CLAMPED_OTD, 2)::NUMBER(5,2) AS PROJECTED_OTD_PCT,
        ROUND(CLAMPED_STOCKOUT, 2)::NUMBER(5,2) AS PROJECTED_STOCKOUT_RISK_PCT,
        ROUND(BASE_PENALTY, 2)::NUMBER(12,2) AS BASELINE_PENALTY_USD,
        ROUND(PROJ_PENALTY, 2)::NUMBER(12,2) AS PROJECTED_PENALTY_EXPOSURE_USD,
        ROUND(PENALTY_AVOIDED, 2)::NUMBER(12,2) AS PENALTY_AVOIDED_USD,
        ROUND(TOTAL_INTERVENTION_COST, 2)::NUMBER(12,2) AS INTERVENTION_COST_USD,
        ROUND(NET_COST, 2)::NUMBER(12,2) AS NET_COST_IMPACT_USD,
        TRUE AS IS_ILLUSTRATIVE,
        'Linear prescriptive model parameterized by APP.SIM_COEFFICIENTS. OTD clamped [0,100], Stockout clamped [0,100]. Illustrative simulation only.' AS ASSUMPTIONS_SUMMARY
    FROM projected
$$;
