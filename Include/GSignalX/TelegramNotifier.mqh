//+------------------------------------------------------------------+
//|                                          TelegramNotifier.mqh     |
//|  WebRequest-only Telegram bot notifier (no DLLs). Market OK.      |
//|  Host fills GsxTgConfig from inputs — no Inp* reads here.         |
//|  v1.30: soft VERIFY (≥1 chat OK); send only to healthy chats.      |
//|  v1.29: plain sends; chatId numeric check; reverify throttle;     |
//|         silent a==b off. v1.28 VERIFY getMe + plain probe/chat.    |
//+------------------------------------------------------------------+
#ifndef GSX_TELEGRAM_NOTIFIER_MQH
#define GSX_TELEGRAM_NOTIFIER_MQH

#include <GSignalX/RiskGuidance.mqh>
#include <GSignalX/BrandLinks.mqh>

#define GSX_TG_QUEUE_CAP   10
#define GSX_TG_HTTP_TO_MS  5000
#define GSX_TG_RATE_WIN_S  60
#define GSX_TG_DEAL_STALE_SEC 45
#define GSX_TG_REVERIFY_COOLDOWN_S 60

//+------------------------------------------------------------------+
enum ENUM_GSX_TG_STATUS
  {
   GSX_TG_NOT_CFG   = 0,
   GSX_TG_ERROR     = 1,
   GSX_TG_CONNECTED = 2,
   GSX_TG_VERIFIED  = 3
  };

enum ENUM_GSX_TG_HOST
  {
   GSX_TG_HOST_NONE  = 0,
   GSX_TG_HOST_SVC   = 1,
   GSX_TG_HOST_DESK  = 2,
   GSX_TG_HOST_CHART = 3
  };

//+------------------------------------------------------------------+
struct GsxTgConfig
  {
   bool   enable;
   string botToken;
   string chatId1;
   string chatId2;
   string chatId3;
   int    silentStartHourGmt; // inclusive; -1 = off
   int    silentEndHourGmt;   // exclusive; wrap ok
   int    ratePerMin;         // default 20
   int    maxRetries;         // default 3
  };

struct GsxTgQueuedMsg
  {
   string   text;
   string   chatId;
   int      retries;
   datetime nextTry;
  };

struct GsxTgPublished
  {
   int    status;      // ENUM_GSX_TG_STATUS
   int    sent;
   int    fail;
   int    queue;
   int    total;
   int    svcOk;
   int    dashOk;
   int    chartOk;
   datetime hb;
   int    dealOwner;   // ENUM_GSX_TG_HOST desk/chart
  };

//+------------------------------------------------------------------+
GsxTgQueuedMsg   g_tgQueue[GSX_TG_QUEUE_CAP];
int              g_tgHead      = 0;
int              g_tgTail      = 0;
int              g_tgCount     = 0;
int              g_tgSentToday = 0;
int              g_tgFailToday = 0;
int              g_tgTotalSent = 0;
string           g_tgLastError = "";
ENUM_GSX_TG_STATUS g_tgStatus  = GSX_TG_NOT_CFG;
bool             g_tgVerified  = false;
datetime         g_tgRateTs[];
double           g_tgSessionPl = 0.0;
datetime         g_tgDayKey    = 0;
string           g_tgAccountTag = "";
string           g_tgHostTag   = "desk";
long             g_tgMagic     = 0;
string           g_tgCfgFp     = "";
datetime         g_tgOverflowWarnAt = 0;
datetime         g_tgLastVerifyAt   = 0;
// Chats that passed the last VERIFY probe (send/skip dead IDs)
string           g_tgHealthy[3];
int              g_tgHealthyN       = 0;

void GsxTgHealthyClear()
  {
   g_tgHealthyN = 0;
   g_tgHealthy[0] = "";
   g_tgHealthy[1] = "";
   g_tgHealthy[2] = "";
  }

void GsxTgHealthyAdd(const string chatId)
  {
   if(chatId == "" || g_tgHealthyN >= 3)
      return;
   for(int i = 0; i < g_tgHealthyN; i++)
      if(g_tgHealthy[i] == chatId)
         return;
   g_tgHealthy[g_tgHealthyN++] = chatId;
  }

bool GsxTgChatIsHealthy(const string chatId)
  {
   if(chatId == "")
      return(false);
   // Before a successful VERIFY, allow any numeric id (first probe / send attempt)
   if(!g_tgVerified || g_tgHealthyN <= 0)
      return(true);
   for(int i = 0; i < g_tgHealthyN; i++)
      if(g_tgHealthy[i] == chatId)
         return(true);
   return(false);
  }

//+------------------------------------------------------------------+
int GsxTgEffectiveRate(const GsxTgConfig &cfg)
  {
   return(cfg.ratePerMin > 0 ? cfg.ratePerMin : 20);
  }

int GsxTgEffectiveRetries(const GsxTgConfig &cfg)
  {
   return(cfg.maxRetries > 0 ? cfg.maxRetries : 3);
  }

