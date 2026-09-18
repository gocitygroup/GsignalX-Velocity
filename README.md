# GSignalX Velocity — MT5 Prop Desk Toolkit

[![License: PolyForm-Noncommercial-1.0.0](https://img.shields.io/badge/License-PolyForm--NC--1.0.0-blue.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-GsignalX--Velocity-469AD4?logo=github)](https://github.com/gocitygroup/GsignalX-Velocity)
[![Manual](https://img.shields.io/badge/Manual-Gsignalx%20Velocity-FBA927)](docs/Gsignalx_Velocity_Users_Manual.html)

**For prop traders, small-fund desks, and practice investors.**  
Structured entries · winners-only harvest · prop-safe soft STOP · one magic.

**GSignalX** opens risk. **ProfitScouter** banks winners. Desk PLAY/STOP never closes tickets.  
Default lot **FIXED 0.01**. Bus schema **v1**. Current cut **Velocity 2.14**.

**Start here**

1. [Trader & investor manual](docs/Gsignalx_Velocity_Users_Manual.html)  
2. [Windows deploy (non-tech)](docs/WINDOWS_DEPLOY_SIMPLE.md)  
3. [Current RELEASE 2.14 — Best use](docs/RELEASE_v2.14_Input_Reliability.md)

Cloud conviction signals (optional): [gsignalx.cloud](https://www.gsignalx.cloud/)

**Desk community** — same invites as GSignalX Executive:

- **[Trading channel](https://t.me/+yURbcVkPi1kxNDg0) (primary)** — Macro overview for day trading: consult the composite current driver breakdown and the cited data sources for the quantitative basis  
- [Trading group](https://t.me/+ZDosSHfUCLU1ZGY0) — feedback & peer desk  
- [WhatsApp meet-up](https://chat.whatsapp.com/EemGekqMwDgKrLj0tkqYlB) — live desk chat  

Manual chapter: [Desk Community](docs/Gsignalx_Velocity_Users_Manual.html#community) · Scouter **TRAIL** best use: [Profit CASH](docs/Gsignalx_Velocity_Users_Manual.html#profit-cash)

**License:** [PolyForm Noncommercial 1.0.0](LICENSE) — personal / education / research; commercial use not permitted ([NOTICE](NOTICE)). [CONTRIBUTING.md](CONTRIBUTING.md)

```bash
git clone https://github.com/gocitygroup/GsignalX-Velocity.git
cd GsignalX-Velocity
```

## Components

| Program | Type | Role |
|---|---|---|
| `GsignalX_Multisymbol_Dashboard.mq5` | Expert | Trade Center — DeskExecute fills, Prop, Telegram (**2.14**) |
| `GsignalX_Service.mq5` | Service | Headless roster scan + fills; yields to Desk (**2.14**) |
| `GsignalX_GocityGroup.mq5` | Expert | Chart strip / optional entries (defer when Desk/Service owns magic) |
| `ProfitScouter_Service.mq5` | Service | Exits — ASAP / BANK / CUT / FLAT |
| `ProfitScouter_DollarTarget.mq5` | Expert | Same harvest on chart |
| `ProfitOpportunity_Grader.mq5` | Service | Cross-terminal opportunity grades |
| `ProfitHarvest_Now.mq5` | Script | One-shot close-at-target |

**Best use:** Topology A — Trade Center DeskExecute ON, Service stopped (or Yield ON), FIXED 0.01, EQ OFF unless you want a floating-DD brake, STOP clears pendings, Scouter owns exits. Details: [RELEASE 2.14](docs/RELEASE_v2.14_Input_Reliability.md) · Manual [System UI Best Use](docs/Gsignalx_Velocity_Users_Manual.html#desk213).

**Trader:** live DIR, FOLLOW pads, Telegram deals + PROP.  
**Investor / monitor:** quieter TG (DAILY + PROP), Compact strip, Scouter harvest.

Practice packs: [PRACTICE $20/$50/$100](docs/PRACTICE_LIVE_SIM_20_50_100.md) · [EUR100 M5 preset](docs/PRESET_100EUR_RawSpread.md)

## Docs

- [Velocity manual (HTML)](docs/Gsignalx_Velocity_Users_Manual.html) — primary  
- [WINDOWS_DEPLOY_SIMPLE.md](docs/WINDOWS_DEPLOY_SIMPLE.md) — ZIP → double-click → MT5  
- [RELEASE_v2.14](docs/RELEASE_v2.14_Input_Reliability.md) — current production cut  
- [DEPLOYMENT_RUNBOOK.md](DEPLOYMENT_RUNBOOK.md) — Confirm gates  
- [DEPLOYMENT.md](DEPLOYMENT.md) — technical install  
- [ARCHITECTURE_CONNECTOR_BUS.md](ARCHITECTURE_CONNECTOR_BUS.md) · [README_ProfitScouter.md](README_ProfitScouter.md) — engineering

## Deploy

**Non-tech:** [WINDOWS_DEPLOY_SIMPLE.md](docs/WINDOWS_DEPLOY_SIMPLE.md)  
**Upgrade:** [`deploy\Clean-and-Deploy.bat`](deploy/Clean-and-Deploy.bat) → Algo Trading ON → Trade Center (DeskExecute) + Scouter + Grader → [`Confirm-After-Start.bat`](deploy/Confirm-After-Start.bat)

Vercel serves the HTML manual from `docs/` ([`vercel.json`](vercel.json)).
