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

void GsxBusFleetSnapFromBook(const GsxAccountBook &book, GsxBusFleetSnap &snap)
  {
   snap.pl = book.pl;
   snap.pos = book.posCount;
   snap.active = GsxAccountBookActivePairs(book);
   snap.valid = book.valid;
  }

void GsxBusFleetSnapBuild(const long magic, GsxBusFleetSnap &snap)
  {
   GsxAccountBook book;
   GsxAccountBookBuild(magic, book);
   GsxBusFleetSnapFromBook(book, snap);
  }

// Shared gate/dir snapshot — Fingerprint + Write pay market gates once.
struct GsxBusSymbolView
  {
   int    direction;
   int    bull;
   int    bear;
   int    minAgree;
   bool   marketOpen;
   bool   weekend;
   bool   fridayLate;
   bool   swing;
   long   spread;
   int    effMaxSpread;
   bool   stale;
   int    lastSigDir;
   string reason;
  };

//+------------------------------------------------------------------+
void GsxSignalBusHeartbeat(const string source)
  {
   GsxBusPublishHeartbeat(source);
  }

//+------------------------------------------------------------------+
void GsxBusBuildSymbolView(const string symbol,
                           const GsxEngineState &st,
                           const int minAgree,
                           const int maxSpreadPt,
                           const int staleTickSec,
                           const bool ignoreSpread,
                           const int swingStartH,
                           const int swingEndH,
                           const string cryptoExtra,
                           const bool fridayStop,
                           const int fridayStopHr,
                           const int joinDirOverride,
                           GsxBusSymbolView &v)
  {
   v.minAgree = minAgree;
   v.lastSigDir = st.lastSigDir;
   v.reason = "";
   v.marketOpen = GsxIsMarketOpen(symbol, staleTickSec, false, true,
                                  true, cryptoExtra, v.reason);
   bool cryptoExempt = GsxCryptoWeekendExempt(symbol, true, cryptoExtra);
   v.weekend = false;
   v.fridayLate = false;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if((dt.day_of_week == SATURDAY || dt.day_of_week == SUNDAY) && !cryptoExempt)
      v.weekend = true;
   int friHr = (fridayStopHr < 0 ? 20 : fridayStopHr);
   if(fridayStop && !cryptoExempt && dt.day_of_week == FRIDAY && dt.hour >= friHr)
      v.fridayLate = true;

   v.bull = 0;
   v.bear = 0;
   v.direction = 0;
   if(st.ready && st.n >= 1)
     {
      int last = st.n - 1;
      v.bull = (st.ppDir[last] == 1 ? 1 : 0) +
               (st.stDir[last] == 1 ? 1 : 0) +
               (st.sbtDir[last] == 1 ? 1 : 0);
      v.bear = 3 - v.bull;
     }

   // Write path: joinDir override (Service Core). Fingerprint uses 999.
   if(joinDirOverride != 999)
      v.direction = joinDirOverride;
   else if(st.ready && st.n >= 1)
     {
      if(v.bull > v.bear)
         v.direction = 1;
      else if(v.bear > v.bull)
         v.direction = -1;
      if(st.lastSigDir != 0)
         v.direction = st.lastSigDir;
     }

   v.spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   v.stale = false;
   datetime tickTime = (datetime)SymbolInfoInteger(symbol, SYMBOL_TIME);
   if(staleTickSec > 0 && tickTime > 0 && (TimeCurrent() - tickTime) > staleTickSec)
      v.stale = true;
   v.swing = GsxInSwingWindow(TimeCurrent(), swingStartH, swingEndH);
   v.effMaxSpread = ignoreSpread ? 0 : maxSpreadPt;
  }

string GsxSignalBusFingerprintFromView(const GsxBusSymbolView &v)
  {
   return StringFormat("%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d",
                       v.direction, v.bull, v.bear, v.minAgree,
                       (v.marketOpen ? 1 : 0), (v.weekend ? 1 : 0), (v.fridayLate ? 1 : 0),
                       (v.swing ? 1 : 0), (int)v.spread, v.effMaxSpread, (v.stale ? 1 : 0),
                       v.lastSigDir);
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
   GsxBusSymbolView v;
   GsxBusBuildSymbolView(symbol, st, minAgree, maxSpreadPt, staleTickSec, ignoreSpread,
                         swingStartH, swingEndH, cryptoExtra, fridayStop, fridayStopHr,
                         999, v);
   return(GsxSignalBusFingerprintFromView(v));
  }

