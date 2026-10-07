//+------------------------------------------------------------------+
//|                                                  DailyBias.mqh    |
//|  Chart-aligned D1 day-outcome bias: Daily (float) + Pre/Third.    |
//|  Pure math + D1 cache — no Trade / FollowDir side effects.        |
//+------------------------------------------------------------------+
#ifndef GSX_DAILY_BIAS_MQH
#define GSX_DAILY_BIAS_MQH

#define GSX_BIAS_NEUTRAL  0
#define GSX_BIAS_BULLISH  1
#define GSX_BIAS_BEARISH -1

#define GSX_BIAS_LANE_NONE  0
#define GSX_BIAS_LANE_DAILY 1
#define GSX_BIAS_LANE_PRE   2
#define GSX_BIAS_LANE_THIRD 3

#define GSX_BIAS_NEUTRAL_PCT 0.05
#define GSX_BIAS_D1_NEED     3   // need rates[0..2]: Daily / Pre-D / Third-D
#define GSX_BIAS_INTRADAY_THROTTLE_SEC 1

struct GsxBiasLeg
  {
   int    dir;       // GSX_BIAS_*
   int    strength;  // 0..100 (0 when neutral)
   double pivot;     // debug / UI continuity (classic P from H/L/C)
   double r1;
   double s1;
   double price;
  };

struct GsxBiasSnapshot
  {
   string symbol;
   GsxBiasLeg dailyIntraday; // alias of published Daily (forming outcome)
   GsxBiasLeg dailyClose;    // Pre-D bar outcome (debug / closed Y)
   GsxBiasLeg daily;         // published Daily — forming C/O outcome
   GsxBiasLeg preDay;        // hist shift 1
   GsxBiasLeg thirdDay;      // hist shift 2 (two bars back)
   datetime   d1Bar0;
   datetime   updatedAt;
   bool       valid;
  };

struct GsxBiasD1Cache
  {
   string   symbol;
   datetime bar0;
   datetime lastIntradayAt;
   MqlRates rates[];   // index 0 = forming, 1 = yesterday, …
   int      n;
   bool     ready;
   datetime histAtBar0;
   GsxBiasLeg histPre;
   GsxBiasLeg histThird;
   bool     histValid;
   GsxBiasLeg lastDaily;
   bool     lastDailyValid;
  };

void GsxBiasLegClear(GsxBiasLeg &leg)
  {
   leg.dir = GSX_BIAS_NEUTRAL;
   leg.strength = 0;
   leg.pivot = 0.0;
   leg.r1 = 0.0;
   leg.s1 = 0.0;
   leg.price = 0.0;
  }

void GsxBiasSnapshotClear(GsxBiasSnapshot &s)
  {
   s.symbol = "";
   GsxBiasLegClear(s.dailyIntraday);
   GsxBiasLegClear(s.dailyClose);
   GsxBiasLegClear(s.daily);
   GsxBiasLegClear(s.preDay);
   GsxBiasLegClear(s.thirdDay);
   s.d1Bar0 = 0;
   s.updatedAt = 0;
   s.valid = false;
  }

void GsxBiasD1CacheClear(GsxBiasD1Cache &c)
  {
   c.symbol = "";
   c.bar0 = 0;
   c.lastIntradayAt = 0;
   ArrayResize(c.rates, 0);
   c.n = 0;
   c.ready = false;
   c.histAtBar0 = 0;
   GsxBiasLegClear(c.histPre);
   GsxBiasLegClear(c.histThird);
   c.histValid = false;
   GsxBiasLegClear(c.lastDaily);
   c.lastDailyValid = false;
  }

string GsxBiasDirLabel(const int dir)
  {
   if(dir > 0) return("BULL");
   if(dir < 0) return("BEAR");
   return("NEUT");
  }

string GsxBiasLaneLabel(const int lane)
  {
   if(lane == GSX_BIAS_LANE_DAILY) return("Daily");
   if(lane == GSX_BIAS_LANE_PRE)   return("Pre-D");
   if(lane == GSX_BIAS_LANE_THIRD) return("Third-D");
   return("Signal");
  }

int GsxBiasLaneNormalize(const int lane)
  {
   if(lane == GSX_BIAS_LANE_DAILY || lane == GSX_BIAS_LANE_PRE || lane == GSX_BIAS_LANE_THIRD)
      return(lane);
   return(GSX_BIAS_LANE_NONE);
  }

