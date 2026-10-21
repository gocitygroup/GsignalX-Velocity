# TP Native — Live Update + Non-Blocking Perf

## Goals

1. When TP is switched **ON**, refresh the chart symbol and open pairs for `magic` without blocking clicks/timer.
2. Dual chart UI: **Chart EA** panel and **Trade Center QuadDraw Automation** both expose `TP ON/OFF` + Median/Average (shared GVs).
3. Avoid hang: no bootstrap/flush on click; budget Desk timer work; skip I/O when TP OFF.

## Architecture

- Click → O(1) ApplyUiSettings + draw + enqueue open symbols.
- OnTimer → drain queue (≤2 updates, ≤1 bootstrap per tick); new closed bar only unless kick.
- TP OFF → clear draw; no ProcessOther / Flush / bootstrap.

## Dual UI

| Surface | Location | Objects |
|---------|----------|---------|
| Chart EA | GocityGroup button row | `BTN_TP`, `BTN_TPTYPE` |
| Trade Center | QuadDraw Automation | `BTN_TP`, `BTN_TPTYPE` (same names → MultisymbolPanel handlers) |
| Status strip | MultisymbolPanel | existing chips |

GVs: `GSX_MS_TPENABLE_{magic}`, `GSX_MS_TPTYPE_{magic}`.

## Checklist

- [x] Dual UI: Chart EA row + QuadDraw Automation `BTN_TP` / `BTN_TPTYPE`
- [x] Open-book + refresh queue API (`TpNativeOpenBook.mqh`)
- [x] Desk tick: OFF early-out, kick drain, budgeted bootstrap/flush
- [x] All toggle paths → `TpnOnTpUiChanged` / `TpnOnTpTypeChanged` (no click bootstrap)
- [ ] Manual: TP OFF → no HLINE; TP ON with open position → level; PLAY/STOP responsive
- [x] Python golden vectors PASS (`total_failures=0`)
- [x] Chart + Desk compile 0 errors / 0 warnings

## Bootstrap

UI bootstrap clamped to `min(historyBars, 300)`. At most one bootstrap per Desk tick.
