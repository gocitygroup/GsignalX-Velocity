//+------------------------------------------------------------------+
//|                                        ProfitScouter/AtrTrail.mqh |
//|  Independent ATR/% candle auto-trail for winning tickets.         |
//|  Include from Core.mqh AFTER LivePos/PosRec globals + CloseTicket.|
//|  Does not alter Profit CASH / LAYER money TrailStep paths.        |
//+------------------------------------------------------------------+
#ifndef PS_ATR_TRAIL_MQH
#define PS_ATR_TRAIL_MQH

#include <GSignalX/CandleMetrics.mqh>
#include <GSignalX/ScoutLink.mqh>
#include <GSignalX/SettingsNotify.mqh>

// Globals gAtrTrailEnabled / g_atrTrail* live in Core.mqh (declared before Monitor).

// Packed optimizer GV: value = effective_mult; companion EMA in PS{id}_OPTE_{canon}
string PsAtrOptMultVar(const string canon)
  {
   return(StringFormat("%sOPT_%s", g_prefix, canon));
  }

string PsAtrOptEmaVar(const string canon)
  {
   return(StringFormat("%sOPTE_%s", g_prefix, canon));
  }

double PsAtrTrailClampMult(const double m)
  {
   double lo = MathMin(InpAtrTrailMultMin, InpAtrTrailMultMax);
   double hi = MathMax(InpAtrTrailMultMin, InpAtrTrailMultMax);
   if(m < lo) return(lo);
   if(m > hi) return(hi);
   return(m);
  }

double PsAtrTrailEffectiveMult(const string canon)
  {
   double base = InpAtrTrailMult;
   if(!InpAtrTrailOptimize || canon == "")
     {
      g_atrTrailLastMultEff = base;
      return(base);
     }
   string n = PsAtrOptMultVar(canon);
   if(GlobalVariableCheck(n))
     {
      double m = PsAtrTrailClampMult(GlobalVariableGet(n));
      g_atrTrailLastMultEff = m;
      return(m);
     }
   g_atrTrailLastMultEff = base;
   return(base);
  }

void PsAtrTrailOptimizerUpdate(const string canon,
                               const double peak,
                               const double banked,
                               const double trailDist)
  {
   if(!InpAtrTrailOptimize || canon == "" || peak <= 0.0 || trailDist <= 0.0)
      return;

   // Reward: fraction of peak retained; higher → widen trail slightly; low → tighten
   double reward = banked / peak;
   if(reward < 0.0) reward = 0.0;
   if(reward > 1.0) reward = 1.0;

   string emaN = PsAtrOptEmaVar(canon);
   string mulN = PsAtrOptMultVar(canon);
   double alpha = InpAtrTrailOptAlpha;
   if(alpha < 0.01) alpha = 0.01;
   if(alpha > 1.0)  alpha = 1.0;

   double ema = reward;
   if(GlobalVariableCheck(emaN))
      ema = (1.0 - alpha) * GlobalVariableGet(emaN) + alpha * reward;
   GlobalVariableSet(emaN, ema);

   double mult = InpAtrTrailMult;
   if(GlobalVariableCheck(mulN))
      mult = GlobalVariableGet(mulN);

   // Target mult rises with reward (keep winners longer), falls when give-back burns peak
   double target = InpAtrTrailMultMin + (InpAtrTrailMultMax - InpAtrTrailMultMin) * ema;
   mult = (1.0 - alpha) * mult + alpha * target;
   mult = PsAtrTrailClampMult(mult);
   GlobalVariableSet(mulN, mult);
   g_atrTrailLastMultEff = mult;
  }

ENUM_TIMEFRAMES PsAtrTrailTf()
  {
   ENUM_TIMEFRAMES tf = InpAtrTrailTf;
#ifdef PS_HOST_EA
   if(tf == PERIOD_CURRENT)
      tf = (ENUM_TIMEFRAMES)Period();
#endif
#ifdef PS_HOST_SERVICE
   if(tf == PERIOD_CURRENT)
      tf = PERIOD_M5;
#endif
   return(tf);
  }

double PsAtrTrailArmFloor()
  {
   if(InpAtrTrailArmMoney > 0.0)
      return Money(InpAtrTrailArmMoney);
   return MinWinFloorMoney();
  }

// Money distance for trail give-back on one ticket.
double PsAtrTrailDistanceMoney(const string sym, const double volume, const double peak)
  {
   if(peak <= 0.0 || volume <= 0.0 || sym == "")
      return(0.0);

   string canon = GsxSymbolCanon(sym);
   double mult  = PsAtrTrailEffectiveMult(canon);
   ENUM_TIMEFRAMES tf = PsAtrTrailTf();

   double atrPts = GsxAtrPoints(sym, tf, MathMax(1, InpAtrTrailPeriod));
   double atrMoney = GsxPointsToMoney(sym, atrPts * mult, volume);

   int nCand = MathMax(1, InpAtrTrailCandles);
   double avgRangePts = GsxAvgClosedRangePts(sym, tf, nCand);
   double candleMoney = GsxPointsToMoney(sym, avgRangePts * mult, volume);

   double atrDist = MathMax(atrMoney, candleMoney);

   double pctDist = 0.0;
   if(InpAtrTrailPct > 0.0)
      pctDist = peak * InpAtrTrailPct / 100.0;

   if(InpAtrTrailMode == PS_ATR_TRAIL_ATR)
      return atrDist;
   if(InpAtrTrailMode == PS_ATR_TRAIL_PERCENT)
      return pctDist;
   // Hybrid: max distance (wider protection)
   return MathMax(atrDist, pctDist);
  }

