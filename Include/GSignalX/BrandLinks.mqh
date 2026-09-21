//+------------------------------------------------------------------+
//| BrandLinks.mqh — canonical public URLs (Market-safe, no DLLs)    |
//| Chart / desk chips Alert+Print the URL; docs mirror the same.    |
//+------------------------------------------------------------------+
#ifndef GSX_BRAND_LINKS_MQH
#define GSX_BRAND_LINKS_MQH

#define GSX_TV_PUB_URL   "https://www.tradingview.com/script/wxa7lWXl-GsignalX-is-a-trend-following/"
#define GSX_TV_PUB_LABEL "TV"

// Hosted Premium Managed desk (ccity) + GSignalX Service booking / mentorship
// Keep in sync with docs/assets/js/gsx-premium.js
#define GSX_PREMIUM_MANUAL_URL   "https://ccity.gsignalx.cloud/Gsignalx_Velocity_Premium_Users_Manual#welcome"
#define GSX_SERVICE_PRICING_URL  "https://www.gsignalx.cloud/pricing"
#define GSX_MENTORSHIP_URL       "https://www.gsignalx.cloud/mentorship"
#define GSX_SERVICE_HOME_URL     "https://www.gsignalx.cloud/"
#define GSX_PREMIUM_LABEL        "PRM"

#define GSX_PREMIUM_ANNOUNCE_GV  "GSX_PREMIUM_ANN_DAY"

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

//+------------------------------------------------------------------+
//| Premium Managed — hosted desk promo                              |
//+------------------------------------------------------------------+
string GsxPremiumTip()
  {
   return("Managed Premium · book via Service");
  }

string GsxPremiumFooterLine()
  {
   return("Managed Premium: " + GSX_PREMIUM_MANUAL_URL +
          " | Book (pricing): " + GSX_SERVICE_PRICING_URL +
          " | Profile → My Services · " + GSX_SERVICE_HOME_URL);
  }

string GsxMentorshipFooterLine()
  {
   return("Mentorship: " + GSX_MENTORSHIP_URL);
  }

// Day-throttle for panel clicks (cheap; avoids Alert spam)
bool GsxPremiumAnnounceAllowed()
  {
   datetime day0 = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(GlobalVariableCheck(GSX_PREMIUM_ANNOUNCE_GV) &&
      (datetime)GlobalVariableGet(GSX_PREMIUM_ANNOUNCE_GV) == day0)
      return(false);
   return(true);
  }

void GsxPremiumAnnounceMark()
  {
   datetime day0 = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   GlobalVariableSet(GSX_PREMIUM_ANNOUNCE_GV, (double)day0);
  }

// Market-safe announce: Manual + pricing + mentorship (user opens/copies)
void GsxPremiumAnnounce(const bool force = false)
  {
   if(!force && !GsxPremiumAnnounceAllowed())
     {
      Print("GsignalX Premium announce already shown today — see Experts log / prior Alert");
      return;
     }
   string msg =
      "GsignalX Velocity Premium (hosted / managed)\n"
      "Manual: " + GSX_PREMIUM_MANUAL_URL + "\n"
      "Install & maintenance pricing: " + GSX_SERVICE_PRICING_URL + "\n"
      "Register → Profile → My Services to book: " + GSX_SERVICE_HOME_URL + "\n"
      "Mentorship (optional): " + GSX_MENTORSHIP_URL;
   Print(msg);
   Alert("GsignalX | Managed Premium\n",
         "Manual: ", GSX_PREMIUM_MANUAL_URL, "\n",
         "Book: ", GSX_SERVICE_PRICING_URL, "\n",
         "Mentorship: ", GSX_MENTORSHIP_URL);
   GsxPremiumAnnounceMark();
  }

void GsxMentorshipAnnounce()
  {
   string msg = "GsignalX mentorship — process & market understanding (educational):\n" +
                GSX_MENTORSHIP_URL;
   Print(msg);
   Alert("GsignalX | Mentorship\n", GSX_MENTORSHIP_URL);
  }

#endif // GSX_BRAND_LINKS_MQH
