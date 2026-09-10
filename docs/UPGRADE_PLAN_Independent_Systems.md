# Upgrade Plan — Independent Signal & Harvest Systems (GSignalX ⇄ ProfitScouter)

**Date:** 2026-09-08 · **Status:** implemented — all 5 programs compiled 0 errors / 0 warnings, confirm gates PASS · **Author:** Claude Code session
**Scope:** GsignalX_GocityGroup.mq5 (v1.14 → v1.15), ProfitScouter Core/EA/Service (v1.12 → v1.13)

---

## 0. Requirements (as requested)

| # | Requirement | Plain reading |
|---|---|---|
| R1 | **Closing profit threshold** — profiting trades must not / will not close on a loss | Once a trade has been in profit, no system path may close it negative; closes that book profit must clear a minimum profit floor |
| R2 | **Signal trigger independent of closing** (profit *and* loss) | The signal engine's entry decision must not be coupled to how/when trades are closed |
| R3 | **Profit Scouter triggering independent, background, simultaneous** | The harvester runs autonomously in the background (Service) while the signal engine keeps working; neither blocks the other |
| R4 | **Signal engine keeps the required number of active pairs filled** | While PLAY, the engine continuously (re-)enters until N pairs are live; after any close it refills |
| R5 | **Upgrade where necessary — deep & specific in system operation and performance** | Fix the operational gaps found in the code review below |

---

## 1. Current system operation (measured from source)

### 1.1 GSignalX signal engine (per-chart EA, 2,273 lines)

**Event model.** All work is driven by `OnTick` (one chart = one symbol):

1. `IsMarketOpen` / `TimeFilterOK` / `SpreadOK` gates computed every tick.
2. `CalcEngines()` once per **new bar** (1200+ bars copied via `CopyRates`, engines PP-SuperTrend / ATR-SuperTrend / SuperBollingerTrend recomputed in O(n)).
3. `EvaluateSignals()` only when `gNeedSignalEval` is armed (new bar, PLAY, or flat-edge march), retried while gates fail.
4. Entries: market or **limit+stop bracket** anchored to the signal-bar open; OCO cleanup on fill via `OnTradeTransaction`.
5. `ManagePendings()` + `ManageTrailing()` every tick.

**Closing paths that exist today (the coupling problem):**

| Path | Location | Trigger | Respects P/L? |
|---|---|---|---|
| Reverse close | `EvaluateSignals` → `CloseCurrent("reverse")` | opposite tradable signal | ❌ closes green or red |
| Reverse close (Reverse off) | same, `CloseCurrent("opposite signal")` | opposite signal | ❌ |
| Weekend flat | `OnTick` Friday hour | `InpCloseBeforeWE` (default **false**) | ❌ |
| STOP closes all | `SetRunState(false)` | `InpStopClosesAll` (default **false**) | ❌ |
| Manual CLOSE button | `OnChartEvent` | user | ❌ (manual, acceptable) |
| Overfill trim | `ResolveOverfill` | bracket double-fill | ❌ (correctness-critical, must stay) |
| Broker SL/TP | attached to every entry | `InpUseStop` (default **true**) | SL closes red by design |

**Re-entry after a harvest.** `OnTick` detects a flat edge (`gHadPosition && !havePos`) and sets `gMarchOnce = true` → the **next** `EvaluateSignals` joins the active engine direction **once**. If that attempt is skipped (spread, session, "already in position" race), the chart stays flat until the *next* flat edge or new PLAY — no retry loop, no fleet awareness.

**Drill window.** PLAY opens a 5–15-minute window (`InpDrillMinutes`, clamped). While active, charts join/re-enter the active direction; when it expires, behaviour returns to flip-only entries. There is **no** notion of "how many pairs should be live" anywhere in the codebase.

### 1.2 ProfitScouter harvest engine (EA + Service share `Core.mqh`)

**Cycle (every `InpCheckIntervalMs` = 100 ms):**

```
RefreshCurrencyFactor (60 s cache)
 → collect eligible positions (profit = floating + swap + cached commission)
 → loss guard  : acc floating ≤ −InpAccMaxLossMoney → close LOSERS only (deepest first)
 → account     : floating ≥ floor → close WINNERS only (highest first)
 → pair basket : sym floating ≥ floor → close that symbol's WINNERS only
 → position    : ticket ≥ floor → close (option: partial close InpPosPartialPct)
 → publish bus snapshot + heartbeat, redraw panel / log status
```

Scalp-ASAP mode (`InpScalpAsapAccountOnly = true`, default) skips trailing/window layers; the single account floor `InpAccTargetMoney` (default 2.0) drives all three levels. START/STOP arm is shared through the `PS{InstanceID}_RUN` global variable; the Service (chart-free, restarts with terminal, `while(!IsStopped())` loop) honors the chart EA's STOP when `InpRespectChartRunState = true`.

