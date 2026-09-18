//+------------------------------------------------------------------+
//|                                         MultisymbolPanel.mqh      |
//|  Full + Compact Trade Center (GSXMS_) — v1.27 wheel page scroll   |
//|  NEVER closes positions.                                          |
//+------------------------------------------------------------------+
#ifndef GSX_MULTISYMBOL_PANEL_MQH
#define GSX_MULTISYMBOL_PANEL_MQH

#include <Trade\Trade.mqh>
#include <GSignalX/ChartPanel.mqh>
#include <GSignalX/RosterViewModel.mqh>
#include <GSignalX/RosterStore.mqh>
#include <GSignalX/Fleet.mqh>
#include <GSignalX/ScoutLink.mqh>
#include <GSignalX/SymbolCanon.mqh>
#include <GSignalX/SymbolClass.mqh>
#include <GSignalX/SessionClock.mqh>
#include <GSignalX/TelegramNotifier.mqh>
#include <GSignalX/SettingsNotify.mqh>
#include <GSignalX/PracticeSim.mqh>
#include <GSignalX/LotSizing.mqh>

#define GSXMS_PFX        "GSXMS_"
#define GSXMS_WIDTH      1280  // v2.05 true quadrant board width
#define GSXMS_RH         26    // tighter rows — more pairs visible
#define GSXMS_TITLE_H    30
#define GSXMS_BTN_H      32
#define GSXMS_BTN_GAP    5
#define GSXMS_STATE_W    84
#define GSXMS_COMPACT_W  525
#define GSXMS_MODE_W     52
#define GSXMS_QUAD_GUTTER 10

// v2.02 vision: high-legibility defaults (Comfort/Far bump further)
color g_msColBg     = C'14,18,26';
color g_msColEdge   = C'72,84,108';
color g_msColAccent = C'255,196,72';
color g_msColBull   = C'52,220,140';
color g_msColBear   = C'245,90,88';
color g_msColText   = C'240,244,252';
color g_msColMuted  = C'178,188,210';
color g_msColTitle  = C'24,30,42';
color g_msColStop   = C'240,186,78';
color g_msColBand   = C'22,28,40';
color g_msColZebra  = C'20,26,36';

int    g_msPanelX        = 12;
int    g_msPanelY        = 22;
bool   g_msDragging      = false;
bool   g_msDragOffSet    = false;
int    g_msDragDX        = 0;
int    g_msDragDY        = 0;
int    g_msPage          = 0;
int    g_msCarouselIdx   = 0;
bool   g_msFlipWait      = false;
int    g_msDeskFollowDir = GSX_FOLLOW_AUTO;
string g_msLastAction    = "";
long   g_msMagic         = 0;
int    g_msPageSize      = 12;
int    g_msPageSizeDefault = 12;
bool   g_msCompact       = false;
bool   g_msDense         = false;  // narrow Trade Center densify (full chrome, tighter metrics)
bool   g_msShowButtons   = true;
bool   g_msShowPractice  = false; // v2.05: mute practice/demo coach by default
int    g_msDefaultFleet  = 4;
int    g_msRowsDrawn     = 0;
int    g_msCompactRowsDrawn = 0;
int    g_msClassMax      = GSX_CLASS_SOFT_MAX_DEFAULT;
int    g_msPanelWidth    = GSXMS_WIDTH;
int    g_msRowH          = GSXMS_RH;
double g_msUiScaleReq    = 1.5;
int    g_msTitleH        = GSXMS_TITLE_H;
int    g_msVision        = GSX_VISION_COMFORT;
bool   g_msScoutLinkEnable = true;
int    g_msScoutInstanceID = 1;
int    g_msLastTotalH    = 0;      // measured panel height for clamp/drag
GsxSessionClockConfig g_msSessionCfg;

// Announce prop-critical setting changes to Telegram (Desk-bound SettingsNotify).
void GsxMsSettingsClick(const string action)
  {
   if(action == "")
      return;
   GsxSettingsAnnounce(action);
  }

// Scaled layout cache (rebuilt each draw via GsxMsLayoutRefresh).
// Peer X offsets come only from GsxLay pack/cols — never stored as absolutes.
struct GsxMsLayout
  {
   int width;
   int titleDesign; // design units for GsxPanelBegin (vision bump once)
   int titleH;      // scaled pixels
   int rh;
   int btnH;
   int btnGap;
   int stateW;
   int statusH;
   int sessH;
   int evtH;
   int tipH;
   int inset;
   int fontBase;
   int fontSmall;
   int fontRow;
   int fontBig;
   int bw;    // preferred cmd button width (equal-pack may shrink)
   int tw;    // category tab
   int twCr;
   int pb;    // practice band tab
   int sectionGap; // legacy alias → bandGap
   int cellGap;    // horizontal spacing between peers
   int bandGap;    // vertical spacing between major bands
   int tableGap;   // vertical spacing inside roster table (usually 0)
   int btnPad;     // inset padding inside button slots
   int clipEvt;
   int clipCoach;
   int clipTip;
  };
GsxMsLayout g_msLay;

//+------------------------------------------------------------------+
void GsxMsPanelSetUiScale(const double scale)
  {
   g_msUiScaleReq = GsxPanelClampScale(scale);
  }

void GsxMsPanelSetVision(const int vision)
  {
   GsxPanelSetVision(vision);
   g_msVision = GsxPanelGetVision();
  }

void GsxMsApplyVisionPalette()
  {
   if(g_msVision == GSX_VISION_NEAR)
     {
      // High-contrast chips for close viewing
      g_msColBg    = C'10,12,18';
      g_msColText  = C'248,250,255';
      g_msColMuted = C'190,198,216';
      g_msColEdge  = C'90,104,130';
      g_msColBand  = C'18,22,32';
      g_msColZebra = C'16,20,28';
     }
   else if(g_msVision == GSX_VISION_FAR)
     {
      // Softer bg, brighter glyphs for desk distance
      g_msColBg    = C'16,20,28';
      g_msColText  = C'255,255,255';
      g_msColMuted = C'198,206,224';
      g_msColEdge  = C'96,110,138';
      g_msColBand  = C'26,32,44';
      g_msColZebra = C'22,28,38';
      g_msColAccent = C'255,204,90';
     }
   else
     {
      g_msColBg    = C'14,18,26';
      g_msColText  = C'240,244,252';
      g_msColMuted = C'178,188,210';
      g_msColEdge  = C'72,84,108';
      g_msColBand  = C'22,28,40';
      g_msColZebra = C'20,26,36';
      g_msColAccent = C'255,196,72';
     }
  }

string GsxMsFriendlyFlags(const GsxMsRow &row)
  {
   string parts = "";
   if(row.busy) parts += (parts == "" ? "" : " · ") + "Busy";
   if(row.pairState == GSX_PAIR_STOP) parts += (parts == "" ? "" : " · ") + "SoftStop";
   if(row.pairState == GSX_PAIR_SUSPEND) parts += (parts == "" ? "" : " · ") + "Suspend";
   if(row.eventBlocked) parts += (parts == "" ? "" : " · ") + "Event";
   if(!row.marketOpen) parts += (parts == "" ? "" : " · ") + "Closed";
   if(row.dirState == "STALE") parts += (parts == "" ? "" : " · ") + "Stale";
   if(row.dirState == "COMPUTE") parts += (parts == "" ? "" : " · ") + "Compute";
   if(row.fillSkip != "") parts += (parts == "" ? "" : " · ") + row.fillSkip;
   if(parts == "")
      return(g_msVision == GSX_VISION_NEAR ? "." : "OK");
   // Compact codes when NEAR (space tight)
   if(g_msVision == GSX_VISION_NEAR)
     {
      string c = "";
      if(row.busy) c += "B";
      if(row.pairState == GSX_PAIR_STOP) c += "T";
      if(row.pairState == GSX_PAIR_SUSPEND) c += "S";
      if(row.eventBlocked) c += "E";
      if(!row.marketOpen) c += "X";
      if(row.dirState == "STALE") c += "K";
      if(row.dirState == "COMPUTE") c += "C";
      if(row.fillSkip != "") c += "!";
      return(c == "" ? "." : c);
     }
   return(parts);
  }

void GsxMsDrawSectionBand(const string tag, const int x, const int y,
                          const int w, const int h)
  {
   // Stay inside content box [x .. x+w] — flat (edge=fill) removes border/shadow glow
   int pad = GsxSx(2);
   GsxPanelRect(tag, x + pad, y, MathMax(GsxSx(40), w - 2 * pad), MathMax(GsxSx(10), h),
                g_msColBand, g_msColBand, false);
  }

void GsxMsLayoutRefreshClips()
  {
   int textW = MathMax(GsxSx(40), g_msLay.width - GsxSx(16));
   int evtReserve = g_msDense ? GsxSx(64) : GsxSx(90);
   g_msLay.clipEvt   = GsxPanelCharsFit(MathMax(GsxSx(40), textW - evtReserve), g_msLay.fontSmall);
   g_msLay.clipCoach = GsxPanelCharsFit(textW, g_msLay.fontSmall);
   g_msLay.clipTip   = GsxPanelCharsFit(textW, g_msLay.fontSmall);
  }

