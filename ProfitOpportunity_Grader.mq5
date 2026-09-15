//+------------------------------------------------------------------+
//|                                  ProfitOpportunity_Grader.mq5   |
//|  Scans FILE_COMMON connector bus and ranks entry + harvest ops    |
//+------------------------------------------------------------------+
#property service
#property copyright "Gocity Group - GSignalX"
#property version   "2.00"
#property description "Gsignalx Velocity 2.00 — Opportunity Grader ranks signals and harvest candidates."

#include <GSignalX/BusProtocol.mqh>
#include <GSignalX/BusIO.mqh>
#include <GSignalX/TerminalIdentity.mqh>
#include <GSignalX/SymbolCanon.mqh>
#include <GSignalX/OpportunityGrade.mqh>

input group "=== Grader ==="
input int    InpIntervalMs        = 2000;   // Scan interval (ms)
input int    InpHeartbeatTTLSec   = 15;     // Ignore terminals older than (sec)
input int    InpTopN              = 8;      // Max ranked entries per list
input int    InpSwingStartHour    = 12;     // Default swing window start (server)
input int    InpSwingEndHour      = 17;     // Default swing window end (server)
input bool   InpLogRanks          = true;   // Print ranks to Experts log
input int    InpLogEverySec       = 30;     // Log interval (sec)
input bool   InpVerboseLog        = false;

struct RankItem
  {
   string kind;
   string tid;
   string symbol_canon;
   double score;
   int    direction;
   double profit;
   string reasons;
  };

RankItem g_entries[];
RankItem g_harvests[];
datetime g_lastLog = 0;

void SortRanksDesc(RankItem &arr[])
  {
   int n = ArraySize(arr);
   for(int i = 0; i < n; i++)
      for(int j = i + 1; j < n; j++)
         if(arr[j].score > arr[i].score)
           {
            RankItem tmp = arr[i];
            arr[i] = arr[j];
            arr[j] = tmp;
           }
  }

void TrimTop(RankItem &arr[], const int topN)
  {
   int n = ArraySize(arr);
   if(n > topN)
      ArrayResize(arr, topN);
  }

bool HeartbeatFresh(const string tid, double &freeMargin, double &floating)
  {
   freeMargin = 0.0;
   floating = 0.0;
   string hb = GsxBusReadAllRetry(GsxBusHeartbeatPath(tid));
   if(hb == "" || !GsxJsonVersionOk(hb))
      return false;
   long ts = GsxJsonGetLong(hb, "ts", 0);
   if(ts <= 0)
      return false;
   if((long)TimeCurrent() - ts > InpHeartbeatTTLSec)
      return false;
   freeMargin = GsxJsonGetDouble(hb, "free_margin", 0.0);
   floating = GsxJsonGetDouble(hb, "equity", 0.0) - GsxJsonGetDouble(hb, "balance", 0.0);
   return true;
  }

void GradeSignalsForTid(const string tid, const double freeMargin, const double floating)
  {
   string files[];
   int n = GsxBusListSignals(tid, files);
   for(int i = 0; i < n; i++)
     {
      string j = GsxBusReadAllRetry(files[i]);
      if(j == "" || !GsxJsonVersionOk(j))
         continue;

      GsxEntryInputs ein;
      ein.direction     = (int)GsxJsonGetLong(j, "direction", 0);
      ein.bull          = (int)GsxJsonGetLong(j, "bull", 0);
      ein.bear          = (int)GsxJsonGetLong(j, "bear", 0);
      ein.min_agree     = (int)GsxJsonGetLong(j, "min_agree", 2);
      ein.in_session    = GsxJsonGetBool(j, "in_session", false);
      ein.weekend       = GsxJsonGetBool(j, "weekend", false);
      ein.friday_late   = GsxJsonGetBool(j, "friday_late", false);
      ein.swing_window  = GsxJsonGetBool(j, "swing_window",
                                         GsxInSwingWindow(TimeCurrent(), InpSwingStartHour, InpSwingEndHour));
      ein.spread_pt     = (int)GsxJsonGetLong(j, "spread_pt", 0);
      ein.max_spread_pt = (int)GsxJsonGetLong(j, "max_spread_pt", 40);
      ein.stale_tick    = GsxJsonGetBool(j, "stale_tick", false);
      ein.market_open   = GsxJsonGetBool(j, "market_open", false);

      GsxGradeResult gr = GsxGradeEntry(ein);
      if(gr.score <= 0.0)
         continue;

      int k = ArraySize(g_entries);
      ArrayResize(g_entries, k + 1);
      g_entries[k].kind = "entry";
      g_entries[k].tid = tid;
      g_entries[k].symbol_canon = GsxJsonGetString(j, "symbol_canon", GsxSymbolCanon(GsxJsonGetString(j, "symbol", "")));
      g_entries[k].score = gr.score;
      g_entries[k].direction = ein.direction;
      g_entries[k].profit = 0.0;
      g_entries[k].reasons = gr.reasons;
     }
  }

