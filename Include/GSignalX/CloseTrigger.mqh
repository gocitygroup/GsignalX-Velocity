//+------------------------------------------------------------------+
//|                                            CloseTrigger.mqh       |
//|  DRY close-reason emit / consume for Scouter + TgDealWatch.       |
//|  Hot path: GV presence (O(1)) + pending FILE_COMMON payload.      |
//|  Audit: append-only jsonl under bus closes/ (ring-rotated).       |
//|  Scouter emits; Desk/Chart deal-watch consumes (no Scouter HTTP). |
//+------------------------------------------------------------------+
#ifndef GSX_CLOSE_TRIGGER_MQH
#define GSX_CLOSE_TRIGGER_MQH

#include <GSignalX/BusProtocol.mqh>
#include <GSignalX/BusIO.mqh>
#include <GSignalX/TerminalIdentity.mqh>
#include <GSignalX/StrategicStop.mqh>

#define GSX_CT_AUDIT_MAX_BYTES  262144   // ~256 KB then rotate
#define GSX_CT_PAYLOAD_SEP      "|"

// Canonical reason tags (Scouter harvest + broker/client fallbacks)
#define GSX_CT_TAG_OVERFILL     "OVERFILL"
#define GSX_CT_TAG_BROKER_SL    "BROKER-SL"
#define GSX_CT_TAG_BROKER_TP    "BROKER-TP"
#define GSX_CT_TAG_BROKER_SO    "BROKER-SO"
#define GSX_CT_TAG_CLIENT       "CLIENT"
#define GSX_CT_TAG_UNKNOWN      "UNKNOWN"
#define GSX_CT_TAG_PARTIAL      "POS-PARTIAL"

struct GsxCloseTriggerEvent
  {
   ulong    ticket;
   long     magic;
   string   sym;
   int      side;       // +1 buy, -1 sell
   double   lots;
   double   entry;
   double   exitPx;
   double   sl;
   double   tp;
   double   pl;
   string   tag;        // ACC-TARGET, ATR-TRAIL, BROKER-SL, ...
   string   source;     // scouter | chart | broker | client
   string   detail;     // human why (peak/floor/strat meta/…)
   long     dealReason; // DEAL_REASON_* or -1 if n/a
   datetime ts;
  };

void GsxCtEventClear(GsxCloseTriggerEvent &e)
  {
   e.ticket = 0;
   e.magic = 0;
   e.sym = "";
   e.side = 0;
   e.lots = 0.0;
   e.entry = 0.0;
   e.exitPx = 0.0;
   e.sl = 0.0;
   e.tp = 0.0;
   e.pl = 0.0;
   e.tag = "";
   e.source = "";
   e.detail = "";
   e.dealReason = -1;
   e.ts = 0;
  }

string GsxCtGvName(const long magic, const ulong ticket)
  {
   return(StringFormat("GSX_CT_%I64d_%I64u", magic, ticket));
  }

string GsxCtPendingRel(const long magic, const ulong ticket)
  {
   return(StringFormat("%s\\closes\\pending\\%I64d_%I64u.ct",
                       GsxBusTerminalDir(GsxMakeTid()), magic, ticket));
  }

string GsxCtAuditRel()
  {
   return(GsxBusTerminalDir(GsxMakeTid()) + "\\closes\\events.jsonl");
  }

string GsxCtAuditBakRel()
  {
   return(GsxBusTerminalDir(GsxMakeTid()) + "\\closes\\events.jsonl.bak");
  }

// Sanitize detail so pipe-split stays stable (detail is last field).
string GsxCtSanitizeDetail(string d)
  {
   StringReplace(d, "|", "/");
   StringReplace(d, "\n", " ");
   StringReplace(d, "\r", " ");
   return(d);
  }

string GsxCtEncodePayload(const GsxCloseTriggerEvent &e)
  {
   // tag|source|pl|ts|sym|side|lots|entry|dealReason|exit|sl|tp|detail
   return(StringFormat("%s%s%s%s%.5f%s%I64d%s%s%s%d%s%.5f%s%.5f%s%I64d%s%.5f%s%.5f%s%.5f%s%s",
                       e.tag, GSX_CT_PAYLOAD_SEP,
                       e.source, GSX_CT_PAYLOAD_SEP,
                       e.pl, GSX_CT_PAYLOAD_SEP,
                       (long)e.ts, GSX_CT_PAYLOAD_SEP,
                       e.sym, GSX_CT_PAYLOAD_SEP,
                       e.side, GSX_CT_PAYLOAD_SEP,
                       e.lots, GSX_CT_PAYLOAD_SEP,
                       e.entry, GSX_CT_PAYLOAD_SEP,
                       e.dealReason, GSX_CT_PAYLOAD_SEP,
                       e.exitPx, GSX_CT_PAYLOAD_SEP,
                       e.sl, GSX_CT_PAYLOAD_SEP,
                       e.tp, GSX_CT_PAYLOAD_SEP,
                       GsxCtSanitizeDetail(e.detail)));
  }

