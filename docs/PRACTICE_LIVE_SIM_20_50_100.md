# Practice Live Account Simulation — $20 / $50 / $100 (Standard + Raw)

**Date:** 2026-09-15 · **Product:** Gsignalx Velocity  
**Audience:** scalpers, day traders, swing traders on micro live/demo balances  
**Code truth:** `Include/GSignalX/PracticeSim.mqh` · Trade Center coach buttons · matching `.set` presets  

## Best use (one screen)

| Desk | Load | Trade Center | Session |
|---|---|---|---|
| Prop / small fund | PropDesk or Multisymbol `.set` | Fleet 4 · FX+CMD START · CR SUSPEND · Event SKIP | London–NY M5 |
| Practice $20 | `Practice_20_{Raw\|Standard}.set` (Service+Scouter) | **20 · RAW/STD · SCALP/DAY/SWING** · fleet 1 · FX only | Scalp: LDN·NY · Day: 07–20 · Swing: 12–17 grades |
| Practice $50 | `Practice_50_*` | **50** · fleet 1–2 · FX only | Same style tips |
| Practice $100 Raw | `Practice_100_Raw` or EUR100 RawSpread | **100 · RAW · DAY/SCALP** · fleet 2 | Aligns with ASAP 1.00 / MinWin 0.50 |

Always: shared magic · restart Services after Inputs→Load · coach buttons soft-apply fleet/cat only · demo first.

> **Disclaimer:** These packs are **risk geometry and discipline rules**, not a performance forecast. Demo first. Min-lot (usually 0.01) dominates percent-risk math below ~$200.

---

## 1. How to run a pack

1. Open a **real demo** funded near the band ($20 / $50 / $100 — € interchangeable for the tables).
2. Load **both** presets (Inputs → Load), then **restart** each Service:
   - `deploy/presets/GSignalX_Service_Practice_{BAND}_{Raw|Standard}.set`
   - `deploy/presets/ProfitScouter_Practice_{BAND}_{Raw|Standard}.set`
3. Attach Trade Center (`GsignalX_Multisymbol_Dashboard`) with the **same magic**.
4. Press panel **20 / 50 / 100**, **RAW / STD**, **SCALP / DAY / SWING** for coach tips. Soft-apply updates **fleet target** + **category filter** only — money floors stay in the `.set` files.
5. PLAY during the suggested session; STOP when the day loss or profit bank hits.

Day style is baked into the `.set` files. Scalp/Swing change trade-count / session tips on the coach strip.

---

## 2. Desk maths (probability, not promises)

Let \(p\) = win rate, \(R\) = avg win ÷ avg loss.

| Metric | Formula | Desk rule |
|---|---|---|
| Expectancy | \(E = pR - (1-p)\) | Require \(E \ge 0.15R\) before raising fleet |
| Kelly (full) | \(f^* = p - (1-p)/R\) | Cap at **¼ Kelly** and at band risk % |
| Loss budget | \(\lfloor\) dailyLoss ÷ perTradeRisk \(\rfloor\) | Stop after budget — shown on coach tip |

At $20–$50, broker **min lot** floors true 1% sizing. Edge control is **session + trade count + ASAP floors**, not lot calculus.

---

## 3. Band geometry (Day defaults)

| Band | Day loss halt | Day profit bank | Fleet | Max lot | Day max trades |
|---|---|---|---|---|---|
| 20 | 1.00 (5%) | 0.40 (2%) | 1 | 0.01 | 2 |
| 50 | 2.00 (4%) | 1.00 (2%) | 2 | 0.02 | 3 |
| 100 | 3.50 (~3.5%) | 1.50 (1.5%) | 2 | 0.10 | 4 |

Style trade caps (coach): Scalp 4/6/8 · Day 2/3/4 · Swing 1/1/2 for bands 20/50/100.

Prop: `InpPropMaxEquityDdPct=5`, Friday block hour 20, strategic stop 4×ATR (disaster cap — do not widen).

---

## 4. Standard vs Raw

| Knob | Raw | Standard |
|---|---|---|
| `InpMaxSpreadPt` (FX) | 25 | 40–50 |
| Scouter `InpIncludeCommission` | true | false |
| ASAP / lock / min-win | lower (net of commission) | higher (must clear spread) |
| Scalp | preferred | discouraged below $100 |

### ASAP floors (Scouter)

| Band | Raw ASAP / lock / minWin | Standard ASAP / lock / minWin |
|---|---|---|
| 20 | 0.20 / 0.20 / 0.10 | 0.40 / 0.40 / 0.20 |
| 50 | 0.50 / 0.50 / 0.25 | 0.80 / 0.80 / 0.40 |
| 100 | 1.00 / 1.00 / 0.50 | 1.50 / 1.50 / 0.75 |

---

## 5. Style · pairs · sessions (secondary suggestions)

| Style | TF | Session tip | Primary pairs |
|---|---|---|---|
| Scalp | M5 | LDN·NY overlap | 1 liquid FX (EURUSD) |
| Day | M5 | 07–20 · avoid Asia FX | 20: EURUSD · 50/100: EURUSD,GBPUSD |
| Swing | M15 | grade band 12–17 | fewer fills; same FX set |

**Asset rules**

- **$20:** FX only. CMD/CRYPTO = SUSPEND.
- **$50:** FX 1–2 majors. CMD/CRYPTO off by default.
- **$100:** FX 2 majors live; XAU optional add; BTC/ETH **watch only** until ~$250.

Session clock on Trade Center is **illustrative GMT**. Hard gates remain MarketGates (sessions, hour filter, spread).

---

## 6. Growth ladder

| Balance | Action |
|---|---|
| 20 → 50 | Re-load 50 pack; raise ASAP family; allow 2nd FX |
| 50 → 100 | Re-load 100 pack; `InpMaxLot` 0.10 |
| 100 → 250 | See [PRESET_100EUR_RawSpread.md](PRESET_100EUR_RawSpread.md) ladder; % risk begins to size |
| 250+ | CMD optional; crypto only with nano/cent or larger equity |

Re-ladder monthly or every +50% balance, whichever first.

---

## 7. Preset index

| Band | Cost | Service | Scouter |
|---|---|---|---|
| 20 | Raw | `GSignalX_Service_Practice_20_Raw.set` | `ProfitScouter_Practice_20_Raw.set` |
| 20 | Standard | `GSignalX_Service_Practice_20_Standard.set` | `ProfitScouter_Practice_20_Standard.set` |
| 50 | Raw | `GSignalX_Service_Practice_50_Raw.set` | `ProfitScouter_Practice_50_Raw.set` |
| 50 | Standard | `GSignalX_Service_Practice_50_Standard.set` | `ProfitScouter_Practice_50_Standard.set` |
| 100 | Raw | `GSignalX_Service_Practice_100_Raw.set` | `ProfitScouter_Practice_100_Raw.set` |
| 100 | Standard | `GSignalX_Service_Practice_100_Standard.set` | `ProfitScouter_Practice_100_Standard.set` |

All under `deploy/presets/`.

---

## 8. Related

- Current cut: [RELEASE_v2.14_Input_Reliability.md](RELEASE_v2.14_Input_Reliability.md)
- EUR 100 deep dive: [PRESET_100EUR_RawSpread.md](PRESET_100EUR_RawSpread.md)
- Prop soft-lock: `Include/GSignalX/PropRisk.mqh` (uses **broker** balance — no virtual equity)
