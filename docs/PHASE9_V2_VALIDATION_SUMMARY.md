# SC_ONTOLOGY v2 Additive Enhancement — CLI Validation Test Summary (Phase 9)

**Execution Date**: October 2, 2026  
**Warehouse**: `HACK_WH` (XSMALL)  
**Database**: `SC_ONTOLOGY`  
**Overall Result**: **8 / 8 PASS** (100% Pass Rate)

---

## Validation Scorecard (T1 – T8)

| Test ID | Test Name | Expected Result | Actual Result | Status | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **T1** | **Governance Registry & Provenance Function** | 8 active metrics in `GOVERNANCE.METRIC_REGISTRY`; `F_METRIC_PROVENANCE('MTR-OUTBOUND-OTD')` returns `CONFIDENCE_TIER = 'Verified'` & `PRIMARY_SOURCE_TABLE = 'CURATED.FACT_OUTBOUND_SHIPMENTS'` | Count = 8; Tier = `Verified`, Table = `CURATED.FACT_OUTBOUND_SHIPMENTS`, Row Count = 15,000 | **PASS** | Complete metadata provenance and lineage verified. |
| **T2** | **Drift Sentinel (Read-Only)** | Latest `V_GOVERNANCE_HEALTH` row `STATUS = 'ALIGNED'`, Canonical = 64.12%, Planning = 83.51%, Procurement = 96.65%, Logistics = 64.12% | Status = `ALIGNED`, Canonical = 64.12%, Planning = 83.51%, Procurement = 96.65%, Logistics = 64.12% | **PASS** | Governed OTD matches logistics numerically but maintains line-level promised-date definition. |
| **T3** | **Persona Consistency via DATA_AGENT_RUN** | Planner, Procurement, and Logistics questions regarding Q3 2026 all return 64.12%, cite `GOVERNANCE.METRIC_REGISTRY`, and do NOT ask clarifying questions | All 3 personas returned 64.12%, cited `GOVERNANCE.METRIC_REGISTRY`, and returned complete responses without clarification | **PASS** | Semantic View grounding ensures mathematical consistency across disparate phrasing. |
| **T4** | **Agent Guardrails** | (a) Ambiguous "on-time rate" -> asks ONE clarifying question (Inbound vs Outbound); (b) "Weather in Munich" -> polite out-of-scope refusal | (a) Asked clarifying question between Outbound Customer vs Inbound Supplier OTD; (b) Refused weather query politely; zero action tools called | **PASS** | Guardrails operate deterministically on both ambiguity and out-of-scope intents. |
| **T5** | **Risk + Recommendations** | `V_RISK_SIGNALS` = 38 rows, all `Low` priority (<40), max score < 40, top entity = `SUP-104`; `CARR-01/03/07` flagged (>38.88%) & `CARR-04` NOT flagged; `APP.RECOMMENDATIONS` = 13 `PROPOSED` rows matching candidate view | 38 rows, all `Low` (max 36.83, top = `SUP-104`); `CARR-01/03/07` FLAGGED, `CARR-04` NOT_FLAGGED (35.59%); exactly 13 PROPOSED rows (0 diff) | **PASS** | Dynamic relative carrier threshold and supplier risk components verified. |
| **T6** | **What-If Simulation Function** | Pure table function with `::FLOAT` args: Baseline (64.12, 0,0,0,0) -> 64.12 OTD, $0 net cost; Scenario (64.12, 15,20,7,10) -> 68.37 OTD, 26.50 risk, +$36,625 net cost; Extreme (64.12, 30,50,14,-20) -> OTD $\le 100$, risk $\ge 0$ | Baseline: 64.12 OTD, $0 net cost; Scenario: 68.37 OTD, 26.50 risk, +$36,625 net cost; Extreme: 88.62 OTD, 0.00 risk (clamped) | **PASS** | Pure table function reads `APP.SIM_COEFFICIENTS` with zero data mutations. |
| **T7** | **Escalation Guardrail (Negative Test)** | `CALL APP.SP_CREATE_ACTION_ITEM(..., 'URGENT', ...)` rejected with `ERROR: Invalid severity...`; `APP.ACTIONS` count remains 1 | Returned `'ERROR: Invalid severity: URGENT. Allowed values: LOW, MEDIUM, HIGH, CRITICAL.'`; `APP.ACTIONS` count = 1 | **PASS** | Parameter validation prevents unauthorized/malformed action insertions. |
| **T8** | **App + Safety State Verification** | `SHOW STREAMLITS` lists `SUPPLY_CHAIN_CONTROL_TOWER` on `HACK_WH`; `LIST @STREAMLIT_STAGE` shows `streamlit_app.py`; 12M Outbound OTD = 66.12%; Tasks = suspended; `APP.ACTIONS` = 1 | App active on `HACK_WH`; `streamlit_app.py` staged (41,920 bytes); 12M OTD = 66.12%; all 3 tasks `suspended`; `APP.ACTIONS` = 1 | **PASS** | Safe, isolated deployment with zero unexpected writes or background tasks. |

---

## Safety & Governance State

- **`APP.ACTIONS` Row Count**:
  - Baseline (Start): **1**
  - Post-Test (End): **1**
- **Scheduled Tasks**:
  - `SC_ONTOLOGY.APP.TSK_ANOMALY_WATCHDOG`: `suspended`
  - `SC_ONTOLOGY.APP.TSK_DAILY_METRIC_CONSISTENCY_TEST`: `suspended`
  - `SC_ONTOLOGY.GOVERNANCE.TSK_DRIFT_SENTINEL`: `suspended`
