# Plan v1.17 — Signal-Engine Entry Sanctity + Profit-Engine Loser Safety

Date: 2026-09-09
Scope: `GsignalX_GocityGroup.mq5` (v1.16 → v1.17), `Include/ProfitScouter/Core.mqh` (v1.14 → v1.15),
`ProfitScouter_Service.mq5`, `ProfitScouter_DollarTarget.mq5`, `ProfitHarvest_Now.mq5`.

---

## 1. Problem analysis (what the code shows today)

### 1.1 The signal engine IS closing losing trades — through the stop-loss it attaches

`InpExitMode = GSX_EXIT_SCOUTER` (default) already prevents reverse-closes: on an opposite
signal the EA defers the exit to Profit Scouter (`EvaluateSignals`, line ~1834). **But every
entry still carries a broker-side ATR stop-loss:**

- `OpenTrade()` (market entries): `sl = price ± InpStopMult*ATR` when `InpUseStop=true` — **and `InpUseStop` defaults to true**.
- `PlacePending()` (limit/stop bracket legs): the same `sl` is attached to every pending order.
- When price touches that SL, the broker closes the trade **at a loss** — from the terminal's
  point of view the signal engine's own SL is what closed the losing trade. This is the exact
  symptom reported ("the signal system is placing/closing losing trades").

Other unguarded close paths in the signal EA:

| Path | Location | Gated by exit mode? | Default |
|---|---|---|---|
| ATR stop-loss attached at entry | `OpenTrade`, `PlacePending` | **No** | **ON (`InpUseStop=true`)** |
| ATR take-profit attached at entry | `OpenTrade`, `PlacePending` | No | off (`InpUseTarget=false`) |
| Trailing-stop writes (SL moves) | `ManageTrailing` | No | off, but not gated |
| Weekend flat close | `OnTick` (`CloseCurrent("weekend flat")`) | **No** | off (`InpCloseBeforeWE=false`), but not gated |
| Reverse close on opposite signal | `EvaluateSignals` | Yes | deferred to Scouter |
| Duplicate overfill trim | `ResolveOverfill` | No | entry-size correction (kept, documented) |

### 1.2 The profit engine still has loser-closing code

- `Core.mqh` `HandleAccount()`: the **loss guard** (`InpAccLossGuardEnable`, `InpAccMaxLossMoney`,
  `CutLosersToGuard`) closes the deepest losers when the account floats below the guard. It is
  default-OFF, but the code path exists and one set-file flip re-enables it.
- `ProfitHarvest_Now.mq5` (manual harvest script): when the *account* total is at target it
  closes **ALL** positions — including losers. Basket mode likewise closes the whole basket,
  green and red together.

### 1.3 Stale pendings are never cleaned up

`ManagePendings()` only expires pendings when `InpPendExpiryBars > 0` (default **0 = never**) or
when a drill window ends. Outside drill, an unfilled bracket can sit forever — across days and
terminal restarts. Nothing sweeps orphans left from a previous session on init.

### 1.4 Fleet fill vs "latest direction"

`FleetFillCheck()` joins only `ActiveDirectionUnderRules()` — the *current* engine agreement.
When the engines momentarily disagree (e.g. one engine flipped, agreement not yet met) the
fleet stops filling even though the bot's latest signal direction is known (`gLastSigDir`).

### 1.5 Real-time visibility of trades and outcomes

The panel shows this chart's position and fleet count, but **no closed-trade outcome stats**
(wins/losses/realized P/L) and no account-wide floating P/L for the bot's magic — so "traded
positions and outcomes" cannot be watched in real time.

---

## 2. Required behaviour (user directives)

1. **Signal engine must never close any trade** — including trades it opened. Every close is
   owned by the profit engine.
2. **Every trade the signal engine opens must be managed by the profit engine** (Scouter scope
   covers it, magic filter must not exclude it).
3. **Profit engine must never close a losing trade.** No opt-in, no code path.
4. **Fleet keeps its default target pairs active, entering in the latest direction.**
5. **Old unfilled entries (pendings) must be cleaned up.**
6. **Real-time updates** of trading state, traded positions and outcomes.
7. Reliability + functionality, plan → implement → build → test.

