# Apex Supply Chain Control Tower — User Manual

**App:** `SC_ONTOLOGY.APP.SUPPLY_CHAIN_CONTROL_TOWER` (Streamlit in Snowflake)
**Open it:** Snowsight → Projects → Streamlit → SUPPLY_CHAIN_CONTROL_TOWER
**URL:** https://app.snowflake.com/zhsbcwu/tn70880/#/streamlit-apps/SC_ONTOLOGY.APP.SUPPLY_CHAIN_CONTROL_TOWER
**Version:** v2 (6 pages), with the 8 Oct 2026 fixes

---

## 0. Before you start

### 0.1 What this app is
Apex Industrial Components is a fictional manufacturer with 4 plants, 30 suppliers, 8 carriers, 100 customers and 12 months of synthetic history. Its Planning, Procurement and Logistics teams each calculated "on-time delivery" differently, so leadership got three different numbers for the same quarter.

The app shows how one **governed ontology** (a single set of agreed business definitions) fixes that, and then goes further:

| Step | Page | One-line meaning |
|---|---|---|
| See | 1. Command Center, 2. Monitor | What is happening, and why the old numbers disagreed |
| Ask | 3. Ask | Ask in plain English and get one trusted answer with its formula |
| Trust | 4. Govern | Prove the definition is approved, monitored and traceable |
| Decide | 5. Decide | Rank the risks, propose fixes, simulate the impact |
| Act | 6. Act | Turn a decision into a tracked action item, with a guard against accidental writes |

### 0.2 Layout
- **Left sidebar:** the 6 page links, plus an info box (warehouse `HACK_WH (XSMALL)`, database `SC_ONTOLOGY`, role `ACCOUNTADMIN`).
- **Top banner:** the app title and the caption "Powered by Snowflake Cortex".
- **Tables:** hover over a table to get a search icon and a full-screen icon. Click a column header to sort.
- **Charts:** hover for tooltips. Use the "…" menu to save as PNG or SVG.

### 0.3 Which buttons change data
Most of the app is read-only. Only these **4 buttons** write data:

| Button | Page | What it writes |
|---|---|---|
| Run Live Drift Check | 4. Govern | 1 new row in `APP.CONSISTENCY_LOG` |
| Generate Recommendations | 5. Decide | Refreshes the PROPOSED rows in `APP.RECOMMENDATIONS` (stays at 13) |
| Escalate to Action Item (checkbox required) | 5. Decide | 1 new row in `APP.ACTIONS` |
| Submit Action Item (checkbox required) | 6. Act | 1 new row in `APP.ACTIONS` |

**Ask Cortex Agent** writes nothing, but it uses AI credits for each question.

### 0.4 Glossary of terms used on screen
| Term | Meaning |
|---|---|
| **OTD (On-Time Delivery)** | % of delivered lines that arrived on or before the **promised** date |
| **OTIF (On-Time In-Full)** | On time **and** with the full quantity |
| **Outbound** | Apex → customer (sales shipments) |
| **Inbound** | Supplier → Apex (purchase orders / goods receipts) |
| **DOI (Days of Inventory)** | How many days the stock on hand lasts at the recent daily usage rate |
| **Landed cost** | Purchase price + inbound freight + duty + handling, per unit received |
| **Q3 2026 order cohort** | Orders **placed** between 1 Jul and 30 Sep 2026, judged by when they were delivered |
| **12-month window** | All history in the dataset (Oct 2025 – Sep 2026) |
| **Canonical / governed** | The single approved definition stored in the Metric Registry |
| **Legacy** | The three old team-specific definitions (Planning, Procurement, Logistics) |
| **Illustrative** | An estimate from a documented heuristic, not a calibrated forecast |

---

## 1. Command Center (home page)

**Purpose:** a one-screen executive summary. This page is read-only.

### 1.1 Governance status banner (blue bar at the top)
> 🛡️ Governance Status: **8 metrics governed · 1 drift-monitored (Outbound OTD, Q3 2026 order cohort) · ALIGNED**