bool GsxCtDecodePayload(const string raw, GsxCloseTriggerEvent &e)
  {
   string parts[];
   int n = StringSplit(raw, StringGetCharacter(GSX_CT_PAYLOAD_SEP, 0), parts);
   if(n < 4)
      return(false);
   e.tag = parts[0];
   e.source = parts[1];
   e.pl = StringToDouble(parts[2]);
   e.ts = (datetime)StringToInteger(parts[3]);
   if(n >= 5)
      e.sym = parts[4];
   if(n >= 6)
      e.side = (int)StringToInteger(parts[5]);
   if(n >= 7)
      e.lots = StringToDouble(parts[6]);
   if(n >= 8)
      e.entry = StringToDouble(parts[7]);
   if(n >= 9)
      e.dealReason = StringToInteger(parts[8]);
   if(n >= 10)
      e.exitPx = StringToDouble(parts[9]);
   if(n >= 11)
      e.sl = StringToDouble(parts[10]);
   if(n >= 12)
      e.tp = StringToDouble(parts[11]);
   if(n >= 13)
     {
      e.detail = parts[12];
      for(int i = 13; i < n; i++)
         e.detail += GSX_CT_PAYLOAD_SEP + parts[i];
     }
   return(e.tag != "");
  }

void GsxCtAuditRotateIfNeeded(const string auditRel)
  {
   if(!FileIsExist(auditRel, FILE_COMMON))
      return;
   long sz = FileGetInteger(auditRel, FILE_SIZE, FILE_COMMON);
   if(sz < 0 || sz < GSX_CT_AUDIT_MAX_BYTES)
      return;
   string bak = GsxCtAuditBakRel();
   FileDelete(bak, FILE_COMMON);
   FileMove(auditRel, FILE_COMMON, bak, FILE_REWRITE);
  }

void GsxCtAuditAppend(const GsxCloseTriggerEvent &e)
  {
   string rel = GsxCtAuditRel();
   GsxEnsureFolderTree(rel);
   GsxCtAuditRotateIfNeeded(rel);

   string j = "{";
   j += GsxJsonKV_I("ts", (long)e.ts);
   j += GsxJsonKV_I("ticket", (long)e.ticket);
   j += GsxJsonKV_I("magic", e.magic);
   j += GsxJsonKV_S("sym", e.sym);
   j += GsxJsonKV_I("side", e.side);
   j += GsxJsonKV_D("lots", e.lots);
   j += GsxJsonKV_D("entry", e.entry);
   j += GsxJsonKV_D("exit", e.exitPx);
   j += GsxJsonKV_D("sl", e.sl);
   j += GsxJsonKV_D("tp", e.tp);
   j += GsxJsonKV_D("pl", e.pl);
   j += GsxJsonKV_S("tag", e.tag);
   j += GsxJsonKV_S("source", e.source);
   j += GsxJsonKV_S("detail", e.detail);
   j += GsxJsonKV_I("deal_reason", e.dealReason, false);
   j += "}\n";

   int h = FileOpen(rel, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
     {
      h = FileOpen(rel, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_REWRITE);
      if(h == INVALID_HANDLE)
         return;
      FileWriteString(h, j);
      FileClose(h);
      return;
     }
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, j);
   FileClose(h);
  }

string GsxCtTagFromDealReason(const long reason)
  {
   if(reason == DEAL_REASON_SL)
      return(GSX_CT_TAG_BROKER_SL);
   if(reason == DEAL_REASON_TP)
      return(GSX_CT_TAG_BROKER_TP);
   if(reason == DEAL_REASON_SO)
      return(GSX_CT_TAG_BROKER_SO);
   if(reason == DEAL_REASON_CLIENT)
      return(GSX_CT_TAG_CLIENT);
   if(reason == DEAL_REASON_EXPERT)
      return("EXPERT");
   if(reason == DEAL_REASON_MOBILE)
      return("MOBILE");
   if(reason == DEAL_REASON_WEB)
      return("WEB");
   return(GSX_CT_TAG_UNKNOWN);
  }

// Human-readable reason line for Telegram (tag + optional detail).
string GsxCtFormatReasonLine(const GsxCloseTriggerEvent &e)
  {
   if(e.detail != "")
      return(e.tag + " | " + e.detail);
   return(e.tag);
  }