void GradeScouterForTid(const string tid, const double freeMargin, const double floating)
  {
   string j = GsxBusReadAllRetry(GsxBusScouterPath(tid));
   if(j == "" || !GsxJsonVersionOk(j))
      return;

   double accTarget = GsxJsonGetDouble(j, "acc_target", 0.0);
   double posTarget = GsxJsonGetDouble(j, "pos_target", 0.0);
   double symTarget = GsxJsonGetDouble(j, "sym_target", 0.0);
   int winStart = (int)GsxJsonGetLong(j, "window_start", 30);
   int winEnd = (int)GsxJsonGetLong(j, "window_end", 60);
   double accFloat = GsxJsonGetDouble(j, "floating", floating);

   // account-level harvest candidate
   if(accTarget > 0.0 && accFloat > 0.0)
     {
      GsxHarvestInputs hin;
      hin.profit = accFloat;
      hin.peak = GsxJsonGetDouble(j, "acc_peak", accFloat);
      hin.armed = GsxJsonGetBool(j, "acc_armed", false);
      hin.target = accTarget;
      hin.trail_give = accTarget * 0.15;
      hin.age_min = winStart;
      hin.window_start = winStart;
      hin.window_end = winEnd;
      hin.free_margin = freeMargin;
      hin.floating = accFloat;
      hin.spread_pt = 0;
      hin.in_session = true;
      GsxGradeResult gr = GsxGradeHarvest(hin);
      int k = ArraySize(g_harvests);
      ArrayResize(g_harvests, k + 1);
      g_harvests[k].kind = "harvest";
      g_harvests[k].tid = tid;
      g_harvests[k].symbol_canon = "ACCOUNT";
      g_harvests[k].score = gr.score;
      g_harvests[k].direction = 0;
      g_harvests[k].profit = accFloat;
      g_harvests[k].reasons = gr.reasons;
     }

   // per-symbol objects — naive split on "{\"symbol\""
   int searchFrom = 0;
   while(true)
     {
      int p = StringFind(j, "\"symbol\":\"", searchFrom);
      if(p < 0)
         break;
      string chunk = StringSubstr(j, p, 400);
      string sym = GsxJsonGetString(chunk, "symbol", "");
      string canon = GsxJsonGetString(chunk, "symbol_canon", GsxSymbolCanon(sym));
      double profit = GsxJsonGetDouble(chunk, "profit", 0.0);
      double peak = GsxJsonGetDouble(chunk, "peak", 0.0);
      bool armed = GsxJsonGetBool(chunk, "armed", false);
      int age = (int)GsxJsonGetLong(chunk, "age_min", 0);
      int spread = (int)GsxJsonGetLong(chunk, "spread_pt", 0);
      double target = (symTarget > 0.0 ? symTarget : posTarget);

      GsxHarvestInputs hin;
      hin.profit = profit;
      hin.peak = peak;
      hin.armed = armed;
      hin.target = (target > 0.0 ? target : 1.0);
      hin.trail_give = MathMax(1.0, peak * 0.3);
      hin.age_min = age;
      hin.window_start = winStart;
      hin.window_end = winEnd;
      hin.free_margin = freeMargin;
      hin.floating = accFloat;
      hin.spread_pt = spread;
      hin.in_session = true;

      GsxGradeResult gr = GsxGradeHarvest(hin);
      if(gr.score > 0.0)
        {
         int k = ArraySize(g_harvests);
         ArrayResize(g_harvests, k + 1);
         g_harvests[k].kind = "harvest";
         g_harvests[k].tid = tid;
         g_harvests[k].symbol_canon = canon;
         g_harvests[k].score = gr.score;
         g_harvests[k].direction = 0;
         g_harvests[k].profit = profit;
         g_harvests[k].reasons = gr.reasons;
        }

      searchFrom = p + 10;
     }
  }

