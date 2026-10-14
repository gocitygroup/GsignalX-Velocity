//+------------------------------------------------------------------+
//|                                                 OcoStraddle.mqh   |
//|  Optional two-sided BuyStop+SellStop breakout straddle (additive).|
//|  Distinct from GSX_ENTRY_BOTH same-dir limit+stop bracket.        |
//|  Never market-closes — trail SL only; Scouter owns exits.         |
//+------------------------------------------------------------------+
#ifndef GSX_OCO_STRADDLE_MQH
#define GSX_OCO_STRADDLE_MQH

#include <Trade\Trade.mqh>

#define GSX_OCO_CMT_BUY   "GSX_OCO_BUY"
#define GSX_OCO_CMT_SELL  "GSX_OCO_SELL"
#define GSX_OCO_CMT_TAG   "GSX_OCO_"

enum ENUM_GSX_OCO_STATE
  {
   GSX_OCO_IDLE     = 0,
   GSX_OCO_WAITING  = 1,
   GSX_OCO_ORDERS   = 2,
   GSX_OCO_MANAGING = 3,
   GSX_OCO_FINISHED = 4
  };

//+------------------------------------------------------------------+
struct GsxOcoConfig
  {
   bool   enable;
   int    activationHour;     // server TimeCurrent hour 0..23
   int    activationMinute;   // 0..59
   int    entryOffsetPts;     // points (SYMBOL_POINT)
   int    initialStopPts;     // 0 = no initial SL on pendings
   int    takeProfitPts;      // 0 = no TP (Scouter parity default)
   int    trailPts;           // 0 = trail off
   int    trailThrottleMs;
   double volumeLots;         // fixed lot for each stop
   int    slippage;
   long   magic;
   bool   verbose;
  };

void GsxOcoConfigClear(GsxOcoConfig &c)
  {
   c.enable = false;
   c.activationHour = 0;
   c.activationMinute = 0;
   c.entryOffsetPts = 20;
   c.initialStopPts = 50;
   c.takeProfitPts = 0;
   c.trailPts = 30;
   c.trailThrottleMs = 250;
   c.volumeLots = 0.01;
   c.slippage = 20;
   c.magic = 0;
   c.verbose = false;
  }

//+------------------------------------------------------------------+
struct GsxOcoInstance
  {
   ENUM_GSX_OCO_STATE state;
   string   symbol;
   string   instanceId;
   datetime triggerAt;
   datetime activationAt;
   datetime signalEventAt;   // lastSigChange / join change used to arm
   ulong    buyTicket;
   ulong    sellTicket;
   ulong    posTicket;
   bool     managedIsBuy;
   bool     placeRequested;
   datetime lastTrailAt;
   string   lastError;
   long     lastPersistFp;
  };

void GsxOcoInstClear(GsxOcoInstance &o)
  {
   o.state = GSX_OCO_IDLE;
   o.symbol = "";
   o.instanceId = "";
   o.triggerAt = 0;
   o.activationAt = 0;
   o.signalEventAt = 0;
   o.buyTicket = 0;
   o.sellTicket = 0;
   o.posTicket = 0;
   o.managedIsBuy = false;
   o.placeRequested = false;
   o.lastTrailAt = 0;
   o.lastError = "";
   o.lastPersistFp = 0;
  }

bool GsxOcoNeedsWork(const GsxOcoInstance &o, const GsxOcoConfig &c)
  {
   if(!c.enable)
      return(false);
   return(o.state == GSX_OCO_WAITING || o.state == GSX_OCO_ORDERS ||
          o.state == GSX_OCO_MANAGING);
  }

bool GsxIsOcoStraddleComment(const string cmt)
  {
   return(StringFind(cmt, GSX_OCO_CMT_TAG) == 0);
  }

//+------------------------------------------------------------------+
//| UI chip helpers (chart + Multisymbol chrome) — DRY labels/colors. |
//+------------------------------------------------------------------+
string GsxOcoChipLabel(const bool enable, const int state, const bool dense)
  {
   if(!enable)
      return(dense ? "OCO" : "OCO");
   if(state == GSX_OCO_WAITING)
      return(dense ? "O·ARM" : "OCO·ARM");
   if(state == GSX_OCO_ORDERS)
      return(dense ? "O·OUT" : "OCO·OUT");
   if(state == GSX_OCO_MANAGING)
      return(dense ? "O·IN" : "OCO·IN");
   // Idle / Finished while enabled
   return(dense ? "OCO" : "OCO ON");
  }

