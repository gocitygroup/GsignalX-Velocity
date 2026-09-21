//+------------------------------------------------------------------+
//|                                                    Engines.mqh    |
//|  Per-symbol PP / SuperTrend / SuperBollingerTrend engine core     |
//+------------------------------------------------------------------+
#ifndef GSX_ENGINES_MQH
#define GSX_ENGINES_MQH

#define GSX_ENG_MODE_SIMPLE   0
#define GSX_ENG_MODE_ADVANCED 1

struct GsxEngineParams
  {
   bool   evalClosedBar;
   int    lookback;
   int    pivotPrd; double ppFactor; int ppAtrLen;
   int    stLen; double stMult; bool useMA; int maLen;
   int    bbLen; double bbMult;
   int    riskAtrLen;
   bool   trigPP, trigST, trigSBT;
  };

struct GsxEngineState
  {
   string   symbol;   // owning roster symbol — must match calc source
   int      tf;       // timeframe used for last successful calc
   int      ppDir[]; int stDir[]; int sbtDir[];
   double   ppLine[]; double stLine[]; double sbtLine[];
   double   ma[]; double atrRisk[];
   double   open[]; double high[]; double low[]; double close[];
   datetime barTime[];
   int      n;
   bool     ready;
   datetime lastBarTime; // last calculated bar open
   int      lastSigDir; int lastSigIdx;
   datetime lastSigChangeTime; // when lastSigDir last changed (staleness)
   string   status;
   // v2.15 tip retention (Core/Service): scalars survive after series freed
   bool     compacted;     // true when only tip (n<=1) retained
   double   lastClose;
   double   lastMa;
   double   lastAtrRisk;
   double   lastSigOpen;   // open of signal bar (or tip open)
   int      tipPpDir;
   int      tipStDir;
   int      tipSbtDir;
   double   tipPpLine;
   double   tipStLine;
   double   tipSbtLine;
  };

// Break MQL5 shared-buffer aliasing on arrays-of-structs with dynamic series.
void GsxEngStateDetach(GsxEngineState &st)
  {
   ArrayFree(st.ppDir);
   ArrayFree(st.stDir);
   ArrayFree(st.sbtDir);
   ArrayFree(st.ppLine);
   ArrayFree(st.stLine);
   ArrayFree(st.sbtLine);
   ArrayFree(st.ma);
   ArrayFree(st.atrRisk);
   ArrayFree(st.open);
   ArrayFree(st.high);
   ArrayFree(st.low);
   ArrayFree(st.close);
   ArrayFree(st.barTime);
  }

void GsxEngStateClearMeta(GsxEngineState &st)
  {
   st.symbol = "";
   st.tf = 0;
   st.n = 0;
   st.ready = false;
   st.lastBarTime = 0;
   st.lastSigDir = 0;
   st.lastSigIdx = -1;
   st.lastSigChangeTime = 0;
   st.status = "";
   st.compacted = false;
   st.lastClose = 0.0;
   st.lastMa = 0.0;
   st.lastAtrRisk = 0.0;
   st.lastSigOpen = 0.0;
   st.tipPpDir = 0;
   st.tipStDir = 0;
   st.tipSbtDir = 0;
   st.tipPpLine = 0.0;
   st.tipStLine = 0.0;
   st.tipSbtLine = 0.0;
  }

