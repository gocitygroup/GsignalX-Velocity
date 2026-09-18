//+------------------------------------------------------------------+
//|                                  ProfitScouter_DollarTarget.mq5  |
//|                    Profit monitoring / harvesting engine for MT5 |
//+------------------------------------------------------------------+
#property copyright "Profit Scouter"
#property version   "2.02"
#property description "Gsignalx Velocity 2.02 — Profit Scouter Dollar Target (EA edition)"
#property description "Standalone START/STOP/AUTO/CASH/LOSS/TRAIL scout; ATR/% auto-trail; movable panel."
#property description "Profit CASH: winners-only at set cash levels. Loss CASH: opt-in cut at cash floor."
#property description "TRAIL = independent ATR/percent candle trail; AUTO = adverse bars; BANK/CUT/FLAT manual."

#define PS_HOST_EA

#include <Trade\Trade.mqh>
#include <GSignalX/ChartPanel.mqh>
#include <ProfitScouter/Inputs.mqh>

input group "=== 1b. EA host ==="
input string  InpPrimarySymbol     = "";      // unused on EA (chart symbol); kept for Core parity
input ENUM_TIMEFRAMES InpAdverseTimeframe = PERIOD_CURRENT;  // Chart period (CURRENT = this chart)
input ENUM_TIMEFRAMES InpAtrTrailTf       = PERIOD_CURRENT;  // ATR trail TF (CURRENT = this chart)

input group "=== 8. Display / Notifications ==="
input bool    InpShowPanel         = true;
input bool    InpShowButtons       = true;    // Chart START/STOP/AUTO/CASH/LOSS/TRAIL + BANK/CUT/FLAT
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
   PrintFormat("ProfitScouter #%d started | scout=%s | auto=%s | cash=%s | lossCash=%s | ccy=%s | target=%s | floor=%.2f | lossFloor=%.2f | factor=%.5f | interval=%dms | bus=%s | closer=%s",
               InpInstanceID, (gScoutEnabled ? "START" : "STOP"),
               (gAdverseEnabled ? "ON" : "OFF"),
               (EffectiveCashMode() ? "CASH" : "LAYER"),
               (gCashLossArmed ? "ON" : "OFF"),
               g_accCcy, TargetCcy(), ProfitCashFloor(), LossCashFloor(), g_ccyFactor, ms,
               (InpBusEnable ? "ON" : "OFF"),
               (GsxScoutCloserAllowsCloses(InpInstanceID, false) ? "EA" : "yield-to-Service"));
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