**Operational gaps found (R1/R5):**

| Gap | Evidence | Consequence |
|---|---|---|
| **Peak tracking only runs when trailing is enabled** | `TrailStep()` is called inside `if(InpPosTrailEnable)`; in ASAP mode `g_pos[r].peak` stays 0 | The engine literally does not know a position was ever in profit — it cannot protect a once-green trade |
| **Winner = any ticket > 0** | `IsProfitableTicket(profit)` is `profit > 0.0` | Account/pair target can "harvest" by closing a +$0.01 dust ticket while the real winners are elsewhere; per-ticket take is uncontrolled |
| **Give-back can fall through the floor** | `TrailCloseAllowed()` refuses to close below `InpTrailMinCloseProfit`, then nothing else acts | A trade that peaked at +50, retraced to +1 is *left open* and can finish red via SL or the EA's reverse close — exactly "profiting once, closing on a lose" |
| **Reverse-signal close is P/L-blind** | `CloseCurrent("reverse")` in the signal EA | The signal system, whose job is entries, is also the system most likely to close a once-profitable trade at a loss |
| **No fleet concept** | no "active pair count" anywhere | After ProfitScouter harvests a pair, refilling is one-shot and uncoordinated; nothing ensures the required number of live pairs |

### 1.3 Interaction map (today)

```
GSignalX (chart EA)                    ProfitScouter (Service, background)
  OnTick: engines -> ENTRY               100 ms loop: monitor -> CLOSE winners/losers
        \                                     /
         \-- reverse-signal CLOSE  <—couple—>  harvest -> flat edge -> march once -> re-entry
```

The reverse close is the only place where the signal engine *closes*; the march-once is the only place the signal engine *reacts* to closes. Both are weak points for the required independence.

---

## 2. Target architecture

```
GSignalX  = ENTRY ENGINE ONLY  — never closes a position (Scouter exit mode default)
            + fleet governor: keep N pairs live while PLAY, refilling continuously
            + independent 1 s timer (fleet + fill loop), own run state (PLAY/STOP)

ProfitScouter = EXIT ENGINE ONLY — never opens a trade
            + per-position PROFIT LOCK: once a ticket has profited, it is
              guaranteed to close green (never below keep-% of its peak)
            + minimum winner floor: profit harvests only take meaningful profit
            + runs chart-free as a Service, 100 ms cycle, fully parallel
```

Both keep talking over the FILE_COMMON bus (snapshots/heartbeats unchanged) and stay decoupled in state: `GSX_RUN_*` vs `PS{id}_RUN`, distinct GV prefixes.

---

## 3. Detailed design

### 3.1 Profit lock — "profiting ones will not close on lose" (Scouter, R1)

New inputs (both host shells, new group **7b. Profit lock & closing floor**):

```
input bool   InpProfitLockEnable = true;   // Profit lock: once green, never close red
input double InpProfitLockArm    = 1.0;    // Arm when peak profit >= (target ccy)
input double InpProfitLockKeepPct= 50.0;   // Guaranteed floor = keep-% of peak
input double InpMinWinProfit     = 0.10;   // Winner harvest: min profit per ticket (0 = off)
```

Mechanics (Core.mqh):

1. **Always-on peak tracking.** `PosRec` gains `lockArmed`. Every monitored position updates its peak every cycle regardless of mode (`peak = max(peak, profit)`, persisted via existing `SavePeak` machinery so it survives restarts).
2. **Arm:** when `peak >= Money(InpProfitLockArm)` → `lockArmed = true` (sticky).
3. **Fire:** when armed and `profit <= peak * InpProfitLockKeepPct/100` (and `profit > 0`) → close the ticket immediately, tag `PROFIT-LOCK`. Because floor > 0 whenever the lock armed, **the ticket is mathematically guaranteed to realize a profit** — it can never reach the loss guard, the SL, or the EA's reverse close first, because the lock fires at the 100 ms cycle while profit is still green.
4. **Winner floor.** `IsProfitableTicket()` becomes `WinCloseEligible()`: a ticket qualifies for any profit harvest only when `profit >= Money(InpMinWinProfit)` (legacy `> 0` when 0). Applied to account, pair-basket and single-ticket harvests alike. The **loss guard is untouched** — it still closes losers only, deepest first.
5. Lock state is shown in the panel/status lines and published on the bus (`lock_armed`, `lock_floor`) for the Grader.

Ordering inside `HandlePosition` becomes: **profit lock → hard target → trail → window**. In ASAP mode the lock runs *before* the ASAP-skip line so it is always active.

