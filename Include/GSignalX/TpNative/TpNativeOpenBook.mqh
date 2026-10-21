//+------------------------------------------------------------------+
//| TpNativeOpenBook.mqh — open symbols + non-blocking refresh queue  |
//+------------------------------------------------------------------+
#ifndef GSX_TP_NATIVE_OPEN_BOOK_MQH
#define GSX_TP_NATIVE_OPEN_BOOK_MQH

#include <GSignalX/RosterStore.mqh>

#define TPN_REFRESH_Q_MAX  32
#define TPN_UI_BOOTSTRAP_CAP  300

string   g_tpnRefreshQ[];
int      g_tpnRefreshQN = 0;
bool     g_tpnRefreshForce = false;

// Parallel last-seen closed-bar open times (avoid structs with dynamic arrays).
string   g_tpnSeenSym[];
datetime g_tpnSeenBar[];
int      g_tpnSeenN = 0;

int TpnCollectOpenSymbols(const long magic, string &out[])
  {
   ArrayResize(out, 0);
   for(int p = PositionsTotal() - 1; p >= 0; p--)
     {
      ulong ticket = PositionGetTicket(p);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(magic != 0 && PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      if(sym == "")
         continue;
      bool dup = false;
      for(int i = 0; i < ArraySize(out); i++)
        {
         if(out[i] == sym)
           {
            dup = true;
            break;
           }
        }
      if(dup)
         continue;
      int n = ArraySize(out);
      ArrayResize(out, n + 1);
      out[n] = sym;
     }
   return(ArraySize(out));
  }

bool TpnRefreshQContains(const string symbol)
  {
   for(int i = 0; i < g_tpnRefreshQN; i++)
      if(g_tpnRefreshQ[i] == symbol)
         return(true);
   return(false);
  }

void TpnRefreshQPush(const string symbol)
  {
   if(symbol == "" || TpnRefreshQContains(symbol))
      return;
   if(g_tpnRefreshQN >= TPN_REFRESH_Q_MAX)
      return;
   ArrayResize(g_tpnRefreshQ, g_tpnRefreshQN + 1);
   g_tpnRefreshQ[g_tpnRefreshQN] = symbol;
   g_tpnRefreshQN++;
  }

void TpnDeskRequestRefresh(const long magic)
  {
   g_tpnRefreshForce = true;
   string open[];
   TpnCollectOpenSymbols(magic, open);
   for(int i = 0; i < ArraySize(open); i++)
      TpnRefreshQPush(open[i]);
  }

bool TpnDeskPopRefresh(string &symbol)
  {
   if(g_tpnRefreshQN <= 0)
     {
      symbol = "";
      return(false);
     }
   symbol = g_tpnRefreshQ[0];
   for(int i = 1; i < g_tpnRefreshQN; i++)
      g_tpnRefreshQ[i - 1] = g_tpnRefreshQ[i];
   g_tpnRefreshQN--;
   ArrayResize(g_tpnRefreshQ, g_tpnRefreshQN);
   return(true);
  }

bool TpnDeskRefreshPending()
  {
   return(g_tpnRefreshForce || g_tpnRefreshQN > 0);
  }

void TpnDeskClearRefreshForce()
  {
   g_tpnRefreshForce = false;
  }

int TpnSeenFind(const string symbol)
  {
   for(int i = 0; i < g_tpnSeenN; i++)
      if(g_tpnSeenSym[i] == symbol)
         return(i);
   return(-1);
  }

datetime TpnSeenGet(const string symbol)
  {
   int i = TpnSeenFind(symbol);
   return(i >= 0 ? g_tpnSeenBar[i] : 0);
  }

void TpnSeenSet(const string symbol, const datetime barOpen)
  {
   int i = TpnSeenFind(symbol);
   if(i >= 0)
     {
      g_tpnSeenBar[i] = barOpen;
      return;
     }
   ArrayResize(g_tpnSeenSym, g_tpnSeenN + 1);
   ArrayResize(g_tpnSeenBar, g_tpnSeenN + 1);
   g_tpnSeenSym[g_tpnSeenN] = symbol;
   g_tpnSeenBar[g_tpnSeenN] = barOpen;
   g_tpnSeenN++;
  }

int TpnUiBootstrapBars(const int historyBars, const int period)
  {
   int need = MathMax(historyBars, period + 2);
   if(need > TPN_UI_BOOTSTRAP_CAP)
      need = TPN_UI_BOOTSTRAP_CAP;
   return(need);
  }

// O(1) — GV + enqueue only (never bootstrap/flush). Chart/Desk apply tip on tick.
void TpnOnTpUiChanged(const long magic, const bool enabled)
  {
   GsxRosterTpEnableSet(magic, enabled);
   if(enabled)
      TpnDeskRequestRefresh(magic);
   else
     {
      while(g_tpnRefreshQN > 0)
        {
         string dump;
         TpnDeskPopRefresh(dump);
        }
      TpnDeskClearRefreshForce();
     }
  }

void TpnOnTpTypeChanged(const long magic, const int typ)
  {
   GsxRosterTpTypeSet(magic, typ);
   if(GsxRosterTpEnableGet(magic, false))
      TpnDeskRequestRefresh(magic);
  }

#endif // GSX_TP_NATIVE_OPEN_BOOK_MQH
