//+------------------------------------------------------------------+
//| TpNativeEngine.mqh — pure native TP engine (prompt §5)            |
//| Struct + functions (MQL5-safe). Independent of Engines.mqh SBT.   |
//+------------------------------------------------------------------+
#ifndef GSX_TP_NATIVE_ENGINE_MQH
#define GSX_TP_NATIVE_ENGINE_MQH

#include <GSignalX/TpNative/TpNativeTypes.mqh>

#define TPN_RING_MAX  512

struct TpnEngine
  {
   TpnSettings set;
   double      highs[];
   double      lows[];
   int         ringN;
   double      line;
   double      prevSeenLine;
   bool        hasPrevSeen;
   double      prevClose;
   bool        hasPrevClose;
   double      prevHigh;
   bool        hasPrevHigh;
   double      prevLow;
   bool        hasPrevLow;
   double      lastPivot;
   bool        hasLastPivot;
   int         lastPivotIndex;
   double      diffs[];
   double      diffsSorted[];
   int         diffN;
   double      diffSum;
   int         lastProcessedIndex;
   string      symbol;
   int         tf;
  };

void TpnEngReset(TpnEngine &e)
  {
   ArrayResize(e.highs, TPN_RING_MAX);
   ArrayResize(e.lows, TPN_RING_MAX);
   ArrayInitialize(e.highs, 0.0);
   ArrayInitialize(e.lows, 0.0);
   e.ringN = 0;
   e.line = 0.0;
   e.prevSeenLine = TPN_NA;
   e.hasPrevSeen = false;
   e.prevClose = TPN_NA;
   e.hasPrevClose = false;
   e.prevHigh = TPN_NA;
   e.hasPrevHigh = false;
   e.prevLow = TPN_NA;
   e.hasPrevLow = false;
   e.lastPivot = TPN_NA;
   e.hasLastPivot = false;
   e.lastPivotIndex = -1;
   ArrayResize(e.diffs, 0);
   ArrayResize(e.diffsSorted, 0);
   e.diffN = 0;
   e.diffSum = 0.0;
   e.lastProcessedIndex = -1;
  }

void TpnEngInit(TpnEngine &e)
  {
   TpnSettingsDefaults(e.set);
   e.symbol = "";
   e.tf = 0;
   TpnEngReset(e);
  }

void TpnEngSetSymbolTf(TpnEngine &e, const string symbol, const int tf)
  {
   e.symbol = symbol;
   e.tf = tf;
  }

bool TpnEngSetSettings(TpnEngine &e, const TpnSettings &s)
  {
   bool rebuild = (s.period != e.set.period ||
                   s.mult != e.set.mult ||
                   s.pivotSource != e.set.pivotSource ||
                   s.crossMode != e.set.crossMode);
   e.set = s;
   if(e.set.period < 1)
      e.set.period = 1;
   if(e.set.period > TPN_RING_MAX)
      e.set.period = TPN_RING_MAX;
   if(e.set.mult < 0.1)
      e.set.mult = 0.1;
   return(rebuild);
  }

void TpnEngPushRing(TpnEngine &e, double &buf[], const double v)
  {
   if(e.ringN < e.set.period)
     {
      buf[e.ringN] = v;
      e.ringN++;
     }
   else
     {
      for(int i = 1; i < e.set.period; i++)
         buf[i - 1] = buf[i];
      buf[e.set.period - 1] = v;
     }
  }

bool TpnEngBands(const TpnEngine &e, double &bbUp, double &bbDn)
  {
   if(e.ringN < e.set.period)
      return(false);
   double sumH = 0.0, sumL = 0.0;
   for(int i = 0; i < e.set.period; i++)
     {
      sumH += e.highs[i];
      sumL += e.lows[i];
     }
   double meanH = sumH / e.set.period;
   double meanL = sumL / e.set.period;
   double varH = 0.0, varL = 0.0;
   for(int i = 0; i < e.set.period; i++)
     {
      double dh = e.highs[i] - meanH;
      double dl = e.lows[i] - meanL;
      varH += dh * dh;
      varL += dl * dl;
     }
   bbUp = meanH + MathSqrt(varH / e.set.period) * e.set.mult;
   bbDn = meanL - MathSqrt(varL / e.set.period) * e.set.mult;
   return(true);
  }

