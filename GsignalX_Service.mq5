//+------------------------------------------------------------------+
//|                                         GsignalX_Service.mq5     |
//|  Chart-free multi-symbol GSignalX entry service (Velocity 2.00)   |
//|  Scouter owns exits — this host never reverse-closes.             |
//+------------------------------------------------------------------+
#property service
#property copyright "Gocity Group"
#property version   "2.14"
#property description "Gsignalx Velocity 2.13 Service - multi-symbol roster scan + fleet fill"
#property description "Entry only (Scouter exits). Yields to DeskExecute OWN when InpYieldToDesk."
#property description "OWN/HOST GV prevents chart+desk+service double-fill. V2.13 host-scoped HB."

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Enumerations (host may redefine; Core uses int casts)            |
//+------------------------------------------------------------------+
enum EnGsxMode
  {
   GSX_SIMPLE   = 0,
   GSX_ADVANCED = 1
  };

enum EnRiskMode
  {
   GSX_RISK_LOT = 0,
   GSX_RISK_PCT = 1
  };

enum EnEntryMode
  {
   GSX_ENTRY_MARKET = 0,
   GSX_ENTRY_LIMIT  = 1,
   GSX_ENTRY_STOP   = 2,
   GSX_ENTRY_BOTH   = 3
  };

enum EnOffsetUnit
  {
   GSX_UNIT_PIPS   = 0,
   GSX_UNIT_POINTS = 1
  };

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "1) Roster & cycle"
input string          InpSymbolList   = "EURUSD,GBPUSD,XAUUSD,USDJPY";
input ENUM_TIMEFRAMES InpTimeframe    = PERIOD_M5;
input int             InpCycleMs      = 100;
input bool            InpRespectChartRunState = true; // Honor GSX_SVC_RUN_{magic}
input int             InpEngineBudgetPerCycle = 4;    // max engine rebuilds per cycle (v2.01)
input int             InpFleetFillsPerCycle   = 2;    // v2.06: fills attempted per cycle
input int             InpSignalMaxAgeSec      = 0;    // 0=off; dir-change max age at entry

input group "2) Fleet"
input bool InpFleetEnable           = true;
input int  InpFleetTargetPairs      = 4;
input int  InpFleetFillCooldownSec = 3;

input group "2b) Scalping drill (chart parity)"
input bool InpDrillEnable       = true;   // Enable drill window after PLAY
input int  InpDrillMinutes      = 10;     // Drill minutes after PLAY (5..15)
input bool InpDrillAllowReentry = true;   // Re-enter while drill active + flat
input bool InpContinuousFleet   = false;  // v2.13: skip drill gate (continuous book)

input group "2b) Yield to desk (v2.12)"
input bool InpYieldToDesk = true; // Idle when Trade Center DeskExecute holds OWN+HB
input int  InpYieldConfirmTicks = 3; // v2.13: consecutive checks before yield/reclaim

input group "3) Mode & signal routing"
input EnGsxMode InpMode          = GSX_SIMPLE;
input bool      InpTrigPP        = true;
input bool      InpTrigST        = false;
input bool      InpTrigSBT       = true;
input int       InpMinAgree      = 2;
input bool      InpEvalClosedBar = true;

input group "4) PP SuperTrend"
input int    InpPivotPrd = 2;
input double InpPPFactor = 3.0;
input int    InpPPAtrLen = 10;

input group "5) ATR SuperTrend + MA"
input int    InpStLen  = 10;
input double InpStMult = 3.0;
input bool   InpUseMA  = true;
input int    InpMaLen  = 20;

input group "6) SuperBollingerTrend"
input int    InpBBLen  = 12;
input double InpBBMult = 2.0;
input int    InpRiskAtrLen = 14;

