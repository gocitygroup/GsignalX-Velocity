# Stage 1 — Document Audit

**Date:** 2026-09-21  
**Product:** Gsignalx Velocity 2.14 + ProfitScouter 2.02  
**Sources audited:** `docs/Gsignalx_Velocity_Users_Manual.html`, `docs/PRACTICE_LIVE_SIM_20_50_100.md`, `docs/PRESET_100EUR_RawSpread.md`, `docs/RELEASE_v2.14_Input_Reliability.md`, `README_ProfitScouter.md`, and the risk stack in `Include/GSignalX/*` + `Include/ProfitScouter/*`.

**Principle preserved:** GSignalX opens risk; PropRisk / MarketGates / EventGate soft-block entries; StrategicStop is catastrophe SL only; ProfitScouter owns exits. Desk PLAY/STOP/HALT never flatten.

---

## 1. What the original docs already do well

| Area | Strength |
|------|----------|
| Architecture split | Clear “opens vs closes” map; non-negotiable behaviours listed |
| Profit / Loss CASH | Practical scalp floors; Loss CASH opt-in; winners-only harvest |
| Prop soft STOP | Explicit: locks entries, never closes; PROP CLEAR + grace |
| Practice geometry | $20/$50/$100 bands with day loss/profit, fleet, ASAP floors |
| EUR 100 preset | Min-lot dominance, catastrophe SL do-not-widen, growth ladder |
| Production cut | Topology A/B, FIXED 0.01 default, Scouter owns BANK/CUT/FLAT |
| Session timing | London–NY overlap recipe; hour/Friday filters documented |
| Scouter depth | Adverse Auto, ATR trail, CASH vs LAYER, close guards |

---

## 2. Missing adaptive risk controls

| Gap | Impact |
|-----|--------|
| No market-condition engine in the manual | Traders treat every signal like a trend continuation |
| No “reason for the trade” vs P/L framing | Premature profit-taking / emotional early loss-cuts |
| Support/resistance treated implicitly only | Levels not framed as decision zones with invalidation |
| Signal generation vs execution not separated | Old/stale cloud or bus DIR may still feel like “must enter” |
| Portfolio / correlation risk thin | EURUSD+GBPUSD fleet concentration not taught as exposure |
| Asset-class matrix incomplete | FX/CMD/CR in UI; indices/equities/CFDs/futures only “OTH” |
| Technology / bot risk chapter absent | VPS, bus stale, duplicate Scouter, symbol suffix mismatch |
| Manual Trade Risk Check missing | No compact pre-entry checklist in desk workflow |
| Trade lifecycle phases not named | Pre-trade → post-trade guidance scattered |
| Digital tips computed but undrawn | `snap.tipLine` / coach lines exist; FDIR tip is static |

---

## 3. Ambiguous instructions / contradictions

| Topic | Ambiguity |
|-------|-----------|
| FIXED 0.01 vs AUTOLOT risk% | Production cut prefers FIXED; growth/preset docs teach % risk that is dormant under min-lot |
| Profit CASH stock 100 vs micro floors | Manual says ladder for micro; stock default 100 can starve small books if not re-set |
| Growth ladders as “samples” vs production | Sample ladders can be read as performance promises without the disclaimer nearby |
| Executive cloud vs Velocity engines | Welcome says both can agree; weak guidance when they conflict |
| WAIT vs FollowDir WAIT | Two WAIT concepts (flip-wait vs direction pad) — easy to confuse under stress |
| StrategicStop mult vs sizing ATR | Documented in preset; under-emphasized in main manual System map |

---

## 4. Technical weaknesses (docs ↔ code)

- Manual does not map risk layers A–Q to concrete knobs (`LotSizing`, `StrategicStop`, `PropRisk`, `EventGate`, `MarketGates`, Scouter).
- No decision tree: instrument → condition → signal valid → size → enter/wait/cancel.
- Broker-specific values sometimes appear as examples (EUR 100 raw) without always repeating “verify instrument specification.”
- `PracticeSim` tips truncated to 96 chars but never rendered when practice UI is off (default).

---

## 5. Market-specific gaps

| Runtime class | Documented? | Gap |
|---------------|-------------|-----|
| Forex (FX) | Yes (sessions, spread) | Weekend/gap and correlation portfolio tips weak |
| Commodity (CMD) | Partial (capacity, news USD link) | Session/roll/gap behaviour under-specified |
| Crypto (CR) | Partial (weekend allow, SUSPEND overnight) | Funding/24h liquidity failure modes thin |
| Other (OTH) | Label only | Indices / equities / CFDs / futures need manual matrix rows |

---

## 6. Automation vs manual-trading risks

| Risk | Current coverage |
|------|------------------|
| Soft STOP never closes | Strong |
| Duplicate entry hosts / same magic | Strong |
| Manual BANK/CUT/FLAT override | Documented; emotional-use guidance weak |
| Removing / widening StrategicStop | Preset warns; main manual should elevate to DO NOT OVERRIDE |
| Revenge / averaging without rule | Missing |
| Bot restart / bus stale / TG queue | Ops docs exist; trader-facing bot safety checklist missing |

---

## 7. Gaps vs master-prompt layers A–Q

| Layer | Status |
|-------|--------|
| A Market / asset | Partial → upgrade matrix |
| B Instrument | Partial (roster / canon) |
| C Market-condition | Missing → new panel |
| D Timeframe | Partial (M5 preliminary) |
| E Signal | Partial (FOLLOW/WAIT, grades) |
| F Entry | Strong (gates) |
| G Position-sizing | Strong (FIXED/AUTOLOT) but confused with leverage in places |
| H Stop-loss | Strong (strategic vs sizing) if elevated |
| I Take-profit | Strong (Profit CASH) |
| J Open-trade management | Partial (Scouter) |
| K Event / news | Strong (EventGate) |
| L Liquidity / execution | Partial (spread gate) |
| M Leverage / margin | Weak (examples only) |
| N Correlation / portfolio | Weak |
| O Technology / bot | Weak |
| P Human-behaviour | Weak |
| Q Exit / profit-protection | Strong (Scouter) + early-exit distinction missing |

---

## 8. Upgrade direction (Stages 2–4)

1. Restructure the HTML manual with risk panels + embedded risk blocks; fold practice/preset/Scouter/release as worked examples.
2. Publish reusable block catalog + digital selector spec.
3. Ship `RiskGuidance.mqh` tips to Trade Center, practice tip line, Settings impact, Telegram OPEN — without changing money logic.
