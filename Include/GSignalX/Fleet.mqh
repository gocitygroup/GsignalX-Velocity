//+------------------------------------------------------------------+
//|                                                     Fleet.mqh     |
//|  Shared fleet lock / ownership / pair accounting (chart+service)  |
//|  Callers pass magic + cooldown — no Inp* reads inside this file.  |
//+------------------------------------------------------------------+
#ifndef GSX_FLEET_MQH
#define GSX_FLEET_MQH

//+------------------------------------------------------------------+
string GsxFleetLockVarName(const long magic)
  {
   return("GSX_FLEET_LOCK_" + IntegerToString((int)magic));
  }

string GsxFleetOwnVarName(const long magic)
  {
   return("GSX_SVC_OWN_" + IntegerToString((int)magic));
  }

string GsxFleetRunVarName(const long magic)
  {
   return("GSX_SVC_RUN_" + IntegerToString((int)magic));
  }

//+------------------------------------------------------------------+
//| Service ownership GV (1 = Service owns fleet for this magic)     |
//+------------------------------------------------------------------+
void GsxFleetServiceOwnSet(const long magic, const bool own)
  {
   GlobalVariableSet(GsxFleetOwnVarName(magic), own ? 1.0 : 0.0);
  }

bool GsxFleetServiceOwns(const long magic)
  {
   string name = GsxFleetOwnVarName(magic);
   if(!GlobalVariableCheck(name))
      return(false);
   return(GlobalVariableGet(name) > 0.5);
  }

//+------------------------------------------------------------------+
//| Service PLAY/STOP GV (1 = run / PLAY)                            |
//+------------------------------------------------------------------+
void GsxFleetServiceRunSet(const long magic, const bool run)
  {
   GlobalVariableSet(GsxFleetRunVarName(magic), run ? 1.0 : 0.0);
  }

bool GsxFleetServiceRunGet(const long magic)
  {
   string name = GsxFleetRunVarName(magic);
   if(!GlobalVariableCheck(name))
      return(false);
   return(GlobalVariableGet(name) > 0.5);
  }

//+------------------------------------------------------------------+
void GsxFleetAddUniqueSymbol(string &syms[], const string s)
  {
   if(s == "")
      return;
   for(int k = 0; k < ArraySize(syms); k++)
      if(syms[k] == s)
         return;
   int n = ArraySize(syms);
   ArrayResize(syms, n + 1);
   syms[n] = s;
  }

//+------------------------------------------------------------------+
//| Account-wide floating P/L + position count for magic             |
//+------------------------------------------------------------------+
void GsxFleetFloating(const long magic, double &pl, int &count)
  {
   pl    = 0.0;
   count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      count++;
     }
  }

//+------------------------------------------------------------------+
//| Distinct symbols with open position OR working pending (magic)   |
//+------------------------------------------------------------------+
int GsxFleetActivePairs(const long magic)
  {
   string syms[];

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      GsxFleetAddUniqueSymbol(syms, PositionGetString(POSITION_SYMBOL));
     }

   int ototal = OrdersTotal();
   for(int i = 0; i < ototal; i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      GsxFleetAddUniqueSymbol(syms, OrderGetString(ORDER_SYMBOL));
     }

   return(ArraySize(syms));
  }

//+------------------------------------------------------------------+
//| Atomic claim of terminal-wide fill slot (CAS + cooldown)         |
//+------------------------------------------------------------------+
bool GsxFleetTryClaim(const long magic, const int cooldownSec, const datetime now)
  {
   string name = GsxFleetLockVarName(magic);
   double prev = 0.0;
   if(GlobalVariableCheck(name))
      prev = GlobalVariableGet(name);
   else
      GlobalVariableSet(name, 0.0);
   if(prev > 0.0 && cooldownSec > 0 && (now - (datetime)prev) < cooldownSec)
      return(false);
   return(GlobalVariableSetOnCondition(name, (double)now, prev));
  }

void GsxFleetClearClaim(const long magic)
  {
   GlobalVariableSet(GsxFleetLockVarName(magic), 0.0);
  }

//+------------------------------------------------------------------+
//| True if magic already has a position or pending on symbol        |
//+------------------------------------------------------------------+
bool GsxFleetSymbolBusy(const string symbol, const long magic)
  {
   if(symbol == "")
      return(false);

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == symbol)
         return(true);
     }

   int ototal = OrdersTotal();
   for(int i = 0; i < ototal; i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) == symbol)
         return(true);
     }
   return(false);
  }

#endif // GSX_FLEET_MQH
//+------------------------------------------------------------------+