//+------------------------------------------------------------------+
//| V2.15: keep tip + scalars; free full lookback series (Core path) |
//+------------------------------------------------------------------+
void GsxEngStateCompactTip(GsxEngineState &st)
  {
   if(!st.ready || st.n < 1)
      return;
   if(st.compacted && st.n <= 1)
      return;

   int last = st.n - 1;
   st.tipPpDir  = (last < ArraySize(st.ppDir)  ? st.ppDir[last]  : 0);
   st.tipStDir  = (last < ArraySize(st.stDir)  ? st.stDir[last]  : 0);
   st.tipSbtDir = (last < ArraySize(st.sbtDir) ? st.sbtDir[last] : 0);
   st.tipPpLine  = (last < ArraySize(st.ppLine)  ? st.ppLine[last]  : 0.0);
   st.tipStLine  = (last < ArraySize(st.stLine)  ? st.stLine[last]  : 0.0);
   st.tipSbtLine = (last < ArraySize(st.sbtLine) ? st.sbtLine[last] : 0.0);
   st.lastClose   = (last < ArraySize(st.close)   ? st.close[last]   : 0.0);
   st.lastMa      = (last < ArraySize(st.ma)      ? st.ma[last]      : 0.0);
   st.lastAtrRisk = (last < ArraySize(st.atrRisk) ? st.atrRisk[last] : 0.0);
   if(st.lastSigIdx >= 0 && st.lastSigIdx < ArraySize(st.open) && st.open[st.lastSigIdx] > 0.0)
      st.lastSigOpen = st.open[st.lastSigIdx];
   else if(last < ArraySize(st.open))
      st.lastSigOpen = st.open[last];
   else
      st.lastSigOpen = 0.0;

   datetime tipBar = (last < ArraySize(st.barTime) ? st.barTime[last] : st.lastBarTime);
   double tipOpen  = (last < ArraySize(st.open)  ? st.open[last]  : 0.0);
   double tipHigh  = (last < ArraySize(st.high)  ? st.high[last]  : 0.0);
   double tipLow   = (last < ArraySize(st.low)   ? st.low[last]   : 0.0);

   GsxEngStateDetach(st);

   ArrayResize(st.ppDir, 1);  st.ppDir[0]  = st.tipPpDir;
   ArrayResize(st.stDir, 1);  st.stDir[0]  = st.tipStDir;
   ArrayResize(st.sbtDir, 1); st.sbtDir[0] = st.tipSbtDir;
   ArrayResize(st.ppLine, 1);  st.ppLine[0]  = st.tipPpLine;
   ArrayResize(st.stLine, 1);  st.stLine[0]  = st.tipStLine;
   ArrayResize(st.sbtLine, 1); st.sbtLine[0] = st.tipSbtLine;
   ArrayResize(st.ma, 1);      st.ma[0]      = st.lastMa;
   ArrayResize(st.atrRisk, 1); st.atrRisk[0] = st.lastAtrRisk;
   ArrayResize(st.close, 1);   st.close[0]   = st.lastClose;
   ArrayResize(st.open, 1);    st.open[0]    = tipOpen;
   ArrayResize(st.high, 1);    st.high[0]    = tipHigh;
   ArrayResize(st.low, 1);     st.low[0]     = tipLow;
   ArrayResize(st.barTime, 1); st.barTime[0] = tipBar;

   st.n = 1;
   st.lastSigIdx = (st.lastSigDir != 0 ? 0 : -1);
   st.compacted = true;
  }

// Rough series byte estimate (for cycle telemetry)
int GsxEngStateBytesEst(const GsxEngineState &st)
  {
   int n = st.n;
   if(n < 0) n = 0;
   // 6 int series + 7 double series approx (pp/st/sbt dir+line, ma, atr, ohlc, barTime)
   return(n * (6 * 4 + 7 * 8) + 64);
  }

double GsxEngTipAtr(const GsxEngineState &st)
  {
   if(st.lastAtrRisk > 0.0)
      return(st.lastAtrRisk);
   if(st.ready && st.n >= 1 && ArraySize(st.atrRisk) >= st.n)
      return(st.atrRisk[st.n - 1]);
   return(0.0);
  }

//+------------------------------------------------------------------+
//| File-local series helpers (avoid colliding with EA globals)      |
//+------------------------------------------------------------------+
void GsxEngSmaSeries(const double &src[], const int n, const int period, double &out[])
  {
   ArrayResize(out, n);
   ArrayInitialize(out, 0.0);
   if(period <= 0 || n < period)
      return;
   double sum = 0.0;
   for(int i = 0; i < n; i++)
     {
      sum += src[i];
      if(i >= period)
         sum -= src[i - period];
      if(i >= period - 1)
         out[i] = sum / period;
     }
  }

void GsxEngStdDevSeries(const double &src[], const int n, const int period, double &out[])
  {
   ArrayResize(out, n);
   ArrayInitialize(out, 0.0);
   if(period <= 1 || n < period)
      return;
   for(int i = period - 1; i < n; i++)
     {
      double mean = 0.0;
      for(int k = i - period + 1; k <= i; k++)
         mean += src[k];
      mean /= period;
      double acc = 0.0;
      for(int k = i - period + 1; k <= i; k++)
         acc += (src[k] - mean) * (src[k] - mean);
      out[i] = MathSqrt(acc / period);   // population stdev, matches Pine ta.stdev
     }
  }

