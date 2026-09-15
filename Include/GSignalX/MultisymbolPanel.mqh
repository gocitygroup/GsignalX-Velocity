//+------------------------------------------------------------------+
//|                                         MultisymbolPanel.mqh      |
//|  Full + Compact Trade Center (GSXMS_) — v1.26 categories/events   |
//|  NEVER closes positions.                                          |
//+------------------------------------------------------------------+
#ifndef GSX_MULTISYMBOL_PANEL_MQH
#define GSX_MULTISYMBOL_PANEL_MQH

#include <GSignalX/ChartPanel.mqh>
#include <GSignalX/RosterViewModel.mqh>
#include <GSignalX/RosterStore.mqh>
#include <GSignalX/Fleet.mqh>
#include <GSignalX/SymbolCanon.mqh>
#include <GSignalX/SymbolClass.mqh>
#include <GSignalX/SessionClock.mqh>
#include <GSignalX/TelegramNotifier.mqh>
#include <GSignalX/PracticeSim.mqh>

#define GSXMS_PFX        "GSXMS_"
#define GSXMS_WIDTH      800   // 1x design units (+25% vs 640 for text balance)
#define GSXMS_RH         22
#define GSXMS_TITLE_H    30
#define GSXMS_BTN_H      34
#define GSXMS_BTN_GAP    8
#define GSXMS_STATE_W    90
#define GSXMS_COMPACT_W  525

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
string g_msLastAction    = "";
long   g_msMagic         = 0;
int    g_msPageSize      = 8;
int    g_msPageSizeDefault = 8;
bool   g_msCompact       = false;
bool   g_msShowButtons   = true;
int    g_msDefaultFleet  = 4;
int    g_msRowsDrawn     = 0;
int    g_msClassMax      = GSX_CLASS_SOFT_MAX_DEFAULT;
int    g_msPanelWidth    = GSXMS_WIDTH;
int    g_msRowH          = GSXMS_RH;
double g_msUiScaleReq    = 1.5;
int    g_msTitleH        = GSXMS_TITLE_H;
int    g_msVision        = GSX_VISION_COMFORT;
GsxSessionClockConfig g_msSessionCfg;

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
   if(row.signalStale) parts += (parts == "" ? "" : " · ") + "Stale";
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
      if(row.signalStale) c += "K";
      return(c == "" ? "." : c);
     }
   return(parts);
  }

void GsxMsDrawSectionBand(const string tag, const int x, const int y,
                          const int w, const int h)
  {
   // Stay inside content box [x .. x+w]
   int pad = GsxSx(2);
   GsxPanelRect(tag, x + pad, y, MathMax(GsxSx(40), w - 2 * pad), MathMax(GsxSx(10), h),
                g_msColBand, g_msColEdge, false);
  }

void GsxMsLayoutRefreshClips()
  {
   int textW = MathMax(GsxSx(40), g_msLay.width - GsxSx(16));
   g_msLay.clipEvt   = GsxPanelCharsFit(MathMax(GsxSx(40), textW - GsxSx(90)), g_msLay.fontSmall);
   g_msLay.clipCoach = GsxPanelCharsFit(textW, g_msLay.fontSmall);
   g_msLay.clipTip   = GsxPanelCharsFit(textW, g_msLay.fontSmall);
  }

void GsxMsLayoutRefresh(const bool forCompact)
  {
   GsxPanelSetVision(g_msVision);
   GsxMsApplyVisionPalette();

   int baseW = forCompact ? GSXMS_COMPACT_W : GSXMS_WIDTH;
   if(g_msVision == GSX_VISION_FAR && !forCompact)
      baseW = 875; // +25% vs prior 700 FAR width
   double eff = GsxPanelFitScale(g_msUiScaleReq, baseW, 24);
   GsxPanelSetScale(eff);

   int bump = GsxPanelFontBump();
   int rhDesign = forCompact ? 14 : (GSXMS_RH + (g_msVision == GSX_VISION_FAR ? 4 :
                                                 (g_msVision == GSX_VISION_COMFORT ? 2 : 0)));
   int titleBase = forCompact ? 18 : GSXMS_TITLE_H;
   // Extra FAR title room for Trade Center chrome (still single bump path)
   if(!forCompact && g_msVision == GSX_VISION_FAR)
      titleBase += 2;
   g_msLay.titleDesign = GsxPanelTitleHDesign(titleBase);
   int btnDesign = forCompact ? 22 :
                   (GSXMS_BTN_H + (g_msVision == GSX_VISION_FAR ? 4 :
                                   (g_msVision == GSX_VISION_COMFORT ? 2 : 0)));

   g_msLay.width   = GsxSx(baseW);
   g_msLay.titleH  = GsxSx(g_msLay.titleDesign);
   g_msLay.rh      = GsxSx(rhDesign);
   g_msLay.btnH    = GsxSx(btnDesign);
   g_msLay.btnGap  = GsxSx(GSXMS_BTN_GAP + (g_msVision == GSX_VISION_FAR ? 2 : 0));
   g_msLay.stateW = GsxSx(forCompact ? 56 :
                           (g_msVision == GSX_VISION_FAR ? 84 : GSXMS_STATE_W));
   g_msLay.inset   = GsxSx(g_msVision == GSX_VISION_FAR ? 10 : 8);
   g_msLay.fontBase  = GsxSf((forCompact ? 7 : 9) + bump);
   g_msLay.fontSmall = GsxSf((forCompact ? 7 : 8) + bump);
   g_msLay.fontRow   = GsxSf((forCompact ? 7 : 9) + bump);
   g_msLay.fontBig   = GsxSf((forCompact ? 8 : 11) + bump);

   g_msLay.bw   = GsxSx(128 + (g_msVision == GSX_VISION_FAR ? 8 : 0));
   g_msLay.tw   = GsxSx(70 + (g_msVision == GSX_VISION_FAR ? 6 : 0));
   g_msLay.twCr = GsxSx(80 + (g_msVision == GSX_VISION_FAR ? 8 : 0));
   g_msLay.pb   = GsxSx(44);

   // Spacing: strong statistical gaps (floor + % of row height)
   // Provisional rh for ratio; refined after infoH below
   int rhGuess = MathMax(g_msLay.rh, g_msLay.fontRow + GsxSp(10));
   g_msLay.cellGap = GsxSpRow(g_msVision == GSX_VISION_NEAR ? 5 : 8, rhGuess, 0.16);
   g_msLay.bandGap = GsxSpRow(g_msVision == GSX_VISION_NEAR ? 8 : 10, rhGuess, 0.26);
   g_msLay.tableGap = 0;
   g_msLay.btnPad = GsxSp(3);
   g_msLay.sectionGap = g_msLay.bandGap;

   // Row heights clear glyphs — Service/Session get extra vertical air
   int glyphInfo = g_msLay.fontSmall + GsxSp(14);
   int miniBtn   = MathMax(GsxSx(20), g_msLay.btnH - GsxSp(4));
   int infoH     = MathMax(glyphInfo, miniBtn + 2 * g_msLay.btnPad);
   g_msLay.statusH = infoH;
   g_msLay.sessH   = infoH;
   g_msLay.evtH    = infoH;
   g_msLay.tipH    = g_msLay.fontSmall + GsxSp(8);
   int tblGlyph = g_msLay.fontRow + GsxSp(10);
   g_msLay.rh = MathMax(g_msLay.rh, MathMax(tblGlyph, miniBtn + GsxSp(4)));
   // Re-anchor gaps to final row height so spacing stays proportional
   g_msLay.cellGap = GsxSpRow(g_msVision == GSX_VISION_NEAR ? 5 : 8, g_msLay.rh, 0.16);
   g_msLay.bandGap = GsxSpRow(g_msVision == GSX_VISION_NEAR ? 8 : 10, g_msLay.rh, 0.26);
   g_msLay.sectionGap = g_msLay.bandGap;

   GsxMsLayoutRefreshClips();

   g_msPanelWidth = g_msLay.width;
   g_msRowH       = g_msLay.rh;
   g_msTitleH     = g_msLay.titleH;
  }

