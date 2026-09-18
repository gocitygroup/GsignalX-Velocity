//+------------------------------------------------------------------+
//|                                        GsignalX_GocityGroup.mq5  |
//|                                                    Gocity Group  |
//|                                                                  |
//|  GsignalX - multi-engine trend Expert Advisor                    |
//|                                                                  |
//|  Engine 1 : PP SuperTrend        (pivot-centred ATR trail)       |
//|  Engine 2 : ATR SuperTrend + MA  (classic SuperTrend + filter)   |
//|  Engine 3 : SuperBollingerTrend  (Bollinger-band trail)          |
//|                                                                  |
//|  Simple mode   : any enabled trigger opens a trade.              |
//|  Advanced mode : trigger must be backed by N agreeing engines.    |
//|                                                                  |
//|  Session aware: FX weekends blocked; crypto 24/7 when allowed.    |
//|  Start mode   : act on the current trend, or wait for the next    |
//|                 complete (freshly closed) signal.                 |
//|                                                                  |
//|  (c) Gocity Group - GsignalX. Research / educational use.        |
//+------------------------------------------------------------------+
#property copyright "Gocity Group"
#property version   "2.00"
#property description "Gsignalx Velocity 2.00 - PP SuperTrend + ATR SuperTrend + SuperBollingerTrend"
#property description "AutoLot/FIXED + EQ equity guide + Compact/Full outcome panel."
#property description "Entry engine: limit/stop bracket, scalping drill, fleet fill."
#property description "Fleet: 4 pairs complete = open position OR working pending."
#property description "Multisymbol roster strip; defers when GsignalX_Service owns magic."
#property description "Scouter mode: catastrophe SL; FOLLOW/WAIT; movable panel."
#property description "STOP / HALT pause the operation only - neither ever closes a trade."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <GSignalX/BusProtocol.mqh>
#include <GSignalX/BusIO.mqh>
#include <GSignalX/SignalBus.mqh>
#include <GSignalX/SymbolCanon.mqh>
#include <GSignalX/TerminalIdentity.mqh>
#include <GSignalX/OpportunityGrade.mqh>
#include <GSignalX/LotSizing.mqh>
#include <GSignalX/ChartPanel.mqh>
#include <GSignalX/Fleet.mqh>
#include <GSignalX/ScoutLink.mqh>
#include <GSignalX/Engines.mqh>
#include <GSignalX/MarketGates.mqh>
#include <GSignalX/FollowGate.mqh>
#include <GSignalX/MultisymbolPanel.mqh>
#include <GSignalX/RosterStore.mqh>
#include <GSignalX/TelegramNotifier.mqh>
#include <GSignalX/TgDealWatch.mqh>
#include <GSignalX/CloseTrigger.mqh>
#include <GSignalX/SettingsNotify.mqh>

//+------------------------------------------------------------------+
//| Enumerations                                                     |
//+------------------------------------------------------------------+
enum EnGsxMode
  {
   GSX_SIMPLE   = 0,   // Simple (any enabled trigger)
   GSX_ADVANCED = 1    // Advanced (N engines must agree)
  };

enum EnStartMode
  {
   GSX_START_NEXT    = 0,  // Next complete signal (wait for a fresh flip)
   GSX_START_CURRENT = 1   // Current signal (join the trend already in place)
  };

enum EnRiskMode
  {
   GSX_RISK_LOT = 0,   // Fixed lot size
   GSX_RISK_PCT = 1    // Percent of balance risked per trade
  };

enum EnEntryMode
  {
   GSX_ENTRY_MARKET = 0,  // Market order only
   GSX_ENTRY_LIMIT  = 1,  // Limit only (wait for a pullback)
   GSX_ENTRY_STOP   = 2,  // Stop only (wait for a breakout)
   GSX_ENTRY_BOTH   = 3   // Both: limit + stop bracket (OCO)
  };

enum EnOffsetUnit
  {
   GSX_UNIT_PIPS   = 0,   // Pips
   GSX_UNIT_POINTS = 1    // Points
  };

enum EnTrailMode
  {
   GSX_TRAIL_OFF = 0,  // Off
   GSX_TRAIL_PP  = 1,  // Trail on PP SuperTrend line
   GSX_TRAIL_SBT = 2   // Trail on SuperBollingerTrend line
  };

enum EnExitMode
  {
   GSX_EXIT_SIGNAL   = 0,  // Signal closes on reverse (legacy)
   GSX_EXIT_SCOUTER  = 1   // Profit Scouter owns all closes (signal never closes)
  };

enum EnPanelDensity
  {
   GSX_PANEL_COMPACT = 0,  // Investor: outcome-first, engines hidden
   GSX_PANEL_FULL    = 1   // Trader: engines + entry detail
  };

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "1) Mode & signal routing"
input EnGsxMode   InpMode          = GSX_SIMPLE;   // Mode
input bool        InpTrigPP        = true;         // Trigger: PP SuperTrend
input bool        InpTrigST        = false;        // Trigger: ATR SuperTrend
input bool        InpTrigSBT       = true;         // Trigger: SuperBollingerTrend
input int         InpMinAgree      = 2;            // Engines that must agree (Advanced)
input EnStartMode InpStartMode     = GSX_START_NEXT; // Start from
input bool        InpEvalClosedBar = true;         // Evaluate on closed bars only

input group "2) PP SuperTrend (pivot)"
input int         InpPivotPrd      = 2;            // Pivot Point Period
input double      InpPPFactor      = 3.0;          // PP ATR Factor
input int         InpPPAtrLen      = 10;           // PP ATR Period

input group "3) ATR SuperTrend + MA filter"
input int         InpStLen         = 10;           // SuperTrend ATR Period
input double      InpStMult        = 3.0;          // SuperTrend ATR Multiplier
input bool        InpUseMA         = true;         // Use MA trend filter
input int         InpMaLen         = 20;           // MA Period

input group "4) SuperBollingerTrend"
input int         InpBBLen         = 12;           // BB Period
input double      InpBBMult        = 2.0;          // BB Multiplier

input group "5) Trade management"
input bool        InpAllowLong     = true;         // Allow Longs
input bool        InpAllowShort    = true;         // Allow Shorts
input bool        InpReverse       = true;         // Reverse on opposite signal
input bool        InpUseStop       = true;         // ATR span (SL in legacy mode; sizing only in Scouter mode)
input double      InpStopMult      = 2.0;          // ATR Stop Multiplier (sizing / legacy SL)
input bool        InpStrategicStopEnable = true;   // Scouter: attach wider catastrophe broker SL
input double      InpStrategicStopMult   = 4.0;    // Catastrophe SL ATR mult (wider than sizing)
input bool        InpUseTarget     = false;        // Use ATR Take-Profit
input double      InpTargetMult    = 4.0;          // ATR Target Multiplier
input int         InpRiskAtrLen    = 14;           // Risk ATR Period
input EnTrailMode InpTrailMode     = GSX_TRAIL_OFF;// Trailing stop source
input int         InpTrailBufferPt = 20;           // Trailing buffer (points)

input group "5b) Entry order type"
input EnEntryMode  InpEntryMode      = GSX_ENTRY_BOTH; // Entry order type (limit+stop bracket default)
input EnOffsetUnit InpOffsetUnit     = GSX_UNIT_PIPS;  // Offset unit
input int          InpLimitOffset    = 5;              // Limit offset from signal open (4..20, default 4-6)
input int          InpStopOffset     = 5;              // Stop offset from signal open (4..20, default 4-6)
input int          InpPendExpiryBars = 0;              // Cancel unfilled after N bars (0 = never / use drill)
input int          InpPendMaxAgeMin  = 240;            // Cancel unfilled pendings older than N minutes (0 = off)
input bool         InpCancelOnFlip   = true;           // Cancel pendings if engines flip against them
input bool         InpPendFromSignalOpen = true;       // Anchor limit/stop to signal bar open

input group "5c) Scalping drill"
input bool        InpDrillEnable       = true;   // Enable scalping drill window
input int         InpDrillMinutes      = 10;     // Drill window minutes after PLAY (5..15)
input bool        InpDrillAllowReentry = true;   // Re-enter while drill active + flat / wrong side
input bool        InpDrillFollowActive = true;   // Follow active engine direction (not flip-only)
input bool        InpDrillMarchAfterFlat = true; // Re-arm entry after harvest/flat while PLAY

input group "5d) Fleet fill (required active pairs)"
input bool        InpFleetEnable          = true;  // Keep required active pairs while PLAY
input int         InpFleetTargetPairs     = 4;     // Required pairs: open OR pending (this magic)
input int         InpFleetFillCooldownSec= 3;     // Min seconds between fleet fills (anti-stampede)
input bool        InpFleetRequireDrill    = false; // Fill only inside the drill window
input bool        InpChartEntriesWhenService = false; // When Service OWN=1: allow off-roster chart entries
input int         InpSignalMaxAgeSec      = 0;    // Reject dir-change entries older than N sec (0=off)

input group "5e) Exit ownership"
input EnExitMode  InpExitMode          = GSX_EXIT_SCOUTER; // Exit ownership (Scouter = signal never closes)
input bool        InpScoutLinkEnable   = true;  // PLAY/HALT also resume/pause Profit Scouter
input int         InpScoutInstanceID   = 1;     // Profit Scouter instance ID to link
input bool        InpFlipWaitDefault   = false; // Initial FOLLOW/WAIT (false=FOLLOW fill new dir)

input group "6) Money management"
input EnRiskMode  InpRiskMode      = GSX_RISK_PCT; // Position sizing (when AUTOLOT on)
input double      InpFixedLot      = 0.01;         // Fixed lot (FIXED mode / default)
input double      InpRiskPct       = 1.0;          // Risk per trade (%)
input double      InpMaxLot        = 5.0;          // Maximum lot cap
input bool        InpAutoLotDefault = false;       // false=FIXED 0.01; true=risk% AUTOLOT
input int         InpMaxDailyPositions = 0;        // Max new entries per UTC day (0 = off)
input double      InpMaxDailyDrawdownPct = 0.0;     // Equity guard: block entries if DD% >= (0 = off)

input group "7) Market open, sessions & weekend"
input bool        InpBlockWeekend  = true;         // Never trade Saturday / Sunday (FX)
input bool        InpUseSessions   = true;         // Respect broker trading sessions
input int         InpStaleTickSec  = 180;          // Treat market closed if no tick for N sec
input bool        InpUseHourFilter = false;        // Use trading-hour window
input int         InpStartHour     = 7;            // Window start hour (server time)
input int         InpEndHour       = 20;           // Window end hour (server time)
input bool        InpFridayStop    = true;         // Stop new trades late Friday (FX)
input int         InpFridayStopHr  = 20;           // Friday: no new trades after hour
input bool        InpCloseBeforeWE = false;        // Close open trades before weekend (FX)
input int         InpCloseWEHour   = 21;           // Friday: close all at hour
input bool        InpCryptoAllowWeekend = true;    // Crypto: allow Sat/Sun + skip Friday flat
input string      InpCryptoExtraList    = "";      // Extra crypto symbols (comma list)

input group "8) Execution"
input long        InpMagic         = 20260904;     // Magic number
input int         InpSlippage      = 20;           // Max deviation (points)
input int         InpMaxSpreadPt   = 40;           // Max spread (points, 0 = off)
input bool        InpIgnoreSpreadDefault = false;  // Chart SPREAD/IGN default (persisted)
input int         InpLookback      = 1200;         // Bars used for calculation
input string      InpComment       = "GsignalX";   // Order comment

input group "10) Chart appearance & controls"
input EnPanelDensity InpPanelDensity = GSX_PANEL_COMPACT; // Panel density (Compact investor / Full trader)
input bool         InpShowButtons  = true;               // Show PLAY/STOP/HALT/FOLLOW|WAIT/SPREAD|IGN/AUTOLOT|FIXED/EQ
input bool         InpShowRosterStrip = true;            // Compact multisymbol roster strip (v1.24)
input int          InpRosterStripPageSize = 4;           // Roster strip page size
input bool         InpShowArrows   = true;               // Draw signal arrows on the chart
input int          InpArrowBars    = 300;                // Arrows: how many bars back
input bool         InpShowLevels   = true;               // Draw engine + trade levels
input ENUM_BASE_CORNER InpCorner   = CORNER_LEFT_UPPER;  // Panel corner
input int          InpPanelX       = 12;                 // Panel X (initial; drag title to move; saved)
input int          InpPanelY       = 22;                 // Panel Y (initial; drag title to move; saved)
input double       InpUiScale      = 1.5;                // UI scale request (system applies −40% size policy)
input ENUM_GSX_UI_VISION InpUiVision = GSX_VISION_COMFORT; // Near / Comfort / Far readability
input string       InpFont         = "Segoe UI";         // Panel font
input int          InpFontSize     = 9;                  // Panel font size (design units)
input color        InpColBull      = C'38,208,124';      // Bullish colour
input color        InpColBear      = C'235,77,75';       // Bearish colour
input color        InpColNeutral   = C'150,155,170';     // Neutral colour
input color        InpColAccent    = C'240,185,60';      // Brand accent
input color        InpColPanelBg   = C'18,22,30';        // Panel background
input color        InpColPanelEdge = C'60,70,88';        // Panel border
input color        InpColText      = C'222,228,240';     // Panel text

input group "9) Notifications & panel"
input bool        InpShowPanel     = true;         // Show on-chart panel
input bool        InpAlertPopup    = false;        // Popup alert on signal
input bool        InpAlertPush     = false;        // Push notification on signal
input bool        InpVerboseSignals = true;        // Log skip reasons when a flip is filtered

input group "9b) Telegram notifier (chart attach)"
input bool   InpTgEnable             = false;
input string InpTgBotToken           = "";
input string InpTgChatId1            = "";
input string InpTgChatId2            = "";
input string InpTgChatId3            = "";
input int    InpTgSilentStartHourGMT = -1;
input int    InpTgSilentEndHourGMT   = -1;
input int    InpTgRatePerMin         = 20;
input int    InpTgMaxRetries         = 3;
input group "11) Connector bus (FILE_COMMON)"
input bool        InpBusEnable       = true;       // Publish signals + heartbeat
input int         InpSwingStartHour  = 12;         // Swing window start (server hour)
input int         InpSwingEndHour    = 17;         // Swing window end (server hour)
input bool        InpBusShowGrades   = true;       // Show top grades on panel

//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
CTrade        trade;
CPositionInfo posinfo;

int      gPPdir[];      // +1 / -1 per bar
int      gSTdir[];
int      gSBTdir[];
double   gPPline[];
double   gSTline[];
double   gSBTline[];
double   gMA[];
double   gAtrRisk[];
double   gClose[];
datetime gBarTime[];
int      gN = 0;
double   gOpen[];
double   gHigh[];
double   gLow[];

