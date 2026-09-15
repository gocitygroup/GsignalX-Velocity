//+------------------------------------------------------------------+
//|                                         RosterViewModel.mqh       |
//|  Pure multisymbol dashboard snapshot (no chart objects)           |
//+------------------------------------------------------------------+
#ifndef GSX_ROSTER_VIEW_MODEL_MQH
#define GSX_ROSTER_VIEW_MODEL_MQH

#include <GSignalX/RosterStore.mqh>
#include <GSignalX/Fleet.mqh>
#include <GSignalX/BusIO.mqh>
#include <GSignalX/BusProtocol.mqh>
#include <GSignalX/TerminalIdentity.mqh>
#include <GSignalX/SymbolCanon.mqh>
#include <GSignalX/SymbolClass.mqh>
#include <GSignalX/SessionClock.mqh>
#include <GSignalX/PracticeSim.mqh>

//+------------------------------------------------------------------+
struct GsxMsRow
  {
   string symbol;
   string canon;
   int    direction;     // from bus or 0
   int    spreadPt;
   bool   busy;
   bool   muted;         // derived: state != START (compat)
   int    pairState;     // GSX_PAIR_*
   int    symClass;      // ENUM_GSX_SYM_CLASS
   double floatingPl;    // symbol floating for magic
   double gradeScore;    // -1 if unknown
   bool   marketOpen;
   bool   eventBlocked;
   bool   signalStale;   // v2.01: bus ts older than TTL
  };

struct GsxMsSnapshot
  {
   long   magic;
   bool   own;
   bool   run;
   int    fleetActive;
   int    fleetTarget;
   double fleetPl;
   int    positions;
   double rosterSeq;
   int    page;
   int    pageSize;
   int    pageCount;
   int    catFilter;       // GSX_CAT_*
   int    classMax;
   int    countFx;
   int    countCmd;
   int    countCr;
   string carouselSym;   // current candidate (filled by panel)
   // v1.25 Trade Center status
   string propStatus;    // OK or LOCK: reason
   string tgStatus;      // NotCfg / Connected / Verified
   int    tgSent;
   int    tgFail;
   int    tgQueue;
   string tgLastError;
   // v1.26 session + events
   GsxSessionClockState session;
   string eventLine;
   int    eventMode;
   // v2.02 practice coach
   int    pracBand;          // 20/50/100
   int    pracCost;          // 0=RAW 1=STD
   int    pracStyle;         // 0=SCALP 1=DAY 2=SWING
   string tipLine;
   string coachLine;
   GsxMsRow rows[];      // filtered roster for active category; panel pages it
   GsxMsRow allRows[];   // full roster (capacity counts)
  };

//+------------------------------------------------------------------+
double GsxMsSymbolFloating(const long magic, const string symbol)
  {
   double pl = 0.0;
   if(symbol == "")
      return(pl);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      pl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return(pl);
  }

//+------------------------------------------------------------------+
double GsxMsGradeScoreForCanon(const string gradesJson, const string canon)
  {
   if(gradesJson == "" || canon == "")
      return(-1.0);

   string needle = "\"symbol_canon\":\"" + canon + "\"";
   int p = StringFind(gradesJson, needle);
   if(p < 0)
      return(-1.0);

   string chunk = StringSubstr(gradesJson, p, 220);
   double sc = GsxJsonGetDouble(chunk, "score", -1.0);
   return(sc);
  }

//+------------------------------------------------------------------+
bool GsxMsRowMarketOpen(const string symbol)
  {
   if(symbol == "" || !SymbolInfoInteger(symbol, SYMBOL_SELECT))
      return(false);

   long tmode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   if(tmode == SYMBOL_TRADE_MODE_DISABLED || tmode == SYMBOL_TRADE_MODE_CLOSEONLY)
      return(false);

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return(false);
   return(true);
  }

void GsxMsFillRow(const long magic,
                  const string sym,
                  const string grades,
                  const string tid,
                  GsxMsRow &row)
  {
   string canon = GsxSymbolCanon(sym);
   row.symbol     = sym;
   row.canon      = canon;
   row.direction  = 0;
   row.spreadPt   = (int)SymbolInfoInteger(sym, SYMBOL_SPREAD);
   row.busy       = GsxFleetSymbolBusy(sym, magic);
   row.pairState  = GsxRosterStateGet(magic, sym);
   row.muted      = (row.pairState != GSX_PAIR_START);
   row.symClass   = (int)GsxSymbolClass(sym);
   row.floatingPl = GsxMsSymbolFloating(magic, sym);
   row.gradeScore = GsxMsGradeScoreForCanon(grades, canon);
   row.marketOpen = GsxMsRowMarketOpen(sym);
   row.eventBlocked = GsxEventBlocksSymbol(magic, sym);
   row.signalStale = false;

   if(canon != "")
     {
      string sig = GsxBusReadAllRetry(GsxBusSignalPath(tid, canon), 2);
      if(sig != "" && GsxJsonVersionOk(sig))
        {
         row.direction = (int)GsxJsonGetLong(sig, "direction", 0);
         long ts = GsxJsonGetLong(sig, "ts", 0);
         if(ts <= 0 || (TimeCurrent() - (datetime)ts) > 15)
            row.signalStale = true;
        }
      else
         row.signalStale = true; // missing under load / Service down
     }
  }

