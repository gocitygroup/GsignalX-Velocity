//+------------------------------------------------------------------+
//|                                               RosterStore.mqh     |
//|  Live multisymbol roster persistence (FILE_COMMON + seq GV)       |
//|  Seed from InpSymbolList when CSV missing.                        |
//|  Pair state START/STOP/SUSPEND (v1.26); mute aliases for compat.  |
//+------------------------------------------------------------------+
#ifndef GSX_ROSTER_STORE_MQH
#define GSX_ROSTER_STORE_MQH

#include <GSignalX/BusIO.mqh>
#include <GSignalX/BusProtocol.mqh>
#include <GSignalX/SymbolRoster.mqh>
#include <GSignalX/SymbolCanon.mqh>
#include <GSignalX/SymbolClass.mqh>

#define GSX_ROSTER_DIR  GSX_BUS_ROOT "\\roster"

#define GSX_PAIR_START    0
#define GSX_PAIR_STOP     1
#define GSX_PAIR_SUSPEND  2

#define GSX_CAT_ALL       0
#define GSX_CAT_FOREX     1
#define GSX_CAT_COMMODITY 2
#define GSX_CAT_CRYPTO    3

#define GSX_CLASS_SOFT_MAX_DEFAULT 8

//+------------------------------------------------------------------+
string GsxRosterStorePath(const long magic)
  {
   return(StringFormat("%s\\%I64d.csv", GSX_ROSTER_DIR, magic));
  }

string GsxRosterSeqVarName(const long magic)
  {
   return("GSX_SVC_ROSTER_SEQ_" + IntegerToString((int)magic));
  }

string GsxRosterMuteVarName(const long magic, const string symbolCanon)
  {
   return(StringFormat("GSX_SYM_MUTE_%d_%s", (int)magic, symbolCanon));
  }

string GsxRosterStateVarName(const long magic, const string symbolCanon)
  {
   return(StringFormat("GSX_SYM_STATE_%d_%s", (int)magic, symbolCanon));
  }

string GsxRosterPageVarName(const long magic)
  {
   return("GSX_MS_PAGE_" + IntegerToString((int)magic));
  }

string GsxRosterFleetTargetVarName(const long magic)
  {
   return("GSX_MS_FLEET_TARGET_" + IntegerToString((int)magic));
  }

string GsxRosterCatVarName(const long magic)
  {
   return("GSX_MS_CAT_" + IntegerToString((int)magic));
  }

string GsxRosterClassMaxVarName(const long magic)
  {
   return("GSX_MS_CLASS_MAX_" + IntegerToString((int)magic));
  }

string GsxRosterPracBandVarName(const long magic)
  {
   return("GSX_MS_PRAC_BAND_" + IntegerToString((int)magic));
  }

string GsxRosterPracCostVarName(const long magic)
  {
   return("GSX_MS_PRAC_COST_" + IntegerToString((int)magic));
  }

string GsxRosterPracStyleVarName(const long magic)
  {
   return("GSX_MS_PRAC_STYLE_" + IntegerToString((int)magic));
  }

//+------------------------------------------------------------------+
double GsxRosterSeqGet(const long magic)
  {
   string name = GsxRosterSeqVarName(magic);
   if(!GlobalVariableCheck(name))
      return(0.0);
   return(GlobalVariableGet(name));
  }

double GsxRosterSeqBump(const long magic)
  {
   double v = GsxRosterSeqGet(magic) + 1.0;
   GlobalVariableSet(GsxRosterSeqVarName(magic), v);
   return(v);
  }

void GsxRosterSeqSet(const long magic, const double seq)
  {
   GlobalVariableSet(GsxRosterSeqVarName(magic), seq);
  }

//+------------------------------------------------------------------+
string GsxRosterStateLabel(const int state)
  {
   if(state == GSX_PAIR_STOP)    return("STOP");
   if(state == GSX_PAIR_SUSPEND) return("SUSPEND");
   return("START");
  }