datetime gLastBarTime  = 0;   // last bar whose engines were calculated
datetime gInitBarTime  = 0;   // bar open time when the EA started
bool     gNeedSignalEval = false; // retry EvaluateSignals until gates pass this bar
bool     gFirstEntryDone = false;
bool     gDataReady    = false;
string   gStatus       = "initialising";
string   gLastAction   = "-";
int      gPendDir      = 0;   // direction of the pending bracket currently working
double   gIntendedLot  = 0.0; // size one leg was supposed to fill for
bool     gOcoRequest   = false; // event handler asked for a cleanup pass
bool     gTradingEnabled = true;  // PLAY / STOP state
GsxTgConfig g_chartTgCfg;
bool     g_chartTgSeeded = false;
string   gPfx            = "GSX_";
int      gLastSigDir     = 0;     // direction of the most recent trigger flip
datetime gSignalEventAt  = 0;     // when current wanted dir-change was first seen
int      gSignalEventDir = 0;
int      gLastSigIdx     = -1;    // its index in the calculation arrays
double   gSignalOpenPx   = 0.0;   // bar open at the active signal (pending anchor)
string   gBusGradeLine   = "grades: -";
datetime gBusLastPub     = 0;
datetime gDrillStart     = 0;     // PLAY time that opened the drill window (0 = inactive)
int      gDrillWanted    = 0;     // direction locked for the current drill window
bool     gHadPosition    = false; // last tick had our magic position (flat-edge detect)
bool     gMarchOnce      = false; // one-shot re-entry after harvest/flat while PLAY
string   gDrillStatus    = "off"; // panel: off / active Xm / expired
int      gFleetFills     = 0;     // fleet fills started by this chart (log/panel)
int      gFleetActive    = 0;     // last observed live pair count (panel)
//--- session outcome tracking (this magic, updated live on every close)
int      gClosedCount    = 0;     // trades closed since the EA started
int      gClosedWins     = 0;     // closes with profit >= 0
int      gClosedLosses   = 0;     // closes with profit < 0 (manual / legacy only)
double   gClosedRealized = 0.0;   // realized P/L this session (profit + swap + commission)
bool     gFlipWaitMode   = false; // false=FOLLOW (2A), true=WAIT (2B)
bool     gIgnoreSpread   = false; // true=bypass InpMaxSpreadPt on entries (IGN)
bool     gAutoLot        = true;  // true=risk%/InpRiskMode sizing; false=fixed lot
double   gMaxDailyDrawdownPct = 0.0; // equity guard threshold % (0 = OFF; chart EQ cycle)
int      gDailyPositionsOpened = 0; // entries counted today (UTC)
datetime gDailyResetDate = 0;     // day-start of last daily counter reset
//--- movable panel (drag title bar; position persisted per chart)
int      g_panelX = 12;
int      g_panelY = 22;
bool     g_panelDragging = false;
bool     g_panelDragOffSet = false;
int      g_panelDragOffX = 0;
int      g_panelDragOffY = 0;
int      g_panelW = 500;
int      g_panelLastH = 280;  // last painted signal panel height (roster strip anchor)
string   g_lastPanelState = "OPEN";
int      g_panelTitleH = 22;
string   gPanelBlockReason = "";  // surfaced on Status (equity/spread/daily/…)
bool     gUiDirty = true;
ulong    gUiLastMs = 0;
bool     gUiNeedChartArt = true;  // redraw arrows/levels on bar or position change
int      gUiLastPosDir = 0;       // track flat↔position for art dirty

//+------------------------------------------------------------------+
//| Service coexistence (v1.23)                                      |
//+------------------------------------------------------------------+
bool ChartServiceOwnsFleet()
  {
   return(GsxFleetServiceOwns(InpMagic));
  }

// Auto entries/fleet: Service owns magic → chart defers when _Symbol is on
// the shared roster (single owner). Override only applies off-roster symbols.
bool ChartAutoEntriesAllowed()
  {
   if(!ChartServiceOwnsFleet())
      return(true);
   if(GsxRosterStoreExists(InpMagic))
     {
      string names[];
      if(GsxRosterStoreLoad(InpMagic, names) && GsxRosterContains(names, _Symbol))
         return(false); // Service owns this roster pair — no chart duplicate
     }
   return(InpChartEntriesWhenService);
  }

void ChartSyncServiceRun(const bool on)
  {
   // Chart PLAY/STOP/HALT drives Service RUN GV for the same magic.
   GsxFleetServiceRunSet(InpMagic, on);
  }


//+------------------------------------------------------------------+
//| Connector bus — publish signal snapshot + heartbeat              |
//+------------------------------------------------------------------+
void GsxPublishBusState(const string tradeState)
  {
   if(!InpBusEnable)
      return;
   if(gBusLastPub != 0 && TimeCurrent() - gBusLastPub < 2)
      return;
   gBusLastPub = TimeCurrent();

   // v2.01 DRY: publish via shared SignalBus (same schema as Service)
   GsxEngineState st;
   st.n = 0;
   st.ready = false;
   st.lastBarTime = 0;
   st.lastSigDir = gLastSigDir;
   st.lastSigIdx = gLastSigIdx;
   st.status = "";
   if(gDataReady && gN >= 1)
     {
      int last = gN - 1;
      ArrayResize(st.ppDir, 1);
      ArrayResize(st.stDir, 1);
      ArrayResize(st.sbtDir, 1);
      st.ppDir[0] = gPPdir[last];
      st.stDir[0] = gSTdir[last];
      st.sbtDir[0] = gSBTdir[last];
      st.n = 1;
      st.ready = true;
     }

   string owner = (ChartServiceOwnsFleet() ? "service" : "chart");
   GsxSignalBusWriteSymbol(_Symbol, st, InpMagic, InpMinAgree,
                           (InpMode == GSX_SIMPLE ? 0 : 1),
                           EffectiveMaxSpreadPt(), InpStaleTickSec,
                           gIgnoreSpread,
                           InpSwingStartHour, InpSwingEndHour, InpCryptoExtraList,
                           true, gClosedCount, gClosedWins, gClosedLosses,
                           gClosedRealized, owner);
   GsxSignalBusHeartbeat("gsignalx");

   // Local grade line for chart strip (advisory)
   string reason = "";
   bool marketOpen = IsMarketOpen(reason);
   bool cryptoExempt = CryptoWeekendExempt();
   bool weekend = false;
   bool fridayLate = false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if((dt.day_of_week == SATURDAY || dt.day_of_week == SUNDAY) && !cryptoExempt)
      weekend = true;
   if(InpFridayStop && !cryptoExempt &&
      dt.day_of_week == FRIDAY && dt.hour >= InpFridayStopHr)
      fridayLate = true;

   int bull = 0, bear = 0, direction = 0;
   if(st.ready)
     {
      bull = (st.ppDir[0] == 1 ? 1 : 0) + (st.stDir[0] == 1 ? 1 : 0) + (st.sbtDir[0] == 1 ? 1 : 0);
      bear = 3 - bull;
      if(bull > bear) direction = 1;
      else if(bear > bull) direction = -1;
      if(st.lastSigDir != 0) direction = st.lastSigDir;
     }
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   bool stale = false;
   datetime tickTime = (datetime)SymbolInfoInteger(_Symbol, SYMBOL_TIME);
   if(InpStaleTickSec > 0 && tickTime > 0 && (TimeCurrent() - tickTime) > InpStaleTickSec)
      stale = true;

   GsxEntryInputs ein;
   ein.direction = direction;
   ein.bull = bull;
   ein.bear = bear;
   ein.min_agree = InpMinAgree;
   ein.in_session = marketOpen && !weekend;
   ein.weekend = weekend;
   ein.friday_late = fridayLate;
   ein.swing_window = GsxInSwingWindow(TimeCurrent(), InpSwingStartHour, InpSwingEndHour);
   ein.spread_pt = (int)spread;
   ein.max_spread_pt = EffectiveMaxSpreadPt();
   ein.stale_tick = stale;
   ein.market_open = marketOpen;
   GsxGradeResult local = GsxGradeEntry(ein);

   if(InpBusShowGrades)
     {
      string grades = GsxBusReadGrades();
      string topE = GsxBusTopGradeLine(grades, "entries");
      string topH = GsxBusTopGradeLine(grades, "harvests");
      gBusGradeLine = StringFormat("local %.0f | %s | %s", local.score, topE, topH);
     }
   else
      gBusGradeLine = StringFormat("local entry %.0f (%s)", local.score, tradeState);
  }

//+------------------------------------------------------------------+
//| Core - rebuild every engine from raw rates (shared Engines.mqh)  |
//+------------------------------------------------------------------+
bool CalcEngines()
  {
   gDataReady = false;

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

   GsxEngineState st;
   if(!GsxCalcEngines(_Symbol, (ENUM_TIMEFRAMES)_Period, p, st))
     {
      gStatus = (st.status == "" ? "waiting for history" : st.status);
      return(false);
     }

   int n = st.n;
   ArrayResize(gPPdir, n);   ArrayResize(gSTdir, n);   ArrayResize(gSBTdir, n);
   ArrayResize(gPPline, n);  ArrayResize(gSTline, n);  ArrayResize(gSBTline, n);
   ArrayResize(gMA, n);      ArrayResize(gAtrRisk, n);
   ArrayResize(gClose, n);   ArrayResize(gBarTime, n);
   ArrayResize(gHigh, n);    ArrayResize(gLow, n);
   ArrayResize(gOpen, n);

   for(int i = 0; i < n; i++)
     {
      gPPdir[i]   = st.ppDir[i];
      gSTdir[i]   = st.stDir[i];
      gSBTdir[i]  = st.sbtDir[i];
      gPPline[i]  = st.ppLine[i];
      gSTline[i]  = st.stLine[i];
      gSBTline[i] = st.sbtLine[i];
      gMA[i]      = st.ma[i];
      gAtrRisk[i] = st.atrRisk[i];
      gClose[i]   = st.close[i];
      gBarTime[i] = st.barTime[i];
      gOpen[i]    = st.open[i];
      gHigh[i]    = st.high[i];
      gLow[i]     = st.low[i];
     }

   gLastSigDir = st.lastSigDir;
   gLastSigIdx = st.lastSigIdx;
   gN = n;
   gDataReady = true;
   return(true);
  }

//+------------------------------------------------------------------+
//| Market open / session / weekend guards                           |
//+------------------------------------------------------------------+
bool CryptoWeekendExempt()
  {
   if(!InpCryptoAllowWeekend)
      return false;
   return GsxIsCryptoSymbolEx(_Symbol, InpCryptoExtraList);
  }

bool IsMarketOpen(string &reason)
  {
   return(GsxIsMarketOpen(_Symbol, InpStaleTickSec, InpBlockWeekend, InpUseSessions,
                          InpCryptoAllowWeekend, InpCryptoExtraList, reason));
  }

bool TimeFilterOK(string &reason)
  {
   return(GsxTimeFilterOK(_Symbol, InpUseHourFilter, InpStartHour, InpEndHour,
                          InpFridayStop, InpFridayStopHr,
                          InpCryptoAllowWeekend, InpCryptoExtraList, reason));
  }

//+------------------------------------------------------------------+
//| Offset helpers                                                   |
//+------------------------------------------------------------------+
double PipSize()
  {
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return(_Point * 10.0);
   return(_Point);
  }

int ClampOffset(int v)
  {
   if(v < 4)  v = 4;
   if(v > 20) v = 20;
   return(v);
  }

double OffsetPrice(int units)
  {
   double one = (InpOffsetUnit == GSX_UNIT_PIPS) ? PipSize() : _Point;
   return(ClampOffset(units) * one);
  }

// Bar open that anchors limit/stop to the active signal opening time.
double SignalAnchorOpen(const int fallbackIdx)
  {
   if(InpPendFromSignalOpen)
     {
      if(gSignalOpenPx > 0.0)
         return(gSignalOpenPx);
      if(gLastSigIdx >= 0 && gLastSigIdx < gN && gOpen[gLastSigIdx] > 0.0)
         return(gOpen[gLastSigIdx]);
     }
   if(fallbackIdx >= 0 && fallbackIdx < gN && gOpen[fallbackIdx] > 0.0)
      return(gOpen[fallbackIdx]);
   double mid = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) * 0.5;
   return(mid);
  }

// Enforce broker pending-side rules vs live ask/bid while keeping signal offset.
double NormalizePendingPrice(const int dir, const bool isStop, double price)
  {
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double minD   = BrokerMinDistance();
   if(minD <= 0.0)
      minD = _Point;

   if(dir == 1)
     {
      if(isStop)
        {
         // Buy Stop must be above Ask
         if(price <= ask)
            price = ask + minD;
         if(price - ask < minD)
            price = ask + minD;
        }
      else
        {
         // Buy Limit must be below Ask
         if(price >= ask)
            price = ask - minD;
         if(ask - price < minD)
            price = ask - minD;
        }
     }
   else
     {
      if(isStop)
        {
         // Sell Stop must be below Bid
         if(price >= bid)
            price = bid - minD;
         if(bid - price < minD)
            price = bid - minD;
        }
      else
        {
         // Sell Limit must be above Bid
         if(price <= bid)
            price = bid + minD;
         if(price - bid < minD)
            price = bid + minD;
        }
     }
   return(NormalizeDouble(price, digits));
  }

// smallest distance the broker will accept for a pending order or a stop
double BrokerMinDistance()
  {
   double stops  = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL)  * _Point;
   double freeze = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   return(MathMax(stops, freeze));
  }

//+------------------------------------------------------------------+
//| Exit ownership                                                   |
//| In Scouter mode the signal engine never reverse-closes a trade.  |
//| Optional catastrophe broker SL (InpStrategicStop*) is the only   |
//| broker-side stop; profit exits belong to Profit Scouter.         |
//+------------------------------------------------------------------+
bool ScouterOwnsExits()
  {
   return(InpExitMode == GSX_EXIT_SCOUTER);
  }

// Strategic catastrophe stop distance (wider than sizing ATR span).
double StrategicStopDistance(const double atr)
  {
   if(!ScouterOwnsExits() || !InpStrategicStopEnable || atr <= 0.0)
      return(0.0);
   double d = InpStrategicStopMult * atr;
   double minD = MinStopDistance();
   if(d < minD)
      d = minD;
   return(d);
  }

//+------------------------------------------------------------------+
//| Position helpers                                                 |
//+------------------------------------------------------------------+
ulong FindPosition(int &dir)
  {
   dir = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic)
         continue;
      long ptype = PositionGetInteger(POSITION_TYPE);
      dir = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      return(ticket);
     }
   return(0);
  }

// True if any account position with this magic is opposite to wanted (+1/-1).
bool MagicHasOppositeDir(const int wanted)
  {
   if(wanted == 0)
      return(false);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic)
         continue;
      long ptype = PositionGetInteger(POSITION_TYPE);
      int  dir   = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      if(dir != wanted)
         return(true);
     }
   return(false);
  }

// FOLLOW/WAIT + FollowDir (shared EntryExec). Entries only — open positions
// are never closed by a mode switch.
bool AllowNewDirEntry(const int wanted)
  {
   int followDir = GsxRosterFollowDirGet(InpMagic, _Symbol, GSX_FOLLOW_AUTO);
   return(GsxAllowEntry(wanted, gFlipWaitMode, InpMagic, followDir));
  }

double NormalizeLot(double lot)
  {
   return(GsxNormalizeLot(_Symbol, lot, InpMaxLot));
  }

double CalcLot(double stopDistance)
  {
   return(GsxCalcLot(_Symbol, stopDistance, gAutoLot, (int)InpRiskMode,
                     InpRiskPct, InpFixedLot, InpMaxLot, InpVerboseSignals));
  }

//+------------------------------------------------------------------+
//| Daily position counter + equity drawdown gate (AutoLot guide)    |
//+------------------------------------------------------------------+
void CheckAndResetDailyCounters()
  {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   datetime dayStart = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
   if(gDailyResetDate != dayStart)
     {
      gDailyPositionsOpened = 0;
      gDailyResetDate = dayStart;
      if(InpVerboseSignals)
         Print("GsignalX: daily position counters reset for ",
               TimeToString(dayStart, TIME_DATE));
     }
  }

bool IsWithinEquityGuard()
  {
   if(gMaxDailyDrawdownPct <= 0.0)
      return(true);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0)
      return(false);
   double drawdownPct = GsxAccountDrawdownPct();
   if(drawdownPct >= gMaxDailyDrawdownPct)
     {
      if(InpVerboseSignals)
         PrintFormat("GsignalX: equity guard triggered: drawdown=%.2f%% >= threshold=%.2f%%",
                     drawdownPct, gMaxDailyDrawdownPct);
      return(false);
     }
   return(true);
  }

bool CanOpenPosition()
  {
   CheckAndResetDailyCounters();
   if(InpMaxDailyPositions > 0 && gDailyPositionsOpened >= InpMaxDailyPositions)
     {
      if(InpVerboseSignals)
         PrintFormat("GsignalX: daily max positions reached (%d/%d) — no new orders",
                     gDailyPositionsOpened, InpMaxDailyPositions);
      return(false);
     }
   return(true);
  }

void RecordPositionOpened()
  {
   CheckAndResetDailyCounters();
   gDailyPositionsOpened++;
   if(InpVerboseSignals)
      PrintFormat("GsignalX: position %d/%s opened today",
                  gDailyPositionsOpened,
                  (InpMaxDailyPositions > 0
                   ? IntegerToString(InpMaxDailyPositions)
                   : "∞"));
  }

bool EntryRiskGuardsOk(string &blockReason)
  {
   blockReason = "";
   if(!IsWithinEquityGuard())
     {
      blockReason = "equity guard";
      return(false);
     }
   if(!CanOpenPosition())
     {
      blockReason = "daily max positions";
      return(false);
     }
   return(true);
  }

