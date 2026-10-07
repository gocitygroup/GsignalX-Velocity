# Daily Bias Follow — Computation Spec (portable)

**Product:** Gsignalx Velocity v2.18  
**Sources:** `Include/GSignalX/Bias/DailyBias.mqh`, `Include/GSignalX/Bias/BiasFollow.mqh`  
**Purpose:** Guide any system implementing the same bias filter (entries only; no EMA).

Bias in Velocity is D1 candle **open→close (or mid) outcome** — not EMA, not MACD, not joinDir.

---

## 1. What bias is (and is not)

| Is | Is not |
|---|---|
| Chart-aligned **day candle** direction (open vs close/mid) | EMA / SMA / MACD / SuperTrend |
| A **filter** on which entry sides are allowed | An exit / flatten / SL engine |
| Per-symbol | Desk-wide “one value pasted onto all pairs” |
| Live while a **lane is armed** | Sticky one-shot forever |

Engines still emit BUY/SELL. Bias only decides **FollowDir** for new entries.

---

## 2. Constants (must match)

```
BIAS_NEUTRAL  =  0
BIAS_BULLISH  =  1
BIAS_BEARISH  = -1

LANE_NONE  = 0   // "Signal" clear
LANE_DAILY = 1
LANE_PRE   = 2
LANE_THIRD = 3

NEUTRAL_PCT = 0.05          // 5% of H–L range = doji band
D1_BARS_NEEDED = 3          // rates[0], [1], [2]
MIN_ABS_BAND = 10 * point   // floor so tiny ranges don’t fake a side
INTRADAY_THROTTLE_SEC = 1   // Daily float recompute cadence
```

Optional debug fields (pivot / R1 / S1 from classic HLC) may be **stored** but **do not** drive published direction. Published dir comes only from `LegFromBarOutcome`.

---

## 3. Core math — `LegFromBarOutcome`

For one D1 bar with `open`, `high`, `low`, and `closeOrMid`:

```
range = max(0, high - low)
body  = closeOrMid - open
band  = max(NEUTRAL_PCT * range, minAbsBand)   // minAbsBand = 10*point (or 0 in pure tests)

if open<=0 or closeOrMid<=0:
    dir = NEUTRAL, strength = 0
elif range <= 0 or abs(body) <= band:
    dir = NEUTRAL, strength = 0          # doji / too flat
elif body > 0:
    dir = BULLISH
else:
    dir = BEARISH

if directional:
    strength = round(clamp(abs(body)/range, 0..1) * 100)   # 1..100
```

**Intuition:** green candle → BULL, red → BEAR, doji/micro-body → NEUT. Strength ≈ body as % of range.

**Pseudo (any language):**

```python
def bar_outcome(o, h, l, c, min_abs_band=0.0):
    rng = max(0.0, h - l)
    body = c - o
    band = max(0.05 * rng, min_abs_band)
    if o <= 0 or c <= 0:
        return 0, 0
    if rng <= 0 or abs(body) <= band:
        return 0, 0
    d = 1 if body > 0 else -1
    s = max(1, min(100, round(abs(body) / rng * 100)))
    return d, s
```

---

## 4. Three published lanes (same formula, different bars)

Need D1 rates with **index 0 = forming (current) day**, 1 = prior closed, 2 = two bars back.

| Lane | Input bar | closeOrMid | Behavior |
|---|---|---|---|
| **Daily** | `rates[0]` | **live mid** `(bid+ask)/2` (fallback bid / last / bar close) | **Floats** with price; expand H/L if mid outside day’s H/L |
| **Pre-D** | `rates[1]` | that bar’s **close** | **Static** until D1 rolls |
| **Third-D** | `rates[2]` | that bar’s **close** | **Static** until D1 rolls |
| **Signal** | — | — | Lane cleared → no bias filter |

**Daily H/L stretch:** before outcome, if `liveMid > high` → use mid as high; if `liveMid < low` → use mid as low. Then run outcome vs **today’s open**.

**Cache rules:**

- Refresh D1 rates when symbol changes or `bar0` (D1 open time) changes.
- Recompute Pre/Third only when `bar0` changes.
- Recompute Daily at most once per `INTRADAY_THROTTLE_SEC` (default 1s).

---

## 5. Arm → FollowDir (live one-side gate)

### Mapping (while armed)

```
BULL → FOLLOW_BUY   (entries BUY only)
BEAR → FOLLOW_SELL  (entries SELL only)
NEUT → FOLLOW_WAIT  (block new entries)
```

