//+------------------------------------------------------------------+
//|                                                       Core.mqh    |
//|  GSignalX Service orchestration (include AFTER host inputs).      |
//|                                                                   |
//|  Required host inputs (Service defines; Core reads by name):      |
//|    InpSymbolList, InpTimeframe, InpCycleMs,                       |
//|    InpFleetEnable, InpFleetTargetPairs, InpFleetFillCooldownSec, |
//|    InpMagic, InpSlippage, InpComment, InpLookback, InpEvalClosedBar,|
//|    InpPivotPrd, InpPPFactor, InpPPAtrLen,                         |
//|    InpStLen, InpStMult, InpUseMA, InpMaLen,                       |
//|    InpBBLen, InpBBMult, InpRiskAtrLen,                            |
//|    InpMode, InpTrigPP, InpTrigST, InpTrigSBT, InpMinAgree,        |
//|    InpAllowLong, InpAllowShort,                                   |
//|    InpEntryMode, InpOffsetUnit, InpLimitOffset, InpStopOffset,    |
//|    InpPendFromSignalOpen, InpPendMaxAgeMin,                       |
//|    InpUseStop, InpStopMult, InpStrategicStopEnable,               |
//|    InpStrategicStopMult, InpUseTarget, InpTargetMult,             |
//|    InpStratStopUseDailyAtr, InpStratStopDailyAtrLen,               |
//|    InpStratStopDailyFloorMult, InpStratStopClassMultFx/Cmd/Cr,    |
//|    InpStratStopRangeBars, InpStratStopRangeMult,                  |
//|    InpStratStopHardCapMult, InpStratStopJitterEnable,             |
//|    InpStratStopJitterPct, InpStratStopMicroPts,                   |
//|    InpRiskMode, InpRiskPct, InpFixedLot, InpMaxLot,               |
//|    InpAutoLotDefault, InpMaxSpreadPt, InpIgnoreSpreadDefault,     |
//|    InpStaleTickSec, InpBlockWeekend, InpUseSessions,              |
//|    InpUseHourFilter, InpStartHour, InpEndHour,                    |
//|    InpFridayStop, InpFridayStopHr,                                |
//|    InpCryptoAllowWeekend, InpCryptoExtraList,                     |
//|    InpBusEnable, InpSwingStartHour, InpSwingEndHour,              |
//|    InpVerboseSignals, InpRespectChartRunState,                    |
//|    InpFlipWaitDefault, InpScoutLinkEnable, InpScoutInstanceID,    |
//|    InpEngineBudgetPerCycle, InpBusFullSyncSec (v2.01)             |
//|    InpFleetFillsPerCycle, InpSignalMaxAgeSec (v2.06)              |
//|    InpDrillEnable, InpDrillMinutes, InpDrillAllowReentry (v2.10)   |
//|    InpContinuousFleet (v2.13; optional continuous fills)          |
//|                                                                   |
//|  Enums may be redefined in the host; Core uses int casts.         |
//+------------------------------------------------------------------+
#ifndef GSX_CORE_MQH
#define GSX_CORE_MQH

#include <Trade\Trade.mqh>
#include <GSignalX/SymbolRoster.mqh>
#include <GSignalX/RosterStore.mqh>
#include <GSignalX/Engines.mqh>
#include <GSignalX/MarketGates.mqh>
#include <GSignalX/Fleet.mqh>
#include <GSignalX/ScoutLink.mqh>
#include <GSignalX/EntryExec.mqh>
#include <GSignalX/SignalBus.mqh>
#include <GSignalX/LotSizing.mqh>
#include <GSignalX/PropRisk.mqh>

//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
CTrade         g_gsxTrade;
string         g_roster[];
GsxEngineState g_eng[];
datetime       g_formWatch[];   // bar-0 open time last used for engine calc
string         g_busFp[];       // last published fingerprint per roster slot
double         g_rosterSeqSeen = -1.0;
bool           g_svcEnabled   = true;
bool           g_flipWait     = false;
bool           g_ignoreSpread = false;
bool           g_autoLot      = false;
double         g_eqGuardPct   = 0.0;  // v2.09 desk EQ guard (0=off)
int            g_engineRecalcs = 0;
int            g_fleetFills    = 0;
int            g_fleetActive   = 0;
datetime       g_busLastPub    = 0;
datetime       g_busLastFullSync = 0;
int            g_engBudgetCursor = 0;
int            g_closedCount   = 0;
int            g_closedWins    = 0;
int            g_closedLosses  = 0;
double         g_closedRealized = 0.0;

// Service Telegram hooks (polled by GsignalX_Service)
string   g_coreLastFillFailSym = "";
string   g_coreLastFillFailWhy = "";
datetime g_coreLastFillFailAt  = 0;
int            g_coreBurstBudgetCycles = 0;
int            g_joinDirCache[];   // last joinDir per roster slot (dir-change fill)
datetime       g_joinDirChangedAt[]; // when current joinDir was first observed
bool           g_onboardPending[]; // v2.07: new roster symbols awaiting first calc/bus
string         g_fillSkip[];       // v2.07: last fill-skip reason per slot (bus)
datetime       g_coreLatSigAt = 0;
datetime       g_coreLatFillAt = 0;
string         g_coreLatSym = "";
// v2.10 desk drill (mirrors chart InpDrillMinutes)
datetime       g_coreDrillStart = 0;
bool           g_corePrevRun    = false;
int            g_drillWanted[];   // per-slot locked dir during drill (0=none)
int            g_coreNewOnboard = 0; // symbols added this reload (ADD → refresh drill)
ulong          g_coreCycleStartMs = 0;
ulong          g_coreLastCycleMs  = 0;
datetime       g_coreCycleLogAt   = 0;
int            g_coreHostTag    = GSX_HOST_SERVICE; // desk vs service OWN claimer
bool           g_coreClaimedOwn = false;
// v2.14.1: one fleet scan per cycle — reused by PublishBus / PublishBusIndex / fills
GsxBusFleetSnap g_coreFleetSnap;
bool            g_coreFleetSnapFresh = false;

//+------------------------------------------------------------------+
void GsxEngStateCopy(const GsxEngineState &src, GsxEngineState &dst)
  {
   // Detach dst first so ArrayCopy cannot leave shared buffers with other slots
   GsxEngStateDetach(dst);
   dst.symbol = src.symbol;
   dst.tf = src.tf;
   dst.n = src.n;
   dst.ready = src.ready;
   dst.lastBarTime = src.lastBarTime;
   dst.lastSigDir = src.lastSigDir;
   dst.lastSigIdx = src.lastSigIdx;
   dst.lastSigChangeTime = src.lastSigChangeTime;
   dst.status = src.status;
   ArrayCopy(dst.ppDir, src.ppDir);
   ArrayCopy(dst.stDir, src.stDir);
   ArrayCopy(dst.sbtDir, src.sbtDir);
   ArrayCopy(dst.ppLine, src.ppLine);
   ArrayCopy(dst.stLine, src.stLine);
   ArrayCopy(dst.sbtLine, src.sbtLine);
   ArrayCopy(dst.ma, src.ma);
   ArrayCopy(dst.atrRisk, src.atrRisk);
   ArrayCopy(dst.open, src.open);
   ArrayCopy(dst.high, src.high);
   ArrayCopy(dst.low, src.low);
   ArrayCopy(dst.close, src.close);
   ArrayCopy(dst.barTime, src.barTime);
  }

