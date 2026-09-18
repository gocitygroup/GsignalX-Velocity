# Settings Notify soak checklist (V2.16)

Operator live soak after deploy + recompile (Dashboard, Chart, Scouter EA/Service).

| Case | Expect | PASS/FAIL | Notes |
|---|---|---|---|
| Desk attach, TG on | `[SETTINGS] … LOAD magic=… RUN=… scout[…]` | | Effective input+UI |
| PLAY | `CLICK PLAY` — entries ON | | |
| STOP | entries OFF; scout still harvests | | |
| HALT | entries OFF; scout OFF; tickets untouched | | |
| FOLLOW / WAIT | mode delta + impact | | |
| AUTOLOT / EQ / IGN | sizing / DD / spread impact | | |
| PROP CLEAR | PROP unlocked | | |
| ADD / REM roster | roster count delta | | |
| Scouter CASH / TRAIL / START | Desk SETTINGS via pending | | No Scouter HTTP |
| PAGE / carousel | no SETTINGS | | |
| OPEN/CLOSE still deliver | deals not starved by SETTINGS | | queue 1/cycle |
| Chart TG failover | LOAD/announce only when desk HB stale | | |

## Compile after deploy

- `Experts\GsignalX_Multisymbol_Dashboard.mq5`
- `Experts\GsignalX_GocityGroup.mq5`
- `Experts\ProfitScouter_DollarTarget.mq5`
- `Services\ProfitScouter_Service.mq5`
