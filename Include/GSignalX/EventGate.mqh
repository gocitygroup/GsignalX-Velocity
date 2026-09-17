//+------------------------------------------------------------------+
//|                                                EventGate.mqh      |
//|  Hybrid economic events: MT5 Calendar + desk CSV.                 |
//|  TRADE = notify only; SKIP = block new fills on affected pairs.   |
//|  Block GVs live in RosterStore; Dashboard polls this module.      |
//+------------------------------------------------------------------+
#ifndef GSX_EVENT_GATE_MQH
#define GSX_EVENT_GATE_MQH

#include <GSignalX/RosterStore.mqh>
#include <GSignalX/SymbolCanon.mqh>
#include <GSignalX/SymbolClass.mqh>
#include <GSignalX/TelegramNotifier.mqh>

#define GSX_EVT_MAX         24

struct GsxEventItem
  {
   datetime when;
   string   name;
   string   currency;   // ISO currency or "DESK"
   string   source;     // CAL | DESK
   int      importance; // 0..3
   string   symbols;    // comma of affected roster symbols
   bool     inBlackout;
   bool     notifyDue;
  };

struct GsxEventGateConfig
  {
   long   magic;
   bool   calendarEnable;
   int    lookAheadMin;      // collect events within this window
   int    blackoutMin;       // radius either side for SKIP
   int    notifyAheadMin;    // Telegram when within this before event
   int    mode;              // TRADE / SKIP
   string deskTimesCsv;      // YYYY.MM.DD HH:MM,...
   string deskNamesCsv;      // optional parallel names
  };

struct GsxEventGateSnapshot
  {
   int    mode;
   int    count;
   string nextLine;          // compact UI line
   GsxEventItem items[];
  };

//+------------------------------------------------------------------+
string GsxEventNotifyVar(const long magic, const string key)
  {
   return(StringFormat("GSX_EVT_NTF_%d_%s", (int)magic, key));
  }

bool GsxEventCurrencyHitsSymbol(const string currency, const string symbol)
  {
   if(currency == "" || symbol == "")
      return(false);
   string ccy = currency;
   StringToUpper(ccy);

   if(ccy == "DESK" || ccy == "ALL")
      return(true);

   string base = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
   string profit = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   StringToUpper(base);
   StringToUpper(profit);
   if(base == ccy || profit == ccy)
      return(true);

   ENUM_GSX_SYM_CLASS cls = GsxSymbolClass(symbol);
   // Metals/oils sometimes lack ISO base/profit — still treat USD news as relevant.
   // Do NOT blanket-block all crypto on every USD calendar print (24/7 book).
   if(cls == GSX_CLASS_COMMODITY && ccy == "USD")
      return(true);

   string canon = GsxSymbolCanon(symbol);
   if(StringFind(canon, ccy) >= 0)
      return(true);
   return(false);
  }

string GsxEventAffectedSymbols(const string currency,
                               const string &roster[],
                               const long magic,
                               const bool activeOnly)
  {
   string out = "";
   for(int i = 0; i < ArraySize(roster); i++)
     {
      string sym = roster[i];
      if(sym == "")
         continue;
      if(activeOnly && GsxRosterStateGet(magic, sym) != GSX_PAIR_START)
         continue;
      if(!GsxEventCurrencyHitsSymbol(currency, sym))
         continue;
      if(out != "")
         out += ",";
      out += sym;
     }
   return(out);
  }

string GsxEventCountryToCurrency(const string countryCode)
  {
   string c = countryCode;
   StringToUpper(c);
   if(c == "US" || c == "USA") return("USD");
   if(c == "EU" || c == "EMU") return("EUR");
   if(c == "GB" || c == "UK")  return("GBP");
   if(c == "JP" || c == "JPN") return("JPY");
   if(c == "AU" || c == "AUS") return("AUD");
   if(c == "NZ" || c == "NZL") return("NZD");
   if(c == "CA" || c == "CAN") return("CAD");
   if(c == "CH" || c == "CHE") return("CHF");
   if(c == "CN" || c == "CHN") return("CNY");
   if(c == "DE" || c == "DEU") return("EUR");
   if(c == "FR" || c == "FRA") return("EUR");
   if(c == "IT" || c == "ITA") return("EUR");
   if(c == "ES" || c == "ESP") return("EUR");
   return(c);
  }