//+------------------------------------------------------------------+
//| Adaptive layout: fit scale to chart + narrow-page clamp.         |
//+------------------------------------------------------------------+
void GsxMsPanelApplyAdaptive()
  {
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   if(chartW <= 0)
      chartW = 1280;

   GsxMsLayoutRefresh(false);

   // Narrow threshold in effective on-chart design units (after −40% geom policy)
   double designW = (double)chartW / MathMax(0.01, GsxPanelGetGeomScale());
   if(designW < 900.0)
     {
      g_msCompact = true;
      int fitW = (int)MathMin(GsxSx(650), MathMax(GsxSx(400), chartW - 24));
      g_msPanelWidth = fitW;
      g_msLay.width = fitW;
      g_msPageSize = MathMin(g_msPageSizeDefault, 5);
      if(g_msPageSize < 1) g_msPageSize = 5;
      // Keep table rows tall enough for fonts (never collapse under glyphs)
      int minRh = g_msLay.fontRow + GsxSx(12);
      g_msLay.rh = MathMax(GsxSx(24), minRh);
      g_msRowH = g_msLay.rh;
      g_msColMuted = C'190,200,220';
      // Width changed — refresh clip budgets so columns/labels fit new box
      GsxMsLayoutRefreshClips();
     }
   else
     {
      g_msCompact = false;
      g_msPageSize = g_msPageSizeDefault;
      GsxMsApplyVisionPalette();
     }

   GsxPanelClampPos(g_msPanelX, g_msPanelY, g_msPanelWidth, GsxSx(280));
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
   return("GSX_MS_FLIPWAIT_" + IntegerToString((int)g_msMagic));
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
   GlobalVariableSet(GsxMsFlipVar(), waitMode ? 1.0 : 0.0);
   g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                    (waitMode ? " WAIT" : " FOLLOW");
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
   int total = SymbolsTotal(true);
   if(total <= 0)
      return("");

   if(g_msCarouselIdx < 0)
      g_msCarouselIdx = 0;
   g_msCarouselIdx = g_msCarouselIdx % total;

   int cat = GsxRosterCatGet(g_msMagic);

   for(int attempt = 0; attempt < total; attempt++)
     {
      int idx = (g_msCarouselIdx + attempt) % total;
      string sym = SymbolName(idx, true);
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
   return(SymbolName(g_msCarouselIdx % total, true));
  }

void GsxMsCarouselStep(const int delta, const string &roster[])
  {
   int total = SymbolsTotal(true);
   if(total <= 0)
      return;

   int cat = GsxRosterCatGet(g_msMagic);
   for(int attempt = 0; attempt < total; attempt++)
     {
      g_msCarouselIdx = (g_msCarouselIdx + delta) % total;
      if(g_msCarouselIdx < 0)
         g_msCarouselIdx += total;
      string sym = SymbolName(g_msCarouselIdx, true);
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
      ObjectDelete(0, GSXMS_PFX + "BTN_MUTE_" + IntegerToString(i));
     }
   g_msRowsDrawn = used;
  }

void GsxMsDrawCatTab(const string tag, const GsxLaySlot &slot,
                     const string text, const bool active)
  {
   if(slot.w <= 0)
      return;
   GsxPanelSlotButtonPad(tag, slot, text,
                         active ? g_msColAccent : g_msColBg,
                         active ? g_msColBg : g_msColText,
                         g_msLay.btnPad);
  }

// Exclusive text-chip width from glyph metrics (prevents neighbor overlap)
int GsxMsTextChipW(const string text, const int fontPx, const int minW)
  {
   int n = StringLen(text);
   if(n < 1) n = 1;
   int w = (int)MathRound((double)n * (double)MathMax(1, fontPx) * 0.66) + GsxSp(10);
   return(MathMax(minW, w));
  }

void GsxMsBandGutter(GsxLayCtx &lay, const int rowH)
  {
   lay.cursorY += GsxSpRow(10, MathMax(1, rowH), 0.30);
  }

void GsxMsDrawPill(const string tagBg, const string tagTx, const GsxLaySlot &slot,
                   const string text, const color bg, const color fg, const int fontPx)
  {
   if(slot.w <= 0 || slot.h <= 0)
     {
      ObjectDelete(0, GSXMS_PFX + tagBg);
      ObjectDelete(0, GSXMS_PFX + tagTx);
      return;
     }
   int inset = MathMax(1, GsxSp(2));
   int rx = slot.x + inset;
   int ry = slot.y + inset;
   int rw = MathMax(1, slot.w - 2 * inset);
   int rh = MathMax(1, slot.h - 2 * inset);
   GsxPanelRect(tagBg, rx, ry, rw, rh, bg, g_msColEdge, false);
   GsxLaySlot lab;
   lab.x = rx;
   lab.y = ry;
   lab.w = rw;
   lab.h = rh;
   GsxPanelSlotLabel(tagTx, lab, text, fg, fontPx, true);
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

bool GsxMsPackPill(GsxLayCtx &lay, const int wantW,
                   const string tagBg, const string tagTx, const string text,
                   const color bg, const color fg, const int fontPx)
  {
   GsxLaySlot s;
   if(!GsxLayPack(lay, wantW, s))
     {
      ObjectDelete(0, GSXMS_PFX + tagBg);
      ObjectDelete(0, GSXMS_PFX + tagTx);
      return(false);
     }
   GsxMsDrawPill(tagBg, tagTx, s, text, bg, fg, fontPx);
   return(true);
  }

void GsxMsDrawStatusRow(GsxLayCtx &lay, const GsxMsSnapshot &snap)
  {
   int fs = g_msLay.fontSmall;
   int pad = MathMax(g_msLay.btnPad, GsxSp(2));
   int rowH = MathMax(g_msLay.statusH, fs + GsxSp(16));
   if(g_msShowButtons)
      rowH = MathMax(rowH, GsxSx(24) + 2 * pad);
   int chipGap = MathMax(g_msLay.cellGap, GsxSp(8));
   GsxLaySetGaps(lay, chipGap, MathMax(g_msLay.bandGap, GsxSpRow(10, rowH, 0.32)));

   GsxLayRowStart(lay, rowH);
   GsxMsDrawSectionBand("SEC_ST", lay.x0, lay.packY, lay.contentW, rowH);

   int verifyW = 0;
   if(g_msShowButtons)
      verifyW = MathMax(GsxSx(72), GsxMsTextChipW("Verify", fs, GsxSx(68)));
   int statusAvail = lay.contentW;
   if(verifyW > 0)
      statusAvail = MathMax(GsxSp(80), lay.contentW - verifyW - chipGap);
   lay.packRemain = statusAvail;

   bool propOk = (StringFind(snap.propStatus, "LOCK") < 0);
   string ownTxt = snap.own ? "Owns chart" : "Service";
   string runTxt = snap.run ? "RUNNING" : "STOPPED";
   string fltTxt = StringFormat("Fleet %d/%d", snap.fleetActive, snap.fleetTarget);
   if(MathAbs(snap.fleetPl) >= 0.005)
      fltTxt += StringFormat(" · %+.2f", snap.fleetPl);
   string propTxt = "Prop " + (snap.propStatus == "" ? "OK" : snap.propStatus);

   color ownBg = snap.own ? C'18,56,40' : C'28,34,46';
   color ownFg = snap.own ? g_msColBull : g_msColMuted;
   color runBg = snap.run ? C'18,56,40' : C'56,24,28';
   color runFg = snap.run ? g_msColBull : g_msColBear;

   GsxMsPackPill(lay, GsxMsTextChipW(ownTxt, fs, GsxSx(72)),
                 "ST_OWN_BG", "ST_OWN", ownTxt, ownBg, ownFg, fs);
   GsxMsPackPill(lay, GsxMsTextChipW(runTxt, fs, GsxSx(76)),
                 "ST_RUN_BG", "ST_RUN", runTxt, runBg, runFg, fs);

   int propW = GsxMsTextChipW(propTxt, fs, GsxSx(72));
   int fltW = GsxMsTextChipW(fltTxt, fs, GsxSx(88));
   bool canProp = (lay.packRemain > fltW + propW + chipGap + GsxSp(48));
   GsxMsPackLabel(lay, fltW, "ST_FLT", fltTxt, g_msColText, fs, false);
   if(canProp)
     {
      if(!propOk)
         GsxMsPackPill(lay, propW, "ST_PROP_BG", "ST_PROP", propTxt,
                       C'56,24,28', g_msColBear, fs);
      else
        {
         ObjectDelete(0, GSXMS_PFX + "ST_PROP_BG");
         GsxMsPackLabel(lay, propW, "ST_PROP", propTxt, g_msColBull, fs, true);
        }
     }
   else
     {
      ObjectDelete(0, GSXMS_PFX + "ST_PROP");
      ObjectDelete(0, GSXMS_PFX + "ST_PROP_BG");
     }

   GsxLaySlot s;
   GsxLayPackFlex(lay, s);
   if(s.w < GsxSp(90))
      ObjectDelete(0, GSXMS_PFX + "ST_TG");
   else
     {
      string tgFull = StringFormat("TG %s · %d/%d q%d",
                                   snap.tgStatus, snap.tgSent, snap.tgFail, snap.tgQueue);
      string tgTxt = (s.w < GsxMsTextChipW(tgFull, fs, GsxSx(120)))
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
      GsxPanelSlotButtonPad("BTN_TG_VERIFY", s, "Verify", g_msColBg, g_msColAccent, pad);
     }

   GsxLayAdvance(lay, rowH);
   GsxMsBandGutter(lay, rowH);
  }

void GsxMsDrawSessionStrip(GsxLayCtx &lay, const GsxSessionClockState &st)
  {
   int fs = g_msLay.fontSmall;
   int rowH = MathMax(g_msLay.sessH, fs + GsxSp(16));
   int chipGap = MathMax(g_msLay.cellGap, GsxSp(8));
   GsxLaySetGaps(lay, chipGap, MathMax(g_msLay.bandGap, GsxSpRow(10, rowH, 0.32)));

   GsxLayRowStart(lay, rowH);
   GsxMsDrawSectionBand("SEC_SS", lay.x0, lay.packY, lay.contentW, rowH);

   GsxMsPackLabel(lay, GsxMsTextChipW("Session", fs, GsxSx(58)),
                  "SS_LBL", "Session", g_msColMuted, fs, true);

   color openBg = C'18,56,40';
   color closedBg = C'28,34,46';
   color openFg = g_msColBull;
   color closedFg = g_msColMuted;

   GsxMsPackPill(lay, GsxMsTextChipW("Asia", fs, GsxSx(42)),
                 "SS_ASIA_BG", "SS_ASIA", "Asia",
                 st.asiaOpen ? openBg : closedBg,
                 st.asiaOpen ? openFg : closedFg, fs);
   GsxMsPackPill(lay, GsxMsTextChipW("London", fs, GsxSx(58)),
                 "SS_LDN_BG", "SS_LDN", "London",
                 st.londonOpen ? openBg : closedBg,
                 st.londonOpen ? openFg : closedFg, fs);
   GsxMsPackPill(lay, GsxMsTextChipW("NY", fs, GsxSx(34)),
                 "SS_NY_BG", "SS_NY", "NY",
                 st.nyOpen ? openBg : closedBg,
                 st.nyOpen ? openFg : closedFg, fs);

   string sum = st.overlap ? ("Overlap · " + st.summary) : st.summary;
   string gmt = StringFormat("GMT %02d", st.hourGmt);
   int gmtW = GsxMsTextChipW(gmt, fs, GsxSx(56));
   int sydW = GsxMsTextChipW("Sydney", fs, GsxSx(54));

   bool showGmt = (lay.packRemain > gmtW + chipGap + GsxSp(40));
   bool showSyd = (lay.packRemain > sydW + (showGmt ? gmtW + chipGap : 0) + GsxSp(36));
   if(showSyd)
      GsxMsPackPill(lay, sydW, "SS_SYD_BG", "SS_SYD", "Sydney",
                    st.sydneyOpen ? openBg : closedBg,
                    st.sydneyOpen ? openFg : closedFg, fs);
   else
     {
      ObjectDelete(0, GSXMS_PFX + "SS_SYD");
      ObjectDelete(0, GSXMS_PFX + "SS_SYD_BG");
     }

   int flexBudget = lay.packRemain - (showGmt ? (gmtW + chipGap) : 0);
   if(flexBudget < GsxSp(36))
     {
      showGmt = false;
      flexBudget = lay.packRemain;
      ObjectDelete(0, GSXMS_PFX + "SS_H");
     }

   GsxLaySlot s;
   int saveRemain = lay.packRemain;
   int saveX = lay.packX;
   lay.packRemain = MathMax(0, flexBudget);
   GsxLayPackFlex(lay, s);
   if(s.w >= GsxSp(36))
      GsxPanelSlotLabel("SS_SUM", s, sum,
                        st.overlap ? g_msColAccent : g_msColText, fs, false);
   else
      ObjectDelete(0, GSXMS_PFX + "SS_SUM");

   if(showGmt)
     {
      lay.packX = saveX + flexBudget + chipGap;
      lay.packRemain = saveRemain - flexBudget - chipGap;
      if(!GsxMsPackLabel(lay, gmtW, "SS_H", gmt, g_msColMuted, fs, false))
         ObjectDelete(0, GSXMS_PFX + "SS_H");
     }

   GsxLayAdvance(lay, rowH);
   GsxMsBandGutter(lay, rowH);
  }

//+------------------------------------------------------------------+
void GsxMsPanelDrawFull(const GsxMsSnapshot &snap)
  {
   GsxMsPanelApplyAdaptive();
   GsxPanelConfigure(GSXMS_PFX, CORNER_LEFT_UPPER, "Segoe UI", 9, g_msColEdge);

   int x = g_msPanelX;
   int y = g_msPanelY;
   int w = g_msPanelWidth;
   int rh = g_msLay.rh;
   int cell = g_msLay.cellGap;
   int band = g_msLay.bandGap;
   int bh = g_msLay.btnH;
   int pad = g_msLay.btnPad;
   int fs = g_msLay.fontSmall;
   int fr = g_msLay.fontRow;
   int btnRowGap = MathMax(GsxSx(4), band / 2);

   int page = snap.page;
   int pageCount = MathMax(1, snap.pageCount);
   if(page < 0) page = 0;
   if(page >= pageCount) page = pageCount - 1;
   g_msPage = page;

   string roster[];
   int nAll = ArraySize(snap.allRows);
   if(nAll <= 0)
      nAll = ArraySize(snap.rows);
   ArrayResize(roster, MathMax(nAll, ArraySize(snap.rows)));
   if(ArraySize(snap.allRows) > 0)
     {
      ArrayResize(roster, ArraySize(snap.allRows));
      for(int i = 0; i < ArraySize(snap.allRows); i++)
         roster[i] = snap.allRows[i].symbol;
     }
   else
     {
      ArrayResize(roster, ArraySize(snap.rows));
      for(int i = 0; i < ArraySize(snap.rows); i++)
         roster[i] = snap.rows[i].symbol;
     }

   string car = GsxMsCarouselCandidate(roster);
   int n = ArraySize(snap.rows);
   int pageRows = MathMin(g_msPageSize, MathMax(0, n - page * g_msPageSize));

   int provisionalH = g_msLay.titleH + GsxSx(560);
   string visionHint = (g_msVision == GSX_VISION_FAR ? "Far view" :
                        (g_msVision == GSX_VISION_NEAR ? "Near view" : "Comfort"));
   GsxPanelBegin(x, y, w, 9, g_msLay.titleDesign);
   GsxPanelApplyChrome(provisionalH, g_msColBg, g_msColEdge, g_msColTitle,
                       g_msColAccent, g_msColMuted,
                       "Trade Center",
                       StringFormat("%s · magic %I64d", visionHint, snap.magic));
   // TitleH may grow in chrome to clear brand glyphs
   g_msLay.titleH = g_gsxPnlTitleH;
   g_msTitleH = g_gsxPnlTitleH;

   int headerGutter = GsxSpRow(8, g_msLay.titleH, 0.22);
   GsxLayCtx lay;
   GsxLayBegin(lay, x, y + g_msLay.titleH + headerGutter, w, cell, band);
   GsxLaySlot s;
   GsxLaySlot slots[];

   int verifyW = MathMax(GsxSx(72), GsxMsTextChipW("Verify", fs, GsxSx(68)));

   // ========== 1) Status row (Service / Run / Fleet / Prop / TG / Verify) ==========
   GsxMsDrawStatusRow(lay, snap);

   // ========== 2) Session row ==========
   GsxMsDrawSessionStrip(lay, snap.session);

   // Restore default gaps for the rest of the panel
   GsxLaySetGaps(lay, cell, band);

   // ========== 3) Events row ==========
   int evtH = MathMax(g_msLay.evtH, fs + GsxSp(14));
   if(g_msShowButtons)
      evtH = MathMax(evtH, GsxSx(22) + 2 * pad);
   GsxLayRowStart(lay, evtH);
   GsxMsDrawSectionBand("SEC_EV", lay.x0, lay.packY, lay.contentW, evtH);
   int evtAvail = lay.contentW;
   if(g_msShowButtons)
      evtAvail = MathMax(GsxSp(80), lay.contentW - verifyW - cell);
   lay.packRemain = evtAvail;
   GsxLayPackFlex(lay, s);
   string evt = snap.eventLine;
   if(evt == "")
      evt = "Events · " + GsxEventModeLabel(snap.eventMode) + " · none upcoming";
   if(s.w > 0)
      GsxPanelSlotLabel("EV_LINE", s, evt, g_msColText, fs, false);
   if(g_msShowButtons)
     {
      s.x = x + evtAvail + cell;
      s.y = lay.packY;
      s.w = verifyW;
      s.h = evtH;
      if(s.x + s.w > x + w)
         s.w = MathMax(1, x + w - s.x);
      GsxPanelSlotButtonPad("BTN_EVT", s, GsxEventModeLabel(snap.eventMode),
                            snap.eventMode == GSX_EVT_MODE_SKIP ? g_msColBear : g_msColBull,
                            g_msColBg, pad);
     }
   GsxLayAdvance(lay, evtH);
   GsxMsBandGutter(lay, evtH);

   if(g_msShowButtons)
     {
      // Button stack: tighter vertical gap than major bands
      GsxLaySetGaps(lay, cell, btnRowGap);

      // ========== 4) Command row ==========
      GsxLayRowStart(lay, bh);
      GsxLayEqual(lay, 4, slots);
      if(ArraySize(slots) >= 4)
        {
         GsxPanelSlotButtonPad("BTN_PLAY", slots[0], "PLAY",
                               snap.run ? g_msColBull : g_msColBg,
                               snap.run ? g_msColBg : g_msColText, pad);
         GsxPanelSlotButtonPad("BTN_STOP", slots[1], "STOP",
                               snap.run ? g_msColBg : g_msColBear,
                               snap.run ? g_msColText : g_msColBg, pad);
         GsxPanelSlotButtonPad("BTN_HALT", slots[2], "HALT",
                               g_msColBg, g_msColAccent, pad);
         GsxPanelSlotButtonPad("BTN_FOLLOW", slots[3],
                               g_msFlipWait ? "WAIT" : "FOLLOW",
                               g_msFlipWait ? g_msColAccent : g_msColBull,
                               g_msColBg, pad);
        }
      GsxLayAdvance(lay, bh);

      // ========== 5) Fleet / page row ==========
      int sq = MathMax(GsxSx(36), bh - GsxSx(4));
      GsxLayRowStart(lay, bh);
      if(GsxLayPack(lay, sq, s))
         GsxPanelSlotButtonPad("BTN_FLEET_M", s, "-", g_msColBg, g_msColText, pad);
      if(GsxLayPack(lay, GsxSx(128), s))
         GsxPanelSlotLabel("FNUM", s, "Target fleet " + IntegerToString(snap.fleetTarget),
                           g_msColAccent, GsxSf(10), true);
      if(GsxLayPack(lay, sq, s))
         GsxPanelSlotButtonPad("BTN_FLEET_P", s, "+", g_msColBg, g_msColText, pad);
      if(GsxLayPack(lay, sq, s))
         GsxPanelSlotButtonPad("BTN_PAGE_P", s, "<", g_msColBg, g_msColText, pad);
      if(GsxLayPack(lay, GsxSx(96), s))
         GsxPanelSlotLabel("PG", s, StringFormat("Page %d of %d", page + 1, pageCount),
                           g_msColText, fr, false);
      if(GsxLayPack(lay, sq, s))
         GsxPanelSlotButtonPad("BTN_PAGE_N", s, ">", g_msColBg, g_msColText, pad);
      GsxLayPackFlex(lay, s);
      GsxPanelSlotLabel("SEQ", s, StringFormat("Roster v%.0f", snap.rosterSeq),
                        g_msColMuted, fs, false);
      GsxLayAdvance(lay, bh);

      // ========== 6) Category row (equal tabs + caps) ==========
      GsxLayRowStart(lay, bh);
      int catW = MathMax(GsxSx(56), (lay.contentW - 3 * cell) / 5);
      if(GsxLayPack(lay, catW, s))
         GsxMsDrawCatTab("BTN_CAT_ALL", s, "ALL", snap.catFilter == GSX_CAT_ALL);
      if(GsxLayPack(lay, catW, s))
         GsxMsDrawCatTab("BTN_CAT_FX", s, "FX", snap.catFilter == GSX_CAT_FOREX);
      if(GsxLayPack(lay, catW, s))
         GsxMsDrawCatTab("BTN_CAT_CMD", s, "CMD", snap.catFilter == GSX_CAT_COMMODITY);
      if(GsxLayPack(lay, catW, s))
         GsxMsDrawCatTab("BTN_CAT_CR", s, "CRYPTO", snap.catFilter == GSX_CAT_CRYPTO);
      GsxLayPackFlex(lay, s);
      GsxPanelSlotLabel("CAP", s,
                        StringFormat("Caps  FX %d/%d · CMD %d/%d · Crypto %d/%d",
                                     snap.countFx, snap.classMax,
                                     snap.countCmd, snap.classMax,
                                     snap.countCr, snap.classMax),
                        g_msColMuted, fs, false);
      GsxLayAdvance(lay, bh);

      // ========== 7) Practice — two equal rows (band | cost/style) ==========
      GsxLayRowStart(lay, bh);
      GsxLayEqual(lay, 3, slots);
      if(ArraySize(slots) >= 3)
        {
         GsxMsDrawCatTab("BTN_PRAC_20", slots[0], "20", snap.pracBand == 20);
         GsxMsDrawCatTab("BTN_PRAC_50", slots[1], "50", snap.pracBand == 50);
         GsxMsDrawCatTab("BTN_PRAC_100", slots[2], "100", snap.pracBand == 100);
        }
      GsxLayAdvance(lay, bh);

      GsxLayRowStart(lay, bh);
      GsxLayEqual(lay, 5, slots);
      if(ArraySize(slots) >= 5)
        {
         GsxMsDrawCatTab("BTN_PRAC_RAW", slots[0], "RAW", snap.pracCost == GSX_COST_RAW);
         GsxMsDrawCatTab("BTN_PRAC_STD", slots[1], "STD", snap.pracCost == GSX_COST_STANDARD);
         GsxMsDrawCatTab("BTN_PRAC_SCALP", slots[2], "SCALP", snap.pracStyle == GSX_STYLE_SCALP);
         GsxMsDrawCatTab("BTN_PRAC_DAY", slots[3], "DAY", snap.pracStyle == GSX_STYLE_DAY);
         GsxMsDrawCatTab("BTN_PRAC_SWING", slots[4], "SWING", snap.pracStyle == GSX_STYLE_SWING);
        }
      GsxLayAdvance(lay, bh);

      // Coach + tip (full-width text rows)
      int tipH = MathMax(g_msLay.tipH, fs + GsxSx(8));
      GsxLayRowStart(lay, tipH);
      GsxLayPackFlex(lay, s);
      string coach = snap.coachLine;
      if(coach == "")
         coach = "Practice tip: load matching Service + Scouter .set files";
      GsxPanelSlotLabel("PRAC_COACH", s, coach, g_msColAccent, fs, false);
      GsxLayAdvance(lay, tipH);

      GsxLayRowStart(lay, tipH);
      GsxLayPackFlex(lay, s);
      string tip = snap.tipLine;
      if(tip == "")
         tip = "Tips: pick pairs · watch session · match timeframe";
      GsxPanelSlotLabel("PRAC_TIP", s, tip, g_msColMuted, fs, false);
      GsxLayAdvance(lay, tipH);

      // ========== 8) Add-candidate row (banded: label | < | symbol | > | ADD | REMOVE) ==========
      int carH = MathMax(bh, g_msLay.fontBig + GsxSx(14));
      GsxLayRowStart(lay, carH);
      GsxMsDrawSectionBand("SEC_CAR", lay.x0, lay.packY, lay.contentW, carH);

      int navW = MathMax(GsxSx(40), carH - GsxSx(4));
      int actW = GsxSx(96);
      int labW = GsxSx(88);
      // Reserve nav + actions; symbol gets the flex middle
      int reserved = labW + 2 * navW + 2 * actW + 5 * cell;
      int symW = MathMax(GsxSx(120), lay.contentW - reserved);

      if(GsxLayPack(lay, labW, s))
         GsxPanelSlotLabel("CAR_LBL", s, "Candidate", g_msColMuted, fs, true);
      if(GsxLayPack(lay, navW, s))
         GsxPanelSlotButtonPad("BTN_CAR_P", s, "<", g_msColBg, g_msColText, pad);
      if(GsxLayPack(lay, symW, s))
        {
         string carTxt = (car == "" ? "No market candidate" : car);
         GsxPanelSlotLabel("CAR", s, carTxt, g_msColAccent, g_msLay.fontBig, true);
        }
      else
         ObjectDelete(0, GSXMS_PFX + "CAR");
      if(GsxLayPack(lay, navW, s))
         GsxPanelSlotButtonPad("BTN_CAR_N", s, ">", g_msColBg, g_msColText, pad);
      if(GsxLayPack(lay, actW, s))
         GsxPanelSlotButtonPad("BTN_ADD", s, "ADD",
                               (car == "" ? g_msColBg : g_msColBull),
                               (car == "" ? g_msColMuted : g_msColBg), pad);
      if(GsxLayPack(lay, actW, s))
         GsxPanelSlotButtonPad("BTN_REM", s, "REMOVE", g_msColBear, g_msColBg, pad);
      else
         ObjectDelete(0, GSXMS_PFX + "BTN_REM");
      // Hide stale combined caption if present from older builds
      ObjectDelete(0, GSXMS_PFX + "CAR_HINT");
      GsxLayAdvance(lay, carH);

      // Restore major band gap before table
      GsxLaySetGaps(lay, cell, band);
     }

   // ========== 9) Roster table (header + exclusive data rows) ==========
   int tblTop = lay.cursorY;
   int tblH = rh * (1 + pageRows);
   GsxMsDrawSectionBand("SEC_TBL", x, tblTop, w, tblH);

   int weights[];
   ArrayResize(weights, 7);
   weights[0] = 22;
   weights[1] = 12;
   weights[2] = 10;
   weights[3] = 10;
   weights[4] = 10;
   weights[5] = 20;
   weights[6] = 16;
   GsxLaySlot cols[];
   GsxLayCols(x, lay.cursorY, w, rh, weights, 7, cols);

   if(ArraySize(cols) >= 7)
     {
      GsxPanelSlotLabel("CH_SYM", cols[0], "Symbol", g_msColMuted, fs, true);
      GsxPanelSlotLabel("CH_DIR", cols[1], "Side", g_msColMuted, fs, true);
      GsxPanelSlotLabel("CH_SPR", cols[2], "Spread", g_msColMuted, fs, true);
      GsxPanelSlotLabel("CH_PL",  cols[3], "P/L", g_msColMuted, fs, true);
      GsxPanelSlotLabel("CH_GR",  cols[4], "Grade", g_msColMuted, fs, true);
      GsxPanelSlotLabel("CH_FLG", cols[5],
                        (g_msVision == GSX_VISION_NEAR ? "Flags" : "Status"),
                        g_msColMuted, fs, true);
      GsxPanelSlotLabel("CH_ST",  cols[6], "State", g_msColMuted, fs, true);
     }
   GsxLayAdvanceTight(lay, rh);

   int start = page * g_msPageSize;
   int drawn = 0;
   for(int i = 0; i < g_msPageSize; i++)
     {
      int ri = start + i;
      if(ri >= n)
         break;

      int ry = lay.cursorY;
      if((i % 2) == 1)
         GsxPanelRect(StringFormat("ROW%d_BG", i), x + GsxSx(2), ry,
                      w - GsxSx(4), rh, g_msColZebra, g_msColZebra, false);
      else
         ObjectDelete(0, GSXMS_PFX + StringFormat("ROW%d_BG", i));

      GsxLayCols(x, ry, w, rh, weights, 7, cols);
      if(ArraySize(cols) < 7)
         break;

      color symClr = snap.rows[ri].marketOpen ? g_msColText : g_msColMuted;
      if(snap.rows[ri].pairState == GSX_PAIR_SUSPEND)
         symClr = g_msColMuted;

      string symTxt = snap.rows[ri].symbol + " · " +
                      GsxSymClassLabel((ENUM_GSX_SYM_CLASS)snap.rows[ri].symClass);
      GsxPanelSlotLabel(StringFormat("ROW%d_SYM", i), cols[0], symTxt, symClr, fr, true);

      string sideTxt = GsxMsDirTxt(snap.rows[ri].direction);
      if(snap.rows[ri].signalStale)
         sideTxt = "Stale " + sideTxt;
      GsxPanelSlotLabel(StringFormat("ROW%d_DIR", i), cols[1], sideTxt,
                        snap.rows[ri].signalStale ? g_msColStop
                                                  : GsxMsDirClr(snap.rows[ri].direction),
                        fr, true);
      GsxPanelSlotLabel(StringFormat("ROW%d_SPR", i), cols[2],
                        IntegerToString(snap.rows[ri].spreadPt) + " pt",
                        g_msColText, fr, false);

      color plClr = (snap.rows[ri].floatingPl > 0.0 ? g_msColBull :
                     (snap.rows[ri].floatingPl < 0.0 ? g_msColBear : g_msColMuted));
      GsxPanelSlotLabel(StringFormat("ROW%d_PL", i), cols[3],
                        StringFormat("%+.2f", snap.rows[ri].floatingPl), plClr, fr, true);

      string gr = (snap.rows[ri].gradeScore < 0.0
                   ? "—"
                   : DoubleToString(snap.rows[ri].gradeScore, 1));
      GsxPanelSlotLabel(StringFormat("ROW%d_GR", i), cols[4], gr, g_msColAccent, fr, true);

      string flags = GsxMsFriendlyFlags(snap.rows[ri]);
      GsxPanelSlotLabel(StringFormat("ROW%d_FLG", i), cols[5], flags, g_msColMuted, fr, false);

      int st = snap.rows[ri].pairState;
      GsxLaySlot stSlot;
      stSlot.x = cols[6].x;
      stSlot.y = cols[6].y;
      stSlot.w = cols[6].w;
      stSlot.h = cols[6].h;
      if(stSlot.w > g_msLay.stateW)
        {
         stSlot.x = cols[6].x + cols[6].w - g_msLay.stateW;
         stSlot.w = g_msLay.stateW;
        }
      GsxPanelSlotButtonPad("BTN_STATE_" + IntegerToString(i), stSlot,
                            GsxMsStateBtn(st), GsxMsStateClr(st), g_msColBg, pad);
      drawn++;
      GsxLayAdvanceTight(lay, rh);
     }
   GsxMsTrimRowObjects(drawn);

   // Gap after table before footer
   lay.cursorY += band;

   // ========== 10) Footer rows ==========
   GsxLaySetGaps(lay, cell, MathMax(GsxSx(2), band / 2));
   int rosterN = ArraySize(snap.allRows) > 0 ? ArraySize(snap.allRows) : n;
   int footH = MathMax(rh, fs + GsxSx(8));

   GsxLayRowStart(lay, footH);
   GsxLayPackFlex(lay, s);
   GsxPanelSlotLabel("FT1", s,
                     StringFormat("Positions %d · Fleet P/L %+.2f · Roster %d · View %d",
                                  snap.positions, snap.fleetPl, rosterN, n),
                     g_msColText, fs, false);
   GsxLayAdvance(lay, footH);

   GsxLayRowStart(lay, footH);
   int half = lay.contentW / 2;
   if(GsxLayPack(lay, half, s))
      GsxPanelSlotLabel("FT2", s, "Last · " + g_msLastAction, g_msColMuted, fs, false);
   GsxLayPackFlex(lay, s);
   GsxPanelSlotLabel("FT3", s, "Exits · Scouter", g_msColAccent, fs, true);
   GsxLayAdvance(lay, footH);

   GsxLayRowStart(lay, footH);
   GsxLayPackFlex(lay, s);
   string tgErr = snap.tgLastError;
   string ft4 = (tgErr == ""
                 ? StringFormat("TG %s · sent %d · fail %d · q %d",
                                snap.tgStatus, snap.tgSent, snap.tgFail, snap.tgQueue)
                 : ("TG error · " + tgErr));
   GsxPanelSlotLabel("FT4", s, ft4,
                     (snap.tgStatus == "Error" ? g_msColBear : g_msColMuted),
                     g_msLay.fontSmall, false);
   GsxLayAdvance(lay, footH);

   int contentH = GsxLayMeasuredH(lay);
   int totalH = g_msLay.titleH + headerGutter + contentH + 2 * g_msLay.inset;
   GsxPanelResizeBg(totalH);
   string bgName = GSXMS_PFX + "BG";
   if(ObjectFind(0, bgName) >= 0)
     {
      int inset = g_msLay.inset > 0 ? g_msLay.inset : GsxSx(8);
      ObjectSetInteger(0, bgName, OBJPROP_XSIZE, w + 2 * inset);
     }
   ChartRedraw();
  }

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
                g_msColBg, g_msColEdge, false);

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
   int actW = GsxSx(72);
   int carH = MathMax(bh, g_msLay.fontBig + GsxSx(10));
   GsxLayRowStart(lay, carH);
   int reserved = 2 * sq + 2 * actW + 4 * cell;
   int symW = MathMax(GsxSx(72), lay.contentW - reserved);
   if(GsxLayPack(lay, sq, s))
      GsxPanelSlotButtonPad("BTN_CAR_P", s, "<", g_msColBg, g_msColText, pad);
   if(GsxLayPack(lay, symW, s))
      GsxPanelSlotLabel("CAR", s, (car == "" ? "—" : car),
                        g_msColAccent, g_msLay.fontBig, true);
   if(GsxLayPack(lay, sq, s))
      GsxPanelSlotButtonPad("BTN_CAR_N", s, ">", g_msColBg, g_msColText, pad);
   if(GsxLayPack(lay, actW, s))
      GsxPanelSlotButtonPad("BTN_ADD", s, "ADD",
                            (car == "" ? g_msColBg : g_msColBull),
                            (car == "" ? g_msColMuted : g_msColBg), pad);
   if(GsxLayPack(lay, actW, s))
      GsxPanelSlotButtonPad("BTN_REM", s, "REM", g_msColBear, g_msColBg, pad);
   // Page controls on next micro-row so candidate stays readable
   GsxLayAdvance(lay, carH);

   int pageH = MathMax(GsxSx(18), g_msLay.fontSmall + GsxSx(6));
   GsxLayRowStart(lay, pageH);
   int pageNav = MathMax(GsxSx(28), pageH);
   int pageAvail = MathMax(GsxSx(40), lay.contentW - 2 * pageNav - 2 * cell);
   lay.packRemain = pageAvail;
   if(GsxLayPack(lay, pageNav, s))
      GsxPanelSlotButtonPad("BTN_PAGE_P", s, "<", g_msColBg, g_msColText, pad);
   GsxLayPackFlex(lay, s);
   GsxPanelSlotLabel("PG", s,
                     StringFormat("Page %d / %d", snap.page + 1, MathMax(1, snap.pageCount)),
                     g_msColText, g_msLay.fontSmall, false);
   s.x = x + pageAvail + cell;
   s.y = lay.packY;
   s.w = pageNav;
   s.h = pageH;
   GsxPanelSlotButtonPad("BTN_PAGE_N", s, ">", g_msColBg, g_msColText, pad);
   GsxLayAdvance(lay, pageH);

   int start = snap.page * g_msPageSize;
   for(int i = 0; i < show; i++)
     {
      int ri = start + i;
      if(ri < 0 || ri >= n)
         break;
      string st = GsxRosterStateLabel(snap.rows[ri].pairState);
      GsxLayRowStart(lay, rh);
      int lineW = MathMax(GsxSx(40), lay.contentW - g_msLay.stateW - lay.gap);
      lay.packRemain = lineW;
      GsxLayPackFlex(lay, s);
      string line = StringFormat("%s %s spr%d %.1f %s%s",
                                 snap.rows[ri].symbol,
                                 GsxMsDirTxt(snap.rows[ri].direction),
                                 snap.rows[ri].spreadPt,
                                 snap.rows[ri].floatingPl,
                                 st,
                                 snap.rows[ri].busy ? " B" : "");
      GsxPanelSlotLabel(StringFormat("CR%d", i), s, line,
                        snap.rows[ri].pairState == GSX_PAIR_START ? g_msColText : g_msColMuted,
                        g_msLay.fontRow, false);
      s.x = x + lineW + lay.gap;
      s.y = lay.packY;
      s.w = g_msLay.stateW;
      s.h = rh;
      GsxPanelSlotButtonPad("BTN_STATE_" + IntegerToString(i), s, st,
                            GsxMsStateClr(snap.rows[ri].pairState), g_msColBg, pad);
      GsxLayAdvanceTight(lay, rh);
     }

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
   g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " " + p.label +
                    " fleet=" + IntegerToString(p.fleetTarget) +
                    " (load .set for floors)";
   return(true);
  }

