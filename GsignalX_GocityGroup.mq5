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
#property version   "1.20"
#property description "GsignalX - PP SuperTrend + ATR SuperTrend + SuperBollingerTrend"
#property description "Entry engine: limit/stop bracket, scalping drill, fleet fill."
#property description "Fleet: 4 pairs complete = open position OR working pending."
#property description "Scouter mode: catastrophe SL; FOLLOW/WAIT; movable panel."
#property description "STOP / HALT pause the operation only - neither ever closes a trade."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <GSignalX/BusProtocol.mqh>
#include <GSignalX/BusIO.mqh>
#include <GSignalX/SymbolCanon.mqh>
#include <GSignalX/TerminalIdentity.mqh>
#include <GSignalX/OpportunityGrade.mqh>

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
input int         InpFleetFillCooldownSec= 10;    // Min seconds between fleet fills (anti-stampede)
input bool        InpFleetRequireDrill    = false; // Fill only inside the drill window

input group "5e) Exit ownership"
input EnExitMode  InpExitMode          = GSX_EXIT_SCOUTER; // Exit ownership (Scouter = signal never closes)
input bool        InpScoutLinkEnable   = true;  // PLAY/HALT also resume/pause Profit Scouter
input int         InpScoutInstanceID   = 1;     // Profit Scouter instance ID to link
input bool        InpFlipWaitDefault   = false; // Initial FOLLOW/WAIT (false=FOLLOW fill new dir)

input group "6) Money management"
input EnRiskMode  InpRiskMode      = GSX_RISK_PCT; // Position sizing
input double      InpFixedLot      = 0.10;         // Fixed lot (if Fixed lot)
input double      InpRiskPct       = 1.0;          // Risk per trade (%)
input double      InpMaxLot        = 5.0;          // Maximum lot cap

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
input bool         InpShowButtons  = true;               // Show PLAY / STOP / HALT / FOLLOW|WAIT / SPREAD|IGN
input bool         InpShowArrows   = true;               // Draw signal arrows on the chart
input int          InpArrowBars    = 300;                // Arrows: how many bars back
input bool         InpShowLevels   = true;               // Draw engine + trade levels
input ENUM_BASE_CORNER InpCorner   = CORNER_LEFT_UPPER;  // Panel corner
input int          InpPanelX       = 12;                 // Panel X (initial; drag title to move; saved)
input int          InpPanelY       = 22;                 // Panel Y (initial; drag title to move; saved)
input string       InpFont         = "Segoe UI";         // Panel font
input int          InpFontSize     = 9;                  // Panel font size
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
string   gPfx            = "GSX_";
int      gLastSigDir     = 0;     // direction of the most recent trigger flip
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
//--- movable panel (drag title bar; position persisted per chart)
int      g_panelX = 12;
int      g_panelY = 22;
bool     g_panelDragging = false;
bool     g_panelDragOffSet = false;
int      g_panelDragOffX = 0;
int      g_panelDragOffY = 0;
string   g_lastPanelState = "OPEN";
int      g_panelW = 320;
int      g_panelTitleH = 22;


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

   string reason = "";
   bool marketOpen = IsMarketOpen(reason);
   bool cryptoExempt = CryptoWeekendExempt();
   bool calendarWeekend = false;
   bool weekend = false;
   bool fridayLate = false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == SATURDAY || dt.day_of_week == SUNDAY)
      calendarWeekend = true;
   // grading: crypto exempt must not be penalized for calendar weekend
   weekend = calendarWeekend && !cryptoExempt;
   if(InpFridayStop && !cryptoExempt &&
      dt.day_of_week == FRIDAY && dt.hour >= InpFridayStopHr)
      fridayLate = true;

   int bull = 0, bear = 0, direction = 0;
   if(gDataReady && gN >= 1)
     {
      int last = gN - 1;
      bull = (gPPdir[last] == 1 ? 1 : 0) + (gSTdir[last] == 1 ? 1 : 0) + (gSBTdir[last] == 1 ? 1 : 0);
      bear = 3 - bull;
      if(bull > bear)
         direction = 1;
      else
         if(bear > bull)
            direction = -1;
      if(gLastSigDir != 0)
         direction = gLastSigDir;
     }

   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   bool stale = false;
   datetime tickTime = (datetime)SymbolInfoInteger(_Symbol, SYMBOL_TIME);
   if(InpStaleTickSec > 0 && tickTime > 0 && (TimeCurrent() - tickTime) > InpStaleTickSec)
      stale = true;

   bool swing = GsxInSwingWindow(TimeCurrent(), InpSwingStartHour, InpSwingEndHour);
   string tid = GsxMakeTid();
   string canon = GsxSymbolCanon(_Symbol);

   //--- live fleet + session outcome snapshot (real time, every publish)
   int    fleetPos  = 0;
   double fleetPL   = 0.0;
   FleetFloating(fleetPL, fleetPos);

   string j = "{";
   j += GsxJsonKV_I("version", GSX_BUS_VERSION);
   j += GsxJsonKV_I("ts", (long)TimeCurrent());
   j += GsxJsonKV_S("tid", tid);
   j += GsxJsonKV_S("symbol", _Symbol);
   j += GsxJsonKV_S("symbol_canon", canon);
   j += GsxJsonKV_I("direction", direction);
   j += GsxJsonKV_I("bull", bull);
   j += GsxJsonKV_I("bear", bear);
   j += GsxJsonKV_I("min_agree", InpMinAgree);
   j += GsxJsonKV_S("mode", (InpMode == GSX_SIMPLE ? "simple" : "advanced"));
   j += GsxJsonKV_B("is_crypto", GsxIsCryptoSymbolEx(_Symbol, InpCryptoExtraList));
   j += GsxJsonKV_B("in_session", marketOpen && !weekend);
   j += GsxJsonKV_B("weekend", weekend);
   j += GsxJsonKV_B("friday_late", fridayLate);
   j += GsxJsonKV_B("swing_window", swing);
   j += GsxJsonKV_I("spread_pt", spread);
   j += GsxJsonKV_I("max_spread_pt", EffectiveMaxSpreadPt());
   j += GsxJsonKV_B("stale_tick", stale);
   j += GsxJsonKV_B("market_open", marketOpen, false);
   j += GsxJsonKV_I("positions", fleetPos);
   j += GsxJsonKV_D("fleet_floating", fleetPL);
   j += GsxJsonKV_I("closed_count", gClosedCount);
   j += GsxJsonKV_I("closed_wins", gClosedWins);
   j += GsxJsonKV_I("closed_losses", gClosedLosses);
   j += GsxJsonKV_D("closed_realized", gClosedRealized, false);
   j += "}";

   GsxBusWriteAtomic(GsxBusSignalPath(tid, canon), j);
   GsxBusRegisterSignal(tid, canon);
   GsxBusPublishHeartbeat("gsignalx");

   GsxEntryInputs ein;
   ein.direction = direction;
   ein.bull = bull;
   ein.bear = bear;
   ein.min_agree = InpMinAgree;
   ein.in_session = marketOpen && !weekend;
   ein.weekend = weekend;
   ein.friday_late = fridayLate;
   ein.swing_window = swing;
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
//| Helpers - math                                                   |
//+------------------------------------------------------------------+
void SmaSeries(const double &src[], const int n, const int period, double &out[])
  {
   ArrayResize(out, n);
   ArrayInitialize(out, 0.0);
   if(period <= 0 || n < period)
      return;
   double sum = 0.0;
   for(int i = 0; i < n; i++)
     {
      sum += src[i];
      if(i >= period)
         sum -= src[i - period];
      if(i >= period - 1)
         out[i] = sum / period;
     }
  }

