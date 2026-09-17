//+------------------------------------------------------------------+
//|                                                  ChartPanel.mqh  |
//|  DRY on-chart panel helpers for GSignalX (Scouter-aligned)       |
//+------------------------------------------------------------------+
#ifndef GSX_CHART_PANEL_MQH
#define GSX_CHART_PANEL_MQH

#define GSX_PANEL_MAX_BODY_ROWS 48
#define GSX_UI_SCALE_MIN        0.55
#define GSX_UI_SCALE_MAX        3.0

// Statistical size policy (layout structure unchanged):
//   geometry  → 40% smaller (keep 0.60)
//   type      → Stevens-like power (exp 0.72) so text stays relatively stronger
//   spacing   → space boost + pixel floors so gaps never collapse with the cut
#define GSX_UI_SIZE_KEEP      0.60
#define GSX_UI_TYPE_EXP       0.72
#define GSX_UI_SPACE_BOOST    1.22
#define GSX_UI_SPACE_FLOOR_PX 4
#define GSX_UI_TYPE_FLOOR_PX  7

// Readable at arm's length (NEAR) or across a desk (FAR). COMFORT is default.
enum ENUM_GSX_UI_VISION
  {
   GSX_VISION_NEAR    = 0,  // denser, high-contrast (laptop / short distance)
   GSX_VISION_COMFORT = 1,  // balanced type + spacing (default)
   GSX_VISION_FAR     = 2   // larger type + airy rows (desk / long-sight)
  };

string            g_gsxPnlPfx      = "GSX_";
ENUM_BASE_CORNER  g_gsxPnlCorner   = CORNER_LEFT_UPPER;
string            g_gsxPnlFont     = "Segoe UI";
int               g_gsxPnlFontSize = 9;   // design units (1x)
color             g_gsxPnlEdge     = C'60,70,88';
double            g_gsxUiScale     = 1.0;  // user/fit request (pre-policy)
double            g_gsxUiGeom      = 0.60; // boxes / widths / heights (40% cut)
double            g_gsxUiType      = 0.70; // fonts (optical; ~pow(0.60,0.72))
double            g_gsxUiSpace     = 0.73; // gaps / padding (strong)
int               g_gsxUiVision    = GSX_VISION_COMFORT;

int  g_gsxPnlX       = 12;
int  g_gsxPnlY       = 22;
int  g_gsxPnlW       = 400;
int  g_gsxPnlCol2    = 120;
int  g_gsxPnlRh      = 17;
int  g_gsxPnlTitleH  = 22;
int  g_gsxPnlBodyTop = 0;
int  g_gsxPnlRow     = 0;
int  g_gsxPnlRowsMax = 0;   // high-water for trim

//+------------------------------------------------------------------+
double GsxPanelClampScale(const double scale)
  {
   if(scale < GSX_UI_SCALE_MIN)
      return(GSX_UI_SCALE_MIN);
   if(scale > GSX_UI_SCALE_MAX)
      return(GSX_UI_SCALE_MAX);
   return(scale);
  }

void GsxPanelSetScale(const double scale)
  {
   // User/fit scale kept for GetScale; policy derives geom/type/space
   double u = GsxPanelClampScale(scale);
   g_gsxUiScale = u;
   g_gsxUiGeom  = u * GSX_UI_SIZE_KEEP;
   // Type: u * keep^exp  (less aggressive than linear 40% cut)
   g_gsxUiType  = u * MathPow(GSX_UI_SIZE_KEEP, GSX_UI_TYPE_EXP);
   // Spacing: slightly stronger than geometry so air remains after the cut
   g_gsxUiSpace = u * GSX_UI_SIZE_KEEP * GSX_UI_SPACE_BOOST;
   if(g_gsxUiGeom < 0.35)  g_gsxUiGeom = 0.35;
   if(g_gsxUiType < 0.42)  g_gsxUiType = 0.42;
   if(g_gsxUiSpace < 0.45) g_gsxUiSpace = 0.45;
  }

double GsxPanelGetScale()
  {
   return(g_gsxUiScale);
  }

double GsxPanelGetGeomScale()
  {
   return(g_gsxUiGeom);
  }

double GsxPanelGetTypeScale()
  {
   return(g_gsxUiType);
  }

