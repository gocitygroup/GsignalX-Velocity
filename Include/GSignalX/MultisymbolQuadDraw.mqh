//+------------------------------------------------------------------+
//| v2.05 — True quadrant Trade Center draw (included by panel host) |
//| Spatial layout: UL|UR / LL|LR → main table → footer               |
//+------------------------------------------------------------------+
#ifndef GSX_MULTISYMBOL_QUAD_DRAW_MQH
#define GSX_MULTISYMBOL_QUAD_DRAW_MQH

void GsxMsDrawQuadHeader(GsxLayCtx &col, const string bandTag, const string titleTag,
                         const string title, const int headH, const int fs)
  {
   // Title row + accent rule for clear section hierarchy
   int titleFs = MathMax(fs + 1, g_msLay.fontRow);
   int ruleH = MathMax(2, GsxSx(2));
   int titleRow = MathMax(headH, titleFs + GsxSx(8));

   GsxLayRowStart(col, titleRow);
   GsxLaySlot s;
   // Inset so title never kisses the panel edge
   int inset = MathMax(GsxSx(6), g_msLay.btnPad + GsxSx(2));
   if(GsxLayPack(col, inset, s))
      ObjectDelete(0, GSXMS_PFX + titleTag + "_PAD");
   GsxLayPackFlex(col, s);
   if(s.w > inset)
     {
      s.w = MathMax(1, s.w - inset);
      GsxPanelSlotLabel(titleTag, s, title, g_msColAccent, titleFs, true);
     }
   GsxLayAdvance(col, titleRow);

   GsxLayRowStart(col, ruleH);
   GsxMsDrawSectionBand(titleTag + "_RULE", col.x0 + inset, col.packY,
                        MathMax(GsxSx(40), col.contentW - 2 * inset), ruleH);
   // Recolor rule to accent edge
   string rn = GSXMS_PFX + titleTag + "_RULE";
   if(ObjectFind(0, rn) >= 0)
     {
      ObjectSetInteger(0, rn, OBJPROP_BGCOLOR, g_msColAccent);
      ObjectSetInteger(0, rn, OBJPROP_COLOR, g_msColAccent);
      ObjectSetInteger(0, rn, OBJPROP_YSIZE, ruleH);
     }
   GsxLayAdvance(col, ruleH + GsxSx(4));
  }

// Apply horizontal content inset for a column pack row
void GsxMsQuadInsetBegin(GsxLayCtx &col, const int inset)
  {
   GsxLaySlot s;
   if(inset > 0 && GsxLayPack(col, inset, s))
     { /* left gutter */ }
  }

// UL — System Indicator
void GsxMsDrawQuadUL(GsxLayCtx &col, const GsxMsSnapshot &snap,
                     const int bh, const int pad, const int fs)
  {
   int headH = MathMax(fs + GsxSx(8), GsxSx(18));
   GsxMsDrawQuadHeader(col, "SEC_SYS", "QH_SYS", "SYSTEM", headH, fs);

   int inset = MathMax(GsxSx(6), pad + GsxSx(2));
   // Taller chips so bold glyphs center cleanly (no bottom clip)
   int rowH = MathMax(bh, fs + GsxSp(16));
   int chipGap = MathMax(GsxSp(8), g_msLay.cellGap);
   GsxLaySetGaps(col, chipGap, MathMax(GsxSx(6), g_msLay.bandGap / 2));

   string ownTxt = snap.own ? "OWN" : "SVC OFF";
   string hbTxt = snap.hbFresh ? "HB" : "NO HB";
   string runTxt = snap.run ? "RUN" : "STOPPED";
   string scoutTxt = (!g_msScoutLinkEnable ? "UNLINK"
                      : (GsxScoutRunGet(g_msScoutInstanceID, true) ? "SCOUT ON" : "SCOUT OFF"));
   if(g_msDense)
     {
      scoutTxt = (!g_msScoutLinkEnable ? "UNL"
                  : (GsxScoutRunGet(g_msScoutInstanceID, true) ? "SCN" : "OFF"));
      if(!snap.own)
         ownTxt = "OFF";
      hbTxt = snap.hbFresh ? "HB" : "NH";
     }

   string tfLbl = EnumToString((ENUM_TIMEFRAMES)snap.deskTf);
   if(StringFind(tfLbl, "PERIOD_") == 0)
      tfLbl = StringSubstr(tfLbl, 7);

   color ownBg = snap.own ? C'18,56,40' : C'56,24,28';
   color hbBg = snap.hbFresh ? C'18,56,40' : C'56,40,18';
   color runBg = snap.run ? C'18,56,40' : C'56,24,28';
   color scoutBg = (!g_msScoutLinkEnable ? C'32,38,50' :
                    (GsxScoutRunGet(g_msScoutInstanceID, true) ? C'18,56,40' : C'56,24,28'));

   // Row 1: OWN | HB | RUN | SCOUT
   GsxLayRowStart(col, rowH);
   GsxMsQuadInsetBegin(col, inset);
   int chipW = MathMax(GsxSx(40), (col.packRemain - 3 * chipGap - inset) / 4);
   GsxMsPackPill(col, chipW, "ST_OWN_BG", "ST_OWN", ownTxt, ownBg,
                 snap.own ? g_msColBull : g_msColBear, fs);
   GsxMsPackPill(col, chipW, "ST_HB_BG", "ST_HB", hbTxt, hbBg,
                 snap.hbFresh ? g_msColBull : g_msColAccent, fs);
   GsxMsPackPill(col, chipW, "ST_RUN_BG", "ST_RUN", runTxt, runBg,
                 snap.run ? g_msColBull : g_msColBear, fs, true);
   GsxMsPackPill(col, chipW, "ST_SCOUT_BG", "ST_SCOUT", scoutTxt, scoutBg,
                 GsxMsScoutStatusClr(), fs);
   GsxLayAdvance(col, rowH);

   // Row 2: fleet / TF / prop — equal width boxes
   GsxLayRowStart(col, rowH);
   GsxMsQuadInsetBegin(col, inset);
   string fltTxt = StringFormat("Fleet %d/%d", snap.fleetActive, snap.fleetTarget);
   string tfTxt = "TF " + tfLbl;
   string drillTxt = (snap.drillSecLeft > 0)
                     ? StringFormat("DRILL %dm%02ds", snap.drillSecLeft / 60, snap.drillSecLeft % 60)
                     : (snap.continuousFleet ? "DRILL CONT"
                        : (snap.run ? "DRILL CLOSED" : "DRILL OFF"));
   bool propOk = (StringFind(snap.propStatus, "LOCK") < 0);
   string propTxt = propOk
                    ? (g_msDense ? "Prop OK" : snap.propStatus)
                    : (g_msDense ? "Prop LOCK" : snap.propStatus);
   int chipW2 = MathMax(GsxSx(48), (col.packRemain - 3 * chipGap - inset) / 4);
   GsxMsPackPill(col, chipW2, "ST_FLT_BG", "ST_FLT", fltTxt, C'32,38,50', g_msColText, fs);
   GsxMsPackPill(col, chipW2, "ST_TF_BG", "ST_TF", tfTxt, C'32,38,50', g_msColAccent, fs);
   GsxMsPackPill(col, chipW2, "ST_DRILL_BG", "ST_DRILL", drillTxt,
                 (snap.drillSecLeft > 0 ? C'18,56,40' :
                  (snap.continuousFleet ? C'56,40,18' : C'32,38,50')),
                 (snap.drillSecLeft > 0 ? g_msColBull :
                  (snap.continuousFleet ? g_msColAccent : g_msColMuted)), fs);
   // v2.13: Prop chip always visible (OK shows peakDD; LOCK shows reason)
   if(!propOk)
      GsxMsPackPill(col, chipW2, "ST_PROP_BG", "ST_PROP", propTxt, C'56,24,28', g_msColBear, fs);
   else
      GsxMsPackPill(col, chipW2, "ST_PROP_BG", "ST_PROP", propTxt, C'18,56,40', g_msColBull, fs);
   GsxLayAdvance(col, rowH);

   // Row 3: Telegram status
   GsxLayRowStart(col, rowH);
   GsxMsQuadInsetBegin(col, inset);
   GsxLaySlot s;
   int rightPad = inset;
   int avail = MathMax(1, col.packRemain - rightPad);
   col.packRemain = avail;
   GsxLayPackFlex(col, s);
   string tgTxt = StringFormat("TG %s · sent %d · fail %d · q %d",
                               snap.tgStatus, snap.tgSent, snap.tgFail, snap.tgQueue);
   if(s.w > 0)
      GsxPanelSlotLabel("ST_TG", s, tgTxt,
                        (snap.tgStatus == "Verified" ? g_msColBull :
                         (snap.tgStatus == "Error" ? g_msColBear :
                          (snap.tgStatus == "Connected" ? g_msColAccent : g_msColMuted))),
                        fs, false);
   GsxLayAdvance(col, rowH);

   if(g_msShowButtons)
     {
      GsxLayRowStart(col, bh);
      GsxMsQuadInsetBegin(col, inset);
      GsxLaySlot slots[];
      // Leave matching right inset
      int btnAvail = MathMax(1, col.packRemain - inset);
      col.packRemain = btnAvail;
      GsxLayEqual(col, 1, slots);
      if(ArraySize(slots) >= 1)
         GsxPanelSlotButtonPad("BTN_TG_VERIFY", slots[0], "Verify",
                               g_msColBg, g_msColAccent, pad);
      GsxLayAdvance(col, bh);
     }
  }