---

## 3. Implementation steps

### Step 1 — GSignalX: entry sanctity in Scouter mode
- `ScouterOwnsExits()` helper (`InpExitMode == GSX_EXIT_SCOUTER`).
- `OpenTrade()` / `PlacePending()`: in Scouter mode send **SL=0 / TP=0** with every entry and
  pending leg. The ATR distance is still computed for **position sizing only** (percent-risk
  sizing keeps working; no broker-side stop is ever attached).
- `CloseCurrent()`: hard guard — refuses to close in Scouter mode, logs the block.
- Weekend flat: in Scouter mode delete pendings only, never close.
- `ManageTrailing()`: disabled in Scouter mode (it only writes SLs).
- OnInit validation: percent-risk sizing no longer requires `InpUseStop` in Scouter mode.
- `ResolveOverfill()` stays — it corrects a double fill (entry correction, the managed trade
  remains open).

### Step 2 — GSignalX: stale pending cleanup
- New input `InpPendMaxAgeMin` (default **240 min**, 0 = off) — auto-expire any unfilled
  pending older than N minutes, always (drill, bars and expiry-bars settings aside).
- `CleanupStalePendings()` runs from `ManagePendings()` every tick and once in `OnInit()`
  (sweeps orphans from previous sessions/restarts).

### Step 3 — GSignalX: fleet fill in the latest direction
- `FleetFillCheck()`: claim the slot when either the active rules direction OR the latest
  signal direction (`gLastSigDir`) is non-zero.
- `EvaluateSignals()` join path: when marching (fleet fill / post-harvest) and the rules give
  no direction, fall back to `gLastSigDir` — the fleet fills in the **latest** direction.

### Step 4 — GSignalX: real-time positions + outcomes
- Session outcome tracking in `OnTradeTransaction` (DEAL_ENTRY_OUT): closed count,
  wins/losses, realized P/L (profit + swap + commission).
- Account-wide live stats for this magic: position count + floating P/L.
- Panel: new "Session" row (closed trades, realized, win rate) and "Fleet / Exit" row extended
  with live floating P/L. Updated every tick — real time.
- Bus: publish `positions`, `fleet_floating`, `closed_count`, `closed_wins`, `closed_losses`,
  `closed_realized` in the signal snapshot.
- Version → 1.17.

### Step 5 — ProfitScouter Core: losers are untouchable
- `CloseTicket()` / `ClosePartial()`: **hard guard** — re-read live profit (incl. swap +
  commission) immediately before sending; if < 0, refuse the close and log. This makes
  "never close a losing trade" a structural invariant, not a policy.
- **Remove the loss guard entirely**: inputs `InpAccLossGuardEnable` / `InpAccMaxLossMoney`
  deleted from both host shells, `CutLosersToGuard()` and its call site deleted from Core.
  Bus keeps publishing `loss_guard: false` for consumer compatibility.
- Session outcome stats: closed-session count + realized P/L tracked on every successful
  close; shown in status log, EA panel and bus snapshot (`closed_session`, `realized_session`).

### Step 6 — ProfitScouter host shells
- Remove the two loss-guard inputs from `ProfitScouter_Service.mq5` and
  `ProfitScouter_DollarTarget.mq5`, bump both to v1.15, update descriptions
  ("losers are never auto-closed — hard-coded").

### Step 7 — ProfitHarvest_Now: winners-only manual harvest
- Account/basket/singles modes close **green tickets only**; losers are reported and left open.
- Version → 1.10.

### Step 8 — Build
```
deploy\Deploy-GSignalX.ps1 -TerminalDataPath <hash> -Compile
   (MetaEditor: "C:\Program Files\MetaTrader 5 IC Markets Global\MetaEditor64.exe")
```
All `.mq5` files + both `.mqh` trees must compile with 0 errors.

### Step 9 — Test / verify
```
deploy\Confirm-GSignalX.ps1 -Gate All -WriteFeedback
```
- Compile gate: 0 errors.
- Static verification checklist (grep-level):
  - no `PositionClose`/`PositionClosePartial` call in `GsignalX_GocityGroup.mq5` outside
    legacy-mode branches / overfill correction;
  - Core `CloseTicket` guard present; no `CutLosersToGuard` anywhere;
  - no SL/TP attached in Scouter-mode entry paths;
  - stale-pending sweep present and called from OnInit + ManagePendings.
