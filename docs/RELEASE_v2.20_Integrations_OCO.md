# RELEASE v2.20 — Integrations & OCO desk cut

**Banner:** Current production cut for Gsignalx Velocity (Gocity Group)  
**Date:** 2026-10-15  
**Hosts:** Trade Center / Service / Chart **`#property version "2.20"`**  
**Bus schema:** still **`version: 1`** (`GSignalX/bus/v1`)  
**Canonical manual:** [Integrations](Gsignalx_Velocity_Users_Manual.html#integrations) · Best use: [#desk213](Gsignalx_Velocity_Users_Manual.html#desk213) · Cloud: [#cloud](Gsignalx_Velocity_Users_Manual.html#cloud) · Deploy: [WINDOWS_DEPLOY_SIMPLE.md](WINDOWS_DEPLOY_SIMPLE.md)

> Historical: [RELEASE_v2.18_Daily_Bias_Follow.md](RELEASE_v2.18_Daily_Bias_Follow.md) · [RELEASE_v2.14_Input_Reliability.md](RELEASE_v2.14_Input_Reliability.md)

---

## What shipped (fund-manager view)

Separation of duties stays absolute: **GSignalX opens risk · ProfitScouter banks winners · soft STOP never flattens the book.**

| Capability | Desk meaning |
|------------|----------------|
| **Cloud connector** | Service group 16 → `trade-api.gsignalx.cloud`; remote opens default ON; **remote closes default OFF** (Scouter keeps exits) |
| **Telegram** | Soft VERIFY; deals / PROP / CLOSE / SETTINGS; silent hours |
| **Signal bus + Grader** | Multi-terminal DIR + advisory grades on Common Files `bus/v1` |
| **ScoutLink** | Trade Center arms Scouter floors (LINK / RUN / CASH / LOSS / TRAIL) without closing from the desk UI |
| **CloseTrigger** | Exit audit (jsonl) + TG CLOSE reason (incl. BROKER-SL) |
| **SettingsNotify** | Prop-critical setting changes → TG (no PAGE spam) |
| **PropRisk** | Challenge soft STOP → `RUN=0`; never `PositionClose` |
| **OCO straddle** | Default **On** — BuyStop+SellStop parallel to EntryMode; sibling cancel on fill; trail; takeoff via `BTN_OCO`; Chart yields when Service/Desk owns magic |

Performance hardening (hang residual): OCO one-book manage, Fleet AccountBook DRY, Desk bus NoSleep, panel object cache — see operator soak in `docs/plans/PROD_HARDENING_V220_PLAN.md`.

---

## Operator defaults

| Item | Default / posture |
|------|-------------------|
| Topology | **A** — DeskExecute ON, Service stopped or Yield ON |
| Lot | FIXED **0.01** |
| OCO | **On** (seed-once; UI takeoff still disables) |
| Exits | ProfitScouter owns BANK / CUT / FLAT |
| Cloud closes | **Off** |
| EQ | OFF unless you want a floating-DD entry brake |
| Bias lane | Signal (cleared) until you arm Daily / Pre-D / Third-D |

Invariant: GSignalX opens · ProfitScouter closes · STOP ≠ FLAT · one Core host places OCO.

---

## Verify

1. `Deploy-GSignalX.ps1 -Compile` (or Clean-and-Deploy)
2. `Confirm-GSignalX.ps1 -Gate All -WriteFeedback` — expect **2.20** hosts + V2.20 Functional markers (OCO default On, Integrations chapter)
3. Manual spot-check: [Users Manual · Integrations](Gsignalx_Velocity_Users_Manual.html#integrations)

Optional live soak: Trade Center drag · OCO arm→fill→sibling cancel · takeoff · Chart with Service OWN (no dual OCO).

---

## License note (PolyForm-NC)

City Velocity remains **[PolyForm Noncommercial 1.0.0](../LICENSE)** — clone, study, and practice-desk use under NC. Soft STOP / funded-challenge workflows are educational and prop-practice oriented; commercial redistribution or paid desk operation of this toolkit is not permitted under NC. **Velocity Premium** remains the managed/paid upsell. Educational — no profit guarantee.