void GsxMsLayoutRefresh(const bool forCompact)
  {
   GsxPanelSetVision(g_msVision);
   GsxMsApplyVisionPalette();

   // Dense = full Trade Center chrome with softer metrics (not chart-strip compact)
   bool dense = (!forCompact && g_msDense);
   int baseW = forCompact ? GSXMS_COMPACT_W : GSXMS_WIDTH;
   if(g_msVision == GSX_VISION_FAR && !forCompact && !dense)
      baseW = 1320;
   if(dense)
      baseW = MathMin(baseW, 900);
   double eff = GsxPanelFitScale(g_msUiScaleReq, baseW, 24);
   GsxPanelSetScale(eff);

   int bump = GsxPanelFontBump();
   // Keep dense fonts legible — do not strip vision bump
   int rhDesign = forCompact ? 14 :
                  (dense ? GSXMS_RH :
                   (GSXMS_RH + (g_msVision == GSX_VISION_FAR ? 4 :
                                (g_msVision == GSX_VISION_COMFORT ? 2 : 0))));
   int titleBase = forCompact ? 18 : (dense ? GSXMS_TITLE_H :
                                      (GSXMS_TITLE_H + (g_msVision == GSX_VISION_FAR ? 2 : 0)));
   g_msLay.titleDesign = GsxPanelTitleHDesign(titleBase);
   int btnDesign = forCompact ? 22 :
                   (dense ? GSXMS_BTN_H :
                    (GSXMS_BTN_H + (g_msVision == GSX_VISION_FAR ? 4 :
                                    (g_msVision == GSX_VISION_COMFORT ? 2 : 0))));

   g_msLay.width   = GsxSx(baseW);
   g_msLay.titleH  = GsxSx(g_msLay.titleDesign);
   g_msLay.rh      = GsxSx(rhDesign);
   g_msLay.btnH    = GsxSx(btnDesign);
   g_msLay.btnGap  = GsxSx(GSXMS_BTN_GAP + (dense ? 0 :
                           (g_msVision == GSX_VISION_FAR ? 2 : 0)));
   if(g_msLay.btnGap < GsxSx(4))
      g_msLay.btnGap = GsxSx(4);
   g_msLay.stateW = GsxSx(forCompact ? 56 :
                           (dense ? 84 :
                            (g_msVision == GSX_VISION_FAR ? 96 : GSXMS_STATE_W)));
   g_msLay.inset   = GsxSx(g_msVision == GSX_VISION_FAR && !dense ? 10 : 8);
   // Comfort: 8/7/8/10 · Dense: 7/7/7/9 · Compact strip: 7/7/7/8
   g_msLay.fontBase  = GsxSf((forCompact ? 7 : (dense ? 7 : 8)) + bump);
   g_msLay.fontSmall = GsxSf((forCompact ? 7 : (dense ? 7 : 7)) + bump);
   g_msLay.fontRow   = GsxSf((forCompact ? 7 : (dense ? 7 : 8)) + bump);
   g_msLay.fontBig   = GsxSf((forCompact ? 8 : (dense ? 9 : 10)) + bump);

   g_msLay.bw   = GsxSx((dense ? 110 : 140) + (g_msVision == GSX_VISION_FAR && !dense ? 8 : 0));
   g_msLay.tw   = GsxSx((dense ? 64 : 78) + (g_msVision == GSX_VISION_FAR && !dense ? 6 : 0));
   g_msLay.twCr = GsxSx((dense ? 72 : 88) + (g_msVision == GSX_VISION_FAR && !dense ? 8 : 0));
   g_msLay.pb   = GsxSx(dense ? 40 : 48);

   int rhGuess = MathMax(g_msLay.rh, g_msLay.fontRow + GsxSp(dense ? 10 : 12));
   g_msLay.cellGap = GsxSpRow(dense ? 5 : (g_msVision == GSX_VISION_NEAR ? 5 : 8),
                              rhGuess, dense ? 0.14 : 0.16);
   g_msLay.bandGap = GsxSpRow(dense ? 8 : (g_msVision == GSX_VISION_NEAR ? 8 : 10),
                              rhGuess, dense ? 0.20 : 0.26);
   g_msLay.tableGap = GsxSp(dense ? 2 : 3);
   g_msLay.btnPad = GsxSp(dense ? 2 : 3);
   g_msLay.sectionGap = g_msLay.bandGap;

   int glyphInfo = g_msLay.fontSmall + GsxSp(dense ? 12 : 14);
   int miniBtn   = MathMax(GsxSx(20), g_msLay.btnH - GsxSp(4));
   int infoH     = MathMax(glyphInfo, miniBtn + 2 * g_msLay.btnPad);
   g_msLay.statusH = infoH;
   g_msLay.sessH   = infoH;
   g_msLay.evtH    = infoH;
   g_msLay.tipH    = g_msLay.fontSmall + GsxSp(dense ? 8 : 10);
   // Glyph-clear table rows — never overlap (taller pitch + air)
   int tblGlyph = (int)MathRound((double)g_msLay.fontRow * 1.45) + GsxSp(dense ? 10 : 12);
   g_msLay.rh = MathMax(g_msLay.rh, MathMax(tblGlyph, miniBtn + GsxSp(8)));
   g_msLay.cellGap = GsxSpRow(dense ? 5 : (g_msVision == GSX_VISION_NEAR ? 5 : 8),
                              g_msLay.rh, dense ? 0.14 : 0.16);
   g_msLay.bandGap = GsxSpRow(dense ? 8 : (g_msVision == GSX_VISION_NEAR ? 8 : 10),
                              g_msLay.rh, dense ? 0.20 : 0.26);
   g_msLay.sectionGap = g_msLay.bandGap;

   GsxMsLayoutRefreshClips();

   g_msPanelWidth = g_msLay.width;
   g_msRowH       = g_msLay.rh;
   g_msTitleH     = g_msLay.titleH;
  }

//+------------------------------------------------------------------+
//| Adaptive layout: fit scale to chart + dense metrics when narrow. |
//+------------------------------------------------------------------+
void GsxMsPanelApplyAdaptive()
  {
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(chartW <= 0)
      chartW = 1280;
   if(chartH <= 0)
      chartH = 720;

   double geom = MathMax(0.01, GsxPanelGetGeomScale());
   double designW = (double)chartW / geom;
   // Dense only on genuinely narrow charts — keep Comfort on wide desks
   g_msDense = (designW < 1000.0);
   g_msCompact = g_msDense;

   GsxMsLayoutRefresh(false);

   designW = (double)chartW / MathMax(0.01, GsxPanelGetGeomScale());
   g_msDense = (designW < 1000.0);
   g_msCompact = g_msDense;

   if(g_msDense)
     {
      int fitW = (int)MathMin(g_msLay.width, MathMax(GsxSx(400), chartW - 24));
      fitW = (int)MathMin(fitW, GsxSx(980));
      g_msPanelWidth = fitW;
      g_msLay.width = fitW;
      g_msColMuted = C'190,200,220';
      GsxMsLayoutRefreshClips();
     }
   else
     {
      g_msPanelWidth = g_msLay.width;
      GsxMsApplyVisionPalette();
     }

   // Height-based pair capacity: 8–18 (quadrant chrome ~360)
   int chrome = GsxSx(360);
   int rh = MathMax(1, g_msLay.rh);
   int byHeight = (chartH - chrome) / rh;
   if(byHeight < 8) byHeight = 8;
   if(byHeight > 18) byHeight = 18;
   if(g_msDense)
      g_msPageSize = byHeight;
   else
     {
      int floorPs = g_msPageSizeDefault;
      if(floorPs < 8) floorPs = 8;
      if(floorPs > 18) floorPs = 18;
      g_msPageSize = MathMax(floorPs, byHeight);
      if(g_msPageSize > 18) g_msPageSize = 18;
     }

   int clampH = (g_msLastTotalH > GsxSx(120) ? g_msLastTotalH : GsxSx(480));
   GsxPanelClampPos(g_msPanelX, g_msPanelY, g_msPanelWidth, clampH);
  }

// Clip text to layout budget then slot-fit (no overflow past container)
void GsxMsSlotLabelBudget(const string tag, const GsxLaySlot &slot,
                          const string text, const color clr,
                          const int fontPx, const bool bold, const int clipChars)
  {
   string t = text;
   if(clipChars > 0)
      t = GsxPanelClip(text, clipChars);
   GsxPanelSlotLabel(tag, slot, t, clr, fontPx, bold);
  }

string GsxMsScoutStatusTxt()
  {
   if(!g_msScoutLinkEnable)
      return("Scout unlink");
   return(GsxScoutRunGet(g_msScoutInstanceID, true) ? "Scout ON" : "Scout OFF");
  }

color GsxMsScoutStatusClr()
  {
   if(!g_msScoutLinkEnable)
      return(g_msColMuted);
   return(GsxScoutRunGet(g_msScoutInstanceID, true) ? g_msColBull : g_msColBear);
  }

//+------------------------------------------------------------------+
string GsxMsPosXVar()
  {
   return(StringFormat("GSX_MS_PNLX_%I64d", ChartID()));
  }

string GsxMsPosYVar()
  {
   return(StringFormat("GSX_MS_PNLY_%I64d", ChartID()));
  }

string GsxMsFlipVar()
  {
   return(GsxRosterFlipWaitVarName(g_msMagic));
  }

void GsxMsPanelSetScoutLink(const bool linkEnable, const int instanceId)
  {
   g_msScoutLinkEnable = linkEnable;
   g_msScoutInstanceID = (instanceId < 1 ? 1 : instanceId);
  }

void GsxMsClearPracticeObjects()
  {
   ObjectDelete(0, GSXMS_PFX + "BTN_PRAC_20");
   ObjectDelete(0, GSXMS_PFX + "BTN_PRAC_50");
   ObjectDelete(0, GSXMS_PFX + "BTN_PRAC_100");
   ObjectDelete(0, GSXMS_PFX + "BTN_PRAC_RAW");
   ObjectDelete(0, GSXMS_PFX + "BTN_PRAC_STD");
   ObjectDelete(0, GSXMS_PFX + "BTN_PRAC_SCALP");
   ObjectDelete(0, GSXMS_PFX + "BTN_PRAC_DAY");
   ObjectDelete(0, GSXMS_PFX + "BTN_PRAC_SWING");
   ObjectDelete(0, GSXMS_PFX + "PRAC_COACH");
   ObjectDelete(0, GSXMS_PFX + "PRAC_TIP");
  }

void GsxMsPanelSetShowPractice(const bool show)
  {
   g_msShowPractice = show;
   if(!show)
      GsxMsClearPracticeObjects();
  }

//+------------------------------------------------------------------+
void GsxMsPanelLoadPos()
  {
   string nx = GsxMsPosXVar();
   string ny = GsxMsPosYVar();
   if(GlobalVariableCheck(nx))
      g_msPanelX = (int)GlobalVariableGet(nx);
   if(GlobalVariableCheck(ny))
      g_msPanelY = (int)GlobalVariableGet(ny);
   if(g_msPanelX < 0) g_msPanelX = 0;
   if(g_msPanelY < 0) g_msPanelY = 0;
  }

