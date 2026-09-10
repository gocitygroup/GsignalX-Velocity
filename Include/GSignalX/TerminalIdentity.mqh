//+------------------------------------------------------------------+
//|                                       TerminalIdentity.mqh        |
//|  Stable per-terminal identity for the connector bus               |
//+------------------------------------------------------------------+
#ifndef GSX_TERMINAL_IDENTITY_MQH
#define GSX_TERMINAL_IDENTITY_MQH

#include <GSignalX/BusProtocol.mqh>

struct GsxTerminalId
  {
   string tid;
   long   login;
   string server;
   string company;
   string currency;
   string data_path;
  };

uint GsxHash32(const string s)
  {
   uint h = 2166136261;
   int n = StringLen(s);
   for(int i = 0; i < n; i++)
     {
      h ^= (uint)StringGetCharacter(s, i);
      h *= 16777619;
     }
   return h;
  }

string GsxMakeTid()
  {
   string raw = TerminalInfoString(TERMINAL_DATA_PATH) + "|" +
                IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "|" +
                AccountInfoString(ACCOUNT_SERVER);
   return StringFormat("%08x", GsxHash32(raw));
  }

void GsxFillIdentity(GsxTerminalId &id)
  {
   id.tid       = GsxMakeTid();
   id.login     = AccountInfoInteger(ACCOUNT_LOGIN);
   id.server    = AccountInfoString(ACCOUNT_SERVER);
   id.company   = AccountInfoString(ACCOUNT_COMPANY);
   id.currency  = AccountInfoString(ACCOUNT_CURRENCY);
   id.data_path = TerminalInfoString(TERMINAL_DATA_PATH);
  }

string GsxBuildHeartbeatJson(const string source)
  {
   GsxTerminalId id;
   GsxFillIdentity(id);
   string j = "{";
   j += GsxJsonKV_I("version", GSX_BUS_VERSION);
   j += GsxJsonKV_I("ts", (long)TimeCurrent());
   j += GsxJsonKV_S("tid", id.tid);
   j += GsxJsonKV_S("source", source);
   j += GsxJsonKV_I("login", id.login);
   j += GsxJsonKV_S("server", id.server);
   j += GsxJsonKV_S("company", id.company);
   j += GsxJsonKV_S("currency", id.currency);
   j += GsxJsonKV_D("balance", AccountInfoDouble(ACCOUNT_BALANCE));
   j += GsxJsonKV_D("equity", AccountInfoDouble(ACCOUNT_EQUITY));
   j += GsxJsonKV_D("free_margin", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
   j += GsxJsonKV_B("connected", (bool)TerminalInfoInteger(TERMINAL_CONNECTED));
   j += GsxJsonKV_B("trade_allowed",
                    (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
                    (bool)AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) &&
                    (bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT), false);
   j += "}";
   return j;
  }

#endif
//+------------------------------------------------------------------+
