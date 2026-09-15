# Plan v2.02 — Practice Live Account Simulation

**Date:** 2026-09-15 · **Status:** complete  
**Scope:** Micro-account practice packs ($20 / $50 / $100) for **Standard** and **Raw** brokers, with Scalp / Day / Swing coach tips on Trade Center. Extends Velocity desk; no bus schema change; no virtual balance.

## Decision lock

| Item | Choice |
|---|---|
| Delivery | Presets + playbook + Full Trade Center coach buttons |
| Cost models | Raw vs Standard first-class |
| Styles | Scalp / Day / Swing (Day baked into `.set`) |
| Soft apply | Fleet target + category filter + coach copy only |
| Money knobs | Authoritative in Service + Scouter `.set` (restart after Load) |
| Balance | Real demo/live broker equity only |

## Deliverables

1. `Include/GSignalX/PracticeSim.mqh` — profile builder + coach formatters  
2. Roster GVs `GSX_MS_PRAC_BAND/COST/STYLE_{magic}` + panel Practice row  
3. 6 Service + 6 Scouter presets under `deploy/presets/`  
4. `docs/PRACTICE_LIVE_SIM_20_50_100.md` playbook  

## Invariant

Dashboard / PropRisk never reverse-close. Practice UI does not mutate Prop money inputs at runtime. Session clock remains illustrative; MarketGates stay authoritative.
