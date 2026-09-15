# GSignalX Multi-Terminal Connector Bus (v1)

Broker-agnostic publish/grade fabric for every MT5 terminal on the same PC via **Common Files** (`FILE_COMMON`). Grades are **advisory** in phase 1 — each terminal still executes its own closes through ProfitScouter.

**Ship / install:** follow [DEPLOYMENT.md](DEPLOYMENT.md) (scripted copy + compile + first-run + verify).

## Deploy map

| Repo path | Copy to |
|---|---|
| `Include/GSignalX/*.mqh` | `<Terminal>\MQL5\Include\GSignalX\` |
| `Include/ProfitScouter/*.mqh` | `<Terminal>\MQL5\Include\ProfitScouter\` |
| `GsignalX_GocityGroup.mq5` | `MQL5\Experts\` |
| `GsignalX_Multisymbol_Dashboard.mq5` | `MQL5\Experts\` |
| `GsignalX_Service.mq5` | `MQL5\Services\` |
| `ProfitScouter_DollarTarget.mq5` | `MQL5\Experts\` |
| `ProfitScouter_Service.mq5` | `MQL5\Services\` |
| `ProfitOpportunity_Grader.mq5` | `MQL5\Services\` |
| `ProfitHarvest_Now.mq5` | `MQL5\Scripts\` |

Common Files root (shared across terminals on one Windows user profile):

`%APPDATA%\MetaQuotes\Terminal\Common\Files\GSignalX\bus\v1\`

Registry files (MT5 directory listing is unreliable across builds):

- `terminals/_index.txt` — one `tid` per line (heartbeat publishers append)
- `terminals/{tid}/signals/_list.txt` — signal JSON filenames for that terminal

## Bus layout

```
GSignalX/bus/v1/
  terminals/{tid}/heartbeat.json
  terminals/{tid}/signals/{symbol_canon}.json
  terminals/{tid}/scouter/snapshot.json
  grades/latest.json
```

`{tid}` = stable 8-hex hash of `TERMINAL_DATA_PATH|login|server`.

### Schema version

Every JSON document includes `"version":1`. Readers **ignore** unknown versions.

### heartbeat.json

```json
{
  "version": 1,
  "ts": 1710000000,
  "tid": "a1b2c3d4",
  "source": "gsignalx|scouter",
  "login": 123456,
  "server": "Broker-Demo",
  "company": "Broker Ltd",
  "currency": "USD",
  "balance": 10000.0,
  "equity": 10050.0,
  "free_margin": 8000.0,
  "connected": true,
  "trade_allowed": true
}
```

### signals/{symbol}.json

```json
{
  "version": 1,
  "ts": 1710000000,
  "tid": "a1b2c3d4",
  "symbol": "EURUSDm",
  "symbol_canon": "EURUSD",
  "direction": 1,
  "bull": 2,
  "bear": 1,
  "min_agree": 2,
  "mode": "advanced",
  "is_crypto": false,
  "in_session": true,
  "weekend": false,
  "friday_late": false,
  "swing_window": true,
  "spread_pt": 12,
  "max_spread_pt": 40,
  "stale_tick": false,
  "market_open": true
}
```

### scouter/snapshot.json

```json
{
  "version": 1,
  "ts": 1710000000,
  "tid": "a1b2c3d4",
  "instance_id": 1,
  "currency": "USD",
  "floating": 42.5,
  "acc_peak": 55.0,
  "acc_armed": true,
  "acc_target": 100.0,
  "pos_target": 10.0,
  "sym_target": 25.0,
  "window_start": 30,
  "window_end": 60,
  "positions": 3,
  "trading_ready": true,
  "last_action": "none",
  "symbols": [
    {
      "symbol": "XAUUSD",
      "symbol_canon": "XAUUSD",
      "count": 1,
      "profit": 18.2,
      "peak": 22.0,
      "armed": true,
      "age_min": 45,
      "spread_pt": 25
    }
  ]
}
```

### grades/latest.json

```json
{
  "version": 1,
  "ts": 1710000000,
  "grader_tid": "ffff0001",
  "entries": [
    {
      "kind": "entry",
      "tid": "a1b2c3d4",
      "symbol_canon": "EURUSD",
      "score": 87.5,
      "direction": 1,
      "reasons": "agree;session;swing;spread_ok"
    }
  ],
  "harvests": [
    {
      "kind": "harvest",
      "tid": "a1b2c3d4",
      "symbol_canon": "XAUUSD",
      "score": 91.0,
      "profit": 18.2,
      "reasons": "near_target;armed;in_window"
    }
  ]
}
```

## Scoring model (0–100)

### Entry / swing-scale (`GsxGradeEntry`)

| Factor | Weight | Notes |
|---|---|---|
| Engine agreement | 30 | `bull`/`bear` vs `min_agree` |
| Session / weekend / Friday | 25 | broker session + calendar guards (`weekend=false` for crypto weekend-exempt symbols) |
| Swing window | 20 | configurable London–NY style hour band (server time) |
| Spread health | 15 | vs `max_spread_pt` |
| Tick freshness / market open | 10 | stale tick penalty |

### Harvest (`GsxGradeHarvest`)

| Factor | Weight | Notes |
|---|---|---|
| Progress to hard target | 35 | profit / target |
| Trail proximity | 25 | armed + give-back distance |
| Time window | 20 | age inside start–end minutes |
| Account heat | 10 | free margin / floating |
| Liquidity proxy | 10 | spread + session |

## Reliability rules

1. **Atomic writes**: write `*.tmp` then `FileMove` replace under `FILE_COMMON`.
2. **Heartbeat TTL**: Grader skips terminals older than `InpHeartbeatTTLSec` (default 15).
3. **No cross-terminal close** in phase 1 — grades are recommendations only.
4. Keep distinct `InpInstanceID` + magic filters to avoid dual-close races on one terminal.
5. Ignore JSON with missing/unknown `version`.

## Compile order (MetaEditor)

1. Confirm Includes are under `MQL5\Include\GSignalX\` and `...\ProfitScouter\`.
2. Compile `ProfitScouter_Service.mq5` (Services).
3. Compile `ProfitScouter_DollarTarget.mq5` (Experts).
4. Compile `ProfitOpportunity_Grader.mq5` (Services).
5. Compile `GsignalX_GocityGroup.mq5` (Experts).
6. Compile `ProfitHarvest_Now.mq5` (Scripts) — unchanged one-shot helper.

Expect **0 errors**. Warnings about unused inputs are acceptable.

Verified compile (MetaEditor, IC Markets terminal data folder): all five programs — **0 errors, 0 warnings**.

## Multi-terminal demo checklist

1. Install Includes + programs on **two** terminals that share the same Windows user (same Common Files).
2. Terminal A: start `ProfitScouter_Service` with `InpBusEnable=true`.
3. Terminal A: attach `GsignalX` on a liquid symbol with `InpBusEnable=true`.
4. Terminal B: start `ProfitOpportunity_Grader`.
5. Confirm files appear under Common Files `GSignalX\bus\v1\terminals\...\`.
6. Confirm `grades\latest.json` lists entry and/or harvest rows within one Grader cycle.
7. On Terminal A Experts log / GsignalX panel: top grade line updates.
8. Stop Terminal A publishers → after TTL, Grader drops that `tid` from ranks.
9. Symbol suffix check: `EURUSDm` and `EURUSD` both canonicalize to `EURUSD`.

## Phase 2 (next)

- Soft command inbox `commands/{tid}/inbox.json` for harvest *recommendations* only.
- Optional `WebRequest` bridge to an external control plane.
