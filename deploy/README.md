# Deploy folder — start here

**Not technical?** Open this first:

`..\docs\WINDOWS_DEPLOY_SIMPLE.md`

## What to double-click

| File | When |
|---|---|
| `Click-and-Run-Deploy.bat` | First install on this PC |
| `Clean-and-Deploy.bat` | Upgrading to a new Velocity version |
| `Confirm-After-Start.bat` | After you started Services in MetaTrader 5 |
| `List-Terminals.bat` | Only list MT5 data folders (troubleshooting) |

## After the black window finishes

1. MetaTrader 5 → **Algo Trading ON**  
2. Start Services: `GsignalX_Service`, `ProfitScouter_Service`, `ProfitOpportunity_Grader`  
3. Attach Expert: `GsignalX_Multisymbol_Dashboard`  
4. Run `Confirm-After-Start.bat`

## Errors

Match the message in **Problems and fixes** inside `WINDOWS_DEPLOY_SIMPLE.md`.  
Common: open MT5 once before deploy; set `METAEDITOR=` in the `.bat` if MetaEditor is not found.
