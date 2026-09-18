//+------------------------------------------------------------------+
//|                                           SettingsNotify.mqh      |
//|  DRY Telegram [SETTINGS] load snapshots + prop-critical deltas.   |
//|  Desk owns HTTP; Scouter writes pending only (no Scouter TG).     |
//|  Enqueue via GsxTgEnqueueTagged — timer drains 1 msg/cycle.       |
//+------------------------------------------------------------------+
#ifndef GSX_SETTINGS_NOTIFY_MQH
#define GSX_SETTINGS_NOTIFY_MQH

#include <GSignalX/TelegramNotifier.mqh>
#include <GSignalX/BusProtocol.mqh>
#include <GSignalX/BusIO.mqh>
#include <GSignalX/TerminalIdentity.mqh>
#include <GSignalX/ScoutLink.mqh>
#include <GSignalX/Fleet.mqh>
#include <GSignalX/RosterStore.mqh>
#include <GSignalX/PropRisk.mqh>

#define GSX_SET_DEBOUNCE_SEC   2
#define GSX_SET_AUDIT_MAX      131072

struct GsxSettingsSnapshot
  {
   long     magic;
   string   host;
   bool     run;
   bool     scoutRun;
   bool     scoutAdverse;
   bool     scoutCash;
   bool     scoutLoss;
   bool     scoutTrail;
   bool     flipWait;
   int      followDir;
   bool     spreadIgn;
   bool     autoLot;
   double   eqPct;
   bool     propLocked;
   string   propReason;
   int      rosterCount;
   int      fleetTarget;
   double   scoutFloor;
   double   scoutMinWin;
   int      scoutInstanceId;
   bool     deskExecute;
   string   exitMode;   // "SCOUTER" | "SIGNAL" | ""
  };

// Bound host context (Desk/Chart set once; panel announce uses this)
bool         g_gsxSetBound     = false;
GsxTgConfig  g_gsxSetCfg;
long         g_gsxSetMagic     = 0;
int          g_gsxSetScoutId   = 1;
string       g_gsxSetHost      = "desk";
bool         g_gsxSetDeskExec  = true;
string       g_gsxSetExitMode  = "SCOUTER";
datetime     g_gsxSetLastSend  = 0;
string       g_gsxSetLastFp    = "";
GsxSettingsSnapshot g_gsxSetPrev;

void GsxSettingsSnapClear(GsxSettingsSnapshot &s)
  {
   s.magic = 0;
   s.host = "";
   s.run = false;
   s.scoutRun = false;
   s.scoutAdverse = false;
   s.scoutCash = false;
   s.scoutLoss = false;
   s.scoutTrail = false;
   s.flipWait = false;
   s.followDir = 0;
   s.spreadIgn = false;
   s.autoLot = false;
   s.eqPct = 0.0;
   s.propLocked = false;
   s.propReason = "";
   s.rosterCount = 0;
   s.fleetTarget = 0;
   s.scoutFloor = 0.0;
   s.scoutMinWin = 0.0;
   s.scoutInstanceId = 1;
   s.deskExecute = false;
   s.exitMode = "";
  }

string GsxSettingsFpGvName(const long magic)
  {
   return(StringFormat("GSX_SET_FP_%I64d", magic));
  }

string GsxSettingsPendingGvName(const long magic)
  {
   return(StringFormat("GSX_SET_PEND_%I64d", magic));
  }

string GsxSettingsPendingRel(const long magic)
  {
   return(StringFormat("%s\\settings\\pending\\%I64d.set",
                       GsxBusTerminalDir(GsxMakeTid()), magic));
  }

string GsxSettingsAuditRel()
  {
   return(GsxBusTerminalDir(GsxMakeTid()) + "\\settings\\events.jsonl");
  }

void GsxSettingsBindHost(const GsxTgConfig &cfg,
                         const long magic,
                         const int scoutInstanceId,
                         const string host,
                         const bool deskExecute = true,
                         const string exitMode = "SCOUTER")
  {
   g_gsxSetCfg = cfg;
   g_gsxSetMagic = magic;
   g_gsxSetScoutId = scoutInstanceId;
   g_gsxSetHost = (host == "" ? "desk" : host);
   g_gsxSetDeskExec = deskExecute;
   g_gsxSetExitMode = exitMode;
   g_gsxSetBound = true;
  }

void GsxSettingsRebindCfg(const GsxTgConfig &cfg)
  {
   if(g_gsxSetBound)
      g_gsxSetCfg = cfg;
  }