//+------------------------------------------------------------------+
string GsxMsSnapshotFingerprint(const GsxMsSnapshot &snap)
  {
   string f = StringFormat("%I64d|%d|%d|%d|%d|%.2f|%d|%.0f|%d|%s|%s|%d|%d|",
                           snap.magic, snap.own ? 1 : 0, snap.run ? 1 : 0,
                           snap.fleetActive, snap.fleetTarget, snap.fleetPl,
                           snap.positions, snap.rosterSeq, snap.page,
                           snap.propStatus, snap.tgStatus, snap.eventMode,
                           ArraySize(snap.rows));
   int n = ArraySize(snap.rows);
   int lim = MathMin(n, 40);
   for(int i = 0; i < lim; i++)
     {
      f += StringFormat("%s:%d:%d:%d:%.1f:%d|",
                        snap.rows[i].symbol,
                        snap.rows[i].direction,
                        snap.rows[i].pairState,
                        snap.rows[i].spreadPt,
                        snap.rows[i].floatingPl,
                        snap.rows[i].signalStale ? 1 : 0);
     }
   return f;
  }

//+------------------------------------------------------------------+
void GsxMsBuildSnapshot(const long magic,
                        const int defaultFleetTarget,
                        const int pageSize,
                        GsxMsSnapshot &out)
  {
   out.magic        = magic;
   out.own          = GsxFleetServiceOwns(magic);
   out.run          = GsxFleetServiceRunGet(magic);
   out.rosterSeq    = GsxRosterSeqGet(magic);
   out.carouselSym  = "";
   out.pageSize     = (pageSize < 1 ? 1 : pageSize);
   out.page         = GsxRosterPageGet(magic);
   out.catFilter    = GsxRosterCatGet(magic);
   out.classMax     = GsxRosterClassMaxGet(magic);
   out.propStatus   = "OK";
   out.tgStatus     = "NotCfg";
   out.tgSent       = 0;
   out.tgFail       = 0;
   out.tgQueue      = 0;
   out.tgLastError  = "";
   out.eventLine    = "";
   out.eventMode    = GsxEventModeGet(magic);

   GsxSessionClockConfig scfg;
   GsxSessionClockDefaults(scfg);
   GsxSessionClockNow(scfg, out.session);

   int ov = GsxRosterFleetTargetGet(magic);
   out.fleetTarget  = (ov > 0 ? ov : MathMax(0, defaultFleetTarget));
   out.fleetActive  = GsxFleetActivePairs(magic);
   GsxFleetFloating(magic, out.fleetPl, out.positions);

   string names[];
   if(!GsxRosterStoreLoad(magic, names))
      ArrayResize(names, 0);

   int nAll = ArraySize(names);
   ArrayResize(out.allRows, nAll);

   string tid = GsxMakeTid();
   string grades = GsxBusReadGrades();

   out.countFx = 0;
   out.countCmd = 0;
   out.countCr = 0;

   for(int i = 0; i < nAll; i++)
     {
      GsxMsFillRow(magic, names[i], grades, tid, out.allRows[i]);
      if(out.allRows[i].symClass == GSX_CLASS_FOREX)     out.countFx++;
      if(out.allRows[i].symClass == GSX_CLASS_COMMODITY) out.countCmd++;
      if(out.allRows[i].symClass == GSX_CLASS_CRYPTO)    out.countCr++;
     }

   // filter rows for active category
   ArrayResize(out.rows, 0);
   for(int i = 0; i < nAll; i++)
     {
      bool keep = false;
      if(out.catFilter == GSX_CAT_ALL)
         keep = true;
      else if(out.catFilter == GSX_CAT_FOREX && out.allRows[i].symClass == GSX_CLASS_FOREX)
         keep = true;
      else if(out.catFilter == GSX_CAT_COMMODITY && out.allRows[i].symClass == GSX_CLASS_COMMODITY)
         keep = true;
      else if(out.catFilter == GSX_CAT_CRYPTO && out.allRows[i].symClass == GSX_CLASS_CRYPTO)
         keep = true;
      if(!keep)
         continue;
      int n = ArraySize(out.rows);
      ArrayResize(out.rows, n + 1);
      out.rows[n] = out.allRows[i];
     }

   int n = ArraySize(out.rows);
   out.pageCount = (n <= 0 ? 1 : (n + out.pageSize - 1) / out.pageSize);
   if(out.page >= out.pageCount)
      out.page = out.pageCount - 1;
   if(out.page < 0)
      out.page = 0;

   out.pracBand  = GsxRosterPracBandGet(magic);
   out.pracCost  = GsxRosterPracCostGet(magic);
   out.pracStyle = GsxRosterPracStyleGet(magic);
   GsxPracticeProfile prac;
   GsxPracticeBuild(out.pracBand, out.pracCost, out.pracStyle, prac);
   out.coachLine = GsxPracticeFormatCoachLine(prac);
   out.tipLine   = GsxPracticeFormatTipLine(prac);
  }

#endif // GSX_ROSTER_VIEW_MODEL_MQH
//+------------------------------------------------------------------+
