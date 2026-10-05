# GsignalX Velocity — Cloud Connector Plan (Public)

**Status:** Phase 4 backport implemented · soak Phase 6  
**Control plane:** `https://trade-api.gsignalx.cloud`  
**Sibling:** Premium `docs/plans/CLOUD_CONNECTOR_PLAN.md` · Trading system `docs/plans/2026-10-toolkit-cloud-connector.md`

## Goal

Public Velocity users with a registered GsignalX trading dashboard account connect using only:

- `InpCloudEmail` — dashboard email  
- `InpCloudBaseUrl` — `https://trade-api.gsignalx.cloud`  
- `InpWorkerRegistrationToken` — one-time mint from Connect PC  

No Go/Python connector download. Market-safe (no DLL).

## Integrity (public repo)

- Do **not** copy Premium OF/VP, SignalJoin, dual-track Premium UI, or private manuals.  
- Cloud* modules only (HTTP + auth + loop + exec + control).  
- Never commit mint tokens, Telegram tokens, or `.set` secrets.

## Inputs (Desk + Service)

| Input | Default | Notes |
|-------|---------|--------|
| `InpCloudEnable` | false | Master switch |
| `InpCloudEmail` | "" | Must match mint owner |
| `InpCloudBaseUrl` | `https://trade-api.gsignalx.cloud` | WebRequest allowlist |
| `InpWorkerRegistrationToken` | "" | One-shot; cleared after success |
| `InpCloudPollSec` | 2 | Command/heartbeat budget |
| `InpCloudAllowRemoteOrders` | true | place_order |
| `InpCloudAllowRemoteCloses` | false | Scouter default exits |

## Modules (from Premium, stripped)

```
Include/GSignalX/Cloud/
  CloudHttp.mqh
  CloudAuth.mqh
  CloudLoop.mqh
  CloudExec.mqh
  CloudControl.mqh
```

Persist: `FILE_COMMON` → `GSignalX/cloud/v1/worker.json` (`worker_id`, `worker_token`, `control_plane`).

Host: prefer `GsignalX_Service.mq5`; Desk may enable same inputs.

## Phases

| Phase | Work | Exit |
|-------|------|------|
| 0 | This plan | Doc review |
| 4 | Backport Cloud* + wire Service/Desk + README | Compile gate; mock CP register/heartbeat |
| 6 | Soak checklist + secret hygiene | Checklist green |

Phases 1–3 / 5 owned by trading system + Premium.

## User steps

1. Register / sign in at trade.gsignalx.cloud  
2. Connect PC → **Use Velocity toolkit** → mint token  
3. MT5 → Tools → Options → Expert Advisors → allow WebRequest for `https://trade-api.gsignalx.cloud`  
4. Attach Service (or Desk) → set email, URL, token → enable cloud  
5. Dashboard shows **Toolkit (Velocity)** online; register MT5 account or auto-claim from session  

## Acceptance

- [x] Register + heartbeat without Go/Python (`Include/GSignalX/Cloud/*` + Service inputs)  
- [x] claim-session binds login+server  
- [x] Dashboard open/close when remote flags allow (`InpCloudAllowRemote*`)  
- [x] No Premium IP in this tree (lite CloudControl; no OF/VP)  

## Soak (Phase 6)

1. Fresh mint enroll  
2. Restart terminal → resume worker_token (no re-mint)  
3. place_order from dashboard  
4. Wrong email rejected  
5. Offline after kill Service  
