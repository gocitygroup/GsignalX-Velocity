# Native TP Module (MQL5 host, scope 1A + Both)

Standalone Take-Profit calculated from closed OHLC bars only:

`bars → Bollinger(H/L) → SBT two-pass trail → flip pivots → Median/Average distance → TP level / hit`

## Scope

- MQL5 host integration + Python golden-vector reference (`tests/tp_native/`).
- Shared `Include/GSignalX/TpNative/` wired into Chart (`GsignalX_GocityGroup.mq5`) and Desk (`GsignalX_Multisymbol_Dashboard.mq5`).
- Existing `Engines.mqh` SBT is **not** modified or merged.
- Default `enabled=false` — TP-OFF leaves host behaviour unchanged.
- `closeOnHit`: Chart/Desk emit FILE_COMMON pending; ProfitScouter `CloseTicket(..., "NATIVE-TP")`.

## Pipeline settings

| Setting | Default |
|---------|---------|
| enabled | false |
| type | MEDIAN |
| closeOnHit | false |
| period | 12 |
| mult | 2.0 |
| pivotSource | ZIGZAG |
| crossMode | SERIES |
| historyBars | 500 |

## Persistence

`FILE_COMMON/GSignalX/tp_native/{symbol}_{tf}.json` — schemaVersion 1.  
UI toggles: `GSX_MS_TPENABLE_{magic}`, `GSX_MS_TPTYPE_{magic}`.

## Tests

```bash
python tests/tp_native/tp_native_ref.py
# MT5: compile & run Scripts/GSX_TpNative_Test.mq5
```

## Files

See README section **Native Take-Profit** and `docs/plans/TP_NATIVE_BASELINE.md`.