void GsxPanelSetVision(const int vision)
  {
   if(vision < GSX_VISION_NEAR)
      g_gsxUiVision = GSX_VISION_NEAR;
   else if(vision > GSX_VISION_FAR)
      g_gsxUiVision = GSX_VISION_FAR;
   else
      g_gsxUiVision = vision;
  }

int GsxPanelGetVision()
  {
   return(g_gsxUiVision);
  }

// Extra design-unit leading between rows (vision-aware; +25% vs prior)
int GsxPanelLead()
  {
   if(g_gsxUiVision == GSX_VISION_FAR)
      return(15);
   if(g_gsxUiVision == GSX_VISION_NEAR)
      return(9);
   return(12);
  }

// Value-column offset from panel left (vision-aware; tracks wider panel)
int GsxPanelCol2Off()
  {
   if(g_gsxUiVision == GSX_VISION_FAR)
      return(175);
   if(g_gsxUiVision == GSX_VISION_NEAR)
      return(140);
   return(155);
  }

// Soft font bump in design units for titles/body
int GsxPanelFontBump()
  {
   if(g_gsxUiVision == GSX_VISION_FAR)
      return(2);
   if(g_gsxUiVision == GSX_VISION_NEAR)
      return(0);
   return(1);
  }

string GsxPanelClip(const string text, const int maxChars)
  {
   if(maxChars < 4 || StringLen(text) <= maxChars)
      return(text);
   return(StringSubstr(text, 0, maxChars - 2) + "..");
  }

   // Approx chars that fit in availPx at given font pixel size
int GsxPanelCharsFit(const int availPx, const int fontPx)
  {
   if(availPx <= 0)
      return(4);
   // Slightly conservative so long rows don't kiss the right edge
   double em = MathMax(4.0, (double)MathMax(1, fontPx) * 0.62);
   int c = (int)MathFloor((double)availPx / em);
   if(c < 4) c = 4;
   return(c);
  }

// Design-unit → pixel (geometry: boxes, widths, row heights)
int GsxSx(const int px)
  {
   if(px == 0)
      return(0);
   int v = (int)MathRound((double)px * g_gsxUiGeom);
   if(v == 0 && px != 0)
      return(px > 0 ? 1 : -1);
   return(v);
  }

// Design-unit → font size (optical type scale; floors keep glyphs readable)
int GsxSf(const int font)
  {
   int v = (int)MathRound((double)font * g_gsxUiType);
   if(v < GSX_UI_TYPE_FLOOR_PX)
      v = GSX_UI_TYPE_FLOOR_PX;
   return(v);
  }

// Design-unit → spacing pixel (strong gaps; never below floor)
int GsxSp(const int px)
  {
   if(px == 0)
      return(0);
   int v = (int)MathRound((double)px * g_gsxUiSpace);
   if(v < GSX_UI_SPACE_FLOOR_PX)
      v = GSX_UI_SPACE_FLOOR_PX;
   return(v);
  }

// Statistical gap: max(strong space, fraction of row height)
int GsxSpRow(const int designGap, const int rowH, const double frac)
  {
   int fromSpace = GsxSp(designGap);
   int fromRow = (int)MathRound((double)MathMax(1, rowH) * MathMax(0.05, frac));
   return(MathMax(fromSpace, fromRow));
  }

// Fit requested scale so baseWidth * geomKeep * scale fits chart
double GsxPanelFitScale(const double requested, const int baseWidth, const int margin = 24)
  {
   double req = GsxPanelClampScale(requested);
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   if(chartW <= 0)
      chartW = 1280;
   if(baseWidth <= 0)
      return(req);
   int avail = chartW - margin;
   if(avail < 1)
      avail = 1;
   // Account for 40% size policy so fit uses true on-chart width
   double geomBudget = (double)baseWidth * GSX_UI_SIZE_KEEP;
   if(geomBudget < 1.0)
      geomBudget = 1.0;
   double fit = (double)avail / geomBudget;
   if(fit < req)
      req = fit;
   return(GsxPanelClampScale(req));
  }

