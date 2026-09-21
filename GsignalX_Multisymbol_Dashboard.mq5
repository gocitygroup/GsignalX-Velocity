//+------------------------------------------------------------------+
//|                            GsignalX_Multisymbol_Dashboard.mq5     |
//|  Prop Firm Trade Center + multi-symbol runtime (Velocity 2.13)    |
//|  DeskExecute embeds Core (signals + fleet entries).               |
//|  NEVER closes positions. Scouter owns exits.                      |
//+------------------------------------------------------------------+
#property copyright   "Gocity Group"
#property version     "2.14"
#property description "Gsignalx Trade Center — single-chart multi-symbol runtime (v2.13)"
#property description "DeskExecute embeds Core. Soft STOP only — Scouter owns closes."
#property description "V2.13: EQ pads, Prop/EQ guidance, continuous fleet, desk risk UI."

//+------------------------------------------------------------------+
//| Enumerations (Core host contract — same as Service)               |
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

#include <GSignalX/ChartPanel.mqh> // ENUM_GSX_UI_VISION before panel inputs

//+------------------------------------------------------------------+
input group "1) Identity & fleet"
input long   InpMagic            = 20260904;
input int    InpFleetTargetPairs = 4;
input int    InpPageSize         = 12;
input string InpSymbolList       = "EURUSD,GBPUSD,USDJPY,AUDUSD,XAUUSD,XAGUSD,USOIL,UKOIL,BTCUSD,ETHUSD,XRPUSD,LTCUSD";
input int    InpClassSoftMax     = 8;      // soft max pairs per category (>=4)
input int    InpRefreshMs        = 500;    // UI cadence (Prop/TG/Events independent)
input bool   InpDeskExecute      = true;   // v2.12: embed Core (signals + fills) in this EA

input group "1b) Core cycle (DeskExecute)"
input ENUM_TIMEFRAMES InpTimeframe    = PERIOD_M5; // fallback TF if desk chart TF invalid
input int             InpCycleMs      = 200;       // Core cadence (ms)
input bool            InpRespectChartRunState = true; // Honor PLAY/STOP (GSX_SVC_RUN)
input int             InpEngineBudgetPerCycle = 4;
input int             InpFleetFillsPerCycle   = 2;
input int             InpSignalMaxAgeSec      = 0;    // 0=off

input group "1c) Fleet / drill (DeskExecute)"
input bool InpFleetEnable           = true;
input int  InpFleetFillCooldownSec = 3;
input bool InpDrillEnable           = true;
input int  InpDrillMinutes          = 10;     // 5..15
input bool InpDrillAllowReentry     = true;
input bool InpContinuousFleet       = false;  // v2.13: skip drill gate (continuous book)

input group "2) Panel"
input int    InpPanelX           = 12;
input int    InpPanelY           = 22;
input double InpUiScale          = 1.5;
input ENUM_GSX_UI_VISION InpUiVision = GSX_VISION_COMFORT;
input bool   InpShowButtons      = true;
input bool   InpShowPractice     = false;
input bool   InpFlipWaitDefault  = false;

input group "2b) Scouter link (HALT/PLAY)"
input bool   InpScoutLinkEnable  = false;
input int    InpScoutInstanceID  = 1;

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
input bool   InpUseTarget            = false;
input double InpTargetMult           = 4.0;

input group "8) Entry order type"
input EnEntryMode  InpEntryMode          = GSX_ENTRY_BOTH;
input EnOffsetUnit InpOffsetUnit         = GSX_UNIT_PIPS;
input int          InpLimitOffset        = 5;
input int          InpStopOffset         = 5;
input bool         InpPendFromSignalOpen = true;
input int          InpPendMaxAgeMin      = 60;   // Cancel unfilled pendings older than N min (was 240)

input group "9) Money management"
input EnRiskMode InpRiskMode       = GSX_RISK_PCT;
input double     InpFixedLot       = 0.01;   // FIXED lot (default entries)
input double     InpRiskPct        = 1.0;
input double     InpMaxLot         = 5.0;
input bool       InpAutoLotDefault = false;  // false=FIXED 0.01; true=risk% AUTOLOT

input group "10) Market gates"
input bool   InpBlockWeekend        = true;
input bool   InpUseSessions         = true;
input int    InpStaleTickSec        = 180;
input bool   InpUseHourFilter       = false;
input int    InpStartHour           = 7;
input int    InpEndHour             = 20;
input bool   InpFridayStop          = true;
input int    InpFridayStopHr        = 20;
input bool   InpCryptoAllowWeekend  = true;
input string InpCryptoExtraList     = "";
input int    InpMaxSpreadPt         = 40;     // FX base; CMD/CR auto-raise (metals 200 / oil 500 / crypto 1500)
input bool   InpIgnoreSpreadDefault = false;

