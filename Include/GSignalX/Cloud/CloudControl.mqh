//+------------------------------------------------------------------+
//|                                             CloudControl.mqh      |
//|  Public Velocity — HTTPS control_panel (no Premium dual-track).   |
//+------------------------------------------------------------------+
#ifndef GSX_CLOUD_CONTROL_HTTPS_MQH
#define GSX_CLOUD_CONTROL_HTTPS_MQH

#include <GSignalX/Fleet.mqh>
#include <GSignalX/BusIO.mqh>
#include <GSignalX/BusProtocol.mqh>
#include <GSignalX/Cloud/CloudHttp.mqh>
#include <GSignalX/Cloud/CloudAuth.mqh>

struct GsxCloudPanelLite
  {
   string mode;
   string run;
   bool   auto_allowed;
   long   revision;
   bool   loaded;
  };

struct GsxCloudControlState
  {
   GsxCloudPanelLite panel;
   string accountId;
   datetime lastFetch;
   string lastError;
  };

void GsxCloudControlClear(GsxCloudControlState &st)
  {
   st.panel.mode = "local";
   st.panel.run = "stop";
   st.panel.auto_allowed = true;
   st.panel.revision = 0;
   st.panel.loaded = false;
   st.accountId = "";
   st.lastFetch = 0;
   st.lastError = "";
  }

bool GsxCloudControlFetch(const GsxCloudIdentity &id, const string accountId,
                          GsxCloudControlState &st)
  {
   st.lastError = "";
   if(id.workerToken == "" || accountId == "")
      return(false);
   string url = GsxCloudTrimSlash(id.controlPlane) +
                "/api/v1/workers/accounts/" + accountId + "/config/control_panel";
   GsxCloudHttpResult res;
   if(!GsxCloudHttpWithRetry("GET", url, id.workerToken, "", res) || !res.ok)
     {
      st.lastError = res.err;
      return(false);
     }
   st.panel.mode = GsxJsonGetString(res.body, "mode", "local");
   st.panel.run = GsxJsonGetString(res.body, "run", "stop");
   st.panel.auto_allowed = GsxJsonGetBool(res.body, "auto_allowed", true);
   st.panel.revision = GsxJsonGetLong(res.body, "revision", 0);
   st.panel.loaded = true;
   st.accountId = accountId;
   st.lastFetch = TimeCurrent();
   GsxBusWriteAtomic("gsignalx\\control_panel.json", res.body);
   return(true);
  }

void GsxCloudControlApplyRun(GsxCloudControlState &st, const long magic)
  {
   if(!st.panel.loaded)
      return;
   if(st.panel.mode != "cloud" && st.panel.mode != "hybrid")
      return;
   bool stop = (st.panel.run == "stop" || !st.panel.auto_allowed || st.panel.mode == "cloud");
   GsxFleetServiceRunSet(magic, !stop && st.panel.run == "play");
   if(st.panel.mode == "cloud")
      GsxFleetServiceRunSet(magic, false); // cloud opens owned by remote commands
  }

bool GsxCloudControlBlocksLocalOpen(GsxCloudControlState &st)
  {
   if(!st.panel.loaded)
      return(false);
   if(st.panel.mode == "cloud")
      return(true);
   if(st.panel.mode == "hybrid" && st.panel.run == "stop")
      return(true);
   return(false);
  }

#endif
//+------------------------------------------------------------------+