int GsxRosterStateNormalize(const int state)
  {
   if(state == GSX_PAIR_STOP || state == GSX_PAIR_SUSPEND)
      return(state);
   return(GSX_PAIR_START);
  }

int GsxRosterStateGet(const long magic, const string symbol)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return(GSX_PAIR_START);

   string stateName = GsxRosterStateVarName(magic, canon);
   if(GlobalVariableCheck(stateName))
      return(GsxRosterStateNormalize((int)GlobalVariableGet(stateName)));

   // migrate legacy mute → STOP once
   string muteName = GsxRosterMuteVarName(magic, canon);
   if(GlobalVariableCheck(muteName) && GlobalVariableGet(muteName) > 0.5)
     {
      GlobalVariableSet(stateName, (double)GSX_PAIR_STOP);
      return(GSX_PAIR_STOP);
     }
   return(GSX_PAIR_START);
  }

void GsxRosterStateSet(const long magic, const string symbol, const int state)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return;
   int st = GsxRosterStateNormalize(state);
   GlobalVariableSet(GsxRosterStateVarName(magic, canon), (double)st);
   // keep mute GV in sync for older readers
   GlobalVariableSet(GsxRosterMuteVarName(magic, canon),
                     (st == GSX_PAIR_START) ? 0.0 : 1.0);
  }

int GsxRosterStateCycle(const long magic, const string symbol)
  {
   int st = GsxRosterStateGet(magic, symbol);
   if(st == GSX_PAIR_START)
      st = GSX_PAIR_STOP;
   else if(st == GSX_PAIR_STOP)
      st = GSX_PAIR_SUSPEND;
   else
      st = GSX_PAIR_START;
   GsxRosterStateSet(magic, symbol, st);
   return(st);
  }

bool GsxRosterIsFillBlocked(const long magic, const string symbol)
  {
   return(GsxRosterStateGet(magic, symbol) != GSX_PAIR_START);
  }

bool GsxRosterIsFleetCandidate(const long magic, const string symbol)
  {
   return(GsxRosterStateGet(magic, symbol) == GSX_PAIR_START);
  }

//+------------------------------------------------------------------+
//| Mute aliases (compat): mute == not START                          |
//+------------------------------------------------------------------+
bool GsxRosterMuteGet(const long magic, const string symbol)
  {
   return(GsxRosterIsFillBlocked(magic, symbol));
  }

void GsxRosterMuteSet(const long magic, const string symbol, const bool mute)
  {
   GsxRosterStateSet(magic, symbol, mute ? GSX_PAIR_STOP : GSX_PAIR_START);
  }

void GsxRosterMuteToggle(const long magic, const string symbol)
  {
   GsxRosterMuteSet(magic, symbol, !GsxRosterMuteGet(magic, symbol));
  }

//+------------------------------------------------------------------+
int GsxRosterPageGet(const long magic)
  {
   string name = GsxRosterPageVarName(magic);
   if(!GlobalVariableCheck(name))
      return(0);
   int p = (int)GlobalVariableGet(name);
   return(p < 0 ? 0 : p);
  }

void GsxRosterPageSet(const long magic, const int page)
  {
   GlobalVariableSet(GsxRosterPageVarName(magic), (double)MathMax(0, page));
  }

int GsxRosterCatGet(const long magic)
  {
   string name = GsxRosterCatVarName(magic);
   if(!GlobalVariableCheck(name))
      return(GSX_CAT_ALL);
   int c = (int)GlobalVariableGet(name);
   if(c < GSX_CAT_ALL || c > GSX_CAT_CRYPTO)
      return(GSX_CAT_ALL);
   return(c);
  }

void GsxRosterCatSet(const long magic, const int cat)
  {
   int c = cat;
   if(c < GSX_CAT_ALL || c > GSX_CAT_CRYPTO)
      c = GSX_CAT_ALL;
   GlobalVariableSet(GsxRosterCatVarName(magic), (double)c);
  }

