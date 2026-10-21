//+------------------------------------------------------------------+
//| TpNativeHost.mqh — closed-bar feed, bootstrap, settings apply     |
//+------------------------------------------------------------------+
#ifndef GSX_TP_NATIVE_HOST_MQH
#define GSX_TP_NATIVE_HOST_MQH

#include <GSignalX/TpNative/TpNativeEngine.mqh>
#include <GSignalX/TpNative/TpNativePersist.mqh>
#include <GSignalX/TpNative/TpNativeDraw.mqh>
#include <GSignalX/TpNative/TpNativeOpenBook.mqh>
#include <GSignalX/TpNative/TpNativeApply.mqh>

struct TpnHostState
  {
   TpnEngine  eng;
   TpnResult  last;
   datetime   lastBarOpen;
   bool       ready;
   bool       dirtySnap;
   string     drawPfx;
   long       magic;
  };

void TpnHostInit(TpnHostState &h, const string symbol, const ENUM_TIMEFRAMES tf,
                 const TpnSettings &set, const string drawPfx, const long magic)
  {
   TpnEngInit(h.eng);
   TpnEngSetSettings(h.eng, set);
   TpnEngSetSymbolTf(h.eng, symbol, (int)tf);
   TpnResultClear(h.last);
   h.lastBarOpen = 0;
   h.ready = false;
   h.dirtySnap = false;
   h.drawPfx = drawPfx;
   h.magic = magic;
   if(TpnLoadSnapshot(h.eng, symbol, (int)tf))
      h.ready = true;
  }

bool TpnHostBootstrap(TpnHostState &h, const string symbol, const ENUM_TIMEFRAMES tf,
                      const int historyBars)
  {
   TpnSettings keep = h.eng.set;
   int need = TpnUiBootstrapBars(historyBars, keep.period);
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(symbol, tf, 1, need, rates);
   if(copied <= 0)
      return(false);

   TpnEngReset(h.eng);
   TpnEngSetSettings(h.eng, keep);
   TpnEngSetSymbolTf(h.eng, symbol, (int)tf);

   TpnBar bars[];
   ArrayResize(bars, copied);
   for(int i = 0; i < copied; i++)
     {
      bars[i].index = i;
      bars[i].time  = rates[i].time;
      bars[i].high  = rates[i].high;
      bars[i].low   = rates[i].low;
      bars[i].close = rates[i].close;
     }
   TpnResult outs[];
   TpnEngBootstrap(h.eng, bars, copied, outs);
   if(copied > 0)
     {
      h.last = outs[copied - 1];
      h.lastBarOpen = rates[copied - 1].time;
     }
   h.ready = true;
   h.dirtySnap = true;
   if(h.eng.set.enabled)
      TpnApplyLevelToOpen(h.magic, symbol, h.last);
   return(true);
  }

// Push current tip level onto matching open positions (no-op if OFF / no level).
void TpnHostSyncOpenTp(TpnHostState &h, const string symbol)
  {
   if(!h.eng.set.enabled || !h.ready)
      return;
   TpnApplyLevelToOpen(h.magic, symbol, h.last);
  }

void TpnHostApplyUiSettings(TpnHostState &h, const bool enabled, const ENUM_TPN_TYPE typ,
                            const bool closeOnHit)
  {
   TpnSettings s = h.eng.set;
   s.enabled = enabled;
   s.type = typ;
   s.closeOnHit = closeOnHit;
   TpnEngSetSettings(h.eng, s);
   h.dirtySnap = true;
   // Recompute level for display without replaying bars
   if(h.ready && h.eng.lastProcessedIndex >= 0)
     {
      TpnBar tip;
      tip.index = h.eng.lastProcessedIndex;
      tip.time = h.last.updatedAt;
      tip.high = h.eng.hasPrevHigh ? h.eng.prevHigh : 0.0;
      tip.low = h.eng.hasPrevLow ? h.eng.prevLow : 0.0;
      tip.close = h.eng.hasPrevClose ? h.eng.prevClose : 0.0;
      h.last = TpnEngFillIdleResult(h.eng, tip);
      h.last.active = enabled;
      if(!enabled)
        {
         h.last.level = TPN_NA;
         h.last.distance = TPN_NA;
         h.last.hit = false;
         h.last.direction = TPN_DIR_NONE;
        }
      else
         TpnApplyLevelToOpen(h.magic, h.eng.symbol, h.last);
     }
  }

bool TpnHostApplyStructural(TpnHostState &h, const TpnSettings &s,
                            const string symbol, const ENUM_TIMEFRAMES tf)
  {
   bool rebuild = TpnEngSetSettings(h.eng, s);
   if(rebuild || !h.ready)
      return(TpnHostBootstrap(h, symbol, tf, s.historyBars));
   return(true);
  }

bool TpnHostOnClosedBar(TpnHostState &h, const string symbol, const ENUM_TIMEFRAMES tf,
                        const datetime closedBarOpen)
  {
   if(!h.ready)
     {
      if(!TpnHostBootstrap(h, symbol, tf, h.eng.set.historyBars))
         return(false);
     }
   if(closedBarOpen == 0 || closedBarOpen == h.lastBarOpen)
      return(false);

   MqlRates r[];
   if(CopyRates(symbol, tf, 1, 1, r) < 1)
      return(false);
   if(h.lastBarOpen != 0 && r[0].time != closedBarOpen)
     {
      PrintFormat("TpNative: bar gap on %s — rebuild", symbol);
      return(TpnHostBootstrap(h, symbol, tf, h.eng.set.historyBars));
     }

   TpnBar bar;
   bar.index = h.eng.lastProcessedIndex + 1;
   if(bar.index < 0)
      bar.index = 0;
   bar.time = r[0].time;
   bar.high = r[0].high;
   bar.low = r[0].low;
   bar.close = r[0].close;

   h.last = TpnEngProcessBar(h.eng, bar);
   h.lastBarOpen = r[0].time;
   h.dirtySnap = true;

   if(h.last.hit)
      TpnEmitPendingHit(symbol, (int)tf, h.last, h.magic, h.eng.set.closeOnHit);

   if(h.last.signal == TPN_SIG_LONG_FLIP || h.last.signal == TPN_SIG_SHORT_FLIP)
      TpnSaveSnapshot(h.eng, symbol, (int)tf);

   if(h.eng.set.enabled)
      TpnApplyLevelToOpen(h.magic, symbol, h.last);

   return(true);
  }

void TpnHostFlush(TpnHostState &h, const string symbol, const int tf)
  {
   if(h.dirtySnap)
     {
      TpnSaveSnapshot(h.eng, symbol, tf);
      h.dirtySnap = false;
     }
  }

void TpnHostDraw(TpnHostState &h, const color clr)
  {
   if(!h.eng.set.enabled)
      TpnDrawClear(h.drawPfx);
   else
      TpnDrawUpdate(h.drawPfx, h.last, clr);
  }

void TpnHostClearDraw(TpnHostState &h)
  {
   TpnDrawClear(h.drawPfx);
  }

#endif // GSX_TP_NATIVE_HOST_MQH
