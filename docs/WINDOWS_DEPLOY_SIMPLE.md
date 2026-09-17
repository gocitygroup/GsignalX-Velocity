# Windows deploy — simple guide (non-technical)

**Product:** Gsignalx Velocity **2.14**  
**Goal:** Toolkit on Windows → MetaTrader 5 **without coding**.

Stuck? [Problems and fixes](#problems-and-fixes).  
Manual: [Gsignalx_Velocity_Users_Manual.html](Gsignalx_Velocity_Users_Manual.html) · Current cut: [RELEASE_v2.14](RELEASE_v2.14_Input_Reliability.md) · Tech: [DEPLOYMENT.md](../DEPLOYMENT.md)

### Best use after deploy (commercial desk)

1. **Profit Scouter** — stock **Profit CASH +100**; leave **CASH** mode ON for scalps; keep **Loss CASH OFF** until you want −N auto cuts. Teachable recipe: [Manual · Profit CASH](Gsignalx_Velocity_Users_Manual.html#profit-cash).  
2. **Telegram** — numeric chat IDs only, each user `/start`s the bot, allow `https://api.telegram.org`, press Trade Center **VERIFY** until **Verified** (soft: ≥1 chat OK). Recipe: [Manual · Telegram](Gsignalx_Velocity_Users_Manual.html#telegram).  
3. Micro/practice books: load matching `deploy/presets/*Practice*` / `*100EUR*` sets so floors match balance — do not leave stock 100 on a €20 account.

---

## What you need first

| Need | Why |
|---|---|
| **Windows 10 or 11** | Deploy scripts are for Windows |
| **MetaTrader 5** installed and opened at least once | Creates the Data Folder the scripts copy into |
| **A demo account** (recommended) | Practice before live or prop challenge |
| **This toolkit folder** | From GitHub ZIP or `git clone` |

You do **not** need to be a programmer. You only double-click a few files and click a few buttons in MT5.

---

## Part A — Get the toolkit onto your PC

### Option 1 — Download ZIP (easiest)

1. Open [GsignalX-Velocity on GitHub](https://github.com/gocitygroup/GsignalX-Velocity).  
2. Click the green **Code** button → **Download ZIP**.  
3. Unzip to a simple path, for example:  
   `C:\GSignalX\GsignalX-Velocity`  
   Avoid Desktop paths with many spaces if you can; short paths work better.  
4. Open the unzipped folder. You should see a folder named **`deploy`** and many `.mq5` files.  
   If you only see one nested folder, open that inner folder until you see `deploy`.

### Option 2 — Git clone (if you already use Git)

```text
git clone https://github.com/gocitygroup/GsignalX-Velocity.git
cd GsignalX-Velocity
```

Same rule: the folder that contains `deploy\` is the toolkit root.

---

## Part B — Install into MetaTrader 5 (one double-click)

1. Close charts that already run old GSignalX / ProfitScouter if you are upgrading (optional but cleaner).  
2. Open the toolkit folder → open **`deploy`**.  
3. Double-click:

| Situation | Double-click this |
|---|---|
| **First time** on this PC | `Click-and-Run-Deploy.bat` |
| **Upgrading** to a new Velocity version | `Clean-and-Deploy.bat` (wipes old toolkit files, then reinstalls) |

4. If Windows asks “Was this app downloaded from the internet?” → **More info** → **Run anyway**.  
5. If PowerShell asks about execution policy, the `.bat` already bypasses it for this script — do not change Windows policy yourself.  
6. A black window runs for a few minutes. Wait until it says **Done** or **CONFIRM SUMMARY**.  
7. Read the last lines. Leave the window open until you understand the next steps, then press any key.

**Healthy compile line looks like:**

```text
Result: 0 errors, 0 warnings
```

If you see errors, use [Problems and fixes](#problems-and-fixes) before continuing.

---

## Part C — Turn it on inside MetaTrader 5

Do these in order. Names must match **Navigator** exactly.

### C1 — Allow trading

1. Open MetaTrader 5.  
2. Toolbar: click **Algo Trading** so it is **green / ON**.  
3. Menu: **Tools → Options → Expert Advisors**  
   - Tick **Allow algorithmic trading**  
   - (Optional Telegram) Allow WebRequest for: `https://api.telegram.org`  
   - Inputs: `InpTgEnable=true`, bot token, **numeric** chat IDs only (not `@username`)  
   - Each recipient must open the bot and send `/start` before VERIFY  
   - Press Trade Center **VERIFY** until status shows **Verified** (probe message `[TG] verify` per chat) — see [Velocity Telegram Alerts](Gsignalx_Velocity_Users_Manual.html#telegram)

### C2 — Start the background services

In **Navigator** (Ctrl+N if hidden) → **Services**:

1. Right-click **`GsignalX_Service`** → Add / Start (Velocity multisymbol entries).  
2. Right-click **`ProfitScouter_Service`** → Add / Start (this one **closes** winners / adverse losers).  
3. Right-click **`ProfitOpportunity_Grader`** → Add / Start (ranks only — does not trade).

If a name is missing: right-click Navigator → **Refresh**, or re-run `Click-and-Run-Deploy.bat`.

### C3 — Attach the Trade Center (recommended)

1. Open any chart (e.g. EURUSD **M5**).  
2. Navigator → **Experts** → drag **`GsignalX_Multisymbol_Dashboard`** onto the chart.  
3. Common tab: allow Algo Trading.  
4. Use the same **Magic** number as the Service (default often `20260904`).

### C4 — Optional chart strip

Attach **`GsignalX_GocityGroup`** on M5 charts for the panel/strip. Keep chart entries deferred while Service owns the magic (default).

### C5 — Confirm again

Double-click **`deploy\Confirm-After-Start.bat`**.  
Aim for **SUMMARY: PASS**. Yellow WARN about stale bus is normal if Services were just started — wait ~60 seconds and run Confirm again.

---

## Recommended first desk (Velocity 2.14)

| Role | Program | Closes trades? |
|---|---|---|
| Entries (Topology A) | Trade Center DeskExecute ON | No |
| Entries (Topology B) | `GsignalX_Service` | No |
| Exits | `ProfitScouter_Service` | **Yes** |
| Grades | `ProfitOpportunity_Grader` | No |

**After start:** FIXED **0.01** · EQ **OFF** (unless wanted) · STOP once (clear pendings) · PROP CLEAR if LOCK · Scouter ON · REM unused pairs.

Full Best use: [RELEASE_v2.14](RELEASE_v2.14_Input_Reliability.md) · [Manual § System UI Best Use](Gsignalx_Velocity_Users_Manual.html#desk213)

---

## Problems and fixes

### Before deploy

| What you see | Likely cause | What to do |
|---|---|---|
| No `deploy` folder after ZIP | Opened the wrong nested folder | Open the folder that contains both `deploy` and `.mq5` files |
| “Windows protected your PC” | SmartScreen | More info → Run anyway (only for this toolkit you downloaded) |
| Script closes instantly | Wrong start folder | Always start `.bat` files from inside `deploy\` of the toolkit |

### During deploy / compile

| What you see | Likely cause | What to do |
|---|---|---|
| `No MT5 terminal data folders found` | MT5 never opened, or different Windows user | Open MT5 once, log into demo, close; run `.bat` again under the **same** Windows user |
| `Could not find MetaEditor64.exe` | Broker MT5 in a non-standard path | Find `MetaEditor64.exe` (Search in Start). Edit `Click-and-Run-Deploy.bat` / `Clean-and-Deploy.bat`: uncomment and set `set METAEDITOR=C:\full\path\MetaEditor64.exe` |
| `Result: N errors` (N > 0) | Incomplete copy or old include clash | Run `Clean-and-Deploy.bat`, then compile again. If still failing, open the `.log` next to the `.ex5` in the Data Folder |
| Antivirus quarantines `.ex5` / script | False positive | Allow / restore the MetaQuotes Terminal folder and the toolkit folder |
| `DEPLOY FAILED` / missing `.ps1` | Incomplete unzip | Re-download ZIP; do not move only the `deploy` folder alone |

### Inside MetaTrader

| What you see | Likely cause | What to do |
|---|---|---|
| Expert / Service missing in Navigator | Not deployed or needs refresh | Re-run deploy `.bat` → Navigator → Refresh |
| Smiley face with X / “AutoTrading disabled” | Algo Trading off | Turn toolbar Algo Trading **ON**; Common tab allow trading on the EA |
| No entries | Service not started, STOP/Prop LOCK, or weekend FX | Check Service running; Dashboard PROP=OK; PLAY/RUN; use liquid session |
| Positions never close | Scouter not started | Start `ProfitScouter_Service` (or attach DollarTarget and START) |
| Telegram fails / WebRequest error | URL not allowed or bad token | Tools → Options → Expert Advisors → allow `https://api.telegram.org`; Trade Center **VERIFY** until Verified ([Telegram Alerts](Gsignalx_Velocity_Users_Manual.html#telegram)) |
| TG VERIFY fail · chat not found | Wrong id, `@username` used, or user never `/start`ed bot | Use numeric chat IDs only; each person opens the bot and sends `/start`; drop invalid IDs; re-VERIFY |
| TG Verified but one chat silent | That chat id dead / never started | Remove bad id from ChatId2/3; fix `/start`; VERIFY fails until every configured chat accepts the probe |
| Token leaked / rotated | BotFather issued a new token | Update `InpTgBotToken` on Dashboard (+ Service if TG on); never commit tokens; VERIFY again |
| Bus / Grades WARN “stale” | Publishers not running yet | Start Service + Scouter + Grader; wait 1 minute; `Confirm-After-Start.bat` again |
| Two harvest engines fighting | Two Scouters on same book | Keep **one** ProfitScouter (Service **or** chart EA), not both on All symbols |

**Telegram input recipe (desk):** `InpTgEnable=true` · numeric `InpTgChatId1` / `2` / `3` only · leave unused chat slots empty · each recipient `/start`s the bot first · allow `https://api.telegram.org` · Trade Center **VERIFY**. VERIFY is **soft**: status becomes **Verified** if at least one chat receives `[TG] verify`; dead chats are skipped for sends (strip may show `skip chat …`). Prefer clearing unused/dead IDs. Never put `@username` in ChatId fields. If a token was shared outside MT5, revoke it in BotFather and paste the new token only into inputs.

### Confirm script

| What you see | Meaning | What to do |
|---|---|---|
| `SUMMARY: PASS` with WARN | Files/compile OK; bus may be idle | Start services; re-run Confirm-After-Start |
| `SUMMARY: FAIL` on Files | Copy did not land | Re-run Click-and-Run-Deploy; check Data Folder path |
| `SUMMARY: FAIL` on Compile | `.ex5` missing or errors in log | Fix MetaEditor path; Clean-and-Deploy; read compile log |
| Feedback file | Auto report | Open `deploy\feedback\CONFIRM_*.md` and keep it for support |

---

## Quick checklist (print / tick)

- [ ] Toolkit folder shows `deploy\` + `.mq5` files  
- [ ] Ran `Click-and-Run-Deploy.bat` (or Clean-and-Deploy for upgrade)  
- [ ] Compile lines show **0 errors, 0 warnings**  
- [ ] MT5 Algo Trading **ON**  
- [ ] Started `GsignalX_Service`, `ProfitScouter_Service`, `ProfitOpportunity_Grader`  
- [ ] Attached `GsignalX_Multisymbol_Dashboard` (same magic) — DeskExecute ON for Topology A  
- [ ] Automation shows **FIXED 0.01**; STOP once to clear stale pendings; PROP CLEAR if needed  
- [ ] Ran `Confirm-After-Start.bat` → PASS (or PASS + idle WARN)  
- [ ] Practising on **demo** before live / challenge  

---

## Still stuck?

1. Note the **exact error line** from the black window or Experts log.  
2. Open the newest file in `deploy\feedback\`.  
3. Ask for help with: Windows version, broker MT5 name, and that feedback file.  
4. Prefer demo until Confirm PASS and one full session is understood.