void StdDevSeries(const double &src[], const int n, const int period, double &out[])
  {
   ArrayResize(out, n);
   ArrayInitialize(out, 0.0);
   if(period <= 1 || n < period)
      return;
   for(int i = period - 1; i < n; i++)
     {
      double mean = 0.0;
      for(int k = i - period + 1; k <= i; k++)
         mean += src[k];
      mean /= period;
      double acc = 0.0;
      for(int k = i - period + 1; k <= i; k++)
         acc += (src[k] - mean) * (src[k] - mean);
      out[i] = MathSqrt(acc / period);   // population stdev, matches Pine ta.stdev
     }
  }

// Wilder smoothing, matches Pine ta.atr / ta.rma
void RmaSeries(const double &src[], const int n, const int period, double &out[])
  {
   ArrayResize(out, n);
   ArrayInitialize(out, 0.0);
   if(period <= 0 || n < period)
      return;
   double sum = 0.0;
   for(int i = 0; i < period; i++)
      sum += src[i];
   double prev = sum / period;
   out[period - 1] = prev;
   for(int i = period; i < n; i++)
     {
      prev = (prev * (period - 1) + src[i]) / period;
      out[i] = prev;
     }
  }

//+------------------------------------------------------------------+
//| Core - rebuild every engine from raw rates                       |
//+------------------------------------------------------------------+
bool CalcEngines()
  {
   gDataReady = false;

   int shift  = InpEvalClosedBar ? 1 : 0;      // 1 = ignore the forming bar
   int want   = InpLookback;
   int warmup = InpBBLen + InpMaLen + InpStLen + InpPPAtrLen + InpRiskAtrLen + InpPivotPrd * 4 + 60;
   if(want < warmup + 100)
      want = warmup + 100;

   MqlRates r[];
   ArraySetAsSeries(r, false);                 // index 0 = oldest
   int n = CopyRates(_Symbol, _Period, shift, want, r);
   if(n < warmup)
     {
      gStatus = "waiting for history (" + IntegerToString(n) + " bars)";
      return(false);
     }

   double hi[], lo[], cl[], hl2[], tr[];
   ArrayResize(hi, n);  ArrayResize(lo, n);  ArrayResize(cl, n);
   ArrayResize(hl2, n); ArrayResize(tr, n);

   for(int i = 0; i < n; i++)
     {
      hi[i]  = r[i].high;
      lo[i]  = r[i].low;
      cl[i]  = r[i].close;
      hl2[i] = (r[i].high + r[i].low) / 2.0;
      if(i == 0)
         tr[i] = hi[i] - lo[i];
      else
        {
         double a = hi[i] - lo[i];
         double b = MathAbs(hi[i] - cl[i - 1]);
         double c = MathAbs(lo[i] - cl[i - 1]);
         tr[i] = MathMax(a, MathMax(b, c));
        }
     }

   double atrPP[], atrST[], atrRisk[], maArr[];
   RmaSeries(tr, n, InpPPAtrLen,   atrPP);
   RmaSeries(tr, n, InpStLen,      atrST);
   RmaSeries(tr, n, InpRiskAtrLen, atrRisk);
   SmaSeries(cl, n, InpMaLen,      maArr);

   double smaHi[], smaLo[], sdHi[], sdLo[];
   SmaSeries(hi, n, InpBBLen, smaHi);
   SmaSeries(lo, n, InpBBLen, smaLo);
   StdDevSeries(hi, n, InpBBLen, sdHi);
   StdDevSeries(lo, n, InpBBLen, sdLo);

   ArrayResize(gPPdir, n);   ArrayResize(gSTdir, n);   ArrayResize(gSBTdir, n);
   ArrayResize(gPPline, n);  ArrayResize(gSTline, n);  ArrayResize(gSBTline, n);
   ArrayResize(gMA, n);      ArrayResize(gAtrRisk, n);
   ArrayResize(gClose, n);   ArrayResize(gBarTime, n);
   ArrayResize(gHigh, n);    ArrayResize(gLow, n);
   ArrayResize(gOpen, n);

   //--- Engine 1 : PP SuperTrend -----------------------------------
   double center = 0.0;
   bool   haveCenter = false;
   double ppTU[], ppTD[];
   ArrayResize(ppTU, n); ArrayResize(ppTD, n);
   ArrayInitialize(ppTU, 0.0); ArrayInitialize(ppTD, 0.0);

   int prd = InpPivotPrd;
   for(int i = 0; i < n; i++)
     {
      //--- pivot confirmed at bar i refers to bar j = i - prd
      int j = i - prd;
      if(j - prd >= 0)
        {
         bool isPH = true, isPL = true;
         for(int k = j - prd; k <= j + prd; k++)
           {
            if(k == j)
               continue;
            if(hi[k] >= hi[j]) isPH = false;
            if(lo[k] <= lo[j]) isPL = false;
           }
         double lastpp = 0.0;
         bool   got    = false;
         if(isPH)      { lastpp = hi[j]; got = true; }
         else if(isPL) { lastpp = lo[j]; got = true; }
         if(got)
           {
            if(!haveCenter) { center = lastpp; haveCenter = true; }
            else            { center = (center * 2.0 + lastpp) / 3.0; }
           }
        }

      double up = 0.0, dn = 0.0;
      bool   valid = (haveCenter && atrPP[i] > 0.0);
      if(valid)
        {
         up = center - InpPPFactor * atrPP[i];
         dn = center + InpPPFactor * atrPP[i];
        }

      if(i == 0 || !valid)
        {
         ppTU[i]   = up;
         ppTD[i]   = dn;
         gPPdir[i] = (i == 0) ? 1 : gPPdir[i - 1];
        }
      else
        {
         double prevTU = (ppTU[i - 1] != 0.0) ? ppTU[i - 1] : up;
         double prevTD = (ppTD[i - 1] != 0.0) ? ppTD[i - 1] : dn;
         ppTU[i] = (cl[i - 1] > prevTU) ? MathMax(up, prevTU) : up;
         ppTD[i] = (cl[i - 1] < prevTD) ? MathMin(dn, prevTD) : dn;
         if(cl[i] > prevTD)      gPPdir[i] =  1;
         else if(cl[i] < prevTU) gPPdir[i] = -1;
         else                    gPPdir[i] = gPPdir[i - 1];
        }
      gPPline[i] = (gPPdir[i] == 1) ? ppTU[i] : ppTD[i];
     }

   //--- Engine 2 : classic ATR SuperTrend --------------------------
   double stUp[], stDn[];
   ArrayResize(stUp, n); ArrayResize(stDn, n);
   ArrayInitialize(stUp, 0.0); ArrayInitialize(stDn, 0.0);
   for(int i = 0; i < n; i++)
     {
      bool valid = (atrST[i] > 0.0);
      double u = valid ? hl2[i] - InpStMult * atrST[i] : 0.0;
      double d = valid ? hl2[i] + InpStMult * atrST[i] : 0.0;
      if(i == 0 || !valid)
        {
         stUp[i]   = u;
         stDn[i]   = d;
         gSTdir[i] = (i == 0) ? 1 : gSTdir[i - 1];
        }
      else
        {
         double u1 = (stUp[i - 1] != 0.0) ? stUp[i - 1] : u;
         double d1 = (stDn[i - 1] != 0.0) ? stDn[i - 1] : d;
         stUp[i] = (cl[i - 1] > u1) ? MathMax(u, u1) : u;
         stDn[i] = (cl[i - 1] < d1) ? MathMin(d, d1) : d;
         int prev = gSTdir[i - 1];
         if(prev == -1 && cl[i] > d1)     gSTdir[i] =  1;
         else if(prev == 1 && cl[i] < u1) gSTdir[i] = -1;
         else                             gSTdir[i] = prev;
        }
      gSTline[i] = (gSTdir[i] == 1) ? stUp[i] : stDn[i];
     }

   //--- Engine 3 : SuperBollingerTrend -----------------------------
   double line = 0.0;
   int    dir  = 1;
   bool   haveLine = false;
   for(int i = 0; i < n; i++)
     {
      bool valid = (smaHi[i] != 0.0 && smaLo[i] != 0.0 && i >= InpBBLen);
      if(!valid)
        {
         gSBTline[i] = 0.0;
         gSBTdir[i]  = dir;
         continue;
        }
      double bbUp = smaHi[i] + sdHi[i] * InpBBMult;
      double bbDn = smaLo[i] - sdLo[i] * InpBBMult;

      if(!haveLine)
        {
         line = bbDn;
         dir  = 1;
         haveLine = true;
        }
      else
         if(dir == 1)
           {
            if(cl[i] < line) { line = bbUp; dir = -1; }
            else             { line = MathMax(line, bbDn); }
           }
         else
           {
            if(cl[i] > line) { line = bbDn; dir = 1; }
            else             { line = MathMin(line, bbUp); }
           }
      gSBTline[i] = line;
      gSBTdir[i]  = dir;
     }

   for(int i = 0; i < n; i++)
     {
      gMA[i]      = maArr[i];
      gAtrRisk[i] = atrRisk[i];
      gClose[i]   = cl[i];
      gBarTime[i] = r[i].time;
      gOpen[i]    = r[i].open;
      gHigh[i]    = hi[i];
      gLow[i]     = lo[i];
     }

   //--- most recent flip among the enabled trigger engines
   gLastSigDir = 0;
   gLastSigIdx = -1;
   for(int i = n - 1; i >= 1 && gLastSigIdx < 0; i--)
     {
      bool up = (InpTrigPP  && gPPdir[i]  ==  1 && gPPdir[i - 1]  == -1) ||
                (InpTrigST  && gSTdir[i]  ==  1 && gSTdir[i - 1]  == -1) ||
                (InpTrigSBT && gSBTdir[i] ==  1 && gSBTdir[i - 1] == -1);
      bool dw = (InpTrigPP  && gPPdir[i]  == -1 && gPPdir[i - 1]  ==  1) ||
                (InpTrigST  && gSTdir[i]  == -1 && gSTdir[i - 1]  ==  1) ||
                (InpTrigSBT && gSBTdir[i] == -1 && gSBTdir[i - 1] ==  1);
      if(up || dw)
        {
         gLastSigDir = up ? 1 : -1;
         gLastSigIdx = i;
        }
     }

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
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
     { reason = "terminal not connected"; return(false); }

   long tmode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(tmode == SYMBOL_TRADE_MODE_DISABLED)
     { reason = "symbol trading disabled"; return(false); }
   if(tmode == SYMBOL_TRADE_MODE_CLOSEONLY)
     { reason = "close-only mode"; return(false); }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
     { reason = "no tick data"; return(false); }

   //--- a market that has not ticked for a long time is closed
   if(InpStaleTickSec > 0 && (TimeCurrent() - tick.time) > InpStaleTickSec)
     { reason = "no ticks for " + IntegerToString((int)(TimeCurrent() - tick.time)) + "s (market closed)"; return(false); }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   ENUM_DAY_OF_WEEK dow = (ENUM_DAY_OF_WEEK)dt.day_of_week;
   bool cryptoExempt = CryptoWeekendExempt();

   //--- hard weekend block (FX/metals); crypto 24/7 exempt
   if(InpBlockWeekend && !cryptoExempt && (dow == SATURDAY || dow == SUNDAY))
     { reason = "weekend"; return(false); }

   //--- broker session table
   if(InpUseSessions)
     {
      datetime from, to;
      int  sessions = 0;
      bool inSession = false;
      int  secs = dt.hour * 3600 + dt.min * 60 + dt.sec;
      for(uint s = 0; s < 8; s++)
        {
         if(!SymbolInfoSessionTrade(_Symbol, dow, s, from, to))
            break;
         sessions++;
         int f = (int)from;
         int t = (int)to;
         if(secs >= f && secs <= t)
            inSession = true;
        }
      if(sessions > 0 && !inSession)
        { reason = "outside broker trading session"; return(false); }

      // crypto brokers often omit Sat/Sun session rows while ticks still flow
      if(sessions == 0 && cryptoExempt &&
         (dow == SATURDAY || dow == SUNDAY))
         return(true);
     }

   return(true);
  }

