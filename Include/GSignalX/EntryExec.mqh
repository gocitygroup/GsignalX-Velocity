//+------------------------------------------------------------------+
//|                                                   EntryExec.mqh   |
//|  Symbol-parameterized entry helpers for GSignalX Service path.    |
//|  Scouter exits only — NEVER reverse-close. Catastrophe SL + TP=0. |
//+------------------------------------------------------------------+
#ifndef GSX_ENTRY_EXEC_MQH
#define GSX_ENTRY_EXEC_MQH

#include <Trade\Trade.mqh>
#include <GSignalX/Engines.mqh>
#include <GSignalX/LotSizing.mqh>
#include <GSignalX/Fleet.mqh>
#include <GSignalX/FollowGate.mqh>
#include <GSignalX/StrategicStop.mqh>

#define GSX_ENTRY_MARKET 0
#define GSX_ENTRY_LIMIT  1
#define GSX_ENTRY_STOP   2
#define GSX_ENTRY_BOTH   3

#define GSX_UNIT_PIPS   0
#define GSX_UNIT_POINTS 1

//+------------------------------------------------------------------+
struct GsxEntryParams
  {
   long   magic;
   int    slippage;
   string comment;
   int    entryMode;              // 0 market 1 limit 2 stop 3 both
   int    offsetUnit;             // 0 pips 1 points
   int    limitOffset;
   int    stopOffset;
   bool   pendFromSignalOpen;
   bool   useStop;
   double stopMult;
   bool   strategicStopEnable;
   double strategicStopMult;
   bool   useTarget;              // ignored on Service/Scouter path (TP forced 0)
   double targetMult;             // ignored on Service/Scouter path
   bool   autoLot;
   int    riskMode;
   double riskPct;
   double fixedLot;
   double maxLot;
   bool   verbose;
   bool   allowLong;
   bool   allowShort;
   // Strategic stop engine (catastrophe SL) — see StrategicStop.mqh
   bool   stratUseDailyAtr;
   int    stratDailyAtrLen;
   double stratDailyFloorMult;
   double stratClassMultFx;
   double stratClassMultCmd;
   double stratClassMultCr;
   int    stratRangeBars;
   double stratRangeMult;
   int    stratSpreadBaseLimit;
   double stratHardCapMult;
   bool   stratJitterEnable;
   double stratJitterPct;
   int    stratMicroPts;
   // exit always scouter for service path
  };

// Fill GsxStratStopParams from entry params (DRY for market/pending).
void GsxEntryFillStratParams(const GsxEntryParams &p, GsxStratStopParams &sp)
  {
   GsxStratStopParamsClear(sp);
   sp.enable           = p.strategicStopEnable;
   sp.strategicMult    = p.strategicStopMult;
   sp.useDailyAtr      = p.stratUseDailyAtr;
   sp.dailyAtrLen      = p.stratDailyAtrLen;
   sp.dailyFloorMult   = p.stratDailyFloorMult;
   sp.classMultFx      = p.stratClassMultFx;
   sp.classMultCmd     = p.stratClassMultCmd;
   sp.classMultCr      = p.stratClassMultCr;
   sp.rangeBars        = p.stratRangeBars;
   sp.rangeMult        = p.stratRangeMult;
   sp.spreadBaseLimit  = p.stratSpreadBaseLimit;
   sp.hardCapMult      = p.stratHardCapMult;
   sp.jitterEnable     = p.stratJitterEnable;
   sp.jitterPct        = p.stratJitterPct;
   sp.microPts         = p.stratMicroPts;
   sp.magic            = p.magic;
  }

//+------------------------------------------------------------------+
double GsxPipSize(const string symbol)
  {
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return(point * 10.0);
   return(point);
  }

int GsxClampOffset(int v)
  {
   if(v < 4)  v = 4;
   if(v > 20) v = 20;
   return(v);
  }

double GsxOffsetPrice(const string symbol, const int offsetUnit, const int units)
  {
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double one = (offsetUnit == GSX_UNIT_PIPS) ? GsxPipSize(symbol) : point;
   return(GsxClampOffset(units) * one);
  }

double GsxBrokerMinDistance(const string symbol)
  {
   double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double stops  = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL)  * point;
   double freeze = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;
   return(MathMax(stops, freeze));
  }

double GsxMinStopDistance(const string symbol)
  {
   // Prefer stops∪freeze (same as broker pending/SL validation).
   return(GsxStratStopBrokerMin(symbol));
  }