// Wilder smoothing, matches Pine ta.atr / ta.rma
void GsxEngRmaSeries(const double &src[], const int n, const int period, double &out[])
  {
   ArrayResize(out, n);
   ArrayInitialize(out, 0.0);
   if(period <= 0 || n < period)
      return;
   double sum = 0.0;
   for(int i = 0; i < period; i++)
      sum += src[i];
   double prev = sum / period;
   out[period - 1] = prev;
   for(int i = period; i < n; i++)
     {
      prev = (prev * (period - 1) + src[i]) / period;
      out[i] = prev;
     }
  }

//+------------------------------------------------------------------+
//| True when bar-0 open time changed vs lastBarTime (then updates)  |
//+------------------------------------------------------------------+
bool GsxEngineNewBar(const string symbol, const ENUM_TIMEFRAMES tf, datetime &lastBarTime)
  {
   datetime t = iTime(symbol, tf, 0);
   if(t == 0)
      return(false);
   if(t == lastBarTime)
      return(false);
   lastBarTime = t;
   return(true);
  }

//+------------------------------------------------------------------+
//| Rebuild PP / ST / SBT engines for one symbol                     |
//+------------------------------------------------------------------+
bool GsxCalcEngines(const string symbol,
                    const ENUM_TIMEFRAMES tf,
                    const GsxEngineParams &p,
                    GsxEngineState &st)
  {
   int shift  = p.evalClosedBar ? 1 : 0;      // 1 = ignore the forming bar
   // v2.13: skip full rebuild when same symbol/TF bar already calculated
   datetime wantBar = iTime(symbol, tf, shift);
   if(st.ready && st.symbol == symbol && st.tf == (int)tf &&
      wantBar != 0 && st.lastBarTime == wantBar && st.n > 0)
     {
      st.status = "";
      return(true);
     }

   // Always detach first — ArrayResize(g_eng[]) can alias dynamic series
   // across slots so every pair would inherit the chart symbol's direction.
   GsxEngStateDetach(st);
   GsxEngStateClearMeta(st);
   st.status = "";

   if(symbol == "")
     {
      st.status = "empty symbol";
      return(false);
     }

   SymbolSelect(symbol, true);

   int want   = p.lookback;
   int warmup = p.bbLen + p.maLen + p.stLen + p.ppAtrLen + p.riskAtrLen + p.pivotPrd * 4 + 60;
   if(want < warmup + 100)
      want = warmup + 100;

   MqlRates r[];
   ArraySetAsSeries(r, false);                 // index 0 = oldest
   int n = CopyRates(symbol, tf, shift, want, r);
   if(n < warmup)
     {
      // Nudge terminal to pull history for off-chart symbols
      datetime times[];
      CopyTime(symbol, tf, shift, want, times);
      ArrayFree(r);
      n = CopyRates(symbol, tf, shift, want, r);
     }
   if(n < warmup)
     {
      st.status = "waiting for history (" + IntegerToString(n) + " bars)";
      st.symbol = symbol;
      st.tf = (int)tf;
      return(false);
     }

   double hi[], lo[], cl[], hl2[], tr[];
   ArrayResize(hi, n);  ArrayResize(lo, n);  ArrayResize(cl, n);
   ArrayResize(hl2, n); ArrayResize(tr, n);

   for(int i = 0; i < n; i++)
     {
      hi[i]  = r[i].high;
      lo[i]  = r[i].low;
      cl[i]  = r[i].close;
      hl2[i] = (r[i].high + r[i].low) / 2.0;
      if(i == 0)
         tr[i] = hi[i] - lo[i];
      else
        {
         double a = hi[i] - lo[i];
         double b = MathAbs(hi[i] - cl[i - 1]);
         double c = MathAbs(lo[i] - cl[i - 1]);
         tr[i] = MathMax(a, MathMax(b, c));
        }
     }

   double atrPP[], atrST[], atrRisk[], maArr[];
   GsxEngRmaSeries(tr, n, p.ppAtrLen,   atrPP);
   GsxEngRmaSeries(tr, n, p.stLen,      atrST);
   GsxEngRmaSeries(tr, n, p.riskAtrLen, atrRisk);
   GsxEngSmaSeries(cl, n, p.maLen,      maArr);

   double smaHi[], smaLo[], sdHi[], sdLo[];
   GsxEngSmaSeries(hi, n, p.bbLen, smaHi);
   GsxEngSmaSeries(lo, n, p.bbLen, smaLo);
   GsxEngStdDevSeries(hi, n, p.bbLen, sdHi);
   GsxEngStdDevSeries(lo, n, p.bbLen, sdLo);

   ArrayResize(st.ppDir, n);   ArrayResize(st.stDir, n);   ArrayResize(st.sbtDir, n);
   ArrayResize(st.ppLine, n);  ArrayResize(st.stLine, n);  ArrayResize(st.sbtLine, n);
   ArrayResize(st.ma, n);      ArrayResize(st.atrRisk, n);
   ArrayResize(st.close, n);   ArrayResize(st.barTime, n);
   ArrayResize(st.high, n);    ArrayResize(st.low, n);
   ArrayResize(st.open, n);

   //--- Engine 1 : PP SuperTrend -----------------------------------
   double center = 0.0;
   bool   haveCenter = false;
   double ppTU[], ppTD[];
   ArrayResize(ppTU, n); ArrayResize(ppTD, n);
   ArrayInitialize(ppTU, 0.0); ArrayInitialize(ppTD, 0.0);

   int prd = p.pivotPrd;
   for(int i = 0; i < n; i++)
     {
      //--- pivot confirmed at bar i refers to bar j = i - prd
      int j = i - prd;
      if(j - prd >= 0)
        {
         bool isPH = true, isPL = true;
         for(int k = j - prd; k <= j + prd; k++)
           {
            if(k == j)
               continue;
            if(hi[k] >= hi[j]) isPH = false;
            if(lo[k] <= lo[j]) isPL = false;
           }
         double lastpp = 0.0;
         bool   got    = false;
         if(isPH)      { lastpp = hi[j]; got = true; }
         else if(isPL) { lastpp = lo[j]; got = true; }
         if(got)
           {
            if(!haveCenter) { center = lastpp; haveCenter = true; }
            else            { center = (center * 2.0 + lastpp) / 3.0; }
           }
        }

      double up = 0.0, dn = 0.0;
      bool   valid = (haveCenter && atrPP[i] > 0.0);
      if(valid)
        {
         up = center - p.ppFactor * atrPP[i];
         dn = center + p.ppFactor * atrPP[i];
        }

      if(i == 0 || !valid)
        {
         ppTU[i]     = up;
         ppTD[i]     = dn;
         st.ppDir[i] = (i == 0) ? 1 : st.ppDir[i - 1];
        }
      else
        {
         double prevTU = (ppTU[i - 1] != 0.0) ? ppTU[i - 1] : up;
         double prevTD = (ppTD[i - 1] != 0.0) ? ppTD[i - 1] : dn;
         ppTU[i] = (cl[i - 1] > prevTU) ? MathMax(up, prevTU) : up;
         ppTD[i] = (cl[i - 1] < prevTD) ? MathMin(dn, prevTD) : dn;
         if(cl[i] > prevTD)      st.ppDir[i] =  1;
         else if(cl[i] < prevTU) st.ppDir[i] = -1;
         else                    st.ppDir[i] = st.ppDir[i - 1];
        }
      st.ppLine[i] = (st.ppDir[i] == 1) ? ppTU[i] : ppTD[i];
     }

   //--- Engine 2 : classic ATR SuperTrend --------------------------
   double stUp[], stDn[];
   ArrayResize(stUp, n); ArrayResize(stDn, n);
   ArrayInitialize(stUp, 0.0); ArrayInitialize(stDn, 0.0);
   for(int i = 0; i < n; i++)
     {
      bool valid = (atrST[i] > 0.0);
      double u = valid ? hl2[i] - p.stMult * atrST[i] : 0.0;
      double d = valid ? hl2[i] + p.stMult * atrST[i] : 0.0;
      if(i == 0 || !valid)
        {
         stUp[i]     = u;
         stDn[i]     = d;
         st.stDir[i] = (i == 0) ? 1 : st.stDir[i - 1];
        }
      else
        {
         double u1 = (stUp[i - 1] != 0.0) ? stUp[i - 1] : u;
         double d1 = (stDn[i - 1] != 0.0) ? stDn[i - 1] : d;
         stUp[i] = (cl[i - 1] > u1) ? MathMax(u, u1) : u;
         stDn[i] = (cl[i - 1] < d1) ? MathMin(d, d1) : d;
         int prev = st.stDir[i - 1];
         if(prev == -1 && cl[i] > d1)     st.stDir[i] =  1;
         else if(prev == 1 && cl[i] < u1) st.stDir[i] = -1;
         else                             st.stDir[i] = prev;
        }
      st.stLine[i] = (st.stDir[i] == 1) ? stUp[i] : stDn[i];
     }

   //--- Engine 3 : SuperBollingerTrend -----------------------------
   double line = 0.0;
   int    dir  = 1;
   bool   haveLine = false;
   for(int i = 0; i < n; i++)
     {
      bool valid = (smaHi[i] != 0.0 && smaLo[i] != 0.0 && i >= p.bbLen);
      if(!valid)
        {
         st.sbtLine[i] = 0.0;
         st.sbtDir[i]  = dir;
         continue;
        }
      double bbUp = smaHi[i] + sdHi[i] * p.bbMult;
      double bbDn = smaLo[i] - sdLo[i] * p.bbMult;

      if(!haveLine)
        {
         line = bbDn;
         dir  = 1;
         haveLine = true;
        }
      else
         if(dir == 1)
           {
            if(cl[i] < line) { line = bbUp; dir = -1; }
            else             { line = MathMax(line, bbDn); }
           }
         else
           {
            if(cl[i] > line) { line = bbDn; dir = 1; }
            else             { line = MathMin(line, bbUp); }
           }
      st.sbtLine[i] = line;
      st.sbtDir[i]  = dir;
     }

   for(int i = 0; i < n; i++)
     {
      st.ma[i]      = maArr[i];
      st.atrRisk[i] = atrRisk[i];
      st.close[i]   = cl[i];
      st.barTime[i] = r[i].time;
      st.open[i]    = r[i].open;
      st.high[i]    = hi[i];
      st.low[i]     = lo[i];
     }

   //--- most recent flip among the enabled trigger engines
   st.lastSigDir = 0;
   st.lastSigIdx = -1;
   for(int i = n - 1; i >= 1 && st.lastSigIdx < 0; i--)
     {
      bool up = (p.trigPP  && st.ppDir[i]  ==  1 && st.ppDir[i - 1]  == -1) ||
                (p.trigST  && st.stDir[i]  ==  1 && st.stDir[i - 1]  == -1) ||
                (p.trigSBT && st.sbtDir[i] ==  1 && st.sbtDir[i - 1] == -1);
      bool dw = (p.trigPP  && st.ppDir[i]  == -1 && st.ppDir[i - 1]  ==  1) ||
                (p.trigST  && st.stDir[i]  == -1 && st.stDir[i - 1]  ==  1) ||
                (p.trigSBT && st.sbtDir[i] == -1 && st.sbtDir[i - 1] ==  1);
      if(up || dw)
        {
         st.lastSigDir = up ? 1 : -1;
         st.lastSigIdx = i;
        }
     }

   st.n = n;
   st.lastBarTime = r[n - 1].time;
   if(st.lastSigIdx >= 0 && st.lastSigIdx < n)
      st.lastSigChangeTime = st.barTime[st.lastSigIdx];
   else
      st.lastSigChangeTime = 0;
   st.symbol = symbol;
   st.tf = (int)tf;
   st.ready = true;
   st.status = "ok";
   st.compacted = false;
   // Tip scalars populated even before CompactTip (EntryExec / bus can use them)
   st.tipPpDir  = st.ppDir[n - 1];
   st.tipStDir  = st.stDir[n - 1];
   st.tipSbtDir = st.sbtDir[n - 1];
   st.tipPpLine  = st.ppLine[n - 1];
   st.tipStLine  = st.stLine[n - 1];
   st.tipSbtLine = st.sbtLine[n - 1];
   st.lastClose   = st.close[n - 1];
   st.lastMa      = st.ma[n - 1];
   st.lastAtrRisk = st.atrRisk[n - 1];
   if(st.lastSigIdx >= 0 && st.open[st.lastSigIdx] > 0.0)
      st.lastSigOpen = st.open[st.lastSigIdx];
   else
      st.lastSigOpen = st.open[n - 1];
   return(true);
  }

