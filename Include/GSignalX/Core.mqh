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
#include <GSignalX/EntryExec.mqh>
#include <GSignalX/SignalBus.mqh>
#include <GSignalX/LotSizing.mqh>

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
bool           g_autoLot      = true;
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

//+------------------------------------------------------------------+
void GsxEngStateCopy(const GsxEngineState &src, GsxEngineState &dst)
  {
   dst.n = src.n;
   dst.ready = src.ready;
   dst.lastBarTime = src.lastBarTime;
   dst.lastSigDir = src.lastSigDir;
   dst.lastSigIdx = src.lastSigIdx;
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
   st.n = 0;
   st.ready = false;
   st.lastBarTime = 0;
   st.lastSigDir = 0;
   st.lastSigIdx = -1;
   st.status = "";
  }

int GsxCoreEngineBudget()
  {
   int b = InpEngineBudgetPerCycle;
   if(b <= 0)
      return 4;
   return b;
  }

int GsxCoreBusFullSyncSec()
  {
   int s = InpBusFullSyncSec;
   if(s <= 0)
      return 10;
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
   return(p);
  }

int GsxCoreJoinDir(const int idx, string &why)
  {
   why = "";
   if(idx < 0 || idx >= ArraySize(g_eng))
      return(0);
   if(!g_eng[idx].ready || g_eng[idx].n < 1)
      return(0);

   int joinDir = GsxActiveDirectionUnderRules(g_eng[idx], g_eng[idx].n - 1,
                                              InpTrigPP, InpTrigST, InpTrigSBT,
                                              InpUseMA, (int)InpMode, InpMinAgree, why);
   if(joinDir == 0)
      joinDir = g_eng[idx].lastSigDir;
   return(joinDir);
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
   if(!GsxSpreadOK(symbol, maxSp, g_ignoreSpread, why))
      return(false);
   return(true);
  }

