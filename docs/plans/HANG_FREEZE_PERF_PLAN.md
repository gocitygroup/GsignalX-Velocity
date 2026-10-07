# Hang/Freeze Performance Plan

**Status:** DONE — Steps 0–6 implemented, compile 0/0, Confirm Functional + All PASS  
**Product:** Gsignalx Velocity v2.19 Hang/Freeze  
**Confirm:** `deploy/feedback/CONFIRM_2026-10-07_212342_Functional.md`, `CONFIRM_2026-10-07_212345_All.md`

## Step workflow

1. Plan → 2. Implement → 3. Build (compile 0/0) → 4. Confirm test → 5. Next

## Steps

| Step | Focus | Status |
|------|--------|--------|
| 0 | Living plan doc | DONE |
| 1 | Trade Center early-exit + drag + single ChartRedraw | DONE |
| 2 | Snapshot bus read batching; no Sleep on UI reads | DONE |
| 3 | Chart roster strip + publish throttle | DONE |
| 4 | Persistence DRY + true append audit | DONE |
| 5 | Core/Service adaptive pacing + desk Core/UI split | DONE |
| 6 | TG verify state machine + Cloud ACK caps | DONE |

## Key changes

- `GsxMsCheapDirtyGate` / live pulse / age-band fingerprint — `Include/GSignalX/RosterViewModel.mqh`
- `DashRefreshPanel` reordered; session outcomes 5s; drag offset — Dashboard + `MultisymbolPanel.mqh`
- `GsxBusSnapBegin/End`, desk TTL 30s, `GsxBusAppendLine` — `BusIO.mqh`
- Prefetch queue + budget cut + Service backoff — `Core.mqh` / `GsignalX_Service.mq5`
- TG `VerifyBegin/Step/Pump`; Cloud ACK≤3; snap/trades split — `TelegramNotifier.mqh` + `CloudLoop.mqh`

## Operator soak (optional live)

1. Reattach Trade Center + Service; drag panel — should stay smooth
2. Idle desk: sparse full paints (heartbeat ~8s)
3. Verbose Core: watch `cycle_ms` vs Scale SLA (&lt;40/60/80 ms)
4. TG VERIFY click — status shows VERIFY… then ok without multi-second freeze

## Non-goals (honored)

- No change to joinDir, bias math, lot sizing, SL, or entry gate semantics
- No new DLLs / OS threads
