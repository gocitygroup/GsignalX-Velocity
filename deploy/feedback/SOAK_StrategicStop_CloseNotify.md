# Soak — Strategic Stop + Close Notify (V2.16+)

Operator live soak after deploy + recompile of Dashboard, Chart EA, Service, ProfitScouter EA/Service.

## What changed

- Catastrophe broker SL uses DRY `StrategicStop.mqh`: signal ATR × class mult, **D1 ATR floor**, H1 range floor, spread floor, hard cap, attach-time jitter.
- Lot sizing unchanged (signal ATR × `InpStopMult`).
- Pending fill one-shot SL re-anchor.
- Telegram CLOSE enriched: exit, ticket, SL/TP, source, reason detail (incl. BROKER-SL strat meta).

## Compile / deploy

Recompile in MetaEditor (or `Deploy-GSignalX.ps1 -Compile`):

- [ ] `GsignalX_Service.mq5` — 0 errors
- [ ] `GsignalX_Multisymbol_Dashboard.mq5` — 0 errors
- [ ] `GsignalX_GocityGroup.mq5` — 0 errors
- [ ] `ProfitScouter_DollarTarget.mq5` / `ProfitScouter_Service.mq5` — 0 errors

## Attach checks (demo)

Open one FX, one CMD (e.g. XAU), one CR (e.g. BTC) under Scouter mode. Experts log should show:

```
catastrophe SL … | class=FX|CMD|CR atrSig=… atrD1=… base=… jitter=…% final=…
```

| Check | FX | CMD | CR | Pass? |
|-------|----|-----|----|-------|
| SL attached (Scouter) | | | | |
| CR/CMD finalDist ≥ FX for similar signal ATR scale | | | | |
| Lot size still from sizing ATR (not D1) | | | | |
| Jitter within ±`InpStratStopJitterPct` of base | | | | |
| Pending fill → SL refresh log once | | | | |

## Close notifications

| Event | Expect TG CLOSE | Pass? |
|-------|-----------------|-------|
| Scouter bank (ACC-TARGET / ATR-TRAIL / …) | `reason=TAG \| detail…` + `#ticket` + SL | |
| Broker SL hit | `reason=BROKER-SL \| BROKER-SL hit \| class=…` + exit/SL | |
| Manual client close | `reason=CLIENT` | |

## BROKER-SL rate (CMD/CR)

Track before/after over a comparable session window:

| Window | Pair class | Opens | BROKER-SL closes | Soft (Scouter) closes |
|--------|------------|-------|------------------|-----------------------|
| Before | CMD/CR | | | |
| After  | CMD/CR | | | |

Expect: fewer premature `BROKER-SL` on crypto/commodities; Scouter soft exits get more room.

## Regression

- [ ] PLAY/STOP never closes trades
- [ ] Prop daily gates unchanged
- [ ] Desk deal-watch ownership (Desk primary / Chart failover)
- [ ] Adverse / CASH / LAYER / PROFIT-LOCK tags still emit
