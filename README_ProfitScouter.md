# Profit Scouter — Dollar Target (MT5 / MQL5)

A money-based profit monitoring and harvesting engine for MetaTrader 5. It does **not** open trades. It watches open positions and banks **winners** when a clear **Profit CASH** floor (or layered trail/window rules) fires.

**Velocity hosts:** `ProfitScouter_DollarTarget` / `ProfitScouter_Service` (bus schema `"version":1`). Desk topology: [docs/RELEASE_v2.14_Input_Reliability.md](docs/RELEASE_v2.14_Input_Reliability.md) · Trader manual: [docs/Gsignalx_Velocity_Users_Manual.html](docs/Gsignalx_Velocity_Users_Manual.html#profit-cash).

**Profit CASH (stock default +100):** `InpAccTargetMoney`, `InpMinWinProfit`, and `InpProfitLockArm` default to **100** account/target currency (blank `InpTargetCurrency` = account USD/EUR). **CASH mode** (seeded by `InpScalpAsapAccountOnly`, toggled on chart as **CASH / LAYER**, persisted `PS{id}_CASH`) drives account + pair + position hard targets from that single floor and skips trail/window. **LAYER** restores per-layer targets, trail, and window rules.

**Loss CASH (opt-in):** `InpAccCashLossMoney` default **100**; arm `InpAccCashLossEnable` default **false**. Chart **LOSS** toggles `PS{id}_LOSS`. When armed and floating ≤ −floor, Scouter cuts scoped losers (`ACC-CASH-LOSS`). Default stays OFF so there is no surprise auto-flatten.

**Adverse experience gates:** loser Auto requires signal + opposing closed-bar streak, plus **min hold age** (`InpAdverseMinAgeMin`, default **15** minutes) and **once-green protect** (`InpAdverseProtectOnceGreen`, default **ON**). Service adverse TF default is **M5**. Account/pair layers no longer early-return when a target is notionally hit but zero winners meet `InpMinWinProfit`.

**Chart buttons:** **START / STOP / AUTO / TRAIL** · **BANK / CUT / FLAT** · **CASH / LAYER** · **LOSS ON / OFF**. Panel shows `Profit CASH +N` and `Loss CASH −N`. Drag the title bar to move; position persists in `PS{InstanceID}_PNLX` / `PNLY`.

**Winner harvest:** profit path closes the **smallest set of green tickets** that covers the threshold — biggest winners first. Losers are never touched by Profit CASH. Intentional loss closes: adverse **AUTO**, opt-in **Loss CASH**, manual **CUT / FLAT**.

**Default close guard:** `CloseTicket` / `ClosePartial` refuse negatives unless `allowLoss` (adverse, Loss CASH, or manual CUT/FLAT). Old account loss-guard input names are **not** restored.

**v1.12+ chart START / STOP / AUTO / TRAIL:** run state persists in `PS{InstanceID}_RUN`; adverse Auto in `PS{InstanceID}_ADVEN`; TRAIL in `PS{InstanceID}_TRAIL`. Service honors chart RUN / ADVEN / CASH / LOSS / TRAIL when `InpRespectChartRunState=true` and Instance ID matches.

**v2.01 agnostic / concurrent:** eligibility uses `GsxSymbolCanon` (broker suffixes OK). Service claims `PS{id}_CLOSER` (+ `PS{id}_CLOSER_TS` heartbeat) and owns **auto-harvest** while fresh; the EA yields automatic closes but **BANK / CUT / FLAT chart buttons always work** (operator override). Stale Service claim (>5s) lets the EA resume auto-harvest. Pair baskets use `InpBasketClosesPerCycle` + rotate. Desk practice soft-apply writes `PS{id}_FLOOR` / `_MINWIN` / `_LOCKARM` live overrides. Shared inputs live in `Include/ProfitScouter/Inputs.mqh`.

**v2.02 ATR/% TRAIL:** independent chart **TRAIL** arm (`PS{id}_TRAIL`) closes winners on ATR×mult / % peak / last-N candle range give-back (Hybrid default). Does not replace Profit CASH floors. Per-canon EMA optimizer nudges trail mult (`PS{id}_OPT_*`). Adverse AUTO optionally requires min body/range pts (`InpAdverseMinBodyPts` / `InpAdverseMinRangePts`, default **0** = unchanged).

**v1.10+** shares one Core engine (`Include/ProfitScouter/Core.mqh`) between the EA and Service, and can publish structured snapshots to the **FILE_COMMON connector bus** so every terminal can be graded together (`cash_mode`, `profit_cash`, `loss_cash`, `loss_cash_armed`).

- Deploy: [DEPLOYMENT.md](DEPLOYMENT.md)  
- Bus protocol: [ARCHITECTURE_CONNECTOR_BUS.md](ARCHITECTURE_CONNECTOR_BUS.md)

---

## 1. What it does

| Layer | Hard target | Trailing (peak → give-back) |
|---|---|---|
| **Per position** | Close (or partially close) a single green ticket at N in profit | Arm at N, close after give-back in money or % of peak (**LAYER** only) |
| **Per pair (basket)** | Bank the basket target from that pair's winners (minimal set) when their combined P/L hits N | Same, on the symbol's combined P/L (**LAYER** only) |
| **Account** | Bank **Profit CASH** from the winners bucket when total floating P/L hits N (minimal set; losers stay on profit path) | Same on total floating P/L (**LAYER** only) |

Evaluation order each cycle: **adverse-bar Auto (optional) → Loss CASH (if armed) → account → pair → position**. Profit harvest never closes red tickets — enforced by the default `CloseTicket` guard.

### Time-from-open window
`InpWindowStartMin` / `InpWindowEndMin` define the age band in which trailing is active (**LAYER** mode). **CASH mode defaults leave `InpWindowEnable = false`** so hard money targets fire immediately with no age gate.

### Currency
Targets are entered in `InpTargetCurrency`. If it differs from the account currency, the EA finds a conversion rate by scanning Market Watch. Leave it blank to use the account currency directly.

### Persistence
Peaks: `PS<ID>_P_<ticket>`, `PS<ID>_S_<symbol>`, `PS<ID>_A_0`. Arms: `PS<ID>_RUN`, `PS<ID>_ADVEN`, `PS<ID>_CASH`, `PS<ID>_LOSS`. Adverse fire stamps: `PS<ID>_ADV_<canon>`.

---

## 2. Build

1. Copy `ProfitScouter_DollarTarget.mq5` into
   `<Terminal Data Folder>\MQL5\Experts\`
   Find that folder from MT5: **File → Open Data Folder**.
2. Open MetaEditor (**Tools → MetaQuotes Language Editor**, or F4 from MT5).
3. In the Navigator, double-click the file, then press **F7** (Compile).
4. The Errors tab should read `0 error(s), 0 warning(s)` and produce
   `MQL5\Experts\ProfitScouter_DollarTarget.ex5`.

Command-line build (optional, for CI or scripted rebuilds):

```bat
"C:\Program Files\MetaTrader 5\MetaEditor64.exe" /compile:"%APPDATA%\MetaQuotes\Terminal\<HASH>\MQL5\Experts\ProfitScouter_DollarTarget.mq5" /log
```

The log lands next to the source as a `.log` file.

Requires MetaTrader 5 build 3000+ (uses `input group`, `CTrade`, millisecond timers).

---

## 3. Deploy and run

1. In MT5, refresh the Navigator (right-click → Refresh). The EA appears under **Expert Advisors**.
2. Enable algo trading: **Tools → Options → Expert Advisors** → allow automated trading; then click the **Algo Trading** toolbar button so it is green.
3. Open **one** chart to host the engine. With `InpScope = All symbols` the chart is only a container for the panel — but when pairing with **GSignalX**, host on **M5** (preliminary desk) so `InpAdverseTimeframe=CURRENT` matches the signal charts. Alone, any quiet symbol/TF is fine; Service users should still set `InpAdverseTimeframe=M5` for an M5 GSignalX desk.
4. Drag the EA onto the chart. On the **Common** tab tick *Allow Algo Trading*. Set your inputs on the **Inputs** tab. Press OK.
5. A smiley face appears top-right and the dashboard prints in the chart corner. **START** / **STOP** buttons appear (if `InpShowButtons=true`).

**Run one auto-closer only** for a given `InpInstanceID`. Prefer `ProfitScouter_Service` for unattended harvest (it claims `PS{id}_CLOSER` with a heartbeat). The chart EA with the same Instance ID yields **automatic** closes while Service is fresh, but **START/STOP/AUTO/TRAIL/CASH/LOSS and BANK/CUT/FLAT still work** on the chart. If Service stops (or its heartbeat goes stale >5s), the EA resumes auto-harvest. Use different `InpInstanceID` + magic filters for disjoint books.

### Standalone buttons (EA host)

Profit Scouter does **not** need GSignalX. Attach the EA alone to harvest any eligible open positions:

| Button | Effect |
|---|---|
| **START** (dense: **GO**) | Arm scouting — Profit CASH / LAYER closes run (`PS{id}_RUN`) |
| **STOP** | Pause closes — panel still updates floating P/L; no closes until START again |
| **AUTO** | Toggle adverse-bar loss exit ON/OFF (`PS{id}_ADVEN`). Does not pause profit targeting |
| **TRAIL** | Independent ATR/% candle auto-trail on winners (`PS{id}_TRAIL`). Does not replace Profit CASH |
| **BANK +** | Confirm → close **winners** only |
| **CUT −** | Confirm → close **losers** only |
| **FLAT** | Confirm → close **all** in scope |
| **CASH / LAYER** | Toggle single Profit CASH floor vs layered trail/window (`PS{id}_CASH`) |
| **LOSS ON / OFF** | Arm opt-in Loss CASH cut at −`InpAccCashLossMoney` (`PS{id}_LOSS`) |

**Only Scouter UI closes tickets.** Desk/Chart PLAY/STOP/HALT never flatten. Full system map: [Manual § Profit CASH](docs/Gsignalx_Velocity_Users_Manual.html#profit-cash).

State survives recompile/restart: `PS{InpInstanceID}_RUN`, `_ADVEN`, `_CASH`, `_LOSS`, `_TRAIL`. Default arm on first attach: scout START, adverse ON, TRAIL OFF, CASH mode seeded from `InpScalpAsapAccountOnly=true`, Loss CASH OFF.

### Best use — TRAIL (Scouter 2.02)

Operator checklist for give-back protection between hard Profit CASH floors:

1. **START ON** (master kill for all auto closes — TRAIL included).
2. Chart **TRAIL ON** (`PS{id}_TRAIL`); Service honors when `InpRespectChartRunState=true`.
3. Keep **Profit CASH** set for the hard bank; TRAIL does not replace it.
4. Keep **AUTO ON** for adverse losers; Loss CASH OFF unless you want −N flatten.
5. Manual **BANK / CUT / FLAT** always work (independent of TRAIL / CASH / AUTO).

Teachable recipe: [Manual · ATR TRAIL](docs/Gsignalx_Velocity_Users_Manual.html#atr-trail).

If you also run `ProfitScouter_Service` with the **same** `InpInstanceID` and `InpRespectChartRunState=true`, chart toggles update Service closes as well. Trade Center / Chart **PLAY** / **HALT** write the same `_RUN` when scout-link is enabled (desk **STOP** leaves Scouter harvesting).

### Making it survive terminal restarts
The EA is bound to its chart, and MT5 saves charts automatically:

1. With the EA attached and configured, right-click the chart → **Save As Picture… no** — instead use **Charts → Template → Save Template**, name it `profitscouter`.
2. Right-click chart → **Profiles → Save As** → name it `Scouter`. MT5 reloads the last profile, with its charts and their EAs, on every launch.
3. Confirm **Tools → Options → Charts → "Save deleted charts to reopen"** is on.

After that, launching the terminal restores the chart and re-runs `OnInit`, the millisecond timer restarts, and peaks reload from global variables. The EA also fires on `OnTick` and `OnTrade`, so it stays responsive between timer ticks.

### 24/7 operation
A desktop terminal must stay running and logged in. For unattended operation, rent an MT5 VPS (**Tools → Options → VPS**, or right-click the account in Navigator → *Register a Virtual Server*) and migrate the chart. The VPS copy runs even with your PC off. Note that terminal global variables are per-installation, so peaks do not migrate with it — the first cycle on the VPS rebuilds them from current profit.

---

## 4. Suggested starting configuration

### Profit CASH mode (stock default) — single-floor profit cycle

One floor (`InpAccTargetMoney`, stock **100**) drives **account, pair, and position** hard closes in **CASH** mode. Micro/demo books: lower the floor (or load practice / EUR100 presets). Mid-size commercial books: keep **100** or ≈0.5–1% of balance. No trail give-back and no age window in CASH mode.

- **Profit hit:** bank the floor from the winners bucket — biggest green tickets first, and only as many as needed to cover the threshold. Losers stay open on the profit path.
- **Adverse-bar Auto (default ON):** BUY signal + selling closed bars > `InpAdverseMinBars` (or SELL + buying bars) closes **same-symbol losers only** after **min hold age** and unless **once-green protect** skips them; winners continue to set levels.
- **Loss CASH:** leave OFF unless you want automatic loser cuts at −`InpAccCashLossMoney` (stock 100).

GSignalX charts on PLAY then re-enter if the signal still says buy/sell (`InpDrillMarchAfterFlat`).

```
InpScope                   = All symbols
InpCheckIntervalMs         = 100
InpScalpAsapAccountOnly    = true    (seeds CASH mode / PS{id}_CASH)
InpTargetCurrency          =      (blank = account ccy; or USD / EUR)

InpPosTargetEnable         = false   (ignored in CASH — floor always armed)
InpPosTrailEnable          = false
InpSymTargetEnable         = false   (ignored in CASH — floor always armed)
InpSymTrailEnable          = false

InpAccTargetEnable         = true
InpAccTargetMoney          = 100     (stock Profit CASH; micro: 5–20 or load preset)
InpAccTrailEnable          = false
InpAccCashLossEnable       = false   (Loss CASH arm OFF)
InpAccCashLossMoney        = 100

InpAdverseExitEnable       = true
InpAdverseMinBars          = 2       (fire when streak > 2, i.e. ≥3 closed bars)
InpAdverseTimeframe        = CURRENT (EA) / M5 (Service stock)
InpAdverseRequireSignal    = true    (skip if bus direction missing)

InpWindowEnable            = false
InpTargetsWindowOnly       = false

InpProfitLockEnable        = true
InpProfitLockArm           = 100     (arm when peak >= Profit CASH floor)
InpProfitLockKeepPct       = 50      (floor = max(50% of peak, MinWinProfit))
InpMinWinProfit            = 100.0   (no winner close below Profit CASH floor)
```

**Preliminary desk with GSignalX:** run signal charts on **M5** and set Service `InpAdverseTimeframe = PERIOD_M5` (the EUR100 RawSpread preset already does). For the chart EA, leave `PERIOD_CURRENT` and host it on an **M5** chart. That pairing keeps bus direction and adverse-bar cuts on the same clock — best performance for entry + harvest. Do not mix M15 signal charts with M5 adverse (or the reverse) unless you intentionally accept mismatched exit speed.

Cycle: adverse Auto may cut same-symbol reds when signal vs bars conflict; optional Loss CASH may cut losers at −N; ticket or pair hits Profit CASH → bank from winners; account net hits floor → bank from winners (biggest first, minimal set); remaining / new opens continue the cycle.

### Layered harvest (optional)

Turn CASH mode **OFF** (chart **LAYER**, or `InpScalpAsapAccountOnly = false` before first GV) and enable the classic pos / pair / account trail stack:

```
InpScope                = All symbols
InpCheckIntervalMs      = 1000
InpTargetCurrency       = USD

InpPosTargetEnable      = true    InpPosTargetMoney   = 10
InpPosTrailEnable       = true    InpPosTrailArm      = 5
InpPosTrailGiveMoney    = 2       InpPosTrailGivePct  = 30

InpSymTargetEnable      = true    InpSymTargetMoney   = 25
InpSymTrailArm          = 12      InpSymTrailGiveMoney= 4

InpAccTargetEnable      = true    InpAccTargetMoney   = 100
InpAccTrailArm          = 50      InpAccTrailGiveMoney= 15

InpWindowEnable         = true    30 → 60 minutes
InpTrailAfterWindow     = true
```

Rule of thumb for layered mode: the arm level should be ~2–3× the give-back, otherwise trailing closes on ordinary spread noise.

---

## 5. Testing before live use

1. **Demo first.** Open a few small manual positions and watch the dashboard's peak/armed columns move.
2. **Strategy Tester** works too: run in *Every tick* mode on a visual chart, open positions manually in visual mode, and confirm closures. The EA alone generates no trades, so a backtest without an order source shows nothing.
3. Set `InpVerboseLog = true` and read the **Experts** tab — every decision and every close retcode is logged.

---

## 6. Behaviour notes and limits

- **Netting accounts**: one position per symbol, so per-position and per-pair rules coincide. Partial close still works.
- **Trail close never books a loss** while `InpTrailRequirePositive = true`. If price collapses through the give-back level, the trade is left open for your own stop-loss to handle. Set it to `false` if you want the give-back rule to close regardless.
- **Market closed / trade disabled**: closes are retried `InpMaxRetries` times per cycle, then retried again on the next cycle. Retcodes `MARKET_CLOSED`, `TRADE_DISABLED` and `NO_MONEY` break the inner retry loop instead of hammering the server.
- **Partial closes** are skipped when the requested slice or the remainder would fall below the symbol's minimum volume; the EA then closes in full at target.
- The account-level peak resets to zero whenever the monitored set becomes empty (flat), so each new trading run starts clean.
- Profit CASH closes only tickets with floating P/L > 0 (biggest first) and takes the **minimal set** that covers the threshold. Red tickets are never closed on a profit target. Default `CloseTicket` refuses negatives; **adverse-bar Auto**, opt-in **Loss CASH**, and manual **CUT/FLAT** may close losers (`allowLoss`).
- Millisecond intervals: default **100 ms** for scalpers; below ~50 ms adds CPU with little extra fill quality.

---

## 7. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Dashboard shows `Trading: BLOCKED` | Algo Trading button off, EA's *Allow Algo Trading* unticked, or investor password / expert trading disabled server-side |
| Positions ignored | Scope or magic filter excludes them — set scope to *All symbols* and turn the magic filter off to confirm |
| `no conversion path XXX->YYY` in log | Target currency has no quote symbol in Market Watch; add one or leave `InpTargetCurrency` blank |
| Targets look off by a factor | Conversion factor is applied to every money input — check the factor shown on the dashboard |
| Trailing never arms | `InpPosTrailArm` too high, or positions younger than `InpWindowStartMin` (peaks track, close is deferred) |
| Nothing happens after restart | Chart wasn't in the saved profile — re-save the profile with the EA attached |


---

## 8. Service edition — `ProfitScouter_Service.mq5`

Same engine, no chart. A service is the right container for something meant to run permanently: it is not tied to a symbol, it is not lost when a chart or profile is closed, and MT5 restarts it automatically on launch.

### What changed from the EA

| EA | Service |
|---|---|
| `OnInit` + millisecond timer + `OnTick` / `OnTrade` | `OnStart()` owns a `while(!IsStopped())` loop with `Sleep(interval)` |
| `Comment()` dashboard on the chart | status block printed to the **Experts** log every `InpStatusEverySec`, optionally mirrored to `MQL5\Files\ProfitScouter_status.txt` |
| Scope "Chart symbol" used `_Symbol` | scope "Single symbol" uses the `InpPrimarySymbol` input |
| — | `SubscribeSymbols()` calls `SymbolSelect()` on init, because no chart subscribes them for you |
| `MQL_TRADE_ALLOWED` check | dropped (a chart/EA flag); terminal and account permissions are still checked |
| `Alert()` on close | removed; `Print` and optional push notification remain |

Everything else — targets, peaks, give-back trailing, the time window, currency conversion, global-variable persistence — is identical code.

### Install and run

1. Copy `ProfitScouter_Service.mq5` into `MQL5\Services\` (not `Experts\`).
2. Compile with **F7** in MetaEditor.
3. In MT5's Navigator, open **Services**, right-click the entry → **Add service**. The inputs dialog appears; set your parameters and give the instance a name. You can add several instances with different `InpInstanceID` and magic filters.
4. Right-click the instance → **Start**. Confirm the "allow modification of the trading account" prompt.
5. Watch the **Experts** tab: you should see the `started` line, then a status block at your chosen interval.

Running services restart automatically the next time the terminal launches — no chart, template or profile to maintain. To stop one, right-click → **Stop**; the loop exits at the next `IsStopped()` check.

### Caveats specific to services

- The **Algo Trading** toolbar button still governs trading. If it is off, the status block shows `trading=BLOCKED` and nothing is closed.
- A service has no `OnTick`, so reaction speed equals `InpCheckIntervalMs`. Default **100 ms** suits multi-layer scalp floors; raise if the Experts log is too chatty.
- Services do not run in the Strategy Tester. Test the EA edition there, or test the service on a demo account.
- If the terminal is disconnected, the loop idles at 1 s intervals instead of acting on stale prices.

---

## 9. Script edition — `ProfitHarvest_Now.mq5`

A one-shot manual sweep. Drop it on a chart, it evaluates once, closes whatever already meets a target, prints a summary and exits. No trailing, no window, no persistence — that's deliberate; it exists for "take it now" moments.

1. Copy into `MQL5\Scripts\`, compile with F7.
2. Drag onto any chart. Because of `#property script_show_inputs`, the parameters dialog opens first.
3. Set `InpDryRun = true` the first time — it reports what it *would* close and sends no orders.
4. With `InpConfirm = true` it shows a Yes/No box before closing anything.

Priority is the same as the engine: if the account target is met it banks **floor-qualified winners only**; otherwise it closes qualifying pair baskets; otherwise qualifying single positions. Losers are never closed by this script. Targets here are in account currency only.

### Which one to use

| Need | Use |
|---|---|
| Continuous unattended monitoring, survives restarts | **Service** |
| Continuous monitoring with an on-chart dashboard, tester support | **EA** |
| Manual, occasional, "close what's already green" | **Script** |
| Rank signals + harvest opportunities across terminals | **ProfitOpportunity_Grader** service |

---

## 10. Connector bus (multi-terminal)

Set `InpBusEnable = true` on ProfitScouter (EA or Service) and/or GsignalX. Snapshots land under Common Files:

`GSignalX\bus\v1\terminals\{tid}\...`

Start **one** `ProfitOpportunity_Grader` service on any participating terminal. It writes `grades\latest.json` (advisory only — no cross-terminal closes).

Deploy steps and the demo checklist are in [ARCHITECTURE_CONNECTOR_BUS.md](ARCHITECTURE_CONNECTOR_BUS.md).

**Note:** Free-text `InpWriteStatusFile` remains available on the Service for local debugging, but the JSON bus is the supported multi-terminal export.