// Strategic catastrophe stop distance — full engine (D1/class/jitter).
// For callers that only need a scalar distance (no persist).
double GsxStrategicStopDistance(const string symbol,
                                const double atr,
                                const bool enable,
                                const double mult)
  {
   GsxStratStopParams sp;
   GsxStratStopParamsClear(sp);
   sp.enable = enable;
   sp.strategicMult = mult;
   GsxStratStopDecision d;
   if(!GsxStratStopBuild(symbol, atr, sp, d))
      return(GsxStrategicStopDistanceLegacy(symbol, atr, enable, mult));
   return(d.finalDist);
  }

// Full decision from entry params (preferred).
bool GsxStrategicStopBuildFromEntry(const string symbol,
                                    const double atr,
                                    const GsxEntryParams &p,
                                    GsxStratStopDecision &out)
  {
   GsxStratStopParams sp;
   GsxEntryFillStratParams(p, sp);
   return(GsxStratStopBuild(symbol, atr, sp, out));
  }

double GsxNormalizePendingPrice(const string symbol,
                                const int dir,
                                const bool isStop,
                                double price)
  {
   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double ask    = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid    = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minD   = GsxBrokerMinDistance(symbol);
   if(minD <= 0.0)
      minD = point;

   if(dir == 1)
     {
      if(isStop)
        {
         if(price <= ask)
            price = ask + minD;
         if(price - ask < minD)
            price = ask + minD;
        }
      else
        {
         if(price >= ask)
            price = ask - minD;
         if(ask - price < minD)
            price = ask - minD;
        }
     }
   else
     {
      if(isStop)
        {
         if(price >= bid)
            price = bid - minD;
         if(bid - price < minD)
            price = bid - minD;
        }
      else
        {
         if(price <= bid)
            price = bid + minD;
         if(price - bid < minD)
            price = bid + minD;
        }
     }
   return(NormalizeDouble(price, digits));
  }

double GsxSignalAnchorOpen(const string symbol,
                           const GsxEngineState &st,
                           const bool pendFromSignalOpen,
                           const int fallbackIdx)
  {
   double mid = (SymbolInfoDouble(symbol, SYMBOL_ASK) + SymbolInfoDouble(symbol, SYMBOL_BID)) * 0.5;
   double base = 0.0;
   if(pendFromSignalOpen)
     {
      // v2.15: tip scalar first (compacted Core engines)
      if(st.lastSigOpen > 0.0)
         base = st.lastSigOpen;
      else if(st.lastSigIdx >= 0 && st.lastSigIdx < st.n && st.open[st.lastSigIdx] > 0.0)
         base = st.open[st.lastSigIdx];
     }
   if(base <= 0.0 && fallbackIdx >= 0 && fallbackIdx < st.n && st.open[fallbackIdx] > 0.0)
      base = st.open[fallbackIdx];
   if(base <= 0.0 && st.lastClose > 0.0)
      base = st.lastClose;
   if(base <= 0.0)
      return(mid);

   // v2.10: if signal bar is too far from market, re-anchor so BOTH can place
   double atr = 0.0;
   if(st.lastAtrRisk > 0.0)
      atr = st.lastAtrRisk;
   else if(st.ready && st.n >= 1 && fallbackIdx >= 0 && fallbackIdx < st.n)
      atr = st.atrRisk[fallbackIdx];
   if(atr <= 0.0 && st.ready && st.n >= 1)
      atr = st.atrRisk[st.n - 1];
   if(atr > 0.0 && MathAbs(base - mid) > 2.0 * atr)
     {
      if(fallbackIdx >= 0 && fallbackIdx < st.n && st.open[fallbackIdx] > 0.0)
         return(st.open[fallbackIdx]);
      return(mid);
     }
   return(base);
  }

//+------------------------------------------------------------------+
ulong GsxFindPosition(const string symbol, const long magic, int &dir)
  {
   dir = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      long ptype = PositionGetInteger(POSITION_TYPE);
      dir = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      return(ticket);
     }
   return(0);
  }

int GsxCountPendings(const string symbol, const long magic)
  {
   int c = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol)
         continue;
      c++;
     }
   return(c);
  }

