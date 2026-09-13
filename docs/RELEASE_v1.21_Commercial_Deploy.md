# GSignalX v1.21 — Commercial Production Release & Deployment

**Date:** 2026-09-13  
**Product:** GSignalX entry engine (`GsignalX_GocityGroup.mq5`)  
**Version:** **1.20 → 1.21**  
**Companion exits:** ProfitScouter **v1.21** (unchanged this release)  
**Audience:** Commercial / desk deploy (demo sign-off required before live)

---

## 1. What ships in v1.21

| Feature | Trader / investor value | Persistence |
|---|---|---|
| **AUTOLOT / FIXED** chart toggle | Risk% sizing vs fixed lot without re-attaching inputs | `GSX_AUTOLOT_{Symbol}_{Magic}` |
| **EQ OFF → 5% → 10% → 20%** | Account equity drawdown guide; blocks new entries | `GSX_EQGUARD_{Symbol}_{Magic}` |
| **Compact / Full panel** (`InpPanelDensity`) | Investor outcome strip vs trader engine detail | Input (chart density toggle deferred) |
| **Outcome strip** | Status wait reason, Scout ON/OFF, Account DD, Session win%, Fleet P/L, Next lot/risk, open R/SL pips | Live (throttled ~250ms) |
| **LotSizing / ChartPanel includes** | DRY risk + UI modules | N/A |
| Panel paint-order fix | Data rows visible above panel background | N/A |

**Unchanged (still required for commercial desk):** PLAY/STOP/HALT, FOLLOW/WAIT, SPREAD/IGN, M5 preliminary TF, Scouter-owned exits, fleet fill, scalping drill.

---

## 2. Production test plan (commercial gate)

Run on a **demo** account that mirrors live symbol suffix, leverage, and raw-spread costs. Do not skip to live until **G1–G7** pass.

### Automated gates (this PC)

```powershell
# From repo root MQ5\files
powershell -ExecutionPolicy Bypass -File .\deploy\Deploy-GSignalX.ps1 `
  -TerminalDataPath "$env:APPDATA\MetaQuotes\Terminal\<HASH>" `
  -Compile `
  -MetaEditorPath "C:\Program Files\MetaTrader 5 IC Markets Global\MetaEditor64.exe"

powershell -ExecutionPolicy Bypass -File .\deploy\Confirm-GSignalX.ps1 `
  -TerminalDataPath "$env:APPDATA\MetaQuotes\Terminal\<HASH>" `
  -Gate All -WriteFeedback
```

Upgrade path (wipe old toolkit then deploy):

```text
deploy\Clean-and-Deploy.bat
```

| Gate | Pass criteria |
|---|---|
| **G1 Files** | Includes include `LotSizing.mqh` + `ChartPanel.mqh`; Experts/Services present |
| **G2 Compile** | All `.ex5` exist; compile logs `0 errors, 0 warnings` |
| **G3 Start** | Algo Trading ON; Scouter + Grader Services running; GSignalX attached on M5 |
| **G4 Bus** | `Common\Files\GSignalX\bus\v1\` has heartbeats / signals after ~60s |
| **G5 Grades** | `grades\latest.json` updates |
| **G6 UI smoke** | Compact panel shows Status/Scout/DD/Next risk; buttons clickable; data not blank |
| **G7 Commercial checklist** | Section 3 below all ticked on demo |

### Manual commercial checklist (demo, 1 session)

- [ ] Panel shows **GsignalX** + Compact/Full hint; **row data visible** (not empty dark box)
- [ ] **AUTOLOT** → Experts log `[LOT_CALC] … mode=AUTOLOT`; **FIXED** uses `InpFixedLot`
- [ ] **EQ** cycles OFF / 5 / 10 / 20; with floating DD ≥ threshold, Status shows wait / no new entries
- [ ] **SPREAD / IGN** still independent of AUTOLOT/EQ
- [ ] **PLAY / HALT** toggles Scout ON/OFF on panel; HALT does **not** close trades
- [ ] Flat: Next risk lot updates when toggling AUTOLOT/FIXED
- [ ] In position: R / SL pips / open $ update within ~1s
- [ ] Drag title: panel moves; no arrow flicker; position persists after reattach
- [ ] One fill on major (e.g. EURUSD M5) + Scouter harvest path observed (or ASAP floor documented)
- [ ] XAUUSD or one metals symbol: lot calc does not crash (fallback to fixed if ticks bad)
- [ ] Daily max positions / equity guard inputs `0` = off; non-zero blocks as designed

**Sign-off line (copy to feedback):**

```text
COMMERCIAL SIGN-OFF v1.21 | Demo | Operator: ____ | Date: ____ | PASS / FAIL
Notes:
```

---

## 3. Deployment text (customer / desk)

### Short release note (paste into chat / email)

```text
GSignalX v1.21 — commercial desk update

