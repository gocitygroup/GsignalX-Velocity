//+------------------------------------------------------------------+
//|                                              GSX_Bias_Test.mq5    |
//|  Unit test: chart-aligned day-outcome bias + FollowDir mapping.   |
//+------------------------------------------------------------------+
#property copyright "GocityGroup"
#property version   "2.18"
#property script_show_inputs

#include <GSignalX/Bias/DailyBias.mqh>
#include <GSignalX/Bias/BiasFollow.mqh>

int g_pass = 0;
int g_fail = 0;

void AssertTrue(const string name, const bool cond)
  {
   if(cond) { g_pass++; PrintFormat("PASS  %s", name); }
   else     { g_fail++; PrintFormat("FAIL  %s", name); }
  }

void AssertEqI(const string name, const long got, const long want)
  {
   AssertTrue(StringFormat("%s (got=%lld want=%lld)", name, got, want), got == want);
  }

void OnStart()
  {
   Print("========== GSX_Bias_Test ==========");

   // Pivot helpers still compile / behave (debug path)
   double p, r1, s1;
   GsxBiasPivotFromHLC(110.0, 100.0, 105.0, p, r1, s1);
   AssertTrue("pivot P≈105", MathAbs(p - 105.0) < 1e-9);

   GsxBiasLeg leg;
   // Red bar: O=110 C=102 H=110 L=100 → BEAR
   GsxBiasLegFromBarOutcome(110, 110, 100, 102, leg);
   AssertEqI("red bar → BEAR", leg.dir, GSX_BIAS_BEARISH);
   AssertTrue("red strength>0", leg.strength > 0);

   // Green bar: O=100 C=108 → BULL
   GsxBiasLegFromBarOutcome(100, 110, 100, 108, leg);
   AssertEqI("green bar → BULL", leg.dir, GSX_BIAS_BULLISH);

   // Doji: tiny body vs range → NEUT (5% of 10 = 0.5; body 0.2)
   GsxBiasLegFromBarOutcome(105.0, 110, 100, 105.2, leg);
   AssertEqI("doji → NEUT", leg.dir, GSX_BIAS_NEUTRAL);

   // Daily float: live below open → BEAR (selling) regardless of “yesterday”
   GsxBiasSnapshot snap;
   GsxBiasComputeFromOhlc(1.1000, 1.1050, 1.0900, 1.0920,   // open 1.10, live 1.092 sell
                          1.0980, 1.1000, 1.0900, 1.0910,   // Pre red
                          1.0920, 1.0950, 1.0850, 1.0860,   // Third red
                          snap);
   AssertTrue("snap valid", snap.valid);
   AssertEqI("Daily live sell → BEAR", snap.daily.dir, GSX_BIAS_BEARISH);
   AssertEqI("Pre-D red → BEAR", snap.preDay.dir, GSX_BIAS_BEARISH);
   AssertEqI("Third-D red → BEAR", snap.thirdDay.dir, GSX_BIAS_BEARISH);

   // Daily buy float
   GsxBiasComputeFromOhlc(1.0900, 1.1000, 1.0880, 1.0980,
                          1.0800, 1.0900, 1.0750, 1.0880,   // Pre green
                          1.0700, 1.0800, 1.0650, 1.0780,   // Third green
                          snap);
   AssertEqI("Daily live buy → BULL", snap.daily.dir, GSX_BIAS_BULLISH);
   AssertEqI("Pre-D green → BULL", snap.preDay.dir, GSX_BIAS_BULLISH);
   AssertEqI("Third-D green → BULL", snap.thirdDay.dir, GSX_BIAS_BULLISH);

   // Hand-built cache shifts 1 and 3
   GsxBiasD1Cache cache;
   GsxBiasD1CacheClear(cache);
   ArrayResize(cache.rates, 5);
   // Index: 0=Daily forming, 1=Pre-D, 2=Third-D
   cache.rates[0].open = 1.1000; cache.rates[0].high = 1.1020; cache.rates[0].low = 1.0950; cache.rates[0].close = 1.0960;
   cache.rates[1].open = 1.0980; cache.rates[1].high = 1.1000; cache.rates[1].low = 1.0900; cache.rates[1].close = 1.0910; // Pre red
   cache.rates[2].open = 1.0920; cache.rates[2].high = 1.0950; cache.rates[2].low = 1.0850; cache.rates[2].close = 1.0860; // Third red
   cache.n = 3;
   cache.ready = true;
   cache.bar0 = D'2026.01.07';
   cache.symbol = "EURUSD";

   GsxBiasLeg pre, third;
   AssertTrue("hist pre from cache", GsxBiasHistFromCache(cache, 1, pre));
   AssertTrue("hist third from cache", GsxBiasHistFromCache(cache, 2, third));
   AssertEqI("cache pre BEAR", pre.dir, GSX_BIAS_BEARISH);
   AssertEqI("cache third BEAR", third.dir, GSX_BIAS_BEARISH);

   // Overall from cache: live below open → Daily BEAR
   GsxBiasSnapshot liveSnap;
   AssertTrue("overall from cache", GsxBiasOverallFromCache(cache, 1.0960, liveSnap));
   AssertEqI("forming Daily BEAR", liveSnap.daily.dir, GSX_BIAS_BEARISH);

   // FollowDir mapping — armed NEUT → WAIT (one-side gate); clear = AUTO via lane NONE
   AssertEqI("bull→BUY", GsxBiasToFollowDir(GSX_BIAS_BULLISH), GSX_FOLLOW_BUY);
   AssertEqI("bear→SELL", GsxBiasToFollowDir(GSX_BIAS_BEARISH), GSX_FOLLOW_SELL);
   AssertEqI("neut→WAIT", GsxBiasToFollowDir(GSX_BIAS_NEUTRAL), GSX_FOLLOW_WAIT);

   GsxBiasComputeFromOhlc(1.1000, 1.1050, 1.0900, 1.0920,
                          1.0980, 1.1000, 1.0900, 1.0910,
                          1.0920, 1.0950, 1.0850, 1.0860,
                          snap);
   AssertEqI("lane daily→SELL", GsxBiasFollowDirForLane(snap, GSX_BIAS_LANE_DAILY), GSX_FOLLOW_SELL);
   AssertEqI("lane pre→SELL", GsxBiasFollowDirForLane(snap, GSX_BIAS_LANE_PRE), GSX_FOLLOW_SELL);
   AssertEqI("lane third→SELL", GsxBiasFollowDirForLane(snap, GSX_BIAS_LANE_THIRD), GSX_FOLLOW_SELL);
   AssertEqI("lane none→AUTO", GsxBiasFollowDirForLane(snap, GSX_BIAS_LANE_NONE), GSX_FOLLOW_AUTO);

   // Doji Daily while armed → WAIT (not both sides)
   GsxBiasComputeFromOhlc(1.1000, 1.1050, 1.0950, 1.1002,
                          1.0980, 1.1000, 1.0900, 1.0910,
                          1.0920, 1.0950, 1.0850, 1.0860,
                          snap);
   AssertEqI("armed daily NEUT→WAIT", GsxBiasFollowDirForLane(snap, GSX_BIAS_LANE_DAILY),
             GSX_FOLLOW_WAIT);
   AssertEqI("packed daily dir helper",
             GsxBiasDirFromPacked(GSX_BIAS_LANE_DAILY, -1, 1, 1), GSX_BIAS_BEARISH);

   int d = 0, s = 0;
   GsxBiasUnpack((double)GsxBiasPack(GSX_BIAS_BEARISH, 55), d, s);
   AssertEqI("pack bear dir", d, GSX_BIAS_BEARISH);
   AssertEqI("pack bear str", s, 55);

   AssertTrue("label daily", GsxBiasLaneLabel(GSX_BIAS_LANE_DAILY) == "Daily");
   AssertTrue("label signal", GsxBiasLaneLabel(GSX_BIAS_LANE_NONE) == "Signal");

   PrintFormat("========== GSX_Bias_Test done: pass=%d fail=%d ==========", g_pass, g_fail);
   if(g_fail > 0)
      Alert(StringFormat("GSX_Bias_Test FAILED (%d)", g_fail));
  }
//+------------------------------------------------------------------+