void GsxMsPanelSavePos()
  {
   GlobalVariableSet(GsxMsPosXVar(), (double)g_msPanelX);
   GlobalVariableSet(GsxMsPosYVar(), (double)g_msPanelY);
  }

void GsxMsPanelLoadFlip()
  {
   string n = GsxMsFlipVar();
   if(GlobalVariableCheck(n))
      g_msFlipWait = (GlobalVariableGet(n) > 0.5);
  }

void GsxMsPanelSetFlip(const bool waitMode)
  {
   g_msFlipWait = waitMode;
   GsxRosterFlipWaitSet(g_msMagic, waitMode);
   g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                    (waitMode ? " WAIT" : " FOLLOW");
  }

void GsxMsPanelSetFollowDir(const string symbol, const int mode)
  {
   GsxRosterFollowDirSet(g_msMagic, symbol, mode);
   g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                    " " + symbol + " Follow " + GsxRosterFollowDirLabel(mode) +
                    " (new entries only)";
  }

void GsxMsPanelSetFollowDirAll(const int mode, const string &roster[])
  {
   GsxRosterFollowDirSetAll(g_msMagic, roster, mode);
   g_msDeskFollowDir = GsxRosterFollowDirNormalize(mode);
   g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                    " Follow " + GsxRosterFollowDirLabel(mode) +
                    " all (Affects new entries only — open positions unchanged)";
  }

// Retire automation for a symbol: STOP fills, cancel pendings, clear GVs.
// Never closes open positions (Scouter owns exits).
// Note: do not include EntryExec.mqh here — its GSX_ENTRY_* macros break chart enums.
void GsxMsCancelSymbolPendings(const string symbol, const long magic, const string why)
  {
   if(symbol == "" || magic == 0)
      return;
   CTrade tr;
   tr.SetExpertMagicNumber(magic);
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol)
         continue;
      if(tr.OrderDelete(ticket))
         Print("GsignalX desk: pending #", ticket, " deleted (", why, ")");
      else
         Print("GsignalX desk: delete failed #", ticket,
               " retcode=", tr.ResultRetcode());
     }
  }

void GsxMsCancelRosterPendings(const long magic, const string &roster[], const string why)
  {
   for(int i = 0; i < ArraySize(roster); i++)
     {
      if(roster[i] != "")
         GsxMsCancelSymbolPendings(roster[i], magic, why);
     }
  }

// Soft-stop a pair: STOP state + cancel brackets (open positions untouched).
void GsxMsSoftStopSymbol(const string symbol, const string why)
  {
   if(symbol == "" || g_msMagic == 0)
      return;
   GsxRosterStateSet(g_msMagic, symbol, GSX_PAIR_STOP);
   GsxMsCancelSymbolPendings(symbol, g_msMagic, why);
   GsxRosterOnboardKickClear(g_msMagic, symbol);
  }

void GsxMsRetireSymbol(const string symbol)
  {
   if(symbol == "" || g_msMagic == 0)
      return;
   GsxMsSoftStopSymbol(symbol, "desk retire");
   GsxRosterClearSymbolMeta(g_msMagic, symbol);
  }

color GsxMsFollowDirClr(const int mode)
  {
   if(mode == GSX_FOLLOW_BUY)  return(g_msColBull);
   if(mode == GSX_FOLLOW_SELL) return(g_msColBear);
   if(mode == GSX_FOLLOW_WAIT) return(g_msColMuted);
   return(g_msColAccent); // FOLLOW / AUTO
  }

//+------------------------------------------------------------------+
void GsxMsPanelInit(const long magic, const int pageSize, const bool compact,
                    const double uiScale = 1.5, const int vision = GSX_VISION_COMFORT)
  {
   g_msMagic     = magic;
   g_msPageSizeDefault = (pageSize < 1 ? 1 : pageSize);
   g_msPageSize  = g_msPageSizeDefault;
   g_msCompact   = compact;
   g_msUiScaleReq = GsxPanelClampScale(uiScale);
   GsxMsPanelSetVision(vision);
   g_msPage      = GsxRosterPageGet(magic);
   g_msDragging  = false;
   g_msLastAction = "ready";
   g_msClassMax  = GsxRosterClassMaxGet(magic);
   GsxSessionClockDefaults(g_msSessionCfg);
   GsxMsPanelLoadPos();
   GsxMsPanelLoadFlip();
   GsxPanelSetScale(g_msUiScaleReq);
   GsxPanelConfigure(GSXMS_PFX, CORNER_LEFT_UPPER, "Segoe UI", 8, g_msColEdge);
  }

void GsxMsPanelDelete()
  {
   ObjectsDeleteAll(0, GSXMS_PFX);
   g_msRowsDrawn = 0;
   g_msCompactRowsDrawn = 0;
  }

//+------------------------------------------------------------------+
bool GsxMsHitTitle(const int mx, const int my)
  {
   int inset = (g_msLay.inset > 0 ? g_msLay.inset : GsxSx(8));
   int left = g_msPanelX - inset;
   int top  = g_msPanelY - inset;
   int ww = (g_msPanelWidth > 0 ? g_msPanelWidth : GsxSx(GSXMS_WIDTH)) + 2 * inset;
   int th = (g_msTitleH > 0 ? g_msTitleH : GsxSx(GSXMS_TITLE_H));
   if(mx < left || mx > left + ww)
      return(false);
   if(my < top || my > top + th)
      return(false);
   return(true);
  }

string GsxMsDirTxt(const int dir)
  {
   if(dir > 0) return("BUY");
   if(dir < 0) return("SELL");
   return("-");
  }

// v2.07: COMPUTE / LIVE / STALE / FLAT / HIST direction cell
string GsxMsDirCellTxt(const GsxMsRow &row)
  {
   string d = GsxMsDirTxt(row.direction);
   if(row.dirState == "COMPUTE")
      return("COMPUTE");
   if(row.dirState == "FLAT")
      return("FLAT");
   if(row.dirState == "STALE")
      return("ST " + d);
   if(row.dirState == "HIST")
     {
      if(row.signalAgeSec >= 0)
         return("H " + d + " " + IntegerToString(row.signalAgeSec) + "s");
      return("H " + d);
     }
   // LIVE
   return(d);
  }

color GsxMsDirCellClr(const GsxMsRow &row)
  {
   if(row.dirState == "COMPUTE")
      return(g_msColMuted);
   if(row.dirState == "FLAT")
      return(g_msColMuted);
   if(row.dirState == "STALE")
      return(g_msColStop);
   if(row.dirState == "HIST")
      return(g_msColAccent);
   return(GsxMsDirClr(row.direction));
  }

color GsxMsDirClr(const int dir)
  {
   if(dir > 0) return(g_msColBull);
   if(dir < 0) return(g_msColBear);
   return(g_msColMuted);
  }

color GsxMsStateClr(const int state)
  {
   if(state == GSX_PAIR_STOP)    return(g_msColStop);
   if(state == GSX_PAIR_SUSPEND) return(g_msColBear);
   return(g_msColBull);
  }

string GsxMsStateBtn(const int state)
  {
   return(GsxRosterStateLabel(state));
  }

bool GsxMsInRoster(const string &names[], const string symbol)
  {
   return(GsxRosterContains(names, symbol));
  }

string GsxMsCarouselCandidate(const string &roster[])
  {
   // Prefer Market Watch; fall back to full symbol list so ADD never goes dead
   bool watchOnly = (SymbolsTotal(true) > 0);
   int total = SymbolsTotal(watchOnly);
   if(total <= 0)
      return("");

   if(g_msCarouselIdx < 0)
      g_msCarouselIdx = 0;
   g_msCarouselIdx = g_msCarouselIdx % total;

   int cat = GsxRosterCatGet(g_msMagic);

   for(int attempt = 0; attempt < total; attempt++)
     {
      int idx = (g_msCarouselIdx + attempt) % total;
      string sym = SymbolName(idx, watchOnly);
      if(sym == "")
         continue;
      if(GsxMsInRoster(roster, sym))
         continue;
      if(cat != GSX_CAT_ALL)
        {
         ENUM_GSX_SYM_CLASS cls = GsxSymbolClass(sym);
         if(cat == GSX_CAT_FOREX && cls != GSX_CLASS_FOREX) continue;
         if(cat == GSX_CAT_COMMODITY && cls != GSX_CLASS_COMMODITY) continue;
         if(cat == GSX_CAT_CRYPTO && cls != GSX_CLASS_CRYPTO) continue;
        }
      g_msCarouselIdx = idx;
      return(sym);
     }
   return(SymbolName(g_msCarouselIdx % total, watchOnly));
  }

void GsxMsCarouselStep(const int delta, const string &roster[])
  {
   bool watchOnly = (SymbolsTotal(true) > 0);
   int total = SymbolsTotal(watchOnly);
   if(total <= 0)
      return;

   int cat = GsxRosterCatGet(g_msMagic);
   for(int attempt = 0; attempt < total; attempt++)
     {
      g_msCarouselIdx = (g_msCarouselIdx + delta) % total;
      if(g_msCarouselIdx < 0)
         g_msCarouselIdx += total;
      string sym = SymbolName(g_msCarouselIdx, watchOnly);
      if(sym == "")
         continue;
      if(GsxMsInRoster(roster, sym))
         continue;
      if(cat != GSX_CAT_ALL)
        {
         ENUM_GSX_SYM_CLASS cls = GsxSymbolClass(sym);
         if(cat == GSX_CAT_FOREX && cls != GSX_CLASS_FOREX) continue;
         if(cat == GSX_CAT_COMMODITY && cls != GSX_CLASS_COMMODITY) continue;
         if(cat == GSX_CAT_CRYPTO && cls != GSX_CLASS_CRYPTO) continue;
        }
      return;
     }
  }

