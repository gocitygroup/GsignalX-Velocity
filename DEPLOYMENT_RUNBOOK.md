# GSignalX — Guided Deployment Runbook (with confirmation + feedback)

Use this after [DEPLOYMENT.md](DEPLOYMENT.md). Work **one gate at a time**. Do not skip ahead if a gate fails.

**Not technical?** Start with [docs/WINDOWS_DEPLOY_SIMPLE.md](docs/WINDOWS_DEPLOY_SIMPLE.md) (ZIP → double-click → MT5 → problems/fixes). Come back here only if you want the gated PASS/FAIL feedback blocks.

**How feedback works**

1. You complete a step (or we run the confirm script).  
2. You fill the gate result: `PASS` / `FAIL` / `BLOCKED` + notes.  
3. Paste that block back in chat (or save under `deploy/feedback/`).  
4. Only then proceed to the next gate — or we fix the failure together.

Session feedback file (copy the template):  
`deploy/feedback/FEEDBACK_YYYY-MM-DD.md`

---

## Click-and-run (Windows)

From File Explorer, open the `deploy\` folder and double-click:

| File | What it does |
|---|---|
| **`Clean-and-Deploy.bat`** | **Upgrade path:** wipe old toolkit + bus, then deploy/compile/confirm |
| **`Clean-Old-Version.bat`** | Wipe old toolkit + bus only |
| **`Click-and-Run-Deploy.bat`** | List terminals → copy to **all** → compile → confirm Files/Compile/Bus/Grades + write feedback |
| **`Confirm-After-Start.bat`** | Re-check Bus + Grades after you start Services in MT5 |
| **`List-Terminals.bat`** | Only list MT5 data folders |

Window stays open (`pause`) so you can read results. Feedback lands in `deploy\feedback\CONFIRM_*.md`.

If MetaEditor is not found, edit `Click-and-Run-Deploy.bat` or `Clean-and-Deploy.bat` and set:

`set METAEDITOR=C:\Program Files\MetaTrader 5 IC Markets Global\MetaEditor64.exe`

(Replace with the real path to **your** broker’s `MetaEditor64.exe` — Search in Windows Start if unsure.)

**MT5 still needs a short manual step after the .bat** (scripts cannot enable Algo Trading for you):

1. Algo Trading **ON** (toolbar green)  
2. Start Services: `GsignalX_Service`, `ProfitScouter_Service`, `ProfitOpportunity_Grader`  
3. Attach `GsignalX_Multisymbol_Dashboard` (same magic)  
4. Run `Confirm-After-Start.bat`  

If the black window shows an error, match it in [WINDOWS_DEPLOY_SIMPLE.md § Problems and fixes](docs/WINDOWS_DEPLOY_SIMPLE.md#problems-and-fixes).

---

## Gate map

| Gate | Goal | Auto-check |
|---|---|---|
| **G0** | Scope + which terminal(s) | `-ListTerminals` |
| **G1** | Files copied into MT5 | `Confirm-GSignalX.ps1 -Gate Files` |
| **G2** | Compile clean (0 errors) | `Confirm-GSignalX.ps1 -Gate Compile` |
| **G3** | Services / EA started | Manual + Experts log |
| **G4** | Bus files on Common Files | `Confirm-GSignalX.ps1 -Gate Bus` |
| **G5** | Grades updating | `Confirm-GSignalX.ps1 -Gate Grades` |
| **G6** | Multi-terminal (optional) | Manual + Bus/Grades |
| **G7** | Sign-off | Feedback summary |

---

## G0 — Scope confirmation

**Do**

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\Deploy-GSignalX.ps1 -ListTerminals
```

In MT5: **File → Open Data Folder** and note the `<HASH>` path.

**Decide**

- Demo account only? (recommended)  
- One terminal or all on this PC?  
- MetaEditor path (if not auto-detected)

**Feedback block (paste)**

```
GATE: G0
RESULT: PASS | FAIL | BLOCKED
TERMINALS:
  - <HASH or full path>
DEMO: yes/no
SCOPE: one | all
METAEDITOR: <path or auto>
NOTES:
```

---

## G1 — Deploy files

