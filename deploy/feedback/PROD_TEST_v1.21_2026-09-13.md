# Production confirm — GSignalX v1.21 commercial pre-flight

- Gate: All (automated) + commercial checklist pending operator demo
- Terminal: C:\Users\babat\AppData\Roaming\MetaQuotes\Terminal\010E047102812FC0C18890992854220E
- When: 2026-09-13T18:29:33+02:00
- Product version: **GSignalX 1.21** / ProfitScouter 1.21
- Release doc: `docs/RELEASE_v1.21_Commercial_Deploy.md`

## Automated results

| Gate | Result |
|---|---|
| Files (incl. LotSizing + ChartPanel) | **PASS** |
| Compile (0 errors / 0 warnings all modules) | **PASS** |
| Bus root + index + scouter snapshot | **PASS** (partial) |
| Heartbeat for indexed tid | **FAIL** — start/reattach GSignalX with bus ON |
| Grades latest.json | **PASS** (stale ts WARN — restart Grader) |

Hard failures: **1** (missing heartbeat — expected until EA is running on chart).

## Operator next (commercial)

1. Algo Trading ON → start Scouter + Grader Services  
2. Re-attach **GsignalX v1.21** on M5 charts (remove old instance first)  
3. Confirm panel **data rows visible**  
4. Run `deploy\Confirm-After-Start.bat` until Bus heartbeat PASS  
5. Complete demo checklist in RELEASE doc → sign-off before live  

```text
COMMERCIAL SIGN-OFF v1.21 | Demo | Operator: ____ | Date: ____ | PASS / FAIL
```