void GsxMsTrimRowObjects(const int used)
  {
   for(int i = used; i < g_msRowsDrawn; i++)
     {
      ObjectDelete(0, GSXMS_PFX + StringFormat("ROW%d_BG", i));
      ObjectDelete(0, GSXMS_PFX + StringFormat("ROW%d_SYM", i));
      ObjectDelete(0, GSXMS_PFX + StringFormat("ROW%d_DIR", i));
      ObjectDelete(0, GSXMS_PFX + StringFormat("ROW%d_SPR", i));
      ObjectDelete(0, GSXMS_PFX + StringFormat("ROW%d_PL", i));
      ObjectDelete(0, GSXMS_PFX + StringFormat("ROW%d_GR", i));
      ObjectDelete(0, GSXMS_PFX + StringFormat("ROW%d_FLG", i));
      ObjectDelete(0, GSXMS_PFX + "BTN_STATE_" + IntegerToString(i));
      ObjectDelete(0, GSXMS_PFX + "BTN_MODE_" + IntegerToString(i));
      ObjectDelete(0, GSXMS_PFX + "BTN_MUTE_" + IntegerToString(i));
      ObjectDelete(0, GSXMS_PFX + "BTN_REM_" + IntegerToString(i));
     }
   g_msRowsDrawn = used;
  }

void GsxMsTrimCompactRows(const int used)
  {
   for(int i = used; i < g_msCompactRowsDrawn; i++)
     {
      ObjectDelete(0, GSXMS_PFX + StringFormat("CR%d", i));
      ObjectDelete(0, GSXMS_PFX + "BTN_STATE_" + IntegerToString(i));
      ObjectDelete(0, GSXMS_PFX + "BTN_REM_" + IntegerToString(i));
     }
   g_msCompactRowsDrawn = used;
  }

// Category-filtered page count (same ceil math as GsxMsBuildSnapshot).
int GsxMsPageCountFromCat()
  {
   string names[];
   GsxRosterStoreLoad(g_msMagic, names);
   string view[];
   GsxRosterFilterByCat(names, GsxRosterCatGet(g_msMagic), view);
   int n = ArraySize(view);
   int ps = MathMax(1, g_msPageSize);
   return(n <= 0 ? 1 : (n + ps - 1) / ps);
  }

// Shared page step for BTN_PAGE_* and mouse-wheel scroll. Clamps to [0, pageCount-1].
bool GsxMsPageStep(const int delta)
  {
   int pc = GsxMsPageCountFromCat();
   int next = g_msPage + delta;
   if(next < 0)
      next = 0;
   if(next >= pc)
      next = pc - 1;
   if(next == g_msPage)
     {
      g_msLastAction = "page " + IntegerToString(g_msPage + 1);
      return(false);
     }
   g_msPage = next;
   GsxRosterPageSet(g_msMagic, g_msPage);
   g_msLastAction = "page " + IntegerToString(g_msPage + 1);
   return(true);
  }

bool GsxMsObjContains(const string name, const int mx, const int my)
  {
   if(ObjectFind(0, name) < 0)
      return(false);
   int x = (int)ObjectGetInteger(0, name, OBJPROP_XDISTANCE);
   int y = (int)ObjectGetInteger(0, name, OBJPROP_YDISTANCE);
   int w = (int)ObjectGetInteger(0, name, OBJPROP_XSIZE);
   int h = (int)ObjectGetInteger(0, name, OBJPROP_YSIZE);
   if(w <= 0 || h <= 0)
      return(false);
   if(mx < x || mx > x + w)
      return(false);
   if(my < y || my > y + h)
      return(false);
   return(true);
  }

// Hit-test Trade Center BG / compact CBG / table band for wheel consume.
bool GsxMsHitTestPanel(const int mx, const int my)
  {
   if(GsxMsObjContains(GSXMS_PFX + "CBG", mx, my))
      return(true);
   if(GsxMsObjContains(GSXMS_PFX + "BG", mx, my))
      return(true);
   if(GsxMsObjContains(GSXMS_PFX + "SEC_TBL", mx, my))
      return(true);
   return(false);
  }

void GsxMsDrawCatTab(const string tag, const GsxLaySlot &slot,
                     const string text, const bool active)
  {
   if(slot.w <= 0)
      return;
   color chipIdle = C'32,38,50';
   GsxPanelSlotButtonPad(tag, slot, text,
                         active ? g_msColAccent : chipIdle,
                         active ? g_msColBg : g_msColText,
                         g_msLay.btnPad);
  }

// Exclusive text-chip width from glyph metrics (prevents neighbor overlap)
int GsxMsTextChipW(const string text, const int fontPx, const int minW)
  {
   int n = StringLen(text);
   if(n < 1) n = 1;
   // Bold + center pad — under-estimate clips ("Londor")
   int w = (int)MathRound((double)n * (double)MathMax(1, fontPx) * 0.72) + GsxSp(18);
   return(MathMax(minW, w));
  }

void GsxMsBandGutter(GsxLayCtx &lay, const int rowH)
  {
   lay.cursorY += GsxSpRow(10, MathMax(1, rowH), 0.30);
  }

void GsxMsDrawPill(const string tagBg, const string tagTx, const GsxLaySlot &slot,
                   const string text, const color bg, const color fg, const int fontPx,
                   const bool clickable = false)
  {
   if(slot.w <= 0 || slot.h <= 0)
     {
      ObjectDelete(0, GSXMS_PFX + tagBg);
      ObjectDelete(0, GSXMS_PFX + tagTx);
      return;
     }
   // Outer slot keeps peers apart; inner rect has real padding for text
   int inset = MathMax(2, GsxSp(2));
   int rx = slot.x + inset;
   int ry = slot.y + inset;
   int rw = MathMax(1, slot.w - 2 * inset);
   int rh = MathMax(1, slot.h - 2 * inset);
   // Flat chip: always edge==bg (no raised border / shadow)
   GsxPanelRect(tagBg, rx, ry, rw, rh, bg, bg, clickable);
   // Text pad inside pill so glyphs never kiss the border
   int tPad = MathMax(2, GsxSp(2));
   GsxLaySlot lab;
   lab.x = rx + tPad;
   lab.y = ry;
   lab.w = MathMax(1, rw - 2 * tPad);
   lab.h = rh;
   GsxPanelSlotLabelCentered(tagTx, lab, text, fg, fontPx, true);
   if(clickable)
     {
      ObjectSetInteger(0, GSXMS_PFX + tagBg, OBJPROP_ZORDER, 55);
      if(ObjectFind(0, GSXMS_PFX + tagTx) >= 0)
        {
         ObjectSetInteger(0, GSXMS_PFX + tagTx, OBJPROP_ZORDER, 56);
         ObjectSetInteger(0, GSXMS_PFX + tagTx, OBJPROP_SELECTABLE, true);
        }
     }
  }

bool GsxMsPackPill(GsxLayCtx &lay, const int wantW,
                   const string tagBg, const string tagTx, const string text,
                   const color bg, const color fg, const int fontPx,
                   const bool clickable = false)
  {
   GsxLaySlot s;
   if(!GsxLayPack(lay, wantW, s))
     {
      ObjectDelete(0, GSXMS_PFX + tagBg);
      ObjectDelete(0, GSXMS_PFX + tagTx);
      return(false);
     }
   GsxMsDrawPill(tagBg, tagTx, s, text, bg, fg, fontPx, clickable);
   return(true);
  }

bool GsxMsPackLabel(GsxLayCtx &lay, const int wantW, const string tag,
                    const string text, const color clr, const int fontPx, const bool bold)
  {
   GsxLaySlot s;
   if(!GsxLayPack(lay, wantW, s))
     {
      ObjectDelete(0, GSXMS_PFX + tag);
      return(false);
     }
   GsxPanelSlotLabel(tag, s, text, clr, fontPx, bold);
   return(true);
  }

