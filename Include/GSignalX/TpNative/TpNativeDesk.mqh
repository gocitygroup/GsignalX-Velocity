//+------------------------------------------------------------------+
//| TpNativeDesk.mqh — multi-symbol TP for Trade Center (non-block)   |
//| Chart host persistent; others stack-local; budgeted refresh queue.|
//+------------------------------------------------------------------+
#ifndef GSX_TP_NATIVE_DESK_MQH
#define GSX_TP_NATIVE_DESK_MQH

#include <GSignalX/TpNative/TpNativeHost.mqh>
#include <GSignalX/TpNative/TpNativeOpenBook.mqh>
#include <GSignalX/RosterStore.mqh>

TpnSettings  g_tpnDeskSet;
bool         g_tpnDeskInited = false;
TpnHostState g_tpnDeskChart;
bool         g_tpnDeskChartReady = false;
string       g_tpnDeskChartSym = "";
bool         g_tpnDeskNeedBootstrap = false; // at most one bootstrap per tick
int          g_tpnDeskBootstrapsThisTick = 0;

void TpnDeskInit(const TpnSettings &set, const long magic)
  {
   g_tpnDeskSet = set;
   g_tpnDeskInited = true;
   g_tpnDeskChartReady = false;
   g_tpnDeskChartSym = "";
   g_tpnDeskNeedBootstrap = false;
   g_tpnDeskBootstrapsThisTick = 0;
   GsxRosterTpEnableSeed(magic, set.enabled);
   GsxRosterTpTypeSeed(magic, (set.type == TPN_AVERAGE) ? 1 : 0);
  }

void TpnDeskSyncSettingsFromGv(const long magic)
  {
   if(!g_tpnDeskInited)
      return;
   g_tpnDeskSet.enabled = GsxRosterTpEnableGet(magic, g_tpnDeskSet.enabled);
   int typ = GsxRosterTpTypeGet(magic, (g_tpnDeskSet.type == TPN_AVERAGE) ? 1 : 0);
   g_tpnDeskSet.type = (typ == 1) ? TPN_AVERAGE : TPN_MEDIAN;
  }

// After OpenBook GV/kick — apply tip to desk chart host (call from panel if Desk linked).
void TpnDeskApplyUiAfterToggle(const long magic)
  {
   TpnDeskSyncSettingsFromGv(magic);
   if(!g_tpnDeskChartReady)
      return;
   TpnHostApplyUiSettings(g_tpnDeskChart, g_tpnDeskSet.enabled, g_tpnDeskSet.type,
                          g_tpnDeskSet.closeOnHit);
   if(!g_tpnDeskSet.enabled)
      TpnHostClearDraw(g_tpnDeskChart);
   else if(g_tpnDeskChartSym != "")
      TpnRefreshQPush(g_tpnDeskChartSym);
  }

bool TpnDeskTryBootstrap(TpnHostState &h, const string symbol, const ENUM_TIMEFRAMES tf)
  {
   if(h.ready)
      return(true);
   if(g_tpnDeskBootstrapsThisTick >= 1)
     {
      g_tpnDeskNeedBootstrap = true;
      return(false);
     }
   if(!TpnHostBootstrap(h, symbol, tf, g_tpnDeskSet.historyBars))
      return(false);
   g_tpnDeskBootstrapsThisTick++;
   return(true);
  }

void TpnDeskEnsureChart(const string symbol, const ENUM_TIMEFRAMES tf, const long magic)
  {
   if(g_tpnDeskChartReady && g_tpnDeskChartSym == symbol)
     {
      TpnHostApplyUiSettings(g_tpnDeskChart, g_tpnDeskSet.enabled, g_tpnDeskSet.type,
                             g_tpnDeskSet.closeOnHit);
      return;
     }
   TpnHostInit(g_tpnDeskChart, symbol, tf, g_tpnDeskSet, "GSXMS_TP_" + symbol + "_", magic);
   if(!g_tpnDeskChart.ready)
      TpnDeskTryBootstrap(g_tpnDeskChart, symbol, tf);
   g_tpnDeskChartReady = true;
   g_tpnDeskChartSym = symbol;
  }