string BuildGradesJson()
  {
   string tid = GsxMakeTid();
   string j = "{";
   j += GsxJsonKV_I("version", GSX_BUS_VERSION);
   j += GsxJsonKV_I("ts", (long)TimeCurrent());
   j += GsxJsonKV_S("grader_tid", tid);
   j += "\"entries\":[";
   for(int i = 0; i < ArraySize(g_entries); i++)
     {
      if(i > 0)
         j += ",";
      j += "{";
      j += GsxJsonKV_S("kind", "entry");
      j += GsxJsonKV_S("tid", g_entries[i].tid);
      j += GsxJsonKV_S("symbol_canon", g_entries[i].symbol_canon);
      j += GsxJsonKV_D("score", g_entries[i].score);
      j += GsxJsonKV_I("direction", g_entries[i].direction);
      j += GsxJsonKV_S("reasons", g_entries[i].reasons, false);
      j += "}";
     }
   j += "],\"harvests\":[";
   for(int i = 0; i < ArraySize(g_harvests); i++)
     {
      if(i > 0)
         j += ",";
      j += "{";
      j += GsxJsonKV_S("kind", "harvest");
      j += GsxJsonKV_S("tid", g_harvests[i].tid);
      j += GsxJsonKV_S("symbol_canon", g_harvests[i].symbol_canon);
      j += GsxJsonKV_D("score", g_harvests[i].score);
      j += GsxJsonKV_D("profit", g_harvests[i].profit);
      j += GsxJsonKV_S("reasons", g_harvests[i].reasons, false);
      j += "}";
     }
   j += "]}";
   return j;
  }

void RunGradeCycle()
  {
   ArrayResize(g_entries, 0);
   ArrayResize(g_harvests, 0);

   string tids[];
   int n = GsxBusListTerminalIds(tids);
   for(int i = 0; i < n; i++)
     {
      double freeMargin = 0.0, floating = 0.0;
      if(!HeartbeatFresh(tids[i], freeMargin, floating))
        {
         if(InpVerboseLog)
            PrintFormat("Grader: skip stale/missing heartbeat tid=%s", tids[i]);
         continue;
        }
      GradeSignalsForTid(tids[i], freeMargin, floating);
      GradeScouterForTid(tids[i], freeMargin, floating);
     }

   SortRanksDesc(g_entries);
   SortRanksDesc(g_harvests);
   TrimTop(g_entries, InpTopN);
   TrimTop(g_harvests, InpTopN);

   string body = BuildGradesJson();
   if(!GsxBusWriteAtomic(GsxBusGradesPath(), body))
     {
      Print("Grader: failed to write grades/latest.json err=", GetLastError());
      return;
     }

   if(InpLogRanks)
     {
      if(g_lastLog == 0 || TimeCurrent() - g_lastLog >= InpLogEverySec)
        {
         g_lastLog = TimeCurrent();
         PrintFormat("Grader: terminals_scanned=%d entries=%d harvests=%d",
                     n, ArraySize(g_entries), ArraySize(g_harvests));
         for(int i = 0; i < ArraySize(g_entries) && i < 3; i++)
            PrintFormat("  ENTRY  %.1f  %s  tid=%s  %s",
                        g_entries[i].score, g_entries[i].symbol_canon,
                        g_entries[i].tid, g_entries[i].reasons);
         for(int i = 0; i < ArraySize(g_harvests) && i < 3; i++)
            PrintFormat("  HARVEST %.1f  %s  tid=%s  pnl=%.2f  %s",
                        g_harvests[i].score, g_harvests[i].symbol_canon,
                        g_harvests[i].tid, g_harvests[i].profit, g_harvests[i].reasons);
        }
     }
  }

void OnStart()
  {
   int ms = (int)MathMax(500, InpIntervalMs);
   PrintFormat("ProfitOpportunity_Grader started | interval=%dms TTL=%ds topN=%d | tid=%s",
               ms, InpHeartbeatTTLSec, InpTopN, GsxMakeTid());

   while(!IsStopped())
     {
      RunGradeCycle();
      Sleep(ms);
     }

   Print("ProfitOpportunity_Grader stopped");
  }
//+------------------------------------------------------------------+
