# Deployment feedback — V2.15 Memory Scale

| Field | Value |
|---|---|
| Operator | Auto (agent) |
| Date | 2026-09-21 |
| Demo only? | n/a (static + Functional confirm) |
| Terminals in scope | Repo Confirm Functional |
| Magic (shared) | (operator) |
| Scouter Instance ID | (operator) |

## Gate log

### G0 Scope
- RESULT: PASS
- NOTES: V2.15 Memory Scale = AccountBook, EngCompactTip, BusReadSized + tid coalesce, ATR handle reuse/prune, Scale Small/Medium/Large presets + InpScaleProfile

### G1 Files
- RESULT: PASS (presets Scale_Small / Scale_Medium / PropDesk_30 Large)

### G2 Compile
- RESULT: PASS
- NOTES: Deploy-GSignalX.ps1 -AllTerminals -Compile → 0 errors / 0 warnings all hosts (Service, Dashboard, Chart, Scouter, Grader, Harvest) on both terminals

### G2b Functional (desk contracts)
- RESULT: PASS
- NOTES: Confirm `-Gate Functional` → SUMMARY PASS; all V2.15 Memory Scale markers PASS. Artifact: `CONFIRM_2026-09-21_201917_Functional.md`

### G3 Runtime
- RESULT: PENDING (operator live Topology A)
- NOTES: Reattach Trade Center v2.15; FIXED 0.01; ADD/REM across FX/CMD/CR; tip engines should keep engKB small in verbose cycle log

### G4–G7
- RESULT: PENDING / operator

## Measurable soak checklist (Topology A)

| Metric | Small | Medium | Large | Notes |
|---|---|---|---|---|
| Core cycle p95 | &lt;40 ms | &lt;60 ms | &lt;80 ms | verbose log when cycle≥80 ms includes book/busW/tip/engKB/scale |
| Bus writes | mirror always; tid on full-sync/first | same | same | expect ~50% fewer FileMove vs dual-write |
| ADD/REM | no multi-MB series copy | same | same | tip retention |
| ATR | handles reused; prune on REM | same | same | |

## Presets

- `deploy/presets/GSignalX_Service_Scale_Small.set` — InpScaleProfile=1
- `deploy/presets/GSignalX_Service_Scale_Medium.set` — InpScaleProfile=2
- `deploy/presets/GSignalX_Service_PropDesk_30.set` — InpScaleProfile=3 (Large)

## Operator next

1. `deploy\Clean-and-Deploy.bat` → 0/0 compile  
2. Topology A: DeskExecute ON; load Medium or Large preset  
3. ADD then REM across categories; confirm DIR LIVE + busy/PL rows  
4. Paste Confirm All + soak notes here