double MinStopDistance()
  {
   long level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   return((double)level * _Point);
  }

//+------------------------------------------------------------------+
//| Trading                                                          |
//+------------------------------------------------------------------+
// Effective entry spread limit: 0 = allow any (IGN on, or InpMaxSpreadPt=0).
// Class-aware: CMD/CR get higher ceilings than the FX base input.
int EffectiveMaxSpreadPt()
  {
   if(gIgnoreSpread)
      return(0);
   return(GsxEffectiveMaxSpreadPt(_Symbol, InpMaxSpreadPt));
  }

bool SpreadOK(string &reason)
  {
   int lim = EffectiveMaxSpreadPt();
   if(lim <= 0)
      return(true);
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > lim)
     { reason = "spread " + IntegerToString((int)spread) + " > limit"; return(false); }
   return(true);
  }

void Notify(string text)
  {
   if(InpAlertPopup)
      Alert("GsignalX ", _Symbol, ": ", text);
   if(InpAlertPush)
      SendNotification("GsignalX | Gocity Group - " + _Symbol + " " + text);
   Print("GsignalX: ", text);
  }

void SignalSkip(const string why, const bool hadRawFlip = false)
  {
   gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " skip: " + why;
   gPanelBlockReason = why;
   gUiDirty = true;
   if(InpVerboseSignals && hadRawFlip)
      Print("GsignalX: skip: ", why);
  }

void GsxUiMarkDirty()
  {
   gUiDirty = true;
  }

bool GsxUiShouldRedraw()
  {
   ulong now = GetTickCount();
   if(gUiDirty || (now - gUiLastMs) >= 250)
     {
      gUiLastMs = now;
      gUiDirty = false;
      return(true);
     }
   return(false);
  }

bool TradeAllowedNow(string &reason)
  {
   if(!gTradingEnabled)
     { reason = "PLAY off"; return(false); }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
     { reason = "AutoTrading off"; return(false); }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
     { reason = "account trade disabled"; return(false); }
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
     { reason = "expert trading disabled"; return(false); }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     { reason = "terminal trade disabled"; return(false); }
   long tmode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(tmode == SYMBOL_TRADE_MODE_DISABLED)
     { reason = "symbol trading disabled"; return(false); }
   if(tmode == SYMBOL_TRADE_MODE_CLOSEONLY)
     { reason = "close-only mode"; return(false); }
   return(true);
  }

bool TrySetFilling(const ENUM_ORDER_TYPE_FILLING fill)
  {
   trade.SetTypeFilling(fill);
   return(true);
  }

bool OrderSendFailedInvalidFill()
  {
   uint rc = trade.ResultRetcode();
   return(rc == TRADE_RETCODE_INVALID_FILL);
  }

void NoteOrderFail(const string what)
  {
   gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " " + what +
                 " failed: " + IntegerToString((int)trade.ResultRetcode()) +
                 " " + trade.ResultRetcodeDescription();
   Print("GsignalX: ", gLastAction);
  }

//+------------------------------------------------------------------+
//| Pending order management                                         |
//+------------------------------------------------------------------+
bool IsOurOrder()
  {
   if(OrderGetString(ORDER_SYMBOL) != _Symbol)
      return(false);
   if(OrderGetInteger(ORDER_MAGIC) != (long)InpMagic)
      return(false);
   return(true);
  }

int CountOurPendings()
  {
   int c = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderGetTicket(i) == 0)
         continue;
      if(IsOurOrder())
         c++;
     }
   return(c);
  }

void DeleteOurPendings(string why)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!IsOurOrder())
         continue;
      if(trade.OrderDelete(ticket))
         Print("GsignalX: pending #", ticket, " deleted (", why, ")");
      else
         Print("GsignalX: delete failed #", ticket, " retcode=", trade.ResultRetcode());
     }
   if(CountOurPendings() == 0)
      gPendDir = 0;
  }

//+------------------------------------------------------------------+
//| Stale pending sweep                                              |
//| Old brackets that never filled are cancelled by age, whatever    |
//| the drill / expiry-bars settings say - and orphans left over     |
//| from a previous session or a terminal restart are cleaned on    |
//| init. Keeps the book free of dead "not entered" orders.         |
//+------------------------------------------------------------------+
void CleanupStalePendings()
  {
   if(InpPendMaxAgeMin <= 0)
      return;

   long maxAge = (long)InpPendMaxAgeMin * 60;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!IsOurOrder())
         continue;
      datetime setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if((long)(TimeCurrent() - setup) >= maxAge)
        {
         if(trade.OrderDelete(ticket))
            Print("GsignalX: stale pending #", ticket, " cancelled (age ",
                  (long)((TimeCurrent() - setup) / 60), " min >= ", InpPendMaxAgeMin, ")");
         else
            Print("GsignalX: stale pending #", ticket, " delete failed retcode=",
                  trade.ResultRetcode());
        }
     }
   if(CountOurPendings() == 0)
      gPendDir = 0;
  }

//--- place one pending leg of the bracket
bool PlacePending(int dir, bool isStop, double price, double atr)
  {
   string gate = "";
   if(!TradeAllowedNow(gate))
     {
      SignalSkip(gate, true);
      return(false);
     }

   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double minD   = BrokerMinDistance();
   price = NormalizePendingPrice(dir, isStop, price);

   //--- sizing distance: ATR span drives percent-risk lot sizing.
   //    Scouter mode may also attach a WIDER catastrophe broker SL
   //    (InpStrategicStopMult); TP stays 0. Profit exits stay with Scouter.
   double stopDist = 0.0;
   if(atr > 0.0 && (InpUseStop || ScouterOwnsExits()))
      stopDist = InpStopMult * atr;
   if(stopDist > 0.0 && stopDist < minD)
      stopDist = minD;

   double sl = 0.0, tp = 0.0;
   double stratDist = 0.0;
   if(ScouterOwnsExits())
     {
      stratDist = StrategicStopDistance(atr);
      if(stratDist > 0.0)
         sl = (dir == 1) ? price - stratDist : price + stratDist;
     }
   else
     {
      if(stopDist > 0.0 && InpUseStop)
         sl = (dir == 1) ? price - stopDist : price + stopDist;
      if(InpUseTarget && atr > 0.0)
        {
         double tDist = InpTargetMult * atr;
         if(tDist < minD)
            tDist = minD;
         tp = (dir == 1) ? price + tDist : price - tDist;
        }
     }
   sl = (sl > 0.0) ? NormalizeDouble(sl, digits) : 0.0;
   tp = (tp > 0.0) ? NormalizeDouble(tp, digits) : 0.0;

   double lot = CalcLot(stopDist);
   if(lot <= 0.0)
     {
      SignalSkip("computed lot is zero", true);
      return(false);
     }

   string cmt = InpComment + (isStop ? " STP" : " LMT");
   bool   ok  = false;

   // Pending orders: try RETURN first (market FOK/IOC often rejects pendings)
   ENUM_ORDER_TYPE_FILLING fills[3] = {ORDER_FILLING_RETURN, ORDER_FILLING_IOC, ORDER_FILLING_FOK};
   for(int attempt = 0; attempt < 2 && !ok; attempt++)
     {
      if(attempt == 1)
        {
         price = NormalizePendingPrice(dir, isStop, price);
         if(sl > 0.0)
           {
            double reDist = (ScouterOwnsExits() ? stratDist : stopDist);
            if(reDist > 0.0)
               sl = NormalizeDouble((dir == 1) ? price - reDist : price + reDist, digits);
           }
         if(tp > 0.0 && InpUseTarget && atr > 0.0)
           {
            double tDist = MathMax(InpTargetMult * atr, minD);
            tp = NormalizeDouble((dir == 1) ? price + tDist : price - tDist, digits);
           }
        }

      for(int a = 0; a < 3 && !ok; a++)
        {
         TrySetFilling(fills[a]);
         if(dir == 1)
            ok = isStop ? trade.BuyStop(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, cmt)
                        : trade.BuyLimit(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, cmt);
         else
            ok = isStop ? trade.SellStop(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, cmt)
                        : trade.SellLimit(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, cmt);
        }
     }

   if(!ok)
     {
      NoteOrderFail("pending");
      return(false);
     }

   gIntendedLot = lot;
   gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " " +
                 ((dir == 1) ? "BUY " : "SELL ") + (isStop ? "STOP " : "LIMIT ") +
                 DoubleToString(lot, 2) + " @ " + DoubleToString(price, digits);
   Notify(((dir == 1) ? "BUY " : "SELL ") + (isStop ? "STOP " : "LIMIT ") +
          DoubleToString(lot, 2) + " @ " + DoubleToString(price, digits));
   if(ScouterOwnsExits() && sl > 0.0 && stratDist > 0.0)
      PrintFormat("GsignalX: catastrophe SL attached %.5f (ATR x %.1f = %.5f price dist) — broker may close without Scouter tag",
                  sl, InpStrategicStopMult, stratDist);
   return(true);
  }

//--- dispatcher: market, limit, stop, or both (prices from signal bar open)
bool PlaceEntry(int dir)
  {
   string riskBlock = "";
   if(!EntryRiskGuardsOk(riskBlock))
     {
      SignalSkip(riskBlock, true);
      return(false);
     }

   if(InpEntryMode == GSX_ENTRY_MARKET)
      return(OpenTrade(dir));

   double atr    = gAtrRisk[gN - 1];
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double minD   = BrokerMinDistance();

   double limOff = OffsetPrice(InpLimitOffset);
   double stpOff = OffsetPrice(InpStopOffset);

   //--- a 4-pip offset can sit inside the broker's minimum distance
   if(limOff <= minD)
      limOff = minD + _Point;
   if(stpOff <= minD)
      stpOff = minD + _Point;

   double base = SignalAnchorOpen(gN - 1);
   gSignalOpenPx = base;

   bool placed = false;

   if(InpEntryMode == GSX_ENTRY_LIMIT || InpEntryMode == GSX_ENTRY_BOTH)
     {
      // Pullback from signal open: buy below / sell above
      double p = (dir == 1) ? (base - limOff) : (base + limOff);
      p = NormalizePendingPrice(dir, false, p);
      if(PlacePending(dir, false, p, atr))
         placed = true;
      else
         if(InpVerboseSignals)
            Print("GsignalX: Buy/Sell Limit failed @ ", DoubleToString(p, digits),
                  " (signal open ", DoubleToString(base, digits), ")");
     }

   if(InpEntryMode == GSX_ENTRY_STOP || InpEntryMode == GSX_ENTRY_BOTH)
     {
      // Breakout from signal open: buy above / sell below
      double p = (dir == 1) ? (base + stpOff) : (base - stpOff);
      p = NormalizePendingPrice(dir, true, p);
      if(PlacePending(dir, true, p, atr))
         placed = true;
      else
         if(InpVerboseSignals)
            Print("GsignalX: Buy/Sell Stop failed @ ", DoubleToString(p, digits),
                  " (signal open ", DoubleToString(base, digits), ")");
     }

   if(placed)
     {
      gPendDir    = dir;
      gFirstEntryDone = true;
      if(StringFind(gLastAction, "LIMIT") < 0 && StringFind(gLastAction, "STOP") < 0)
         gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " " +
                       ((dir == 1) ? "BUY" : "SELL") + " bracket @ sig " +
                       DoubleToString(base, digits);
     }
   else
      SignalSkip("limit/stop not placed", true);
   return(placed);
  }

//--- OCO, expiry and invalidation
void ManagePendings()
  {
   if(CountOurPendings() == 0)
     {
      gPendDir = 0;
      return;
     }

   //--- age-based sweep first: dead brackets must go whatever the
   //    drill / expiry-bar rules below would decide
   CleanupStalePendings();
   if(CountOurPendings() == 0)
      return;

   //--- OCO: once one leg fills, the other is cancelled
   int d;
   if(FindPosition(d) != 0)
     {
      DeleteOurPendings("OCO - other leg filled");
      return;
     }

   //--- during drill: keep pendings until the window ends
   if(InpDrillEnable && gDrillStart != 0)
     {
      if(!DrillWindowActive())
        {
         DeleteOurPendings("drill window ended");
         return;
        }
     }
   else
      if(InpPendExpiryBars > 0)
        {
         long maxAge = (long)InpPendExpiryBars * PeriodSeconds();
         for(int i = OrdersTotal() - 1; i >= 0; i--)
           {
            ulong ticket = OrderGetTicket(i);
            if(ticket == 0)
               continue;
            if(!IsOurOrder())
               continue;
            datetime setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
            if((long)(TimeCurrent() - setup) >= maxAge)
               if(trade.OrderDelete(ticket))
                  Print("GsignalX: pending #", ticket, " expired after ",
                        InpPendExpiryBars, " bars");
           }
        }

   //--- cancel if active rules direction turned against the bracket
   if(InpCancelOnFlip && gDataReady && gPendDir != 0 && gN > 1)
     {
      string why = "";
      int active = ActiveDirectionUnderRules(gN - 1, why);
      if(active != 0 && active != gPendDir)
         DeleteOurPendings("signal flipped against the bracket");
     }
  }

