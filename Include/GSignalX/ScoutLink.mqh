//+------------------------------------------------------------------+
//|                                                  ScoutLink.mqh    |
//|  Shared Profit Scouter START/STOP GV (PS{id}_RUN).                |
//|  Chart EA, Trade Center, and Service hosts write; Scouter reads.  |
//|  Never closes tickets — harvest arm only.                         |
//+------------------------------------------------------------------+
#ifndef GSX_SCOUT_LINK_MQH
#define GSX_SCOUT_LINK_MQH

//+------------------------------------------------------------------+
string GsxScoutRunVarName(const int instanceId)
  {
   return(StringFormat("PS%d_RUN", instanceId));
  }

void GsxScoutRunSet(const int instanceId, const bool on)
  {
   GlobalVariableSet(GsxScoutRunVarName(instanceId), on ? 1.0 : 0.0);
  }

bool GsxScoutRunGet(const int instanceId, const bool defaultOn = true)
  {
   string name = GsxScoutRunVarName(instanceId);
   if(!GlobalVariableCheck(name))
      return(defaultOn);
   return(GlobalVariableGet(name) > 0.5);
  }

// Linked write: no-op when scout link disabled (entries-only hosts).
void GsxScoutRunSetLinked(const bool linkEnable, const int instanceId, const bool on)
  {
   if(!linkEnable)
      return;
   GsxScoutRunSet(instanceId, on);
  }

#endif // GSX_SCOUT_LINK_MQH
//+------------------------------------------------------------------+
