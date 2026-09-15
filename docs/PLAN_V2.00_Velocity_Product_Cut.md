# Plan v2.00 — Gsignalx Velocity Product Cut

**Date:** 2026-09-14 · **Status:** complete (hosts 2.00 + docs + Confirm packaging)  
**Scope:** Align primary hosts to `#property version "2.00"`, ship Operators/RELEASE docs and Velocity 2.00 manual for Service + Trade Center + Telegram + PropRisk + Scouter best use. No new trading logic; bus schema stays `GSX_BUS_VERSION = 1`.

## Decision lock

| Item | Choice |
|---|---|
| Product version | Hosts → `2.00` |
| Bus protocol | Keep `GSX_BUS_VERSION = 1` / `GSignalX/bus/v1` |
| Code | Version banners + descriptions only |
| Docs | Velocity HTML primary; `RELEASE_v2.00_Prop_Desk_Deploy.md` sign-off |
| Provenance | Feature work remains PLAN_V1.23 / V1.24 / V1.25 + Scouter v1.22 adverse gates |

## Host matrix

| Host | File | Version |
|---|---|---|
| Chart entry | `GsignalX_GocityGroup.mq5` | 2.00 |
| Entry Service | `GsignalX_Service.mq5` | 2.00 |
| Trade Center | `GsignalX_Multisymbol_Dashboard.mq5` | 2.00 |
| Scouter EA | `ProfitScouter_DollarTarget.mq5` | 2.00 |
| Scouter Service | `ProfitScouter_Service.mq5` | 2.00 |
| Grader | `ProfitOpportunity_Grader.mq5` | 2.00 |

`ProfitHarvest_Now.mq5` stays `1.10` (utility script).

## Deliverables

1. This plan + `docs/RELEASE_v2.00_Prop_Desk_Deploy.md`
2. Host version bumps
3. Velocity HTML / index / CREED HTML → 2.00
4. README, CREED.md, DEPLOYMENT*, README_ProfitScouter → 2.00
5. Confirm packaging asserts for `"2.00"`; Deploy compile 0/0; Confirm All

## Invariant

Entries (Service / chart) and exits (Scouter) remain independent. Dashboard / Service / PropRisk never reverse-close. Soft STOP only.