bool OpenTrade(int dir)
  {
   string gate = "";
   if(!TradeAllowedNow(gate))
     {
      SignalSkip(gate, true);
      return(false);
     }

   double atr = gAtrRisk[gN - 1];
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = (dir == 1) ? ask : bid;
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   //--- sizing distance: ATR span drives percent-risk lot sizing.
   //    Scouter mode may attach a WIDER catastrophe broker SL; TP = 0.
   double stopDist = 0.0;
   if(atr > 0.0 && (InpUseStop || ScouterOwnsExits()))
      stopDist = InpStopMult * atr;
   double minDist  = MinStopDistance();
   if(stopDist > 0.0 && stopDist < minDist)
      stopDist = minDist;

   double sl = 0.0, tp = 0.0;
   double stratDist = 0.0;
   if(ScouterOwnsExits())
     {
      stratDist = StrategicStopDistance(atr);
      if(stratDist > 0.0)
         sl = (dir == 1) ? price - stratDist : price + stratDist;
     }
   else
     {
      if(stopDist > 0.0 && InpUseStop)
         sl = (dir == 1) ? price - stopDist : price + stopDist;
      if(InpUseTarget && atr > 0.0)
        {
         double tDist = InpTargetMult * atr;
         if(tDist < minDist)
            tDist = minDist;
         tp = (dir == 1) ? price + tDist : price - tDist;
        }
     }

   sl = (sl > 0.0) ? NormalizeDouble(sl, digits) : 0.0;
   tp = (tp > 0.0) ? NormalizeDouble(tp, digits) : 0.0;

   double lot = CalcLot(stopDist);
   if(lot <= 0.0)
     {
      SignalSkip("computed lot is zero", true);
      return(false);
     }

   double margin = 0.0;
   ENUM_ORDER_TYPE otype = (dir == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(OrderCalcMargin(otype, _Symbol, lot, price, margin))
     {
      if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
        {
         SignalSkip("not enough free margin", true);
         return(false);
        }
     }

   trade.SetTypeFillingBySymbol(_Symbol);
   bool ok = (dir == 1)
             ? trade.Buy(lot, _Symbol, 0.0, sl, tp, InpComment)
             : trade.Sell(lot, _Symbol, 0.0, sl, tp, InpComment);

   if(!ok && OrderSendFailedInvalidFill())
     {
      ENUM_ORDER_TYPE_FILLING alts[3] = {ORDER_FILLING_FOK, ORDER_FILLING_IOC, ORDER_FILLING_RETURN};
      for(int a = 0; a < 3 && !ok; a++)
        {
         TrySetFilling(alts[a]);
         ok = (dir == 1)
              ? trade.Buy(lot, _Symbol, 0.0, sl, tp, InpComment)
              : trade.Sell(lot, _Symbol, 0.0, sl, tp, InpComment);
        }
     }

   if(!ok)
     {
      NoteOrderFail("order");
      return(false);
     }

   gFirstEntryDone = true;
   gIntendedLot    = lot;
   gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " " +
                 ((dir == 1) ? "BUY " : "SELL ") + DoubleToString(lot, 2) +
                 " @ " + DoubleToString(price, digits);
   Notify(((dir == 1) ? "LONG " : "SHORT ") + DoubleToString(lot, 2) +
          " lots @ " + DoubleToString(price, digits));
   if(ScouterOwnsExits() && sl > 0.0 && stratDist > 0.0)
      PrintFormat("GsignalX: catastrophe SL attached %.5f (ATR x %.1f = %.5f price dist) — broker may close without Scouter tag",
                  sl, InpStrategicStopMult, stratDist);
   return(true);
  }

void CloseCurrent(string why)
  {
   //--- hard invariant: in Scouter mode the signal engine NEVER closes
   //    a trade - not even one it opened. Profit Scouter owns closes.
   if(ScouterOwnsExits())
     {
      Print("GsignalX: close request '", why, "' BLOCKED - exits are owned by Profit Scouter");
      return;
     }
   int dir;
   ulong ticket = FindPosition(dir);
   if(ticket == 0)
      return;
   if(trade.PositionClose(ticket))
     {
      gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " CLOSE (" + why + ")";
      Notify("closed position: " + why);
     }
   else
      Print("GsignalX: close failed retcode=", trade.ResultRetcode());
  }

void ManageTrailing()
  {
   if(InpTrailMode == GSX_TRAIL_OFF || !gDataReady)
      return;
   //--- trailing only writes stops, so it is an exit path: disabled
   //    while Profit Scouter owns the closes.
   if(ScouterOwnsExits())
      return;

   int dir;
   ulong ticket = FindPosition(dir);
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return;

   double lineVal = (InpTrailMode == GSX_TRAIL_PP) ? gPPline[gN - 1] : gSBTline[gN - 1];
   if(lineVal <= 0.0)
      return;

   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double buffer = InpTrailBufferPt * _Point;
   double curSL  = PositionGetDouble(POSITION_SL);
   double curTP  = PositionGetDouble(POSITION_TP);
   double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minD   = MinStopDistance();
   double newSL  = 0.0;

   if(dir == 1)
     {
      newSL = NormalizeDouble(lineVal - buffer, digits);
      if(newSL >= bid - minD)
         return;
      if(curSL > 0.0 && newSL <= curSL)
         return;
     }
   else
     {
      newSL = NormalizeDouble(lineVal + buffer, digits);
      if(newSL <= ask + minD)
         return;
      if(curSL > 0.0 && newSL >= curSL)
         return;
     }

   trade.PositionModify(ticket, newSL, curTP);
  }

//+------------------------------------------------------------------+
//| Double-fill protection                                           |
//| Both bracket legs point the same way, so a spike that fills both |
//| doubles the intended size rather than hedging it. This trims the |
//| excess back to one unit of risk.                                 |
//+------------------------------------------------------------------+
void ResolveOverfill()
  {
   if(gIntendedLot <= 0.0)
      return;

   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      step = 0.01;

   ulong keep = 0;
   int   n    = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic)
         continue;
      n++;
      if(keep == 0 || ticket < keep)
         keep = ticket;              // keep the earliest fill
     }

   //--- hedging account: close every duplicate position
   if(n > 1)
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic)
            continue;
         if(ticket == keep)
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
         string sym = PositionGetString(POSITION_SYMBOL);
         long magic = PositionGetInteger(POSITION_MAGIC);
         int side = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
         double lots = PositionGetDouble(POSITION_VOLUME);
         double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         double pl = PositionGetDouble(POSITION_PROFIT)
                     + PositionGetDouble(POSITION_SWAP);
         if(trade.PositionClose(ticket))
           {
            Print("GsignalX: duplicate fill closed #", ticket);
            GsxCtEmit(ticket, magic, GSX_CT_TAG_OVERFILL, "chart", pl,
                      sym, side, lots, entry, -1);
           }
        }
      return;
     }

   //--- netting account: one position carrying double the volume
   if(n == 1 && PositionSelectByTicket(keep))
     {
      double vol = PositionGetDouble(POSITION_VOLUME);
      if(vol > gIntendedLot * 1.5)
        {
         double excess = MathFloor((vol - gIntendedLot) / step) * step;
         if(excess >= step)
           {
            string sym = PositionGetString(POSITION_SYMBOL);
            long magic = PositionGetInteger(POSITION_MAGIC);
            int side = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
            double entry = PositionGetDouble(POSITION_PRICE_OPEN);
            double pl = PositionGetDouble(POSITION_PROFIT)
                        + PositionGetDouble(POSITION_SWAP);
            if(trade.PositionClosePartial(keep, excess))
              {
               Print("GsignalX: trimmed overfill by ", DoubleToString(excess, 2), " lots");
               // Partial trim: audit only (position remains)
               GsxCtEmit(keep, magic, GSX_CT_TAG_OVERFILL, "chart", pl,
                         sym, side, excess, entry, -1, false);
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Scalping drill helpers                                           |
//+------------------------------------------------------------------+
int ClampDrillMinutes()
  {
   int m = InpDrillMinutes;
   if(m < 5)  m = 5;
   if(m > 15) m = 15;
   return(m);
  }

bool DrillWindowActive()
  {
   if(!InpDrillEnable || gDrillStart == 0)
      return(false);
   int elapsed = (int)((TimeCurrent() - gDrillStart) / 60);
   return(elapsed < ClampDrillMinutes());
  }

int DrillSecondsLeft()
  {
   if(!DrillWindowActive())
      return(0);
   int total = ClampDrillMinutes() * 60;
   int used  = (int)(TimeCurrent() - gDrillStart);
   int left  = total - used;
   return(left > 0 ? left : 0);
  }

void ClearDrillWindow(const string why)
  {
   if(gDrillStart != 0 && InpVerboseSignals)
      Print("GsignalX: drill cleared (", why, ")");
   gDrillStart  = 0;
   gDrillWanted = 0;
   if(!InpDrillEnable)
      gDrillStatus = "off";
   else
      if(why == "STOP")
         gDrillStatus = "idle";
      else
         gDrillStatus = "expired";
  }

void StartDrillWindow()
  {
   if(!InpDrillEnable)
     {
      gDrillStart  = 0;
      gDrillWanted = 0;
      gDrillStatus = "off";
      return;
     }
   gDrillStart  = TimeCurrent();
   gDrillWanted = 0;
   gDrillStatus = "active " + IntegerToString(ClampDrillMinutes()) + "m";
   if(InpVerboseSignals)
      Print("GsignalX: drill window started for ", ClampDrillMinutes(), " minutes");
  }

void RefreshDrillStatus()
  {
   if(!InpDrillEnable)
     {
      gDrillStatus = "off";
      return;
     }
   if(gDrillStart == 0)
     {
      if(gDrillStatus != "expired")
         gDrillStatus = "idle";
      return;
     }
   if(!DrillWindowActive())
     {
      ClearDrillWindow("window expired");
      return;
     }
   int sec = DrillSecondsLeft();
   gDrillStatus = "ON " + IntegerToString(sec / 60) + "m" +
                  IntegerToString(sec % 60) + "s";
  }

//+------------------------------------------------------------------+
//| Fleet governor — shared Fleet.mqh (chart + service)              |
//| A pair is complete when it has an open position OR at least one  |
//| working pending with our magic. Default target = 4.              |
//+------------------------------------------------------------------+
string FleetLockVarName()
  {
   return(GsxFleetLockVarName(InpMagic));
  }

void FleetFloating(double &pl, int &count)
  {
   GsxFleetFloating(InpMagic, pl, count);
  }

void FleetAddUniqueSymbol(string &syms[], const string s)
  {
   GsxFleetAddUniqueSymbol(syms, s);
  }

int FleetActivePairs()
  {
   return(GsxFleetActivePairs(InpMagic));
  }

bool FleetTryClaim(const datetime now)
  {
   return(GsxFleetTryClaim(InpMagic, InpFleetFillCooldownSec, now));
  }

// Timer entry: if the fleet is short and this pair is idle, claim the
// fill slot and evaluate the entry immediately (joins active direction).
void FleetFillCheck()
  {
   if(!InpFleetEnable || !gTradingEnabled || !gDataReady)
      return;
   // Single owner: defer on-roster when Service OWN (ChartAutoEntriesAllowed).
   // Do not short-circuit on OWN alone — off-roster / !OWN chart independence.
   if(!ChartAutoEntriesAllowed())
      return;

   gFleetActive = FleetActivePairs();

   if(InpFleetRequireDrill && !DrillWindowActive())
      return;
   if(gFleetActive >= InpFleetTargetPairs)
      return;

   int d;
   if(FindPosition(d) != 0)
      return;                        // this pair already live
   if(CountOurPendings() > 0)
      return;                        // this pair already working a bracket

   string why = "";
   if(!IsMarketOpen(why))
      return;
   if(!TimeFilterOK(why) || !SpreadOK(why))
      return;

   //--- only claim the fill slot when there is a direction to join:
   //    the current rules direction, or the latest signal direction
   string activeWhy = "";
   int joinDir = ActiveDirectionUnderRules(gN - 1, activeWhy);
   if(joinDir == 0)
      joinDir = gLastSigDir;
   if(joinDir == 0)
      return;
   if(!AllowNewDirEntry(joinDir))
      return;                        // WAIT: opposite magic exposure still open

   if(!FleetTryClaim(TimeCurrent()))
      return;

   gFleetFills++;
   gMarchOnce = true;
   gNeedSignalEval = true;
   if(InpVerboseSignals)
      Print("GsignalX: fleet fill #", gFleetFills, " on ", _Symbol,
            " - covered pairs ", gFleetActive, "/", InpFleetTargetPairs,
            " (open or pending)");

   string block = "";
   bool hours  = TimeFilterOK(why);
   bool spread = SpreadOK(why);
   TryRunSignalEval(hours, spread, block);
  }

// Active direction under bot entry rules (agreement + MA + enabled triggers).
// Does not require a flip — used for drill follow / post-harvest march.
int ActiveDirectionUnderRules(const int i, string &skipWhy)
  {
   skipWhy = "";
   if(i < 0 || i >= gN)
      return(0);

   bool trigBull = true, trigBear = true;
   bool anyTrig  = false;
   if(InpTrigPP)
     {
      anyTrig = true;
      if(gPPdir[i] != 1)  trigBull = false;
      if(gPPdir[i] != -1) trigBear = false;
     }
   if(InpTrigST)
     {
      anyTrig = true;
      if(gSTdir[i] != 1)  trigBull = false;
      if(gSTdir[i] != -1) trigBear = false;
     }
   if(InpTrigSBT)
     {
      anyTrig = true;
      if(gSBTdir[i] != 1)  trigBull = false;
      if(gSBTdir[i] != -1) trigBear = false;
     }
   if(!anyTrig)
     {
      skipWhy = "no triggers";
      return(0);
     }

   double c  = gClose[i];
   double ma = gMA[i];
   bool maLongOK  = (!InpUseMA || ma <= 0.0 || c > ma);
   bool maShortOK = (!InpUseMA || ma <= 0.0 || c < ma);

   int bull = (gPPdir[i] == 1 ? 1 : 0) + (gSTdir[i] == 1 ? 1 : 0) + (gSBTdir[i] == 1 ? 1 : 0);
   int bear = 3 - bull;
   bool agreeLong  = (InpMode == GSX_SIMPLE) || (bull >= InpMinAgree);
   bool agreeShort = (InpMode == GSX_SIMPLE) || (bear >= InpMinAgree);

   int wanted = 0;
   if(trigBull && maLongOK && agreeLong)
      wanted = 1;
   else
      if(trigBear && maShortOK && agreeShort)
         wanted = -1;

   if(wanted == 0)
     {
      if(trigBull && !maLongOK)       skipWhy = "MA filter";
      else if(trigBear && !maShortOK) skipWhy = "MA filter";
      else if(trigBull && !agreeLong) skipWhy = "engines disagree";
      else if(trigBear && !agreeShort) skipWhy = "engines disagree";
      else                            skipWhy = "no active direction";
     }
   return(wanted);
  }

//+------------------------------------------------------------------+
//| Signal evaluation                                                |
//+------------------------------------------------------------------+
// Returns wanted direction at bar index i: +1 / -1 / 0.
// rawFlip=true when an enabled engine flipped on that bar (for arrow muting).
int SignalWantedAt(const int i, bool &rawFlip, string &skipWhy)
  {
   rawFlip = false;
   skipWhy = "";
   if(i < 1 || i >= gN)
      return(0);

   int prev = i - 1;
   bool ppLong   = (gPPdir[i]  ==  1 && gPPdir[prev]  == -1);
   bool ppShort  = (gPPdir[i]  == -1 && gPPdir[prev]  ==  1);
   bool stLong   = (gSTdir[i]  ==  1 && gSTdir[prev]  == -1);
   bool stShort  = (gSTdir[i]  == -1 && gSTdir[prev]  ==  1);
   bool sbtLong  = (gSBTdir[i] ==  1 && gSBTdir[prev] == -1);
   bool sbtShort = (gSBTdir[i] == -1 && gSBTdir[prev] ==  1);

   bool rawLong  = (InpTrigPP && ppLong)  || (InpTrigST && stLong)  || (InpTrigSBT && sbtLong);
   bool rawShort = (InpTrigPP && ppShort) || (InpTrigST && stShort) || (InpTrigSBT && sbtShort);
   rawFlip = (rawLong || rawShort);

   double c  = gClose[i];
   double ma = gMA[i];
   bool maLongOK  = (!InpUseMA || ma <= 0.0 || c > ma);
   bool maShortOK = (!InpUseMA || ma <= 0.0 || c < ma);

   int bull = (gPPdir[i] == 1 ? 1 : 0) + (gSTdir[i] == 1 ? 1 : 0) + (gSBTdir[i] == 1 ? 1 : 0);
   int bear = 3 - bull;
   bool agreeLong  = (InpMode == GSX_SIMPLE) || (bull >= InpMinAgree);
   bool agreeShort = (InpMode == GSX_SIMPLE) || (bear >= InpMinAgree);

   int wanted = 0;
   if(rawLong && !rawShort && maLongOK && agreeLong)
      wanted = 1;
   else
      if(rawShort && !rawLong && maShortOK && agreeShort)
         wanted = -1;

   if(wanted == 0 && rawFlip)
     {
      if(rawLong && !maLongOK)
         skipWhy = "MA filter";
      else
         if(rawShort && !maShortOK)
            skipWhy = "MA filter";
         else
            if(rawLong && !agreeLong)
               skipWhy = "engines disagree";
            else
               if(rawShort && !agreeShort)
                  skipWhy = "engines disagree";
               else
                  if(rawLong && rawShort)
                     skipWhy = "conflicting flips";
                  else
                     skipWhy = "filters";
     }
   return(wanted);
  }

void EvaluateSignals()
  {
   if(gN < 3)
     {
      SignalSkip("not enough bars");
      return;
     }

   RefreshDrillStatus();

   int last = gN - 1;
   bool rawFlip = false;
   string skipWhy = "";
   int wanted = SignalWantedAt(last, rawFlip, skipWhy);

   //--- join active direction under bot rules (start-current / drill / post-flat march)
   string activeWhy = "";
   int activeDir = ActiveDirectionUnderRules(last, activeWhy);
   bool drillOn = DrillWindowActive();

   if(wanted == 0 && InpStartMode == GSX_START_CURRENT && !gFirstEntryDone)
     {
      wanted = activeDir;
      if(wanted == 0 && activeWhy != "")
         skipWhy = activeWhy;
     }

   bool drillJoin = false;
   // join the active direction for drill follow, post-harvest march or fleet
   // fill - the fleet governor must fill even when the drill is disabled.
   // When a march (fleet fill / post-harvest) finds no direction under the
   // current rules, it joins the LATEST signal direction instead, so the
   // required pairs stay active in the direction the engines last called.
   if(wanted == 0 && (InpDrillEnable || InpFleetEnable) && InpDrillFollowActive && gTradingEnabled)
     {
      if(drillOn || gMarchOnce)
        {
         if(activeDir == 0 && gMarchOnce && gLastSigDir != 0)
           {
            activeDir  = gLastSigDir;
            activeWhy  = "latest signal direction";
           }
         wanted = activeDir;
         drillJoin = (wanted != 0);
         if(wanted == 0 && activeWhy != "")
            skipWhy = activeWhy;
        }
     }

   //--- lock / clear drill direction
   if(drillOn && wanted != 0)
     {
      if(gDrillWanted == 0)
         gDrillWanted = wanted;
      else
         if(wanted != gDrillWanted)
           {
            ClearDrillWindow("signal switched");
            drillOn = false;
            drillJoin = false;
           }
     }

   // Outside drill/march and start-next: suppress join-on-attach until a fresh flip bar
   if(!drillJoin && InpStartMode == GSX_START_NEXT && gBarTime[last] <= gInitBarTime)
     {
      if(rawFlip || wanted != 0)
         SignalSkip("StartMode wait next flip", rawFlip);
      return;
     }

   if(wanted == 0)
     {
      if(rawFlip || drillOn || gMarchOnce)
         SignalSkip((skipWhy == "" ? "no tradable signal" : skipWhy), true);
      gMarchOnce = false;
      return;
     }

   if(wanted == 1 && !InpAllowLong)
     {
      SignalSkip("longs disabled", true);
      gMarchOnce = false;
      return;
     }
   if(wanted == -1 && !InpAllowShort)
     {
      SignalSkip("shorts disabled", true);
      gMarchOnce = false;
      return;
     }

   gLastSigDir = wanted;
   gLastSigIdx = last;
   if(last >= 0 && last < gN && gOpen[last] > 0.0)
      gSignalOpenPx = gOpen[last];

   int curDir;
   ulong ticket = FindPosition(curDir);

   if(ticket != 0)
     {
      gMarchOnce = false;
      if(curDir == wanted)
        {
         SignalSkip("already in position", true);
         return;
        }
      //--- Scouter owns the exits: the signal engine never closes here.
      //    Leave the open trade for Profit Scouter; gLastSigDir is already
      //    updated so FOLLOW flat charts / fleet timer refill the new side.
      if(InpExitMode == GSX_EXIT_SCOUTER)
        {
         if(CountOurPendings() > 0)
            DeleteOurPendings("opposite signal (exit deferred)");
         // FOLLOW: clear fleet cooldown so other flat charts can refill ASAP
         if(!gFlipWaitMode && InpFleetEnable)
            GlobalVariableSet(FleetLockVarName(), 0.0);
         SignalSkip("opposite signal - exit deferred to Profit Scouter", true);
         return;
        }
      if(!InpReverse)
        {
         DeleteOurPendings("opposite signal");
         CloseCurrent("opposite signal");
         SignalSkip("opposite close-only (Reverse off)", true);
         return;
        }
      CloseCurrent("reverse");
     }
   else
     {
      if(drillJoin && !InpDrillAllowReentry && !rawFlip && !gMarchOnce &&
         !(InpStartMode == GSX_START_CURRENT && !gFirstEntryDone))
        {
         SignalSkip("drill re-entry off", true);
         return;
        }
      if(!AllowNewDirEntry(wanted))
        {
         SignalSkip("WAIT: opposite exposure", true);
         gMarchOnce = false;
         return;
        }
     }

   if(CountOurPendings() > 0)
     {
      if(gPendDir == wanted)
        {
         SignalSkip("same-side pending", true);
         gMarchOnce = false;
         return;
        }
      DeleteOurPendings("new opposite signal");
     }

   if(!AllowNewDirEntry(wanted))
     {
      SignalSkip("WAIT: opposite exposure", true);
      gMarchOnce = false;
      return;
     }

   gMarchOnce = false;
   if(!ChartAutoEntriesAllowed())
     {
      SignalSkip("Service owns entries (chart deferred)", true);
      return;
     }
   if(InpSignalMaxAgeSec > 0)
     {
      if(wanted != gSignalEventDir)
        {
         gSignalEventDir = wanted;
         gSignalEventAt  = TimeCurrent();
        }
      if(gSignalEventAt > 0 &&
         (TimeCurrent() - gSignalEventAt) > InpSignalMaxAgeSec)
        {
         SignalSkip("stale signal age", true);
         gSignalEventAt = 0;
         return;
        }
     }
   PlaceEntry(wanted);
  }

bool TryRunSignalEval(const bool hoursOk, const bool spreadOk, string &blockReason)
  {
   blockReason = "";
   if(!gNeedSignalEval || !gDataReady)
      return(false);

   string gate = "";
   if(!TradeAllowedNow(gate))
     {
      blockReason = gate;
      return(false);
     }
   if(!hoursOk)
     {
      blockReason = "hours/Friday filter";
      return(false);
     }
   if(!spreadOk)
     {
      blockReason = "spread";
      return(false);
     }

   EvaluateSignals();
   gNeedSignalEval = false;
   return(true);
  }

//+------------------------------------------------------------------+
//| Chart objects - panel, buttons, arrows, levels                   |
//+------------------------------------------------------------------+
string DirText(int d) { return(d == 1 ? "BULL" : "BEAR"); }
color  DirColor(int d) { return(d == 1 ? InpColBull : InpColBear); }

void SetRect(string tag, int x, int y, int w, int h, color bg, color edge, bool selectable = false)
  {
   GsxPanelConfigure(gPfx, InpCorner, InpFont, InpFontSize, InpColPanelEdge);
   GsxPanelRect(tag, x, y, w, h, bg, edge, selectable);
  }

void SetLabel(string tag, int x, int y, string text, color clr, int size, bool bold)
  {
   GsxPanelConfigure(gPfx, InpCorner, InpFont, InpFontSize, InpColPanelEdge);
   GsxPanelLabel(tag, x, y, text, clr, size, bold);
  }

void SetButton(string tag, int x, int y, int w, int h, string text, color bg, color fg)
  {
   GsxPanelConfigure(gPfx, InpCorner, InpFont, InpFontSize, InpColPanelEdge);
   GsxPanelButton(tag, x, y, w, h, text, bg, fg);
  }

void DeleteOurObjects()
  {
   GsxPanelConfigure(gPfx, InpCorner, InpFont, InpFontSize, InpColPanelEdge);
   GsxPanelDeleteAll();
  }

string GsxPanelPosXVar()
  {
   return(StringFormat("GSX_PNLX_%I64d", ChartID()));
  }

string GsxPanelPosYVar()
  {
   return(StringFormat("GSX_PNLY_%I64d", ChartID()));
  }

void GsxLoadPanelPos()
  {
   g_panelX = InpPanelX;
   g_panelY = InpPanelY;
   string nx = GsxPanelPosXVar();
   string ny = GsxPanelPosYVar();
   if(GlobalVariableCheck(nx))
      g_panelX = (int)GlobalVariableGet(nx);
   if(GlobalVariableCheck(ny))
      g_panelY = (int)GlobalVariableGet(ny);
   if(g_panelX < 0) g_panelX = 0;
   if(g_panelY < 0) g_panelY = 0;
  }

void GsxSavePanelPos()
  {
   GlobalVariableSet(GsxPanelPosXVar(), (double)g_panelX);
   GlobalVariableSet(GsxPanelPosYVar(), (double)g_panelY);
  }

bool GsxPanelHitTitle(const int mx, const int my)
  {
   if(!InpShowPanel)
      return(false);
   int inset = GsxSx(8);
   int left = g_panelX - inset;
   int top  = g_panelY - inset;
   int ww = g_panelW + 2 * inset;
   if(mx < left || mx > left + ww)
      return(false);
   if(my < top || my > top + g_panelTitleH)
      return(false);
   return(true);
  }

//--- price levels: engine lines and the live trade
void DrawLevels()
  {
   string names[6] = {"LV_PP", "LV_SBT", "LV_ENTRY", "LV_SL", "LV_TP", "LV_MA"};
   if(!InpShowLevels || !gDataReady)
     {
      for(int i = 0; i < 6; i++)
         ObjectDelete(0, gPfx + names[i]);
      return;
     }

   int last = gN - 1;

   double vals[6];
   color  cols[6];
   string txts[6];
   vals[0] = gPPline[last];   cols[0] = DirColor(gPPdir[last]);   txts[0] = "PP";
   vals[1] = gSBTline[last];  cols[1] = DirColor(gSBTdir[last]);  txts[1] = "SBT";
   vals[5] = gMA[last];       cols[5] = InpColNeutral;            txts[5] = "MA";

   int dir;
   ulong ticket = FindPosition(dir);
   if(ticket != 0 && PositionSelectByTicket(ticket))
     {
      vals[2] = PositionGetDouble(POSITION_PRICE_OPEN); cols[2] = InpColAccent; txts[2] = "ENTRY";
      vals[3] = PositionGetDouble(POSITION_SL);         cols[3] = InpColBear;   txts[3] = "SL";
      vals[4] = PositionGetDouble(POSITION_TP);         cols[4] = InpColBull;   txts[4] = "TP";
     }
   else
     {
      vals[2] = 0.0; vals[3] = 0.0; vals[4] = 0.0;
     }

   for(int i = 0; i < 6; i++)
     {
      string n = gPfx + names[i];
      if(vals[i] <= 0.0)
        {
         ObjectDelete(0, n);
         continue;
        }
      if(ObjectFind(0, n) < 0)
        {
         ObjectCreate(0, n, OBJ_HLINE, 0, 0, vals[i]);
         ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, n, OBJPROP_BACK, true);
        }
      ObjectSetDouble(0, n, OBJPROP_PRICE, vals[i]);
      ObjectSetInteger(0, n, OBJPROP_COLOR, cols[i]);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, (i >= 2 && i <= 4) ? 1 : 2);
      ObjectSetInteger(0, n, OBJPROP_STYLE, (i >= 2 && i <= 4) ? STYLE_DASH : STYLE_DOT);
      ObjectSetString(0, n, OBJPROP_TEXT, "GsignalX " + txts[i]);
     }
  }

//--- arrows: bright = trade-quality; muted = raw flip filtered out
void DrawArrows()
  {
   if(!InpShowArrows || !gDataReady)
      return;

   int first = gN - InpArrowBars;
   if(first < 1)
      first = 1;

   for(int i = first; i < gN; i++)
     {
      bool rawFlip = false;
      string skipWhy = "";
      int wanted = SignalWantedAt(i, rawFlip, skipWhy);
      if(!rawFlip && wanted == 0)
         continue;

      bool up = (wanted == 1) || (wanted == 0 &&
                ((InpTrigPP  && gPPdir[i]  ==  1 && gPPdir[i - 1]  == -1) ||
                 (InpTrigST  && gSTdir[i]  ==  1 && gSTdir[i - 1]  == -1) ||
                 (InpTrigSBT && gSBTdir[i] ==  1 && gSBTdir[i - 1] == -1)));
      bool dw = (wanted == -1) || (wanted == 0 &&
                ((InpTrigPP  && gPPdir[i]  == -1 && gPPdir[i - 1]  ==  1) ||
                 (InpTrigST  && gSTdir[i]  == -1 && gSTdir[i - 1]  ==  1) ||
                 (InpTrigSBT && gSBTdir[i] == -1 && gSBTdir[i - 1] ==  1)));
      if(!up && !dw)
         continue;

      bool tradable = (wanted != 0);
      color arrowCol = tradable ? (up ? InpColBull : InpColBear) : InpColNeutral;
      int   width    = tradable ? 2 : 1;

      string n = gPfx + "AR_" + IntegerToString((int)gBarTime[i]);
      if(ObjectFind(0, n) < 0)
        {
         double pad   = (gHigh[i] - gLow[i]) * 0.6 + _Point * 10;
         double price = up ? gLow[i] - pad : gHigh[i] + pad;
         ObjectCreate(0, n, OBJ_ARROW, 0, gBarTime[i], price);
         ObjectSetInteger(0, n, OBJPROP_ARROWCODE, up ? 233 : 234);
         ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, n, OBJPROP_ANCHOR, up ? ANCHOR_TOP : ANCHOR_BOTTOM);

         int bull = (gPPdir[i] == 1 ? 1 : 0) + (gSTdir[i] == 1 ? 1 : 0) + (gSBTdir[i] == 1 ? 1 : 0);
         string tn = gPfx + "AT_" + IntegerToString((int)gBarTime[i]);
         ObjectCreate(0, tn, OBJ_TEXT, 0, gBarTime[i], price);
         ObjectSetString(0, tn, OBJPROP_TEXT,
                         (up ? "BUY " : "SELL ") + IntegerToString(up ? bull : 3 - bull) + "/3" +
                         (tradable ? "" : " ~"));
         ObjectSetInteger(0, tn, OBJPROP_FONTSIZE, tradable ? 7 : 6);
         ObjectSetString(0, tn, OBJPROP_FONT, InpFont);
         ObjectSetInteger(0, tn, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, tn, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, tn, OBJPROP_ANCHOR, up ? ANCHOR_UPPER : ANCHOR_LOWER);
         ObjectSetInteger(0, tn, OBJPROP_COLOR, arrowCol);
        }

      ObjectSetInteger(0, n, OBJPROP_COLOR, arrowCol);
      ObjectSetInteger(0, n, OBJPROP_WIDTH, width);
      string tn2 = gPfx + "AT_" + IntegerToString((int)gBarTime[i]);
      if(ObjectFind(0, tn2) >= 0)
         ObjectSetInteger(0, tn2, OBJPROP_COLOR, arrowCol);
     }
  }

//--- seconds left on the forming bar
string BarCountdown()
  {
   long left = (long)(iTime(_Symbol, _Period, 0) + PeriodSeconds() - TimeCurrent());
   if(left < 0)
      left = 0;
   return(StringFormat("%02d:%02d", (int)(left / 60), (int)(left % 60)));
  }

//+------------------------------------------------------------------+
//| Panel                                                            |
//+------------------------------------------------------------------+
void UpdatePanel(string tradeState)
  {
   g_lastPanelState = tradeState;

   if(!InpShowPanel)
     {
      DeleteOurObjects();
      return;
     }

   const bool compact = (InpPanelDensity == GSX_PANEL_COMPACT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double effScale = GsxPanelFitScale(InpUiScale, 520, 24);
   GsxPanelSetScale(effScale);
   GsxPanelSetVision((int)InpUiVision);
   GsxMsPanelSetUiScale(InpUiScale);
   GsxMsPanelSetVision((int)InpUiVision);

   int x = g_panelX;
   int y = g_panelY;
   g_panelW = GsxSx(520);
   GsxPanelClampPos(g_panelX, g_panelY, g_panelW, GsxSx(280));
   x = g_panelX;
   y = g_panelY;

   GsxPanelConfigure(gPfx, InpCorner, InpFont, InpFontSize, InpColPanelEdge);
   GsxPanelBegin(x, y, g_panelW, InpFontSize, GsxPanelTitleHDesign(InpFontSize + 12));
   g_panelTitleH = g_gsxPnlTitleH;

   //--- Chrome BEFORE body rows so RECTANGLE_LABEL BG cannot cover text
   // 3 button rows need real height after UI scale (avoid roster overlap)
   int btnH = (InpShowButtons ? GsxSx(128) : GsxSx(12));
   int estRows = compact ? 16 : 26;
   if(InpBusEnable)
      estRows++;
   int estH = g_panelTitleH + estRows * g_gsxPnlRh + btnH;
   string densHint = compact
                     ? (InpUiVision == GSX_VISION_FAR ? "Comfort desk · drag" : "Compact · drag title")
                     : (InpUiVision == GSX_VISION_NEAR ? "Full · near view" : "Full · drag title");
   GsxPanelApplyChrome(estH, InpColPanelBg, InpColPanelEdge, C'36,42,54',
                       InpColAccent, InpColNeutral, "GsignalX", densHint);

   bool marketOpen = (StringFind(tradeState, "OPEN") == 0);

   //--- Status (surface waiting / block reason for investors)
   color runCol = !gTradingEnabled ? InpColBear : (marketOpen ? InpColBull : InpColNeutral);
   string runTxt = !gTradingEnabled ? "STOPPED" : (marketOpen ? "RUNNING" : "IDLE");
   if(gTradingEnabled && gPanelBlockReason != "")
     {
      runTxt = "WAIT: " + gPanelBlockReason;
      runCol = InpColAccent;
     }
   GsxPanelRow("Status", runTxt, InpColNeutral, runCol, true);

   //--- Scout link (read-only; PLAY/HALT write PS#_RUN)
   bool scoutOn = true;
   if(InpScoutLinkEnable)
     {
      string sn = StringFormat("PS%d_RUN", InpScoutInstanceID);
      if(GlobalVariableCheck(sn))
         scoutOn = (GlobalVariableGet(sn) > 0.5);
     }
   else
      scoutOn = false;
   GsxPanelRow("Scout",
               (!InpScoutLinkEnable ? "unlink" : (scoutOn ? "ON" : "OFF")),
               InpColNeutral,
               (!InpScoutLinkEnable ? InpColNeutral : (scoutOn ? InpColBull : InpColBear)),
               true);

   GsxPanelRow("Symbol / TF",
               _Symbol + "  " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period), 7),
               InpColNeutral, InpColText, false);

   //--- Account DD
   {
      double liveDd = GsxAccountDrawdownPct();
      string guardTxt = (gMaxDailyDrawdownPct <= 0.0)
                        ? "OFF"
                        : (DoubleToString(gMaxDailyDrawdownPct, 0) + "%");
      string ddTxt = DoubleToString(liveDd, 1) + "% / " + guardTxt;
      color  ddCol = InpColNeutral;
      if(gMaxDailyDrawdownPct > 0.0)
         ddCol = (liveDd >= gMaxDailyDrawdownPct) ? InpColBear : InpColAccent;
      GsxPanelRow("Account DD", ddTxt, InpColNeutral, ddCol, false);
   }

   //--- Session P/L + win%
   {
      double winPct = 0.0;
      if(gClosedCount > 0)
         winPct = 100.0 * (double)gClosedWins / (double)gClosedCount;
      string ses = DoubleToString(gClosedRealized, 2) +
                   "  " + IntegerToString(gClosedWins) + "W/" +
                   IntegerToString(gClosedLosses) + "L  " +
                   DoubleToString(winPct, 0) + "%";
      color sesCol = (gClosedRealized > 0.0 ? InpColBull :
                      (gClosedRealized < 0.0 ? InpColBear : InpColNeutral));
      GsxPanelRow("Session", ses, InpColNeutral, sesCol, false);
   }

   //--- Fleet float
   {
      double fleetPL = 0.0;
      int    fleetPos = 0;
      FleetFloating(fleetPL, fleetPos);
      int fleetN = (InpFleetEnable ? FleetActivePairs() : 0);
      string fleetTxt = InpFleetEnable
                        ? (IntegerToString(fleetN) + "/" + IntegerToString(InpFleetTargetPairs) +
                           "  " + DoubleToString(fleetPL, 2))
                        : ("off  " + DoubleToString(fleetPL, 2));
      color fleetCol = (fleetPos > 0
                        ? (fleetPL >= 0.0 ? InpColBull : InpColBear)
                        : InpColText);
      GsxPanelRow("Fleet P/L", fleetTxt, InpColNeutral, fleetCol, true);
   }

   //--- Open position / outcome
   int dir = 0;
   ulong ticket = FindPosition(dir);
   double pip = PipSize();
   if(ticket != 0 && PositionSelectByTicket(ticket))
     {
      double vol   = PositionGetDouble(POSITION_VOLUME);
      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      double prof  = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double moved = (dir == 1) ? (bid - open) : (open - ask);
      string rTxt = "R n/a";
      string slPipTxt = "";
      if(sl > 0.0)
        {
         double riskDist = MathAbs(open - sl);
         if(riskDist > 0.0)
            rTxt = DoubleToString(moved / riskDist, 2) + "R";
         double toSl = (dir == 1) ? (bid - sl) : (sl - ask);
         slPipTxt = "  SL " + DoubleToString(toSl / pip, 1) + "p";
        }
      GsxPanelRow("Position",
                  (dir == 1 ? "LONG " : "SHORT ") + DoubleToString(vol, 2) +
                  "  " + rTxt + slPipTxt + "  " + DoubleToString(prof, 2),
                  InpColNeutral, DirColor(dir), true);
      if(!compact)
        {
         string slTxt = (sl > 0.0) ? DoubleToString(sl, digits) : "none";
         string tpTxt = (tp > 0.0) ? DoubleToString(tp, digits) : "open";
         GsxPanelRow("SL / TP", slTxt + "  /  " + tpTxt, InpColNeutral, InpColText, false);
        }
     }
   else
      GsxPanelRow("Position", "flat", InpColNeutral, InpColNeutral, false);

   //--- Next lot / risk $ / daily (always preview for outcome clarity)
   {
      double atr = (gDataReady && gN > 0) ? gAtrRisk[gN - 1] : 0.0;
      double stopDist = (atr > 0.0) ? (InpStopMult * atr) : 0.0;
      double nextLot = CalcLot(stopDist);
      if(ticket != 0 && gIntendedLot > 0.0)
         nextLot = gIntendedLot;
      double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPct / 100.0;
      string dailyCap = (InpMaxDailyPositions > 0)
                        ? IntegerToString(InpMaxDailyPositions)
                        : "inf";
      string riskTxt = DoubleToString(nextLot, 2) + " lot";
      if(gAutoLot && InpRiskMode == GSX_RISK_PCT)
         riskTxt += "  ~" + DoubleToString(riskMoney, 2);
      else
         riskTxt += "  fixed";
      riskTxt += "  day " + IntegerToString(gDailyPositionsOpened) + "/" + dailyCap;
      GsxPanelRow("Next risk", riskTxt, InpColNeutral,
                  gAutoLot ? InpColBull : InpColText, false);
   }

   //--- Last signal
   {
      string sigTxt = "none yet";
      color  sigCol = InpColNeutral;
      if(gLastSigIdx >= 0 && gDataReady)
        {
         int ago = (gN - 1) - gLastSigIdx;
         sigTxt = (gLastSigDir == 1 ? "BUY" : "SELL") + "  " +
                  TimeToString(gBarTime[gLastSigIdx], TIME_MINUTES) +
                  "  (" + IntegerToString(ago) + " bars)";
         sigCol = DirColor(gLastSigDir);
        }
      GsxPanelRow("Last signal", sigTxt, InpColNeutral, sigCol, false);
   }

   //--- Engines: Full = detail + meter; Compact = one-liner only on Full path skip
   if(!compact)
     {
      if(gDataReady && gN > 1)
        {
         int last = gN - 1;
         int bull = (gPPdir[last] == 1 ? 1 : 0) + (gSTdir[last] == 1 ? 1 : 0) +
                    (gSBTdir[last] == 1 ? 1 : 0);
         string meter = "";
         int agree = MathMax(bull, 3 - bull);
         for(int i = 0; i < 3; i++)
            meter += (i < agree) ? CharToString(110) : CharToString(111);

         GsxPanelRow("PP SuperTrend",
                     DirText(gPPdir[last]) + (InpTrigPP ? "  *" : ""),
                     InpColNeutral, DirColor(gPPdir[last]), true);
         GsxPanelRow("ATR SuperTrend",
                     DirText(gSTdir[last]) + (InpTrigST ? "  *" : ""),
                     InpColNeutral, DirColor(gSTdir[last]), true);
         GsxPanelRow("SuperBollinger",
                     DirText(gSBTdir[last]) + (InpTrigSBT ? "  *" : ""),
                     InpColNeutral, DirColor(gSBTdir[last]), true);
         GsxPanelRow("Agreement",
                     IntegerToString(agree) + "/3  " + meter + "  " +
                     (bull >= 2 ? "BULL" : "BEAR"),
                     InpColNeutral, (bull >= 2 ? InpColBull : InpColBear), true);
        }
      else
         GsxPanelRow("Engines", gStatus, InpColNeutral, InpColNeutral, false);
     }
   else
      if(gDataReady && gN > 1)
        {
         int last = gN - 1;
         int bull = (gPPdir[last] == 1 ? 1 : 0) + (gSTdir[last] == 1 ? 1 : 0) +
                    (gSBTdir[last] == 1 ? 1 : 0);
         string eng = "PP " + DirText(gPPdir[last]) +
                      " · ST " + DirText(gSTdir[last]) +
                      " · SB " + DirText(gSBTdir[last]) +
                      " · " + IntegerToString(MathMax(bull, 3 - bull)) + "/3";
         GsxPanelRow("Engines", eng, InpColNeutral,
                     (bull >= 2 ? InpColBull : InpColBear), false);
        }

   //--- Market + spread
   GsxPanelRow("Market", tradeState, InpColNeutral,
               marketOpen ? InpColBull : InpColBear, false);
   GsxPanelRow("Spread / bar",
               IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)) + " pts" +
               (gIgnoreSpread ? " IGN" : "") +
               (gAutoLot ? " AUTO" : " FIX") + "  " + BarCountdown(),
               InpColNeutral,
               gIgnoreSpread ? InpColAccent : InpColText, false);

   if(!compact)
     {
      RefreshDrillStatus();
      color drillCol = InpColNeutral;
      if(DrillWindowActive())
         drillCol = InpColBull;
      else
         if(gDrillStatus == "expired")
            drillCol = InpColBear;
      GsxPanelRow("Drill",
                  (!InpDrillEnable ? "off" : gDrillStatus),
                  InpColNeutral, drillCol, true);

      GsxPanelRow("Mode",
                  (InpMode == GSX_SIMPLE ? "Simple" :
                   "Advanced " + IntegerToString(InpMinAgree) + "/3"),
                  InpColNeutral, InpColText, false);

      int pend = CountOurPendings();
      string entryTxt = "market";
      if(InpEntryMode == GSX_ENTRY_LIMIT)
         entryTxt = "limit " + IntegerToString(ClampOffset(InpLimitOffset));
      if(InpEntryMode == GSX_ENTRY_STOP)
         entryTxt = "stop " + IntegerToString(ClampOffset(InpStopOffset));
      if(InpEntryMode == GSX_ENTRY_BOTH)
         entryTxt = "L" + IntegerToString(ClampOffset(InpLimitOffset)) +
                    "/S" + IntegerToString(ClampOffset(InpStopOffset));
      string unitTxt = (InpEntryMode == GSX_ENTRY_MARKET ? "" :
                        (InpOffsetUnit == GSX_UNIT_PIPS ? "p" : "pt"));
      string anchorTxt = "";
      if(InpEntryMode != GSX_ENTRY_MARKET && gSignalOpenPx > 0.0)
         anchorTxt = " @" + DoubleToString(gSignalOpenPx, digits);
      GsxPanelRow("Entry orders", entryTxt + unitTxt + anchorTxt,
                  InpColNeutral, InpColText, false);
      GsxPanelRow("Working",
                  pend == 0 ? "none"
                            : IntegerToString(pend) + " pending " +
                              (gPendDir == 1 ? "BUY" : "SELL"),
                  InpColNeutral,
                  pend == 0 ? InpColNeutral : DirColor(gPendDir), false);

      GsxPanelRowSmall("Last action", gLastAction, InpColNeutral, InpColText);
      GsxPanelRow("Flip fill",
                  gFlipWaitMode ? "WAIT (clear opposite)" : "FOLLOW (fill new dir)",
                  InpColNeutral,
                  gFlipWaitMode ? InpColAccent : InpColBull, true);
      GsxPanelRow("Exit owner",
                  (InpExitMode == GSX_EXIT_SCOUTER ? "scout" : "signal"),
                  InpColNeutral, InpColText, false);
     }

   if(InpBusEnable)
      GsxPanelRowSmall("Opp grades", gBusGradeLine, InpColNeutral, InpColAccent);

   GsxPanelTrimBody();

   //--- shrink/grow BG to actual body height (size only — do not recreate BG)
   int totalH = g_panelTitleH + GsxPanelRowCount() * g_gsxPnlRh + btnH;
   GsxPanelResizeBg(totalH);
   g_panelLastH = totalH;

   if(InpShowButtons)
     {
      int by = GsxPanelButtonsY();
      // Floor height so scaled UI never crushes glyphs
      int bh = MathMax(22, GsxSf(InpFontSize + 2) + GsxSp(12));
      int bpad = 1;
      int gap = MathMax(4, GsxSp(6));
      color chipIdle = C'32,38,50';
      GsxLayCtx blay;
      GsxLayBegin(blay, x, by, g_panelW, gap, gap);
      GsxLaySlot bslots[];

      GsxLayRowStart(blay, bh);
      GsxLayEqual(blay, 4, bslots);
      if(ArraySize(bslots) >= 4)
        {
         GsxPanelSlotButtonPad("BTN_RUN", bslots[0], "PLAY",
                               gTradingEnabled ? InpColBull : chipIdle,
                               gTradingEnabled ? InpColPanelBg : InpColText, bpad);
         GsxPanelSlotButtonPad("BTN_STOP", bslots[1], "STOP",
                               gTradingEnabled ? chipIdle : InpColBear,
                               gTradingEnabled ? InpColText : InpColPanelBg, bpad);
         GsxPanelSlotButtonPad("BTN_FLAT", bslots[2], "HALT",
                               chipIdle, InpColAccent, bpad);
         GsxPanelSlotButtonPad("BTN_FLIP", bslots[3],
                               gFlipWaitMode ? "WAIT" : "FOLLOW",
                               gFlipWaitMode ? InpColAccent : InpColBull,
                               InpColPanelBg, bpad);
        }
      GsxLayAdvance(blay, bh);

      int followDir = GsxRosterFollowDirGet(InpMagic, _Symbol, GSX_FOLLOW_AUTO);
      GsxLayRowStart(blay, bh);
      GsxLayEqual(blay, 4, bslots);
      if(ArraySize(bslots) >= 4)
        {
         GsxPanelSlotButtonPad("BTN_FDIR_AUTO", bslots[0], "FOLLOW",
                               followDir == GSX_FOLLOW_AUTO ? InpColBull : chipIdle,
                               followDir == GSX_FOLLOW_AUTO ? InpColPanelBg : InpColText, bpad);
         GsxPanelSlotButtonPad("BTN_FDIR_BUY", bslots[1], "BUY",
                               followDir == GSX_FOLLOW_BUY ? InpColBull : chipIdle,
                               followDir == GSX_FOLLOW_BUY ? InpColPanelBg : InpColText, bpad);
         GsxPanelSlotButtonPad("BTN_FDIR_SELL", bslots[2], "SELL",
                               followDir == GSX_FOLLOW_SELL ? InpColBear : chipIdle,
                               followDir == GSX_FOLLOW_SELL ? InpColPanelBg : InpColText, bpad);
         GsxPanelSlotButtonPad("BTN_FDIR_WAIT", bslots[3], "WAIT",
                               followDir == GSX_FOLLOW_WAIT ? InpColNeutral : chipIdle,
                               followDir == GSX_FOLLOW_WAIT ? InpColPanelBg : InpColText, bpad);
        }
      GsxLayAdvance(blay, bh);

      GsxLayRowStart(blay, bh);
      GsxLayEqual(blay, 3, bslots);
      if(ArraySize(bslots) >= 3)
        {
         GsxPanelSlotButtonPad("BTN_SPREAD", bslots[0],
                               gIgnoreSpread ? "IGN" : "SPREAD",
                               gIgnoreSpread ? InpColAccent : chipIdle,
                               gIgnoreSpread ? InpColPanelBg : InpColText, bpad);
         GsxPanelSlotButtonPad("BTN_AUTOLOT", bslots[1],
                               gAutoLot ? "AUTOLOT" : "FIXED",
                               gAutoLot ? InpColBull : chipIdle,
                               gAutoLot ? InpColPanelBg : InpColText, bpad);
         bool eqOn = (gMaxDailyDrawdownPct > 0.0);
         string eqLbl = eqOn ? StringFormat("EQ %.0f%%", gMaxDailyDrawdownPct) : "EQ OFF";
         GsxPanelSlotButtonPad("BTN_EQGUARD", bslots[2], eqLbl,
                               eqOn ? InpColAccent : chipIdle,
                               eqOn ? InpColPanelBg : InpColText, bpad);
        }

      // Grow panel to real button stack (fixes black gap / roster collision)
      int stackH = GsxLayMeasuredH(blay) + GsxSx(8);
      int needH = g_panelTitleH + GsxPanelRowCount() * g_gsxPnlRh + stackH;
      if(needH > g_panelLastH)
        {
         GsxPanelResizeBg(needH);
         g_panelLastH = needH;
        }
     }

   //--- chart art: skip while dragging; arrows only when marked dirty
   if(!g_panelDragging)
     {
      if(gUiNeedChartArt || ticket != 0)
         DrawLevels();
      if(gUiNeedChartArt)
        {
         DrawArrows();
         gUiNeedChartArt = false;
        }
     }

   //--- v1.24 compact multisymbol roster strip (shared GSXMS_ panel)
   GsxChartDrawRosterStrip();

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Compact roster strip under the signal panel                      |
//+------------------------------------------------------------------+
bool GsxChartRosterStripEnabled()
  {
   if(!InpShowRosterStrip)
      return(false);
   // Prefer showing when Service owns OR a roster file already exists.
   if(ChartServiceOwnsFleet())
      return(true);
   return(GsxRosterStoreExists(InpMagic));
  }