bool GsxEventAlreadyNotified(const long magic, const string key)
  {
   string n = GsxEventNotifyVar(magic, key);
   if(!GlobalVariableCheck(n))
      return(false);
   return(GlobalVariableGet(n) > 0.5);
  }

void GsxEventMarkNotified(const long magic, const string key)
  {
   GlobalVariableSet(GsxEventNotifyVar(magic, key), 1.0);
  }

string GsxEventDedupeKey(const datetime when, const string name, const string currency)
  {
   string safe = name;
   StringReplace(safe, " ", "_");
   if(StringLen(safe) > 24)
      safe = StringSubstr(safe, 0, 24);
   return(StringFormat("%I64d_%s_%s", (long)when, currency, safe));
  }

void GsxEventPushItem(GsxEventItem &items[], const GsxEventItem &it)
  {
   int n = ArraySize(items);
   if(n >= GSX_EVT_MAX)
      return;
   ArrayResize(items, n + 1);
   items[n] = it;
  }

void GsxEventSortByTime(GsxEventItem &items[])
  {
   int n = ArraySize(items);
   for(int i = 0; i < n; i++)
      for(int j = i + 1; j < n; j++)
         if(items[j].when < items[i].when)
           {
            GsxEventItem tmp = items[i];
            items[i] = items[j];
            items[j] = tmp;
           }
  }

void GsxEventCollectDesk(const GsxEventGateConfig &cfg,
                         const string &roster[],
                         GsxEventItem &items[])
  {
   if(cfg.deskTimesCsv == "")
      return;

   string times[];
   string names[];
   int nt = StringSplit(cfg.deskTimesCsv, ',', times);
   int nn = 0;
   if(cfg.deskNamesCsv != "")
      nn = StringSplit(cfg.deskNamesCsv, ',', names);

   datetime now = TimeCurrent();
   int radius = MathMax(0, cfg.blackoutMin) * 60;
   int look = MathMax(cfg.lookAheadMin, cfg.blackoutMin) * 60;
   int notifyH = MathMax(0, cfg.notifyAheadMin) * 60;

   for(int i = 0; i < nt; i++)
     {
      string t = times[i];
      StringTrimLeft(t);
      StringTrimRight(t);
      if(t == "")
         continue;
      datetime when = StringToTime(t);
      if(when <= 0)
         continue;

      long delta = (long)(when - now);
      if(delta < -radius)
         continue;
      if(delta > look)
         continue;

      GsxEventItem it;
      it.when = when;
      it.currency = "DESK";
      it.source = "DESK";
      it.importance = 3;
      if(i < nn)
        {
         string nm = names[i];
         StringTrimLeft(nm);
         StringTrimRight(nm);
         it.name = (nm == "" ? "Desk event" : nm);
        }
      else
         it.name = "Desk event";
      it.symbols = GsxEventAffectedSymbols("DESK", roster, cfg.magic, true);
      it.inBlackout = (MathAbs(delta) <= radius);
      it.notifyDue = (delta >= 0 && delta <= notifyH);
      if(it.symbols != "")
         GsxEventPushItem(items, it);
     }
  }