void GsxDeletePendings(CTrade &trade, const string symbol, const long magic, const string why)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol)
         continue;
      if(trade.OrderDelete(ticket))
         Print("GsignalX EntryExec: pending #", ticket, " deleted (", why, ")");
      else
         Print("GsignalX EntryExec: delete failed #", ticket,
               " retcode=", trade.ResultRetcode());
     }
  }

// Cancel magic pendings whose symbol is not on the live roster (stale pair hygiene).
int GsxCleanupOrphanPendings(CTrade &trade, const long magic, const string &roster[])
  {
   int killed = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      string sym = OrderGetString(ORDER_SYMBOL);
      if(sym == "")
         continue;
      bool onRoster = false;
      for(int r = 0; r < ArraySize(roster); r++)
        {
         if(roster[r] == "" )
            continue;
         if(roster[r] == sym)
           {
            onRoster = true;
            break;
           }
        }
      if(onRoster)
         continue;
      if(trade.OrderDelete(ticket))
        {
         killed++;
         Print("GsignalX EntryExec: orphan pending #", ticket, " ", sym,
               " deleted (not on roster)");
        }
     }
   return(killed);
  }

void GsxCleanupStalePendings(CTrade &trade, const long magic, const int maxAgeMin)
  {
   if(maxAgeMin <= 0)
      return;
   long maxAge = (long)maxAgeMin * 60;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      datetime setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if((long)(TimeCurrent() - setup) >= maxAge)
        {
         if(trade.OrderDelete(ticket))
            Print("GsignalX EntryExec: stale pending #", ticket, " cancelled (age ",
                  (long)((TimeCurrent() - setup) / 60), " min >= ", maxAgeMin, ")");
         else
            Print("GsignalX EntryExec: stale pending #", ticket,
                  " delete failed retcode=", trade.ResultRetcode());
        }
     }
  }

void GsxCleanupStalePendings(CTrade &trade,
                             const string symbol,
                             const long magic,
                             const int maxAgeMin)
  {
   if(maxAgeMin <= 0 || symbol == "")
      return;
   long maxAge = (long)maxAgeMin * 60;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol)
         continue;
      datetime setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if((long)(TimeCurrent() - setup) >= maxAge)
        {
         if(trade.OrderDelete(ticket))
            Print("GsignalX EntryExec: stale pending #", ticket, " on ", symbol,
                  " cancelled (age ", (long)((TimeCurrent() - setup) / 60),
                  " min >= ", maxAgeMin, ")");
         else
            Print("GsignalX EntryExec: stale pending #", ticket,
                  " delete failed retcode=", trade.ResultRetcode());
        }
     }
  }

bool GsxTradeAllowedNow(const string symbol, const bool tradingEnabled, string &reason)
  {
   if(!tradingEnabled)
     { reason = "PLAY off"; return(false); }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
     { reason = "AutoTrading off"; return(false); }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
     { reason = "account trade disabled"; return(false); }
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
     { reason = "expert trading disabled"; return(false); }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     { reason = "terminal trade disabled"; return(false); }
   long tmode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   if(tmode == SYMBOL_TRADE_MODE_DISABLED)
     { reason = "symbol trading disabled"; return(false); }
   if(tmode == SYMBOL_TRADE_MODE_CLOSEONLY)
     { reason = "close-only mode"; return(false); }
   return(true);
  }

//+------------------------------------------------------------------+
//| Scouter path: close requests are always blocked in this module.   |
//+------------------------------------------------------------------+
void GsxCloseCurrentBlocked(const string why)
  {
   Print("GsignalX EntryExec: close request '", why,
         "' BLOCKED - exits are owned by Profit Scouter");
  }

bool GsxTrySetFilling(CTrade &trade, const ENUM_ORDER_TYPE_FILLING fill)
  {
   trade.SetTypeFilling(fill);
   return(true);
  }

bool GsxOrderSendFailedInvalidFill(CTrade &trade)
  {
   uint rc = trade.ResultRetcode();
   return(rc == TRADE_RETCODE_INVALID_FILL);
  }