//+------------------------------------------------------------------+
//| Pivot geometry (debug / optional fields — not published dir)       |
//+------------------------------------------------------------------+
void GsxBiasPivotFromHLC(const double h, const double l, const double c,
                         double &p, double &r1, double &s1)
  {
   p  = (h + l + c) / 3.0;
   r1 = 2.0 * p - l;
   s1 = 2.0 * p - h;
  }

double GsxBiasHalfSpan(const double p, const double r1, const double s1)
  {
   double up = MathAbs(r1 - p);
   double dn = MathAbs(p - s1);
   double span = MathMax(up, dn);
   if(span <= 0.0)
      return(0.0);
   return(span);
  }

int GsxBiasClassifyPrice(const double price, const double p, const double r1, const double s1,
                         int &strengthOut)
  {
   strengthOut = 0;
   double half = GsxBiasHalfSpan(p, r1, s1);
   if(half <= 0.0 || p <= 0.0)
      return(GSX_BIAS_NEUTRAL);

   double band = half * GSX_BIAS_NEUTRAL_PCT;
   double dist = price - p;
   if(MathAbs(dist) <= band)
      return(GSX_BIAS_NEUTRAL);

   int dir = (dist > 0.0 ? GSX_BIAS_BULLISH : GSX_BIAS_BEARISH);
   double ratio = MathAbs(dist) / half;
   if(ratio < 0.0) ratio = 0.0;
   if(ratio > 1.0) ratio = 1.0;
   strengthOut = (int)MathRound(ratio * 100.0);
   if(strengthOut < 1) strengthOut = 1;
   if(strengthOut > 100) strengthOut = 100;
   return(dir);
  }

void GsxBiasLegFromPrice(const double price, const double h, const double l, const double c,
                         GsxBiasLeg &out)
  {
   GsxBiasLegClear(out);
   out.price = price;
   GsxBiasPivotFromHLC(h, l, c, out.pivot, out.r1, out.s1);
   int str = 0;
   out.dir = GsxBiasClassifyPrice(price, out.pivot, out.r1, out.s1, str);
   out.strength = (out.dir == GSX_BIAS_NEUTRAL ? 0 : str);
  }

int GsxBiasOverallAgree(const int a, const int b)
  {
   if(a == GSX_BIAS_BULLISH && b == GSX_BIAS_BULLISH)
      return(GSX_BIAS_BULLISH);
   if(a == GSX_BIAS_BEARISH && b == GSX_BIAS_BEARISH)
      return(GSX_BIAS_BEARISH);
   return(GSX_BIAS_NEUTRAL);
  }

// Chart-aligned day outcome: closeOrMid vs open (D1 candle color).
// Doji/NEUT when |body| <= max(NEUTRAL_PCT * range, minAbsBand).
void GsxBiasLegFromBarOutcome(const double openPrice, const double high, const double low,
                              const double closeOrMid, GsxBiasLeg &out,
                              const double minAbsBand = 0.0)
  {
   GsxBiasLegClear(out);
   out.price = closeOrMid;
   GsxBiasPivotFromHLC(high, low, closeOrMid, out.pivot, out.r1, out.s1);

   if(openPrice <= 0.0 || closeOrMid <= 0.0)
      return;

   double range = high - low;
   if(range < 0.0) range = 0.0;
   double body = closeOrMid - openPrice;
   double band = GSX_BIAS_NEUTRAL_PCT * range;
   if(minAbsBand > band)
      band = minAbsBand;

   if(range <= 0.0 || MathAbs(body) <= band)
     {
      out.dir = GSX_BIAS_NEUTRAL;
      out.strength = 0;
      return;
     }

   out.dir = (body > 0.0 ? GSX_BIAS_BULLISH : GSX_BIAS_BEARISH);
   double ratio = MathAbs(body) / range;
   if(ratio > 1.0) ratio = 1.0;
   int str = (int)MathRound(ratio * 100.0);
   if(str < 1) str = 1;
   if(str > 100) str = 100;
   out.strength = str;
  }

