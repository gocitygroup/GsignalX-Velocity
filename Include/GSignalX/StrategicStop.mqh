//+------------------------------------------------------------------+
//|                                            StrategicStop.mqh      |
//|  DRY catastrophe broker-SL engine: signal ATR + D1 floor +        |
//|  class mults + range/spread floors + attach-time jitter.          |
//|  Lot sizing stays on signal ATR; this module only sizes ticket SL.|
//+------------------------------------------------------------------+
#ifndef GSX_STRATEGIC_STOP_MQH
#define GSX_STRATEGIC_STOP_MQH

#include <GSignalX/CandleMetrics.mqh>
#include <GSignalX/SymbolClass.mqh>
#include <GSignalX/MarketGates.mqh>
#include <GSignalX/BusProtocol.mqh>
#include <GSignalX/BusIO.mqh>
#include <GSignalX/TerminalIdentity.mqh>

#define GSX_STRAT_PAYLOAD_SEP "|"
#define GSX_STRAT_SPREAD_K    3.0   // spread floor = k × current spread pts

//+------------------------------------------------------------------+
struct GsxStratStopParams
  {
   bool              enable;
   double            strategicMult;      // × signal ATR
   bool              useDailyAtr;
   int               dailyAtrLen;
   double            dailyFloorMult;     // × D1 ATR
   double            classMultFx;
   double            classMultCmd;
   double            classMultCr;
   int               rangeBars;          // H1 avg range bars
   double            rangeMult;
   int               spreadBaseLimit;    // for class-aware spread ceiling (0=use live spread only)
   double            hardCapMult;        // max vs signal ATR × class
   bool              jitterEnable;
   double            jitterPct;          // ±% of base
   int               microPts;           // max micro point offset
   long              magic;              // seed / persist key
  };

struct GsxStratStopDecision
  {
   bool              ok;
   ENUM_GSX_SYM_CLASS cls;
   double            atrSignal;
   double            atrD1;              // price units
   double            classMult;
   double            signalDist;
   double            d1Floor;
   double            rangeFloor;
   double            spreadFloor;
   double            brokerMin;
   double            baseDist;
   double            hardCap;
   double            jitterFrac;         // applied fraction (−pct..+pct)/100
   double            microOffset;        // price units
   double            finalDist;
   string            reason;             // short human summary
  };

//+------------------------------------------------------------------+
void GsxStratStopParamsClear(GsxStratStopParams &p)
  {
   p.enable = false;
   p.strategicMult = 4.0;
   p.useDailyAtr = true;
   p.dailyAtrLen = 14;
   p.dailyFloorMult = 0.20;
   p.classMultFx = 1.0;
   p.classMultCmd = 1.35;
   p.classMultCr = 1.75;
   p.rangeBars = 6;
   p.rangeMult = 1.0;
   p.spreadBaseLimit = 50;
   p.hardCapMult = 12.0;
   p.jitterEnable = true;
   p.jitterPct = 8.0;
   p.microPts = 5;
   p.magic = 0;
  }

void GsxStratStopDecisionClear(GsxStratStopDecision &d)
  {
   d.ok = false;
   d.cls = GSX_CLASS_OTHER;
   d.atrSignal = 0.0;
   d.atrD1 = 0.0;
   d.classMult = 1.0;
   d.signalDist = 0.0;
   d.d1Floor = 0.0;
   d.rangeFloor = 0.0;
   d.spreadFloor = 0.0;
   d.brokerMin = 0.0;
   d.baseDist = 0.0;
   d.hardCap = 0.0;
   d.jitterFrac = 0.0;
   d.microOffset = 0.0;
   d.finalDist = 0.0;
   d.reason = "";
  }

//+------------------------------------------------------------------+
double GsxStratStopBrokerMin(const string symbol)
  {
   double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return(0.0);
   double stops  = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL)  * point;
   double freeze = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;
   return(MathMax(stops, freeze));
  }

