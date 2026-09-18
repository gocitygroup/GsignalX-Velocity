//+------------------------------------------------------------------+
//|                                                  ScoutLink.mqh    |
//|  Shared Profit Scouter GV API (RUN/ADVEN/CASH/LOSS/CLOSER/floors).|
//|  Chart EA, Trade Center, and Service hosts write; Scouter reads.  |
//|  Never closes tickets — harvest arm / floors / closer claim only. |
//+------------------------------------------------------------------+
#ifndef GSX_SCOUT_LINK_MQH
#define GSX_SCOUT_LINK_MQH

// Closer host tags (mirror Fleet OWN pattern)
#define GSX_SCOUT_CLOSER_NONE    0
#define GSX_SCOUT_CLOSER_EA      1
#define GSX_SCOUT_CLOSER_SERVICE 2

//+------------------------------------------------------------------+
//| RUN — harvest arm                                                |
//+------------------------------------------------------------------+
string GsxScoutRunVarName(const int instanceId)
  {
   return(StringFormat("PS%d_RUN", instanceId));
  }

void GsxScoutRunSet(const int instanceId, const bool on)
  {
   GlobalVariableSet(GsxScoutRunVarName(instanceId), on ? 1.0 : 0.0);
  }

bool GsxScoutRunGet(const int instanceId, const bool defaultOn = true)
  {
   string name = GsxScoutRunVarName(instanceId);
   if(!GlobalVariableCheck(name))
      return(defaultOn);
   return(GlobalVariableGet(name) > 0.5);
  }

// Linked write: no-op when scout link disabled (entries-only hosts).
void GsxScoutRunSetLinked(const bool linkEnable, const int instanceId, const bool on)
  {
   if(!linkEnable)
      return;
   GsxScoutRunSet(instanceId, on);
  }

//+------------------------------------------------------------------+
//| ADVEN — adverse-bar Auto arm                                     |
//+------------------------------------------------------------------+
string GsxScoutAdvenVarName(const int instanceId)
  {
   return(StringFormat("PS%d_ADVEN", instanceId));
  }

void GsxScoutAdvenSet(const int instanceId, const bool on)
  {
   GlobalVariableSet(GsxScoutAdvenVarName(instanceId), on ? 1.0 : 0.0);
  }

bool GsxScoutAdvenGet(const int instanceId, const bool defaultOn = true)
  {
   string name = GsxScoutAdvenVarName(instanceId);
   if(!GlobalVariableCheck(name))
      return(defaultOn);
   return(GlobalVariableGet(name) > 0.5);
  }

//+------------------------------------------------------------------+
//| CASH — single-floor vs LAYER mode                                |
//+------------------------------------------------------------------+
string GsxScoutCashVarName(const int instanceId)
  {
   return(StringFormat("PS%d_CASH", instanceId));
  }

void GsxScoutCashSet(const int instanceId, const bool on)
  {
   GlobalVariableSet(GsxScoutCashVarName(instanceId), on ? 1.0 : 0.0);
  }

bool GsxScoutCashGet(const int instanceId, const bool defaultOn = true)
  {
   string name = GsxScoutCashVarName(instanceId);
   if(!GlobalVariableCheck(name))
      return(defaultOn);
   return(GlobalVariableGet(name) > 0.5);
  }

//+------------------------------------------------------------------+
//| LOSS — Loss CASH arm                                             |
//+------------------------------------------------------------------+
string GsxScoutLossVarName(const int instanceId)
  {
   return(StringFormat("PS%d_LOSS", instanceId));
  }

void GsxScoutLossSet(const int instanceId, const bool on)
  {
   GlobalVariableSet(GsxScoutLossVarName(instanceId), on ? 1.0 : 0.0);
  }

bool GsxScoutLossGet(const int instanceId, const bool defaultOn = false)
  {
   string name = GsxScoutLossVarName(instanceId);
   if(!GlobalVariableCheck(name))
      return(defaultOn);
   return(GlobalVariableGet(name) > 0.5);
  }

//+------------------------------------------------------------------+
//| CLOSER — exclusive auto-harvest ownership (Service preferred)    |
//| Manual BANK/CUT/FLAT on the EA chart always remain operator OK.  |
//+------------------------------------------------------------------+
string GsxScoutCloserVarName(const int instanceId)
  {
   return(StringFormat("PS%d_CLOSER", instanceId));
  }

string GsxScoutCloserTsVarName(const int instanceId)
  {
   return(StringFormat("PS%d_CLOSER_TS", instanceId));
  }

void GsxScoutCloserSet(const int instanceId, const int host)
  {
   GlobalVariableSet(GsxScoutCloserVarName(instanceId), (double)host);
   GlobalVariableSet(GsxScoutCloserTsVarName(instanceId), (double)TimeCurrent());
  }

int GsxScoutCloserGet(const int instanceId)
  {
   string name = GsxScoutCloserVarName(instanceId);
   if(!GlobalVariableCheck(name))
      return(GSX_SCOUT_CLOSER_NONE);
   int h = (int)GlobalVariableGet(name);
   if(h == GSX_SCOUT_CLOSER_EA || h == GSX_SCOUT_CLOSER_SERVICE)
      return(h);
   return(GSX_SCOUT_CLOSER_NONE);
  }

datetime GsxScoutCloserTsGet(const int instanceId)
  {
   string name = GsxScoutCloserTsVarName(instanceId);
   if(!GlobalVariableCheck(name))
      return(0);
   return((datetime)GlobalVariableGet(name));
  }

