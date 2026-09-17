//+------------------------------------------------------------------+
//|                                         RosterViewModel.mqh       |
//|  Pure multisymbol dashboard snapshot (no chart objects)           |
//+------------------------------------------------------------------+
#ifndef GSX_ROSTER_VIEW_MODEL_MQH
#define GSX_ROSTER_VIEW_MODEL_MQH

#include <GSignalX/RosterStore.mqh>
#include <GSignalX/Fleet.mqh>
#include <GSignalX/ScoutLink.mqh>
#include <GSignalX/BusIO.mqh>
#include <GSignalX/BusProtocol.mqh>
#include <GSignalX/TerminalIdentity.mqh>
#include <GSignalX/SymbolCanon.mqh>
#include <GSignalX/SymbolClass.mqh>
#include <GSignalX/SessionClock.mqh>
#include <GSignalX/PracticeSim.mqh>
#include <GSignalX/LotSizing.mqh>

//+------------------------------------------------------------------+
struct GsxMsRow
  {
   string symbol;
   string canon;
   int    direction;     // from bus or lastDir GV
   int    spreadPt;
   bool   busy;
   bool   muted;         // derived: state != START (compat)
   int    pairState;     // GSX_PAIR_*
   int    symClass;      // ENUM_GSX_SYM_CLASS
   double floatingPl;    // symbol floating for magic
   double gradeScore;    // -1 if unknown
   bool   marketOpen;
   bool   eventBlocked;
   bool   signalStale;   // v2.01: bus ts older than TTL (had bus)
   int    followDir;     // GSX_FOLLOW_* Follow/Buy/Sell/Wait
   int    signalAgeSec;  // v2.06: seconds since bus ts (-1 unknown)
   datetime signalTs;    // bus ts
   // v2.07 DIR UX: COMPUTE / LIVE / STALE / FLAT / HIST
   string dirState;      // COMPUTE|LIVE|STALE|FLAT|HIST
   string fillSkip;      // Service fill_skip from bus
   bool   histDir;       // direction from lastDir GV
  };

struct GsxMsSnapshot
  {
   long   magic;
   bool   own;
   bool   run;
   bool   svcAlive;      // OWN + heartbeat (entries health)
   bool   hbFresh;       // v2.08: heartbeat alone
   bool   ignoreSpread;  // v2.08: desk SPREAD/IGN
   bool   autoLot;       // v2.09: desk AUTOLOT
   double eqGuardPct;    // v2.09: desk EQ guard %
   int    drillSecLeft;  // v2.10: desk drill seconds remaining (0=off/expired)
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
   // v2.03 desk chrome completeness
   bool   flipWait;          // FOLLOW=false WAIT=true
   bool   scoutLink;         // InpScoutLinkEnable mirrored by panel
   bool   scoutOn;           // PS{id}_RUN
   int    deskTf;            // Period seconds enum from Trade Center chart
   bool   deskTfFromChart;   // true when GSX_MS_TF_* present + valid
   double accountEquity;     // v2.05 Trade Info fingerprint
   double accountBalance;
   double accountDdPct;
   // v2.13 Prop / session guidance (display only)
   double propPeakDdPct;
   double propDayRealized;
   double propWeekRealized;
   int    propTradesToday;
   int    propMaxTrades;     // 0=off / unknown until host injects
   int    sessionWins;
   int    sessionLosses;
   double sessionNetPl;
   bool   continuousFleet;   // host InpContinuousFleet mirrored
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

// v2.14.1: one positions walk → per-symbol PL (avoids O(roster × positions))
void GsxMsBuildFloatingPlMap(const long magic, string &syms[], double &pls[])
  {
   ArrayResize(syms, 0);
   ArrayResize(pls, 0);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      if(sym == "")
         continue;
      double add = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      int found = -1;
      for(int k = 0; k < ArraySize(syms); k++)
         if(syms[k] == sym)
           {
            found = k;
            break;
           }
      if(found < 0)
        {
         int n = ArraySize(syms);
         ArrayResize(syms, n + 1);
         ArrayResize(pls, n + 1);
         syms[n] = sym;
         pls[n] = add;
        }
      else
         pls[found] += add;
     }
  }