bool GsxSignalBusWriteFromView(const string symbol,
                               const GsxEngineState &st,
                               const GsxBusSymbolView &v,
                               const long magic,
                               const int modeSimple0Adv1,
                               const string cryptoExtra,
                               const bool busEnable,
                               const int closedCount,
                               const int closedWins,
                               const int closedLosses,
                               const double closedRealized,
                               const string fleetOwner,
                               const GsxBusFleetSnap &fleetSnap,
                               const string fillSkip,
                               const bool writeTidPath)
  {
   if(!busEnable)
      return(false);

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
      // Hot-path fallback — callers should pass a valid cycle snap (Core does).
      static datetime s_snapWarnAt = 0;
      if(TimeCurrent() - s_snapWarnAt >= 30)
        {
         PrintFormat("GsignalX bus: fleet snap invalid on %s — rebuilding AccountBook",
                     symbol);
         s_snapWarnAt = TimeCurrent();
        }
      GsxBusFleetSnap built;
      GsxBusFleetSnapBuild(magic, built);
      fleetPL = built.pl;
      fleetPos = built.pos;
      fleetActive = built.active;
     }

   string j = "{";
   j += GsxJsonKV_I("version", GSX_BUS_VERSION);
   j += GsxJsonKV_I("ts", (long)TimeCurrent());
   j += GsxJsonKV_S("tid", tid);
   j += GsxJsonKV_S("symbol", symbol);
   j += GsxJsonKV_S("symbol_canon", canon);
   j += GsxJsonKV_I("direction", v.direction);
   j += GsxJsonKV_I("last_sig_dir", st.lastSigDir);
   j += GsxJsonKV_I("bull", v.bull);
   j += GsxJsonKV_I("bear", v.bear);
   j += GsxJsonKV_I("min_agree", v.minAgree);
   j += GsxJsonKV_S("mode", (modeSimple0Adv1 == 0 ? "simple" : "advanced"));
   j += GsxJsonKV_B("is_crypto", GsxIsCryptoSymbolEx(symbol, cryptoExtra));
   j += GsxJsonKV_B("in_session", v.marketOpen && !v.weekend);
   j += GsxJsonKV_B("weekend", v.weekend);
   j += GsxJsonKV_B("friday_late", v.fridayLate);
   j += GsxJsonKV_B("swing_window", v.swing);
   j += GsxJsonKV_I("spread_pt", v.spread);
   j += GsxJsonKV_I("max_spread_pt", v.effMaxSpread);
   j += GsxJsonKV_B("stale_tick", v.stale);
   j += GsxJsonKV_B("market_open", v.marketOpen);
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
   GsxBusSymbolView v;
   GsxBusBuildSymbolView(symbol, st, minAgree, maxSpreadPt, staleTickSec, ignoreSpread,
                         swingStartH, swingEndH, cryptoExtra, fridayStop, fridayStopHr,
                         joinDirOverride, v);
   return(GsxSignalBusWriteFromView(symbol, st, v, magic, modeSimple0Adv1, cryptoExtra,
                                    busEnable, closedCount, closedWins, closedLosses,
                                    closedRealized, fleetOwner, fleetSnap, fillSkip,
                                    writeTidPath));
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
                             const string fleetOwner,
                             const int joinDirOverride = 999)
  {
   GsxBusFleetSnap snap;
   GsxBusFleetSnapBuild(magic, snap);
   return GsxSignalBusWriteSymbolEx(symbol, st, magic, minAgree, modeSimple0Adv1,
                                    maxSpreadPt, staleTickSec, ignoreSpread,
                                    swingStartH, swingEndH, cryptoExtra, busEnable,
                                    closedCount, closedWins, closedLosses,
                                    closedRealized, fleetOwner, snap, "",
                                    joinDirOverride);
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
