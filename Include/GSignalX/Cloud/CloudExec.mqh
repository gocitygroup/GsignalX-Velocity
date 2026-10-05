//+------------------------------------------------------------------+
//|                                                CloudExec.mqh      |
//|  Map dashboard commands → CTrade open/close/modify + ack.         |
//+------------------------------------------------------------------+
#ifndef GSX_CLOUD_EXEC_MQH
#define GSX_CLOUD_EXEC_MQH

#include <Trade\Trade.mqh>
#include <GSignalX/BusProtocol.mqh>
#include <GSignalX/Cloud/CloudHttp.mqh>
#include <GSignalX/Cloud/CloudAuth.mqh>

struct GsxCloudExecResult
  {
   bool   ok;
   string body;   // JSON ack payload
   string err;
  };

string GsxCloudAckOk(const string extra = "")
  {
   if(extra == "")
      return("{\"ok\":true}");
   return("{" + extra + ",\"ok\":true}");
  }

string GsxCloudAckErr(const string msg)
  {
   return("{\"ok\":false,\"error\":\"" + msg + "\"}");
  }

bool GsxCloudCloseByTicket(CTrade &trade, const ulong ticket, string &err)
  {
   if(!PositionSelectByTicket(ticket))
     {
      err = "position not found";
      return(false);
     }
   if(!trade.PositionClose(ticket))
     {
      err = trade.ResultRetcodeDescription();
      return(false);
     }
   return(true);
  }

int GsxCloudCloseFiltered(CTrade &trade, const bool profitableOnly, const bool losingOnly)
  {
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(profitableOnly && profit <= 0.0)
         continue;
      if(losingOnly && profit >= 0.0)
         continue;
      if(trade.PositionClose(ticket))
         closed++;
     }
   return(closed);
  }

bool GsxCloudPlaceMarket(CTrade &trade, const long magic, const string symbol, const string side,
                         const double volume, string &err, ulong &ticket)
  {
   ticket = 0;
   string sym = symbol;
   StringTrimLeft(sym);
   StringTrimRight(sym);
   if(sym == "" || volume <= 0.0)
     {
      err = "symbol and volume required";
      return(false);
     }
   if(!SymbolSelect(sym, true))
     {
      err = "symbol select failed";
      return(false);
     }
   // Use toolkit magic so Scouter / fleet ownership see remote opens
   trade.SetExpertMagicNumber(magic);
   bool buy = (StringCompare(side, "buy", false) == 0 || StringCompare(side, "BUY", false) == 0);
   bool ok = buy ? trade.Buy(volume, sym) : trade.Sell(volume, sym);
   if(!ok)
     {
      err = trade.ResultRetcodeDescription();
      return(false);
     }
   ticket = trade.ResultOrder();
   return(true);
  }

bool GsxCloudExecCommand(const GsxCloudConfig &cfg, const long magic,
                         const string type, const string payload,
                         GsxCloudExecResult &out)
  {
   out.ok = false;
   out.body = "";
   out.err = "";
   CTrade trade;
   trade.SetAsyncMode(false);
   trade.SetExpertMagicNumber(magic);

   if(type == "place_order")
     {
      if(!cfg.allowRemoteOrders)
        {
         out.err = "remote orders disabled";
         out.body = GsxCloudAckErr(out.err);
         return(true); // ack as blocked
        }
      string symbol = GsxJsonGetString(payload, "symbol", "");
      string side = GsxJsonGetString(payload, "side", "buy");
      double volume = GsxJsonGetDouble(payload, "volume", 0.0);
      ulong ticket = 0;
      string err = "";
      if(!GsxCloudPlaceMarket(trade, magic, symbol, side, volume, err, ticket))
        {
         out.err = err;
         out.body = "{\"ok\":false,\"placed\":false,\"error\":\"" + err + "\",\"blocked_by\":\"cloud_exec\"}";
         return(true);
        }
      out.ok = true;
      out.body = StringFormat("{\"ok\":true,\"placed\":true,\"ticket\":%I64u,\"volume\":%.2f,\"magic\":%I64d}",
                              ticket, volume, magic);
      return(true);
     }

   if(type == "close_all" || type == "close_profitable" || type == "close_losing" ||
      type == "close_position" || type == "close_partial")
     {
      if(!cfg.allowRemoteCloses)
        {
         out.err = "remote closes disabled";
         out.body = GsxCloudAckErr(out.err);
         return(true);
        }
      if(type == "close_position")
        {
         ulong ticket = (ulong)GsxJsonGetLong(payload, "ticket", 0);
         string err = "";
         if(!GsxCloudCloseByTicket(trade, ticket, err))
           {
            out.body = GsxCloudAckErr(err);
            return(true);
           }
         out.ok = true;
         out.body = "{\"ok\":true,\"closed_count\":1}";
         return(true);
        }
      int n = 0;
      if(type == "close_all")
         n = GsxCloudCloseFiltered(trade, false, false);
      else if(type == "close_profitable")
         n = GsxCloudCloseFiltered(trade, true, false);
      else if(type == "close_losing")
         n = GsxCloudCloseFiltered(trade, false, true);
      out.ok = true;
      out.body = StringFormat("{\"ok\":true,\"closed_count\":%d}", n);
      return(true);
     }

   if(type == "modify_position")
     {
      ulong ticket = (ulong)GsxJsonGetLong(payload, "ticket", 0);
      double sl = GsxJsonGetDouble(payload, "sl", 0.0);
      double tp = GsxJsonGetDouble(payload, "tp", 0.0);
      if(!PositionSelectByTicket(ticket))
        {
         out.body = GsxCloudAckErr("position not found");
         return(true);
        }
      if(!trade.PositionModify(ticket, sl, tp))
        {
         out.body = GsxCloudAckErr(trade.ResultRetcodeDescription());
         return(true);
        }
      out.ok = true;
      out.body = "{\"ok\":true,\"modified\":true}";
      return(true);
     }

   out.body = "{\"ok\":false,\"unsupported\":true,\"error\":\"unknown command type\"}";
   return(true);
  }

bool GsxCloudAckCommand(const GsxCloudIdentity &id, const string accountId,
                        const string cmdId, const string resultJson)
  {
   string url = GsxCloudTrimSlash(id.controlPlane) +
                "/api/v1/workers/accounts/" + accountId +
                "/commands/" + cmdId + "/ack";
   GsxCloudHttpResult res;
   return(GsxCloudHttpWithRetry("POST", url, id.workerToken, resultJson, res) && res.ok);
  }

#endif
//+------------------------------------------------------------------+
