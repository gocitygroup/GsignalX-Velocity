//+------------------------------------------------------------------+
//|                                     ProfitScouter_Service.mq5   |
//|          Profit monitoring / harvesting SERVICE for MetaTrader 5 |
//|          Runs chart-free and auto-starts with the terminal.      |
//+------------------------------------------------------------------+
#property service
#property copyright "Profit Scouter"
#property version   "2.02"
#property description "Gsignalx Velocity 2.02 — Profit Scouter Dollar Target (Service edition)"
#property description "Fixed cash floors; ATR/% TRAIL; honors chart START/STOP/AUTO/CASH/LOSS/TRAIL via Instance ID."
#property description "Profit CASH: winners-only at set cash levels. Loss CASH: opt-in cut at cash floor."
#property description "Sole closer when running; EA yields auto closes; BANK/CUT/FLAT always OK on chart."

#define PS_HOST_SERVICE

#include <Trade\Trade.mqh>
#include <ProfitScouter/Inputs.mqh>

input group "=== 1b. Service host ==="
input string  InpPrimarySymbol     = "EURUSD";
input bool    InpRespectChartRunState = true; // Honor PS{id}_RUN / ADVEN / CASH / LOSS / TRAIL from chart
input ENUM_TIMEFRAMES InpAdverseTimeframe = PERIOD_M5; // Service has no chart; M5 matches Velocity desk
input ENUM_TIMEFRAMES InpAtrTrailTf       = PERIOD_M5; // ATR trail TF for headless host

input group "=== 8. Status / Notifications ==="
input bool    InpLogStatus         = true;
input int     InpStatusEverySec    = 60;
input bool    InpWriteStatusFile   = false;
input string  InpStatusFileName    = "ProfitScouter_status.txt";
input bool    InpPushOnClose       = false;
input bool    InpVerboseLog        = true;

#include <ProfitScouter/Core.mqh>

void OnStart()
  {
   PsInitEngine();
   GsxScoutCloserClaimService(InpInstanceID);

   int ms = (int)MathMax(100, InpCheckIntervalMs);
   PrintFormat("ProfitScouter service #%d started | ccy=%s | target=%s | profitCash=%.2f | lossCash=%.2f | factor=%.5f | interval=%dms | bus=%s | cashMode=%s | chartRun=%s | closer=SERVICE",
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
      // Keep sole-closer claim alive while Service runs
      GsxScoutCloserClaimService(InpInstanceID);
      if(InpRespectChartRunState)
        {
         PsLoadScoutEnabled();
         PsLoadAdverseEnabled();
         PsLoadCashMode();
         PsLoadCashLossArmed();
         PsLoadAtrTrailEnabled();
        }
      else
        {
         gScoutEnabled = true;
         gAdverseEnabled = InpAdverseExitEnable;
         gCashMode = InpScalpAsapAccountOnly;
         gCashLossArmed = InpAccCashLossEnable;
         gAtrTrailEnabled = InpAtrTrailEnable;
        }
      Monitor();
      Sleep(ms);
     }

   GsxScoutCloserReleaseService(InpInstanceID);
   PrintFormat("ProfitScouter service #%d stopped", InpInstanceID);
  }
//+------------------------------------------------------------------+