void TpnEngAddDiff(TpnEngine &e, const double d)
  {
   ArrayResize(e.diffs, e.diffN + 1);
   e.diffs[e.diffN] = d;
   e.diffSum += d;
   ArrayResize(e.diffsSorted, e.diffN + 1);
   int lo = 0, hi = e.diffN;
   while(lo < hi)
     {
      int mid = (lo + hi) / 2;
      if(e.diffsSorted[mid] < d)
         lo = mid + 1;
      else
         hi = mid;
     }
   for(int i = e.diffN; i > lo; i--)
      e.diffsSorted[i] = e.diffsSorted[i - 1];
   e.diffsSorted[lo] = d;
   e.diffN++;
  }

double TpnEngDistance(const TpnEngine &e)
  {
   if(e.diffN <= 0)
      return(TPN_NA);
   if(e.set.type == TPN_AVERAGE)
      return(e.diffSum / e.diffN);
   int mid = e.diffN / 2;
   if((e.diffN % 2) == 1)
      return(e.diffsSorted[mid]);
   return(0.5 * (e.diffsSorted[mid - 1] + e.diffsSorted[mid]));
  }

void TpnEngTrail(TpnEngine &e, const double close, const bool haveBands,
                 const double bbUp, const double bbDn)
  {
   if(!haveBands)
      e.line = 0.0;
   else if(close > e.line)
      e.line = MathMax(e.line, bbDn);
   else if(close < e.line)
      e.line = MathMin(e.line, bbUp);
   else
      e.line = 0.0;
  }

void TpnEngPass(TpnEngine &e, const bool cond, const double val, const double pivotHl,
                const double close, const int barIndex,
                const bool haveBands, const double bbUp, const double bbDn)
  {
   TpnEngTrail(e, close, haveBands, bbUp, bbDn);
   if(!cond)
      return;
   e.line = val;
   double y2 = close;
   if(e.set.pivotSource == TPN_PIVOT_ZIGZAG)
      y2 = e.line;
   else if(e.set.pivotSource == TPN_PIVOT_HIGH_LOW)
      y2 = pivotHl;
   if(e.hasLastPivot)
      TpnEngAddDiff(e, MathAbs(y2 - e.lastPivot));
   e.lastPivot = y2;
   e.hasLastPivot = true;
   e.lastPivotIndex = barIndex;
  }

void TpnEngRebuildSorted(TpnEngine &e)
  {
   ArrayResize(e.diffsSorted, e.diffN);
   e.diffSum = 0.0;
   for(int i = 0; i < e.diffN; i++)
     {
      e.diffsSorted[i] = e.diffs[i];
      e.diffSum += e.diffs[i];
     }
   for(int i = 1; i < e.diffN; i++)
     {
      double key = e.diffsSorted[i];
      int j = i - 1;
      while(j >= 0 && e.diffsSorted[j] > key)
        {
         e.diffsSorted[j + 1] = e.diffsSorted[j];
         j--;
        }
      e.diffsSorted[j + 1] = key;
     }
  }

TpnResult TpnEngFillIdleResult(const TpnEngine &e, const TpnBar &bar)
  {
   TpnResult r;
   TpnResultClear(r);
   r.active = e.set.enabled;
   r.type = e.set.type;
   r.barIndex = bar.index;
   r.updatedAt = bar.time;
   r.sbtLine = e.line;
   r.sampleCount = e.diffN;
   r.pivotIndex = e.hasLastPivot ? e.lastPivotIndex : -1;
   r.pivotPrice = e.hasLastPivot ? e.lastPivot : TPN_NA;
   double dist = TpnEngDistance(e);
   r.distance = (e.set.enabled && !TpnIsNa(dist)) ? dist : TPN_NA;
   if(e.set.enabled && e.hasLastPivot && !TpnIsNa(dist))
     {
      bool isLong = (bar.close > e.line);
      r.direction = isLong ? TPN_DIR_LONG : TPN_DIR_SHORT;
      r.level = isLong ? (e.lastPivot + dist) : (e.lastPivot - dist);
     }
   return(r);
  }

