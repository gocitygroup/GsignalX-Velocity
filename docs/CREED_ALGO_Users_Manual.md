---
title: "CREED ALGO Users Manual"
subtitle: "Daily Session Trading · Scaling Program · Profit Scouting"
author: "Gocity Group — GSignalX Toolkit"
date: "2026"
---

# CREED ALGO Users Manual

**Daily Session Trading · Scaling Program · Profit Scouting**  
*For beginner and advanced traders — manual and automated workflows*

**Product umbrella:** CREED ALGO  
**Technical stack (MetaTrader 5):** GSignalX · ProfitScouter · Opportunity Grader · ProfitHarvest_Now  
**Publisher:** Gocity Group

> **Important:** Trading involves risk of loss. This manual describes software behaviour. It is not investment advice. Always practise on a demo account before live capital.

---

## How to use this manual

| If you are… | Start here |
|---|---|
| **New to CREED ALGO / MT5** | [Chapter 3 — Install & first run](#3-install--first-run) → [Chapter 5 — Beginner automated day](#5-beginner-automated-day) |
| **Trading a daily session** | [Chapter 4 — Daily Session trading](#4-daily-session-trading) |
| **Scaling across pairs** | [Chapter 7 — Scaling program](#7-scaling-program-multi-pair-swing-entries) |
| **Banking profit (scout)** | [Chapter 9 — Profit Scouting](#9-creed-algo-profit-scouting) |
| **Advanced / multi-terminal** | [Chapter 11 — Advanced reference](#11-advanced-reference) |

Callouts used in this guide:

- **Beginner** — do this first; safe defaults.
- **Advanced** — optional power settings; change only when you understand the effect.

---

## 1. Welcome to CREED ALGO

CREED ALGO is the trading umbrella for the Gocity **GSignalX** toolkit on MetaTrader 5. It combines:

1. **Signal-driven entries** — follow multi-engine trend direction on each chart you enable (PLAY).
2. **Profit scouting** — watch floating P/L and close positions when a money target is reached (default: one account-wide minimum).
3. **Opportunity grades** (optional) — rank setups across terminals; grades are **advisory only**.

### What CREED ALGO does

- Attaches to charts you choose; each chart trades **its own symbol**.
- Opens (or places pending) trades when PLAY is on and entry rules agree.
- Closes profit according to ProfitScouter (automated) or ProfitHarvest_Now (manual one-shot).
- After an account harvest closes everything, charts still on PLAY can **re-enter** if the signal still says buy or sell (march-after-flat).

### What CREED ALGO does not do

- Guarantee profit or remove market risk.
- Pyramid / add multiple lots on the **same** symbol ticket (one intended position per chart magic).
- Remotely force other terminals to open or close (grades do not execute trades).
- Replace your broker’s risk controls or your own money management.

### MT5 names vs CREED branding

| CREED ALGO name | What you see in MT5 Navigator |
|---|---|
| Signal / entry engine | `GsignalX_GocityGroup` (Expert) |
| Profit scouting (chart) | `ProfitScouter_DollarTarget` (Expert) |
| Profit scouting (24/7) | `ProfitScouter_Service` (Service) |
| Opportunity ranks | `ProfitOpportunity_Grader` (Service) |
| Manual take-profit sweep | `ProfitHarvest_Now` (Script) |

---

## 2. System map

```
  Watchlist charts          PLAY / STOP / HALT
         │                        │
         ▼                        ▼
   ┌─────────────┐         Scalping drill window
   │  GSignalX   │◄──────── (5–15 min after PLAY)
   │  entries    │
   └──────┬──────┘
          │ positions open
          ▼
   ┌─────────────┐     optional     ┌─────────────┐
   │ ProfitScout │◄────────────────┤   Grader    │
   │ ASAP / trail│   (advisory)    │  ranks only │
   └──────┬──────┘                 └─────────────┘
          │ close all at account min
          ▼
   Flat → GSignalX re-arms (march) if signal still active
```

| Component | Opens trades? | Closes trades? | Needs a chart? |
|---|---|---|---|
| GSignalX | Yes (when PLAY) | No (Scouter mode default; STOP/HALT never close) | Yes |
| ProfitScouter Service | No | Yes (money rules) | No |
| ProfitScouter EA | No | Yes | Yes (host chart) |
| Grader | No | No | No |
| ProfitHarvest_Now | No | Yes (one shot) | Drop on any chart |

**Beginner layout:** one ProfitScouter **Service** + Grader + GSignalX on each pair you want to trade.  
**Advanced layout:** same, plus bus grades on the panel; optional second terminal for research.

---

## 3. Install & first run

### 3.1 Deploy files

From the toolkit folder:

1. Run `deploy\Click-and-Run-Deploy.bat` (fresh) or `deploy\Clean-and-Deploy.bat` (upgrade).
2. Or PowerShell: `Deploy-GSignalX.ps1` with your terminal data path and `-Compile`.

Confirm steps are documented in `DEPLOYMENT_RUNBOOK.md` (gates G0–G7).

### 3.2 MetaTrader checklist

**Beginner — do these before any PLAY:**

1. **Tools → Options → Expert Advisors** — allow automated trading; allow DLL imports only if your broker/docs require it.
2. Toolbar **Algo Trading** button = **green / ON**.
3. **Navigator → Services** — Add / Start:
   - `ProfitScouter_Service` (`InpBusEnable = true` recommended)
   - `ProfitOpportunity_Grader` (one instance)
4. Open charts for your daily roster; attach `GsignalX_GocityGroup` on each.
5. On each EA: Common tab → **Allow Algo Trading**.
6. Run `deploy\Confirm-After-Start.bat` (or Confirm script Gate All).

### 3.3 First-run defaults that matter

| Area | Suggested first setting |
|---|---|
| GSignalX entry | Limit+Stop bracket, offsets **5** pips (range 4–20) |
| Drill | Enabled, **10** minutes |
| ProfitScouter | **Scalp ASAP** on; `InpAccTargetMoney` = your minimum take (e.g. 10 account currency) |
| Scope | All symbols (one Service instance) |

---

## 4. Daily Session trading

CREED ALGO is built to work cleanly inside a **defined daily window**, not “always on every hour.”

### 4.1 Broker session vs your hour filter

| Control | Default | Role |
|---|---|---|
| `InpUseSessions` | true | Obey broker market session calendar |
| `InpUseHourFilter` | false | Optional hard gate on server hours |
| `InpStartHour` / `InpEndHour` | 7 / 20 | Used when hour filter is ON |
| `InpFridayStop` / hour | true / 20 | No new FX entries late Friday |
| `InpBlockWeekend` | true | No Sat/Sun FX (crypto can be exempt) |

**Beginner daily session recipe**

1. Decide your session (example: London–NY overlap on your broker **server** clock).
2. Set `InpUseHourFilter = true`, `InpStartHour` / `InpEndHour` to that band.
3. Only press **PLAY** when you are watching the session; press **STOP** when done.
4. Keep Friday stop on for FX.

**Advanced:** leave hour filter off and rely on broker sessions + manual PLAY discipline; use swing band (below) for grade timing only.

### 4.2 Swing band (grades, not a hard block)

`InpSwingStartHour` / `InpSwingEndHour` (default **12–17** server time) mark a preferred window for **opportunity grades**. They do **not** by themselves block entries. For a hard block, use the hour filter or STOP.

### 4.3 Crypto vs FX

With `InpCryptoAllowWeekend = true`, detected crypto symbols skip FX Saturday/Sunday blocks and Friday flatten rules. Add odd broker symbol names to `InpCryptoExtraList` if needed.

### 4.4 When to PLAY and STOP

| Action | Effect |
|---|---|
| **PLAY** | New entries allowed; starts the **scalping drill** window (if enabled); linked Scouter resumes |
| **STOP** | Pauses new entries; pendings cancelled. **Never closes a trade** — the Scouter keeps managing exits |
| **HALT** | One-click full stop: pauses entries **and** the linked Scouter harvest. **Never closes a trade** |
| **FOLLOW / WAIT** | Fleet fill new direction vs wait until opposite magic exposure is clear |
| **SPREAD / IGN** | Respect `InpMaxSpreadPt` (default) vs ignore the entry spread gate for instant signal fills |

**SPREAD / IGN** is per chart and survives restart (`GSX_SPREADIGN_{Symbol}_{Magic}`). Default is **SPREAD** (limit on). Press **IGN** when you want the signal filled even if the spread is above the limit — fills may be worse; press **SPREAD** again to restore the gate. Turning IGN on while PLAY re-arms evaluation so a chart stuck on `waiting: spread` can enter immediately. Exit/scouting logic is unchanged.

---

## 5. Beginner automated day

Follow this once on **demo**:

1. Start **ProfitScouter_Service** (ASAP account target set to a small demo amount, e.g. 5–10).
2. Start **ProfitOpportunity_Grader**.
3. Attach **GSignalX** on 1–3 liquid pairs; Algo Trading ON.
4. At session open, press **PLAY** on each chart you want live.
5. Watch panel: Status RUNNING, Drill countdown, Working pendings or Position.
6. When combined floating profit hits the Scouter account target → the target is **banked from the winners only** (biggest green tickets first, minimal set); losers stay open.
7. If PLAY is still on and the signal still agrees → chart may **re-open** (march-after-flat / drill).
8. At session end → **STOP** on each chart (or leave STOP and let Friday/weekend rules protect FX).

You have just run the full CREED loop: **signal → entry → scout → harvest → optional re-entry**.

---

## 6. Manual trading with CREED tools

You can use CREED as a **decision aid** without full automation.

### 6.1 Discretionary entries

1. Attach GSignalX with Algo Trading allowed **or** use it mainly for panel bias.
2. Read **Last signal**, engine agreement, and **Opp grades**.
3. Place your own market/pending orders if you prefer full manual control.
4. Keep ProfitScouter running so floating profits are still scouted, **or** harvest yourself.

### 6.2 Manual profit take — ProfitHarvest_Now

1. Drag script `ProfitHarvest_Now` onto any chart.
2. Set account target (default focuses on **account total**).
3. Confirm; script closes what already meets the target and exits.
4. No trailing and no background loop — ideal for “bank it now.”

### 6.3 HALT vs STOP (manual discipline)

- Use **STOP** to pause new entries on one chart while the Scouter keeps managing exits.
- Use **HALT** when you want the whole operation paused (entries + harvesting) — nothing is closed, open trades are simply left as-is.

---

## 7. Scaling program (multi-pair swing entries)

### 7.1 What “scaling” means in CREED ALGO

Scaling here means **growing or shrinking how many pairs are live**, and **how large each position is**, during the daily session — aligned with swing-quality hours and your account profit target.

It does **not** mean pyramiding (adding ticket after ticket on the same pair). GSignalX keeps **one intended position per symbol/magic**.

### 7.2 Build a daily roster

1. Choose a short list of liquid pairs (example: majors + one metal).
2. Open one chart per pair; attach GSignalX with the **same magic** only if you intend one strategy family (or different magics to separate strategies).
3. Use **one** ProfitScouter instance with scope **All symbols** (or a symbol list that matches the roster).

### 7.3 Position sizing

| Mode | Input | Use when |
|---|---|---|
| Fixed lot | `InpRiskMode = Fixed lot`, `InpFixedLot` | Beginners; constant size |
| Percent risk | `InpRiskMode = % of balance`, `InpRiskPct`, ATR stop ON | Scaling risk with account |
| Cap | `InpMaxLot` | Hard ceiling per trade |

**Beginner:** fixed small lot.  
**Advanced:** 0.5–1% risk per trade with ATR stop; raise PLAY pair count only when grades/session are strong.

### 7.4 Scale the program with the session

| Session quality | Action |
|---|---|
| Strong (liquid, swing band, high grades) | PLAY more roster pairs; normal risk % |
| Average | PLAY core pairs only |
| Poor / news / late Friday | STOP; reduce or zero new risk |
| After ASAP harvest | Let march re-enter only on pairs still PLAY + valid signal |

### 7.5 Account target vs open risk

ProfitScouter’s **single account minimum** (`InpAccTargetMoney`) closes **all** floating positions when hit. Plan so that:

- Sum of expected scalp takes ≥ your target, and  
- Number of PLAY pairs × risk per pair stays within your daily loss tolerance (set `InpAccMaxLossMoney` if you want an emergency flatten).

---

## 8. Order entry rules

### 8.1 Entry modes

| Mode | Behaviour |
|---|---|
| **Market** | Immediate fill |
| **Limit** | Pullback from **signal bar open** |
| **Stop** | Breakout from signal bar open |
| **Both** (default) | Limit + Stop bracket (OCO: one fill cancels the other) |

Offsets: default **5** (typical scalp **4–6**); absolute clamp **4–20** (pips or points per `InpOffsetUnit`).  
`InpPendFromSignalOpen = true` anchors levels to the active signal opening bar, then adjusts for broker minimum distance.

### 8.2 Scalping drill

| Input | Default | Meaning |
|---|---|---|
| `InpDrillEnable` | true | Drill on PLAY |
| `InpDrillMinutes` | 10 | Window length (5–15) |
| `InpDrillFollowActive` | true | Follow active direction under bot filters |
| `InpDrillAllowReentry` | true | Re-enter while drill / flat rules allow |
| `InpDrillMarchAfterFlat` | true | After harvest flat, one re-arm if signal still valid |

After the window expires, behaviour returns to flip-based entries until the next PLAY.

### 8.3 Signal filters (custom bot rules)

Entries respect:

- Enabled engines (PP SuperTrend, ATR SuperTrend, SuperBollingerTrend)
- Simple vs Advanced agreement (`InpMinAgree`)
- Optional MA filter
- Allow Long / Allow Short
- Spread, sessions, hour filter, PLAY state

---

## 9. CREED ALGO Profit Scouting

Profit scouting is the **exit brain**. It does not open trades. It can run **standalone** (ProfitScouter chart EA only) or beside GSignalX.

### 9.0 Chart START / STOP (standalone)

On `ProfitScouter_DollarTarget`:

- **START** — arm harvest (closes when targets hit).
- **STOP** — watch-only; no closes until you START again.
- Panel line shows `Scout: START|STOP`. Independent of GSignalX PLAY.
- Matching Service `InpInstanceID` + `InpRespectChartRunState` follows the same arm state.

### 9.1 Scalp ASAP (default — recommended for daily sessions)

| Setting | Typical value |
|---|---|
| `InpScalpAsapAccountOnly` | true |
| `InpAccTargetEnable` | true |
| `InpAccTargetMoney` | Your minimum take (e.g. 10) |
| Pos / Sym targets & trails | off |
| `InpWindowEnable` | false (no age gate) |
| `InpCheckIntervalMs` | 500 |

When **total floating P/L** of monitored positions ≥ target → **close everything**. Fast, simple, session-friendly.

### 9.2 Automated vs manual scout

| Method | Best for |
|---|---|
| **ProfitScouter_Service** | Unattended daily / VPS (honors chart START/STOP if same Instance ID) |
| **ProfitScouter_DollarTarget** EA | Visual dashboard + **START/STOP** on a host chart |
| **ProfitHarvest_Now** | Manual “take it now” |

Run **one** scouter scope over the same positions (avoid two instances racing).

### 9.3 After harvest — keep the set marching

With GSignalX PLAY + march-after-flat:

1. Scouter closes all at the account min.  
2. Chart goes flat.  
3. If the signal still says buy or sell → EA re-enters that pair.  
4. Open positions again match the active direction set.

### 9.4 Advanced — layered trail harvest

Set `InpScalpAsapAccountOnly = false` and enable per-position / per-pair / account trails if you want give-back logic and age windows (classic 30–60 minute trail band). See `README_ProfitScouter.md`.

---

## 10. Safety & risk

**Beginner checklist**

- [ ] Demo first until you trust PLAY / harvest / STOP behaviour  
- [ ] Algo Trading ON only when you intend automation  
- [ ] STOP when you leave the screen  
- [ ] Account target sized for your account (not vanity numbers)  
- [ ] One Scouter instance for “All symbols”  

**Advanced safeguards**

- `InpAccMaxLossMoney` — loss-guard threshold; used only when `InpAccLossGuardEnable = true` (default **off** — losers are never auto-closed)  
- `InpMaxSpreadPt` — skip entries in wide spreads (chart **IGN** button can bypass this per symbol)  
- Separate magics per strategy family  

**Honest limits**

- Slippage, requotes, and broker stops can change fills.  
- Grades are scores, not orders.  
- Weekend / Friday rules protect FX; verify crypto detection for your symbols.

---

## 11. Advanced reference

### 11.1 GSignalX input groups (cheat sheet)

| Group | Purpose |
|---|---|
| Mode & routing | Simple/Advanced, triggers, start next vs current |
| Engines | PP / ATR ST / SuperBollinger parameters |
| Trade management | Long/short, reverse, ATR SL/TP, trail |
| Entry order type | Market / Limit / Stop / Both; offsets 4–20; signal-open anchor |
| Scalping drill | Window, re-entry, follow-active, march-after-flat |
| Money management | Fixed lot or % risk, max lot |
| Sessions & weekend | Sessions, hour filter, Friday, crypto |
| Execution | Magic, slippage, max spread, ignore-spread default, lookback |
| Panel & bus | PLAY / SPREAD|IGN buttons, grades, notifications |

### 11.2 Opportunity grades (bus)

Published under Common Files: `GSignalX\bus\v1\`.  
Grader writes `grades/latest.json`. Panel **Opp grades** summarises top ideas.  
Scoring rewards agreement, session, swing window, spread health — **advisory**.

### 11.3 Verify after deploy

1. Files compiled (0 errors).  
2. Services running.  
3. GSignalX smiley / panel visible; PLAY works.  
4. Bus heartbeats / signal JSON when bus enabled.  
5. Scouter closes at target on demo.  
6. After close, PLAY chart re-enters if signal still active.

Full gates: `DEPLOYMENT_RUNBOOK.md`.

### 11.4 Troubleshooting

| Symptom | Check |
|---|---|
| No entries | PLAY? Algo Trading? Hour/session/spread (try **IGN**)? Drill expired waiting for flip? |
| Limit/Stop rejected | Offset vs stops level; panel Last action; try 5–6 pips; filling RETURN |
| No harvest | Scouter **START**? Algo Trading? Scope/magic filter? ASAP target too high? |
| Scout not closing | Panel shows `Scout: STOP` — press **START** |
| Double closes | Two Scouters on same positions — keep one |
| Grades empty | Bus enable + Grader started + Common Files path |

---

## 12. Glossary

| Term | Meaning |
|---|---|
| **CREED ALGO** | Product umbrella for this GSignalX + ProfitScouter toolkit |
| **PLAY / STOP** | Per-chart arming of new entries |
| **SPREAD / IGN** | Per-chart toggle: enforce vs bypass entry max-spread gate |
| **Drill** | Timed window after PLAY for active-signal entries |
| **March-after-flat** | Re-arm entry after Scouter (or close) flats the chart |
| **ASAP account target** | Bank the target from winners only when total floating P/L hits one minimum |
| **Scaling program** | Multi-pair roster + risk sizing; not pyramiding |
| **Swing window** | Hour band that boosts opportunity grades (default 12–17) |
| **Magic** | EA order ID used to own positions/orders |
| **FILE_COMMON bus** | Shared JSON fabric across terminals on one Windows user |
| **OCO bracket** | Limit + Stop; one fill cancels the other |

---

## Appendix A — Recommended daily session template

**FX majors, server roughly aligned to London–NY**

| Item | Value |
|---|---|
| Hour filter | ON · Start 8 · End 17 (adjust to your broker server) |
| Swing grades | 12–17 |
| Drill | 10 minutes |
| Entry | Both · Limit 5 · Stop 5 |
| Risk | Fixed 0.01–0.10 lot on demo; then % risk live |
| Scouter | ASAP · Acc target sized to account · Interval 500 ms |
| End of day | STOP all charts; optional Friday flatten |

---

## Appendix B — Related documents

| Document | Topic |
|---|---|
| `README.md` | Toolkit overview |
| `README_ProfitScouter.md` | Harvest presets in depth |
| `DEPLOYMENT.md` | Install & verify |
| `DEPLOYMENT_RUNBOOK.md` | Gated go-live with feedback |
| `ARCHITECTURE_CONNECTOR_BUS.md` | Bus protocol & scoring |

---

## Appendix C — Version notes

Manual aligned with toolkit behaviour as of **GSignalX v1.16** / **ProfitScouter v1.14** (scalping drill, signal-open limit/stop defaults, Scalp ASAP account target, chart START/STOP scout, winners-only minimal threshold harvest, opt-in loss guard, non-closing STOP/HALT).

---

*© Gocity Group — CREED ALGO / GSignalX. For research and educational use with MetaTrader 5. Trade responsibly.*
