//+------------------------------------------------------------------+
//|                                     ProfitScouter_Service.mq5   |
//|          Profit monitoring / harvesting SERVICE for MetaTrader 5 |
//|          Runs chart-free and auto-starts with the terminal.      |
//+------------------------------------------------------------------+
#property service
#property copyright "Profit Scouter"
#property version   "2.00"
#property description "Gsignalx Velocity 2.00 — Profit Scouter Dollar Target (Service edition)"
#property description "Fixed cash floors; profit lock; honors chart START/STOP/AUTO/CASH/LOSS via Instance ID."
#property description "Profit CASH: winners-only at set cash levels. Loss CASH: opt-in cut at cash floor."
#property description "Default CloseTicket refuses losses; ADVERSE-BAR Auto and LOSS CASH may allowLoss."

#define PS_HOST_SERVICE

#include <Trade\Trade.mqh>

enum ENUM_PS_SCOPE
  {
   PS_SCOPE_ONE   = 0,   // Single symbol only
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
input string  InpPrimarySymbol     = "EURUSD";
input int     InpCheckIntervalMs   = 100;     // scalp: fast poll (ms)
input string  InpTargetCurrency    = "";
input bool    InpIncludeSwap       = true;
input bool    InpIncludeCommission = true;
input int     InpSlippagePoints    = 30;
input int     InpMaxRetries        = 3;
input bool    InpScalpAsapAccountOnly = true; // Seed CASH mode (single floor) if no PS{id}_CASH GV
input bool    InpRespectChartRunState = true; // Honor PS{id}_RUN / ADVEN / CASH / LOSS from chart

input group "=== 2. Profit CASH floor (account) ==="
input bool    InpAccTargetEnable   = true;
input double  InpAccTargetMoney    = 100.0;   // Profit CASH floor in target ccy (blank InpTargetCurrency = account USD/EUR)
input double  InpAccTargetPctBal   = 0.0;
input bool    InpAccTrailEnable    = false;   // Layered only (ignored in CASH mode)
input double  InpAccTrailArm       = 50.0;
input double  InpAccTrailGiveMoney = 15.0;
input double  InpAccTrailGivePct   = 30.0;
input ENUM_PS_TRAIL InpAccTrailMode = PS_TRAIL_ANY;

input group "=== 2b. Loss CASH floor (account) ==="
input bool    InpAccCashLossEnable = false;   // Initial LOSS arm if no PS{id}_LOSS GV (chart LOSS toggles)
input double  InpAccCashLossMoney  = 100.0;   // Cut losers when floating <= -this (target ccy)

input group "=== 3. Per-position target (Layered) ==="
input bool    InpPosTargetEnable   = false;
input double  InpPosTargetMoney    = 10.0;
input double  InpPosPartialPct     = 0.0;

input group "=== 4. Per-position trailing (Layered) ==="
input bool    InpPosTrailEnable    = false;
input double  InpPosTrailArm       = 5.0;
input double  InpPosTrailGiveMoney = 2.0;
input double  InpPosTrailGivePct   = 30.0;
input ENUM_PS_TRAIL InpPosTrailMode = PS_TRAIL_ANY;

input group "=== 5. Per-pair basket target (Layered) ==="
input bool    InpSymTargetEnable   = false;
input double  InpSymTargetMoney    = 25.0;
input bool    InpSymTrailEnable    = false;
input double  InpSymTrailArm       = 12.0;
input double  InpSymTrailGiveMoney = 4.0;
input double  InpSymTrailGivePct   = 30.0;
input ENUM_PS_TRAIL InpSymTrailMode = PS_TRAIL_ANY;

input group "=== 6. Time-from-open window (Layered) ==="
input bool    InpWindowEnable      = false;   // CASH mode: do not gate on age
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
input double  InpProfitLockArm        = 100.0;   // Arm lock when peak >= Profit CASH floor (target ccy)
input double  InpProfitLockKeepPct    = 50.0;    // Lock floor = max(keep-% of peak, MinWinProfit)
input double  InpMinWinProfit         = 100.0;   // Winner close min per ticket (= Profit CASH floor; target ccy)

input group "=== 7c. Adverse-bar Auto loss exit ==="
input bool            InpAdverseExitEnable       = true;         // Initial AUTO arm if no saved PS{id}_ADVEN (chart toggles)
input int             InpAdverseMinBars          = 2;            // Fire when consecutive closed bars > this (2 -> >=3)
input ENUM_TIMEFRAMES InpAdverseTimeframe        = PERIOD_M5;    // Service has no chart; M5 matches Velocity desk
input bool            InpAdverseRequireSignal    = true;         // Skip if bus direction missing/0
input int             InpAdverseMinAgeMin        = 15;           // Min hold minutes before adverse may cut (0=off)
input bool            InpAdverseProtectOnceGreen = true;         // Skip adverse if ticket once peaked green / lock armed

input group "=== 8. Status / Notifications ==="
input bool    InpLogStatus         = true;
input int     InpStatusEverySec    = 60;
input bool    InpWriteStatusFile   = false;
input string  InpStatusFileName    = "ProfitScouter_status.txt";
input bool    InpPushOnClose       = false;
input bool    InpVerboseLog        = true;

input group "=== 9. Connector bus (FILE_COMMON) ==="
input bool    InpBusEnable         = true;   // Publish snapshot + heartbeat to Common Files

#include <ProfitScouter/Core.mqh>

void OnStart()
  {
   PsInitEngine();

   int ms = (int)MathMax(100, InpCheckIntervalMs);
   PrintFormat("ProfitScouter service #%d started | ccy=%s | target=%s | profitCash=%.2f | lossCash=%.2f | factor=%.5f | interval=%dms | bus=%s | cashMode=%s | chartRun=%s",
               InpInstanceID, g_accCcy, TargetCcy(), ProfitCashFloor(), LossCashFloor(), g_ccyFactor, ms,
               (InpBusEnable ? "ON" : "OFF"),
               (EffectiveCashMode() ? "CASH" : "LAYER"),
               (InpRespectChartRunState ? "honor" : "ignore"));

   while(!IsStopped())
     {
      if(!TerminalInfoInteger(TERMINAL_CONNECTED))
        {
         Sleep(1000);
         continue;
        }
      if(InpRespectChartRunState)
        {
         PsLoadScoutEnabled();
         PsLoadAdverseEnabled();
         PsLoadCashMode();
         PsLoadCashLossArmed();
        }
      else
        {
         gScoutEnabled = true;
         gAdverseEnabled = InpAdverseExitEnable;
         gCashMode = InpScalpAsapAccountOnly;
         gCashLossArmed = InpAccCashLossEnable;
        }
      Monitor();
      Sleep(ms);
     }

   PrintFormat("ProfitScouter service #%d stopped", InpInstanceID);
  }
//+------------------------------------------------------------------+
