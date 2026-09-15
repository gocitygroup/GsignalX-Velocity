//+------------------------------------------------------------------+
//|                                                   PropRisk.mqh    |
//|  Challenge-pack soft-lock (never closes positions).               |
//|  Breach → GsxFleetServiceRunSet(magic,false); user PLAY to clear. |
//|  Host fills GsxPropConfig from inputs — no Inp* reads here.       |
//+------------------------------------------------------------------+
#ifndef GSX_PROP_RISK_MQH
#define GSX_PROP_RISK_MQH

#include <GSignalX/Fleet.mqh>

//+------------------------------------------------------------------+
struct GsxPropConfig
  {
   bool   enable;
   long   magic;
   double dailyLossMoney;    // 0=off
   double dailyLossPct;      // 0=off, of day-start balance
   double maxEquityDdPct;    // 0=off from day peak equity
   int    maxTradesDay;      // 0=off
   double maxDaySharePct;    // consistency: today vs week profit bank; 0=off
   double dailyProfitTarget; // 0=off halt when hit
   int    blockFridayHour;   // -1=off; stop new entries from this server hour Friday
   int    newsBlackoutMin;   // minutes either side of news times
   string newsTimesCsv;      // "YYYY.MM.DD HH:MM,YYYY.MM.DD HH:MM"
  };

//+------------------------------------------------------------------+
struct GsxPropState
  {
   bool     locked;
   string   reason;
   double   dayStartBalance;
   double   dayStartEquity;
   double   dayPeakEquity;
   double   dayRealized;   // closed P/L today for magic
   double   weekRealized;
   int      tradesToday;
   datetime dayKey;
   datetime weekKey;
  };

//+------------------------------------------------------------------+
//| GV name helpers                                                  |
//+------------------------------------------------------------------+
string GsxPropGvLocked(const long magic)
  { return("GSX_PROP_LOCKED_" + IntegerToString((int)magic)); }

string GsxPropGvDayBal(const long magic)
  { return("GSX_PROP_DAY_BAL_" + IntegerToString((int)magic)); }

string GsxPropGvDayEq(const long magic)
  { return("GSX_PROP_DAY_EQ_" + IntegerToString((int)magic)); }

string GsxPropGvDayPeak(const long magic)
  { return("GSX_PROP_DAY_PEAK_" + IntegerToString((int)magic)); }

string GsxPropGvDayReal(const long magic)
  { return("GSX_PROP_DAY_REAL_" + IntegerToString((int)magic)); }

string GsxPropGvWeekReal(const long magic)
  { return("GSX_PROP_WEEK_REAL_" + IntegerToString((int)magic)); }

string GsxPropGvTrades(const long magic)
  { return("GSX_PROP_TRADES_" + IntegerToString((int)magic)); }

string GsxPropGvDayKey(const long magic)
  { return("GSX_PROP_DAY_KEY_" + IntegerToString((int)magic)); }

string GsxPropGvWeekKey(const long magic)
  { return("GSX_PROP_WEEK_KEY_" + IntegerToString((int)magic)); }

string GsxPropGvReasonCode(const long magic)
  { return("GSX_PROP_REASON_" + IntegerToString((int)magic)); }

//+------------------------------------------------------------------+
int GsxPropReasonToCode(const string reason)
  {
   if(reason == "DAILY_LOSS_MONEY") return(1);
   if(reason == "DAILY_LOSS_PCT")   return(2);
   if(reason == "EQUITY_DD")        return(3);
   if(reason == "MAX_TRADES")       return(4);
   if(reason == "CONSISTENCY")      return(5);
   if(reason == "PROFIT_TARGET")    return(6);
   if(reason == "FRIDAY")           return(7);
   if(reason == "NEWS")             return(8);
   if(reason != "")                 return(9);
   return(0);
  }

string GsxPropCodeToReason(const int code)
  {
   switch(code)
     {
      case 1: return("DAILY_LOSS_MONEY");
      case 2: return("DAILY_LOSS_PCT");
      case 3: return("EQUITY_DD");
      case 4: return("MAX_TRADES");
      case 5: return("CONSISTENCY");
      case 6: return("PROFIT_TARGET");
      case 7: return("FRIDAY");
      case 8: return("NEWS");
      case 9: return("PROP");
      default: return("");
     }
  }

//+------------------------------------------------------------------+
double GsxPropGvGet(const string name, const double defVal)
  {
   if(!GlobalVariableCheck(name))
      return(defVal);
   return(GlobalVariableGet(name));
  }

void GsxPropGvSet(const string name, const double v)
  {
   GlobalVariableSet(name, v);
  }