void GsxChartDrawRosterStrip()
  {
   if(!GsxChartRosterStripEnabled())
     {
      // leave any prior strip alone if disabled mid-session — avoid wipe of Dashboard on same chart
      return;
     }

   GsxMsSnapshot snap;
   GsxMsBuildSnapshot(InpMagic, InpFleetTargetPairs, InpRosterStripPageSize, snap);
   GsxMsSnapshotApplyScout(snap, InpScoutLinkEnable, InpScoutInstanceID);
   g_msPage = snap.page;
   g_msDefaultFleet = InpFleetTargetPairs;
   g_msShowButtons = true;
   int ay = g_panelY + g_panelLastH + GsxSx(14);
   GsxMsPanelDrawCompact(snap, g_panelX, ay);

   // restore ChartPanel prefix for next signal panel paint
   GsxPanelConfigure(gPfx, InpCorner, InpFont, InpFontSize, InpColPanelEdge);
  }

//+------------------------------------------------------------------+
//| PLAY / STOP control                                              |
//| STOP pauses the entry engine only - it NEVER closes positions.  |
//| Closes are owned by Profit Scouter (see InpExitMode).            |
//+------------------------------------------------------------------+
string RunStateVarName()
  {
   return("GSX_RUN_" + _Symbol + "_" + IntegerToString((int)InpMagic));
  }