void GsxTgSetHostTag(const string tag)
  {
   g_tgHostTag = (tag == "" ? "desk" : tag);
  }

void GsxTgSetMagic(const long magic)
  {
   g_tgMagic = magic;
  }

string GsxTgConfigFingerprint(const GsxTgConfig &cfg)
  {
   return(StringFormat("%d|%s|%s|%s|%s|%d|%d|%d|%d",
                       cfg.enable ? 1 : 0,
                       cfg.botToken,
                       cfg.chatId1, cfg.chatId2, cfg.chatId3,
                       cfg.silentStartHourGmt, cfg.silentEndHourGmt,
                       cfg.ratePerMin, cfg.maxRetries));
  }

//+------------------------------------------------------------------+
string GsxTgStatusVar(const long magic)
  { return("GSX_TG_STATUS_" + IntegerToString((int)magic)); }
string GsxTgSentVar(const long magic)
  { return("GSX_TG_SENT_" + IntegerToString((int)magic)); }
string GsxTgFailVar(const long magic)
  { return("GSX_TG_FAIL_" + IntegerToString((int)magic)); }
string GsxTgQVar(const long magic)
  { return("GSX_TG_Q_" + IntegerToString((int)magic)); }
string GsxTgTotalVar(const long magic)
  { return("GSX_TG_TOTAL_" + IntegerToString((int)magic)); }
string GsxTgSvcOkVar(const long magic)
  { return("GSX_TG_SVC_OK_" + IntegerToString((int)magic)); }
string GsxTgDashOkVar(const long magic)
  { return("GSX_TG_DASH_OK_" + IntegerToString((int)magic)); }
string GsxTgChartOkVar(const long magic)
  { return("GSX_TG_CHART_OK_" + IntegerToString((int)magic)); }
string GsxTgHbVar(const long magic)
  { return("GSX_TG_HB_" + IntegerToString((int)magic)); }
string GsxTgDealOwnerVar(const long magic)
  { return("GSX_TG_DEAL_OWNER_" + IntegerToString((int)magic)); }
string GsxTgDeskHbVar(const long magic)
  { return("GSX_TG_DESK_HB_" + IntegerToString((int)magic)); }

//+------------------------------------------------------------------+
string GsxTgUrlEncode(string s)
  {
   string out = "";
   int n = StringLen(s);
   for(int i = 0; i < n; i++)
     {
      ushort c = StringGetCharacter(s, i);
      if((c >= 'A' && c <= 'Z') ||
         (c >= 'a' && c <= 'z') ||
         (c >= '0' && c <= '9') ||
         c == '-' || c == '_' || c == '.' || c == '~')
         out += CharToString((uchar)c);
      else if(c == ' ')
         out += "%20";
      else if(c < 128)
         out += StringFormat("%%%02X", c);
      else
        {
         uchar utf8[];
         string ch = ShortToString(c);
         int nbytes = StringToCharArray(ch, utf8, 0, WHOLE_ARRAY, CP_UTF8);
         if(nbytes > 0)
            nbytes--;
         for(int b = 0; b < nbytes; b++)
            out += StringFormat("%%%02X", utf8[b]);
        }
     }
   return(out);
  }

string GsxTgEscapeMarkdown(string s)
  {
   string specials = "_*[]()~`>#+-=|{}.!";
   string out = "";
   int n = StringLen(s);
   for(int i = 0; i < n; i++)
     {
      ushort c = StringGetCharacter(s, i);
      string ch = ShortToString(c);
      if(StringFind(specials, ch) >= 0)
         out += "\\" + ch;
      else
         out += ch;
     }
   return(out);
  }

// Numeric chat IDs only (optional leading '-' for groups/channels). Reject @username.
bool GsxTgChatIdOk(string &chatId, string &err)
  {
   err = "";
   StringTrimLeft(chatId);
   StringTrimRight(chatId);
   if(chatId == "")
     {
      err = "empty chatId";
      return(false);
     }
   if(StringGetCharacter(chatId, 0) == '@')
     {
      err = "chatId must be numeric (not @username): " + chatId;
      return(false);
     }
   int start = 0;
   if(StringGetCharacter(chatId, 0) == '-')
      start = 1;
   int n = StringLen(chatId);
   if(start >= n)
     {
      err = "chatId must be numeric (not @username): " + chatId;
      return(false);
     }
   for(int i = start; i < n; i++)
     {
      ushort c = StringGetCharacter(chatId, i);
      if(c < '0' || c > '9')
        {
         err = "chatId must be numeric (not @username): " + chatId;
         return(false);
        }
     }
   return(true);
  }

bool GsxTgInSilentHours(const GsxTgConfig &cfg)
  {
   if(cfg.silentStartHourGmt < 0 || cfg.silentEndHourGmt < 0)
      return(false);
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int h = dt.hour;
   int a = cfg.silentStartHourGmt % 24;
   int b = cfg.silentEndHourGmt % 24;
   // a == b means silent window disabled (not always-on)
   if(a == b)
      return(false);
   if(a < b)
      return(h >= a && h < b);
   return(h >= a || h < b);
  }

