# Close-Trigger soak checklist (V2.15)

Operator live soak after deploy + recompile of Dashboard, Chart EA, ProfitScouter EA/Service.

| Case | Expect | PASS/FAIL | Notes |
|---|---|---|---|
| Winner harvest (CASH floor) | TG `[CLOSE] … \| reason=ACC-TARGET` (or SYM-/POS-TARGET) | | Match Experts `ProfitScouter [ACC-TARGET]` |
| ATR trail bank | `reason=ATR-TRAIL` | | TRAIL arm ON |
| Adverse loser cut | `reason=ADVERSE-BAR` | | AUTO arm ON |
| Cash loss cut | `reason=ACC-CASH-LOSS` | | LOSS arm ON |
| Manual BANK | `reason=BANK` | | Chart Scouter button |
| Manual CUT / FLAT | `reason=CUT` / `FLAT` | | |
| Broker catastrophe SL (crypto/CMD spike) | `reason=BROKER-SL` | | Experts may show SL-on-open log; no Scouter tag |
| Overfill duplicate trim | `reason=OVERFILL` (full close) or audit-only partial | | |
| Scouter magic filter | Init WARN if filter OFF + SCOPE_ALL; production filter ON | | |
| Service TG | WARN/PROP only — no duplicate OPEN/CLOSE | | |
| Desk STOP | Entries pause; Scouter still harvests; no desk closes | | |
| Audit file | `…\bus\v1\terminals\{tid}\closes\events.jsonl` grows on emit | | |

## Compile after deploy

Recompile in MetaEditor (or `Deploy-GSignalX.ps1 -Compile`):

- `Experts\GsignalX_Multisymbol_Dashboard.mq5`
- `Experts\GsignalX_GocityGroup.mq5`
- `Experts\ProfitScouter_DollarTarget.mq5`
- `Services\ProfitScouter_Service.mq5`
- `Services\GsignalX_Service.mq5`

## Production defaults (Topology A)

- Shared desk magic on Service / Dashboard / Chart / Scouter
- `InpUseMagicFilter=true`, `InpMagicNumber=<desk magic>`
- One Scouter instance owns harvest (`PS{id}_CLOSER`)