void GsxEngStateReset(GsxEngineState &st)
  {
   GsxEngStateDetach(st);
   GsxEngStateClearMeta(st);
  }

// True when engine series were computed for this roster slot's symbol+TF.
bool GsxCoreEngOwnsSymbol(const int idx, const string symbol, const ENUM_TIMEFRAMES tf)
  {
   if(idx < 0 || idx >= ArraySize(g_eng) || symbol == "")
      return(false);
   if(!g_eng[idx].ready || g_eng[idx].n < 1)
      return(false);
   if(g_eng[idx].symbol != symbol)
      return(false);
   if(tf != PERIOD_CURRENT && g_eng[idx].tf != 0 && g_eng[idx].tf != (int)tf)
      return(false);
   return(true);
  }

int GsxCoreEngineBudget()
  {
   int b = InpEngineBudgetPerCycle;
   if(b <= 0)
      b = 4;
   if(g_coreBurstBudgetCycles > 0)
      return(MathMax(b, MathMin(ArraySize(g_roster), b * 2)));
   return(b);
  }

int GsxCoreFillsPerCycle()
  {
   int n = InpFleetFillsPerCycle;
   if(n <= 0)
      return(2);
   return(n);
  }

int GsxCoreSignalMaxAgeSec()
  {
   int a = InpSignalMaxAgeSec;
   if(a < 0)
      return(15);
   return(a);
  }

bool GsxCoreSignalFresh(const int idx, const int joinDir, string &why)
  {
   why = "";
   int maxAge = GsxCoreSignalMaxAgeSec();
   if(maxAge <= 0)
      return(true);
   if(idx < 0 || idx >= ArraySize(g_roster) || joinDir == 0)
     {
      why = "no signal";
      return(false);
     }
   if(ArraySize(g_joinDirCache) != ArraySize(g_roster))
      ArrayResize(g_joinDirCache, ArraySize(g_roster));
   if(ArraySize(g_joinDirChangedAt) != ArraySize(g_roster))
      ArrayResize(g_joinDirChangedAt, ArraySize(g_roster));

   // First fill / never-armed direction: exempt age (onboard + cold start)
   if(g_joinDirCache[idx] == 0)
     {
      if(g_joinDirChangedAt[idx] <= 0)
         g_joinDirChangedAt[idx] = TimeCurrent();
      return(true);
     }

   // Same-dir fleet top-up / already-armed direction: allow
   if(joinDir == g_joinDirCache[idx])
      return(true);

   // Dir-change: stamp once; if aged out, skip this cycle but do NOT poison cache
   // (poisoning permanently skipped fills after brief claim contention).
   if(g_joinDirChangedAt[idx] <= 0)
      g_joinDirChangedAt[idx] = TimeCurrent();
   long age = (long)(TimeCurrent() - g_joinDirChangedAt[idx]);
   if(age > maxAge)
     {
      why = StringFormat("stale signal age=%lds > %d", age, maxAge);
      g_joinDirChangedAt[idx] = 0; // re-arm on next observation
      return(false);
     }
   return(true);
  }

void GsxCoreEnsureSlotMeta(const int n)
  {
   if(ArraySize(g_joinDirCache) != n)
      ArrayResize(g_joinDirCache, n);
   if(ArraySize(g_joinDirChangedAt) != n)
      ArrayResize(g_joinDirChangedAt, n);
   if(ArraySize(g_onboardPending) != n)
      ArrayResize(g_onboardPending, n);
   if(ArraySize(g_fillSkip) != n)
      ArrayResize(g_fillSkip, n);
   if(ArraySize(g_busFp) != n)
      ArrayResize(g_busFp, n);
   if(ArraySize(g_drillWanted) != n)
     {
      int old = ArraySize(g_drillWanted);
      ArrayResize(g_drillWanted, n);
      for(int k = old; k < n; k++)
         g_drillWanted[k] = 0;
     }
  }

int GsxCoreClampDrillMinutes()
  {
   int m = InpDrillMinutes;
   if(m < 5)  m = 5;
   if(m > 15) m = 15;
   return(m);
  }

bool GsxCoreDrillActive()
  {
   if(!InpDrillEnable || g_coreDrillStart == 0)
      return(false);
   int elapsed = (int)((TimeCurrent() - g_coreDrillStart) / 60);
   return(elapsed < GsxCoreClampDrillMinutes());
  }

int GsxCoreDrillSecondsLeft()
  {
   if(!GsxCoreDrillActive())
      return(0);
   int total = GsxCoreClampDrillMinutes() * 60;
   int used  = (int)(TimeCurrent() - g_coreDrillStart);
   int left  = total - used;
   return(left > 0 ? left : 0);
  }

void GsxCoreCancelAllRosterPendings(const string why)
  {
   for(int i = 0; i < ArraySize(g_roster); i++)
     {
      if(g_roster[i] == "")
         continue;
      GsxDeletePendings(g_gsxTrade, g_roster[i], InpMagic, why);
     }
  }

void GsxCoreClearDrill(const string why)
  {
   if(g_coreDrillStart != 0 && InpVerboseSignals)
      PrintFormat("GsignalX Core: drill cleared (%s)", why);
   g_coreDrillStart = 0;
   for(int i = 0; i < ArraySize(g_drillWanted); i++)
      g_drillWanted[i] = 0;
   GsxCoreCancelAllRosterPendings("drill " + why);
  }

void GsxCoreStartDrill()
  {
   if(!InpDrillEnable)
     {
      g_coreDrillStart = 0;
      return;
     }
   g_coreDrillStart = TimeCurrent();
   for(int i = 0; i < ArraySize(g_drillWanted); i++)
      g_drillWanted[i] = 0;
   if(InpVerboseSignals)
      PrintFormat("GsignalX Core: drill window started for %d minutes",
                  GsxCoreClampDrillMinutes());
  }

void GsxCoreRefreshDrill()
  {
   if(!InpDrillEnable)
     {
      g_coreDrillStart = 0;
      return;
     }
   if(g_coreDrillStart == 0)
      return;
   if(!GsxCoreDrillActive())
      GsxCoreClearDrill("window expired");
  }

void GsxCoreSetFillSkip(const int idx, const string reason)
  {
   if(idx < 0)
      return;
   GsxCoreEnsureSlotMeta(ArraySize(g_roster));
   if(idx >= ArraySize(g_fillSkip))
      return;
   g_fillSkip[idx] = reason;
  }

bool GsxCoreAnyOnboardPending()
  {
   for(int i = 0; i < ArraySize(g_onboardPending); i++)
      if(g_onboardPending[i])
         return(true);
   return(false);
  }

void GsxCoreMarkOnboardSettled(const int idx)
  {
   if(idx < 0 || idx >= ArraySize(g_onboardPending))
      return;
   g_onboardPending[idx] = false;
  }

// Terminal onboard outcomes (do not keep retrying forever). Gate skips keep pending.
// History wait is NOT terminal — keep onboard until engines ready or sticky fail.
bool GsxCoreOnboardTerminalSkip(const string skip)
  {
   if(skip == "")
      return(false);
   if(skip == "not START")
      return(true);
   if(StringFind(skip, "FollowDir/") == 0)
      return(true);
   return(false);
  }

