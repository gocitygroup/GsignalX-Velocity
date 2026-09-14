# Auto confirm report

- Gate: LoserSafety
- Terminal: C:\Users\babat\AppData\Roaming\MetaQuotes\Terminal\010E047102812FC0C18890992854220E
- When: 2026-09-14T19:00:25.3165609+02:00
- Hard failures: 0

```
GSignalX Confirm  2026-09-14 19:00:25
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

SUMMARY: PASS (0 hard failures; see WARN lines)
```

