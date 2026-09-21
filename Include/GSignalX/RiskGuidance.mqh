//+------------------------------------------------------------------+
//| RiskGuidance.mqh — adaptive risk tip selector (advisory only)   |
//| Pure helpers: no Inp* reads, no orders, no closes.              |
//| Catalog: docs/risk/RISK_GUIDANCE_BLOCKS.md                       |
//+------------------------------------------------------------------+
#ifndef GSX_RISK_GUIDANCE_MQH
#define GSX_RISK_GUIDANCE_MQH

#include <GSignalX/SymbolClass.mqh>

// Trade-lifecycle / settings phases (selector input)
enum ENUM_GSX_RISK_PHASE
  {
   GSX_RISK_PHASE_PRETRADE = 0,
   GSX_RISK_PHASE_ENTRY    = 1,
   GSX_RISK_PHASE_OPEN     = 2,
   GSX_RISK_PHASE_PROFIT   = 3,
   GSX_RISK_PHASE_DRAWDOWN = 4,
   GSX_RISK_PHASE_EXIT     = 5,
   GSX_RISK_PHASE_POST     = 6,
   GSX_RISK_PHASE_SETTINGS = 7
  };

// Compact context — callers pass primitives (no snapshot dependency)
struct GsxRiskContext
  {
   int  symClass;     // ENUM_GSX_SYM_CLASS or GSX_CAT_* (0=ALL/OTH)
   int  phase;        // ENUM_GSX_RISK_PHASE
   bool propLocked;
   bool eventSkip;
   bool sessionOverlap;
   bool londonNy;
   bool asiaOnly;
   bool autoLot;
   bool spreadIgn;
  };

//+------------------------------------------------------------------+
void GsxRiskContextClear(GsxRiskContext &ctx)
  {
   ctx.symClass = 0;
   ctx.phase = GSX_RISK_PHASE_ENTRY;
   ctx.propLocked = false;
   ctx.eventSkip = false;
   ctx.sessionOverlap = false;
   ctx.londonNy = false;
   ctx.asiaOnly = false;
   ctx.autoLot = false;
   ctx.spreadIgn = false;
  }

//+------------------------------------------------------------------+
string GsxRiskClipTip(string tip, const int maxLen = 96)
  {
   if(maxLen <= 0)
      return(tip);
   if(StringLen(tip) > maxLen)
      tip = StringSubstr(tip, 0, maxLen) + "..";
   return(tip);
  }

//+------------------------------------------------------------------+
string GsxRiskBlockId(const GsxRiskContext &ctx)
  {
   if(ctx.propLocked)
      return("RB_DRAWDOWN");
   if(ctx.eventSkip)
      return("RB_PRETRADE");
   if(ctx.phase == GSX_RISK_PHASE_SETTINGS)
      return("RB_SETTINGS");
   if(ctx.phase == GSX_RISK_PHASE_PRETRADE)
      return("RB_PRETRADE");
   if(ctx.phase == GSX_RISK_PHASE_ENTRY)
      return("RB_ENTRY");
   if(ctx.phase == GSX_RISK_PHASE_OPEN)
      return("RB_OPEN");
   if(ctx.phase == GSX_RISK_PHASE_PROFIT)
      return("RB_PROFIT");
   if(ctx.phase == GSX_RISK_PHASE_DRAWDOWN)
      return("RB_DRAWDOWN");
   if(ctx.phase == GSX_RISK_PHASE_EXIT)
      return("RB_EXIT");
   if(ctx.phase == GSX_RISK_PHASE_POST)
      return("RB_POST");
   return("RB_ENTRY");
  }

//+------------------------------------------------------------------+
string GsxRiskClassNote(const int symClass)
  {
   // Accepts ENUM_GSX_SYM_CLASS or GSX_CAT_* (same 0..3 numbering for FX/CMD/CR)
   if(symClass == GSX_CLASS_CRYPTO || symClass == 3)
      return("CR: 24h ok · watch spread · overnight SUSPEND if policy");
   if(symClass == GSX_CLASS_COMMODITY || symClass == 2)
      return("CMD: USD/news sensitive · verify hours/gaps");
   if(symClass == GSX_CLASS_FOREX || symClass == 1)
      return("FX: prefer LDN·NY · thin Asia needs a plan");
   return("");
  }

//+------------------------------------------------------------------+
string GsxRiskPhaseTip(const int phase)
  {
   if(phase == GSX_RISK_PHASE_PRETRADE)
      return("Pre-trade: class+session+Prop+Event · size Profit CASH to book");
   if(phase == GSX_RISK_PHASE_ENTRY)
      return("Entry: DIR fresh? spread OK? fleet room? FIXED unless intentional AUTO");
   if(phase == GSX_RISK_PHASE_OPEN)
      return("Open: manage reason not P/L · cat SL stays · Scouter owns exits");
   if(phase == GSX_RISK_PHASE_PROFIT)
      return("Profit: bank by plan (CASH/TRAIL) · not greed hold or fear BANK");
   if(phase == GSX_RISK_PHASE_DRAWDOWN)
      return("DD: cut on thesis/budget · not hope · no revenge size");
   if(phase == GSX_RISK_PHASE_EXIT)
      return("Exit: tag the reason · STOP≠close · one Scouter per book");
   if(phase == GSX_RISK_PHASE_POST)
      return("Post: journal class+session+tag · one change at a time");
   if(phase == GSX_RISK_PHASE_SETTINGS)
      return("Settings: entries/harvest posture only · tickets untouched");
   return("Manage the reason for the trade, not merely P/L");
  }