input group "11) Execution"
input int    InpSlippage       = 20;
input int    InpLookback       = 400;
input string InpComment        = "GsignalX-Desk";
input bool   InpVerboseSignals = true;

input group "12) Connector bus"
input bool InpBusEnable      = true;
input int  InpSwingStartHour = 12;
input int  InpSwingEndHour   = 17;
input int  InpBusFullSyncSec = 3;

input group "13) Telegram notifier"
input bool   InpTgEnable              = false;
input string InpTgBotToken            = "";
input string InpTgChatId1             = "";
input string InpTgChatId2             = "";
input string InpTgChatId3             = "";
input int    InpTgSilentStartHourGMT  = -1;
input int    InpTgSilentEndHourGMT    = -1;
input int    InpTgRatePerMin          = 20;
input int    InpTgMaxRetries          = 3;

input group "14) Prop challenge pack"
input bool   InpPropEnable            = true;
input double InpPropDailyLossMoney    = 0.0;
input double InpPropDailyLossPct      = 0.0;
input double InpPropMaxEquityDdPct    = 0.0;   // 0=OFF (guide only); was 5 — too tight for live desk
input int    InpPropMaxTradesDay      = 0;
input double InpPropMaxDaySharePct    = 0.0;
input double InpPropDailyProfitTarget = 0.0;
input int    InpPropBlockFridayHour   = -1;    // -1=OFF (was 20 — weekend lock surprised desks)
input int    InpPropNewsBlackoutMin   = 0;
input string InpPropNewsTimes         = "";

input group "15) Session clock (illustrative GMT)"
input int    InpSessAsiaStart         = 0;
input int    InpSessAsiaEnd           = 9;
input int    InpSessLondonStart       = 7;
input int    InpSessLondonEnd         = 16;
input int    InpSessNyStart           = 12;
input int    InpSessNyEnd             = 21;
input int    InpSessSydneyStart       = 21;
input int    InpSessSydneyEnd         = 6;

input group "16) Events (calendar + desk CSV)"
input bool   InpEvtCalendarEnable     = true;
input int    InpEvtLookAheadMin       = 120;
input int    InpEvtBlackoutMin        = 30;
input int    InpEvtNotifyAheadMin     = 30;
input int    InpEvtModeDefault        = 0;     // 0=TRADE 1=SKIP
input string InpEvtDeskTimes          = "";
input string InpEvtDeskNames          = "";
input int    InpEvtPollSec            = 30;

// Core host — must follow inputs that Core reads by name
#include <GSignalX/Core.mqh>
// Desk UI reads live joinDir/fill_skip from in-process Core (no bus lag)
#define GSX_DESK_CORE_LIVE 1
#include <GSignalX/MultisymbolPanel.mqh>
#include <GSignalX/TelegramNotifier.mqh>
#include <GSignalX/TgDealWatch.mqh>
#include <GSignalX/SettingsNotify.mqh>
#include <GSignalX/PropRisk.mqh>
#include <GSignalX/EventGate.mqh>
#include <GSignalX/SessionClock.mqh>
#include <GSignalX/BusIO.mqh>

//+------------------------------------------------------------------+
GsxTgConfig   g_tgCfg;
GsxPropConfig g_propCfg;
GsxPropState  g_propSt;
datetime      g_lastDailySummary = 0;
datetime      g_lastWeeklySummary = 0;
datetime      g_lastEvtPoll = 0;
datetime      g_lastPropEval = 0;
datetime      g_lastForcedRedraw = 0;
string        g_lastSnapFp = "";
string        g_evtLine = "";
int           g_evtMode = GSX_EVT_MODE_TRADE;
int           g_tgWeekTrades = 0;
int           g_tgWeekWins = 0;

bool          g_deskCoreActive = false;
ulong         g_deskLastCoreMs = 0;
ulong         g_deskLastUiMs   = 0;

//+------------------------------------------------------------------+
GsxTgConfig DashBuildTgConfig()
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

GsxPropConfig DashBuildPropConfig()
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