void GsxTgResetDailyStatsIfNeeded()
  {
   datetime now = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   datetime dayStart = now - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   if(g_tgDayKey != dayStart)
     {
      g_tgDayKey    = dayStart;
      g_tgSentToday = 0;
      g_tgFailToday = 0;
     }
  }

bool GsxTgRateAllow(const GsxTgConfig &cfg)
  {
   datetime now = TimeCurrent();
   int lim = GsxTgEffectiveRate(cfg);
   int n = ArraySize(g_tgRateTs);
   int kept = 0;
   for(int i = 0; i < n; i++)
     {
      if(now - g_tgRateTs[i] < GSX_TG_RATE_WIN_S)
        {
         g_tgRateTs[kept] = g_tgRateTs[i];
         kept++;
        }
     }
   if(kept != n)
      ArrayResize(g_tgRateTs, kept);
   return(kept < lim);
  }

void GsxTgRateMark()
  {
   int n = ArraySize(g_tgRateTs);
   ArrayResize(g_tgRateTs, n + 1);
   g_tgRateTs[n] = TimeCurrent();
  }

bool GsxTgHttpOkBody(const string body)
  {
   return(StringFind(body, "\"ok\":true") >= 0 || StringFind(body, "\"ok\": true") >= 0);
  }

bool GsxTgHttpPostEx(const string token, const string chatId, const string text,
                     const bool useMarkdown, string &err)
  {
   err = "";
   if(token == "" || chatId == "")
     {
      err = "missing token/chatId";
      return(false);
     }

   string url = "https://api.telegram.org/bot" + token + "/sendMessage";
   string payload = "chat_id=" + GsxTgUrlEncode(chatId) +
                    "&text=" + GsxTgUrlEncode(text);
   if(useMarkdown)
      payload += "&parse_mode=Markdown";

   char   data[];
   char   result[];
   string resultHeaders;
   int nbytes = StringToCharArray(payload, data, 0, WHOLE_ARRAY, CP_UTF8);
   if(nbytes > 0)
      ArrayResize(data, nbytes - 1);

   ResetLastError();
   int code = WebRequest("POST", url,
                         "Content-Type: application/x-www-form-urlencoded\r\n",
                         GSX_TG_HTTP_TO_MS, data, result, resultHeaders);
   if(code == -1)
     {
      err = "WebRequest failed err=" + IntegerToString(GetLastError()) +
            " (allow https://api.telegram.org in Tools→Options→Expert Advisors)";
      return(false);
     }

   string body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   if(code != 200 || !GsxTgHttpOkBody(body))
     {
      err = "HTTP " + IntegerToString(code) + " " + StringSubstr(body, 0, 180);
      return(false);
     }
   return(true);
  }

bool GsxTgHttpPost(const string token, const string chatId, const string text, string &err)
  {
   // Default plain text — avoids legacy Markdown "can't parse entities" on deal/PROP bodies
   return(GsxTgHttpPostEx(token, chatId, text, false, err));
  }