string FlipWaitVarName()
  {
   return("GSX_FLIPWAIT_" + _Symbol + "_" + IntegerToString((int)InpMagic));
  }

string SpreadIgnVarName()
  {
   return("GSX_SPREADIGN_" + _Symbol + "_" + IntegerToString((int)InpMagic));
  }

string AutoLotVarName()
  {
   return("GSX_AUTOLOT_" + _Symbol + "_" + IntegerToString((int)InpMagic));
  }

string EquityGuardVarName()
  {
   return("GSX_EQGUARD_" + _Symbol + "_" + IntegerToString((int)InpMagic));
  }

void LoadFlipWaitMode()
  {
   string n = FlipWaitVarName();
   if(GlobalVariableCheck(n))
     {
      gFlipWaitMode = (GlobalVariableGet(n) > 0.5);
      return;
     }
   gFlipWaitMode = InpFlipWaitDefault;
   GlobalVariableSet(n, gFlipWaitMode ? 1.0 : 0.0);
  }

void LoadIgnoreSpread()
  {
   string n = SpreadIgnVarName();
   if(GlobalVariableCheck(n))
     {
      gIgnoreSpread = (GlobalVariableGet(n) > 0.5);
      return;
     }
   gIgnoreSpread = InpIgnoreSpreadDefault;
   GlobalVariableSet(n, gIgnoreSpread ? 1.0 : 0.0);
  }

