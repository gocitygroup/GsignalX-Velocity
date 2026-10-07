# RELEASE v2.18 — Daily Bias Follow

**Banner:** Current production cut for Gsignalx Velocity (Gocity Group)  
**Date:** 2026-10-07  
**Hosts:** Trade Center / Service **`#property version "2.18"`**  
**Bus schema:** still **`version: 1`** (`GSignalX/bus/v1`)  
**Canonical manual:** [Gsignalx_Velocity_Users_Manual.html#bias-follow](Gsignalx_Velocity_Users_Manual.html#bias-follow) · Best use: [#desk213](Gsignalx_Velocity_Users_Manual.html#desk213) · Deploy: [WINDOWS_DEPLOY_SIMPLE.md](WINDOWS_DEPLOY_SIMPLE.md)

> Historical cut: [RELEASE_v2.14_Input_Reliability.md](RELEASE_v2.14_Input_Reliability.md) (input reliability / Best Use baseline).

---

## What shipped

- **Daily Bias Follow** — chart-aligned D1 lanes (Daily / Pre-D / Third-D) arm FollowDir; **Signal** clears to AUTO.
- **Live one-side gate** — while a lane is armed: BULL→BUY · BEAR→SELL · **NEUT→WAIT** (block new entries). Not sticky; tracks live direction.
- **No EMA** — open→close / mid-vs-open only. Bias never closes tickets; Scouter still banks winners.
- **Desk + chart chips** — Trade Center chrome and chart Signal panel; Mode / FDIR pads clear the armed lane.
- **Public manual + i18n** — `#bias-follow` chapter; six locale catalogs (`bias-follow.json`); `CACHE_VER` **2.18**.

---

## Operator defaults

| Item | Default / posture |
|------|-------------------|
| Bias lane | **Signal** (cleared) until you arm Daily / Pre-D / Third-D |
| Topology | **A** — DeskExecute ON, Service stopped or Yield ON |
| Lot | FIXED **0.01** |
| Exits | ProfitScouter owns BANK / CUT / FLAT |
| EQ | OFF unless you want a floating-DD entry brake |

Invariant: GSignalX opens · ProfitScouter closes · STOP ≠ FLAT.

---

## Verify

1. `Deploy-GSignalX.ps1 -Compile` (or Clean-and-Deploy)
2. `Confirm-GSignalX.ps1 -Gate All -WriteFeedback` — expect **2.18** hosts + Bias one-side green
3. Optional: `GSX_Bias_Test.mq5` / Confirm Bias gate for NEUT→WAIT and Signal clear

Manual spot-check: open [Users Manual](Gsignalx_Velocity_Users_Manual.html)?`lang=en|es|ar|zh` — Bias chapter loads; Arabic RTL OK.

---

## License note (PolyForm-NC)

City Velocity remains **[PolyForm Noncommercial 1.0.0](../LICENSE)** — clone, study, and practice-desk use under NC. Soft STOP / funded-challenge workflows are educational and prop-practice oriented; commercial redistribution or paid desk operation of this toolkit is not permitted under NC. **Velocity Premium** remains the managed/paid upsell.