**Do** (example for one terminal)

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\Deploy-GSignalX.ps1 `
  -TerminalDataPath "$env:APPDATA\MetaQuotes\Terminal\<HASH>"
```

Or all terminals:

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\Deploy-GSignalX.ps1 -AllTerminals
```

**Confirm**

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\Confirm-GSignalX.ps1 `
  -TerminalDataPath "$env:APPDATA\MetaQuotes\Terminal\<HASH>" -Gate Files
```

**Feedback block**

```
GATE: G1
RESULT: PASS | FAIL | BLOCKED
CONFIRM_SCRIPT: (paste last lines)
NOTES:
```

---

## G2 — Compile

**Do**

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\Deploy-GSignalX.ps1 `
  -TerminalDataPath "$env:APPDATA\MetaQuotes\Terminal\<HASH>" -Compile
```

**Confirm**

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\Confirm-GSignalX.ps1 `
  -TerminalDataPath "$env:APPDATA\MetaQuotes\Terminal\<HASH>" -Gate Compile
```

Expect five programs with `.ex5` present and last compile logs showing `0 errors`.

**Feedback block**

```
GATE: G2
RESULT: PASS | FAIL | BLOCKED
RESULTS:
  ProfitScouter_Service: 0 errors?
  ProfitScouter_DollarTarget: 0 errors?
  ProfitOpportunity_Grader: 0 errors?
  GsignalX_GocityGroup: 0 errors?
  GsignalX_Service: 0 errors?
  GsignalX_Multisymbol_Dashboard: 0 errors?
  ProfitHarvest_Now: 0 errors?
  Hosts #property version "2.00" on six primary programs?
NOTES:
```

---

## G3 — Start runtime

**Do (on demo) — Velocity 2.00 topology**

1. Enable **Algo Trading** (green).  
2. If Telegram enabled: Tools → Options → Expert Advisors → allow WebRequest for `https://api.telegram.org`.  
3. Services → Add/Start `GsignalX_Service` (shared magic; seed roster).  
4. Services → Add/Start `ProfitScouter_Service` with `InpBusEnable=true`.  
5. Services → Add/Start `ProfitOpportunity_Grader` (one instance).  
6. Attach `GsignalX_Multisymbol_Dashboard` (same magic; PropRisk / Telegram inputs as needed).  
7. Optional: attach `GsignalX_GocityGroup` on M5 for UI/strip; keep `InpChartEntriesWhenService=false`.  
8. Refresh Navigator if programs missing.

**ProfitScouter production filter (Topology A)**

- Set `InpUseMagicFilter=true` and `InpMagicNumber` to the shared desk magic.  
- Default is filter OFF + `PS_SCOPE_ALL` (backward compatible) — Experts will WARN on init; foreign magics can be harvested.  
- Closer claim freshness is 5s (`GSX_SCOUT_CLOSER_FRESH_SEC`); stale Service → chart Scouter resumes auto-harvest (avoid dual hosts thrashing).

**Close-trigger Telegram (V2.15)**

- Desk deal-watch CLOSE messages include `| reason=TAG` (e.g. `ACC-TARGET`, `ATR-TRAIL`, `ADVERSE-BAR`, `BROKER-SL`, `OVERFILL`, `BANK`).  
- Scouter emits the tag; Desk/Chart consumes it (Service does **not** send OPEN/CLOSE).  
- Audit trail: `%APPDATA%\MetaQuotes\Terminal\Common\Files\GSignalX\bus\v1\terminals\{tid}\closes\events.jsonl`

**Settings Telegram (V2.16)**

- On Desk load (TG enabled): `[SETTINGS] … LOAD magic=… RUN=… scout[…]` with effective input/UI state.  
- Prop-critical clicks (PLAY/STOP/HALT/FOLLOW/AUTOLOT/EQ/PROP_CLEAR/roster ADD|REM|…) enqueue `[SETTINGS] CLICK … | impact`.  
- Scouter START/CASH/TRAIL/… write pending; Desk drains on timer (Scouter never sends HTTP).  
- PAGE/carousel/practice never notify. SETTINGS share the 1-msg/cycle queue with deals — no click-path WebRequest.  
- Audit: `…\settings\events.jsonl`

