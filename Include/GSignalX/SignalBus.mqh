//+------------------------------------------------------------------+
//|                                                  SignalBus.mqh    |
//|  Per-symbol signal JSON + heartbeat for FILE_COMMON connector bus |
//|  v2.01: optional fleet snapshot (avoid per-symbol position scans) |
//+------------------------------------------------------------------+
#ifndef GSX_SIGNAL_BUS_MQH
#define GSX_SIGNAL_BUS_MQH

#include <GSignalX/Engines.mqh>
#include <GSignalX/Fleet.mqh>
#include <GSignalX/BusIO.mqh>
#include <GSignalX/BusProtocol.mqh>
#include <GSignalX/SymbolCanon.mqh>
#include <GSignalX/OpportunityGrade.mqh>
#include <GSignalX/TerminalIdentity.mqh>
#include <GSignalX/MarketGates.mqh>

//+------------------------------------------------------------------+
struct GsxBusFleetSnap
  {
   double pl;
   int    pos;
   int    active;
   bool   valid;
  };

//+------------------------------------------------------------------+
void GsxSignalBusHeartbeat(const string source)
  {
   GsxBusPublishHeartbeat(source);
  }

//+------------------------------------------------------------------+
//| Fingerprint of fields that merit a bus rewrite (dirty publish).   |
//+------------------------------------------------------------------+
string GsxSignalBusFingerprint(const string symbol,
                               const GsxEngineState &st,
                               const int minAgree,
                               const int maxSpreadPt,
                               const int staleTickSec,
                               const bool ignoreSpread,
                               const int swingStartH,
                               const int swingEndH,
                               const string cryptoExtra,
                               const bool fridayStop = true,
                               const int fridayStopHr = 20)
  {
   string reason = "";
   bool marketOpen = GsxIsMarketOpen(symbol, staleTickSec, false, true,
                                     true, cryptoExtra, reason);
   bool cryptoExempt = GsxCryptoWeekendExempt(symbol, true, cryptoExtra);
   bool weekend = false;
   bool fridayLate = false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if((dt.day_of_week == SATURDAY || dt.day_of_week == SUNDAY) && !cryptoExempt)
      weekend = true;
   int friHr = (fridayStopHr < 0 ? 20 : fridayStopHr);
   if(fridayStop && !cryptoExempt && dt.day_of_week == FRIDAY && dt.hour >= friHr)
      fridayLate = true;

   int bull = 0, bear = 0, direction = 0;
   if(st.ready && st.n >= 1)
     {
      int last = st.n - 1;
      bull = (st.ppDir[last] == 1 ? 1 : 0) +
             (st.stDir[last] == 1 ? 1 : 0) +
             (st.sbtDir[last] == 1 ? 1 : 0);
      bear = 3 - bull;
      if(bull > bear) direction = 1;
      else if(bear > bull) direction = -1;
      if(st.lastSigDir != 0)
         direction = st.lastSigDir;
     }

   long spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   bool stale = false;
   datetime tickTime = (datetime)SymbolInfoInteger(symbol, SYMBOL_TIME);
   if(staleTickSec > 0 && tickTime > 0 && (TimeCurrent() - tickTime) > staleTickSec)
      stale = true;
   bool swing = GsxInSwingWindow(TimeCurrent(), swingStartH, swingEndH);
   int effMax = ignoreSpread ? 0 : maxSpreadPt;

   return StringFormat("%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d",
                       direction, bull, bear, minAgree,
                       (marketOpen ? 1 : 0), (weekend ? 1 : 0), (fridayLate ? 1 : 0),
                       (swing ? 1 : 0), (int)spread, effMax, (stale ? 1 : 0),
                       st.lastSigDir);
  }

