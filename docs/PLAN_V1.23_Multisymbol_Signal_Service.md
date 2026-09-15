# Plan v1.23 — Multisymbol GSignalX Signal Service

**Date:** 2026-09-14 · **Status:** implemented (modules + Service + chart coexistence + deploy/confirm)  
**Scope:** chart-free `GsignalX_Service.mq5` + shared `Include/GSignalX` core + chart EA coexistence (Scouter exits).

---

## Goal

Ship **both**:

- **A)** Chart-free `GsignalX_Service.mq5` — scans `InpSymbolList`, computes engines per symbol, places entries, fleet-fills to N pairs (mirrors ProfitScouter Service).
- **B)** Strengthened multi-chart fleet on `GsignalX_GocityGroup.mq5` for UI/manual desks.

**Exit ownership stays Scouter.** Signal hosts never reverse-close.

---

## Architecture

| Role | Host | Symbol model |
|---|---|---|
| Entry / signals | `GsignalX_Service` + chart EA | Service = roster; chart = `_Symbol` |
| Exit / harvest | ProfitScouter Service/EA | Account-wide |
| Shared core | `Include/GSignalX/*` | Symbol/magic parameterized |

**Coexistence:** Service sets `GSX_SVC_OWN_{magic}=1` while running. Same-magic chart EA skips fleet fill and (by default) auto-entries when OWN is set. Chart PLAY/STOP/HALT syncs `GSX_SVC_RUN_{magic}`.

---

## Modules

| Module | Responsibility |
|---|---|
| `SymbolRoster.mqh` | Parse CSV, resolve via canon, `SymbolSelect` |
| `Engines.mqh` | Per-symbol PP/ST/SBT + `GsxActiveDirectionUnderRules` |
| `MarketGates.mqh` | Session / weekend / spread / hour gates by symbol |
| `Fleet.mqh` | Active pairs, CAS claim, OWN/RUN GVs, symbol busy |
| `EntryExec.mqh` | Market/limit/stop bracket; Scouter catastrophe SL; TP=0; no reverse-close |
| `SignalBus.mqh` | Per-symbol signal JSON + heartbeat (`fleet_owner` / `fleet_active`) |
| `Core.mqh` | Service orchestration (include after host inputs) |

---

## Service cycle

1. Load `GSX_SVC_RUN_{magic}` when `InpRespectChartRunState`.
2. If disabled → return.
3. Per roster symbol: on forming-bar change → `GsxCalcEngines`; count recalcs.
4. `GsxCleanupStalePendings` for magic.
5. Fleet: pick first idle roster symbol with joinDir ≠ 0, gates OK; claim → `GsxPlaceEntry`; **one fill per cycle**.
6. Bus every ~2s: write all roster signals + one heartbeat; `fleet_owner="service"`.

---

## Reliability gates

| Metric | Gate |
|---|---|
| Compile | 0 errors / 0 warnings (Service + chart + includes) |
| Coexistence | OWN=1 → charts do not fleet-fill |
| Fleet fill | Short fleet fills idle roster symbol within ~1–2 cycles |
| Engine CPU | Recalc only on per-symbol new forming bar |
| Independence | No reverse-close from signal hosts |
| Bus | `signals/{canon}.json` per roster symbol + heartbeat |
| Deploy | `Deploy-GSignalX.ps1` copies/compiles Service; Confirm checks files + coexistence |

---

## Out of scope

Bus Phase 2 command inbox; grade-driven auto-PLAY.