void GsxOcoChipColors(const bool enable, const int state,
                      color &bg, color &fg,
                      const color colIdle, const color colAccent,
                      const color colBull, const color colMuted,
                      const color colPanelBg)
  {
   if(!enable)
     {
      bg = colIdle;
      fg = colMuted;
      return;
     }
   if(state == GSX_OCO_MANAGING)
     {
      bg = colBull;
      fg = colPanelBg;
      return;
     }
   if(state == GSX_OCO_WAITING || state == GSX_OCO_ORDERS)
     {
      bg = colAccent;
      fg = colPanelBg;
      return;
     }
   bg = colBull;
   fg = colPanelBg;
  }

//+------------------------------------------------------------------+
//| Broker helpers                                                    |
//+------------------------------------------------------------------+
double GsxOcoPoint(const string symbol)
  {
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   return(pt > 0.0 ? pt : 1e-5);
  }

double GsxOcoMinDist(const string symbol)
  {
   double point  = GsxOcoPoint(symbol);
   double stops  = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL)  * point;
   double freeze = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;
   double spread = SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID);
   if(spread < 0.0)
      spread = 0.0;
   return(MathMax(point, MathMax(spread, MathMax(stops, freeze))));
  }

double GsxOcoRoundTick(const string symbol, const double price)
  {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return(NormalizeDouble(price, digits));
  }

datetime GsxOcoComputeActivation(const datetime now, const int hour, const int minute)
  {
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = MathMax(0, MathMin(23, hour));
   dt.min  = MathMax(0, MathMin(59, minute));
   dt.sec  = 0;
   return(StructToTime(dt));
  }

bool GsxOcoValidQuote(const string symbol, double &bid, double &ask, string &reason)
  {
   bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
     { reason = "missing_quote"; return(false); }
   if(ask < bid)
     { reason = "crossed_quote"; return(false); }
   reason = "ok";
   return(true);
  }

bool GsxOcoBuildLevels(const string symbol,
                       const GsxOcoConfig &cfg,
                       double &buyStop, double &sellStop,
                       double &buySl, double &sellSl,
                       double &buyTp, double &sellTp,
                       string &reason)
  {
   buyStop = sellStop = buySl = sellSl = buyTp = sellTp = 0.0;
   double bid = 0.0, ask = 0.0;
   if(!GsxOcoValidQuote(symbol, bid, ask, reason))
      return(false);

   double point = GsxOcoPoint(symbol);
   double minD  = GsxOcoMinDist(symbol);
   double offset = MathMax((double)MathMax(0, cfg.entryOffsetPts) * point, minD);

   buyStop  = GsxOcoRoundTick(symbol, ask + offset);
   sellStop = GsxOcoRoundTick(symbol, bid - offset);
   if(buyStop <= ask)
     { reason = "buy_stop_not_above_ask"; return(false); }
   if(sellStop >= bid)
     { reason = "sell_stop_not_below_bid"; return(false); }

   if(cfg.initialStopPts > 0)
     {
      double slDist = MathMax((double)cfg.initialStopPts * point, minD);
      buySl  = GsxOcoRoundTick(symbol, buyStop - slDist);
      sellSl = GsxOcoRoundTick(symbol, sellStop + slDist);
      if(buySl >= buyStop || sellSl <= sellStop)
        { reason = "initial_sl_invalid"; return(false); }
     }

   if(cfg.takeProfitPts > 0)
     {
      double tpDist = (double)cfg.takeProfitPts * point;
      buyTp  = GsxOcoRoundTick(symbol, buyStop + tpDist);
      sellTp = GsxOcoRoundTick(symbol, sellStop - tpDist);
     }

   reason = "ok";
   return(true);
  }

//+------------------------------------------------------------------+
bool GsxOcoProposeTrail(const bool isBuy,
                        const double price,
                        const double trailDist,
                        const double tick,
                        const double minDist,
                        const double curSl,
                        const bool hasSl,
                        double &proposed,
                        string &reason)
  {
   proposed = 0.0;
   reason = "";
   if(price <= 0.0 || trailDist <= 0.0)
     { reason = "bad_inputs"; return(false); }

   double raw = isBuy ? (price - trailDist) : (price + trailDist);
   proposed = raw;
   if(tick > 0.0)
      proposed = MathRound(raw / tick) * tick;

   if(minDist > 0.0)
     {
      if(isBuy && price - proposed < minDist)
         proposed = price - minDist;
      else if(!isBuy && proposed - price < minDist)
         proposed = price + minDist;
      if(tick > 0.0)
         proposed = MathRound(proposed / tick) * tick;
     }

   if(isBuy && proposed >= price)
     { reason = "sl_not_below_market"; return(false); }
   if(!isBuy && proposed <= price)
     { reason = "sl_not_above_market"; return(false); }

   double eps = (tick > 0.0 ? tick * 0.1 : 1e-10);
   if(hasSl && curSl > 0.0)
     {
      if(isBuy)
        {
         if(proposed <= curSl + eps)
           { reason = "not_tighter"; return(false); }
        }
      else
        {
         if(proposed >= curSl - eps)
           { reason = "not_tighter"; return(false); }
        }
     }

   reason = "ok";
   return(true);
  }

