//+------------------------------------------------------------------+
//| TpNativeScouter.mqh — consume pending hits → CloseTicket          |
//| Include from ProfitScouter Core only (needs CloseTicket).         |
//+------------------------------------------------------------------+
#ifndef GSX_TP_NATIVE_SCOUTER_MQH
#define GSX_TP_NATIVE_SCOUTER_MQH

#include <GSignalX/TpNative/TpNativePersist.mqh>

#ifndef GSX_CT_TAG_NATIVE_TP
#define GSX_CT_TAG_NATIVE_TP  "NATIVE-TP"
#endif

// Close open positions matching symbol+direction+magic when closeOnHit.
void TpnScouterProcessPending()
  {
   string paths[];
   int n = TpnListPendingHits(paths);
   for(int i = 0; i < n; i++)
     {
      string symbol = "";
      int tf = 0, barIndex = -1;
      string direction = "";
      double level = 0.0;
      long magic = 0;
      bool closeOnHit = false;
      if(!TpnConsumePending(paths[i], symbol, tf, barIndex, direction, level, magic, closeOnHit))
         continue;
      if(!closeOnHit)
        {
         if(InpVerboseLog)
            PrintFormat("TpNative: hit %s bar=%d level=%.5f (closeOnHit=false)",
                        symbol, barIndex, level);
         continue;
        }

      int wantDir = (direction == "LONG") ? 1 : ((direction == "SHORT") ? -1 : 0);
      for(int p = PositionsTotal() - 1; p >= 0; p--)
        {
         ulong ticket = PositionGetTicket(p);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(magic != 0 && PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         string ps = PositionGetString(POSITION_SYMBOL);
         if(ps != symbol)
            continue;
         int side = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
         if(wantDir != 0 && side != wantDir)
            continue;
         // Native TP only closes winners (CloseTicket default guard)
         string detail = StringFormat("NATIVE-TP bar=%d level=%.5f", barIndex, level);
         CloseTicket(ticket, GSX_CT_TAG_NATIVE_TP, false, detail);
        }
     }
  }

#endif // GSX_TP_NATIVE_SCOUTER_MQH