int GsxRosterClassMaxGet(const long magic)
  {
   string name = GsxRosterClassMaxVarName(magic);
   if(!GlobalVariableCheck(name))
      return(GSX_CLASS_SOFT_MAX_DEFAULT);
   int m = (int)GlobalVariableGet(name);
   return(m < 4 ? 4 : m);   // capacity at least 4 per category
  }

void GsxRosterClassMaxSet(const long magic, const int softMax)
  {
   GlobalVariableSet(GsxRosterClassMaxVarName(magic),
                     (double)MathMax(4, softMax));
  }

//+------------------------------------------------------------------+
//| Event SKIP block GVs (written by EventGate poll; read by Core)   |
//+------------------------------------------------------------------+
#define GSX_EVT_MODE_TRADE  0
#define GSX_EVT_MODE_SKIP   1

string GsxEventModeVar(const long magic)
  {
   return("GSX_EVT_MODE_" + IntegerToString((int)magic));
  }

string GsxEventBlockVar(const long magic, const string canon)
  {
   return(StringFormat("GSX_EVT_BLOCK_%d_%s", (int)magic, canon));
  }

int GsxEventModeGet(const long magic)
  {
   string n = GsxEventModeVar(magic);
   if(!GlobalVariableCheck(n))
      return(GSX_EVT_MODE_TRADE);
   int m = (int)GlobalVariableGet(n);
   return(m == GSX_EVT_MODE_SKIP ? GSX_EVT_MODE_SKIP : GSX_EVT_MODE_TRADE);
  }

void GsxEventModeSet(const long magic, const int mode)
  {
   GlobalVariableSet(GsxEventModeVar(magic),
                     (double)(mode == GSX_EVT_MODE_SKIP ? GSX_EVT_MODE_SKIP : GSX_EVT_MODE_TRADE));
  }

void GsxEventModeToggle(const long magic)
  {
   int m = GsxEventModeGet(magic);
   GsxEventModeSet(magic, (m == GSX_EVT_MODE_SKIP ? GSX_EVT_MODE_TRADE : GSX_EVT_MODE_SKIP));
  }

string GsxEventModeLabel(const int mode)
  {
   return(mode == GSX_EVT_MODE_SKIP ? "SKIP" : "TRADE");
  }

bool GsxEventBlocksSymbol(const long magic, const string symbol)
  {
   if(GsxEventModeGet(magic) != GSX_EVT_MODE_SKIP)
      return(false);
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return(false);
   string n = GsxEventBlockVar(magic, canon);
   if(!GlobalVariableCheck(n))
      return(false);
   return(GlobalVariableGet(n) > 0.5);
  }

void GsxEventBlockClearAll(const long magic, const string &roster[])
  {
   for(int i = 0; i < ArraySize(roster); i++)
     {
      string canon = GsxSymbolCanon(roster[i]);
      if(canon == "")
         continue;
      GlobalVariableSet(GsxEventBlockVar(magic, canon), 0.0);
     }
  }

void GsxEventBlockSet(const long magic, const string symbol, const bool blocked)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return;
   GlobalVariableSet(GsxEventBlockVar(magic, canon), blocked ? 1.0 : 0.0);
  }

//+------------------------------------------------------------------+
//| Fleet target override: >0 means UI overrides Service input       |
//+------------------------------------------------------------------+
int GsxRosterFleetTargetGet(const long magic)
  {
   string name = GsxRosterFleetTargetVarName(magic);
   if(!GlobalVariableCheck(name))
      return(0);
   int t = (int)GlobalVariableGet(name);
   return(t < 0 ? 0 : t);
  }

void GsxRosterFleetTargetSet(const long magic, const int target)
  {
   GlobalVariableSet(GsxRosterFleetTargetVarName(magic), (double)MathMax(0, target));
  }