void GsxScoutCloserClear(const int instanceId)
  {
   string name = GsxScoutCloserVarName(instanceId);
   string ts  = GsxScoutCloserTsVarName(instanceId);
   if(GlobalVariableCheck(name))
      GlobalVariableDel(name);
   if(GlobalVariableCheck(ts))
      GlobalVariableDel(ts);
  }

// Service claims sole auto-closer and refreshes heartbeat each cycle.
void GsxScoutCloserClaimService(const int instanceId)
  {
   GsxScoutCloserSet(instanceId, GSX_SCOUT_CLOSER_SERVICE);
  }

void GsxScoutCloserReleaseService(const int instanceId)
  {
   if(GsxScoutCloserGet(instanceId) == GSX_SCOUT_CLOSER_SERVICE)
      GsxScoutCloserClear(instanceId);
  }

bool GsxScoutCloserIsService(const int instanceId)
  {
   return(GsxScoutCloserGet(instanceId) == GSX_SCOUT_CLOSER_SERVICE);
  }

// Fresh Service claim window (seconds). Stale/crash → EA resumes auto harvest.
#define GSX_SCOUT_CLOSER_FRESH_SEC  5

bool GsxScoutCloserServiceFresh(const int instanceId)
  {
   if(GsxScoutCloserGet(instanceId) != GSX_SCOUT_CLOSER_SERVICE)
      return(false);
   datetime ts = GsxScoutCloserTsGet(instanceId);
   if(ts <= 0)
      return(false);
   return((TimeCurrent() - ts) <= GSX_SCOUT_CLOSER_FRESH_SEC);
  }

// True when this host may run *automatic* harvest closes.
// Manual EA BANK/CUT/FLAT bypass this (operator override).
bool GsxScoutCloserAllowsCloses(const int instanceId, const bool isServiceHost)
  {
   if(isServiceHost)
      return(true);
   // EA auto-harvest: yield only while Service claim is fresh
   if(GsxScoutCloserServiceFresh(instanceId))
      return(false);
   // Stale SERVICE tag: clear so UI/logs stay honest
   if(GsxScoutCloserGet(instanceId) == GSX_SCOUT_CLOSER_SERVICE)
      GsxScoutCloserClear(instanceId);
   return(true);
  }

//+------------------------------------------------------------------+
//| Live practice floors (desk soft-apply overrides inputs)          |
//+------------------------------------------------------------------+
string GsxScoutFloorVarName(const int instanceId)
  {
   return(StringFormat("PS%d_FLOOR", instanceId));
  }

string GsxScoutMinWinVarName(const int instanceId)
  {
   return(StringFormat("PS%d_MINWIN", instanceId));
  }

string GsxScoutLockArmVarName(const int instanceId)
  {
   return(StringFormat("PS%d_LOCKARM", instanceId));
  }

void GsxScoutFloorsSet(const int instanceId,
                       const double floor,
                       const double minWin,
                       const double lockArm)
  {
   GlobalVariableSet(GsxScoutFloorVarName(instanceId), floor);
   GlobalVariableSet(GsxScoutMinWinVarName(instanceId), minWin);
   GlobalVariableSet(GsxScoutLockArmVarName(instanceId), lockArm);
  }

void GsxScoutFloorsClear(const int instanceId)
  {
   string a = GsxScoutFloorVarName(instanceId);
   string b = GsxScoutMinWinVarName(instanceId);
   string c = GsxScoutLockArmVarName(instanceId);
   if(GlobalVariableCheck(a)) GlobalVariableDel(a);
   if(GlobalVariableCheck(b)) GlobalVariableDel(b);
   if(GlobalVariableCheck(c)) GlobalVariableDel(c);
  }

bool GsxScoutFloorGet(const int instanceId, double &floorOut)
  {
   string name = GsxScoutFloorVarName(instanceId);
   if(!GlobalVariableCheck(name))
      return(false);
   floorOut = GlobalVariableGet(name);
   return(true);
  }

bool GsxScoutMinWinGet(const int instanceId, double &minWinOut)
  {
   string name = GsxScoutMinWinVarName(instanceId);
   if(!GlobalVariableCheck(name))
      return(false);
   minWinOut = GlobalVariableGet(name);
   return(true);
  }

bool GsxScoutLockArmGet(const int instanceId, double &lockArmOut)
  {
   string name = GsxScoutLockArmVarName(instanceId);
   if(!GlobalVariableCheck(name))
      return(false);
   lockArmOut = GlobalVariableGet(name);
   return(true);
  }

//+------------------------------------------------------------------+
//| TRAIL — independent ATR/% auto-trail arm                         |
//+------------------------------------------------------------------+
string GsxScoutTrailVarName(const int instanceId)
  {
   return(StringFormat("PS%d_TRAIL", instanceId));
  }

void GsxScoutTrailSet(const int instanceId, const bool on)
  {
   GlobalVariableSet(GsxScoutTrailVarName(instanceId), on ? 1.0 : 0.0);
  }

bool GsxScoutTrailGet(const int instanceId, const bool defaultOn = false)
  {
   string name = GsxScoutTrailVarName(instanceId);
   if(!GlobalVariableCheck(name))
      return(defaultOn);
   return(GlobalVariableGet(name) > 0.5);
  }

#endif // GSX_SCOUT_LINK_MQH
//+------------------------------------------------------------------+
