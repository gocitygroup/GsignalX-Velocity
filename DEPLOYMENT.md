# GSignalX MQL5 Toolkit — Deployment Guide

Step-by-step install, compile, run, and verify for the connector bus + opportunity grader on one or more MetaTrader 5 terminals.

**Guided deploy with confirmation gates + feedback:** [DEPLOYMENT_RUNBOOK.md](DEPLOYMENT_RUNBOOK.md)

**Commercial v1.21 release (AutoLot / EQ / Compact panel):** [docs/RELEASE_v1.21_Commercial_Deploy.md](docs/RELEASE_v1.21_Commercial_Deploy.md)

For protocol/schema details see [ARCHITECTURE_CONNECTOR_BUS.md](ARCHITECTURE_CONNECTOR_BUS.md).  
For Profit Scouter inputs see [README_ProfitScouter.md](README_ProfitScouter.md).

---

## 1. Prerequisites

| Requirement | Notes |
|---|---|
| MetaTrader 5 build **3000+** | Uses `input group`, `CTrade`, ms timers, Services |
| Windows user profile | Common Files are per Windows user — terminals must share the same user to share the bus |
| Algo Trading enabled | Toolbar button green; Tools → Options → Expert Advisors → allow automated trading |
| Demo first | Validate bus + grades before live |

---

## 2. What gets deployed