//+------------------------------------------------------------------+
//| Practice coach selection (Trade Center soft tips; not risk math) |
//+------------------------------------------------------------------+
int GsxRosterPracBandGet(const long magic)
  {
   string name = GsxRosterPracBandVarName(magic);
   if(!GlobalVariableCheck(name))
      return(100);
   int b = (int)GlobalVariableGet(name);
   if(b == 20 || b == 50 || b == 100)
      return(b);
   return(100);
  }

void GsxRosterPracBandSet(const long magic, const int band)
  {
   int b = band;
   if(b != 20 && b != 50 && b != 100)
      b = 100;
   GlobalVariableSet(GsxRosterPracBandVarName(magic), (double)b);
  }

int GsxRosterPracCostGet(const long magic)
  {
   string name = GsxRosterPracCostVarName(magic);
   if(!GlobalVariableCheck(name))
      return(0); // RAW
   int c = (int)GlobalVariableGet(name);
   return(c == 1 ? 1 : 0);
  }

void GsxRosterPracCostSet(const long magic, const int cost)
  {
   GlobalVariableSet(GsxRosterPracCostVarName(magic), (double)(cost == 1 ? 1 : 0));
  }

int GsxRosterPracStyleGet(const long magic)
  {
   string name = GsxRosterPracStyleVarName(magic);
   if(!GlobalVariableCheck(name))
      return(1); // DAY
   int s = (int)GlobalVariableGet(name);
   if(s == 0 || s == 2)
      return(s);
   return(1);
  }

void GsxRosterPracStyleSet(const long magic, const int style)
  {
   int s = style;
   if(s != 0 && s != 2)
      s = 1;
   GlobalVariableSet(GsxRosterPracStyleVarName(magic), (double)s);
  }

//+------------------------------------------------------------------+
string GsxRosterJoinCsv(const string &names[])
  {
   string body = "";
   for(int i = 0; i < ArraySize(names); i++)
     {
      string s = names[i];
      StringTrimLeft(s);
      StringTrimRight(s);
      if(s == "")
         continue;
      if(body != "")
         body += ",";
      body += s;
     }
   return(body);
  }

bool GsxRosterContains(const string &names[], const string symbol)
  {
   string want = GsxSymbolCanon(symbol);
   if(want == "" && symbol == "")
      return(false);
   for(int i = 0; i < ArraySize(names); i++)
     {
      if(names[i] == symbol)
         return(true);
      if(want != "" && GsxSymbolCanon(names[i]) == want)
         return(true);
     }
   return(false);
  }

int GsxRosterCountByClass(const string &names[], const ENUM_GSX_SYM_CLASS cls)
  {
   int n = 0;
   for(int i = 0; i < ArraySize(names); i++)
      if(GsxSymbolClass(names[i]) == cls)
         n++;
   return(n);
  }

bool GsxRosterClassAtCap(const string &names[],
                         const ENUM_GSX_SYM_CLASS cls,
                         const int softMax)
  {
   if(cls == GSX_CLASS_OTHER)
      return(false);
   int cap = (softMax < 4 ? 4 : softMax);
   return(GsxRosterCountByClass(names, cls) >= cap);
  }

bool GsxRosterAdd(string &names[], const string symbol)
  {
   if(symbol == "")
      return(false);
   if(GsxRosterContains(names, symbol))
      return(false);
   string one[];
   ArrayResize(one, 1);
   one[0] = symbol;
   GsxRosterResolve(one);
   GsxRosterSelect(one);
   int n = ArraySize(names);
   ArrayResize(names, n + 1);
   names[n] = one[0];
   return(true);
  }