void LoadAutoLot()
  {
   // v2.14: desk GSX_MS_AUTOLOT_ is source of truth; migrate legacy per-symbol once
   string legacy = AutoLotVarName();
   if(!GlobalVariableCheck(GsxRosterAutoLotVarName(InpMagic)))
     {
      if(GlobalVariableCheck(legacy))
         GsxRosterAutoLotSet(InpMagic, GlobalVariableGet(legacy) > 0.5);
      else
         GsxRosterAutoLotSeed(InpMagic, InpAutoLotDefault);
     }
   gAutoLot = GsxRosterAutoLotGet(InpMagic, InpAutoLotDefault);
   GlobalVariableSet(legacy, gAutoLot ? 1.0 : 0.0);
  }

void LoadEquityGuard()
  {
   // v2.14: bridge to desk EQ pads (0/5/10/20)
   string legacy = EquityGuardVarName();
   if(!GlobalVariableCheck(GsxRosterEqGuardVarName(InpMagic)))
     {
      if(GlobalVariableCheck(legacy))
         GsxRosterEqGuardSet(InpMagic, GlobalVariableGet(legacy));
      else
         GsxRosterEqGuardSeed(InpMagic, InpMaxDailyDrawdownPct);
     }
   gMaxDailyDrawdownPct = GsxRosterEqGuardGet(InpMagic, 0.0);
   GlobalVariableSet(legacy, gMaxDailyDrawdownPct);
  }

void SetFlipWaitMode(const bool waitMode, const bool announce)
  {
   gFlipWaitMode = waitMode;
   GlobalVariableSet(FlipWaitVarName(), waitMode ? 1.0 : 0.0);
   if(announce)
     {
      gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                    (waitMode ? " WAIT - new dir after opposite cleared"
                              : " FOLLOW - fill new dir on free charts");
      Notify(waitMode ? "WAIT: new-direction entries blocked while opposite magic positions exist"
                      : "FOLLOW: flat charts / fleet fill the latest signal direction");
     }
   UpdatePanel(g_lastPanelState);
   GsxUiMarkDirty();
  }

void SetIgnoreSpread(const bool on, const bool announce)
  {
   gIgnoreSpread = on;
   GlobalVariableSet(SpreadIgnVarName(), on ? 1.0 : 0.0);

   //--- IGN mid-block: re-arm so a chart stuck on "waiting: spread" can fill now
   if(on && gTradingEnabled)
     {
      gNeedSignalEval = true;
      string reason = "";
      bool hours = TimeFilterOK(reason);
      bool spread = SpreadOK(reason);
      if(CalcEngines())
        {
         string block = "";
         if(!TryRunSignalEval(hours, spread, block) && block != "" && InpVerboseSignals)
            Print("GsignalX: IGN armed, waiting: ", block);
        }
     }

   if(announce)
     {
      gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                    (on ? " IGN - spread gate off"
                        : " SPREAD - limit " + IntegerToString(InpMaxSpreadPt) + " pt");
      Notify(on ? "IGN: entries ignore max-spread gate (wider fills allowed)"
                : "SPREAD: entries respect max-spread limit again");
     }
   gPanelBlockReason = "";
   GsxUiMarkDirty();
   UpdatePanel(g_lastPanelState);
  }

void SetAutoLot(const bool on, const bool announce)
  {
   gAutoLot = on;
   GsxRosterAutoLotSet(InpMagic, on);
   GlobalVariableSet(AutoLotVarName(), on ? 1.0 : 0.0);
   if(announce)
     {
      gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                    (on ? " AUTOLOT - risk% sizing"
                        : " FIXED - lot " + DoubleToString(InpFixedLot, 2));
      Notify(on ? "AUTOLOT: entries sized by risk% / stop distance"
                : "FIXED: entries use fixed lot " + DoubleToString(InpFixedLot, 2));
     }
   GsxUiMarkDirty();
   UpdatePanel(g_lastPanelState);
  }

void SetEquityGuardPct(const double pct, const bool announce)
  {
   GsxRosterEqGuardSet(InpMagic, pct);
   gMaxDailyDrawdownPct = GsxRosterEqGuardGet(InpMagic, 0.0);
   GlobalVariableSet(EquityGuardVarName(), gMaxDailyDrawdownPct);
   if(announce)
     {
      if(gMaxDailyDrawdownPct <= 0.0)
        {
         gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " EQ OFF - equity guard off";
         Notify("EQ OFF: equity drawdown guard disabled for new entries");
        }
      else
        {
         gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                       " EQ " + DoubleToString(gMaxDailyDrawdownPct, 0) +
                       "% - block entries at DD";
         Notify("EQ " + DoubleToString(gMaxDailyDrawdownPct, 0) +
                "%: new entries blocked when account DD reaches threshold");
        }
     }
   gPanelBlockReason = "";
   GsxUiMarkDirty();
   UpdatePanel(g_lastPanelState);
  }

//--- chart cycle: OFF → 5% → 10% → 20% → OFF
void CycleEquityGuardPct(const bool announce)
  {
   double next = 0.0;
   if(gMaxDailyDrawdownPct <= 0.0)
      next = 5.0;
   else
      if(gMaxDailyDrawdownPct < 7.5)
         next = 10.0;
      else
         if(gMaxDailyDrawdownPct < 15.0)
            next = 20.0;
         else
            next = 0.0;
   SetEquityGuardPct(next, announce);
  }

//--- shared Profit Scouter run-state global (PS<id>_RUN):
//    writing it pauses/resumes the scouter harvest without touching
//    any open position. HALT uses it for the one-click full stop.
string ScoutRunVarName()
  {
   return(GsxScoutRunVarName(InpScoutInstanceID));
  }

void SetScoutRun(const bool on)
  {
   GsxScoutRunSetLinked(InpScoutLinkEnable, InpScoutInstanceID, on);
  }

void SetRunState(bool on, bool announce)
  {
   gTradingEnabled = on;
   GlobalVariableSet(RunStateVarName(), on ? 1.0 : 0.0);
   ChartSyncServiceRun(on);

   if(!on)
     {
      DeleteOurPendings("stopped by user");
      gNeedSignalEval = false;
      gMarchOnce = false;
      ClearDrillWindow("STOP");
     }
   else
     {
      StartDrillWindow();
      //--- PLAY mid-bar: re-arm evaluation of the latest closed-bar signal
      gNeedSignalEval = true;
      string reason = "";
      bool hours = TimeFilterOK(reason);
      bool spread = SpreadOK(reason);
      if(CalcEngines())
        {
         string block = "";
         if(!TryRunSignalEval(hours, spread, block) && block != "" && InpVerboseSignals)
            Print("GsignalX: PLAY armed, waiting: ", block);
        }
     }

   if(announce)
     {
      gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                    (on ? " PLAY - trading enabled" : " STOP - trading paused");
      Notify(on ? "PLAY: new entries enabled"
                : "STOP: paused, open trades left running");
     }
   gPanelBlockReason = "";
   GsxUiMarkDirty();
   gUiNeedChartArt = true;
   UpdatePanel(g_lastPanelState);
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   // Multisymbol strip / dashboard objects on this chart (GSXMS_)
   // Wheel has empty sparam — route via strip enable or existing GSXMS_ objects.
   bool msWheel = (id == CHARTEVENT_MOUSE_WHEEL &&
                   (GsxChartRosterStripEnabled() || ObjectFind(0, "GSXMS_CBG") >= 0 ||
                    ObjectFind(0, "GSXMS_BG") >= 0));
   if(StringFind(sparam, "GSXMS_") == 0 ||
      (id == CHARTEVENT_MOUSE_MOVE && g_msDragging) ||
      msWheel)
     {
      if(GsxMsPanelOnChartEvent(id, lparam, dparam, sparam))
        {
         GsxUiMarkDirty();
         UpdatePanel(g_lastPanelState);
         return;
        }
     }

   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      string click = sparam;
      // Flat chip text labels end with _TX — route to parent button name
      if(StringLen(click) > 3 && StringSubstr(click, StringLen(click) - 3) == "_TX")
         click = StringSubstr(click, 0, StringLen(click) - 3);
      ObjectSetInteger(0, click, OBJPROP_SELECTED, false);

      if(click == gPfx + "BTN_RUN")
        {
         SetScoutRun(true);   // linked: resume the scouter harvest as well
         SetRunState(true, true);
         GsxSettingsAnnounce("PLAY");
        }
      else
         if(click == gPfx + "BTN_STOP")
           {
            SetRunState(false, true);   // entries only - scouter keeps managing exits
            GsxSettingsAnnounce("STOP");
           }
         else
            if(click == gPfx + "BTN_FLAT")
              {
               SetRunState(false, false);
               SetScoutRun(false);
               gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                             " HALT - operation paused (no closes)";
               Notify("HALT: operation paused (entries + scouting) - open trades left untouched");
               gPanelBlockReason = "";
               GsxUiMarkDirty();
               UpdatePanel(g_lastPanelState);
               GsxSettingsAnnounce("HALT");
              }
            else
               if(click == gPfx + "BTN_FLIP")
                 {
                  SetFlipWaitMode(!gFlipWaitMode, true);
                  GsxSettingsAnnounce(gFlipWaitMode ? "FOLLOW WAIT" : "FOLLOW");
                 }
               else
                  if(click == gPfx + "BTN_FDIR_AUTO" ||
                     click == gPfx + "BTN_FDIR_BUY" ||
                     click == gPfx + "BTN_FDIR_SELL" ||
                     click == gPfx + "BTN_FDIR_WAIT")
                    {
                     int mode = GSX_FOLLOW_AUTO;
                     if(click == gPfx + "BTN_FDIR_BUY")  mode = GSX_FOLLOW_BUY;
                     if(click == gPfx + "BTN_FDIR_SELL") mode = GSX_FOLLOW_SELL;
                     if(click == gPfx + "BTN_FDIR_WAIT") mode = GSX_FOLLOW_WAIT;
                     GsxRosterFollowDirSet(InpMagic, _Symbol, mode);
                     gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                                   " Follow " + GsxRosterFollowDirLabel(mode) +
                                   " (new entries only)";
                     Notify("Follow " + GsxRosterFollowDirLabel(mode) +
                            ": affects new entries only — open positions unchanged");
                     GsxUiMarkDirty();
                     UpdatePanel(g_lastPanelState);
                     GsxSettingsAnnounce("FDIR " + GsxRosterFollowDirLabel(mode));
                    }
                  else
                  if(click == gPfx + "BTN_SPREAD")
                    {
                     SetIgnoreSpread(!gIgnoreSpread, true);
                     GsxSettingsAnnounce(gIgnoreSpread ? "IGN" : "SPREAD");
                    }
                  else
                     if(click == gPfx + "BTN_AUTOLOT")
                       {
                        SetAutoLot(!gAutoLot, true);
                        GsxSettingsAnnounce("AUTOLOT");
                       }
                     else
                        if(click == gPfx + "BTN_EQGUARD")
                          {
                           CycleEquityGuardPct(true);
                           GsxSettingsAnnounce("EQ");
                          }
                        else
                           if(click == gPfx + "TITLE")
                             {
                              g_panelDragging = true;
                              g_panelDragOffSet = false;
                              ObjectSetInteger(0, click, OBJPROP_SELECTED, false);
                              return;
                             }
                           else
                              return;

      ObjectSetInteger(0, click, OBJPROP_SELECTED, false);
      ChartRedraw();
      return;
     }

   if(id == CHARTEVENT_MOUSE_MOVE)
     {
      int mx = (int)lparam;
      int my = (int)dparam;
      int flags = (int)StringToInteger(sparam);
      bool leftDown = ((flags & 1) == 1);

      if(g_panelDragging)
        {
         if(!leftDown)
           {
            g_panelDragging = false;
            g_panelDragOffSet = false;
            GsxSavePanelPos();
            gUiNeedChartArt = true;
            GsxUiMarkDirty();
            UpdatePanel(g_lastPanelState);   // restore levels/arrows
            return;
           }
         if(!g_panelDragOffSet)
           {
            g_panelDragOffX = mx - g_panelX;
            g_panelDragOffY = my - g_panelY;
            g_panelDragOffSet = true;
           }
         g_panelX = (int)MathMax(0, mx - g_panelDragOffX);
         g_panelY = (int)MathMax(0, my - g_panelDragOffY);
         GsxPanelClampPos(g_panelX, g_panelY, g_panelW, g_panelLastH);
         UpdatePanel(g_lastPanelState);
         return;
        }

      if(leftDown && GsxPanelHitTitle(mx, my))
        {
         g_panelDragging = true;
         g_panelDragOffX = mx - g_panelX;
         g_panelDragOffY = my - g_panelY;
         g_panelDragOffSet = true;
        }
     }
  }

//+------------------------------------------------------------------+
//| Init / Deinit                                                    |
//+------------------------------------------------------------------+
GsxTgConfig ChartBuildTgConfig()
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