int GsxCoreBusFullSyncSec()
  {
   int s = InpBusFullSyncSec;
   if(s <= 0)
      return 3; // v2.06 desk: keep direction ts fresh
   return s;
  }

//+------------------------------------------------------------------+
GsxEngineParams GsxCoreBuildEngineParams()
  {
   GsxEngineParams p;
   p.evalClosedBar = InpEvalClosedBar;
   p.lookback      = InpLookback;
   p.pivotPrd      = InpPivotPrd;
   p.ppFactor      = InpPPFactor;
   p.ppAtrLen      = InpPPAtrLen;
   p.stLen         = InpStLen;
   p.stMult        = InpStMult;
   p.useMA         = InpUseMA;
   p.maLen         = InpMaLen;
   p.bbLen         = InpBBLen;
   p.bbMult        = InpBBMult;
   p.riskAtrLen    = InpRiskAtrLen;
   p.trigPP        = InpTrigPP;
   p.trigST        = InpTrigST;
   p.trigSBT       = InpTrigSBT;
   return(p);
  }

GsxEntryParams GsxCoreBuildEntryParams()
  {
   GsxEntryParams p;
   p.magic               = InpMagic;
   p.slippage            = InpSlippage;
   p.comment             = InpComment;
   p.entryMode           = (int)InpEntryMode;
   p.offsetUnit          = (int)InpOffsetUnit;
   p.limitOffset         = InpLimitOffset;
   p.stopOffset          = InpStopOffset;
   p.pendFromSignalOpen  = InpPendFromSignalOpen;
   p.useStop             = InpUseStop;
   p.stopMult            = InpStopMult;
   p.strategicStopEnable = InpStrategicStopEnable;
   p.strategicStopMult   = InpStrategicStopMult;
   p.useTarget           = InpUseTarget;
   p.targetMult          = InpTargetMult;
   p.autoLot             = g_autoLot;
   p.riskMode            = (int)InpRiskMode;
   p.riskPct             = InpRiskPct;
   p.fixedLot            = InpFixedLot;
   p.maxLot              = InpMaxLot;
   p.verbose             = InpVerboseSignals;
   p.allowLong           = InpAllowLong;
   p.allowShort          = InpAllowShort;
   p.stratUseDailyAtr      = InpStratStopUseDailyAtr;
   p.stratDailyAtrLen      = InpStratStopDailyAtrLen;
   p.stratDailyFloorMult   = InpStratStopDailyFloorMult;
   p.stratClassMultFx      = InpStratStopClassMultFx;
   p.stratClassMultCmd     = InpStratStopClassMultCmd;
   p.stratClassMultCr      = InpStratStopClassMultCr;
   p.stratRangeBars        = InpStratStopRangeBars;
   p.stratRangeMult        = InpStratStopRangeMult;
   p.stratSpreadBaseLimit  = InpMaxSpreadPt;
   p.stratHardCapMult      = InpStratStopHardCapMult;
   p.stratJitterEnable     = InpStratStopJitterEnable;
   p.stratJitterPct        = InpStratStopJitterPct;
   p.stratMicroPts         = InpStratStopMicroPts;
   return(p);
  }

int GsxCoreJoinDir(const int idx, string &why)
  {
   why = "";
   if(idx < 0 || idx >= ArraySize(g_eng) || idx >= ArraySize(g_roster))
      return(0);
   string sym = g_roster[idx];
   if(sym == "")
      return(0);
   // Reject aliased/stale series from another pair (chart-symbol bleed)
   if(!g_eng[idx].ready || g_eng[idx].n < 1)
      return(0);
   if(g_eng[idx].symbol != "" && g_eng[idx].symbol != sym)
     {
      why = "engine symbol mismatch";
      return(0);
     }

   int last = g_eng[idx].n - 1;
   int joinDir = GsxActiveDirectionUnderRules(g_eng[idx], last,
                                              InpTrigPP, InpTrigST, InpTrigSBT,
                                              InpUseMA, (int)InpMode, InpMinAgree, why);
   if(joinDir == 0)
      joinDir = g_eng[idx].lastSigDir;
   // Enabled-trigger majority fallback (never count disabled ST/PP/SBT)
   if(joinDir == 0)
     {
      joinDir = GsxEnabledTriggerMajority(g_eng[idx], last,
                                          InpTrigPP, InpTrigST, InpTrigSBT);
      if(joinDir == 0 && why == "")
         why = "flat dir";
      else if(joinDir != 0)
         why = "";
     }
   return(joinDir);
  }

// Same-process UI shortcut (Dashboard DeskExecute): live DIR/fill_skip without bus lag.
bool GsxCoreLiveRowForSymbol(const string symbol,
                             int &direction,
                             string &fillSkip,
                             bool &ready)
  {
   direction = 0;
   fillSkip = "";
   ready = false;
   if(symbol == "" || ArraySize(g_roster) <= 0)
      return(false);
   string want = GsxSymbolCanon(symbol);
   for(int i = 0; i < ArraySize(g_roster); i++)
     {
      if(g_roster[i] == "")
         continue;
      if(g_roster[i] != symbol &&
         (want == "" || GsxSymbolCanon(g_roster[i]) != want))
         continue;
      ready = g_eng[i].ready;
      fillSkip = (i < ArraySize(g_fillSkip) ? g_fillSkip[i] : "");
      // Never surface another symbol's series as this row's DIR
      if(g_eng[i].ready && g_eng[i].symbol != "" && g_eng[i].symbol != g_roster[i] &&
         g_eng[i].symbol != symbol)
        {
         ready = false;
         fillSkip = "engine symbol mismatch";
         direction = 0;
         return(true);
        }
      string why = "";
      direction = GsxCoreJoinDir(i, why);
      if(direction == 0 && fillSkip == "" && why != "")
         fillSkip = why;
      return(true);
     }
   return(false);
  }

bool GsxCoreGatesOk(const string symbol, string &why)
  {
   why = "";
   if(!GsxIsMarketOpen(symbol, InpStaleTickSec, InpBlockWeekend, InpUseSessions,
                       InpCryptoAllowWeekend, InpCryptoExtraList, why))
      return(false);
   if(!GsxTimeFilterOK(symbol, InpUseHourFilter, InpStartHour, InpEndHour,
                       InpFridayStop, InpFridayStopHr,
                       InpCryptoAllowWeekend, InpCryptoExtraList, why))
      return(false);
   int maxSp = g_ignoreSpread ? 0 : InpMaxSpreadPt;
   // GsxSpreadOK applies class-aware ceilings (CMD/CR wider than FX base)
   if(!GsxSpreadOK(symbol, maxSp, g_ignoreSpread, why))
      return(false);
   return(true);
  }

// Sort fill candidates: lower class-busy count first so CMD/CR are not
// starved by FX-first roster order under a small fleet target.
void GsxCoreSortFillOrderByClassDiversity(int &order[])
  {
   int n = ArraySize(order);
   if(n <= 1)
      return;
   for(int a = 0; a < n - 1; a++)
     {
      for(int b = a + 1; b < n; b++)
        {
         int ia = order[a];
         int ib = order[b];
         int ca = GsxFleetActiveInClass(InpMagic, (int)GsxSymbolClass(g_roster[ia]));
         int cb = GsxFleetActiveInClass(InpMagic, (int)GsxSymbolClass(g_roster[ib]));
         if(cb < ca || (cb == ca && ib < ia))
           {
            order[a] = ib;
            order[b] = ia;
           }
        }
     }
  }

