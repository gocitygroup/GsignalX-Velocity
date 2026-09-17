# Deployment feedback — V2.14.1 desk perf

| Field | Value |
|---|---|
| Operator | Auto (agent) |
| Date | 2026-09-17 |
| Demo only? | n/a (static + compile confirm) |
| Terminals in scope | AllTerminals deploy |
| Magic (shared) | (operator) |
| Scouter Instance ID | (operator) |

## Gate log

### G0 Scope
- RESULT: PASS
- NOTES: 2.13 desk + 2.14 cut; perf = publish-as-ready, roster cache, fleet snap, PL batch, mirror ≤15s

### G1 Files
- RESULT: PASS

### G2 Compile
- RESULT: PASS (0 errors / 0 warnings all hosts, all terminals)

### G2b Functional (desk contracts)
- RESULT: PASS
- NOTES: Confirm `-Gate All` includes V2.13 / V2.14 / **V2.14.1** markers

### G3 Runtime
- RESULT: PENDING (operator live Topology A)
- NOTES: Reattach Trade Center after deploy; FIXED 0.01; STOP once; REM unused; PLAY live book

### G4 Bus
- RESULT: PASS (WARN idle/stale HB OK until publishers warm)

### G5 Grades
- RESULT: PASS (WARN stale until Grader running)

### G6 Multi-terminal
- RESULT: SKIPPED / WARN (1 indexed tid)

### G7 Sign-off
- RESULT: PASS (static/compile)
- OVERALL: Ready for Topology A soak
- BLOCKERS: none for code path
- WHAT_WORKED: V2.14.1 Functional markers; 0/0 compile
- WHAT_TO_IMPROVE_NEXT: complete live soak checklist below

## Topology A — Preferred live desk (operator)

| Case | PASS/FAIL | Notes |
|---|---|---|
| DeskExecute owns fills; Service yields on Desk OWN + desk HB | | |
| STOP / HALT / PLAY / Scouter invariants | | |
| STOP → ADD stays STOPPED until PLAY | | |
| AUTOLOT/EQ survive reattach | | |
| EQ 5% fill_skip; EQ OFF clears | | |
| PROP CLEAR / REKICK needs PLAY | | |
| DIR present for all pairs; updates as each symbol finishes calc | | |

Confirm output: `deploy/feedback/CONFIRM_2026-09-17_031142_All.md`