//+------------------------------------------------------------------+
//| v2.20: one Positions+Orders walk → OCO ticket map (manage pass)   |
//+------------------------------------------------------------------+
struct GsxOcoBook
  {
   long   magic;
   bool   valid;
   string pendKeys[];     // "symbol|comment"
   ulong  pendTickets[];
   string posSyms[];
   ulong  posTickets[];
   bool   posIsBuy[];
  };

GsxOcoBook g_gsxOcoBook;

void GsxOcoBookClear(GsxOcoBook &book)
  {
   book.magic = 0;
   book.valid = false;
   ArrayResize(book.pendKeys, 0);
   ArrayResize(book.pendTickets, 0);
   ArrayResize(book.posSyms, 0);
   ArrayResize(book.posTickets, 0);
   ArrayResize(book.posIsBuy, 0);
  }

void GsxOcoBookAddPending(GsxOcoBook &book, const string symbol, const string cmt,
                          const ulong ticket)
  {
   if(symbol == "" || cmt == "" || ticket == 0)
      return;
   string key = symbol + "|" + cmt;
   for(int i = 0; i < ArraySize(book.pendKeys); i++)
     {
      if(book.pendKeys[i] == key)
        {
         book.pendTickets[i] = ticket;
         return;
        }
     }
   int n = ArraySize(book.pendKeys);
   ArrayResize(book.pendKeys, n + 1);
   ArrayResize(book.pendTickets, n + 1);
   book.pendKeys[n] = key;
   book.pendTickets[n] = ticket;
  }

void GsxOcoBookAddPosition(GsxOcoBook &book, const string symbol, const ulong ticket,
                           const bool isBuy)
  {
   if(symbol == "" || ticket == 0)
      return;
   for(int i = 0; i < ArraySize(book.posSyms); i++)
     {
      if(book.posSyms[i] == symbol)
        {
         book.posTickets[i] = ticket;
         book.posIsBuy[i] = isBuy;
         return;
        }
     }
   int n = ArraySize(book.posSyms);
   ArrayResize(book.posSyms, n + 1);
   ArrayResize(book.posTickets, n + 1);
   ArrayResize(book.posIsBuy, n + 1);
   book.posSyms[n] = symbol;
   book.posTickets[n] = ticket;
   book.posIsBuy[n] = isBuy;
  }

void GsxOcoBookBuild(const long magic, GsxOcoBook &book)
  {
   GsxOcoBookClear(book);
   book.magic = magic;

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(!GsxIsOcoStraddleComment(PositionGetString(POSITION_COMMENT)))
         continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      GsxOcoBookAddPosition(book, sym, ticket, isBuy);
     }

   int ototal = OrdersTotal();
   for(int i = 0; i < ototal; i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      string cmt = OrderGetString(ORDER_COMMENT);
      if(!GsxIsOcoStraddleComment(cmt))
         continue;
      GsxOcoBookAddPending(book, OrderGetString(ORDER_SYMBOL), cmt, ticket);
     }

   book.valid = true;
  }

// Begin/End: manage pass sets module book so Find* use O(1) lookups
void GsxOcoBookBegin(const long magic)
  {
   GsxOcoBookBuild(magic, g_gsxOcoBook);
  }

void GsxOcoBookEnd()
  {
   g_gsxOcoBook.valid = false;
  }

bool GsxOcoBookLookupPending(const GsxOcoBook &book, const string symbol,
                             const string cmtExact, ulong &ticket)
  {
   ticket = 0;
   if(!book.valid || symbol == "" || cmtExact == "")
      return(false);
   string key = symbol + "|" + cmtExact;
   for(int i = 0; i < ArraySize(book.pendKeys); i++)
     {
      if(book.pendKeys[i] == key)
        {
         ticket = book.pendTickets[i];
         return(ticket > 0);
        }
     }
   return(false);
  }

