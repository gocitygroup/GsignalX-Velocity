# Native Take-Profit (`tp_native`)

Self-contained TP module. Host supplies **closed OHLC bars only**. Does not use or modify `Engines.mqh` SuperBollingerTrend.

## Pipeline

1. Ring buffers of highs/lows (length = `period`)
2. Population Bollinger bands on highs and lows
3. Flip signals (`SERIES` / `CARRIED` cross mode)
4. SBT line: **two sequential trail passes** (LONG then SHORT); ZigZag/HIGH_LOW/CLOSE pivots; swing distances
5. TP distance = Median (even → mean of middles) or Average of all distances
6. Level = lastPivot ± distance; hit = first touch vs previous bar extreme

## UI

- **Chart EA:** `TP ON/OFF` + `Median|Average` row; HLINE + label when ON
- **Trade Center:** QuadDraw Automation chips + status strip; same object names / handlers
- Shared GVs: `GSX_MS_TPENABLE_{magic}`, `GSX_MS_TPTYPE_{magic}`
- Default **OFF** — no level, no hit pending, no closes

**Operator manual (i18n):** [Integrations · Native TP](Gsignalx_Velocity_Users_Manual.html#integrations) · [System UI Best Use](Gsignalx_Velocity_Users_Manual.html#desk213) · [RELEASE_v2.20_Native_TP.md](RELEASE_v2.20_Native_TP.md)

## Live update / perf

- Toggle is O(1): GV + tip recompute + enqueue open symbols (`TpnOnTpUiChanged`). Never bootstrap/flush on click.
- Desk `OnTimer` drains ≤2 symbols and ≤1 bootstrap per tick; TP OFF skips ProcessOther/Flush.
- UI bootstrap clamped to `min(historyBars, 300)` (`TpnUiBootstrapBars`).

## Broker TP on open positions

When TP is **ON** and a valid tip level exists, matching open positions (same `magic`, same side as tip direction) get `PositionModify` with that TP (existing SL kept). Re-applied on activate, type change, bootstrap, and new closed bars — skipped if already within 2 points or level fails stops/freeze checks. TP OFF does not clear broker TP.

## Close on hit

Chart/Desk write `FILE_COMMON/GSignalX/tp_native/pending/*.hit`.  
ProfitScouter `Monitor()` → `CloseTicket(..., "NATIVE-TP")` only when `closeOnHit=true` and trade is a winner (existing loser guard).

## Settings (inputs + GV)

| Key | Default |
|-----|---------|
| enabled | false |
| type | MEDIAN |
| closeOnHit | false |
| period / mult | 12 / 2.0 |
| pivotSource | ZIGZAG |
| historyBars | 500 |

Structural changes (`period`, `mult`, `pivotSource`) rebuild from stored rates.

## Tests

```bash
python tests/tp_native/tp_native_ref.py
```

MT5: compile `GSX_TpNative_Test.mq5` and run as Script.

## Snapshot

`GSignalX/tp_native/{symbol}_{tf}.json` — schemaVersion 1; diffs rebuilt into sorted structure on load.
