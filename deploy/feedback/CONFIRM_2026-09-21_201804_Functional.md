# Auto confirm report

- Gate: Functional
- Terminal: C:\Users\babat\AppData\Roaming\MetaQuotes\Terminal\010E047102812FC0C18890992854220E
- When: 2026-09-21T20:18:04.9876794+02:00
- Hard failures: 3

```
GSignalX Confirm  2026-09-21 20:18:04
TerminalDataPath=C:\Users\babat\AppData\Roaming\MetaQuotes\Terminal\010E047102812FC0C18890992854220E
BusRoot=C:\Users\babat\AppData\Roaming\MetaQuotes\Terminal\Common\Files\GSignalX\bus\v1

=== GATE Functional (desk contracts static) ===
PASS  ScoutLink.mqh
PASS  ScoutLink shared PS{id}_RUN helpers
PASS  Service RUN/OWN GV helpers
PASS  RosterStore FOLLOW/WAIT GV helpers
PASS  Core hot-reloads FOLLOW/WAIT each cycle
PASS  Single WAIT+FollowDir gate GsxAllowEntry
PASS  Trade Center HALT pauses linked Scouter (no closes)
PASS  Trade Center STOP entries-only (Scouter keeps harvesting)
PASS  Trade Center PLAY resumes Service RUN + Scouter
PASS  Dashboard scout link inputs wired
PASS  Chart SPREAD/AUTOLOT/EQ GV names present
PASS  Chart HALT pauses entries + Scouter
PASS  PropRisk soft STOP (RUN=0, no PositionClose)
PASS  EntryExec blocks reverse-closes
PASS  Scouter winners-only harvest + adverse loser path
PASS  ProfitScouter uses shared ScoutLink
PASS  OWN double-fill deferral contract present
PASS  Trade Center sizing 1280/32 (Functional)
PASS  LotSizing freeze (CalcLot/Normalize/DD signatures)
PASS  MarketGates GsxSpreadOK freeze
PASS  V2.12 class-aware spread + crypto session/hour exempt
PASS  Fleet floating P/L freeze
PASS  RosterStore FollowDir + TF GV helpers
PASS  EntryExec shared FollowDir gate
PASS  Core enforces FollowDir + live TF
PASS  Trade Center FollowDir UI + entries-only copy
PASS  FollowDir Wait mode (Follow/Buy/Sell/Wait)
PASS  Retire cleanup + SWAP + start/stop-all
PASS  Signal-age gate + multi-fill + dir-change cache
PASS  Chart defers roster symbols when Service owns
PASS  Chart strip signal age + FollowDir status fields
PASS  Cross-terminal freshest signal + desk mirror
PASS  Service publishes signals while STOPPED
PASS  Roster canon dedupe on ADD/load
PASS  Trade Center quadrant section markers
PASS  True dual-column GsxLaySplit2 + quad drawers
PASS  Practice coach muted by InpShowPractice
PASS  V2.07 onboard priority calc + immediate bus
PASS  V2.07 onboard fill claim exception
PASS  V2.07 COMPUTE/LIVE/STALE/FLAT DIR UX
PASS  V2.07 lastDir GV persistence
PASS  V2.07 SVC OFF + heartbeat health chip
PASS  V2.07 fill_skip on bus + desk row
PASS  V2.07 desk-mirror-first + 250ms freshest cache
PASS  V2.07 first-fill SignalMaxAge exempt
PASS  V2.08 FleetFillCheck uses ChartAutoEntriesAllowed only
PASS  V2.08/V2.14 ActivatePair onboard without forced PLAY
PASS  V2.08 onboard settle only on fill/terminal
PASS  V2.08 desk SPREAD/IGN GV + UI
PASS  V2.08 per-row REM + safe carousel REM
PASS  V2.08 ScoutLink default false + OWN/HB split
PASS  V2.09/V2.13 desk AUTOLOT/EQ GVs + Core poll/gate + UI
PASS  V2.09 Scouter BANK/CUT/FLAT + MessageBox (loser guard intact)
PASS  V2.10 bus DIR uses joinDir override
PASS  V2.10 enabled-trigger majority joinDir fallback
PASS  V2.10 onboard history retry (not terminal)
PASS  V2.10 Service/Core PLAY drill window + fill gate
PASS  V2.10.1 PLAY/ADD drill kick + ADD under PLAY refresh
PASS  V2.11 ActivatePair chart/desk parity
PASS  V2.12 ADD/re-ARM onboard kick (keep LastDir)
PASS  V2.12 desk live DIR from Core
PASS  V2.12 CMD/CR fleet diversity + oil/crypto alias resolve
PASS  V2.12 per-pair engine series (no chart DIR bleed)
PASS  V2.10 anchor clamp + pending hygiene
PASS  V2.10 desk DRILL status chip
PASS  V2.12 Dashboard DeskExecute hosts Core
PASS  V2.12 Core host tag + OWN claim
PASS  V2.12 Desk vs Service yield mutual exclusion
PASS  V2.12 ADD button survives tight UR layout
PASS  V2.13 discrete EQ OFF/5/10/20 pads
PASS  V2.13 Trade Info EQ guide + Prop peak DD + session outcomes
PASS  V2.13 Friday/NEWS non-sticky Prop windows
PASS  V2.13.1 eased EQUITY_DD (default off + grace + PROP CLEAR)
PASS  V2.13 Core PropOnNewEntry + continuous fleet + cycle_ms
PASS  V2.13 host-scoped HB + per-canon bus cache + yield hysteresis
PASS  V2.13 Drill REKICK + engine prefetch
PASS  V2.13.2 stale-pair trigger lifetime (orphan pendings + STOP hygiene)
PASS  V2.14 AUTOLOT seed-if-missing (no OnInit stomp)
PASS  V2.14 chart AutoLot/EQ bridge to desk GSX_MS_* GVs
PASS  V2.14 EntryExec AUTOLOT ATR sizing + AUTO->FIX signal
PASS  V2.14 instant Desk yield + ActivatePair preserves STOP
PASS  V2.14 fleet multi-fill claim cooldown bypass
PASS  V2.14 Prop day-rollover clear + SignalBus Friday hour
PASS  V2.15 host versions Dashboard/Service
PASS  V2.14.1 RR publish-as-ready (PublishBusIndex after bar recalc)
PASS  V2.14.1 RosterStore seq-gated in-memory cache
PASS  V2.14.1 cycle fleet snap reuse (PublishBus + fills)
PASS  V2.14.1 snapshot batched floating PL map
PASS  V2.14.1 desk-mirror fast path age <=15s
PASS  V2.15 AccountBook one-scan (Fleet + Core + RosterViewModel)
PASS  V2.15 EngCompactTip + tip scalars (Core/Service)
PASS  V2.15 BusReadSized + desk-mirror coalesce (tid on full-sync/first)
PASS  V2.15 AtrHandleReuse + prune on REM/roster
PASS  V2.15 Scale presets Small/Medium/Large + InpScaleProfile
PASS  MultisymbolPanel GsxMsPageStep + wheel hit-test
PASS  MultisymbolPanel page clamp + compact CR trim
PASS  Dashboard + Chart EA CHART_EVENT_MOUSE_WHEEL enable
PASS  V2.15 CloseTrigger emit/consume + audit jsonl + BROKER-SL
PASS  V2.15 Scouter CloseTicket emit + magic-filter WARN
FAIL  V2.15 FormatCloseEx missing
FAIL  V2.15 TgDealWatch reason path missing
PASS  V2.15 OVERFILL emit + catastrophe SL open log
FAIL  V2.15 EntryExec SL open log missing
PASS  V2.16 SettingsNotify LOAD/Announce/pending + EnqueueTagged
PASS  V2.16 GsxTgEnqueueTagged (no drain on enqueue)
PASS  V2.16 MultisymbolPanel prop-critical SETTINGS (no PAGE)
PASS  V2.16 Desk LOAD + drain pending
PASS  V2.16 Scouter arm pending (no HTTP)

SUMMARY: FAIL (3 hard failure(s))
```