| Part | Meaning | Source |
|---|---|---|
| **8 metrics governed** | 8 active metric definitions are approved in the registry | `GOVERNANCE.METRIC_REGISTRY` (IS_ACTIVE = TRUE) |
| **1 drift-monitored** | Only Outbound OTD for the Q3 2026 cohort is checked automatically against the legacy numbers | Wording fixed by design |
| **ALIGNED / DRIFT** | Result of the latest drift check | `GOVERNANCE.V_GOVERNANCE_HEALTH` |

Never read this as "8 of 8 aligned". Only one metric is monitored.

### 1.2 The four metric cards
| Card | Typical value | What it means | How it is calculated |
|---|---|---|---|
| **Open Action Items** · "Awaiting Review" | e.g. 8 | Action tickets still in status `OPEN_PENDING_REVIEW`. The red arrow is intentional: more open items is worse | `COUNT(*)` of `APP.ACTIONS` where STATUS = 'OPEN_PENDING_REVIEW' |
| **Proposed Recommendations** · "Prescriptive Engine" | 13 | Fixes suggested by the rules engine and not yet acted on | `COUNT(*)` of `APP.RECOMMENDATIONS` where STATUS = 'PROPOSED' |
| **Network Outbound OTD** · "12-Month History Window" | **66.12%** | Customer on-time delivery over the full 12 months, all plants (9,816 on-time / 14,850 delivered lines) | On-time delivered lines ÷ delivered lines in `CURATED.FACT_OUTBOUND_SHIPMENTS` |
| **Q3 2026 Cohort OTD** · "Governed Benchmark" | **64.12%** | The same metric, only for orders placed in Q3 2026 (2,193 / 3,420). This is the headline number every persona must agree on | Same formula, filtered to `DIM_DATE.QUARTER_YEAR = 'Q3 2026'` on order date |

The two OTD values differ because they cover different time windows, not because of a mistake. Q3 was a worse quarter than the yearly average.

### 1.3 Top 5 Risk Signals table (left)
Lists the 5 suppliers or carriers with the highest risk score, from `APP.V_RISK_SIGNALS`.

| Column | Meaning |
|---|---|
| ENTITY_TYPE / ENTITY_ID / ENTITY_NAME | SUPPLIER (SUP-xxx) or CARRIER (CARR-xx) |
| TOTAL_EVENTS | PO lines (suppliers) or shipment lines (carriers) analysed |
| LATE_RATE_% | % of delivered lines that were late |
| VOLATILITY_SCORE | How unpredictable the lead time or delay is. Standard deviation in days × 10, capped at 100 |
| SLA_BREACH_% | Suppliers: how far actual OTIF falls below the contract target. Carriers: % of deliveries ≥ 5 days late |
| STOCKOUT_RISK_% | Suppliers: % of their part-plant combinations with under 15 days of inventory. Carriers: backorder rate |
| RISK_SCORE | 0.35 × Late + 0.25 × Volatility + 0.20 × SLA breach + 0.20 × Stockout (0–100) |
| PRIORITY | Critical ≥ 80, High ≥ 60, Medium ≥ 40, Low < 40 |
| EST_PENALTY_USD | Illustrative penalty exposure: 5% of the spend or freight on late lines |

**How to read today's data:** all 38 entities (30 suppliers + 8 carriers) are in the **Low** band on this absolute 0–100 scale. The ranking still matters. **SUP-104 Titan Micro-Foundry** is top with **36.83**, followed by carriers **CARR-01, CARR-07 and CARR-03**, which are late about 47% of the time against a network average of about 34%.

### 1.4 Top 10 Risk Exposure chart
A horizontal bar per entity on a fixed 0–100 axis. The dashed line at **40** marks the "Low band < 40" boundary. Every bar sits left of it, which shows visually that no entity is above Low yet.

### 1.5 Proposed Recommendations by Issue (right)
Counts the PROPOSED recommendations by type:

| ISSUE_TYPE | Count today | Owner |
|---|---|---|
| BUFFER_STOCKOUT_RISK | 8 | Supply Chain Planning |
| CARRIER_CHRONIC_DELAY | 3 | Logistics Operations |
| HIGH_LEAD_TIME_VOLATILITY | 1 | Procurement Lead |
| SLA_BREACH_PENALTY_RISK | 1 | Vendor Management |

