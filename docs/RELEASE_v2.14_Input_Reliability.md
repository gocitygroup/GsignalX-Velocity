# RELEASE v2.14 — Current Production Cut

**Banner:** Current production cut for Gsignalx Velocity (Gocity Group)  
**Date:** 2026-09-17  
**Hosts:** Trade Center / Service **`#property version "2.14"`**  
**Bus schema:** still **`version: 1`** (`GSignalX/bus/v1`)  
**Canonical manual:** [Gsignalx_Velocity_Users_Manual.html#desk213](Gsignalx_Velocity_Users_Manual.html#desk213) (System UI Best Use) · Adaptive risk: [#risk-framework](Gsignalx_Velocity_Users_Manual.html#risk-framework) · Deploy: [WINDOWS_DEPLOY_SIMPLE.md](WINDOWS_DEPLOY_SIMPLE.md)

> Operator cut below remains valid. Prefer the HTML manual for risk lifecycle, asset matrix, and digital tip behaviour (`RiskGuidance.mqh`).

---

## Who it’s for

- **Prop / small-fund traders** — structured entries, soft Prop locks, live desk DIR  
- **Practice investors** — $20 / $50 / $100 packs; quieter Telegram (DAILY + PROP)  
- **Invariant:** GSignalX opens risk; **ProfitScouter** banks winners. Desk/Chart PLAY/STOP/HALT never close tickets.

---

## Best use (run the desk)

| Mode | DeskExecute | Service | Result |
|------|-------------|---------|--------|
| **A (preferred)** | ON | Stopped | Trade Center owns fills |
| **B (headless)** | OFF | Running | Service owns fills |
| Both | ON | Yield ON | Service idles on Desk OWN + HB |

**One magic.** Do not attach Chart EA for entries on the same magic.  
**Lot:** FIXED **0.01** (press AUTOLOT only for intentional risk%).  
**EQ:** leave **OFF** unless you want a floating-DD entry brake.  
**Prop challenge:** set max equity DD 5–10 only on challenge accounts; use **PROP CLEAR** if locked (PLAY alone does not clear Prop).  
**Hygiene:** REM unused pairs; STOP cancels pendings; START only what you want live.  
**Exits:** Scouter owns BANK / CUT / FLAT.

---

## All on-chart controls

Four surfaces. Services have **no** chart buttons. Full tables: [Manual § System UI](Gsignalx_Velocity_Users_Manual.html#desk213).

### Cross-surface

| Rule | Detail |
|------|--------|
| STOP vs HALT | STOP = entries off, Scouter may harvest; HALT = entries + linked Scouter off; neither closes |
| Scouter START/STOP | Harvest arm only — not desk PLAY/STOP |
| BANK / CUT / FLAT | Only UI flatten path |
| FOLLOW vs FollowDir | Run-strip FOLLOW = flip-wait; FOLLOW·BUY·SELL·WAIT = direction gate |
| EQ | Chart = cycle OFF→5→10→20; Desk = four pads |

### Trade Center (`GSXMS_`)

| Strip | Controls |
|-------|----------|
| Nav | VERIFY · ALL/FX/CMD/CRYPTO · fleet ± · page · carousel · ADD/SWAP/REM |
| Run | PLAY · STOP · HALT · FOLLOW\|WAIT (flip) · SPREAD\|IGN |
| Lot/EQ | FIXED\|AUTOLOT · EQ OFF/5/10/20 |
| Status | RUN/FOL/EVT/FIX **labels** · REKICK (**needs PLAY**) |
| FollowDir | FOLLOW · BUY · SELL · WAIT (all roster pairs) |
| Bulk | START ALL / STOP ALL (**current category view**) · PROP CLEAR (+arm PLAY) / PROP OK · EVT · practice 20/50/100 |
| Per-row | MODE · START/STOP/SUSPEND · X (REM) |

### Chart Signal panel (`GSX_`)

PLAY · STOP · HALT · flip FOLLOW\|WAIT · FollowDir (this symbol) · SPREAD\|IGN · FIXED\|AUTOLOT · EQ cycle.

### Chart roster strip

Carousel <> · ADD/SWAP/REM · page · per-row STATE/X. No PLAY/EQ/PROP on strip.

### ProfitScouter (`PSBTN_`)

START · STOP · AUTO · **BANK +** · **CUT −** · **FLAT** (confirm closes).

---

## What ships in 2.14 (includes 2.13 desk)

| Area | Takeaway |
|------|----------|
| Desk risk UI (2.13) | EQ pads; Account DD vs Prop peak DD; session W/L/net; PROP CLEAR; REKICK |
| Prop ease | Equity DD default OFF; Friday default OFF; recoverable EQUITY_DD |
| Lot | FIXED 0.01; AUTOLOT off by default |
| Trigger lifetime | STOP cancels pendings; orphan prune; no cold-start re-fire |
| Input sync (2.14) | AUTOLOT/EQ survive reattach; chart chips use desk GVs |
| Service | Instant yield on Desk OWN; multi-fill per cycle; Prop day locks clear at UTC rollover |
| Perf (2.14.1) | RR publish-as-ready; roster seq cache; cycle fleet snap; snapshot PL batch; desk-mirror ≤15s |

---

## Upgrade after deploy

1. Compile all terminals; reattach Trade Center; restart Service if used.  
2. Automation shows **FIXED** / **0.01**.  
3. **STOP** once → **REM** unused pairs → **PLAY** / START the live book.  
4. Prop LOCK from old equity rule → **PROP CLEAR**.

```powershell
.\deploy\Deploy-GSignalX.ps1 -AllTerminals -Compile -MetaEditorPath "...\MetaEditor64.exe"
.\deploy\Confirm-GSignalX.ps1 -Gate All -WriteFeedback
```

Expect Functional PASS including V2.14 markers; idle bus/grades WARN OK.

## Soak (before live)

1. Topology A + Yield ON  
2. Toggle AUTOLOT → reattach → still ON  
3. STOP → ADD → stays STOPPED until PLAY  
4. Desk alive → Service yields immediately  
5. EQ 5% with floating loss ≥5% → fill_skip; EQ OFF clears  
6. Roster ≥6 pairs → DIR present on all rows; updates as each symbol finishes calc (no 1s stall across book)  