//+------------------------------------------------------------------+
string GsxRiskTipLine(const GsxRiskContext &ctx)
  {
   if(ctx.propLocked)
      return(GsxRiskClipTip("Prop LOCK — no new risk until CLEAR · open tickets unmanaged here"));
   if(ctx.eventSkip)
      return(GsxRiskClipTip("Event SKIP — block new fills on hit symbols · reassess after"));
   if(ctx.spreadIgn)
      return(GsxRiskClipTip("IGN on — worse fills allowed · reassess size/slippage before entry"));
   if(ctx.autoLot && ctx.phase == GSX_RISK_PHASE_SETTINGS)
      return(GsxRiskClipTip("AUTOLOT: size≠leverage · min-lot may dominate small books"));

   string classNote = GsxRiskClassNote(ctx.symClass);
   if(ctx.phase == GSX_RISK_PHASE_ENTRY || ctx.phase == GSX_RISK_PHASE_PRETRADE)
     {
      if(ctx.asiaOnly && (ctx.symClass == GSX_CLASS_FOREX || ctx.symClass == 1 || ctx.symClass == 0))
         return(GsxRiskClipTip("FX Asia window — liquidity thin · wait LDN/NY unless plan says so"));
      if(ctx.londonNy)
         return(GsxRiskClipTip("LDN·NY overlap — entries OK if DIR/spread/fleet clear · Scouter exits"));
      if(classNote != "")
         return(GsxRiskClipTip(classNote));
      return(GsxRiskClipTip("New entries only — open positions unchanged · manage reason not P/L"));
     }

   if(classNote != "" && (ctx.phase == GSX_RISK_PHASE_OPEN || ctx.phase == GSX_RISK_PHASE_PROFIT))
      return(GsxRiskClipTip(GsxRiskPhaseTip(ctx.phase)));

   return(GsxRiskClipTip(GsxRiskPhaseTip(ctx.phase)));
  }

//+------------------------------------------------------------------+
// Desk Trade Center tip (FDIR row) — soft entry posture + context
string GsxRiskDeskTip(const int catFilter,
                      const bool propLocked,
                      const bool eventSkip,
                      const bool sessionOverlap,
                      const bool londonOpen,
                      const bool nyOpen,
                      const bool asiaOpen,
                      const bool autoLot,
                      const bool spreadIgn)
  {
   GsxRiskContext ctx;
   GsxRiskContextClear(ctx);
   ctx.symClass = catFilter;
   ctx.phase = GSX_RISK_PHASE_ENTRY;
   ctx.propLocked = propLocked;
   ctx.eventSkip = eventSkip;
   ctx.sessionOverlap = sessionOverlap;
   ctx.londonNy = (londonOpen && nyOpen);
   ctx.asiaOnly = (asiaOpen && !londonOpen && !nyOpen);
   ctx.autoLot = autoLot;
   ctx.spreadIgn = spreadIgn;
   return(GsxRiskTipLine(ctx));
  }

//+------------------------------------------------------------------+
string GsxRiskTipForSymbol(const string sym, const int phase = GSX_RISK_PHASE_ENTRY)
  {
   GsxRiskContext ctx;
   GsxRiskContextClear(ctx);
   ctx.symClass = (int)GsxSymbolClass(sym);
   ctx.phase = phase;
   string tip = GsxRiskTipLine(ctx);
   // Prefer short class note on OPEN alerts
   if(phase == GSX_RISK_PHASE_ENTRY)
     {
      string cn = GsxRiskClassNote(ctx.symClass);
      if(cn != "")
         tip = GsxRiskClipTip(cn, 72);
     }
   return(tip);
  }

//+------------------------------------------------------------------+
string GsxRiskSettingsClause(const string action)
  {
   string a = action;
   StringToUpper(a);
   if(StringFind(a, "AUTOLOT") >= 0)
      return("risk: size≠leverage · verify stop distance");
   if(StringFind(a, "EQ") >= 0)
      return("risk: EQ blocks entries only · open tickets stay");
   if(StringFind(a, "PROP") >= 0)
      return("risk: Prop soft-lock · never flattens");
   if(StringFind(a, "FLEET") >= 0)
      return("risk: re-check correlated FX/CMD exposure");
   if(StringFind(a, "LOAD") >= 0)
      return("risk: confirm Profit CASH sized to book");
   if(StringFind(a, "HALT") >= 0)
      return("risk: HALT≠flat · Scouter paused");
   if(StringFind(a, "STOP") >= 0)
      return("risk: STOP≠close · Scouter may still bank");
   if(StringFind(a, "IGN") >= 0 || StringFind(a, "SPREAD") >= 0)
      return("risk: spreads drive slippage · size down if IGN");
   if(StringFind(a, "LOSS") >= 0)
      return("risk: Loss CASH is intentional loser cut");
   if(StringFind(a, "PLAY") >= 0)
      return("risk: manage reason not P/L after fill");
   return("risk: manage reason not P/L");
  }

//+------------------------------------------------------------------+
string GsxRiskPracticeEnrich(const int softCat, const string baseTip)
  {
   string note = GsxRiskClassNote(softCat);
   string out = baseTip;
   if(note != "")
     {
      // Prefer keeping practice maths; append short class cue when room
      string cue = "";
      if(softCat == 3 || softCat == GSX_CLASS_CRYPTO)
         cue = " · CR spread";
      else if(softCat == 2 || softCat == GSX_CLASS_COMMODITY)
         cue = " · CMD news";
      else if(softCat == 1 || softCat == GSX_CLASS_FOREX)
         cue = " · FX session";
      if(cue != "" && StringFind(out, cue) < 0)
         out += cue;
     }
   return(GsxRiskClipTip(out, 96));
  }

#endif // GSX_RISK_GUIDANCE_MQH
//+------------------------------------------------------------------+
