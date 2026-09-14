//+------------------------------------------------------------------+
//|                                      ProfitScouter/Core.mqh       |
//|  Shared harvest engine — include AFTER host inputs + PS_HOST_*    |
//+------------------------------------------------------------------+
#ifndef PS_CORE_MQH
#define PS_CORE_MQH

#include <Trade\Trade.mqh>
#include <GSignalX/BusProtocol.mqh>
#include <GSignalX/BusIO.mqh>
#include <GSignalX/SymbolCanon.mqh>
#include <GSignalX/TerminalIdentity.mqh>
#include <GSignalX/BarDirection.mqh>

#ifndef PS_HOST_SERVICE
#ifndef PS_HOST_EA
#error Define PS_HOST_SERVICE or PS_HOST_EA before including Core.mqh
#endif
#endif

//+------------------------------------------------------------------+
//| Structures                                                       |
//+------------------------------------------------------------------+
struct PosRec
  {
   ulong             ticket;
   double            peak;
   bool              armed;
   double            commission;
   bool              commLoaded;
   bool              seen;
   bool              lockArmed;   // profit lock armed (peak >= InpProfitLockArm)
  };

struct SymRec
  {
   string            sym;
   double            peak;
   bool              armed;
   bool              seen;
  };

struct LivePos
  {
   ulong             ticket;
   long              magic;
   string            sym;
   double            profit;
   double            volume;
   datetime          opened;
   int               symIndex;
   long              posType;   // POSITION_TYPE_BUY / SELL (panel / logs)
  };

struct SymAgg
  {
   string            sym;
   double            profit;
   double            volume;
   datetime          oldest;
   int               count;
   int               winCount;   // positions in profit on this pair
   int               lossCount;  // positions in loss on this pair
  };

// Per-symbol adverse-bar sensor cache (streaks recompute on new bar only)
struct AdvCache
  {
   string            sym;
   string            canon;
   int               dir;         // last bus signal direction (+1/-1/0)
   datetime          barTime;     // forming-bar open time for InpAdverseTimeframe
   int               sellStreak;  // consecutive closed selling bars
   int               buyStreak;   // consecutive closed buying bars
  };

//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
CTrade         g_trade;
PosRec         g_pos[];
SymRec         g_sym[];
double         g_accPeak   = 0.0;
bool           g_accArmed  = false;

LivePos        g_live[];
SymAgg         g_agg[];
AdvCache       g_adv[];

string         g_allowList[];
string         g_prefix;
string         g_accCcy;
double         g_ccyFactor = 1.0;
datetime       g_ccyStamp  = 0;
uint           g_lastRun   = 0;
bool           g_busy      = false;
int            g_closedCycle = 0;
double         g_lastAccProfit = 0.0;
string         g_lastAction = "none";
datetime       g_statusStamp = 0;
//--- profit / loss categorisation (rebuilt every cycle)
int            g_winCount  = 0;   // harvest-qualified winners, account wide
double         g_winSum    = 0.0;
int            g_lossCount = 0;   // losing positions (profit targets leave them; adverse Auto may cut)
double         g_lossSum   = 0.0;
//--- session outcome tracking (every close this service performed)
int            g_closedSession  = 0;   // positions closed since the host started
double         g_realizedSession = 0.0; // profit banked at those closes
bool           gScoutEnabled = true;   // START/STOP scout arm (chart UI + GV)
bool           gAdverseEnabled = true; // AUTO adverse-bar loss exit arm (chart UI + GV)
string         g_btnPfx      = "PSBTN_";
string         g_pnlPfx      = "PSPNL_";
//--- adverse-bar Auto visibility (real-time bus / panel)
string         g_adverseLastSym    = "";
int            g_adverseLastStreak = 0;
int            g_adverseClosedCycle = 0;
#ifdef PS_HOST_EA
int            g_panelX = 10;
int            g_panelY = 18;
bool           g_panelDragging = false;
bool           g_panelDragOffSet = false;
int            g_panelDragOffX = 0;
int            g_panelDragOffY = 0;
int            g_panelLinesUsed = 0;
#endif

//+------------------------------------------------------------------+
//| Service entry point                                              |
//| A service has no chart and no OnTick/OnTimer: it owns its own    |
//| loop and must exit as soon as IsStopped() turns true.            |
//+------------------------------------------------------------------+
// OnStart / OnInit provided by host shell

void SubscribeSymbols()
  {
   if(InpScope == PS_SCOPE_ONE)
     {
      if(InpPrimarySymbol != "" && !SymbolSelect(InpPrimarySymbol, true))
         PrintFormat("ProfitScouter: cannot select %s", InpPrimarySymbol);
      return;
     }
   for(int i = 0; i < ArraySize(g_allowList); i++)
      if(!SymbolSelect(g_allowList[i], true))
         PrintFormat("ProfitScouter: cannot select %s", g_allowList[i]);
  }

//+------------------------------------------------------------------+
//| Main monitoring cycle                                            |
//+------------------------------------------------------------------+
void Monitor()
  {
   RefreshCurrencyFactor(false);

   //--- 1. collect eligible positions -------------------------------
   ArrayResize(g_live, 0);
   ArrayResize(g_agg, 0);
   g_winCount = 0;  g_winSum  = 0.0;
   g_lossCount = 0; g_lossSum = 0.0;

   MarkUnseen();

   double   accProfit = 0.0;
   datetime accOldest = 0;

   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;

      string sym   = PositionGetString(POSITION_SYMBOL);
      long   magic = PositionGetInteger(POSITION_MAGIC);
      if(!IsEligible(sym, magic))
         continue;

      double profit = PositionGetDouble(POSITION_PROFIT);
      if(InpIncludeSwap)
         profit += PositionGetDouble(POSITION_SWAP);
      if(InpIncludeCommission)
         profit += CachedCommission(ticket, (ulong)PositionGetInteger(POSITION_IDENTIFIER));

      LivePos lp;
      lp.ticket   = ticket;
      lp.magic    = magic;
      lp.sym      = sym;
      lp.profit   = profit;
      lp.volume   = PositionGetDouble(POSITION_VOLUME);
      lp.opened   = (datetime)PositionGetInteger(POSITION_TIME);
      lp.symIndex = AggIndex(sym);
      lp.posType  = PositionGetInteger(POSITION_TYPE);

      int n = ArraySize(g_live);
      ArrayResize(g_live, n + 1);
      g_live[n] = lp;

      //--- symbol aggregation + profit / loss bucketing
      g_agg[lp.symIndex].profit += profit;
      g_agg[lp.symIndex].volume += lp.volume;
      g_agg[lp.symIndex].count++;
      if(profit > 0.0)
        {
         g_agg[lp.symIndex].winCount++;
         g_winCount++;
         g_winSum += profit;
        }
      else
         if(profit < 0.0)
           {
            g_agg[lp.symIndex].lossCount++;
            g_lossCount++;
            g_lossSum += profit;
           }
      if(g_agg[lp.symIndex].oldest == 0 || lp.opened < g_agg[lp.symIndex].oldest)
         g_agg[lp.symIndex].oldest = lp.opened;

      //--- account aggregation
      accProfit += profit;
      if(accOldest == 0 || lp.opened < accOldest)
         accOldest = lp.opened;

      //--- always-on peak tracking (drives the profit lock in every mode)
      TrackPosPeak(TouchPosRec(ticket), profit);
     }

   g_lastAccProfit = accProfit;
   PurgeUnseen();

   if(ArraySize(g_live) == 0)
     {
      ResetAccountPeak();
      PsAfterCycle(0.0, 0);
      return;
     }

   //--- chart / shared START-STOP: watch only, no closes while STOPPED
   if(!gScoutEnabled)
     {
      g_lastAction = "scout STOPPED";
      PsAfterCycle(accProfit, ArraySize(g_live));
      return;
     }

   if(!TradingReady())
     {
      PsAfterCycle(accProfit, ArraySize(g_live));
      return;
     }

   //--- 1b. adverse-bar Auto loss exit (per symbol), then profit targeting
   if(HandleAdverseBarLossCut())
     {
      accProfit = 0.0;
      for(int i = 0; i < ArraySize(g_live); i++)
         accProfit += g_live[i].profit;
      g_lastAccProfit = accProfit;
     }

   //--- 2. account level ---------------------------------------------
   if(HandleAccount(accProfit, accOldest))
     {
      // winners-only harvest may leave tickets open when MinWin not yet met
      double rem = 0.0;
      for(int i = 0; i < ArraySize(g_live); i++)
         rem += g_live[i].profit;
      PsAfterCycle(rem, ArraySize(g_live));
      return;
     }

   //--- 3. per-pair level (ASAP: hard floor only; layered: full rules)
   bool basketClosed = false;
   for(int s = 0; s < ArraySize(g_agg); s++)
     {
      if(HandleSymbol(s))
         basketClosed = true;
     }
   if(basketClosed)
     {
      PsAfterCycle(accProfit, ArraySize(g_live));
      return;
     }

   //--- 4. per-position level ----------------------------------------
   for(int p = 0; p < ArraySize(g_live); p++)
      HandlePosition(p);

   PsAfterCycle(accProfit, ArraySize(g_live));
  }

