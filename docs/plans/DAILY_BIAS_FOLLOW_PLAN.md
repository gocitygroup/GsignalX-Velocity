# Daily Bias Follow (Desk + Chart)

**Status:** Chart-aligned independent day outcomes (2.18) + live one-side gate  
**Living plan** for Velocity bias lanes that match D1 candle colors.

## Product rule

Bias describes **each D1 bar’s price-move ending outcome** as seen on the chart — not EMA/MACD and not joinDir.
JoinDir still produces signals; bias only **filters** which sides may enter via FollowDir / `GsxAllowEntry`.
Bias never closes trades.

| Lane | Bar | Outcome |
|------|-----|---------|
| **Daily** | Forming `rates[0]` (floats) | Live mid vs **today’s open** — sell bar → BEAR, buy → BULL |
| **Pre-D** | Closed `rates[1]` | Close vs **that bar’s open** (static) |
| **Third-D** | Closed `rates[2]` | Same (static) — two bars back from today |
| **NEUT** | Doji | `\|C−O\| ≤ max(5%×(H−L), 10×point)` |

### While a bias lane is armed (one-side gate)

| Live lane dir | Effective FollowDir | Entries |
|---------------|---------------------|---------|
| BULL | BUY | joinDir BUY only |
| BEAR | SELL | joinDir SELL only |
| NEUT / invalid | WAIT | block new entries |
| Signal (lane NONE) | AUTO | both sides |

Gate resolves via `GsxBiasEffectiveFollowDir` at fill time (live snap), not a frozen one-shot only.

**Hard rule — No EMA:** Bias is only D1 open vs close/live-mid.

## Locked decisions

| Decision | Choice |
|----------|--------|
| Desk click | Desk-wide: arm one lane; each symbol’s FollowDir from **that** symbol’s bias |
| Chart click | Per-symbol only |
| While armed | Live lane dir → one-sided FollowDir (event sync GV) |
| Lanes | Daily \| Pre-Day \| Third-Day \| Signal (clear → AUTO) |
| Gate | `FollowGate.mqh` + `GsxBiasEffectiveFollowDir` |
| Hist refresh | Pre/Third only on D1 `bar0` change; Daily throttled |
| Bus shape | Extend `GsxBusSymbolView` |

## Modules

| Path | Role |
|------|------|
| `Include/GSignalX/Bias/DailyBias.mqh` | `GsxBiasLegFromBarOutcome` + D1 cache |
| `Include/GSignalX/Bias/BiasFollow.mqh` | Lane GVs + Apply + `GsxBiasEffectiveFollowDir` |
| `GSX_Bias_Test.mq5` | Unit tests |

## Checklist

- [x] Chart-aligned C vs O for Daily / Pre / Third (independent)
- [x] No EMA / no indicator bias
- [x] Core + `GsxBusSymbolView` bias JSON
- [x] Live one-side gate (NEUT→WAIT; BEAR→SELL only; BULL→BUY only)
