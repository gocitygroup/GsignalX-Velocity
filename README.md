# GSignalX MQL5 Trading Toolkit

[![License: PolyForm-Noncommercial-1.0.0](https://img.shields.io/badge/License-PolyForm--NC--1.0.0-blue.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-GSignalX--MQL5--TradingToolkit-469AD4?logo=github)](https://github.com/gocitygroup/GSignalX-MQL5-TradingToolkit)
[![Manual](https://img.shields.io/badge/Manual-Gsignalx%20Velocity-FBA927)](docs/Gsignalx_Velocity_Users_Manual.html)

Broker-agnostic MT5 toolkit for signals (GsignalX), profit harvesting (ProfitScouter), and multi-terminal opportunity grading via a FILE_COMMON connector bus. Product desk brand: **Gsignalx Velocity** (Gocity Group). Executive cloud conviction: [gsignalx.cloud](https://www.gsignalx.cloud/).

**License:** source-available under [PolyForm Noncommercial 1.0.0](LICENSE) — personal, educational, and research use welcome; **commercial use not permitted** under this license (see [NOTICE](NOTICE)). Feedback and contributions: [CONTRIBUTING.md](CONTRIBUTING.md).

**Clone:**

```bash
git clone https://github.com/gocitygroup/GSignalX-MQL5-TradingToolkit.git
cd GSignalX-MQL5-TradingToolkit
```

## Components

| Program | Type | Role |
|---|---|---|
| `GsignalX_GocityGroup.mq5` | Expert | Multi-engine trend signals + entries; scalping drill; fleet fill; movable panel; bus publisher |
| `ProfitScouter_DollarTarget.mq5` | Expert | Money-target harvest with movable chart panel; profit lock; AUTO adverse exit |
| `ProfitScouter_Service.mq5` | Service | Same harvest engine, chart-free, background |
| `ProfitOpportunity_Grader.mq5` | Service | Ranks entry + harvest opportunities across terminals |
| `ProfitHarvest_Now.mq5` | Script | One-shot close-at-target |

**Two independent systems (v1.20 / ProfitScouter v1.18):** GSignalX is the **entry engine** and ProfitScouter is the **exit engine**. With `InpExitMode = Scouter` (default) the signal EA never reverse-closes a position — Profit Scouter owns profit exits. In Scouter mode entries attach an optional **catastrophe broker SL** only (`InpStrategicStopEnable`, default **4.0×ATR**, wider than sizing `InpStopMult`); **TP stays open**. Chart **FOLLOW** (default) leaves open positions for Scouter and keeps filling the latest signal direction on free charts / fleet; **WAIT** (4th button) blocks new-direction entries while opposite-direction magic exposure remains. Every cycle ProfitScouter banks thresholds from **winners only** (default ASAP floor **$5**); adverse-bar Auto may cut same-symbol losers. The **fleet governor** (`InpFleetTargetPairs` default **4**) treats a pair as complete when it has an **open position or working pending** — fill stops once 4 pairs are covered. Unfilled pendings expire by age (`InpPendMaxAgeMin`). Panel/bus show live fleet floating P/L and session outcomes.

**Chart controls never close trades:** **PLAY** / **STOP** / **HALT** / **FOLLOW|WAIT**. STOP pauses entries; HALT pauses entries + linked Scouter; FOLLOW/WAIT toggles flip-fill policy. Open positions are left for Profit Scouter (plus optional catastrophe SL).

Shared libraries live under `Include/GSignalX/` and `Include/ProfitScouter/`.

**Crypto weekends:** GsignalX v1.11+ auto-detects crypto (path/currency/name) and, with `InpCryptoAllowWeekend=true` (default), skips FX Saturday/Sunday blocks, Friday cut-off, and weekend flatten. Add odd broker names to `InpCryptoExtraList` if needed.

**Order entry (v1.14+):** default is **limit + stop bracket** anchored to the **signal bar open** (`InpPendFromSignalOpen`). Offsets default to **5** pips each (set **4–6** for tight scalp; clamp **4–20**). During the scalping drill window, unfilled pendings stay until the window ends. Set `InpEntryMode=Market` for immediate fills.

**Scalping drill (v1.13+):** each chart is independent. On **PLAY**, a 5–15 minute drill window starts (`InpDrillMinutes`, default 10). While the window is open and engines agree under the bot’s entry rules (MA / MinAgree / AllowLong-Short), GSignalX joins or re-enters that chart’s symbol in the active BUY/SELL direction — not flip-only. After ProfitScouter closes all positions at the account money target, each PLAY chart that goes flat re-arms once (`InpDrillMarchAfterFlat`) and opens again if the signal still says buy or sell. When the drill window expires, behaviour returns to flip-based entries until the next PLAY.

## Docs

- [**Gsignalx Velocity Trader Manual (HTML)**](docs/Gsignalx_Velocity_Users_Manual.html) — primary desk manual for prop / small-fund traders (sessions, €10+ growth ladder, deploy on Windows, behavioural checklist). GitHub Pages entry: [`docs/index.html`](docs/index.html). Executive cloud signals: [gsignalx.cloud](https://www.gsignalx.cloud/)
- [CREED ALGO Users Manual (legacy)](docs/CREED_ALGO_Users_Manual.md) — prior umbrella guide ([PDF](docs/CREED_ALGO_Users_Manual.pdf))
- [DEPLOYMENT_RUNBOOK.md](DEPLOYMENT_RUNBOOK.md) — **guided gates G0–G7 with feedback blocks** (use this for step-by-step confirm)
- [DEPLOYMENT.md](DEPLOYMENT.md) — install, compile, first-run, verify
- [ARCHITECTURE_CONNECTOR_BUS.md](ARCHITECTURE_CONNECTOR_BUS.md) — bus protocol, scoring, demo checklist
- [README_ProfitScouter.md](README_ProfitScouter.md) — Profit Scouter configuration and behaviour
- [PRESET_100EUR_RawSpread.md](docs/PRESET_100EUR_RawSpread.md) — micro-capital raw-spread growth preset

## Quick deploy

**Easiest:** for a **new version upgrade**, double-click [`deploy\Clean-and-Deploy.bat`](deploy/Clean-and-Deploy.bat).  
For a fresh deploy without wiping: [`deploy\Click-and-Run-Deploy.bat`](deploy/Click-and-Run-Deploy.bat).  
Then start Services in MT5, then double-click [`deploy\Confirm-After-Start.bat`](deploy/Confirm-After-Start.bat).

Or PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\Deploy-GSignalX.ps1 -ListTerminals
powershell -ExecutionPolicy Bypass -File .\deploy\Deploy-GSignalX.ps1 `
  -TerminalDataPath "$env:APPDATA\MetaQuotes\Terminal\<HASH>" -Compile
powershell -ExecutionPolicy Bypass -File .\deploy\Confirm-GSignalX.ps1 -Gate All -WriteFeedback
```

Walk gates with feedback: [DEPLOYMENT_RUNBOOK.md](DEPLOYMENT_RUNBOOK.md).