**Confirm (manual)**

- Experts log: GSignalX Service OWN / roster; Scouter `started ... bus=ON`; Grader `started`  
- Dashboard: PROP/TG strip visible; roster rows update  
- Chart (if attached): GsignalX smiley + optional roster strip  
- On close: Telegram `[CLOSE] … | reason=…` matches Experts `ProfitScouter [TAG]` (or `BROKER-SL` for catastrophe stops)  
- On attach/click: Telegram `[SETTINGS] LOAD` / `CLICK STOP|HALT|…` with impact text 

**Feedback block**

```
GATE: G3
RESULT: PASS | FAIL | BLOCKED
GSX_SERVICE: running yes/no | OWN=1 yes/no
SCOUTER: running yes/no | bus=ON yes/no
GRADER: running yes/no
DASHBOARD: attached yes/no | PROP strip yes/no
GSIGNALX_CHART: attached yes/no (optional)
ALGO_TRADING: on/off
WEBREQUEST_TG: n/a | allowed yes/no
NOTES: (paste 2-3 Experts lines if FAIL)
```
---

## G4 — Bus on disk

**Confirm**

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\Confirm-GSignalX.ps1 -Gate Bus
```

Or open:

`%APPDATA%\MetaQuotes\Terminal\Common\Files\GSignalX\bus\v1\`

Expect `_index.txt`, `heartbeat.json`, and after GsignalX a `signals\` entry.

**Feedback block**

```
GATE: G4
RESULT: PASS | FAIL | BLOCKED
INDEX: yes/no
HEARTBEAT_AGE_SEC: <n or unknown>
SIGNAL_FILES: <count>
SCOUTER_SNAPSHOT: yes/no
NOTES:
```

---

## G5 — Grades confirmation

**Confirm**

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\Confirm-GSignalX.ps1 -Gate Grades
```

Expect `grades\latest.json` with `version:1` and recent `ts`. Empty `entries`/`harvests` arrays can still be PASS if the file is fresh (no scorable opportunity yet).

**Feedback block**

```
GATE: G5
RESULT: PASS | FAIL | BLOCKED
GRADES_FILE: yes/no
TS_AGE_SEC: <n>
ENTRIES: <count>
HARVESTS: <count>
PANEL_LINE: (optional paste)
NOTES:
```

---

## G6 — Second terminal (optional)

**Do**

1. Deploy+compile on second HASH (or `-AllTerminals`).  
2. Start Scouter (and optionally GsignalX) there with bus on.  
3. Keep **one** Grader on the PC.  
4. Re-run `-Gate Bus` / `-Gate Grades`.

**Feedback block**

```
GATE: G6
RESULT: PASS | FAIL | BLOCKED | SKIPPED
TERMINAL_B: <HASH>
BOTH_IN_INDEX: yes/no
GRADES_SEE_BOTH: yes/no
NOTES:
```

---

## G7 — Sign-off

**Feedback block**

```
GATE: G7
RESULT: PASS | FAIL
OVERALL: ready for demo ops | needs fixes | ready for limited live
BLOCKERS:
WHAT_WORKED:
WHAT_TO_IMPROVE_NEXT:
  - soft command inbox (phase 2)
  - other:
OPERATOR:
DATE:
```

---

## Suggested chat cadence with the agent

1. You: `Starting G0` + paste G0 feedback.  
2. Agent: confirms or adjusts plan → tells you exact G1 command.  
3. Repeat through G7.  
4. On FAIL: agent proposes one fix; you re-run that gate only.

Do not batch all gates in one message unless everything already PASSed.

---

## Quick commands cheat sheet

```powershell
# From repo: d:\GocityGroup\GSignalX\TradingBot\MQ5\files

.\deploy\Deploy-GSignalX.ps1 -ListTerminals
.\deploy\Deploy-GSignalX.ps1 -TerminalDataPath "<DATA>" -Compile
.\deploy\Confirm-GSignalX.ps1 -TerminalDataPath "<DATA>" -Gate All -WriteFeedback
```

`-WriteFeedback` appends a timestamped report under `deploy/feedback/`.
