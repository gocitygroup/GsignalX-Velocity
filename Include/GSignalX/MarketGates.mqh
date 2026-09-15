//+------------------------------------------------------------------+
//|                                              MarketGates.mqh      |
//|  Symbol-parameterized session / weekend / spread / hour gates     |
//+------------------------------------------------------------------+
#ifndef GSX_MARKET_GATES_MQH
#define GSX_MARKET_GATES_MQH

#include <GSignalX/SymbolCanon.mqh>

//+------------------------------------------------------------------+
bool GsxCryptoWeekendExempt(const string symbol,
                            const bool allowWeekend,
                            const string cryptoExtraList)
  {
   if(!allowWeekend)
      return(false);
   return(GsxIsCryptoSymbolEx(symbol, cryptoExtraList));
  }

//+------------------------------------------------------------------+
bool GsxIsMarketOpen(const string symbol,
                     const int staleTickSec,
                     const bool blockWeekend,
                     const bool useSessions,
                     const bool allowCryptoWeekend,
                     const string cryptoExtra,
                     string &reason)
  {
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
     { reason = "terminal not connected"; return(false); }

   long tmode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   if(tmode == SYMBOL_TRADE_MODE_DISABLED)
     { reason = "symbol trading disabled"; return(false); }
   if(tmode == SYMBOL_TRADE_MODE_CLOSEONLY)
     { reason = "close-only mode"; return(false); }

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
     { reason = "no tick data"; return(false); }

   if(staleTickSec > 0 && (TimeCurrent() - tick.time) > staleTickSec)
     {
      reason = "no ticks for " + IntegerToString((int)(TimeCurrent() - tick.time)) +
               "s (market closed)";
      return(false);
     }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   ENUM_DAY_OF_WEEK dow = (ENUM_DAY_OF_WEEK)dt.day_of_week;
   bool cryptoExempt = GsxCryptoWeekendExempt(symbol, allowCryptoWeekend, cryptoExtra);

   if(blockWeekend && !cryptoExempt && (dow == SATURDAY || dow == SUNDAY))
     { reason = "weekend"; return(false); }

   if(useSessions)
     {
      datetime from, to;
      int  sessions = 0;
      bool inSession = false;
      int  secs = dt.hour * 3600 + dt.min * 60 + dt.sec;
      for(uint s = 0; s < 8; s++)
        {
         if(!SymbolInfoSessionTrade(symbol, dow, s, from, to))
            break;
         sessions++;
         int f = (int)from;
         int t = (int)to;
         if(secs >= f && secs <= t)
            inSession = true;
        }
      if(sessions > 0 && !inSession)
        { reason = "outside broker trading session"; return(false); }

      // crypto brokers often omit Sat/Sun session rows while ticks still flow
      if(sessions == 0 && cryptoExempt &&
         (dow == SATURDAY || dow == SUNDAY))
         return(true);
     }

   return(true);
  }

//+------------------------------------------------------------------+
bool GsxTimeFilterOK(const string symbol,
                     const bool useHourFilter,
                     const int startH,
                     const int endH,
                     const bool fridayStop,
                     const int fridayStopHr,
                     const bool allowCryptoWeekend,
                     const string cryptoExtra,
                     string &reason)
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   bool cryptoExempt = GsxCryptoWeekendExempt(symbol, allowCryptoWeekend, cryptoExtra);

   if(useHourFilter)
     {
      bool ok;
      if(startH <= endH)
         ok = (dt.hour >= startH && dt.hour < endH);
      else                                  // window crosses midnight
         ok = (dt.hour >= startH || dt.hour < endH);
      if(!ok)
        { reason = "outside trading hours"; return(false); }
     }

   if(fridayStop && !cryptoExempt &&
      dt.day_of_week == FRIDAY && dt.hour >= fridayStopHr)
     { reason = "Friday cut-off"; return(false); }

   return(true);
  }

//+------------------------------------------------------------------+
bool GsxSpreadOK(const string symbol,
                 const int maxSpreadPt,
                 const bool ignoreSpread,
                 string &reason)
  {
   int lim = ignoreSpread ? 0 : maxSpreadPt;
   if(lim <= 0)
      return(true);
   long spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(spread > lim)
     {
      reason = "spread " + IntegerToString((int)spread) + " > limit";
      return(false);
     }
   return(true);
  }

#endif // GSX_MARKET_GATES_MQH
//+------------------------------------------------------------------+