bool TimeFilterOK(string &reason)
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   bool cryptoExempt = CryptoWeekendExempt();

   if(InpUseHourFilter)
     {
      bool ok;
      if(InpStartHour <= InpEndHour)
         ok = (dt.hour >= InpStartHour && dt.hour < InpEndHour);
      else                                  // window crosses midnight
         ok = (dt.hour >= InpStartHour || dt.hour < InpEndHour);
      if(!ok)
        { reason = "outside trading hours"; return(false); }
     }

   if(InpFridayStop && !cryptoExempt &&
      dt.day_of_week == FRIDAY && dt.hour >= InpFridayStopHr)
     { reason = "Friday cut-off"; return(false); }

   return(true);
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

// FOLLOW: allow new-dir entries on flat charts. WAIT: block while opposite
// magic exposure still exists (Scouter / catastrophe SL must clear first).
bool AllowNewDirEntry(const int wanted)
  {
   if(wanted == 0)
      return(false);
   if(!gFlipWaitMode)
      return(true);                 // FOLLOW
   return(!MagicHasOppositeDir(wanted));
  }

double NormalizeLot(double lot)
  {
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(stepLot <= 0.0)
      stepLot = 0.01;
   lot = MathFloor(lot / stepLot) * stepLot;
   if(InpMaxLot > 0.0 && lot > InpMaxLot)
      lot = MathFloor(InpMaxLot / stepLot) * stepLot;
   if(lot < minLot)
      lot = minLot;
   if(lot > maxLot)
      lot = maxLot;
   return(NormalizeDouble(lot, 2));
  }

