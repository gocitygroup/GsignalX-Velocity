//+------------------------------------------------------------------+
//| TpNativeDraw.mqh — chart HLINE + label for TP level               |
//+------------------------------------------------------------------+
#ifndef GSX_TP_NATIVE_DRAW_MQH
#define GSX_TP_NATIVE_DRAW_MQH

#include <GSignalX/TpNative/TpNativeTypes.mqh>

string TpnLineName(const string pfx)
  {
   return(pfx + "TPN_LEVEL");
  }

string TpnLabelName(const string pfx)
  {
   return(pfx + "TPN_LBL");
  }

void TpnDrawClear(const string pfx)
  {
   ObjectDelete(0, TpnLineName(pfx));
   ObjectDelete(0, TpnLabelName(pfx));
  }

void TpnDrawUpdate(const string pfx, const TpnResult &r, const color clr)
  {
   if(!r.active || TpnIsNa(r.level))
     {
      TpnDrawClear(pfx);
      return;
     }

   string ln = TpnLineName(pfx);
   if(ObjectFind(0, ln) < 0)
     {
      ObjectCreate(0, ln, OBJ_HLINE, 0, 0, r.level);
      ObjectSetInteger(0, ln, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, ln, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, ln, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, ln, OBJPROP_WIDTH, 1);
     }
   ObjectSetDouble(0, ln, OBJPROP_PRICE, r.level);
   ObjectSetInteger(0, ln, OBJPROP_COLOR, clr);

   string lb = TpnLabelName(pfx);
   string txt = StringFormat("TP (%s)  %.5f  n=%d", TpnTypeToStr(r.type), r.level, r.sampleCount);
   if(r.hit)
      txt += "  HIT";
   if(ObjectFind(0, lb) < 0)
     {
      ObjectCreate(0, lb, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, lb, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, lb, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, lb, OBJPROP_XDISTANCE, 8);
      ObjectSetInteger(0, lb, OBJPROP_YDISTANCE, 48);
      ObjectSetInteger(0, lb, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lb, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, lb, OBJPROP_FONTSIZE, 8);
     }
   ObjectSetString(0, lb, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, lb, OBJPROP_COLOR, clr);
  }

#endif // GSX_TP_NATIVE_DRAW_MQH
