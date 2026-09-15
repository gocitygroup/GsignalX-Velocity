# Profit Scouter — Dollar Target (MT5 / MQL5)

A money-based profit monitoring and harvesting engine for MetaTrader 5. It does **not** open trades. It watches every open position and closes them when a money target or a peak-profit give-back rule fires.

**Velocity 2.00 host version:** `ProfitScouter_DollarTarget` / `ProfitScouter_Service` ship as `#property version "2.00"` (bus schema remains `"version":1`). Prop desk topology: [docs/RELEASE_v2.00_Prop_Desk_Deploy.md](docs/RELEASE_v2.00_Prop_Desk_Deploy.md).

**Adverse experience gates (shipped in prior 1.22, retained in 2.00):** loser Auto still requires signal + opposing closed-bar streak, plus **min hold age** (`InpAdverseMinAgeMin`, default **15** minutes) and **once-green protect** (`InpAdverseProtectOnceGreen`, default **ON** — skips tickets that already peaked green / lock-armed). Service adverse TF default is **M5**. Account/pair layers no longer early-return when a target is notionally hit but zero winners meet `InpMinWinProfit`. Audit: [docs/AUDIT_ProfitScouter_Loser_Close_2026-09-14.md](docs/AUDIT_ProfitScouter_Loser_Close_2026-09-14.md).

**Winner floor = ASAP 5:** defaults align so winners do not bank below **5** account currency (USD/EUR when `InpTargetCurrency` is blank): `InpAccTargetMoney=5`, `InpMinWinProfit=5`, `InpProfitLockArm=5`, and profit-lock floor is `max(keep-% of peak, MinWinProfit)`. Re-attach or **Reset** EA inputs if the chart still shows an old floor of 2 / MinWin 0.10.

**v1.18 movable panel:** the EA dashboard is an on-chart object panel (not `Comment`). Drag the title bar (**PROFIT SCOUTER · drag to move**) to reposition. **START / STOP / AUTO** are standalone chart buttons (`InpBtnX` / `InpBtnY`) so they stay visible while the panel moves. Panel position persists in `PS{InstanceID}_PNLX` / `PS{InstanceID}_PNLY`.

**v1.16 / v1.17 adverse-bar Auto loss exit:** when scout is START-armed, each cycle may close **same-symbol losers** if the last GSignalX bus signal conflicts with consecutive closed OHLC bars: BUY + selling bars > `InpAdverseMinBars` (default 2 → fire at ≥3), or SELL + buying bars > N. Winners are left for profit targeting at set levels. Default `CloseTicket` still refuses losses; only the `ADVERSE-BAR` path may pass `allowLoss`. Fire is once per symbol per bar (`PS{id}_ADV_{canon}`). Chart **AUTO** button (v1.17) toggles the feature via `PS{id}_ADVEN`. **v1.22** adds min hold age + once-green protect. Plan: [docs/PLAN_V1.18_Adverse_Bar_Auto_Exit.md](docs/PLAN_V1.18_Adverse_Bar_Auto_Exit.md).

**v1.15 default close guard:** account loss-guard inputs were removed. `CloseTicket` / `ClosePartial` re-read live profit (incl. swap + commission) and **refuse negatives** unless an explicit Auto path opts in (`allowLoss` — adverse-bar only in v1.16).

**v1.14 categorised buckets + minimal threshold harvest:** every cycle splits the monitored set into a **winners bucket** and a **losers bucket** (visible on the panel, in the Service status block, and on the connector bus). When a threshold fires, the engine closes **the smallest set of green tickets that covers the threshold** — biggest winners first — and then stops. Remaining winners keep running toward their own targets and **losers are never touched by a profit close**.

**v1.14 default = Scalp ASAP multi-layer (winners-only harvest):** one money floor (`InpAccTargetMoney`, default **5**, recommended band **2–10** in account currency or `InpTargetCurrency` USD/EUR). Each cycle checks **account → pair → position**. Profit targets bank the floor **from winners only** (minimal set). Trail/window rules stay off in ASAP. After harvest, remaining / new opens continue the cycle. Pair with GSignalX scalping drill so PLAY charts re-open after flat.