//+------------------------------------------------------------------+
//| Account level handling                                           |
//+------------------------------------------------------------------+
bool HandleAccount(double profit, datetime oldest)
  {
   //--- losers are not closed by profit layers here: the account layer only
   //    banks winners. Same-symbol losers may be cut earlier by adverse Auto.

   int    age      = AgeMinutes(oldest);
   bool   inWindow = InWindow(age);
   bool   trailOk  = TrailAllowed(age);

   //--- hard target (ASAP when window gate off) — bank the threshold:
   //    close the MINIMAL winner set that covers the target, biggest
   //    winners first. Every other ticket (dust winners and ALL
   //    losers) stays open.
   double target = AsapFloorMoney();
   if(InpAccTargetPctBal > 0.0)
     {
      double byPct = AccountInfoDouble(ACCOUNT_BALANCE) * InpAccTargetPctBal / 100.0;
      target = (target > 0.0 ? MathMin(target, byPct) : byPct);
     }

   if(InpAccTargetEnable && target > 0.0 && profit >= target)
     {
      if(!InpTargetsWindowOnly || inWindow)
        {
         Notify(StringFormat("ACCOUNT target reached: %.2f >= %.2f %s - banking winners to cover the target",
                             profit, target, g_accCcy));
         double banked = HarvestWinners(target, "", "ACC-TARGET");
         // Only consume the cycle when something was banked. A net float
         // above target with no floor-qualified winners must not block
         // pair/position layers for this cycle.
         if(banked > 0.0)
           {
            ResetAccountPeak();
            g_lastAction = StringFormat("Account target banked %.2f", banked);
            return true;
           }
         g_lastAction = StringFormat("Account target %.2f hit, 0 banked (await MinWin)", target);
        }
     }

   //--- scalp ASAP: no trail / window force-close at account layer
   if(InpScalpAsapAccountOnly)
      return false;

   //--- trailing
   if(InpAccTrailEnable)
     {
      bool fire = TrailStep(profit, g_accPeak, g_accArmed,
                            Money(InpAccTrailArm), Money(InpAccTrailGiveMoney),
                            InpAccTrailGivePct, InpAccTrailMode);
      SaveAccountPeak();
      if(fire && trailOk && TrailCloseAllowed(profit))
        {
         Notify(StringFormat("ACCOUNT trail close: peak %.2f -> %.2f %s - banking current profit",
                             g_accPeak, profit, g_accCcy));
         double banked = HarvestWinners(profit, "", "ACC-TRAIL");
         if(banked > 0.0)
           {
            ResetAccountPeak();
            g_lastAction = StringFormat("Account trail banked %.2f", banked);
            return true;
           }
        }
     }

   //--- forced close at window end
   if(InpWindowEnable && InpCloseAtWindowEnd && age > InpWindowEndMin &&
      profit >= Money(InpWindowEndMinProfit) && InpWindowEndMinProfit > 0.0)
     {
      Notify(StringFormat("ACCOUNT window expired with %.2f %s - banking winners", profit, g_accCcy));
      double banked = HarvestWinners(profit, "", "ACC-WINDOW");
      if(banked > 0.0)
        {
         ResetAccountPeak();
         g_lastAction = StringFormat("Window end banked %.2f", banked);
         return true;
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Per-pair handling                                                |
//+------------------------------------------------------------------+
bool HandleSymbol(int aggIdx)
  {
   string sym    = g_agg[aggIdx].sym;
   double profit = g_agg[aggIdx].profit;
   int    age    = AgeMinutes(g_agg[aggIdx].oldest);
   bool   inWin  = InWindow(age);
   bool   trailOk = TrailAllowed(age);

   int r = SymIndex(sym, true);

   //--- hard target (ASAP: always armed from account floor) — bank the
   //    threshold from THIS pair's winners only: minimal winner set,
   //    other pairs and all losers untouched.
   double target = SymHardTarget();
   if(SymHardEnabled() && target > 0.0 && profit >= target)
     {
      if(!InpTargetsWindowOnly || inWin)
        {
         Notify(StringFormat("%s basket target reached: %.2f >= %.2f %s - banking this pair's winners",
                             sym, profit, target, g_accCcy));
         double banked = HarvestWinners(target, sym, "SYM-TARGET");
         if(banked > 0.0)
           {
            ResetSymPeak(r);
            g_lastAction = StringFormat("%s target banked %.2f", sym, banked);
            return true;
           }
         g_lastAction = StringFormat("%s target %.2f hit, 0 banked (await MinWin)", sym, target);
        }
     }

   //--- scalp ASAP: hard targets only — skip trail / window
   if(InpScalpAsapAccountOnly)
      return false;

   //--- trailing
   if(InpSymTrailEnable)
     {
      bool fire = TrailStep(profit, g_sym[r].peak, g_sym[r].armed,
                            Money(InpSymTrailArm), Money(InpSymTrailGiveMoney),
                            InpSymTrailGivePct, InpSymTrailMode);
      SaveSymPeak(r);
      if(fire && trailOk && TrailCloseAllowed(profit))
        {
         Notify(StringFormat("%s basket trail close: peak %.2f -> %.2f %s - banking current profit",
                             sym, g_sym[r].peak, profit, g_accCcy));
         double banked = HarvestWinners(profit, sym, "SYM-TRAIL");
         if(banked > 0.0)
           {
            ResetSymPeak(r);
            g_lastAction = StringFormat("%s trail banked %.2f", sym, banked);
            return true;
           }
        }
     }

   //--- window expiry
   if(InpWindowEnable && InpCloseAtWindowEnd && age > InpWindowEndMin &&
      InpWindowEndMinProfit > 0.0 && profit >= Money(InpWindowEndMinProfit))
     {
      Notify(StringFormat("%s window expired with %.2f %s - banking winners", sym, profit, g_accCcy));
      double banked = HarvestWinners(profit, sym, "SYM-WINDOW");
      if(banked > 0.0)
        {
         ResetSymPeak(r);
         g_lastAction = StringFormat("%s window banked %.2f", sym, banked);
         return true;
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Per-position handling                                            |
//+------------------------------------------------------------------+
void HandlePosition(int liveIdx)
  {
   ulong  ticket = g_live[liveIdx].ticket;
   double profit = g_live[liveIdx].profit;
   int    age    = AgeMinutes(g_live[liveIdx].opened);
   bool   inWin  = InWindow(age);
   bool   trailOk = TrailAllowed(age);

   if(!PositionSelectByTicket(ticket))
      return;

   int r = PosIndex(ticket, true);
   if(r < 0)
      return;

   //--- profit lock: once a trade has profited, close it while still green.
   //    Fires at keep-% of the recorded peak, BEFORE the give-back can run
   //    the ticket to zero - an armed ticket can never close on a loss.
   double lockFloor = LockFloor(r);
   if(lockFloor > 0.0 && profit > 0.0 && profit <= lockFloor)
     {
      // Enforce winner floor: do not profit-lock close below MinWinProfit
      if(InpMinWinProfit > 0.0 && profit < Money(InpMinWinProfit))
         return;
      Notify(StringFormat("#%I64u profit lock: peak %.2f -> %.2f <= floor %.2f %s - closing green",
                          ticket, g_pos[r].peak, profit, lockFloor, g_accCcy));
      if(CloseTicket(ticket, "PROFIT-LOCK"))
        {
         DropPosRec(ticket);
         g_lastAction = "Profit lock";
        }
      return;
     }

   //--- hard target (ASAP: always armed from account floor)
   double target = PosHardTarget();
   if(PosHardEnabled() && target > 0.0 && profit >= target)
     {
      if(!InpTargetsWindowOnly || inWin)
        {
         if(!InpScalpAsapAccountOnly && InpPosPartialPct > 0.0 && InpPosPartialPct < 100.0)
           {
            double vol = PartialVolume(g_live[liveIdx].sym, g_live[liveIdx].volume, InpPosPartialPct);
            if(vol > 0.0)
              {
               Notify(StringFormat("#%I64u target %.2f %s - partial close %.2f lots",
                                   ticket, profit, g_accCcy, vol));
               if(ClosePartial(ticket, vol))
                 {
                  g_pos[r].peak  = 0.0;
                  g_pos[r].armed = false;
                  SavePosPeak(r);
                  g_lastAction = "Partial close";
                 }
               return;
              }
           }
         Notify(StringFormat("#%I64u target reached: %.2f >= %.2f %s", ticket, profit, target, g_accCcy));
         if(CloseTicket(ticket, "POS-TARGET"))
           {
            DropPosRec(ticket);
            g_lastAction = "Position target";
           }
         return;
        }
     }

   //--- scalp ASAP: hard targets only — skip trail / window
   if(InpScalpAsapAccountOnly)
      return;

   //--- trailing
   if(InpPosTrailEnable)
     {
      bool fire = TrailStep(profit, g_pos[r].peak, g_pos[r].armed,
                            Money(InpPosTrailArm), Money(InpPosTrailGiveMoney),
                            InpPosTrailGivePct, InpPosTrailMode);
      SavePosPeak(r);
      if(fire && trailOk && TrailCloseAllowed(profit))
        {
         Notify(StringFormat("#%I64u trail close: peak %.2f -> %.2f %s",
                             ticket, g_pos[r].peak, profit, g_accCcy));
         if(CloseTicket(ticket, "POS-TRAIL"))
           {
            DropPosRec(ticket);
            g_lastAction = "Position trail";
           }
         return;
        }
     }

   //--- window expiry
   if(InpWindowEnable && InpCloseAtWindowEnd && age > InpWindowEndMin &&
      InpWindowEndMinProfit > 0.0 && profit >= Money(InpWindowEndMinProfit))
     {
      Notify(StringFormat("#%I64u window expired with %.2f %s - closing", ticket, profit, g_accCcy));
      if(CloseTicket(ticket, "POS-WINDOW"))
        {
         DropPosRec(ticket);
         g_lastAction = "Position window end";
        }
     }
  }

//+------------------------------------------------------------------+
//| Always-on peak tracking + profit lock arming                     |
//| Runs every cycle for every monitored position, in every mode,    |
//| so the engine always knows how far a trade has run into profit. |
//+------------------------------------------------------------------+
void TrackPosPeak(const int r, const double profit)
  {
   if(r < 0 || r >= ArraySize(g_pos))
      return;

   if(profit > g_pos[r].peak)
     {
      g_pos[r].peak = profit;
      SavePosPeak(r);                       // survives terminal restart
     }

   if(InpProfitLockEnable && !g_pos[r].lockArmed && g_pos[r].peak >= Money(InpProfitLockArm))
     {
      g_pos[r].lockArmed = true;
      if(InpVerboseLog)
         PrintFormat("ProfitScouter: #%I64u profit lock ARMED (peak %.2f >= %.2f %s)",
                      g_pos[r].ticket, g_pos[r].peak, Money(InpProfitLockArm), g_accCcy);
     }
  }

// Guaranteed floor of an armed lock: keep-% of the recorded peak.
double LockFloor(const int r)
  {
   if(r < 0 || r >= ArraySize(g_pos))
      return(0.0);
   if(!InpProfitLockEnable || !g_pos[r].lockArmed)
      return(0.0);
   double floor = g_pos[r].peak * InpProfitLockKeepPct / 100.0;
   // Never bank a locked winner below the configured winner floor (ASAP default 5)
   if(InpMinWinProfit > 0.0)
      floor = MathMax(floor, Money(InpMinWinProfit));
   return(floor);
  }

//+------------------------------------------------------------------+
//| Generic peak / give-back engine                                  |
//| Returns true when the give-back condition fires.                 |
//+------------------------------------------------------------------+
bool TrailStep(double profit, double &peak, bool &armed,
               double armLevel, double giveMoney, double givePct,
               ENUM_PS_TRAIL mode)
  {
   if(profit > peak)
      peak = profit;

   if(!armed)
     {
      if(armLevel <= 0.0 || profit >= armLevel)
         armed = (peak > 0.0);
      if(!armed)
         return false;
     }

   if(peak <= 0.0)
      return false;

   double drop = peak - profit;
   if(drop <= 0.0)
      return false;

   bool hitMoney = (giveMoney > 0.0 && drop >= giveMoney);
   bool hitPct   = (givePct   > 0.0 && drop >= peak * givePct / 100.0);

   if(mode == PS_TRAIL_MONEY)
      return hitMoney;
   if(mode == PS_TRAIL_PERCENT)
      return hitPct;
   return (hitMoney || hitPct);
  }

//+------------------------------------------------------------------+
//| Window helpers                                                   |
//+------------------------------------------------------------------+
int AgeMinutes(datetime opened)
  {
   if(opened == 0)
      return 0;
   long secs = (long)(TimeCurrent() - opened);
   if(secs < 0)
      secs = 0;
   return (int)(secs / 60);
  }

bool InWindow(int ageMin)
  {
   if(!InpWindowEnable)
      return true;
   return (ageMin >= InpWindowStartMin && ageMin <= InpWindowEndMin);
  }

bool TrailAllowed(int ageMin)
  {
   if(!InpWindowEnable)
      return true;
   if(ageMin < InpWindowStartMin)
      return false;
   if(ageMin > InpWindowEndMin)
      return InpTrailAfterWindow;
   return true;
  }

bool TrailCloseAllowed(double profit)
  {
   if(!InpTrailRequirePositive)
      return true;
   return (profit >= Money(InpTrailMinCloseProfit));
  }

//+------------------------------------------------------------------+
//| Currency conversion                                              |
//+------------------------------------------------------------------+
string TargetCcy()
  {
   string c = InpTargetCurrency;
   StringTrimLeft(c);
   StringTrimRight(c);
   StringToUpper(c);
   if(c == "")
      return g_accCcy;
   return c;
  }

double Money(double amountInTargetCcy)
  {
   return amountInTargetCcy * g_ccyFactor;
  }

// Scalp ASAP single floor (InpAccTargetMoney) drives account + pair + position hard closes.
double AsapFloorMoney()
  {
   return Money(InpAccTargetMoney);
  }

bool SymHardEnabled()
  {
   return (InpScalpAsapAccountOnly || InpSymTargetEnable);
  }

double SymHardTarget()
  {
   if(InpScalpAsapAccountOnly)
      return AsapFloorMoney();
   return Money(InpSymTargetMoney);
  }

bool PosHardEnabled()
  {
   return (InpScalpAsapAccountOnly || InpPosTargetEnable);
  }

double PosHardTarget()
  {
   if(InpScalpAsapAccountOnly)
      return AsapFloorMoney();
   return Money(InpPosTargetMoney);
  }

void RefreshCurrencyFactor(bool force)
  {
   if(!force && TimeCurrent() - g_ccyStamp < 60)
      return;
   g_ccyStamp = TimeCurrent();

   string from = TargetCcy();
   if(from == g_accCcy)
     {
      g_ccyFactor = 1.0;
      return;
     }

   double r = ConvRate(from, g_accCcy);
   if(r > 0.0)
      g_ccyFactor = r;
   else
     {
      g_ccyFactor = 1.0;
      if(force)
         PrintFormat("ProfitScouter: no conversion path %s->%s, using factor 1.0", from, g_accCcy);
     }
  }

double ConvRate(string from, string to)
  {
   if(from == to)
      return 1.0;
   double d = DirectRate(from, to);
   if(d > 0.0)
      return d;

   string bridges[3] = {"USD", "EUR", "GBP"};
   for(int i = 0; i < 3; i++)
     {
      if(bridges[i] == from || bridges[i] == to)
         continue;
      double a = DirectRate(from, bridges[i]);
      double b = DirectRate(bridges[i], to);
      if(a > 0.0 && b > 0.0)
         return a * b;
     }
   return 0.0;
  }

double DirectRate(string from, string to)
  {
   if(from == to)
      return 1.0;
   int total = SymbolsTotal(false);
   for(int i = 0; i < total; i++)
     {
      string s = SymbolName(i, false);
      string b = SymbolInfoString(s, SYMBOL_CURRENCY_BASE);
      string p = SymbolInfoString(s, SYMBOL_CURRENCY_PROFIT);

      if(b == from && p == to)
        {
         double px = Mid(s);
         if(px > 0.0)
            return px;
        }
      if(b == to && p == from)
        {
         double px = Mid(s);
         if(px > 0.0)
            return 1.0 / px;
        }
     }
   return 0.0;
  }

double Mid(string sym)
  {
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
     {
      if(!SymbolSelect(sym, true))
         return 0.0;
      bid = SymbolInfoDouble(sym, SYMBOL_BID);
      ask = SymbolInfoDouble(sym, SYMBOL_ASK);
     }
   if(bid <= 0.0 || ask <= 0.0)
      return 0.0;
   return (bid + ask) / 2.0;
  }

//+------------------------------------------------------------------+
//| Filters                                                          |
//+------------------------------------------------------------------+
void BuildAllowList()
  {
   ArrayResize(g_allowList, 0);
   if(InpScope != PS_SCOPE_LIST)
      return;

   string parts[];
   int n = StringSplit(InpSymbolList, StringGetCharacter(",", 0), parts);
   for(int i = 0; i < n; i++)
     {
      string s = parts[i];
      StringTrimLeft(s);
      StringTrimRight(s);
      if(s == "")
         continue;
      int k = ArraySize(g_allowList);
      ArrayResize(g_allowList, k + 1);
      g_allowList[k] = s;
     }
  }

bool IsEligible(string sym, long magic)
  {
   if(InpUseMagicFilter && magic != InpMagicNumber)
      return false;

   if(InpScope == PS_SCOPE_ONE)
     {
#ifdef PS_HOST_SERVICE
      return (sym == InpPrimarySymbol);
#else
      return (sym == _Symbol);
#endif
     }

   if(InpScope == PS_SCOPE_LIST)
     {
      for(int i = 0; i < ArraySize(g_allowList); i++)
         if(g_allowList[i] == sym)
            return true;
      return false;
     }
   return true;
  }

bool TradingReady()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      return false;
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      return false;
   return true;
  }

bool SymbolClosable(string sym)
  {
   long mode = SymbolInfoInteger(sym, SYMBOL_TRADE_MODE);
   return (mode == SYMBOL_TRADE_MODE_FULL ||
           mode == SYMBOL_TRADE_MODE_CLOSEONLY ||
           mode == SYMBOL_TRADE_MODE_LONGONLY ||
           mode == SYMBOL_TRADE_MODE_SHORTONLY);
  }

//+------------------------------------------------------------------+
//| Closing routines                                                 |
//+------------------------------------------------------------------+
// Live profit of the currently selected position (incl. swap and
// commission per the include settings) - the value the loser guard
// compares against immediately before a close is sent.
double LiveProfitOfSelected()
  {
   double p = PositionGetDouble(POSITION_PROFIT);
   if(InpIncludeSwap)
      p += PositionGetDouble(POSITION_SWAP);
   if(InpIncludeCommission)
      p += DealCommission((ulong)PositionGetInteger(POSITION_IDENTIFIER));
   return p;
  }

bool CloseTicket(ulong ticket, string tag, const bool allowLoss = false)
  {
   if(!PositionSelectByTicket(ticket))
      return false;

   string sym = PositionGetString(POSITION_SYMBOL);
   if(!SymbolClosable(sym))
     {
      if(InpVerboseLog)
         PrintFormat("ProfitScouter: %s not closable right now (market closed?)", sym);
      return false;
     }

   //--- HARD GUARD: by default Profit Scouter never closes a losing trade.
   //    The only intentional exception is adverse-bar Auto (allowLoss=true).
   double liveProfit = LiveProfitOfSelected();
   if(liveProfit < 0.0 && !allowLoss)
     {
      PrintFormat("ProfitScouter [%s]: close #%I64u %s BLOCKED - never closes a losing trade (%.2f)",
                  tag, ticket, sym, liveProfit);
      return false;
     }

   g_trade.SetExpertMagicNumber((ulong)PositionGetInteger(POSITION_MAGIC));
   g_trade.SetTypeFillingBySymbol(sym);
   g_trade.SetDeviationInPoints(InpSlippagePoints);

   int tries = (int)MathMax(1, InpMaxRetries);
   for(int a = 0; a < tries; a++)
     {
      if(g_trade.PositionClose(ticket, InpSlippagePoints))
        {
         PrintFormat("ProfitScouter [%s]: closed #%I64u %s (%.2f)",
                     tag, ticket, sym, liveProfit);
         g_closedCycle++;
         g_closedSession++;
         g_realizedSession += liveProfit;
         return true;
        }
      uint rc = g_trade.ResultRetcode();
      PrintFormat("ProfitScouter [%s]: close #%I64u failed rc=%u (%s)",
                  tag, ticket, rc, g_trade.ResultRetcodeDescription());
      if(rc == TRADE_RETCODE_MARKET_CLOSED || rc == TRADE_RETCODE_NO_MONEY ||
         rc == TRADE_RETCODE_TRADE_DISABLED)
         break;
      Sleep(200);
      if(!PositionSelectByTicket(ticket))
         return true; // gone already
     }
   return false;
  }

bool ClosePartial(ulong ticket, double volume)
  {
   if(!PositionSelectByTicket(ticket))
      return false;
   string sym = PositionGetString(POSITION_SYMBOL);

   //--- HARD GUARD: a partial close of a losing trade is a loss, too.
   double liveProfit = LiveProfitOfSelected();
   if(liveProfit < 0.0)
     {
      PrintFormat("ProfitScouter: partial close #%I64u %s BLOCKED - never closes a losing trade (%.2f)",
                  ticket, sym, liveProfit);
      return false;
     }

   g_trade.SetExpertMagicNumber((ulong)PositionGetInteger(POSITION_MAGIC));
   g_trade.SetTypeFillingBySymbol(sym);

   int tries = (int)MathMax(1, InpMaxRetries);
   for(int a = 0; a < tries; a++)
     {
      if(g_trade.PositionClosePartial(ticket, volume, InpSlippagePoints))
        {
         PrintFormat("ProfitScouter: partial close #%I64u %.2f lots", ticket, volume);
         return true;
        }
      PrintFormat("ProfitScouter: partial close #%I64u failed rc=%u (%s)",
                  ticket, g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
      Sleep(200);
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Adverse-bar Auto loss exit (symmetric, per-symbol)               |
//| BUY signal + selling closed bars > N  → close losers on symbol   |
//| SELL signal + buying closed bars > N → close losers on symbol    |
//| Profit targeting continues afterward at set levels.              |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES PsAdverseTf()
  {
   ENUM_TIMEFRAMES tf = InpAdverseTimeframe;
#ifdef PS_HOST_EA
   if(tf == PERIOD_CURRENT)
      return((ENUM_TIMEFRAMES)Period());
#else
   if(tf == PERIOD_CURRENT)
      return(PERIOD_M15);   // Service has no chart
#endif
   return(tf);
  }

int PsAdvCacheIndex(const string sym, const bool create)
  {
   for(int i = 0; i < ArraySize(g_adv); i++)
      if(g_adv[i].sym == sym)
         return(i);
   if(!create)
      return(-1);
   int n = ArraySize(g_adv);
   ArrayResize(g_adv, n + 1);
   g_adv[n].sym        = sym;
   g_adv[n].canon      = GsxSymbolCanon(sym);
   g_adv[n].dir        = 0;
   g_adv[n].barTime    = 0;
   g_adv[n].sellStreak = 0;
   g_adv[n].buyStreak  = 0;
   return(n);
  }

int PsReadLastSignalDir(const string sym)
  {
   string tid   = GsxMakeTid();
   string canon = GsxSymbolCanon(sym);
   string j     = GsxBusReadAll(GsxBusSignalPath(tid, canon));
   if(j == "")
      return(0);
   return((int)GsxJsonGetLong(j, "direction", 0));
  }

void PsRefreshAdvCache(const string sym)
  {
   int ix = PsAdvCacheIndex(sym, true);
   if(ix < 0)
      return;

   ENUM_TIMEFRAMES tf = PsAdverseTf();
   datetime        bt = iTime(sym, tf, 0);

   // Bus direction: refresh every cycle (cheap file read of fixed JSON)
   g_adv[ix].dir = PsReadLastSignalDir(sym);

   // Streaks: only recompute when the forming bar advances
   if(bt != 0 && bt != g_adv[ix].barTime)
     {
      g_adv[ix].barTime    = bt;
      g_adv[ix].sellStreak = GsxCountConsecutiveClosedBars(sym, tf, -1);
      g_adv[ix].buyStreak  = GsxCountConsecutiveClosedBars(sym, tf,  1);
     }
  }

string PsAdvFireVar(const string canon)
  {
   return(StringFormat("%sADV_%s", g_prefix, canon));
  }

bool PsAdvAlreadyFiredThisBar(const string canon, const datetime barTime)
  {
   if(barTime <= 0)
      return(true);
   string n = PsAdvFireVar(canon);
   if(!GlobalVariableCheck(n))
      return(false);
   return((datetime)GlobalVariableGet(n) == barTime);
  }

void PsAdvMarkFired(const string canon, const datetime barTime)
  {
   if(barTime <= 0)
      return;
   GlobalVariableSet(PsAdvFireVar(canon), (double)barTime);
  }

// True when adverse Auto may cut this live loser (hold age + once-green).
bool AdverseEligibleLoser(const int liveIdx)
  {
   if(liveIdx < 0 || liveIdx >= ArraySize(g_live))
      return(false);
   if(g_live[liveIdx].profit >= 0.0)
      return(false);

   if(InpAdverseMinAgeMin > 0)
     {
      int age = AgeMinutes(g_live[liveIdx].opened);
      if(age < InpAdverseMinAgeMin)
        {
         if(InpVerboseLog)
            PrintFormat("ProfitScouter [ADVERSE-BAR]: skip #%I64u %s age=%d < minAge=%d",
                        g_live[liveIdx].ticket, g_live[liveIdx].sym, age, InpAdverseMinAgeMin);
         return(false);
        }
     }

   if(InpAdverseProtectOnceGreen)
     {
      int r = PosIndex(g_live[liveIdx].ticket, false);
      if(r >= 0 && (g_pos[r].lockArmed || g_pos[r].peak > 0.0))
        {
         if(InpVerboseLog)
            PrintFormat("ProfitScouter [ADVERSE-BAR]: skip #%I64u %s once-green peak=%.2f lock=%s",
                        g_live[liveIdx].ticket, g_live[liveIdx].sym, g_pos[r].peak,
                        (g_pos[r].lockArmed ? "Y" : "N"));
         return(false);
        }
     }
   return(true);
  }

// Close eligible red tickets on one symbol (deepest loss first). Winners untouched.
bool CloseLosersOnSymbol(const string sym, const string tag)
  {
   int idxs[];
   int n = ArraySize(g_live);
   ArrayResize(idxs, n);
   int m = 0;
   for(int i = 0; i < n; i++)
     {
      if(g_live[i].sym != sym)
         continue;
      if(!AdverseEligibleLoser(i))
         continue;
      idxs[m++] = i;
     }
   ArrayResize(idxs, m);
   if(m <= 0)
      return(false);

   SortIdxsByProfit(idxs, m, false);   // deepest losers first

   int closed = 0;
   for(int k = 0; k < m; k++)
     {
      int i = idxs[k];
      if(CloseTicket(g_live[i].ticket, tag, true))
        {
         DropPosRec(g_live[i].ticket);
         closed++;
        }
     }
   if(closed > 0)
      CompactLiveKeepOpen();
   return(closed > 0);
  }

bool HandleAdverseBarLossCut()
  {
   g_adverseClosedCycle = 0;
   if(!gAdverseEnabled)
      return(false);

   bool any = false;
   const int minBars = (int)MathMax(0, InpAdverseMinBars);

   for(int s = 0; s < ArraySize(g_agg); s++)
     {
      if(g_agg[s].lossCount <= 0)
         continue;

      string sym = g_agg[s].sym;
      PsRefreshAdvCache(sym);
      int ix = PsAdvCacheIndex(sym, false);
      if(ix < 0)
         continue;

      int dir = g_adv[ix].dir;
      if(InpAdverseRequireSignal && dir == 0)
         continue;

      int  streak = 0;
      bool fire   = false;
      if(dir == 1 && g_adv[ix].sellStreak > minBars)
        {
         fire   = true;
         streak = g_adv[ix].sellStreak;
        }
      else
         if(dir == -1 && g_adv[ix].buyStreak > minBars)
           {
            fire   = true;
            streak = g_adv[ix].buyStreak;
           }

      if(!fire)
         continue;
      if(PsAdvAlreadyFiredThisBar(g_adv[ix].canon, g_adv[ix].barTime))
         continue;

      // Claim this bar before closes so a second host (Service+EA) does not
      // race the same symbol/bar. Claim only when at least one loser is eligible.
      bool anyEligible = false;
      for(int li = 0; li < ArraySize(g_live); li++)
        {
         if(g_live[li].sym == sym && AdverseEligibleLoser(li))
           {
            anyEligible = true;
            break;
           }
        }
      if(!anyEligible)
         continue;

      PsAdvMarkFired(g_adv[ix].canon, g_adv[ix].barTime);

      int before = g_closedCycle;
      if(CloseLosersOnSymbol(sym, "ADVERSE-BAR"))
        {
         int closedNow = g_closedCycle - before;
         g_adverseClosedCycle += closedNow;
         g_adverseLastSym     = sym;
         g_adverseLastStreak  = streak;
         g_lastAction = StringFormat("ADVERSE-BAR %s dir=%d streak=%d closed=%d",
                                     sym, dir, streak, closedNow);
         Notify(g_lastAction);
         any = true;
        }
      else
        {
         g_lastAction = StringFormat("ADVERSE-BAR %s dir=%d streak=%d closed=0",
                                     sym, dir, streak);
        }
     }
   return(any);
  }

//+------------------------------------------------------------------+
//| Profit / loss categorisation + minimal threshold harvest         |
//|                                                                  |
//| Every cycle the live set is bucketed into winners and losers    |
//| (see Monitor). All profit closes go through HarvestWinners:     |
//| it banks exactly the threshold amount using the smallest set    |
//| of green tickets (biggest first) and never touches losers or    |
//| other pairs. Adverse-bar Auto (HandleAdverseBarLossCut) is the  |
//| sole path that may close same-symbol losers.                     |
//+------------------------------------------------------------------+
// Sort live indices by cached profit (desc = biggest winner first,
// asc = deepest loser first).
void SortIdxsByProfit(int &idxs[], const int m, const bool desc)
  {
   for(int a = 0; a < m - 1; a++)
      for(int b = a + 1; b < m; b++)
        {
         bool swap = desc ? (g_live[idxs[b]].profit > g_live[idxs[a]].profit)
                          : (g_live[idxs[b]].profit < g_live[idxs[a]].profit);
         if(swap)
           {
            int tmp = idxs[a];
            idxs[a] = idxs[b];
            idxs[b] = tmp;
           }
        }
  }

// Collect the indices of the green tickets from the live set, sorted
// biggest winner first. sym == "" selects the whole account scope.
// Losing tickets are never selected here — profit harvest only.
int SelectBucket(const bool winners, const string sym, int &idxs[])
  {
   int n = ArraySize(g_live);
   ArrayResize(idxs, n);
   int m = 0;
   for(int i = 0; i < n; i++)
     {
      if(sym != "" && g_live[i].sym != sym)
         continue;
      if(!winners)
         continue;                    // profit path never selects losers
      if(IsProfitableTicket(g_live[i].profit))
         idxs[m++] = i;
     }
   ArrayResize(idxs, m);
   SortIdxsByProfit(idxs, m, winners);
   return(m);
  }

// Bank `need` of profit: close the minimal set of winners (biggest
// first) whose cumulative profit covers the threshold, then STOP -
// remaining winners keep running and losers stay untouched.
// sym == "" -> account scope. Returns the profit actually banked.
double HarvestWinners(const double need, const string sym, const string tag)
  {
   if(need <= 0.0)
      return(0.0);

   int idxs[];
   int m = SelectBucket(true, sym, idxs);
   if(m <= 0)
      return(0.0);

   double banked = 0.0;
   int    closed = 0;
   for(int k = 0; k < m && banked < need; k++)
     {
      int i = idxs[k];
      if(CloseTicket(g_live[i].ticket, tag))
        {
         DropPosRec(g_live[i].ticket);
         banked += g_live[i].profit;
         closed++;
        }
     }
   if(closed > 0)
      CompactLiveKeepOpen();
   return(banked);
  }

// Winner-harvest floor: a green ticket qualifies for a profit close only
// when it has reached InpMinWinProfit (target ccy). Dust tickets between
// 0 and the floor stay open and keep running toward it. 0 = legacy > 0.
bool IsProfitableTicket(double profit)
  {
   if(profit <= 0.0)
      return(false);
   if(InpMinWinProfit > 0.0)
      return(profit >= Money(InpMinWinProfit));
   return(true);
  }

void CompactLiveKeepOpen()
  {
   int n = ArraySize(g_live);
   if(n <= 0)
      return;

   LivePos keep[];
   int m = 0;
   for(int i = 0; i < n; i++)
     {
      if(!PositionSelectByTicket(g_live[i].ticket))
         continue;
      ArrayResize(keep, m + 1);
      keep[m++] = g_live[i];
     }
   ArrayResize(g_live, m);
   for(int i = 0; i < m; i++)
      g_live[i] = keep[i];
  }

double PartialVolume(string sym, double volume, double pct)
  {
   double step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   double minv = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   if(step <= 0.0)
      step = 0.01;

   double want = volume * pct / 100.0;
   want = MathFloor(want / step) * step;
   want = NormalizeDouble(want, 2);

   if(want < minv)
      return 0.0;
   if(volume - want < minv)
      return 0.0;   // remainder would be invalid -> caller closes in full
   return want;
  }

//+------------------------------------------------------------------+
//| Commission cache                                                 |
//+------------------------------------------------------------------+
double CachedCommission(ulong ticket, ulong identifier)
  {
   int r = PosIndex(ticket, true);
   if(r < 0)
      return 0.0;
   if(!g_pos[r].commLoaded)
     {
      g_pos[r].commission = DealCommission(identifier);
      g_pos[r].commLoaded = true;
     }
   return g_pos[r].commission;
  }

double DealCommission(ulong identifier)
  {
   double c = 0.0;
   if(HistorySelectByPosition(identifier))
     {
      int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; i++)
        {
         ulong d = HistoryDealGetTicket(i);
         if(d > 0)
            c += HistoryDealGetDouble(d, DEAL_COMMISSION);
        }
     }
   return c;
  }

//+------------------------------------------------------------------+
//| Record management                                                |
//+------------------------------------------------------------------+
int AggIndex(string sym)
  {
   for(int i = 0; i < ArraySize(g_agg); i++)
      if(g_agg[i].sym == sym)
         return i;

   int n = ArraySize(g_agg);
   ArrayResize(g_agg, n + 1);
   g_agg[n].sym    = sym;
   g_agg[n].profit = 0.0;
   g_agg[n].volume = 0.0;
   g_agg[n].oldest = 0;
   g_agg[n].count  = 0;
   g_agg[n].winCount  = 0;
   g_agg[n].lossCount = 0;
   return n;
  }

int PosIndex(ulong ticket, bool createIfMissing)
  {
   for(int i = 0; i < ArraySize(g_pos); i++)
      if(g_pos[i].ticket == ticket)
         return i;

   if(!createIfMissing)
      return -1;

   int n = ArraySize(g_pos);
   ArrayResize(g_pos, n + 1);
   g_pos[n].ticket     = ticket;
   g_pos[n].peak       = LoadPeak("P", (string)ticket);
   g_pos[n].armed      = (g_pos[n].peak > 0.0);
   g_pos[n].commission = 0.0;
   g_pos[n].commLoaded = false;
   g_pos[n].seen       = true;
   // lock re-arms from the persisted peak (survives terminal restart)
   g_pos[n].lockArmed  = (InpProfitLockEnable && g_pos[n].peak >= Money(InpProfitLockArm));
   return n;
  }

int SymIndex(string sym, bool createIfMissing)
  {
   for(int i = 0; i < ArraySize(g_sym); i++)
      if(g_sym[i].sym == sym)
         return i;

   if(!createIfMissing)
      return -1;

   int n = ArraySize(g_sym);
   ArrayResize(g_sym, n + 1);
   g_sym[n].sym   = sym;
   g_sym[n].peak  = LoadPeak("S", sym);
   g_sym[n].armed = (g_sym[n].peak > 0.0);
   g_sym[n].seen  = true;
   return n;
  }

int TouchPosRec(ulong ticket)
  {
   int r = PosIndex(ticket, true);
   if(r >= 0)
      g_pos[r].seen = true;
   int s = -1;
   if(PositionSelectByTicket(ticket))
      s = SymIndex(PositionGetString(POSITION_SYMBOL), true);
   if(s >= 0)
      g_sym[s].seen = true;
   return(r);
  }

void MarkUnseen()
  {
   for(int i = 0; i < ArraySize(g_pos); i++)
      g_pos[i].seen = false;
   for(int i = 0; i < ArraySize(g_sym); i++)
      g_sym[i].seen = false;
  }

void PurgeUnseen()
  {
   for(int i = ArraySize(g_pos) - 1; i >= 0; i--)
      if(!g_pos[i].seen)
         DropPosAt(i);

   for(int i = ArraySize(g_sym) - 1; i >= 0; i--)
      if(!g_sym[i].seen)
        {
         DelPeak("S", g_sym[i].sym);
         RemoveSymAt(i);
        }
  }

void DropPosRec(ulong ticket)
  {
   int r = PosIndex(ticket, false);
   if(r >= 0)
      DropPosAt(r);
  }

void DropPosAt(int idx)
  {
   if(idx < 0 || idx >= ArraySize(g_pos))
      return;
   DelPeak("P", (string)g_pos[idx].ticket);
   int last = ArraySize(g_pos) - 1;
   for(int i = idx; i < last; i++)
      g_pos[i] = g_pos[i + 1];
   ArrayResize(g_pos, last);
  }

void RemoveSymAt(int idx)
  {
   if(idx < 0 || idx >= ArraySize(g_sym))
      return;
   int last = ArraySize(g_sym) - 1;
   for(int i = idx; i < last; i++)
      g_sym[i] = g_sym[i + 1];
   ArrayResize(g_sym, last);
  }

void ResetSymPeak(int idx)
  {
   if(idx < 0 || idx >= ArraySize(g_sym))
      return;
   g_sym[idx].peak  = 0.0;
   g_sym[idx].armed = false;
   DelPeak("S", g_sym[idx].sym);
  }

void ResetAccountPeak()
  {
   g_accPeak  = 0.0;
   g_accArmed = false;
   DelPeak("A", "0");
  }

//+------------------------------------------------------------------+
//| Peak persistence (survives terminal restart)                     |
//+------------------------------------------------------------------+
string GVName(string kind, string id)
  {
   return g_prefix + kind + "_" + id;
  }

double LoadPeak(string kind, string id)
  {
   if(!InpPersistPeaks)
      return 0.0;
   string n = GVName(kind, id);
   if(GlobalVariableCheck(n))
      return GlobalVariableGet(n);
   return 0.0;
  }

void SavePeak(string kind, string id, double value)
  {
   if(!InpPersistPeaks)
      return;
   if(value <= 0.0)
      return;
   GlobalVariableSet(GVName(kind, id), value);
  }

void DelPeak(string kind, string id)
  {
   if(!InpPersistPeaks)
      return;
   string n = GVName(kind, id);
   if(GlobalVariableCheck(n))
      GlobalVariableDel(n);
  }

void SavePosPeak(int idx)
  {
   if(idx >= 0 && idx < ArraySize(g_pos))
      SavePeak("P", (string)g_pos[idx].ticket, g_pos[idx].peak);
  }

void SaveSymPeak(int idx)
  {
   if(idx >= 0 && idx < ArraySize(g_sym))
      SavePeak("S", g_sym[idx].sym, g_sym[idx].peak);
  }

void SaveAccountPeak()
  {
   SavePeak("A", "0", g_accPeak);
  }

void LoadAccountPeak()
  {
   g_accPeak  = LoadPeak("A", "0");
   g_accArmed = (g_accPeak > 0.0);
  }

void CleanupStaleGlobals()
  {
   if(!InpPersistPeaks)
      return;
   string tag = g_prefix + "P_";
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
     {
      string n = GlobalVariableName(i);
      if(StringFind(n, tag) != 0)
         continue;
      string idStr = StringSubstr(n, StringLen(tag));
      ulong  ticket = (ulong)StringToInteger(idStr);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         GlobalVariableDel(n);
     }
  }

//+------------------------------------------------------------------+
//| Status output                                                    |
//| No chart, so the dashboard goes to the Experts log and,          |
//| optionally, to a text file in MQL5\\Files that you can tail or    |
//| read from another program.                                       |
//+------------------------------------------------------------------+
int LockedPosCount()
  {
   int c = 0;
   for(int i = 0; i < ArraySize(g_pos); i++)
      if(g_pos[i].lockArmed)
         c++;
   return(c);
  }

#ifdef PS_HOST_SERVICE
void LogStatus(double accProfit, int count)
  {
   if(!InpLogStatus && !InpWriteStatusFile)
      return;

   int every = (int)MathMax(5, InpStatusEverySec);
   if(g_statusStamp != 0 && TimeCurrent() - g_statusStamp < every)
      return;
   g_statusStamp = TimeCurrent();

   string head1 = StringFormat("=== ProfitScouter #%d | %s | targets in %s (x%.5f) | %s ===",
                               InpInstanceID, g_accCcy, TargetCcy(), g_ccyFactor,
                               TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
   string head2 = StringFormat("scope=%s magic=%s interval=%dms window=%s %d-%d min trailAfter=%s scout=%s trading=%s",
                               ScopeText(),
                               (InpUseMagicFilter ? (string)InpMagicNumber : "any"),
                               (int)MathMax(100, InpCheckIntervalMs),
                               (InpWindowEnable ? "ON" : "OFF"), InpWindowStartMin, InpWindowEndMin,
                               (InpTrailAfterWindow ? "yes" : "no"),
                               (gScoutEnabled ? "START" : "STOP"),
                               (TradingReady() ? "enabled" : "BLOCKED"));
   string head3 = StringFormat("positions=%d  floating=%.2f %s  accPeak=%.2f %s  accTarget=%.2f  last=%s",
                               count, accProfit, g_accCcy, g_accPeak,
                               (g_accArmed ? "[ARMED]" : ""), Money(InpAccTargetMoney), g_lastAction);
   string head4 = StringFormat("lock=%s arm>=%.2f keep=%.0f%% locked=%d | win floor=%.2f %s",
                               (InpProfitLockEnable ? "ON" : "OFF"), Money(InpProfitLockArm),
                               InpProfitLockKeepPct, LockedPosCount(), Money(InpMinWinProfit), g_accCcy);
   string head5 = StringFormat("winners=%d (+%.2f)  losers=%d (%.2f)  |  closed=%d realized=%.2f",
                               g_winCount, g_winSum, g_lossCount, g_lossSum,
                               g_closedSession, g_realizedSession);
   string head6 = StringFormat("adverse=%s minBars>%d minAge=%d onceGreen=%s last=%s streak=%d closed=%d",
                               (gAdverseEnabled ? "ON" : "OFF"), InpAdverseMinBars, InpAdverseMinAgeMin,
                               (InpAdverseProtectOnceGreen ? "protect" : "cut"),
                               (g_adverseLastSym == "" ? "-" : g_adverseLastSym),
                               g_adverseLastStreak, g_adverseClosedCycle);

   if(InpLogStatus)
     {
      Print(head1);
      Print(head2);
      Print(head3);
      Print(head4);
      Print(head5);
      Print(head6);
     }

   string body = head1 + "\n" + head2 + "\n" + head3 + "\n" + head4 + "\n" + head5 + "\n" + head6 + "\n";

   for(int i = 0; i < ArraySize(g_agg); i++)
     {
      int    r     = SymIndex(g_agg[i].sym, false);
      double peak  = (r >= 0 ? g_sym[r].peak : 0.0);
      bool   armed = (r >= 0 ? g_sym[r].armed : false);
      string line  = StringFormat("  %-12s n=%d (w%d/l%d)  P/L %8.2f  peak %8.2f  age %4d min %s",
                                  g_agg[i].sym, g_agg[i].count, g_agg[i].winCount,
                                  g_agg[i].lossCount, g_agg[i].profit, peak,
                                  AgeMinutes(g_agg[i].oldest), (armed ? "[ARMED]" : ""));
      if(InpLogStatus)
         Print(line);
      body += line + "\n";
     }

   if(InpWriteStatusFile)
      WriteStatusFile(body);
  }

//+------------------------------------------------------------------+
void WriteStatusFile(string body)
  {
   string name = InpStatusFileName;
   if(name == "")
      return;
   int h = FileOpen(name, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE)
     {
      if(InpVerboseLog)
         PrintFormat("ProfitScouter: cannot write %s, err=%d", name, GetLastError());
      return;
     }
   FileWriteString(h, body);
   FileClose(h);
  }

#else
void LogStatus(double accProfit, int count) { /* EA uses DrawPanel */ }
void WriteStatusFile(string body) { }
#endif

string ScopeText()
  {
   if(InpScope == PS_SCOPE_ONE)
     {
#ifdef PS_HOST_SERVICE
      return "symbol " + InpPrimarySymbol;
#else
      return "chart symbol";
#endif
     }
   if(InpScope == PS_SCOPE_LIST)
      return "custom list";
   return "all symbols";
  }

void Notify(string msg)
  {
   if(InpVerboseLog)
      Print("ProfitScouter: ", msg);
#ifdef PS_HOST_EA
   if(InpAlertOnClose)
      Alert("ProfitScouter: ", msg);
#endif
   if(InpPushOnClose)
      SendNotification("ProfitScouter: " + msg);
  }

#ifdef PS_HOST_EA
//+------------------------------------------------------------------+
//| Movable on-chart info panel (drag title bar)                     |
//+------------------------------------------------------------------+
#define PS_PANEL_W        460
#define PS_PANEL_TITLE_H  22
#define PS_PANEL_LINE_H   13
#define PS_PANEL_MAX_LINES 36
#define PS_PANEL_PAD      8

string PsPanelPosXVar() { return(StringFormat("PS%d_PNLX", InpInstanceID)); }
string PsPanelPosYVar() { return(StringFormat("PS%d_PNLY", InpInstanceID)); }

void PsLoadPanelPos()
  {
   g_panelX = InpPanelX;
   g_panelY = InpPanelY;
   string nx = PsPanelPosXVar();
   string ny = PsPanelPosYVar();
   if(GlobalVariableCheck(nx))
      g_panelX = (int)GlobalVariableGet(nx);
   if(GlobalVariableCheck(ny))
      g_panelY = (int)GlobalVariableGet(ny);
   if(g_panelX < 0) g_panelX = 0;
   if(g_panelY < 0) g_panelY = 0;
  }

void PsSavePanelPos()
  {
   GlobalVariableSet(PsPanelPosXVar(), (double)g_panelX);
   GlobalVariableSet(PsPanelPosYVar(), (double)g_panelY);
  }

void PsPanelRect(const string tag, const int x, const int y, const int w, const int h,
                 const color bg, const color edge, const bool selectable)
  {
   string n = g_pnlPfx + tag;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_BACK, false);
      ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
     }
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR, edge);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, selectable);
   ObjectSetInteger(0, n, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, selectable ? 5 : 1);
  }

void PsPanelLabel(const string tag, const int x, const int y, const string text,
                  const color clr, const int size, const bool bold)
  {
   string n = g_pnlPfx + tag;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, n, OBJPROP_BACK, false);
      ObjectSetInteger(0, n, OBJPROP_ZORDER, 10);
     }
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, n, OBJPROP_FONT, bold ? "Segoe UI Bold" : "Consolas");
  }

void PsDeletePanel()
  {
   ObjectsDeleteAll(0, g_pnlPfx);
   g_panelLinesUsed = 0;
   g_panelDragging = false;
   g_panelDragOffSet = false;
  }

void PsPanelSetLine(const int idx, const string text, const color clr)
  {
   if(idx < 0 || idx >= PS_PANEL_MAX_LINES)
      return;
   int y = g_panelY + PS_PANEL_TITLE_H + 4 + idx * PS_PANEL_LINE_H;
   PsPanelLabel(StringFormat("L%d", idx), g_panelX + PS_PANEL_PAD, y, text, clr, 8, false);
   if(idx + 1 > g_panelLinesUsed)
      g_panelLinesUsed = idx + 1;
  }

void PsPanelTrimLines(const int keep)
  {
   for(int i = keep; i < g_panelLinesUsed; i++)
      ObjectDelete(0, g_pnlPfx + StringFormat("L%d", i));
   g_panelLinesUsed = keep;
  }

void PsPanelApplyLayout(const int bodyLines)
  {
   int bodyH = MathMax(1, bodyLines) * PS_PANEL_LINE_H + 10;
   int totalH = PS_PANEL_TITLE_H + bodyH;
   PsPanelRect("BG", g_panelX, g_panelY, PS_PANEL_W, totalH,
               C'22,26,34', C'70,78,92', false);
   // Title bar is the drag handle
   PsPanelRect("TITLE", g_panelX, g_panelY, PS_PANEL_W, PS_PANEL_TITLE_H,
               C'36,42,54', C'90,110,140', true);
   PsPanelLabel("TITLE_TX", g_panelX + PS_PANEL_PAD, g_panelY + 3,
                "PROFIT SCOUTER  ·  drag to move", C'200,210,230', 9, true);
  }

void PsPanelPushLine(string &lines[], const string text)
  {
   int n = ArraySize(lines);
   ArrayResize(lines, n + 1);
   lines[n] = text;
  }

void DrawPanel(double accProfit, int count)
  {
   if(!InpShowPanel)
     {
      PsDeletePanel();
      PsUpdateButtons();
      ChartRedraw();
      return;
     }

   // While dragging, chrome is repositioned by the mouse handler
   if(g_panelDragging)
     {
      PsUpdateButtons();
      return;
     }

   Comment("");   // clear legacy Comment dashboard

   string ccy = TargetCcy();
   string lines[];
   ArrayResize(lines, 0);

   PsPanelPushLine(lines, StringFormat("Instance %d | %s | targets in %s (x%.5f)",
                                       InpInstanceID, g_accCcy, ccy, g_ccyFactor));
   PsPanelPushLine(lines, StringFormat("Scout: %s | Mode: %s | Scope: %s | Magic: %s | %d ms",
                                       (gScoutEnabled ? "START" : "STOP"),
                                       (InpScalpAsapAccountOnly ? "Scalp ASAP" : "layered"),
                                       ScopeText(), (InpUseMagicFilter ? (string)InpMagicNumber : "any"),
                                       (int)MathMax(100, InpCheckIntervalMs)));
   PsPanelPushLine(lines, StringFormat("Window: %s %d-%d min | trail after: %s",
                                       (InpWindowEnable ? "ON" : "OFF"), InpWindowStartMin, InpWindowEndMin,
                                       (InpTrailAfterWindow ? "yes" : "no")));
   PsPanelPushLine(lines, "----------------------------------------------");
   PsPanelPushLine(lines, StringFormat("Positions monitored : %d", count));
   PsPanelPushLine(lines, StringFormat("Floating profit     : %.2f %s", accProfit, g_accCcy));
   PsPanelPushLine(lines, StringFormat("Winners / Losers    : %d (+%.2f) / %d (%.2f)",
                                       g_winCount, g_winSum, g_lossCount, g_lossSum));
   PsPanelPushLine(lines, StringFormat("Account peak        : %.2f %s %s", g_accPeak, g_accCcy,
                                       (g_accArmed ? "[ARMED]" : "")));
   PsPanelPushLine(lines, StringFormat("ASAP floor          : %.2f %s%s", AsapFloorMoney(), g_accCcy,
                                       (InpScalpAsapAccountOnly ? "  [ASAP]" : "")));
   PsPanelPushLine(lines, StringFormat("Profit lock         : %s arm>=%.2f keep=%.0f%% locked=%d | win floor %.2f",
                                       (InpProfitLockEnable ? "ON" : "OFF"), Money(InpProfitLockArm),
                                       InpProfitLockKeepPct, LockedPosCount(), Money(InpMinWinProfit)));
   PsPanelPushLine(lines, StringFormat("Adverse Auto        : %s minBars>%d minAge=%d onceGreen=%s tf=%d last=%s streak=%d closed=%d",
                                       (gAdverseEnabled ? "ON" : "OFF"), InpAdverseMinBars, InpAdverseMinAgeMin,
                                       (InpAdverseProtectOnceGreen ? "protect" : "cut"),
                                       (int)PsAdverseTf(),
                                       (g_adverseLastSym == "" ? "-" : g_adverseLastSym),
                                       g_adverseLastStreak, g_adverseClosedCycle));
   PsPanelPushLine(lines, StringFormat("Account target      : %.2f %s%s", Money(InpAccTargetMoney), g_accCcy,
                                       (InpScalpAsapAccountOnly ? "  [ASAP]" : "")));
   PsPanelPushLine(lines, "----------------------------------------------");

   for(int i = 0; i < ArraySize(g_agg); i++)
     {
      int r = SymIndex(g_agg[i].sym, false);
      double peak = (r >= 0 ? g_sym[r].peak : 0.0);
      bool armed  = (r >= 0 ? g_sym[r].armed : false);
      PsPanelPushLine(lines, StringFormat("%-10s n=%d (w%d/l%d)  P/L %8.2f  peak %8.2f  age %4d min %s",
                                          g_agg[i].sym, g_agg[i].count, g_agg[i].winCount, g_agg[i].lossCount,
                                          g_agg[i].profit, peak,
                                          AgeMinutes(g_agg[i].oldest), (armed ? "[ARMED]" : "")));
     }

   PsPanelPushLine(lines, "----------------------------------------------");
   PsPanelPushLine(lines, StringFormat("Session closes      : %d realized %.2f %s",
                                       g_closedSession, g_realizedSession, g_accCcy));
   PsPanelPushLine(lines, StringFormat("Last action: %s | Trading: %s",
                                       g_lastAction, (TradingReady() ? "enabled" : "BLOCKED")));

   int nLines = ArraySize(lines);
   if(nLines > PS_PANEL_MAX_LINES)
      nLines = PS_PANEL_MAX_LINES;

   PsPanelApplyLayout(nLines);
   for(int i = 0; i < nLines; i++)
      PsPanelSetLine(i, lines[i], C'210,218,230');
   PsPanelTrimLines(nLines);

   PsUpdateButtons();
   ChartRedraw();
  }

bool PsPanelHitTitle(const int mx, const int my)
  {
   if(!InpShowPanel)
      return(false);
   if(mx < g_panelX || mx > g_panelX + PS_PANEL_W)
      return(false);
   if(my < g_panelY || my > g_panelY + PS_PANEL_TITLE_H)
      return(false);
   return(true);
  }

void PsPanelMoveTo(const int x, const int y)
  {
   g_panelX = (int)MathMax(0, x);
   g_panelY = (int)MathMax(0, y);
  }

bool PsHandleChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(PsHandleChartClick(sparam))
         return(true);
      if(sparam == g_pnlPfx + "TITLE")
        {
         g_panelDragging = true;
         g_panelDragOffSet = false;
         return(false);
        }
      return(false);
     }

   if(id == CHARTEVENT_MOUSE_MOVE)
     {
      int mx = (int)lparam;
      int my = (int)dparam;
      int flags = (int)StringToInteger(sparam);
      bool leftDown = ((flags & 1) == 1);

      if(g_panelDragging)
        {
         if(!leftDown)
           {
            g_panelDragging = false;
            g_panelDragOffSet = false;
            PsSavePanelPos();
            return(false);
           }
         if(!g_panelDragOffSet)
           {
            g_panelDragOffX = mx - g_panelX;
            g_panelDragOffY = my - g_panelY;
            g_panelDragOffSet = true;
           }
         PsPanelMoveTo(mx - g_panelDragOffX, my - g_panelDragOffY);
         PsPanelApplyLayout(MathMax(1, g_panelLinesUsed));
         for(int i = 0; i < g_panelLinesUsed; i++)
           {
            string n = g_pnlPfx + StringFormat("L%d", i);
            if(ObjectFind(0, n) >= 0)
              {
               ObjectSetInteger(0, n, OBJPROP_XDISTANCE, g_panelX + PS_PANEL_PAD);
               ObjectSetInteger(0, n, OBJPROP_YDISTANCE,
                               g_panelY + PS_PANEL_TITLE_H + 4 + i * PS_PANEL_LINE_H);
              }
           }
         string tn = g_pnlPfx + "TITLE_TX";
         if(ObjectFind(0, tn) >= 0)
           {
            ObjectSetInteger(0, tn, OBJPROP_XDISTANCE, g_panelX + PS_PANEL_PAD);
            ObjectSetInteger(0, tn, OBJPROP_YDISTANCE, g_panelY + 3);
           }
         PsUpdateButtons();
         ChartRedraw();
         return(false);
        }

      if(leftDown && PsPanelHitTitle(mx, my))
        {
         g_panelDragging = true;
         g_panelDragOffX = mx - g_panelX;
         g_panelDragOffY = my - g_panelY;
         g_panelDragOffSet = true;
        }
      return(false);
     }

   return(false);
  }