void GsxCtEmitEx(const ulong ticket,
                 const long magic,
                 const string tag,
                 const string source,
                 const double pl,
                 const string sym = "",
                 const int side = 0,
                 const double lots = 0.0,
                 const double entry = 0.0,
                 const long dealReason = -1,
                 const bool hotPending = true,
                 const double exitPx = 0.0,
                 const double sl = 0.0,
                 const double tp = 0.0,
                 const string detail = "")
  {
   if(ticket == 0 || tag == "")
      return;

   GsxCloseTriggerEvent e;
   GsxCtEventClear(e);
   e.ticket = ticket;
   e.magic = magic;
   e.tag = tag;
   e.source = (source == "" ? "scouter" : source);
   e.pl = pl;
   e.ts = TimeCurrent();
   e.dealReason = dealReason;
   e.sym = sym;
   e.side = side;
   e.lots = lots;
   e.entry = entry;
   e.exitPx = exitPx;
   e.sl = sl;
   e.tp = tp;
   e.detail = detail;

   if(PositionSelectByTicket(ticket))
     {
      if(e.sym == "")
         e.sym = PositionGetString(POSITION_SYMBOL);
      if(e.side == 0)
         e.side = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      if(e.lots <= 0.0)
         e.lots = PositionGetDouble(POSITION_VOLUME);
      if(e.entry <= 0.0)
         e.entry = PositionGetDouble(POSITION_PRICE_OPEN);
      if(e.sl <= 0.0)
         e.sl = PositionGetDouble(POSITION_SL);
      if(e.tp <= 0.0)
         e.tp = PositionGetDouble(POSITION_TP);
      if(e.magic == 0)
         e.magic = PositionGetInteger(POSITION_MAGIC);
     }

   if(hotPending)
     {
      GlobalVariableSet(GsxCtGvName(e.magic, e.ticket), (double)e.ts);

      string pending = GsxCtPendingRel(e.magic, e.ticket);
      GsxEnsureFolderTree(pending);
      string body = GsxCtEncodePayload(e);
      int h = FileOpen(pending, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_REWRITE);
      if(h != INVALID_HANDLE)
        {
         FileWriteString(h, body);
         FileClose(h);
        }
     }

   GsxCtAuditAppend(e);
  }

// Backward-compatible wrapper.
void GsxCtEmit(const ulong ticket,
               const long magic,
               const string tag,
               const string source,
               const double pl,
               const string sym = "",
               const int side = 0,
               const double lots = 0.0,
               const double entry = 0.0,
               const long dealReason = -1,
               const bool hotPending = true)
  {
   GsxCtEmitEx(ticket, magic, tag, source, pl, sym, side, lots, entry,
               dealReason, hotPending, 0.0, 0.0, 0.0, "");
  }

void GsxCtEmitFromSelected(const ulong ticket,
                           const string tag,
                           const string source,
                           const double pl,
                           const string detail = "")
  {
   if(!PositionSelectByTicket(ticket))
     {
      GsxCtEmitEx(ticket, 0, tag, source, pl, "", 0, 0.0, 0.0, -1, true, 0.0, 0.0, 0.0, detail);
      return;
     }
   long magic = PositionGetInteger(POSITION_MAGIC);
   string sym = PositionGetString(POSITION_SYMBOL);
   int side = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
   double lots = PositionGetDouble(POSITION_VOLUME);
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   GsxCtEmitEx(ticket, magic, tag, source, pl, sym, side, lots, entry, -1, true,
               0.0, sl, tp, detail);
  }

