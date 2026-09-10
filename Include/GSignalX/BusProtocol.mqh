//+------------------------------------------------------------------+
//|                                           BusProtocol.mqh         |
//|  GSignalX connector bus — schema version and path helpers         |
//+------------------------------------------------------------------+
#ifndef GSX_BUS_PROTOCOL_MQH
#define GSX_BUS_PROTOCOL_MQH

#define GSX_BUS_VERSION       1
#define GSX_BUS_ROOT          "GSignalX\\bus\\v1"
#define GSX_BUS_TERMINALS     GSX_BUS_ROOT "\\terminals"
#define GSX_BUS_GRADES_FILE   GSX_BUS_ROOT "\\grades\\latest.json"

string GsxBusTerminalDir(const string tid)
  {
   return StringFormat("%s\\%s", GSX_BUS_TERMINALS, tid);
  }

string GsxBusHeartbeatPath(const string tid)
  {
   return GsxBusTerminalDir(tid) + "\\heartbeat.json";
  }

string GsxBusSignalPath(const string tid, const string symbolCanon)
  {
   return StringFormat("%s\\signals\\%s.json", GsxBusTerminalDir(tid), symbolCanon);
  }

string GsxBusScouterPath(const string tid)
  {
   return GsxBusTerminalDir(tid) + "\\scouter\\snapshot.json";
  }

string GsxBusGradesPath()
  {
   return GSX_BUS_GRADES_FILE;
  }

string GsxJsonEscape(string s)
  {
   StringReplace(s, "\\", "\\\\");
   StringReplace(s, "\"", "\\\"");
   StringReplace(s, "\n", "\\n");
   StringReplace(s, "\r", "");
   return s;
  }

string GsxJsonKV_S(const string key, const string value, const bool trailingComma = true)
  {
   string line = StringFormat("\"%s\":\"%s\"", key, GsxJsonEscape(value));
   return trailingComma ? line + "," : line;
  }

string GsxJsonKV_I(const string key, const long value, const bool trailingComma = true)
  {
   string line = StringFormat("\"%s\":%I64d", key, value);
   return trailingComma ? line + "," : line;
  }

string GsxJsonKV_D(const string key, const double value, const bool trailingComma = true)
  {
   string line = StringFormat("\"%s\":%.5f", key, value);
   return trailingComma ? line + "," : line;
  }

string GsxJsonKV_B(const string key, const bool value, const bool trailingComma = true)
  {
   string line = StringFormat("\"%s\":%s", key, (value ? "true" : "false"));
   return trailingComma ? line + "," : line;
  }

//--- naive extractors for fixed-field JSON we control ---------------
string GsxJsonGetString(const string json, const string key, const string def = "")
  {
   string needle = "\"" + key + "\":\"";
   int p = StringFind(json, needle);
   if(p < 0)
      return def;
   p += StringLen(needle);
   int e = StringFind(json, "\"", p);
   if(e < 0)
      return def;
   return StringSubstr(json, p, e - p);
  }

long GsxJsonGetLong(const string json, const string key, const long def = 0)
  {
   string needle = "\"" + key + "\":";
   int p = StringFind(json, needle);
   if(p < 0)
      return def;
   p += StringLen(needle);
   while(p < StringLen(json) && (StringGetCharacter(json, p) == ' ' || StringGetCharacter(json, p) == '\t'))
      p++;
   string num = "";
   while(p < StringLen(json))
     {
      ushort c = StringGetCharacter(json, p);
      if((c >= '0' && c <= '9') || c == '-' || c == '+')
         num += ShortToString(c);
      else
         break;
      p++;
     }
   if(num == "")
      return def;
   return StringToInteger(num);
  }

double GsxJsonGetDouble(const string json, const string key, const double def = 0.0)
  {
   string needle = "\"" + key + "\":";
   int p = StringFind(json, needle);
   if(p < 0)
      return def;
   p += StringLen(needle);
   while(p < StringLen(json) && (StringGetCharacter(json, p) == ' ' || StringGetCharacter(json, p) == '\t'))
      p++;
   string num = "";
   while(p < StringLen(json))
     {
      ushort c = StringGetCharacter(json, p);
      if((c >= '0' && c <= '9') || c == '-' || c == '+' || c == '.' || c == 'e' || c == 'E')
         num += ShortToString(c);
      else
         break;
      p++;
     }
   if(num == "")
      return def;
   return StringToDouble(num);
  }

bool GsxJsonGetBool(const string json, const string key, const bool def = false)
  {
   string needle = "\"" + key + "\":";
   int p = StringFind(json, needle);
   if(p < 0)
      return def;
   p += StringLen(needle);
   if(StringFind(json, "true", p) == p)
      return true;
   if(StringFind(json, "false", p) == p)
      return false;
   return def;
  }

bool GsxJsonVersionOk(const string json)
  {
   long v = GsxJsonGetLong(json, "version", -1);
   return (v == GSX_BUS_VERSION);
  }

#endif
//+------------------------------------------------------------------+