//+------------------------------------------------------------------+
//| Active direction under bot entry rules (agreement + MA + triggers)|
//| modeSimpleOrAdv: 0 = simple, 1 = advanced                        |
//+------------------------------------------------------------------+
int GsxActiveDirectionUnderRules(const GsxEngineState &st,
                                 const int i,
                                 const bool trigPP,
                                 const bool trigST,
                                 const bool trigSBT,
                                 const bool useMA,
                                 const int modeSimpleOrAdv,
                                 const int minAgree,
                                 string &skipWhy)
  {
   skipWhy = "";
   if(i < 0 || i >= st.n)
      return(0);

   bool trigBull = true, trigBear = true;
   bool anyTrig  = false;
   if(trigPP)
     {
      anyTrig = true;
      if(st.ppDir[i] != 1)  trigBull = false;
      if(st.ppDir[i] != -1) trigBear = false;
     }
   if(trigST)
     {
      anyTrig = true;
      if(st.stDir[i] != 1)  trigBull = false;
      if(st.stDir[i] != -1) trigBear = false;
     }
   if(trigSBT)
     {
      anyTrig = true;
      if(st.sbtDir[i] != 1)  trigBull = false;
      if(st.sbtDir[i] != -1) trigBear = false;
     }
   if(!anyTrig)
     {
      skipWhy = "no triggers";
      return(0);
     }

   double c  = st.close[i];
   double ma = st.ma[i];
   bool maLongOK  = (!useMA || ma <= 0.0 || c > ma);
   bool maShortOK = (!useMA || ma <= 0.0 || c < ma);

   int bull = (st.ppDir[i] == 1 ? 1 : 0) + (st.stDir[i] == 1 ? 1 : 0) + (st.sbtDir[i] == 1 ? 1 : 0);
   int bear = 3 - bull;
   bool agreeLong  = (modeSimpleOrAdv == GSX_ENG_MODE_SIMPLE) || (bull >= minAgree);
   bool agreeShort = (modeSimpleOrAdv == GSX_ENG_MODE_SIMPLE) || (bear >= minAgree);

   int wanted = 0;
   if(trigBull && maLongOK && agreeLong)
      wanted = 1;
   else
      if(trigBear && maShortOK && agreeShort)
         wanted = -1;

   if(wanted == 0)
     {
      if(trigBull && !maLongOK)        skipWhy = "MA filter";
      else if(trigBear && !maShortOK)  skipWhy = "MA filter";
      else if(trigBull && !agreeLong)  skipWhy = "engines disagree";
      else if(trigBear && !agreeShort) skipWhy = "engines disagree";
      else                             skipWhy = "no active direction";
     }
   return(wanted);
  }