#else
void DrawPanel(double accProfit, int count) { }
void PsDeletePanel() { }
#endif

void PsPublishBusSnapshot(double accProfit, int count)
  {
   if(!InpBusEnable)
      return;

   string tid = GsxMakeTid();
   string j = "{";
   j += GsxJsonKV_I("version", GSX_BUS_VERSION);
   j += GsxJsonKV_I("ts", (long)TimeCurrent());
   j += GsxJsonKV_S("tid", tid);
   j += GsxJsonKV_I("instance_id", InpInstanceID);
   j += GsxJsonKV_S("currency", g_accCcy);
   j += GsxJsonKV_D("floating", accProfit);
   j += GsxJsonKV_D("acc_peak", g_accPeak);
   j += GsxJsonKV_B("acc_armed", g_accArmed);
   j += GsxJsonKV_D("acc_target", Money(InpAccTargetMoney));
   j += GsxJsonKV_D("pos_target", PosHardTarget());
   j += GsxJsonKV_D("sym_target", SymHardTarget());
   j += GsxJsonKV_B("lock_enable", InpProfitLockEnable);
   j += GsxJsonKV_D("lock_arm", Money(InpProfitLockArm));
   j += GsxJsonKV_D("lock_keep_pct", InpProfitLockKeepPct);
   j += GsxJsonKV_D("win_floor", Money(InpMinWinProfit));
   j += GsxJsonKV_I("locked_count", LockedPosCount());
   j += GsxJsonKV_B("scalp_asap", InpScalpAsapAccountOnly);
   j += GsxJsonKV_I("window_start", InpWindowStartMin);
   j += GsxJsonKV_I("window_end", InpWindowEndMin);
   j += GsxJsonKV_I("positions", count);
   j += GsxJsonKV_I("win_count", g_winCount);
   j += GsxJsonKV_D("win_profit", g_winSum);
   j += GsxJsonKV_I("loss_count", g_lossCount);
   j += GsxJsonKV_D("loss_profit", g_lossSum);
   j += GsxJsonKV_B("loss_guard", false);      // legacy field; account loss-guard removed
   j += GsxJsonKV_B("adverse_enable", gAdverseEnabled);
   j += GsxJsonKV_I("adverse_min_bars", InpAdverseMinBars);
   j += GsxJsonKV_I("adverse_min_age", InpAdverseMinAgeMin);
   j += GsxJsonKV_B("adverse_protect_once_green", InpAdverseProtectOnceGreen);
   j += GsxJsonKV_S("adverse_last_sym", g_adverseLastSym);
   j += GsxJsonKV_I("adverse_last_streak", g_adverseLastStreak);
   j += GsxJsonKV_I("adverse_closed_cycle", g_adverseClosedCycle);
   j += GsxJsonKV_I("closed_session", g_closedSession);
   j += GsxJsonKV_D("realized_session", g_realizedSession);
   j += GsxJsonKV_B("trading_ready", TradingReady());
   j += GsxJsonKV_B("scout_enabled", gScoutEnabled);
   j += GsxJsonKV_S("last_action", g_lastAction);
   j += "\"symbols\":[";
   for(int i = 0; i < ArraySize(g_agg); i++)
     {
      int    r     = SymIndex(g_agg[i].sym, false);
      double peak  = (r >= 0 ? g_sym[r].peak : 0.0);
      bool   armed = (r >= 0 ? g_sym[r].armed : false);
      long   spread = SymbolInfoInteger(g_agg[i].sym, SYMBOL_SPREAD);
      if(i > 0)
         j += ",";
      j += "{";
      j += GsxJsonKV_S("symbol", g_agg[i].sym);
      j += GsxJsonKV_S("symbol_canon", GsxSymbolCanon(g_agg[i].sym));
      j += GsxJsonKV_I("count", g_agg[i].count);
      j += GsxJsonKV_I("win_count", g_agg[i].winCount);
      j += GsxJsonKV_I("loss_count", g_agg[i].lossCount);
      j += GsxJsonKV_D("profit", g_agg[i].profit);
      j += GsxJsonKV_D("peak", peak);
      j += GsxJsonKV_B("armed", armed);
      j += GsxJsonKV_I("age_min", AgeMinutes(g_agg[i].oldest));
      j += GsxJsonKV_I("spread_pt", spread, false);
      j += "}";
     }
   j += "]}";
   GsxBusWriteAtomic(GsxBusScouterPath(tid), j);
   GsxBusPublishHeartbeat("scouter");
  }

