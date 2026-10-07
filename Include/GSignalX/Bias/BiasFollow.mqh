//+------------------------------------------------------------------+
//|                                                 BiasFollow.mqh    |
//|  Bias lane → FollowDir (desk-wide / chart-local).                 |
//|  While armed: live lane dir drives one-sided entries (no EMA).    |
//|  Never closes positions. Signal clear → AUTO (both sides).        |
//+------------------------------------------------------------------+
#ifndef GSX_BIAS_FOLLOW_MQH
#define GSX_BIAS_FOLLOW_MQH

#include <GSignalX/Bias/DailyBias.mqh>
#include <GSignalX/RosterStore.mqh>
#include <GSignalX/FollowGate.mqh>
#include <GSignalX/SymbolCanon.mqh>

//+------------------------------------------------------------------+
string GsxBiasDeskLaneVarName(const long magic)
  {
   return("GSX_MS_BIASLANE_" + IntegerToString((int)magic));
  }

string GsxBiasChartLaneVarName(const long magic, const string symbol)
  {
   return(StringFormat("GSX_BIASLANE_%s_%d", symbol, (int)magic));
  }

// Packed snapshot: sign(dir)*1000 + strength (0..100) → decode later
string GsxBiasSnapVarName(const long magic, const string symbolCanon, const string tag)
  {
   return(StringFormat("GSX_MS_BIAS_%d_%s_%s", (int)magic, symbolCanon, tag));
  }

int GsxBiasPack(const int dir, const int strength)
  {
   int s = strength;
   if(s < 0) s = 0;
   if(s > 100) s = 100;
   if(dir > 0) return(1000 + s);
   if(dir < 0) return(-(1000 + s));
   return(0);
  }

void GsxBiasUnpack(const double packed, int &dir, int &strength)
  {
   dir = GSX_BIAS_NEUTRAL;
   strength = 0;
   int v = (int)packed;
   if(v == 0)
      return;
   if(v > 0)
     {
      dir = GSX_BIAS_BULLISH;
      strength = v - 1000;
     }
   else
     {
      dir = GSX_BIAS_BEARISH;
      strength = (-v) - 1000;
     }
   if(strength < 0) strength = 0;
   if(strength > 100) strength = 100;
  }

void GsxBiasGvSetIfChanged(const string name, const double value)
  {
   if(GlobalVariableCheck(name) && GlobalVariableGet(name) == value)
      return;
   GlobalVariableSet(name, value);
  }

int GsxBiasDeskLaneGet(const long magic, const int defaultLane = GSX_BIAS_LANE_NONE)
  {
   string name = GsxBiasDeskLaneVarName(magic);
   if(!GlobalVariableCheck(name))
      return(GsxBiasLaneNormalize(defaultLane));
   return(GsxBiasLaneNormalize((int)GlobalVariableGet(name)));
  }

void GsxBiasDeskLaneSet(const long magic, const int lane)
  {
   GsxBiasGvSetIfChanged(GsxBiasDeskLaneVarName(magic),
                         (double)GsxBiasLaneNormalize(lane));
  }

int GsxBiasChartLaneGet(const long magic, const string symbol, const int defaultLane = GSX_BIAS_LANE_NONE)
  {
   string name = GsxBiasChartLaneVarName(magic, symbol);
   if(!GlobalVariableCheck(name))
      return(GsxBiasLaneNormalize(defaultLane));
   return(GsxBiasLaneNormalize((int)GlobalVariableGet(name)));
  }

void GsxBiasChartLaneSet(const long magic, const string symbol, const int lane)
  {
   GsxBiasGvSetIfChanged(GsxBiasChartLaneVarName(magic, symbol),
                         (double)GsxBiasLaneNormalize(lane));
  }

void GsxBiasSnapWrite(const long magic, const string symbol, const GsxBiasSnapshot &snap)
  {
   string canon = GsxSymbolCanon(symbol);
   if(canon == "" || !snap.valid)
      return;
   GsxBiasGvSetIfChanged(GsxBiasSnapVarName(magic, canon, "D"),
                         (double)GsxBiasPack(snap.daily.dir, snap.daily.strength));
   GsxBiasGvSetIfChanged(GsxBiasSnapVarName(magic, canon, "P"),
                         (double)GsxBiasPack(snap.preDay.dir, snap.preDay.strength));
   GsxBiasGvSetIfChanged(GsxBiasSnapVarName(magic, canon, "T"),
                         (double)GsxBiasPack(snap.thirdDay.dir, snap.thirdDay.strength));
  }

