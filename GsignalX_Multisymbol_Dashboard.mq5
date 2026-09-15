//+------------------------------------------------------------------+
//|                            GsignalX_Multisymbol_Dashboard.mq5     |
//|  Prop Firm Trade Center (Velocity 2.00 / v1.26)                   |
//|  Categories · pair state · session clock · hybrid events          |
//|  NEVER closes positions. Scouter owns exits.                      |
//+------------------------------------------------------------------+
#property copyright   "Gocity Group"
#property version     "2.00"
#property description "Gsignalx Velocity Trade Center — categories, sessions, events"
#property description "Telegram notifier (WebRequest). Soft STOP only — never closes trades."

#include <GSignalX/RosterStore.mqh>
#include <GSignalX/MultisymbolPanel.mqh>
#include <GSignalX/TelegramNotifier.mqh>
#include <GSignalX/TgDealWatch.mqh>
#include <GSignalX/PropRisk.mqh>
#include <GSignalX/EventGate.mqh>
#include <GSignalX/SessionClock.mqh>

//+------------------------------------------------------------------+
input group "1) Identity & fleet"
input long   InpMagic            = 20260904;
input int    InpFleetTargetPairs = 4;
input int    InpPageSize         = 8;
input string InpSeedList         = "EURUSD,GBPUSD,USDJPY,AUDUSD,XAUUSD,XAGUSD,USOIL,UKOIL,BTCUSD,ETHUSD,XRPUSD,LTCUSD";
input int    InpClassSoftMax     = 8;      // soft max pairs per category (>=4)
input int    InpRefreshMs        = 1000;   // v2.01: UI cadence (Prop/TG/Events independent)

input group "2) Panel"
input int    InpPanelX           = 12;
input int    InpPanelY           = 22;
input double InpUiScale          = 1.5;   // UI scale request (system applies −40% size policy)
input ENUM_GSX_UI_VISION InpUiVision = GSX_VISION_COMFORT; // Near / Comfort / Far readability
input bool   InpShowButtons      = true;
input bool   InpFlipWaitDefault  = false;

input group "3) Telegram notifier"
input bool   InpTgEnable              = false;
input string InpTgBotToken            = "";
input string InpTgChatId1             = "";
input string InpTgChatId2             = "";
input string InpTgChatId3             = "";
input int    InpTgSilentStartHourGMT  = -1;  // -1 = off
input int    InpTgSilentEndHourGMT    = -1;
input int    InpTgRatePerMin          = 20;
input int    InpTgMaxRetries          = 3;

input group "4) Prop challenge pack"
input bool   InpPropEnable            = true;
input double InpPropDailyLossMoney    = 0.0;   // 0=off
input double InpPropDailyLossPct      = 0.0;   // 0=off
input double InpPropMaxEquityDdPct    = 5.0;   // 0=off
input int    InpPropMaxTradesDay      = 0;     // 0=off
input double InpPropMaxDaySharePct    = 0.0;   // consistency; 0=off
input double InpPropDailyProfitTarget = 0.0;   // 0=off
input int    InpPropBlockFridayHour   = 20;    // -1=off
input int    InpPropNewsBlackoutMin   = 0;     // sticky PROP STOP; minutes either side
input string InpPropNewsTimes         = "";    // YYYY.MM.DD HH:MM,...

input group "5) Session clock (illustrative GMT)"
input int    InpSessAsiaStart         = 0;
input int    InpSessAsiaEnd           = 9;
input int    InpSessLondonStart       = 7;
input int    InpSessLondonEnd         = 16;
input int    InpSessNyStart           = 12;
input int    InpSessNyEnd             = 21;
input int    InpSessSydneyStart       = 21;
input int    InpSessSydneyEnd         = 6;

input group "6) Events (calendar + desk CSV)"
input bool   InpEvtCalendarEnable     = true;
input int    InpEvtLookAheadMin       = 120;
input int    InpEvtBlackoutMin        = 30;    // SKIP radius either side
input int    InpEvtNotifyAheadMin     = 30;
input int    InpEvtModeDefault        = 0;     // 0=TRADE 1=SKIP
input string InpEvtDeskTimes          = "";    // YYYY.MM.DD HH:MM,... (merged with prop news CSV)
input string InpEvtDeskNames          = "";    // optional names parallel to desk times
input int    InpEvtPollSec            = 30;

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
   // merge desk + prop news CSV for hybrid desk events
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

