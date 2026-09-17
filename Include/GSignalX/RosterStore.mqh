//+------------------------------------------------------------------+
//|                                               RosterStore.mqh     |
//|  Live multisymbol roster persistence (FILE_COMMON + seq GV)       |
//|  Seed from InpSymbolList when CSV missing.                        |
//|  Pair state START/STOP/SUSPEND (v1.26); mute aliases for compat.  |
//+------------------------------------------------------------------+
#ifndef GSX_ROSTER_STORE_MQH
#define GSX_ROSTER_STORE_MQH

#include <GSignalX/BusIO.mqh>
#include <GSignalX/BusProtocol.mqh>
#include <GSignalX/SymbolRoster.mqh>
#include <GSignalX/SymbolCanon.mqh>
#include <GSignalX/SymbolClass.mqh>
#include <GSignalX/Fleet.mqh>

#define GSX_ROSTER_DIR  GSX_BUS_ROOT "\\roster"

#define GSX_PAIR_START    0
#define GSX_PAIR_STOP     1
#define GSX_PAIR_SUSPEND  2

#define GSX_CAT_ALL       0
#define GSX_CAT_FOREX     1
#define GSX_CAT_COMMODITY 2
#define GSX_CAT_CRYPTO    3

#define GSX_CLASS_SOFT_MAX_DEFAULT 8

// FollowDir — per-symbol entry side filter (entries only; does not close).
#ifndef GSX_FOLLOW_AUTO
#define GSX_FOLLOW_AUTO  0
#define GSX_FOLLOW_BUY   1
#define GSX_FOLLOW_SELL  2
#define GSX_FOLLOW_WAIT  3
#endif

#ifndef GSX_FOLLOW_WAIT
#define GSX_FOLLOW_WAIT  3
#endif

// v2.14.1: seq-gated in-memory roster (skip FILE_COMMON + SymbolsTotal resolve)
long   g_gsxRosterCacheMagic = 0;
double g_gsxRosterCacheSeq   = -1.0;
string g_gsxRosterCacheNames[];

//+------------------------------------------------------------------+
string GsxRosterStorePath(const long magic)
  {
   return(StringFormat("%s\\%I64d.csv", GSX_ROSTER_DIR, magic));
  }

string GsxRosterSeqVarName(const long magic)
  {
   return("GSX_SVC_ROSTER_SEQ_" + IntegerToString((int)magic));
  }

string GsxRosterMuteVarName(const long magic, const string symbolCanon)
  {
   return(StringFormat("GSX_SYM_MUTE_%d_%s", (int)magic, symbolCanon));
  }

string GsxRosterStateVarName(const long magic, const string symbolCanon)
  {
   return(StringFormat("GSX_SYM_STATE_%d_%s", (int)magic, symbolCanon));
  }

string GsxRosterPageVarName(const long magic)
  {
   return("GSX_MS_PAGE_" + IntegerToString((int)magic));
  }

string GsxRosterFleetTargetVarName(const long magic)
  {
   return("GSX_MS_FLEET_TARGET_" + IntegerToString((int)magic));
  }

string GsxRosterCatVarName(const long magic)
  {
   return("GSX_MS_CAT_" + IntegerToString((int)magic));
  }

string GsxRosterClassMaxVarName(const long magic)
  {
   return("GSX_MS_CLASS_MAX_" + IntegerToString((int)magic));
  }

string GsxRosterPracBandVarName(const long magic)
  {
   return("GSX_MS_PRAC_BAND_" + IntegerToString((int)magic));
  }

string GsxRosterPracCostVarName(const long magic)
  {
   return("GSX_MS_PRAC_COST_" + IntegerToString((int)magic));
  }

string GsxRosterPracStyleVarName(const long magic)
  {
   return("GSX_MS_PRAC_STYLE_" + IntegerToString((int)magic));
  }

string GsxRosterFlipWaitVarName(const long magic)
  {
   return("GSX_MS_FLIPWAIT_" + IntegerToString((int)magic));
  }

// Trade Center FOLLOW/WAIT — Service Core hot-reloads each cycle.
bool GsxRosterFlipWaitGet(const long magic, const bool defaultWait)
  {
   string name = GsxRosterFlipWaitVarName(magic);
   if(!GlobalVariableCheck(name))
      return(defaultWait);
   return(GlobalVariableGet(name) > 0.5);
  }

void GsxRosterFlipWaitSet(const long magic, const bool waitMode)
  {
   GlobalVariableSet(GsxRosterFlipWaitVarName(magic), waitMode ? 1.0 : 0.0);
  }

//+------------------------------------------------------------------+
//| FollowDir — Follow / Buy / Sell / Wait (per symbol). Entries only.|
//+------------------------------------------------------------------+
string GsxRosterFollowDirVarName(const long magic, const string symbolCanon)
  {
   return(StringFormat("GSX_MS_FOLLOWDIR_%d_%s", (int)magic, symbolCanon));
  }