### 1.6 Curated Data Layer Freshness (bottom)
The 6 largest curated tables, from `GOVERNANCE.V_DATA_FRESHNESS`:
- **ROW_COUNT / SIZE_KB:** how much data the table holds.
- **LAST_REFRESH_TIME:** when Snowflake last refreshed the table.
- **LATEST_DATA_DATE:** the newest business date inside the data.

If LAST_REFRESH_TIME is recent, the pipeline is alive.

---

## 2. Monitor

The page has two tabs.

### 2.1 Tab "Executive KPIs"
**Filters:**
- **Filter by Manufacturing Plant:** all 4 plants are selected by default (Austin, Binh Duong, Columbus, Munich). Remove a plant by clicking its ×.
- **Filter by Order Quarter:** defaults to **Q3 2026**. Add quarters to widen the window. Clearing all quarters means "all quarters".

**KPI cards** (all update with the filters):

| Card | Default value (all plants, Q3 2026) | Meaning |
|---|---|---|
| **Outbound OTD (Customer)** · "Promised Date Basis" | 64.12% | Customer lines delivered on or before the promised date |
| **Inbound OTIF (Suppliers)** · "Target: ≥92%" | 89.87% | Supplier PO lines received on time **and** in full. This is below the 92% target |
| **Days of Inventory (DOI)** · "Total On-Hand / Daily Use" | 15.2 days | Total on-hand ÷ total average daily consumption over the last 30 days. **Only the plant filter applies** (it uses the current inventory snapshot) |
| **Avg Landed Cost / Unit** · "All-in Procurement" | $89.8 | (Purchase + freight + duty + handling) ÷ units received |

**Charts:**
- **Monthly Outbound OTD Trend by Plant:** one line per plant, by month, inside the selected quarters.
- **Inventory Valuation by Plant ($ USD):** current inventory value per plant. Only the plant filter applies.

Try this: select only Munich, then add Q2 2026, and watch every card and chart change.

### 2.2 Tab "Before vs After Consistency"
Shows the original problem: three legacy team numbers for the same quarter, next to the governed number.

| Perspective | Old rule | Reported |
|---|---|---|
| Legacy Planning | Plant **dispatch** date ≤ promised date (ignores transit) | **83.51%** |
| Legacy Procurement | Goods-receipt date ≤ supplier commit date **+ 3-day grace** (actually an inbound measure) | **96.65%** |
| Legacy Logistics | Proof of delivery ≤ customer **requested** date (shipment header grain) | **64.12%** |
| **Governed ontology** | Actual delivery ≤ **promised** date, per delivered **line** | **64.12%** |

**Blue disclosure box:** Legacy Logistics and the governed number are equal **only numerically**, because of how the synthetic data was generated. Their definitions are different (requested date vs promised date, header grain vs line grain). Always say this out loud.

This tab is a fixed explanatory table. The live, recomputed comparison is on **4. Govern → Governance Health**.

---

## 3. Ask (conversational analytics)

**Purpose:** ask supply-chain questions in plain English. A Cortex Agent answers using the governed semantic model, so different wording gives the **same** number.

### 3.1 Controls
| Control | What it does |
|---|---|
| **📋 Planner / 📦 Procurement / 🚚 Logistics Persona Question** | Fills the question box with that persona's wording (it does not send the question) |
| **Enter a supply chain question** | Free text. You can type anything |
| **🚀 Ask Cortex Agent** | Sends the question to `APP.SC_ONTOLOGY_AGENT`. Takes about 10–40 seconds and uses AI credits |

The three persona questions:
- Planner: *"What was our promised-date delivery performance for orders placed in Q3 2026?"*
- Procurement: *"How timely were customer deliveries for orders placed in Q3 2026?"*
- Logistics: *"What percentage of delivered order lines met the promised date for orders placed in Q3 2026?"*

The expected answer for all three is **64.12%**.