GsxEventGateConfig DashBuildEvtConfig()
  {
   GsxEventGateConfig c;
   c.magic = InpMagic;
   c.calendarEnable = InpEvtCalendarEnable;
   c.lookAheadMin = MathMax(1, InpEvtLookAheadMin);
   c.blackoutMin = MathMax(0, InpEvtBlackoutMin);
   c.notifyAheadMin = MathMax(0, InpEvtNotifyAheadMin);
   c.mode = GsxEventModeGet(InpMagic);
   string desk = InpEvtDeskTimes;
   if(InpPropNewsTimes != "")
     {
      if(desk != "")
         desk += ",";
      desk += InpPropNewsTimes;
     }
   c.deskTimesCsv = desk;
   c.deskNamesCsv = InpEvtDeskNames;
   return(c);
  }

void DashApplySessionCfg()
  {
   g_msSessionCfg.asiaStart   = InpSessAsiaStart;
   g_msSessionCfg.asiaEnd     = InpSessAsiaEnd;
   g_msSessionCfg.londonStart = InpSessLondonStart;
   g_msSessionCfg.londonEnd   = InpSessLondonEnd;
   g_msSessionCfg.nyStart     = InpSessNyStart;
   g_msSessionCfg.nyEnd       = InpSessNyEnd;
   g_msSessionCfg.sydneyStart = InpSessSydneyStart;
   g_msSessionCfg.sydneyEnd   = InpSessSydneyEnd;
  }

bool DashServicePeerAlive()
  {
   return(GsxFleetPeerHostOwns(InpMagic, GSX_HOST_SERVICE) &&
          GsxBusHeartbeatFresh(5));
  }

bool DashTryStartCore(const string why)
  {
   if(!InpDeskExecute)
      return(false);
   if(g_deskCoreActive)
      return(true);
   // Claim OWN + desk HB before Core so Service can yield on first tick (v2.14)
   GsxFleetServiceOwnSet(InpMagic, true);
   GsxFleetHostSet(InpMagic, GSX_HOST_DESK);
   GsxSignalBusHeartbeat("gsignalx-desk");
   GsxCoreInitEx(GSX_HOST_DESK, true);
   g_deskCoreActive = true;
   PrintFormat("GSX Desk: Core started host=desk (%s)", why);
   return(true);
  }

void DashStopCore(const string why)
  {
   if(!g_deskCoreActive)
      return;
   GsxCoreDeinit();
   g_deskCoreActive = false;
   PrintFormat("GSX Desk: Core stopped (%s)", why);
  }

//+------------------------------------------------------------------+
void DashDealWatch()
  {
   GsxTgDeskHeartbeat(InpMagic);
   GsxTgwPoll(InpMagic, g_tgCfg, true);
   // v2.13: Prop trade count is owned by Core GsxPropOnNewEntry after fills
   g_tgSessionPl = g_tgwSessionPl;
  }

double DashEquityDdPct()
  {
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_propSt.dayPeakEquity <= 0.0)
      return(0.0);
   return(100.0 * (g_propSt.dayPeakEquity - eq) / g_propSt.dayPeakEquity);
  }

void DashMaybeSummaries()
  {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   datetime dayStart = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));

   if(g_lastDailySummary != dayStart && TimeGMT() - dayStart < 300)
     {
      string body = GsxTgBuildDailyBody(g_propSt.dayRealized,
                                        MathMax(g_propSt.tradesToday, g_tgwDayTrades),
                                        g_tgwDayWins,
                                        DashEquityDdPct(),
                                        AccountInfoDouble(ACCOUNT_BALANCE));
      GsxTgNotifyDaily(g_tgCfg, body);
      g_tgWeekTrades += MathMax(g_propSt.tradesToday, g_tgwDayTrades);
      g_tgWeekWins += g_tgwDayWins;
      g_lastDailySummary = dayStart;
     }

   if(dt.day_of_week == 1 && dt.hour == 0 && dt.min < 5)
     {
      if(g_lastWeeklySummary != dayStart)
        {
         string body = GsxTgBuildWeeklyBody(g_propSt.weekRealized,
                                            g_tgWeekTrades, g_tgWeekWins,
                                            DashEquityDdPct(),
                                            AccountInfoDouble(ACCOUNT_BALANCE));
         GsxTgNotifyWeekly(g_tgCfg, body);
         g_tgWeekTrades = 0;
         g_tgWeekWins = 0;
         g_lastWeeklySummary = dayStart;
        }
     }
  }