void PsAfterCycle(double accProfit, int count)
  {
   PsPublishBusSnapshot(accProfit, count);
#ifdef PS_HOST_SERVICE
   LogStatus(accProfit, count);
#else
   DrawPanel(accProfit, count);
#endif
  }

bool PsInitEngine()
  {
   g_prefix = StringFormat("PS%d_", InpInstanceID);
   g_accCcy = AccountInfoString(ACCOUNT_CURRENCY);
   g_trade.SetDeviationInPoints(InpSlippagePoints);
   g_trade.SetAsyncMode(false);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);
   BuildAllowList();
#ifdef PS_HOST_SERVICE
   SubscribeSymbols();
#endif
   RefreshCurrencyFactor(true);
   LoadAccountPeak();
   CleanupStaleGlobals();
   PsLoadScoutEnabled();
   PsLoadAdverseEnabled();
#ifdef PS_HOST_EA
   PsLoadPanelPos();
#endif
   return true;
  }

//+------------------------------------------------------------------+
//| Scout START / STOP (standalone harvest arm)                      |
//+------------------------------------------------------------------+
string PsRunStateVarName()
  {
   return(StringFormat("PS%d_RUN", InpInstanceID));
  }

void PsLoadScoutEnabled()
  {
   string n = PsRunStateVarName();
   if(GlobalVariableCheck(n))
     {
      gScoutEnabled = (GlobalVariableGet(n) > 0.5);
      return;
     }
#ifdef PS_HOST_EA
   gScoutEnabled = InpScoutStartArmed;
#else
   gScoutEnabled = true;
#endif
   GlobalVariableSet(n, gScoutEnabled ? 1.0 : 0.0);
  }

