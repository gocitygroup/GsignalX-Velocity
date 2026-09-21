# Practice Live Packs — $20 / $50 / $100

**Canonical trader guidance:** [Gsignalx_Velocity_Users_Manual.html — Fund Growth](Gsignalx_Velocity_Users_Manual.html#growth) · [Risk Framework](Gsignalx_Velocity_Users_Manual.html#risk-framework) · [Risk Checklists](Gsignalx_Velocity_Users_Manual.html#risk-checks)

**Code truth:** `Include/GSignalX/PracticeSim.mqh` · Trade Center coach buttons · matching `.set` presets  
**Adaptive tips:** `Include/GSignalX/RiskGuidance.mqh` (enriches practice tip lines)  
**Chart companion (Week 1):** [GsignalX on TradingView](https://www.tradingview.com/script/wxa7lWXl-GsignalX-is-a-trend-following/) — watch the same engines while you paper the MT5 loop (does not place orders).

> **Disclaimer:** Risk geometry and discipline rules — not a performance forecast. Demo first. Min-lot dominates percent-risk math below ~$200.

---

## Run a pack

1. Fund a **real demo** near $20 / $50 / $100.
2. Load both presets (Inputs → Load), then **restart** Services:
   - `deploy/presets/GSignalX_Service_Practice_{BAND}_{Raw|Standard}.set`
   - `deploy/presets/ProfitScouter_Practice_{BAND}_{Raw|Standard}.set`
3. Attach Trade Center with the **same magic**.
4. Press **20 / 50 / 100 · RAW / STD · SCALP / DAY / SWING** for coach tips (soft-apply = fleet + category only).
5. PLAY in the suggested session; STOP when day loss or profit bank hits.

## Band geometry (Day defaults)

| Band | Day loss | Day profit | Fleet | Max lot | Day max trades |
|------|----------|------------|-------|---------|----------------|
| 20 | 1.00 | 0.40 | 1 | 0.01 | 2 |
| 50 | 2.00 | 1.00 | 2 | 0.02 | 3 |
| 100 | 3.50 | 1.50 | 2 | 0.10 | 4 |

Raw ASAP / lock / minWin: 0.20/0.20/0.10 · 0.50/0.50/0.25 · 1.00/1.00/0.50 (Standard higher).  
Do not widen StrategicStopMult above 4.0×ATR.

Full expectancy / Kelly notes and Standard vs Raw spreads: see Growth + Risk chapters in the HTML manual.
