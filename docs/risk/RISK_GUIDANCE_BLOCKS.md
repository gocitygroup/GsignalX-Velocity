# Stage 3 — Reusable Risk Guidance Blocks

Canonical catalog for the Velocity manual and digital tips.  
Each block answers: **check · why · failure · avoid · invalidate · monitor · asset delta**.

Block IDs match `Include/GSignalX/RiskGuidance.mqh`.

---

## Manual Trade Risk Check (template)

Adapt fields per section — do not paste identically everywhere.

```
┌──────────────────────────────────────┐
│ MANUAL TRADE RISK CHECK              │
├──────────────────────────────────────┤
│ Market condition:                    │
│ Signal still valid:                  │
│ Entry zone / DIR freshness:          │
│ Invalidation level:                  │
│ Stop-loss defined (sizing ≠ cat SL): │
│ Position size calculated:            │
│ Event/news risk checked:             │
│ Spread/liquidity checked:            │
│ Correlated exposure checked:         │
│ Exit conditions defined (Scouter):   │
│ Emotional override detected:         │
└──────────────────────────────────────┘
```

---

## PRETRADE — `RB_PRETRADE`

| Field | Guidance |
|-------|----------|
| Check | Instrument class (FX/CMD/CR/OTH), session open, Prop status, Event mode, Profit CASH sized to book |
| Why | Most bad fills start before PLAY — wrong book, wrong hour, locked Prop |
| Failure | Entering into SKIP/NEWS, Asia FX noise, or with stock Profit CASH 100 on a micro book |
| Avoid | “Must trade today”; loading Chart EA entries on same magic as DeskExecute |
| Invalidate | Prop LOCK, Event SKIP on symbol, market closed, stale bus OWN |
| Monitor | Session strip, event line, TG VERIFY if deals matter |
| Asset delta | FX: session hours matter. CR: 24h but spreads widen. CMD: USD/news sensitivity. OTH: verify contract hours |

---

## ENTRY — `RB_ENTRY`

| Field | Guidance |
|-------|----------|
| Check | Signal DIR still valid; FOLLOW/WAIT and FollowDir; spread gate; fleet capacity; lot FIXED vs intentional AUTOLOT |
| Why | A signal is not an order — execution conditions can invalidate it |
| Failure | Chasing old DIR after structure change; IGN on thin liquidity; AUTOLOT after a loss streak |
| Avoid | Averaging without a written rule; overriding WAIT emotionally |
| Invalidate | Opposite exposure under WAIT; max fleet; EQ DD soft-block; pair STOP/SUSPEND |
| Monitor | Fill price vs expected; immediate spread blowout |
| Asset delta | FX: max-spread pts. CMD: wider floors. CR: weekend/after-hours OK by gate, still check liquidity |

---

## OPEN — `RB_OPEN`

| Field | Guidance |
|-------|----------|
| Check | Has the **reason** for the trade changed? Strategic SL attached? Scouter START armed? |
| Why | Open tickets must keep earning the right to stay open |
| Failure | Moving StrategicStop wider; removing broker SL; micromanaging every M1 wiggle |
| Avoid | Closing solely because floating is red or green for a moment |
| Invalidate | Structural break of the setup thesis; Event SKIP while you planned to add |
| Monitor | Bus DIR vs position; adverse-bar path; session transition |
| Asset delta | Gaps (indices/equities/CMD opens) can jump past mental stops — verify broker SL behaviour |

---

## PROFIT — `RB_PROFIT`

| Field | Guidance |
|-------|----------|
| Check | Profit CASH / lock / TRAIL plan vs greed hold; CASH vs LAYER mode |
| Why | Structured banking ≠ fear of giving back |
| Failure | Moving TP farther after green float without a rule; disabling Scouter mid-winner |
| Avoid | Premature BANK of a partial plan that was designed to reach the floor |
| Invalidate | Thesis broken even if green — valid early exit |
| Monitor | Peak vs give-back; once-green protect on adverse path |
| Asset delta | Volatile CR/CMD may hit floor faster — do not treat that as “too easy, hold forever” |