//+------------------------------------------------------------------+
void DashDealWatch()
  {
   GsxTgDeskHeartbeat(InpMagic);
   GsxTgwPoll(InpMagic, g_tgCfg, true);
   for(int i = 0; i < g_tgwNewOpens; i++)
     {
      GsxPropOnNewEntry(g_propSt);
     }
   if(g_tgwNewOpens > 0)
      GsxPropSave(InpMagic, g_propSt);
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

void DashRefreshPanel(const bool forceRedraw = false)
  {
   DashApplySessionCfg();
   GsxMsPanelSetUiScale(InpUiScale);
   GsxMsPanelSetVision((int)InpUiVision);
   GsxMsPanelApplyAdaptive();
   GsxMsSnapshot snap;
   GsxMsBuildSnapshot(InpMagic, InpFleetTargetPairs, g_msPageSize, snap);
   GsxSessionClockNow(g_msSessionCfg, snap.session);
   snap.propStatus = GsxPropStatusText(g_propSt);

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
   bool heartbeat = (g_lastForcedRedraw == 0 || TimeCurrent() - g_lastForcedRedraw >= 2);
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
   GsxRosterClassMaxSet(InpMagic, InpClassSoftMax);
   g_msClassMax = GsxRosterClassMaxGet(InpMagic);
   DashApplySessionCfg();

   string names[];
   GsxRosterStoreEnsure(InpMagic, InpSeedList, names);

   if(GsxRosterFleetTargetGet(InpMagic) <= 0 && InpFleetTargetPairs > 0)
      GsxRosterFleetTargetSet(InpMagic, InpFleetTargetPairs);

   if(!GlobalVariableCheck(GsxMsFlipVar()))
      GsxMsPanelSetFlip(InpFlipWaitDefault);

   if(!GlobalVariableCheck(GsxEventModeVar(InpMagic)))
      GsxEventModeSet(InpMagic, (InpEvtModeDefault == 1 ? GSX_EVT_MODE_SKIP : GSX_EVT_MODE_TRADE));

   g_tgCfg = DashBuildTgConfig();
   g_propCfg = DashBuildPropConfig();
   GsxPropLoad(InpMagic, g_propSt);
   GsxPropEnsureDayWeek(g_propSt);

   GsxTgSetMagic(InpMagic);
   GsxTgSetHostTag("desk");
   string acct = StringFormat("%I64d %s desk", AccountInfoInteger(ACCOUNT_LOGIN),
                              AccountInfoString(ACCOUNT_SERVER));
   GsxTgInit(g_tgCfg, acct);
   GsxTgDeskHeartbeat(InpMagic);
   GsxTgwSeedFromOpen(InpMagic);

   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   int ms = (int)MathMax(100, InpRefreshMs);
   EventSetMillisecondTimer(ms);

   DashPollEvents(true);

   PrintFormat("GSX Trade Center v2.01 | magic=%I64d | tg=%s | prop=%s | evt=%s | refresh=%dms | roster=%d",
               InpMagic,
               (InpTgEnable ? GsxTgStatusText() : "OFF"),
               (InpPropEnable ? "ON" : "OFF"),
               (InpEvtCalendarEnable ? "CAL+DESK" : "DESK"),
               ms,
               ArraySize(names));
   Print("GSX best use: one magic · M5 Service · fleet 4 · FX+CMD START · CR SUSPEND · Event SKIP · TG desk+svc");
   Print("GSX best use practice: 20/50/100 · RAW/STD · SCALP/DAY/SWING · load Practice_*.set + restart · docs/PRACTICE_LIVE_SIM_20_50_100.md");
   DashRefreshPanel(true);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   GsxTgDeinit(g_tgCfg, g_tgwSessionPl);
   GsxPropSave(InpMagic, g_propSt);
   GsxMsPanelSavePos();
   GsxMsPanelDelete();
  }

void OnTimer()
  {
   g_tgCfg = DashBuildTgConfig();
   g_propCfg = DashBuildPropConfig();
   GsxTgMaybeReverify(g_tgCfg);
   GsxTgDeskHeartbeat(InpMagic);

   // Prop every ≥2s (HistorySelect is expensive)
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
   // TG: at most one WebRequest budget per timer tick
   GsxTgProcessQueueEx(g_tgCfg, 1);
   GsxTgPublishStatus(InpMagic);
   DashMaybeSummaries();
   DashRefreshPanel(false);
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == "GSXMS_BTN_PLAY")
     {
      g_propSt.locked = false;
      g_propSt.reason = "";
      GsxPropSave(InpMagic, g_propSt);
     }
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == "GSXMS_BTN_TG_VERIFY")
     {
      g_tgCfg = DashBuildTgConfig();
      string err;
      if(GsxTgVerifyConnection(g_tgCfg, err))
        {
         GsxTgSendNow(g_tgCfg, "TG", "Re-verified — " + GsxTgEscapeMarkdown("desk"));
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " TG VERIFY ok";
        }
      else
        {
         g_tgLastError = err;
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " TG VERIFY fail";
        }
      GsxTgPublishStatus(InpMagic);
      DashRefreshPanel(true);
      return;
     }

   if(GsxMsPanelOnChartEvent(id, lparam, dparam, sparam))
     {
      if(id == CHARTEVENT_OBJECT_CLICK && sparam == "GSXMS_BTN_EVT")
         DashPollEvents(true);
      DashRefreshPanel(true);
     }
  }

//+------------------------------------------------------------------+