int GsxRosterFollowDirNormalize(const int mode)
  {
   if(mode == GSX_FOLLOW_BUY || mode == GSX_FOLLOW_SELL || mode == GSX_FOLLOW_WAIT)
      return(mode);
   return(GSX_FOLLOW_AUTO);
  }

string GsxRosterFollowDirLabel(const int mode)
  {
   if(mode == GSX_FOLLOW_BUY)  return("BUY");
   if(mode == GSX_FOLLOW_SELL) return("SELL");
   if(mode == GSX_FOLLOW_WAIT) return("WAIT");
   return("FOLLOW");
  }

int GsxRosterFollowDirGet(const long magic, const string symbol, const int defaultMode = GSX_FOLLOW_AUTO)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return(GsxRosterFollowDirNormalize(defaultMode));
   string name = GsxRosterFollowDirVarName(magic, canon);
   if(!GlobalVariableCheck(name))
      return(GsxRosterFollowDirNormalize(defaultMode));
   return(GsxRosterFollowDirNormalize((int)GlobalVariableGet(name)));
  }

void GsxRosterFollowDirSet(const long magic, const string symbol, const int mode)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return;
   GlobalVariableSet(GsxRosterFollowDirVarName(magic, canon),
                     (double)GsxRosterFollowDirNormalize(mode));
  }

void GsxRosterFollowDirClear(const long magic, const string symbol)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return;
   string name = GsxRosterFollowDirVarName(magic, canon);
   if(GlobalVariableCheck(name))
      GlobalVariableDel(name);
  }

int GsxRosterFollowDirCycle(const long magic, const string symbol)
  {
   int m = GsxRosterFollowDirGet(magic, symbol, GSX_FOLLOW_AUTO);
   if(m == GSX_FOLLOW_AUTO)
      m = GSX_FOLLOW_BUY;
   else if(m == GSX_FOLLOW_BUY)
      m = GSX_FOLLOW_SELL;
   else if(m == GSX_FOLLOW_SELL)
      m = GSX_FOLLOW_WAIT;
   else
      m = GSX_FOLLOW_AUTO;
   GsxRosterFollowDirSet(magic, symbol, m);
   return(m);
  }

void GsxRosterFollowDirSetAll(const long magic, const string &symbols[], const int mode)
  {
   int n = ArraySize(symbols);
   for(int i = 0; i < n; i++)
     {
      if(symbols[i] != "")
         GsxRosterFollowDirSet(magic, symbols[i], mode);
     }
  }

//+------------------------------------------------------------------+
//| Last good direction (Service → Trade Center HIST fallback) v2.07 |
//+------------------------------------------------------------------+
string GsxRosterLastDirVarName(const long magic, const string symbolCanon)
  {
   return(StringFormat("GSX_MS_LASTDIR_%d_%s", (int)magic, symbolCanon));
  }

void GsxRosterLastDirSet(const long magic, const string symbol, const int dir)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "" || dir == 0)
      return;
   GlobalVariableSet(GsxRosterLastDirVarName(magic, canon), (double)dir);
  }

int GsxRosterLastDirGet(const long magic, const string symbol)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return(0);
   string name = GsxRosterLastDirVarName(magic, canon);
   if(!GlobalVariableCheck(name))
      return(0);
   int d = (int)GlobalVariableGet(name);
   if(d > 0) return(1);
   if(d < 0) return(-1);
   return(0);
  }

// Desk/Core: mark symbol for forced onboard calc/bus/fill (ADD / re-ARM)
string GsxRosterOnboardKickVarName(const long magic, const string symbolCanon)
  {
   return(StringFormat("GSX_MS_ONBOARD_%d_%s", (int)magic, symbolCanon));
  }

void GsxRosterOnboardKickSet(const long magic, const string symbol)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return;
   GlobalVariableSet(GsxRosterOnboardKickVarName(magic, canon), (double)TimeCurrent());
  }

void GsxRosterOnboardKickClear(const long magic, const string symbol)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return;
   string name = GsxRosterOnboardKickVarName(magic, canon);
   if(GlobalVariableCheck(name))
      GlobalVariableDel(name);
  }

bool GsxRosterOnboardKickTake(const long magic, const string symbol)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return(false);
   string name = GsxRosterOnboardKickVarName(magic, canon);
   if(!GlobalVariableCheck(name))
      return(false);
   GlobalVariableDel(name);
   return(true);
  }

datetime GsxRosterLastDirTime(const long magic, const string symbol)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return(0);
   string name = GsxRosterLastDirVarName(magic, canon);
   if(!GlobalVariableCheck(name))
      return(0);
   return(GlobalVariableTime(name));
  }

void GsxRosterLastDirClear(const long magic, const string symbol)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return;
   string name = GsxRosterLastDirVarName(magic, canon);
   if(GlobalVariableCheck(name))
      GlobalVariableDel(name);
  }