void GsxPanelClampPos(int &px, int &py, const int panelW, const int panelH)
  {
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(chartW <= 0) chartW = 1280;
   if(chartH <= 0) chartH = 720;
   int maxX = MathMax(0, chartW - MathMax(40, panelW - 8));
   int maxY = MathMax(0, chartH - MathMax(40, panelH / 4));
   if(px < 0) px = 0;
   if(py < 0) py = 0;
   if(px > maxX) px = maxX;
   if(py > maxY) py = maxY;
  }

//+------------------------------------------------------------------+
//| Slot / pack layout engine (exclusive rectangles, no peer overlap)|
//+------------------------------------------------------------------+
#define GSX_LAY_MAX_SLOTS 16

struct GsxLaySlot
  {
   int x;
   int y;
   int w;
   int h;
  };

struct GsxLayCtx
  {
   int x0;
   int y0;
   int contentW;
   int cursorY;
   int gap;      // horizontal cell gap (used by Pack/Equal)
   int rowGap;   // vertical gap after Advance
   int packX;
   int packY;
   int packH;
   int packRemain;
  };

int GsxPanelTitleHDesign(const int baseTitleH)
  {
   // Vision bump applied exactly once
   if(g_gsxUiVision == GSX_VISION_FAR)
      return(baseTitleH + 6);
   if(g_gsxUiVision == GSX_VISION_COMFORT)
      return(baseTitleH + 4);
   return(baseTitleH);
  }

void GsxLayBegin(GsxLayCtx &ctx, const int x, const int y, const int w,
                 const int cellGap, const int rowGap = -1)
  {
   ctx.x0 = x;
   ctx.y0 = y;
   ctx.contentW = MathMax(1, w);
   ctx.cursorY = y;
   ctx.gap = MathMax(0, cellGap);
   ctx.rowGap = (rowGap < 0 ? ctx.gap : MathMax(0, rowGap));
   ctx.packX = x;
   ctx.packY = y;
   ctx.packH = 0;
   ctx.packRemain = ctx.contentW;
  }

void GsxLaySetGaps(GsxLayCtx &ctx, const int cellGap, const int rowGap)
  {
   ctx.gap = MathMax(0, cellGap);
   ctx.rowGap = MathMax(0, rowGap);
  }

void GsxLayRowStart(GsxLayCtx &ctx, const int rowH)
  {
   ctx.packX = ctx.x0;
   ctx.packY = ctx.cursorY;
   ctx.packH = MathMax(1, rowH);
   ctx.packRemain = ctx.contentW;
  }

bool GsxLayPack(GsxLayCtx &ctx, const int wantW, GsxLaySlot &out)
  {
   int w = wantW;
   if(w < 1) w = 1;
   if(w > ctx.packRemain)
     {
      out.x = 0;
      out.y = 0;
      out.w = 0;
      out.h = 0;
      return(false);
     }
   out.x = ctx.packX;
   out.y = ctx.packY;
   out.w = w;
   out.h = ctx.packH;
   int step = w + ctx.gap;
   ctx.packX += step;
   ctx.packRemain -= step;
   if(ctx.packRemain < 0)
      ctx.packRemain = 0;
   return(true);
  }

void GsxLayPackFlex(GsxLayCtx &ctx, GsxLaySlot &out)
  {
   int w = MathMax(0, ctx.packRemain);
   out.x = ctx.packX;
   out.y = ctx.packY;
   out.w = w;
   out.h = ctx.packH;
   ctx.packX += w;
   ctx.packRemain = 0;
  }

int GsxLayEqual(GsxLayCtx &ctx, const int n, GsxLaySlot &out[])
  {
   ArrayResize(out, 0);
   if(n < 1)
      return(0);
   // Prefer current pack window (supports insets); fall back to full contentW
   int x0 = ctx.packX;
   int avail = ctx.packRemain;
   if(avail < 1)
     {
      x0 = ctx.x0;
      avail = ctx.contentW;
     }
   int gap = MathMax(GsxSp(6), ctx.gap);
   int gaps = gap * (n - 1);
   int each = (avail - gaps) / n;
   if(each < 1)
      each = 1;
   ArrayResize(out, n);
   int x = x0;
   for(int i = 0; i < n; i++)
     {
      int wi = each;
      if(i == n - 1)
         wi = x0 + avail - x;
      if(wi < 1) wi = 1;
      out[i].x = x;
      out[i].y = ctx.packY;
      out[i].w = wi;
      out[i].h = ctx.packH;
      x += wi + gap;
     }
   ctx.packX = x0 + avail;
   ctx.packRemain = 0;
   return(n);
  }