void GsxSettingsBuild(const long magic,
                      const int scoutInstanceId,
                      const string host,
                      const bool deskExecute,
                      const string exitMode,
                      GsxSettingsSnapshot &out)
  {
   GsxSettingsSnapClear(out);
   out.magic = magic;
   out.host = host;
   out.scoutInstanceId = scoutInstanceId;
   out.deskExecute = deskExecute;
   out.exitMode = exitMode;

   out.run = GsxFleetServiceRunGet(magic);
   out.flipWait = GsxRosterFlipWaitGet(magic, false);
   out.spreadIgn = GsxRosterSpreadIgnGet(magic, false);
   out.autoLot = GsxRosterAutoLotGet(magic, false);
   out.eqPct = GsxRosterEqGuardGet(magic, 0.0);
   out.followDir = GsxRosterFollowDirGet(magic, "", GSX_FOLLOW_AUTO);
   // desk-wide follow: use empty-symbol fallback; hosts may overwrite

   string roster[];
   GsxRosterStoreLoad(magic, roster);
   out.rosterCount = ArraySize(roster);
   out.fleetTarget = GsxRosterFleetTargetGet(magic);

   out.scoutRun = GsxScoutRunGet(scoutInstanceId, true);
   out.scoutAdverse = GsxScoutAdvenGet(scoutInstanceId, true);
   out.scoutCash = GsxScoutCashGet(scoutInstanceId, true);
   out.scoutLoss = GsxScoutLossGet(scoutInstanceId, false);
   out.scoutTrail = GsxScoutTrailGet(scoutInstanceId, false);

   double fl = 0.0, mw = 0.0;
   if(GsxScoutFloorGet(scoutInstanceId, fl))
      out.scoutFloor = fl;
   if(GsxScoutMinWinGet(scoutInstanceId, mw))
      out.scoutMinWin = mw;

   GsxPropState pst;
   GsxPropLoad(magic, pst);
   out.propLocked = pst.locked;
   out.propReason = pst.reason;
  }

string GsxSettingsFingerprint(const GsxSettingsSnapshot &s)
  {
   return(StringFormat("%I64d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%.0f|%d|%d|%d|%.0f|%.0f|%s|%d",
                       s.magic,
                       s.run ? 1 : 0,
                       s.scoutRun ? 1 : 0,
                       s.scoutAdverse ? 1 : 0,
                       s.scoutCash ? 1 : 0,
                       s.scoutLoss ? 1 : 0,
                       s.scoutTrail ? 1 : 0,
                       s.flipWait ? 1 : 0,
                       s.spreadIgn ? 1 : 0,
                       s.autoLot ? 1 : 0,
                       s.eqPct,
                       s.propLocked ? 1 : 0,
                       s.rosterCount,
                       s.fleetTarget,
                       s.scoutFloor,
                       s.scoutMinWin,
                       s.exitMode,
                       s.followDir));
  }

string GsxSettingsRunLabel(const GsxSettingsSnapshot &s)
  {
   if(s.run)
      return("PLAY");
   if(!s.scoutRun)
      return("HALT");
   return("STOP");
  }