int GsxCoreEffectiveFleetTarget()
  {
   int ov = GsxRosterFleetTargetGet(InpMagic);
   if(ov > 0)
      return(ov);
   return(InpFleetTargetPairs);
  }

void GsxCoreRetireSymbol(const string symbol)
  {
   if(symbol == "")
      return;
   GsxRosterStateSet(InpMagic, symbol, GSX_PAIR_STOP);
   GsxDeletePendings(g_gsxTrade, symbol, InpMagic, "roster retire");
   GsxRosterClearSymbolMeta(InpMagic, symbol);
   if(InpVerboseSignals)
      PrintFormat("GsignalX Core: retired %s (pendings+meta cleared; positions left for Scouter)",
                  symbol);
  }

//+------------------------------------------------------------------+
//| Rebuild engine slots for a new roster, preserving overlapping    |
//| symbols' ready state (v2.01 — avoid full cold restart).          |
//+------------------------------------------------------------------+
void GsxCoreApplyRoster(const string &newRoster[])
  {
   int oldN = ArraySize(g_roster);
   string oldRoster[];
   ArrayResize(oldRoster, oldN);
   GsxEngineState oldEng[];
   ArrayResize(oldEng, oldN);
   datetime oldWatch[];
   ArrayResize(oldWatch, oldN);
   string oldFp[];
   ArrayResize(oldFp, oldN);
   int oldJoin[];
   ArrayResize(oldJoin, oldN);

   for(int i = 0; i < oldN; i++)
     {
      oldRoster[i] = g_roster[i];
      GsxEngStateCopy(g_eng[i], oldEng[i]);
      oldWatch[i] = (i < ArraySize(g_formWatch) ? g_formWatch[i] : 0);
      oldFp[i] = (i < ArraySize(g_busFp) ? g_busFp[i] : "");
      oldJoin[i] = (i < ArraySize(g_joinDirCache) ? g_joinDirCache[i] : 0);
     }

   // Retire symbols that left the roster (entries stop; no position closes)
   for(int j = 0; j < oldN; j++)
     {
      if(oldRoster[j] == "")
         continue;
      bool still = false;
      for(int i = 0; i < ArraySize(newRoster); i++)
        {
         if(newRoster[i] == oldRoster[j])
           {
            still = true;
            break;
           }
        }
      if(!still)
         GsxCoreRetireSymbol(oldRoster[j]);
     }

   int n = ArraySize(newRoster);
   ArrayResize(g_roster, n);
   ArrayResize(g_eng, n);
   ArrayResize(g_formWatch, n);
   ArrayResize(g_busFp, n);
   ArrayResize(g_joinDirCache, n);
   ArrayResize(g_joinDirChangedAt, n);
   ArrayResize(g_onboardPending, n);
   ArrayResize(g_fillSkip, n);
   ArrayResize(g_drillWanted, n);

   int newCount = 0;
   for(int i = 0; i < n; i++)
     {
      g_roster[i] = newRoster[i];
      GsxEngStateReset(g_eng[i]);
      g_formWatch[i] = 0;
      g_busFp[i] = "";
      g_joinDirCache[i] = 0;
      g_joinDirChangedAt[i] = 0;
      g_fillSkip[i] = "";
      g_drillWanted[i] = 0;
      g_onboardPending[i] = true; // assume new until matched

      for(int j = 0; j < oldN; j++)
        {
         if(oldRoster[j] == "" || oldRoster[j] != newRoster[i])
            continue;
         GsxEngStateCopy(oldEng[j], g_eng[i]);
         // Only keep series that were computed for THIS exact symbol
         if(g_eng[i].ready && g_eng[i].symbol == newRoster[i])
           {
            g_formWatch[i] = oldWatch[j];
            g_busFp[i] = oldFp[j];
            g_joinDirCache[i] = oldJoin[j];
            g_onboardPending[i] = false;
           }
         else
           {
            GsxEngStateReset(g_eng[i]);
            g_formWatch[i] = 0;
            g_onboardPending[i] = true;
           }
         break;
        }
      if(g_onboardPending[i] && newRoster[i] != "")
        {
         newCount++;
         // v2.13: prefetch history so onboard is not stuck waiting
         ENUM_TIMEFRAMES tfWarm = GsxRosterTimeframeGet(InpMagic, InpTimeframe);
         if(!GsxRosterTimeframeValid(tfWarm))
            tfWarm = PERIOD_M5;
         GsxEngPrefetchHistory(newRoster[i], tfWarm, InpLookback);
        }
     }

   // Burst until onboard symbols are ready (or fail sticky)
   g_coreBurstBudgetCycles = MathMax(2, (newCount > 0 ? MathMax(8, newCount + 2) : 2));
   g_coreNewOnboard = newCount; // cycle starts drill when RUN (ADD under PLAY)
  }

bool GsxCoreReloadRoster()
  {
   string loaded[];
   if(!GsxRosterStoreLoad(InpMagic, loaded))
     {
      // file missing mid-run: keep current in-memory roster
      return(false);
     }
   GsxCoreApplyRoster(loaded);
   g_rosterSeqSeen = GsxRosterSeqGet(InpMagic);
   if(InpVerboseSignals)
      PrintFormat("GsignalX Core: roster reload n=%d seq=%.0f",
                  ArraySize(g_roster), g_rosterSeqSeen);
   return(true);
  }

void GsxCoreMaybeReloadRoster()
  {
   double seq = GsxRosterSeqGet(InpMagic);
   if(g_rosterSeqSeen < 0.0)
     {
      g_rosterSeqSeen = seq;
      return;
     }
   if(seq != g_rosterSeqSeen)
      GsxCoreReloadRoster();
  }

