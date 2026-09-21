# Adaptive Risk Manual — Final Quality Checklist

Date: 2026-09-21 · Against master-prompt §25

| Check | Status | Evidence |
|-------|--------|----------|
| Risk guidance throughout workflow | Pass | New panels + embedded `.risk-block` in System/Growth/Prop/Beginner/Welcome |
| Context-specific guidance | Pass | Market Conditions table; lifecycle phases; digital selector priority |
| Forex ≠ commodities ≠ crypto ≠ indices/equities | Pass | Asset matrix panel; SymbolClass tips |
| Signal risk ≠ execution risk | Pass | Lifecycle phases 2–3; beginner signal validation block |
| Bot risk ≠ strategy risk | Pass | Bot safety check on System map |
| Position size ≠ leverage | Pass | Position-size check block |
| Stop-loss guidance defined | Pass | Sizing ATR vs StrategicStop called out |
| Profit-management guidance defined | Pass | Profit CASH + RB_PROFIT |
| Early-loss vs emotional exit distinguished | Pass | Prop DO NOT OVERRIDE + Exit decision block |
| Early-profit vs structured profit distinguished | Pass | Same |
| S/R limitations explained | Pass | Market Conditions S/R risk block |
| Trend/pullback/consolidation differences | Pass | Market Conditions table |
| News/event risk included | Pass | EventGate + conditions table |
| Correlation risk included | Pass | Asset matrix portfolio section |
| Multi-timeframe risk included | Pass | M5 preliminary + S/R MTF note |
| Market-condition can invalidate signals | Pass | Invalidate columns + decision tree |
| Technology failures considered | Pass | Bot safety + Spec O layer |
| No guaranteed performance claims | Pass | Disclaimers retained; ladders labeled samples |
| No unsupported numerical assumptions | Pass | Broker values → verify instrument spec |
| Broker/exchange values marked dynamic | Pass | Asset matrix + RiskGuidance tips |
| Manual vs automated separate guidance | Pass | Lifecycle + Manual Trade Risk Check |
| Document remains practical | Pass | Maps to Velocity knobs; tips ≤96 chars |

## Digital hooks verification

| Hook | File | Behaviour |
|------|------|-----------|
| FDIR tip | `MultisymbolQuadDraw.mqh` | `GsxRiskDeskTip` / practice `tipLine` |
| Practice tip | `PracticeSim.mqh` | `GsxRiskPracticeEnrich` |
| Settings impact | `SettingsNotify.mqh` | Appends `GsxRiskSettingsClause` |
| Telegram OPEN | `TelegramNotifier.mqh` | `\| tip:` via `GsxRiskTipForSymbol` |
| Module | `RiskGuidance.mqh` | Pure helpers; no orders |

## Deliverables

- Stage 1: `docs/RISK_MANUAL_AUDIT.md`
- Stage 2: `docs/Gsignalx_Velocity_Users_Manual.html` (+ CSS)
- Stage 3: `docs/risk/RISK_GUIDANCE_BLOCKS.md`
- Stage 4: `docs/risk/RISK_GUIDANCE_SPEC.md` + code hooks
- Satellites slimmed to pointers