| Source (this repo) | Destination under terminal data folder |
|---|---|
| `Include/GSignalX/*.mqh` | `MQL5\Include\GSignalX\` |
| `Include/ProfitScouter/*.mqh` | `MQL5\Include\ProfitScouter\` |
| `GsignalX_GocityGroup.mq5` | `MQL5\Experts\` |
| `ProfitScouter_DollarTarget.mq5` | `MQL5\Experts\` |
| `ProfitScouter_Service.mq5` | `MQL5\Services\` |
| `ProfitOpportunity_Grader.mq5` | `MQL5\Services\` |
| `ProfitHarvest_Now.mq5` | `MQL5\Scripts\` |

**Terminal data folder:** in MT5 use **File → Open Data Folder**.  
Typical path: `%APPDATA%\MetaQuotes\Terminal\<HASH>\`

**Shared bus (all terminals on this PC/user):**  
`%APPDATA%\MetaQuotes\Terminal\Common\Files\GSignalX\bus\v1\`

---

## 3. Automated deploy (recommended)

### Click and run (easiest)

**New install:** double-click [`deploy\Click-and-Run-Deploy.bat`](deploy/Click-and-Run-Deploy.bat)

**Upgrade to a new toolkit version:** double-click [`deploy\Clean-and-Deploy.bat`](deploy/Clean-and-Deploy.bat)  
(removes old Experts/Services/Scripts/Includes + Common Files bus, then deploy/compile/confirm)

| File | What it does |
|---|---|
| [`Clean-and-Deploy.bat`](deploy/Clean-and-Deploy.bat) | **Upgrade:** clean old install → deploy → compile → confirm |
| [`Clean-Old-Version.bat`](deploy/Clean-Old-Version.bat) | Clean only (then run Click-and-Run-Deploy yourself) |
| [`Click-and-Run-Deploy.bat`](deploy/Click-and-Run-Deploy.bat) | Deploy/compile/confirm without wiping first |
| [`Confirm-After-Start.bat`](deploy/Confirm-After-Start.bat) | Re-check Bus + Grades after Services start |
| [`List-Terminals.bat`](deploy/List-Terminals.bat) | List MT5 data folders |

After deploy:

1. In MT5: Algo Trading ON → start `ProfitScouter_Service` + `ProfitOpportunity_Grader` → attach GsignalX (bus ON)  
2. Double-click [`deploy\Confirm-After-Start.bat`](deploy/Confirm-After-Start.bat)

If MetaEditor is not found, edit the deploy `.bat` and set `METAEDITOR=...`.

### PowerShell (from repo root `MQ5\files`)

### List known terminal data folders

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\Deploy-GSignalX.ps1 -ListTerminals
```

### Copy sources into one terminal

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\Deploy-GSignalX.ps1 `
  -TerminalDataPath "$env:APPDATA\MetaQuotes\Terminal\<HASH>"
```

### Copy + compile with MetaEditor

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\Deploy-GSignalX.ps1 `
  -TerminalDataPath "$env:APPDATA\MetaQuotes\Terminal\<HASH>" `
  -Compile `
  -MetaEditorPath "C:\Program Files\MetaTrader 5 IC Markets Global\MetaEditor64.exe"
```

### Deploy to every terminal under Common MetaQuotes

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\Deploy-GSignalX.ps1 -AllTerminals -Compile `
  -MetaEditorPath "C:\Program Files\MetaTrader 5 IC Markets Global\MetaEditor64.exe"
```

The script:

1. Creates `Include\GSignalX`, `Include\ProfitScouter`, Experts / Services / Scripts dirs as needed  
2. Copies `.mqh` / `.mq5` files  
3. Optionally runs MetaEditor `/compile` in the documented order  
4. Prints `Result:` lines from each `.log`

Expect **0 errors, 0 warnings** on a healthy install.

---

## 4. Manual deploy

1. **File → Open Data Folder** in each MT5 terminal you will use.  
2. Copy folders/files per the table in §2.  
3. Open MetaEditor (F4).  
4. Compile in this order (Navigator → file → F7):

   1. `Services\ProfitScouter_Service.mq5`  
   2. `Experts\ProfitScouter_DollarTarget.mq5`  
   3. `Services\ProfitOpportunity_Grader.mq5`  
   4. `Experts\GsignalX_GocityGroup.mq5`  
   5. `Scripts\ProfitHarvest_Now.mq5`

5. In MT5 Navigator: right-click → **Refresh**.

---

## 5. First-run configuration

### 5.1 Global terminal settings

1. Tools → Options → Expert Advisors  
   - Allow automated trading  
   - Allow DLL imports: **off** (not required)  
2. Click **Algo Trading** so it is green.

### 5.2 ProfitScouter Service (unattended harvest)

1. Navigator → **Services** → right-click `ProfitScouter_Service` → **Add service**  
2. Suggested inputs for bus-enabled demo:

| Input | Value |
|---|---|
| `InpScope` | All symbols |
| `InpCheckIntervalMs` | 1000 |
| `InpBusEnable` | **true** |
| `InpLogStatus` | true |
| `InpInstanceID` | 1 (unique per overlapping magic scope) |

3. Start the service; allow trading-account modification if prompted.  
4. Experts tab should show `started ... bus=ON`.

### 5.3 Opportunity Grader (one instance per PC is enough)

1. Add service `ProfitOpportunity_Grader`  
2. Defaults are fine for demo:

| Input | Default | Meaning |
|---|---|---|
| `InpIntervalMs` | 2000 | Scan period |
| `InpHeartbeatTTLSec` | 15 | Drop stale terminals |
| `InpTopN` | 8 | Rank list length |
| `InpSwingStartHour` / `InpSwingEndHour` | 12 / 17 | Server-time swing band |
| `InpLogRanks` | true | Print top ranks |

3. Start it. Look for `Grader: terminals_scanned=...`.

### 5.4 GsignalX (signals + bus publish)

1. Open a liquid chart (e.g. EURUSD H1).  
2. Attach `GsignalX_GocityGroup`.  
3. Common tab: Allow Algo Trading.  
4. Set `InpBusEnable = true`, `InpBusShowGrades = true`.  
5. Optional: tune `InpSwingStartHour` / `InpSwingEndHour` to your broker server clock.  
6. Panel row **Opp grades** should update within a few seconds after Grader runs.  
7. **Orders (v1.12+):** default `InpEntryMode = Market`. Press PLAY mid-bar after a signal — the EA re-arms evaluation and should place (or show `skip:` / `waiting:` on Last action). Bright BUY/SELL arrows are trade-quality; muted `~` arrows are filtered flips only.

**Crypto on weekends (v1.11+):** leave `InpCryptoAllowWeekend=true` (default). Crypto is auto-detected from symbol path/currency/name. If a broker uses odd names, set `InpCryptoExtraList` (e.g. `BTCUSD,ETHUSD`). FX still blocks Sat/Sun when `InpBlockWeekend=true`. Stale ticks / trade-disabled remain hard stops for crypto too.

### Weekend demo checks

- Crypto chart Sat/Sun with fresh ticks: panel `OPEN`, signals can fire.  
- FX chart Sat/Sun: still `CLOSED (weekend)`.  
- Bus signal JSON: `"is_crypto":true`, `"weekend":false` for exempt crypto.

### 5.5 Multi-terminal

Repeat §3–§5.2 (and optionally §5.4) on each terminal.  
Start **one** Grader only (any participating terminal).  
All publishers must use the **same Windows user** so they share Common Files.

---

## 6. Verify deployment

### 6.1 Files on disk

Open:

`%APPDATA%\MetaQuotes\Terminal\Common\Files\GSignalX\bus\v1\`

You should see:

```
terminals\_index.txt
terminals\<tid>\heartbeat.json
terminals\<tid>\signals\_list.txt
terminals\<tid>\signals\<SYMBOL>.json      (after GsignalX)
terminals\<tid>\scouter\snapshot.json      (after Scouter)
grades\latest.json                         (after Grader)
```

### 6.2 Functional checks

| Check | Pass criteria |
|---|---|
| Heartbeat fresh | `ts` in heartbeat within last ~15s while publisher runs |
| Signal publish | `symbol_canon` strips broker suffixes (`EURUSDm` → `EURUSD`) |
| Scouter snapshot | `floating`, `symbols[]`, `trading_ready` present |
| Grades | `grades\latest.json` has `entries` and/or `harvests` |
| TTL | Stop publishers → after TTL, Grader drops that `tid` from ranks |
| Panel | GsignalX shows local score + top entry/harvest lines |

### 6.3 Safety reminder (phase 1)

Grades are **advisory**. Closures still happen only inside the local ProfitScouter on that terminal. There is no cross-terminal auto-close.

---

## 7. Recommended operating layouts

| Goal | Run |
|---|---|
| Unattended harvest + grading | Scouter **Service** + Grader Service (no chart required) |
| Chart dashboard harvest | Scouter **EA** on a quiet chart + Grader |
| Signals + grades on chart | GsignalX + Grader (+ Scouter if harvesting) |
| Manual take-profit sweep | `ProfitHarvest_Now` script (dry-run first) |

Do **not** run two Scouters against the same positions unless magic/`InpInstanceID` scopes do not overlap.

---

## 8. VPS / second PC notes

- Common Files do **not** sync across machines or Windows users.  
- Each VPS needs its own deploy + its own Grader (or a later WebRequest bridge — phase 2).  
- Peak GlobalVariables are per terminal install; after VPS migrate, peaks rebuild from live profit.

---

## 9. Upgrade / rollback

**Upgrade:** re-run `Deploy-GSignalX.ps1` (or copy files), recompile, restart Services, re-attach EAs.  
**Rollback:** restore previous `.mq5` / `Include` copies from git, recompile, restart.

Bus schema uses `"version":1`. Old readers ignore unknown versions; keep publishers and Grader on the same toolkit revision when possible.

---

## 10. Troubleshooting

| Symptom | Fix |
|---|---|
| Compile: `file not found` Include | Includes not under `MQL5\Include\GSignalX` (and ProfitScouter) |
| Service missing in Navigator | File must live in `MQL5\Services\` then Refresh |
| `bus=ON` but no Common Files | Wrong Windows user / sandboxed terminal; confirm Common\Files path |
| Grader `terminals_scanned=0` | No heartbeat yet — start Scouter or GsignalX with `InpBusEnable` |
| Grades empty | No positive entry/harvest scores yet; open demo positions or wait for engine agreement |
| Trading BLOCKED | Algo Trading off, or investor password / expert trading disabled |
| Two terminals, no shared grades | Different Windows accounts, or Grader not started |

---

## 11. Post-deploy checklist (print / tick)

- [ ] Includes copied to every terminal in use  
- [ ] All five programs compiled (0 errors)  
- [ ] Algo Trading enabled  
- [ ] ProfitScouter Service started (`InpBusEnable=true`)  
- [ ] Grader Service started (one per PC/user)  
- [ ] GsignalX attached with bus + grades on (optional but recommended)  
- [ ] Common Files bus tree populated  
- [ ] `grades\latest.json` updating  
- [ ] Demo checklist in architecture doc completed before live  