Upgrade the entry EA to v1.21 (ProfitScouter remains v1.21).

New on-chart controls:
• AUTOLOT / FIXED — risk% lot sizing vs fixed lot (persisted per symbol)
• EQ OFF / 5% / 10% / 20% — account equity drawdown guard for new entries
• Compact panel (default) — investor outcome strip; set Full for engine diagnosis

Recommended desk defaults: M5 · Compact · AUTOLOT · EQ 10% · SPREAD on · Scouter exits.

Deploy: run deploy\Clean-and-Deploy.bat (or Click-and-Run-Deploy.bat), enable Algo Trading,
start ProfitScouter_Service + ProfitOpportunity_Grader, re-attach GsignalX on each chart,
then run deploy\Confirm-After-Start.bat.

Demo sign-off required before live capital.
```

### Operator steps (1 page)

1. Close or remove old GSignalX charts (optional but clean).  
2. Run **`deploy\Clean-and-Deploy.bat`** (upgrade) or **`Click-and-Run-Deploy.bat`** (overwrite).  
3. MT5 → **Algo Trading ON**.  
4. Navigator → Services → start **ProfitScouter_Service** + **ProfitOpportunity_Grader**.  
5. Attach **GsignalX v1.21** on **M5** watchlist; load preset if using EUR100 raw-spread.  
6. Confirm panel data rows visible; press **PLAY** on charts that should trade.  
7. Run **`deploy\Confirm-After-Start.bat`** — Bus + Grades should PASS.  
8. Complete Section 2 commercial checklist on demo → sign off → then live.

### Rollback

- Keep prior `.ex5` / repo tag of v1.20.  
- Re-deploy previous tree with `Deploy-GSignalX.ps1` or restore from backup.  
- Chart GVs (`GSX_AUTOLOT_*`, `GSX_EQGUARD_*`) can remain; they are ignored by older builds without those buttons.

---

## 4. Recommended commercial defaults

| Setting | Value | Why |
|---|---|---|
| Timeframe | **M5** | Drill + Scouter adverse alignment |
| `InpPanelDensity` | **Compact** | Investor glance on watchlist |
| Chart AUTOLOT | **ON** | Risk-sized entries |
| Chart EQ | **10%** | Account circuit breaker |
| Chart SPREAD | **ON** | Avoid news/rollover blowouts |
| `InpExitMode` | **Scouter** | Entry sanctity |
| ASAP floor | Per account size (see EUR100 preset) | Winners-only harvest |

---

## 5. Files touched this release

| Action | Path |
|---|---|
| MODIFY | `GsignalX_GocityGroup.mq5` → `#property version "1.21"` |
| CREATE | `Include/GSignalX/LotSizing.mqh`, `Include/GSignalX/ChartPanel.mqh` (already in tree) |
| MODIFY | `deploy/Confirm-GSignalX.ps1` — Files gate includes LotSizing + ChartPanel |
| CREATE | `docs/RELEASE_v1.21_Commercial_Deploy.md` (this file) |
| MODIFY | Manual / README version chips where referenced |

---

## 6. Next (post v1.21)

- Optional chart Compact/Full toggle with GV  
- Bus fields for lot / risk_pct for graders  
- Live capital playbook with broker-specific max spread tables