// Legacy Agree helper (kept for Confirm / tests of pivot path — not used by published lanes).
void GsxBiasDayFromCloseAndPivots(const double close,
                                  const double ownH, const double ownL, const double ownC,
                                  const double priorH, const double priorL, const double priorC,
                                  GsxBiasLeg &out)
  {
   GsxBiasLeg legOwn;
   GsxBiasLeg legPrior;
   GsxBiasLegFromPrice(close, ownH, ownL, ownC, legOwn);
   GsxBiasLegFromPrice(close, priorH, priorL, priorC, legPrior);

   GsxBiasLegClear(out);
   out.price = close;
   out.pivot = legOwn.pivot;
   out.r1 = legOwn.r1;
   out.s1 = legOwn.s1;
   out.dir = GsxBiasOverallAgree(legOwn.dir, legPrior.dir);
   if(out.dir == GSX_BIAS_NEUTRAL)
      out.strength = 0;
   else
     {
      int s = (legOwn.strength + legPrior.strength) / 2;
      if(s < 1) s = 1;
      if(s > 100) s = 100;
      out.strength = s;
     }
  }

//+------------------------------------------------------------------+
//| D1 cache                                                           |
//+------------------------------------------------------------------+
bool GsxBiasD1CacheEnsure(GsxBiasD1Cache &c, const string symbol, const bool forceRates)
  {
   if(symbol == "")
      return(false);

   datetime bar0 = iTime(symbol, PERIOD_D1, 0);
   if(bar0 == 0)
     {
      c.ready = false;
      c.histValid = false;
      return(false);
     }

   bool sameSym = (c.symbol == symbol);
   bool sameBar = (sameSym && c.bar0 == bar0 && c.ready && c.n >= GSX_BIAS_D1_NEED);
   if(sameBar && !forceRates)
      return(true);

   MqlRates tmp[];
   int got = CopyRates(symbol, PERIOD_D1, 0, GSX_BIAS_D1_NEED + 2, tmp);
   if(got < GSX_BIAS_D1_NEED)
     {
      c.ready = false;
      c.histValid = false;
      return(false);
     }
   ArrayResize(c.rates, got);
   for(int i = 0; i < got; i++)
      c.rates[i] = tmp[got - 1 - i];

   if(!sameBar || forceRates)
      c.histValid = false;

   c.symbol = symbol;
   c.bar0 = bar0;
   c.n = got;
   c.ready = true;
   return(true);
  }

double GsxBiasLiveMid(const string symbol)
  {
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid > 0.0 && ask > 0.0)
      return(0.5 * (bid + ask));
   if(bid > 0.0)
      return(bid);
   double last = SymbolInfoDouble(symbol, SYMBOL_LAST);
   if(last > 0.0)
      return(last);
   return(0.0);
  }

double GsxBiasMinAbsBand(const string symbol)
  {
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(pt <= 0.0)
      return(0.0);
   return(pt * 10.0);
  }

// Historical closed D1 at shift s: that bar's open→close outcome (chart candle).
bool GsxBiasHistFromCache(const GsxBiasD1Cache &c, const int shift, GsxBiasLeg &out)
  {
   GsxBiasLegClear(out);
   if(!c.ready || shift < 1 || shift >= c.n)
      return(false);
   const MqlRates day = c.rates[shift];
   double minBand = GsxBiasMinAbsBand(c.symbol);
   GsxBiasLegFromBarOutcome(day.open, day.high, day.low, day.close, out, minBand);
   return(true);
  }

// Daily = forming D1 outcome: live mid vs today's open (floats with chart).
bool GsxBiasOverallFromCache(const GsxBiasD1Cache &c, const double liveMid, GsxBiasSnapshot &snap)
  {
   if(!c.ready || c.n < 1 || liveMid <= 0.0)
      return(false);

   const MqlRates t = c.rates[0];
   double h = t.high;
   double l = t.low;
   if(liveMid > h) h = liveMid;
   if(liveMid < l && liveMid > 0.0) l = liveMid;

   double minBand = GsxBiasMinAbsBand(c.symbol);
   GsxBiasLegFromBarOutcome(t.open, h, l, liveMid, snap.daily, minBand);
   snap.dailyIntraday = snap.daily;

   GsxBiasLegClear(snap.dailyClose);
   if(c.n >= 2)
     {
      const MqlRates y = c.rates[1];
      GsxBiasLegFromBarOutcome(y.open, y.high, y.low, y.close, snap.dailyClose, minBand);
     }
   return(true);
  }