void PsSetScoutEnabled(const bool on, const bool announce)
  {
   gScoutEnabled = on;
   GlobalVariableSet(PsRunStateVarName(), on ? 1.0 : 0.0);
   g_lastAction = on ? "scout START" : "scout STOPPED";
   if(announce)
     {
      Notify(on ? "START: profit scouting armed (closes enabled)"
                : "STOP: profit scouting paused (watch only)");
     }
#ifdef PS_HOST_EA
   PsUpdateButtons();
   ChartRedraw();
#endif
  }

//+------------------------------------------------------------------+
//| Adverse AUTO on/off (chart toggle + shared GV for Service)       |
//+------------------------------------------------------------------+
string PsAdverseStateVarName()
  {
   return(StringFormat("PS%d_ADVEN", InpInstanceID));
  }

void PsLoadAdverseEnabled()
  {
   string n = PsAdverseStateVarName();
   if(GlobalVariableCheck(n))
     {
      gAdverseEnabled = (GlobalVariableGet(n) > 0.5);
      return;
     }
   gAdverseEnabled = InpAdverseExitEnable;
   GlobalVariableSet(n, gAdverseEnabled ? 1.0 : 0.0);
  }

void PsSetAdverseEnabled(const bool on, const bool announce)
  {
   gAdverseEnabled = on;
   GlobalVariableSet(PsAdverseStateVarName(), on ? 1.0 : 0.0);
   g_lastAction = on ? "adverse AUTO ON" : "adverse AUTO OFF";
   if(announce)
     {
      Notify(on ? "AUTO ON: adverse-bar loss exit armed"
                : "AUTO OFF: adverse-bar loss exit paused");
     }
#ifdef PS_HOST_EA
   PsUpdateButtons();
   ChartRedraw();
#endif
  }