bool GsxTgHttpGetMe(const string token, string &err)
  {
   err = "";
   if(token == "")
     {
      err = "missing token";
      return(false);
     }

   string url = "https://api.telegram.org/bot" + token + "/getMe";
   char   data[];
   char   result[];
   string resultHeaders;
   ArrayResize(data, 0);

   ResetLastError();
   int code = WebRequest("GET", url, "", GSX_TG_HTTP_TO_MS, data, result, resultHeaders);
   if(code == -1)
     {
      err = "WebRequest failed err=" + IntegerToString(GetLastError()) +
            " (allow https://api.telegram.org in Tools→Options→Expert Advisors)";
      return(false);
     }

   string body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   if(code != 200 || !GsxTgHttpOkBody(body))
     {
      err = "HTTP " + IntegerToString(code) + " " + StringSubstr(body, 0, 180);
      return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
bool GsxTgVerifyConnection(const GsxTgConfig &cfg, string &err)
  {
   err = "";
   g_tgVerified = false;
   if(!cfg.enable || cfg.botToken == "")
     {
      g_tgStatus = GSX_TG_NOT_CFG;
      err = "Telegram disabled or no token";
      return(false);
     }

   // Connected = token present while getMe + chat probes run
   g_tgStatus = GSX_TG_CONNECTED;
   if(!GsxTgHttpGetMe(cfg.botToken, err))
     {
      g_tgLastError = err;
      g_tgStatus    = GSX_TG_ERROR;
      g_tgVerified  = false;
      g_tgLastVerifyAt = TimeCurrent();
      return(false);
     }

   string chats[3];
   int nChats = 0;
   string rawIds[3];
   int nRaw = 0;
   if(cfg.chatId1 != "") rawIds[nRaw++] = cfg.chatId1;
   if(cfg.chatId2 != "") rawIds[nRaw++] = cfg.chatId2;
   if(cfg.chatId3 != "") rawIds[nRaw++] = cfg.chatId3;
   if(nRaw == 0)
     {
      err = "no chatId configured (numeric IDs only; each user must /start the bot)";
      g_tgLastError = err;
      g_tgStatus    = GSX_TG_ERROR;
      g_tgVerified  = false;
      GsxTgHealthyClear();
      g_tgLastVerifyAt = TimeCurrent();
      return(false);
     }

   GsxTgHealthyClear();
   string failDetail = "";
   int okCount = 0;

   for(int r = 0; r < nRaw; r++)
     {
      string id = rawIds[r];
      string idErr;
      if(!GsxTgChatIdOk(id, idErr))
        {
         if(failDetail != "")
            failDetail += "; ";
         failDetail += idErr;
         continue;
        }
      chats[nChats++] = id;
     }

   // Plain probe — Verified if ≥1 chat delivers (dead IDs skipped for sends)
   for(int i = 0; i < nChats; i++)
     {
      string probeErr;
      if(!GsxTgHttpPostEx(cfg.botToken, chats[i], "[TG] verify", false, probeErr))
        {
         if(failDetail != "")
            failDetail += "; ";
         failDetail += "chat " + chats[i] + ": " + probeErr;
         continue;
        }
      GsxTgHealthyAdd(chats[i]);
      okCount++;
     }

   g_tgLastVerifyAt = TimeCurrent();

   if(okCount <= 0)
     {
      err = (failDetail != "" ? failDetail
             : "no chatId delivered (numeric IDs only; each user must /start the bot)");
      g_tgLastError = err;
      g_tgStatus    = GSX_TG_ERROR;
      g_tgVerified  = false;
      GsxTgHealthyClear();
      return(false);
     }

   g_tgVerified = true;
   g_tgStatus   = GSX_TG_VERIFIED;
   // Keep skip warning visible on Trade Center when some chats are dead
   if(failDetail != "")
      g_tgLastError = "skip " + failDetail;
   else
      g_tgLastError = "";
   err = g_tgLastError;
   return(true);
  }

//+------------------------------------------------------------------+
void GsxTgPublishStatus(const long magic)
  {
   if(magic <= 0)
      return;
   GlobalVariableSet(GsxTgStatusVar(magic), (double)g_tgStatus);
   GlobalVariableSet(GsxTgSentVar(magic), (double)g_tgSentToday);
   GlobalVariableSet(GsxTgFailVar(magic), (double)g_tgFailToday);
   GlobalVariableSet(GsxTgQVar(magic), (double)g_tgCount);
   GlobalVariableSet(GsxTgTotalVar(magic), (double)g_tgTotalSent);
   GlobalVariableSet(GsxTgHbVar(magic), (double)TimeCurrent());

   int ok = (g_tgStatus == GSX_TG_VERIFIED) ? 1 : 0;
   if(g_tgHostTag == "svc")
      GlobalVariableSet(GsxTgSvcOkVar(magic), (double)ok);
   else if(g_tgHostTag == "chart")
      GlobalVariableSet(GsxTgChartOkVar(magic), (double)ok);
   else
      GlobalVariableSet(GsxTgDashOkVar(magic), (double)ok);
  }

void GsxTgReadPublishedStatus(const long magic, GsxTgPublished &out)
  {
   out.status = GSX_TG_NOT_CFG;
   out.sent = out.fail = out.queue = out.total = 0;
   out.svcOk = out.dashOk = out.chartOk = 0;
   out.hb = 0;
   out.dealOwner = GSX_TG_HOST_NONE;
   if(magic <= 0)
      return;

   if(GlobalVariableCheck(GsxTgStatusVar(magic)))
      out.status = (int)GlobalVariableGet(GsxTgStatusVar(magic));
   if(GlobalVariableCheck(GsxTgSentVar(magic)))
      out.sent = (int)GlobalVariableGet(GsxTgSentVar(magic));
   if(GlobalVariableCheck(GsxTgFailVar(magic)))
      out.fail = (int)GlobalVariableGet(GsxTgFailVar(magic));
   if(GlobalVariableCheck(GsxTgQVar(magic)))
      out.queue = (int)GlobalVariableGet(GsxTgQVar(magic));
   if(GlobalVariableCheck(GsxTgTotalVar(magic)))
      out.total = (int)GlobalVariableGet(GsxTgTotalVar(magic));
   if(GlobalVariableCheck(GsxTgSvcOkVar(magic)))
      out.svcOk = (int)GlobalVariableGet(GsxTgSvcOkVar(magic));
   if(GlobalVariableCheck(GsxTgDashOkVar(magic)))
      out.dashOk = (int)GlobalVariableGet(GsxTgDashOkVar(magic));
   if(GlobalVariableCheck(GsxTgChartOkVar(magic)))
      out.chartOk = (int)GlobalVariableGet(GsxTgChartOkVar(magic));
   if(GlobalVariableCheck(GsxTgHbVar(magic)))
      out.hb = (datetime)GlobalVariableGet(GsxTgHbVar(magic));
   if(GlobalVariableCheck(GsxTgDealOwnerVar(magic)))
      out.dealOwner = (int)GlobalVariableGet(GsxTgDealOwnerVar(magic));

   // merge: Verified if any host ok; else Error if any local status Error
   if(out.svcOk > 0 || out.dashOk > 0 || out.chartOk > 0)
      out.status = GSX_TG_VERIFIED;
  }

string GsxTgStatusLabel(const int status)
  {
   if(status == GSX_TG_VERIFIED)  return("Verified");
   if(status == GSX_TG_CONNECTED) return("Connected");
   if(status == GSX_TG_ERROR)     return("Error");
   return("NotCfg");
  }

void GsxTgClaimDealOwner(const long magic, const ENUM_GSX_TG_HOST who)
  {
   if(magic <= 0)
      return;
   GlobalVariableSet(GsxTgDealOwnerVar(magic), (double)who);
   if(who == GSX_TG_HOST_DESK)
      GlobalVariableSet(GsxTgDeskHbVar(magic), (double)TimeCurrent());
  }

void GsxTgDeskHeartbeat(const long magic)
  {
   if(magic <= 0)
      return;
   GlobalVariableSet(GsxTgDeskHbVar(magic), (double)TimeCurrent());
   GlobalVariableSet(GsxTgDealOwnerVar(magic), (double)GSX_TG_HOST_DESK);
  }

bool GsxTgDeskOwnerFresh(const long magic)
  {
   string n = GsxTgDeskHbVar(magic);
   if(!GlobalVariableCheck(n))
      return(false);
   datetime hb = (datetime)GlobalVariableGet(n);
   return((TimeCurrent() - hb) <= GSX_TG_DEAL_STALE_SEC);
  }

int GsxTgDealOwnerGet(const long magic)
  {
   if(GsxTgDeskOwnerFresh(magic))
      return(GSX_TG_HOST_DESK);
   string n = GsxTgDealOwnerVar(magic);
   if(!GlobalVariableCheck(n))
      return(GSX_TG_HOST_NONE);
   return((int)GlobalVariableGet(n));
  }

// Chart may own deals only when desk HB stale
bool GsxTgChartMayOwnDeals(const long magic)
  {
   return(!GsxTgDeskOwnerFresh(magic));
  }

//+------------------------------------------------------------------+
void GsxTgEnqueueChat(const string chatId, const string text)
  {
   if(chatId == "" || text == "")
      return;

   string id = chatId;
   // Wildcard "*" means "all chats" fan-out resolved in ProcessQueueEx
   if(id != "*")
     {
      string idErr;
      if(!GsxTgChatIdOk(id, idErr))
        {
         g_tgLastError = idErr;
         g_tgFailToday++;
         return;
        }
     }

   if(g_tgCount >= GSX_TG_QUEUE_CAP)
     {
      g_tgHead = (g_tgHead + 1) % GSX_TG_QUEUE_CAP;
      g_tgCount--;
      if(TimeCurrent() - g_tgOverflowWarnAt > 60)
         g_tgOverflowWarnAt = TimeCurrent(); // host may send WARN
     }

   g_tgQueue[g_tgTail].text    = text;
   g_tgQueue[g_tgTail].chatId  = id;
   g_tgQueue[g_tgTail].retries = 0;
   g_tgQueue[g_tgTail].nextTry = 0;
   g_tgTail = (g_tgTail + 1) % GSX_TG_QUEUE_CAP;
   g_tgCount++;
  }

void GsxTgEnqueue(const string text)
  {
   if(text == "")
      return;
   GsxTgEnqueueChat("*", text);
  }

bool GsxTgOverflowPending()
  {
   return(g_tgOverflowWarnAt != 0 &&
          (TimeCurrent() - g_tgOverflowWarnAt) < 2);
  }

//+------------------------------------------------------------------+
//| maxMsgs: 0 = drain eligible; 1+ = hard cap (Service hot path).    |
//+------------------------------------------------------------------+
void GsxTgProcessQueueEx(const GsxTgConfig &cfg, const int maxMsgs)
  {
   if(!cfg.enable || cfg.botToken == "")
      return;

   GsxTgResetDailyStatsIfNeeded();
   if(GsxTgInSilentHours(cfg))
      return;

   int maxRetries = GsxTgEffectiveRetries(cfg);
   int safety = g_tgCount;
   int processed = 0;
   while(g_tgCount > 0 && safety-- > 0)
     {
      if(maxMsgs > 0 && processed >= maxMsgs)
         break;

      GsxTgQueuedMsg msg = g_tgQueue[g_tgHead];
      if(msg.nextTry > 0 && TimeCurrent() < msg.nextTry)
         break;
      if(!GsxTgRateAllow(cfg))
         break;

      string chats[3];
      int nChats = 0;
      if(msg.chatId == "*" || msg.chatId == "")
        {
         if(g_tgVerified && g_tgHealthyN > 0)
           {
            for(int h = 0; h < g_tgHealthyN; h++)
               chats[nChats++] = g_tgHealthy[h];
           }
         else
           {
            if(cfg.chatId1 != "" && GsxTgChatIsHealthy(cfg.chatId1)) chats[nChats++] = cfg.chatId1;
            if(cfg.chatId2 != "" && GsxTgChatIsHealthy(cfg.chatId2)) chats[nChats++] = cfg.chatId2;
            if(cfg.chatId3 != "" && GsxTgChatIsHealthy(cfg.chatId3)) chats[nChats++] = cfg.chatId3;
           }
        }
      else
         chats[nChats++] = msg.chatId;

      if(nChats == 0)
        {
         g_tgHead = (g_tgHead + 1) % GSX_TG_QUEUE_CAP;
         g_tgCount--;
         continue;
        }

      bool allOk = true;
      string err;
      string keepSkip = "";
      if(StringFind(g_tgLastError, "skip ") == 0)
         keepSkip = g_tgLastError;
      for(int c = 0; c < nChats; c++)
        {
         if(!GsxTgRateAllow(cfg))
           {
            allOk = false;
            break;
           }
         if(!GsxTgHttpPost(cfg.botToken, chats[c], msg.text, err))
           {
            allOk = false;
            g_tgFailToday++;
            g_tgLastError = err;
            if(g_tgStatus == GSX_TG_VERIFIED)
               g_tgStatus = GSX_TG_CONNECTED;
            break;
           }
         GsxTgRateMark();
         g_tgSentToday++;
         g_tgTotalSent++;
         g_tgLastError = keepSkip; // preserve skip-warn; clear transient send errors
        }

      processed++;
      if(allOk)
        {
         g_tgHead = (g_tgHead + 1) % GSX_TG_QUEUE_CAP;
         g_tgCount--;
        }
      else
        {
         g_tgQueue[g_tgHead].retries++;
         if(g_tgQueue[g_tgHead].retries >= maxRetries)
           {
            g_tgHead = (g_tgHead + 1) % GSX_TG_QUEUE_CAP;
            g_tgCount--;
           }
         else
           {
            g_tgQueue[g_tgHead].nextTry = TimeCurrent() +
                                          (datetime)(2 * g_tgQueue[g_tgHead].retries);
            break;
           }
        }
     }

   if(g_tgMagic > 0)
      GsxTgPublishStatus(g_tgMagic);
  }

void GsxTgProcessQueue(const GsxTgConfig &cfg)
  {
   GsxTgProcessQueueEx(cfg, 0); // 0 = process all eligible (legacy)
  }

//+------------------------------------------------------------------+
void GsxTgSendNow(const GsxTgConfig &cfg, const string tag, const string body)
  {
   if(!cfg.enable)
      return;

   GsxTgResetDailyStatsIfNeeded();
   string host = (g_tgHostTag == "" ? "" : (" " + g_tgHostTag));
   string msg = "[" + tag + "]" + host + " " + body;

   // Prefer VERIFY-healthy chats so dead IDs do not poison the queue
   if(g_tgVerified && g_tgHealthyN > 0)
     {
      for(int h = 0; h < g_tgHealthyN; h++)
         GsxTgEnqueueChat(g_tgHealthy[h], msg);
     }
   else
     {
      if(cfg.chatId1 != "" && GsxTgChatIsHealthy(cfg.chatId1))
         GsxTgEnqueueChat(cfg.chatId1, msg);
      if(cfg.chatId2 != "" && GsxTgChatIsHealthy(cfg.chatId2))
         GsxTgEnqueueChat(cfg.chatId2, msg);
      if(cfg.chatId3 != "" && GsxTgChatIsHealthy(cfg.chatId3))
         GsxTgEnqueueChat(cfg.chatId3, msg);
     }

   // overflow WARN once — only to healthy/primary chat
   if(g_tgOverflowWarnAt != 0 && (TimeCurrent() - g_tgOverflowWarnAt) <= 1)
     {
      string w = "[WARN]" + host + " queue overflow — oldest dropped (cap " +
                 IntegerToString(GSX_TG_QUEUE_CAP) + ")";
      string warnChat = (g_tgHealthyN > 0 ? g_tgHealthy[0] : cfg.chatId1);
      if(warnChat != "")
         GsxTgEnqueueChat(warnChat, w);
      g_tgOverflowWarnAt = TimeCurrent() - 120; // arm cooldown
     }

   GsxTgProcessQueue(cfg);
  }

// Enqueue tagged message without draining the queue (Settings / non-urgent).
// Host timer drains via ProcessQueueEx(cfg, 1).
void GsxTgEnqueueTagged(const GsxTgConfig &cfg, const string tag, const string body)
  {
   if(!cfg.enable)
      return;

   GsxTgResetDailyStatsIfNeeded();
   string host = (g_tgHostTag == "" ? "" : (" " + g_tgHostTag));
   string msg = "[" + tag + "]" + host + " " + body;

   if(g_tgVerified && g_tgHealthyN > 0)
     {
      for(int h = 0; h < g_tgHealthyN; h++)
         GsxTgEnqueueChat(g_tgHealthy[h], msg);
     }
   else
     {
      if(cfg.chatId1 != "" && GsxTgChatIsHealthy(cfg.chatId1))
         GsxTgEnqueueChat(cfg.chatId1, msg);
      if(cfg.chatId2 != "" && GsxTgChatIsHealthy(cfg.chatId2))
         GsxTgEnqueueChat(cfg.chatId2, msg);
      if(cfg.chatId3 != "" && GsxTgChatIsHealthy(cfg.chatId3))
         GsxTgEnqueueChat(cfg.chatId3, msg);
     }

   if(g_tgOverflowWarnAt != 0 && (TimeCurrent() - g_tgOverflowWarnAt) <= 1)
     {
      string w = "[WARN]" + host + " queue overflow — oldest dropped (cap " +
                 IntegerToString(GSX_TG_QUEUE_CAP) + ")";
      string warnChat = (g_tgHealthyN > 0 ? g_tgHealthy[0] : cfg.chatId1);
      if(warnChat != "")
         GsxTgEnqueueChat(warnChat, w);
      g_tgOverflowWarnAt = TimeCurrent() - 120;
     }
  }

void GsxTgNotifyOpen(const GsxTgConfig &cfg, const string body)
  { GsxTgSendNow(cfg, "OPEN", body); }

void GsxTgNotifyClose(const GsxTgConfig &cfg, const string body)
  { GsxTgSendNow(cfg, "CLOSE", body); }

void GsxTgNotifyModify(const GsxTgConfig &cfg, const string body)
  { GsxTgSendNow(cfg, "MODIFY", body); }

void GsxTgNotifySignal(const GsxTgConfig &cfg, const string body)
  { GsxTgSendNow(cfg, "SIGNAL", body); }

void GsxTgNotifyError(const GsxTgConfig &cfg, const string body)
  { GsxTgSendNow(cfg, "ERROR", body); }

void GsxTgNotifyWarn(const GsxTgConfig &cfg, const string body)
  { GsxTgSendNow(cfg, "WARN", body); }

void GsxTgNotifyCustom(const GsxTgConfig &cfg, const string tag, const string body)
  { GsxTgSendNow(cfg, tag, body); }

void GsxTgNotifyDaily(const GsxTgConfig &cfg, const string body)
  {
   // Chart foundation footer once per daily digest (not on every trade alert)
   GsxTgSendNow(cfg, "DAILY", body + "\n" + GsxTvPubFooterLine());
  }

void GsxTgNotifyWeekly(const GsxTgConfig &cfg, const string body)
  { GsxTgSendNow(cfg, "WEEKLY", body); }

//+------------------------------------------------------------------+
string GsxTgFormatOpen(const string sym, const string side, const double lots,
                       const double entry, const double sl, const double tp)
  {
   string body = StringFormat("%s %s %.2f lots @ %.5f SL=%.5f TP=%.5f",
                              sym, side, lots, entry, sl, tp);
   string tip = GsxRiskTipForSymbol(sym, GSX_RISK_PHASE_ENTRY);
   if(tip != "")
      body += " | tip:" + tip;
   return(body);
  }

string GsxTgFormatModify(const string sym, const double sl, const double tp)
  {
   return(StringFormat("%s SL=%.5f TP=%.5f", sym, sl, tp));
  }

string GsxTgFormatClose(const string sym, const string side, const double lots,
                        const double entry, const double pl)
  {
   return(GsxTgFormatCloseEx(sym, side, lots, entry, pl, ""));
  }

string GsxTgFormatCloseEx(const string sym, const string side, const double lots,
                          const double entry, const double pl, const string reason)
  {
   return(GsxTgFormatCloseFull(sym, side, lots, entry, 0.0, pl, 0, 0.0, 0.0, reason, ""));
  }

// Enriched CLOSE: exit / ticket / SL / source / detail for desk ops.
string GsxTgFormatCloseFull(const string sym, const string side, const double lots,
                            const double entry, const double exitPx, const double pl,
                            const ulong ticket, const double sl, const double tp,
                            const string reason, const string source)
  {
   string body = StringFormat("%s %s lots=%.2f entry=%.5f", sym, side, lots, entry);
   if(exitPx > 0.0)
      body += StringFormat(" exit=%.5f", exitPx);
   body += StringFormat(" P/L=%.2f", pl);
   if(ticket > 0)
      body += StringFormat(" | #%I64u", ticket);
   if(sl > 0.0 || tp > 0.0)
      body += StringFormat(" SL=%.5f TP=%.5f", sl, tp);
   if(source != "")
      body += StringFormat(" src=%s", source);
   if(reason != "")
      body += " | reason=" + reason;
   return(body);
  }

string GsxTgBuildDailyBody(const double dayPl, const int trades, const int wins,
                           const double drawdownPct, const double balance)
  {
   double wr = (trades > 0 ? (100.0 * wins / trades) : 0.0);
   return(StringFormat("dayPL=%.2f trades=%d winRate=%.0f%% DD=%.2f%% bal=%.2f",
                       dayPl, trades, wr, drawdownPct, balance));
  }

string GsxTgBuildWeeklyBody(const double weekPl, const int trades, const int wins,
                            const double drawdownPct, const double balance)
  {
   double wr = (trades > 0 ? (100.0 * wins / trades) : 0.0);
   return(StringFormat("weekPL=%.2f trades=%d winRate=%.0f%% DD=%.2f%% bal=%.2f",
                       weekPl, trades, wr, drawdownPct, balance));
  }

//+------------------------------------------------------------------+
bool GsxTgMaybeReverify(const GsxTgConfig &cfg)
  {
   string fp = GsxTgConfigFingerprint(cfg);
   bool fpChanged = (fp != g_tgCfgFp);

   if(!cfg.enable)
     {
      g_tgCfgFp = fp;
      g_tgStatus = GSX_TG_NOT_CFG;
      g_tgVerified = false;
      GsxTgHealthyClear();
      if(g_tgMagic > 0)
         GsxTgPublishStatus(g_tgMagic);
      return(false);
     }

   // Already verified and config unchanged — stay verified
   if(!fpChanged && g_tgStatus == GSX_TG_VERIFIED)
      return(true);

   // CONNECTED after send fail: keep last error; do NOT re-probe every tick
   if(!fpChanged && g_tgStatus == GSX_TG_CONNECTED)
      return(false);

   // ERROR / NOT_CFG: cooldown before automatic retry
   if(!fpChanged &&
      (g_tgStatus == GSX_TG_ERROR || g_tgStatus == GSX_TG_NOT_CFG) &&
      g_tgLastVerifyAt != 0 &&
      (TimeCurrent() - g_tgLastVerifyAt) < GSX_TG_REVERIFY_COOLDOWN_S)
      return(false);

   g_tgCfgFp = fp;
   string err;
   bool ok = GsxTgVerifyConnection(cfg, err);
   if(!ok)
      g_tgLastError = err;
   if(g_tgMagic > 0)
      GsxTgPublishStatus(g_tgMagic);
   return(ok);
  }

void GsxTgInit(const GsxTgConfig &cfg, const string accountTag)
  {
   g_tgAccountTag = accountTag;
   g_tgSessionPl  = 0.0;
   g_tgHead = g_tgTail = g_tgCount = 0;
   ArrayResize(g_tgRateTs, 0);
   g_tgCfgFp = GsxTgConfigFingerprint(cfg);
   GsxTgResetDailyStatsIfNeeded();

   if(!cfg.enable)
     {
      g_tgStatus   = GSX_TG_NOT_CFG;
      g_tgVerified = false;
      if(g_tgMagic > 0)
         GsxTgPublishStatus(g_tgMagic);
      return;
     }

   string err;
   if(!GsxTgVerifyConnection(cfg, err))
     {
      g_tgLastError = err;
      g_tgStatus = GSX_TG_ERROR;
      if(g_tgMagic > 0)
         GsxTgPublishStatus(g_tgMagic);
      return;
     }

   string who = (accountTag != "" ? accountTag : "GSignalX");
   GsxTgSendNow(cfg, "TG",
                "Connection verified — " + who + "\n" + GsxTvPubFooterLine());
   GsxTgSendNow(cfg, "START", "EA started — " + who);
   if(g_tgMagic > 0)
      GsxTgPublishStatus(g_tgMagic);
  }

void GsxTgDeinit(const GsxTgConfig &cfg, double sessionPl)
  {
   g_tgSessionPl = sessionPl;
   if(cfg.enable)
     {
      string pl = DoubleToString(sessionPl, 2);
      GsxTgSendNow(cfg, "STOP", "EA stopped — session P/L: " + pl);
      for(int i = 0; i < GSX_TG_QUEUE_CAP && g_tgCount > 0; i++)
         GsxTgProcessQueue(cfg);
     }
   if(g_tgMagic > 0)
      GsxTgPublishStatus(g_tgMagic);
  }

string GsxTgStatusText()
  {
   return(GsxTgStatusLabel((int)g_tgStatus));
  }

int    GsxTgSentToday()   { return(g_tgSentToday); }
int    GsxTgFailToday()   { return(g_tgFailToday); }
int    GsxTgQueueDepth()  { return(g_tgCount); }
int    GsxTgTotalSent()   { return(g_tgTotalSent); }
string GsxTgLastError()   { return(g_tgLastError); }
bool   GsxTgIsVerified()  { return(g_tgVerified && g_tgStatus == GSX_TG_VERIFIED); }

#endif // GSX_TELEGRAM_NOTIFIER_MQH
//+------------------------------------------------------------------+