//+------------------------------------------------------------------+
void GsxCoreInitEx(const int hostTag, const bool claimOwn)
  {
   g_coreHostTag = (hostTag == GSX_HOST_DESK ? GSX_HOST_DESK : GSX_HOST_SERVICE);
   g_coreClaimedOwn = false;

   // Live roster file wins; seed from InpSymbolList when absent.
   GsxRosterStoreEnsure(InpMagic, InpSymbolList, g_roster);
   g_rosterSeqSeen = GsxRosterSeqGet(InpMagic);

   int n = ArraySize(g_roster);
   ArrayResize(g_eng, n);
   ArrayResize(g_formWatch, n);
   ArrayResize(g_busFp, n);
   ArrayResize(g_joinDirCache, n);
   ArrayResize(g_joinDirChangedAt, n);
   ArrayResize(g_onboardPending, n);
   ArrayResize(g_fillSkip, n);
   ArrayResize(g_drillWanted, n);
   g_coreNewOnboard = 0;
   for(int i = 0; i < n; i++)
     {
      GsxEngStateReset(g_eng[i]);
      g_formWatch[i] = 0;
      g_busFp[i] = "";
      g_joinDirCache[i] = 0;
      g_joinDirChangedAt[i] = 0;
      g_fillSkip[i] = "";
      g_drillWanted[i] = 0;
      // v2.13.2: cold start does NOT mark entire roster onboard — that re-fired
      // stale pairs after restart. Only ADD/ActivatePair onboard kicks arm fills.
      g_onboardPending[i] = false;
      if(g_roster[i] != "")
        {
         ENUM_TIMEFRAMES tfWarm = GsxRosterTimeframeValid(InpTimeframe) ? InpTimeframe : PERIOD_M5;
         GsxEngPrefetchHistory(g_roster[i], tfWarm, InpLookback);
        }
     }

   g_svcEnabled   = true;
   g_flipWait     = InpFlipWaitDefault;
   g_ignoreSpread = GsxRosterSpreadIgnGet(InpMagic, InpIgnoreSpreadDefault);
   g_autoLot      = GsxRosterAutoLotGet(InpMagic, InpAutoLotDefault);
   g_eqGuardPct   = GsxRosterEqGuardGet(InpMagic, 0.0);
   g_engineRecalcs = 0;
   g_fleetFills    = 0;
   g_fleetActive   = 0;
   g_busLastPub    = 0;
   g_busLastFullSync = 0;
   g_engBudgetCursor = 0;
   g_closedCount   = 0;
   g_closedWins    = 0;
   g_closedLosses  = 0;
   g_closedRealized = 0.0;

   g_gsxTrade.SetExpertMagicNumber(InpMagic);
   g_gsxTrade.SetDeviationInPoints(InpSlippage);

   if(claimOwn)
     {
      GsxFleetServiceOwnSet(InpMagic, true);
      GsxFleetHostSet(InpMagic, g_coreHostTag);
      g_coreClaimedOwn = true;
     }
   // Do not force RUN here — Trade Center PLAY owns the drill edge.
   if(!GlobalVariableCheck(GsxFleetRunVarName(InpMagic)))
      GsxFleetServiceRunSet(InpMagic, false);
   g_svcEnabled = GsxFleetServiceRunGet(InpMagic);
   g_corePrevRun = g_svcEnabled;
   if(g_svcEnabled)
      GsxCoreStartDrill();
   else
      g_coreDrillStart = 0;

   PrintFormat("GsignalX Core: init roster=%d magic=%I64d host=%s OWN=%d RUN=%d flip=%s autolot=%s seq=%.0f drill=%s",
               n, InpMagic, GsxFleetHostLabel(g_coreHostTag),
               (g_coreClaimedOwn ? 1 : 0), (g_svcEnabled ? 1 : 0),
               (g_flipWait ? "WAIT" : "FOLLOW"),
               (g_autoLot ? "ON" : "FIXED"),
               g_rosterSeqSeen,
               (InpDrillEnable ? IntegerToString(GsxCoreClampDrillMinutes()) + "m" : "off"));
  }

void GsxCoreInit()
  {
   GsxCoreInitEx(GSX_HOST_SERVICE, true);
  }

void GsxCoreDeinit()
  {
   if(g_coreClaimedOwn && GsxFleetHostGet(InpMagic) == g_coreHostTag)
     {
      GsxFleetServiceOwnSet(InpMagic, false);
      GsxFleetHostClear(InpMagic);
     }
   g_coreClaimedOwn = false;
   PrintFormat("GsignalX Core: deinit host=%s OWN=0 magic=%I64d recalcs=%d fills=%d",
               GsxFleetHostLabel(g_coreHostTag), InpMagic, g_engineRecalcs, g_fleetFills);
  }

//+------------------------------------------------------------------+
bool GsxCoreTryFillIndex(const int i, const GsxEntryParams &ep, const int target,
                         const int fillsDoneThisCycle)
  {
   if(i < 0 || i >= ArraySize(g_roster))
      return(false);
   string sym = g_roster[i];
   if(sym == "")
      return(false);

   GsxCoreEnsureSlotMeta(ArraySize(g_roster));
   bool onboard = (i < ArraySize(g_onboardPending) && g_onboardPending[i]);

   if(InpDrillEnable && !InpContinuousFleet && !GsxCoreDrillActive())
     {
      GsxCoreSetFillSkip(i, "drill closed");
      return(false);
     }

   if(!GsxRosterIsFleetCandidate(InpMagic, sym))
     {
      GsxCoreSetFillSkip(i, "not START");
      return(false);
     }
   if(GsxEventBlocksSymbol(InpMagic, sym))
     {
      GsxCoreSetFillSkip(i, "event block");
      return(false);
     }
   if(GsxFleetSymbolBusy(sym, InpMagic))
     {
      GsxCoreSetFillSkip(i, "busy");
      return(false);
     }
   if(!GsxCoreEngOwnsSymbol(i, sym, PERIOD_CURRENT))
     {
      GsxCoreSetFillSkip(i, "engine not ready");
      return(false);
     }

   int active = GsxFleetActivePairs(InpMagic);
   if(active >= target)
     {
      GsxCoreSetFillSkip(i, StringFormat("fleet full %d/%d", active, target));
      return(false);
     }

   string why = "";
   int joinDir = GsxCoreJoinDir(i, why);
   if(joinDir == 0)
     {
      g_joinDirCache[i] = 0;
      GsxCoreSetFillSkip(i, (why != "" ? why : "flat dir"));
      return(false);
     }

   int followDir = GsxRosterFollowDirGet(InpMagic, sym, GSX_FOLLOW_AUTO);
   if(!GsxAllowEntry(joinDir, g_flipWait, InpMagic, followDir))
     {
      GsxCoreSetFillSkip(i, StringFormat("FollowDir/%s", GsxRosterFollowDirLabel(followDir)));
      return(false);
     }

   // Per-symbol drill direction lock (chart parity); allow reentry when enabled
   if(InpDrillEnable && GsxCoreDrillActive() && i < ArraySize(g_drillWanted))
     {
      if(g_drillWanted[i] == 0)
         g_drillWanted[i] = joinDir;
      else if(g_drillWanted[i] != joinDir)
        {
         if(!InpDrillAllowReentry)
           {
            GsxCoreSetFillSkip(i, "drill side lock");
            return(false);
           }
         g_drillWanted[i] = joinDir; // reentry: follow new agree side
        }
     }

   string freshWhy = "";
   if(!GsxCoreSignalFresh(i, joinDir, freshWhy))
     {
      GsxCoreSetFillSkip(i, freshWhy);
      if(InpVerboseSignals)
         PrintFormat("GsignalX Core: skip stale %s — %s", sym, freshWhy);
      return(false);
     }

   if(!GsxCoreGatesOk(sym, why))
     {
      GsxCoreSetFillSkip(i, why);
      return(false);
     }

   // Desk equity guard (blocks new entries only; Scouter still exits)
   if(g_eqGuardPct > 0.0)
     {
      double dd = GsxAccountDrawdownPct();
      if(dd >= g_eqGuardPct)
        {
         GsxCoreSetFillSkip(i, StringFormat("equity guard %.1f%%>=%.0f%%", dd, g_eqGuardPct));
         if(InpVerboseSignals)
            PrintFormat("GsignalX Core: equity guard skip %s dd=%.2f%% >= %.0f%%",
                        sym, dd, g_eqGuardPct);
         return(false);
        }
     }

   string tradeWhy = "";
   if(!GsxTradeAllowedNow(sym, g_svcEnabled, tradeWhy))
     {
      GsxCoreSetFillSkip(i, tradeWhy);
      return(false);
     }

   // Onboard / same-cycle siblings: cooldown bypass so FillsPerCycle works (v2.14)
   int cool = onboard ? 0 : ((fillsDoneThisCycle > 0) ? 0 : InpFleetFillCooldownSec);
   if(!GsxFleetTryClaim(InpMagic, cool, TimeCurrent()))
     {
      GsxCoreSetFillSkip(i, "claim cooldown");
      return(false);
     }

   g_coreLatSigAt = (i < ArraySize(g_joinDirChangedAt) ? g_joinDirChangedAt[i] : TimeCurrent());
   g_coreLatFillAt = TimeCurrent();
   g_coreLatSym = sym;
   long latMs = (long)(g_coreLatFillAt - g_coreLatSigAt) * 1000;

   string action = "";
   bool ok = GsxPlaceEntry(g_gsxTrade, sym, joinDir, g_eng[i], ep, action);
   if(ok)
     {
      g_joinDirCache[i] = joinDir;
      g_fleetFills++;
      g_fleetActive = GsxFleetActivePairs(InpMagic);
      GsxCoreSetFillSkip(i, "");
      GsxRosterLastDirSet(InpMagic, sym, joinDir);
      // v2.13: single source of truth for Prop MAX_TRADES counter
      {
         GsxPropState pst;
         GsxPropLoad(InpMagic, pst);
         GsxPropOnNewEntry(pst);
         GsxPropSave(InpMagic, pst);
      }
      if(onboard)
         GsxCoreMarkOnboardSettled(i);
      if(InpVerboseSignals)
         PrintFormat("GsignalX Core: fleet fill #%d on %s dir=%d | %s | pairs %d/%d | sig→entry~%lds%s",
                     g_fleetFills, sym, joinDir, action,
                     g_fleetActive, target,
                     (long)(g_coreLatFillAt - g_coreLatSigAt),
                     (onboard ? " | onboard" : ""));
      return(true);
     }

   GsxFleetClearClaim(InpMagic);
   g_coreLastFillFailSym = sym;
   g_coreLastFillFailWhy = action;
   g_coreLastFillFailAt  = TimeCurrent();
   GsxCoreSetFillSkip(i, action);
   if(InpVerboseSignals)
      PrintFormat("GsignalX Core: fleet fill failed on %s: %s (lat~%ldms unused)",
                  sym, action, latMs);
   return(false);
  }