// UR — Symbol Actions
void GsxMsDrawQuadUR(GsxLayCtx &col, const GsxMsSnapshot &snap,
                     const string car, const int page, const int pageCount,
                     const int bh, const int pad, const int fs)
  {
   int headH = MathMax(fs + GsxSx(8), GsxSx(18));
   GsxMsDrawQuadHeader(col, "SEC_SYM", "QH_SYM", "SYMBOLS", headH, fs);

   int inset = MathMax(GsxSx(6), pad + GsxSx(2));
   int cell = MathMax(GsxSp(6), g_msLay.cellGap);
   GsxLaySetGaps(col, cell, MathMax(GsxSx(4), g_msLay.bandGap / 2));
   GsxLaySlot s;
   GsxLaySlot slots[];

   // Categories — equal buttons
   GsxLayRowStart(col, bh);
   GsxMsQuadInsetBegin(col, inset);
   int catAvail = MathMax(1, col.packRemain - inset);
   col.packRemain = catAvail;
   GsxLayEqual(col, 4, slots);
   if(ArraySize(slots) >= 4)
     {
      GsxMsDrawCatTab("BTN_CAT_ALL", slots[0], "ALL", snap.catFilter == GSX_CAT_ALL);
      GsxMsDrawCatTab("BTN_CAT_FX", slots[1], "FX", snap.catFilter == GSX_CAT_FOREX);
      GsxMsDrawCatTab("BTN_CAT_CMD", slots[2], "CMD", snap.catFilter == GSX_CAT_COMMODITY);
      GsxMsDrawCatTab("BTN_CAT_CR", slots[3], g_msDense ? "CRY" : "CRYPTO",
                      snap.catFilter == GSX_CAT_CRYPTO);
     }
   GsxLayAdvance(col, bh);

   // Fleet / page — square controls + label
   int sq = MathMax(GsxSx(28), bh - 2 * pad);
   GsxLayRowStart(col, bh);
   GsxMsQuadInsetBegin(col, inset);
   if(GsxLayPack(col, sq, s))
      GsxPanelSlotButtonPad("BTN_FLEET_M", s, "-", C'32,38,50', g_msColText, pad);
   else
      ObjectDelete(0, GSXMS_PFX + "BTN_FLEET_M");
   if(GsxLayPack(col, sq, s))
      GsxPanelSlotButtonPad("BTN_FLEET_P", s, "+", C'32,38,50', g_msColText, pad);
   else
      ObjectDelete(0, GSXMS_PFX + "BTN_FLEET_P");
   if(GsxLayPack(col, sq, s))
      GsxPanelSlotButtonPad("BTN_PAGE_P", s, "<", C'32,38,50', g_msColText, pad);
   else
      ObjectDelete(0, GSXMS_PFX + "BTN_PAGE_P");
   if(GsxLayPack(col, sq, s))
      GsxPanelSlotButtonPad("BTN_PAGE_N", s, ">", C'32,38,50', g_msColText, pad);
   else
      ObjectDelete(0, GSXMS_PFX + "BTN_PAGE_N");
   int rightPad = inset;
   int labAvail = MathMax(1, col.packRemain - rightPad);
   col.packRemain = labAvail;
   GsxLayPackFlex(col, s);
   if(s.w > 0)
      GsxPanelSlotLabel("FNUM", s,
                        StringFormat("Fleet %d · Pg %d/%d", snap.fleetTarget, page + 1, pageCount),
                        g_msColAccent, fs, true);
   GsxLayAdvance(col, bh);

   // Candidate row — < SYM > ADD SWAP REM (ADD never dropped on tight UR)
   GsxLayRowStart(col, MathMax(bh, GsxSx(30)));
   GsxMsQuadInsetBegin(col, inset);
   color chipIdle = C'32,38,50';
   int actW = MathMax(GsxSx(44), MathMin(col.packRemain / 8, GsxSx(64)));
   string carTxt = (car == "" ? "—" : car);
   int symW = MathMax(GsxSx(56), GsxMsTextChipW(carTxt, g_msLay.fontRow, GsxSx(68)));
   int carNeed = 2 * sq + symW + 2 * col.gap;
   int actNeed = 3 * actW + 2 * col.gap;
   int oneRowNeed = carNeed + actNeed + inset + col.gap;
   bool splitRow = (col.packRemain < oneRowNeed);

   if(GsxLayPack(col, sq, s))
      GsxPanelSlotButtonPad("BTN_CAR_P", s, "<", chipIdle, g_msColText, pad);
   else
      ObjectDelete(0, GSXMS_PFX + "BTN_CAR_P");
   // Shrink symbol chip so ADD always has room on single-row layouts
   if(!splitRow)
     {
      int leave = actNeed + inset + col.gap;
      int maxSym = MathMax(GsxSx(48), col.packRemain - sq - leave);
      if(symW > maxSym)
         symW = maxSym;
     }
   if(GsxLayPack(col, symW, s))
      GsxPanelSlotLabelCentered("CAR", s, carTxt, g_msColAccent, g_msLay.fontRow, true);
   else
      ObjectDelete(0, GSXMS_PFX + "CAR");
   if(GsxLayPack(col, sq, s))
      GsxPanelSlotButtonPad("BTN_CAR_N", s, ">", chipIdle, g_msColText, pad);
   else
      ObjectDelete(0, GSXMS_PFX + "BTN_CAR_N");

   if(splitRow)
     {
      GsxLayAdvance(col, MathMax(bh, GsxSx(30)));
      GsxLayRowStart(col, MathMax(bh, GsxSx(30)));
      GsxMsQuadInsetBegin(col, inset);
      actW = MathMax(GsxSx(44), MathMin((col.packRemain - inset - 2 * col.gap) / 3, GsxSx(72)));
     }
   else
     {
      int spacer = MathMax(0, col.packRemain - inset - actNeed);
      if(spacer > 0)
        {
         GsxLaySlot skip;
         GsxLayPack(col, spacer, skip);
        }
     }

   // Priority: ADD always, then REM, then SWAP
   if(GsxLayPack(col, actW, s))
      GsxPanelSlotButtonPad("BTN_ADD", s, "ADD",
                            (car == "" ? chipIdle : g_msColBull),
                            (car == "" ? g_msColMuted : g_msColBg), pad);
   else
     {
      // Last resort: consume remaining width for ADD
      GsxLayPackFlex(col, s);
      if(s.w >= GsxSx(36))
         GsxPanelSlotButtonPad("BTN_ADD", s, "ADD",
                               (car == "" ? chipIdle : g_msColBull),
                               (car == "" ? g_msColMuted : g_msColBg), pad);
      else
         ObjectDelete(0, GSXMS_PFX + "BTN_ADD");
     }

   GsxLaySlot swapSlot;
   bool haveSwap = GsxLayPack(col, actW, swapSlot);
   GsxLaySlot remSlot;
   bool haveRem = GsxLayPack(col, actW, remSlot);
   if(haveRem)
     {
      if(haveSwap)
         GsxPanelSlotButtonPad("BTN_SWAP", swapSlot, "SWAP", chipIdle, g_msColAccent, pad);
      else
         ObjectDelete(0, GSXMS_PFX + "BTN_SWAP");
      GsxPanelSlotButtonPad("BTN_REM", remSlot, "REM", g_msColBear, g_msColBg, pad);
     }
   else if(haveSwap)
     {
      ObjectDelete(0, GSXMS_PFX + "BTN_SWAP");
      GsxPanelSlotButtonPad("BTN_REM", swapSlot, "REM", g_msColBear, g_msColBg, pad);
     }
   else
     {
      ObjectDelete(0, GSXMS_PFX + "BTN_SWAP");
      ObjectDelete(0, GSXMS_PFX + "BTN_REM");
     }
   ObjectDelete(0, GSXMS_PFX + "CAR_LBL");
   ObjectDelete(0, GSXMS_PFX + "CAR_HINT");
   GsxLayAdvance(col, MathMax(bh, GsxSx(30)));

   // Caps
   GsxLayRowStart(col, MathMax(fs + GsxSx(6), GsxSx(16)));
   GsxMsQuadInsetBegin(col, inset);
   int capAvail = MathMax(1, col.packRemain - inset);
   col.packRemain = capAvail;
   GsxLayPackFlex(col, s);
   if(s.w > 0)
      GsxMsSlotLabelBudget("CAP_LINE", s,
                           StringFormat("FX %d · CMD %d · CR %d · max %d",
                                        snap.countFx, snap.countCmd, snap.countCr, snap.classMax),
                           g_msColMuted, fs, false, g_msLay.clipTip);
   GsxLayAdvance(col, MathMax(fs + GsxSx(6), GsxSx(16)));
  }

