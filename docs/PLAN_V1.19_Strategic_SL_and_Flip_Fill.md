# Plan v1.19 — Strategic Catastrophe SL + FOLLOW/WAIT Flip Fill

Date: 2026-09-10  
Scope: `GsignalX_GocityGroup.mq5` (v1.18 → v1.19), `README.md`, this doc.

---

## 1. Decisions locked

- **1C**: Wider broker **catastrophe SL** on Scouter entries (`InpStrategicStopMult`, default 4.0×ATR); TP=0; profit exits stay with ProfitScouter; signal never reverse-closes.
- **2A default (FOLLOW)**: Leave open positions for Scouter; flat charts / fleet keep filling the latest signal direction.
- **2B (WAIT)** via 4th chart button: block new-direction entries while any same-magic position exists in the opposite direction.

---

## 2. Implementation

### Strategic SL
- Inputs: `InpStrategicStopEnable`, `InpStrategicStopMult`.
- `StrategicStopDistance()`; attached in `OpenTrade` / `PlacePending` when `ScouterOwnsExits()`.
- Sizing still uses `InpStopMult`.

### FOLLOW / WAIT
- `gFlipWaitMode` + GV `GSX_FLIPWAIT_{symbol}_{magic}`.
- `MagicHasOppositeDir` / `AllowNewDirEntry`.
- Gated in `EvaluateSignals` (flat entry) and `FleetFillCheck`.
- Opposite open + Scouter: never close; FOLLOW clears fleet cooldown GV for faster refill.

### UI
- Buttons: PLAY | STOP | HALT | FOLLOW/WAIT.
- Panel row "Flip fill"; panel width 320.

---

## 3. Build / test

```
deploy\Deploy-GSignalX.ps1 -TerminalDataPath <hash> -Compile
deploy\Confirm-GSignalX.ps1 -Gate Compile -WriteFeedback
```

### Results

### Build — PASS (2026-09-10)
`Deploy-GSignalX.ps1 -Compile` → all five sources **0 errors, 0 warnings**.
`GsignalX_GocityGroup.mq5` v1.19 compiled clean.

### Static verification
- Scouter `CloseCurrent` still blocked for reverse.
- Strategic SL attached only when `InpStrategicStopEnable` and Scouter mode.
- WAIT gates `EvaluateSignals` + `FleetFillCheck` via `AllowNewDirEntry`.
- Chart buttons: PLAY, STOP, HALT, FOLLOW/WAIT.
