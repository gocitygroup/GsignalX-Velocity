# Optional OCO Straddle Plan (MQL5)

**Status:** DONE — Steps 0–4 (compile 0/0 Service+Desk+Chart; Confirm Functional PASS)  
**Product:** Gsignalx Velocity — additive two-sided BuyStop+SellStop  
**Cycle:** Plan → Implement → Compile → Confirm → Next  
**Confirm:** `deploy/feedback/CONFIRM_2026-10-14_224428_Functional.md` (V2.19 OCO gate)

## Locked decisions

- Platform: MQL5 `GsignalXVelocity` only (no CTrader).
- Feature: optional two-sided breakout straddle (BuyStop above Ask + SellStop below Bid).
- Distinct from `GSX_ENTRY_BOTH` (same-direction limit+stop bracket).
- Default **off** (`InpEnableOcoStraddle=false`).
- Parallel with MARKET/LIMIT/STOP/BOTH until operator disables OCO (“taking off”).
- Arms from FollowDir-allowed signals (AUTO or Bias). Bias WAIT → no arm.
- Never market-closes; Scouter owns exits. OCO cancels sibling pending + trails own SL.
- Soft desk STOP cancels straddle pendings (same magic).

## Naming

| Existing | New |
|----------|-----|
| `GSX_ENTRY_BOTH` same-dir bracket | `InpEnableOcoStraddle` opposite-side stops |
| Comments `… LMT` / `… STP` | `GSX_OCO_BUY` / `GSX_OCO_SELL` |

## State machine

Idle → WaitingForActivation → OrdersPlaced → ManagingPosition → Finished → Idle (next distinct signal)

## Files

| Role | Path |
|------|------|
| Module | `Include/GSignalX/OcoStraddle.mqh` |
| Skip-OCO deletes | `Include/GSignalX/EntryExec.mqh` |
| Arm + manage | `Include/GSignalX/Core.mqh` |
| Hosts | `GsignalX_Service.mq5`, `GsignalX_Multisymbol_Dashboard.mq5`, `GsignalX_GocityGroup.mq5` |
| Confirm | `deploy/Confirm-GSignalX.ps1` |

## Confirm checklist

- [x] `OcoStraddle.mqh` present
- [x] `InpEnableOcoStraddle` on Service + Dashboard + Chart
- [x] `GSX_OCO_BUY` / `GSX_OCO_SELL` comments
- [x] Entry mode enums unchanged (0–3)
- [x] `GsxPlaceEntry` still called when OCO enabled (parallel)
- [x] Compile 0/0 Service + Multisymbol Dashboard + GocityGroup
- [x] `BTN_OCO` on chart + Multisymbol chrome; RosterStore OcoEnable/DeskState GV (Confirm 2026-10-14_230916)

## Residual risks

- Broker filling/comment on pending→position may differ by broker; reconcile prefers comment + magic.
- Activation uses server `TimeCurrent` wall-clock (not UTC); document for operators.
- Chart + Service same magic: only one host should enable OCO per symbol to avoid dual place (OWN yield still applies to fills).

## UI toggle (v2.19+)

- Desk-wide chip `BTN_OCO` on chart signal panel + Multisymbol Trade Center chrome.
- Persist: `GSX_MS_OCOENABLE_{magic}` (seed once from `InpEnableOcoStraddle`; UI wins after seed).
- Desk lifecycle for Multi paint: `GSX_MS_OCOSTATE_{magic}` written by Core (max state across roster) — no order scans in panel.
- Labels: `OCO` (off) · `OCO·ARM` · `OCO·OUT` · `OCO·IN`. Click toggles enable; OFF = takeoff.

## Non-goals

- No change to joinDir, bias math, lot sizing for step entries, Scouter closes, or BOTH bracket semantics.
- No per-row OCO buttons in the roster list.