bool GsxCtConsume(const ulong ticket, const long magic, GsxCloseTriggerEvent &out)
  {
   GsxCtEventClear(out);
   out.ticket = ticket;
   out.magic = magic;

   string gv = GsxCtGvName(magic, ticket);
   string pending = GsxCtPendingRel(magic, ticket);
   bool hasGv = GlobalVariableCheck(gv);
   bool hasFile = FileIsExist(pending, FILE_COMMON);

   if(!hasGv && !hasFile)
      return(false);

   if(hasFile)
     {
      int h = FileOpen(pending, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
      if(h != INVALID_HANDLE)
        {
         string raw = "";
         while(!FileIsEnding(h))
            raw += FileReadString(h);
         FileClose(h);
         StringTrimLeft(raw);
         StringTrimRight(raw);
         GsxCtDecodePayload(raw, out);
        }
      FileDelete(pending, FILE_COMMON);
     }

   if(hasGv)
     {
      if(out.ts <= 0)
         out.ts = (datetime)GlobalVariableGet(gv);
      GlobalVariableDel(gv);
     }

   out.ticket = ticket;
   out.magic = magic;
   if(out.tag == "")
      out.tag = GSX_CT_TAG_UNKNOWN;
   return(true);
  }

// Fill exit price + deal reason from already-selected history.
void GsxCtFillFromHistory(const ulong positionId,
                          const long magic,
                          GsxCloseTriggerEvent &e)
  {
   long bestReason = -1;
   datetime bestTime = 0;
   double exitPx = 0.0;
   double pl = 0.0;
   int total = HistoryDealsTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0)
         continue;
      if((ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID) != positionId)
         continue;
      if(HistoryDealGetInteger(d, DEAL_MAGIC) != magic)
         continue;
      long entry = HistoryDealGetInteger(d, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         continue;
      pl += HistoryDealGetDouble(d, DEAL_PROFIT)
            + HistoryDealGetDouble(d, DEAL_SWAP)
            + HistoryDealGetDouble(d, DEAL_COMMISSION);
      datetime t = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      if(t >= bestTime)
        {
         bestTime = t;
         bestReason = HistoryDealGetInteger(d, DEAL_REASON);
         exitPx = HistoryDealGetDouble(d, DEAL_PRICE);
        }
     }
   if(MathAbs(e.pl) < 1e-12 && MathAbs(pl) > 1e-12)
      e.pl = pl;
   if(e.exitPx <= 0.0 && exitPx > 0.0)
      e.exitPx = exitPx;
   if(e.dealReason < 0 && bestReason >= 0)
      e.dealReason = bestReason;
  }

// Enrich broker closes with persisted strategic-stop meta.
void GsxCtEnrichBrokerDetail(const ulong ticket, const long magic, GsxCloseTriggerEvent &e)
  {
   if(e.tag != GSX_CT_TAG_BROKER_SL && e.tag != GSX_CT_TAG_BROKER_TP && e.tag != GSX_CT_TAG_BROKER_SO)
      return;
   if(e.detail != "")
      return;

   GsxStratStopDecision d;
   if(GsxStratStopLoad(ticket, magic, d))
     {
      if(e.tag == GSX_CT_TAG_BROKER_SL)
         e.detail = GsxStratStopBrokerSlDetail(d, e.sl);
      else
         e.detail = StringFormat("%s | %s", e.tag, d.reason);
      GsxStratStopClear(ticket, magic);
      return;
     }

   if(e.tag == GSX_CT_TAG_BROKER_SL)
      e.detail = StringFormat("BROKER-SL hit SL=%.5f", e.sl);
   else if(e.tag == GSX_CT_TAG_BROKER_TP)
      e.detail = StringFormat("BROKER-TP hit TP=%.5f", e.tp);
   else if(e.tag == GSX_CT_TAG_BROKER_SO)
      e.detail = "broker stop-out";
  }

// Full resolve into event (preferred for enriched TG CLOSE).
bool GsxCtResolveEvent(const ulong positionId,
                       const long magic,
                       const bool historyReady,
                       GsxCloseTriggerEvent &out)
  {
   GsxCtEventClear(out);
   out.ticket = positionId;
   out.magic = magic;

   if(GsxCtConsume(positionId, magic, out))
     {
      if(!historyReady)
        {
         // optional: leave exit blank if no history
        }
      else
         GsxCtFillFromHistory(positionId, magic, out);
      if(out.source == "")
         out.source = "scouter";
      GsxCtEnrichBrokerDetail(positionId, magic, out);
      return(true);
     }

   if(!historyReady)
     {
      if(!HistorySelect(TimeCurrent() - 86400 * 7, TimeCurrent() + 60))
        {
         out.tag = GSX_CT_TAG_UNKNOWN;
         out.source = "unknown";
         return(false);
        }
     }

   GsxCtFillFromHistory(positionId, magic, out);
   if(out.dealReason < 0)
     {
      out.tag = GSX_CT_TAG_UNKNOWN;
      out.source = "unknown";
      return(false);
     }
   out.tag = GsxCtTagFromDealReason(out.dealReason);
   out.source = (out.tag == GSX_CT_TAG_CLIENT ? "client" : "broker");
   GsxCtEnrichBrokerDetail(positionId, magic, out);
   return(true);
  }

string GsxCtResolveReason(const ulong positionId,
                          const long magic,
                          const bool historyReady,
                          double &outPl)
  {
   outPl = 0.0;
   GsxCloseTriggerEvent ev;
   if(!GsxCtResolveEvent(positionId, magic, historyReady, ev))
      return(GSX_CT_TAG_UNKNOWN);
   outPl = ev.pl;
   return(GsxCtFormatReasonLine(ev));
  }

#endif // GSX_CLOSE_TRIGGER_MQH
//+------------------------------------------------------------------+
