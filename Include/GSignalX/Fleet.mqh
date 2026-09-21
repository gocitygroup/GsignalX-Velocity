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
//| V2.15: one Positions+Orders walk → busy / PL / class counts      |
//+------------------------------------------------------------------+
struct GsxAccountBook
  {
   long   magic;
   bool   valid;
   double pl;
   int    posCount;
   string busySyms[];   // distinct symbols with pos or pending
   string plSyms[];     // symbols with open positions
   double plBySym[];    // floating PL aligned with plSyms
   int    classBusyFx;
   int    classBusyCmd;
   int    classBusyCr;
   int    classBusyOth;
  };

void GsxAccountBookClear(GsxAccountBook &book)
  {
   book.magic = 0;
   book.valid = false;
   book.pl = 0.0;
   book.posCount = 0;
   ArrayResize(book.busySyms, 0);
   ArrayResize(book.plSyms, 0);
   ArrayResize(book.plBySym, 0);
   book.classBusyFx = 0;
   book.classBusyCmd = 0;
   book.classBusyCr = 0;
   book.classBusyOth = 0;
  }

void GsxAccountBookAddPl(GsxAccountBook &book, const string sym, const double add)
  {
   if(sym == "")
      return;
   for(int k = 0; k < ArraySize(book.plSyms); k++)
     {
      if(book.plSyms[k] == sym)
        {
         book.plBySym[k] += add;
         return;
        }
     }
   int n = ArraySize(book.plSyms);
   ArrayResize(book.plSyms, n + 1);
   ArrayResize(book.plBySym, n + 1);
   book.plSyms[n] = sym;
   book.plBySym[n] = add;
  }

void GsxAccountBookNoteBusyClass(GsxAccountBook &book, const string sym)
  {
   // Count unique busy symbols per class (call only when newly added to busySyms)
   int c = (int)GsxSymbolClass(sym);
   if(c == GSX_CLASS_FOREX)           book.classBusyFx++;
   else if(c == GSX_CLASS_COMMODITY)  book.classBusyCmd++;
   else if(c == GSX_CLASS_CRYPTO)     book.classBusyCr++;
   else                               book.classBusyOth++;
  }

void GsxAccountBookAddBusy(GsxAccountBook &book, const string sym)
  {
   if(sym == "")
      return;
   for(int k = 0; k < ArraySize(book.busySyms); k++)
      if(book.busySyms[k] == sym)
         return;
   int n = ArraySize(book.busySyms);
   ArrayResize(book.busySyms, n + 1);
   book.busySyms[n] = sym;
   GsxAccountBookNoteBusyClass(book, sym);
  }

void GsxAccountBookBuild(const long magic, GsxAccountBook &book)
  {
   GsxAccountBookClear(book);
   book.magic = magic;

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      double add = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      book.pl += add;
      book.posCount++;
      GsxAccountBookAddBusy(book, sym);
      GsxAccountBookAddPl(book, sym, add);
     }

   int ototal = OrdersTotal();
   for(int i = 0; i < ototal; i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      GsxAccountBookAddBusy(book, OrderGetString(ORDER_SYMBOL));
     }

   book.valid = true;
  }

bool GsxAccountBookBusy(const GsxAccountBook &book, const string symbol)
  {
   if(!book.valid || symbol == "")
      return(false);
   for(int i = 0; i < ArraySize(book.busySyms); i++)
      if(book.busySyms[i] == symbol)
         return(true);
   return(false);
  }

int GsxAccountBookActivePairs(const GsxAccountBook &book)
  {
   if(!book.valid)
      return(0);
   return(ArraySize(book.busySyms));
  }

int GsxAccountBookActiveInClass(const GsxAccountBook &book, const int symClass)
  {
   if(!book.valid)
      return(0);
   if(symClass == GSX_CLASS_FOREX)     return(book.classBusyFx);
   if(symClass == GSX_CLASS_COMMODITY) return(book.classBusyCmd);
   if(symClass == GSX_CLASS_CRYPTO)    return(book.classBusyCr);
   return(book.classBusyOth);
  }

double GsxAccountBookSymbolPl(const GsxAccountBook &book, const string symbol)
  {
   if(!book.valid || symbol == "")
      return(0.0);
   for(int i = 0; i < ArraySize(book.plSyms); i++)
      if(book.plSyms[i] == symbol)
         return(book.plBySym[i]);
   return(0.0);
  }

//+------------------------------------------------------------------+
//| Account-wide floating P/L + position count for magic             |
//+------------------------------------------------------------------+
void GsxFleetFloating(const long magic, double &pl, int &count)
  {
   GsxAccountBook book;
   GsxAccountBookBuild(magic, book);
   pl = book.pl;
   count = book.posCount;
  }

//+------------------------------------------------------------------+
//| Distinct symbols with open position OR working pending (magic)   |
//+------------------------------------------------------------------+
int GsxFleetActivePairs(const long magic)
  {
   GsxAccountBook book;
   GsxAccountBookBuild(magic, book);
   return(GsxAccountBookActivePairs(book));
  }

// How many busy (pos/pending) symbols of a given asset class for this magic.
int GsxFleetActiveInClass(const long magic, const int symClass)
  {
   GsxAccountBook book;
   GsxAccountBookBuild(magic, book);
   return(GsxAccountBookActiveInClass(book, symClass));
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
   GsxAccountBook book;
   GsxAccountBookBuild(magic, book);
   return(GsxAccountBookBusy(book, symbol));
  }

#endif // GSX_FLEET_MQH
//+------------------------------------------------------------------+