//+------------------------------------------------------------------+
bool GsxOpenMarket(CTrade &trade,
                   const string symbol,
                   const int dir,
                   const GsxEngineState &st,
                   const GsxEntryParams &p,
                   string &action)
  {
   action = "";
   if(dir == 0)
      return(false);
   if(dir > 0 && !p.allowLong)
     { action = "longs disabled"; return(false); }
   if(dir < 0 && !p.allowShort)
     { action = "shorts disabled"; return(false); }

   string gate = "";
   if(!GsxTradeAllowedNow(symbol, true, gate))
     { action = gate; return(false); }

   if(!st.ready || st.n < 1)
     { action = "engines not ready"; return(false); }

   double atr = GsxEngTipAtr(st);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double price = (dir == 1) ? ask : bid;
   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   // sizing distance from ATR (Scouter path: always size when ATR ready — v2.14 parity)
   double stopDist = 0.0;
   if(atr > 0.0)
      stopDist = p.stopMult * atr;
   double minDist = GsxBrokerMinDistance(symbol);
   if(stopDist > 0.0 && stopDist < minDist)
      stopDist = minDist;

   double sl = 0.0;
   double tp = 0.0; // Scouter path: TP always 0
   GsxStratStopDecision stratDec;
   GsxStratStopDecisionClear(stratDec);
   double stratDist = 0.0;
   if(p.strategicStopEnable && atr > 0.0)
     {
      if(GsxStrategicStopBuildFromEntry(symbol, atr, p, stratDec))
         stratDist = stratDec.finalDist;
      else
         stratDist = GsxStrategicStopDistanceLegacy(symbol, atr, true, p.strategicStopMult);
      if(stratDist > 0.0)
        {
         sl = GsxStratStopPrice(dir, price, stratDist, digits);
         sl = GsxStratStopValidateVsMarket(symbol, dir, price, sl);
        }
     }

   if(p.autoLot && stopDist <= 0.0 && p.verbose)
      PrintFormat("GsignalX Entry: AUTO→FIX fallback on %s (no ATR sizing distance)", symbol);

   double lot = GsxCalcLot(symbol, stopDist, p.autoLot, p.riskMode,
                           p.riskPct, p.fixedLot, p.maxLot, p.verbose);
   if(lot <= 0.0)
     { action = "computed lot is zero"; return(false); }

   double margin = 0.0;
   ENUM_ORDER_TYPE otype = (dir == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(OrderCalcMargin(otype, symbol, lot, price, margin))
     {
      if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
        { action = "not enough free margin"; return(false); }
     }

   trade.SetExpertMagicNumber(p.magic);
   trade.SetDeviationInPoints(p.slippage);
   trade.SetTypeFillingBySymbol(symbol);

   bool ok = (dir == 1)
             ? trade.Buy(lot, symbol, 0.0, sl, tp, p.comment)
             : trade.Sell(lot, symbol, 0.0, sl, tp, p.comment);

   if(!ok && GsxOrderSendFailedInvalidFill(trade))
     {
      ENUM_ORDER_TYPE_FILLING alts[3] = {ORDER_FILLING_FOK, ORDER_FILLING_IOC, ORDER_FILLING_RETURN};
      for(int a = 0; a < 3 && !ok; a++)
        {
         GsxTrySetFilling(trade, alts[a]);
         ok = (dir == 1)
              ? trade.Buy(lot, symbol, 0.0, sl, tp, p.comment)
              : trade.Sell(lot, symbol, 0.0, sl, tp, p.comment);
        }
     }

   if(!ok)
     {
      action = "order failed: " + IntegerToString((int)trade.ResultRetcode()) +
               " " + trade.ResultRetcodeDescription();
      return(false);
     }

   action = ((dir == 1) ? "BUY " : "SELL ") + DoubleToString(lot, 2) +
            " @ " + DoubleToString(price, digits);

   ulong ticket = trade.ResultOrder();
   if(ticket == 0)
      ticket = trade.ResultDeal();
   // Prefer live position ticket for this symbol/magic
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != p.magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      ticket = t;
      break;
     }
   if(stratDec.ok && ticket > 0)
      GsxStratStopPersist(ticket, p.magic, stratDec);

   if(sl > 0.0 && stratDist > 0.0)
      PrintFormat("GsignalX Entry: catastrophe SL %s %.5f | %s",
                  symbol, sl, stratDec.reason);
   return(true);
  }