//+------------------------------------------------------------------+
//| Desk-wide spread IGN (Trade Center → Service) v2.08              |
//+------------------------------------------------------------------+
string GsxRosterSpreadIgnVarName(const long magic)
  {
   return("GSX_MS_SPREADIGN_" + IntegerToString((int)magic));
  }

bool GsxRosterSpreadIgnGet(const long magic, const bool defaultIgn = false)
  {
   string name = GsxRosterSpreadIgnVarName(magic);
   if(!GlobalVariableCheck(name))
      return(defaultIgn);
   return(GlobalVariableGet(name) > 0.5);
  }

void GsxRosterSpreadIgnSet(const long magic, const bool ign)
  {
   GlobalVariableSet(GsxRosterSpreadIgnVarName(magic), ign ? 1.0 : 0.0);
  }

bool GsxRosterSpreadIgnToggle(const long magic)
  {
   bool next = !GsxRosterSpreadIgnGet(magic, false);
   GsxRosterSpreadIgnSet(magic, next);
   return(next);
  }

//+------------------------------------------------------------------+
//| Desk AUTOLOT / FIXED (Trade Center → Service) v2.09              |
//+------------------------------------------------------------------+
string GsxRosterAutoLotVarName(const long magic)
  {
   return("GSX_MS_AUTOLOT_" + IntegerToString((int)magic));
  }

bool GsxRosterAutoLotGet(const long magic, const bool defaultOn = false)
  {
   string name = GsxRosterAutoLotVarName(magic);
   if(!GlobalVariableCheck(name))
      return(defaultOn);
   return(GlobalVariableGet(name) > 0.5);
  }

void GsxRosterAutoLotSet(const long magic, const bool on)
  {
   GlobalVariableSet(GsxRosterAutoLotVarName(magic), on ? 1.0 : 0.0);
  }

// v2.14: seed only when missing — never stomp operator desk/chart toggles on attach
bool GsxRosterAutoLotSeed(const long magic, const bool defaultOn)
  {
   string name = GsxRosterAutoLotVarName(magic);
   if(GlobalVariableCheck(name))
      return(false);
   GsxRosterAutoLotSet(magic, defaultOn);
   return(true);
  }

bool GsxRosterAutoLotToggle(const long magic)
  {
   bool next = !GsxRosterAutoLotGet(magic, false);
   GsxRosterAutoLotSet(magic, next);
   return(next);
  }

//+------------------------------------------------------------------+
//| Desk equity guard % (0=off; cycle 0→5→10→20→0) v2.09             |
//+------------------------------------------------------------------+
string GsxRosterEqGuardVarName(const long magic)
  {
   return("GSX_MS_EQGUARD_" + IntegerToString((int)magic));
  }

double GsxRosterEqGuardNormalize(const double pct)
  {
   if(pct >= 17.5) return(20.0);
   if(pct >= 7.5)  return(10.0);
   if(pct >= 2.5)  return(5.0);
   return(0.0);
  }

double GsxRosterEqGuardGet(const long magic, const double defaultPct = 0.0)
  {
   string name = GsxRosterEqGuardVarName(magic);
   if(!GlobalVariableCheck(name))
      return(GsxRosterEqGuardNormalize(defaultPct));
   return(GsxRosterEqGuardNormalize(GlobalVariableGet(name)));
  }

void GsxRosterEqGuardSet(const long magic, const double pct)
  {
   GlobalVariableSet(GsxRosterEqGuardVarName(magic), GsxRosterEqGuardNormalize(pct));
  }

// v2.14: seed EQ guard only when missing (preserve desk pads across reattach)
bool GsxRosterEqGuardSeed(const long magic, const double defaultPct)
  {
   string name = GsxRosterEqGuardVarName(magic);
   if(GlobalVariableCheck(name))
      return(false);
   GsxRosterEqGuardSet(magic, defaultPct);
   return(true);
  }

double GsxRosterEqGuardCycle(const long magic)
  {
   double cur = GsxRosterEqGuardGet(magic, 0.0);
   double next = 0.0;
   if(cur <= 0.0)       next = 5.0;
   else if(cur < 7.5)   next = 10.0;
   else if(cur < 17.5)  next = 20.0;
   else                 next = 0.0;
   GsxRosterEqGuardSet(magic, next);
   return(next);
  }

string GsxRosterEqGuardLabel(const double pct)
  {
   double p = GsxRosterEqGuardNormalize(pct);
   if(p <= 0.0) return("EQ OFF");
   return(StringFormat("EQ %.0f%%", p));
  }

//+------------------------------------------------------------------+
//| Desk drill seconds left (Service → Trade Center) v2.10           |
//+------------------------------------------------------------------+
string GsxRosterDrillSecVarName(const long magic)
  {
   return("GSX_MS_DRILLSEC_" + IntegerToString((int)magic));
  }