double CalcLot(double stopDistance)
  {
   if(InpRiskMode == GSX_RISK_LOT || stopDistance <= 0.0)
      return(NormalizeLot(InpFixedLot));

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0)
     {
      Print("GsignalX: tick value/size unavailable, falling back to fixed lot");
      return(NormalizeLot(InpFixedLot));
     }

   double riskMoney  = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPct / 100.0;
   double lossPerLot = (stopDistance / tickSize) * tickValue;
   if(lossPerLot <= 0.0)
      return(NormalizeLot(InpFixedLot));

   return(NormalizeLot(riskMoney / lossPerLot));
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
int EffectiveMaxSpreadPt()
  {
   if(gIgnoreSpread)
      return(0);
   return(InpMaxSpreadPt);
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
   if(InpVerboseSignals && hadRawFlip)
      Print("GsignalX: skip: ", why);
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
   return(true);
  }

//--- dispatcher: market, limit, stop, or both (prices from signal bar open)
bool PlaceEntry(int dir)
  {
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
   if(ScouterOwnsExits())
     {
      double stratDist = StrategicStopDistance(atr);
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
         if(trade.PositionClose(ticket))
            Print("GsignalX: duplicate fill closed #", ticket);
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
         if(excess >= step && trade.PositionClosePartial(keep, excess))
            Print("GsignalX: trimmed overfill by ", DoubleToString(excess, 2), " lots");
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
//| Fleet governor — keep the required number of pairs covered       |
//| A pair is complete when it has an open position OR at least one  |
//| working pending with our magic. Default target = 4.              |
//+------------------------------------------------------------------+
string FleetLockVarName()
  {
   return("GSX_FLEET_LOCK_" + IntegerToString((int)InpMagic));
  }

// Account-wide live floating P/L + position count for this magic
// (every pair the fleet holds, updated on every tick in real time).
void FleetFloating(double &pl, int &count)
  {
   pl    = 0.0;
   count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic)
         continue;
      pl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      count++;
     }
  }

