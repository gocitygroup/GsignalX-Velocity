//+------------------------------------------------------------------+
//| TpNativeApply.mqh — push computed TP level onto open positions    |
//+------------------------------------------------------------------+
#ifndef GSX_TP_NATIVE_APPLY_MQH
#define GSX_TP_NATIVE_APPLY_MQH

#include <Trade/Trade.mqh>
#include <GSignalX/TpNative/TpNativeTypes.mqh>

double TpnBrokerMinDist(const string symbol)
  {
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      point = _Point;
   double stops  = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL)  * point;
   double freeze = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;
   return(MathMax(stops, freeze));
  }

bool TpnLevelOkForSide(const string symbol, const long posType, const double entry,
                       const double level)
  {
   if(TpnIsNa(level) || entry <= 0.0)
      return(false);
   // Must be on the profitable side of entry
   if(posType == POSITION_TYPE_BUY && level <= entry)
      return(false);
   if(posType == POSITION_TYPE_SELL && level >= entry)
      return(false);

   double minDist = TpnBrokerMinDist(symbol);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return(false);
   if(posType == POSITION_TYPE_BUY && level < ask + minDist)
      return(false);
   if(posType == POSITION_TYPE_SELL && level > bid - minDist)
      return(false);
   return(true);
  }

// Apply computed native TP to matching open positions. Keeps existing SL.
// Returns number of successful PositionModify calls.
int TpnApplyLevelToOpen(const long magic, const string symbolFilter, const TpnResult &r)
  {
   if(!r.active || TpnIsNa(r.level) || r.direction == TPN_DIR_NONE)
      return(0);

   CTrade tpnTrade;
   tpnTrade.SetAsyncMode(false);
   int modified = 0;

   for(int p = PositionsTotal() - 1; p >= 0; p--)
     {
      ulong ticket = PositionGetTicket(p);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(magic != 0 && PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      if(symbolFilter != "" && sym != symbolFilter)
         continue;

      long posType = PositionGetInteger(POSITION_TYPE);
      int side = (posType == POSITION_TYPE_BUY) ? 1 : -1;
      int want = (r.direction == TPN_DIR_LONG) ? 1 : ((r.direction == TPN_DIR_SHORT) ? -1 : 0);
      if(want != 0 && side != want)
         continue;

      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      double level = NormalizeDouble(r.level, digits);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      if(!TpnLevelOkForSide(sym, posType, entry, level))
         continue;

      double curSl = PositionGetDouble(POSITION_SL);
      double curTp = PositionGetDouble(POSITION_TP);
      double point = SymbolInfoDouble(sym, SYMBOL_POINT);
      if(point <= 0.0)
         point = _Point;
      if(curTp > 0.0 && MathAbs(curTp - level) < 2.0 * point)
         continue;

      if(tpnTrade.PositionModify(ticket, curSl, level))
        {
         modified++;
         PrintFormat("TpNative: set TP #%I64u %s %.5f -> %.5f (%s)",
                     ticket, sym, curTp, level, TpnDirToStr(r.direction));
        }
      else
         PrintFormat("TpNative: PositionModify TP failed #%I64u %s err=%d",
                     ticket, sym, (int)tpnTrade.ResultRetcode());
     }
   return(modified);
  }

#endif // GSX_TP_NATIVE_APPLY_MQH