void GsxRosterDrillSecSet(const long magic, const int secLeft)
  {
   GlobalVariableSet(GsxRosterDrillSecVarName(magic), (double)MathMax(0, secLeft));
  }

int GsxRosterDrillSecGet(const long magic)
  {
   string name = GsxRosterDrillSecVarName(magic);
   if(!GlobalVariableCheck(name))
      return(0);
   return((int)GlobalVariableGet(name));
  }

// Desk → Service: force (re)start drill on PLAY / ADD under PLAY (v2.10.1)
string GsxRosterDrillKickVarName(const long magic)
  {
   return("GSX_MS_DRILLKICK_" + IntegerToString((int)magic));
  }

void GsxRosterDrillKickSet(const long magic)
  {
   GlobalVariableSet(GsxRosterDrillKickVarName(magic), (double)TimeCurrent());
  }

bool GsxRosterDrillKickTake(const long magic)
  {
   string name = GsxRosterDrillKickVarName(magic);
   if(!GlobalVariableCheck(name))
      return(false);
   double v = GlobalVariableGet(name);
   GlobalVariableDel(name);
   return(v > 0.0);
  }

//+------------------------------------------------------------------+
//| Desk timeframe — Trade Center chart Period → Service (fallback M5)|
//+------------------------------------------------------------------+
string GsxRosterTimeframeVarName(const long magic)
  {
   return("GSX_MS_TF_" + IntegerToString((int)magic));
  }

bool GsxRosterTimeframeValid(const ENUM_TIMEFRAMES tf)
  {
   if(tf == PERIOD_CURRENT)
      return(false);
   int sec = PeriodSeconds(tf);
   return(sec > 0);
  }

void GsxRosterTimeframeSet(const long magic, const ENUM_TIMEFRAMES tf)
  {
   GlobalVariableSet(GsxRosterTimeframeVarName(magic), (double)(int)tf);
  }

ENUM_TIMEFRAMES GsxRosterTimeframeGet(const long magic, const ENUM_TIMEFRAMES fallback = PERIOD_M5)
  {
   string name = GsxRosterTimeframeVarName(magic);
   ENUM_TIMEFRAMES fb = fallback;
   if(!GsxRosterTimeframeValid(fb))
      fb = PERIOD_M5;
   if(!GlobalVariableCheck(name))
      return(fb);
   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)(int)GlobalVariableGet(name);
   if(!GsxRosterTimeframeValid(tf))
      return(fb);
   return(tf);
  }

//+------------------------------------------------------------------+
double GsxRosterSeqGet(const long magic)
  {
   string name = GsxRosterSeqVarName(magic);
   if(!GlobalVariableCheck(name))
      return(0.0);
   return(GlobalVariableGet(name));
  }

double GsxRosterSeqBump(const long magic)
  {
   double v = GsxRosterSeqGet(magic) + 1.0;
   GlobalVariableSet(GsxRosterSeqVarName(magic), v);
   return(v);
  }

void GsxRosterSeqSet(const long magic, const double seq)
  {
   GlobalVariableSet(GsxRosterSeqVarName(magic), seq);
  }

//+------------------------------------------------------------------+
string GsxRosterStateLabel(const int state)
  {
   if(state == GSX_PAIR_STOP)    return("STOP");
   if(state == GSX_PAIR_SUSPEND) return("SUSPEND");
   return("START");
  }

int GsxRosterStateNormalize(const int state)
  {
   if(state == GSX_PAIR_STOP || state == GSX_PAIR_SUSPEND)
      return(state);
   return(GSX_PAIR_START);
  }

int GsxRosterStateGet(const long magic, const string symbol)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return(GSX_PAIR_START);

   string stateName = GsxRosterStateVarName(magic, canon);
   if(GlobalVariableCheck(stateName))
      return(GsxRosterStateNormalize((int)GlobalVariableGet(stateName)));

   // migrate legacy mute → STOP once
   string muteName = GsxRosterMuteVarName(magic, canon);
   if(GlobalVariableCheck(muteName) && GlobalVariableGet(muteName) > 0.5)
     {
      GlobalVariableSet(stateName, (double)GSX_PAIR_STOP);
      return(GSX_PAIR_STOP);
     }
   return(GSX_PAIR_START);
  }

void GsxRosterStateSet(const long magic, const string symbol, const int state)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return;
   int st = GsxRosterStateNormalize(state);
   GlobalVariableSet(GsxRosterStateVarName(magic, canon), (double)st);
   // keep mute GV in sync for older readers
   GlobalVariableSet(GsxRosterMuteVarName(magic, canon),
                     (st == GSX_PAIR_START) ? 0.0 : 1.0);
  }

void GsxRosterStateClear(const long magic, const string symbol)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return;
   string sn = GsxRosterStateVarName(magic, canon);
   string mn = GsxRosterMuteVarName(magic, canon);
   if(GlobalVariableCheck(sn))
      GlobalVariableDel(sn);
   if(GlobalVariableCheck(mn))
      GlobalVariableDel(mn);
  }

