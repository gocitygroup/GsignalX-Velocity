//+------------------------------------------------------------------+
//|                                       ProfitHarvest_Now.mq5      |
//|   One-shot companion script: sweeps open positions ONCE and       |
//|   closes whatever already meets a money target, then exits.       |
//|   Use it for manual "take the money now" moments. It does no      |
//|   trailing - that is the job of the EA / Service edition.         |
//+------------------------------------------------------------------+
#property copyright "Profit Scouter"
#property version   "1.10"
#property script_show_inputs
#property description "Profit Scouter - one-shot harvest. Closes GREEN positions already at target."
#property description "Losers are never closed by the harvest - they are reported and left open."

#include <Trade\Trade.mqh>

enum ENUM_HV_SCOPE
  {
   HV_SCOPE_CHART = 0,   // Chart symbol only
   HV_SCOPE_ALL   = 1    // All symbols
  };

input group "=== Filters ==="
input ENUM_HV_SCOPE InpScope      = HV_SCOPE_ALL;  // Symbol scope
input bool   InpUseMagicFilter    = false;   // Filter by magic number
input long   InpMagicNumber       = 0;       // Magic number
input bool   InpIncludeSwap       = true;    // Include swap in profit
input bool   InpIncludeCommission = true;    // Include commission in profit

input group "=== Targets (account currency) ==="
input double InpAccTargetMoney    = 10.0;    // Close ALL if total profit >= (0 = off)
input double InpSymTargetMoney    = 0.0;     // Close a pair basket at >= (0 = off)
input double InpPosTargetMoney    = 0.0;     // Close a single position at >= (0 = off)

input group "=== Execution ==="
input int    InpSlippagePoints    = 30;      // Max slippage (points)
input int    InpMaxRetries        = 3;       // Retries per position
input bool   InpDryRun            = false;   // Report only, do not close
input bool   InpConfirm           = true;    // Ask for confirmation first

CTrade g_trade;

struct HvPos
  {
   ulong    ticket;
   string   sym;
   double   profit;
  };

struct HvAgg
  {
   string   sym;
   double   profit;
   int      count;
  };

HvPos  g_pos[];
HvAgg  g_agg[];

//+------------------------------------------------------------------+
void OnStart()
  {
   string ccy = AccountInfoString(ACCOUNT_CURRENCY);

   g_trade.SetDeviationInPoints(InpSlippagePoints);
   g_trade.SetAsyncMode(false);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   double total = Collect();
   int    n     = ArraySize(g_pos);

   if(n == 0)
     {
      Print("ProfitHarvest: no matching open positions.");
      return;
     }

   PrintFormat("ProfitHarvest: %d position(s), total floating %.2f %s", n, total, ccy);
   for(int i = 0; i < ArraySize(g_agg); i++)
      PrintFormat("   %-12s n=%d  P/L %.2f %s", g_agg[i].sym, g_agg[i].count, g_agg[i].profit, ccy);

   //--- decide what would be closed --------------------------------
   //    Winners only: every mode skips losing tickets. The losers are
   //    reported and left open - this harvest never closes a red trade.
   int green = 0, red = 0;
   double greenSum = 0.0;
   for(int i = 0; i < n; i++)
     {
      if(g_pos[i].profit >= 0.0)
        {
         green++;
         greenSum += g_pos[i].profit;
        }
      else
         red++;
     }

   string plan = "";
   int    mode = 0;   // 1 = green sweep, 2 = baskets, 3 = singles

   if(InpAccTargetMoney > 0.0 && total >= InpAccTargetMoney)
     {
      mode = 1;
      plan = StringFormat("Account target met (%.2f >= %.2f %s): close the %d GREEN position(s) (+%.2f).",
                          total, InpAccTargetMoney, ccy, green, greenSum);
      if(red > 0)
         plan += StringFormat(" %d losing position(s) are LEFT OPEN.", red);
     }
   else
     {
      int baskets = 0, singles = 0;
      for(int i = 0; i < ArraySize(g_agg); i++)
         if(InpSymTargetMoney > 0.0 && g_agg[i].profit >= InpSymTargetMoney)
            baskets++;
      for(int i = 0; i < n; i++)
         if(InpPosTargetMoney > 0.0 && g_pos[i].profit >= InpPosTargetMoney)
            singles++;

      if(baskets > 0)
        {
         mode = 2;
         plan = StringFormat("%d pair basket(s) at or above %.2f %s.", baskets, InpSymTargetMoney, ccy);
        }
      else
         if(singles > 0)
           {
            mode = 3;
            plan = StringFormat("%d single position(s) at or above %.2f %s.", singles, InpPosTargetMoney, ccy);
           }
     }

   if(mode == 0)
     {
      Print("ProfitHarvest: nothing meets a target. Nothing closed.");
      return;
     }

   Print("ProfitHarvest: ", plan);

   if(InpDryRun)
     {
      Print("ProfitHarvest: dry run - no orders sent.");
      return;
     }

   if(InpConfirm)
     {
      int answer = MessageBox(plan + "\n\nProceed?", "Profit Harvest", MB_YESNO | MB_ICONQUESTION);
      if(answer != IDYES)
        {
         Print("ProfitHarvest: cancelled by user.");
         return;
        }
     }

   if(!TradingReady())
     {
      Print("ProfitHarvest: trading is not permitted (Algo Trading off, or account restricted).");
      return;
     }

   //--- execute -----------------------------------------------------
   //    Winners only: losers are skipped and left open.
   int closed = 0, skipped = 0;
   if(mode == 1)
     {
      for(int i = n - 1; i >= 0; i--)
        {
         if(g_pos[i].profit < 0.0)
           {
            skipped++;
            continue;
           }
         if(ClosePos(g_pos[i].ticket))
            closed++;
        }
     }
   else
      if(mode == 2)
        {
         for(int a = 0; a < ArraySize(g_agg); a++)
           {
            if(!(InpSymTargetMoney > 0.0 && g_agg[a].profit >= InpSymTargetMoney))
               continue;
            for(int i = n - 1; i >= 0; i--)
              {
               if(g_pos[i].sym != g_agg[a].sym)
                  continue;
               if(g_pos[i].profit < 0.0)
                 {
                  skipped++;
                  continue;
                 }
               if(ClosePos(g_pos[i].ticket))
                  closed++;
              }
           }
        }
      else
        {
         for(int i = n - 1; i >= 0; i--)
            if(InpPosTargetMoney > 0.0 && g_pos[i].profit >= InpPosTargetMoney && ClosePos(g_pos[i].ticket))
               closed++;
        }

   PrintFormat("ProfitHarvest: finished, %d position(s) closed, %d losing position(s) left open.",
               closed, skipped);
  }