void GsxEventCollectCalendar(const GsxEventGateConfig &cfg,
                             const string &roster[],
                             GsxEventItem &items[])
  {
   if(!cfg.calendarEnable)
      return;

   datetime now = TimeCurrent();
   datetime from = now - MathMax(0, cfg.blackoutMin) * 60;
   datetime to   = now + MathMax(cfg.lookAheadMin, 1) * 60;
   int radius = MathMax(0, cfg.blackoutMin) * 60;
   int notifyH = MathMax(0, cfg.notifyAheadMin) * 60;

   MqlCalendarValue values[];
   int n = CalendarValueHistory(values, from, to);
   if(n <= 0)
      return;

   for(int i = 0; i < n; i++)
     {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev))
         continue;
      if(ev.importance < CALENDAR_IMPORTANCE_HIGH)
         continue;

      datetime when = values[i].time;
      if(when <= 0)
         when = values[i].period;
      if(when <= 0)
         continue;

      MqlCalendarCountry country;
      string ccy = "";
      if(CalendarCountryById(ev.country_id, country))
        {
         ccy = country.currency;
         if(ccy == "")
            ccy = GsxEventCountryToCurrency(country.code);
        }
      if(ccy == "")
         continue;
      StringToUpper(ccy);

      string affected = GsxEventAffectedSymbols(ccy, roster, cfg.magic, true);
      if(affected == "")
         continue;

      long delta = (long)(when - now);

      GsxEventItem it;
      it.when = when;
      it.name = ev.name;
      it.currency = ccy;
      it.source = "CAL";
      it.importance = (int)ev.importance;
      it.symbols = affected;
      it.inBlackout = (MathAbs(delta) <= radius);
      it.notifyDue = (delta >= 0 && delta <= notifyH);
      GsxEventPushItem(items, it);
     }
  }

void GsxEventApplyBlocks(const GsxEventGateConfig &cfg,
                         const string &roster[],
                         const GsxEventItem &items[])
  {
   GsxEventBlockClearAll(cfg.magic, roster);
   if(cfg.mode != GSX_EVT_MODE_SKIP)
      return;

   for(int i = 0; i < ArraySize(items); i++)
     {
      if(!items[i].inBlackout)
         continue;
      string parts[];
      int np = StringSplit(items[i].symbols, ',', parts);
      for(int k = 0; k < np; k++)
        {
         string s = parts[k];
         StringTrimLeft(s);
         StringTrimRight(s);
         if(s != "")
            GsxEventBlockSet(cfg.magic, s, true);
        }
     }
  }

string GsxEventBuildNextLine(const GsxEventItem &items[], const int mode)
  {
   string modeLbl = GsxEventModeLabel(mode);
   if(ArraySize(items) <= 0)
      return(modeLbl + " · no upcoming events");

   GsxEventItem it = items[0];
   string nm = it.name;
   if(StringLen(nm) > 28)
      nm = StringSubstr(nm, 0, 28) + "..";
   return(StringFormat("%s · %s %s %s [%s]",
                       modeLbl,
                       TimeToString(it.when, TIME_DATE|TIME_MINUTES),
                       it.currency,
                       nm,
                       it.source));
  }

bool GsxEventGatePoll(const GsxEventGateConfig &cfg,
                      const GsxTgConfig &tgCfg,
                      const bool sendTelegram,
                      GsxEventGateSnapshot &snap)
  {
   snap.mode = cfg.mode;
   snap.count = 0;
   snap.nextLine = "";
   ArrayResize(snap.items, 0);

   string roster[];
   if(!GsxRosterStoreLoad(cfg.magic, roster))
      ArrayResize(roster, 0);

   GsxEventCollectDesk(cfg, roster, snap.items);
   GsxEventCollectCalendar(cfg, roster, snap.items);
   GsxEventSortByTime(snap.items);
   snap.count = ArraySize(snap.items);
   snap.nextLine = GsxEventBuildNextLine(snap.items, cfg.mode);

   GsxEventApplyBlocks(cfg, roster, snap.items);

   if(sendTelegram && tgCfg.enable)
     {
      for(int i = 0; i < snap.count; i++)
        {
         if(!snap.items[i].notifyDue)
            continue;
         string key = GsxEventDedupeKey(snap.items[i].when,
                                        snap.items[i].name,
                                        snap.items[i].currency);
         if(GsxEventAlreadyNotified(cfg.magic, key))
            continue;
         string body = StringFormat("%s %s | %s | pairs=%s | mode=%s",
                                    TimeToString(snap.items[i].when, TIME_DATE|TIME_MINUTES),
                                    snap.items[i].currency,
                                    snap.items[i].name,
                                    snap.items[i].symbols,
                                    GsxEventModeLabel(cfg.mode));
         GsxTgNotifyCustom(tgCfg, "EVENT", body);
         GsxEventMarkNotified(cfg.magic, key);
        }
     }
   return(true);
  }

#endif // GSX_EVENT_GATE_MQH
//+------------------------------------------------------------------+
