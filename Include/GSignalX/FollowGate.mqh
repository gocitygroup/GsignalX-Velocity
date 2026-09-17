//+------------------------------------------------------------------+
//|                                                  FollowGate.mqh   |
//|  Shared FOLLOW/WAIT + FollowDir entry gates (entries only).       |
//|  Used by EntryExec (Service) and chart EA without pulling Trade.  |
//+------------------------------------------------------------------+
#ifndef GSX_FOLLOW_GATE_MQH
#define GSX_FOLLOW_GATE_MQH

#ifndef GSX_FOLLOW_AUTO
#define GSX_FOLLOW_AUTO  0
#define GSX_FOLLOW_BUY   1
#define GSX_FOLLOW_SELL  2
#define GSX_FOLLOW_WAIT  3
#endif

#ifndef GSX_FOLLOW_WAIT
#define GSX_FOLLOW_WAIT  3
#endif

//+------------------------------------------------------------------+
bool GsxMagicHasOppositeDir(const long magic, const int wanted)
  {
   if(wanted == 0)
      return(false);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      long ptype = PositionGetInteger(POSITION_TYPE);
      int  dir   = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      if(dir != wanted)
         return(true);
     }
   return(false);
  }

bool GsxAllowNewDirEntry(const int wanted, const bool flipWaitMode, const long magic)
  {
   if(wanted == 0)
      return(false);
   if(!flipWaitMode)
      return(true);                 // FOLLOW
   return(!GsxMagicHasOppositeDir(magic, wanted));
  }

// FollowDir: Follow(Auto)=any; Buy; Sell; Wait=no new entries.
// Entries only: never closes or modifies open positions.
bool GsxFollowDirAllows(const int wanted, const int followDirMode)
  {
   if(wanted == 0)
      return(false);
   int mode = followDirMode;
   if(mode == GSX_FOLLOW_WAIT)
      return(false);
   if(mode != GSX_FOLLOW_BUY && mode != GSX_FOLLOW_SELL)
      mode = GSX_FOLLOW_AUTO;
   if(mode == GSX_FOLLOW_BUY)
      return(wanted == 1);
   if(mode == GSX_FOLLOW_SELL)
      return(wanted == -1);
   return(true); // AUTO / Follow
  }

// Combined entry gate: FOLLOW/WAIT + FollowDir (shared by Service + chart).
bool GsxAllowEntry(const int wanted,
                   const bool flipWaitMode,
                   const long magic,
                   const int followDirMode)
  {
   if(!GsxFollowDirAllows(wanted, followDirMode))
      return(false);
   return(GsxAllowNewDirEntry(wanted, flipWaitMode, magic));
  }

#endif // GSX_FOLLOW_GATE_MQH
//+------------------------------------------------------------------+
