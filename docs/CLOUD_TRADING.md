# Cloud trading with Gsignalx Velocity

**Educational guide — not investment advice. Trading involves risk of loss.**

Use this when you want Velocity to keep running on your Windows PC while you **open or manage orders** from a browser or phone on the GSignalX trading dashboard. For **conviction signals** (what the market wants), use [gsignalx.cloud](https://www.gsignalx.cloud/) — that is separate from order routing.

---

## Why connect?

- **Mobility:** Check the book, place a market order, or pause the worker without sitting at the MT5 desk.
- **Same toolkit:** Your entries and harvest rules still run locally; the cloud sends **allowed** remote actions to **GsignalX_Service** on your machine.
- **Pair with Executive:** Read probability / confluence on [gsignalx.cloud](https://www.gsignalx.cloud/), execute and bank winners with Velocity + ProfitScouter on MT5.

**Three URLs (do not mix them up)**

| Site | Role |
|------|------|
| [gsignalx.cloud](https://www.gsignalx.cloud/) | Executive **signals** — conviction, not MT5 orders |
| [trade.gsignalx.cloud](https://trade.gsignalx.cloud) | **Trading dashboard** — register, Connect PC, manage book |
| `https://trade-api.gsignalx.cloud` | Control-plane API — allow in MT5 WebRequest only |

---

## Step-by-step

### 1. Register on the trading dashboard

1. Open [trade.gsignalx.cloud](https://trade.gsignalx.cloud) and create an account (use the same email you will paste into MT5).
2. Complete **Connect PC** and choose **Use Velocity toolkit**.
3. Mint a **worker registration token** (one-time). Copy it immediately — treat it like a password. Do not post it in Telegram, GitHub, or community chats.

### 2. Allow WebRequest in MetaTrader 5

1. MT5 → **Tools → Options → Expert Advisors**.
2. Enable **Allow WebRequest for listed URL**.
3. Add: `https://trade-api.gsignalx.cloud`
4. OK and restart MT5 if prompted.

(Telegram uses a different URL: `https://api.telegram.org` — add that separately if you use desk alerts.)

### 3. Configure GsignalX_Service (not the Trade Center Dashboard)

Cloud inputs live on **`GsignalX_Service.mq5`** only — input group **“16) GsignalX cloud connector (trade-api)”**. Attach Service on **one** chart per account book (same as your normal Service recipe).

| Dashboard / docs name | MT5 input | Notes |
|----------------------|-----------|--------|
| Master switch | `InpCloudEnable` | Set **true** to connect |
| Account email | `InpCloudEmail` | Must match the dashboard account that minted the token |
| Control-plane URL | `InpCloudBaseUrl` | Default `https://trade-api.gsignalx.cloud` — leave unless GSignalX gives you another host |
| Worker registration token | `InpWorkerRegistrationToken` | Paste the one-time mint from Connect PC |
| Poll interval (seconds) | `InpCloudPollSec` | Default 2 — usually leave as-is |
| Allow remote **opens** | `InpCloudAllowRemoteOrders` | Default **true** |
| Allow remote **closes** | `InpCloudAllowRemoteCloses` | Default **false** — ProfitScouter still owns harvest unless you explicitly enable closes |

4. Start **Algo Trading** and ensure **GsignalX_Service** is running.
5. On the dashboard, your toolkit should show **online**. Session claim binds your MT5 login + server to that worker.

**After the first successful enroll:** Service saves a **worker token** locally. Restarting MT5 or Service typically **resumes** without minting a new registration token (unless you revoke the worker on the dashboard).

---

## What you can do from the dashboard

- See worker / session status and control run or play style actions (as exposed in the product UI).
- Place **market** orders when `InpCloudAllowRemoteOrders=true` (subject to your local engines, prop locks, and roster rules).
- Modify **SL/TP** on an open ticket.
- Request **closes** (all / profitable / losing / single ticket) only if you set `InpCloudAllowRemoteCloses=true` — otherwise exits stay with **ProfitScouter** (recommended for most desks).

Remote orders use your Velocity magic and local execution path on the PC — the dashboard does not replace MT5; it instructs the Service worker.

---

## Safety defaults (recommended)

- **Topology A** still applies: Trade Center **DeskExecute** for local fills when that is your desk recipe; Service yields when configured; one Scouter brain for harvest.
- Leave **`InpCloudAllowRemoteCloses=false`** unless you have a deliberate reason to close from the cloud — Scouter **Profit CASH** harvesting is the normal exit process.
- Never enable cloud remote opens on a demo you do not control, or with tokens pasted into shared screenshots.
- Cloud connector does **not** guarantee fills, profit, or prop rule compliance — your firm rules and broker still apply.

---

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Service logs / dashboard shows offline | Algo Trading ON; Service attached; `InpCloudEnable=true` |
| HTTP / WebRequest errors | URL `https://trade-api.gsignalx.cloud` allowed exactly (https, no trailing junk) |
| Enroll rejected | `InpCloudEmail` matches dashboard account; token not expired or reused after revoke |
| Remote order ignored | `InpCloudAllowRemoteOrders`; prop soft lock; roster empty; Desk/Service ownership |
| Must re-mint every time | Normal only after revoke — otherwise check saved worker resume in Service logs |
| Confused with Executive | [gsignalx.cloud](https://www.gsignalx.cloud/) does **not** place MT5 orders — use Service inputs for the trade-api connector |

---

## More help

- **Manual chapter:** [Cloud Trading](Gsignalx_Velocity_Users_Manual.html#cloud) in the Velocity HTML manual (7 languages).
- **Windows deploy:** [WINDOWS_DEPLOY_SIMPLE.md](WINDOWS_DEPLOY_SIMPLE.md) — optional cloud section after Best use.
- **Managed Premium:** [Premium manual](https://ccity.gsignalx.cloud/Gsignalx_Velocity_Premium_Users_Manual#welcome) · [Pricing](https://www.gsignalx.cloud/pricing) · register on [gsignalx.cloud](https://www.gsignalx.cloud/) → **Profile → My Services**.
- **Community:** [Trading channel](https://t.me/+yURbcVkPi1kxNDg0) (macro overview) · [Trading group](https://t.me/+ZDosSHfUCLU1ZGY0) — never share registration tokens or bot tokens.
- **Engineering soak notes (not for traders):** `docs/plans/CLOUD_CONNECTOR_PLAN.md`.