Why this satisfies R1 end-to-end: the lock guarantees a once-green ticket closes green; the winner floor guarantees green tickets are only taken at meaningful profit; the loss guard only ever touches red tickets; and with 3.2 below, the only remaining P/L-blind closer (reverse signal) is switched off by default.

### 3.2 Exit independence — signal engine stops closing (GSignalX, R2)

New input group **5e. Exit ownership**:

```
enum EnExitMode { GSX_EXIT_SIGNAL = 0,   // Signal closes on reverse (legacy)
                  GSX_EXIT_SCOUTER = 1 }  // Scouter owns ALL closes (default)
input EnExitMode InpExitMode = GSX_EXIT_SCOUTER;
```

`EvaluateSignals` change: when holding a position opposite to a fresh `wanted` signal:

- `GSX_EXIT_SCOUTER`: cancel any same-side pendings (they are stale entries), then `SignalSkip("opposite signal - exit deferred to Profit Scouter")` and **return without closing**. The Scouter closes the position on profit target / profit lock / loss guard; the flat-edge or fleet loop then re-enters in the new direction.
- `GSX_EXIT_SIGNAL`: exact current behaviour (reverse close) for users who want the old coupling.

Kept intentionally (documented): broker SL/TP on entries (last-resort safety net when the terminal is offline — the Scouter cannot act without a running terminal); `ResolveOverfill` (correctness, not strategy); weekend-flat / STOP-closes-all / manual CLOSE (each already behind its own default-off input or a human action).

Result: the entry decision is a pure function of engines + gates; close events influence it only through the fleet/march refill loop, which is the *desired* coupling (fill the quota back up).

### 3.3 Fleet governor — keep the required number of pairs active (GSignalX, R4)

New input group **5d. Fleet fill**:

```
input bool InpFleetEnable        = true;  // Keep N active pairs while PLAY
input int  InpFleetTargetPairs    = 5;     // Required live pairs (this magic)
input int  InpFleetFillCooldownSec= 10;     // Min seconds between fleet fills (anti-stampede)
input bool InpFleetRequireDrill   = false;  // Fill only inside the drill window
```

Mechanics:

1. **Active pair count** = number of *distinct symbols* holding an open position with `InpMagic` (scanned account-wide in `FleetActivePairs()`). Pendings don't count as active (an unfilled pending must not occupy a slot forever), but a chart with its own pending is considered "busy" and does not try to fill.
2. **Per-chart 1-second timer** (`EventSetTimer(1)` → new `OnTimer`). Each tick of the timer a chart runs `FleetFillCheck()`:
   - skip if not PLAY, not fleet-enabled, engines not ready, own symbol has a position or a pending, drill required but window inactive, fleet already at target, or spread/session gates fail;
   - claim the global fill slot with an atomic compare-and-set on GV `GSX_FLEET_LOCK_<magic>` (`GlobalVariableSetOnCondition`) — exactly one chart in the terminal can start a fill per cooldown window, which prevents N charts all firing at once and overshooting the target;
   - on claim: set `gMarchOnce = true`, arm `gNeedSignalEval`, and run the evaluation immediately (join the active direction under bot rules — the same proven `drillJoin` path the drill already uses).
3. **Continuous refill.** The flat-edge march (`InpDrillMarchAfterFlat`) stays; the fleet timer adds the missing retry loop: if a fill attempt was skipped for any reason, the next timer pass (1 s) tries again, re-counting the fleet first. Every close by the Scouter therefore results in a refill attempt within ~1 s + cooldown — "continuously enter position to fill up the required entry number".
4. **No same-symbol double-fill** is possible by construction: each chart trades only its own `_Symbol`, and a chart with a position/pending never fills. Overshoot across symbols is bounded by the CAS lock: after one fill, the next claimant re-counts before entering.

Performance: `FleetActivePairs()` is O(positions); the timer runs once per second per chart — negligible next to the existing per-tick `ManagePendings`/`ManageTrailing`.

### 3.4 Background, simultaneous operation (R3)

Already largely true; hardened by this upgrade:

- The **Service** edition is the always-on harvester (auto-restarts with the terminal, no chart, 100 ms loop). Its run state is only *optionally* linked to the chart EA (`InpRespectChartRunState`, default true — keep: it is a coordination convenience, not a dependency; with no chart EA present the Service runs armed by default).
- GSignalX gains its own timer so it no longer depends on bar boundaries or close events to act.
- Neither program calls into the other: coordination is only through positions, terminal GVs, and the bus — the definition of "fully independent and functional".

---

## 4. Step-by-step implementation plan

