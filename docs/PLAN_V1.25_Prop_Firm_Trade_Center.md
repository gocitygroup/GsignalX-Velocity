# Plan v1.25 — Prop Firm Trade Center + Telegram

**Date:** 2026-09-14 · **Status:** implemented  
**Scope:** Multisymbol Dashboard Trade Center UI, TelegramNotifier (WebRequest), PropRisk challenge pack. Soft STOP only; Scouter owns closes.

## Modules

- `Include/GSignalX/TelegramNotifier.mqh` — queue, rate limit, silent hours, verify, Markdown
- `Include/GSignalX/PropRisk.mqh` — daily/weekly loss, equity DD, max trades, consistency, profit target, Friday/news blackout
- `MultisymbolPanel.mqh` — 560px Trade Center, 28px buttons, PROP/TG status
- `GsignalX_Multisymbol_Dashboard.mq5` — host wiring

## Invariant

Dashboard never closes trades. Prop breach → `GSX_SVC_RUN=0` + Telegram `[PROP]`.