input group "7) Trade management"
input bool   InpAllowLong            = true;
input bool   InpAllowShort           = true;
input bool   InpUseStop              = true;
input double InpStopMult             = 2.0;
input bool   InpStrategicStopEnable  = true;
input double InpStrategicStopMult    = 4.0;
input bool   InpStratStopUseDailyAtr = true;
input int    InpStratStopDailyAtrLen = 14;
input double InpStratStopDailyFloorMult = 0.20;
input double InpStratStopClassMultFx  = 1.0;
input double InpStratStopClassMultCmd = 1.35;
input double InpStratStopClassMultCr  = 1.75;
input int    InpStratStopRangeBars    = 6;
input double InpStratStopRangeMult    = 1.0;
input double InpStratStopHardCapMult  = 12.0;
input bool   InpStratStopJitterEnable = true;
input double InpStratStopJitterPct    = 8.0;
input int    InpStratStopMicroPts     = 5;
input bool   InpUseTarget            = false; // ignored (Scouter TP=0)
input double InpTargetMult           = 4.0;

input group "8) Entry order type"
input EnEntryMode  InpEntryMode         = GSX_ENTRY_BOTH;
input EnOffsetUnit InpOffsetUnit        = GSX_UNIT_PIPS;
input int          InpLimitOffset       = 5;
input int          InpStopOffset        = 5;
input bool         InpPendFromSignalOpen = true;
input int          InpPendMaxAgeMin     = 60;   // Cancel unfilled pendings older than N min (was 240)

input group "9) Exit ownership / flip"
input bool InpFlipWaitDefault  = false; // false=FOLLOW, true=WAIT
input bool InpScoutLinkEnable  = true;
input int  InpScoutInstanceID  = 1;

input group "10) Money management"
input EnRiskMode InpRiskMode       = GSX_RISK_PCT;
input double     InpFixedLot       = 0.01;   // FIXED lot (default entries)
input double     InpRiskPct        = 1.0;
input double     InpMaxLot         = 5.0;
input bool       InpAutoLotDefault = false;  // false=FIXED 0.01; true=risk% AUTOLOT

input group "11) Market gates"
input bool   InpBlockWeekend       = true;
input bool   InpUseSessions        = true;
input int    InpStaleTickSec       = 180;
input bool   InpUseHourFilter      = false;
input int    InpStartHour          = 7;
input int    InpEndHour            = 20;
input bool   InpFridayStop         = true;
input int    InpFridayStopHr       = 20;
input bool   InpCryptoAllowWeekend = true;
input string InpCryptoExtraList    = "";
input int    InpMaxSpreadPt        = 40;
input bool   InpIgnoreSpreadDefault = false;

input group "12) Execution"
input long   InpMagic     = 20260904;
input int    InpSlippage  = 20;
input int    InpLookback  = 400;   // v2.01 production default (raise for advanced desks)
input string InpComment   = "GsignalX-Svc";
input bool   InpVerboseSignals = true;

input group "13) Connector bus"
input bool InpBusEnable      = true;
input int  InpSwingStartHour = 12;
input int  InpSwingEndHour   = 17;
input int  InpBusFullSyncSec = 3; // force rewrite all symbols at least every N sec

input group "14) Telegram notifier"
input bool   InpTgEnable             = false;
input string InpTgBotToken           = "";
input string InpTgChatId1            = "";
input string InpTgChatId2            = "";
input string InpTgChatId3            = "";
input int    InpTgSilentStartHourGMT = -1;
input int    InpTgSilentEndHourGMT   = -1;
input int    InpTgRatePerMin         = 20;
input int    InpTgMaxRetries         = 3;

input group "15) Prop challenge pack (headless soft STOP)"
input bool   InpPropEnable            = true;
input double InpPropDailyLossMoney    = 0.0;
input double InpPropDailyLossPct      = 0.0;
input double InpPropMaxEquityDdPct    = 0.0;   // 0=OFF (guide only); set 5–10 for challenge
input int    InpPropMaxTradesDay      = 0;
input double InpPropMaxDaySharePct    = 0.0;
input double InpPropDailyProfitTarget = 0.0;
input int    InpPropBlockFridayHour   = -1;    // -1=OFF
input int    InpPropNewsBlackoutMin   = 0;
input string InpPropNewsTimes         = "";

#include <GSignalX/Core.mqh>
#include <GSignalX/TelegramNotifier.mqh>
#include <GSignalX/PropRisk.mqh>

