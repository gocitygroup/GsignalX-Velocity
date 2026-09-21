# Preset — EUR 100 raw-spread growth account

**Canonical trader guidance:** [Gsignalx_Velocity_Users_Manual.html — Fund Growth](Gsignalx_Velocity_Users_Manual.html#growth) · [System / Profit CASH](Gsignalx_Velocity_Users_Manual.html#profit-cash) · [Risk Framework](Gsignalx_Velocity_Users_Manual.html#risk-framework)

**Presets (Inputs → Load, then restart Services):**

| Program | Preset |
|---------|--------|
| Chart / Service entry | `deploy/presets/GSignalX_100EUR_RawSpread.set` |
| ProfitScouter Service | `deploy/presets/ProfitScouter_100EUR_RawSpread.set` |

## Three constraints (summary)

1. **Min lot is the real risk setting** below ~EUR 200 — percent sizing floors to 0.01.
2. **Losers ride past sizing ATR** — Scouter mode attaches StrategicStop (~4×ATR) as catastrophe SL; adverse Auto cuts losers.
3. **Stock Profit CASH 100 is unreachable at 0.01** on EUR 100 — preset uses ASAP 1.00 / MinWin 0.50.

## Key preset deltas vs stock

| Knob | EUR 100 preset |
|------|----------------|
| Profit CASH / lock | 1.00 |
| MinWin | 0.50 |
| Fleet | 2 |
| MaxLot | 0.10 |
| MaxSpreadPt (FX) | 25 |
| Hour filter | 7–20 ON |
| Adverse TF | M5 |
| StrategicStopMult | **4.0 — do not widen** |

Re-ladder floors with balance (see Growth chapter). Verify spreads, commission, and contract specs from your broker — examples in older notes are illustrative only.
