//+------------------------------------------------------------------+
//|                                                   BusIO.mqh       |
//|  FILE_COMMON atomic JSON read/write + peer terminal discovery     |
//|  v2.01: no delete-gap replace; read retry; register cache+retry   |
//+------------------------------------------------------------------+
#ifndef GSX_BUS_IO_MQH
#define GSX_BUS_IO_MQH

#include <GSignalX/BusProtocol.mqh>
#include <GSignalX/TerminalIdentity.mqh>

#define GSX_BUS_REG_CACHE_MAX  64
#define GSX_BUS_REG_RETRY      3

string g_gsxBusCachedTids[GSX_BUS_REG_CACHE_MAX];
int    g_gsxBusCachedTidN = 0;
string g_gsxBusCachedSigKeys[GSX_BUS_REG_CACHE_MAX];
int    g_gsxBusCachedSigN = 0;

bool GsxEnsureFolderTree(const string relativeFilePath)
  {
   string parts[];
   int n = StringSplit(relativeFilePath, StringGetCharacter("\\", 0), parts);
   if(n <= 1)
      return true;

   string cur = "";
   for(int i = 0; i < n - 1; i++)
     {
      if(parts[i] == "")
         continue;
      if(cur == "")
         cur = parts[i];
      else
         cur = cur + "\\" + parts[i];
      FolderCreate(cur, FILE_COMMON);
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Write tmp then FileMove with FILE_REWRITE — no delete gap.        |
//+------------------------------------------------------------------+
bool GsxBusWriteAtomic(const string relativePath, const string body)
  {
   GsxEnsureFolderTree(relativePath);
   string tmp = relativePath + ".tmp";

   int h = FileOpen(tmp, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_REWRITE);
   if(h == INVALID_HANDLE)
      return false;
   FileWriteString(h, body);
   FileClose(h);

   ResetLastError();
   if(FileMove(tmp, FILE_COMMON, relativePath, FILE_REWRITE))
      return true;

   // Fallback: rewrite target in place (target never deleted first)
   int h2 = FileOpen(tmp, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h2 == INVALID_HANDLE)
      return false;
   string data = "";
   while(!FileIsEnding(h2))
      data += FileReadString(h2) + "\n";
   FileClose(h2);

   int h3 = FileOpen(relativePath, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_REWRITE);
   if(h3 == INVALID_HANDLE)
      return false;
   FileWriteString(h3, data);
   FileClose(h3);
   FileDelete(tmp, FILE_COMMON);
   return true;
  }

string GsxBusReadAll(const string relativePath)
  {
   if(!FileIsExist(relativePath, FILE_COMMON))
      return "";
   int h = FileOpen(relativePath, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
      return "";
   string data = "";
   while(!FileIsEnding(h))
     {
      string line = FileReadString(h);
      if(data == "")
         data = line;
      else
         data += "\n" + line;
     }
   FileClose(h);
   return data;
  }

//+------------------------------------------------------------------+
//| Retry short/empty reads once under concurrent publish.            |
//+------------------------------------------------------------------+
string GsxBusReadAllRetry(const string relativePath, const int retries = 2)
  {
   string data = GsxBusReadAll(relativePath);
   int left = MathMax(0, retries);
   while(left > 0 && data == "" && FileIsExist(relativePath, FILE_COMMON))
     {
      Sleep(5);
      data = GsxBusReadAll(relativePath);
      left--;
     }
   // Truncation guard: JSON docs should end with '}'
   left = MathMax(0, retries);
   while(left > 0 && data != "" &&
         StringGetCharacter(data, StringLen(data) - 1) != '}' &&
         StringFind(relativePath, ".json") >= 0)
     {
      Sleep(5);
      string again = GsxBusReadAll(relativePath);
      if(again != "")
         data = again;
      left--;
     }
   return data;
  }

bool GsxBusCacheHas(const string &arr[], const int n, const string key)
  {
   for(int i = 0; i < n; i++)
      if(arr[i] == key)
         return true;
   return false;
  }

void GsxBusCacheAdd(string &arr[], int &n, const string key)
  {
   if(n >= GSX_BUS_REG_CACHE_MAX || key == "" || GsxBusCacheHas(arr, n, key))
      return;
   arr[n] = key;
   n++;
  }

bool GsxBusLinePresent(const string body, const string token)
  {
   if(body == "" || token == "")
      return false;
   // exact line match (avoid tid substring false positives)
   string needle = "\n" + token + "\n";
   string padded = "\n" + body + "\n";
   return(StringFind(padded, needle) >= 0);
  }

void GsxBusRegisterTid(const string tid)
  {
   if(tid == "")
      return;
   if(GsxBusCacheHas(g_gsxBusCachedTids, g_gsxBusCachedTidN, tid))
      return;

   string indexPath = GSX_BUS_TERMINALS + "\\_index.txt";
   for(int attempt = 0; attempt < GSX_BUS_REG_RETRY; attempt++)
     {
      string existing = GsxBusReadAllRetry(indexPath, 1);
      if(GsxBusLinePresent(existing, tid))
        {
         GsxBusCacheAdd(g_gsxBusCachedTids, g_gsxBusCachedTidN, tid);
         return;
        }
      string body = existing;
      if(body != "" && StringGetCharacter(body, StringLen(body) - 1) != '\n')
         body += "\n";
      body += tid + "\n";
      if(GsxBusWriteAtomic(indexPath, body))
        {
         GsxBusCacheAdd(g_gsxBusCachedTids, g_gsxBusCachedTidN, tid);
         return;
        }
      Sleep(5);
     }
  }

void GsxBusRegisterSignal(const string tid, const string symbolCanon)
  {
   if(tid == "" || symbolCanon == "")
      return;
   string fileName = symbolCanon + ".json";
   string cacheKey = tid + "|" + fileName;
   if(GsxBusCacheHas(g_gsxBusCachedSigKeys, g_gsxBusCachedSigN, cacheKey))
      return;

   string listPath = GsxBusTerminalDir(tid) + "\\signals\\_list.txt";
   for(int attempt = 0; attempt < GSX_BUS_REG_RETRY; attempt++)
     {
      string existing = GsxBusReadAllRetry(listPath, 1);
      if(GsxBusLinePresent(existing, fileName))
        {
         GsxBusCacheAdd(g_gsxBusCachedSigKeys, g_gsxBusCachedSigN, cacheKey);
         return;
        }
      string body = existing;
      if(body != "" && StringGetCharacter(body, StringLen(body) - 1) != '\n')
         body += "\n";
      body += fileName + "\n";
      if(GsxBusWriteAtomic(listPath, body))
        {
         GsxBusCacheAdd(g_gsxBusCachedSigKeys, g_gsxBusCachedSigN, cacheKey);
         return;
        }
      Sleep(5);
     }
  }

int GsxBusListTerminalIds(string &tids[])
  {
   ArrayResize(tids, 0);
   string indexPath = GSX_BUS_TERMINALS + "\\_index.txt";
   string existing = GsxBusReadAllRetry(indexPath);
   if(existing == "")
      return 0;

   string parts[];
   int n = StringSplit(existing, StringGetCharacter("\n", 0), parts);
   for(int i = 0; i < n; i++)
     {
      string t = parts[i];
      StringTrimLeft(t);
      StringTrimRight(t);
      if(t == "" || t == "_index" || StringFind(t, ".tmp") >= 0)
         continue;
      bool dup = false;
      for(int k = 0; k < ArraySize(tids); k++)
         if(tids[k] == t)
           {
            dup = true;
            break;
           }
      if(dup)
         continue;
      int m = ArraySize(tids);
      ArrayResize(tids, m + 1);
      tids[m] = t;
     }
   return ArraySize(tids);
  }

int GsxBusListSignals(const string tid, string &files[])
  {
   ArrayResize(files, 0);
   string listPath = GsxBusTerminalDir(tid) + "\\signals\\_list.txt";
   string existing = GsxBusReadAllRetry(listPath);
   if(existing != "")
     {
      string parts[];
      int n = StringSplit(existing, StringGetCharacter("\n", 0), parts);
      for(int i = 0; i < n; i++)
        {
         string name = parts[i];
         StringTrimLeft(name);
         StringTrimRight(name);
         if(name == "" || StringFind(name, ".json") < 0)
            continue;
         int k = ArraySize(files);
         ArrayResize(files, k + 1);
         files[k] = GsxBusTerminalDir(tid) + "\\signals\\" + name;
        }
      return ArraySize(files);
     }

   string root = GsxBusTerminalDir(tid) + "\\signals\\*";
   string name;
   long handle = FileFindFirst(root, name, FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return 0;
   do
     {
      if(StringFind(name, ".json") < 0)
         continue;
      if(StringFind(name, ".tmp") >= 0)
         continue;
      int k = ArraySize(files);
      ArrayResize(files, k + 1);
      files[k] = GsxBusTerminalDir(tid) + "\\signals\\" + name;
     }
   while(FileFindNext(handle, name));
   FileFindClose(handle);
   return ArraySize(files);
  }

bool GsxBusPublishHeartbeat(const string source)
  {
   string tid = GsxMakeTid();
   GsxBusRegisterTid(tid);
   string body = GsxBuildHeartbeatJson(source);
   return GsxBusWriteAtomic(GsxBusHeartbeatPath(tid), body);
  }

string GsxBusReadGrades()
  {
   string j = GsxBusReadAllRetry(GsxBusGradesPath());
   if(j == "" || !GsxJsonVersionOk(j))
      return "";
   return j;
  }

string GsxBusTopGradeLine(const string json, const string kind)
  {
   if(json == "")
      return "grades: none";
   string key = "\"" + kind + "\"";
   int p = StringFind(json, key);
   if(p < 0)
      return kind + ": none";
   string canon = GsxJsonGetString(StringSubstr(json, p), "symbol_canon", "-");
   double sc = GsxJsonGetDouble(StringSubstr(json, p), "score", 0.0);
   string tid = GsxJsonGetString(StringSubstr(json, p), "tid", "-");
   return StringFormat("%s top %.1f %s @%s", kind, sc, canon, tid);
  }

#endif
//+------------------------------------------------------------------+