//+------------------------------------------------------------------+
bool GsxSignalBusWriteSymbolEx(const string symbol,
                               const GsxEngineState &st,
                               const long magic,
                               const int minAgree,
                               const int modeSimple0Adv1,
                               const int maxSpreadPt,
                               const int staleTickSec,
                               const bool ignoreSpread,
                               const int swingStartH,
                               const int swingEndH,
                               const string cryptoExtra,
                               const bool busEnable,
                               const int closedCount,
                               const int closedWins,
                               const int closedLosses,
                               const double closedRealized,
                               const string fleetOwner,
                               const GsxBusFleetSnap &fleetSnap,
                               const string fillSkip = "",
                               const int joinDirOverride = 999,
                               const bool fridayStop = true,
                               const int fridayStopHr = 20,
                               const bool writeTidPath = true)
  {
   if(!busEnable)
      return(false);

   string reason = "";
   bool marketOpen = GsxIsMarketOpen(symbol, staleTickSec, false, true,
                                     true, cryptoExtra, reason);

   bool cryptoExempt = GsxCryptoWeekendExempt(symbol, true, cryptoExtra);
   bool calendarWeekend = false;
   bool weekend = false;
   bool fridayLate = false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == SATURDAY || dt.day_of_week == SUNDAY)
      calendarWeekend = true;
   weekend = calendarWeekend && !cryptoExempt;
   int friHr = (fridayStopHr < 0 ? 20 : fridayStopHr);
   if(fridayStop && !cryptoExempt && dt.day_of_week == FRIDAY && dt.hour >= friHr)
      fridayLate = true;

   int bull = 0, bear = 0, direction = 0;
   if(st.ready && st.n >= 1)
     {
      int last = st.n - 1;
      bull = (st.ppDir[last] == 1 ? 1 : 0) +
             (st.stDir[last] == 1 ? 1 : 0) +
             (st.sbtDir[last] == 1 ? 1 : 0);
      bear = 3 - bull;
     }

   // v2.10: when caller passes joinDir (Service Core), desk DIR matches fill
   if(joinDirOverride != 999)
      direction = joinDirOverride;
   else if(st.ready && st.n >= 1)
     {
      if(bull > bear)
         direction = 1;
      else if(bear > bull)
         direction = -1;
      if(st.lastSigDir != 0)
         direction = st.lastSigDir;
     }

   long spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   bool stale = false;
   datetime tickTime = (datetime)SymbolInfoInteger(symbol, SYMBOL_TIME);
   if(staleTickSec > 0 && tickTime > 0 && (TimeCurrent() - tickTime) > staleTickSec)
      stale = true;

   int effMaxSpread = ignoreSpread ? 0 : maxSpreadPt;
   bool swing = GsxInSwingWindow(TimeCurrent(), swingStartH, swingEndH);
   string tid = GsxMakeTid();
   string canon = GsxSymbolCanon(symbol);

   double fleetPL = 0.0;
   int    fleetPos = 0;
   int    fleetActive = 0;
   if(fleetSnap.valid)
     {
      fleetPL = fleetSnap.pl;
      fleetPos = fleetSnap.pos;
      fleetActive = fleetSnap.active;
     }
   else
     {
      GsxFleetFloating(magic, fleetPL, fleetPos);
      fleetActive = GsxFleetActivePairs(magic);
     }

   string j = "{";
   j += GsxJsonKV_I("version", GSX_BUS_VERSION);
   j += GsxJsonKV_I("ts", (long)TimeCurrent());
   j += GsxJsonKV_S("tid", tid);
   j += GsxJsonKV_S("symbol", symbol);
   j += GsxJsonKV_S("symbol_canon", canon);
   j += GsxJsonKV_I("direction", direction);
   j += GsxJsonKV_I("last_sig_dir", st.lastSigDir);
   j += GsxJsonKV_I("bull", bull);
   j += GsxJsonKV_I("bear", bear);
   j += GsxJsonKV_I("min_agree", minAgree);
   j += GsxJsonKV_S("mode", (modeSimple0Adv1 == 0 ? "simple" : "advanced"));
   j += GsxJsonKV_B("is_crypto", GsxIsCryptoSymbolEx(symbol, cryptoExtra));
   j += GsxJsonKV_B("in_session", marketOpen && !weekend);
   j += GsxJsonKV_B("weekend", weekend);
   j += GsxJsonKV_B("friday_late", fridayLate);
   j += GsxJsonKV_B("swing_window", swing);
   j += GsxJsonKV_I("spread_pt", spread);
   j += GsxJsonKV_I("max_spread_pt", effMaxSpread);
   j += GsxJsonKV_B("stale_tick", stale);
   j += GsxJsonKV_B("market_open", marketOpen);
   j += GsxJsonKV_I("positions", fleetPos);
   j += GsxJsonKV_D("fleet_floating", fleetPL);
   j += GsxJsonKV_I("fleet_active", fleetActive);
   j += GsxJsonKV_S("fleet_owner", (fleetOwner == "" ? "unknown" : fleetOwner));
   j += GsxJsonKV_I("closed_count", closedCount);
   j += GsxJsonKV_I("closed_wins", closedWins);
   j += GsxJsonKV_I("closed_losses", closedLosses);
   j += GsxJsonKV_D("closed_realized", closedRealized, true);
   j += GsxJsonKV_S("fill_skip", fillSkip, false);
   j += "}";

   // v2.15: always write desk mirror (UI freshest); tid path on full-sync/register
   bool okMirror = GsxBusWriteAtomic(GsxBusDeskSignalPath(canon), j);
   if(!okMirror)
      return(false);
   if(writeTidPath)
     {
      if(!GsxBusWriteAtomic(GsxBusSignalPath(tid, canon), j))
         return(false);
     }
   GsxBusRegisterSignal(tid, canon);
   return(true);
  }

