//+------------------------------------------------------------------+
//|                                              PracticeSim.mqh      |
//|  Practice / live micro-account coach profiles (20/50/100).         |
//|  Standard vs Raw cost models × Scalp / Day / Swing.               |
//|  Pure helpers — no Inp* reads, no virtual balance.                |
//|  Authoritative money knobs remain in .set presets.                |
//+------------------------------------------------------------------+
#ifndef GSX_PRACTICE_SIM_MQH
#define GSX_PRACTICE_SIM_MQH

enum ENUM_GSX_PRACTICE_BAND
  {
   GSX_PRAC_BAND_20  = 20,
   GSX_PRAC_BAND_50  = 50,
   GSX_PRAC_BAND_100 = 100
  };

enum ENUM_GSX_COST_MODEL
  {
   GSX_COST_RAW      = 0,
   GSX_COST_STANDARD = 1
  };

enum ENUM_GSX_TRADE_STYLE
  {
   GSX_STYLE_SCALP = 0,
   GSX_STYLE_DAY   = 1,
   GSX_STYLE_SWING = 2
  };

//+------------------------------------------------------------------+
struct GsxPracticeProfile
  {
   int    band;                 // 20 / 50 / 100
   int    cost;                 // ENUM_GSX_COST_MODEL
   int    style;                // ENUM_GSX_TRADE_STYLE
   double balanceNotional;      // account currency units
   double riskPct;
   double maxLot;
   int    fleetTarget;
   double dailyLossMoney;
   double dailyProfitTarget;
   int    maxTradesDay;
   int    maxSpreadPt;
   double asapFloor;
   double lockArm;
   double minWin;
   bool   includeCommission;
   int    softCat;              // 0=ALL 1=FX 2=CMD 3=CR (matches GSX_CAT_*)
   int    lossBudget;           // consecutive losers before daily halt
   string primaryPairsCsv;
   string secondaryPairsCsv;
   string sessionHint;
   string tfHint;
   string expectancyNote;
   string label;                // e.g. "100 RAW DAY"
  };

//+------------------------------------------------------------------+
string GsxPracticeBandLabel(const int band)
  {
   if(band == GSX_PRAC_BAND_20)  return("20");
   if(band == GSX_PRAC_BAND_50)  return("50");
   if(band == GSX_PRAC_BAND_100) return("100");
   return("?");
  }

string GsxPracticeCostLabel(const int cost)
  {
   if(cost == GSX_COST_STANDARD) return("STD");
   return("RAW");
  }

string GsxPracticeStyleLabel(const int style)
  {
   if(style == GSX_STYLE_SCALP) return("SCALP");
   if(style == GSX_STYLE_SWING) return("SWING");
   return("DAY");
  }

int GsxPracticeBandNormalize(const int band)
  {
   if(band == GSX_PRAC_BAND_20 || band == GSX_PRAC_BAND_50 || band == GSX_PRAC_BAND_100)
      return(band);
   return(GSX_PRAC_BAND_100);
  }

int GsxPracticeCostNormalize(const int cost)
  {
   if(cost == GSX_COST_STANDARD)
      return(GSX_COST_STANDARD);
   return(GSX_COST_RAW);
  }

int GsxPracticeStyleNormalize(const int style)
  {
   if(style == GSX_STYLE_SCALP || style == GSX_STYLE_SWING)
      return(style);
   return(GSX_STYLE_DAY);
  }