### 3.2 What the response contains
1. **Cortex Agent Response:** the agent's own answer in plain English. It includes the canonical metric name, the formula, a mention of the Governed Metric Registry, and usually the counts (2,193 / 3,420).
2. **View Analyst-Generated SQL** (expander, when shown): the exact SQL the agent generated and ran.
3. **🛡️ Metric Provenance: Outbound OTD** (green box). It appears when the question is about delivery or OTD and shows:
   - **Verified Metric Provenance:** `MTR-OUTBOUND-OTD`, Confidence Tier **Verified**, Approved by **Data Governance Council**.
   - **Exact Governed Formula:** the formula from the registry.
   - **Evaluation Grain / Owner Team:** Customer / Plant / Month, owned by Logistics.
   - **Primary Source Table:** `CURATED.FACT_OUTBOUND_SHIPMENTS`, with its row count and refresh time.
   - **Semantic View Lineage:** `SEMANTIC.SV_SUPPLY_CHAIN_INTELLIGENCE` → fact table.
4. **📐 Deterministic Cohort Parity Check** (blue box, persona questions only): the app recomputes the number directly in SQL, **independent of the AI**, so you can see the agent's answer matches (64.12%, 2,193 / 3,420).

**Confidence tiers:** *Verified* means the metric is in the registry and linked to a verified query. *Governed/Ad-hoc* means it's in the registry but not linked to one. *Unverified* means it isn't in the registry.

### 3.3 Guardrails (try these)
| You ask | The agent should |
|---|---|
| "What is our on-time rate?" (no inbound/outbound) | Ask **one** clarifying question: customer outbound or supplier inbound? |
| "What is the weather in Munich tomorrow?" | Politely refuse and redirect to supply-chain topics |
| "What are the SLA terms for Titan Micro-Foundry?" | Use **contract search** and quote the clauses (≥95% OTIF target; a 5% rebate plus executive review below 80%) |

The chat cannot create actions. The action tool is deliberately excluded from the chat.

**Known nit:** the provenance badge is triggered by keywords, so a question containing "delivery" that is really about inbound may still show the Outbound badge.

---

## 4. Govern

The page has three tabs.

### 4.1 Tab "Governance Health" (drift sentinel)
- **Current Sentinel Status pill:** green **● ALIGNED** or red **▲ DRIFT**.
- **Table** (from `GOVERNANCE.V_GOVERNANCE_HEALTH`, latest run):

| Column | Meaning |
|---|---|
| METRIC_NAME | `Outbound_OTD_Q3_2026` |
| CANONICAL_VALUE | Governed value, recomputed (64.12) |
| LEGACY_LOGISTICS_VAL / PLANNING_VAL / PROCUREMENT_VAL | Values from the three legacy views (64.12 / 83.51 / 96.65) |
| DELTA_VS_LOGISTICS / PLANNING / PROCUREMENT | Canonical minus each legacy value (0 / −19.39 / −32.53) |
| DELTA_MAX | Largest absolute gap (32.53) |
| STATUS | **ALIGNED** if the gap between canonical and **legacy Logistics** is ≤ 0.5 points, otherwise **DRIFT** |
| LAST_CHECKED / LOG_ID | When the check ran, and its ID (DFT-yyyymmdd-hhmmss) |

- **🔄 Run Live Drift Check:** recomputes all four values now, writes 1 log row, and shows a green "SUCCESS: Drift Check completed (ALIGNED) …" message.

The large Planning and Procurement deltas are **expected**. They are the "before" problem, so they don't turn the status red. Only the Logistics-vs-canonical comparison decides ALIGNED or DRIFT.

### 4.2 Tab "Metric Glossary"
A live list of the 8 governed metrics from `GOVERNANCE.METRIC_REGISTRY`:

| Key | Metric | Owner |
|---|---|---|
| MTR-OUTBOUND-OTD | Outbound OTD % | Logistics |
| MTR-OUTBOUND-OTIF | Outbound OTIF % | Planning |
| MTR-INBOUND-OTD | Inbound OTD % | Procurement |
| MTR-INBOUND-OTIF | Inbound OTIF % | Procurement |
| MTR-DAYS-INVENTORY | Days of Inventory | Planning |
| MTR-UNIT-LANDED-COST | Unit Landed Cost | Procurement |
| MTR-LEAD-TIME-VAR | Supplier Lead Time Variance | Procurement |
| MTR-BACKORDER-RATE | Backorder Rate % | Planning |

