//+------------------------------------------------------------------+
//| TpNativePersist.mqh — FILE_COMMON snapshot + pending hit queue    |
//+------------------------------------------------------------------+
#ifndef GSX_TP_NATIVE_PERSIST_MQH
#define GSX_TP_NATIVE_PERSIST_MQH

#include <GSignalX/BusIO.mqh>
#include <GSignalX/TpNative/TpNativeEngine.mqh>

#define TPN_SNAP_ROOT     "GSignalX\\tp_native"
#define TPN_PENDING_ROOT  "GSignalX\\tp_native\\pending"

string TpnSnapPath(const string symbol, const int tf)
  {
   string sym = symbol;
   StringReplace(sym, ".", "_");
   StringReplace(sym, "/", "_");
   return(StringFormat("%s\\%s_%d.json", TPN_SNAP_ROOT, sym, tf));
  }

string TpnPendingPath(const string symbol, const int tf, const int barIndex)
  {
   string sym = symbol;
   StringReplace(sym, ".", "_");
   return(StringFormat("%s\\%s_%d_%d.hit", TPN_PENDING_ROOT, sym, tf, barIndex));
  }

string TpnEncodeDoubleArray(const double &arr[], const int n)
  {
   string s = "[";
   for(int i = 0; i < n; i++)
     {
      if(i > 0)
         s += ",";
      s += DoubleToString(arr[i], 8);
     }
   s += "]";
   return(s);
  }

bool TpnParseDoubleArray(const string json, const string key, double &out[])
  {
   string needle = "\"" + key + "\":[";
   int p = StringFind(json, needle);
   if(p < 0)
     {
      ArrayResize(out, 0);
      return(true);
     }
   p += StringLen(needle);
   int e = StringFind(json, "]", p);
   if(e < 0)
      return(false);
   string body = StringSubstr(json, p, e - p);
   string parts[];
   int n = StringSplit(body, ',', parts);
   ArrayResize(out, 0);
   if(body == "" || n <= 0)
      return(true);
   ArrayResize(out, n);
   for(int i = 0; i < n; i++)
     {
      string t = parts[i];
      StringTrimLeft(t);
      StringTrimRight(t);
      out[i] = StringToDouble(t);
     }
   return(true);
  }

string TpnSerializeSnapshot(const TpnEngine &eng, const string symbol, const int tf)
  {
   TpnSettings s = eng.set;
   string body = "{";
   body += GsxJsonKV_I("schemaVersion", TPN_SCHEMA_VERSION);
   body += GsxJsonKV_S("symbol", symbol);
   body += GsxJsonKV_I("timeframe", tf);
   body += "\"settings\":{";
   body += GsxJsonKV_B("enabled", s.enabled);
   body += GsxJsonKV_S("type", TpnTypeToStr(s.type));
   body += GsxJsonKV_B("closeOnHit", s.closeOnHit);
   body += GsxJsonKV_I("period", s.period);
   body += GsxJsonKV_D("mult", s.mult);
   body += GsxJsonKV_S("pivotSource", TpnPivotSourceToStr(s.pivotSource));
   body += GsxJsonKV_S("crossMode", TpnCrossModeToStr(s.crossMode), false);
   body += "},";
   body += "\"state\":{";
   body += "\"highs\":" + TpnEncodeDoubleArray(eng.highs, eng.ringN) + ",";
   body += "\"lows\":" + TpnEncodeDoubleArray(eng.lows, eng.ringN) + ",";
   body += GsxJsonKV_D("line", eng.line);
   body += GsxJsonKV_B("hasPrevSeenLine", eng.hasPrevSeen);
   body += GsxJsonKV_D("prevSeenLine", eng.hasPrevSeen ? eng.prevSeenLine : 0.0);
   body += GsxJsonKV_B("hasPrevClose", eng.hasPrevClose);
   body += GsxJsonKV_D("prevClose", eng.hasPrevClose ? eng.prevClose : 0.0);
   body += GsxJsonKV_B("hasPrevHigh", eng.hasPrevHigh);
   body += GsxJsonKV_D("prevHigh", eng.hasPrevHigh ? eng.prevHigh : 0.0);
   body += GsxJsonKV_B("hasPrevLow", eng.hasPrevLow);
   body += GsxJsonKV_D("prevLow", eng.hasPrevLow ? eng.prevLow : 0.0);
   body += GsxJsonKV_B("hasLastPivot", eng.hasLastPivot);
   body += GsxJsonKV_D("lastPivot", eng.hasLastPivot ? eng.lastPivot : 0.0);
   body += GsxJsonKV_I("lastPivotIndex", eng.lastPivotIndex);
   body += "\"diffs\":" + TpnEncodeDoubleArray(eng.diffs, eng.diffN) + ",";
   body += GsxJsonKV_I("lastProcessedIndex", eng.lastProcessedIndex, false);
   body += "},";
   body += GsxJsonKV_I("savedAt", (long)TimeGMT(), false);
   body += "}";
   return(body);
  }

bool TpnSaveSnapshot(const TpnEngine &eng, const string symbol, const int tf)
  {
   return(GsxBusWriteAtomic(TpnSnapPath(symbol, tf), TpnSerializeSnapshot(eng, symbol, tf)));
  }

