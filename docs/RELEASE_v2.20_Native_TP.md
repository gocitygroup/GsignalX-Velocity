# RELEASE v2.20 — Native TP (docs + runtime addendum)

**Banner:** Native Take-Profit operator cut (Gocity Group)  
**Date:** 2026-10-21  
**Hosts:** Trade Center / Chart remain **`#property version "2.20"`**  
**Canonical manual:** [Integrations · Native TP](Gsignalx_Velocity_Users_Manual.html#integrations) · [Best Use](Gsignalx_Velocity_Users_Manual.html#desk213) · Engineer: [TP_NATIVE.md](TP_NATIVE.md)

---

## What operators get

| Capability | Desk meaning |
|------------|----------------|
| **TP ON/OFF** | Shared GV; Chart EA + Trade Center Automation chips |
| **Median / Average** | Tip distance type (visible when ON) |
| **Broker TP** | When ON, matching open positions get `PositionModify` TP (SL kept) |
| **closeOnHit** | Optional Scouter close tag `NATIVE-TP` (winners only) |
| **Default** | **OFF** — no HLINE, no broker push, no pending hits |

Performance: O(1) toggle; Desk timer drains ≤2 open symbols and ≤1 bootstrap per tick.

---

## Verify

1. Manual EN + `?lang=it|fr|ru|ar|zh|es` — Integrations / desk213 / welcome TP copy
2. `python docs/_audit_i18n.py`
3. `python tests/tp_native/tp_native_ref.py`
4. Chart/Desk compile 0 errors / 0 warnings

Live: TP OFF → no HLINE; TP ON with open position matching tip side → broker TP set; PLAY/STOP/OCO stay responsive.