Columns: business definition, exact SQL formula, grain, owner, verified query reference, version and approver. If the registry changes, this tab changes too. Nothing on it is hard-coded.

### 4.3 Tab "Ontology & Lineage"
A diagram of the business model:
- **Yellow boxes (dimensions):** Supplier, Part, Plant, Product, Customer, Carrier.
- **Green boxes (facts):** Purchase Orders, Outbound Shipments, Inventory Position.
- **Purple box:** Bill of Materials (parts → products).
- **Arrows:** relationships, e.g. Supplier *issues to* PO, Carrier *transported by* Shipment.

Use the full-screen icon for presenting.

---

## 5. Decide

The page has two tabs.

### 5.1 Tab "Prescriptive Recommendations"
**a) Active Risk Signals:** the full list of all 38 entities, with the same columns as the Command Center table (see 1.3), ranked by RISK_SCORE.

**🔄 Generate Recommendations:** re-runs the rules against the latest risk signals. It shows "SUCCESS: Generated recommendations. Total: 13, Proposed: 13". The run is safe to repeat: it never duplicates rows and never touches approved or executed rows.

**b) Governed Recommendations Table:** one row per recommendation.

| Column | Meaning |
|---|---|
| RECOMMENDATION_ID | `REC-<entity>-<issue>`, e.g. REC-SUP-104-SLA_BREACH_PENALTY_RISK |
| ISSUE_TYPE / RECOMMENDATION_TEXT | What was detected and what to do |
| OTD_UPLIFT_% (ILLUSTRATIVE) | Expected OTD improvement **for that entity** |
| COST_DELTA_$ (ILLUSTRATIVE) | Expected cost of the action |
| PENALTY_AVOID_$ (ILLUSTRATIVE) | Expected penalty avoided (a share of that entity's penalty exposure) |
| OWNER_ROLE / PRIORITY / STATUS | Who owns it, its risk band, and PROPOSED |
| SOURCE_SIGNALS | The exact numbers that triggered it (JSON) |

**Never add up** the uplift or penalty columns across rows. They are per-entity estimates that overlap.

The rules:
| Rule | Trigger | Recommendation |
|---|---|---|
| Lead-time volatility | Supplier volatility score ≥ 50 | Dual-source and expedite part of the volume |
| SLA breach + penalty | Supplier SLA shortfall ≥ 30 points **and** penalty exposure > $10,000 | Executive recovery plan and rebate clawback |
| Stockout buffer | Supplier stockout risk ≥ 15% | +7 days of safety stock, adjust the reorder point |
| Chronic carrier delay | Carrier late rate ≥ network average + 5 points | Route swap or split shipment lanes |

**c) 🔍 View Recommendation Trigger Signals:** expand it to see the SOURCE_SIGNALS JSON for every recommendation. This answers "why this recommendation?".

**d) 🚨 Escalate Recommendation to Operational Action:**
1. Pick a recommendation in **Select Recommendation to Escalate**. The blue box and the text on the right update to show the target entity, issue and recommendation.
2. Tick **"I explicitly confirm creating this governed operational action item…"**.
3. Click **🚀 Escalate to Action Item**.

- Without the tick, you get a yellow warning and nothing is written.
- With the tick, a new action is created (suppliers → `SUPPLIER_ESCALATION`, carriers → `CARRIER_REVIEW`; severity HIGH for High/Critical priority, otherwise MEDIUM). The green success message with the new ACTION_ID appears at the **top of the tab**, so scroll up to see it.

### 5.2 Tab "What-If Simulation Lab"
A yellow banner says **ILLUSTRATIVE MODEL**: the numbers come from documented linear assumptions, not a calibrated forecast.

