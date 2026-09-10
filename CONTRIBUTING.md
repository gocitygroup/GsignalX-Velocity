# Contributing to GSignalX MQL5 Trading Toolkit

Thank you for helping improve **Gsignalx Velocity**. Feedback from prop desks, small funds, and individual traders makes the toolkit better for everyone.

## License reminder

This project is **source-available under [PolyForm Noncommercial 1.0.0](LICENSE)**. Contributions are welcome for personal, educational, research, and other noncommercial use. Commercial redistribution or sale of the software is not allowed under this license — contact Gocity Group for commercial arrangements.

By opening a pull request or issue with patches, you agree that your contribution may be included under the same PolyForm Noncommercial terms and the project [NOTICE](NOTICE).

## Ways to help

1. **Report bugs** — Deploy failures, wrong harvest behaviour, panel/display issues, session-filter surprises.
2. **Share desk feedback** — What worked on a funded challenge / small fund (session hours, ASAP floors, fleet size). No account credentials or broker passwords.
3. **Improve docs** — Clarity in the [Velocity trader manual](docs/Gsignalx_Velocity_Users_Manual.html), presets, or runbook gates.
4. **Propose code fixes** — Prefer focused PRs; keep entry (GSignalX) and exit (ProfitScouter) concerns separate.

## Feedback channels

- **GitHub Issues:** https://github.com/gocitygroup/GSignalX-MQL5-TradingToolkit/issues  
- **Discussions / PR comments:** use the same repository  
- **Executive cloud signals & product programs:** https://www.gsignalx.cloud/

## Before you open an issue

Include when possible:

- Toolkit version (GSignalX / ProfitScouter from the panel or `#property version`)
- MT5 build, OS, broker type (raw vs standard) — not login details
- Symbol, timeframe, and whether ProfitScouter Service was running
- Steps to reproduce; attach `deploy/feedback/` confirm logs if you ran Confirm gates
- Expected vs actual behaviour

## Pull request hygiene

1. Fork and branch from the default branch.
2. Keep changes scoped (one concern per PR).
3. Do not commit secrets, account dumps, or large binary terminals data.
4. Update the Velocity manual or README when behaviour or deploy steps change.
5. Describe *why* the change helps traders or maintainers.

## Code of collaboration

- Be specific and respectful — prop and retail desks learn from the same bugs.
- Prefer evidence (logs, screenshots of panels with account numbers blurred).
- Do not ask maintainers to bypass noncommercial license terms in Issues.

## Clone & local verify

```powershell
git clone https://github.com/gocitygroup/GSignalX-MQL5-TradingToolkit.git
cd GSignalX-MQL5-TradingToolkit
# Then follow docs/Gsignalx_Velocity_Users_Manual.html → Deploy
```
