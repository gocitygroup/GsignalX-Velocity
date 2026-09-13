//+------------------------------------------------------------------+
//|                                                  ChartPanel.mqh  |
//|  DRY on-chart panel helpers for GSignalX (Scouter-aligned)       |
//+------------------------------------------------------------------+
#ifndef GSX_CHART_PANEL_MQH
#define GSX_CHART_PANEL_MQH

#define GSX_PANEL_MAX_BODY_ROWS 48

string            g_gsxPnlPfx      = "GSX_";
ENUM_BASE_CORNER  g_gsxPnlCorner   = CORNER_LEFT_UPPER;
string            g_gsxPnlFont     = "Segoe UI";
int               g_gsxPnlFontSize = 9;
color             g_gsxPnlEdge     = C'60,70,88';

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
   ObjectSetString(0, n, OBJPROP_FONT, bold ? "Segoe UI Bold" : g_gsxPnlFont);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, 50);
  }

//+------------------------------------------------------------------+
void GsxPanelButton(const string tag, const int x, const int y,
                    const int w, const int h, const string text,
                    const color bg, const color fg)
  {
   string n = g_gsxPnlPfx + tag;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_ZORDER, 60);
      ObjectSetString(0, n, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, n, OBJPROP_FONTSIZE, g_gsxPnlFontSize);
     }
   ObjectSetInteger(0, n, OBJPROP_CORNER, g_gsxPnlCorner);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR, fg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, g_gsxPnlEdge);
   ObjectSetInteger(0, n, OBJPROP_STATE, false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, 60);
  }

//+------------------------------------------------------------------+
void GsxPanelBegin(const int x, const int y, const int w,
                   const int fontSize, const int titleH)
  {
   g_gsxPnlX      = x;
   g_gsxPnlY      = y;
   g_gsxPnlW      = w;
   g_gsxPnlRh     = fontSize + 8;
   g_gsxPnlTitleH = titleH;
   g_gsxPnlCol2   = x + 118;
   g_gsxPnlBodyTop = y + titleH;
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
   GsxPanelLabel(li, g_gsxPnlX, yy, label, labelClr, g_gsxPnlFontSize, false);
   GsxPanelLabel(vi, g_gsxPnlCol2, yy, value, valueClr, g_gsxPnlFontSize, valueBold);
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
   GsxPanelLabel(li, g_gsxPnlX, yy, label, labelClr, g_gsxPnlFontSize, false);
   GsxPanelLabel(vi, g_gsxPnlCol2, yy, value, valueClr, g_gsxPnlFontSize - 1, false);
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
   return(g_gsxPnlBodyTop + g_gsxPnlRh * g_gsxPnlRow + 6);
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
   //--- BG first (behind labels). Do not recreate after body rows or it covers text.
   GsxPanelRect("BG", g_gsxPnlX - 8, g_gsxPnlY - 8, g_gsxPnlW, totalH, bg, edge, false);
   GsxPanelRect("TITLE", g_gsxPnlX - 8, g_gsxPnlY - 8, g_gsxPnlW, g_gsxPnlTitleH,
                titleBg, edge, true);
   GsxPanelLabel("H1", g_gsxPnlX, g_gsxPnlY - 2, title, titleClr, g_gsxPnlFontSize + 3, true);
   GsxPanelLabel("H2", g_gsxPnlX + 88, g_gsxPnlY + 2, hint, hintClr, g_gsxPnlFontSize - 1, false);
  }

//+------------------------------------------------------------------+
//| Resize panel background only (after body rows are known)         |
//+------------------------------------------------------------------+
void GsxPanelResizeBg(const int totalH)
  {
   string n = g_gsxPnlPfx + "BG";
   if(ObjectFind(0, n) >= 0)
      ObjectSetInteger(0, n, OBJPROP_YSIZE, totalH);
  }

//+------------------------------------------------------------------+
void GsxPanelDeleteAll()
  {
   ObjectsDeleteAll(0, g_gsxPnlPfx);
   g_gsxPnlRow = 0;
   g_gsxPnlRowsMax = 0;
  }

#endif // GSX_CHART_PANEL_MQH