void DashPollEvents(const bool force)
  {
   int pollSec = MathMax(5, InpEvtPollSec);
   if(!force && g_lastEvtPoll != 0 && (TimeCurrent() - g_lastEvtPoll) < pollSec)
      return;

   GsxEventGateConfig ecfg = DashBuildEvtConfig();
   GsxEventGateSnapshot esnap;
   GsxEventGatePoll(ecfg, g_tgCfg, true, esnap);
   g_evtLine = esnap.nextLine;
   g_evtMode = esnap.mode;
   g_lastEvtPoll = TimeCurrent();
  }

void DashPublishDeskTimeframe()
  {
   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)Period();
   if(!GsxRosterTimeframeValid(tf))
      tf = (GsxRosterTimeframeValid(InpTimeframe) ? InpTimeframe : PERIOD_M5);
   GsxRosterTimeframeSet(InpMagic, tf);
  }

void DashRefreshPanel(const bool forceRedraw = false)
  {
   DashPublishDeskTimeframe();
   DashApplySessionCfg();
   GsxMsPanelSetUiScale(InpUiScale);
   GsxMsPanelSetVision((int)InpUiVision);
   GsxMsPanelSetShowPractice(InpShowPractice);
   GsxMsPanelApplyAdaptive();
   GsxMsSnapshot snap;
   GsxMsBuildSnapshot(InpMagic, InpFleetTargetPairs, g_msPageSize, snap);
   GsxMsSnapshotApplyScout(snap, InpScoutLinkEnable, InpScoutInstanceID);
   GsxSessionClockNow(g_msSessionCfg, snap.session);
   snap.propStatus = GsxPropStatusText(g_propSt);
   snap.propPeakDdPct    = GsxPropPeakDdPct(g_propSt);
   snap.propDayRealized  = g_propSt.dayRealized;
   snap.propWeekRealized = g_propSt.weekRealized;
   snap.propTradesToday  = g_propSt.tradesToday;
   snap.propMaxTrades    = InpPropMaxTradesDay;
   snap.continuousFleet  = InpContinuousFleet;
   datetime dayFrom = g_propSt.dayKey;
   if(dayFrom <= 0)
     {
      MqlDateTime dt;
      TimeToStruct(TimeGMT(), dt);
      dayFrom = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
     }
   GsxPropSessionOutcomes(InpMagic, dayFrom,
                          snap.sessionWins, snap.sessionLosses, snap.sessionNetPl);

   GsxTgPublished pub;
   GsxTgReadPublishedStatus(InpMagic, pub);
   snap.tgStatus = GsxTgStatusText();
   if(snap.tgStatus == "NotCfg" && pub.status == GSX_TG_VERIFIED)
      snap.tgStatus = "Verified";
   else if(snap.tgStatus == "NotCfg" && pub.status == GSX_TG_ERROR)
      snap.tgStatus = "Error";
   snap.tgSent = GsxTgSentToday();
   snap.tgFail = GsxTgFailToday();
   snap.tgQueue = GsxTgQueueDepth();
   snap.tgLastError = GsxTgLastError();
   snap.eventLine = g_evtLine;
   snap.eventMode = GsxEventModeGet(InpMagic);
   g_msPage = snap.page;

   string fp = GsxMsSnapshotFingerprint(snap);
   // v2.13: forced heartbeat redraw 8s (was 2s) — fingerprint still drives dirty path
   bool heartbeat = (g_lastForcedRedraw == 0 || TimeCurrent() - g_lastForcedRedraw >= 8);
   if(!forceRedraw && !heartbeat && fp == g_lastSnapFp)
      return;

   g_lastSnapFp = fp;
   g_lastForcedRedraw = TimeCurrent();
   GsxMsPanelDrawFull(snap);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   g_msPanelX      = InpPanelX;
   g_msPanelY      = InpPanelY;
   g_msShowButtons = InpShowButtons;
   g_msDefaultFleet = MathMax(0, InpFleetTargetPairs);
   g_msFlipWait    = InpFlipWaitDefault;

   GsxMsPanelInit(InpMagic, InpPageSize, false, InpUiScale, (int)InpUiVision);
   GsxMsPanelSetScoutLink(InpScoutLinkEnable, InpScoutInstanceID);
   GsxMsPanelSetShowPractice(InpShowPractice);
   DashPublishDeskTimeframe();
   GsxRosterClassMaxSet(InpMagic, InpClassSoftMax);
   g_msClassMax = GsxRosterClassMaxGet(InpMagic);
   DashApplySessionCfg();

   string names[];
   GsxRosterStoreEnsure(InpMagic, InpSymbolList, names);

   if(GsxRosterFleetTargetGet(InpMagic) <= 0 && InpFleetTargetPairs > 0)
      GsxRosterFleetTargetSet(InpMagic, InpFleetTargetPairs);

   if(!GlobalVariableCheck(GsxMsFlipVar()))
      GsxMsPanelSetFlip(InpFlipWaitDefault);

   // Product default: FIXED 0.01 — seed only if missing so reattach keeps desk toggle (v2.14)
   GsxRosterAutoLotSeed(InpMagic, InpAutoLotDefault);

   if(!GlobalVariableCheck(GsxEventModeVar(InpMagic)))
      GsxEventModeSet(InpMagic, (InpEvtModeDefault == 1 ? GSX_EVT_MODE_SKIP : GSX_EVT_MODE_TRADE));

   g_tgCfg = DashBuildTgConfig();
   g_propCfg = DashBuildPropConfig();
   GsxPropLoad(InpMagic, g_propSt);
   GsxPropEnsureDayWeek(g_propSt);
   // v2.13.1: release stale EQUITY_DD trap from prior 5% default so desk can trade
   if(g_propSt.locked &&
      (g_propSt.reason == "EQUITY_DD" || InpPropMaxEquityDdPct <= 0.0))
     {
      if(g_propSt.reason == "EQUITY_DD" || InpPropMaxEquityDdPct <= 0.0)
        {
         GsxPropGrantEquityGrace(InpMagic, 300);
         GsxPropClearLock(g_propCfg, g_propSt, false);
         Print("GSX Trade Center: cleared stale Prop EQUITY_DD lock (gate off or eased)");
        }
     }
   // One evaluate to apply off/recover rules to GV
   {
      bool became = false;
      GsxPropEvaluate(g_propCfg, g_propSt, became);
   }

   GsxTgSetMagic(InpMagic);
   GsxTgSetHostTag("desk");
   string acct = StringFormat("%I64d %s desk", AccountInfoInteger(ACCOUNT_LOGIN),
                              AccountInfoString(ACCOUNT_SERVER));
   GsxTgInit(g_tgCfg, acct);
   GsxTgDeskHeartbeat(InpMagic);
   GsxTgwSeedFromOpen(InpMagic);

   GsxSettingsBindHost(g_tgCfg, InpMagic, InpScoutInstanceID, "desk",
                       InpDeskExecute, "SCOUTER");
   if(InpTgEnable)
      GsxSettingsNotifyLoad(g_tgCfg, InpMagic, InpScoutInstanceID, "desk",
                            InpDeskExecute, "SCOUTER");

   DashTryStartCore("OnInit");

   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   ChartSetInteger(0, CHART_EVENT_MOUSE_WHEEL, true);
   int cycle = (int)MathMax(50, InpCycleMs);
   int uiMs  = (int)MathMax(100, InpRefreshMs);
   int ms = (InpDeskExecute ? (int)MathMin(cycle, uiMs) : uiMs);
   EventSetMillisecondTimer(ms);
   g_deskLastCoreMs = GetTickCount();
   g_deskLastUiMs   = GetTickCount();

   DashPollEvents(true);

   PrintFormat("GSX Trade Center v2.13 | magic=%I64d | deskExec=%s core=%s | tg=%s | prop=%s | cycle=%dms ui=%dms | roster=%d | contFleet=%s",
               InpMagic,
               (InpDeskExecute ? "ON" : "OFF"),
               (g_deskCoreActive ? "ACTIVE" : "OFF"),
               (InpTgEnable ? GsxTgStatusText() : "OFF"),
               (InpPropEnable ? "ON" : "OFF"),
               cycle, uiMs,
               ArraySize(names),
               (InpContinuousFleet ? "ON" : "OFF"));
   Print("GSX v2.13: attach Dashboard once · DeskExecute=true · stop Service to avoid OWN clash · Scouter owns exits");
   DashRefreshPanel(true);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   DashStopCore("OnDeinit");
   GsxTgDeinit(g_tgCfg, g_tgwSessionPl);
   GsxPropSave(InpMagic, g_propSt);
   GsxMsPanelSavePos();
   GsxMsPanelDelete();
  }