double GsxMsFloatingPlLookup(const string &syms[], const double &pls[], const string symbol)
  {
   if(symbol == "")
      return(0.0);
   for(int i = 0; i < ArraySize(syms); i++)
      if(syms[i] == symbol)
         return(pls[i]);
   return(0.0);
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
                  GsxMsRow &row,
                  const double floatingPl = 0.0,
                  const bool floatingPlKnown = false)
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
   row.floatingPl = (floatingPlKnown ? floatingPl : GsxMsSymbolFloating(magic, sym));
   row.gradeScore = GsxMsGradeScoreForCanon(grades, canon);
   row.marketOpen = GsxMsRowMarketOpen(sym);
   row.eventBlocked = GsxEventBlocksSymbol(magic, sym);
   row.signalStale = false;
   row.followDir = GsxRosterFollowDirGet(magic, sym, GSX_FOLLOW_AUTO);
   row.signalAgeSec = -1;
   row.signalTs = 0;
   row.dirState = "COMPUTE";
   row.fillSkip = "";
   row.histDir = false;

   if(canon == "")
      return;

   // Same-process Core (Dashboard DeskExecute): prefer live joinDir over bus I/O
#ifdef GSX_DESK_CORE_LIVE
   {
    int liveDir = 0;
    string liveSkip = "";
    bool liveReady = false;
    if(GsxCoreLiveRowForSymbol(sym, liveDir, liveSkip, liveReady))
      {
       // Only trust LIVE when Core actually owns this symbol's price series
       if(liveReady || liveDir != 0 || liveSkip != "")
         {
          row.direction = liveDir;
          row.fillSkip = liveSkip;
          row.signalTs = TimeCurrent();
          row.signalAgeSec = 0;
          row.signalStale = false;
          row.histDir = false;
          if(liveDir != 0 && liveReady)
             row.dirState = "LIVE";
          else if(liveSkip != "" &&
                  (StringFind(liveSkip, "wait") >= 0 ||
                   StringFind(liveSkip, "history") >= 0 ||
                   StringFind(liveSkip, "engine") >= 0 ||
                   StringFind(liveSkip, "no bars") >= 0 ||
                   StringFind(liveSkip, "mismatch") >= 0))
             row.dirState = "COMPUTE";
          else if(liveDir != 0)
             row.dirState = "COMPUTE"; // direction without verified ready
          else
             row.dirState = "FLAT";
          return;
         }
      }
   }
#endif

   datetime bestTs = 0;
   string sig = GsxBusReadFreshestSignal(canon, bestTs);
   if(sig != "")
     {
      row.direction = (int)GsxJsonGetLong(sig, "direction", 0);
      if(row.direction == 0)
         row.direction = (int)GsxJsonGetLong(sig, "last_sig_dir", 0);
      row.fillSkip = GsxJsonGetString(sig, "fill_skip", "");
      row.signalTs = bestTs;
      if(bestTs <= 0)
        {
         row.dirState = "COMPUTE";
         row.signalStale = false;
        }
      else
        {
         row.signalAgeSec = (int)(TimeCurrent() - bestTs);
         if(row.signalAgeSec > 60)
           {
            row.dirState = "STALE";
            row.signalStale = true;
           }
         else if(row.direction == 0)
           {
            row.dirState = "FLAT";
            row.signalStale = false;
           }
         else
           {
            row.dirState = "LIVE";
            row.signalStale = false;
           }
        }
     }
   else
     {
      // Never published — COMPUTE (not STALE). Fall back to last good DIR.
      int ld = GsxRosterLastDirGet(magic, sym);
      if(ld != 0)
        {
         row.direction = ld;
         row.histDir = true;
         row.dirState = "HIST";
         datetime lt = GsxRosterLastDirTime(magic, sym);
         if(lt > 0)
            row.signalAgeSec = (int)(TimeCurrent() - lt);
         row.signalStale = false;
        }
      else
        {
         row.dirState = "COMPUTE";
         row.signalStale = false;
        }
     }
  }