string GsxSettingsImpact(const string action, const GsxSettingsSnapshot &s)
  {
   string a = action;
   StringToUpper(a);
   if(StringFind(a, "PLAY") >= 0 || StringFind(a, "RUN") == 0)
      return("entries ON; scout harvest " + (s.scoutRun ? "ON" : "OFF"));
   if(StringFind(a, "HALT") >= 0 || StringFind(a, "FLAT") >= 0)
      return("entries OFF; scout harvest OFF; open tickets untouched");
   if(StringFind(a, "STOP") >= 0)
      return("entries OFF; pendings cleared; Scouter still harvests");
   if(StringFind(a, "FOLLOW") >= 0 || StringFind(a, "FLIP") >= 0)
      return(s.flipWait ? "WAIT: block new-dir vs opposite exposure"
                        : "FOLLOW: fill latest signal direction");
   if(StringFind(a, "AUTOLOT") >= 0)
      return(s.autoLot ? "lots sized by risk%/ATR" : "FIXED lot sizing");
   if(StringFind(a, "EQ") >= 0)
      return(s.eqPct <= 0.0 ? "equity DD guard OFF"
                            : StringFormat("block new entries at %.0f%% account DD", s.eqPct));
   if(StringFind(a, "SPREAD") >= 0 || StringFind(a, "IGN") >= 0)
      return(s.spreadIgn ? "max-spread gate ignored" : "max-spread gate ON");
   if(StringFind(a, "CASH") >= 0)
      return(s.scoutCash ? "Scouter single profit floor (trail/window off)"
                         : "Scouter layered targets/trails");
   if(StringFind(a, "TRAIL") >= 0)
      return(s.scoutTrail ? "ATR trail harvest armed" : "ATR trail off");
   if(StringFind(a, "LOSS") >= 0)
      return(s.scoutLoss ? "Loss CASH arm ON (cut losers at floor)"
                         : "Loss CASH arm OFF");
   if(StringFind(a, "AUTO") >= 0 || StringFind(a, "ADVERSE") >= 0)
      return(s.scoutAdverse ? "adverse-bar loser exit armed"
                            : "adverse-bar loser exit off");
   if(StringFind(a, "SCOUT") >= 0 || StringFind(a, "START") >= 0)
      return(s.scoutRun ? "profit scouting armed (closes enabled)"
                        : "profit scouting paused (watch only)");
   if(StringFind(a, "PROP") >= 0)
      return(s.propLocked ? ("Prop LOCK " + s.propReason + " — entries stopped")
                          : "Prop unlocked — entries may resume");
   if(StringFind(a, "FDIR") >= 0 || StringFind(a, "FOLLOWDIR") >= 0)
      return("desk FollowDir filter applied to new entries");
   if(StringFind(a, "FLEET") >= 0)
      return("fleet target pairs changed — fill cadence");
   if(StringFind(a, "PAIR") >= 0 || StringFind(a, "STATE") >= 0)
      return("pair START/STOP — signal eligibility only (no closes)");
   if(StringFind(a, "ADD") >= 0 || StringFind(a, "REM") >= 0 || StringFind(a, "SWAP") >= 0)
      return("roster book changed — signal universe updated");
   if(StringFind(a, "EVT") >= 0)
      return("event gate TRADE/SKIP for new entries");
   if(StringFind(a, "LOAD") >= 0)
      return("effective input+UI state at host start");
   return("settings applied");
  }

string GsxSettingsFormatLoad(const GsxSettingsSnapshot &s)
  {
   return(StringFormat(
      "LOAD magic=%I64d host=%s RUN=%s deskExec=%s exit=%s FOLLOW=%s FDIR=%d "
      "AUTOLOT=%s EQ=%s IGN=%s PROP=%s roster=%d fleet=%d "
      "scout[id=%d RUN=%s CASH=%s LOSS=%s TRAIL=%s ADV=%s floor=%.0f minWin=%.0f] | %s",
      s.magic, s.host, GsxSettingsRunLabel(s),
      (s.deskExecute ? "ON" : "OFF"),
      (s.exitMode == "" ? "-" : s.exitMode),
      (s.flipWait ? "WAIT" : "FOLLOW"),
      s.followDir,
      (s.autoLot ? "ON" : "OFF"),
      GsxRosterEqGuardLabel(s.eqPct),
      (s.spreadIgn ? "ON" : "OFF"),
      (s.propLocked ? ("LOCK:" + s.propReason) : "OK"),
      s.rosterCount, s.fleetTarget,
      s.scoutInstanceId,
      (s.scoutRun ? "ON" : "OFF"),
      (s.scoutCash ? "ON" : "OFF"),
      (s.scoutLoss ? "ON" : "OFF"),
      (s.scoutTrail ? "ON" : "OFF"),
      (s.scoutAdverse ? "ON" : "OFF"),
      s.scoutFloor, s.scoutMinWin,
      GsxSettingsImpact("LOAD", s)));
  }

