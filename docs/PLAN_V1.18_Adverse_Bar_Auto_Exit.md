# Plan v1.18 — Auto Mode Adverse-Bar Loss Exit + Profit Targeting

Date: 2026-09-10  
Scope: `Include/GSignalX/BarDirection.mqh` (new), `Include/ProfitScouter/Core.mqh` (v1.15 → v1.16),
`ProfitScouter_Service.mq5`, `ProfitScouter_DollarTarget.mq5`, `README_ProfitScouter.md`.

---

## 1. Decisions locked

- **Symmetric**: BUY signal + selling closed bars (>2) **and** SELL signal + buying closed bars (>2).
- **Scope**: close **only losers on that same symbol**; winners keep ASAP/layered targeting.
- **Policy**: conditional exception to v1.15 “never close losers”. Default `CloseTicket` still refuses
  loss closes unless the adverse Auto path passes `allowLoss=true`.

---

## 2. Behaviour

When scout is START-armed and trading is ready, each Monitor cycle:

1. For each symbol with open losers, read last GSignalX bus `direction` and count consecutive
   **closed** OHLC bars (shift ≥ 1): selling = `close < open`, buying = `close > open` (doji breaks streak).
2. If `direction == +1` and sell streak > `InpAdverseMinBars` (default 2 → fire at ≥ 3), close all
   losers on **that symbol only**.
3. If `direction == -1` and buy streak > `InpAdverseMinBars`, same for that symbol.
4. If bus direction is missing/0 and `InpAdverseRequireSignal=true`, skip (never guess).
5. One fire per symbol per bar (GV `PS{id}_ADV_{canon}`).
6. Then existing profit path runs unchanged: account → pair → position winners-only targets.

---

## 3. Implementation steps

### Step 1 — Plan doc
- This file.

### Step 2 — Shared bar helper
- `Include/GSignalX/BarDirection.mqh` → `GsxCountConsecutiveClosedBars(symbol, tf, candleDir)`.

### Step 3 — Core adverse Auto engine
- Per-symbol cache (dir + streaks, refresh streaks on new bar only).
- `CloseTicket(ticket, tag, allowLoss=false)` — adverse path only sets `allowLoss=true`.
- `CloseLosersOnSymbol` / `HandleAdverseBarLossCut` before profit layers in `Monitor()`.
- Bus: `adverse_enable`, `adverse_last_sym`, `adverse_last_streak`, `adverse_closed_cycle`.
- Extend `LivePos` with `posType` for logging.

### Step 4 — Host shells
- Inputs: `InpAdverseExitEnable`, `InpAdverseMinBars`, `InpAdverseTimeframe`, `InpAdverseRequireSignal`.
- Version bump 1.15 → 1.16; description update.

### Step 5 — README
- Document Auto Mode adverse rules; hard guard remains default.

### Step 6 — Build
```
deploy\Deploy-GSignalX.ps1 -TerminalDataPath <hash> -Compile
```

### Step 7 — Test
```
deploy\Confirm-GSignalX.ps1 -Gate All -WriteFeedback
```
Static checks:
- `allowLoss` / `ADVERSE-BAR` only on adverse path.
- Profit harvest still winners-only.
- No `CutLosersToGuard` restored.

Live recipes (after restart Service + refresh charts):
1. BUY signal + ≥3 selling closed bars + red tickets on symbol → reds closed; greens left for targets.
2. Mirror SELL + buying bars.
3. Missing bus direction → no loss close.
4. Winner still hits ASAP floor independently.

---

## 4. Results

### Build — PASS (2026-09-10)
`Deploy-GSignalX.ps1 -TerminalDataPath 010E047102812FC0C18890992854220E -Compile`
compiled all five sources with **0 errors, 0 warnings**:

| Source | Result |
|---|---|
| Experts\GsignalX_GocityGroup.mq5 | 0 errors, 0 warnings |
| Experts\ProfitScouter_DollarTarget.mq5 (v1.16) | 0 errors, 0 warnings |
| Services\ProfitScouter_Service.mq5 (v1.16) | 0 errors, 0 warnings |
| Services\ProfitOpportunity_Grader.mq5 | 0 errors, 0 warnings |
| Scripts\ProfitHarvest_Now.mq5 | 0 errors, 0 warnings |

### Confirm gate — PASS
`Confirm-GSignalX.ps1 -Gate All -WriteFeedback` → **PASS, 0 hard failures**
(feedback: `deploy\feedback\CONFIRM_2026-09-10_150923_All.md`).
WARNs: heartbeat/grades age ~3 h (known clock-skew / publishers not freshly restarted); no live scouter snapshot until Service restart with `InpBusEnable`.

### Static verification — PASS
- `HandleAdverseBarLossCut` + `ADVERSE-BAR` + `allowLoss` present in Core.
- `GsxCountConsecutiveClosedBars` in `BarDirection.mqh`.
- Host inputs `InpAdverse*` on DollarTarget + Service.
- No `CutLosersToGuard` restored.
- Profit harvest still winners-only (`SelectBucket` skips losers).

### Next (runtime)
1. Restart **ProfitScouter_Service** and refresh chart EA / GSignalX so v1.17 loads.
2. Chart buttons: **START** / **STOP** / **AUTO** (AUTO toggles adverse via `PS{id}_ADVEN`).
3. Verify recipes in §3 Step 7 on a live chart with bus signals publishing.

### AUTO chart toggle (follow-up)
- Runtime `gAdverseEnabled` + GV `PS{id}_ADVEN`; `InpAdverseExitEnable` seeds first attach only.
- EA button **AUTO ON/OFF** beside START/STOP; Service reloads GV each loop when `InpRespectChartRunState`.
- Hosts bumped to **v1.17**.