void GsxCoreFleetFillOnce()
  {
   if(!InpFleetEnable || !g_svcEnabled)
      return;

   int target = GsxCoreEffectiveFleetTarget();
   g_fleetActive = GsxFleetActivePairs(InpMagic);
   if(g_fleetActive >= target)
     {
      // Surface fleet-full on candidates so desk can show fill_skip
      for(int i = 0; i < ArraySize(g_roster); i++)
        {
         if(g_roster[i] == "" || !g_eng[i].ready)
            continue;
         if(!GsxRosterIsFleetCandidate(InpMagic, g_roster[i]))
            continue;
         if(GsxFleetSymbolBusy(g_roster[i], InpMagic))
            continue;
         GsxCoreSetFillSkip(i, StringFormat("fleet full %d/%d", g_fleetActive, target));
        }
      return;
     }

   GsxEntryParams ep = GsxCoreBuildEntryParams();
   int maxFills = GsxCoreFillsPerCycle();
   int fillsDone = 0;
   int n = ArraySize(g_roster);
   GsxCoreEnsureSlotMeta(n);

   // Build priority order: onboard first, then dir-changed, then others.
   // Within each pass, prefer under-represented asset classes (CMD/CR vs FX).
   int order[];
   ArrayResize(order, 0);
   for(int pass = 0; pass < 3; pass++)
     {
      int batch[];
      ArrayResize(batch, 0);
      for(int i = 0; i < n; i++)
        {
         if(!g_eng[i].ready || g_roster[i] == "")
            continue;
         string why = "";
         int joinDir = GsxCoreJoinDir(i, why);
         bool onboard = (i < ArraySize(g_onboardPending) && g_onboardPending[i]);
         bool changed = (joinDir != 0 && joinDir != g_joinDirCache[i]);
         if(pass == 0 && !onboard)
            continue;
         if(pass == 1 && (onboard || !changed))
            continue;
         if(pass == 2 && (onboard || changed))
            continue;
         int k = ArraySize(batch);
         ArrayResize(batch, k + 1);
         batch[k] = i;
        }
      GsxCoreSortFillOrderByClassDiversity(batch);
      for(int bi = 0; bi < ArraySize(batch); bi++)
        {
         int k = ArraySize(order);
         ArrayResize(order, k + 1);
         order[k] = batch[bi];
        }
     }

   for(int oi = 0; oi < ArraySize(order) && fillsDone < maxFills; oi++)
     {
      if(g_fleetActive >= target)
         break;
      int i = order[oi];
      if(GsxCoreTryFillIndex(i, ep, target, fillsDone))
        {
         fillsDone++;
         g_fleetActive = GsxFleetActivePairs(InpMagic);
         if(g_coreFleetSnapFresh)
            g_coreFleetSnap.active = g_fleetActive;
         if(i < ArraySize(g_joinDirChangedAt))
            g_joinDirChangedAt[i] = 0;
        }
     }
  }

void GsxCoreRefreshFleetSnap()
  {
   g_coreFleetSnap.pl = 0.0;
   g_coreFleetSnap.pos = 0;
   GsxFleetFloating(InpMagic, g_coreFleetSnap.pl, g_coreFleetSnap.pos);
   g_coreFleetSnap.active = GsxFleetActivePairs(InpMagic);
   g_coreFleetSnap.valid = true;
   g_coreFleetSnapFresh = true;
   g_fleetActive = g_coreFleetSnap.active;
  }

void GsxCoreEnsureFleetSnap()
  {
   if(!g_coreFleetSnapFresh)
      GsxCoreRefreshFleetSnap();
  }

bool GsxCorePublishBusIndex(const int i, const bool forceThrottleBypass)
  {
   if(!InpBusEnable)
      return(false);
   if(i < 0 || i >= ArraySize(g_roster) || g_roster[i] == "")
      return(false);

   if(!forceThrottleBypass)
     {
      if(g_busLastPub != 0 && TimeCurrent() - g_busLastPub < 1)
         return(false);
     }

   // Bus fingerprint/display uses class-aware ceiling so desk matches fill gate
   int maxSpBase = g_ignoreSpread ? 0 : InpMaxSpreadPt;
   int maxSp = (maxSpBase <= 0 ? 0 : GsxEffectiveMaxSpreadPt(g_roster[i], maxSpBase));
   GsxCoreEnsureFleetSnap();

   GsxCoreEnsureSlotMeta(ArraySize(g_roster));
   string skip = (i < ArraySize(g_fillSkip) ? g_fillSkip[i] : "");

   string whyJ = "";
   int jd = GsxCoreJoinDir(i, whyJ);
   if(jd != 0)
      GsxRosterLastDirSet(InpMagic, g_roster[i], jd);

   if(!GsxSignalBusWriteSymbolEx(g_roster[i], g_eng[i], InpMagic, InpMinAgree,
                                 (int)InpMode, maxSp, InpStaleTickSec, g_ignoreSpread,
                                 InpSwingStartHour, InpSwingEndHour, InpCryptoExtraList,
                                 true, g_closedCount, g_closedWins, g_closedLosses,
                                 g_closedRealized, "service", g_coreFleetSnap, skip, jd,
                                 InpFridayStop, InpFridayStopHr))
      return(false);

   string fp = GsxSignalBusFingerprint(g_roster[i], g_eng[i], InpMinAgree, maxSp,
                                       InpStaleTickSec, g_ignoreSpread,
                                       InpSwingStartHour, InpSwingEndHour,
                                       InpCryptoExtraList, InpFridayStop, InpFridayStopHr);
   g_busFp[i] = fp + "|" + skip + "|" + IntegerToString(jd);
   // Do not stamp throttle on forced onboard writes — cycle still needs full bus/heartbeat
   if(!forceThrottleBypass)
      g_busLastPub = TimeCurrent();
   return(true);
  }