GsxTgConfig   g_svcTgCfg;
GsxPropConfig g_svcPropCfg;
GsxPropState  g_svcPropSt;
datetime      g_svcPropLast = 0;
datetime      g_svcTgWarnAt = 0;
bool          g_svcTgLastOwn = false;
int           g_svcYieldHits = 0;   // v2.13 hysteresis toward Desk yield
int           g_svcReclaimHits = 0; // v2.13 hysteresis toward reclaim
ulong         g_svcYieldAtMs = 0;

GsxTgConfig SvcBuildTgConfig()
  {
   GsxTgConfig c;
   c.enable = InpTgEnable;
   c.botToken = InpTgBotToken;
   c.chatId1 = InpTgChatId1;
   c.chatId2 = InpTgChatId2;
   c.chatId3 = InpTgChatId3;
   c.silentStartHourGmt = InpTgSilentStartHourGMT;
   c.silentEndHourGmt = InpTgSilentEndHourGMT;
   c.ratePerMin = InpTgRatePerMin;
   c.maxRetries = InpTgMaxRetries;
   return(c);
  }

GsxPropConfig SvcBuildPropConfig()
  {
   GsxPropConfig c;
   c.enable = InpPropEnable;
   c.magic = InpMagic;
   c.dailyLossMoney = InpPropDailyLossMoney;
   c.dailyLossPct = InpPropDailyLossPct;
   c.maxEquityDdPct = InpPropMaxEquityDdPct;
   c.maxTradesDay = InpPropMaxTradesDay;
   c.maxDaySharePct = InpPropMaxDaySharePct;
   c.dailyProfitTarget = InpPropDailyProfitTarget;
   c.blockFridayHour = InpPropBlockFridayHour;
   c.newsBlackoutMin = InpPropNewsBlackoutMin;
   c.newsTimesCsv = InpPropNewsTimes;
   return(c);
  }

void SvcTgWarnThrottled(const string body)
  {
   if(!InpTgEnable)
      return;
   if(TimeCurrent() - g_svcTgWarnAt < 60)
      return;
   g_svcTgWarnAt = TimeCurrent();
   GsxTgNotifyWarn(g_svcTgCfg, body);
  }

void SvcPropTick()
  {
   if(!InpPropEnable)
      return;
   if(g_svcPropLast != 0 && TimeCurrent() - g_svcPropLast < 2)
      return;
   g_svcPropLast = TimeCurrent();
   g_svcPropCfg = SvcBuildPropConfig();
   bool became = false;
   if(GsxPropEvaluate(g_svcPropCfg, g_svcPropSt, became) && became)
      SvcTgWarnThrottled("PROP soft STOP — " + g_svcPropSt.reason);
  }

// v2.13: Desk OWN + desk-sourced heartbeat (not any-tid HB)
bool SvcDeskAliveNow()
  {
   return(GsxFleetPeerHostOwns(InpMagic, GSX_HOST_DESK) &&
          GsxBusHeartbeatFreshFromSource(5, "gsignalx-desk"));
  }

void SvcTgTick()
  {
   g_svcTgCfg = SvcBuildTgConfig();
   GsxTgMaybeReverify(g_svcTgCfg);
   // v2.01: at most one HTTP attempt per Service cycle (keep fills responsive)
   GsxTgProcessQueueEx(g_svcTgCfg, 1);
   GsxTgPublishStatus(InpMagic);

   bool own = GsxFleetServiceOwns(InpMagic);
   if(g_svcTgLastOwn && !own)
      SvcTgWarnThrottled("OWN lost — chart may own fleet fills");
   g_svcTgLastOwn = own;

   if(ArraySize(g_roster) <= 0)
      SvcTgWarnThrottled("roster empty — no symbols to scan");

   if(g_coreLastFillFailAt != 0 &&
      TimeCurrent() - g_coreLastFillFailAt < 5)
     {
      SvcTgWarnThrottled("fill fail " + g_coreLastFillFailSym +
                         " — " + g_coreLastFillFailWhy);
      g_coreLastFillFailAt = 0;
     }
  }