// Majority among enabled triggers only (ignore disabled engines).
int GsxEnabledTriggerMajority(const GsxEngineState &st,
                              const int i,
                              const bool trigPP,
                              const bool trigST,
                              const bool trigSBT)
  {
   if(i < 0 || i >= st.n)
      return(0);
   int bull = 0, bear = 0, n = 0;
   if(trigPP)
     {
      n++;
      if(st.ppDir[i] == 1) bull++;
      else if(st.ppDir[i] == -1) bear++;
     }
   if(trigST)
     {
      n++;
      if(st.stDir[i] == 1) bull++;
      else if(st.stDir[i] == -1) bear++;
     }
   if(trigSBT)
     {
      n++;
      if(st.sbtDir[i] == 1) bull++;
      else if(st.sbtDir[i] == -1) bear++;
     }
   if(n <= 0)
      return(0);
   if(bull > bear)
      return(1);
   if(bear > bull)
      return(-1);
   return(0);
  }

//+------------------------------------------------------------------+
//| Prefetch history for off-chart symbols (ADD / cold start) v2.13  |
//+------------------------------------------------------------------+
void GsxEngPrefetchHistory(const string symbol, const ENUM_TIMEFRAMES tf, const int bars)
  {
   if(symbol == "")
      return;
   SymbolSelect(symbol, true);
   int want = MathMax(bars, 200);
   datetime times[];
   CopyTime(symbol, tf, 0, want, times);
   MqlRates r[];
   CopyRates(symbol, tf, 0, want, r);
  }

#endif // GSX_ENGINES_MQH
//+------------------------------------------------------------------+