**v1.13 profit lock & winner floor:** the engine tracks each position's peak every cycle. Once peak reaches `InpProfitLockArm` (default **5**), lock arms; close when profit falls to `max(keep-% of peak, MinWinProfit)`. The **winner floor** `InpMinWinProfit` (default **5**, same as ASAP) blocks harvests and lock closes below that amount. Loss path unchanged (adverse / catastrophe only for reds).

**v1.12+ chart START / STOP / AUTO:** the EA edition is a **standalone** harvest tool. Chart buttons **START** (arm profit closes), **STOP** (watch P/L only), and **AUTO** (toggle adverse-bar loss exit). Run state persists in `PS{InstanceID}_RUN`; adverse Auto in `PS{InstanceID}_ADVEN`. The Service honors both when `InpRespectChartRunState=true` and `InpInstanceID` matches the chart EA.

**v1.10+** shares one Core engine (`Include/ProfitScouter/Core.mqh`) between the EA and Service, and can publish structured snapshots to the **FILE_COMMON connector bus** so every terminal can be graded together.

- Deploy: [DEPLOYMENT.md](DEPLOYMENT.md)  
- Bus protocol: [ARCHITECTURE_CONNECTOR_BUS.md](ARCHITECTURE_CONNECTOR_BUS.md)

---

## 1. What it does

| Layer | Hard target | Trailing (peak → give-back) |
|---|---|---|
| **Per position** | Close (or partially close) a single green ticket at N in profit | Arm at N, close after give-back in money or % of peak |
| **Per pair (basket)** | Bank the basket target from that pair's winners (minimal set) when their combined P/L hits N | Same, on the symbol's combined P/L |
| **Account** | Bank the target from the **winners bucket** when total floating P/L hits N (minimal set; losers stay open on profit path) | Same on total floating P/L — profit path never closes losers |

Evaluation order each cycle: **adverse-bar Auto (optional) → account → pair → position**. Profit harvest never closes red tickets — enforced by the default `CloseTicket` guard. Adverse Auto may close same-symbol losers when signal vs consecutive closed bars conflict. A profit close takes the **smallest set of winners** whose cumulative profit covers the threshold — other winners keep running toward their own targets. Winning pairs/positions can still harvest at the ASAP floor without waiting for net account P/L.