//+------------------------------------------------------------------+
string GsxMsSnapshotFingerprint(const GsxMsSnapshot &snap)
  {
   string f = StringFormat("%I64d|%d|%d|%d|%d|%d|%d|%.0f|%d|%d|%.2f|%d|%.0f|%d|%s|%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%.2f|%.2f|%.1f|%s|%.1f|%.2f|%d|%d|%d|%.2f|%d|",
                           snap.magic, snap.own ? 1 : 0, snap.run ? 1 : 0,
                           snap.svcAlive ? 1 : 0,
                           snap.hbFresh ? 1 : 0,
                           snap.ignoreSpread ? 1 : 0,
                           snap.autoLot ? 1 : 0,
                           snap.eqGuardPct,
                           snap.fleetActive, snap.fleetTarget, snap.fleetPl,
                           snap.positions, snap.rosterSeq, snap.page,
                           snap.propStatus, snap.tgStatus, snap.eventMode,
                           ArraySize(snap.rows),
                           snap.pracBand, snap.pracCost, snap.pracStyle,
                           snap.flipWait ? 1 : 0,
                           snap.scoutLink ? 1 : 0,
                           snap.scoutOn ? 1 : 0,
                           snap.deskTf,
                           snap.deskTfFromChart ? 1 : 0,
                           snap.accountEquity,
                           snap.accountBalance,
                           snap.accountDdPct,
                           snap.eventLine,
                           snap.propPeakDdPct,
                           snap.propDayRealized,
                           snap.propTradesToday,
                           snap.sessionWins,
                           snap.sessionLosses,
                           snap.sessionNetPl,
                           snap.continuousFleet ? 1 : 0);
   int n = ArraySize(snap.rows);
   int lim = MathMin(n, 40);
   for(int i = 0; i < lim; i++)
     {
      f += StringFormat("%s:%d:%s:%d:%.1f:%d:%d:%d:%s|",
                        snap.rows[i].symbol,
                        snap.rows[i].direction,
                        snap.rows[i].dirState,
                        snap.rows[i].pairState,
                        snap.rows[i].floatingPl,
                        snap.rows[i].signalStale ? 1 : 0,
                        snap.rows[i].followDir,
                        snap.rows[i].signalAgeSec,
                        snap.rows[i].fillSkip);
     }
   f += IntegerToString(snap.drillSecLeft);
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
   out.hbFresh      = GsxBusHeartbeatFresh(5);
   out.svcAlive     = (out.own && out.hbFresh);
   out.ignoreSpread = GsxRosterSpreadIgnGet(magic, false);
   out.autoLot      = GsxRosterAutoLotGet(magic, false);
   out.eqGuardPct   = GsxRosterEqGuardGet(magic, 0.0);
   out.drillSecLeft = GsxRosterDrillSecGet(magic);
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
   out.propPeakDdPct    = 0.0;
   out.propDayRealized  = 0.0;
   out.propWeekRealized = 0.0;
   out.propTradesToday  = 0;
   out.propMaxTrades    = 0;
   out.sessionWins      = 0;
   out.sessionLosses    = 0;
   out.sessionNetPl     = 0.0;
   out.continuousFleet  = false;

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

   // One positions walk for all roster rows
   string plSyms[];
   double plVals[];
   GsxMsBuildFloatingPlMap(magic, plSyms, plVals);

   out.countFx = 0;
   out.countCmd = 0;
   out.countCr = 0;

   for(int i = 0; i < nAll; i++)
     {
      double rowPl = GsxMsFloatingPlLookup(plSyms, plVals, names[i]);
      GsxMsFillRow(magic, names[i], grades, tid, out.allRows[i], rowPl, true);
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
   out.flipWait  = GsxRosterFlipWaitGet(magic, false);
   out.scoutLink = true;
   out.scoutOn   = GsxScoutRunGet(1, true);
   {
      string tfName = GsxRosterTimeframeVarName(magic);
      out.deskTfFromChart = GlobalVariableCheck(tfName);
      out.deskTf = (int)GsxRosterTimeframeGet(magic, PERIOD_M5);
   }
   out.accountEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   out.accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   out.accountDdPct   = GsxAccountDrawdownPct();
   GsxPracticeProfile prac;
   GsxPracticeBuild(out.pracBand, out.pracCost, out.pracStyle, prac);
   out.coachLine = GsxPracticeFormatCoachLine(prac);
   out.tipLine   = GsxPracticeFormatTipLine(prac);
  }

// Panel/Dashboard call after build to stamp live scout link chrome.
void GsxMsSnapshotApplyScout(GsxMsSnapshot &snap, const bool linkEnable, const int instanceId)
  {
   snap.scoutLink = linkEnable;
   snap.scoutOn   = GsxScoutRunGet(instanceId < 1 ? 1 : instanceId, true);
   snap.flipWait  = GsxRosterFlipWaitGet(snap.magic, snap.flipWait);
  }

#endif // GSX_ROSTER_VIEW_MODEL_MQH
//+------------------------------------------------------------------+
