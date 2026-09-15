//+------------------------------------------------------------------+
//|                                         GsignalX_Service.mq5     |
//|  Chart-free multi-symbol GSignalX entry service (Velocity 2.00)   |
//|  Scouter owns exits — this host never reverse-closes.             |
//+------------------------------------------------------------------+
#property service
#property copyright "Gocity Group"
#property version   "2.00"
#property description "Gsignalx Velocity 2.00 Service - multi-symbol roster scan + fleet fill"
#property description "Entry only (Scouter exits). Shared magic with chart EA."
#property description "OWN GV prevents chart double-fill while Service runs."

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
input int             InpCycleMs      = 200;
input bool            InpRespectChartRunState = true; // Honor GSX_SVC_RUN_{magic}
input int             InpEngineBudgetPerCycle = 4;    // max engine rebuilds per cycle (v2.01)

input group "2) Fleet"
input bool InpFleetEnable           = true;
input int  InpFleetTargetPairs      = 4;
input int  InpFleetFillCooldownSec = 10;

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
input bool   InpUseTarget            = false; // ignored (Scouter TP=0)
input double InpTargetMult           = 4.0;

input group "8) Entry order type"
input EnEntryMode  InpEntryMode         = GSX_ENTRY_BOTH;
input EnOffsetUnit InpOffsetUnit        = GSX_UNIT_PIPS;
input int          InpLimitOffset       = 5;
input int          InpStopOffset        = 5;
input bool         InpPendFromSignalOpen = true;
input int          InpPendMaxAgeMin     = 240;

input group "9) Exit ownership / flip"
input bool InpFlipWaitDefault  = false; // false=FOLLOW, true=WAIT
input bool InpScoutLinkEnable  = true;
input int  InpScoutInstanceID  = 1;

input group "10) Money management"
input EnRiskMode InpRiskMode       = GSX_RISK_PCT;
input double     InpFixedLot       = 0.10;
input double     InpRiskPct        = 1.0;
input double     InpMaxLot         = 5.0;
input bool       InpAutoLotDefault = true;

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
input int  InpBusFullSyncSec = 10; // force rewrite all symbols at least every N sec

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
input double InpPropMaxEquityDdPct    = 5.0;
input int    InpPropMaxTradesDay      = 0;
input double InpPropMaxDaySharePct    = 0.0;
input double InpPropDailyProfitTarget = 0.0;
input int    InpPropBlockFridayHour   = 20;
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
   GsxCoreInit();

   g_svcTgCfg = SvcBuildTgConfig();
   g_svcPropCfg = SvcBuildPropConfig();
   GsxPropLoad(InpMagic, g_svcPropSt);
   GsxTgSetMagic(InpMagic);
   GsxTgSetHostTag("svc");
   string acct = StringFormat("%I64d %s svc", AccountInfoInteger(ACCOUNT_LOGIN),
                              AccountInfoString(ACCOUNT_SERVER));
   GsxTgInit(g_svcTgCfg, acct);
   if(InpTgEnable && !GsxTgIsVerified())
      GsxTgNotifyError(g_svcTgCfg, "init verify failed — " + GsxTgLastError());
   g_svcTgLastOwn = GsxFleetServiceOwns(InpMagic);

   int ms = (int)MathMax(100, InpCycleMs);
   PrintFormat("GsignalX service started | roster=%s | tf=%s | cycle=%dms | budget=%d | lookback=%d | magic=%I64d | fleet=%d | bus=%s | prop=%s | tg=%s",
               InpSymbolList,
               EnumToString(InpTimeframe),
               ms,
               InpEngineBudgetPerCycle,
               InpLookback,
               InpMagic,
               InpFleetTargetPairs,
               (InpBusEnable ? "ON" : "OFF"),
               (InpPropEnable ? "ON" : "OFF"),
               (InpTgEnable ? GsxTgStatusText() : "OFF"));

   while(!IsStopped())
     {
      if(!TerminalInfoInteger(TERMINAL_CONNECTED))
        {
         Sleep(1000);
         continue;
        }
      SvcPropTick();
      GsxCoreCycle();
      SvcTgTick();
      Sleep(ms);
     }

   GsxTgDeinit(g_svcTgCfg, 0.0);
   GsxCoreDeinit();
   PrintFormat("GsignalX service stopped | recalcs=%d fills=%d",
               g_engineRecalcs, g_fleetFills);
  }
//+------------------------------------------------------------------+