//+------------------------------------------------------------------+
void GsxPracticeBuild(const int bandIn,
                      const int costIn,
                      const int styleIn,
                      GsxPracticeProfile &out)
  {
   int band  = GsxPracticeBandNormalize(bandIn);
   int cost  = GsxPracticeCostNormalize(costIn);
   int style = GsxPracticeStyleNormalize(styleIn);
   bool raw  = (cost == GSX_COST_RAW);

   out.band = band;
   out.cost = cost;
   out.style = style;
   out.balanceNotional = (double)band;
   out.riskPct = 1.0;
   out.includeCommission = raw;
   out.softCat = 1; // FX
   out.secondaryPairsCsv = "";
   out.primaryPairsCsv = "EURUSD";
   out.tfHint = "M5";
   out.sessionHint = "07-20 FX";
   out.expectancyNote = "E>=0.15R before scale";

   // --- Band money / fleet geometry (Day defaults; style adjusts) ---
   if(band == GSX_PRAC_BAND_20)
     {
      out.dailyLossMoney = 1.00;
      out.dailyProfitTarget = 0.40;
      out.maxLot = 0.01;
      out.fleetTarget = 1;
      out.maxTradesDay = 2;
      out.primaryPairsCsv = "EURUSD";
      out.secondaryPairsCsv = raw ? "GBPUSD watch" : "none — STD scalp hostile";
      out.asapFloor = raw ? 0.20 : 0.40;
      out.lockArm   = raw ? 0.20 : 0.40;
      out.minWin    = raw ? 0.10 : 0.20;
      out.maxSpreadPt = raw ? 25 : 50;
     }
   else if(band == GSX_PRAC_BAND_50)
     {
      out.dailyLossMoney = 2.00;
      out.dailyProfitTarget = 1.00;
      out.maxLot = 0.02;
      out.fleetTarget = 2;
      out.maxTradesDay = 3;
      out.primaryPairsCsv = "EURUSD,GBPUSD";
      out.secondaryPairsCsv = "USDJPY watch · CMD/CR off";
      out.asapFloor = raw ? 0.50 : 0.80;
      out.lockArm   = raw ? 0.50 : 0.80;
      out.minWin    = raw ? 0.25 : 0.40;
      out.maxSpreadPt = raw ? 25 : 45;
     }
   else // 100
     {
      out.dailyLossMoney = 3.50;
      out.dailyProfitTarget = 1.50;
      out.maxLot = 0.10;
      out.fleetTarget = 2;
      out.maxTradesDay = 4;
      out.primaryPairsCsv = "EURUSD,GBPUSD";
      out.secondaryPairsCsv = "XAUUSD optional · BTC/ETH watch only";
      out.asapFloor = raw ? 1.00 : 1.50;
      out.lockArm   = raw ? 1.00 : 1.50;
      out.minWin    = raw ? 0.50 : 0.75;
      out.maxSpreadPt = raw ? 25 : 40;
      out.softCat = 0; // ALL
     }

   // --- Style overlays ---
   if(style == GSX_STYLE_SCALP)
     {
      out.tfHint = "M5";
      out.sessionHint = "LDN·NY overlap";
      out.maxTradesDay = (band == GSX_PRAC_BAND_20 ? 4 :
                          (band == GSX_PRAC_BAND_50 ? 6 : 8));
      if(band == GSX_PRAC_BAND_50)
         out.fleetTarget = 1;
      if(!raw && band < GSX_PRAC_BAND_100)
        {
         out.expectancyNote = "STD+SCALP: prefer Day · spread eats edge";
         out.sessionHint = "LDN·NY only if spread OK";
        }
      else
         out.expectancyNote = "Scalp: bank ASAP · cut losers fast";
     }
   else if(style == GSX_STYLE_SWING)
     {
      out.tfHint = "M15";
      out.sessionHint = "grade 12-17";
      out.maxTradesDay = (band == GSX_PRAC_BAND_100 ? 2 : 1);
      out.fleetTarget = MathMin(out.fleetTarget, (band == GSX_PRAC_BAND_20 ? 1 : 2));
      out.expectancyNote = "Swing: fewer fills · hold R>=1.5";
      if(band >= GSX_PRAC_BAND_100)
         out.secondaryPairsCsv = "AUDUSD/USDJPY watch · CR off";
     }
   else // DAY
     {
      out.tfHint = "M5";
      out.sessionHint = "07-20 · avoid Asia FX";
      out.expectancyNote = "Day default · load matching .set";
     }

   // Effective per-trade risk estimate (min-lot dominated)
   double perTradeRisk = MathMax(0.25, out.asapFloor);
   if(band == GSX_PRAC_BAND_20)
      perTradeRisk = MathMax(0.50, out.asapFloor);
   else if(band == GSX_PRAC_BAND_50)
      perTradeRisk = MathMax(0.80, out.asapFloor);
   else
      perTradeRisk = MathMax(1.20, out.asapFloor);

   out.lossBudget = (int)MathMax(1.0, MathFloor(out.dailyLossMoney / perTradeRisk + 1e-9));

   out.label = GsxPracticeBandLabel(band) + " " +
               GsxPracticeCostLabel(cost) + " " +
               GsxPracticeStyleLabel(style);
  }

//+------------------------------------------------------------------+
string GsxPracticeFormatCoachLine(const GsxPracticeProfile &p)
  {
   return(StringFormat("%s · risk%%%.1f maxLot%.2f fleet%d · dayLoss%.2f tgt%.2f · trades%d · ASAP%.2f",
                       p.label,
                       p.riskPct,
                       p.maxLot,
                       p.fleetTarget,
                       p.dailyLossMoney,
                       p.dailyProfitTarget,
                       p.maxTradesDay,
                       p.asapFloor));
  }

string GsxPracticeFormatTipLine(const GsxPracticeProfile &p)
  {
   string tip = StringFormat("%s · %s · pairs %s",
                             p.tfHint,
                             p.sessionHint,
                             p.primaryPairsCsv);
   if(p.secondaryPairsCsv != "")
      tip += " · 2nd " + p.secondaryPairsCsv;
   tip += StringFormat(" · lossBudget%d · %s", p.lossBudget, p.expectancyNote);
   if(StringLen(tip) > 96)
      tip = StringSubstr(tip, 0, 96) + "..";
   return(tip);
  }

#endif // GSX_PRACTICE_SIM_MQH
//+------------------------------------------------------------------+
