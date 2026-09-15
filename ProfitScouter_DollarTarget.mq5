//+------------------------------------------------------------------+
//|                                  ProfitScouter_DollarTarget.mq5  |
//|                    Profit monitoring / harvesting engine for MT5 |
//+------------------------------------------------------------------+
#property copyright "Profit Scouter"
#property version   "2.00"
#property description "Gsignalx Velocity 2.00 — Profit Scouter Dollar Target (EA edition)"
#property description "Standalone START/STOP/AUTO scout; Scalp ASAP; movable on-chart panel."
#property description "Profit harvest: winners-only at set levels. Adverse-bar Auto can close same-symbol losers."
#property description "Chart AUTO toggles adverse loss exit; default CloseTicket refuses losses otherwise."

#define PS_HOST_EA

#include <Trade\Trade.mqh>
#include <GSignalX/ChartPanel.mqh>

enum ENUM_PS_SCOPE
  {
   PS_SCOPE_ONE   = 0,   // Chart symbol only
   PS_SCOPE_ALL   = 1,   // All symbols
   PS_SCOPE_LIST  = 2    // Custom symbol list
  };

enum ENUM_PS_TRAIL
  {
   PS_TRAIL_MONEY   = 0,
   PS_TRAIL_PERCENT = 1,
   PS_TRAIL_ANY     = 2
  };

input group "=== 1. General / Filters ==="
input int     InpInstanceID        = 1;
input bool    InpUseMagicFilter    = false;
input long    InpMagicNumber       = 0;
input ENUM_PS_SCOPE InpScope       = PS_SCOPE_ALL;
input string  InpSymbolList        = "EURUSD,GBPUSD,XAUUSD";
input string  InpPrimarySymbol     = "";      // unused on EA (chart symbol); kept for Core parity
input int     InpCheckIntervalMs   = 100;     // scalp: fast poll (ms)
input string  InpTargetCurrency    = "";
input bool    InpIncludeSwap       = true;
input bool    InpIncludeCommission = true;
input int     InpSlippagePoints    = 30;
input int     InpMaxRetries        = 3;
input bool    InpScalpAsapAccountOnly = true; // ASAP hard floor at account+pair+pos (skip trail/window)

input group "=== 2. Per-position target ==="
input bool    InpPosTargetEnable   = false;
input double  InpPosTargetMoney    = 10.0;
input double  InpPosPartialPct     = 0.0;

input group "=== 3. Per-position trailing ==="
input bool    InpPosTrailEnable    = false;
input double  InpPosTrailArm       = 5.0;
input double  InpPosTrailGiveMoney = 2.0;
input double  InpPosTrailGivePct   = 30.0;
input ENUM_PS_TRAIL InpPosTrailMode = PS_TRAIL_ANY;

input group "=== 4. Per-pair (symbol basket) target ==="
input bool    InpSymTargetEnable   = false;
input double  InpSymTargetMoney    = 25.0;
input bool    InpSymTrailEnable    = false;
input double  InpSymTrailArm       = 12.0;
input double  InpSymTrailGiveMoney = 4.0;
input double  InpSymTrailGivePct   = 30.0;
input ENUM_PS_TRAIL InpSymTrailMode = PS_TRAIL_ANY;

input group "=== 5. Account-level target ==="
input bool    InpAccTargetEnable   = true;
input double  InpAccTargetMoney    = 5.0;     // ASAP floor in target ccy (blank InpTargetCurrency = account USD/EUR)
input double  InpAccTargetPctBal   = 0.0;
input bool    InpAccTrailEnable    = false;
input double  InpAccTrailArm       = 50.0;
input double  InpAccTrailGiveMoney = 15.0;
input double  InpAccTrailGivePct   = 30.0;
input ENUM_PS_TRAIL InpAccTrailMode = PS_TRAIL_ANY;
input group "=== 6. Time-from-open window ==="
input bool    InpWindowEnable      = false;   // scalp ASAP: do not gate on age
input int     InpWindowStartMin    = 0;
input int     InpWindowEndMin      = 60;
input bool    InpTrailAfterWindow  = true;
input bool    InpTargetsWindowOnly = false;
input bool    InpCloseAtWindowEnd  = false;
input double  InpWindowEndMinProfit = 0.5;

