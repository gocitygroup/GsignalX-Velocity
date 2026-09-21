# Stage 4 — Risk Guidance Implementation Spec

**Version:** 1.0 (Velocity 2.14 hooks)  
**Code:** `Include/GSignalX/RiskGuidance.mqh`  
**Catalog:** [RISK_GUIDANCE_BLOCKS.md](RISK_GUIDANCE_BLOCKS.md)

---

## 1. Goal

Select **context-aware** short guidance for Trade Center, SettingsNotify, and Telegram — not one static warning for every trader.  
v1 does **not** change lot, SL, or harvest math. Tips are advisory only.

---

## 2. Context schema

| Field | Type | v1 source | Status |
|-------|------|-----------|--------|
| `asset_class` | FX/CMD/CR/OTH | `SymbolClass` / `snap.catFilter` | Live |
| `instrument` | string | symbol / canon | Live (TG OPEN) |
| `market_condition` | enum | — | **Future** (default UNKNOWN; proxies below) |
| `timeframe` | enum | desk chart TF / practice `tfHint` | Partial |
| `signal_type` | string | bus DIR / Executive (manual only) | Partial |
| `signal_age` | seconds | — | **Future** |
| `trade_direction` | buy/sell | deal / FollowDir | Partial |
| `volatility_state` | low/norm/high | — | **Future** (spread gate proxies stress) |
| `session` | ASIA/LDN/NY/SYD/overlap | `SessionClock` | Live |
| `event_risk` | TRADE/SKIP/none | `EventGate` / `snap.eventMode` | Live |
| `position_size` | lots | deal / FIXED | Partial |
| `stop_distance` | price | sizing ATR / StrategicStop | **Future** tip-only |
| `account_risk` | Prop/EQ/practice band | PropRisk, EQ guard, PracticeSim | Live |
| `portfolio_exposure` | fleet counts by class | `countFx/Cmd/Cr`, fleet target | Partial |
| `execution_mode` | desk/service/chart | host tag | Partial |
| `manual_or_automated` | bool | BANK/CUT vs Scouter auto | Partial |
| `trade_phase` | PRETRADE…POST/SETTINGS | caller | Live |

### Market-condition proxies (v1)

Until an OHLC classifier exists, map:

| Proxy | Treat as |
|-------|----------|
| Event SKIP active | News-driven / elevated event risk |
| Prop LOCK | Account-risk halt (not a chart pattern) |
| Session overlap LDN+NY | Expansion / higher participation (FX) |
| Asia-only FX filter view | Lower liquidity caution |
| `ignoreSpread` IGN ON | Abnormal execution willingness — warn |

---

## 3. Selector algorithm (v1)

Priority (first match wins for primary tip):

1. `propLocked` → Prop LOCK tip (`RB_DRAWDOWN` flavour)
2. `eventSkip` → Event SKIP tip (`RB_PRETRADE`)
3. `phase == SETTINGS` → settings clause for action
4. `phase == ENTRY` or desk FDIR row → entry/soft-entry tip + class/session colouring
5. Class-specific note (CR / CMD / FX session) when cat filter narrows book
6. Default soft: “New entries only — open positions unchanged”

Truncate UI tips to **96** characters (practice tip contract).

---

## 4. Digital surfaces

| Surface | File | Hook |
|---------|------|------|
| Trade Center FDIR tip | `MultisymbolQuadDraw.mqh` | `GsxRiskDeskTip(...)` replaces static string |
| Practice tip line | `PracticeSim.mqh` | Enrich `GsxPracticeFormatTipLine` |
| Settings impact | `SettingsNotify.mqh` | Append `GsxRiskSettingsClause(action)` |
| Telegram OPEN | `TelegramNotifier.mqh` | Suffix `\| tip:…` via `GsxRiskTipForSymbol` |

### Non-goals (v1)

- FollowGate prose API  
- OpportunityGrade sentence expansion  
- New Trade Center quadrant  
- Automatic OHLC market-condition engine  

---

## 5. Future extension

Persist block IDs in bus JSON or TG payloads (`risk_block=RB_ENTRY`) for analytics.  
Add `market_condition` from bar structure + ATR percentile.  
Drive HTML manual deep-links from the same block IDs (`#risk-lifecycle`).

---

## 6. Safety

- Never invent broker contract sizes, margins, or win rates in tips.  
- Never imply desk STOP/HALT closes tickets.  
- Never instruct widening StrategicStop.  
- Tips must remain actionable, not “never trade volatility.”