**Inputs:**
| Input | Range | Default | Meaning |
|---|---|---|---|
| Governed Baseline Outbound OTD % | 0–100 | 64.12 | Starting point (the Q3 2026 cohort) |
| Premium Freight Expedite Allocation | 0–30% | 15 | Share of volume moved to faster, pricier freight |
| Dual-Sourced Secondary Supplier Allocation | 0–50% | 20 | Share of volume split to a second supplier |
| Safety Stock Buffer Increase | 0–14 days | 7 | Extra days of buffer stock |
| Unanticipated Demand Surge Shock | −20 to +20% | +10 | Demand spike (positive) or drop (negative) |

**Outputs** (with the defaults):
| Card | Value | Meaning |
|---|---|---|
| Projected Outbound OTD | **68.37%** (+4.25 vs baseline) | Baseline + 0.25 × expedite + 0.20 × alt supplier − 0.35 × demand shock |
| Projected Stockout Risk | **26.5%** (assumed base 40%) | 40 + 0.40 × shock − 2.5 × safety-stock days |
| Projected Penalty Exposure | **$75,705** (−$14,875 avoided) | (90% target − projected OTD) × $3,500 per point |
| Net Cost Impact | **+$36,625** | Intervention cost ($51,500) − penalty avoided ($14,875). Positive = costs more than it saves |

- **Financial Analysis box:** blue "This scenario does not pay back…" when the net cost is positive, or green "Net positive ROI" when it's negative.
- **Charts:** Baseline vs Projected (%) for OTD and stockout risk, and Penalty Exposure (USD).
- **Raw result table:** every output column from `APP.F_WHATIF_PROJECTION`.
- **Simulation Model Parameter Registry:** all 11 coefficients from `APP.SIM_COEFFICIENTS`, each marked "Assumed (illustrative)".

Try this: set expedite and alt supplier to 0 and safety stock to 0, and you get the baseline. Raising safety stock lowers stockout risk but increases cost.

---

## 6. Act

### 6.1 Actions & Escalation Tracker
The full `APP.ACTIONS` log, newest first.

| Column | Meaning |
|---|---|
| ACTION_ID | `ACT-yyyymmdd-hhmmss-xxxx` |
| ACTION_TYPE | SUPPLIER_ESCALATION, IOT_ALERT, INVENTORY_REORDER, CARRIER_REVIEW, PROCESS_AUDIT |
| TARGET_ENTITY_TYPE / ID | What the action is about, e.g. SUPPLIER / SUP-104 |
| SEVERITY | LOW, MEDIUM, HIGH, CRITICAL |
| DESCRIPTION | Free text |
| STATUS | OPEN_PENDING_REVIEW for new items |
| CREATED_BY / CREATED_AT | Who and when |

IOT_ALERT rows would come from the IoT watchdog task, which is **suspended** to save cost.

### 6.2 Create Governed Action Item / Supplier Escalation
1. Choose **Action Type**, **Target Entity Type**, **Target Entity ID** (default SUP-104), **Severity** (HIGH = Level-2) and **Description**.
2. Tick **"I confirm this governed operational ticket should be created in APP.ACTIONS"**.
3. Click **🚀 Submit Action Item**.

- Without the tick, you get a yellow warning and nothing is written.
- With the tick, a green "SUCCESS: Created Action Item ACT-… [SUPPLIER_ESCALATION] for SUPPLIER SUP-104 with Severity HIGH" message appears.
- The stored procedure also validates every input. An invalid value or a description under 5 or over 1,000 characters returns `ERROR: …` and nothing is written.

The checkbox stays ticked after a submit. Untick it before the next one if you want the guard back in place.

---

## 7. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Page shows a red "AttributeError: … has no attribute 'rerun'" | Fixed on 8 Oct. Close and reopen the app tab to load the new code |
| A page looks blank under its tabs | Fixed on 8 Oct. If it happens again, click the first tab |
| Persona button seems to send the Planner question | Fixed on 8 Oct. Check that the question box shows the persona wording before clicking Ask |
| Agent takes long or times out | Cold warehouse or agent latency. Wait about 40 s and retry once |
| "Execution Error" on Ask | Agent or service issue. Retry, then check `SHOW AGENTS IN SCHEMA SC_ONTOLOGY.APP` |
| Numbers look different from this manual | Data or test rows changed (e.g. Open Action Items grows each time you escalate) |