void GsxRosterStateSetAll(const long magic, const string &symbols[], const int state)
  {
   int n = ArraySize(symbols);
   for(int i = 0; i < n; i++)
     {
      if(symbols[i] != "")
         GsxRosterStateSet(magic, symbols[i], state);
     }
  }

int GsxRosterStateCycle(const long magic, const string symbol)
  {
   int st = GsxRosterStateGet(magic, symbol);
   if(st == GSX_PAIR_START)
      st = GSX_PAIR_STOP;
   else if(st == GSX_PAIR_STOP)
      st = GSX_PAIR_SUSPEND;
   else
      st = GSX_PAIR_START;
   GsxRosterStateSet(magic, symbol, st);
   return(st);
  }

bool GsxRosterIsFillBlocked(const long magic, const string symbol)
  {
   return(GsxRosterStateGet(magic, symbol) != GSX_PAIR_START);
  }

bool GsxRosterIsFleetCandidate(const long magic, const string symbol)
  {
   return(GsxRosterStateGet(magic, symbol) == GSX_PAIR_START);
  }

//+------------------------------------------------------------------+
//| Mute aliases (compat): mute == not START                          |
//+------------------------------------------------------------------+
bool GsxRosterMuteGet(const long magic, const string symbol)
  {
   return(GsxRosterIsFillBlocked(magic, symbol));
  }

void GsxRosterMuteSet(const long magic, const string symbol, const bool mute)
  {
   GsxRosterStateSet(magic, symbol, mute ? GSX_PAIR_STOP : GSX_PAIR_START);
  }

void GsxRosterMuteToggle(const long magic, const string symbol)
  {
   GsxRosterMuteSet(magic, symbol, !GsxRosterMuteGet(magic, symbol));
  }

//+------------------------------------------------------------------+
int GsxRosterPageGet(const long magic)
  {
   string name = GsxRosterPageVarName(magic);
   if(!GlobalVariableCheck(name))
      return(0);
   int p = (int)GlobalVariableGet(name);
   return(p < 0 ? 0 : p);
  }

void GsxRosterPageSet(const long magic, const int page)
  {
   GlobalVariableSet(GsxRosterPageVarName(magic), (double)MathMax(0, page));
  }

int GsxRosterCatGet(const long magic)
  {
   string name = GsxRosterCatVarName(magic);
   if(!GlobalVariableCheck(name))
      return(GSX_CAT_ALL);
   int c = (int)GlobalVariableGet(name);
   if(c < GSX_CAT_ALL || c > GSX_CAT_CRYPTO)
      return(GSX_CAT_ALL);
   return(c);
  }

void GsxRosterCatSet(const long magic, const int cat)
  {
   int c = cat;
   if(c < GSX_CAT_ALL || c > GSX_CAT_CRYPTO)
      c = GSX_CAT_ALL;
   GlobalVariableSet(GsxRosterCatVarName(magic), (double)c);
  }

int GsxRosterClassMaxGet(const long magic)
  {
   string name = GsxRosterClassMaxVarName(magic);
   if(!GlobalVariableCheck(name))
      return(GSX_CLASS_SOFT_MAX_DEFAULT);
   int m = (int)GlobalVariableGet(name);
   return(m < 4 ? 4 : m);   // capacity at least 4 per category
  }

void GsxRosterClassMaxSet(const long magic, const int softMax)
  {
   GlobalVariableSet(GsxRosterClassMaxVarName(magic),
                     (double)MathMax(4, softMax));
  }

//+------------------------------------------------------------------+
//| Event SKIP block GVs (written by EventGate poll; read by Core)   |
//+------------------------------------------------------------------+
#define GSX_EVT_MODE_TRADE  0
#define GSX_EVT_MODE_SKIP   1

string GsxEventModeVar(const long magic)
  {
   return("GSX_EVT_MODE_" + IntegerToString((int)magic));
  }

string GsxEventBlockVar(const long magic, const string canon)
  {
   return(StringFormat("GSX_EVT_BLOCK_%d_%s", (int)magic, canon));
  }

int GsxEventModeGet(const long magic)
  {
   string n = GsxEventModeVar(magic);
   if(!GlobalVariableCheck(n))
      return(GSX_EVT_MODE_TRADE);
   int m = (int)GlobalVariableGet(n);
   return(m == GSX_EVT_MODE_SKIP ? GSX_EVT_MODE_SKIP : GSX_EVT_MODE_TRADE);
  }

void GsxEventModeSet(const long magic, const int mode)
  {
   GlobalVariableSet(GsxEventModeVar(magic),
                     (double)(mode == GSX_EVT_MODE_SKIP ? GSX_EVT_MODE_SKIP : GSX_EVT_MODE_TRADE));
  }