void GsxMsDrawStatusRow(GsxLayCtx &lay, const GsxMsSnapshot &snap)
  {
   int fs = g_msLay.fontSmall;
   int pad = MathMax(g_msLay.btnPad, GsxSp(2));
   int rowH = MathMax(g_msLay.statusH, fs + GsxSp(g_msDense ? 12 : 16));
   if(g_msShowButtons)
      rowH = MathMax(rowH, GsxSx(g_msDense ? 22 : 24) + 2 * pad);
   int chipGap = MathMax(g_msLay.cellGap, GsxSp(g_msDense ? 5 : 8));
   GsxLaySetGaps(lay, chipGap, MathMax(g_msLay.bandGap, GsxSpRow(g_msDense ? 6 : 10, rowH, 0.32)));

   GsxLayRowStart(lay, rowH);
   // Quadrant UL — System Indicator
   GsxMsDrawSectionBand("SEC_SYS", lay.x0, lay.packY, lay.contentW, rowH);
   GsxMsDrawSectionBand("SEC_ST", lay.x0, lay.packY, lay.contentW, rowH);

   int verifyW = 0;
   if(g_msShowButtons && !g_msDense)
      verifyW = MathMax(GsxSx(72), GsxMsTextChipW("Verify", fs, GsxSx(68)));
   else if(g_msShowButtons && g_msDense)
      verifyW = MathMax(GsxSx(52), GsxMsTextChipW("Vfy", fs, GsxSx(48)));
   int statusAvail = lay.contentW;
   if(verifyW > 0)
      statusAvail = MathMax(GsxSp(80), lay.contentW - verifyW - chipGap);
   lay.packRemain = statusAvail;

   bool propOk = (StringFind(snap.propStatus, "LOCK") < 0);
   string ownTxt = snap.own
                   ? (g_msDense ? "OWN" : "Owns chart")
                   : (g_msDense ? "OFF" : "SVC OFF");
   string hbTxt = snap.hbFresh ? (g_msDense ? "HB" : "HB OK") : (g_msDense ? "NH" : "NO HB");
   string runTxt = snap.run ? (g_msDense ? "RUN" : "RUNNING") : (g_msDense ? "STOP" : "STOPPED");
   string scoutTxt = GsxMsScoutStatusTxt();
   if(g_msDense)
     {
      if(!g_msScoutLinkEnable) scoutTxt = "UNL";
      else scoutTxt = (GsxScoutRunGet(g_msScoutInstanceID, true) ? "SCN" : "SCOFF");
     }
   string fltTxt = StringFormat("Fleet %d/%d", snap.fleetActive, snap.fleetTarget);
   if(!g_msDense && MathAbs(snap.fleetPl) >= 0.005)
      fltTxt += StringFormat(" · %+.2f", snap.fleetPl);
   string propTxt = "Prop " + (snap.propStatus == "" ? "OK" : snap.propStatus);

   color ownBg = snap.own ? C'18,56,40' : C'56,24,28';
   color ownFg = snap.own ? g_msColBull : g_msColBear;
   color hbBg = snap.hbFresh ? C'18,56,40' : C'56,40,18';
   color hbFg = snap.hbFresh ? g_msColBull : g_msColAccent;
   color runBg = snap.run ? C'18,56,40' : C'56,24,28';
   color runFg = snap.run ? g_msColBull : g_msColBear;
   color scoutBg = (!g_msScoutLinkEnable ? C'28,34,46' :
                    (GsxScoutRunGet(g_msScoutInstanceID, true) ? C'18,56,40' : C'56,24,28'));
   color scoutFg = GsxMsScoutStatusClr();

   GsxMsPackPill(lay, GsxMsTextChipW(ownTxt, fs, GsxSx(g_msDense ? 40 : 72)),
                 "ST_OWN_BG", "ST_OWN", ownTxt, ownBg, ownFg, fs);
   GsxMsPackPill(lay, GsxMsTextChipW(hbTxt, fs, GsxSx(g_msDense ? 36 : 56)),
                 "ST_HB_BG", "ST_HB", hbTxt, hbBg, hbFg, fs);
   GsxMsPackPill(lay, GsxMsTextChipW(runTxt, fs, GsxSx(g_msDense ? 44 : 76)),
                 "ST_RUN_BG", "ST_RUN", runTxt, runBg, runFg, fs, true);
   GsxMsPackPill(lay, GsxMsTextChipW(scoutTxt, fs, GsxSx(g_msDense ? 48 : 80)),
                 "ST_SCOUT_BG", "ST_SCOUT", scoutTxt, scoutBg, scoutFg, fs);
   string sprTxt = snap.ignoreSpread ? "IGN" : "SPREAD";
   color sprBg = snap.ignoreSpread ? C'56,40,18' : C'28,34,46';
   color sprFg = snap.ignoreSpread ? g_msColAccent : g_msColMuted;
   if(g_msShowButtons)
      GsxMsPackPill(lay, GsxMsTextChipW(sprTxt, fs, GsxSx(g_msDense ? 44 : 64)),
                    "ST_SPR_BG", "BTN_SPREAD", sprTxt, sprBg, sprFg, fs);
   else
      GsxMsPackPill(lay, GsxMsTextChipW(sprTxt, fs, GsxSx(g_msDense ? 44 : 64)),
                    "ST_SPR_BG", "ST_SPR", sprTxt, sprBg, sprFg, fs);
   string lotTxt = snap.autoLot ? (g_msDense ? "AUTO" : "AUTOLOT") : "FIXED";
   color lotBg = snap.autoLot ? C'18,56,40' : C'28,34,46';
   color lotFg = snap.autoLot ? g_msColBull : g_msColMuted;
   if(g_msShowButtons)
      GsxMsPackPill(lay, GsxMsTextChipW(lotTxt, fs, GsxSx(g_msDense ? 40 : 60)),
                    "ST_LOT_BG", "BTN_AUTOLOT", lotTxt, lotBg, lotFg, fs);
   else
      GsxMsPackPill(lay, GsxMsTextChipW(lotTxt, fs, GsxSx(g_msDense ? 40 : 60)),
                    "ST_LOT_BG", "ST_LOT", lotTxt, lotBg, lotFg, fs);
   string eqTxt = g_msDense
                  ? (snap.eqGuardPct > 0.0 ? StringFormat("EQ%.0f", snap.eqGuardPct) : "EQ0")
                  : GsxRosterEqGuardLabel(snap.eqGuardPct);
   color eqBg = (snap.eqGuardPct > 0.0 ? C'56,40,18' : C'28,34,46');
   color eqFg = (snap.eqGuardPct > 0.0 ? g_msColAccent : g_msColMuted);
   // Status EQ cycles for compact strip; Full Automation uses discrete pads
   if(g_msShowButtons)
      GsxMsPackPill(lay, GsxMsTextChipW(eqTxt, fs, GsxSx(g_msDense ? 40 : 56)),
                    "ST_EQ_BG", "BTN_EQGUARD", eqTxt, eqBg, eqFg, fs);
   else
      GsxMsPackPill(lay, GsxMsTextChipW(eqTxt, fs, GsxSx(g_msDense ? 40 : 56)),
                    "ST_EQ_BG", "ST_EQ", eqTxt, eqBg, eqFg, fs);

   int propW = GsxMsTextChipW(propTxt, fs, GsxSx(72));
   int fltW = GsxMsTextChipW(fltTxt, fs, GsxSx(g_msDense ? 72 : 88));
   // v2.13: always prefer showing Prop chip when space allows
   bool canProp = (lay.packRemain > fltW + propW + chipGap + GsxSp(24));
   GsxMsPackLabel(lay, fltW, "ST_FLT", fltTxt, g_msColText, fs, false);
   if(canProp)
     {
      if(!propOk)
         GsxMsPackPill(lay, propW, "ST_PROP_BG", "ST_PROP", propTxt,
                       C'56,24,28', g_msColBear, fs);
      else
         GsxMsPackPill(lay, propW, "ST_PROP_BG", "ST_PROP", propTxt,
                       C'18,56,40', g_msColBull, fs);
     }
   else
     {
      ObjectDelete(0, GSXMS_PFX + "ST_PROP");
      ObjectDelete(0, GSXMS_PFX + "ST_PROP_BG");
     }

   GsxLaySlot s;
   GsxLayPackFlex(lay, s);
   if(s.w < GsxSp(g_msDense ? 56 : 90))
      ObjectDelete(0, GSXMS_PFX + "ST_TG");
   else
     {
      string tgFull = StringFormat("TG %s · %d/%d q%d",
                                   snap.tgStatus, snap.tgSent, snap.tgFail, snap.tgQueue);
      string localErr = GsxTgLastError();
      bool showErr = (localErr != "" &&
                      (snap.tgStatus == "Error" ||
                       snap.tgStatus == "Connected" ||
                       StringFind(localErr, "skip ") == 0 ||
                       (snap.tgFail > 0 && snap.tgStatus != "Verified")));
      if(showErr)
        {
         string clip = localErr;
         if(StringLen(clip) > 28)
            clip = StringSubstr(clip, 0, 28);
         tgFull = StringFormat("TG %s · %s", snap.tgStatus, clip);
        }
      string tgTxt = (g_msDense || s.w < GsxMsTextChipW(tgFull, fs, GsxSx(120)))
                     ? ("TG " + snap.tgStatus)
                     : tgFull;
      GsxPanelSlotLabel("ST_TG", s, tgTxt,
                        (snap.tgStatus == "Verified" ? g_msColBull :
                         (snap.tgStatus == "Error" ? g_msColBear :
                          (snap.tgStatus == "Connected" ? g_msColAccent : g_msColMuted))),
                        fs, false);
     }

   if(g_msShowButtons)
     {
      s.x = lay.x0 + statusAvail + chipGap;
      s.y = lay.packY;
      s.w = verifyW;
      s.h = rowH;
      if(s.x + s.w > lay.x0 + lay.contentW)
         s.w = MathMax(1, lay.x0 + lay.contentW - s.x);
      GsxPanelSlotButtonPad("BTN_TG_VERIFY", s,
                            g_msDense ? "Vfy" : "Verify",
                            g_msColBg, g_msColAccent, pad);
     }

   GsxLayAdvance(lay, rowH);
   GsxMsBandGutter(lay, rowH);
  }

void GsxMsDrawSessionStrip(GsxLayCtx &lay, const GsxSessionClockState &st)
  {
   int fs = g_msLay.fontSmall;
   int pad = MathMax(1, g_msLay.btnPad);
   // One consistent row height so pills/labels share a baseline
   int rowH = MathMax(g_msLay.sessH, MathMax(fs + GsxSp(16), GsxSx(24) + 2 * pad));
   int chipGap = MathMax(GsxSp(8), g_msLay.cellGap);
   GsxLaySetGaps(lay, chipGap, MathMax(g_msLay.bandGap, GsxSp(6)));

   GsxLayRowStart(lay, rowH);
   GsxMsDrawSectionBand("SEC_SS", lay.x0, lay.packY, lay.contentW, rowH);

   // Left rail: SESSION label with clear gap before chips
   string sessLbl = "SESSION";
   int lblW = MathMax(GsxSx(72), GsxMsTextChipW(sessLbl, fs, GsxSx(68)));
   GsxMsPackLabel(lay, lblW, "SS_LBL", sessLbl, g_msColMuted, fs, true);

   color openBg = C'18,56,40';
   color closedBg = C'32,38,50';
   color openFg = g_msColBull;
   color closedFg = g_msColMuted;

   // Short equal-width labels — never clip ("Londor") or crowd Overlap
   string aLbl = "ASIA";
   string lLbl = "LDN";
   string nLbl = "NY";
   string sLbl = "SYD";
   int pillW = MathMax(GsxSx(g_msDense ? 44 : 56),
                       GsxMsTextChipW("ASIA", fs, GsxSx(52)));
   GsxMsPackPill(lay, pillW, "SS_ASIA_BG", "SS_ASIA", aLbl,
                 st.asiaOpen ? openBg : closedBg,
                 st.asiaOpen ? openFg : closedFg, fs);
   GsxMsPackPill(lay, pillW, "SS_LDN_BG", "SS_LDN", lLbl,
                 st.londonOpen ? openBg : closedBg,
                 st.londonOpen ? openFg : closedFg, fs);
   GsxMsPackPill(lay, pillW, "SS_NY_BG", "SS_NY", nLbl,
                 st.nyOpen ? openBg : closedBg,
                 st.nyOpen ? openFg : closedFg, fs);
   GsxMsPackPill(lay, pillW, "SS_SYD_BG", "SS_SYD", sLbl,
                 st.sydneyOpen ? openBg : closedBg,
                 st.sydneyOpen ? openFg : closedFg, fs);

   string gmt = StringFormat("GMT %02d", st.hourGmt);
   int gmtW = MathMax(GsxSx(56), GsxMsTextChipW(gmt, fs, GsxSx(54)));

   string sum = st.overlap ? ("Overlap · " + st.summary) : st.summary;
   if(g_msDense)
      sum = (st.overlap ? "OLAP" : "—");

   // Reserve GMT on the right; flex summary in the middle
   int flexBudget = MathMax(0, lay.packRemain - gmtW - chipGap);
   GsxLaySlot s;
   int saveX = lay.packX;
   int saveRemain = lay.packRemain;
   lay.packRemain = flexBudget;
   GsxLayPackFlex(lay, s);
   if(s.w >= GsxSp(28))
      GsxPanelSlotLabel("SS_SUM", s, sum,
                        st.overlap ? g_msColAccent : g_msColMuted, fs, false);
   else
      ObjectDelete(0, GSXMS_PFX + "SS_SUM");

   lay.packX = saveX + flexBudget + chipGap;
   lay.packRemain = saveRemain - flexBudget - chipGap;
   if(!GsxMsPackLabel(lay, gmtW, "SS_H", gmt, g_msColText, fs, true))
      ObjectDelete(0, GSXMS_PFX + "SS_H");

   GsxLayAdvance(lay, rowH);
   GsxMsBandGutter(lay, rowH);
  }