void OnTimer()
  {
   ulong now = GetTickCount();
   int cycle = (int)MathMax(50, InpCycleMs);
   int uiMs  = (int)MathMax(100, InpRefreshMs);

   // Claim Core if needed; keep DeskExecute as primary owner (Service yields)
   if(InpDeskExecute)
     {
      if(!g_deskCoreActive)
         DashTryStartCore("timer reclaim");
     }
   else if(g_deskCoreActive)
      DashStopCore("DeskExecute off");

   if(g_deskCoreActive && (now - g_deskLastCoreMs >= (ulong)cycle))
     {
      g_deskLastCoreMs = now;
      DashPublishDeskTimeframe();
      GsxCoreCycle();
     }

   if(now - g_deskLastUiMs < (ulong)uiMs)
      return;
   g_deskLastUiMs = now;

   g_tgCfg = DashBuildTgConfig();
   g_propCfg = DashBuildPropConfig();
   GsxTgMaybeReverify(g_tgCfg);
   GsxTgDeskHeartbeat(InpMagic);

   if(g_lastPropEval == 0 || TimeCurrent() - g_lastPropEval >= 2)
     {
      g_lastPropEval = TimeCurrent();
      bool became = false;
      if(GsxPropEvaluate(g_propCfg, g_propSt, became))
        {
        }
      if(became)
        {
         GsxTgNotifyCustom(g_tgCfg, "PROP",
                           "LOCK " + g_propSt.reason + " — entries stopped (Scouter keeps exits)");
        }
     }

   DashPollEvents(false);
   DashDealWatch();
   GsxSettingsRebindCfg(g_tgCfg);
   GsxSettingsDrainPending(g_tgCfg);
   GsxTgProcessQueueEx(g_tgCfg, 1);
   GsxTgPublishStatus(InpMagic);
   DashMaybeSummaries();
   DashRefreshPanel(false);
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == "GSXMS_BTN_PLAY")
     {
      // Clear soft-STOP; grant equity grace so EQUITY_DD does not instant re-lock
      GsxPropGrantEquityGrace(InpMagic, 180);
      GsxPropClearLock(g_propCfg, g_propSt, true);
      bool became = false;
      g_propCfg = DashBuildPropConfig();
      if(GsxPropEvaluate(g_propCfg, g_propSt, became) && g_propSt.locked)
        {
         // Money / max-trades / consistency still sticky — surface reason
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                          " PROP still breached — " + g_propSt.reason;
        }
      else
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                          " PLAY (prop unlocked)";
      GsxSettingsAnnounce("PLAY PROP");
     }
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == "GSXMS_BTN_PROP_CLEAR")
     {
      GsxPropGrantEquityGrace(InpMagic, 300);
      GsxPropClearLock(g_propCfg, g_propSt, true);
      g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                       " PROP CLEAR + PLAY armed";
      GsxSettingsAnnounce("PROP CLEAR");
      if(g_deskCoreActive)
        {
         DashPublishDeskTimeframe();
         GsxCoreCycle();
         g_deskLastCoreMs = GetTickCount();
        }
      DashRefreshPanel(true);
      return;
     }
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == "GSXMS_BTN_TG_VERIFY")
     {
      g_tgCfg = DashBuildTgConfig();
      string err;
      // Soft VERIFY: Verified if ≥1 chat delivers; dead chats skipped for sends
      if(GsxTgVerifyConnection(g_tgCfg, err))
        {
         GsxTgSendNow(g_tgCfg, "TG",
                      "Connection verified — Trade Center\n" + GsxTvPubFooterLine());
         if(err != "")
           {
            string warn = err;
            if(StringLen(warn) > 56)
               warn = StringSubstr(warn, 0, 56);
            g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                             " TG VERIFY ok · " + warn;
           }
         else
            g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " TG VERIFY ok";
        }
      else
        {
         g_tgLastError = err;
         string detail = err;
         if(StringLen(detail) > 72)
            detail = StringSubstr(detail, 0, 72);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                          " TG VERIFY fail · " + detail;
        }
      GsxTgPublishStatus(InpMagic);
      DashRefreshPanel(true);
      return;
     }

   if(GsxMsPanelOnChartEvent(id, lparam, dparam, sparam))
     {
      if(id == CHARTEVENT_OBJECT_CLICK && sparam == "GSXMS_BTN_EVT")
         DashPollEvents(true);
      // Immediate Core pass after PLAY/ADD so fills are not UI-cadence delayed
      if(g_deskCoreActive && id == CHARTEVENT_OBJECT_CLICK)
        {
         DashPublishDeskTimeframe();
         GsxCoreCycle();
         g_deskLastCoreMs = GetTickCount();
        }
      DashRefreshPanel(true);
     }
  }

//+------------------------------------------------------------------+