void FleetAddUniqueSymbol(string &syms[], const string s)
  {
   if(s == "")
      return;
   for(int k = 0; k < ArraySize(syms); k++)
      if(syms[k] == s)
         return;
   int n = ArraySize(syms);
   ArrayResize(syms, n + 1);
   syms[n] = s;
  }

// Distinct symbols with an open position OR working pending (our magic).
// One symbol with both bracket legs counts as a single complete pair.
int FleetActivePairs()
  {
   string syms[];

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagic)
         continue;
      FleetAddUniqueSymbol(syms, PositionGetString(POSITION_SYMBOL));
     }

   int ototal = OrdersTotal();
   for(int i = 0; i < ototal; i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != (long)InpMagic)
         continue;
      FleetAddUniqueSymbol(syms, OrderGetString(ORDER_SYMBOL));
     }

   return(ArraySize(syms));
  }

// Atomic claim of the terminal-wide fill slot. Fails when another chart
// claimed it inside the cooldown window (GlobalVariableSetOnCondition
// is a server-side compare-and-set, so same-second races are safe).
bool FleetTryClaim(const datetime now)
  {
   string name = FleetLockVarName();
   double prev = 0.0;
   if(GlobalVariableCheck(name))
      prev = GlobalVariableGet(name);
   else
      GlobalVariableSet(name, 0.0);
   if(prev > 0.0 && (now - (datetime)prev) < InpFleetFillCooldownSec)
      return(false);
   return(GlobalVariableSetOnCondition(name, (double)now, prev));
  }

// Timer entry: if the fleet is short and this pair is idle, claim the
// fill slot and evaluate the entry immediately (joins the active engine
// direction under bot rules - same path the drill uses).
void FleetFillCheck()
  {
   if(!InpFleetEnable || !gTradingEnabled || !gDataReady)
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
   string n = gPfx + tag;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_BACK, false);
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
     }
   ObjectSetInteger(0, n, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR, edge);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, selectable);
   ObjectSetInteger(0, n, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, selectable ? 5 : 0);
  }

void SetLabel(string tag, int x, int y, string text, color clr, int size, bool bold)
  {
   string n = gPfx + tag;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_BACK, false);
      ObjectSetInteger(0, n, OBJPROP_ZORDER, 10);
     }
   ObjectSetInteger(0, n, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, n, OBJPROP_FONT, bold ? "Segoe UI Bold" : InpFont);
  }

void SetButton(string tag, int x, int y, int w, int h, string text, color bg, color fg)
  {
   string n = gPfx + tag;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_ZORDER, 20);
      ObjectSetString(0, n, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, n, OBJPROP_FONTSIZE, InpFontSize);
     }
   ObjectSetInteger(0, n, OBJPROP_CORNER, InpCorner);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR, fg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, InpColPanelEdge);
   ObjectSetInteger(0, n, OBJPROP_STATE, false);
  }