void GsxCorePublishBus()
  {
   if(!InpBusEnable)
      return;
   // Fast cadence for live desk direction (was 2s — caused STALE / blank DIR)
   if(g_busLastPub != 0 && TimeCurrent() - g_busLastPub < 1)
      return;
   g_busLastPub = TimeCurrent();

   int maxSpBase = g_ignoreSpread ? 0 : InpMaxSpreadPt;
   bool fullSync = (g_busLastFullSync == 0 ||
                    TimeCurrent() - g_busLastFullSync >= GsxCoreBusFullSyncSec());

   // Reuse cycle fleet snap (refresh only if nothing published yet this cycle)
   GsxCoreEnsureFleetSnap();

   GsxCoreEnsureSlotMeta(ArraySize(g_roster));

   int wrote = 0;
   for(int i = 0; i < ArraySize(g_roster); i++)
     {
      if(g_roster[i] == "")
         continue;
      string skip = (i < ArraySize(g_fillSkip) ? g_fillSkip[i] : "");
      string whyJ = "";
      int jd = GsxCoreJoinDir(i, whyJ);
      int maxSp = (maxSpBase <= 0 ? 0 : GsxEffectiveMaxSpreadPt(g_roster[i], maxSpBase));
      string fp = GsxSignalBusFingerprint(g_roster[i], g_eng[i], InpMinAgree, maxSp,
                                          InpStaleTickSec, g_ignoreSpread,
                                          InpSwingStartHour, InpSwingEndHour,
                                          InpCryptoExtraList, InpFridayStop, InpFridayStopHr);
      fp += "|" + skip + "|" + IntegerToString(jd);
      bool dirty = fullSync || (g_busFp[i] != fp);
      if(!dirty)
         continue;

      if(jd != 0)
         GsxRosterLastDirSet(InpMagic, g_roster[i], jd);

      if(GsxSignalBusWriteSymbolEx(g_roster[i], g_eng[i], InpMagic, InpMinAgree,
                                   (int)InpMode, maxSp, InpStaleTickSec, g_ignoreSpread,
                                   InpSwingStartHour, InpSwingEndHour, InpCryptoExtraList,
                                   true, g_closedCount, g_closedWins, g_closedLosses,
                                   g_closedRealized, "service", g_coreFleetSnap, skip, jd,
                                   InpFridayStop, InpFridayStopHr))
        {
         g_busFp[i] = fp;
         wrote++;
        }
     }
   if(fullSync)
      g_busLastFullSync = TimeCurrent();
   GsxSignalBusHeartbeat(g_coreHostTag == GSX_HOST_DESK ? "gsignalx-desk" : "gsignalx-service");
   if(InpVerboseSignals && wrote > 0)
      PrintFormat("GsignalX Core: bus wrote %d symbols (full=%s fleetActive=%d)",
                  wrote, (fullSync ? "Y" : "N"), g_coreFleetSnap.active);
  }

bool GsxCoreCalcIndex(const int i, const ENUM_TIMEFRAMES deskTf, const GsxEngineParams &ep)
  {
   if(i < 0 || i >= ArraySize(g_roster))
      return(false);
   string sym = g_roster[i];
   if(sym == "")
      return(false);

   SymbolSelect(sym, true);

   // Stale/aliased series from another symbol → force full rebuild
   if(g_eng[i].ready && g_eng[i].symbol != "" && g_eng[i].symbol != sym)
      GsxEngStateReset(g_eng[i]);

   datetime form = iTime(sym, deskTf, 0);
   if(form == 0)
     {
      GsxCoreSetFillSkip(i, "no bars");
      return(false);
     }
   if(GsxCalcEngines(sym, deskTf, ep, g_eng[i]))
     {
      g_formWatch[i] = form;
      g_engineRecalcs++;
      return(true);
     }
   if(InpVerboseSignals)
      PrintFormat("GsignalX Core: engine wait %s: %s", sym, g_eng[i].status);
   GsxCoreSetFillSkip(i, (g_eng[i].status != "" ? g_eng[i].status : "engine wait"));
   return(false);
  }

//+------------------------------------------------------------------+
void GsxCoreApplyOnboardKicks()
  {
   int n = ArraySize(g_roster);
   if(n <= 0)
      return;
   GsxCoreEnsureSlotMeta(n);
   int kicked = 0;
   for(int i = 0; i < n; i++)
     {
      if(g_roster[i] == "")
         continue;
      if(!GsxRosterOnboardKickTake(InpMagic, g_roster[i]))
         continue;
      g_onboardPending[i] = true;
      g_joinDirCache[i] = 0;
      g_joinDirChangedAt[i] = 0;
      g_drillWanted[i] = 0;
      g_fillSkip[i] = "";
      g_formWatch[i] = 0;
      GsxEngStateReset(g_eng[i]); // force recompute from THIS pair's prices
      kicked++;
     }
   if(kicked > 0)
     {
      g_coreNewOnboard += kicked;
      g_coreBurstBudgetCycles = MathMax(g_coreBurstBudgetCycles,
                                        MathMax(8, kicked + 2));
     }
  }

