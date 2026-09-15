# Auto confirm report

- Gate: LoserSafety
- Terminal: C:\Users\babat\AppData\Roaming\MetaQuotes\Terminal\010E047102812FC0C18890992854220E
- When: 2026-09-14T23:46:57.4188465+02:00
- Hard failures: 0

```
GSignalX Confirm  2026-09-14 23:46:57
TerminalDataPath=C:\Users\babat\AppData\Roaming\MetaQuotes\Terminal\010E047102812FC0C18890992854220E
BusRoot=C:\Users\babat\AppData\Roaming\MetaQuotes\Terminal\Common\Files\GSignalX\bus\v1

=== GATE LoserSafety (static) ===
PASS  no loss-guard symbols in Core.mqh
PASS  adverse allowLoss path present (1 CloseTicket true call(s))
PASS  ADVERSE-BAR tag present
PASS  CloseTicket loser hard-guard present
PASS  adverse min-age + once-green gates in Core
PASS  AdverseEligibleLoser present
PASS  host shells expose InpAdverseMinAgeMin
PASS  Service adverse TF default mentions PERIOD_M5
PASS  ProfitHarvest_Now loser guard present
PASS  GSignalX Scouter opposite-signal defer present
PASS  GsignalX_Service is chart-free roster service
PASS  Service OWN GV + chart coexistence hooks present
PASS  chart defer input + Service fleet fill present
PASS  SignalBus publishes fleet_owner
PASS  Multisymbol Dashboard host present (no closes)
PASS  RosterStore CSV + seq persistence
PASS  Core hot-reload + pair-state-aware fleet fill
PASS  MultisymbolPanel GSXMS_ + chart roster strip input
PASS  TelegramNotifier WebRequest + verify + queue
PASS  PropRisk challenge gates present
PASS  Dashboard 2.00 Telegram + Prop inputs
PASS  Trade Center button sizing 640/28
PASS  SymbolClass.mqh
PASS  SessionClock.mqh
PASS  EventGate.mqh
PASS  RosterStore pair state START/STOP/SUSPEND
PASS  Trade Center category tabs + state + session strip
PASS  Dashboard EventGate + v1.26 wiring
PASS  Core honors pair state + event SKIP blocks
PASS  Velocity 2.00 host versions (6/6)
PASS  GSX_BUS_VERSION remains 1 (product 2.00 keeps bus schema 1)

SUMMARY: PASS (0 hard failures; see WARN lines)
```

