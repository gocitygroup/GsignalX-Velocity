# Preset — EUR 100 raw-spread 1:500 growth account

Date: 2026-09-10
Scope: default settings for GSignalX v1.19 (entry engine) + ProfitScouter v1.18 Service (exit engine) sized for a **EUR 100** account on a **raw-spread broker** (e.g. IC Markets Global: ~0.1–0.3 pip majors + ~$7/lot round-turn commission) at **1:500 leverage**.

Preset files (load in the EA/Service **Inputs → Load**):

| Program | Preset |
|---|---|
| `GsignalX_GocityGroup.mq5` (each chart) | `deploy/presets/GSignalX_100EUR_RawSpread.set` |
| `ProfitScouter_Service.mq5` (one instance) | `deploy/presets/ProfitScouter_100EUR_RawSpread.set` |

The chart-EA variant (`ProfitScouter_DollarTarget.mq5`) takes the same values — note its `InpAdverseTimeframe` default is CURRENT (chart TF), so keep that chart on M5 too.

---

## 1. The three constraints that shape the preset

1. **The minimum lot is the real risk setting.** At EUR 100, 1% risk = EUR 1, but a 2.0×ATR stop span needs lot 0.005 — `NormalizeLot()` floors it to 0.01. Every trade is 0.01 lots and the effective risk per trade = stop distance in pips × EUR 0.10 (~2% on M15, ~1–1.5% on M5). This is why the preset runs **M5 charts**. Percent sizing only starts sizing (rather than flooring) once balance ≈ EUR 200+.
2. **Losers ride past the sizing span.** In Scouter mode the only attached SL is the catastrophe stop (`InpStrategicStopMult` 4.0×ATR); red tickets exit via adverse-bar Auto (≥3 closed bars against the bus signal) or that SL. On M15 a loser can cost 4–5% of a EUR 100 account; on M5 ~2% worst case.
3. **The stock ASAP floor (EUR 5) is unreachable at 0.01 lots.** EUR 5 = 50 pips on EURUSD. The whole floor family (`InpAccTargetMoney` / `InpProfitLockArm` / `InpMinWinProfit`, stock 5/5/5 per the v1.21 alignment) is scaled 5× down here and laddered back up with the balance (§3).

Leverage 1:500 is not a risk driver at this size (0.01 lot EURUSD ≈ EUR 2 margin). Raw spread favours the design (commission ≈ EUR 0.07 per 0.01-lot round turn) as long as `InpIncludeCommission`/`InpIncludeSwap` stay **true** so every floor is net.

## 2. Changed inputs vs stock defaults

### GSignalX (entry) — M5, EURUSD + GBPUSD

| Input | Stock | Preset | Why |
|---|---|---|---|
| `InpMaxLot` | 5.0 | **0.10** | Hard sanity cap; a bug cannot open 5 lots on EUR 100. Raise with the ladder. |
| `InpFleetTargetPairs` | 4 | **2** | Two concurrent 0.01 positions cap a correlated bad wave at ~4% (not ~8–10%). Ladder to 3 @ EUR 250, 4 @ EUR 400+. |
| `InpMaxSpreadPt` | 40 | **25** | Raw majors idle at 1–3 points in-session; 25 still admits normal noise but rejects rollover blowout sooner. |
| `InpUseHourFilter` | false | **true** (7–20) | Excludes the rollover window outright instead of relying on the spread filter. |
| `InpPendMaxAgeMin` | 240 | **60** | On M5 a 4-hour-old bracket is far offside; sweep faster. |
| `InpExitMode` | Scouter | **Scouter** | Keep: signal never closes. |
| `InpStrategicStopEnable` / `_Mult` | true / 4.0 | **true / 4.0** | Disaster cap ≈ 2% of account at 0.01 M5. Do not widen. |
| `InpRiskMode` / `InpRiskPct` | % / 1.0 | **% / 1.0** | Dormant below ~EUR 200 (min-lot floor), then takes over automatically. |
| Signals, drill, bracket entry, weekend rules | — | **stock** | PP/SBT/MA triggers, 5+5 pip bracket, 10-min drill, Friday/weekend blocks all stay default. |

### ProfitScouter Service (exit)