void GsxCoreCycle()
  {
   g_coreCycleStartMs = GetTickCount();
   g_coreFleetSnapFresh = false; // force one fleet scan this cycle (reuse thereafter)
   // 0) live roster hot-reload from Dashboard / chart strip
   GsxCoreMaybeReloadRoster();
   // 0a) ADD/re-ARM kicks (even when symbol already on roster)
   GsxCoreApplyOnboardKicks();

   // 0b) Trade Center FOLLOW/WAIT — live GV (fallback: Service input default)
   g_flipWait = GsxRosterFlipWaitGet(InpMagic, InpFlipWaitDefault);

   // 0b2) Desk SPREAD/IGN (Trade Center → Service)
   g_ignoreSpread = GsxRosterSpreadIgnGet(InpMagic, InpIgnoreSpreadDefault);

   // 0b3) Desk AUTOLOT + EQ guard (Trade Center → Service) v2.09
   g_autoLot    = GsxRosterAutoLotGet(InpMagic, InpAutoLotDefault);
   g_eqGuardPct = GsxRosterEqGuardGet(InpMagic, 0.0);

   // 0c) Desk timeframe from Trade Center chart (fallback InpTimeframe → M5)
   ENUM_TIMEFRAMES deskTf = GsxRosterTimeframeGet(InpMagic, InpTimeframe);
   if(!GsxRosterTimeframeValid(deskTf))
      deskTf = PERIOD_M5;

   // 1) honor chart/service run GV when requested
   if(InpRespectChartRunState)
      g_svcEnabled = GsxFleetServiceRunGet(InpMagic);

   // 1b) PLAY/STOP edge → start/clear desk drill (chart parity)
   if(g_svcEnabled && !g_corePrevRun)
      GsxCoreStartDrill();
   else if(!g_svcEnabled && g_corePrevRun)
     {
      GsxCoreClearDrill("STOP");
      // Soft STOP: kill working brackets so old pairs cannot still trigger
      GsxCoreCancelAllRosterPendings("soft STOP");
      int orphans = GsxCleanupOrphanPendings(g_gsxTrade, InpMagic, g_roster);
      if(InpVerboseSignals && orphans > 0)
         PrintFormat("GsignalX Core: STOP cleared %d orphan pending(s)", orphans);
     }
   g_corePrevRun = g_svcEnabled;

   // 1c) PLAY click while already RUN, or ADD under PLAY → (re)open drill
   bool kick = GsxRosterDrillKickTake(InpMagic);
   int added = g_coreNewOnboard;
   g_coreNewOnboard = 0;
   if(g_svcEnabled && InpDrillEnable && (kick || added > 0))
     {
      // Refresh window so new pairs are not stuck behind an expired/idle drill
      if(kick || !GsxCoreDrillActive())
         GsxCoreStartDrill();
      else if(added > 0 && InpVerboseSignals)
         PrintFormat("GsignalX Core: ADD %d pair(s) under active drill (%ds left)",
                     added, GsxCoreDrillSecondsLeft());
     }

   GsxCoreRefreshDrill();
   GsxRosterDrillSecSet(InpMagic, GsxCoreDrillSecondsLeft());

   // 2) Always refresh engines + publish bus (directions live even when STOPPED).
   //    Fleet fills only when RUN/enabled.
   GsxEngineParams ep = GsxCoreBuildEngineParams();
   int n = ArraySize(g_roster);
   GsxCoreEnsureSlotMeta(n);
   int budget = GsxCoreEngineBudget();
   int done = 0;
   int advanced = 0;

   // 2a) v2.07/v2.08 onboard priority: force first calc + immediate bus (+ fill if RUN)
   // Keep pending through gate skips (spread/claim/busy); settle on fill or terminal skip.
   // Fill order prefers under-represented classes so FX seed does not starve CMD/CR.
   int onboardIdx[];
   ArrayResize(onboardIdx, 0);
   for(int i = 0; i < n; i++)
     {
      if(!g_onboardPending[i] || g_roster[i] == "")
         continue;
      bool ok = GsxCoreCalcIndex(i, deskTf, ep);
      done++;
      if(ok || g_eng[i].ready)
        {
         GsxCorePublishBusIndex(i, true);
         int k = ArraySize(onboardIdx);
         ArrayResize(onboardIdx, k + 1);
         onboardIdx[k] = i;
        }
      else
        {
         // History / not ready: keep onboard pending; still publish so desk shows COMPUTE/skip
         GsxCoreSetFillSkip(i, (g_eng[i].status != "" ? g_eng[i].status : "waiting for history"));
         GsxCorePublishBusIndex(i, true);
        }
     }
   if(g_svcEnabled && InpFleetEnable && ArraySize(onboardIdx) > 0)
     {
      GsxCoreSortFillOrderByClassDiversity(onboardIdx);
      int target = GsxCoreEffectiveFleetTarget();
      GsxEntryParams epar = GsxCoreBuildEntryParams();
      int fillsOnboard = 0;
      for(int oi = 0; oi < ArraySize(onboardIdx); oi++)
        {
         int i = onboardIdx[oi];
         if(GsxCoreTryFillIndex(i, epar, target, fillsOnboard))
           {
            fillsOnboard++;
            continue;
           }
         string skip = (i < ArraySize(g_fillSkip) ? g_fillSkip[i] : "");
         if(GsxCoreOnboardTerminalSkip(skip))
            GsxCoreMarkOnboardSettled(i);
        }
     }

   // 2b) Priority pass for !ready slots (avoid RR starvation)
   if(n > 0 && done < budget)
     {
      for(int i = 0; i < n && done < budget; i++)
        {
         if(g_roster[i] == "" || g_eng[i].ready)
            continue;
         if(GsxCoreCalcIndex(i, deskTf, ep))
           {
            GsxCorePublishBusIndex(i, true);
           }
         done++;
        }
     }

   // 2c) Normal round-robin for bar changes / remaining budget
   if(n > 0)
     {
      if(g_engBudgetCursor < 0 || g_engBudgetCursor >= n)
         g_engBudgetCursor = 0;
      for(int step = 0; step < n && done < budget; step++)
        {
         int i = (g_engBudgetCursor + step) % n;
         advanced++;
         string sym = g_roster[i];
         if(sym == "")
            continue;
         bool candidate = GsxRosterIsFleetCandidate(InpMagic, sym);
         datetime form = iTime(sym, deskTf, 0);
         if(form == 0)
            continue;
         bool need = (!g_eng[i].ready || form != g_formWatch[i] ||
                      g_eng[i].symbol != sym ||
                      (g_eng[i].tf != 0 && g_eng[i].tf != (int)deskTf));
         if(!need)
            continue;
         if(!candidate && done > 0 && done >= MathMax(1, budget / 2))
            continue;
         // Publish-as-ready: do not wait for 1s batched PublishBus throttle
         GsxCoreCalcIndex(i, deskTf, ep);
         GsxCorePublishBusIndex(i, true);
         done++;
        }
      if(advanced > 0)
         g_engBudgetCursor = (g_engBudgetCursor + MathMax(1, advanced)) % n;
     }

   if(GsxCoreAnyOnboardPending())
      g_coreBurstBudgetCycles = MathMax(g_coreBurstBudgetCycles, 2);
   else if(g_coreBurstBudgetCycles > 0)
      g_coreBurstBudgetCycles--;

   // 3) bus first so Trade Center sees direction even while fills are paused
   GsxCorePublishBus();

   g_coreLastCycleMs = GetTickCount() - g_coreCycleStartMs;
   if(InpVerboseSignals &&
      (g_coreCycleLogAt == 0 || TimeCurrent() - g_coreCycleLogAt >= 10) &&
      g_coreLastCycleMs >= 80)
     {
      PrintFormat("GsignalX Core: cycle_ms=%I64u recalcs=%d fills=%d roster=%d",
                  g_coreLastCycleMs, g_engineRecalcs, g_fleetFills, ArraySize(g_roster));
      g_coreCycleLogAt = TimeCurrent();
     }

   // Pending lifetime hygiene even while STOPPED (orphans from REM / old chart)
   GsxCleanupStalePendings(g_gsxTrade, InpMagic, InpPendMaxAgeMin);
   GsxCleanupOrphanPendings(g_gsxTrade, InpMagic, g_roster);
   // Re-anchor catastrophe SL after pending fills (one-shot per ticket)
   GsxStratStopRefreshFilled(g_gsxTrade, InpMagic, InpVerboseSignals);

   if(!g_svcEnabled)
      return;

   // 5) fleet fill — up to N attempts/cycle; onboard + dir-change preferred
   GsxCoreFleetFillOnce();
  }

#endif // GSX_CORE_MQH
//+------------------------------------------------------------------+
