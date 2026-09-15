//+------------------------------------------------------------------+
//|                                              SymbolClass.mqh      |
//|  Asset-class taxonomy: Forex / Commodity / Crypto / Other         |
//|  Pure helpers — no UI / GV. Reuses SymbolCanon crypto detectors.  |
//+------------------------------------------------------------------+
#ifndef GSX_SYMBOL_CLASS_MQH
#define GSX_SYMBOL_CLASS_MQH

#include <GSignalX/SymbolCanon.mqh>

enum ENUM_GSX_SYM_CLASS
  {
   GSX_CLASS_OTHER     = 0,
   GSX_CLASS_FOREX     = 1,
   GSX_CLASS_COMMODITY = 2,
   GSX_CLASS_CRYPTO    = 3
  };

//+------------------------------------------------------------------+
string GsxSymClassLabel(const ENUM_GSX_SYM_CLASS c)
  {
   if(c == GSX_CLASS_FOREX)     return("FX");
   if(c == GSX_CLASS_COMMODITY) return("CMD");
   if(c == GSX_CLASS_CRYPTO)    return("CR");
   return("OTH");
  }

string GsxSymClassTabLabel(const ENUM_GSX_SYM_CLASS c)
  {
   if(c == GSX_CLASS_FOREX)     return("FX");
   if(c == GSX_CLASS_COMMODITY) return("CMD");
   if(c == GSX_CLASS_CRYPTO)    return("CRYPTO");
   return("ALL");
  }

//+------------------------------------------------------------------+
bool GsxIsFxCurrencyCode(string ccy)
  {
   StringTrimLeft(ccy);
   StringTrimRight(ccy);
   StringToUpper(ccy);
   if(StringLen(ccy) != 3)
      return(false);
   if(GsxIsCryptoCurrency(ccy))
      return(false);

   string fx[] = {
      "USD","EUR","GBP","JPY","AUD","NZD","CAD","CHF","SEK","NOK","DKK",
      "PLN","HUF","CZK","TRY","ZAR","MXN","SGD","HKD","CNH","CNY","INR",
      "KRW","THB","IDR","PHP","RUB","ILS","SAR","AED","BRL","CLP","COP"
   };
   for(int i = 0; i < ArraySize(fx); i++)
      if(ccy == fx[i])
         return(true);
   return(false);
  }

bool GsxCommodityNameHasToken(const string upper)
  {
   string tokens[] = {
      "XAU","XAG","XPT","XPD","GOLD","SILVER","PLATINUM","PALLADIUM",
      "OIL","WTI","BRENT","USOIL","UKOIL","XTI","XBR","NGAS","NATGAS",
      "GAS","COPPER","COCOA","COFFEE","SUGAR","WHEAT","CORN","COTTON"
   };
   for(int i = 0; i < ArraySize(tokens); i++)
      if(StringFind(upper, tokens[i]) >= 0)
         return(true);
   return(false);
  }

bool GsxCommodityPathLooksCommodity(string path)
  {
   StringToUpper(path);
   if(path == "")
      return(false);
   if(StringFind(path, "METAL") >= 0)      return(true);
   if(StringFind(path, "COMMODIT") >= 0)   return(true);
   if(StringFind(path, "ENERGY") >= 0)     return(true);
   if(StringFind(path, "OIL") >= 0)        return(true);
   if(StringFind(path, "AGRICULT") >= 0)   return(true);
   return(false);
  }

bool GsxIsCommoditySymbol(string sym)
  {
   StringTrimLeft(sym);
   StringTrimRight(sym);
   if(sym == "")
      return(false);

   string path = SymbolInfoString(sym, SYMBOL_PATH);
   if(GsxCommodityPathLooksCommodity(path))
      return(true);

   string upper = sym;
   StringToUpper(upper);
   int slash = StringFind(upper, "\\");
   if(slash >= 0)
      upper = StringSubstr(upper, slash + 1);

   string canon = GsxSymbolCanon(sym);
   if(GsxCommodityNameHasToken(upper) || GsxCommodityNameHasToken(canon))
      return(true);

   string base = SymbolInfoString(sym, SYMBOL_CURRENCY_BASE);
   StringToUpper(base);
   if(base == "XAU" || base == "XAG" || base == "XPT" || base == "XPD")
      return(true);

   return(false);
  }

bool GsxIsForexSymbol(string sym)
  {
   if(GsxIsCryptoSymbol(sym) || GsxIsCommoditySymbol(sym))
      return(false);

   string base = SymbolInfoString(sym, SYMBOL_CURRENCY_BASE);
   string profit = SymbolInfoString(sym, SYMBOL_CURRENCY_PROFIT);
   if(GsxIsFxCurrencyCode(base) && GsxIsFxCurrencyCode(profit) && base != profit)
      return(true);

   // name fallback: 6-letter FX pair after canon
   string canon = GsxSymbolCanon(sym);
   if(StringLen(canon) == 6)
     {
      string a = StringSubstr(canon, 0, 3);
      string b = StringSubstr(canon, 3, 3);
      if(GsxIsFxCurrencyCode(a) && GsxIsFxCurrencyCode(b) && a != b)
         return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
ENUM_GSX_SYM_CLASS GsxSymbolClass(const string symbol)
  {
   if(symbol == "")
      return(GSX_CLASS_OTHER);
   if(GsxIsCryptoSymbol(symbol))
      return(GSX_CLASS_CRYPTO);
   if(GsxIsCommoditySymbol(symbol))
      return(GSX_CLASS_COMMODITY);
   if(GsxIsForexSymbol(symbol))
      return(GSX_CLASS_FOREX);
   return(GSX_CLASS_OTHER);
  }

#endif // GSX_SYMBOL_CLASS_MQH
//+------------------------------------------------------------------+
