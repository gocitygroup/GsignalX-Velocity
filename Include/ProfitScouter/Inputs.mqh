//+------------------------------------------------------------------+
//|                                      ProfitScouter/Inputs.mqh     |
//|  Shared enums + input groups for EA and Service hosts.            |
//|  Include AFTER PS_HOST_* define; host-only inputs stay in .mq5.   |
//+------------------------------------------------------------------+
#ifndef PS_INPUTS_MQH
#define PS_INPUTS_MQH

enum ENUM_PS_SCOPE
  {
   PS_SCOPE_ONE   = 0,   // Chart / primary symbol only
   PS_SCOPE_ALL   = 1,   // All symbols
   PS_SCOPE_LIST  = 2    // Custom symbol list
  };

enum ENUM_PS_TRAIL
  {
   PS_TRAIL_MONEY   = 0,
   PS_TRAIL_PERCENT = 1,
   PS_TRAIL_ANY     = 2
  };

enum ENUM_PS_ATR_TRAIL_MODE
  {
   PS_ATR_TRAIL_ATR     = 0,  // ATR × mult (+ candle-range floor)
   PS_ATR_TRAIL_PERCENT = 1,  // % of peak money
   PS_ATR_TRAIL_HYBRID  = 2   // max(ATR money, % of peak)
  };

input group "=== 1. General / Filters ==="
input int     InpInstanceID        = 1;
input bool    InpUseMagicFilter    = false;
input long    InpMagicNumber       = 0;
input ENUM_PS_SCOPE InpScope       = PS_SCOPE_ALL;
input string  InpSymbolList        = "EURUSD,GBPUSD,XAUUSD";
input int     InpCheckIntervalMs   = 100;     // scalp: fast poll (ms)
input string  InpTargetCurrency    = "";
input bool    InpIncludeSwap       = true;
input bool    InpIncludeCommission = true;
input int     InpSlippagePoints    = 30;
input int     InpMaxRetries        = 3;
input bool    InpScalpAsapAccountOnly = true; // Seed CASH mode (single floor) if no PS{id}_CASH GV
input int     InpBasketClosesPerCycle = 2;    // Fair multi-symbol: max pair-basket banks per cycle

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
input bool            InpAdverseExitEnable       = true;            // Initial AUTO arm if no saved PS{id}_ADVEN
input int             InpAdverseMinBars          = 2;               // Fire when consecutive closed bars > this (2 -> >=3)
input bool            InpAdverseRequireSignal    = true;            // Skip if bus direction missing/0
input int             InpAdverseMinAgeMin        = 15;              // Min hold minutes before adverse may cut (0=off)
input bool            InpAdverseProtectOnceGreen = true;            // Skip adverse if ticket once peaked green / lock armed
input double          InpAdverseMinBodyPts       = 0.0;            // 0=off; avg opposing body must be >= pts
input double          InpAdverseMinRangePts      = 0.0;            // 0=off; avg opposing range must be >= pts
input int             InpAdverseLengthBars       = 3;              // Bars for adverse length average (when pts>0)

input group "=== 7d. ATR / Percent auto-trail (independent TRAIL arm) ==="
input bool                   InpAtrTrailEnable     = false;  // Seed TRAIL arm if no PS{id}_TRAIL GV
input ENUM_PS_ATR_TRAIL_MODE InpAtrTrailMode       = PS_ATR_TRAIL_HYBRID;
input int                    InpAtrTrailPeriod     = 14;
input double                 InpAtrTrailMult       = 1.5;    // Base ATR multiplier
input double                 InpAtrTrailPct        = 30.0;   // % of peak money give-back
input int                    InpAtrTrailCandles    = 3;      // Avg range of last N closed bars as distance floor
input double                 InpAtrTrailArmMoney   = 0.0;    // 0 = use MinWin floor to arm
input bool                   InpAtrTrailOptimize   = true;   // Adaptive EMA mult per symbol_canon
input double                 InpAtrTrailMultMin    = 0.8;
input double                 InpAtrTrailMultMax    = 2.5;
input double                 InpAtrTrailOptAlpha   = 0.20;   // EMA learning rate

input group "=== 9. Connector bus (FILE_COMMON) ==="
input bool    InpBusEnable         = true;

#endif // PS_INPUTS_MQH
//+------------------------------------------------------------------+