void GsxEventModeToggle(const long magic)
  {
   int m = GsxEventModeGet(magic);
   GsxEventModeSet(magic, (m == GSX_EVT_MODE_SKIP ? GSX_EVT_MODE_TRADE : GSX_EVT_MODE_SKIP));
  }

string GsxEventModeLabel(const int mode)
  {
   return(mode == GSX_EVT_MODE_SKIP ? "SKIP" : "TRADE");
  }

bool GsxEventBlocksSymbol(const long magic, const string symbol)
  {
   if(GsxEventModeGet(magic) != GSX_EVT_MODE_SKIP)
      return(false);
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return(false);
   string n = GsxEventBlockVar(magic, canon);
   if(!GlobalVariableCheck(n))
      return(false);
   return(GlobalVariableGet(n) > 0.5);
  }

void GsxEventBlockClearAll(const long magic, const string &roster[])
  {
   for(int i = 0; i < ArraySize(roster); i++)
     {
      string canon = GsxSymbolCanon(roster[i]);
      if(canon == "")
         continue;
      GlobalVariableSet(GsxEventBlockVar(magic, canon), 0.0);
     }
  }

void GsxEventBlockSet(const long magic, const string symbol, const bool blocked)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return;
   GlobalVariableSet(GsxEventBlockVar(magic, canon), blocked ? 1.0 : 0.0);
  }

//+------------------------------------------------------------------+
//| Fleet target override: >0 means UI overrides Service input       |
//+------------------------------------------------------------------+
int GsxRosterFleetTargetGet(const long magic)
  {
   string name = GsxRosterFleetTargetVarName(magic);
   if(!GlobalVariableCheck(name))
      return(0);
   int t = (int)GlobalVariableGet(name);
   return(t < 0 ? 0 : t);
  }

void GsxRosterFleetTargetSet(const long magic, const int target)
  {
   GlobalVariableSet(GsxRosterFleetTargetVarName(magic), (double)MathMax(0, target));
  }

//+------------------------------------------------------------------+
//| Practice coach selection (Trade Center soft tips; not risk math) |
//+------------------------------------------------------------------+
int GsxRosterPracBandGet(const long magic)
  {
   string name = GsxRosterPracBandVarName(magic);
   if(!GlobalVariableCheck(name))
      return(100);
   int b = (int)GlobalVariableGet(name);
   if(b == 20 || b == 50 || b == 100)
      return(b);
   return(100);
  }

void GsxRosterPracBandSet(const long magic, const int band)
  {
   int b = band;
   if(b != 20 && b != 50 && b != 100)
      b = 100;
   GlobalVariableSet(GsxRosterPracBandVarName(magic), (double)b);
  }

int GsxRosterPracCostGet(const long magic)
  {
   string name = GsxRosterPracCostVarName(magic);
   if(!GlobalVariableCheck(name))
      return(0); // RAW
   int c = (int)GlobalVariableGet(name);
   return(c == 1 ? 1 : 0);
  }

void GsxRosterPracCostSet(const long magic, const int cost)
  {
   GlobalVariableSet(GsxRosterPracCostVarName(magic), (double)(cost == 1 ? 1 : 0));
  }

int GsxRosterPracStyleGet(const long magic)
  {
   string name = GsxRosterPracStyleVarName(magic);
   if(!GlobalVariableCheck(name))
      return(1); // DAY
   int s = (int)GlobalVariableGet(name);
   if(s == 0 || s == 2)
      return(s);
   return(1);
  }

void GsxRosterPracStyleSet(const long magic, const int style)
  {
   int s = style;
   if(s != 0 && s != 2)
      s = 1;
   GlobalVariableSet(GsxRosterPracStyleVarName(magic), (double)s);
  }

//+------------------------------------------------------------------+
string GsxRosterJoinCsv(const string &names[])
  {
   string body = "";
   for(int i = 0; i < ArraySize(names); i++)
     {
      string s = names[i];
      StringTrimLeft(s);
      StringTrimRight(s);
      if(s == "")
         continue;
      if(body != "")
         body += ",";
      body += s;
     }
   return(body);
  }

bool GsxRosterContains(const string &names[], const string symbol)
  {
   string want = GsxSymbolCanon(symbol);
   if(want == "" && symbol == "")
      return(false);
   for(int i = 0; i < ArraySize(names); i++)
     {
      if(names[i] == symbol)
         return(true);
      if(want != "" && GsxSymbolCanon(names[i]) == want)
         return(true);
     }
   return(false);
  }

int GsxRosterCountByClass(const string &names[], const ENUM_GSX_SYM_CLASS cls)
  {
   int n = 0;
   for(int i = 0; i < ArraySize(names); i++)
      if(GsxSymbolClass(names[i]) == cls)
         n++;
   return(n);
  }

bool GsxRosterClassAtCap(const string &names[],
                         const ENUM_GSX_SYM_CLASS cls,
                         const int softMax)
  {
   if(cls == GSX_CLASS_OTHER)
      return(false);
   int cap = (softMax < 4 ? 4 : softMax);
   return(GsxRosterCountByClass(names, cls) >= cap);
  }