bool TpnLoadSnapshot(TpnEngine &eng, const string symbol, const int tf)
  {
   string path = TpnSnapPath(symbol, tf);
   if(!FileIsExist(path, FILE_COMMON))
      return(false);
   string body = GsxBusReadAll(path);
   if(body == "" || StringFind(body, "\"schemaVersion\"") < 0)
     {
      PrintFormat("TpNative: corrupt snapshot %s — rebuild", path);
      return(false);
     }
   if(GsxJsonGetLong(body, "schemaVersion", 0) != TPN_SCHEMA_VERSION)
     {
      PrintFormat("TpNative: unsupported schema — rebuild");
      return(false);
     }

   TpnSettings s;
   TpnSettingsDefaults(s);
   s.enabled = GsxJsonGetBool(body, "enabled", false);
   s.type = TpnTypeFromStr(GsxJsonGetString(body, "type", "MEDIAN"));
   s.closeOnHit = GsxJsonGetBool(body, "closeOnHit", false);
   s.period = (int)GsxJsonGetLong(body, "period", 12);
   s.mult = GsxJsonGetDouble(body, "mult", 2.0);
   s.pivotSource = TpnPivotSourceFromStr(GsxJsonGetString(body, "pivotSource", "ZIGZAG"));
   s.crossMode = TpnCrossModeFromStr(GsxJsonGetString(body, "crossMode", "SERIES"));
   TpnEngSetSettings(eng, s);

   double highs[], lows[], diffs[];
   if(!TpnParseDoubleArray(body, "highs", highs) ||
      !TpnParseDoubleArray(body, "lows", lows) ||
      !TpnParseDoubleArray(body, "diffs", diffs))
      return(false);
   int ringN = ArraySize(highs);
   if(ringN != ArraySize(lows))
      return(false);

   if(!TpnEngImportState(eng, highs, lows, ringN,
                         GsxJsonGetDouble(body, "line", 0.0),
                         GsxJsonGetDouble(body, "prevSeenLine", 0.0),
                         GsxJsonGetBool(body, "hasPrevSeenLine", false),
                         GsxJsonGetDouble(body, "prevClose", 0.0),
                         GsxJsonGetBool(body, "hasPrevClose", false),
                         GsxJsonGetDouble(body, "prevHigh", 0.0),
                         GsxJsonGetBool(body, "hasPrevHigh", false),
                         GsxJsonGetDouble(body, "prevLow", 0.0),
                         GsxJsonGetBool(body, "hasPrevLow", false),
                         GsxJsonGetDouble(body, "lastPivot", 0.0),
                         GsxJsonGetBool(body, "hasLastPivot", false),
                         (int)GsxJsonGetLong(body, "lastPivotIndex", -1),
                         diffs, ArraySize(diffs),
                         (int)GsxJsonGetLong(body, "lastProcessedIndex", -1)))
      return(false);
   // ImportState resets settings — re-apply
   TpnEngSetSettings(eng, s);
   TpnEngSetSymbolTf(eng, symbol, tf);
   return(true);
  }

bool TpnEmitPendingHit(const string symbol, const int tf, const TpnResult &r,
                       const long magic, const bool closeOnHit)
  {
   if(!r.hit || !r.active)
      return(false);
   string path = TpnPendingPath(symbol, tf, r.barIndex);
   if(FileIsExist(path, FILE_COMMON))
      return(false);
   string body = StringFormat("{\"symbol\":\"%s\",\"timeframe\":%d,\"barIndex\":%d,"
                              "\"direction\":\"%s\",\"level\":%.8f,\"magic\":%I64d,"
                              "\"closeOnHit\":%s,\"ts\":%I64d}",
                              symbol, tf, r.barIndex, TpnDirToStr(r.direction),
                              r.level, magic, (closeOnHit ? "true" : "false"),
                              (long)TimeCurrent());
   return(GsxBusWriteAtomic(path, body));
  }

int TpnListPendingHits(string &paths[])
  {
   ArrayResize(paths, 0);
   string name;
   long h = FileFindFirst(TPN_PENDING_ROOT + "\\*.hit", name, FILE_COMMON);
   if(h == INVALID_HANDLE)
      return(0);
   do
     {
      int n = ArraySize(paths);
      ArrayResize(paths, n + 1);
      paths[n] = TPN_PENDING_ROOT + "\\" + name;
     }
   while(FileFindNext(h, name));
   FileFindClose(h);
   return(ArraySize(paths));
  }

bool TpnConsumePending(const string path, string &symbol, int &tf, int &barIndex,
                       string &direction, double &level, long &magic, bool &closeOnHit)
  {
   string body = GsxBusReadAll(path);
   if(body == "")
      return(false);
   symbol = GsxJsonGetString(body, "symbol", "");
   tf = (int)GsxJsonGetLong(body, "timeframe", 0);
   barIndex = (int)GsxJsonGetLong(body, "barIndex", -1);
   direction = GsxJsonGetString(body, "direction", "");
   level = GsxJsonGetDouble(body, "level", 0.0);
   magic = GsxJsonGetLong(body, "magic", 0);
   closeOnHit = GsxJsonGetBool(body, "closeOnHit", false);
   FileDelete(path, FILE_COMMON);
   return(symbol != "");
  }

#endif // GSX_TP_NATIVE_PERSIST_MQH
