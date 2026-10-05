//+------------------------------------------------------------------+
//|                                                CloudLoop.mqh      |
//|  Heartbeat, claim-session, snapshot, trades, command poll.        |
//+------------------------------------------------------------------+
#ifndef GSX_CLOUD_LOOP_MQH
#define GSX_CLOUD_LOOP_MQH

#include <GSignalX/TerminalIdentity.mqh>
#include <GSignalX/Cloud/CloudHttp.mqh>
#include <GSignalX/Cloud/CloudAuth.mqh>
#include <GSignalX/Cloud/CloudExec.mqh>
#include <GSignalX/Cloud/CloudControl.mqh>

struct GsxCloudRuntime
  {
   GsxCloudConfig   cfg;
   GsxCloudIdentity id;
   GsxCloudControlState control;
   string accountId;
   datetime lastBeat;
   datetime lastClaim;
   datetime lastSnapshot;
   datetime lastCommands;
   datetime lastControl;
   string lastError;
   bool   online;
  };

void GsxCloudRuntimeClear(GsxCloudRuntime &rt)
  {
   GsxCloudCfgClear(rt.cfg);
   GsxCloudIdClear(rt.id);
   GsxCloudControlClear(rt.control);
   rt.accountId = "";
   rt.lastBeat = 0;
   rt.lastClaim = 0;
   rt.lastSnapshot = 0;
   rt.lastCommands = 0;
   rt.lastControl = 0;
   rt.lastError = "";
   rt.online = false;
  }

bool GsxCloudHeartbeat(GsxCloudRuntime &rt)
  {
   if(rt.id.workerToken == "")
      return(false);
   string body = "{";
   body += GsxJsonKV_I("assigned_count", (rt.accountId == "" ? 0 : 1));
   body += GsxJsonKV_S("connector_runtime", rt.cfg.runtime);
   body += "\"terminal\":" + GsxCloudTerminalJson();
   body += "}";
   string url = GsxCloudTrimSlash(rt.id.controlPlane) + "/api/v1/workers/heartbeat";
   GsxCloudHttpResult res;
   if(!GsxCloudHttpWithRetry("POST", url, rt.id.workerToken, body, res) || !res.ok)
     {
      rt.lastError = res.err;
      rt.online = false;
      return(false);
     }
   GsxCloudApplyRotatedToken(rt.id, res.body);
   rt.lastBeat = TimeCurrent();
   rt.online = true;
   return(true);
  }

bool GsxCloudClaimSession(GsxCloudRuntime &rt)
  {
   GsxTerminalId tid;
   GsxFillIdentity(tid);
   string body = "{";
   body += GsxJsonKV_I("login", tid.login);
   body += GsxJsonKV_S("server", tid.server);
   body += GsxJsonKV_S("company", tid.company);
   body += GsxJsonKV_S("currency", tid.currency);
   body += GsxJsonKV_S("name", StringFormat("MT5 %I64d@%s", tid.login, tid.server), false);
   body += "}";
   string url = GsxCloudTrimSlash(rt.id.controlPlane) + "/api/v1/workers/accounts/claim-session";
   GsxCloudHttpResult res;
   if(!GsxCloudHttpWithRetry("POST", url, rt.id.workerToken, body, res) || !res.ok)
     {
      rt.lastError = "claim: " + res.err + " " + StringSubstr(res.body, 0, 120);
      return(false);
     }
   rt.accountId = GsxJsonGetString(res.body, "account_id", "");
   rt.lastClaim = TimeCurrent();
   return(rt.accountId != "");
  }

bool GsxCloudPushSnapshot(GsxCloudRuntime &rt)
  {
   if(rt.accountId == "")
      return(false);
   string body = "{";
   body += GsxJsonKV_D("balance", AccountInfoDouble(ACCOUNT_BALANCE));
   body += GsxJsonKV_D("equity", AccountInfoDouble(ACCOUNT_EQUITY));
   body += GsxJsonKV_D("margin", AccountInfoDouble(ACCOUNT_MARGIN));
   body += GsxJsonKV_D("free_margin", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
   body += GsxJsonKV_D("profit", AccountInfoDouble(ACCOUNT_PROFIT));
   body += GsxJsonKV_S("currency", AccountInfoString(ACCOUNT_CURRENCY));
   body += GsxJsonKV_I("login", AccountInfoInteger(ACCOUNT_LOGIN));
   body += GsxJsonKV_S("server", AccountInfoString(ACCOUNT_SERVER), false);
   body += "}";
   string url = GsxCloudTrimSlash(rt.id.controlPlane) +
                "/api/v1/workers/accounts/" + rt.accountId + "/snapshot";
   GsxCloudHttpResult res;
   if(!GsxCloudHttpWithRetry("POST", url, rt.id.workerToken, body, res) || !res.ok)
     {
      rt.lastError = "snapshot: " + res.err;
      return(false);
     }
   rt.lastSnapshot = TimeCurrent();
   return(true);
  }

// Minimal trades push: open positions as lightweight book (closed history optional later).
bool GsxCloudPushTrades(GsxCloudRuntime &rt)
  {
   if(rt.accountId == "")
      return(false);
   string trades = "[";
   int n = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(n > 0)
         trades += ",";
      trades += "{";
      trades += GsxJsonKV_I("ticket", (long)ticket);
      trades += GsxJsonKV_S("symbol", PositionGetString(POSITION_SYMBOL));
      trades += GsxJsonKV_S("side", (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "buy" : "sell"));
      trades += GsxJsonKV_D("volume", PositionGetDouble(POSITION_VOLUME));
      trades += GsxJsonKV_D("profit", PositionGetDouble(POSITION_PROFIT), false);
      trades += "}";
      n++;
      if(n >= 50)
         break;
     }
   trades += "]";
   string body = "{\"trades\":" + trades + "}";
   string url = GsxCloudTrimSlash(rt.id.controlPlane) +
                "/api/v1/workers/accounts/" + rt.accountId + "/trades";
   GsxCloudHttpResult res;
   return(GsxCloudHttpWithRetry("POST", url, rt.id.workerToken, body, res) && res.ok);
  }