bool GsxRosterAdd(string &names[], const string symbol)
  {
   if(symbol == "")
      return(false);
   if(GsxRosterContains(names, symbol))
      return(false);
   string one[];
   ArrayResize(one, 1);
   one[0] = symbol;
   GsxRosterResolve(one);
   GsxRosterSelect(one);
   int n = ArraySize(names);
   ArrayResize(names, n + 1);
   names[n] = one[0];
   return(true);
  }

// Default automation for a newly added pair (Follow + START).
void GsxRosterOnboardSymbol(const long magic, const string symbol)
  {
   if(symbol == "")
      return;
   GsxRosterStateSet(magic, symbol, GSX_PAIR_START);
   GsxRosterFollowDirSet(magic, symbol, GSX_FOLLOW_AUTO);
  }

// Clear per-symbol automation meta (FollowDir / state / mute / lastDir / onboard).
// Does not touch positions. Caller cancels pendings separately.
void GsxRosterClearSymbolMeta(const long magic, const string symbol)
  {
   GsxRosterFollowDirClear(magic, symbol);
   GsxRosterStateClear(magic, symbol);
   GsxRosterLastDirClear(magic, symbol);
   GsxRosterOnboardKickClear(magic, symbol);
  }

// capacity-aware ADD; reason set on failure
bool GsxRosterAddCapped(string &names[],
                        const string symbol,
                        const int softMax,
                        string &reason)
  {
   reason = "";
   if(symbol == "")
     {
      reason = "empty";
      return(false);
     }

   string one[];
   ArrayResize(one, 1);
   one[0] = symbol;
   GsxRosterResolve(one);
   GsxRosterSelect(one);
   string resolved = one[0];
   if(resolved == "")
     {
      reason = "unresolved";
      return(false);
     }
   // Canon-aware duplicate (blocks EURUSD vs EURUSDm / suffix twins)
   if(GsxRosterContains(names, resolved))
     {
      reason = "duplicate";
      return(false);
     }

   ENUM_GSX_SYM_CLASS cls = GsxSymbolClass(resolved);
   if(GsxRosterClassAtCap(names, cls, softMax))
     {
      reason = GsxSymClassLabel(cls) + " at cap " + IntegerToString(MathMax(4, softMax));
      return(false);
     }

   int n = ArraySize(names);
   ArrayResize(names, n + 1);
   names[n] = resolved;
   return(true);
  }

// Chart-attach / desk-ADD parity: fully enable signal + trade for one symbol.
// - resolve/select into Market Watch
// - add to roster when missing (capacity-aware)
// - START + FOLLOW
// - PLAY + drill kick so Service opens a fill window
// - ensure fleet target has room for this candidate
bool GsxRosterActivatePair(const long magic,
                           const string symbol,
                           string &roster[],
                           const int classSoftMax,
                           const bool addIfMissing,
                           string &reason)
  {
   reason = "";
   if(symbol == "")
     {
      reason = "empty symbol";
      return(false);
     }

   string one[];
   ArrayResize(one, 1);
   one[0] = symbol;
   GsxRosterResolve(one);
   GsxRosterSelect(one);
   string sym = one[0];
   if(sym == "")
     {
      reason = "unresolved";
      return(false);
     }

   bool added = false;
   if(!GsxRosterContains(roster, sym))
     {
      if(!addIfMissing)
        {
         reason = "not on roster";
         return(false);
        }
      string addWhy = "";
      if(!GsxRosterAddCapped(roster, sym, classSoftMax, addWhy))
        {
         reason = (addWhy != "" ? addWhy : "add failed");
         return(false);
        }
      added = true;
     }

   GsxRosterOnboardSymbol(magic, sym);
   // Do NOT clear LastDir — wiping it blanks desk DIR until bus/live catches up.
   // Force Core onboard so ADD/re-ARM gets priority calc + fill (even if already on roster).
   GsxRosterOnboardKickSet(magic, sym);

   // Always reserve a fleet slot for this activated pair (do not stick at default 4)
   int target = GsxRosterFleetTargetGet(magic);
   if(target <= 0)
      target = 4;
   int active = GsxFleetActivePairs(magic);
   int need = active + 1;
   // ADD always grows capacity by one from current target when already at/over cap
   if(added && target <= active)
      need = active + 1;
   if(target < need)
     {
      GsxRosterFleetTargetSet(magic, need);
      target = need;
     }

   // v2.14: do NOT force PLAY — STOPPED desk stays STOPPED; operator must PLAY
   GsxRosterDrillKickSet(magic);

   if(!GsxRosterStoreSave(magic, roster, true))
     {
      reason = "roster save failed";
      return(false);
     }

   string ownNote = GsxFleetServiceOwns(magic) ? "OWN" : "Service not OWN";
   reason = StringFormat("%s %s · START+FOLLOW · PLAY · fleet≥%d · %s",
                         (added ? "ADD" : "ARM"), sym, target, ownNote);
   return(true);
  }