bool GsxOcoBookLookupPosition(const GsxOcoBook &book, const string symbol,
                              const ulong preferTicket, ulong &ticket, bool &isBuy)
  {
   ticket = 0;
   isBuy = false;
   if(!book.valid || symbol == "")
      return(false);
   if(preferTicket > 0)
     {
      for(int i = 0; i < ArraySize(book.posTickets); i++)
        {
         if(book.posTickets[i] == preferTicket && book.posSyms[i] == symbol)
           {
            ticket = preferTicket;
            isBuy = book.posIsBuy[i];
            return(true);
           }
        }
     }
   for(int i = 0; i < ArraySize(book.posSyms); i++)
     {
      if(book.posSyms[i] == symbol)
        {
         ticket = book.posTickets[i];
         isBuy = book.posIsBuy[i];
         return(ticket > 0);
        }
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Order book scans (ownership by magic + GSX_OCO_* comment)         |
//| Prefer g_gsxOcoBook when Begin() active; else live scan fallback. |
//+------------------------------------------------------------------+
bool GsxOcoFindPending(const string symbol, const long magic, const string cmtExact,
                       ulong &ticket)
  {
   ticket = 0;
   if(g_gsxOcoBook.valid && g_gsxOcoBook.magic == magic)
      return(GsxOcoBookLookupPending(g_gsxOcoBook, symbol, cmtExact, ticket));

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(t == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol)
         continue;
      if(OrderGetString(ORDER_COMMENT) != cmtExact)
         continue;
      ticket = t;
      return(true);
     }
   return(false);
  }

bool GsxOcoFindPosition(const string symbol, const long magic, const ulong preferTicket,
                        ulong &ticket, bool &isBuy)
  {
   ticket = 0;
   isBuy = false;
   if(preferTicket > 0 && PositionSelectByTicket(preferTicket))
     {
      if(PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == symbol &&
         GsxIsOcoStraddleComment(PositionGetString(POSITION_COMMENT)))
        {
         ticket = preferTicket;
         isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
         return(true);
        }
     }

   if(g_gsxOcoBook.valid && g_gsxOcoBook.magic == magic)
      return(GsxOcoBookLookupPosition(g_gsxOcoBook, symbol, preferTicket, ticket, isBuy));

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if(!GsxIsOcoStraddleComment(PositionGetString(POSITION_COMMENT)))
         continue;
      ticket = t;
      isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      return(true);
     }
   return(false);
  }

int GsxOcoCancelComment(CTrade &tr, const string symbol, const long magic,
                        const string cmtExact, const string why)
  {
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(t == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol)
         continue;
      if(OrderGetString(ORDER_COMMENT) != cmtExact)
         continue;
      if(tr.OrderDelete(t))
        {
         n++;
         PrintFormat("GsignalX OCO: cancel #%I64u %s (%s)", t, cmtExact, why);
        }
      else
         PrintFormat("GsignalX OCO: cancel fail #%I64u ret=%u", t, tr.ResultRetcode());
     }
   return(n);
  }

int GsxOcoCancelAllForSymbol(CTrade &tr, const string symbol, const long magic,
                             const string why)
  {
   int n = 0;
   n += GsxOcoCancelComment(tr, symbol, magic, GSX_OCO_CMT_BUY, why);
   n += GsxOcoCancelComment(tr, symbol, magic, GSX_OCO_CMT_SELL, why);
   return(n);
  }

int GsxOcoCancelAllMagic(CTrade &tr, const long magic, const string why)
  {
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(t == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!GsxIsOcoStraddleComment(OrderGetString(ORDER_COMMENT)))
         continue;
      if(tr.OrderDelete(t))
        {
         n++;
         PrintFormat("GsignalX OCO: cancel #%I64u (%s)", t, why);
        }
     }
   return(n);
  }

//+------------------------------------------------------------------+
//| GV persistence (per magic+symbol)                                 |
//+------------------------------------------------------------------+
string GsxOcoGvKey(const long magic, const string symbol, const string field)
  {
   return(StringFormat("GSX_OCO_%I64d_%s_%s", magic, symbol, field));
  }

long GsxOcoFingerprint(const GsxOcoInstance &o)
  {
   return((long)o.state * 1000003L +
          (long)o.buyTicket + (long)o.sellTicket * 17L +
          (long)o.posTicket * 31L + (long)o.placeRequested);
  }