// LL — Trader Automation
void GsxMsDrawQuadLL(GsxLayCtx &col, const GsxMsSnapshot &snap,
                     const int bh, const int pad, const int fs)
  {
   int headH = MathMax(fs + GsxSx(8), GsxSx(18));
   GsxMsDrawQuadHeader(col, "SEC_AUTO", "QH_AUTO", "AUTOMATION", headH, fs);

   int inset = MathMax(GsxSx(6), pad + GsxSx(2));
   GsxLaySetGaps(col, MathMax(GsxSp(6), g_msLay.btnGap), MathMax(GsxSx(4), g_msLay.bandGap / 2));
   GsxLaySlot slots[];
   GsxLaySlot s;

   GsxLayRowStart(col, bh);
   GsxMsQuadInsetBegin(col, inset);
   int avail = MathMax(1, col.packRemain - inset);
   col.packRemain = avail;
   GsxLayEqual(col, 5, slots);
   color chipIdle = C'32,38,50';
   if(ArraySize(slots) >= 5)
     {
      string followCap = g_msFlipWait ? "WAIT" : "FOLLOW";
      string sprTxt = snap.ignoreSpread ? "IGN" : "SPREAD";
      GsxPanelSlotButtonPad("BTN_PLAY", slots[0], "PLAY",
                            snap.run ? g_msColBull : chipIdle,
                            snap.run ? g_msColBg : g_msColText, pad);
      GsxPanelSlotButtonPad("BTN_STOP", slots[1], "STOP",
                            snap.run ? chipIdle : g_msColBear,
                            snap.run ? g_msColText : g_msColBg, pad);
      GsxPanelSlotButtonPad("BTN_HALT", slots[2], "HALT",
                            chipIdle, g_msColAccent, pad);
      GsxPanelSlotButtonPad("BTN_FOLLOW", slots[3], followCap,
                            g_msFlipWait ? g_msColAccent : g_msColBull,
                            g_msColBg, pad);
      GsxPanelSlotButtonPad("BTN_SPREAD", slots[4], sprTxt,
                            snap.ignoreSpread ? g_msColAccent : chipIdle,
                            snap.ignoreSpread ? g_msColBg : g_msColText, pad);
     }
   GsxLayAdvance(col, bh);

   GsxLayRowStart(col, bh);
   GsxMsQuadInsetBegin(col, inset);
   avail = MathMax(1, col.packRemain - inset);
   col.packRemain = avail;
   GsxLayEqual(col, 5, slots);
   if(ArraySize(slots) >= 5)
     {
      string lotTxt = snap.autoLot ? "AUTOLOT" : "FIXED";
      bool eq0 = (snap.eqGuardPct <= 0.0);
      bool eq5 = (snap.eqGuardPct > 0.0 && snap.eqGuardPct < 7.5);
      bool eq10 = (snap.eqGuardPct >= 7.5 && snap.eqGuardPct < 17.5);
      bool eq20 = (snap.eqGuardPct >= 17.5);
      GsxPanelSlotButtonPad("BTN_AUTOLOT", slots[0], lotTxt,
                            snap.autoLot ? g_msColBull : chipIdle,
                            snap.autoLot ? g_msColBg : g_msColText, pad);
      GsxPanelSlotButtonPad("BTN_EQ_0", slots[1], "EQ OFF",
                            eq0 ? g_msColMuted : chipIdle,
                            eq0 ? g_msColBg : g_msColText, pad);
      GsxPanelSlotButtonPad("BTN_EQ_5", slots[2], "5%",
                            eq5 ? g_msColAccent : chipIdle,
                            eq5 ? g_msColBg : g_msColText, pad);
      GsxPanelSlotButtonPad("BTN_EQ_10", slots[3], "10%",
                            eq10 ? g_msColAccent : chipIdle,
                            eq10 ? g_msColBg : g_msColText, pad);
      GsxPanelSlotButtonPad("BTN_EQ_20", slots[4], "20%",
                            eq20 ? g_msColAccent : chipIdle,
                            eq20 ? g_msColBg : g_msColText, pad);
     }
   GsxLayAdvance(col, bh);

   // v2.13 feature-guard summary + drill REKICK (no duplicate click tags)
   GsxLayRowStart(col, bh);
   GsxMsQuadInsetBegin(col, inset);
   avail = MathMax(1, col.packRemain - inset);
   col.packRemain = avail;
   GsxLayEqual(col, 5, slots);
   if(ArraySize(slots) >= 5)
     {
      string gRun  = snap.run ? "RUN" : "STOP";
      string gFlip = snap.flipWait ? "WAIT" : "FOL";
      string gEvt  = GsxEventModeLabel(snap.eventMode);
      string gLot  = snap.autoLot ? "AUTO" : "FIX";
      string gDrill = "REKICK";
      GsxPanelSlotLabel("GD_RUN", slots[0], gRun,
                        snap.run ? g_msColBull : g_msColBear, fs, true);
      GsxPanelSlotLabel("GD_FLIP", slots[1], gFlip,
                        snap.flipWait ? g_msColAccent : g_msColBull, fs, true);
      GsxPanelSlotLabel("GD_EVT", slots[2], gEvt, g_msColText, fs, true);
      GsxPanelSlotLabel("GD_LOT", slots[3], gLot,
                        snap.autoLot ? g_msColBull : g_msColMuted, fs, true);
      GsxPanelSlotButtonPad("BTN_DRILL_REKICK", slots[4], gDrill,
                            (snap.drillSecLeft > 0 ? chipIdle : g_msColAccent),
                            (snap.drillSecLeft > 0 ? g_msColText : g_msColBg), pad);
     }
   GsxLayAdvance(col, bh);

   GsxLayRowStart(col, bh);
   GsxMsQuadInsetBegin(col, inset);
   avail = MathMax(1, col.packRemain - inset);
   col.packRemain = avail;
   GsxLayEqual(col, 4, slots);
   if(ArraySize(slots) >= 4)
     {
      bool aOn = (g_msDeskFollowDir == GSX_FOLLOW_AUTO);
      bool bOn = (g_msDeskFollowDir == GSX_FOLLOW_BUY);
      bool sOn = (g_msDeskFollowDir == GSX_FOLLOW_SELL);
      bool wOn = (g_msDeskFollowDir == GSX_FOLLOW_WAIT);
      GsxPanelSlotButtonPad("BTN_FDIR_AUTO", slots[0], "FOLLOW",
                            aOn ? g_msColBull : chipIdle,
                            aOn ? g_msColBg : g_msColText, pad);
      GsxPanelSlotButtonPad("BTN_FDIR_BUY", slots[1], "BUY",
                            bOn ? g_msColBull : chipIdle,
                            bOn ? g_msColBg : g_msColText, pad);
      GsxPanelSlotButtonPad("BTN_FDIR_SELL", slots[2], "SELL",
                            sOn ? g_msColBear : chipIdle,
                            sOn ? g_msColBg : g_msColText, pad);
      GsxPanelSlotButtonPad("BTN_FDIR_WAIT", slots[3], "WAIT",
                            wOn ? g_msColMuted : chipIdle,
                            wOn ? g_msColBg : g_msColText, pad);
     }
   GsxLayAdvance(col, bh);

   GsxLayRowStart(col, bh);
   GsxMsQuadInsetBegin(col, inset);
   avail = MathMax(1, col.packRemain - inset);
   col.packRemain = avail;
   GsxLayEqual(col, 2, slots);
   if(ArraySize(slots) >= 2)
     {
      GsxPanelSlotButtonPad("BTN_PAIR_START_ALL", slots[0], "START ALL",
                            chipIdle, g_msColBull, pad);
      GsxPanelSlotButtonPad("BTN_PAIR_STOP_ALL", slots[1], "STOP ALL",
                            chipIdle, g_msColBear, pad);
     }
   GsxLayAdvance(col, bh);

   // v2.13.1: explicit Prop CLEAR so equity lock cannot trap the desk
   GsxLayRowStart(col, bh);
   GsxMsQuadInsetBegin(col, inset);
   avail = MathMax(1, col.packRemain - inset);
   col.packRemain = avail;
   GsxLayEqual(col, 1, slots);
   if(ArraySize(slots) >= 1)
     {
      bool propLocked = (StringFind(snap.propStatus, "LOCK") >= 0);
      GsxPanelSlotButtonPad("BTN_PROP_CLEAR", slots[0],
                            propLocked ? "PROP CLEAR" : "PROP OK",
                            propLocked ? g_msColBear : chipIdle,
                            propLocked ? g_msColBg : g_msColMuted, pad);
     }
   GsxLayAdvance(col, bh);

   int tipH = MathMax(fs + GsxSx(8), GsxSx(18));
   GsxLayRowStart(col, tipH);
   GsxMsQuadInsetBegin(col, inset);
   avail = MathMax(1, col.packRemain - inset);
   col.packRemain = avail;
   GsxLayPackFlex(col, s);
   GsxMsSlotLabelBudget("FDIR_TIP", s,
                        "New entries only — open positions unchanged",
                        g_msColMuted, fs, false, g_msLay.clipTip);
   GsxLayAdvance(col, tipH);

   if(g_msShowPractice && g_msShowButtons)
     {
      GsxLayRowStart(col, bh);
      GsxMsQuadInsetBegin(col, inset);
      avail = MathMax(1, col.packRemain - inset);
      col.packRemain = avail;
      GsxLayEqual(col, 3, slots);
      if(ArraySize(slots) >= 3)
        {
         GsxMsDrawCatTab("BTN_PRAC_20", slots[0], "20", snap.pracBand == 20);
         GsxMsDrawCatTab("BTN_PRAC_50", slots[1], "50", snap.pracBand == 50);
         GsxMsDrawCatTab("BTN_PRAC_100", slots[2], "100", snap.pracBand == 100);
        }
      GsxLayAdvance(col, bh);
      GsxLayRowStart(col, bh);
      GsxMsQuadInsetBegin(col, inset);
      avail = MathMax(1, col.packRemain - inset);
      col.packRemain = avail;
      GsxLayEqual(col, 5, slots);
      if(ArraySize(slots) >= 5)
        {
         GsxMsDrawCatTab("BTN_PRAC_RAW", slots[0], "RAW", snap.pracCost == GSX_COST_RAW);
         GsxMsDrawCatTab("BTN_PRAC_STD", slots[1], "STD", snap.pracCost == GSX_COST_STANDARD);
         GsxMsDrawCatTab("BTN_PRAC_SCALP", slots[2], "SCALP", snap.pracStyle == GSX_STYLE_SCALP);
         GsxMsDrawCatTab("BTN_PRAC_DAY", slots[3], "DAY", snap.pracStyle == GSX_STYLE_DAY);
         GsxMsDrawCatTab("BTN_PRAC_SWING", slots[4], "SWING", snap.pracStyle == GSX_STYLE_SWING);
        }
      GsxLayAdvance(col, bh);
     }
   else
      GsxMsClearPracticeObjects();
  }

