# Production Hardening v2.20 (Hang Residual + DRY)

**Status:** DONE — Steps 0–6; compile 0/0 all hosts; Confirm All PASS  
**Product:** Gsignalx Velocity v2.20  
**Prior art:** `docs/plans/HANG_FREEZE_PERF_PLAN.md` (v2.19 DONE)  
**Confirm:** `deploy/feedback/CONFIRM_2026-10-15_011432_All.md`  
**Cycle:** Plan → Implement → Compile 0/0 → Confirm → Next

## Locked decisions

- Topology A: Service + Trade Center (`InpDeskExecute`) own Core/fills; Chart is consumer/UI; Scouter owns exits.
- Non-goals: no change to joinDir, bias math, lot sizing, SL, or entry-gate semantics.
- No new DLLs / OS threads.
- **OCO default On:** `InpEnableOcoStraddle=true` on Service, Dashboard, Chart. UI takeoff still disables.
- **Seed rule:** `GsxRosterOcoEnableSeed` seeds once; after seed, desk GV/UI wins.

## Steps

| Step | Focus | Status |
|------|--------|--------|
| 0 | Living plan doc | DONE |
| 0b | OCO default On | DONE |
| 1 | OCO one-book ticket map | DONE |
| 2 | Fleet DRY book reuse | DONE |
| 3 | Chart yield when Core host owns | DONE |
| 4 | Snapshot / UI polish | DONE |
| 5 | Bus writer NoSleep on Desk path | DONE |
| 6 | Confirm All + soak checklist | DONE |

## Key changes

- `InpEnableOcoStraddle=true` — Service / Dashboard / Chart
- `GsxOcoBookBegin/Build/End` + Find* lookup — `OcoStraddle.mqh`; Core + Chart manage
- `GsxFleet*(…, GsxAccountBook&)` overloads — `Fleet.mqh`; Core fill path reuses `g_coreAccountBook`
- Chart `ChartManageOco` / `ChartArmOcoFromSignal` yield when `ChartServiceOwnsFleet()`
- `GsxMsRefreshRowMarket` + off-page skip; `GsxMsObjCacheRebuild` for drag
- `GsxBusWriterNoSleepBegin/End` on Desk Core cycle

## Operator soak (optional live)

1. Reattach Trade Center + Service (Topology A); drag panel — stay smooth
2. OCO default On: arm → fill one side → sibling cancel → trail; takeoff cancels straddles
3. Large roster: verbose Core `cycle_ms` vs Scale SLA
4. Chart attached with Service OWN: Chart must not place dual OCO

## Non-goals (honored)

- No change to joinDir, bias math, lot sizing, SL, or entry gate semantics
- No new DLLs / OS threads
- No live broker automation in Confirm (static + compile)