string GsxSettingsFormatDelta(const GsxSettingsSnapshot &prev,
                              const GsxSettingsSnapshot &next,
                              const string action)
  {
   string bits = "";
   if(prev.run != next.run)
      bits += StringFormat(" RUN %s→%s", GsxSettingsRunLabel(prev), GsxSettingsRunLabel(next));
   if(prev.scoutRun != next.scoutRun)
      bits += StringFormat(" scout %s→%s", (prev.scoutRun ? "ON" : "OFF"), (next.scoutRun ? "ON" : "OFF"));
   if(prev.flipWait != next.flipWait)
      bits += StringFormat(" mode %s→%s", (prev.flipWait ? "WAIT" : "FOLLOW"), (next.flipWait ? "WAIT" : "FOLLOW"));
   if(prev.autoLot != next.autoLot)
      bits += StringFormat(" lot %s→%s", (prev.autoLot ? "AUTO" : "FIX"), (next.autoLot ? "AUTO" : "FIX"));
   if(MathAbs(prev.eqPct - next.eqPct) > 0.1)
      bits += StringFormat(" EQ %s→%s", GsxRosterEqGuardLabel(prev.eqPct), GsxRosterEqGuardLabel(next.eqPct));
   if(prev.spreadIgn != next.spreadIgn)
      bits += StringFormat(" spreadIgn %d→%d", (prev.spreadIgn ? 1 : 0), (next.spreadIgn ? 1 : 0));
   if(prev.scoutCash != next.scoutCash)
      bits += StringFormat(" CASH %d→%d", (prev.scoutCash ? 1 : 0), (next.scoutCash ? 1 : 0));
   if(prev.scoutTrail != next.scoutTrail)
      bits += StringFormat(" TRAIL %d→%d", (prev.scoutTrail ? 1 : 0), (next.scoutTrail ? 1 : 0));
   if(prev.scoutLoss != next.scoutLoss)
      bits += StringFormat(" LOSS %d→%d", (prev.scoutLoss ? 1 : 0), (next.scoutLoss ? 1 : 0));
   if(prev.scoutAdverse != next.scoutAdverse)
      bits += StringFormat(" ADV %d→%d", (prev.scoutAdverse ? 1 : 0), (next.scoutAdverse ? 1 : 0));
   if(prev.propLocked != next.propLocked)
      bits += StringFormat(" PROP %s→%s", (prev.propLocked ? "LOCK" : "OK"), (next.propLocked ? "LOCK" : "OK"));
   if(prev.rosterCount != next.rosterCount)
      bits += StringFormat(" roster %d→%d", prev.rosterCount, next.rosterCount);
   if(prev.fleetTarget != next.fleetTarget)
      bits += StringFormat(" fleet %d→%d", prev.fleetTarget, next.fleetTarget);
   if(bits == "")
      bits = " (applied)";

   return(StringFormat("CLICK %s →%s | %s", action, bits, GsxSettingsImpact(action, next)));
  }

void GsxSettingsAuditAppend(const string kind, const string body)
  {
   string rel = GsxSettingsAuditRel();
   GsxEnsureFolderTree(rel);
   if(FileIsExist(rel, FILE_COMMON))
     {
      long sz = FileGetInteger(rel, FILE_SIZE, FILE_COMMON);
      if(sz >= GSX_SET_AUDIT_MAX)
        {
         string bak = rel + ".bak";
         FileDelete(bak, FILE_COMMON);
         FileMove(rel, FILE_COMMON, bak, FILE_REWRITE);
        }
     }
   string j = "{";
   j += GsxJsonKV_I("ts", (long)TimeCurrent());
   j += GsxJsonKV_S("kind", kind);
   j += GsxJsonKV_S("body", body, false);
   j += "}\n";
   int h = FileOpen(rel, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
     {
      h = FileOpen(rel, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_REWRITE);
      if(h == INVALID_HANDLE)
         return;
      FileWriteString(h, j);
      FileClose(h);
      return;
     }
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, j);
   FileClose(h);
  }

bool GsxSettingsShouldSend(const string fp, const bool force)
  {
   if(force)
      return(true);
   if(fp == g_gsxSetLastFp)
      return(false);
   if(g_gsxSetLastSend > 0 && (TimeCurrent() - g_gsxSetLastSend) < GSX_SET_DEBOUNCE_SEC)
      return(false);
   return(true);
  }

void GsxSettingsNotify(const GsxTgConfig &cfg,
                       const string body,
                       const string fp,
                       const bool force)
  {
   if(!cfg.enable || body == "")
      return;
   if(!GsxSettingsShouldSend(fp, force))
      return;

   GsxTgEnqueueTagged(cfg, "SETTINGS", body);
   g_gsxSetLastFp = fp;
   g_gsxSetLastSend = TimeCurrent();
   GlobalVariableSet(GsxSettingsFpGvName(g_gsxSetMagic), (double)TimeCurrent());
   GsxSettingsAuditAppend(force ? "LOAD" : "DELTA", body);
  }

void GsxSettingsNotifyLoad(const GsxTgConfig &cfg,
                           const long magic,
                           const int scoutInstanceId,
                           const string host,
                           const bool deskExecute,
                           const string exitMode)
  {
   GsxSettingsSnapshot snap;
   GsxSettingsBuild(magic, scoutInstanceId, host, deskExecute, exitMode, snap);
   string body = GsxSettingsFormatLoad(snap);
   string fp = GsxSettingsFingerprint(snap);
   GsxSettingsNotify(cfg, body, fp, true);
   g_gsxSetPrev = snap;
  }