bool GsxBiasSnapRead(const long magic, const string symbol,
                     int &dailyDir, int &dailyStr,
                     int &preDir, int &preStr,
                     int &thirdDir, int &thirdStr)
  {
   dailyDir = preDir = thirdDir = GSX_BIAS_NEUTRAL;
   dailyStr = preStr = thirdStr = 0;
   string canon = GsxSymbolCanon(symbol);
   if(canon == "")
      return(false);
   string d = GsxBiasSnapVarName(magic, canon, "D");
   string p = GsxBiasSnapVarName(magic, canon, "P");
   string t = GsxBiasSnapVarName(magic, canon, "T");
   bool any = false;
   if(GlobalVariableCheck(d))
     {
      GsxBiasUnpack(GlobalVariableGet(d), dailyDir, dailyStr);
      any = true;
     }
   if(GlobalVariableCheck(p))
     {
      GsxBiasUnpack(GlobalVariableGet(p), preDir, preStr);
      any = true;
     }
  if(GlobalVariableCheck(t))
     {
      GsxBiasUnpack(GlobalVariableGet(t), thirdDir, thirdStr);
      any = true;
     }
   return(any);
  }

// Shared UI cell text (desk + chart).
string GsxBiasCellTxt(const int dir, const int strength)
  {
   string d = GsxBiasDirLabel(dir);
   if(dir == 0)
      return(d);
   if(strength > 0)
      return(d + " " + IntegerToString(strength));
   return(d);
  }

// Map bias dir → FollowDir. Armed NEUT → WAIT (block); clear uses AUTO separately.
int GsxBiasToFollowDir(const int biasDir)
  {
   if(biasDir > 0) return(GSX_FOLLOW_BUY);
   if(biasDir < 0) return(GSX_FOLLOW_SELL);
   return(GSX_FOLLOW_WAIT);
  }

int GsxBiasFollowDirForLane(const GsxBiasSnapshot &snap, const int lane)
  {
   if(GsxBiasLaneNormalize(lane) == GSX_BIAS_LANE_NONE)
      return(GSX_FOLLOW_AUTO);
   if(!snap.valid)
      return(GSX_FOLLOW_WAIT);
   return(GsxBiasToFollowDir(GsxBiasDirForLane(snap, lane)));
  }

int GsxBiasDirFromPacked(const int lane,
                         const int dailyDir, const int preDir, const int thirdDir)
  {
   int L = GsxBiasLaneNormalize(lane);
   if(L == GSX_BIAS_LANE_DAILY) return(dailyDir);
   if(L == GSX_BIAS_LANE_PRE)   return(preDir);
   if(L == GSX_BIAS_LANE_THIRD) return(thirdDir);
   return(GSX_BIAS_NEUTRAL);
  }

// Live one-sided FollowDir while a bias lane is armed.
// useChartLane=true → chart arm; false → desk arm.
// Lane NONE → manual roster FollowDir (AUTO/BUY/SELL/WAIT).
int GsxBiasEffectiveFollowDir(const long magic, const string symbol,
                              const bool useChartLane,
                              const bool syncFollowDirGv = true)
  {
   if(symbol == "")
      return(GSX_FOLLOW_AUTO);

   int lane = (useChartLane
               ? GsxBiasChartLaneGet(magic, symbol, GSX_BIAS_LANE_NONE)
               : GsxBiasDeskLaneGet(magic, GSX_BIAS_LANE_NONE));
   if(lane == GSX_BIAS_LANE_NONE)
      return(GsxRosterFollowDirGet(magic, symbol, GSX_FOLLOW_AUTO));

   int dailyDir = 0, dailyStr = 0, preDir = 0, preStr = 0, thirdDir = 0, thirdStr = 0;
   bool have = GsxBiasSnapRead(magic, symbol, dailyDir, dailyStr,
                               preDir, preStr, thirdDir, thirdStr);
   int biasDir = GSX_BIAS_NEUTRAL;
   if(have)
      biasDir = GsxBiasDirFromPacked(lane, dailyDir, preDir, thirdDir);
   else
     {
      GsxBiasD1Cache cache;
      GsxBiasD1CacheClear(cache);
      GsxBiasSnapshot snap;
      if(GsxBiasCompute(symbol, cache, snap, false) && snap.valid)
        {
         GsxBiasSnapWrite(magic, symbol, snap);
         biasDir = GsxBiasDirForLane(snap, lane);
        }
      else
        {
         // Armed but no D1 data → block entries
         if(syncFollowDirGv)
            GsxRosterFollowDirSetIfChanged(magic, symbol, GSX_FOLLOW_WAIT);
         return(GSX_FOLLOW_WAIT);
        }
     }

   int fd = GsxBiasToFollowDir(biasDir);
   if(syncFollowDirGv)
      GsxRosterFollowDirSetIfChanged(magic, symbol, fd);
   return(fd);
  }

// Re-seed one symbol from live bias when desk lane is armed (e.g. START).
bool GsxBiasReapplySymbolDesk(const long magic, const string symbol)
  {
   int lane = GsxBiasDeskLaneGet(magic, GSX_BIAS_LANE_NONE);
   if(lane == GSX_BIAS_LANE_NONE || symbol == "")
      return(false);
   GsxBiasEffectiveFollowDir(magic, symbol, false, true);
   return(true);
  }