// Full recompute. Daily throttled; Pre/Third only when D1 bar0 changes.
bool GsxBiasCompute(const string symbol, GsxBiasD1Cache &cache, GsxBiasSnapshot &out,
                    const bool forceRates = false)
  {
   GsxBiasSnapshotClear(out);
   out.symbol = symbol;
   if(!GsxBiasD1CacheEnsure(cache, symbol, forceRates))
      return(false);

   datetime now = TimeCurrent();
   bool needHist = forceRates || !cache.histValid || cache.histAtBar0 != cache.bar0;
   if(needHist)
     {
      GsxBiasHistFromCache(cache, 1, cache.histPre);   // Pre-D = rates[1]
      GsxBiasHistFromCache(cache, 2, cache.histThird); // Third-D = rates[2]
      cache.histAtBar0 = cache.bar0;
      cache.histValid = true;
     }
   out.preDay = cache.histPre;
   out.thirdDay = cache.histThird;

   bool throttleDaily = (!forceRates && cache.lastDailyValid &&
                         cache.lastIntradayAt > 0 &&
                         (now - cache.lastIntradayAt) < GSX_BIAS_INTRADAY_THROTTLE_SEC);
   if(throttleDaily)
     {
      out.daily = cache.lastDaily;
      out.dailyIntraday = cache.lastDaily;
     }
   else
     {
      double mid = GsxBiasLiveMid(symbol);
      if(mid <= 0.0 && cache.n > 0)
         mid = cache.rates[0].close;
      if(!GsxBiasOverallFromCache(cache, mid, out))
         return(false);
      cache.lastDaily = out.daily;
      cache.lastDailyValid = true;
      cache.lastIntradayAt = now;
     }

   out.d1Bar0 = cache.bar0;
   out.updatedAt = now;
   out.valid = true;
   return(true);
  }

int GsxBiasDirForLane(const GsxBiasSnapshot &snap, const int lane)
  {
   int L = GsxBiasLaneNormalize(lane);
   if(!snap.valid || L == GSX_BIAS_LANE_NONE)
      return(GSX_BIAS_NEUTRAL);
   if(L == GSX_BIAS_LANE_DAILY) return(snap.daily.dir);
   if(L == GSX_BIAS_LANE_PRE)   return(snap.preDay.dir);
   if(L == GSX_BIAS_LANE_THIRD) return(snap.thirdDay.dir);
   return(GSX_BIAS_NEUTRAL);
  }

int GsxBiasStrengthForLane(const GsxBiasSnapshot &snap, const int lane)
  {
   int L = GsxBiasLaneNormalize(lane);
   if(!snap.valid || L == GSX_BIAS_LANE_NONE)
      return(0);
   if(L == GSX_BIAS_LANE_DAILY) return(snap.daily.strength);
   if(L == GSX_BIAS_LANE_PRE)   return(snap.preDay.strength);
   if(L == GSX_BIAS_LANE_THIRD) return(snap.thirdDay.strength);
   return(0);
  }

// Pure OHLC unit-test path (no SymbolInfo).
// Daily: forming O/H/L + liveMid as close. Pre/Third: that day's O/H/L/C.
void GsxBiasComputeFromOhlc(const double dayOpen, const double dayHigh, const double dayLow,
                            const double liveMid,
                            const double preO, const double preH, const double preL, const double preC,
                            const double thirdO, const double thirdH, const double thirdL, const double thirdC,
                            GsxBiasSnapshot &out)
  {
   GsxBiasSnapshotClear(out);
   out.symbol = "TEST";
   double h = dayHigh;
   double l = dayLow;
   if(liveMid > h) h = liveMid;
   if(liveMid < l && liveMid > 0.0) l = liveMid;
   GsxBiasLegFromBarOutcome(dayOpen, h, l, liveMid, out.daily);
   out.dailyIntraday = out.daily;
   GsxBiasLegFromBarOutcome(preO, preH, preL, preC, out.dailyClose);
   GsxBiasLegFromBarOutcome(preO, preH, preL, preC, out.preDay);
   GsxBiasLegFromBarOutcome(thirdO, thirdH, thirdL, thirdC, out.thirdDay);
   out.valid = true;
   out.updatedAt = TimeCurrent();
  }

#endif // GSX_DAILY_BIAS_MQH
//+------------------------------------------------------------------+