void GsxOcoPersist(GsxOcoInstance &o, const long magic, const bool force)
  {
   if(o.symbol == "")
      return;
   long fp = GsxOcoFingerprint(o);
   if(!force && fp == o.lastPersistFp)
      return;
   o.lastPersistFp = fp;
   GlobalVariableSet(GsxOcoGvKey(magic, o.symbol, "state"), (double)o.state);
   GlobalVariableSet(GsxOcoGvKey(magic, o.symbol, "trig"), (double)o.triggerAt);
   GlobalVariableSet(GsxOcoGvKey(magic, o.symbol, "act"), (double)o.activationAt);
   GlobalVariableSet(GsxOcoGvKey(magic, o.symbol, "sig"), (double)o.signalEventAt);
   GlobalVariableSet(GsxOcoGvKey(magic, o.symbol, "buy"), (double)o.buyTicket);
   GlobalVariableSet(GsxOcoGvKey(magic, o.symbol, "sell"), (double)o.sellTicket);
   GlobalVariableSet(GsxOcoGvKey(magic, o.symbol, "pos"), (double)o.posTicket);
   GlobalVariableSet(GsxOcoGvKey(magic, o.symbol, "buySide"), o.managedIsBuy ? 1.0 : 0.0);
   GlobalVariableSet(GsxOcoGvKey(magic, o.symbol, "place"), o.placeRequested ? 1.0 : 0.0);
  }

bool GsxOcoRestore(GsxOcoInstance &o, const string symbol, const long magic)
  {
   string k = GsxOcoGvKey(magic, symbol, "state");
   if(!GlobalVariableCheck(k))
      return(false);
   o.symbol = symbol;
   o.state = (ENUM_GSX_OCO_STATE)(int)GlobalVariableGet(k);
   o.triggerAt = (datetime)GlobalVariableGet(GsxOcoGvKey(magic, symbol, "trig"));
   o.activationAt = (datetime)GlobalVariableGet(GsxOcoGvKey(magic, symbol, "act"));
   o.signalEventAt = (datetime)GlobalVariableGet(GsxOcoGvKey(magic, symbol, "sig"));
   o.buyTicket = (ulong)GlobalVariableGet(GsxOcoGvKey(magic, symbol, "buy"));
   o.sellTicket = (ulong)GlobalVariableGet(GsxOcoGvKey(magic, symbol, "sell"));
   o.posTicket = (ulong)GlobalVariableGet(GsxOcoGvKey(magic, symbol, "pos"));
   o.managedIsBuy = (GlobalVariableGet(GsxOcoGvKey(magic, symbol, "buySide")) > 0.5);
   o.placeRequested = (GlobalVariableGet(GsxOcoGvKey(magic, symbol, "place")) > 0.5);
   o.instanceId = StringFormat("%I64d", (long)o.triggerAt);
   if(o.state == GSX_OCO_FINISHED)
      GsxOcoInstClear(o);
   return(true);
  }

void GsxOcoClearGv(const string symbol, const long magic)
  {
   string fields[] = {"state","trig","act","sig","buy","sell","pos","buySide","place"};
   for(int i = 0; i < ArraySize(fields); i++)
     {
      string k = GsxOcoGvKey(magic, symbol, fields[i]);
      if(GlobalVariableCheck(k))
         GlobalVariableDel(k);
     }
  }

//+------------------------------------------------------------------+
void GsxOcoFinish(GsxOcoInstance &o, const string reason)
  {
   o.state = GSX_OCO_FINISHED;
   o.lastError = reason;
   o.placeRequested = false;
  }

void GsxOcoResetIdle(GsxOcoInstance &o)
  {
   // Preserve last signalEventAt so Finished → Idle does not re-arm the same event.
   string sym = o.symbol;
   datetime lastSig = o.signalEventAt;
   GsxOcoInstClear(o);
   o.symbol = sym;
   o.signalEventAt = lastSig;
  }

//+------------------------------------------------------------------+
//| Arm from FollowDir-allowed signal (AUTO or Bias).                 |
//| Duplicate while active → ignore. Finished clears then may re-arm.|
//+------------------------------------------------------------------+
bool GsxOcoOnSignal(GsxOcoInstance &o,
                    const GsxOcoConfig &cfg,
                    const string symbol,
                    const datetime signalEventAt,
                    const datetime now)
  {
   if(!cfg.enable || symbol == "")
      return(false);

   if(o.state == GSX_OCO_FINISHED)
      GsxOcoResetIdle(o);

   if(o.state != GSX_OCO_IDLE)
      return(false); // duplicate while active

   // Distinct signal event required (joinDir / lastSig change time).
   // signalEventAt==0 is never sticky-matched (cold Idle).
   if(signalEventAt > 0 && o.signalEventAt == signalEventAt)
      return(false);

   o.symbol = symbol;
   o.signalEventAt = signalEventAt;
   o.triggerAt = now;
   o.activationAt = GsxOcoComputeActivation(now, cfg.activationHour, cfg.activationMinute);
   // Past wall-clock today → immediately eligible (activationAt <= now)
   o.instanceId = StringFormat("%I64d-%I64d", (long)now, (long)signalEventAt);
   o.buyTicket = 0;
   o.sellTicket = 0;
   o.posTicket = 0;
   o.managedIsBuy = false;
   o.placeRequested = false;
   o.lastError = "";
   o.lastTrailAt = 0;
   o.state = GSX_OCO_WAITING;
   if(cfg.verbose)
      PrintFormat("GsignalX OCO: armed %s instance=%s activation=%s",
                  symbol, o.instanceId, TimeToString(o.activationAt, TIME_DATE|TIME_MINUTES));
   return(true);
  }