| Step | File | Change | Build gate |
|---|---|---|---|
| 1 | `Include/ProfitScouter/Core.mqh` | `PosRec.lockArmed`; always-on `TrackPosPeak`; profit-lock check at top of `HandlePosition` (both modes); `WinCloseEligible()` replacing `IsProfitableTicket()` in all harvest routines; lock row in panel/status; `lock_armed`/`lock_floor` on the bus | compiles 0 errors |
| 2 | `ProfitScouter_DollarTarget.mq5`, `ProfitScouter_Service.mq5` | new input group 7b (lock + floor); version bump 1.13 | compiles 0 errors |
| 3 | `GsignalX_GocityGroup.mq5` | `EnExitMode` + `InpExitMode`; `EvaluateSignals` opposite-holding branch respects it; version 1.15 | compiles 0 errors |
| 4 | `GsignalX_GocityGroup.mq5` | Fleet module: inputs 5d/5e, `FleetActivePairs()`, CAS lock, `OnTimer` → `FleetFillCheck()`, `EventSetTimer/EventKillTimer`, panel row (Exit/Fleet), init log | compiles 0 errors |
| 5 | `README.md`, `README_ProfitScouter.md` | document the three new behaviours and defaults | — |
| 6 | deploy | `deploy\Deploy-GSignalX.ps1 -TerminalDataPath <hash> -Compile` → all 5 programs `0 errors, 0 warnings` | deploy gate |
| 7 | confirm | `deploy\Confirm-GSignalX.ps1 -Gate All -WriteFeedback` → 0 hard failures, feedback file written | confirm gate |
| 8 | functional test | Strategy Tester recipe (below) + live-demo checklist | manual |

---

## 5. Test plan

### 5.1 Build verification (automated)
- Compile all five programs via the deploy script; require `Result: 0 errors, 0 warnings` in each `.log`.
- Run Confirm gates Files/Compile/Bus/Grades; a feedback block is written under `deploy\feedback\`.

### 5.2 Strategy Tester recipe (EA edition, demo account)
1. **Profit lock:** visual mode, any symbol. Open a manual position (visual mode allows manual trades). Watch the panel: `peak` rises; once `peak ≥ arm`, the row shows `LOCK`. Drag price against the position until profit falls to `peak × keep%` → log must show `PROFIT-LOCK: closed #… (locked +X.XX)` and the realized deal must be green.
2. **Winner floor:** set `InpMinWinProfit = 5`, open a position at +1 → an account target of 2 must **not** close it (log: skipped, below floor); at +5 it closes.
3. **Scouter exit mode:** attach GSignalX with `InpExitMode = Scouter`, wait for an opposite signal while holding a position → log must show `exit deferred to Profit Scouter`, position stays open, ProfitScouter closes it at target/lock/loss guard.
4. **Fleet:** attach the EA to 3 charts (3 symbols) with `InpFleetTargetPairs = 2`. Press PLAY on two of them → within a cooldown window exactly 2 pairs must be live; close one manually → the fleet refills within ~1–11 s. Watch the panel `Fleet: n/2` row.

### 5.3 Live-demo acceptance checklist
- [ ] Service running; experts log shows the startup line with `lock=ON floor=…`
- [ ] A harvested winner realizes ≥ `InpMinWinProfit` (account history)
- [ ] A locked ticket realizes ≥ `peak × keep%` (never red after arming)
- [ ] After each harvest, some PLAY chart re-enters; active-pair count returns to target
- [ ] STOP on the chart EA pauses entries but the Service keeps closing at targets (independent arms)
- [ ] No reverse-signal close appears in the log while `InpExitMode = Scouter`

---

## 6. Risk register

| Risk | Mitigation |
|---|---|
| Lock closes too early on noisy scalps (arm=1, keep=50% is tight) | Defaults are deliberately scalper-friendly; raising `InpProfitLockArm`/`KeepPct` loosens it; lock never fires before profit ≥ arm |
| Fleet over-entry if two charts claim in the same second | CAS on the fleet lock GV makes the second claim fail; cooldown re-counts before filling |
| Netting accounts: opposite entry while holding would auto-close | In Scouter exit mode opposite entries are skipped while holding — the Scouter closes, then fleet re-enters |
| Broker SL still closes red (terminal offline) | Intentional: SL stays as the offline safety net; Scouter owns closes whenever the terminal is alive |
| One-shot behaviours users rely on (reverse close) | `InpExitMode = Signal` restores the legacy behaviour exactly |

---

## 7. Next steps after this upgrade

1. Run the demo checklist (5.3) and record a feedback block.
2. Tune `InpProfitLockArm`/`KeepPct` per asset class (crypto wicks vs FX).
3. Optional follow-ups: publish fleet state on the bus for the Grader; per-symbol fleet weights; equity-based loss guard.