// Desk-wide arm lane; each symbol FollowDir from that symbol's bias.
// Caller supplies fresh snapshots parallel to roster (same length).
int GsxBiasApplyLaneDesk(const long magic, const int lane,
                         const string &roster[], const GsxBiasSnapshot &snaps[])
  {
   int L = GsxBiasLaneNormalize(lane);
   GsxBiasDeskLaneSet(magic, L);
   int n = ArraySize(roster);
   int applied = 0;
   for(int i = 0; i < n; i++)
     {
      if(roster[i] == "")
         continue;
      int fd = GSX_FOLLOW_AUTO;
      if(L != GSX_BIAS_LANE_NONE)
        {
         if(i < ArraySize(snaps) && snaps[i].valid)
            fd = GsxBiasFollowDirForLane(snaps[i], L);
         else
            fd = GSX_FOLLOW_WAIT;
        }
      GsxRosterFollowDirSetIfChanged(magic, roster[i], fd);
      applied++;
     }
   return(applied);
  }

// Convenience: compute each symbol then apply (desk hosts without Core snaps).
int GsxBiasApplyLaneDeskLive(const long magic, const int lane, const string &roster[])
  {
   int L = GsxBiasLaneNormalize(lane);
   int n = ArraySize(roster);
   // Signal clear: no CopyRates — just AUTO FollowDir
   if(L == GSX_BIAS_LANE_NONE)
     {
      GsxBiasDeskLaneSet(magic, GSX_BIAS_LANE_NONE);
      for(int i = 0; i < n; i++)
        {
         if(roster[i] == "")
            continue;
         GsxRosterFollowDirSetIfChanged(magic, roster[i], GSX_FOLLOW_AUTO);
        }
      return(n);
     }

   GsxBiasSnapshot snaps[];
   ArrayResize(snaps, n);
   GsxBiasD1Cache cache;
   for(int i = 0; i < n; i++)
     {
      GsxBiasSnapshotClear(snaps[i]);
      if(roster[i] == "")
         continue;
      // Keep rates cache warm across symbols of same apply when possible
      if(cache.symbol != roster[i])
         GsxBiasD1CacheClear(cache);
      GsxBiasCompute(roster[i], cache, snaps[i], false);
      if(snaps[i].valid)
         GsxBiasSnapWrite(magic, roster[i], snaps[i]);
     }
   return(GsxBiasApplyLaneDesk(magic, lane, roster, snaps));
  }

// Chart arm: this symbol only.
bool GsxBiasApplyLaneChart(const long magic, const string symbol, const int lane,
                           const GsxBiasSnapshot &snap,
                           const bool alreadySnapWritten = false)
  {
   if(symbol == "")
      return(false);
   int L = GsxBiasLaneNormalize(lane);
   GsxBiasChartLaneSet(magic, symbol, L);
   int fd = GSX_FOLLOW_AUTO;
   if(L != GSX_BIAS_LANE_NONE)
      fd = (snap.valid ? GsxBiasFollowDirForLane(snap, L) : GSX_FOLLOW_WAIT);
   GsxRosterFollowDirSetIfChanged(magic, symbol, fd);
   if(snap.valid && !alreadySnapWritten)
      GsxBiasSnapWrite(magic, symbol, snap);
   return(true);
  }

bool GsxBiasApplyLaneChartLive(const long magic, const string symbol, const int lane)
  {
   int L = GsxBiasLaneNormalize(lane);
   if(L == GSX_BIAS_LANE_NONE)
     {
      GsxBiasChartLaneSet(magic, symbol, GSX_BIAS_LANE_NONE);
      GsxRosterFollowDirSetIfChanged(magic, symbol, GSX_FOLLOW_AUTO);
      return(true);
     }
   GsxBiasD1Cache cache;
   GsxBiasD1CacheClear(cache);
   GsxBiasSnapshot snap;
   if(!GsxBiasCompute(symbol, cache, snap, false))
     {
      GsxBiasChartLaneSet(magic, symbol, L);
      GsxRosterFollowDirSetIfChanged(magic, symbol, GSX_FOLLOW_WAIT);
      return(false);
     }
   return(GsxBiasApplyLaneChart(magic, symbol, lane, snap, false));
  }

void GsxBiasClearLaneDesk(const long magic, const string &roster[])
  {
   GsxBiasApplyLaneDeskLive(magic, GSX_BIAS_LANE_NONE, roster);
  }

void GsxBiasClearLaneChart(const long magic, const string symbol)
  {
   GsxBiasApplyLaneChartLive(magic, symbol, GSX_BIAS_LANE_NONE);
  }

#endif // GSX_BIAS_FOLLOW_MQH
//+------------------------------------------------------------------+
