# Plan v1.26 — Trade Center Categories, Pair State, Sessions, Events

**Date:** 2026-09-14 · **Status:** implemented  
**Scope:** Category tabs (Forex / Commodity / Crypto, ≥4 capacity each), three-state pair control (START / STOP / SUSPEND), illustrative GMT session clock, hybrid MT5 Calendar + desk CSV EventGate with TRADE/SKIP and Telegram ahead notify.

## Decisions

| Item | Choice |
|---|---|
| Events | Hybrid: MT5 Calendar primary + desk CSV; Prop sticky NEWS CSV unchanged |
| Pair control | START / STOP / SUSPEND replaces MUTE (mute GV migrated → STOP) |
| Categories | Soft max 8/class (min capacity 4); seed 4 FX + 4 CMD + 4 CR |
| Session clock | Illustrative GMT only — `MarketGates` remains authoritative |

## Modules

| File | Role |
|---|---|
| `Include/GSignalX/SymbolClass.mqh` | FX / Commodity / Crypto taxonomy |
| `Include/GSignalX/SessionClock.mqh` | Asia / London / NY / Sydney GMT windows |
| `Include/GSignalX/EventGate.mqh` | Calendar + CSV poll, TG `EVENT`, SKIP blocks |
| `Include/GSignalX/RosterStore.mqh` | `GSX_SYM_STATE_*`, cat/cap, event block GVs |
| `Include/GSignalX/RosterViewModel.mqh` | Filtered snapshot + class counts |
| `Include/GSignalX/MultisymbolPanel.mqh` | 640px Trade Center UI |
| `Include/GSignalX/Core.mqh` | Fill skips non-START + event-blocked symbols |
| `GsignalX_Multisymbol_Dashboard.mq5` | Inputs + timer poll |

## Pair state semantics

| State | Scan / bus | New fills | Fleet candidate |
|---|---|---|---|
| START | yes | yes | yes |
| STOP | yes | no | no |
| SUSPEND | yes | no | no |

Dashboard never closes positions. Scouter owns exits.

## Persistence

| Store | Content |
|---|---|
| `roster/{magic}.csv` | Symbol list |
| `GSX_SYM_STATE_{magic}_{canon}` | 0/1/2 |
| `GSX_MS_CAT_{magic}` | Category tab |
| `GSX_MS_CLASS_MAX_{magic}` | Soft max (≥4) |
| `GSX_EVT_MODE_{magic}` | TRADE / SKIP |
| `GSX_EVT_BLOCK_{magic}_{canon}` | Active SKIP blackout |
| `GSX_EVT_NTF_*` | Telegram dedupe |

## Invariants

- Fleet PLAY / STOP / HALT + PropRisk soft STOP preserved
- Compact chart roster strip still works
- Object prefix `GSXMS_` isolation
- Prop `InpPropNewsBlackoutMin` sticky fleet STOP unchanged (default off)

## Best use case (prop / small fund)

**London–NY FX + metals book** on one magic; crypto on roster but **SUSPENDed** until intentional.

1. Service + Dashboard + Scouter share one `InpMagic`; seed ≥4 per FX / CMD / CRYPTO.
2. START only the 2–4 pairs for the session; STOP idle FX; SUSPEND crypto overnight.
3. Fleet target **4** (or **2** on challenge); M5 Service; Scouter adverse **M5**.
4. Event mode **SKIP** + Telegram `[EVENT]`; switch to **TRADE** only when watching the print.
5. Session clock = awareness; broker hour filter / Friday stop = hard gates.
6. Dashboard never flattens — PROP / HALT / pair STOP only pause new entries.

| Posture | START | Events |
|---|---|---|
| Challenge | 1–2 FX | SKIP |
| Standard prop | 2–4 FX+CMD | SKIP |
| Event scalp | Relevant FX | TRADE + watch |

Operator docs: Velocity manual § Multisymbol Desk · [RELEASE_v2.00](RELEASE_v2.00_Prop_Desk_Deploy.md) §3.