//+------------------------------------------------------------------+
bool GsxOcoPlacePair(CTrade &tr, GsxOcoInstance &o, const GsxOcoConfig &cfg,
                     string &reason)
  {
   reason = "";
   double buyStop, sellStop, buySl, sellSl, buyTp, sellTp;
   if(!GsxOcoBuildLevels(o.symbol, cfg, buyStop, sellStop, buySl, sellSl, buyTp, sellTp, reason))
      return(false);

   // Idempotent: if both already exist, accept
   ulong existingBuy = 0, existingSell = 0;
   bool hasBuy = GsxOcoFindPending(o.symbol, cfg.magic, GSX_OCO_CMT_BUY, existingBuy);
   bool hasSell = GsxOcoFindPending(o.symbol, cfg.magic, GSX_OCO_CMT_SELL, existingSell);
   if(hasBuy && hasSell)
     {
      o.buyTicket = existingBuy;
      o.sellTicket = existingSell;
      o.state = GSX_OCO_ORDERS;
      o.placeRequested = true;
      reason = "already_placed";
      return(true);
     }
   if(hasBuy || hasSell)
     {
      // Ambiguous one-sided — cancel orphan and fail
      GsxOcoCancelAllForSymbol(tr, o.symbol, cfg.magic, "orphan_before_place");
      reason = "orphan_pending";
      GsxOcoFinish(o, reason);
      return(false);
     }

   double lot = cfg.volumeLots;
   if(lot <= 0.0)
     {
      reason = "volume_too_small";
      GsxOcoFinish(o, reason);
      return(false);
     }
   double step = SymbolInfoDouble(o.symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(o.symbol, SYMBOL_VOLUME_MIN);
   if(step > 0.0)
      lot = MathFloor(lot / step) * step;
   if(lot < vmin)
     {
      reason = "volume_too_small";
      GsxOcoFinish(o, reason);
      return(false);
     }

   tr.SetExpertMagicNumber(cfg.magic);
   tr.SetDeviationInPoints(cfg.slippage);
   tr.SetTypeFillingBySymbol(o.symbol);

   bool okBuy = tr.BuyStop(lot, buyStop, o.symbol, buySl, buyTp, ORDER_TIME_GTC, 0, GSX_OCO_CMT_BUY);
   ulong buyId = okBuy ? tr.ResultOrder() : 0;
   bool okSell = tr.SellStop(lot, sellStop, o.symbol, sellSl, sellTp, ORDER_TIME_GTC, 0, GSX_OCO_CMT_SELL);
   ulong sellId = okSell ? tr.ResultOrder() : 0;

   if(buyId > 0 && sellId > 0)
     {
      o.buyTicket = buyId;
      o.sellTicket = sellId;
      o.state = GSX_OCO_ORDERS;
      o.placeRequested = true;
      reason = "orders_placed";
      if(cfg.verbose)
         PrintFormat("GsignalX OCO: pair %s buy@%.5f sell@%.5f lot=%.2f",
                     o.symbol, buyStop, sellStop, lot);
      return(true);
     }

   // Partial — cancel accepted side, finish
   if(buyId > 0)
      GsxOcoCancelComment(tr, o.symbol, cfg.magic, GSX_OCO_CMT_BUY, "partial_place");
   if(sellId > 0)
      GsxOcoCancelComment(tr, o.symbol, cfg.magic, GSX_OCO_CMT_SELL, "partial_place");
   reason = "partial_place";
   GsxOcoFinish(o, reason);
   if(cfg.verbose)
      PrintFormat("GsignalX OCO: partial place on %s buyOk=%d sellOk=%d",
                  o.symbol, (int)okBuy, (int)okSell);
   return(false);
  }

//+------------------------------------------------------------------+
void GsxOcoReconcile(CTrade &tr, GsxOcoInstance &o, const GsxOcoConfig &cfg)
  {
   if(!cfg.enable)
     {
      GsxOcoResetIdle(o);
      return;
     }
   if(o.symbol == "")
      return;

   ulong pos = 0;
   bool isBuy = false;
   if(GsxOcoFindPosition(o.symbol, cfg.magic, o.posTicket, pos, isBuy))
     {
      o.posTicket = pos;
      o.managedIsBuy = isBuy;
      o.state = GSX_OCO_MANAGING;
      // Cancel sibling pending
      if(isBuy)
         GsxOcoCancelComment(tr, o.symbol, cfg.magic, GSX_OCO_CMT_SELL, "reconcile_oco");
      else
         GsxOcoCancelComment(tr, o.symbol, cfg.magic, GSX_OCO_CMT_BUY, "reconcile_oco");
      return;
     }

   ulong b = 0, s = 0;
   bool hb = GsxOcoFindPending(o.symbol, cfg.magic, GSX_OCO_CMT_BUY, b);
   bool hs = GsxOcoFindPending(o.symbol, cfg.magic, GSX_OCO_CMT_SELL, s);
   if(hb && hs)
     {
      o.buyTicket = b;
      o.sellTicket = s;
      o.state = GSX_OCO_ORDERS;
      o.placeRequested = true;
      return;
     }
   if(hb || hs)
     {
      GsxOcoCancelAllForSymbol(tr, o.symbol, cfg.magic, "reconcile_orphan");
      GsxOcoFinish(o, "reconcile_orphan_pending");
      return;
     }

   // No broker footprint
   if(o.state == GSX_OCO_WAITING && o.placeRequested)
      GsxOcoFinish(o, "place_lost");
   else
      GsxOcoResetIdle(o);
  }

//+------------------------------------------------------------------+
//| Advance waiting / orders / trail. Never closes a position.        |
//+------------------------------------------------------------------+
void GsxOcoOnTick(CTrade &tr, GsxOcoInstance &o, const GsxOcoConfig &cfg,
                  const datetime now)
  {
   if(!cfg.enable)
     {
      if(o.state != GSX_OCO_IDLE)
        {
         GsxOcoCancelAllForSymbol(tr, o.symbol, cfg.magic, "oco_disabled");
         GsxOcoResetIdle(o);
         GsxOcoClearGv(o.symbol, cfg.magic);
        }
      return;
     }

   if(o.state == GSX_OCO_IDLE || o.state == GSX_OCO_FINISHED)
      return;
   if(o.symbol == "")
      return;

   if(o.state == GSX_OCO_WAITING)
     {
      if(now < o.activationAt)
         return;
      if(o.placeRequested)
         return; // place-once latch
      string why = "";
      o.placeRequested = true; // latch before send (avoid tick spam)
      if(!GsxOcoPlacePair(tr, o, cfg, why))
        {
         if(o.state != GSX_OCO_FINISHED)
           {
            // Quote reject — stay waiting, clear latch to retry next tick
            if(StringFind(why, "quote") >= 0 || StringFind(why, "buy_stop") >= 0 ||
               StringFind(why, "sell_stop") >= 0 || StringFind(why, "initial_sl") >= 0)
              {
               o.placeRequested = false;
               o.lastError = why;
               return;
              }
           }
         GsxOcoPersist(o, cfg.magic, true);
         return;
        }
      GsxOcoPersist(o, cfg.magic, true);
      return;
     }

   if(o.state == GSX_OCO_ORDERS)
     {
      ulong pos = 0;
      bool isBuy = false;
      if(GsxOcoFindPosition(o.symbol, cfg.magic, 0, pos, isBuy))
        {
         o.posTicket = pos;
         o.managedIsBuy = isBuy;
         o.state = GSX_OCO_MANAGING;
         if(isBuy)
            GsxOcoCancelComment(tr, o.symbol, cfg.magic, GSX_OCO_CMT_SELL, "fill_buy_oco");
         else
            GsxOcoCancelComment(tr, o.symbol, cfg.magic, GSX_OCO_CMT_BUY, "fill_sell_oco");
         GsxOcoPersist(o, cfg.magic, true);
         return;
        }

      ulong b = 0, s = 0;
      bool hb = GsxOcoFindPending(o.symbol, cfg.magic, GSX_OCO_CMT_BUY, b);
      bool hs = GsxOcoFindPending(o.symbol, cfg.magic, GSX_OCO_CMT_SELL, s);
      if(!hb && !hs)
        {
         GsxOcoFinish(o, "orders_gone_no_fill");
         GsxOcoPersist(o, cfg.magic, true);
         return;
        }
      if((hb && !hs) || (!hb && hs))
        {
         GsxOcoCancelAllForSymbol(tr, o.symbol, cfg.magic, "orphan_pending");
         GsxOcoFinish(o, "orphan_pending");
         GsxOcoPersist(o, cfg.magic, true);
         return;
        }
      o.buyTicket = b;
      o.sellTicket = s;
      return;
     }

   if(o.state == GSX_OCO_MANAGING)
     {
      ulong pos = 0;
      bool isBuy = false;
      if(!GsxOcoFindPosition(o.symbol, cfg.magic, o.posTicket, pos, isBuy))
        {
         GsxOcoFinish(o, "position_closed");
         GsxOcoPersist(o, cfg.magic, true);
         return;
        }
      o.posTicket = pos;
      o.managedIsBuy = isBuy;

      // Idempotent sibling cancel
      if(isBuy)
         GsxOcoCancelComment(tr, o.symbol, cfg.magic, GSX_OCO_CMT_SELL, "manage_oco");
      else
         GsxOcoCancelComment(tr, o.symbol, cfg.magic, GSX_OCO_CMT_BUY, "manage_oco");

      if(cfg.trailPts <= 0)
         return;

      int throttle = MathMax(0, cfg.trailThrottleMs);
      if(throttle > 0 && o.lastTrailAt != 0)
        {
         // Coarse second clock + GetTickCount for sub-second throttle
         long dtSec = (long)(now - o.lastTrailAt);
         if(dtSec < 0)
            dtSec = 0;
         if(dtSec == 0 && throttle < 1000)
           {
            // same second — allow at most one eval; rely on lastTrailAt stamp
            return;
           }
         if(dtSec * 1000 < throttle)
            return;
        }
      o.lastTrailAt = now;

      if(!PositionSelectByTicket(pos))
         return;
      double curSl = PositionGetDouble(POSITION_SL);
      double curTp = PositionGetDouble(POSITION_TP);
      double price = isBuy ? SymbolInfoDouble(o.symbol, SYMBOL_BID)
                           : SymbolInfoDouble(o.symbol, SYMBOL_ASK);
      double point = GsxOcoPoint(o.symbol);
      double trailDist = (double)cfg.trailPts * point;
      double minD = GsxOcoMinDist(o.symbol);
      double proposed = 0.0;
      string why = "";
      if(!GsxOcoProposeTrail(isBuy, price, trailDist, point, minD, curSl, curSl > 0.0,
                             proposed, why))
         return;
      proposed = GsxOcoRoundTick(o.symbol, proposed);
      tr.SetExpertMagicNumber(cfg.magic);
      if(tr.PositionModify(pos, proposed, curTp))
        {
         if(cfg.verbose)
            PrintFormat("GsignalX OCO: trail #%I64u SL %.5f (%s)", pos, proposed, why);
        }
      else if(cfg.verbose)
         PrintFormat("GsignalX OCO: trail reject #%I64u ret=%u", pos, tr.ResultRetcode());
     }
  }

//+------------------------------------------------------------------+
//| Fill-event helper for OnTradeTransaction (cancel sibling only).   |
//+------------------------------------------------------------------+
bool GsxOcoOnDealIn(CTrade &tr, GsxOcoInstance &o, const GsxOcoConfig &cfg,
                    const ulong dealTicket)
  {
   if(!cfg.enable || o.symbol == "" || dealTicket == 0)
      return(false);
   if(!HistoryDealSelect(dealTicket))
      return(false);
   if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != cfg.magic)
      return(false);
   if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != o.symbol)
      return(false);
   long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
      return(false);
   string cmt = HistoryDealGetString(dealTicket, DEAL_COMMENT);
   // Position comment may differ; accept if we are in ORDERS/MANAGING
   if(o.state != GSX_OCO_ORDERS && o.state != GSX_OCO_MANAGING && o.state != GSX_OCO_WAITING)
     {
      if(!GsxIsOcoStraddleComment(cmt))
         return(false);
     }

   long dtype = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   bool isBuy = (dtype == DEAL_TYPE_BUY);
   ulong pos = 0;
   bool pb = false;
   if(GsxOcoFindPosition(o.symbol, cfg.magic, 0, pos, pb))
     {
      o.posTicket = pos;
      o.managedIsBuy = pb;
     }
   else
      o.managedIsBuy = isBuy;

   o.state = GSX_OCO_MANAGING;
   if(o.managedIsBuy)
      GsxOcoCancelComment(tr, o.symbol, cfg.magic, GSX_OCO_CMT_SELL, "deal_fill_oco");
   else
      GsxOcoCancelComment(tr, o.symbol, cfg.magic, GSX_OCO_CMT_BUY, "deal_fill_oco");
   GsxOcoPersist(o, cfg.magic, true);
   return(true);
  }

#endif // GSX_OCO_STRADDLE_MQH
//+------------------------------------------------------------------+
