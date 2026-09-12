# Weekend crypto verification — 2026-09-12 (Saturday)

| Field | Value |
|---|---|
| Operator | Auto (Cursor agent) |
| Date | 2026-09-12 (Saturday) |
| Terminal | IC Markets Global `010E047102812FC0C18890992854220E` |
| Account | ICMarketsSC-Demo `51498514` |
| Demo only? | yes |
| Code change? | none (plan: already enabled) |

## Checklist results

### 1) Crypto chart + PLAY → Market OPEN / trading path live

**PASS**

- Charts: `ETHUSD`, `SOLUSD` with `InpCryptoAllowWeekend=true`, `InpBlockWeekend=true`, `InpCryptoExtraList=` (British Pound profile).
- Live bus (updated continuously Sat evening):

| Symbol | is_crypto | market_open | weekend | stale_tick | bus age |
|---|---|---|---|---|---|
| ETHUSD | true | true | false | false | ~0 min |
| SOLUSD | true | true | false | false | ~0 min |

- Experts log: `SOLUSD` received `PLAY: new entries enabled` / `PLAY armed, waiting: spread` (spread gate only — not weekend).
- `ETHUSD` drill window started and later expired while market stayed open.
- Tick folders on Demo: BTCUSD/ETHUSD last write **2026-09-12**; FX last write **2026-09-10**.

### 2) FX chart → weekend blocked with defaults

**PASS** (behavioral + config; panel text not refreshed without ticks)

- Same profile: `EURUSD` / `GBPUSD` / `XAUUSD` have `InpBlockWeekend=true`, `is_crypto=false`.
- Bus files for FX **frozen since 2026-09-10 ~21:40** (~45h): no Saturday `OnTick` → no new entries / no bus republish.
- Gate simulation with defaults: non-crypto Sat/Sun → `IsMarketOpen` reason `weekend`.
- Note: without FX ticks, the chart panel may not redraw to `CLOSED (weekend)` until a tick arrives; the entry path is still blocked (no tick / weekend gate / fleet fill skips closed market).

### 3) Crypto detection / ExtraList

**PASS — no ExtraList fix needed**

- `ETHUSD` / `SOLUSD` classified `is_crypto:true` with empty `InpCryptoExtraList`.
- Name-token check covers BTC/ETH/SOL and common suffixes (`.a`, `m`).

## Sign-off

| Item | Result |
|---|---|
| Weekend crypto enablement | Already on — verified live |
| Chart PLAY required | Confirmed (logs) |
| FX weekend protection | Confirmed (no Sat activity + inputs) |
| Code / ExtraList change | None |
| OVERALL | PASS |
