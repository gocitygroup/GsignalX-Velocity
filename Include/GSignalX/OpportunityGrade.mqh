//+------------------------------------------------------------------+
//|                                       OpportunityGrade.mqh        |
//|  Pure scoring for entry (swing/scale) and harvest opportunities   |
//+------------------------------------------------------------------+
#ifndef GSX_OPPORTUNITY_GRADE_MQH
#define GSX_OPPORTUNITY_GRADE_MQH

struct GsxEntryInputs
  {
   int    direction;       // 1 long, -1 short, 0 flat
   int    bull;
   int    bear;
   int    min_agree;
   bool   in_session;
   bool   weekend;
   bool   friday_late;
   bool   swing_window;
   int    spread_pt;
   int    max_spread_pt;
   bool   stale_tick;
   bool   market_open;
  };

struct GsxHarvestInputs
  {
   double profit;
   double peak;
   bool   armed;
   double target;
   double trail_give;
   int    age_min;
   int    window_start;
   int    window_end;
   double free_margin;
   double floating;
   int    spread_pt;
   bool   in_session;
  };

struct GsxGradeResult
  {
   double score;
   string reasons;
  };

double GsxClamp01(const double x)
  {
   if(x < 0.0)
      return 0.0;
   if(x > 1.0)
      return 1.0;
   return x;
  }

void GsxAddReason(string &reasons, const string tag)
  {
   if(reasons == "")
      reasons = tag;
   else
      reasons += ";" + tag;
  }

GsxGradeResult GsxGradeEntry(const GsxEntryInputs &in)
  {
   GsxGradeResult r;
   r.score = 0.0;
   r.reasons = "";

   if(in.direction == 0)
     {
      r.reasons = "no_signal";
      return r;
     }

   int agreeSide = (in.direction > 0 ? in.bull : in.bear);
   double agreeFrac = 0.0;
   if(in.min_agree > 0)
      agreeFrac = GsxClamp01((double)agreeSide / (double)MathMax(in.min_agree, 1));
   else
      agreeFrac = GsxClamp01((double)agreeSide / 3.0);
   r.score += 30.0 * agreeFrac;
   if(agreeFrac >= 1.0)
      GsxAddReason(r.reasons, "agree");

   double sessionPts = 0.0;
   if(in.weekend || in.friday_late)
      sessionPts = 0.0;
   else
      if(in.in_session)
        {
         sessionPts = 1.0;
         GsxAddReason(r.reasons, "session");
        }
      else
         sessionPts = 0.35;
   r.score += 25.0 * sessionPts;

   if(in.swing_window)
     {
      r.score += 20.0;
      GsxAddReason(r.reasons, "swing");
     }

   double spreadPts = 1.0;
   if(in.max_spread_pt > 0)
     {
      if(in.spread_pt <= 0)
         spreadPts = 1.0;
      else
         if(in.spread_pt >= in.max_spread_pt)
            spreadPts = 0.0;
         else
            spreadPts = 1.0 - (double)in.spread_pt / (double)in.max_spread_pt;
     }
   r.score += 15.0 * spreadPts;
   if(spreadPts >= 0.7)
      GsxAddReason(r.reasons, "spread_ok");

   double tickPts = 0.0;
   if(in.market_open && !in.stale_tick)
     {
      tickPts = 1.0;
      GsxAddReason(r.reasons, "fresh");
     }
   else
      if(in.market_open)
         tickPts = 0.4;
   r.score += 10.0 * tickPts;

   if(r.score > 100.0)
      r.score = 100.0;
   return r;
  }

GsxGradeResult GsxGradeHarvest(const GsxHarvestInputs &in)
  {
   GsxGradeResult r;
   r.score = 0.0;
   r.reasons = "";

   double progress = 0.0;
   if(in.target > 0.0 && in.profit > 0.0)
      progress = GsxClamp01(in.profit / in.target);
   r.score += 35.0 * progress;
   if(progress >= 0.8)
      GsxAddReason(r.reasons, "near_target");
   else
      if(progress >= 0.4)
         GsxAddReason(r.reasons, "profit_building");

   double trailPts = 0.0;
   if(in.armed && in.peak > 0.0)
     {
      double drop = in.peak - in.profit;
      if(drop < 0.0)
         drop = 0.0;
      double give = (in.trail_give > 0.0 ? in.trail_give : in.peak * 0.3);
      if(give <= 0.0)
         give = 1.0;
      trailPts = GsxClamp01(1.0 - drop / give);
      GsxAddReason(r.reasons, "armed");
     }
   r.score += 25.0 * trailPts;

   double winPts = 0.0;
   if(in.window_end > in.window_start)
     {
      if(in.age_min >= in.window_start && in.age_min <= in.window_end)
        {
         winPts = 1.0;
         GsxAddReason(r.reasons, "in_window");
        }
      else
         if(in.age_min < in.window_start)
            winPts = 0.35;
         else
            winPts = 0.55;
     }
   else
      winPts = 0.5;
   r.score += 20.0 * winPts;

   double heat = 1.0;
   if(in.free_margin > 0.0 && in.floating < 0.0)
     {
      double ratio = MathAbs(in.floating) / in.free_margin;
      heat = 1.0 - GsxClamp01(ratio);
     }
   r.score += 10.0 * heat;

   double liq = (in.in_session ? 1.0 : 0.4);
   if(in.spread_pt > 80)
      liq *= 0.5;
   else
      if(in.spread_pt > 40)
         liq *= 0.75;
   r.score += 10.0 * liq;

   if(r.score > 100.0)
      r.score = 100.0;
   return r;
  }

bool GsxInSwingWindow(const datetime t, const int startHour, const int endHour)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int h = dt.hour;
   if(startHour == endHour)
      return true;
   if(startHour < endHour)
      return (h >= startHour && h < endHour);
   return (h >= startHour || h < endHour);
  }

#endif
//+------------------------------------------------------------------+
