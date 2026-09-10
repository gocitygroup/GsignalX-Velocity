//+------------------------------------------------------------------+
//|                                           BarDirection.mqh        |
//|  Shared OHLC closed-bar streak helpers (GSignalX + ProfitScouter) |
//+------------------------------------------------------------------+
#ifndef GSX_BAR_DIRECTION_MQH
#define GSX_BAR_DIRECTION_MQH

//+------------------------------------------------------------------+
//| Count consecutive CLOSED bars matching candleDir:                 |
//|   +1 = buying  (close > open)                                     |
//|   -1 = selling (close < open)                                     |
//| Starts at shift 1 (last closed bar). A doji (close == open)       |
//| breaks the streak. Returns 0 on bad args or no rates.             |
//+------------------------------------------------------------------+
int GsxCountConsecutiveClosedBars(const string symbol,
                                  const ENUM_TIMEFRAMES tf,
                                  const int candleDir)
  {
   if(symbol == "" || candleDir == 0)
      return(0);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // shift 1..N — ignore the forming bar
   const int want = 64;
   int n = CopyRates(symbol, tf, 1, want, rates);
   if(n <= 0)
      return(0);

   int streak = 0;
   for(int i = 0; i < n; i++)
     {
      if(rates[i].close == rates[i].open)
         break;
      int barDir = (rates[i].close > rates[i].open) ? 1 : -1;
      if(barDir != candleDir)
         break;
      streak++;
     }
   return(streak);
  }

#endif // GSX_BAR_DIRECTION_MQH
//+------------------------------------------------------------------+