bool PsAtrTrailShouldFire(const int liveIdx, double &trailDistOut)
  {
   trailDistOut = 0.0;
   if(liveIdx < 0 || liveIdx >= ArraySize(g_live))
      return(false);

   double profit = g_live[liveIdx].profit;
   if(profit <= 0.0)
      return(false);
   if(!TrailCloseAllowed(profit))
      return(false);

   int r = PosIndex(g_live[liveIdx].ticket, false);
   if(r < 0)
      return(false);

   double peak = g_pos[r].peak;
   double arm  = PsAtrTrailArmFloor();
   if(peak < arm)
      return(false);

   double dist = PsAtrTrailDistanceMoney(g_live[liveIdx].sym, g_live[liveIdx].volume, peak);
   if(dist <= 0.0)
      return(false);
   trailDistOut = dist;

   double drop = peak - profit;
   return(drop >= dist);
  }

// Independent ATR/% trail — closes green tickets on give-back. Returns true if any closed.
bool HandleAtrTrailProfit()
  {
   g_atrTrailClosedCycle = 0;
   if(!gAtrTrailEnabled)
      return(false);
   if(!gScoutEnabled || !g_closerAllows)
      return(false);

   bool any = false;
   int n = ArraySize(g_live);
   // Biggest winners first so we bank strongest peaks when multiple fire
   int idxs[];
   ArrayResize(idxs, n);
   int m = 0;
   for(int i = 0; i < n; i++)
     {
      if(g_live[i].profit > 0.0)
         idxs[m++] = i;
     }
   ArrayResize(idxs, m);
   SortIdxsByProfit(idxs, m, true);

   for(int k = 0; k < m; k++)
     {
      int li = idxs[k];
      double dist = 0.0;
      if(!PsAtrTrailShouldFire(li, dist))
         continue;

      ulong  ticket = g_live[li].ticket;
      string sym    = g_live[li].sym;
      double profit = g_live[li].profit;
      int    r      = PosIndex(ticket, false);
      double peak   = (r >= 0 ? g_pos[r].peak : profit);

      if(CloseTicket(ticket, "ATR-TRAIL", false))
        {
         g_atrTrailClosedCycle++;
         g_atrTrailLastSym = sym;
         PsAtrTrailOptimizerUpdate(GsxSymbolCanon(sym), peak, profit, dist);
         g_lastAction = StringFormat("ATR-TRAIL #%I64u %s banked=%.2f peak=%.2f dist=%.2f mult=%.2f",
                                     ticket, sym, profit, peak, dist, g_atrTrailLastMultEff);
         Notify(g_lastAction);
         any = true;
        }
     }

   if(any)
      CompactLiveKeepOpen();
   return(any);
  }

void PsLoadAtrTrailEnabled()
  {
   string n = GsxScoutTrailVarName(InpInstanceID);
   if(GlobalVariableCheck(n))
     {
      gAtrTrailEnabled = GsxScoutTrailGet(InpInstanceID, false);
      return;
     }
   gAtrTrailEnabled = InpAtrTrailEnable;
   GsxScoutTrailSet(InpInstanceID, gAtrTrailEnabled);
  }

void PsSetAtrTrailEnabled(const bool on, const bool announce)
  {
   gAtrTrailEnabled = on;
   GsxScoutTrailSet(InpInstanceID, on);
   g_lastAction = on ? "ATR TRAIL ON" : "ATR TRAIL OFF";
#ifdef PS_HOST_EA
   g_psLastFp = "";
#endif
   if(announce)
     {
      Notify(on
             ? StringFormat("TRAIL ON: ATR/%% auto-trail armed (mult=%.2f N=%d)",
                            InpAtrTrailMult, InpAtrTrailCandles)
             : "TRAIL OFF: ATR/%% auto-trail paused (CASH/LAYER/AUTO unchanged)");
      long magic = (InpUseMagicFilter && InpMagicNumber > 0) ? InpMagicNumber : InpMagicNumber;
      GsxSettingsPendingSetScout(InpInstanceID, magic, on ? "TRAIL ON" : "TRAIL OFF");
     }
#ifdef PS_HOST_EA
   PsUpdateButtons();
   ChartRedraw();
#endif
  }

#endif // PS_ATR_TRAIL_MQH
//+------------------------------------------------------------------+