//+------------------------------------------------------------------+
void GsxPropLoad(const long magic, GsxPropState &st)
  {
   st.locked          = (GsxPropGvGet(GsxPropGvLocked(magic), 0.0) > 0.5);
   st.dayStartBalance = GsxPropGvGet(GsxPropGvDayBal(magic), 0.0);
   st.dayStartEquity  = GsxPropGvGet(GsxPropGvDayEq(magic), 0.0);
   st.dayPeakEquity   = GsxPropGvGet(GsxPropGvDayPeak(magic), 0.0);
   st.dayRealized     = GsxPropGvGet(GsxPropGvDayReal(magic), 0.0);
   st.weekRealized    = GsxPropGvGet(GsxPropGvWeekReal(magic), 0.0);
   st.tradesToday     = (int)GsxPropGvGet(GsxPropGvTrades(magic), 0.0);
   st.dayKey          = (datetime)GsxPropGvGet(GsxPropGvDayKey(magic), 0.0);
   st.weekKey         = (datetime)GsxPropGvGet(GsxPropGvWeekKey(magic), 0.0);
   st.reason          = GsxPropCodeToReason((int)GsxPropGvGet(GsxPropGvReasonCode(magic), 0.0));
   if(st.locked && st.reason == "")
      st.reason = "PROP";
  }

void GsxPropSave(const long magic, const GsxPropState &st)
  {
   GsxPropGvSet(GsxPropGvLocked(magic),     st.locked ? 1.0 : 0.0);
   GsxPropGvSet(GsxPropGvDayBal(magic),     st.dayStartBalance);
   GsxPropGvSet(GsxPropGvDayEq(magic),      st.dayStartEquity);
   GsxPropGvSet(GsxPropGvDayPeak(magic),    st.dayPeakEquity);
   GsxPropGvSet(GsxPropGvDayReal(magic),    st.dayRealized);
   GsxPropGvSet(GsxPropGvWeekReal(magic),   st.weekRealized);
   GsxPropGvSet(GsxPropGvTrades(magic),     (double)st.tradesToday);
   GsxPropGvSet(GsxPropGvDayKey(magic),     (double)st.dayKey);
   GsxPropGvSet(GsxPropGvWeekKey(magic),    (double)st.weekKey);
   GsxPropGvSet(GsxPropGvReasonCode(magic), (double)GsxPropReasonToCode(st.reason));
  }

//+------------------------------------------------------------------+
datetime GsxPropUtcDayStart(const datetime gmtNow)
  {
   MqlDateTime dt;
   TimeToStruct(gmtNow, dt);
   return(gmtNow - (dt.hour * 3600 + dt.min * 60 + dt.sec));
  }

datetime GsxPropUtcWeekStart(const datetime gmtNow)
  {
   datetime dayStart = GsxPropUtcDayStart(gmtNow);
   MqlDateTime dt;
   TimeToStruct(dayStart, dt);
   // 0=Sun … 6=Sat → Monday-based
   int daysFromMon = (dt.day_of_week == 0) ? 6 : (dt.day_of_week - 1);
   return(dayStart - daysFromMon * 86400);
  }

//+------------------------------------------------------------------+
void GsxPropEnsureDayWeek(GsxPropState &st)
  {
   datetime nowGmt   = TimeGMT();
   datetime dayStart = GsxPropUtcDayStart(nowGmt);
   datetime weekStart = GsxPropUtcWeekStart(nowGmt);

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);

   if(st.dayKey != dayStart)
     {
      st.dayKey          = dayStart;
      st.dayStartBalance = bal;
      st.dayStartEquity  = eq;
      st.dayPeakEquity   = eq;
      st.dayRealized     = 0.0;
      st.tradesToday     = 0;
      // sticky lock survives day rollover (user must PLAY)
     }

   if(st.weekKey != weekStart)
     {
      st.weekKey      = weekStart;
      st.weekRealized = 0.0;
     }

   if(eq > st.dayPeakEquity)
      st.dayPeakEquity = eq;

   if(st.dayStartBalance <= 0.0)
      st.dayStartBalance = bal;
   if(st.dayStartEquity <= 0.0)
      st.dayStartEquity = eq;
   if(st.dayPeakEquity <= 0.0)
      st.dayPeakEquity = eq;
  }

//+------------------------------------------------------------------+
double GsxPropMagicRealizedSince(const long magic, const datetime from)
  {
   double sum = 0.0;
   datetime to = TimeCurrent();
   if(from <= 0 || to < from)
      return(0.0);

   if(!HistorySelect(from, to))
      return(0.0);

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if((long)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic)
         continue;

      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
         continue;

      sum += HistoryDealGetDouble(ticket, DEAL_PROFIT)
           + HistoryDealGetDouble(ticket, DEAL_SWAP)
           + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
     }
   return(sum);
  }

//+------------------------------------------------------------------+
bool GsxPropInNewsWindow(const GsxPropConfig &cfg)
  {
   if(cfg.newsBlackoutMin <= 0 || cfg.newsTimesCsv == "")
      return(false);

   string parts[];
   int n = StringSplit(cfg.newsTimesCsv, ',', parts);
   if(n <= 0)
      return(false);

   datetime now = TimeCurrent();
   int radius = cfg.newsBlackoutMin * 60;

   for(int i = 0; i < n; i++)
     {
      string t = parts[i];
      StringTrimLeft(t);
      StringTrimRight(t);
      if(t == "")
         continue;
      datetime news = StringToTime(t);
      if(news <= 0)
         continue;
      if(MathAbs((long)(now - news)) <= radius)
         return(true);
     }
   return(false);
  }