| Input | Stock | Preset | Why |
|---|---|---|---|
| `InpAccTargetMoney` (ASAP floor) | 5.0 | **1.0** | 1% of balance per harvest cycle = 10 pips at 0.01 lots. Drives account + pair + position closes. |
| `InpProfitLockArm` | 5.0 | **1.0** | Arm lock at the floor (v1.21 alignment rule). |
| `InpMinWinProfit` | 5.0 | **0.50** | Lets two dust winners (e.g. +0.60 each) jointly bank the EUR 1 account floor; lock floor = max(50% of peak, 0.50). |
| `InpAccTargetPctBal` | 0.0 | **0.0** | The code takes `min(fixed, %)` at the account layer only (Core.mqh `HandleAccount`), so a % only *lowers* the floor and never reaches the pair/position layers. Manual ladder (§3) is cleaner. |
| `InpAdverseTimeframe` | M15 | **M5** | Match the chart TF — loser cuts after ~15 min instead of ~45, roughly halving realized losses. |
| `InpAdverseMinBars` / `_RequireSignal` / `_Enable` | 2 / true / true | **same** | Fire at ≥3 adverse closed bars, only when the bus signal conflicts. The single loser-exit path. |
| `InpIncludeCommission` / `InpIncludeSwap` | true / true | **true / true** | Critical on raw accounts — floors are net. |
| `InpSymbolList` | EURUSD,GBPUSD,XAUUSD | **EURUSD,GBPUSD** | Match the traded fleet. |
| Everything else (ASAP stack, trails off, window off, 100 ms poll) | — | **stock** | |

## 3. Growth ladder — re-apply as the account compounds

Every fixed-money knob must move with the balance; the floor is the compounding mechanism.

| Balance | `InpAccTargetMoney` / `InpProfitLockArm` | `InpMinWinProfit` | `InpFleetTargetPairs` | `InpMaxLot` | GSignalX charts |
|---|---|---|---|---|---|
| EUR 100 | 1.00 | 0.50 | 2 | 0.10 | EURUSD + GBPUSD M5 |
| EUR 250 | 2.50 | 1.00 | 3 | 0.25 | + one major (AUDUSD / USDJPY) M5 |
| EUR 500 | 5.00 (stock defaults) | 2.50 | 4 | 0.50 | + XAUUSD becomes viable (0.01 gold ≈ 1% risk span) |
| EUR 1,000+ | ≈1% of balance, review monthly | floor ÷ 2 | 4 | ≈1% × balance ÷ sizing span | as fleet, keep pairs ≤ 4 |

Rules of thumb:

- **Floor ≈ 1% of balance** at all times (stock `5` is the EUR 500 rung).
- A banked cycle ≈ +1%; a loser ≈ −1.5–2% (adverse Auto usually beats the 4×ATR catastrophe SL to it). The adverse exit keeping losers smaller than winners is the edge of the two-engine split at this size.
- Never widen `InpStrategicStopMult` above 4.0 — it is the per-trade disaster cap.
- Re-ladder **monthly** or every +50% balance, whichever first. Below EUR 200 the min-lot floor overrides `InpRiskPct` anyway.

## 4. Deploy & verify

1. Deploy the current build: `deploy\Deploy-GSignalX.ps1 -TerminalDataPath <hash> -Compile`, then start the ProfitScouter **Service** and attach GSignalX to two M5 charts (EURUSD, GBPUSD).
2. Load the presets: EA properties → **Inputs → Load** → the `.set` files above. **Running Services/EAs do not hot-reload inputs** — restart the Service from the Navigator after loading.
3. Press **PLAY** on both charts; confirm the link (`InpScoutInstanceID=1` matches the Service `InpInstanceID=1`).
4. Verify before funding:
   - Scouter panel: `ASAP floor 1.00 [ASAP]`, `win floor 0.50`, `Adverse Auto ON tf=M5` (the v1.21 README warns stale charts can still show the old 5/0.10 floor — if so, re-attach or Reset inputs).
   - GSignalX panel: Fleet row shows 2-pair coverage; session row starts at 0/0.
   - Bus JSON (`win_floor`, `acc_target`) reports 0.50 / 1.00.
5. **Demo first.** This is a risk-geometry proposal, not a performance forecast — the PP/SuperTrend/Bollinger agreement has not been backtested at these floors. Run demo or Strategy Tester (every-tick) for ~2 weeks and check the session closed wins/losses before going live.

---

## Related — $20 / $50 / $100 practice packs (Standard + Raw)

For Velocity Service + Scouter + Trade Center coach buttons (Scalp / Day / Swing), see **[PRACTICE_LIVE_SIM_20_50_100.md](PRACTICE_LIVE_SIM_20_50_100.md)** and plan **[PLAN_V2.02_Practice_Live_Simulation.md](PLAN_V2.02_Practice_Live_Simulation.md)**. The $100 Raw pack aligns with this EUR100 ASAP geometry; Standard packs use wider floors and `InpIncludeCommission=false`.