void GsxRosterDedupeInPlace(string &names[])
  {
   string out[];
   ArrayResize(out, 0);
   for(int i = 0; i < ArraySize(names); i++)
     {
      if(names[i] == "")
         continue;
      if(GsxRosterContains(out, names[i]))
         continue;
      int n = ArraySize(out);
      ArrayResize(out, n + 1);
      out[n] = names[i];
     }
   ArrayResize(names, ArraySize(out));
   for(int i = 0; i < ArraySize(out); i++)
      names[i] = out[i];
  }

bool GsxRosterRemove(string &names[], const string symbol)
  {
   string want = GsxSymbolCanon(symbol);
   int idx = -1;
   for(int i = 0; i < ArraySize(names); i++)
     {
      if(names[i] == symbol || (want != "" && GsxSymbolCanon(names[i]) == want))
        {
         idx = i;
         break;
        }
     }
   if(idx < 0)
      return(false);
   for(int j = idx; j < ArraySize(names) - 1; j++)
      names[j] = names[j + 1];
   ArrayResize(names, ArraySize(names) - 1);
   return(true);
  }

void GsxRosterFilterByCat(const string &names[],
                          const int cat,
                          string &out[])
  {
   ArrayResize(out, 0);
   for(int i = 0; i < ArraySize(names); i++)
     {
      ENUM_GSX_SYM_CLASS cls = GsxSymbolClass(names[i]);
      bool keep = false;
      if(cat == GSX_CAT_ALL)
         keep = true;
      else if(cat == GSX_CAT_FOREX && cls == GSX_CLASS_FOREX)
         keep = true;
      else if(cat == GSX_CAT_COMMODITY && cls == GSX_CLASS_COMMODITY)
         keep = true;
      else if(cat == GSX_CAT_CRYPTO && cls == GSX_CLASS_CRYPTO)
         keep = true;
      if(!keep)
         continue;
      int n = ArraySize(out);
      ArrayResize(out, n + 1);
      out[n] = names[i];
     }
  }

//+------------------------------------------------------------------+
void GsxRosterStoreCachePut(const long magic, const string &names[])
  {
   g_gsxRosterCacheMagic = magic;
   g_gsxRosterCacheSeq   = GsxRosterSeqGet(magic);
   ArrayCopy(g_gsxRosterCacheNames, names);
  }

bool GsxRosterStoreCacheTry(const long magic, string &names[])
  {
   double seq = GsxRosterSeqGet(magic);
   if(g_gsxRosterCacheMagic != magic ||
      g_gsxRosterCacheSeq != seq ||
      ArraySize(g_gsxRosterCacheNames) <= 0)
      return(false);
   ArrayCopy(names, g_gsxRosterCacheNames);
   return(true);
  }

bool GsxRosterStoreSave(const long magic, const string &names[], const bool bumpSeq = true)
  {
   string path = GsxRosterStorePath(magic);
   string body = GsxRosterJoinCsv(names);
   if(!GsxBusWriteAtomic(path, body))
      return(false);
   if(bumpSeq)
      GsxRosterSeqBump(magic);
   GsxRosterStoreCachePut(magic, names);
   return(true);
  }

bool GsxRosterStoreLoad(const long magic, string &names[])
  {
   ArrayResize(names, 0);
   if(GsxRosterStoreCacheTry(magic, names))
      return(true);

   string path = GsxRosterStorePath(magic);
   string body = GsxBusReadAll(path);
   if(body == "")
      return(false);
   // allow newlines or commas
   StringReplace(body, "\r", "");
   StringReplace(body, "\n", ",");
   GsxRosterParse(body, names);
   GsxRosterResolve(names);
   GsxRosterSelect(names);
   GsxRosterDedupeInPlace(names);
   if(ArraySize(names) <= 0)
      return(false);
   GsxRosterStoreCachePut(magic, names);
   return(true);
  }

bool GsxRosterStoreExists(const long magic)
  {
   return(FileIsExist(GsxRosterStorePath(magic), FILE_COMMON));
  }

//+------------------------------------------------------------------+
//| Load CSV if present; otherwise seed from CSV string and save     |
//+------------------------------------------------------------------+
int GsxRosterStoreEnsure(const long magic, const string seedCsv, string &names[])
  {
   if(GsxRosterStoreLoad(magic, names))
      return(ArraySize(names));

   GsxRosterParse(seedCsv, names);
   GsxRosterResolve(names);
   GsxRosterSelect(names);
   if(ArraySize(names) > 0)
      GsxRosterStoreSave(magic, names, true);
   return(ArraySize(names));
  }

#endif // GSX_ROSTER_STORE_MQH
//+------------------------------------------------------------------+