bool GsxPropInFridayBlock(const GsxPropConfig &cfg)
  {
   if(cfg.blockFridayHour < 0)
      return(false);
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week != FRIDAY)
      return(false);
   return(dt.hour >= cfg.blockFridayHour);
  }

//+------------------------------------------------------------------+
void GsxPropApplySoftStop(const GsxPropConfig &cfg, GsxPropState &st,
                          const string reason, bool &becameLocked)
  {
   if(st.locked)
      return;
   st.locked = true;
   st.reason = reason;
   becameLocked = true;
   GsxFleetServiceRunSet(cfg.magic, false);
  }

//+------------------------------------------------------------------+
bool GsxPropEvaluate(const GsxPropConfig &cfg, GsxPropState &st, bool &becameLocked)
  {
   becameLocked = false;
   if(!cfg.enable)
      return(false);

   GsxPropEnsureDayWeek(st);

   // refresh realized from history (UTC day/week keys mapped via TimeGMT epochs;
   // HistorySelect uses server time — approximate with current day/week keys)
   datetime dayFrom  = st.dayKey;
   datetime weekFrom = st.weekKey;
   // convert GMT epoch keys to a usable HistorySelect window: use TimeCurrent day/week
   // when broker TZ differs, still approximate via keys stored as GMT midnights
   st.dayRealized  = GsxPropMagicRealizedSince(cfg.magic, dayFrom);
   st.weekRealized = GsxPropMagicRealizedSince(cfg.magic, weekFrom);

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > st.dayPeakEquity)
      st.dayPeakEquity = eq;

   // --- sticky money / trade / target / consistency gates ---
   if(!st.locked)
     {
      if(cfg.dailyLossMoney > 0.0 && st.dayRealized <= -cfg.dailyLossMoney)
         GsxPropApplySoftStop(cfg, st, "DAILY_LOSS_MONEY", becameLocked);

      if(!st.locked && cfg.dailyLossPct > 0.0 && st.dayStartBalance > 0.0)
        {
         double lim = st.dayStartBalance * (cfg.dailyLossPct / 100.0);
         if(st.dayRealized <= -lim)
            GsxPropApplySoftStop(cfg, st, "DAILY_LOSS_PCT", becameLocked);
        }

      if(!st.locked && cfg.maxEquityDdPct > 0.0 && st.dayPeakEquity > 0.0)
        {
         double ddPct = 100.0 * (st.dayPeakEquity - eq) / st.dayPeakEquity;
         if(ddPct >= cfg.maxEquityDdPct)
            GsxPropApplySoftStop(cfg, st, "EQUITY_DD", becameLocked);
        }

      if(!st.locked && cfg.maxTradesDay > 0 && st.tradesToday >= cfg.maxTradesDay)
         GsxPropApplySoftStop(cfg, st, "MAX_TRADES", becameLocked);

      if(!st.locked && cfg.dailyProfitTarget > 0.0 && st.dayRealized >= cfg.dailyProfitTarget)
         GsxPropApplySoftStop(cfg, st, "PROFIT_TARGET", becameLocked);

      if(!st.locked && cfg.maxDaySharePct > 0.0 && st.dayRealized > 0.0)
        {
         double weekBank = st.weekRealized;
         if(weekBank < st.dayRealized)
            weekBank = st.dayRealized; // avoid div0 / negative bank early week
         if(weekBank > 0.0)
           {
            double share = 100.0 * st.dayRealized / weekBank;
            if(share >= cfg.maxDaySharePct)
               GsxPropApplySoftStop(cfg, st, "CONSISTENCY", becameLocked);
           }
        }
     }

   // --- Friday / news: sticky soft STOP (until PLAY) ---
   if(!st.locked)
     {
      if(GsxPropInFridayBlock(cfg))
         GsxPropApplySoftStop(cfg, st, "FRIDAY", becameLocked);

      if(!st.locked && GsxPropInNewsWindow(cfg))
         GsxPropApplySoftStop(cfg, st, "NEWS", becameLocked);
     }
   else
     {
      // already locked: keep RUN=0 if somehow re-enabled without clearing lock
      if(GsxFleetServiceRunGet(cfg.magic))
         GsxFleetServiceRunSet(cfg.magic, false);
     }

   GsxPropSave(cfg.magic, st);
   return(st.locked);
  }

//+------------------------------------------------------------------+
void GsxPropOnNewEntry(GsxPropState &st)
  {
   GsxPropEnsureDayWeek(st);
   st.tradesToday++;
  }

//+------------------------------------------------------------------+
string GsxPropStatusText(const GsxPropState &st)
  {
   if(!st.locked)
      return("OK");
   if(st.reason == "")
      return("LOCK: PROP");
   return("LOCK: " + st.reason);
  }

#endif // GSX_PROP_RISK_MQH