int GsxLayCols(const int x0, const int y, const int contentW, const int h,
               const int &weights[], const int n, GsxLaySlot &out[])
  {
   ArrayResize(out, 0);
   if(n < 1 || contentW < 1)
      return(0);
   int sum = 0;
   for(int i = 0; i < n; i++)
      sum += MathMax(1, weights[i]);
   if(sum < 1) sum = 1;
   ArrayResize(out, n);
   int used = 0;
   for(int i = 0; i < n; i++)
     {
      int wi;
      if(i == n - 1)
         wi = contentW - used;
      else
         wi = contentW * MathMax(1, weights[i]) / sum;
      if(wi < 1) wi = 1;
      out[i].x = x0 + used;
      out[i].y = y;
      out[i].w = wi;
      out[i].h = h;
      used += wi;
     }
   return(n);
  }

void GsxLayAdvance(GsxLayCtx &ctx, const int h)
  {
   ctx.cursorY += MathMax(0, h) + ctx.rowGap;
  }

// Stack table rows with no extra band gap (exclusive tiles)
void GsxLayAdvanceTight(GsxLayCtx &ctx, const int h)
  {
   ctx.cursorY += MathMax(0, h);
  }

int GsxLayMeasuredH(const GsxLayCtx &ctx)
  {
   int h = ctx.cursorY - ctx.y0 - ctx.rowGap;
   if(h < 1) h = 1;
   return(h);
  }

// Split a parent content width into two equal columns (true dual-column / quadrant).
// left/right get independent GsxLayCtx; gutter is the horizontal gap between columns.
void GsxLaySplit2(const int x0, const int y0, const int contentW,
                  const int gutter, const int cellGap, const int rowGap,
                  GsxLayCtx &left, GsxLayCtx &right)
  {
   int g = MathMax(0, gutter);
   int colW = (contentW - g) / 2;
   if(colW < 1)
      colW = 1;
   int rightW = contentW - g - colW;
   if(rightW < 1)
      rightW = 1;
   GsxLayBegin(left, x0, y0, colW, cellGap, rowGap);
   GsxLayBegin(right, x0 + colW + g, y0, rightW, cellGap, rowGap);
  }

// After packing left/right independently, advance parent cursor by max column height.
int GsxLaySplit2MeasuredH(const GsxLayCtx &left, const GsxLayCtx &right)
  {
   return(MathMax(GsxLayMeasuredH(left), GsxLayMeasuredH(right)));
  }

void GsxPanelSlotLabel(const string tag, const GsxLaySlot &slot,
                       const string text, const color clr,
                       const int fontPx, const bool bold)
  {
   if(slot.w <= 0 || slot.h <= 0)
      return;
   int padX = MathMax(GsxSp(3), GsxSp(2));
   int budget = GsxPanelCharsFit(MathMax(4, slot.w - 2 * padX), fontPx);
   // Position by fontPx (not inflated glyph) — keeps text mid-box, avoids bottom clip
   int yOff = MathMax(0, (slot.h - fontPx) / 2);
   if(yOff + fontPx > slot.h)
      yOff = MathMax(0, slot.h - fontPx);
   GsxPanelLabel(tag, slot.x + padX, slot.y + yOff,
                 GsxPanelClip(text, budget), clr, fontPx, bold);
  }

// Centered label inside a slot (for status chips / pills)
void GsxPanelSlotLabelCentered(const string tag, const GsxLaySlot &slot,
                               const string text, const color clr,
                               const int fontPx, const bool bold)
  {
   if(slot.w <= 0 || slot.h <= 0)
      return;
   int padX = MathMax(GsxSp(4), GsxSp(3));
   int budget = GsxPanelCharsFit(MathMax(4, slot.w - 2 * padX), fontPx);
   string clipped = GsxPanelClip(text, budget);
   int yOff = MathMax(0, (slot.h - fontPx) / 2);
   if(yOff + fontPx > slot.h)
      yOff = MathMax(0, slot.h - fontPx);
   int approxW = (int)MathRound((double)StringLen(clipped) * (double)fontPx * 0.58);
   int xOff = MathMax(padX, (slot.w - approxW) / 2);
   if(xOff + approxW > slot.w - padX)
      xOff = padX;
   GsxPanelLabel(tag, slot.x + xOff, slot.y + yOff, clipped, clr, fontPx, bold);
  }