//+------------------------------------------------------------------+
bool GsxPlacePending(CTrade &trade,
                     const string symbol,
                     const int dir,
                     const bool isStop,
                     double price,
                     const double atr,
                     const GsxEntryParams &p,
                     string &action)
  {
   action = "";
   string gate = "";
   if(!GsxTradeAllowedNow(symbol, true, gate))
     { action = gate; return(false); }

   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double minD   = GsxBrokerMinDistance(symbol);
   price = GsxNormalizePendingPrice(symbol, dir, isStop, price);

   double stopDist = 0.0;
   if(atr > 0.0)
      stopDist = p.stopMult * atr;
   if(stopDist > 0.0 && stopDist < minD)
      stopDist = minD;

   double sl = 0.0;
   double tp = 0.0; // Scouter: TP always 0
   GsxStratStopDecision stratDec;
   GsxStratStopDecisionClear(stratDec);
   double stratDist = 0.0;
   if(p.strategicStopEnable && atr > 0.0)
     {
      if(GsxStrategicStopBuildFromEntry(symbol, atr, p, stratDec))
         stratDist = stratDec.finalDist;
      else
         stratDist = GsxStrategicStopDistanceLegacy(symbol, atr, true, p.strategicStopMult);
      if(stratDist > 0.0)
        {
         sl = GsxStratStopPrice(dir, price, stratDist, digits);
         sl = GsxStratStopValidateVsMarket(symbol, dir, price, sl);
        }
     }

   if(p.autoLot && stopDist <= 0.0 && p.verbose)
      PrintFormat("GsignalX Entry: AUTO→FIX fallback on %s pending (no ATR sizing distance)", symbol);

   double lot = GsxCalcLot(symbol, stopDist, p.autoLot, p.riskMode,
                           p.riskPct, p.fixedLot, p.maxLot, p.verbose);
   if(lot <= 0.0)
     { action = "computed lot is zero"; return(false); }

   string cmt = p.comment + (isStop ? " STP" : " LMT");
   bool   ok  = false;

   trade.SetExpertMagicNumber(p.magic);
   trade.SetDeviationInPoints(p.slippage);

   ENUM_ORDER_TYPE_FILLING fills[3] = {ORDER_FILLING_RETURN, ORDER_FILLING_IOC, ORDER_FILLING_FOK};
   for(int attempt = 0; attempt < 2 && !ok; attempt++)
     {
      if(attempt == 1)
        {
         price = GsxNormalizePendingPrice(symbol, dir, isStop, price);
         if(sl > 0.0 && stratDist > 0.0)
           {
            sl = GsxStratStopPrice(dir, price, stratDist, digits);
            sl = GsxStratStopValidateVsMarket(symbol, dir, price, sl);
           }
        }

      for(int a = 0; a < 3 && !ok; a++)
        {
         GsxTrySetFilling(trade, fills[a]);
         if(dir == 1)
            ok = isStop ? trade.BuyStop(lot, price, symbol, sl, tp, ORDER_TIME_GTC, 0, cmt)
                        : trade.BuyLimit(lot, price, symbol, sl, tp, ORDER_TIME_GTC, 0, cmt);
         else
            ok = isStop ? trade.SellStop(lot, price, symbol, sl, tp, ORDER_TIME_GTC, 0, cmt)
                        : trade.SellLimit(lot, price, symbol, sl, tp, ORDER_TIME_GTC, 0, cmt);
        }
     }

   if(!ok)
     {
      action = "pending failed: " + IntegerToString((int)trade.ResultRetcode()) +
               " " + trade.ResultRetcodeDescription();
      return(false);
     }

   action = ((dir == 1) ? "BUY " : "SELL ") + (isStop ? "STOP " : "LIMIT ") +
            DoubleToString(lot, 2) + " @ " + DoubleToString(price, digits);
   if(stratDec.ok)
      GsxStratStopPersistPending(p.magic, symbol, stratDec);
   if(sl > 0.0 && stratDist > 0.0)
      PrintFormat("GsignalX Entry: catastrophe SL pending %s %.5f | %s",
                  symbol, sl, stratDec.reason);
   return(true);
  }