void DeleteOurObjects()
  {
   ObjectsDeleteAll(0, gPfx);
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
   int left = g_panelX - 8;
   int top  = g_panelY - 8;
   if(mx < left || mx > left + g_panelW)
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

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int x  = g_panelX;
   int y  = g_panelY;
   int rh = InpFontSize + 8;          // row height
   int w  = g_panelW;
   int col2 = x + 108;
   g_panelTitleH = InpFontSize + 12;

   bool marketOpen = (StringFind(tradeState, "OPEN") == 0);
   int  rows = 20 + (InpBusEnable ? 1 : 0);
   int  bodyTop = y + g_panelTitleH;
   int  totalH = g_panelTitleH + rows * rh + (InpShowButtons ? 78 : 12);

   SetRect("BG", x - 8, y - 8, w, totalH, InpColPanelBg, InpColPanelEdge, false);
   // Title bar = drag handle
   SetRect("TITLE", x - 8, y - 8, w, g_panelTitleH,
           C'36,42,54', InpColPanelEdge, true);
   SetLabel("H1", x, y - 2, "GsignalX", InpColAccent, InpFontSize + 3, true);
   SetLabel("H2", x + 78, y + 2, "drag to move", InpColNeutral, InpFontSize - 1, false);

   int r = 0;
   y = bodyTop;   // content rows start below the title

   //--- run state pill
   color runCol = !gTradingEnabled ? InpColBear : (marketOpen ? InpColBull : InpColNeutral);
   string runTxt = !gTradingEnabled ? "STOPPED" : (marketOpen ? "RUNNING" : "IDLE");
   SetLabel("L_RUN",  x, y + rh * r, "Status", InpColNeutral, InpFontSize, false);
   SetLabel("V_RUN",  col2, y + rh * r, runTxt, runCol, InpFontSize, true);
   r++;

   SetLabel("L_SYM",  x, y + rh * r, "Symbol / TF", InpColNeutral, InpFontSize, false);
   SetLabel("V_SYM",  col2, y + rh * r, _Symbol + "  " +
            StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period), 7), InpColText, InpFontSize, false);
   r++;

   SetLabel("L_MODE", x, y + rh * r, "Mode", InpColNeutral, InpFontSize, false);
   SetLabel("V_MODE", col2, y + rh * r, (InpMode == GSX_SIMPLE ? "Simple" :
            "Advanced " + IntegerToString(InpMinAgree) + "/3"), InpColText, InpFontSize, false);
   r++;

   RefreshDrillStatus();
   color drillCol = InpColNeutral;
   if(DrillWindowActive())
      drillCol = InpColBull;
   else
      if(gDrillStatus == "expired")
         drillCol = InpColBear;
   SetLabel("L_DRL", x, y + rh * r, "Drill", InpColNeutral, InpFontSize, false);
   SetLabel("V_DRL", col2, y + rh * r,
            (!InpDrillEnable ? "off" : gDrillStatus),
            drillCol, InpFontSize, true);
   r++;

   //--- engines
   if(gDataReady && gN > 1)
     {
      int last = gN - 1;
      int bull = (gPPdir[last] == 1 ? 1 : 0) + (gSTdir[last] == 1 ? 1 : 0) + (gSBTdir[last] == 1 ? 1 : 0);

      SetLabel("L_PP",  x, y + rh * r, "PP SuperTrend", InpColNeutral, InpFontSize, false);
      SetLabel("V_PP",  col2, y + rh * r, DirText(gPPdir[last]) +
               (InpTrigPP ? "  *" : ""), DirColor(gPPdir[last]), InpFontSize, true);
      r++;
      SetLabel("L_ST",  x, y + rh * r, "ATR SuperTrend", InpColNeutral, InpFontSize, false);
      SetLabel("V_ST",  col2, y + rh * r, DirText(gSTdir[last]) +
               (InpTrigST ? "  *" : ""), DirColor(gSTdir[last]), InpFontSize, true);
      r++;
      SetLabel("L_SB",  x, y + rh * r, "SuperBollinger", InpColNeutral, InpFontSize, false);
      SetLabel("V_SB",  col2, y + rh * r, DirText(gSBTdir[last]) +
               (InpTrigSBT ? "  *" : ""), DirColor(gSBTdir[last]), InpFontSize, true);
      r++;

      string meter = "";
      for(int i = 0; i < 3; i++)
         meter += (i < MathMax(bull, 3 - bull)) ? CharToString(110) : CharToString(111);
      SetLabel("L_AGR", x, y + rh * r, "Agreement", InpColNeutral, InpFontSize, false);
      SetLabel("V_AGR", col2, y + rh * r, IntegerToString(MathMax(bull, 3 - bull)) + "/3  " +
               (bull >= 2 ? "BULL" : "BEAR"), bull >= 2 ? InpColBull : InpColBear, InpFontSize, true);
      r++;

      //--- last signal detail
      string sigTxt = "none yet";
      color  sigCol = InpColNeutral;
      if(gLastSigIdx >= 0)
        {
         int ago = (gN - 1) - gLastSigIdx;
         sigTxt = (gLastSigDir == 1 ? "BUY" : "SELL") + "  " +
                  TimeToString(gBarTime[gLastSigIdx], TIME_MINUTES) +
                  "  (" + IntegerToString(ago) + " bars)";
         sigCol = DirColor(gLastSigDir);
        }
      SetLabel("L_SIG", x, y + rh * r, "Last signal", InpColNeutral, InpFontSize, false);
      SetLabel("V_SIG", col2, y + rh * r, sigTxt, sigCol, InpFontSize, false);
      r++;
     }
   else
     {
      SetLabel("L_ENG", x, y + rh * r, "Engines", InpColNeutral, InpFontSize, false);
      SetLabel("V_ENG", col2, y + rh * r, gStatus, InpColNeutral, InpFontSize, false);
      r += 5;
     }

   //--- market
   SetLabel("L_MKT", x, y + rh * r, "Market", InpColNeutral, InpFontSize, false);
   SetLabel("V_MKT", col2, y + rh * r, tradeState,
            marketOpen ? InpColBull : InpColBear, InpFontSize, false);
   r++;

   SetLabel("L_SPR", x, y + rh * r, "Spread / bar", InpColNeutral, InpFontSize, false);
   SetLabel("V_SPR", col2, y + rh * r,
            IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)) + " pts" +
            (gIgnoreSpread ? " IGN" : "") + "   " + BarCountdown(),
            gIgnoreSpread ? InpColAccent : InpColText, InpFontSize, false);
   r++;

   //--- position detail
   int dir;
   ulong ticket = FindPosition(dir);
   if(ticket != 0 && PositionSelectByTicket(ticket))
     {
      double vol   = PositionGetDouble(POSITION_VOLUME);
      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      double prof  = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      double pip   = PipSize();
      double moved = (dir == 1) ? (SymbolInfoDouble(_Symbol, SYMBOL_BID) - open)
                                : (open - SymbolInfoDouble(_Symbol, SYMBOL_ASK));

      SetLabel("L_POS", x, y + rh * r, "Position", InpColNeutral, InpFontSize, false);
      SetLabel("V_POS", col2, y + rh * r,
               (dir == 1 ? "LONG " : "SHORT ") + DoubleToString(vol, 2) + " @ " +
               DoubleToString(open, digits), DirColor(dir), InpFontSize, true);
      r++;

      string slTxt = (sl > 0.0) ? DoubleToString(sl, digits) : "none";
      string tpTxt = (tp > 0.0) ? DoubleToString(tp, digits) : "open";
      SetLabel("L_SLT", x, y + rh * r, "SL / TP", InpColNeutral, InpFontSize, false);
      SetLabel("V_SLT", col2, y + rh * r, slTxt + "  /  " + tpTxt, InpColText, InpFontSize, false);
      r++;

      //--- result in currency and in R
      string rTxt = "";
      if(sl > 0.0)
        {
         double riskDist = MathAbs(open - sl);
         if(riskDist > 0.0)
            rTxt = "   " + DoubleToString(moved / riskDist, 2) + "R";
        }
      SetLabel("L_PL", x, y + rh * r, "Open result", InpColNeutral, InpFontSize, false);
      SetLabel("V_PL", col2, y + rh * r,
               DoubleToString(prof, 2) + "  (" + DoubleToString(moved / pip, 1) + "p)" + rTxt,
               prof >= 0.0 ? InpColBull : InpColBear, InpFontSize, true);
      r++;
     }
   else
     {
      SetLabel("L_POS", x, y + rh * r, "Position", InpColNeutral, InpFontSize, false);
      SetLabel("V_POS", col2, y + rh * r, "flat", InpColNeutral, InpFontSize, false);
      r++;
      SetLabel("L_SLT", x, y + rh * r, "SL / TP", InpColNeutral, InpFontSize, false);
      SetLabel("V_SLT", col2, y + rh * r, "-", InpColNeutral, InpFontSize, false);
      r++;
      SetLabel("L_PL",  x, y + rh * r, "Open result", InpColNeutral, InpFontSize, false);
      SetLabel("V_PL",  col2, y + rh * r, "-", InpColNeutral, InpFontSize, false);
      r++;
     }

   //--- working orders
   int pend = CountOurPendings();
   SetLabel("L_ORD", x, y + rh * r, "Entry orders", InpColNeutral, InpFontSize, false);
   string entryTxt = "market";
   if(InpEntryMode == GSX_ENTRY_LIMIT) entryTxt = "limit " + IntegerToString(ClampOffset(InpLimitOffset));
   if(InpEntryMode == GSX_ENTRY_STOP)  entryTxt = "stop "  + IntegerToString(ClampOffset(InpStopOffset));
   if(InpEntryMode == GSX_ENTRY_BOTH)  entryTxt = "L" + IntegerToString(ClampOffset(InpLimitOffset)) +
                                                  "/S" + IntegerToString(ClampOffset(InpStopOffset));
   string unitTxt = (InpEntryMode == GSX_ENTRY_MARKET ? "" :
                     (InpOffsetUnit == GSX_UNIT_PIPS ? "p" : "pt"));
   string anchorTxt = "";
   if(InpEntryMode != GSX_ENTRY_MARKET && gSignalOpenPx > 0.0)
      anchorTxt = " @" + DoubleToString(gSignalOpenPx, digits);
   SetLabel("V_ORD", col2, y + rh * r, entryTxt + unitTxt + anchorTxt,
            InpColText, InpFontSize, false);
   r++;
   SetLabel("L_WRK", x, y + rh * r, "Working", InpColNeutral, InpFontSize, false);
   SetLabel("V_WRK", col2, y + rh * r,
            pend == 0 ? "none" : IntegerToString(pend) + " pending " + (gPendDir == 1 ? "BUY" : "SELL"),
            pend == 0 ? InpColNeutral : DirColor(gPendDir), InpFontSize, false);
   r++;

   SetLabel("L_ACT", x, y + rh * r, "Last action", InpColNeutral, InpFontSize, false);
   SetLabel("V_ACT", col2, y + rh * r, gLastAction, InpColText, InpFontSize - 1, false);
   r++;

   SetLabel("L_FLW", x, y + rh * r, "Flip fill", InpColNeutral, InpFontSize, false);
   SetLabel("V_FLW", col2, y + rh * r,
            gFlipWaitMode ? "WAIT (clear opposite first)" : "FOLLOW (fill new dir)",
            gFlipWaitMode ? InpColAccent : InpColBull, InpFontSize, true);
   r++;

   //--- fleet / exit ownership + account-wide live floating P/L
   int  fleetN   = (InpFleetEnable ? FleetActivePairs() : 0);
   bool fleetShort = (InpFleetEnable && fleetN < InpFleetTargetPairs);
   double fleetPL = 0.0;
   int    fleetPos = 0;
   FleetFloating(fleetPL, fleetPos);
   string fleetTxt = (InpFleetEnable ?
                       IntegerToString(fleetN) + "/" + IntegerToString(InpFleetTargetPairs) +
                       (fleetShort ? " filling" : " full") + " (pos|pend)" : "off");
   SetLabel("L_FLT", x, y + rh * r, "Fleet / Exit", InpColNeutral, InpFontSize, false);
   SetLabel("V_FLT", col2, y + rh * r, fleetTxt + " " + DoubleToString(fleetPL, 2) +
            "  |  " + (InpExitMode == GSX_EXIT_SCOUTER ? "scout" : "signal"),
            (fleetPos > 0 ? (fleetPL >= 0.0 ? InpColBull : InpColBear)
                          : (fleetShort ? InpColAccent : InpColText)),
            InpFontSize, true);
   r++;

   //--- session outcomes (this chart's symbol, updated on every close)
   SetLabel("L_SES", x, y + rh * r, "Session", InpColNeutral, InpFontSize, false);
   SetLabel("V_SES", col2, y + rh * r,
            "closed " + IntegerToString(gClosedCount) +
            "  +" + IntegerToString(gClosedWins) + " / -" + IntegerToString(gClosedLosses) +
            "  " + DoubleToString(gClosedRealized, 2),
            (gClosedRealized > 0.0 ? InpColBull :
             (gClosedRealized < 0.0 ? InpColBear : InpColNeutral)), InpFontSize, false);
   r++;

   if(InpBusEnable)
     {
      SetLabel("L_BUS", x, y + rh * r, "Opp grades", InpColNeutral, InpFontSize, false);
      SetLabel("V_BUS", col2, y + rh * r, gBusGradeLine, InpColAccent, InpFontSize - 1, false);
      r++;
     }

   //--- controls
   if(InpShowButtons)
     {
      int by = y + rh * r + 6;
      SetButton("BTN_RUN",  x,       by, 74, 24, "PLAY",
                gTradingEnabled ? InpColBull : InpColPanelBg,
                gTradingEnabled ? InpColPanelBg : InpColText);
      SetButton("BTN_STOP", x + 80,  by, 74, 24, "STOP",
                gTradingEnabled ? InpColPanelBg : InpColBear,
                gTradingEnabled ? InpColText : InpColPanelBg);
      SetButton("BTN_FLAT", x + 160, by, 74, 24, "HALT", InpColPanelBg, InpColAccent);
      SetButton("BTN_FLIP", x + 240, by, 74, 24,
                gFlipWaitMode ? "WAIT" : "FOLLOW",
                gFlipWaitMode ? InpColAccent : InpColBull,
                InpColPanelBg);
      //--- second row: spread gate toggle (IGN bypasses InpMaxSpreadPt)
      int by2 = by + 30;
      SetButton("BTN_SPREAD", x, by2, 74, 24,
                gIgnoreSpread ? "IGN" : "SPREAD",
                gIgnoreSpread ? InpColAccent : InpColPanelBg,
                gIgnoreSpread ? InpColPanelBg : InpColText);
     }

   if(!g_panelDragging)
     {
      DrawLevels();
      DrawArrows();
     }
   ChartRedraw();
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
   UpdatePanel(g_lastPanelState);
  }