double GsxStratStopClassMult(const ENUM_GSX_SYM_CLASS cls, const GsxStratStopParams &p)
  {
   if(cls == GSX_CLASS_CRYPTO)
      return((p.classMultCr > 0.0) ? p.classMultCr : 1.75);
   if(cls == GSX_CLASS_COMMODITY)
      return((p.classMultCmd > 0.0) ? p.classMultCmd : 1.35);
   if(cls == GSX_CLASS_FOREX)
      return((p.classMultFx > 0.0) ? p.classMultFx : 1.0);
   return((p.classMultFx > 0.0) ? p.classMultFx : 1.0);
  }

// Deterministic U[0,1) from symbol|bar|magic — stable within the current M1 bar.
double GsxStratStopUnitRand(const string symbol, const long magic)
  {
   datetime bar = iTime(symbol, PERIOD_M1, 0);
   if(bar == 0)
      bar = TimeCurrent();
   string key = StringFormat("%s|%I64d|%I64d", symbol, (long)bar, magic);
   uint h = 2166136261u;
   int n = StringLen(key);
   for(int i = 0; i < n; i++)
     {
      h ^= (uint)StringGetCharacter(key, i);
      h *= 16777619u;
     }
   return((double)(h % 1000000u) / 1000000.0);
  }

//+------------------------------------------------------------------+
//| Core compute: base distance before jitter. Returns finalDist set  |
//| to base; call ApplyJitter to randomize.                           |
//+------------------------------------------------------------------+
bool GsxStratStopCompute(const string symbol,
                         const double atrSignal,
                         const GsxStratStopParams &p,
                         GsxStratStopDecision &out)
  {
   GsxStratStopDecisionClear(out);
   if(!p.enable || atrSignal <= 0.0 || symbol == "")
      return(false);

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return(false);

   out.cls = GsxSymbolClass(symbol);
   out.classMult = GsxStratStopClassMult(out.cls, p);
   out.atrSignal = atrSignal;
   out.brokerMin = GsxStratStopBrokerMin(symbol);

   out.signalDist = atrSignal * p.strategicMult * out.classMult;

   if(p.useDailyAtr && p.dailyAtrLen > 0 && p.dailyFloorMult > 0.0)
     {
      double atrD1Pts = GsxAtrPoints(symbol, PERIOD_D1, p.dailyAtrLen);
      out.atrD1 = atrD1Pts * point;
      if(out.atrD1 > 0.0)
         out.d1Floor = out.atrD1 * p.dailyFloorMult * out.classMult;
     }

   if(p.rangeBars > 0 && p.rangeMult > 0.0)
     {
      double avgPts = GsxAvgClosedRangePts(symbol, PERIOD_H1, p.rangeBars);
      if(avgPts > 0.0)
         out.rangeFloor = avgPts * point * p.rangeMult;
     }

   long liveSpread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   double spreadPts = (double)liveSpread;
   int effCeil = GsxEffectiveMaxSpreadPt(symbol, (p.spreadBaseLimit > 0 ? p.spreadBaseLimit : 50));
   if(effCeil > 0)
      spreadPts = MathMax(spreadPts, (double)effCeil * 0.25); // light class-aware lift
   if(spreadPts > 0.0)
      out.spreadFloor = spreadPts * point * GSX_STRAT_SPREAD_K;

   out.baseDist = out.signalDist;
   if(out.d1Floor > out.baseDist)
      out.baseDist = out.d1Floor;
   if(out.rangeFloor > out.baseDist)
      out.baseDist = out.rangeFloor;
   if(out.spreadFloor > out.baseDist)
      out.baseDist = out.spreadFloor;
   if(out.brokerMin > out.baseDist)
      out.baseDist = out.brokerMin;

   out.hardCap = 0.0;
   if(p.hardCapMult > 0.0)
      out.hardCap = atrSignal * p.hardCapMult * out.classMult;
   if(out.hardCap > 0.0 && out.baseDist > out.hardCap)
      out.baseDist = out.hardCap;

   out.finalDist = out.baseDist;
   out.ok = (out.finalDist > 0.0);
   out.reason = StringFormat("class=%s atrSig=%.5f atrD1=%.5f base=%.5f",
                             GsxSymClassLabel(out.cls), out.atrSignal, out.atrD1, out.baseDist);
   return(out.ok);
  }