#ifdef PS_HOST_EA
void PsSetButton(const string tag, const int x, const int y, const int w, const int h,
                 const string text, const color bg, const color fg)
  {
   string n = g_btnPfx + tag;
   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, n, OBJPROP_ZORDER, 50);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetInteger(0, n, OBJPROP_COLOR, fg);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, n, OBJPROP_FONT, "Segoe UI");
   ObjectSetInteger(0, n, OBJPROP_STATE, false);
  }

void PsDeleteButtons()
  {
   ObjectDelete(0, g_btnPfx + "START");
   ObjectDelete(0, g_btnPfx + "STOP");
   ObjectDelete(0, g_btnPfx + "AUTO");
  }

void PsUpdateButtons()
  {
   if(!InpShowButtons)
     {
      PsDeleteButtons();
      return;
     }
   // Standalone controls (not docked) so they stay visible while the panel moves
   int x = InpBtnX;
   int y = InpBtnY;
   PsSetButton("START", x, y, 78, 26, "START",
               gScoutEnabled ? C'38,208,124' : C'40,44,52',
               gScoutEnabled ? C'18,22,30' : C'222,228,240');
   PsSetButton("STOP", x + 86, y, 78, 26, "STOP",
               gScoutEnabled ? C'40,44,52' : C'235,77,75',
               gScoutEnabled ? C'222,228,240' : C'18,22,30');
   PsSetButton("AUTO", x + 172, y, 78, 26,
               gAdverseEnabled ? "AUTO ON" : "AUTO OFF",
               gAdverseEnabled ? C'56,168,220' : C'40,44,52',
               gAdverseEnabled ? C'18,22,30' : C'222,228,240');
  }

bool PsHandleChartClick(const string sparam)
  {
   if(sparam == g_btnPfx + "START")
     {
      PsSetScoutEnabled(true, true);
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      return true;
     }
   if(sparam == g_btnPfx + "STOP")
     {
      PsSetScoutEnabled(false, true);
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      return true;
     }
   if(sparam == g_btnPfx + "AUTO")
     {
      PsSetAdverseEnabled(!gAdverseEnabled, true);
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      return true;
     }
   return false;
  }
#endif

#endif // PS_CORE_MQH
//+------------------------------------------------------------------+

