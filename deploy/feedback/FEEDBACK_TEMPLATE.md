# Deployment feedback — TEMPLATE

Copy to `FEEDBACK_YYYY-MM-DD.md` and fill as you pass each gate.

| Field | Value |
|---|---|
| Operator | |
| Date | |
| PC / Windows user | |
| Demo only? | yes / no |
| Terminals in scope | |
| Magic (shared) | |
| Scouter Instance ID | |

## Gate log

### G0 Scope
- RESULT:
- NOTES:

### G1 Files
- RESULT:
- NOTES:

### G2 Compile
- RESULT:
- NOTES:

### G2b Functional (desk contracts)
- RESULT:
- NOTES: Confirm `-Gate Functional` / included in All

### G3 Runtime
- RESULT:
- NOTES:

### G4 Bus
- RESULT:
- NOTES:

### G5 Grades
- RESULT:
- NOTES:

### G6 Multi-terminal
- RESULT: PASS / FAIL / SKIPPED
- NOTES:

### G7 Sign-off
- RESULT:
- OVERALL:
- BLOCKERS:
- WHAT_WORKED:
- WHAT_TO_IMPROVE_NEXT:

**Where to send narrative feedback:** start with the [trading channel](https://t.me/+yURbcVkPi1kxNDg0) (**primary**) — macro overview for day trading: consult the composite current driver breakdown and the cited data sources for the quantitative basis. Share WHAT_WORKED / process notes in the [trading group](https://t.me/+ZDosSHfUCLU1ZGY0) (redact tokens and account numbers). Reproducible bugs → [GitHub Issues](https://github.com/gocitygroup/GsignalX-Velocity/issues).

## Topology A — Preferred live desk (DeskExecute ON; Service stopped or Yield ON)

One magic · FIXED 0.01 · EQ OFF unless floating-DD brake · Chart EA not filling same magic · Scouter owns BANK/CUT/FLAT.

| Case | PASS/FAIL | Notes |
|---|---|---|
| DeskExecute owns fills; Service yields on Desk OWN + desk HB | | |
| STOP pauses entries, cancels pendings, Scouter on, tickets remain | | |
| HALT pauses entries + Scouter, tickets remain | | |
| PLAY resumes entries + Scouter | | |
| STOP → ADD stays STOPPED until PLAY | | |
| FOLLOW fills latest signal direction | | |
| WAIT blocks new-dir while opposite magic exposure | | |
| FollowDir FOLLOW/BUY/SELL/WAIT (desk-wide + per-row MODE) | | |
| SPREAD enforces InpMaxSpreadPt | | |
| IGN bypasses desk max-spread on new entries | | |
| AUTOLOT sizes from risk% / ATR (fail-safe → fixed); survives reattach | | |
| FIXED uses InpFixedLot | | |
| EQ OFF / 5% / 10% / 20% blocks at Account DD; EQ OFF clears | | |
| PROP CLEAR unlocks + arms PLAY; PLAY alone does not clear Prop | | |
| REKICK needs PLAY | | |
| DIR present for all pairs; updates as each symbol finishes calc | | |
| ASAP winners-only; losers via adverse Auto / catastrophe SL | | |

## Topology B — Headless Service (DeskExecute OFF / detached; Service running)

Optional chart OWN defer. Same magic · one Scouter.

| Case | PASS/FAIL | Notes |
|---|---|---|
| Service OWN=1; chart does not double-fill | | |
| TC STOP → RUN=0; Scouter still harvests; no closes | | |
| TC HALT → RUN=0 + PS{id}_RUN=0; tickets remain | | |
| TC PLAY resumes RUN + Scouter | | |
| TC FOLLOW/WAIT live (Service honors GSX_MS_FLIPWAIT) | | |
| Pair START/STOP/SUSPEND never closes | | |
| Prop soft STOP → RUN=0; tickets remain; PROP CLEAR unlocks | | |
| Service spread/autolot via desk GVs / inputs | | |
| One Scouter All — single harvest owner | | |
| Bus + Grades after start | | |

## Raw script output (optional)

```
(paste Confirm-GSignalX.ps1 -Gate All output here)
```
