# Plan v1.24 — Multisymbol Dashboard UI

**Date:** 2026-09-14 · **Status:** implemented  
**Scope:** Shared MultisymbolPanel + Dashboard EA + chart compact roster strip; FILE_COMMON roster persistence; Service hot-reload; Scouter owns exits.

## Architecture (option 3)

- Shared `Include/GSignalX/MultisymbolPanel.mqh` (Full + Compact)
- Host `GsignalX_Multisymbol_Dashboard.mq5`
- Chart EA embeds compact roster strip (`InpShowRosterStrip`)
- Service `Core.mqh` hot-reloads `roster/{magic}.csv` on `GSX_SVC_ROSTER_SEQ_{magic}`

## Persistence

| Store | Content |
|---|---|
| `GSignalX/bus/v1/roster/{magic}.csv` | Live symbol CSV |
| `GSX_SVC_ROSTER_SEQ_{magic}` | Reload stamp |
| `GSX_SYM_MUTE_{magic}_{canon}` | Per-symbol mute |
| `GSX_MS_PNLX/Y_{ChartID}` | Dashboard position |
| `GSX_MS_PAGE_{magic}` | Page index |
| `GSX_MS_FLEET_TARGET_{magic}` | Fleet target override (>0) |

Remove from roster does not close positions. Mute blocks Service fills only.

## Modules

RosterStore, RosterViewModel, MultisymbolPanel; Core reload + mute-aware fill; Dashboard Expert; chart strip.

## Gates

Compile 0/0; persist across restart; ADD → Service fill; OWN coexistence; mute skip; no reverse-close; `GSXMS_` vs `GSX_` object isolation.
