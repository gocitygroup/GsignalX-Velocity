# Audit — ProfitScouter loser closes (evidence first)

Date: 2026-09-14  
Terminal journal: `010E047102812FC0C18890992854220E` (Logs `20260912`–`20260914`)  
Scope: static close-path inventory + runtime attribution + scenario matrix + policy.

---

## Phase 1 — Static close-path inventory

| Actor | Site | Can close red? | Gate |
|-------|------|----------------|------|
| ProfitScouter Core | `CloseTicket` default | No | `liveProfit < 0 && !allowLoss` → BLOCKED |
| ProfitScouter Core | `ClosePartial` | No | always refuses negatives |
| ProfitScouter Core | `HarvestWinners` / ACC/SYM/POS | No | `IsProfitableTicket` + `CloseTicket` |
| ProfitScouter Core | `HandleAdverseBarLossCut` | **Yes** | `allowLoss=true`, tag `ADVERSE-BAR` |
| ProfitHarvest_Now | `ClosePos` | No | own hard guard |
| GSignalX Scouter mode | opposite signal | No | `exit deferred to Profit Scouter` |
| GSignalX Signal mode | `CloseCurrent` | Yes | only if `InpExitMode != Scouter` |
| GSignalX | catastrophe SL | Yes (broker) | `InpStrategicStop*` attach |
| Loss-guard | removed | — | no `CutLosersToGuard` / `InpAccMaxLossMoney` in `.mq5`/`.mqh` |

**Invariant check (source):** `allowLoss=true` only at `CloseLosersOnSymbol` → adverse path. PASS.

**Known static risks scored:**

1. Adverse can cut once-green tickets after they go red (lock only fires while green).
2. `HandleAccount` / `HandleSymbol` return true after target hit even if `banked == 0`.
3. Service default adverse TF was `PERIOD_M15` vs M5 desk.
4. Dual host (Service + EA) same Instance ID can race closes.
5. Stale CREED docs still mention loss-guard / “close everything”.

---

## Phase 2 — Runtime attribution (2026-09-14)

| Metric | Count | Attribution |
|--------|------:|-------------|
| `ADVERSE-BAR]: closed` (negatives) | 26 | Software loser closes — **all** adverse |
| `ACC-TARGET]: closed` | 29 | Winners only (all profits &gt; 0) |
| `SYM-TARGET]: closed` | 2 | Winners only |
| Profit-path close with `(-` | **0** | No guard hole |
| `ProfitScouter ... BLOCKED - never closes` | **0** | Profit path never selected reds |
| `exit deferred to Profit Scouter` | 3+ | Scouter sanctity working |
| `CloseCurrent` | 0 | Signal reverse-close not active |
| Broker SL journal hits | 0 | Not the observed path |
| Dual-host `rc=10036` | 1+ | Service raced EA after EA already closed |
| Adverse notify with `streak=3 closed≥1` | 554 | Rules: dir set, streak &gt; minBars(2) |

**Sample loser close:**  
`ProfitScouter [ADVERSE-BAR]: closed #… BTCUSD (-7.20)` + `ADVERSE-BAR BTCUSD dir=1 streak=3 closed=1`

**Verdict:** Unknown closes → **ADVERSE-BAR**. Bar/signal experience rules **were** satisfied. What was missing is **trade hold experience**: status lines showed symbol baskets at **age 0 min** while adverse was armed, and large reds (e.g. -50.45, -33.02) show once-green tickets can still be adverse-cut after flipping red.

---

## Phase 3 — Scenario matrix

| Scenario | Result | Evidence |
|----------|--------|----------|
| ASAP banks only floor winners; reds untouched | **PASS** | ACC/SYM closes all green; 0 red profit tags |
| Profit lock only while green | **PASS** | Code `profit > 0`; no red PROFIT-LOCK |
| AUTO OFF / STOP freezes adverse | **PASS** (code) | Live day had AUTO ON |
| Missing bus dir skips adverse | **PASS** (code) | `InpAdverseRequireSignal` |
| Streak ≤ minBars skips | **PASS** | Fires at streak 3 with minBars 2 |
| Scouter opposite → defer | **PASS** | Journal defer; CloseCurrent=0 |
| BUY + sell streak closes same-symbol reds | **PASS** | Designed behavior; 26 closes |
| Once-green then red + adverse | **FAIL intent** | Allowed today; large adverse reds |
| Target hit, banked=0 early return | **FAIL** | Code returns true unconditionally |
| Dual Service+EA scavengers | **FAIL ops** | rc=10036 race |
| Service M15 vs M5 desk | **RISK** | Service input default M15 |

---

## Phase 4 — Policy decision

**Chosen package: B — Adverse too aggressive (tighten gates)**  
Not C (no profit-path guard hole). Not D alone (attribution is adverse, not SL). Not A (age-0 / once-green cuts need product change).

### Implementation package (v1.22)

1. **`InpAdverseMinAgeMin`** (default **15**) — do not adverse-cut tickets younger than N minutes (trade experience / hold).
2. **`InpAdverseProtectOnceGreen`** (default **true**) — skip adverse on tickets with recorded peak &gt; 0 or `lockArmed`.
3. **Claim fire GV before closes** — reduce dual-host double attempt on the same bar.
4. **Service default adverse TF → `PERIOD_M5`** — align with M5 desk.
5. **Early-return fix** — account/pair layers return true only if `banked > 0`.
6. **Confirm greps** — static loser-safety invariants in `Confirm-GSignalX.ps1`.
7. **Doc sync** — CREED/README remove loss-guard / “close everything” wording; document new adverse gates.

---

## Phase 5 — Implementation (v1.22) — DONE

Deployed + compiled on terminal `010E047102812FC0C18890992854220E` (0 errors).

| Change | Status |
|--------|--------|
| `InpAdverseMinAgeMin=15` | Done (both hosts) |
| `InpAdverseProtectOnceGreen=true` | Done |
| Claim fire GV before closes | Done |
| Service adverse TF → M5 | Done |
| Early-return only if `banked > 0` | Done (ACC/SYM target+trail+window) |
| Confirm `LoserSafety` gate | Done — PASS |
| CREED/README stale wording | Done |
| Audit doc | This file |

**Operator after deploy:** restart ProfitScouter Service and re-attach DollarTarget (or Reset inputs) so new adverse inputs load. Prefer **one** scavenger per Instance ID.

