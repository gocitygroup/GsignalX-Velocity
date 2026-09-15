//+------------------------------------------------------------------+
//|                                             SessionClock.mqh      |
//|  Illustrative GMT session clock (Asia/London/NY/Sydney).          |
//|  NOT broker-authoritative — MarketGates still gate real trades.   |
//+------------------------------------------------------------------+
#ifndef GSX_SESSION_CLOCK_MQH
#define GSX_SESSION_CLOCK_MQH

struct GsxSessionClockConfig
  {
   int asiaStart;      // inclusive hour GMT
   int asiaEnd;        // exclusive
   int londonStart;
   int londonEnd;
   int nyStart;
   int nyEnd;
   int sydneyStart;
   int sydneyEnd;      // may wrap past midnight
  };

struct GsxSessionClockState
  {
   bool asiaOpen;
   bool londonOpen;
   bool nyOpen;
   bool sydneyOpen;
   int  openCount;
   bool overlap;       // 2+ sessions open
   int  hourGmt;
   string summary;     // e.g. "LDN·NY"
  };

//+------------------------------------------------------------------+
void GsxSessionClockDefaults(GsxSessionClockConfig &cfg)
  {
   cfg.asiaStart   = 0;
   cfg.asiaEnd     = 9;
   cfg.londonStart = 7;
   cfg.londonEnd   = 16;
   cfg.nyStart     = 12;
   cfg.nyEnd       = 21;
   cfg.sydneyStart = 21;
   cfg.sydneyEnd   = 6;   // wraps
  }

bool GsxSessionHourInRange(const int hour, const int startH, const int endH)
  {
   if(startH == endH)
      return(false);
   if(startH < endH)
      return(hour >= startH && hour < endH);
   // wrap (e.g. Sydney 21–06)
   return(hour >= startH || hour < endH);
  }

//+------------------------------------------------------------------+
void GsxSessionClockNow(const GsxSessionClockConfig &cfg, GsxSessionClockState &out)
  {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   out.hourGmt = dt.hour;
   out.asiaOpen   = GsxSessionHourInRange(dt.hour, cfg.asiaStart, cfg.asiaEnd);
   out.londonOpen = GsxSessionHourInRange(dt.hour, cfg.londonStart, cfg.londonEnd);
   out.nyOpen     = GsxSessionHourInRange(dt.hour, cfg.nyStart, cfg.nyEnd);
   out.sydneyOpen = GsxSessionHourInRange(dt.hour, cfg.sydneyStart, cfg.sydneyEnd);

   out.openCount = 0;
   if(out.asiaOpen)   out.openCount++;
   if(out.londonOpen) out.openCount++;
   if(out.nyOpen)     out.openCount++;
   if(out.sydneyOpen) out.openCount++;
   out.overlap = (out.openCount >= 2);

   out.summary = "";
   if(out.asiaOpen)   { if(out.summary != "") out.summary += "·"; out.summary += "ASIA"; }
   if(out.londonOpen) { if(out.summary != "") out.summary += "·"; out.summary += "LDN"; }
   if(out.nyOpen)     { if(out.summary != "") out.summary += "·"; out.summary += "NY"; }
   if(out.sydneyOpen) { if(out.summary != "") out.summary += "·"; out.summary += "SYD"; }
   if(out.summary == "")
      out.summary = "CLOSED";
  }

#endif // GSX_SESSION_CLOCK_MQH
//+------------------------------------------------------------------+