void GsxSettingsAnnounce(const string action)
  {
   if(!g_gsxSetBound || !g_gsxSetCfg.enable)
      return;
   // Desk owns SETTINGS when HB fresh; chart only on failover
   if(g_gsxSetHost == "chart" && !GsxTgChartMayOwnDeals(g_gsxSetMagic))
      return;
   if(g_gsxSetHost == "desk")
      GsxTgDeskHeartbeat(g_gsxSetMagic);

   GsxSettingsSnapshot snap;
   GsxSettingsBuild(g_gsxSetMagic, g_gsxSetScoutId, g_gsxSetHost,
                    g_gsxSetDeskExec, g_gsxSetExitMode, snap);
   string body = GsxSettingsFormatDelta(g_gsxSetPrev, snap, action);
   string fp = GsxSettingsFingerprint(snap);
   GsxSettingsNotify(g_gsxSetCfg, body, fp, false);
   g_gsxSetPrev = snap;
  }

string GsxSettingsPendingScoutRel(const int scoutId)
  {
   return(StringFormat("%s\\settings\\pending\\ps%d.set",
                       GsxBusTerminalDir(GsxMakeTid()), scoutId));
  }

string GsxSettingsPendingScoutGvName(const int scoutId)
  {
   return(StringFormat("GSX_SET_PEND_PS%d", scoutId));
  }

// Scouter → Desk pending (no HTTP from Scouter)
void GsxSettingsPendingSet(const long magic, const string action)
  {
   if(action == "")
      return;
   if(magic > 0)
     {
      GlobalVariableSet(GsxSettingsPendingGvName(magic), (double)TimeCurrent());
      string rel = GsxSettingsPendingRel(magic);
      GsxEnsureFolderTree(rel);
      int h = FileOpen(rel, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_REWRITE);
      if(h != INVALID_HANDLE)
        {
         FileWriteString(h, action);
         FileClose(h);
        }
     }
  }

void GsxSettingsPendingSetScout(const int scoutId, const long magic, const string action)
  {
   if(action == "" || scoutId <= 0)
      return;
   GsxSettingsPendingSet(magic, action);
   GlobalVariableSet(GsxSettingsPendingScoutGvName(scoutId), (double)TimeCurrent());
   string rel = GsxSettingsPendingScoutRel(scoutId);
   GsxEnsureFolderTree(rel);
   int h = FileOpen(rel, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_REWRITE);
   if(h == INVALID_HANDLE)
      return;
   FileWriteString(h, action);
   FileClose(h);
  }

bool GsxSettingsPendingConsume(const long magic, string &actionOut)
  {
   actionOut = "";
   string gv = GsxSettingsPendingGvName(magic);
   string rel = GsxSettingsPendingRel(magic);
   bool hasGv = GlobalVariableCheck(gv);
   bool hasFile = FileIsExist(rel, FILE_COMMON);
   if(!hasGv && !hasFile)
      return(false);

   if(hasFile)
     {
      int h = FileOpen(rel, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
      if(h != INVALID_HANDLE)
        {
         actionOut = "";
         while(!FileIsEnding(h))
            actionOut += FileReadString(h);
         FileClose(h);
         StringTrimLeft(actionOut);
         StringTrimRight(actionOut);
        }
      FileDelete(rel, FILE_COMMON);
     }
   if(hasGv)
      GlobalVariableDel(gv);
   if(actionOut == "")
      actionOut = "SCOUT";
   return(true);
  }

bool GsxSettingsPendingConsumeScout(const int scoutId, string &actionOut)
  {
   actionOut = "";
   if(scoutId <= 0)
      return(false);
   string gv = GsxSettingsPendingScoutGvName(scoutId);
   string rel = GsxSettingsPendingScoutRel(scoutId);
   bool hasGv = GlobalVariableCheck(gv);
   bool hasFile = FileIsExist(rel, FILE_COMMON);
   if(!hasGv && !hasFile)
      return(false);
   if(hasFile)
     {
      int h = FileOpen(rel, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
      if(h != INVALID_HANDLE)
        {
         while(!FileIsEnding(h))
            actionOut += FileReadString(h);
         FileClose(h);
         StringTrimLeft(actionOut);
         StringTrimRight(actionOut);
        }
      FileDelete(rel, FILE_COMMON);
     }
   if(hasGv)
      GlobalVariableDel(gv);
   if(actionOut == "")
      actionOut = "SCOUT";
   return(true);
  }

void GsxSettingsDrainPending(const GsxTgConfig &cfg)
  {
   if(!g_gsxSetBound)
      return;
   GsxSettingsRebindCfg(cfg);
   string action;
   if(GsxSettingsPendingConsume(g_gsxSetMagic, action))
      GsxSettingsAnnounce(action);
   else if(GsxSettingsPendingConsumeScout(g_gsxSetScoutId, action))
      GsxSettingsAnnounce(action);
  }

#endif // GSX_SETTINGS_NOTIFY_MQH
//+------------------------------------------------------------------+