// LR — Trade Info Details (aligned key / value columns)
void GsxMsDrawQuadLR(GsxLayCtx &col, const GsxMsSnapshot &snap,
                     const int fs)
  {
   int headH = MathMax(fs + GsxSx(8), GsxSx(18));
   GsxMsDrawQuadHeader(col, "SEC_INFO", "QH_INFO", "TRADE INFO", headH, fs);

   int inset = MathMax(GsxSx(6), g_msLay.btnPad + GsxSx(2));
   GsxLaySetGaps(col, MathMax(GsxSp(6), g_msLay.cellGap), MathMax(GsxSx(3), g_msLay.bandGap / 3));
   GsxLaySlot s;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double dd = GsxAccountDrawdownPct();
   int lineH = MathMax(fs + GsxSx(10), GsxSx(20));
   int keyW = MathMax(GsxSx(88), GsxMsTextChipW("Floating P/L", fs, GsxSx(84)));

   string guideTxt = (snap.eqGuardPct <= 0.0)
                     ? "OFF"
                     : (DoubleToString(snap.eqGuardPct, 0) + "%");
   string ddPair = StringFormat("%.1f%% / %s", dd, guideTxt);
   color ddCol = g_msColMuted;
   if(snap.eqGuardPct > 0.0 && dd >= snap.eqGuardPct)
      ddCol = g_msColBear;
   else if(dd >= 5.0)
      ddCol = g_msColBear;
   else if(dd >= 2.0)
      ddCol = g_msColStop;

   string peakTxt = StringFormat("%.1f%%", snap.propPeakDdPct);
   color peakCol = (snap.propPeakDdPct >= 5.0 ? g_msColBear :
                    (snap.propPeakDdPct >= 2.0 ? g_msColStop : g_msColMuted));

   string sessTxt = StringFormat("W%d L%d · %+.2f",
                                 snap.sessionWins, snap.sessionLosses, snap.sessionNetPl);
   color sessCol = (snap.sessionNetPl > 0.0 ? g_msColBull :
                    (snap.sessionNetPl < 0.0 ? g_msColBear : g_msColMuted));

   string propBook = StringFormat("%+.0f / %+.0f · %d%s",
                                  snap.propDayRealized, snap.propWeekRealized,
                                  snap.propTradesToday,
                                  (snap.propMaxTrades > 0
                                   ? ("/" + IntegerToString(snap.propMaxTrades))
                                   : ""));
   bool propLocked = (StringFind(snap.propStatus, "LOCK") >= 0);

   // Helper local pack: key | value
   string keys[9];
   string vals[9];
   color  vclrs[9];
   keys[0] = "Positions";   vals[0] = IntegerToString(snap.positions); vclrs[0] = g_msColText;
   keys[1] = "Floating P/L"; vals[1] = StringFormat("%+.2f", snap.fleetPl);
   vclrs[1] = (snap.fleetPl > 0.0 ? g_msColBull : (snap.fleetPl < 0.0 ? g_msColBear : g_msColMuted));
   keys[2] = "Equity";      vals[2] = StringFormat("%.2f", eq);       vclrs[2] = g_msColText;
   keys[3] = "Balance";     vals[3] = StringFormat("%.2f", bal);      vclrs[3] = g_msColText;
   keys[4] = "Account DD";  vals[4] = ddPair;                        vclrs[4] = ddCol;
   keys[5] = "Prop peak DD"; vals[5] = peakTxt;                      vclrs[5] = peakCol;
   keys[6] = "Session";     vals[6] = sessTxt;                       vclrs[6] = sessCol;
   keys[7] = "Prop book";   vals[7] = propBook;
   vclrs[7] = (propLocked ? g_msColBear : g_msColText);
   keys[8] = "Prop";        vals[8] = snap.propStatus;
   vclrs[8] = (propLocked ? g_msColBear : g_msColBull);

   for(int i = 0; i < 9; i++)
     {
      GsxLayRowStart(col, lineH);
      GsxMsQuadInsetBegin(col, inset);
      if(GsxLayPack(col, keyW, s))
         GsxPanelSlotLabel(StringFormat("INFO_K%d", i), s, keys[i], g_msColMuted, fs, false);
      int rightPad = inset;
      int vAvail = MathMax(1, col.packRemain - rightPad);
      col.packRemain = vAvail;
      GsxLayPackFlex(col, s);
      if(s.w > 0)
         GsxPanelSlotLabel(StringFormat("INFO_V%d", i), s, vals[i], vclrs[i], fs, true);
      GsxLayAdvance(col, lineH);
     }

   // Remove legacy single-line labels if present
   ObjectDelete(0, GSXMS_PFX + "INFO_POS");
   ObjectDelete(0, GSXMS_PFX + "INFO_PL");
   ObjectDelete(0, GSXMS_PFX + "INFO_EQ");
   ObjectDelete(0, GSXMS_PFX + "INFO_DD");

   GsxLayRowStart(col, lineH);
   GsxMsQuadInsetBegin(col, inset);
   int spAvail = MathMax(1, col.packRemain - inset);
   col.packRemain = spAvail;
   GsxLayPackFlex(col, s);
   GsxMsSlotLabelBudget("INFO_SP", s,
                        "EQ OFF=guide only · Prop peak≠Account DD",
                        g_msColMuted, fs, false, g_msLay.clipEvt);
   GsxLayAdvance(col, lineH);
  }

