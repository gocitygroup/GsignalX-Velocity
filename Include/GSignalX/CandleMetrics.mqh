//+------------------------------------------------------------------+
//|                                            CandleMetrics.mqh      |
//|  Shared ATR + closed-bar range/body helpers (Scouter + gates).    |
//|  Bar-time keyed caches — no CopyRates thrash per poll.            |
//+------------------------------------------------------------------+
#ifndef GSX_CANDLE_METRICS_MQH
#define GSX_CANDLE_METRICS_MQH

//+------------------------------------------------------------------+
struct GsxAtrCache
  {
   string            sym;
   ENUM_TIMEFRAMES   tf;
   int               period;
   datetime          barTime;
   double            atrPts;
  };

GsxAtrCache g_gsxAtrCache[];

//+------------------------------------------------------------------+
int GsxAtrCacheIndex(const string sym, const ENUM_TIMEFRAMES tf, const int period, const bool create)
  {
   for(int i = 0; i < ArraySize(g_gsxAtrCache); i++)
     {
      if(g_gsxAtrCache[i].sym == sym &&
         g_gsxAtrCache[i].tf == tf &&
         g_gsxAtrCache[i].period == period)
         return(i);
     }
   if(!create)
      return(-1);
   int n = ArraySize(g_gsxAtrCache);
   ArrayResize(g_gsxAtrCache, n + 1);
   g_gsxAtrCache[n].sym     = sym;
   g_gsxAtrCache[n].tf      = tf;
   g_gsxAtrCache[n].period  = period;
   g_gsxAtrCache[n].barTime = 0;
   g_gsxAtrCache[n].atrPts  = 0.0;
   return(n);
  }

//+------------------------------------------------------------------+
//| ATR in points (price / _Point). Cached per symbol/tf/period.     |
//+------------------------------------------------------------------+
double GsxAtrPoints(const string symbol, const ENUM_TIMEFRAMES tf, const int period)
  {
   if(symbol == "" || period < 1)
      return(0.0);

   datetime bt = iTime(symbol, tf, 0);
   int ix = GsxAtrCacheIndex(symbol, tf, period, true);
   if(ix < 0)
      return(0.0);

   if(bt != 0 && bt == g_gsxAtrCache[ix].barTime && g_gsxAtrCache[ix].atrPts > 0.0)
      return(g_gsxAtrCache[ix].atrPts);

   int handle = iATR(symbol, tf, period);
   if(handle == INVALID_HANDLE)
      return(0.0);

   double buf[];
   ArraySetAsSeries(buf, true);
   // shift 1 = last closed bar ATR
   if(CopyBuffer(handle, 0, 1, 1, buf) < 1)
     {
      IndicatorRelease(handle);
      return(0.0);
     }
   IndicatorRelease(handle);

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return(0.0);

   double atrPts = buf[0] / point;
   g_gsxAtrCache[ix].barTime = bt;
   g_gsxAtrCache[ix].atrPts  = atrPts;
   return(atrPts);
  }

//+------------------------------------------------------------------+
//| Closed-bar range in points (shift 1 = last closed).              |
//+------------------------------------------------------------------+
double GsxClosedBarRangePts(const string symbol, const ENUM_TIMEFRAMES tf, const int shift = 1)
  {
   if(symbol == "" || shift < 1)
      return(0.0);
   double hi = iHigh(symbol, tf, shift);
   double lo = iLow(symbol, tf, shift);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0 || hi <= 0.0 || lo <= 0.0)
      return(0.0);
   return((hi - lo) / point);
  }

//+------------------------------------------------------------------+
//| Closed-bar body |close-open| in points.                          |
//+------------------------------------------------------------------+
double GsxClosedBarBodyPts(const string symbol, const ENUM_TIMEFRAMES tf, const int shift = 1)
  {
   if(symbol == "" || shift < 1)
      return(0.0);
   double op = iOpen(symbol, tf, shift);
   double cl = iClose(symbol, tf, shift);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return(0.0);
   return(MathAbs(cl - op) / point);
  }

//+------------------------------------------------------------------+
//| Average closed-bar range over last N closed bars (shift 1..N).   |
//+------------------------------------------------------------------+
double GsxAvgClosedRangePts(const string symbol, const ENUM_TIMEFRAMES tf, const int nBars)
  {
   if(symbol == "" || nBars < 1)
      return(0.0);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int n = CopyRates(symbol, tf, 1, nBars, rates);
   if(n <= 0)
      return(0.0);

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return(0.0);

   double sum = 0.0;
   for(int i = 0; i < n; i++)
      sum += (rates[i].high - rates[i].low) / point;
   return(sum / (double)n);
  }

//+------------------------------------------------------------------+
//| Average closed-bar body over last N closed bars.                 |
//+------------------------------------------------------------------+
double GsxAvgClosedBodyPts(const string symbol, const ENUM_TIMEFRAMES tf, const int nBars)
  {
   if(symbol == "" || nBars < 1)
      return(0.0);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int n = CopyRates(symbol, tf, 1, nBars, rates);
   if(n <= 0)
      return(0.0);

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return(0.0);

   double sum = 0.0;
   for(int i = 0; i < n; i++)
      sum += MathAbs(rates[i].close - rates[i].open) / point;
   return(sum / (double)n);
  }

//+------------------------------------------------------------------+
//| Money value of one point move for 1.0 lot on symbol.             |
//+------------------------------------------------------------------+
double GsxPointValueMoney(const string symbol)
  {
   double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(tickSize <= 0.0 || tickValue <= 0.0 || point <= 0.0)
      return(0.0);
   return(tickValue * (point / tickSize));
  }

// Convert points distance to account money for given volume.
double GsxPointsToMoney(const string symbol, const double points, const double volume)
  {
   if(points <= 0.0 || volume <= 0.0)
      return(0.0);
   double pv = GsxPointValueMoney(symbol);
   if(pv <= 0.0)
      return(0.0);
   return(points * pv * volume);
  }

#endif // GSX_CANDLE_METRICS_MQH
//+------------------------------------------------------------------+