void GsxPanelSlotButton(const string tag, const GsxLaySlot &slot,
                        const string text, const color bg, const color fg)
  {
   if(slot.w <= 0 || slot.h <= 0)
      return;
   GsxPanelButton(tag, slot.x, slot.y, slot.w, slot.h, text, bg, fg);
  }

// Light inset only — heavy pad crushed scaled button height / clipped text
void GsxPanelSlotButtonPad(const string tag, const GsxLaySlot &slot,
                           const string text, const color bg, const color fg,
                           const int pad)
  {
   if(slot.w <= 0 || slot.h <= 0)
      return;
   int p = MathMax(1, MathMin(pad, 2));
   int bw = slot.w - 2 * p;
   int bh = slot.h - 2 * p;
   if(bw < 20 || bh < 16)
     {
      GsxPanelSlotButton(tag, slot, text, bg, fg);
      return;
     }
   GsxPanelButton(tag, slot.x + p, slot.y + p, bw, bh, text, bg, fg);
  }

//+------------------------------------------------------------------+
void GsxPanelConfigure(const string pfx,
                       const ENUM_BASE_CORNER corner,
                       const string font,
                       const int fontSize,
                       const color edge)
  {
   g_gsxPnlPfx      = pfx;
   g_gsxPnlCorner   = corner;
   g_gsxPnlFont     = font;
   g_gsxPnlFontSize = fontSize;
   g_gsxPnlEdge     = edge;
  }

//+------------------------------------------------------------------+
void GsxPanelRect(const string tag, const int x, const int y,
                  const int w, const int h,
                  const color bg, const color edge, const bool selectable)
  {
   string n = g_gsxPnlPfx + tag;
   if(ObjectFind(0, n) >= 0)
     {
      // Never overwrite a live OBJ_BUTTON with a rect
      if((ENUM_OBJECT)ObjectGetInteger(0, n, OBJPROP_TYPE) == OBJ_BUTTON)
         return;
     }
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_BACK, false);
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
     }
   ObjectSetInteger(0, n, OBJPROP_CORNER, g_gsxPnlCorner);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR, edge);
   ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, selectable);
   ObjectSetInteger(0, n, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, selectable ? 5 : 1);
  }

//+------------------------------------------------------------------+
void GsxPanelLabel(const string tag, const int x, const int y,
                   const string text, const color clr,
                   const int size, const bool bold)
  {
   string n = g_gsxPnlPfx + tag;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_BACK, false);
      ObjectSetInteger(0, n, OBJPROP_ZORDER, 50);
     }
   ObjectSetInteger(0, n, OBJPROP_CORNER, g_gsxPnlCorner);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, n, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0, n, OBJPROP_ZORDER, 50);
  }

//+------------------------------------------------------------------+
// Native OBJ_BUTTON — reliable glyph centering. Border=bg softens bevel.
void GsxPanelButton(const string tag, const int x, const int y,
                    const int w, const int h, const string text,
                    const color bg, const color fg)
  {
   string n = g_gsxPnlPfx + tag;
   ObjectDelete(0, n + "_TX"); // leftover from flat-rect experiment
   if(ObjectFind(0, n) >= 0)
     {
      if((ENUM_OBJECT)ObjectGetInteger(0, n, OBJPROP_TYPE) != OBJ_BUTTON)
         ObjectDelete(0, n);
     }
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_ZORDER, 60);
     }
   int bh = MathMax(18, h);
   int bw = MathMax(24, w);
   int fsBtn = MathMax(8, MathMin(GsxSf(g_gsxPnlFontSize + 1), bh - 8));
   ObjectSetInteger(0, n, OBJPROP_CORNER, g_gsxPnlCorner);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, bw);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, bh);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetString(0, n, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fsBtn);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR, fg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_STATE, false);
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, 60);
  }

