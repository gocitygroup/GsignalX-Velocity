//+------------------------------------------------------------------+
//|                                            SymbolCanon.mqh        |
//|  Normalize broker symbol suffixes + crypto classification         |
//+------------------------------------------------------------------+
#ifndef GSX_SYMBOL_CANON_MQH
#define GSX_SYMBOL_CANON_MQH

string GsxSymbolCanon(string sym)
  {
   StringTrimLeft(sym);
   StringTrimRight(sym);
   if(sym == "")
      return "";

   string upper = sym;
   StringToUpper(upper);

   //--- strip leading broker path prefixes like "FX\\" rarely used
   int slash = StringFind(upper, "\\");
   if(slash >= 0)
      upper = StringSubstr(upper, slash + 1);

   string suffixes[] = {
      ".I", ".E", ".A", ".B", ".C", ".M", ".P", ".PRO", ".RAW", ".ECN",
      "PRO", "RAW", "ECN", "MICRO", "MINI",
      "M", "C", "I", "E", "#"
   };

   bool changed = true;
   while(changed)
     {
      changed = false;
      for(int i = 0; i < ArraySize(suffixes); i++)
        {
         string sfx = suffixes[i];
         int n = StringLen(upper);
         int m = StringLen(sfx);
         if(n <= m)
            continue;
         if(StringSubstr(upper, n - m) == sfx)
           {
            string stem = StringSubstr(upper, 0, n - m);
            if(StringGetCharacter(sfx, 0) == '.' || StringLen(sfx) > 1)
              {
               upper = stem;
               changed = true;
               break;
              }
            if(StringLen(stem) >= 6)
              {
               upper = stem;
               changed = true;
               break;
              }
           }
        }
     }

   while(StringLen(upper) > 6)
     {
      ushort c = StringGetCharacter(upper, StringLen(upper) - 1);
      if(c >= '0' && c <= '9')
         upper = StringSubstr(upper, 0, StringLen(upper) - 1);
      else
         break;
     }

   return upper;
  }

bool GsxIsCryptoCurrency(string ccy)
  {
   StringTrimLeft(ccy);
   StringTrimRight(ccy);
   StringToUpper(ccy);
   if(ccy == "")
      return false;

   string tokens[] = {
      "BTC", "ETH", "XBT", "USDT", "USDC", "BNB", "SOL", "XRP", "ADA",
      "DOGE", "LTC", "BCH", "DOT", "AVAX", "MATIC", "TRX", "LINK", "UNI",
      "ATOM", "NEAR", "APT", "ARB", "OP"
   };
   for(int i = 0; i < ArraySize(tokens); i++)
      if(ccy == tokens[i])
         return true;
   return false;
  }

bool GsxCryptoNameHasToken(const string upperName)
  {
   string tokens[] = {
      "BTC", "ETH", "XBT", "USDT", "USDC", "BNB", "SOL", "XRP", "ADA",
      "DOGE", "LTC", "BCH", "DOT", "AVAX", "MATIC", "TRX", "LINK", "UNI",
      "ATOM", "NEAR", "APT", "ARB", "OP", "BITCOIN", "ETHEREUM", "CRYPTO"
   };
   for(int i = 0; i < ArraySize(tokens); i++)
      if(StringFind(upperName, tokens[i]) >= 0)
         return true;
   return false;
  }

bool GsxCryptoPathLooksCrypto(string path)
  {
   StringToUpper(path);
   if(path == "")
      return false;
   if(StringFind(path, "CRYPTO") >= 0)
      return true;
   if(StringFind(path, "CRYPTOCURRENCY") >= 0)
      return true;
   if(StringFind(path, "DIGITAL") >= 0)
      return true;
   if(StringFind(path, "BITCOIN") >= 0)
      return true;
   if(StringFind(path, "ALTCOIN") >= 0)
      return true;
   return false;
  }

bool GsxIsCryptoSymbol(string sym)
  {
   StringTrimLeft(sym);
   StringTrimRight(sym);
   if(sym == "")
      return false;

   string path = SymbolInfoString(sym, SYMBOL_PATH);
   if(GsxCryptoPathLooksCrypto(path))
      return true;

   string base = SymbolInfoString(sym, SYMBOL_CURRENCY_BASE);
   string profit = SymbolInfoString(sym, SYMBOL_CURRENCY_PROFIT);
   if(GsxIsCryptoCurrency(base) || GsxIsCryptoCurrency(profit))
      return true;

   string upper = sym;
   StringToUpper(upper);
   int slash = StringFind(upper, "\\");
   if(slash >= 0)
      upper = StringSubstr(upper, slash + 1);

   string canon = GsxSymbolCanon(sym);
   if(GsxCryptoNameHasToken(upper) || GsxCryptoNameHasToken(canon))
      return true;

   return false;
  }

bool GsxIsCryptoSymbolEx(string sym, string extraList)
  {
   if(GsxIsCryptoSymbol(sym))
      return true;

   StringTrimLeft(extraList);
   StringTrimRight(extraList);
   if(extraList == "")
      return false;

   string target = sym;
   StringToUpper(target);
   string canon = GsxSymbolCanon(sym);

   string parts[];
   int n = StringSplit(extraList, StringGetCharacter(",", 0), parts);
   for(int i = 0; i < n; i++)
     {
      string p = parts[i];
      StringTrimLeft(p);
      StringTrimRight(p);
      if(p == "")
         continue;
      StringToUpper(p);
      if(target == p || canon == p)
         return true;
      if(StringFind(target, p) >= 0 || StringFind(canon, p) >= 0)
         return true;
     }
   return false;
  }

#endif
//+------------------------------------------------------------------+
