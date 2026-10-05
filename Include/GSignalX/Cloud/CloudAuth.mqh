//+------------------------------------------------------------------+
//|                                                CloudAuth.mqh      |
//|  Register + persist/rotate worker_token under FILE_COMMON.        |
//+------------------------------------------------------------------+
#ifndef GSX_CLOUD_AUTH_MQH
#define GSX_CLOUD_AUTH_MQH

#include <GSignalX/BusIO.mqh>
#include <GSignalX/BusProtocol.mqh>
#include <GSignalX/TerminalIdentity.mqh>
#include <GSignalX/Cloud/CloudHttp.mqh>

#define GSX_CLOUD_WORKER_REL  "GSignalX\\cloud\\v1\\worker.json"

struct GsxCloudConfig
  {
   bool   enable;
   string email;
   string baseUrl;
   string registrationToken;
   string runtime;          // velocity | velocity_premium
   string agentVersion;
   string workerName;
   int    capacity;
   int    pollSec;
   bool   allowRemoteOrders;
   bool   allowRemoteCloses;
   bool   pushSignals;
  };

struct GsxCloudIdentity
  {
   string workerId;
   string workerToken;
   string controlPlane;
   string runtime;
   bool   registered;
   string lastError;
   datetime lastRegisterAt;
  };

void GsxCloudCfgClear(GsxCloudConfig &c)
  {
   c.enable = false;
   c.email = "";
   c.baseUrl = "https://trade-api.gsignalx.cloud";
   c.registrationToken = "";
   c.runtime = "velocity";
   c.agentVersion = "velocity-2.15";
   c.workerName = "velocity";
   c.capacity = 1;
   c.pollSec = 2;
   c.allowRemoteOrders = true;
   c.allowRemoteCloses = false;
   c.pushSignals = false;
  }

void GsxCloudIdClear(GsxCloudIdentity &id)
  {
   id.workerId = "";
   id.workerToken = "";
   id.controlPlane = "";
   id.runtime = "";
   id.registered = false;
   id.lastError = "";
   id.lastRegisterAt = 0;
  }

bool GsxCloudLoadIdentity(GsxCloudIdentity &id)
  {
   GsxCloudIdClear(id);
   string body = GsxBusReadAll(GSX_CLOUD_WORKER_REL);
   if(body == "")
      return(false);
   id.workerId = GsxJsonGetString(body, "worker_id", "");
   id.workerToken = GsxJsonGetString(body, "worker_token", "");
   id.controlPlane = GsxJsonGetString(body, "control_plane", "");
   id.runtime = GsxJsonGetString(body, "connector_runtime", "");
   id.registered = (id.workerToken != "");
   return(id.registered);
  }

bool GsxCloudSaveIdentity(const GsxCloudIdentity &id)
  {
   string j = "{";
   j += GsxJsonKV_S("worker_id", id.workerId);
   j += GsxJsonKV_S("worker_token", id.workerToken);
   j += GsxJsonKV_S("control_plane", id.controlPlane);
   j += GsxJsonKV_S("connector_runtime", id.runtime, false);
   j += "}";
   return(GsxBusWriteAtomic(GSX_CLOUD_WORKER_REL, j));
  }

string GsxCloudTerminalJson()
  {
   GsxTerminalId tid;
   GsxFillIdentity(tid);
   string j = "{";
   j += GsxJsonKV_S("tid", tid.tid);
   j += GsxJsonKV_I("login", tid.login);
   j += GsxJsonKV_S("server", tid.server);
   j += GsxJsonKV_S("company", tid.company);
   j += GsxJsonKV_S("currency", tid.currency);
   j += GsxJsonKV_I("build", (long)TerminalInfoInteger(TERMINAL_BUILD), false);
   j += "}";
   return(j);
  }

bool GsxCloudRegister(const GsxCloudConfig &cfg, GsxCloudIdentity &id)
  {
   id.lastError = "";
   string base = GsxCloudTrimSlash(cfg.baseUrl);
   if(base == "" || cfg.registrationToken == "")
     {
      id.lastError = "baseUrl and registrationToken required";
      return(false);
     }

   string body = "{";
   body += GsxJsonKV_S("registration_token", cfg.registrationToken);
   body += GsxJsonKV_S("name", cfg.workerName);
   body += GsxJsonKV_S("region", "default");
   body += GsxJsonKV_S("agent_version", cfg.agentVersion);
   body += GsxJsonKV_S("connector_runtime", cfg.runtime);
   body += GsxJsonKV_S("email", cfg.email);
   body += GsxJsonKV_I("capacity", cfg.capacity);
   body += "\"terminal\":" + GsxCloudTerminalJson();
   body += "}";

   GsxCloudHttpResult res;
   string url = base + "/api/v1/workers/register";
   if(!GsxCloudHttpWithRetry("POST", url, "", body, res) || !res.ok)
     {
      id.lastError = res.err + " " + StringSubstr(res.body, 0, 180);
      return(false);
     }

   id.workerId = GsxJsonGetString(res.body, "worker_id", "");
   id.workerToken = GsxJsonGetString(res.body, "worker_token", "");
   id.controlPlane = base;
   id.runtime = cfg.runtime;
   id.registered = (id.workerToken != "");
   id.lastRegisterAt = TimeCurrent();
   if(!id.registered)
     {
      id.lastError = "register response missing worker_token";
      return(false);
     }
   GsxCloudSaveIdentity(id);
   return(true);
  }

// Resume saved token when control plane matches; else register with mint.
bool GsxCloudEnsureAuth(const GsxCloudConfig &cfg, GsxCloudIdentity &id)
  {
   string base = GsxCloudTrimSlash(cfg.baseUrl);
   GsxCloudIdentity saved;
   if(GsxCloudLoadIdentity(saved) && saved.controlPlane == base && saved.workerToken != "")
     {
      id = saved;
      id.runtime = cfg.runtime;
      return(true);
     }
   if(cfg.registrationToken == "")
     {
      id.lastError = "no saved worker_token and no registration token";
      return(false);
     }
   return(GsxCloudRegister(cfg, id));
  }

void GsxCloudApplyRotatedToken(GsxCloudIdentity &id, const string body)
  {
   string tok = GsxJsonGetString(body, "worker_token", "");
   if(tok == "" || tok == id.workerToken)
      return;
   id.workerToken = tok;
   GsxCloudSaveIdentity(id);
  }

#endif
//+------------------------------------------------------------------+