Profit includes swap and commission when those options are on (commission is read once from the position's opening deal and cached).

### Time-from-open window
`InpWindowStartMin` / `InpWindowEndMin` define the age band in which trailing is active (layered mode). **Scalp ASAP defaults leave `InpWindowEnable = false`** so hard money targets fire immediately with no age gate.

When the window is enabled (layered presets often use 30 → 60 minutes):

- age < start → peaks are still tracked, but no trail close (avoids being shaken out early)
- inside the band → trailing armed and live
- age > end → keeps trailing if `InpTrailAfterWindow = true`, otherwise stops
- `InpCloseAtWindowEnd = true` force-closes anything still green when the window expires

For baskets and the account level, "age" is the age of the **oldest** position in the group.

### Currency
Targets are entered in `InpTargetCurrency`. If it differs from the account currency, the EA finds a conversion rate by scanning Market Watch for a symbol whose base/profit currencies match (direct, or bridged through USD/EUR/GBP) and refreshes it every 60 seconds. Leave it blank to use the account currency directly.

### Persistence
Peak values are stored in terminal **global variables** (`PS<ID>_P_<ticket>`, `PS<ID>_S_<symbol>`, `PS<ID>_A_0`). If the terminal restarts, a position that had already run up to +40 keeps its peak instead of restarting from zero. Stale entries for positions that no longer exist are deleted on init. Adverse Auto last-fire stamps use `PS<ID>_ADV_<canon>` (one fire per symbol per bar). Chart AUTO on/off uses `PS<ID>_ADVEN`.

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

**Run one instance only** if the scope is "All symbols". Two instances monitoring the same positions will race each other. If you want several instances (e.g. one per strategy magic number), give each a different `InpInstanceID` so their stored peaks stay separate, and use `InpUseMagicFilter` so their position sets do not overlap.

### Standalone START / STOP (v1.12+)

Profit Scouter does **not** need GSignalX. Attach the EA alone to harvest any eligible open positions:

| Button | Effect |
|---|---|
| **START** | Arm scouting — money targets / ASAP closes run |
| **STOP** | Pause closes — panel still updates floating P/L; no closes at all until START again |
| **AUTO** | Toggle adverse-bar loss exit (ON/OFF). Does not pause profit targeting. |

State is stored in terminal global variables `PS{InpInstanceID}_RUN` (scout) and `PS{InpInstanceID}_ADVEN` (adverse Auto) and survives recompile/restart. Default arm on first attach: `InpScoutStartArmed=true`, `InpAdverseExitEnable=true`.

If you also run `ProfitScouter_Service` with the **same** `InpInstanceID` and `InpRespectChartRunState=true`, pressing **STOP** / **AUTO** on the chart EA updates Service closes as well.

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

### Scalp ASAP (default in v1.14+) — multi-layer profit cycle

One floor (`InpAccTargetMoney`) drives **account, pair, and position** hard closes. Raise it in the **2–10** band for larger takes. No trail give-back and no age window in ASAP.

- **Profit hit:** bank the floor from the winners bucket — biggest green tickets first, and only as many as needed to cover the threshold. Losers stay open on the profit path.
- **Adverse-bar Auto (v1.16+, default ON):** BUY signal + selling closed bars > `InpAdverseMinBars` (or SELL + buying bars) closes **same-symbol losers only** after **min hold age** and unless **once-green protect** skips them (v1.22); winners continue to set levels. Profit `CloseTicket` still refuses losses unless `allowLoss` (adverse path).
- Symbol basket targets bank the floor from **that pair's green tickets only** — other pairs are untouched.

GSignalX charts on PLAY then re-enter if the signal still says buy/sell (`InpDrillMarchAfterFlat`).

```
InpScope                   = All symbols
InpCheckIntervalMs         = 100
InpScalpAsapAccountOnly    = true
InpTargetCurrency          =      (blank = account ccy; or USD / EUR)

InpPosTargetEnable         = false   (ignored in ASAP — floor always armed)
InpPosTrailEnable          = false
InpSymTargetEnable         = false   (ignored in ASAP — floor always armed)
InpSymTrailEnable          = false

InpAccTargetEnable         = true
InpAccTargetMoney          = 5       (scalp default; band 2–10)
InpAccTrailEnable          = false

InpAdverseExitEnable       = true
InpAdverseMinBars          = 2       (fire when streak > 2, i.e. ≥3 closed bars)
InpAdverseTimeframe        = CURRENT (EA) / M15 (Service stock)
InpAdverseRequireSignal    = true    (skip if bus direction missing)

InpWindowEnable            = false
InpTargetsWindowOnly       = false

InpProfitLockEnable        = true
InpProfitLockArm           = 5      (arm when peak >= ASAP floor)
InpProfitLockKeepPct       = 50     (floor = max(50% of peak, MinWinProfit))
InpMinWinProfit            = 5.0    (no winner close below ASAP floor)
```

**Preliminary desk with GSignalX:** run signal charts on **M5** and set Service `InpAdverseTimeframe = PERIOD_M5` (the EUR100 RawSpread preset already does). For the chart EA, leave `PERIOD_CURRENT` and host it on an **M5** chart. That pairing keeps bus direction and adverse-bar cuts on the same clock — best performance for entry + harvest. Do not mix M15 signal charts with M5 adverse (or the reverse) unless you intentionally accept mismatched exit speed.

Cycle: adverse Auto may cut same-symbol reds when signal vs bars conflict; ticket or pair hits **5** → bank from winners (≥5 each); account net hits **5** → bank **5** from winners (biggest first, minimal set); remaining / new opens continue the cycle.

### Layered harvest (optional)

Turn `InpScalpAsapAccountOnly = false` and enable the classic pos / pair / account trail stack:

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
- Scalp ASAP **profit** closes only tickets with floating P/L > 0 (biggest first) and takes the **minimal set** that covers the threshold. Red tickets are never closed on a profit target. Default `CloseTicket` refuses negatives; **v1.16 adverse-bar Auto** is the only path that may close same-symbol losers (`allowLoss` + `ADVERSE-BAR`).
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