TpnResult TpnEngProcessBar(TpnEngine &e, const TpnBar &bar)
  {
   if(bar.index == e.lastProcessedIndex)
      return(TpnEngFillIdleResult(e, bar));

   TpnEngPushRing(e, e.highs, bar.high);
   TpnEngPushRing(e, e.lows, bar.low);

   double bbUp = TPN_NA, bbDn = TPN_NA;
   bool haveBands = TpnEngBands(e, bbUp, bbDn);

   double lineIn = e.line;
   bool longFlip = false;
   bool shortFlip = false;
   bool seriesMode = (e.set.crossMode == TPN_CROSS_SERIES);
   bool warm = (!e.hasPrevClose || !haveBands || (seriesMode && !e.hasPrevSeen));
   if(!warm)
     {
      double refPrev = seriesMode ? e.prevSeenLine : lineIn;
      longFlip  = (bar.close > lineIn && e.prevClose <= refPrev);
      shortFlip = (bar.close < lineIn && e.prevClose >= refPrev);
      if(longFlip && shortFlip)
        {
         longFlip = false;
         shortFlip = false;
        }
     }

   TpnEngPass(e, longFlip, bbDn, bar.low, bar.close, bar.index, haveBands, bbUp, bbDn);
   TpnEngPass(e, shortFlip, bbUp, bar.high, bar.close, bar.index, haveBands, bbUp, bbDn);

   ENUM_TPN_SIGNAL sig = TPN_SIG_NONE;
   if(longFlip)
      sig = TPN_SIG_LONG_FLIP;
   else if(shortFlip)
      sig = TPN_SIG_SHORT_FLIP;

   double dist = TpnEngDistance(e);
   bool isLong = (bar.close > e.line);
   double level = TPN_NA;
   bool hit = false;
   ENUM_TPN_DIRECTION dir = TPN_DIR_NONE;
   if(e.set.enabled && e.hasLastPivot && !TpnIsNa(dist))
     {
      dir = isLong ? TPN_DIR_LONG : TPN_DIR_SHORT;
      level = isLong ? (e.lastPivot + dist) : (e.lastPivot - dist);
      if(e.hasPrevHigh)
        {
         if(isLong)
            hit = (bar.high >= level && e.prevHigh < level);
         else
            hit = (bar.low <= level && e.prevLow > level);
        }
     }

   e.prevSeenLine = lineIn;
   e.hasPrevSeen = true;
   e.prevClose = bar.close;
   e.hasPrevClose = true;
   e.prevHigh = bar.high;
   e.hasPrevHigh = true;
   e.prevLow = bar.low;
   e.hasPrevLow = true;
   e.lastProcessedIndex = bar.index;

   TpnResult r;
   TpnResultClear(r);
   r.active = e.set.enabled;
   r.type = e.set.type;
   r.distance = (e.set.enabled && !TpnIsNa(dist)) ? dist : TPN_NA;
   r.level = e.set.enabled ? level : TPN_NA;
   r.direction = e.set.enabled ? dir : TPN_DIR_NONE;
   r.pivotIndex = e.hasLastPivot ? e.lastPivotIndex : -1;
   r.pivotPrice = e.hasLastPivot ? e.lastPivot : TPN_NA;
   r.hit = e.set.enabled ? hit : false;
   r.sampleCount = e.diffN;
   r.sbtLine = e.line;
   r.signal = sig;
   r.barIndex = bar.index;
   r.updatedAt = bar.time;
   return(r);
  }

void TpnEngBootstrap(TpnEngine &e, const TpnBar &bars[], const int n, TpnResult &out[])
  {
   ArrayResize(out, n);
   for(int i = 0; i < n; i++)
      out[i] = TpnEngProcessBar(e, bars[i]);
  }

bool TpnEngImportState(TpnEngine &e,
                       const double &highs[], const double &lows[], const int ringN,
                       const double line, const double prevSeen, const bool hasPrevSeen,
                       const double prevClose, const bool hasPrevClose,
                       const double prevHigh, const bool hasPrevHigh,
                       const double prevLow, const bool hasPrevLow,
                       const double lastPivot, const bool hasLastPivot, const int lastPivotIndex,
                       const double &diffs[], const int diffN, const int lastProcessedIndex)
  {
   TpnEngReset(e);
   if(ringN < 0 || ringN > TPN_RING_MAX || diffN < 0)
      return(false);
   e.ringN = ringN;
   for(int i = 0; i < ringN; i++)
     {
      e.highs[i] = highs[i];
      e.lows[i] = lows[i];
     }
   e.line = line;
   e.prevSeenLine = prevSeen;
   e.hasPrevSeen = hasPrevSeen;
   e.prevClose = prevClose;
   e.hasPrevClose = hasPrevClose;
   e.prevHigh = prevHigh;
   e.hasPrevHigh = hasPrevHigh;
   e.prevLow = prevLow;
   e.hasPrevLow = hasPrevLow;
   e.lastPivot = lastPivot;
   e.hasLastPivot = hasLastPivot;
   e.lastPivotIndex = lastPivotIndex;
   e.diffN = diffN;
   ArrayResize(e.diffs, diffN);
   for(int i = 0; i < diffN; i++)
      e.diffs[i] = diffs[i];
   TpnEngRebuildSorted(e);
   e.lastProcessedIndex = lastProcessedIndex;
   return(true);
  }

#endif // GSX_TP_NATIVE_ENGINE_MQH