### Clear (Signal / Mode / manual FDIR)

```
LANE_NONE → FOLLOW_AUTO   (both sides allowed again)
```

**Critical:** While armed, FollowDir is **re-derived from live snap** on each gate/refresh — not frozen at click time. If Daily flips BULL→BEAR mid-session, entries flip with it. If it goes NEUT, entries **WAIT**.

Invalid/missing D1 while armed → treat as **WAIT** (safe block).

Bias **never** closes tickets; only entry eligibility.

---

## 6. System architecture (port this shape)

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ D1 OHLC + mid   │ →   │ Compute 3 legs   │ →   │ Snapshot store  │
│ (per symbol)    │     │ Daily/Pre/Third  │     │ (GV / redis /…) │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
┌─────────────────┐     ┌──────────────────┐              │
│ Armed lane      │ →   │ EffectiveFollow  │ ←────────────┘
│ NONE/D/P/T      │     │ BULL/BEAR/NEUT   │
└─────────────────┘     └────────┬─────────┘
                                 │
                        ┌────────▼─────────┐
                        │ Entry allow gate │  BUY/SELL vs FollowDir
                        └──────────────────┘
```

**Desk vs chart:**

- Desk arm: one lane for the magic; **each symbol** uses **that symbol’s** bias for the chosen lane.
- Chart arm: lane for one symbol only.
- Manual FollowDir / Mode clear → set lane to NONE.

**Packed store (optional, MT5 GV style):**  
`sign(dir) * (1000 + strength)` → e.g. BULL 72 → `1072`, BEAR 40 → `-1040`, NEUT → `0`.

---

## 7. Entry gate contract

When evaluating a signal BUY or SELL:

1. Resolve `followDir = EffectiveFollowDir(symbol)` (bias if armed, else roster AUTO/BUY/SELL/WAIT).
2. If `followDir == WAIT` → **deny**.
3. If `followDir == BUY` and signal is SELL → **deny** (and vice versa).
4. If `followDir == AUTO` → allow either side (other desk filters still apply).

Do **not** use bias to close, reverse, or trail.

---

## 8. Worked example

Symbol EURUSD, point = 0.00001 → `minAbsBand = 0.0001`.

**Today (forming):** O=1.1000, H=1.1050, L=1.0980, mid=1.1030

- range = 0.0070 (after mid stretch still inside)
- body = 0.0030
- band = max(0.05×0.0070, 0.0001) = 0.00035
- |body| > band → **BULL**, strength ≈ round(0.003/0.007×100) = **43**

**Yesterday (Pre-D):** O=1.1020, H=1.1040, L=1.0990, C=1.1000

- body = -0.0020, range = 0.0050 → **BEAR**, strength ≈ 40

**Arm Daily** → FollowDir = BUY. Mid later falls to 1.0995 vs open 1.1000 → may go **NEUT/BEAR** → WAIT/SELL live.

**Arm Signal** → FollowDir = AUTO.

---

## 9. Porting checklist

1. D1 series with forming bar at index 0; need ≥3 bars.
2. Implement only `LegFromBarOutcome` for published dirs (ignore pivot Agree path).
3. Daily = mid vs open; Pre/Third = close vs open on hist bars.
4. Persist three dirs (+ optional strength) per symbol.
5. Persist armed lane (desk and/or chart).
6. `EffectiveFollowDir` live map; NEUT→WAIT; NONE→AUTO.
7. Wire entry allow only; never closes.
8. Unit-test with fixed OHLC (Velocity’s `GsxBiasComputeFromOhlc` pattern).

---

## 10. Anti-patterns to avoid

- EMA / crossover / “trend strength” instead of open→close
- Freezing FollowDir at click and never updating Daily
- Treating NEUT as AUTO
- Closing or reversing from bias
- One desk click applying **one** pair’s dir to every symbol (must recompute **per symbol**)

---

## Related docs

- Trader manual chapter: [`docs/Gsignalx_Velocity_Users_Manual.html`](docs/Gsignalx_Velocity_Users_Manual.html)#bias-follow
- Release note: [`docs/RELEASE_v2.18_Daily_Bias_Follow.md`](docs/RELEASE_v2.18_Daily_Bias_Follow.md)
- Internal plan: [`docs/plans/DAILY_BIAS_FOLLOW_PLAN.md`](docs/plans/DAILY_BIAS_FOLLOW_PLAN.md)
