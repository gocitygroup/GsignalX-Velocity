# TP Native — Step 0 Baseline (2026-10-21)

## Stack (assumptions)

- Host: MT5 MQL5 GsignalX Velocity 2.20 (Chart + Multisymbol Desk + ProfitScouter).
- No in-repo REST/SPA; settings = `input` + panel chips + GlobalVariables; persistence = FILE_COMMON JSON.
- Existing Engines SBT is **independent** and must remain untouched.
- Closes: Scouter `CloseTicket` only; Chart/Desk emit pending hits.

## Confirm baseline

```
.\deploy\Confirm-GSignalX.ps1 -Gate Files
→ SUMMARY: PASS (0 hard failures)  2026-10-21 20:46:53
```

## TP-OFF regression checklist

When `tp.enabled == false` (default):

1. No `OBJ_HLINE` / TP label objects created or left visible.
2. No FILE_COMMON pending under `GSignalX/tp_native/pending/`.
3. No `NATIVE-TP` closes from Scouter.
4. Existing PP/ST/SBT engines, OCO chip, FollowDir, Bias, Scouter harvest unchanged.
5. Confirm Files / LoserSafety / Functional still PASS after integration.
