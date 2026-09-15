# Gsignalx Velocity 2.00 — Prop Desk Production Release & Deployment

**Date:** 2026-09-14  
**Product:** Gsignalx Velocity (Gocity Group)  
**Version:** **hosts → 2.00** (umbrella over Service / Trade Center / Telegram / PropRisk / Scouter adverse gates)  
**Bus schema:** still **`version: 1`** (`GSignalX/bus/v1`) — do not mix with a protocol bump  
**Audience:** Prop / small-fund operators — demo sign-off required before live challenge or live capital

Feature provenance: [PLAN_V1.23](PLAN_V1.23_Multisymbol_Signal_Service.md), [PLAN_V1.24](PLAN_V1.24_Multisymbol_Dashboard_UI.md), [PLAN_V1.25](PLAN_V1.25_Prop_Firm_Trade_Center.md), [PLAN_V1.26](PLAN_V1.26_Trade_Center_Categories_Events.md), [PLAN_V1.27](PLAN_V1.27_Telegram_Dual_Host.md), Scouter adverse gates (prior v1.22). Historical commercial cut: [RELEASE_v1.21](RELEASE_v1.21_Commercial_Deploy.md).

**Non-tech Windows install (ZIP / double-click / error table):** [WINDOWS_DEPLOY_SIMPLE.md](WINDOWS_DEPLOY_SIMPLE.md)

---

## 1. What ships in Velocity 2.00

| Capability | Operator value | Owner |
|---|---|---|
| Chart entry EA 2.00 | Engines, drill, fleet, AUTOLOT/EQ/Compact, roster strip | `GsignalX_GocityGroup` |
| Multisymbol Service 2.00 | Chart-free roster scan + fleet fill; `OWN` GV | `GsignalX_Service` |
| Trade Center 2.00 / v1.26 | Categories FX/CMD/CRYPTO, START/STOP/SUSPEND, session clock, hybrid events TRADE/SKIP + TG `[EVENT]`, PROP/TG strip | `GsignalX_Multisymbol_Dashboard` |
| Telegram notifier | OPEN/CLOSE/MODIFY + DAILY/WEEKLY (winRate/DD) + START/STOP + WARN/ERROR + `[PROP]`/`[EVENT]`; Service+Dashboard+Chart; VERIFY UI | `TelegramNotifier.mqh` |
| Prop soft locks | Daily loss $/%, equity DD, max trades/day, consistency, Friday, news CSV → sticky STOP | `PropRisk.mqh` |
| Scouter 2.00 | Winners-only ASAP floor; adverse-bar Auto (min age + once-green) | DollarTarget / Service |
| Grader 2.00 | Ranks entry + harvest ops across terminals | `ProfitOpportunity_Grader` |

**Unchanged invariants:** `InpExitMode = Scouter` (default) → entry hosts never reverse-close; PLAY/STOP/HALT never close; Prop breach soft-STOP only; Scouter owns profit and adverse exits.

---

## 2. Recommended production topology (one magic)

Use **one** `InpMagic` across Service, charts, Dashboard, and Scouter.

```text
+---------------------+     FILE_COMMON bus v1      +----------------------+
| GsignalX_Service    |---- signals / heartbeats -->| ProfitOpportunity_   |
| OWN=1, roster CSV   |                             | Grader               |
+----------+----------+                             +----------------------+
           | live roster + SEQ GV
           v
+---------------------+     soft STOP (RUN=0)       +----------------------+
| Multisymbol         |<--- PropRisk / operator ----| ProfitScouter_       |
| Dashboard           |     PLAY resumes            | Service (exits)      |
| PROP + Telegram     |                             +----------------------+
+---------------------+
           |
           v optional M5 charts (UI / strip; InpChartEntriesWhenService=false)
+---------------------+
| GsignalX chart EAs  |
+---------------------+
```

| Role | Attach | Notes |
|---|---|---|
| Entries | **Service** | Seed or live roster; Scouter closes |
| Desk UI | **Dashboard** one chart | Categories, START/STOP/SUSPEND, events, fleet, PROP/TG |
| Chart UI | Optional M5 charts | Defer entries while Service owns magic |
| Exits | **ProfitScouter_Service** (or DollarTarget) | ASAP $5 floor; adverse M5 |
| Grades | **Grader** | After bus heartbeats |

---

## 3. Best-use playbook (fund desk)

