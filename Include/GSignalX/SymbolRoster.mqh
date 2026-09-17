//+------------------------------------------------------------------+
//|                                            SymbolRoster.mqh       |
//|  Parse / resolve / select multi-symbol roster lists               |
//+------------------------------------------------------------------+
#ifndef GSX_SYMBOL_ROSTER_MQH
#define GSX_SYMBOL_ROSTER_MQH

#include <GSignalX/SymbolCanon.mqh>

//+------------------------------------------------------------------+
//| Split CSV symbol list → trimmed non-empty names                  |
//+------------------------------------------------------------------+
int GsxRosterParse(const string listCsv, string &out[])
  {
   ArrayResize(out, 0);
   if(listCsv == "")
      return(0);

   string parts[];
   int n = StringSplit(listCsv, StringGetCharacter(",", 0), parts);
   for(int i = 0; i < n; i++)
     {
      string p = parts[i];
      StringTrimLeft(p);
      StringTrimRight(p);
      if(p == "")
         continue;
      int sz = ArraySize(out);
      ArrayResize(out, sz + 1);
      out[sz] = p;
     }
   return(ArraySize(out));
  }

string GsxSymbolFamilyKey(string canon)
  {
   StringToUpper(canon);
   if(canon == "USOIL" || canon == "XTIUSD" || canon == "WTIUSD" ||
      canon == "WTICOUSD" || canon == "WTI" || canon == "XTI")
      return("OILWTI");
   if(canon == "UKOIL" || canon == "XBRUSD" || canon == "BRENT" ||
      canon == "XBR" || canon == "UKOILSPOT")
      return("OILBRENT");
   if(canon == "XAUUSD" || canon == "GOLD" || canon == "GOLDUSD")
      return("XAUUSD");
   if(canon == "XAGUSD" || canon == "SILVER" || canon == "SILVERUSD")
      return("XAGUSD");
   if(canon == "BTCUSD" || canon == "XBTUSD" || canon == "BTCUSDT")
      return("BTCUSD");
   if(canon == "ETHUSD" || canon == "ETHUSDT")
      return("ETHUSD");
   if(canon == "XRPUSD" || canon == "XRPUSDT")
      return("XRPUSD");
   if(canon == "LTCUSD" || canon == "LTCUSDT")
      return("LTCUSD");
   return(canon);
  }

bool GsxSymbolCanonMatch(const string a, const string b)
  {
   if(a == "" || b == "")
      return(false);
   if(a == b)
      return(true);
   return(GsxSymbolFamilyKey(a) == GsxSymbolFamilyKey(b) &&
          GsxSymbolFamilyKey(a) != a); // only when aliased family
  }

//+------------------------------------------------------------------+
//| Resolve operator names to live broker SymbolName via canon match |
//+------------------------------------------------------------------+
void GsxRosterResolve(string &names[])
  {
   int total = SymbolsTotal(false);
   for(int i = 0; i < ArraySize(names); i++)
     {
      string raw = names[i];
      StringTrimLeft(raw);
      StringTrimRight(raw);
      names[i] = raw;
      if(raw == "")
         continue;

      string want = GsxSymbolCanon(raw);
      if(want == "")
         continue;

      string exact = "";
      string canonHit = "";
      string familyHit = "";
      for(int s = 0; s < total; s++)
        {
         string live = SymbolName(s, false);
         if(live == "")
            continue;
         if(live == raw)
           {
            exact = live;
            break;
           }
         string liveCanon = GsxSymbolCanon(live);
         if(canonHit == "" && liveCanon == want)
            canonHit = live;
         if(familyHit == "" && GsxSymbolCanonMatch(want, liveCanon))
            familyHit = live;
        }

      if(exact != "")
         names[i] = exact;
      else if(canonHit != "")
         names[i] = canonHit;
      else if(familyHit != "")
         names[i] = familyHit;
      // else keep operator spelling for diagnostics
     }
  }

//+------------------------------------------------------------------+
//| Ensure every roster name is in Market Watch                      |
//+------------------------------------------------------------------+
void GsxRosterSelect(const string &names[])
  {
   for(int i = 0; i < ArraySize(names); i++)
     {
      if(names[i] == "")
         continue;
      SymbolSelect(names[i], true);
     }
  }

#endif // GSX_SYMBOL_ROSTER_MQH
//+------------------------------------------------------------------+
