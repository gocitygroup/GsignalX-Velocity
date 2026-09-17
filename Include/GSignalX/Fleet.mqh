//+------------------------------------------------------------------+
//|                                                     Fleet.mqh     |
//|  Shared fleet lock / ownership / pair accounting (chart+service)  |
//|  Callers pass magic + cooldown — no Inp* reads inside this file.  |
//+------------------------------------------------------------------+
#ifndef GSX_FLEET_MQH
#define GSX_FLEET_MQH

#include <GSignalX/SymbolClass.mqh>

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

// Host tag: who claimed OWN (desk EA vs headless Service) — mutual exclusion
#define GSX_HOST_NONE    0
#define GSX_HOST_DESK    1
#define GSX_HOST_SERVICE 2

string GsxFleetHostVarName(const long magic)
  {
   return("GSX_SVC_HOST_" + IntegerToString((int)magic));
  }

void GsxFleetHostSet(const long magic, const int host)
  {
   GlobalVariableSet(GsxFleetHostVarName(magic), (double)host);
  }

int GsxFleetHostGet(const long magic)
  {
   string name = GsxFleetHostVarName(magic);
   if(!GlobalVariableCheck(name))
      return(GSX_HOST_NONE);
   int h = (int)GlobalVariableGet(name);
   if(h == GSX_HOST_DESK || h == GSX_HOST_SERVICE)
      return(h);
   return(GSX_HOST_NONE);
  }

void GsxFleetHostClear(const long magic)
  {
   string name = GsxFleetHostVarName(magic);
   if(GlobalVariableCheck(name))
      GlobalVariableDel(name);
  }

string GsxFleetHostLabel(const int host)
  {
   if(host == GSX_HOST_DESK)    return("desk");
   if(host == GSX_HOST_SERVICE) return("service");
   return("none");
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

// OWN claimed by peerHost (heartbeat checked by caller via GsxBusHeartbeatFresh).
bool GsxFleetPeerHostOwns(const long magic, const int peerHost)
  {
   if(peerHost == GSX_HOST_NONE)
      return(false);
   if(!GsxFleetServiceOwns(magic))
      return(false);
   return(GsxFleetHostGet(magic) == peerHost);
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

// How many busy (pos/pending) symbols of a given asset class for this magic.
int GsxFleetActiveInClass(const long magic, const int symClass)
  {
   string syms[];
   ArrayResize(syms, 0);

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      string s = PositionGetString(POSITION_SYMBOL);
      if((int)GsxSymbolClass(s) == symClass)
         GsxFleetAddUniqueSymbol(syms, s);
     }

   int ototal = OrdersTotal();
   for(int i = 0; i < ototal; i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      string s = OrderGetString(ORDER_SYMBOL);
      if((int)GsxSymbolClass(s) == symClass)
         GsxFleetAddUniqueSymbol(syms, s);
     }

   return(ArraySize(syms));
  }

//+------------------------------------------------------------------+
//| Atomic claim of terminal-wide fill slot (CAS + cooldown)         |
//| cooldownSec=0 bypasses rate limit (multi-fill same cycle) v2.14  |
//+------------------------------------------------------------------+
bool GsxFleetTryClaim(const long magic, const int cooldownSec, const datetime now)
  {
   string name = GsxFleetLockVarName(magic);
   double prev = 0.0;
   if(GlobalVariableCheck(name))
      prev = GlobalVariableGet(name);
   else
      GlobalVariableSet(name, 0.0);
   // Rate-limit only when cooldownSec > 0; siblings in same cycle pass cool=0
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