#include <GSignalX/MultisymbolQuadDraw.mqh>

void GsxMsPanelDrawCompact(const GsxMsSnapshot &snap, const int anchorX, const int anchorY)
  {
   GsxMsLayoutRefresh(true);
   GsxPanelConfigure(GSXMS_PFX, CORNER_LEFT_UPPER, "Segoe UI", 7, g_msColEdge);

   int x = anchorX;
   int y = anchorY;
   int w = g_msLay.width;
   int rh = MathMax(g_msLay.rh, g_msLay.fontRow + GsxSx(8));
   int bh = g_msLay.btnH;
   int cell = MathMax(GsxSx(3), g_msLay.cellGap);
   int pad = MathMax(1, g_msLay.btnPad);
   int n = ArraySize(snap.rows);
   int show = MathMin(n, MathMin(g_msPageSize, 5));

   string roster[];
   int nAll = ArraySize(snap.allRows);
   if(nAll > 0)
     {
      ArrayResize(roster, nAll);
      for(int i = 0; i < nAll; i++)
         roster[i] = snap.allRows[i].symbol;
     }
   else
     {
      ArrayResize(roster, n);
      for(int i = 0; i < n; i++)
         roster[i] = snap.rows[i].symbol;
     }
   string car = GsxMsCarouselCandidate(roster);

   int headH = MathMax(GsxSx(18), g_msLay.fontBig + GsxSx(8));
   int provisionalH = headH + bh + show * rh + GsxSx(16);
   GsxPanelRect("CBG", x - GsxSx(4), y - GsxSx(2), w + GsxSx(8), provisionalH,
                g_msColBg, g_msColBg, false);

   GsxLayCtx lay;
   GsxLayBegin(lay, x, y, w, cell, GsxSx(4));
   GsxLaySlot s;

   GsxTgPublished pub;
   GsxTgReadPublishedStatus(snap.magic, pub);
   string tgLbl = GsxTgStatusLabel(pub.status);

   GsxLayRowStart(lay, headH);
   GsxLayPackFlex(lay, s);
   GsxPanelSlotLabel("CT", s,
                     StringFormat("Roster %d · Fleet %d of %d · %s%s · TG %s",
                                  nAll > 0 ? nAll : n, snap.fleetActive, snap.fleetTarget,
                                  snap.run ? "Running" : "Stopped",
                                  snap.own ? " · Owns chart" : "",
                                  tgLbl),
                     g_msColAccent, g_msLay.fontBig, true);
   GsxLayAdvance(lay, headH);

   int sq = MathMax(GsxSx(28), bh - GsxSx(2));
   int actW = GsxSx(64);
   int carH = MathMax(GsxSx(30), g_msLay.fontBig + GsxSp(14));
   color chipIdle = C'32,38,50';
   GsxLayRowStart(lay, carH);
   // Compact control group: < SYM > … ADD SWAP REM
   string carTxt = (car == "" ? "—" : car);
   int symW = MathMax(GsxSx(84), GsxMsTextChipW(carTxt, g_msLay.fontBig, GsxSx(80)));
   if(GsxLayPack(lay, sq, s))
      GsxPanelSlotButtonPad("BTN_CAR_P", s, "<", chipIdle, g_msColText, pad);
   if(GsxLayPack(lay, symW, s))
      GsxPanelSlotLabelCentered("CAR", s, carTxt,
                                g_msColAccent, g_msLay.fontBig, true);
   if(GsxLayPack(lay, sq, s))
      GsxPanelSlotButtonPad("BTN_CAR_N", s, ">", chipIdle, g_msColText, pad);
   int actNeed = 3 * actW + 2 * lay.gap;
   int spacer = MathMax(GsxSp(8), lay.packRemain - actNeed);
   if(spacer > 0)
     {
      GsxLaySlot skip;
      GsxLayPack(lay, spacer, skip);
     }
   if(GsxLayPack(lay, actW, s))
      GsxPanelSlotButtonPad("BTN_ADD", s, "ADD",
                            (car == "" ? chipIdle : g_msColBull),
                            (car == "" ? g_msColMuted : g_msColBg), pad);
   if(GsxLayPack(lay, actW, s))
      GsxPanelSlotButtonPad("BTN_SWAP", s, "SWAP", chipIdle, g_msColAccent, pad);
   if(GsxLayPack(lay, actW, s))
      GsxPanelSlotButtonPad("BTN_REM", s, "REM", g_msColBear, g_msColBg, pad);
   GsxLayAdvance(lay, carH);

   int pageH = MathMax(GsxSx(20), g_msLay.fontSmall + GsxSx(8));
   GsxLayRowStart(lay, pageH);
   int pageNav = MathMax(GsxSx(28), pageH);
   int pageAvail = MathMax(GsxSx(40), lay.contentW - 2 * pageNav - 2 * cell);
   lay.packRemain = pageAvail;
   if(GsxLayPack(lay, pageNav, s))
      GsxPanelSlotButtonPad("BTN_PAGE_P", s, "<", chipIdle, g_msColText, pad);
   GsxLayPackFlex(lay, s);
   GsxPanelSlotLabel("PG", s,
                     StringFormat("Page %d / %d", snap.page + 1, MathMax(1, snap.pageCount)),
                     g_msColText, g_msLay.fontSmall, false);
   s.x = x + pageAvail + cell;
   s.y = lay.packY;
   s.w = pageNav;
   s.h = pageH;
   GsxPanelSlotButtonPad("BTN_PAGE_N", s, ">", chipIdle, g_msColText, pad);
   GsxLayAdvance(lay, pageH);

   int start = snap.page * g_msPageSize;
   for(int i = 0; i < show; i++)
     {
      int ri = start + i;
      if(ri < 0 || ri >= n)
         break;
      string st = GsxRosterStateLabel(snap.rows[ri].pairState);
      string mode = GsxRosterFollowDirLabel(snap.rows[ri].followDir);
      string age = (snap.rows[ri].signalAgeSec < 0)
                   ? "?—s"
                   : (IntegerToString(snap.rows[ri].signalAgeSec) + "s");
      GsxLayRowStart(lay, rh);
      int remW = MathMax(GsxSx(36), GsxSx(44));
      int lineW = MathMax(GsxSx(40), lay.contentW - g_msLay.stateW - remW - 2 * lay.gap);
      lay.packRemain = lineW;
      GsxLayPackFlex(lay, s);
      string line = StringFormat("%s %s %s %.1f %s%s %s",
                                 snap.rows[ri].symbol,
                                 GsxMsDirCellTxt(snap.rows[ri]),
                                 mode,
                                 snap.rows[ri].floatingPl,
                                 st,
                                 snap.rows[ri].busy ? " OPEN" : "",
                                 age);
      GsxPanelSlotLabel(StringFormat("CR%d", i), s, line,
                        snap.rows[ri].pairState == GSX_PAIR_START
                        ? GsxMsDirCellClr(snap.rows[ri]) : g_msColMuted,
                        g_msLay.fontRow, false);
      s.x = x + lineW + lay.gap;
      s.y = lay.packY;
      s.w = g_msLay.stateW;
      s.h = rh;
      GsxPanelSlotButtonPad("BTN_STATE_" + IntegerToString(i), s, st,
                            GsxMsStateClr(snap.rows[ri].pairState), g_msColBg, pad);
      s.x = x + lineW + lay.gap + g_msLay.stateW + lay.gap;
      s.y = lay.packY;
      s.w = remW;
      s.h = rh;
      GsxPanelSlotButtonPad("BTN_REM_" + IntegerToString(i), s, "X",
                            g_msColBear, g_msColBg, pad);
      GsxLayAdvanceTight(lay, rh + MathMax(0, g_msLay.tableGap));
     }
   GsxMsTrimCompactRows(show);

   int totalH = GsxLayMeasuredH(lay) + GsxSx(8);
   string cbg = GSXMS_PFX + "CBG";
   if(ObjectFind(0, cbg) >= 0)
      ObjectSetInteger(0, cbg, OBJPROP_YSIZE, totalH);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
bool GsxMsPanelSetCat(const int cat)
  {
   GsxRosterCatSet(g_msMagic, cat);
   g_msPage = 0;
   GsxRosterPageSet(g_msMagic, 0);
   g_msLastAction = "cat " + IntegerToString(cat);
   return(true);
  }

bool GsxMsPanelApplyPractice(const int band, const int cost, const int style)
  {
   GsxRosterPracBandSet(g_msMagic, band);
   GsxRosterPracCostSet(g_msMagic, cost);
   GsxRosterPracStyleSet(g_msMagic, style);

   GsxPracticeProfile p;
   GsxPracticeBuild(band, cost, style, p);
   GsxRosterFleetTargetSet(g_msMagic, p.fleetTarget);
   GsxRosterCatSet(g_msMagic, p.softCat);
   g_msPage = 0;
   GsxRosterPageSet(g_msMagic, 0);

   // Push live Scouter floors (desk soft-apply → Core overrides without Service restart)
   if(g_msScoutLinkEnable && g_msScoutInstanceID > 0)
     {
      GsxScoutFloorsSet(g_msScoutInstanceID, p.asapFloor, p.minWin, p.lockArm);
      g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " " + p.label +
                       " fleet=" + IntegerToString(p.fleetTarget) +
                       " floor=" + DoubleToString(p.asapFloor, 2);
     }
   else
     {
      g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " " + p.label +
                       " fleet=" + IntegerToString(p.fleetTarget) +
                       " (scout unlink — load .set for floors)";
     }
   return(true);
  }

bool GsxMsPanelOnChartEvent(const int id,
                            const long &lparam,
                            const double &dparam,
                            const string &sparam)
  {
   // Wheel over Trade Center / compact strip → page step (consume to keep chart zoom).
   if(id == CHARTEVENT_MOUSE_WHEEL)
     {
      int mx = (int)(short)lparam;
      int my = (int)(short)(lparam >> 16);
      int delta = (int)dparam;
      if(!GsxMsHitTestPanel(mx, my))
         return(false);
      // Scroll up (delta>0) → previous page; scroll down → next (clamped).
      if(delta > 0)
         GsxMsPageStep(-1);
      else if(delta < 0)
         GsxMsPageStep(1);
      return(true);
     }

   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(StringFind(sparam, GSXMS_PFX) != 0)
         return(false);

      string tag = StringSubstr(sparam, StringLen(GSXMS_PFX));
      // Flat chips use RECTANGLE_LABEL; map label clicks and clear selection
      if(StringLen(tag) > 3 && StringSubstr(tag, StringLen(tag) - 3) == "_TX")
         tag = StringSubstr(tag, 0, StringLen(tag) - 3);
      ObjectSetInteger(0, GSXMS_PFX + tag, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);

      if(tag == "TITLE")
        {
         g_msDragging = true;
         g_msDragOffSet = false;
         return(true);
        }

      if(tag == "BTN_PLAY" || tag == "ST_RUN" || tag == "ST_RUN_BG")
        {
         GsxFleetServiceRunSet(g_msMagic, true);
         GsxRosterDrillKickSet(g_msMagic); // restart drill even if already PLAY
         GsxScoutRunSetLinked(g_msScoutLinkEnable, g_msScoutInstanceID, true);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " PLAY";
         GsxMsSettingsClick("PLAY");
         return(true);
        }
      if(tag == "BTN_STOP")
        {
         // Entries only — Scouter keeps harvesting open tickets.
         // Cancel working brackets so old pairs cannot still trigger.
         string roster[];
         GsxRosterStoreLoad(g_msMagic, roster);
         GsxMsCancelRosterPendings(g_msMagic, roster, "desk STOP");
         GsxFleetServiceRunSet(g_msMagic, false);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                          " STOP (entries off · pendings cleared · scout runs)";
         GsxMsSettingsClick("STOP");
         return(true);
        }
      if(tag == "BTN_HALT")
        {
         // Pause entries + linked Scouter; never closes tickets.
         string roster[];
         GsxRosterStoreLoad(g_msMagic, roster);
         GsxMsCancelRosterPendings(g_msMagic, roster, "desk HALT");
         GsxFleetServiceRunSet(g_msMagic, false);
         GsxScoutRunSetLinked(g_msScoutLinkEnable, g_msScoutInstanceID, false);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                          " HALT (no closes) · pendings cleared";
         GsxMsSettingsClick("HALT");
         return(true);
        }
      if(tag == "BTN_FOLLOW")
        {
         GsxMsPanelSetFlip(!g_msFlipWait);
         GsxMsSettingsClick(g_msFlipWait ? "FOLLOW WAIT" : "FOLLOW");
         return(true);
        }
      if(tag == "BTN_SPREAD")
        {
         bool ign = GsxRosterSpreadIgnToggle(g_msMagic);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                          (ign ? " IGN spread (desk)" : " SPREAD guard on (desk)");
         GsxMsSettingsClick(ign ? "IGN" : "SPREAD");
         return(true);
        }
      if(tag == "BTN_AUTOLOT")
        {
         bool on = GsxRosterAutoLotToggle(g_msMagic);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                          (on ? " AUTOLOT (desk risk%)" : " FIXED lot (desk)");
         GsxMsSettingsClick("AUTOLOT");
         return(true);
        }
      if(tag == "BTN_EQGUARD")
        {
         double pct = GsxRosterEqGuardCycle(g_msMagic);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " " +
                          GsxRosterEqGuardLabel(pct) + " (desk entries)";
         GsxMsSettingsClick("EQ");
         return(true);
        }
      if(tag == "BTN_EQ_0" || tag == "BTN_EQ_5" || tag == "BTN_EQ_10" || tag == "BTN_EQ_20")
        {
         double pct = 0.0;
         if(tag == "BTN_EQ_5")  pct = 5.0;
         if(tag == "BTN_EQ_10") pct = 10.0;
         if(tag == "BTN_EQ_20") pct = 20.0;
         GsxRosterEqGuardSet(g_msMagic, pct);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " " +
                          GsxRosterEqGuardLabel(pct) + " (desk entries)";
         GsxMsSettingsClick("EQ");
         return(true);
        }
      if(tag == "BTN_DRILL_REKICK")
        {
         if(!GsxFleetServiceRunGet(g_msMagic))
           {
            g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                             " REKICK needs PLAY";
            return(true);
           }
         GsxRosterDrillKickSet(g_msMagic);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                          " DRILL REKICK";
         return(true);
        }
      if(tag == "BTN_FDIR_AUTO" || tag == "BTN_FDIR_BUY" ||
         tag == "BTN_FDIR_SELL" || tag == "BTN_FDIR_WAIT")
        {
         int mode = GSX_FOLLOW_AUTO;
         if(tag == "BTN_FDIR_BUY")  mode = GSX_FOLLOW_BUY;
         if(tag == "BTN_FDIR_SELL") mode = GSX_FOLLOW_SELL;
         if(tag == "BTN_FDIR_WAIT") mode = GSX_FOLLOW_WAIT;
         string roster[];
         GsxRosterStoreLoad(g_msMagic, roster);
         GsxMsPanelSetFollowDirAll(mode, roster);
         GsxMsSettingsClick("FDIR " + GsxRosterFollowDirLabel(mode));
         return(true);
        }
      if(tag == "BTN_PAIR_START_ALL" || tag == "BTN_PAIR_STOP_ALL")
        {
         string roster[];
         GsxRosterStoreLoad(g_msMagic, roster);
         string view[];
         GsxRosterFilterByCat(roster, GsxRosterCatGet(g_msMagic), view);
         int st = (tag == "BTN_PAIR_START_ALL") ? GSX_PAIR_START : GSX_PAIR_STOP;
         if(st == GSX_PAIR_STOP)
           {
            for(int si = 0; si < ArraySize(view); si++)
               GsxMsSoftStopSymbol(view[si], "STOP ALL");
           }
         else
            GsxRosterStateSetAll(g_msMagic, view, st);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " " +
                          GsxRosterStateLabel(st) + " all (" +
                          IntegerToString(ArraySize(view)) + ")";
         GsxMsSettingsClick("PAIR " + GsxRosterStateLabel(st) + " ALL");
         return(true);
        }
      if(tag == "BTN_EVT")
        {
         GsxEventModeToggle(g_msMagic);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                          " EVT " + GsxEventModeLabel(GsxEventModeGet(g_msMagic));
         GsxMsSettingsClick("EVT");
         return(true);
        }
      if(tag == "BTN_CAT_ALL") return(GsxMsPanelSetCat(GSX_CAT_ALL));
      if(tag == "BTN_CAT_FX")  return(GsxMsPanelSetCat(GSX_CAT_FOREX));
      if(tag == "BTN_CAT_CMD") return(GsxMsPanelSetCat(GSX_CAT_COMMODITY));
      if(tag == "BTN_CAT_CR")  return(GsxMsPanelSetCat(GSX_CAT_CRYPTO));

      if(StringFind(tag, "BTN_PRAC_") == 0)
        {
         if(!g_msShowPractice)
            return(true);
        }
      if(tag == "BTN_PRAC_20")
         return(GsxMsPanelApplyPractice(20, GsxRosterPracCostGet(g_msMagic),
                                        GsxRosterPracStyleGet(g_msMagic)));
      if(tag == "BTN_PRAC_50")
         return(GsxMsPanelApplyPractice(50, GsxRosterPracCostGet(g_msMagic),
                                        GsxRosterPracStyleGet(g_msMagic)));
      if(tag == "BTN_PRAC_100")
         return(GsxMsPanelApplyPractice(100, GsxRosterPracCostGet(g_msMagic),
                                        GsxRosterPracStyleGet(g_msMagic)));
      if(tag == "BTN_PRAC_RAW")
         return(GsxMsPanelApplyPractice(GsxRosterPracBandGet(g_msMagic),
                                        GSX_COST_RAW,
                                        GsxRosterPracStyleGet(g_msMagic)));
      if(tag == "BTN_PRAC_STD")
         return(GsxMsPanelApplyPractice(GsxRosterPracBandGet(g_msMagic),
                                        GSX_COST_STANDARD,
                                        GsxRosterPracStyleGet(g_msMagic)));
      if(tag == "BTN_PRAC_SCALP")
         return(GsxMsPanelApplyPractice(GsxRosterPracBandGet(g_msMagic),
                                        GsxRosterPracCostGet(g_msMagic),
                                        GSX_STYLE_SCALP));
      if(tag == "BTN_PRAC_DAY")
         return(GsxMsPanelApplyPractice(GsxRosterPracBandGet(g_msMagic),
                                        GsxRosterPracCostGet(g_msMagic),
                                        GSX_STYLE_DAY));
      if(tag == "BTN_PRAC_SWING")
         return(GsxMsPanelApplyPractice(GsxRosterPracBandGet(g_msMagic),
                                        GsxRosterPracCostGet(g_msMagic),
                                        GSX_STYLE_SWING));

      if(tag == "BTN_FLEET_M")
        {
         int t = GsxRosterFleetTargetGet(g_msMagic);
         if(t <= 0)
            t = g_msDefaultFleet;
         t = MathMax(0, t - 1);
         GsxRosterFleetTargetSet(g_msMagic, t);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                          " fleet=" + IntegerToString(t);
         GsxMsSettingsClick("FLEET");
         return(true);
        }
      if(tag == "BTN_FLEET_P")
        {
         int t = GsxRosterFleetTargetGet(g_msMagic);
         if(t <= 0)
            t = g_msDefaultFleet;
         t = t + 1;
         GsxRosterFleetTargetSet(g_msMagic, t);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                          " fleet=" + IntegerToString(t);
         GsxMsSettingsClick("FLEET");
         return(true);
        }
      if(tag == "BTN_PAGE_P")
        {
         GsxMsPageStep(-1);
         return(true);
        }
      if(tag == "BTN_PAGE_N")
        {
         GsxMsPageStep(1);
         return(true);
        }

      string names[];
      GsxRosterStoreLoad(g_msMagic, names);
      string view[];
      GsxRosterFilterByCat(names, GsxRosterCatGet(g_msMagic), view);

      if(tag == "BTN_CAR_P")
        {
         GsxMsCarouselStep(-1, names);
         g_msLastAction = "carousel <";
         return(true);
        }
      if(tag == "BTN_CAR_N")
        {
         GsxMsCarouselStep(1, names);
         g_msLastAction = "carousel >";
         return(true);
        }
      if(tag == "BTN_ADD")
        {
         string car = GsxMsCarouselCandidate(names);
         string reason = "";
         int cap = GsxRosterClassMaxGet(g_msMagic);
         if(car == "")
           {
            g_msLastAction = "ADD skipped: no Market Watch symbols";
            return(true);
           }
         // Already on desk → re-ARM (START+FOLLOW+PLAY+drill) like chart reattach
         if(GsxMsInRoster(names, car))
           {
            if(GsxRosterActivatePair(g_msMagic, car, names, cap, false, reason))
              {
               g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " " + reason;
               GsxMsCarouselStep(1, names);
               GsxMsSettingsClick("ADD " + car);
              }
            else
              {
               GsxMsCarouselStep(1, names);
               g_msLastAction = "ADD skipped" + (reason == "" ? "" : (": " + reason));
              }
            return(true);
           }
         if(GsxRosterActivatePair(g_msMagic, car, names, cap, true, reason))
           {
            g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " " + reason;
            GsxMsCarouselStep(1, names);
            GsxMsSettingsClick("ADD " + car);
           }
         else
           {
            if(reason == "duplicate")
               GsxMsCarouselStep(1, names);
            g_msLastAction = "ADD skipped" + (reason == "" ? "" : (": " + reason));
           }
         return(true);
        }
      if(tag == "BTN_SWAP")
        {
         string rem = "";
         string carRem = GsxMsCarouselCandidate(names);
         if(carRem != "" && GsxMsInRoster(names, carRem))
            rem = carRem;
         else
           {
            int start = g_msPage * g_msPageSize;
            if(start >= 0 && start < ArraySize(view))
               rem = view[start];
           }
         string addSym = "";
         // Prefer next carousel candidate not already on roster
         int tryN = MathMax(8, ArraySize(names) + 4);
         for(int t = 0; t < tryN; t++)
           {
            GsxMsCarouselStep(1, names);
            string cand = GsxMsCarouselCandidate(names);
            if(cand != "" && !GsxMsInRoster(names, cand) && cand != rem)
              {
               addSym = cand;
               break;
              }
           }
         if(rem == "" || addSym == "")
           {
            g_msLastAction = "SWAP: need remove target + free candidate";
            return(true);
           }
         string reason = "";
         int cap = GsxRosterClassMaxGet(g_msMagic);
         GsxMsRetireSymbol(rem);
         GsxRosterRemove(names, rem);
         if(!GsxRosterAddCapped(names, addSym, cap, reason))
           {
            // rollback rem into list if add failed
            GsxRosterAdd(names, rem);
            GsxRosterOnboardSymbol(g_msMagic, rem);
            GsxRosterStoreSave(g_msMagic, names, true);
            g_msLastAction = "SWAP add failed" + (reason == "" ? "" : (": " + reason));
            return(true);
           }
         GsxRosterOnboardSymbol(g_msMagic, addSym);
         GsxRosterStoreSave(g_msMagic, names, true);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                          " SWAP " + rem + " → " + addSym;
         GsxMsSettingsClick("SWAP");
         return(true);
        }
      if(tag == "BTN_REM")
        {
         // Carousel REM only when candidate is already on the roster (never silent page-first).
         string carRem = GsxMsCarouselCandidate(names);
         if(carRem == "" || !GsxMsInRoster(names, carRem))
           {
            g_msLastAction = "REM: select roster pair on carousel";
            return(true);
           }
         if(GsxRosterRemove(names, carRem))
           {
            GsxMsRetireSymbol(carRem);
            GsxRosterStoreSave(g_msMagic, names, true);
            g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                             " REMOVE " + carRem + " (pendings cancelled)";
            GsxMsSettingsClick("REM " + carRem);
           }
         else
            g_msLastAction = "REMOVE skipped";
         return(true);
        }

      if(StringFind(tag, "BTN_REM_") == 0)
        {
         string numPart = StringSubstr(tag, StringLen("BTN_REM_"));
         int local = (int)StringToInteger(numPart);
         int ri = g_msPage * g_msPageSize + local;
         if(ri < 0 || ri >= ArraySize(view))
           {
            g_msLastAction = "REM: row out of range";
            return(true);
           }
         string rem = view[ri];
         if(rem == "")
           {
            g_msLastAction = "REM: empty row";
            return(true);
           }
         if(GsxRosterRemove(names, rem))
           {
            GsxMsRetireSymbol(rem);
            GsxRosterStoreSave(g_msMagic, names, true);
            g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                             " REMOVE " + rem + " (pendings cancelled)";
            GsxMsSettingsClick("REM " + rem);
           }
         else
            g_msLastAction = "REMOVE skipped " + rem;
         return(true);
        }

      if(StringFind(tag, "BTN_MODE_") == 0)
        {
         string numPart = StringSubstr(tag, StringLen("BTN_MODE_"));
         int local = (int)StringToInteger(numPart);
         int ri = g_msPage * g_msPageSize + local;
         if(ri >= 0 && ri < ArraySize(view))
           {
            int mode = GsxRosterFollowDirCycle(g_msMagic, view[ri]);
            g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                             " " + view[ri] + " Follow " +
                             GsxRosterFollowDirLabel(mode) +
                             " (new entries only)";
            GsxMsSettingsClick("FDIR " + view[ri]);
           }
         return(true);
        }

      if(StringFind(tag, "BTN_STATE_") == 0 || StringFind(tag, "BTN_MUTE_") == 0)
        {
         string numPart = tag;
         if(StringFind(tag, "BTN_STATE_") == 0)
            numPart = StringSubstr(tag, StringLen("BTN_STATE_"));
         else
            numPart = StringSubstr(tag, StringLen("BTN_MUTE_"));
         int local = (int)StringToInteger(numPart);
         int ri = g_msPage * g_msPageSize + local;
         if(ri >= 0 && ri < ArraySize(view))
           {
            int st = GsxRosterStateCycle(g_msMagic, view[ri]);
            if(st == GSX_PAIR_START)
              {
               // Re-arm like chart activate: FOLLOW + PLAY + drill
               GsxRosterFollowDirSet(g_msMagic, view[ri], GSX_FOLLOW_AUTO);
               GsxRosterOnboardKickSet(g_msMagic, view[ri]);
               GsxFleetServiceRunSet(g_msMagic, true);
               GsxRosterDrillKickSet(g_msMagic);
              }
            else
              {
               // STOP/SUSPEND: cancel brackets so this pair cannot still trigger
               GsxMsCancelSymbolPendings(view[ri], g_msMagic, "pair " + GsxRosterStateLabel(st));
               GsxRosterOnboardKickClear(g_msMagic, view[ri]);
              }
            g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                             " " + GsxRosterStateLabel(st) + " " + view[ri] +
                             (st == GSX_PAIR_START ? " · PLAY" : " · pendings cleared");
            GsxMsSettingsClick("STATE " + GsxRosterStateLabel(st));
           }
         return(true);
        }

      return(true);
     }

   if(id == CHARTEVENT_MOUSE_MOVE)
     {
      int mx = (int)lparam;
      int my = (int)dparam;
      int flags = (int)StringToInteger(sparam);
      bool leftDown = ((flags & 1) == 1);

      if(g_msDragging)
        {
         if(!leftDown)
           {
            g_msDragging = false;
            g_msDragOffSet = false;
            GsxMsPanelSavePos();
            return(true);
           }
         if(!g_msDragOffSet)
           {
            g_msDragDX = mx - g_msPanelX;
            g_msDragDY = my - g_msPanelY;
            g_msDragOffSet = true;
           }
         g_msPanelX = MathMax(0, mx - g_msDragDX);
         g_msPanelY = MathMax(0, my - g_msDragDY);
         int dragH = (g_msLastTotalH > GsxSx(120) ? g_msLastTotalH : GsxSx(480));
         GsxPanelClampPos(g_msPanelX, g_msPanelY, g_msPanelWidth, dragH);
         return(true);
        }

      if(leftDown && GsxMsHitTitle(mx, my))
        {
         g_msDragging = true;
         g_msDragOffSet = false;
         return(true);
        }
     }

   return(false);
  }

#endif // GSX_MULTISYMBOL_PANEL_MQH
//+------------------------------------------------------------------+
