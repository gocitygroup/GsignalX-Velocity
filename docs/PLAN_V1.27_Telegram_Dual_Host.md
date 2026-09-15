# Plan v1.27 — Telegram Dual-Host + Feature Contract

**Date:** 2026-09-15 · **Status:** implemented  
**Scope:** Market-style Telegram feature contract across engine, Service, Dashboard, Chart attach; dual/tri-host ownership split; status NotCfg/Connected/Verified/Error; shared GVs for Chart UI.

## Feature contract

Queue **10**, retries **3**, rate **20**/min, silent hours, getMe verify, multi-chat 3, Markdown tags, WebRequest-only. OPEN/CLOSE/MODIFY with entry/SL/TP/P/L; DAILY/WEEKLY with win rate/drawdown/balance; START/STOP; ERROR/WARN/SIGNAL/custom.

## Ownership

| Host | Sends |
|---|---|
| Service | START/STOP svc, WARN fill/roster/OWN, ERROR |
| Dashboard | OPEN/CLOSE/MODIFY (primary), PROP, EVENT, DAILY/WEEKLY |
| Chart | START/STOP chart; deal watch only if deal-owner failover |

Deal owner: Dashboard HB fresh → desk; else Chart if verified.

## Status GVs

`GSX_TG_STATUS/SENT/FAIL/Q/TOTAL/SVC_OK/DASH_OK/CHART_OK/HB/DEAL_OWNER` per magic.