// Attach-time jitter only. Mutates decision.finalDist / jitterFrac / microOffset / reason.
void GsxStratStopApplyJitter(const string symbol,
                             const GsxStratStopParams &p,
                             GsxStratStopDecision &d)
  {
   if(!d.ok || d.baseDist <= 0.0)
      return;

   double dist = d.baseDist;
   d.jitterFrac = 0.0;
   d.microOffset = 0.0;

   if(p.jitterEnable && p.jitterPct > 0.0)
     {
      double u = GsxStratStopUnitRand(symbol, p.magic);
      // map u∈[0,1) → [−pct, +pct]
      double pct = MathMax(0.0, p.jitterPct);
      d.jitterFrac = ((u * 2.0) - 1.0) * (pct / 100.0);
      dist = d.baseDist * (1.0 + d.jitterFrac);
     }

   if(p.jitterEnable && p.microPts > 0)
     {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double u2 = GsxStratStopUnitRand(symbol + "|m", p.magic);
      int pts = 1 + (int)MathFloor(u2 * (double)MathMax(1, p.microPts));
      if(pts > p.microPts)
         pts = p.microPts;
      d.microOffset = (double)pts * point;
      dist += d.microOffset;
     }

   if(d.brokerMin > 0.0 && dist < d.brokerMin)
      dist = d.brokerMin;
   if(d.hardCap > 0.0 && dist > d.hardCap)
      dist = d.hardCap;

   d.finalDist = dist;
   d.reason = StringFormat("class=%s atrSig=%.5f atrD1=%.5f base=%.5f jitter=%.1f%% micro=%.5f final=%.5f",
                           GsxSymClassLabel(d.cls), d.atrSignal, d.atrD1, d.baseDist,
                           d.jitterFrac * 100.0, d.microOffset, d.finalDist);
  }

// Full path: compute + jitter.
bool GsxStratStopBuild(const string symbol,
                       const double atrSignal,
                       const GsxStratStopParams &p,
                       GsxStratStopDecision &out)
  {
   if(!GsxStratStopCompute(symbol, atrSignal, p, out))
      return(false);
   GsxStratStopApplyJitter(symbol, p, out);
   return(out.ok && out.finalDist > 0.0);
  }

//+------------------------------------------------------------------+
//| Validate / widen SL vs live market (stops ∪ freeze).              |
//| Returns corrected SL price (0 if no SL).                          |
//+------------------------------------------------------------------+
double GsxStratStopValidateVsMarket(const string symbol,
                                    const int dir,
                                    const double refPrice,
                                    double sl)
  {
   if(sl <= 0.0 || refPrice <= 0.0 || dir == 0)
      return(sl);

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double minD = GsxStratStopBrokerMin(symbol);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(minD <= 0.0)
      minD = point;

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double market = (dir > 0) ? bid : ask; // SL checked vs exit side
   if(market <= 0.0)
      market = refPrice;

   if(dir > 0)
     {
      // buy: SL must be <= market - minD
      double maxSl = market - minD;
      if(sl > maxSl)
         sl = maxSl;
      if(refPrice - sl < minD)
         sl = refPrice - minD;
     }
   else
     {
      double minSl = market + minD;
      if(sl < minSl)
         sl = minSl;
      if(sl - refPrice < minD)
         sl = refPrice + minD;
     }

   if(sl <= 0.0)
      return(0.0);
   return(NormalizeDouble(sl, digits));
  }

// Build SL price from entry + decision.
double GsxStratStopPrice(const int dir, const double entry, const double dist, const int digits)
  {
   if(dist <= 0.0 || entry <= 0.0 || dir == 0)
      return(0.0);
   double sl = (dir > 0) ? (entry - dist) : (entry + dist);
   return(NormalizeDouble(sl, digits));
  }

//+------------------------------------------------------------------+
//| Persist / load decision for CLOSE notifications (ticket GV).      |
//| GV stores finalDist; companion string file holds full payload.    |
//+------------------------------------------------------------------+
string GsxStratStopGvName(const long magic, const ulong ticket)
  {
   return(StringFormat("GSX_SSL_%I64d_%I64u", magic, ticket));
  }