---

## DRAWDOWN — `RB_DRAWDOWN`

| Field | Guidance |
|-------|----------|
| Check | Valid risk-based cut (adverse Auto / Loss CASH / Prop day loss) vs emotional CUT |
| Why | Red float alone is not a reason; broken thesis or budget hit is |
| Failure | Revenge re-entry; AUTOLOT after loss; clearing Prop without understanding the lock |
| Avoid | Hope-holding past StrategicStop plan; removing Loss CASH after it arms for a reason |
| Invalidate | Day loss / Prop LOCK / loss budget exhausted (practice bands) |
| Monitor | Session W/L/net; Prop peak DD vs account EQ guide |
| Asset delta | Illiquid symbols: slippage on CUT can exceed plan — size smaller before entry |

---

## EXIT — `RB_EXIT`

| Field | Guidance |
|-------|----------|
| Check | Close reason (BANK / CUT / FLAT / adverse / ATR-TRAIL / broker SL / Loss CASH) |
| Why | Strategy risk ≠ execution risk ≠ technology risk |
| Failure | Double Scouter instances racing; FLAT as panic without confirm |
| Avoid | Desk STOP/HALT expecting closes (they do not close) |
| Invalidate | N/A — document why you exited |
| Monitor | CloseTrigger / Telegram reason line |
| Asset delta | Partial fills / rejects: verify broker; do not assume guaranteed SL |

---

## POST — `RB_POST`

| Field | Guidance |
|-------|----------|
| Check | What invalidated or confirmed? Floor vs realized? Session budget left? |
| Why | Process improves only when reviewed |
| Failure | Ignoring correlated losses across EURUSD+GBPUSD |
| Avoid | Changing five knobs after one loser |
| Invalidate | — |
| Monitor | Journal: reason, class, session, close tag |
| Asset delta | Note class-specific failure (spread, gap, news) for next pre-trade |

---

## SETTINGS — `RB_SETTINGS`

| Field | Guidance |
|-------|----------|
| Check | Impact of PLAY/STOP/HALT/AUTOLOT/EQ/PROP/FLEET/LOAD before confirming |
| Why | Desk clicks change risk posture without closing tickets |
| Failure | HALT thinking book is flat; AUTOLOT on micro without understanding min-lot |
| Avoid | Widening `InpStrategicStopMult` above desk policy |
| Invalidate | — |
| Monitor | SettingsNotify TG line |
| Asset delta | Fleet add of CMD/CR changes capacity and correlation — re-check exposure |

---

## Compact digital tips (≤96 chars)

| ID | Example tip |
|----|-------------|
| `RB_PRETRADE` | Pre-trade: class+session+Prop+Event · size Profit CASH to book |
| `RB_ENTRY` | Entry: DIR fresh? spread OK? fleet room? FIXED unless intentional AUTO |
| `RB_OPEN` | Open: manage reason not P/L · cat SL stays · Scouter owns exits |
| `RB_PROFIT` | Profit: bank by plan (CASH/TRAIL) · not greed hold or fear BANK |
| `RB_DRAWDOWN` | DD: cut on thesis/budget · not hope · no revenge size |
| `RB_EXIT` | Exit: tag the reason · STOP≠close · one Scouter per book |
| `RB_POST` | Post: journal class+session+tag · one change at a time |
| `RB_SETTINGS` | Settings: entries/harvest posture only · tickets untouched |
| Desk soft | New entries only — open positions unchanged |
| Prop LOCK | Prop LOCK — no new risk until CLEAR · open tickets unmanaged here |
| Event SKIP | Event SKIP — block new fills on hit symbols · reassess after |
| FX session | FX: prefer LDN·NY · avoid thin Asia unless plan says so |
| CR note | Crypto: 24h ok · watch spread/liquidity · overnight SUSPEND if policy |
| CMD note | CMD: USD/news sensitive · verify hours/gaps · wider spread floors |