bool GsxMsPanelOnChartEvent(const int id,
                            const long &lparam,
                            const double &dparam,
                            const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(StringFind(sparam, GSXMS_PFX) != 0)
         return(false);

      string tag = StringSubstr(sparam, StringLen(GSXMS_PFX));
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);

      if(tag == "TITLE")
        {
         g_msDragging = true;
         g_msDragOffSet = false;
         return(true);
        }

      if(tag == "BTN_PLAY")
        {
         GsxFleetServiceRunSet(g_msMagic, true);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " PLAY";
         return(true);
        }
      if(tag == "BTN_STOP")
        {
         GsxFleetServiceRunSet(g_msMagic, false);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) + " STOP";
         return(true);
        }
      if(tag == "BTN_HALT")
        {
         GsxFleetServiceRunSet(g_msMagic, false);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                          " HALT (no closes)";
         return(true);
        }
      if(tag == "BTN_FOLLOW")
        {
         GsxMsPanelSetFlip(!g_msFlipWait);
         return(true);
        }
      if(tag == "BTN_EVT")
        {
         GsxEventModeToggle(g_msMagic);
         g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                          " EVT " + GsxEventModeLabel(GsxEventModeGet(g_msMagic));
         return(true);
        }
      if(tag == "BTN_CAT_ALL") return(GsxMsPanelSetCat(GSX_CAT_ALL));
      if(tag == "BTN_CAT_FX")  return(GsxMsPanelSetCat(GSX_CAT_FOREX));
      if(tag == "BTN_CAT_CMD") return(GsxMsPanelSetCat(GSX_CAT_COMMODITY));
      if(tag == "BTN_CAT_CR")  return(GsxMsPanelSetCat(GSX_CAT_CRYPTO));

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
         return(true);
        }
      if(tag == "BTN_PAGE_P")
        {
         g_msPage = MathMax(0, g_msPage - 1);
         GsxRosterPageSet(g_msMagic, g_msPage);
         g_msLastAction = "page " + IntegerToString(g_msPage + 1);
         return(true);
        }
      if(tag == "BTN_PAGE_N")
        {
         g_msPage = g_msPage + 1;
         GsxRosterPageSet(g_msMagic, g_msPage);
         g_msLastAction = "page " + IntegerToString(g_msPage + 1);
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
         if(car != "" && GsxRosterAddCapped(names, car, cap, reason))
           {
            GsxRosterStoreSave(g_msMagic, names, true);
            g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                             " ADD " + car;
            GsxMsCarouselStep(1, names);
           }
         else
            g_msLastAction = "ADD skipped" + (reason == "" ? "" : (": " + reason));
         return(true);
        }
      if(tag == "BTN_REM")
        {
         int start = g_msPage * g_msPageSize;
         if(start >= 0 && start < ArraySize(view))
           {
            string rem = view[start];
            if(GsxRosterRemove(names, rem))
              {
               GsxRosterStoreSave(g_msMagic, names, true);
               g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                                " REMOVE " + rem;
              }
            else
               g_msLastAction = "REMOVE skipped";
           }
         else
            g_msLastAction = "REMOVE skipped";
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
            g_msLastAction = TimeToString(TimeCurrent(), TIME_MINUTES) +
                             " " + GsxRosterStateLabel(st) + " " + view[ri];
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
         GsxPanelClampPos(g_msPanelX, g_msPanelY, g_msPanelWidth, GsxSx(280));
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