string GsxStratStopMetaRel(const long magic, const ulong ticket)
  {
   return(StringFormat("%s\\stops\\%I64d_%I64u.ssl",
                       GsxBusTerminalDir(GsxMakeTid()), magic, ticket));
  }

string GsxStratStopEncode(const GsxStratStopDecision &d)
  {
   // class|atrSig|atrD1|base|final|jitterPct|micro|reason
   return(StringFormat("%s%s%.8f%s%.8f%s%.8f%s%.8f%s%.4f%s%.8f%s%s",
                       GsxSymClassLabel(d.cls), GSX_STRAT_PAYLOAD_SEP,
                       d.atrSignal, GSX_STRAT_PAYLOAD_SEP,
                       d.atrD1, GSX_STRAT_PAYLOAD_SEP,
                       d.baseDist, GSX_STRAT_PAYLOAD_SEP,
                       d.finalDist, GSX_STRAT_PAYLOAD_SEP,
                       d.jitterFrac * 100.0, GSX_STRAT_PAYLOAD_SEP,
                       d.microOffset, GSX_STRAT_PAYLOAD_SEP,
                       d.reason));
  }

bool GsxStratStopDecode(const string raw, GsxStratStopDecision &d)
  {
   GsxStratStopDecisionClear(d);
   string parts[];
   int n = StringSplit(raw, StringGetCharacter(GSX_STRAT_PAYLOAD_SEP, 0), parts);
   if(n < 5)
      return(false);
   string lab = parts[0];
   if(lab == "CR")
      d.cls = GSX_CLASS_CRYPTO;
   else if(lab == "CMD")
      d.cls = GSX_CLASS_COMMODITY;
   else if(lab == "FX")
      d.cls = GSX_CLASS_FOREX;
   else
      d.cls = GSX_CLASS_OTHER;
   d.atrSignal = StringToDouble(parts[1]);
   d.atrD1 = StringToDouble(parts[2]);
   d.baseDist = StringToDouble(parts[3]);
   d.finalDist = StringToDouble(parts[4]);
   if(n >= 6)
      d.jitterFrac = StringToDouble(parts[5]) / 100.0;
   if(n >= 7)
      d.microOffset = StringToDouble(parts[6]);
   if(n >= 8)
     {
      d.reason = parts[7];
      for(int i = 8; i < n; i++)
         d.reason += GSX_STRAT_PAYLOAD_SEP + parts[i];
     }
   d.ok = (d.finalDist > 0.0);
   return(d.ok);
  }

void GsxStratStopPersist(const ulong ticket, const long magic, const GsxStratStopDecision &d)
  {
   if(ticket == 0 || !d.ok)
      return;
   GlobalVariableSet(GsxStratStopGvName(magic, ticket), d.finalDist);

   string rel = GsxStratStopMetaRel(magic, ticket);
   GsxEnsureFolderTree(rel);
   int h = FileOpen(rel, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_REWRITE);
   if(h == INVALID_HANDLE)
      return;
   FileWriteString(h, GsxStratStopEncode(d));
   FileClose(h);
  }

