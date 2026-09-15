# Plan v2.01 — Production Hardening (20–30 symbols + multi-terminal bus)

**Date:** 2026-09-15 · **Status:** implemented  
**Scope:** Reliability/performance patch train on Velocity 2.00 hosts. Bus schema stays `GSX_BUS_VERSION = 1`.

## Goals

- Sustain **20–30 symbols** per magic without bar-open engine storms
- Harden FILE_COMMON bus for **several terminals** (confirm target ≤8 writers)
- Headless **PropRisk** on Service; TG off the hot path
- Trade Center adaptive layout + docs mobile polish

## Delivered

| Area | Change |
|---|---|
| BusIO | No delete-gap atomic replace; `GsxBusReadAllRetry`; register cache + retry |
| SignalBus | `GsxBusFleetSnap` once/publish; `WriteSymbolEx`; dirty fingerprint |
| Core | Engine budget round-robin; dirty bus + full sync; roster engine preserve |
| Service | Prop poll ≥2s; TG `ProcessQueueEx(...,1)`; budget/lookback inputs |
| Chart | Bus publish DRY via SignalBus |
| Dashboard | Refresh 1000ms; Prop 2s; dirty fingerprint redraw; TG budget 1 |
| Panel | Adaptive width/page/row; contrast; STALE direction chip |
| Docs | Shared CSS/JS; SVG assets; mobile chapter select; CREED UTF-8 archive |
| Ops | `GSignalX_Service_PropDesk_30.set`; Confirm `ProdHardening` + bus race probe |

## Invariants

Entries never reverse-close · Prop/PLAY soft RUN only · one fill/cycle · bus `version:1`

## Next (v2.02 if needed)

Incremental/rolling StdDev in `GsxEngStdDevSeries` if bar-open wall time still exceeds cycle budget under 30 symbols.
