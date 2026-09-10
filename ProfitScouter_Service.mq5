//+------------------------------------------------------------------+
//|                                     ProfitScouter_Service.mq5   |
//|          Profit monitoring / harvesting SERVICE for MetaTrader 5 |
//|          Runs chart-free and auto-starts with the terminal.      |
//+------------------------------------------------------------------+
#property service
#property copyright "Profit Scouter"
#property version   "1.21"
#property description "Profit Scouter - Dollar Target (Service edition)"
#property description "Scalp ASAP; profit lock; honors chart START/STOP/AUTO via shared Instance ID."
#property description "Profit harvest: winners-only at set levels. Adverse-bar Auto can close same-symbol losers."
#property description "Default CloseTicket refuses losses; only ADVERSE-BAR Auto may allowLoss."

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
input bool    InpScalpAsapAccountOnly = true; // ASAP hard floor at account+pair+pos (skip trail/window)
input bool    InpRespectChartRunState = true; // Honor PS{id}_RUN from chart START/STOP

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
input bool            InpAdverseExitEnable    = true;         // Initial AUTO arm if no saved PS{id}_ADVEN (chart toggles)
input int             InpAdverseMinBars       = 2;            // Fire when consecutive closed bars > this (2 -> >=3)
input ENUM_TIMEFRAMES InpAdverseTimeframe     = PERIOD_M15;   // Service has no chart; default M15
input bool            InpAdverseRequireSignal = true;         // Skip if bus direction missing/0

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
   PrintFormat("ProfitScouter service #%d started | ccy=%s | target=%s | floor=%.2f | factor=%.5f | interval=%dms | bus=%s | scalpASAP=%s | chartRun=%s",
               InpInstanceID, g_accCcy, TargetCcy(), Money(InpAccTargetMoney), g_ccyFactor, ms,
               (InpBusEnable ? "ON" : "OFF"),
               (InpScalpAsapAccountOnly ? "acc+pair+pos" : "OFF"),
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
        }
      else
        {
         gScoutEnabled = true;
         gAdverseEnabled = InpAdverseExitEnable;
        }
      Monitor();
      Sleep(ms);
     }

   PrintFormat("ProfitScouter service #%d stopped", InpInstanceID);
  }
//+------------------------------------------------------------------+
