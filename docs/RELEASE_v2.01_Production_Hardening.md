# Gsignalx Velocity 2.01 — Production Hardening Release

**Date:** 2026-09-15  
**Product:** Gsignalx Velocity (Gocity Group)  
**Hosts:** remain `#property version "2.00"` (feature surface)  
**Hardening train:** **2.01** (latency, bus safety, headless Prop, UI/docs)  
**Bus schema:** still **`version: 1`**

Companion: [PLAN_V2.01_Production_Hardening.md](PLAN_V2.01_Production_Hardening.md) · base topology [RELEASE_v2.00_Prop_Desk_Deploy.md](RELEASE_v2.00_Prop_Desk_Deploy.md)

---

## 1. Why 2.01

Velocity 2.00 was functionally ready for a prop desk. Sustained **20–30 symbols** plus **several terminals** on Common Files exposed:

- M5 bar-open engine storms (`CopyRates` + StdDev × N)
- FILE_COMMON delete-gap races and register RMW storms
- Dashboard 250ms HistorySelect + ChartRedraw + TG WebRequest
- Prop soft locks only while Trade Center ran

## 2. Operator changes

| Item | Action |
|---|---|
| Service preset | Prefer `deploy/presets/GSignalX_Service_PropDesk_30.set` |
| Cycle | `InpCycleMs=200`, `InpEngineBudgetPerCycle=4`, `InpLookback=400` |
| Bus | Dirty publish + `InpBusFullSyncSec=10` full sync |
| Prop | Service evaluates headless (≥2s); PLAY still clears from Dashboard |
| Dashboard | Default refresh **1000ms**; narrow charts auto-compact |
| STALE rows | Direction flagged when bus `ts` >15s or signal missing |
| Docs | Velocity primary; CREED HTML is UTF-8 legacy archive |
| Multi-terminal | Harden for concurrent writers; practical confirm target **≤8** tids on one Windows profile. Above that raise Grader `InpIntervalMs`. |

## 3. Confirm gates

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\Deploy-GSignalX.ps1 -AllTerminals -Compile

powershell -ExecutionPolicy Bypass -File .\deploy\Confirm-GSignalX.ps1 `
  -Gate All -WriteFeedback
```

New gate: **ProdHardening** (static contracts).  
**Bus** gate now includes rapid-read race probe and multi-tid / ≥20 signals WARN/PASS.

## 4. Manual desk checklist (demo)

- [ ] Service OWN=1 with PropDesk_30 roster; engines warm within budget (no multi-second freeze every M5)
- [ ] Prop trip with Dashboard **detached** → RUN=0; positions remain; PLAY from Dashboard resumes
- [ ] Trade Center on narrow chart: compact width, brighter muted text, STALE when Service stopped
- [ ] Bus race probe PASS under live publish
- [ ] Second terminal indexed (optional) → Grader grades both within TTL
- [ ] Docs phone viewport: chapter select visible ≤900px; logos load

## 5. Invariants (unchanged)

Entry hosts never reverse-close · Scouter owns exits · soft STOP only · one fill per Service cycle · bus schema v1