// Process one non-chart symbol: only on new bar or force kick; flush only if dirty pivot.
void TpnDeskProcessOther(const string symbol, const ENUM_TIMEFRAMES tf, const long magic,
                         const bool force)
  {
   datetime closedOpen = iTime(symbol, tf, 1);
   if(closedOpen == 0)
      return;
   datetime seen = TpnSeenGet(symbol);
   if(!force && seen == closedOpen)
      return;

   TpnHostState h;
   TpnHostInit(h, symbol, tf, g_tpnDeskSet, "GSXMS_TP_" + symbol + "_", magic);
   TpnHostApplyUiSettings(h, g_tpnDeskSet.enabled, g_tpnDeskSet.type, g_tpnDeskSet.closeOnHit);
   if(!h.ready)
     {
      if(!TpnDeskTryBootstrap(h, symbol, tf))
        {
         TpnRefreshQPush(symbol); // retry next tick
         return;
        }
     }
   else if(force && h.ready)
     {
      // Tip refresh without replaying history
      TpnHostApplyUiSettings(h, true, g_tpnDeskSet.type, g_tpnDeskSet.closeOnHit);
     }

   if(closedOpen != h.lastBarOpen)
      TpnHostOnClosedBar(h, symbol, tf, closedOpen);

   // Flush only on pivot/hit (dirtySnap set by OnClosedBar signal path saves immediately;
   // otherwise debounce: flush if force kick completed tip refresh)
   if(h.dirtySnap && (force || h.last.signal != TPN_SIG_NONE || h.last.hit))
      TpnHostFlush(h, symbol, (int)tf);
   else if(h.dirtySnap && force)
      TpnHostFlush(h, symbol, (int)tf);

   TpnSeenSet(symbol, closedOpen);
  }

void TpnDeskTick(const string chartSym, const ENUM_TIMEFRAMES tf, const long magic,
                 const int budget = 2)
  {
   if(!g_tpnDeskInited)
      return;
   g_tpnDeskBootstrapsThisTick = 0;
   TpnDeskSyncSettingsFromGv(magic);

   // TP OFF: clear draw, no open-pair I/O
   if(!g_tpnDeskSet.enabled)
     {
      if(g_tpnDeskChartReady)
        {
         TpnHostApplyUiSettings(g_tpnDeskChart, false, g_tpnDeskSet.type, g_tpnDeskSet.closeOnHit);
         TpnHostClearDraw(g_tpnDeskChart);
         // Still advance engine state on new closed bar (warm for instant ON)
         if(chartSym != "")
           {
            datetime t = iTime(chartSym, tf, 1);
            if(t > 0 && t != g_tpnDeskChart.lastBarOpen && g_tpnDeskChart.ready)
               TpnHostOnClosedBar(g_tpnDeskChart, chartSym, tf, t);
           }
        }
      return;
     }

   int done = 0;
   if(chartSym != "")
     {
      TpnDeskEnsureChart(chartSym, tf, magic);
      datetime t = iTime(chartSym, tf, 1);
      bool forceChart = TpnDeskRefreshPending() && (g_tpnDeskChartSym == chartSym);
      if(t > 0)
        {
         if(t != g_tpnDeskChart.lastBarOpen)
            TpnHostOnClosedBar(g_tpnDeskChart, chartSym, tf, t);
         else if(forceChart)
            TpnHostApplyUiSettings(g_tpnDeskChart, true, g_tpnDeskSet.type,
                                   g_tpnDeskSet.closeOnHit);
         TpnSeenSet(chartSym, t);
        }
      if(!g_tpnDeskChart.ready)
         TpnDeskTryBootstrap(g_tpnDeskChart, chartSym, tf);
      done++;
     }

   // Drain refresh queue first (kick from TP ON)
   while(done < budget)
     {
      string sym = "";
      if(!TpnDeskPopRefresh(sym))
         break;
      if(sym == chartSym)
         continue;
      TpnDeskProcessOther(sym, tf, magic, true);
      done++;
     }
   TpnDeskClearRefreshForce();

   // Incremental open pairs (new bar only)
   if(done < budget)
     {
      string open[];
      TpnCollectOpenSymbols(magic, open);
      for(int i = 0; i < ArraySize(open) && done < budget; i++)
        {
         if(open[i] == chartSym)
            continue;
         datetime t = iTime(open[i], tf, 1);
         if(t == 0 || t == TpnSeenGet(open[i]))
            continue;
         TpnDeskProcessOther(open[i], tf, magic, false);
         done++;
        }
     }
  }

void TpnDeskFlushAll()
  {
   if(g_tpnDeskChartReady)
      TpnHostFlush(g_tpnDeskChart, g_tpnDeskChart.eng.symbol, g_tpnDeskChart.eng.tf);
  }

void TpnDeskDrawChart(const string symbol, const color clr)
  {
   if(!g_tpnDeskSet.enabled || !g_tpnDeskChartReady || g_tpnDeskChartSym != symbol)
     {
      TpnDrawClear("GSXMS_TP_" + symbol + "_");
      return;
     }
   TpnHostDraw(g_tpnDeskChart, clr);
  }

#endif // GSX_TP_NATIVE_DESK_MQH