- Behavioural recipes (live terminal, PLAY state):
  1. Force an opposite signal with an open position → panel must show "exit deferred to
     Profit Scouter", position stays open.
  2. Open trade in Scouter mode → position shows SL **none** / TP **open** on panel.
  3. Push a winner above the ASAP floor → Scouter banks it; losers untouched.
  4. Leave a pending untriggered > max age → it expires with a log line.
  5. Watch panel "Session" row update the moment a close lands (OnTradeTransaction).

### Step 10 — Docs + memory
- Record build/test results in this document (§4).
- Update session memory with the new guarantees.

---

## 4. Results (2026-09-09)

### Build — PASS
`Deploy-GSignalX.ps1 -TerminalDataPath 010E047102812FC0C18890992854220E -Compile`
compiled all five sources with **0 errors, 0 warnings**:

| Source | Result |
|---|---|
| Experts\GsignalX_GocityGroup.mq5 (v1.17) | 0 errors, 0 warnings |
| Experts\ProfitScouter_DollarTarget.mq5 (v1.15) | 0 errors, 0 warnings |
| Services\ProfitScouter_Service.mq5 (v1.15) | 0 errors, 0 warnings |
| Services\ProfitOpportunity_Grader.mq5 | 0 errors, 0 warnings |
| Scripts\ProfitHarvest_Now.mq5 (v1.10) | 0 errors, 0 warnings |

### Confirm gate — PASS
`Confirm-GSignalX.ps1 -Gate All -WriteFeedback` → **PASS, 0 hard failures**
(feedback: `deploy\feedback\CONFIRM_2026-09-09_165822_All.md`).
Two WARNs remain on the Bus/Grades heartbeat age — these are a known
~3 h clock-skew artifact (bus timestamps use broker *server* time, the
gate computes age from local machine time). Pre-existing, not from this
change. Two earlier gate runs showed transient `FAIL missing heartbeat` /
`FAIL grades\latest.json missing` races while the live publishers were
atomically rewriting those exact files; both cleared on re-run.

### Static verification — PASS
- No `CutLosersToGuard` / `IsLosingTicket` / `InpAccLossGuardEnable` /
  `InpAccMaxLossMoney` anywhere in `.mq5`/`.mqh` (grep clean).
- `CloseTicket` / `ClosePartial` / `ClosePos` all carry the hard
  never-close-a-loser guard.
- Scouter-mode entry paths attach SL=0 / TP=0; `CloseCurrent` is blocked;
  trailing and weekend flat are gated off in Scouter mode.
- Stale-pending sweep wired into `OnInit` + `ManagePendings`.

### Live observation at deploy time
The terminal was live during the build: the bus showed 3 open losing
positions (XAUUSD −8.24, XAUGBP −7.02, XAUEUR −7.50; account −22.76)
**left open by the profit engine** — exactly the required behaviour —
while `last_action` showed a 2.37 account-target harvest banked earlier
from winners.

### Runtime action required (not code)
The running instances still execute the previous build (bus JSON was in
the old format). To load v1.17 / v1.15:
1. Stop and **restart the ProfitScouter_Service** (and the Grader) from
   the Navigator → Services panel — MT5 services do not hot-reload.
2. **Re-attach / refresh the GsignalX charts** (switch timeframe or
   remove+re-add the EA) so each chart reloads the new `.ex5`.
   Open positions and pendings are untouched by a reload; the stale
   pending sweep will clean any orphan brackets on init.

After restart, verify in real time:
- New signal JSON carries `positions`, `fleet_floating`, `closed_count`,
  `closed_wins`, `closed_losses`, `closed_realized`.
- Scouter snapshot carries `closed_session`, `realized_session` and
  `loss_guard: false`.
- Panel rows "Fleet / Exit" (live floating P/L) and "Session"
  (closed trades, win/loss, realized) update on every tick/close.
- New entries show **SL none / TP open** on the panel (Scouter mode).