//+------------------------------------------------------------------+
//| Begin layout. fontSize/titleH are design units (scaled here).    |
//+------------------------------------------------------------------+
void GsxPanelBegin(const int x, const int y, const int w,
                   const int fontSize, const int titleH)
  {
   // titleH is design units AFTER GsxPanelTitleHDesign (single vision bump)
   int bump = GsxPanelFontBump();
   g_gsxPnlX      = x;
   g_gsxPnlY      = y;
   g_gsxPnlW      = w;
   g_gsxPnlRh     = GsxSf(fontSize + bump) + GsxSx(GsxPanelLead());
   g_gsxPnlTitleH = GsxSx(titleH);
   g_gsxPnlCol2   = x + GsxSx(GsxPanelCol2Off());
   g_gsxPnlBodyTop = y + g_gsxPnlTitleH;
   g_gsxPnlRow    = 0;
  }

//+------------------------------------------------------------------+
void GsxPanelRow(const string label, const string value,
                 const color labelClr, const color valueClr, const bool valueBold)
  {
   if(g_gsxPnlRow >= GSX_PANEL_MAX_BODY_ROWS)
      return;
   int yy = g_gsxPnlBodyTop + g_gsxPnlRh * g_gsxPnlRow;
   string li = StringFormat("R%d_L", g_gsxPnlRow);
   string vi = StringFormat("R%d_V", g_gsxPnlRow);
   int fs = GsxSf(g_gsxPnlFontSize + GsxPanelFontBump());
   int valBudget = GsxPanelCharsFit(g_gsxPnlW - (g_gsxPnlCol2 - g_gsxPnlX) - GsxSx(10), fs);
   GsxPanelLabel(li, g_gsxPnlX, yy, GsxPanelClip(label, 18), labelClr, fs, false);
   GsxPanelLabel(vi, g_gsxPnlCol2, yy, GsxPanelClip(value, valBudget), valueClr, fs, valueBold);
   g_gsxPnlRow++;
   if(g_gsxPnlRow > g_gsxPnlRowsMax)
      g_gsxPnlRowsMax = g_gsxPnlRow;
  }

//+------------------------------------------------------------------+
void GsxPanelRowSmall(const string label, const string value,
                      const color labelClr, const color valueClr)
  {
   if(g_gsxPnlRow >= GSX_PANEL_MAX_BODY_ROWS)
      return;
   int yy = g_gsxPnlBodyTop + g_gsxPnlRh * g_gsxPnlRow;
   string li = StringFormat("R%d_L", g_gsxPnlRow);
   string vi = StringFormat("R%d_V", g_gsxPnlRow);
   int fs = GsxSf(g_gsxPnlFontSize + GsxPanelFontBump());
   int fsSm = GsxSf(g_gsxPnlFontSize + GsxPanelFontBump() - 1);
   int valBudget = GsxPanelCharsFit(g_gsxPnlW - (g_gsxPnlCol2 - g_gsxPnlX) - GsxSx(10), fsSm);
   GsxPanelLabel(li, g_gsxPnlX, yy, GsxPanelClip(label, 18), labelClr, fs, false);
   GsxPanelLabel(vi, g_gsxPnlCol2, yy, GsxPanelClip(value, valBudget), valueClr, fsSm, false);
   g_gsxPnlRow++;
   if(g_gsxPnlRow > g_gsxPnlRowsMax)
      g_gsxPnlRowsMax = g_gsxPnlRow;
  }

//+------------------------------------------------------------------+
int GsxPanelRowCount()
  {
   return(g_gsxPnlRow);
  }

//+------------------------------------------------------------------+
int GsxPanelButtonsY()
  {
   return(g_gsxPnlBodyTop + g_gsxPnlRh * g_gsxPnlRow + GsxSx(6));
  }

//+------------------------------------------------------------------+
void GsxPanelTrimBody()
  {
   for(int i = g_gsxPnlRow; i < g_gsxPnlRowsMax; i++)
     {
      ObjectDelete(0, g_gsxPnlPfx + StringFormat("R%d_L", i));
      ObjectDelete(0, g_gsxPnlPfx + StringFormat("R%d_V", i));
     }
   g_gsxPnlRowsMax = g_gsxPnlRow;
  }

