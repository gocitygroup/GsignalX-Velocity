//+------------------------------------------------------------------+
//| BrandLinks.mqh — canonical public URLs (Market-safe, no DLLs)    |
//| Chart / desk TV chips Alert+Print the URL; docs mirror the same. |
//+------------------------------------------------------------------+
#ifndef GSX_BRAND_LINKS_MQH
#define GSX_BRAND_LINKS_MQH

#define GSX_TV_PUB_URL   "https://www.tradingview.com/script/wxa7lWXl-GsignalX-is-a-trend-following/"
#define GSX_TV_PUB_LABEL "TV"

// Short panel tip (never paste the full URL into a chip label)
string GsxTvPubTip()
  {
   return("Foundation · TradingView pub");
  }

// One-line TG / docs footer
string GsxTvPubFooterLine()
  {
   return("Chart foundation: " + GSX_TV_PUB_URL);
  }

// Market-safe announce: Experts log + Alert (user opens/copies URL)
void GsxTvPubAnnounce()
  {
   string msg = "GsignalX chart foundation (TradingView) — does not place MT5 orders:\n" +
                GSX_TV_PUB_URL;
   Print(msg);
   Alert("GsignalX | TradingView publication\n", GSX_TV_PUB_URL);
  }

#endif // GSX_BRAND_LINKS_MQH