**Best use case:** London–NY **FX + metals** book on one magic. Crypto stays on the roster but **SUSPENDed** until you deliberately trade it. Event mode **SKIP** for high-impact FX news; PropRisk soft locks match the challenge.

**Practice live (micro):** For **$20 / $50 / $100** (or €) on **Raw or Standard**, load matching `deploy/presets/GSignalX_Service_Practice_*` + `ProfitScouter_Practice_*`, restart Services, then use Trade Center **20/50/100 · RAW/STD · SCALP/DAY/SWING** for coach tips (fleet/cat soft-apply only). Full maths: [PRACTICE_LIVE_SIM_20_50_100.md](PRACTICE_LIVE_SIM_20_50_100.md).

1. **Timeframe:** preliminary desk **M5**; match Scouter adverse TF to **M5** (Swing coach tip: **M15** grades).  
2. **Fleet:** `InpFleetTargetPairs = 4` (pair complete = open **or** working pending). Challenge desks may use **2**; practice **$20 → 1**, **$50–$100 → 2**.  
3. **Categories:** seed ≥4 per FX / CMD / CRYPTO; trade from **FX** (and CMD for XAU) tabs — START only the pairs for this session; STOP idle FX; **SUSPEND** crypto overnight. Micro practice: FX only.  
4. **Pair state:** START = fills; STOP = no new fills (still scanned); SUSPEND = no fills / not fleet candidate — never closes tickets.  
5. **Events:** Calendar ON + Event **SKIP** default; Telegram `[EVENT]` ahead of relevant activated pairs. Use **TRADE** only when eyes are on the print. Sticky Prop news CSV remains optional hard lock.  
6. **Session clock:** illustrative GMT strip for awareness — still enforce broker hour filter / Friday stop for hard gates. Scalp → LDN·NY overlap; Day → 07–20; Swing → grade band 12–17.  
7. **Risk UI:** Compact · AUTOLOT · EQ **10%** · **SPREAD** on (IGN only deliberate). Practice packs set tighter `InpMaxLot` / Prop day loss from `.set`.  
8. **Harvest:** ASAP floor **≈1%** of balance (stock demo often **5**; practice Raw $100 = **1.00**; Standard floors higher). Adverse min age **15** min on M5; once-green protect **ON**.  
9. **Prop:** set daily loss / DD / max trades to challenge rules (or practice pack values); soft STOP → fix → **PLAY**; never expect Dashboard to flatten.  
10. **Telegram:** allowlist `https://api.telegram.org`; Service (engine WARN) + Dashboard (deals/PROP/EVENT/VERIFY) + Chart attach failover; status NotCfg/Connected/Verified/Error. **Trader** = Service+Dashboard live tags; **Investor** = Dashboard summaries+PROP + silent hours — [Velocity Telegram Alerts](Gsignalx_Velocity_Users_Manual.html#telegram).  
11. **Coexistence:** do not run two entry owners on the same magic (Service OWN + chart entries both true).  
12. **Practice coach:** Full Trade Center only — buttons do **not** hot-load ASAP/Prop money; always **Inputs → Load** + restart Service after changing pack.

| Desk posture | START set | Events | Notes |
|---|---|---|---|
| Practice $20/$50 | 1–2 FX · CMD/CR SUSPEND | SKIP | Raw preferred for scalp; Standard → Day/Swing |
| Practice $100 | 2 FX · XAU optional | SKIP | Aligns with EUR100 Raw ASAP geometry |
| Challenge / risk-off | 1–2 FX | SKIP | Tight daily loss |
| Standard prop | 2–4 FX+CMD | SKIP | Default London–NY |
| Event scalp | Relevant FX | TRADE + watch | Desk must be present |

---

## 4. Production test plan

### Automated (this PC)

```powershell
# From repo root MQ5\files
powershell -ExecutionPolicy Bypass -File .\deploy\Deploy-GSignalX.ps1 -AllTerminals -Compile

powershell -ExecutionPolicy Bypass -File .\deploy\Confirm-GSignalX.ps1 `
  -Gate All -WriteFeedback
```

Upgrade wipe path: `deploy\Clean-and-Deploy.bat`.

| Gate | Pass criteria |
|---|---|
| **G1 Files** | Six hosts present; Telegram/Prop/Roster includes present |
| **G2 Compile** | `.ex5` exist; compile logs **0 errors, 0 warnings** |
| **G2b Versions** | Confirm asserts `#property version "2.00"` on six hosts |
| **G3 Start** | Algo ON; Service + Scouter Service + Grader; Dashboard attached |
| **G4 Bus** | `Common\Files\GSignalX\bus\v1\` heartbeats/signals ~60s; grades `"version":1` |
| **G5 Roster** | `bus\v1\roster\{magic}.csv` + `GSX_SVC_ROSTER_SEQ_{magic}` advances |
| **G6 UI** | Trade Center PROP/TG strip; chart strip optional; buttons never close |
| **G7 Desk checklist** | Section 5 below |

### Manual desk checklist (demo)

- [ ] Service OWN=1; chart EA defers fleet/auto-entry  
- [ ] Dashboard ADD/REMOVE updates roster; mute skips symbol  
- [ ] Fleet target change reflected in Service fill  
- [ ] Prop trip → sticky STOP / RUN=0; **positions remain**; PLAY resumes  
- [ ] Telegram verify + sample OPEN/CLOSE tags (if enabled)  
- [ ] Scouter banks winners >= floor; adverse path respects age/once-green  
- [ ] HALT / STOP on chart never closes  
- [ ] WebRequest allowlist includes Telegram API when TG on  

| Gate | Result (2026-09-14 Confirm) |
|---|---|
| Files / Compile | PASS — 0 errors / 0 warnings on all hosts |
| LoserSafety + 2.00 packaging | PASS — 6/6 host versions; `GSX_BUS_VERSION=1` |
| Bus / Grades | PASS — schema `"version":1` (stale heartbeat WARNs OK if publishers idle) |

Feedback artifact: `deploy/feedback/CONFIRM_2026-09-14_225711_All.md`.

**Sign-off line (demo runtime still operator-owned):**

```text
VELOCITY 2.00 SIGN-OFF | Build+Confirm static: PASS | Demo runtime: ____ | Operator: ____ | Date: ____
```

---

## 5. Operator steps (1 page)

**Non-tech path (ZIP / double-click / error table):** [WINDOWS_DEPLOY_SIMPLE.md](WINDOWS_DEPLOY_SIMPLE.md)

1. Run **`deploy\Clean-and-Deploy.bat`** (upgrade) or **`Click-and-Run-Deploy.bat`**.  
2. MT5 → **Algo Trading ON**.  
3. Allow WebRequest URL `https://api.telegram.org` if using Telegram.  
4. Start Services: **GsignalX_Service**, **ProfitScouter_Service**, **ProfitOpportunity_Grader**.  
5. Attach **Multisymbol Dashboard** (seed list + magic).  
6. Optional: attach chart **GSignalX** on M5 for strip/UI; keep `InpChartEntriesWhenService=false`.  
7. Configure PropRisk inputs to challenge; enable Telegram if needed.  
8. Run **`deploy\Confirm-After-Start.bat`** → expect All PASS including version 2.00.  
9. Complete checklist → sign off → challenge / live.

If a black-window error appears, match it in [WINDOWS_DEPLOY_SIMPLE.md § Problems and fixes](WINDOWS_DEPLOY_SIMPLE.md#problems-and-fixes) before retrying.

### Rollback

- Re-deploy prior tagged tree / prior `.ex5`.  
- Bus path remains `v1` — no schema migration on rollback.

---

## 6. Short release note (paste)

```text
Gsignalx Velocity 2.00 — prop desk cut (+ practice live packs)

Hosts bumped to 2.00: GSignalX chart + Service, Multisymbol Trade Center,
ProfitScouter EA/Service, Opportunity Grader. FILE_COMMON bus stays schema v1.

Production desk: Service owns entries, Dashboard owns roster/categories/events/PROP/Telegram/practice coach,
Scouter owns exits (soft Prop STOP never closes). Best use: London–NY FX+metals, crypto
SUSPEND, Event SKIP, M5, fleet 4, AUTOLOT + EQ 10%, ASAP ≈1% balance, adverse age 15.

Practice live: $20/$50/$100 · Raw or Standard — load Practice_*.set pairs, restart Services,
Trade Center 20/50/100 · RAW/STD · SCALP/DAY/SWING (coach tips; see docs/PRACTICE_LIVE_SIM_20_50_100.md).

Deploy: Clean-and-Deploy.bat → Algo ON → start Services → attach Dashboard →
Confirm-After-Start.bat. Demo sign-off before live / challenge.

Non-tech: docs/WINDOWS_DEPLOY_SIMPLE.md
```