int GsxCoreEffectiveFleetTarget()
  {
   int ov = GsxRosterFleetTargetGet(InpMagic);
   if(ov > 0)
      return(ov);
   return(InpFleetTargetPairs);
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

   for(int i = 0; i < oldN; i++)
     {
      oldRoster[i] = g_roster[i];
      GsxEngStateCopy(g_eng[i], oldEng[i]);
      oldWatch[i] = (i < ArraySize(g_formWatch) ? g_formWatch[i] : 0);
      oldFp[i] = (i < ArraySize(g_busFp) ? g_busFp[i] : "");
     }

   int n = ArraySize(newRoster);
   ArrayResize(g_roster, n);
   ArrayResize(g_eng, n);
   ArrayResize(g_formWatch, n);
   ArrayResize(g_busFp, n);

   for(int i = 0; i < n; i++)
     {
      g_roster[i] = newRoster[i];
      GsxEngStateReset(g_eng[i]);
      g_formWatch[i] = 0;
      g_busFp[i] = "";

      for(int j = 0; j < oldN; j++)
        {
         if(oldRoster[j] == "" || oldRoster[j] != newRoster[i])
            continue;
         GsxEngStateCopy(oldEng[j], g_eng[i]);
         g_formWatch[i] = oldWatch[j];
         g_busFp[i] = oldFp[j];
         break;
        }
     }
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
void GsxCoreInit()
  {
   // Live roster file wins; seed from InpSymbolList when absent.
   GsxRosterStoreEnsure(InpMagic, InpSymbolList, g_roster);
   g_rosterSeqSeen = GsxRosterSeqGet(InpMagic);

   int n = ArraySize(g_roster);
   ArrayResize(g_eng, n);
   ArrayResize(g_formWatch, n);
   ArrayResize(g_busFp, n);
   for(int i = 0; i < n; i++)
     {
      GsxEngStateReset(g_eng[i]);
      g_formWatch[i] = 0;
      g_busFp[i] = "";
     }

   g_svcEnabled   = true;
   g_flipWait     = InpFlipWaitDefault;
   g_ignoreSpread = InpIgnoreSpreadDefault;
   g_autoLot      = InpAutoLotDefault;
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

   GsxFleetServiceOwnSet(InpMagic, true);
   GsxFleetServiceRunSet(InpMagic, true);

   PrintFormat("GsignalX Core: init roster=%d magic=%I64d OWN=1 RUN=1 flip=%s autolot=%s seq=%.0f",
               n, InpMagic,
               (g_flipWait ? "WAIT" : "FOLLOW"),
               (g_autoLot ? "ON" : "FIXED"),
               g_rosterSeqSeen);
  }

void GsxCoreDeinit()
  {
   GsxFleetServiceOwnSet(InpMagic, false);
   PrintFormat("GsignalX Core: deinit OWN=0 magic=%I64d recalcs=%d fills=%d",
               InpMagic, g_engineRecalcs, g_fleetFills);
  }

//+------------------------------------------------------------------+
void GsxCoreFleetFillOnce()
  {
   if(!InpFleetEnable || !g_svcEnabled)
      return;

   int target = GsxCoreEffectiveFleetTarget();
   g_fleetActive = GsxFleetActivePairs(InpMagic);
   if(g_fleetActive >= target)
      return;

   GsxEntryParams ep = GsxCoreBuildEntryParams();

   for(int i = 0; i < ArraySize(g_roster); i++)
     {
      string sym = g_roster[i];
      if(sym == "")
         continue;
      if(!GsxRosterIsFleetCandidate(InpMagic, sym))
         continue;                   // STOP/SUSPEND: skip new fills
      if(GsxEventBlocksSymbol(InpMagic, sym))
         continue;                   // Event SKIP blackout for this pair
      if(GsxFleetSymbolBusy(sym, InpMagic))
         continue;
      if(!g_eng[i].ready)
         continue;

      string why = "";
      int joinDir = GsxCoreJoinDir(i, why);
      if(joinDir == 0)
         continue;
      if(!GsxAllowNewDirEntry(joinDir, g_flipWait, InpMagic))
         continue;
      if(!GsxCoreGatesOk(sym, why))
         continue;

      string tradeWhy = "";
      if(!GsxTradeAllowedNow(sym, g_svcEnabled, tradeWhy))
         continue;

      if(!GsxFleetTryClaim(InpMagic, InpFleetFillCooldownSec, TimeCurrent()))
         return; // cooldown / contention — try next cycle

      string action = "";
      bool ok = GsxPlaceEntry(g_gsxTrade, sym, joinDir, g_eng[i], ep, action);
      if(ok)
        {
         g_fleetFills++;
         g_fleetActive = GsxFleetActivePairs(InpMagic);
         if(InpVerboseSignals)
            PrintFormat("GsignalX Core: fleet fill #%d on %s dir=%d | %s | pairs %d/%d",
                        g_fleetFills, sym, joinDir, action,
                        g_fleetActive, target);
        }
      else
        {
         GsxFleetClearClaim(InpMagic);
         g_coreLastFillFailSym = sym;
         g_coreLastFillFailWhy = action;
         g_coreLastFillFailAt  = TimeCurrent();
         if(InpVerboseSignals)
            PrintFormat("GsignalX Core: fleet fill failed on %s: %s", sym, action);
        }
      break; // anti-stampede: one fill attempt per cycle
     }
  }

void GsxCorePublishBus()
  {
   if(!InpBusEnable)
      return;
   if(g_busLastPub != 0 && TimeCurrent() - g_busLastPub < 2)
      return;
   g_busLastPub = TimeCurrent();

   int maxSp = g_ignoreSpread ? 0 : InpMaxSpreadPt;
   bool fullSync = (g_busLastFullSync == 0 ||
                    TimeCurrent() - g_busLastFullSync >= GsxCoreBusFullSyncSec());

   GsxBusFleetSnap snap;
   snap.pl = 0;
   snap.pos = 0;
   GsxFleetFloating(InpMagic, snap.pl, snap.pos);
   snap.active = GsxFleetActivePairs(InpMagic);
   snap.valid = true;

   if(ArraySize(g_busFp) != ArraySize(g_roster))
      ArrayResize(g_busFp, ArraySize(g_roster));

   int wrote = 0;
   for(int i = 0; i < ArraySize(g_roster); i++)
     {
      if(g_roster[i] == "")
         continue;
      string fp = GsxSignalBusFingerprint(g_roster[i], g_eng[i], InpMinAgree, maxSp,
                                          InpStaleTickSec, g_ignoreSpread,
                                          InpSwingStartHour, InpSwingEndHour,
                                          InpCryptoExtraList);
      bool dirty = fullSync || (g_busFp[i] != fp);
      if(!dirty)
         continue;
      if(GsxSignalBusWriteSymbolEx(g_roster[i], g_eng[i], InpMagic, InpMinAgree,
                                   (int)InpMode, maxSp, InpStaleTickSec, g_ignoreSpread,
                                   InpSwingStartHour, InpSwingEndHour, InpCryptoExtraList,
                                   true, g_closedCount, g_closedWins, g_closedLosses,
                                   g_closedRealized, "service", snap))
        {
         g_busFp[i] = fp;
         wrote++;
        }
     }
   if(fullSync)
      g_busLastFullSync = TimeCurrent();
   GsxSignalBusHeartbeat("gsignalx-service");
   if(InpVerboseSignals && wrote > 0)
      PrintFormat("GsignalX Core: bus wrote %d symbols (full=%s fleetActive=%d)",
                  wrote, (fullSync ? "Y" : "N"), snap.active);
  }

//+------------------------------------------------------------------+
void GsxCoreCycle()
  {
   // 0) live roster hot-reload from Dashboard / chart strip
   GsxCoreMaybeReloadRoster();

   // 1) honor chart/service run GV when requested
   if(InpRespectChartRunState)
      g_svcEnabled = GsxFleetServiceRunGet(InpMagic);

   // 2) stopped
   if(!g_svcEnabled)
      return;

   // 3) budgeted engine recalc (round-robin) — avoids M5 bar-open storm
   GsxEngineParams ep = GsxCoreBuildEngineParams();
   int n = ArraySize(g_roster);
   int budget = GsxCoreEngineBudget();
   int done = 0;
   if(n > 0)
     {
      if(g_engBudgetCursor < 0 || g_engBudgetCursor >= n)
         g_engBudgetCursor = 0;
      for(int step = 0; step < n && done < budget; step++)
        {
         int i = (g_engBudgetCursor + step) % n;
         string sym = g_roster[i];
         if(sym == "")
            continue;
         datetime form = iTime(sym, InpTimeframe, 0);
         if(form == 0)
            continue;
         bool need = (!g_eng[i].ready || form != g_formWatch[i]);
         if(!need)
            continue;
         if(GsxCalcEngines(sym, InpTimeframe, ep, g_eng[i]))
           {
            g_formWatch[i] = form;
            g_engineRecalcs++;
            done++;
           }
         else
            if(InpVerboseSignals)
               PrintFormat("GsignalX Core: engine wait %s: %s", sym, g_eng[i].status);
        }
      g_engBudgetCursor = (g_engBudgetCursor + 1) % n;
     }

   // 4) stale pending sweep (all symbols for magic)
   GsxCleanupStalePendings(g_gsxTrade, InpMagic, InpPendMaxAgeMin);

   // 5) fleet fill — one attempt per cycle
   GsxCoreFleetFillOnce();

   // 6) bus: dirty symbols (+ periodic full sync) + heartbeat
   GsxCorePublishBus();
  }

#endif // GSX_CORE_MQH
//+------------------------------------------------------------------+