bool GsxCloudPollCommands(GsxCloudRuntime &rt, const long magic)
  {
   if(rt.accountId == "")
      return(false);
   string url = GsxCloudTrimSlash(rt.id.controlPlane) +
                "/api/v1/workers/accounts/" + rt.accountId + "/commands";
   GsxCloudHttpResult res;
   if(!GsxCloudHttpWithRetry("GET", url, rt.id.workerToken, "", res) || !res.ok)
     {
      rt.lastError = "commands: " + res.err;
      return(false);
     }
   rt.lastCommands = TimeCurrent();
   // Walk simple array of command objects by scanning "id" / "type" pairs.
   string body = res.body;
   int pos = 0;
   int guard = 0;
   while(guard < 20)
     {
      int idKey = StringFind(body, "\"id\"", pos);
      if(idKey < 0)
         break;
      string slice = StringSubstr(body, idKey);
      string cmdId = GsxJsonGetString(slice, "id", "");
      string type = GsxJsonGetString(slice, "type", "");
      if(cmdId == "" || type == "")
        {
         pos = idKey + 4;
         guard++;
         continue;
        }
      // payload may be nested object — pass slice window
      int next = StringFind(body, "\"id\"", idKey + 4);
      string payload = (next > idKey ? StringSubstr(body, idKey, next - idKey) : slice);
      GsxCloudExecResult er;
      GsxCloudExecCommand(rt.cfg, magic, type, payload, er);
      GsxCloudAckCommand(rt.id, rt.accountId, cmdId, er.body);
      pos = idKey + 4;
      guard++;
     }
   return(true);
  }

bool GsxCloudPushVelocitySignals(GsxCloudRuntime &rt, const string signalsJsonArray)
  {
   if(!rt.cfg.pushSignals || rt.accountId == "" || signalsJsonArray == "")
      return(false);
   string body = "{\"signals\":" + signalsJsonArray + "}";
   string url = GsxCloudTrimSlash(rt.id.controlPlane) +
                "/api/v1/workers/accounts/" + rt.accountId + "/velocity/signals";
   GsxCloudHttpResult res;
   return(GsxCloudHttpWithRetry("POST", url, rt.id.workerToken, body, res) && res.ok);
  }

// One budgeted tick of the cloud worker (call from Service loop).
// At most one HTTP family per call so the entry cycle stays responsive.
void GsxCloudTick(GsxCloudRuntime &rt, const long magic)
  {
   if(!rt.cfg.enable)
      return;
   if(!rt.id.registered)
     {
      if(!GsxCloudEnsureAuth(rt.cfg, rt.id))
        {
         rt.lastError = rt.id.lastError;
         return;
        }
      PrintFormat("GsignalX cloud: registered worker_id=%s runtime=%s",
                  rt.id.workerId, rt.cfg.runtime);
      return; // auth already used the HTTP budget this tick
     }

   int poll = MathMax(1, rt.cfg.pollSec);
   datetime now = TimeCurrent();

   // Priority: heartbeat → claim → commands → control → snapshot/trades
   if(now - rt.lastBeat >= poll)
     {
      GsxCloudHeartbeat(rt);
      return;
     }

   if(rt.accountId == "" && now - rt.lastClaim >= poll)
     {
      GsxCloudClaimSession(rt);
      return;
     }

   if(rt.accountId != "" && now - rt.lastCommands >= poll)
     {
      GsxCloudPollCommands(rt, magic);
      return;
     }

   if(rt.accountId != "" && now - rt.lastControl >= MathMax(2, poll))
     {
      if(GsxCloudControlFetch(rt.id, rt.accountId, rt.control))
        {
         GsxCloudControlApplyRun(rt.control, magic);
         rt.lastControl = now;
        }
      return;
     }

   if(rt.accountId != "" && now - rt.lastSnapshot >= poll)
     {
      // Snapshot + trades share one budgeted tick (two short POSTs, no command latency)
      GsxCloudPushSnapshot(rt);
      GsxCloudPushTrades(rt);
     }
  }

#endif
//+------------------------------------------------------------------+