// capacity-aware ADD; reason set on failure
bool GsxRosterAddCapped(string &names[],
                        const string symbol,
                        const int softMax,
                        string &reason)
  {
   reason = "";
   if(symbol == "")
     {
      reason = "empty";
      return(false);
     }
   if(GsxRosterContains(names, symbol))
     {
      reason = "duplicate";
      return(false);
     }

   string one[];
   ArrayResize(one, 1);
   one[0] = symbol;
   GsxRosterResolve(one);
   GsxRosterSelect(one);
   string resolved = one[0];
   ENUM_GSX_SYM_CLASS cls = GsxSymbolClass(resolved);
   if(GsxRosterClassAtCap(names, cls, softMax))
     {
      reason = GsxSymClassLabel(cls) + " at cap " + IntegerToString(MathMax(4, softMax));
      return(false);
     }

   int n = ArraySize(names);
   ArrayResize(names, n + 1);
   names[n] = resolved;
   return(true);
  }

bool GsxRosterRemove(string &names[], const string symbol)
  {
   string want = GsxSymbolCanon(symbol);
   int idx = -1;
   for(int i = 0; i < ArraySize(names); i++)
     {
      if(names[i] == symbol || (want != "" && GsxSymbolCanon(names[i]) == want))
        {
         idx = i;
         break;
        }
     }
   if(idx < 0)
      return(false);
   for(int j = idx; j < ArraySize(names) - 1; j++)
      names[j] = names[j + 1];
   ArrayResize(names, ArraySize(names) - 1);
   return(true);
  }

void GsxRosterFilterByCat(const string &names[],
                          const int cat,
                          string &out[])
  {
   ArrayResize(out, 0);
   for(int i = 0; i < ArraySize(names); i++)
     {
      ENUM_GSX_SYM_CLASS cls = GsxSymbolClass(names[i]);
      bool keep = false;
      if(cat == GSX_CAT_ALL)
         keep = true;
      else if(cat == GSX_CAT_FOREX && cls == GSX_CLASS_FOREX)
         keep = true;
      else if(cat == GSX_CAT_COMMODITY && cls == GSX_CLASS_COMMODITY)
         keep = true;
      else if(cat == GSX_CAT_CRYPTO && cls == GSX_CLASS_CRYPTO)
         keep = true;
      if(!keep)
         continue;
      int n = ArraySize(out);
      ArrayResize(out, n + 1);
      out[n] = names[i];
     }
  }

//+------------------------------------------------------------------+
bool GsxRosterStoreSave(const long magic, const string &names[], const bool bumpSeq = true)
  {
   string path = GsxRosterStorePath(magic);
   string body = GsxRosterJoinCsv(names);
   if(!GsxBusWriteAtomic(path, body))
      return(false);
   if(bumpSeq)
      GsxRosterSeqBump(magic);
   return(true);
  }

bool GsxRosterStoreLoad(const long magic, string &names[])
  {
   ArrayResize(names, 0);
   string path = GsxRosterStorePath(magic);
   string body = GsxBusReadAll(path);
   if(body == "")
      return(false);
   // allow newlines or commas
   StringReplace(body, "\r", "");
   StringReplace(body, "\n", ",");
   GsxRosterParse(body, names);
   GsxRosterResolve(names);
   GsxRosterSelect(names);
   return(ArraySize(names) > 0);
  }

bool GsxRosterStoreExists(const long magic)
  {
   return(FileIsExist(GsxRosterStorePath(magic), FILE_COMMON));
  }

//+------------------------------------------------------------------+
//| Load CSV if present; otherwise seed from CSV string and save     |
//+------------------------------------------------------------------+
int GsxRosterStoreEnsure(const long magic, const string seedCsv, string &names[])
  {
   if(GsxRosterStoreLoad(magic, names))
      return(ArraySize(names));

   GsxRosterParse(seedCsv, names);
   GsxRosterResolve(names);
   GsxRosterSelect(names);
   if(ArraySize(names) > 0)
      GsxRosterStoreSave(magic, names, true);
   return(ArraySize(names));
  }

#endif // GSX_ROSTER_STORE_MQH
//+------------------------------------------------------------------+