//+------------------------------------------------------------------+
void OnStart()
  {
   g_svcTgCfg = SvcBuildTgConfig();
   g_svcPropCfg = SvcBuildPropConfig();
   GsxPropLoad(InpMagic, g_svcPropSt);
   if(g_svcPropSt.locked &&
      (g_svcPropSt.reason == "EQUITY_DD" || InpPropMaxEquityDdPct <= 0.0))
     {
      GsxPropGrantEquityGrace(InpMagic, 300);
      GsxPropClearLock(g_svcPropCfg, g_svcPropSt, false);
      Print("GsignalX service: cleared stale Prop EQUITY_DD lock");
     }
   GsxTgSetMagic(InpMagic);
   GsxTgSetHostTag("svc");
   string acct = StringFormat("%I64d %s svc", AccountInfoInteger(ACCOUNT_LOGIN),
                              AccountInfoString(ACCOUNT_SERVER));
   GsxTgInit(g_svcTgCfg, acct);
   if(InpTgEnable && !GsxTgIsVerified())
      GsxTgNotifyError(g_svcTgCfg, "init verify failed — " + GsxTgLastError());

   // Align desk lot mode with Service input default only when GV missing (v2.14)
   GsxRosterAutoLotSeed(InpMagic, InpAutoLotDefault);

   bool coreOn = false;
   int needHits = MathMax(1, InpYieldConfirmTicks);
   if(InpYieldToDesk && SvcDeskAliveNow())
     {
      PrintFormat("GsignalX service: yielding to Desk OWN (magic=%I64d) — stop DeskExecute or detach Dashboard to reclaim",
                  InpMagic);
      g_svcYieldHits = needHits;
      g_svcYieldAtMs = GetTickCount();
     }
   else
     {
      GsxCoreInitEx(GSX_HOST_SERVICE, true);
      coreOn = true;
     }
   g_svcTgLastOwn = GsxFleetServiceOwns(InpMagic);

   int ms = (int)MathMax(100, InpCycleMs);
   PrintFormat("GsignalX service started | core=%s | roster=%s | tf=%s | cycle=%dms | magic=%I64d | fleet=%d | yieldDesk=%s | yieldHits=%d",
               (coreOn ? "ON" : "YIELD"),
               InpSymbolList,
               EnumToString(InpTimeframe),
               ms,
               InpMagic,
               InpFleetTargetPairs,
               (InpYieldToDesk ? "ON" : "OFF"),
               needHits);

   while(!IsStopped())
     {
      if(!TerminalInfoInteger(TERMINAL_CONNECTED))
        {
         Sleep(1000);
         continue;
        }

      // Yield immediately when Desk owns; reclaim only after hysteresis (v2.14)
      if(InpYieldToDesk)
        {
         bool deskAlive = SvcDeskAliveNow();
         if(deskAlive)
           {
            g_svcYieldHits++;
            g_svcReclaimHits = 0;
            if(coreOn)
              {
               GsxCoreDeinit();
               coreOn = false;
               g_svcYieldAtMs = GetTickCount();
               PrintFormat("GsignalX service: Desk OWN+HB — Core paused immediately (hits=%d)",
                           g_svcYieldHits);
              }
           }
         else
           {
            g_svcReclaimHits++;
            g_svcYieldHits = 0;
            if(!coreOn && g_svcReclaimHits >= needHits)
              {
               ulong pausedMs = (g_svcYieldAtMs > 0 ? (GetTickCount() - g_svcYieldAtMs) : 0);
               GsxCoreInitEx(GSX_HOST_SERVICE, true);
               coreOn = true;
               PrintFormat("GsignalX service: Desk gone — Core reclaimed (yield_ms=%I64u hits=%d)",
                           pausedMs, g_svcReclaimHits);
               g_svcYieldAtMs = 0;
              }
           }
        }

      SvcPropTick();
      if(coreOn)
         GsxCoreCycle();
      SvcTgTick();
      Sleep(ms);
     }

   GsxTgDeinit(g_svcTgCfg, 0.0);
   if(coreOn)
      GsxCoreDeinit();
   PrintFormat("GsignalX service stopped | recalcs=%d fills=%d",
               g_engineRecalcs, g_fleetFills);
  }
//+------------------------------------------------------------------+
