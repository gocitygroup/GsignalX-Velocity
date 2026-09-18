//+------------------------------------------------------------------+
//|                                              TgDealWatch.mqh      |
//|  Magic-scoped position watch → Telegram OPEN/CLOSE/MODIFY         |
//|  Used by Dashboard (primary) and Chart (failover).                |
//|  CLOSE reasons: CloseTrigger consume first, else DEAL_REASON.     |
//+------------------------------------------------------------------+
#ifndef GSX_TG_DEAL_WATCH_MQH
#define GSX_TG_DEAL_WATCH_MQH

#include <GSignalX/TelegramNotifier.mqh>
#include <GSignalX/CloseTrigger.mqh>

ulong    g_tgwTickets[];
string   g_tgwSym[];
int      g_tgwDir[];
double   g_tgwLots[];
double   g_tgwEntry[];
double   g_tgwSl[];
double   g_tgwTp[];
double   g_tgwSessionPl = 0.0;
int      g_tgwDayWins = 0;
int      g_tgwDayTrades = 0;
int      g_tgwNewOpens = 0;
datetime g_tgwDayKey = 0;

void GsxTgwResetDayIfNeeded()
  {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   datetime dayStart = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
   if(g_tgwDayKey != dayStart)
     {
      g_tgwDayKey = dayStart;
      g_tgwDayWins = 0;
      g_tgwDayTrades = 0;
     }
  }

int GsxTgwFind(const ulong ticket)
  {
   for(int i = 0; i < ArraySize(g_tgwTickets); i++)
      if(g_tgwTickets[i] == ticket)
         return(i);
   return(-1);
  }

void GsxTgwAdd(const ulong ticket, const string sym, const int dir,
               const double lots, const double entry, const double sl, const double tp)
  {
   int n = ArraySize(g_tgwTickets);
   ArrayResize(g_tgwTickets, n + 1);
   ArrayResize(g_tgwSym, n + 1);
   ArrayResize(g_tgwDir, n + 1);
   ArrayResize(g_tgwLots, n + 1);
   ArrayResize(g_tgwEntry, n + 1);
   ArrayResize(g_tgwSl, n + 1);
   ArrayResize(g_tgwTp, n + 1);
   g_tgwTickets[n] = ticket;
   g_tgwSym[n] = sym;
   g_tgwDir[n] = dir;
   g_tgwLots[n] = lots;
   g_tgwEntry[n] = entry;
   g_tgwSl[n] = sl;
   g_tgwTp[n] = tp;
  }

void GsxTgwRemoveAt(const int idx)
  {
   int n = ArraySize(g_tgwTickets);
   if(idx < 0 || idx >= n)
      return;
   for(int i = idx; i < n - 1; i++)
     {
      g_tgwTickets[i] = g_tgwTickets[i + 1];
      g_tgwSym[i] = g_tgwSym[i + 1];
      g_tgwDir[i] = g_tgwDir[i + 1];
      g_tgwLots[i] = g_tgwLots[i + 1];
      g_tgwEntry[i] = g_tgwEntry[i + 1];
      g_tgwSl[i] = g_tgwSl[i + 1];
      g_tgwTp[i] = g_tgwTp[i + 1];
     }
   ArrayResize(g_tgwTickets, n - 1);
   ArrayResize(g_tgwSym, n - 1);
   ArrayResize(g_tgwDir, n - 1);
   ArrayResize(g_tgwLots, n - 1);
   ArrayResize(g_tgwEntry, n - 1);
   ArrayResize(g_tgwSl, n - 1);
   ArrayResize(g_tgwTp, n - 1);
  }

double GsxTgwCloseProfit(const ulong positionId, const long magic)
  {
   if(!HistorySelect(TimeCurrent() - 86400 * 7, TimeCurrent() + 60))
      return(0.0);
   double pl = 0.0;
   int total = HistoryDealsTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0)
         continue;
      if((ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID) != positionId)
         continue;
      if(HistoryDealGetInteger(d, DEAL_MAGIC) != magic)
         continue;
      long entry = HistoryDealGetInteger(d, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         continue;
      pl += HistoryDealGetDouble(d, DEAL_PROFIT)
            + HistoryDealGetDouble(d, DEAL_SWAP)
            + HistoryDealGetDouble(d, DEAL_COMMISSION);
     }
   return(pl);
  }

void GsxTgwSeedFromOpen(const long magic)
  {
   ArrayResize(g_tgwTickets, 0);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      GsxTgwAdd(ticket,
                PositionGetString(POSITION_SYMBOL),
                (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1,
                PositionGetDouble(POSITION_VOLUME),
                PositionGetDouble(POSITION_PRICE_OPEN),
                PositionGetDouble(POSITION_SL),
                PositionGetDouble(POSITION_TP));
     }
  }

