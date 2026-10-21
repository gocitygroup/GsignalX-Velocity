//+------------------------------------------------------------------+
//| TpNativeTypes.mqh — contracts for standalone native TP module     |
//| Namespace: TpNative / TPN_*  (independent of Engines.mqh SBT)     |
//+------------------------------------------------------------------+
#ifndef GSX_TP_NATIVE_TYPES_MQH
#define GSX_TP_NATIVE_TYPES_MQH

#define TPN_SCHEMA_VERSION  1
#define TPN_NA              EMPTY_VALUE

enum ENUM_TPN_TYPE
  {
   TPN_MEDIAN  = 0,
   TPN_AVERAGE = 1
  };

enum ENUM_TPN_PIVOT_SOURCE
  {
   TPN_PIVOT_ZIGZAG   = 0,
   TPN_PIVOT_HIGH_LOW = 1,
   TPN_PIVOT_CLOSE    = 2
  };

enum ENUM_TPN_CROSS_MODE
  {
   TPN_CROSS_SERIES  = 0,  // A1 default: prevSeenLine
   TPN_CROSS_CARRIED = 1
  };

enum ENUM_TPN_SIGNAL
  {
   TPN_SIG_NONE       = 0,
   TPN_SIG_LONG_FLIP  = 1,
   TPN_SIG_SHORT_FLIP = 2
  };

enum ENUM_TPN_DIRECTION
  {
   TPN_DIR_NONE  = 0,
   TPN_DIR_LONG  = 1,
   TPN_DIR_SHORT = -1
  };

struct TpnBar
  {
   int      index;
   datetime time;
   double   high;
   double   low;
   double   close;
  };

struct TpnSettings
  {
   bool                 enabled;
   ENUM_TPN_TYPE        type;
   bool                 closeOnHit;
   int                  period;
   double               mult;
   ENUM_TPN_PIVOT_SOURCE pivotSource;
   ENUM_TPN_CROSS_MODE  crossMode;
   int                  historyBars;  // bootstrap length; 0 = host default
  };

struct TpnResult
  {
   bool              active;
   ENUM_TPN_TYPE     type;
   double            distance;     // TPN_NA if null
   double            level;
   ENUM_TPN_DIRECTION direction;
   int               pivotIndex;   // -1 if null
   double            pivotPrice;
   bool              hit;
   int               sampleCount;
   double            sbtLine;
   ENUM_TPN_SIGNAL   signal;
   int               barIndex;
   datetime          updatedAt;
  };

void TpnSettingsDefaults(TpnSettings &s)
  {
   s.enabled      = false;
   s.type         = TPN_MEDIAN;
   s.closeOnHit   = false;
   s.period       = 12;
   s.mult         = 2.0;
   s.pivotSource  = TPN_PIVOT_ZIGZAG;
   s.crossMode    = TPN_CROSS_SERIES;
   s.historyBars  = 500;
  }

void TpnResultClear(TpnResult &r)
  {
   r.active      = false;
   r.type        = TPN_MEDIAN;
   r.distance    = TPN_NA;
   r.level       = TPN_NA;
   r.direction   = TPN_DIR_NONE;
   r.pivotIndex  = -1;
   r.pivotPrice  = TPN_NA;
   r.hit         = false;
   r.sampleCount = 0;
   r.sbtLine     = TPN_NA;
   r.signal      = TPN_SIG_NONE;
   r.barIndex    = -1;
   r.updatedAt   = 0;
  }

bool TpnIsNa(const double v)
  {
   return(!MathIsValidNumber(v) || v == TPN_NA);
  }

string TpnTypeToStr(const ENUM_TPN_TYPE t)
  {
   return(t == TPN_AVERAGE ? "AVERAGE" : "MEDIAN");
  }

ENUM_TPN_TYPE TpnTypeFromStr(const string s)
  {
   if(s == "AVERAGE" || s == "average")
      return(TPN_AVERAGE);
   return(TPN_MEDIAN);
  }

string TpnPivotSourceToStr(const ENUM_TPN_PIVOT_SOURCE p)
  {
   if(p == TPN_PIVOT_HIGH_LOW) return("HIGH_LOW");
   if(p == TPN_PIVOT_CLOSE)    return("CLOSE");
   return("ZIGZAG");
  }

ENUM_TPN_PIVOT_SOURCE TpnPivotSourceFromStr(const string s)
  {
   if(s == "HIGH_LOW") return(TPN_PIVOT_HIGH_LOW);
   if(s == "CLOSE")    return(TPN_PIVOT_CLOSE);
   return(TPN_PIVOT_ZIGZAG);
  }

string TpnCrossModeToStr(const ENUM_TPN_CROSS_MODE m)
  {
   return(m == TPN_CROSS_CARRIED ? "CARRIED" : "SERIES");
  }

ENUM_TPN_CROSS_MODE TpnCrossModeFromStr(const string s)
  {
   if(s == "CARRIED") return(TPN_CROSS_CARRIED);
   return(TPN_CROSS_SERIES);
  }

string TpnDirToStr(const ENUM_TPN_DIRECTION d)
  {
   if(d == TPN_DIR_LONG)  return("LONG");
   if(d == TPN_DIR_SHORT) return("SHORT");
   return("");
  }

string TpnSignalToStr(const ENUM_TPN_SIGNAL s)
  {
   if(s == TPN_SIG_LONG_FLIP)  return("LONG_FLIP");
   if(s == TPN_SIG_SHORT_FLIP) return("SHORT_FLIP");
   return("");
  }

#endif // GSX_TP_NATIVE_TYPES_MQH