//+------------------------------------------------------------------+
void GsxPanelApplyChrome(const int totalH,
                         const color bg, const color edge, const color titleBg,
                         const color titleClr, const color hintClr,
                         const string title, const string hint)
  {
   int inset = GsxSx(g_gsxUiVision == GSX_VISION_FAR ? 12 : 10);
   int boxX = g_gsxPnlX - inset;
   int boxY = g_gsxPnlY - inset;
   int boxW = g_gsxPnlW + 2 * inset;
   int titleFs = g_gsxPnlFontSize + 3 + GsxPanelFontBump() +
                 (g_gsxUiVision == GSX_VISION_FAR ? 1 : 0);
   int titleFsPx = GsxSf(titleFs);
   int hintFsPx = GsxSf(g_gsxPnlFontSize + GsxPanelFontBump() - 1);
   // Title height clears brand glyphs + inner pad (never kisses body)
   int needTitleH = (int)MathRound((double)titleFsPx * 1.35) + GsxSp(12);
   if(g_gsxPnlTitleH < needTitleH)
      g_gsxPnlTitleH = needTitleH;

   // Three exclusive slots: Brand | Context (flex) | Affordance
   int gap = GsxSp(6);
   int dragW = (int)MathRound(4.0 * (double)hintFsPx * 0.66) + GsxSp(12); // "drag"
   if(dragW < GsxSx(40)) dragW = GsxSx(40);
   int brandW = g_gsxPnlW * 30 / 100;
   if(brandW < GsxSx(96)) brandW = GsxSx(96);
   int maxBrand = g_gsxPnlW - dragW - gap * 2 - GsxSx(48);
   if(brandW > maxBrand) brandW = MathMax(GsxSx(72), maxBrand);
   int ctxW = g_gsxPnlW - brandW - dragW - gap * 2;
   if(ctxW < GsxSx(40))
     {
      ctxW = GsxSx(40);
      brandW = MathMax(GsxSx(64), g_gsxPnlW - dragW - ctxW - gap * 2);
     }

   GsxPanelRect("BG", boxX, boxY, boxW, totalH, bg, bg, false);
   GsxPanelRect("TITLE", boxX, boxY, boxW, g_gsxPnlTitleH,
                titleBg, titleBg, true);

   GsxLaySlot sBrand, sCtx, sDrag;
   sBrand.x = g_gsxPnlX;
   sBrand.y = g_gsxPnlY;
   sBrand.w = brandW;
   sBrand.h = g_gsxPnlTitleH;
   sCtx.x = g_gsxPnlX + brandW + gap;
   sCtx.y = g_gsxPnlY;
   sCtx.w = ctxW;
   sCtx.h = g_gsxPnlTitleH;
   sDrag.x = g_gsxPnlX + brandW + gap + ctxW + gap;
   sDrag.y = g_gsxPnlY;
   sDrag.w = dragW;
   sDrag.h = g_gsxPnlTitleH;
   if(sDrag.x + sDrag.w > g_gsxPnlX + g_gsxPnlW)
      sDrag.w = MathMax(1, g_gsxPnlX + g_gsxPnlW - sDrag.x);

   GsxPanelSlotLabel("H1", sBrand, title, titleClr, titleFsPx, true);
   GsxPanelSlotLabel("H2", sCtx, hint, hintClr, hintFsPx, false);
   GsxPanelSlotLabel("H3", sDrag, "drag", hintClr, hintFsPx, false);
  }

void GsxPanelResizeBg(const int totalH)
  {
   string n = g_gsxPnlPfx + "BG";
   if(ObjectFind(0, n) >= 0)
     {
      int inset = GsxSx(g_gsxUiVision == GSX_VISION_FAR ? 12 : 10);
      ObjectSetInteger(0, n, OBJPROP_YSIZE, totalH);
      ObjectSetInteger(0, n, OBJPROP_XSIZE, g_gsxPnlW + 2 * inset);
     }
  }

//+------------------------------------------------------------------+
void GsxPanelDeleteAll()
  {
   ObjectsDeleteAll(0, g_gsxPnlPfx);
   g_gsxPnlRow = 0;
   g_gsxPnlRowsMax = 0;
  }

#endif // GSX_CHART_PANEL_MQH