// notify=false seeds silently (restart); notify=true sends OPEN/MODIFY/CLOSE
void GsxTgwPoll(const long magic, const GsxTgConfig &cfg, const bool notify)
  {
   GsxTgwResetDayIfNeeded();
   g_tgwNewOpens = 0;
   ulong live[];
   ArrayResize(live, 0);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      int dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      double lots = PositionGetDouble(POSITION_VOLUME);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      int n = ArraySize(live);
      ArrayResize(live, n + 1);
      live[n] = ticket;

      int w = GsxTgwFind(ticket);
      if(w < 0)
        {
         GsxTgwAdd(ticket, sym, dir, lots, entry, sl, tp);
         g_tgwNewOpens++;
         if(notify)
            GsxTgNotifyOpen(cfg, GsxTgFormatOpen(sym, (dir > 0 ? "BUY" : "SELL"),
                                                 lots, entry, sl, tp));
        }
      else if(notify)
        {
         if(MathAbs(g_tgwSl[w] - sl) > 1e-8 || MathAbs(g_tgwTp[w] - tp) > 1e-8)
           {
            g_tgwSl[w] = sl;
            g_tgwTp[w] = tp;
            GsxTgNotifyModify(cfg, GsxTgFormatModify(sym, sl, tp));
           }
        }
     }

   // Collect closed tickets first so we HistorySelect once per poll wave
   ulong closedTickets[];
   int   closedIdx[];
   ArrayResize(closedTickets, 0);
   ArrayResize(closedIdx, 0);

   for(int w = ArraySize(g_tgwTickets) - 1; w >= 0; w--)
     {
      ulong t = g_tgwTickets[w];
      bool found = false;
      for(int k = 0; k < ArraySize(live); k++)
         if(live[k] == t)
           {
            found = true;
            break;
           }
      if(found)
         continue;
      int cn = ArraySize(closedTickets);
      ArrayResize(closedTickets, cn + 1);
      ArrayResize(closedIdx, cn + 1);
      closedTickets[cn] = t;
      closedIdx[cn] = w;
     }

   bool historyReady = false;
   if(ArraySize(closedTickets) > 0)
      historyReady = HistorySelect(TimeCurrent() - 86400 * 7, TimeCurrent() + 60);

   // Sort closedIdx descending for safe RemoveAt
   for(int a = 0; a < ArraySize(closedIdx); a++)
      for(int b = a + 1; b < ArraySize(closedIdx); b++)
         if(closedIdx[b] > closedIdx[a])
           {
            int tmpI = closedIdx[a];
            closedIdx[a] = closedIdx[b];
            closedIdx[b] = tmpI;
            ulong tmpT = closedTickets[a];
            closedTickets[a] = closedTickets[b];
            closedTickets[b] = tmpT;
           }

   for(int c = 0; c < ArraySize(closedTickets); c++)
     {
      int w = closedIdx[c];
      ulong t = closedTickets[c];

      double pl = 0.0;
      // Prefer CloseTrigger (Scouter tag); else DEAL_REASON → BROKER-SL / …
      string reason = GsxCtResolveReason(t, magic, historyReady, pl);
      if(MathAbs(pl) < 1e-12)
         pl = GsxTgwCloseProfit(t, magic); // may re-select history; ok

      // If consume already set pl from emit, keep it; GsxTgwCloseProfit as fallback
      if(MathAbs(pl) < 1e-12 && historyReady)
        {
         // recompute from already-selected history without second HistorySelect
         int total = HistoryDealsTotal();
         for(int i = total - 1; i >= 0; i--)
           {
            ulong d = HistoryDealGetTicket(i);
            if(d == 0)
               continue;
            if((ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID) != t)
               continue;
            if(HistoryDealGetInteger(d, DEAL_MAGIC) != magic)
               continue;
            long entry = HistoryDealGetInteger(d, DEAL_ENTRY);
            if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
               continue;
            pl += HistoryDealGetDouble(d, DEAL_PROFIT)
                  + HistoryDealGetDouble(d, DEAL_SWAP)
                  + HistoryDealGetDouble(d, DEAL_COMMISSION);
           }
        }

      if(notify)
         GsxTgNotifyClose(cfg, GsxTgFormatCloseEx(g_tgwSym[w],
                                                  (g_tgwDir[w] > 0 ? "BUY" : "SELL"),
                                                  g_tgwLots[w], g_tgwEntry[w], pl, reason));
      g_tgwSessionPl += pl;
      g_tgwDayTrades++;
      if(pl > 0.0)
         g_tgwDayWins++;
      GsxTgwRemoveAt(w);
     }
  }

#endif // GSX_TG_DEAL_WATCH_MQH
//+------------------------------------------------------------------+
