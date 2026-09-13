//+------------------------------------------------------------------+
//|                                                  LotSizing.mqh   |
//|  Risk-based / fixed lot sizing (AutoLot) — shared by GSignalX    |
//|  Formula: riskMoney / ((stopDist / tickSize) * tickValue)        |
//|  Fail-safe: always returns a normalized fallback lot on error.   |
//+------------------------------------------------------------------+
#ifndef GSX_LOT_SIZING_MQH
#define GSX_LOT_SIZING_MQH

//--- matches EnRiskMode in GsignalX_GocityGroup.mq5 (0=fixed, 1=percent)
#define GSX_LOT_MODE_FIXED 0
#define GSX_LOT_MODE_PCT   1

//+------------------------------------------------------------------+
//| Clamp lot to broker min/step/max and optional EA cap             |
//+------------------------------------------------------------------+
double GsxNormalizeLot(const string symbol, double lot, const double maxLotCap)
  {
   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(stepLot <= 0.0)
      stepLot = 0.01;
   lot = MathFloor(lot / stepLot) * stepLot;
   if(maxLotCap > 0.0 && lot > maxLotCap)
      lot = MathFloor(maxLotCap / stepLot) * stepLot;
   if(lot < minLot)
      lot = minLot;
   if(lot > maxLot)
      lot = maxLot;
   return(NormalizeDouble(lot, 2));
  }

//+------------------------------------------------------------------+
//| Core AutoLot calculator                                          |
//| useAutoLot=false → always fixedLot (chart FIXED)                 |
//| useAutoLot=true  → riskMode PCT uses balance×risk%; else fixed   |
//+------------------------------------------------------------------+
double GsxCalcLot(const string symbol,
                  const double stopDistance,
                  const bool   useAutoLot,
                  const int    riskMode,
                  const double riskPct,
                  const double fixedLot,
                  const double maxLotCap,
                  const bool   logCalc = false)
  {
   const string modeTag = useAutoLot ? "AUTOLOT" : "FIXED";

   //--- chart FIXED, or EA fixed-lot mode, or unusable stop distance
   if(!useAutoLot || riskMode == GSX_LOT_MODE_FIXED || stopDistance <= 0.0)
     {
      double lotFixed = GsxNormalizeLot(symbol, fixedLot, maxLotCap);
      if(logCalc)
         PrintFormat("[LOT_CALC] symbol=%s balance=%.2f risk%%=%.2f sl_dist=%.5f "
                     "tick_val=n/a raw=%.4f final=%.2f mode=%s",
                     symbol,
                     AccountInfoDouble(ACCOUNT_BALANCE),
                     riskPct,
                     stopDistance,
                     fixedLot,
                     lotFixed,
                     modeTag);
      return(lotFixed);
     }

   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0)
     {
      Print("GsignalX: tick value/size unavailable, falling back to fixed lot");
      double lotFb = GsxNormalizeLot(symbol, fixedLot, maxLotCap);
      if(logCalc)
         PrintFormat("[LOT_CALC] symbol=%s balance=%.2f risk%%=%.2f sl_dist=%.5f "
                     "tick_val=0 raw=%.4f final=%.2f mode=%s (fallback)",
                     symbol,
                     AccountInfoDouble(ACCOUNT_BALANCE),
                     riskPct,
                     stopDistance,
                     fixedLot,
                     lotFb,
                     modeTag);
      return(lotFb);
     }

   //--- normalized tick value per point (works for forex, metals, indices)
   double tickValuePerPoint = (tickValue / tickSize);
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * riskPct / 100.0;
   double lossPerLot = stopDistance * tickValuePerPoint;
   if(lossPerLot <= 0.0)
     {
      double lotFb = GsxNormalizeLot(symbol, fixedLot, maxLotCap);
      if(logCalc)
         PrintFormat("[LOT_CALC] symbol=%s balance=%.2f risk%%=%.2f sl_dist=%.5f "
                     "tick_val=%.6f raw=%.4f final=%.2f mode=%s (fallback)",
                     symbol, balance, riskPct, stopDistance,
                     tickValuePerPoint, fixedLot, lotFb, modeTag);
      return(lotFb);
     }

   double rawLot   = riskMoney / lossPerLot;
   double finalLot = GsxNormalizeLot(symbol, rawLot, maxLotCap);

   if(logCalc)
      PrintFormat("[LOT_CALC] symbol=%s balance=%.2f risk%%=%.2f sl_dist=%.5f "
                  "tick_val=%.6f raw=%.4f final=%.2f mode=%s",
                  symbol, balance, riskPct, stopDistance,
                  tickValuePerPoint, rawLot, finalLot, modeTag);

   return(finalLot);
  }

//+------------------------------------------------------------------+
//| Floating drawdown % from balance (0 if balance unavailable)      |
//| Shared by equity guard gate + chart Account DD panel row         |
//+------------------------------------------------------------------+
double GsxAccountDrawdownPct()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0)
      return(0.0);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = (balance - equity) / balance * 100.0;
   if(dd < 0.0)
      return(0.0);
   return(dd);
  }

#endif // GSX_LOT_SIZING_MQH