//+------------------------------------------------------------------+
//| One-shot: after pending fill, re-anchor SL to entry ± finalDist. |
//| Call each cycle from Service/Desk/Chart.                          |
//+------------------------------------------------------------------+
int GsxStratStopRefreshFilled(CTrade &trade, const long magic, const bool verbose)
  {
   int nFixed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      GsxStratStopDecision existing;
      if(GsxStratStopLoad(ticket, magic, existing))
         continue; // already bound to this ticket

      GsxStratStopDecision pend;
      if(!GsxStratStopLoadPending(magic, sym, pend) || !pend.ok || pend.finalDist <= 0.0)
         continue;

      int dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSl = PositionGetDouble(POSITION_SL);
      double curTp = PositionGetDouble(POSITION_TP);
      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

      double wantSl = GsxStratStopPrice(dir, entry, pend.finalDist, digits);
      wantSl = GsxStratStopValidateVsMarket(sym, dir, entry, wantSl);
      if(wantSl <= 0.0)
         continue;

      double point = SymbolInfoDouble(sym, SYMBOL_POINT);
      if(point <= 0.0)
         point = 1e-5;
      // Skip if already within 2 points of intended
      if(curSl > 0.0 && MathAbs(curSl - wantSl) < 2.0 * point)
        {
         GsxStratStopPersist(ticket, magic, pend);
         GsxStratStopClearPending(magic, sym);
         continue;
        }

      trade.SetExpertMagicNumber(magic);
      if(trade.PositionModify(ticket, wantSl, curTp))
        {
         GsxStratStopPersist(ticket, magic, pend);
         GsxStratStopClearPending(magic, sym);
         nFixed++;
         if(verbose)
            PrintFormat("GsignalX Entry: fill SL refresh #%I64u %s SL %.5f -> %.5f | %s",
                        ticket, sym, curSl, wantSl, pend.reason);
        }
     }
   return(nFixed);
  }

//+------------------------------------------------------------------+
//| Market or bracket entry. Scouter SL only (catastrophe), TP=0.     |
//+------------------------------------------------------------------+
bool GsxPlaceEntry(CTrade &trade,
                   const string symbol,
                   const int dir,
                   const GsxEngineState &st,
                   const GsxEntryParams &p,
                   string &action)
  {
   action = "";
   if(dir == 0)
      return(false);
   if(dir > 0 && !p.allowLong)
     { action = "longs disabled"; return(false); }
   if(dir < 0 && !p.allowShort)
     { action = "shorts disabled"; return(false); }

   if(p.entryMode == GSX_ENTRY_MARKET)
      return(GsxOpenMarket(trade, symbol, dir, st, p, action));

   if(!st.ready || st.n < 1)
     { action = "engines not ready"; return(false); }

   double atr    = GsxEngTipAtr(st);
   int    digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minD   = GsxBrokerMinDistance(symbol);

   double limOff = GsxOffsetPrice(symbol, p.offsetUnit, p.limitOffset);
   double stpOff = GsxOffsetPrice(symbol, p.offsetUnit, p.stopOffset);
   if(limOff <= minD)
      limOff = minD + point;
   if(stpOff <= minD)
      stpOff = minD + point;

   double base = GsxSignalAnchorOpen(symbol, st, p.pendFromSignalOpen, st.n - 1);
   bool placed = false;
   string lastAct = "";

   // Clean same-symbol pendings before placing a fresh BOTH bracket
   GsxDeletePendings(trade, symbol, p.magic, "pre-bracket");

   if(p.entryMode == GSX_ENTRY_LIMIT || p.entryMode == GSX_ENTRY_BOTH)
     {
      double px = (dir == 1) ? (base - limOff) : (base + limOff);
      px = GsxNormalizePendingPrice(symbol, dir, false, px);
      string act = "";
      if(GsxPlacePending(trade, symbol, dir, false, px, atr, p, act))
        {
         placed = true;
         lastAct = act;
        }
      else
         if(p.verbose)
            Print("GsignalX EntryExec: Limit failed on ", symbol, " @ ",
                  DoubleToString(px, digits), " (", act, ")");
     }

   if(p.entryMode == GSX_ENTRY_STOP || p.entryMode == GSX_ENTRY_BOTH)
     {
      double px = (dir == 1) ? (base + stpOff) : (base - stpOff);
      px = GsxNormalizePendingPrice(symbol, dir, true, px);
      string act = "";
      if(GsxPlacePending(trade, symbol, dir, true, px, atr, p, act))
        {
         placed = true;
         lastAct = act;
        }
      else
         if(p.verbose)
            Print("GsignalX EntryExec: Stop failed on ", symbol, " @ ",
                  DoubleToString(px, digits), " (", act, ")");
     }

   if(placed)
     {
      action = (lastAct != "") ? lastAct :
               (((dir == 1) ? "BUY" : "SELL") + " bracket @ sig " +
                DoubleToString(base, digits));
      return(true);
     }

   action = "limit/stop not placed";
   return(false);
  }

#endif // GSX_ENTRY_EXEC_MQH
//+------------------------------------------------------------------+