input group "=== 7. Trailing safety ==="
input bool    InpTrailRequirePositive = true;
input double  InpTrailMinCloseProfit  = 0.10;
input bool    InpPersistPeaks         = true;

input group "=== 7b. Profit lock & winner floor ==="
input bool    InpProfitLockEnable     = true;    // Lock green trades: never close once-profitable on a loss
input double  InpProfitLockArm        = 5.0;     // Arm lock when peak >= ASAP floor (target ccy)
input double  InpProfitLockKeepPct    = 50.0;    // Lock floor = max(keep-% of peak, MinWinProfit)
input double  InpMinWinProfit         = 5.0;     // Winner close min per ticket (= ASAP floor; target ccy)

input group "=== 7c. Adverse-bar Auto loss exit ==="
input bool            InpAdverseExitEnable       = true;            // Initial AUTO arm if no saved PS{id}_ADVEN
input int             InpAdverseMinBars          = 2;               // Fire when consecutive closed bars > this (2 -> >=3)
input ENUM_TIMEFRAMES InpAdverseTimeframe        = PERIOD_CURRENT;  // Chart period (CURRENT = this chart)
input bool            InpAdverseRequireSignal    = true;            // Skip if bus direction missing/0
input int             InpAdverseMinAgeMin        = 15;              // Min hold minutes before adverse may cut (0=off)
input bool            InpAdverseProtectOnceGreen = true;            // Skip adverse if ticket once peaked green / lock armed

input group "=== 8. Display / Notifications ==="
input bool    InpShowPanel         = true;
input bool    InpShowButtons       = true;    // Chart START / STOP / AUTO (standalone)
input bool    InpScoutStartArmed   = true;    // Initial arm if no saved run state
input int     InpPanelX            = 10;      // Panel X (left-upper); drag to move; saved
input int     InpPanelY            = 50;      // Panel Y (below buttons by default)
input double  InpUiScale           = 1.5;     // UI scale request (system applies −40% size policy)
input ENUM_GSX_UI_VISION InpUiVision = GSX_VISION_COMFORT; // Near / Comfort / Far readability
input int     InpBtnX              = 10;      // Buttons X (left-upper corner)
input int     InpBtnY              = 18;      // Buttons Y (left-upper corner)
input bool    InpAlertOnClose      = false;
input bool    InpPushOnClose       = false;
input bool    InpVerboseLog        = true;

input group "=== 9. Connector bus (FILE_COMMON) ==="
input bool    InpBusEnable         = true;

#include <ProfitScouter/Core.mqh>

int OnInit()
  {
   if(!PsInitEngine())
      return(INIT_FAILED);

   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);

   int ms = (int)MathMax(100, InpCheckIntervalMs);
   if(!EventSetMillisecondTimer(ms))
     {
      Print("ProfitScouter: failed to start timer, err=", GetLastError());
      return(INIT_FAILED);
     }

   PsUpdateButtons();
   PrintFormat("ProfitScouter #%d started | scout=%s | auto=%s | ccy=%s | target=%s | floor=%.2f | factor=%.5f | interval=%dms | bus=%s | scalpASAP=%s",
               InpInstanceID, (gScoutEnabled ? "START" : "STOP"),
               (gAdverseEnabled ? "ON" : "OFF"),
               g_accCcy, TargetCcy(), Money(InpAccTargetMoney), g_ccyFactor, ms,
               (InpBusEnable ? "ON" : "OFF"),
               (InpScalpAsapAccountOnly ? "acc+pair+pos" : "OFF"));
   Monitor();
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   PsDeleteButtons();
   PsDeletePanel();
   Comment("");
   PrintFormat("ProfitScouter #%d stopped (reason=%d)", InpInstanceID, reason);
  }

void OnTimer()  { TryMonitor(); }
void OnTick()   { TryMonitor(); }
void OnTrade()  { TryMonitor(); }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(PsHandleChartEvent(id, lparam, dparam, sparam))
      TryMonitor();
  }

void TryMonitor()
  {
   if(g_busy)
      return;
   uint now = GetTickCount();
   uint gap = (uint)MathMax(100, InpCheckIntervalMs);
   if(now - g_lastRun < gap)
      return;
   g_lastRun = now;
   g_busy = true;
   Monitor();
   g_busy = false;
  }
//+------------------------------------------------------------------+