//+------------------------------------------------------------------+
void GsxMsPanelDrawFull(const GsxMsSnapshot &snap)
  {
   GsxMsPanelApplyAdaptive();
   GsxPanelConfigure(GSXMS_PFX, CORNER_LEFT_UPPER, "Segoe UI", 8, g_msColEdge);

   int x = g_msPanelX;
   int y = g_msPanelY;
   int w = g_msPanelWidth;
   int rh = g_msLay.rh;
   int cell = g_msLay.cellGap;
   int band = g_msLay.bandGap;
   int bh = g_msLay.btnH;
   int pad = g_msLay.btnPad;
   int fs = g_msLay.fontSmall;
   int fr = g_msLay.fontRow;
   int gutter = GsxSx(GSXMS_QUAD_GUTTER);

   int page = snap.page;
   int pageCount = MathMax(1, snap.pageCount);
   if(page < 0) page = 0;
   if(page >= pageCount) page = pageCount - 1;
   g_msPage = page;
   g_msFlipWait = snap.flipWait;

   string roster[];
   if(ArraySize(snap.allRows) > 0)
     {
      ArrayResize(roster, ArraySize(snap.allRows));
      for(int i = 0; i < ArraySize(snap.allRows); i++)
         roster[i] = snap.allRows[i].symbol;
     }
   else
     {
      ArrayResize(roster, ArraySize(snap.rows));
      for(int i = 0; i < ArraySize(snap.rows); i++)
         roster[i] = snap.rows[i].symbol;
     }

   string car = GsxMsCarouselCandidate(roster);
   int n = ArraySize(snap.rows);
   int pageRows = MathMin(g_msPageSize, MathMax(0, n - page * g_msPageSize));

   int provisionalH = g_msLay.titleH + GsxSx(620);
   string visionHint = (g_msVision == GSX_VISION_FAR ? "Far" :
                        (g_msVision == GSX_VISION_NEAR ? "Near" : "Comfort"));
   GsxPanelBegin(x, y, w, 8, g_msLay.titleDesign);
   GsxPanelApplyChrome(provisionalH, g_msColBg, g_msColEdge, g_msColTitle,
                       g_msColAccent, g_msColMuted,
                       "Trade Center",
                       StringFormat("%s · magic %I64d · live desk", visionHint, snap.magic));
   g_msLay.titleH = g_gsxPnlTitleH;
   g_msTitleH = g_gsxPnlTitleH;

   int headerGutter = GsxSpRow(6, g_msLay.titleH, 0.20);
   GsxLayCtx lay;
   GsxLayBegin(lay, x, y + g_msLay.titleH + headerGutter, w, cell, band);
   GsxLaySlot s;

   // --- Session (full width) ---
   GsxMsDrawSessionStrip(lay, snap.session);
   GsxLaySetGaps(lay, cell, band);

   // --- Events (full width) — single text line + TRADE/SKIP (no EVENTSTRADE merge) ---
   int evtH = MathMax(bh, fs + GsxSp(14));
   GsxLayRowStart(lay, evtH);
   GsxMsDrawSectionBand("SEC_EV", lay.x0, lay.packY, lay.contentW, evtH);

   int evtBtnW = 0;
   if(g_msShowButtons)
      evtBtnW = MathMax(GsxSx(76), GsxMsTextChipW("TRADE", fs, GsxSx(72)) + 2 * pad);

   // eventLine already includes mode label ("TRADE · …"); prefix EVENTS once
   string evtBody = snap.eventLine;
   if(evtBody == "")
      evtBody = GsxEventModeLabel(snap.eventMode) + " · no upcoming events";
   string evt = "EVENTS  ·  " + evtBody;

   int msgAvail = lay.contentW;
   if(evtBtnW > 0)
      msgAvail = MathMax(GsxSp(80), lay.contentW - evtBtnW - cell);
   lay.packRemain = msgAvail;
   GsxLayPackFlex(lay, s);
   if(s.w > 0)
      GsxMsSlotLabelBudget("EV_LINE", s, evt, g_msColText, fs, false, g_msLay.clipEvt);
   ObjectDelete(0, GSXMS_PFX + "EV_LBL"); // legacy separate label caused EVENTSTRADE mash

   if(g_msShowButtons)
     {
      s.x = lay.x0 + msgAvail + cell;
      s.y = lay.packY;
      s.w = evtBtnW;
      s.h = evtH;
      if(s.x + s.w > lay.x0 + lay.contentW)
         s.w = MathMax(1, lay.x0 + lay.contentW - s.x);
      GsxPanelSlotButtonPad("BTN_EVT", s, GsxEventModeLabel(snap.eventMode),
                            snap.eventMode == GSX_EVT_MODE_SKIP ? g_msColBear : g_msColBull,
                            g_msColBg, pad);
     }
   GsxLayAdvance(lay, evtH);
   GsxMsBandGutter(lay, evtH);

   // ========== TRUE 2x2 QUADRANTS (GsxLaySplit2) ==========
   int quadY = lay.cursorY;
   GsxLayCtx leftA, rightA;
   GsxLaySplit2(lay.x0, quadY, lay.contentW, gutter, cell, MathMax(GsxSx(3), band / 2),
                leftA, rightA);
   // Background panels first (under content)
   int estAH = GsxSx(g_msShowButtons ? 150 : 110);
   GsxMsDrawSectionBand("SEC_SYS", leftA.x0, quadY, leftA.contentW, estAH);
   GsxMsDrawSectionBand("SEC_SYM", rightA.x0, quadY, rightA.contentW, estAH);
   if(g_msShowButtons)
     {
      GsxMsDrawQuadUL(leftA, snap, bh, pad, fs);
      GsxMsDrawQuadUR(rightA, snap, car, page, pageCount, bh, pad, fs);
     }
   else
     {
      GsxMsDrawQuadUL(leftA, snap, bh, pad, fs);
      GsxMsDrawQuadHeader(rightA, "SEC_SYM", "QH_SYM", "SYMBOLS",
                          MathMax(fs + GsxSx(6), GsxSx(16)), fs);
     }
   int rowAH = GsxLaySplit2MeasuredH(leftA, rightA);
   // Resize band rects to measured height
   if(ObjectFind(0, GSXMS_PFX + "SEC_SYS") >= 0)
      ObjectSetInteger(0, GSXMS_PFX + "SEC_SYS", OBJPROP_YSIZE, rowAH);
   if(ObjectFind(0, GSXMS_PFX + "SEC_SYM") >= 0)
      ObjectSetInteger(0, GSXMS_PFX + "SEC_SYM", OBJPROP_YSIZE, rowAH);
   lay.cursorY = quadY + rowAH + band;

   int quadY2 = lay.cursorY;
   GsxLayCtx leftB, rightB;
   GsxLaySplit2(lay.x0, quadY2, lay.contentW, gutter, cell, MathMax(GsxSx(3), band / 2),
                leftB, rightB);
   int estBH = GsxSx(g_msShowButtons ? (g_msShowPractice ? 180 : 140) : 120);
   GsxMsDrawSectionBand("SEC_AUTO", leftB.x0, quadY2, leftB.contentW, estBH);
   GsxMsDrawSectionBand("SEC_INFO", rightB.x0, quadY2, rightB.contentW, estBH);
   if(g_msShowButtons)
      GsxMsDrawQuadLL(leftB, snap, bh, pad, fs);
   else
      GsxMsDrawQuadHeader(leftB, "SEC_AUTO", "QH_AUTO", "AUTOMATION",
                          MathMax(fs + GsxSx(6), GsxSx(16)), fs);
   GsxMsDrawQuadLR(rightB, snap, fs);
   int rowBH = GsxLaySplit2MeasuredH(leftB, rightB);
   if(ObjectFind(0, GSXMS_PFX + "SEC_AUTO") >= 0)
      ObjectSetInteger(0, GSXMS_PFX + "SEC_AUTO", OBJPROP_YSIZE, rowBH);
   if(ObjectFind(0, GSXMS_PFX + "SEC_INFO") >= 0)
      ObjectSetInteger(0, GSXMS_PFX + "SEC_INFO", OBJPROP_YSIZE, rowBH);
   lay.cursorY = quadY2 + rowBH + band;

   // ========== Main table ==========
   int tblTop = lay.cursorY;
   int tGap = MathMax(0, g_msLay.tableGap);
   int rowPitch = rh + tGap;
   int tblH = rh + pageRows * rowPitch;
   GsxMsDrawSectionBand("SEC_TBL", x, tblTop, w, tblH);

   int weights[];
   ArrayResize(weights, 9);
   weights[0] = 20; weights[1] = 10; weights[2] = 9; weights[3] = 9;
   weights[4] = 9; weights[5] = 9; weights[6] = 12; weights[7] = 12; weights[8] = 10;
   GsxLaySlot cols[];
   GsxLayCols(x, lay.cursorY, w, rh, weights, 9, cols);
   if(ArraySize(cols) >= 9)
     {
      GsxPanelSlotLabel("CH_SYM", cols[0], "Symbol", g_msColMuted, fs, true);
      GsxPanelSlotLabel("CH_DIR", cols[1], "Signal", g_msColMuted, fs, true);
      GsxPanelSlotLabel("CH_MODE", cols[2], "Mode", g_msColMuted, fs, true);
      GsxPanelSlotLabel("CH_SPR", cols[3], "Spread", g_msColMuted, fs, true);
      GsxPanelSlotLabel("CH_PL",  cols[4], "P/L", g_msColMuted, fs, true);
      GsxPanelSlotLabel("CH_GR",  cols[5], "Grade", g_msColMuted, fs, true);
      GsxPanelSlotLabel("CH_FLG", cols[6], "Status", g_msColMuted, fs, true);
      GsxPanelSlotLabel("CH_ST",  cols[7], "State", g_msColMuted, fs, true);
      GsxPanelSlotLabel("CH_REM", cols[8], "Rem", g_msColMuted, fs, true);
     }
   GsxLayAdvanceTight(lay, rowPitch);

   int start = page * g_msPageSize;
   int drawn = 0;
   for(int i = 0; i < g_msPageSize; i++)
     {
      int ri = start + i;
      if(ri >= n)
         break;
      int ry = lay.cursorY;
      if((i % 2) == 1)
         GsxPanelRect(StringFormat("ROW%d_BG", i), x + GsxSx(2), ry,
                      w - GsxSx(4), rh, g_msColZebra, g_msColZebra, false);
      else
         ObjectDelete(0, GSXMS_PFX + StringFormat("ROW%d_BG", i));

      GsxLayCols(x, ry, w, rh, weights, 9, cols);
      if(ArraySize(cols) < 9)
         break;

      color symClr = snap.rows[ri].marketOpen ? g_msColText : g_msColMuted;
      if(snap.rows[ri].pairState == GSX_PAIR_SUSPEND)
         symClr = g_msColMuted;
      string symTxt = g_msDense
                      ? snap.rows[ri].symbol
                      : (snap.rows[ri].symbol + " · " +
                         GsxSymClassLabel((ENUM_GSX_SYM_CLASS)snap.rows[ri].symClass));
      GsxPanelSlotLabel(StringFormat("ROW%d_SYM", i), cols[0], symTxt, symClr, fr, true);

      string sideTxt = GsxMsDirCellTxt(snap.rows[ri]);
      GsxPanelSlotLabel(StringFormat("ROW%d_DIR", i), cols[1], sideTxt,
                        GsxMsDirCellClr(snap.rows[ri]),
                        fr, true);

      int fd = snap.rows[ri].followDir;
      GsxLaySlot modeSlot;
      modeSlot.x = cols[2].x;
      modeSlot.y = cols[2].y;
      modeSlot.w = cols[2].w;
      modeSlot.h = cols[2].h;
      int wantMode = MathMax(GsxSx(36), MathMin(GsxSx(GSXMS_MODE_W), modeSlot.w));
      if(modeSlot.w > wantMode)
        {
         modeSlot.x = cols[2].x + (cols[2].w - wantMode) / 2;
         modeSlot.w = wantMode;
        }
      GsxPanelSlotButtonPad("BTN_MODE_" + IntegerToString(i), modeSlot,
                            GsxRosterFollowDirLabel(fd),
                            GsxMsFollowDirClr(fd), g_msColBg, pad);

      GsxPanelSlotLabel(StringFormat("ROW%d_SPR", i), cols[3],
                        IntegerToString(snap.rows[ri].spreadPt) + " pt",
                        g_msColText, fr, false);

      color plClr = (snap.rows[ri].floatingPl > 0.0 ? g_msColBull :
                     (snap.rows[ri].floatingPl < 0.0 ? g_msColBear : g_msColMuted));
      GsxPanelSlotLabel(StringFormat("ROW%d_PL", i), cols[4],
                        StringFormat("%+.2f", snap.rows[ri].floatingPl), plClr, fr, true);

      string gr = (snap.rows[ri].gradeScore < 0.0
                   ? "—"
                   : DoubleToString(snap.rows[ri].gradeScore, 1));
      GsxPanelSlotLabel(StringFormat("ROW%d_GR", i), cols[5], gr, g_msColAccent, fr, true);
      GsxPanelSlotLabel(StringFormat("ROW%d_FLG", i), cols[6],
                        GsxMsFriendlyFlags(snap.rows[ri]), g_msColMuted, fr, false);

      int st = snap.rows[ri].pairState;
      GsxLaySlot stSlot;
      stSlot.x = cols[7].x;
      stSlot.y = cols[7].y;
      stSlot.w = cols[7].w;
      stSlot.h = cols[7].h;
      int wantSt = MathMax(GsxSx(48), MathMin(g_msLay.stateW, stSlot.w));
      if(stSlot.w > wantSt)
        {
         stSlot.x = cols[7].x + cols[7].w - wantSt;
         stSlot.w = wantSt;
        }
      GsxPanelSlotButtonPad("BTN_STATE_" + IntegerToString(i), stSlot,
                            GsxMsStateBtn(st), GsxMsStateClr(st), g_msColBg, pad);

      GsxLaySlot remSlot;
      remSlot.x = cols[8].x;
      remSlot.y = cols[8].y;
      remSlot.w = cols[8].w;
      remSlot.h = cols[8].h;
      int wantRem = MathMax(GsxSx(36), MathMin(GsxSx(52), remSlot.w));
      if(remSlot.w > wantRem)
        {
         remSlot.x = cols[8].x + (cols[8].w - wantRem) / 2;
         remSlot.w = wantRem;
        }
      GsxPanelSlotButtonPad("BTN_REM_" + IntegerToString(i), remSlot,
                            "REM", g_msColBear, g_msColBg, pad);
      drawn++;
      GsxLayAdvanceTight(lay, rowPitch);
     }
   GsxMsTrimRowObjects(drawn);
   lay.cursorY += band;

   // ========== Footer ==========
   GsxLaySetGaps(lay, cell, MathMax(GsxSx(3), band / 2));
   int rosterN = ArraySize(snap.allRows) > 0 ? ArraySize(snap.allRows) : n;
   int footH = MathMax(rh, fs + GsxSx(10));

   GsxLayRowStart(lay, footH);
   GsxLayPackFlex(lay, s);
   GsxPanelSlotLabel("FT1", s,
                     StringFormat("Updated %s · Pos %d · P/L %+.2f · Roster %d · View %d · v2.05",
                                  TimeToString(TimeCurrent(), TIME_SECONDS),
                                  snap.positions, snap.fleetPl, rosterN, n),
                     g_msColText, fs, false);
   GsxLayAdvance(lay, footH);

   GsxLayRowStart(lay, footH);
   int half = lay.contentW / 2;
   if(GsxLayPack(lay, half, s))
      GsxPanelSlotLabel("FT2", s, "Last · " + g_msLastAction, g_msColMuted, fs, false);
   GsxLayPackFlex(lay, s);
   GsxPanelSlotLabel("FT3", s,
                     "Exits · " + GsxMsScoutStatusTxt() + " · STOP entries · HALT+scout",
                     g_msColAccent, fs, true);
   GsxLayAdvance(lay, footH);

   GsxLayRowStart(lay, footH);
   GsxLayPackFlex(lay, s);
   string tgErr = snap.tgLastError;
   string ft4 = (tgErr == ""
                 ? StringFormat("TG %s · sent %d · fail %d · q %d",
                                snap.tgStatus, snap.tgSent, snap.tgFail, snap.tgQueue)
                 : ("TG error · " + tgErr));
   GsxPanelSlotLabel("FT4", s, ft4,
                     (snap.tgStatus == "Error" ? g_msColBear : g_msColMuted),
                     fs, false);
   GsxLayAdvance(lay, footH);

   // Remove legacy full-width status band objects that conflict
   ObjectDelete(0, GSXMS_PFX + "SEC_ST");
   ObjectDelete(0, GSXMS_PFX + "SEC_CAR");

   int contentH = GsxLayMeasuredH(lay);
   int totalH = g_msLay.titleH + headerGutter + contentH + 2 * g_msLay.inset;
   g_msLastTotalH = totalH;
   GsxPanelClampPos(g_msPanelX, g_msPanelY, g_msPanelWidth, totalH);
   GsxPanelResizeBg(totalH);
   string bgName = GSXMS_PFX + "BG";
   if(ObjectFind(0, bgName) >= 0)
     {
      int inset = g_msLay.inset > 0 ? g_msLay.inset : GsxSx(8);
      ObjectSetInteger(0, bgName, OBJPROP_XSIZE, w + 2 * inset);
      ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, g_msPanelX - inset);
      ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, g_msPanelY - inset);
     }
   ChartRedraw();
  }

#endif // GSX_MULTISYMBOL_QUAD_DRAW_MQH
//+------------------------------------------------------------------+