void ChartTgTick()
  {
   if(!InpTgEnable)
      return;
   g_chartTgCfg = ChartBuildTgConfig();
   GsxTgMaybeReverify(g_chartTgCfg);
   GsxSettingsRebindCfg(g_chartTgCfg);
   if(GsxTgChartMayOwnDeals(InpMagic))
      GsxSettingsDrainPending(g_chartTgCfg);
   GsxTgProcessQueueEx(g_chartTgCfg, 1);
   GsxTgPublishStatus(InpMagic);

   // Deal failover when Trade Center desk HB is stale
   if(GsxTgChartMayOwnDeals(InpMagic) && GsxTgIsVerified())
     {
      GsxTgClaimDealOwner(InpMagic, GSX_TG_HOST_CHART);
      if(!g_chartTgSeeded)
        {
         GsxTgwSeedFromOpen(InpMagic);
         g_chartTgSeeded = true;
        }
      GsxTgwPoll(InpMagic, g_chartTgCfg, true);
     }
  }

int OnInit()
  {
   if(InpMinAgree < 1 || InpMinAgree > 3)
     {
      Print("GsignalX: 'Engines that must agree' must be 1..3");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(!InpTrigPP && !InpTrigST && !InpTrigSBT)
     {
      Print("GsignalX: at least one trigger engine must be enabled");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpRiskMode == GSX_RISK_PCT && !InpUseStop && !ScouterOwnsExits())
     {
      Print("GsignalX: percent risk sizing requires the ATR stop-loss to be enabled");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpRiskMode == GSX_RISK_PCT && !InpUseStop && ScouterOwnsExits())
      Print("GsignalX: percent risk sizing uses the ATR span for lot size; ",
            "catastrophe SL mult=", DoubleToString(InpStrategicStopMult, 1),
            (InpStrategicStopEnable ? " ON" : " OFF"));
   if(ScouterOwnsExits() && InpStrategicStopEnable && InpStrategicStopMult <= InpStopMult)
      Print("GsignalX: warning - strategic stop mult (", InpStrategicStopMult,
            ") should be wider than sizing stop mult (", InpStopMult, ")");
   if(InpDrillEnable && (InpDrillMinutes < 5 || InpDrillMinutes > 15))
      Print("GsignalX: drill minutes ", InpDrillMinutes,
            " outside 5..15 — clamped to ", ClampDrillMinutes(), " at runtime");
   if(InpFleetEnable && InpFleetTargetPairs < 1)
     {
      Print("GsignalX: 'Required live pairs' must be >= 1");
      return(INIT_PARAMETERS_INCORRECT);
     }

   if(InpEntryMode != GSX_ENTRY_MARKET)
     {
      if(InpLimitOffset < 4 || InpLimitOffset > 20 ||
         InpStopOffset  < 4 || InpStopOffset  > 20)
        {
         Print("GsignalX: limit/stop offsets must be between 4 and 20");
         return(INIT_PARAMETERS_INCORRECT);
        }
      double minD = BrokerMinDistance();
      if(OffsetPrice(InpLimitOffset) <= minD || OffsetPrice(InpStopOffset) <= minD)
         Print("GsignalX: warning - broker minimum distance is ",
               DoubleToString(minD, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
               ", offsets will be widened to match");
     }

   if(InpMaxDailyPositions < 0)
     {
      Print("GsignalX: 'Max daily positions' must be >= 0");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpMaxDailyDrawdownPct < 0.0)
     {
      Print("GsignalX: 'Max daily drawdown %' must be >= 0");
      return(INIT_PARAMETERS_INCORRECT);
     }

   trade.SetExpertMagicNumber((ulong)InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false);

   //--- PLAY / STOP state survives a restart or recompile
   if(GlobalVariableCheck(RunStateVarName()))
     {
      gTradingEnabled = (GlobalVariableGet(RunStateVarName()) > 0.5);
      ChartSyncServiceRun(gTradingEnabled);
     }
   else
      SetRunState(true, false);

   LoadFlipWaitMode();
   LoadIgnoreSpread();
   LoadAutoLot();
   LoadEquityGuard();
   CheckAndResetDailyCounters();

   //--- sweep unfilled brackets left over from a previous session
   CleanupStalePendings();

   //--- if already PLAY on restart, open a fresh drill window
   if(gTradingEnabled && InpDrillEnable && gDrillStart == 0)
      StartDrillWindow();

   //--- fleet governor: 1 s timer drives the fill loop independently of
   //    bar boundaries and close events, so the required pair count is
   //    restored continuously while PLAY
   if(InpFleetEnable && !EventSetTimer(1))
      Print("GsignalX: fleet timer failed to start (err=", GetLastError(),
            ") - fleet fills limited to bar/flat edges");

   ChartSetInteger(0, CHART_SHOW_GRID, false);
   ChartSetInteger(0, CHART_FOREGROUND, false);
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   ChartSetInteger(0, CHART_EVENT_MOUSE_WHEEL, true);
   GsxLoadPanelPos();

   // v1.24 compact roster strip (same magic as Service / Dashboard)
   g_msDefaultFleet = InpFleetTargetPairs;
   GsxMsPanelInit(InpMagic, InpRosterStripPageSize, true, InpUiScale, (int)InpUiVision);
   GsxMsPanelSetScoutLink(InpScoutLinkEnable, InpScoutInstanceID);

   // Chart attach: only ActivatePair when this chart symbol is NEW to the roster.
   // Re-activating an existing multi-desk pair forced PLAY+drill and re-fired old pairs.
   {
      string roster[];
      if(!GsxRosterStoreExists(InpMagic))
         GsxRosterStoreEnsure(InpMagic, _Symbol, roster);
      else
         GsxRosterStoreLoad(InpMagic, roster);
      int cap = GsxRosterClassMaxGet(InpMagic);
      if(cap < 4)
         cap = 8;
      string actWhy = "";
      bool already = GsxRosterContains(roster, _Symbol);
      if(already)
        {
         if(InpVerboseSignals)
            Print("GsignalX: chart attach — ", _Symbol,
                  " already on shared roster (no re-PLAY / no onboard kick)");
        }
      else if(GsxRosterActivatePair(InpMagic, _Symbol, roster, cap, true, actWhy))
        {
         gTradingEnabled = true;
         GlobalVariableSet(RunStateVarName(), 1.0);
         if(InpDrillEnable && gDrillStart == 0)
            StartDrillWindow();
         if(InpVerboseSignals)
            Print("GsignalX: chart activate — ", actWhy);
        }
      else if(InpVerboseSignals)
         Print("GsignalX: chart activate skipped — ", actWhy);
   }

   gInitBarTime = iTime(_Symbol, _Period, InpEvalClosedBar ? 1 : 0);
   gLastBarTime = 0;
   gNeedSignalEval = true;
   gFirstEntryDone = false;
   gMarchOnce = false;
   gHadPosition = false;
   gLastAction = "-";

   int d0;
   gHadPosition = (FindPosition(d0) != 0);

   Print("GsignalX initialised on ", _Symbol, " ", EnumToString((ENUM_TIMEFRAMES)_Period),
         " | start mode: ", (InpStartMode == GSX_START_NEXT ? "next complete signal" : "current signal"),
         " | entry: ", (InpEntryMode == GSX_ENTRY_MARKET ? "market" :
                        InpEntryMode == GSX_ENTRY_LIMIT ? "limit" :
                        InpEntryMode == GSX_ENTRY_STOP ? "stop" : "bracket"),
         " L/S=", ClampOffset(InpLimitOffset), "/", ClampOffset(InpStopOffset),
         (InpOffsetUnit == GSX_UNIT_PIPS ? "p" : "pt"),
         " | drill: ", (InpDrillEnable ? IntegerToString(ClampDrillMinutes()) + "m" : "off"),
         " | exit: ", (InpExitMode == GSX_EXIT_SCOUTER ? "Profit Scouter owns closes" : "signal reverse-close"),
         " | stratSL: ", (ScouterOwnsExits() && InpStrategicStopEnable
                         ? DoubleToString(InpStrategicStopMult, 1) + "xATR" : "off"),
         " | flip: ", (gFlipWaitMode ? "WAIT" : "FOLLOW"),
         " | follow: ", GsxRosterFollowDirLabel(GsxRosterFollowDirGet(InpMagic, _Symbol, GSX_FOLLOW_AUTO)),
         " | fleet: ", (InpFleetEnable ? IntegerToString(InpFleetTargetPairs) + " pairs" : "off"),
         " | svcOwn: ", (ChartServiceOwnsFleet() ? "YES" : "no"),
         " | chartEntries@svc: ", (InpChartEntriesWhenService ? "ON" : "OFF"));

   gUiDirty = true;
   gUiNeedChartArt = true;
   UpdatePanel("initialising");

   g_chartTgCfg = ChartBuildTgConfig();
   GsxTgSetMagic(InpMagic);
   GsxTgSetHostTag("chart");
   string acct = StringFormat("%I64d %s chart %s", AccountInfoInteger(ACCOUNT_LOGIN),
                              AccountInfoString(ACCOUNT_SERVER), _Symbol);
   GsxTgInit(g_chartTgCfg, acct);
   g_chartTgSeeded = false;

   string exitLab = (InpExitMode == GSX_EXIT_SCOUTER ? "SCOUTER" : "SIGNAL");
   GsxSettingsBindHost(g_chartTgCfg, InpMagic, InpScoutInstanceID, "chart",
                       false, exitLab);
   if(InpTgEnable && GsxTgChartMayOwnDeals(InpMagic))
      GsxSettingsNotifyLoad(g_chartTgCfg, InpMagic, InpScoutInstanceID, "chart",
                            false, exitLab);

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(InpTgEnable)
      GsxTgDeinit(g_chartTgCfg, g_tgwSessionPl);
   Comment("");
   DeleteOurObjects();
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Timer — fleet fill loop (independent of ticks, bars and closes)  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   FleetFillCheck();
   ChartTgTick();
   // Harden: retry march/fleet-armed eval when gates clear (not only flat-edge once).
   if(gTradingEnabled && ChartAutoEntriesAllowed() && gDataReady &&
      (gMarchOnce || gNeedSignalEval))
     {
      string why = "";
      bool hours = TimeFilterOK(why);
      bool spread = SpreadOK(why);
      string block = "";
      TryRunSignalEval(hours, spread, block);
     }
  }

//+------------------------------------------------------------------+
//| Tick                                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   string reason = "";
   bool   open   = IsMarketOpen(reason);
   bool   hours  = TimeFilterOK(reason);
   bool   spread = SpreadOK(reason);
   string state  = open ? (hours ? (spread ? "OPEN" : "OPEN (" + reason + ")") : "BLOCKED (" + reason + ")")
                        : "CLOSED (" + reason + ")";

   //--- weekend flat (FX only; crypto exempt): pendings are always
   //    cleaned; positions are only closed in legacy exit mode - in
   //    Scouter mode the open trades stay with Profit Scouter.
   if(InpCloseBeforeWE && open && !CryptoWeekendExempt())
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == FRIDAY && dt.hour >= InpCloseWEHour)
        {
         int d;
         DeleteOurPendings("weekend flat");
         if(!ScouterOwnsExits() && FindPosition(d) != 0)
            CloseCurrent("weekend flat");
         UpdatePanel(state);
         GsxPublishBusState(state);
         return;
        }
     }

   if(!open)
     {
      UpdatePanel(state);
      GsxPublishBusState(state);
      return;
     }

   //--- fallback for a transaction event that was missed (reconnect, restart)
   if(gOcoRequest)
     {
      DeleteOurPendings("OCO cleanup");
      ResolveOverfill();
      gOcoRequest = false;
     }

   //--- bracket housekeeping and trailing run on every tick
   ManagePendings();
   if(gDataReady)
      ManageTrailing();

   //--- post-harvest march: flat edge while PLAY → re-arm join of active signal
   int flatDir;
   bool havePos = (FindPosition(flatDir) != 0);
   if(gTradingEnabled && InpDrillMarchAfterFlat && gHadPosition && !havePos)
     {
      gMarchOnce = true;
      gNeedSignalEval = true;
      if(InpVerboseSignals)
         Print("GsignalX: flat detected — marching active signal");
     }
   gHadPosition = havePos;

   //--- signals: calculate once per new bar; retry eval until gates pass
   //    flat-edge / march sets gNeedSignalEval above; avoid per-tick order spam
   datetime barTime = iTime(_Symbol, _Period, 0);
   if(barTime != gLastBarTime)
     {
      if(CalcEngines())
        {
         gLastBarTime = barTime;
         gNeedSignalEval = true;
         gUiNeedChartArt = true;
         GsxUiMarkDirty();
        }
     }

   if(gNeedSignalEval && open)
     {
      string block = "";
      if(!TryRunSignalEval(hours, spread, block))
        {
         // keep retrying this bar; surface gate on panel
         if(block != "")
           {
            gPanelBlockReason = block;
            if(InpVerboseSignals &&
               (StringFind(gLastAction, "waiting:") < 0 || StringFind(gLastAction, block) < 0))
               gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " waiting: " + block;
            GsxUiMarkDirty();
           }
        }
      else
         gPanelBlockReason = "";
     }

   //--- position flat/open edge → refresh chart art
   int artDir = 0;
   bool artPos = (FindPosition(artDir) != 0);
   int artSig = artPos ? artDir : 0;
   if(artSig != gUiLastPosDir)
     {
      gUiLastPosDir = artSig;
      gUiNeedChartArt = true;
      GsxUiMarkDirty();
     }

   if(state != g_lastPanelState)
      GsxUiMarkDirty();

   if(g_panelDragging || GsxUiShouldRedraw())
      UpdatePanel(state);
   GsxPublishBusState(state);
  }
//|                                                                  |
//| Fires the moment the server reports a deal, so the surviving leg |
//| of an OCO bracket is cancelled on the fill event rather than on  |
//| the next tick. Trade calls made here are guarded against         |
//| re-entrancy; anything that cannot be completed immediately is    |
//| deferred to OnTick through gOcoRequest.                          |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest    &request,
                        const MqlTradeResult     &result)
  {
   static bool busy = false;

   //--- an order left the book: refresh the bracket state
   if(trans.type == TRADE_TRANSACTION_ORDER_DELETE ||
      trans.type == TRADE_TRANSACTION_HISTORY_ADD)
     {
      if(CountOurPendings() == 0)
         gPendDir = 0;
     }

   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(trans.symbol != _Symbol)
      return;
   if(!HistoryDealSelect(trans.deal))
     {
      gOcoRequest = true;               // could not read it, let OnTick sort it out
      return;
     }
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != (long)InpMagic)
      return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol)
      return;

   long dtype = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   if(dtype != DEAL_TYPE_BUY && dtype != DEAL_TYPE_SELL)
      return;

   long   entry  = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   double volume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
   double price  = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
     {
      RecordPositionOpened();
      gPanelBlockReason = "";
      gUiNeedChartArt = true;
      GsxUiMarkDirty();
      gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " FILLED " +
                    DoubleToString(volume, 2) + " @ " + DoubleToString(price, digits);
      Notify("filled " + DoubleToString(volume, 2) + " @ " +
             DoubleToString(price, digits) + " - cancelling the other leg");

      if(busy)
        {
         gOcoRequest = true;            // already inside a trade call, defer
         return;
        }
      busy = true;
      DeleteOurPendings("OCO - fill event");
      ResolveOverfill();
      busy = false;

      if(CountOurPendings() > 0)
         gOcoRequest = true;            // something survived, retry on the next tick
      else
         gPendDir = 0;
      return;
     }

   if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
     {
      //--- full outcome: profit + swap + commission, tracked the moment
      //    the broker reports the close (real time, not on next tick)
      double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                    + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                    + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
      gClosedCount++;
      gClosedRealized += profit;
      if(profit >= 0.0)
         gClosedWins++;
      else
         gClosedLosses++;

      gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " EXIT " +
                    DoubleToString(volume, 2) + " (" + DoubleToString(profit, 2) + ")";
      Notify("position closed " + DoubleToString(volume, 2) +
             " lots, result " + DoubleToString(profit, 2));
      gIntendedLot = 0.0;
      gOcoRequest  = true;              // clear any bracket left behind
      gUiNeedChartArt = true;
      GsxUiMarkDirty();
     }
  }
//+------------------------------------------------------------------+