bool GsxStratStopLoad(const ulong ticket, const long magic, GsxStratStopDecision &out)
  {
   GsxStratStopDecisionClear(out);
   string rel = GsxStratStopMetaRel(magic, ticket);
   bool hasFile = FileIsExist(rel, FILE_COMMON);
   if(hasFile)
     {
      int h = FileOpen(rel, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
      if(h != INVALID_HANDLE)
        {
         string raw = "";
         while(!FileIsEnding(h))
            raw += FileReadString(h);
         FileClose(h);
         StringTrimLeft(raw);
         StringTrimRight(raw);
         if(GsxStratStopDecode(raw, out))
            return(true);
        }
     }
   string gv = GsxStratStopGvName(magic, ticket);
   if(GlobalVariableCheck(gv))
     {
      out.finalDist = GlobalVariableGet(gv);
      out.baseDist = out.finalDist;
      out.ok = (out.finalDist > 0.0);
      out.reason = StringFormat("final=%.5f (gv-only)", out.finalDist);
      return(out.ok);
     }
   return(false);
  }

void GsxStratStopClear(const ulong ticket, const long magic)
  {
   string gv = GsxStratStopGvName(magic, ticket);
   if(GlobalVariableCheck(gv))
      GlobalVariableDel(gv);
   string rel = GsxStratStopMetaRel(magic, ticket);
   if(FileIsExist(rel, FILE_COMMON))
      FileDelete(rel, FILE_COMMON);
  }

// Pending-path: stash last decision by symbol until fill assigns a ticket.
string GsxStratStopPendGvName(const long magic, const string symbol)
  {
   return(StringFormat("GSX_SSLP_%I64d_%s", magic, GsxSymbolCanon(symbol)));
  }

string GsxStratStopPendMetaRel(const long magic, const string symbol)
  {
   return(StringFormat("%s\\stops\\pend_%I64d_%s.ssl",
                       GsxBusTerminalDir(GsxMakeTid()), magic, GsxSymbolCanon(symbol)));
  }

void GsxStratStopPersistPending(const long magic, const string symbol, const GsxStratStopDecision &d)
  {
   if(!d.ok || symbol == "")
      return;
   GlobalVariableSet(GsxStratStopPendGvName(magic, symbol), d.finalDist);
   string rel = GsxStratStopPendMetaRel(magic, symbol);
   GsxEnsureFolderTree(rel);
   int h = FileOpen(rel, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_REWRITE);
   if(h == INVALID_HANDLE)
      return;
   FileWriteString(h, GsxStratStopEncode(d));
   FileClose(h);
  }

bool GsxStratStopLoadPending(const long magic, const string symbol, GsxStratStopDecision &out)
  {
   GsxStratStopDecisionClear(out);
   string rel = GsxStratStopPendMetaRel(magic, symbol);
   if(FileIsExist(rel, FILE_COMMON))
     {
      int h = FileOpen(rel, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
      if(h != INVALID_HANDLE)
        {
         string raw = "";
         while(!FileIsEnding(h))
            raw += FileReadString(h);
         FileClose(h);
         StringTrimLeft(raw);
         StringTrimRight(raw);
         if(GsxStratStopDecode(raw, out))
            return(true);
        }
     }
   string gv = GsxStratStopPendGvName(magic, symbol);
   if(GlobalVariableCheck(gv))
     {
      out.finalDist = GlobalVariableGet(gv);
      out.baseDist = out.finalDist;
      out.ok = (out.finalDist > 0.0);
      return(out.ok);
     }
   return(false);
  }

void GsxStratStopClearPending(const long magic, const string symbol)
  {
   string gv = GsxStratStopPendGvName(magic, symbol);
   if(GlobalVariableCheck(gv))
      GlobalVariableDel(gv);
   string rel = GsxStratStopPendMetaRel(magic, symbol);
   if(FileIsExist(rel, FILE_COMMON))
      FileDelete(rel, FILE_COMMON);
  }

// Human detail for BROKER-SL notifications.
string GsxStratStopBrokerSlDetail(const GsxStratStopDecision &d, const double sl)
  {
   if(!d.ok && d.finalDist <= 0.0)
      return("BROKER-SL hit");
   return(StringFormat("BROKER-SL hit | %s SL=%.5f",
                       (d.reason != "" ? d.reason : "catastrophe"), sl));
  }

// Thin legacy wrapper: distance = strategicMult × atr floored to broker min (no class/D1).
double GsxStrategicStopDistanceLegacy(const string symbol,
                                      const double atr,
                                      const bool enable,
                                      const double mult)
  {
   if(!enable || atr <= 0.0)
      return(0.0);
   double d = mult * atr;
   double minD = GsxStratStopBrokerMin(symbol);
   if(d < minD)
      d = minD;
   return(d);
  }

#endif // GSX_STRATEGIC_STOP_MQH
//+------------------------------------------------------------------+