//--- shared Profit Scouter run-state global (PS<id>_RUN):
//    writing it pauses/resumes the scouter harvest without touching
//    any open position. HALT uses it for the one-click full stop.
string ScoutRunVarName()
  {
   return(StringFormat("PS%d_RUN", InpScoutInstanceID));
  }

void SetScoutRun(const bool on)
  {
   if(!InpScoutLinkEnable)
      return;
   GlobalVariableSet(ScoutRunVarName(), on ? 1.0 : 0.0);
  }

void SetRunState(bool on, bool announce)
  {
   gTradingEnabled = on;
   GlobalVariableSet(RunStateVarName(), on ? 1.0 : 0.0);

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
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == gPfx + "BTN_RUN")
        {
         SetRunState(true, true);
         SetScoutRun(true);   // linked: resume the scouter harvest as well
        }
      else
         if(sparam == gPfx + "BTN_STOP")
            SetRunState(false, true);   // entries only - scouter keeps managing exits
         else
            if(sparam == gPfx + "BTN_FLAT")
              {
               SetRunState(false, false);
               SetScoutRun(false);
               gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                             " HALT - operation paused (no closes)";
               Notify("HALT: operation paused (entries + scouting) - open trades left untouched");
              }
            else
               if(sparam == gPfx + "BTN_FLIP")
                  SetFlipWaitMode(!gFlipWaitMode, true);
               else
                  if(sparam == gPfx + "BTN_SPREAD")
                     SetIgnoreSpread(!gIgnoreSpread, true);
                  else
                     if(sparam == gPfx + "TITLE")
                       {
                        g_panelDragging = true;
                        g_panelDragOffSet = false;
                        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
                        return;
                       }
                     else
                        return;

      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
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

   trade.SetExpertMagicNumber((ulong)InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false);

   //--- PLAY / STOP state survives a restart or recompile
   if(GlobalVariableCheck(RunStateVarName()))
      gTradingEnabled = (GlobalVariableGet(RunStateVarName()) > 0.5);
   else
      SetRunState(true, false);

   LoadFlipWaitMode();
   LoadIgnoreSpread();

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
   GsxLoadPanelPos();

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
         " | fleet: ", (InpFleetEnable ? IntegerToString(InpFleetTargetPairs) + " pairs" : "off"));

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
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
        }
     }

   if(gNeedSignalEval && open)
     {
      string block = "";
      if(!TryRunSignalEval(hours, spread, block))
        {
         // keep retrying this bar; surface gate on panel occasionally
         if(block != "" && InpVerboseSignals &&
            (StringFind(gLastAction, "waiting:") < 0 || StringFind(gLastAction, block) < 0))
            gLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " waiting: " + block;
        }
     }

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
     }
  }
//+------------------------------------------------------------------+