//+------------------------------------------------------------------+
bool GsxSignalBusWriteSymbol(const string symbol,
                             const GsxEngineState &st,
                             const long magic,
                             const int minAgree,
                             const int modeSimple0Adv1,
                             const int maxSpreadPt,
                             const int staleTickSec,
                             const bool ignoreSpread,
                             const int swingStartH,
                             const int swingEndH,
                             const string cryptoExtra,
                             const bool busEnable,
                             const int closedCount,
                             const int closedWins,
                             const int closedLosses,
                             const double closedRealized,
                             const string fleetOwner)
  {
   GsxBusFleetSnap snap;
   snap.pl = 0;
   snap.pos = 0;
   snap.active = 0;
   snap.valid = false;
   return GsxSignalBusWriteSymbolEx(symbol, st, magic, minAgree, modeSimple0Adv1,
                                    maxSpreadPt, staleTickSec, ignoreSpread,
                                    swingStartH, swingEndH, cryptoExtra, busEnable,
                                    closedCount, closedWins, closedLosses,
                                    closedRealized, fleetOwner, snap, "");
  }

//+------------------------------------------------------------------+
void GsxSignalBusPublish(const string symbol,
                         ENUM_TIMEFRAMES /*unused*/,
                         const GsxEngineState &st,
                         const long magic,
                         const int minAgree,
                         const int modeSimple0Adv1,
                         const int maxSpreadPt,
                         const int staleTickSec,
                         const bool ignoreSpread,
                         const int swingStartH,
                         const int swingEndH,
                         const string cryptoExtra,
                         const bool busEnable,
                         datetime &lastPub,
                         const int closedCount,
                         const int closedWins,
                         const int closedLosses,
                         const double closedRealized,
                         const string fleetOwner)
  {
   if(!busEnable)
      return;
   if(lastPub != 0 && TimeCurrent() - lastPub < 2)
      return;
   lastPub = TimeCurrent();

   GsxSignalBusWriteSymbol(symbol, st, magic, minAgree, modeSimple0Adv1,
                           maxSpreadPt, staleTickSec, ignoreSpread,
                           swingStartH, swingEndH, cryptoExtra, busEnable,
                           closedCount, closedWins, closedLosses,
                           closedRealized, fleetOwner);
   GsxSignalBusHeartbeat("gsignalx");
  }

#endif // GSX_SIGNAL_BUS_MQH
//+------------------------------------------------------------------+