//+------------------------------------------------------------------+
double Collect()
  {
   ArrayResize(g_pos, 0);
   ArrayResize(g_agg, 0);
   double total = 0.0;

   int t = PositionsTotal();
   for(int i = 0; i < t; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      string sym   = PositionGetString(POSITION_SYMBOL);
      long   magic = PositionGetInteger(POSITION_MAGIC);

      if(InpUseMagicFilter && magic != InpMagicNumber)
         continue;
      if(InpScope == HV_SCOPE_CHART && sym != _Symbol)
         continue;

      double profit = PositionGetDouble(POSITION_PROFIT);
      if(InpIncludeSwap)
         profit += PositionGetDouble(POSITION_SWAP);
      if(InpIncludeCommission)
         profit += DealCommission((ulong)PositionGetInteger(POSITION_IDENTIFIER));

      int n = ArraySize(g_pos);
      ArrayResize(g_pos, n + 1);
      g_pos[n].ticket = ticket;
      g_pos[n].sym    = sym;
      g_pos[n].profit = profit;

      int a = AggIndex(sym);
      g_agg[a].profit += profit;
      g_agg[a].count++;

      total += profit;
     }
   return total;
  }

//+------------------------------------------------------------------+
int AggIndex(string sym)
  {
   for(int i = 0; i < ArraySize(g_agg); i++)
      if(g_agg[i].sym == sym)
         return i;
   int n = ArraySize(g_agg);
   ArrayResize(g_agg, n + 1);
   g_agg[n].sym    = sym;
   g_agg[n].profit = 0.0;
   g_agg[n].count  = 0;
   return n;
  }

//+------------------------------------------------------------------+
double DealCommission(ulong identifier)
  {
   double c = 0.0;
   if(HistorySelectByPosition(identifier))
     {
      int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; i++)
        {
         ulong d = HistoryDealGetTicket(i);
         if(d > 0)
            c += HistoryDealGetDouble(d, DEAL_COMMISSION);
        }
     }
   return c;
  }

//+------------------------------------------------------------------+
bool TradingReady()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
bool ClosePos(ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
      return false;

   string sym = PositionGetString(POSITION_SYMBOL);

   //--- HARD GUARD: never close a losing trade, whatever the mode
   double p = PositionGetDouble(POSITION_PROFIT);
   if(InpIncludeSwap)
      p += PositionGetDouble(POSITION_SWAP);
   if(InpIncludeCommission)
      p += DealCommission((ulong)PositionGetInteger(POSITION_IDENTIFIER));
   if(p < 0.0)
     {
      PrintFormat("ProfitHarvest: close #%I64u %s BLOCKED - never closes a losing trade (%.2f)",
                  ticket, sym, p);
      return false;
     }

   g_trade.SetExpertMagicNumber((ulong)PositionGetInteger(POSITION_MAGIC));
   g_trade.SetTypeFillingBySymbol(sym);

   int tries = (int)MathMax(1, InpMaxRetries);
   for(int a = 0; a < tries; a++)
     {
      if(IsStopped())
         return false;
      if(g_trade.PositionClose(ticket, InpSlippagePoints))
        {
         PrintFormat("ProfitHarvest: closed #%I64u %s", ticket, sym);
         return true;
        }
      uint rc = g_trade.ResultRetcode();
      PrintFormat("ProfitHarvest: close #%I64u failed rc=%u (%s)",
                  ticket, rc, g_trade.ResultRetcodeDescription());
      if(rc == TRADE_RETCODE_MARKET_CLOSED || rc == TRADE_RETCODE_TRADE_DISABLED)
         break;
      Sleep(200);
      if(!PositionSelectByTicket(ticket))
         return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
