<#
.SYNOPSIS
  Confirm GSignalX deployment gates and optionally write a feedback report.

.EXAMPLE
  .\Confirm-GSignalX.ps1 -Gate All -WriteFeedback

.EXAMPLE
  .\Confirm-GSignalX.ps1 -TerminalDataPath "$env:APPDATA\MetaQuotes\Terminal\<HASH>" -Gate Compile
#>
[CmdletBinding()]
param(
  [ValidateSet("Files", "Compile", "Bus", "Grades", "LoserSafety", "ProdHardening", "Functional", "All")]
  [string] $Gate = "All",

  [string] $TerminalDataPath = "",

  [switch] $WriteFeedback,

  [string] $RepoRoot = ""
)

$ErrorActionPreference = "Continue"

if (-not $RepoRoot) {
  $RepoRoot = Split-Path -Parent $PSScriptRoot
}

function Get-DefaultTerminal {
  $root = Join-Path $env:APPDATA "MetaQuotes\Terminal"
  if (-not (Test-Path $root)) { return $null }
  $hit = Get-ChildItem $root -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName "MQL5") } |
    Select-Object -First 1
  if ($hit) { return $hit.FullName }
  return $null
}

if (-not $TerminalDataPath) {
  $TerminalDataPath = Get-DefaultTerminal
  if (-not $TerminalDataPath) {
    throw "No TerminalDataPath and no MT5 data folder found. Pass -TerminalDataPath."
  }
  Write-Host "Using terminal: $TerminalDataPath"
}

$mql5 = Join-Path $TerminalDataPath "MQL5"
$busRoot = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\GSignalX\bus\v1"
$lines = New-Object System.Collections.Generic.List[string]
$fail = 0

function Add-Line([string] $s) {
  Write-Host $s
  $script:lines.Add($s) | Out-Null
}

function Test-PathMark([string] $path, [string] $label) {
  if (Test-Path $path) {
    Add-Line "PASS  $label"
    return $true
  }
  Add-Line "FAIL  $label  (missing: $path)"
  $script:fail++
  return $false
}

function Confirm-LoserSafety {
  Add-Line "=== GATE LoserSafety (static) ==="
  $core = Join-Path $RepoRoot "Include\ProfitScouter\Core.mqh"
  $inputs = Join-Path $RepoRoot "Include\ProfitScouter\Inputs.mqh"
  $scout = Join-Path $RepoRoot "Include\GSignalX\ScoutLink.mqh"
  $gsx  = Join-Path $RepoRoot "GsignalX_GocityGroup.mq5"
  $svc  = Join-Path $RepoRoot "ProfitScouter_Service.mq5"
  $ea   = Join-Path $RepoRoot "ProfitScouter_DollarTarget.mq5"
  $harv = Join-Path $RepoRoot "ProfitHarvest_Now.mq5"

  if (-not (Test-Path $core)) {
    Add-Line "FAIL  Core.mqh missing at $core"
    $script:fail++
    return
  }

  $coreText = Get-Content $core -Raw
  $inpText  = if (Test-Path $inputs) { Get-Content $inputs -Raw } else { "" }
  $scoutText = if (Test-Path $scout) { Get-Content $scout -Raw } else { "" }
  $gsxText  = if (Test-Path $gsx)  { Get-Content $gsx  -Raw } else { "" }
  $svcText  = if (Test-Path $svc)  { Get-Content $svc  -Raw } else { "" }
  $eaText   = if (Test-Path $ea)   { Get-Content $ea   -Raw } else { "" }
  $harvText = if (Test-Path $harv) { Get-Content $harv -Raw } else { "" }
  $hostText = $eaText + "`n" + $svcText + "`n" + $inpText

  if ($coreText -match 'CutLosersToGuard|InpAccMaxLossMoney|InpAccLossGuardEnable') {
    Add-Line "FAIL  loss-guard symbols restored in Core.mqh"
    $script:fail++
  }
  else {
    Add-Line "PASS  no loss-guard symbols in Core.mqh"
  }

  $adverseTrue = ([regex]::Matches($coreText, 'CloseTicket\([^)]+,\s*true\)')).Count
  if ($adverseTrue -lt 1) {
    Add-Line "FAIL  expected CloseTicket(..., true) on adverse path"
    $script:fail++
  }
  else {
    Add-Line "PASS  adverse allowLoss path present ($adverseTrue CloseTicket true call(s))"
  }

  if ($coreText -notmatch 'ADVERSE-BAR') {
    Add-Line "FAIL  ADVERSE-BAR tag missing"
    $script:fail++
  }
  else {
    Add-Line "PASS  ADVERSE-BAR tag present"
  }

  if ($coreText -notmatch 'never closes a losing trade') {
    Add-Line "FAIL  CloseTicket loser hard-guard string missing"
    $script:fail++
  }
  else {
    Add-Line "PASS  CloseTicket loser hard-guard present"
  }

  #--- Cash-amount profit / loss floors (Velocity desk) ---
  if ($coreText -match 'ACC-CASH-LOSS' -and $coreText -match 'CutLosersCash' -and $coreText -match 'HandleAccountCashLoss') {
    Add-Line "PASS  ACC-CASH-LOSS cut path present"
  }
  else {
    Add-Line "FAIL  ACC-CASH-LOSS cut path missing"
    $script:fail++
  }

  if ($coreText -match 'EffectiveCashMode' -and $coreText -match 'ProfitCashFloor' -and $coreText -match 'LossCashFloor') {
    Add-Line "PASS  cash-mode helpers present"
  }
  else {
    Add-Line "FAIL  cash-mode helpers missing"
    $script:fail++
  }

  if (($coreText -match 'PS%d_CASH' -or $scoutText -match 'PS%d_CASH') -and
      ($coreText -match 'PS%d_LOSS' -or $scoutText -match 'PS%d_LOSS')) {
    Add-Line "PASS  PS{id}_CASH / PS{id}_LOSS GV names present"
  }
  else {
    Add-Line "FAIL  CASH/LOSS GV persistence missing"
    $script:fail++
  }

  if ($coreText -match 'cash_mode' -and $coreText -match 'loss_cash_armed' -and $coreText -match 'profit_cash') {
    Add-Line "PASS  bus cash fields present"
  }
  else {
    Add-Line "FAIL  bus cash fields missing"
    $script:fail++
  }

  if ($hostText -match 'InpAccCashLossMoney' -and $hostText -match 'InpAccCashLossEnable') {
    Add-Line "PASS  host shells expose Loss CASH inputs"
  }
  else {
    Add-Line "FAIL  host shells missing Loss CASH inputs"
    $script:fail++
  }

  if ($inpText -match 'InpAccTargetMoney\s*=\s*100\.0' -and
      $eaText -match 'ProfitScouter/Inputs.mqh' -and $svcText -match 'ProfitScouter/Inputs.mqh') {
    Add-Line "PASS  Profit CASH default is 100 on both hosts"
  }
  else {
    Add-Line "FAIL  Profit CASH default is not 100 on both hosts"
    $script:fail++
  }

  if ($inpText -match 'InpAccCashLossMoney\s*=\s*100\.0') {
    Add-Line "PASS  Loss CASH amount default is 100 on both hosts"
  }
  else {
    Add-Line "FAIL  Loss CASH amount default is not 100 on both hosts"
    $script:fail++
  }

  if ($coreText -match 'PSBTN_.*"CASH"' -or ($coreText -match 'PsSetButton\("CASH"' -and $coreText -match 'PsSetButton\("LOSS"')) {
    Add-Line "PASS  chart CASH/LOSS buttons present"
  }
  else {
    Add-Line "FAIL  chart CASH/LOSS buttons missing"
    $script:fail++
  }

  if ($coreText -notmatch 'InpAdverseMinAgeMin' -or $coreText -notmatch 'InpAdverseProtectOnceGreen') {
    Add-Line "FAIL  adverse min-age / once-green gates missing in Core"
    $script:fail++
  }
  else {
    Add-Line "PASS  adverse min-age + once-green gates in Core"
  }

  if ($coreText -notmatch 'AdverseEligibleLoser') {
    Add-Line "FAIL  AdverseEligibleLoser missing"
    $script:fail++
  }
  else {
    Add-Line "PASS  AdverseEligibleLoser present"
  }

  if ($hostText -match 'InpAdverseMinAgeMin') {
    Add-Line "PASS  host shells expose InpAdverseMinAgeMin"
  }
  else {
    Add-Line "FAIL  host shells missing InpAdverseMinAgeMin"
    $script:fail++
  }

  if ($svcText -match 'PERIOD_M5') {
    Add-Line "PASS  Service adverse TF default mentions PERIOD_M5"
  }
  else {
    Add-Line "WARN  Service default TF may not be M5"
  }

  if ($harvText -match 'never closes a losing trade') {
    Add-Line "PASS  ProfitHarvest_Now loser guard present"
  }
  else {
    Add-Line "WARN  ProfitHarvest_Now loser guard string missing"
  }

  if ($gsxText -match 'exit deferred to Profit Scouter') {
    Add-Line "PASS  GSignalX Scouter opposite-signal defer present"
  }
  else {
    Add-Line "FAIL  GSignalX Scouter defer string missing"
    $script:fail++
  }

  #--- V2.01 Scouter agnostic / closer / fair harvest ---
  if ($coreText -match 'GsxSymbolCanon' -and $coreText -match 'IsEligible') {
    Add-Line "PASS  V2.01 canon-based IsEligible"
  }
  else {
    Add-Line "FAIL  V2.01 canon eligibility missing"
    $script:fail++
  }

  if ($scoutText -match 'GsxScoutCloserClaimService' -and $scoutText -match 'GsxScoutCloserAllowsCloses' -and
      $scoutText -match 'GsxScoutCloserServiceFresh' -and $coreText -match 'g_closerAllows' -and
      $coreText -match 'g_closerManualBypass' -and $svcText -match 'GsxScoutCloserClaimService') {
    Add-Line "PASS  V2.01 Service sole closer (PS CLOSER)"
  }
  else {
    Add-Line "FAIL  V2.01 closer ownership missing"
    $script:fail++
  }

  if ($coreText -match 'InpBasketClosesPerCycle' -and $coreText -match 'g_basketRotate') {
    Add-Line "PASS  V2.01 fair multi-symbol basket budget"
  }
  else {
    Add-Line "FAIL  V2.01 basket fairness missing"
    $script:fail++
  }

  if ($scoutText -match 'GsxScoutFloorsSet' -and $coreText -match 'GsxScoutFloorGet' -and
      $coreText -match 'MinWinFloorMoney') {
    Add-Line "PASS  V2.01 practice floor GV overrides"
  }
  else {
    Add-Line "FAIL  V2.01 floor GV bridge missing"
    $script:fail++
  }

  if ($scoutText -match 'GsxScoutAdvenSet' -and $scoutText -match 'GsxScoutCashSet' -and
      $scoutText -match 'GsxScoutLossSet') {
    Add-Line "PASS  V2.01 ScoutLink ADVEN/CASH/LOSS helpers"
  }
  else {
    Add-Line "FAIL  V2.01 ScoutLink arm helpers missing"
    $script:fail++
  }

  if ($coreText -match 'PSBTN_' -and $coreText -match 'g_btnPfx = StringFormat') {
    Add-Line "PASS  V2.01 instance-prefixed panel objects"
  }
  else {
    Add-Line "FAIL  V2.01 instance panel prefix missing"
    $script:fail++
  }

  if ($coreText -match 'g_busForcePub' -and $coreText -match 's_busTick') {
    Add-Line "PASS  V2.01 scouter bus publish throttle"
  }
  else {
    Add-Line "FAIL  V2.01 bus throttle missing"
    $script:fail++
  }

  #--- V2.02 ATR/% TRAIL + candle-length adverse ---
  $candle = Join-Path $RepoRoot "Include\GSignalX\CandleMetrics.mqh"
  $atrTr  = Join-Path $RepoRoot "Include\ProfitScouter\AtrTrail.mqh"
  $candleText = if (Test-Path $candle) { Get-Content $candle -Raw } else { "" }
  $atrText = if (Test-Path $atrTr) { Get-Content $atrTr -Raw } else { "" }

  if ($candleText -match 'GsxAtrPoints' -and $candleText -match 'GsxAvgClosedRangePts' -and
      $candleText -match 'GsxClosedBarBodyPts') {
    Add-Line "PASS  V2.02 CandleMetrics ATR/range/body helpers"
  }
  else {
    Add-Line "FAIL  V2.02 CandleMetrics missing"
    $script:fail++
  }

  if ($atrText -match 'HandleAtrTrailProfit' -and $atrText -match 'ATR-TRAIL' -and
      $atrText -match 'PsAtrTrailOptimizerUpdate' -and $coreText -match 'HandleAtrTrailProfit') {
    Add-Line "PASS  V2.02 ATR trail harvest + optimizer"
  }
  else {
    Add-Line "FAIL  V2.02 ATR trail path missing"
    $script:fail++
  }

  if ($scoutText -match 'GsxScoutTrailSet' -and $coreText -match 'PsSetButton\("TRAIL"' -and
      $coreText -match 'PsSetAtrTrailEnabled') {
    Add-Line "PASS  V2.02 TRAIL button + ScoutLink arm"
  }
  else {
    Add-Line "FAIL  V2.02 TRAIL UI/arm missing"
    $script:fail++
  }

  if ($inpText -match 'InpAdverseMinBodyPts' -and $inpText -match 'InpAdverseMinRangePts' -and
      $coreText -match 'GsxAvgClosedBodyPts') {
    Add-Line "PASS  V2.02 adverse candle-length gate (default 0)"
  }
  else {
    Add-Line "FAIL  V2.02 adverse length gate missing"
    $script:fail++
  }

  if ($coreText -match 'atr_trail_enable' -and $coreText -match 'atr_trail_mult_eff') {
    Add-Line "PASS  V2.02 bus atr_trail fields"
  }
  else {
    Add-Line "FAIL  V2.02 bus atr_trail fields missing"
    $script:fail++
  }

  #--- Velocity 2.00 provenance: Service / Dashboard / Prop+Telegram feature gates ---
  #--- (feature content shipped as 1.23–1.25; hosts now #property version 2.00) ---
  #--- Multisymbol signal service coexistence ---
  $gsxSvc = Join-Path $RepoRoot "GsignalX_Service.mq5"
  $gsxCore = Join-Path $RepoRoot "Include\GSignalX\Core.mqh"
  $gsxFleet = Join-Path $RepoRoot "Include\GSignalX\Fleet.mqh"
  $gsxSvcText = if (Test-Path $gsxSvc) { Get-Content $gsxSvc -Raw } else { "" }
  $gsxCoreText = if (Test-Path $gsxCore) { Get-Content $gsxCore -Raw } else { "" }
  $gsxFleetText = if (Test-Path $gsxFleet) { Get-Content $gsxFleet -Raw } else { "" }

  if ($gsxSvcText -match '#property service' -and $gsxSvcText -match 'InpSymbolList') {
    Add-Line "PASS  GsignalX_Service is chart-free roster service"
  }
  else {
    Add-Line "FAIL  GsignalX_Service missing or not a roster service"
    $script:fail++
  }

  if ($gsxFleetText -match 'GSX_SVC_OWN_' -and $gsxText -match 'ChartServiceOwnsFleet') {
    Add-Line "PASS  Service OWN GV + chart coexistence hooks present"
  }
  else {
    Add-Line "FAIL  Service OWN / chart coexistence missing"
    $script:fail++
  }

  if ($gsxText -match 'InpChartEntriesWhenService' -and $gsxCoreText -match 'GsxCoreFleetFillOnce') {
    Add-Line "PASS  chart defer input + Service fleet fill present"
  }
  else {
    Add-Line "FAIL  chart defer / Service fleet fill missing"
    $script:fail++
  }

  if ($gsxCoreText -match 'fleet_owner' -or (Test-Path (Join-Path $RepoRoot "Include\GSignalX\SignalBus.mqh"))) {
    $busText = Get-Content (Join-Path $RepoRoot "Include\GSignalX\SignalBus.mqh") -Raw -ErrorAction SilentlyContinue
    if ($busText -match 'fleet_owner') {
      Add-Line "PASS  SignalBus publishes fleet_owner"
    }
    else {
      Add-Line "FAIL  SignalBus missing fleet_owner"
      $script:fail++
    }
  }

  #--- Multisymbol Dashboard ---
  $dash = Join-Path $RepoRoot "GsignalX_Multisymbol_Dashboard.mq5"
  $store = Join-Path $RepoRoot "Include\GSignalX\RosterStore.mqh"
  $msPanel = Join-Path $RepoRoot "Include\GSignalX\MultisymbolPanel.mqh"
  $dashText = if (Test-Path $dash) { Get-Content $dash -Raw } else { "" }
  $storeText = if (Test-Path $store) { Get-Content $store -Raw } else { "" }
  $msPanelText = if (Test-Path $msPanel) { Get-Content $msPanel -Raw } else { "" }

  if ($dashText -match 'NEVER closes' -and $dashText -match 'GsxMsPanelDrawFull') {
    Add-Line "PASS  Multisymbol Dashboard host present (no closes)"
  }
  else {
    Add-Line "FAIL  Multisymbol Dashboard missing"
    $script:fail++
  }

  if ($storeText -match 'GSX_SVC_ROSTER_SEQ_' -and $storeText -match 'GsxRosterStoreSave') {
    Add-Line "PASS  RosterStore CSV + seq persistence"
  }
  else {
    Add-Line "FAIL  RosterStore persistence missing"
    $script:fail++
  }

  if ($gsxCoreText -match 'GsxCoreMaybeReloadRoster' -and ($gsxCoreText -match 'GsxRosterIsFleetCandidate' -or $gsxCoreText -match 'GsxRosterMuteGet')) {
    Add-Line "PASS  Core hot-reload + pair-state-aware fleet fill"
  }
  else {
    Add-Line "FAIL  Core hot-reload / pair-state gate missing"
    $script:fail++
  }

  if ($msPanelText -match 'GSXMS_' -and $gsxText -match 'InpShowRosterStrip') {
    Add-Line "PASS  MultisymbolPanel GSXMS_ + chart roster strip input"
  }
  else {
    Add-Line "FAIL  MultisymbolPanel / chart strip missing"
    $script:fail++
  }

  #--- Prop Trade Center + Telegram ---
  $tg = Join-Path $RepoRoot "Include\GSignalX\TelegramNotifier.mqh"
  $prop = Join-Path $RepoRoot "Include\GSignalX\PropRisk.mqh"
  $tgText = if (Test-Path $tg) { Get-Content $tg -Raw } else { "" }
  $propText = if (Test-Path $prop) { Get-Content $prop -Raw } else { "" }

  if ($tgText -match 'WebRequest' -and $tgText -match 'GsxTgVerifyConnection' -and $tgText -match 'GSX_TG_QUEUE_CAP' -and $tgText -match 'GsxTgHttpPostEx' -and $tgText -match '\[TG\] verify') {
    Add-Line "PASS  TelegramNotifier WebRequest + verify + queue"
  }
  else {
    Add-Line "FAIL  TelegramNotifier incomplete"
    $script:fail++
  }

  if ($tgText -match 'GsxTgChatIdOk' -and $tgText -match 'chatId must be numeric' -and
      $tgText -match 'GsxTgHttpPostEx\(token,\s*chatId,\s*text,\s*false' -and
      $tgText -match 'GSX_TG_REVERIFY_COOLDOWN_S') {
    Add-Line "PASS  Telegram v1.29 plain post + chatId reject + reverify cooldown"
  }
  else {
    Add-Line "FAIL  Telegram v1.29 plain/chatId/reverify contract missing"
    $script:fail++
  }

  if ($tgText -match 'GsxTgHealthyAdd' -and $tgText -match 'skip ' -and $tgText -match 'g_tgHealthyN') {
    Add-Line "PASS  Telegram v1.30 soft VERIFY healthy-chat list"
  }
  else {
    Add-Line "FAIL  Telegram v1.30 soft VERIFY / healthy chats missing"
    $script:fail++
  }

  if ($tgText -match 'a == b' -and $tgText -match 'silent window disabled') {
    Add-Line "PASS  Telegram silent hours a==b means off"
  }
  else {
    Add-Line "FAIL  Telegram silent hours a==b fix missing"
    $script:fail++
  }

  if ($tgText -match 'GSX_TG_ERROR' -and $tgText -match 'GsxTgPublishStatus' -and $tgText -match 'GSX_TG_QUEUE_CAP\s+10') {
    Add-Line "PASS  Telegram v1.27 Error status + PublishStatus + queue=10"
  }
  else {
    Add-Line "FAIL  Telegram v1.27 status/publish/queue contract missing"
    $script:fail++
  }

  if ($gsxSvcText -match 'InpTgEnable' -and $gsxText -match 'InpTgEnable') {
    Add-Line "PASS  Service + Chart Telegram inputs present"
  }
  else {
    Add-Line "FAIL  Service/Chart Telegram inputs missing"
    $script:fail++
  }

  if ($dashText -match 'BTN_TG_VERIFY' -or $msPanelText -match 'BTN_TG_VERIFY') {
    Add-Line "PASS  Trade Center TG VERIFY button"
  }
  else {
    Add-Line "FAIL  TG VERIFY UI missing"
    $script:fail++
  }

  if (Test-Path (Join-Path $RepoRoot "Include\GSignalX\TgDealWatch.mqh")) {
    Add-Line "PASS  TgDealWatch.mqh present"
  }
  else {
    Add-Line "FAIL  TgDealWatch.mqh missing"
    $script:fail++
  }

  if ($propText -match 'GsxPropEvaluate' -and $propText -match 'DAILY_LOSS' -and $propText -match 'CONSISTENCY') {
    Add-Line "PASS  PropRisk challenge gates present"
  }
  else {
    Add-Line "FAIL  PropRisk gates missing"
    $script:fail++
  }

  if ($dashText -match 'InpTgBotToken' -and $dashText -match 'InpPropEnable' -and
      ($dashText -match '#property\s+version\s+"2\.\d+"')) {
    Add-Line "PASS  Dashboard 2.xx Telegram + Prop inputs"
  }
  else {
    Add-Line "FAIL  Dashboard 2.xx wiring / version missing"
    $script:fail++
  }

  if ($msPanelText -match 'GSXMS_WIDTH\s+1280' -and $msPanelText -match 'GSXMS_BTN_H\s+32') {
    Add-Line "PASS  Trade Center button sizing 1280/32"
  }
  else {
    Add-Line "FAIL  Trade Center sizing not updated (expect 1280/32)"
    $script:fail++
  }

  #--- v1.26 categories / pair state / sessions / events ---
  $symClass = Join-Path $RepoRoot "Include\GSignalX\SymbolClass.mqh"
  $sessClk  = Join-Path $RepoRoot "Include\GSignalX\SessionClock.mqh"
  $evtGate  = Join-Path $RepoRoot "Include\GSignalX\EventGate.mqh"
  Test-PathMark $symClass "SymbolClass.mqh" | Out-Null
  Test-PathMark $sessClk  "SessionClock.mqh" | Out-Null
  Test-PathMark $evtGate  "EventGate.mqh" | Out-Null

  if ($storeText -match 'GSX_PAIR_START' -and $storeText -match 'GsxRosterStateGet' -and $storeText -match 'GsxRosterIsFleetCandidate') {
    Add-Line "PASS  RosterStore pair state START/STOP/SUSPEND"
  }
  else {
    Add-Line "FAIL  RosterStore pair state missing"
    $script:fail++
  }

  if ($msPanelText -match 'BTN_CAT_FX' -and $msPanelText -match 'BTN_STATE_' -and $msPanelText -match 'SESS') {
    Add-Line "PASS  Trade Center category tabs + state + session strip"
  }
  else {
    Add-Line "FAIL  Trade Center v1.26 UI chrome missing"
    $script:fail++
  }

  if ($dashText -match 'InpEvtCalendarEnable' -and $dashText -match 'GsxEventGatePoll') {
    Add-Line "PASS  Dashboard EventGate wiring"
  }
  else {
    Add-Line "FAIL  Dashboard EventGate wiring missing"
    $script:fail++
  }

  if ($gsxCoreText -match 'GsxRosterIsFleetCandidate' -and $gsxCoreText -match 'GsxEventBlocksSymbol') {
    Add-Line "PASS  Core honors pair state + event SKIP blocks"
  }
  else {
    Add-Line "FAIL  Core fill path missing state/event gates"
    $script:fail++
  }

  #--- Velocity 2.00 packaging: host #property version asserts ---
  $hosts200 = @(
    @{ Path = (Join-Path $RepoRoot "GsignalX_GocityGroup.mq5"); Label = "GsignalX_GocityGroup" },
    @{ Path = (Join-Path $RepoRoot "GsignalX_Service.mq5"); Label = "GsignalX_Service" },
    @{ Path = (Join-Path $RepoRoot "GsignalX_Multisymbol_Dashboard.mq5"); Label = "GsignalX_Multisymbol_Dashboard" },
    @{ Path = (Join-Path $RepoRoot "ProfitScouter_DollarTarget.mq5"); Label = "ProfitScouter_DollarTarget" },
    @{ Path = (Join-Path $RepoRoot "ProfitScouter_Service.mq5"); Label = "ProfitScouter_Service" },
    @{ Path = (Join-Path $RepoRoot "ProfitOpportunity_Grader.mq5"); Label = "ProfitOpportunity_Grader" }
  )
  $verOk = 0
  foreach ($h in $hosts200) {
    $t = if (Test-Path $h.Path) { Get-Content $h.Path -Raw } else { "" }
    if ($t -match '#property\s+version\s+"2\.\d+"') {
      $verOk++
    }
    else {
      Add-Line ("FAIL  {0} missing #property version `"2.xx`"" -f $h.Label)
      $script:fail++
    }
  }
  if ($verOk -eq $hosts200.Count) {
    Add-Line "PASS  Velocity 2.xx host versions (6/6)"
  }

  $busProto = Join-Path $RepoRoot "Include\GSignalX\BusProtocol.mqh"
  $busProtoText = if (Test-Path $busProto) { Get-Content $busProto -Raw } else { "" }
  if ($busProtoText -match '#define\s+GSX_BUS_VERSION\s+1\b') {
    Add-Line "PASS  GSX_BUS_VERSION remains 1 (product 2.00 keeps bus schema 1)"
  }
  else {
    Add-Line "FAIL  GSX_BUS_VERSION unexpected (expected 1)"
    $script:fail++
  }
}

function Confirm-Files {
  Add-Line "=== GATE Files ==="
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\BusIO.mqh") "Include GSignalX\BusIO.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\OpportunityGrade.mqh") "Include GSignalX\OpportunityGrade.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\LotSizing.mqh") "Include GSignalX\LotSizing.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\ChartPanel.mqh") "Include GSignalX\ChartPanel.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\Fleet.mqh") "Include GSignalX\Fleet.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\ScoutLink.mqh") "Include GSignalX\ScoutLink.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\CloseTrigger.mqh") "Include GSignalX\CloseTrigger.mqh" | Out-Null
  Test-PathMark (Join-Path $RepoRoot "Include\GSignalX\CloseTrigger.mqh") "Repo CloseTrigger.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\SettingsNotify.mqh") "Include GSignalX\SettingsNotify.mqh" | Out-Null
  Test-PathMark (Join-Path $RepoRoot "Include\GSignalX\SettingsNotify.mqh") "Repo SettingsNotify.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\TgDealWatch.mqh") "Include GSignalX\TgDealWatch.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\TelegramNotifier.mqh") "Include GSignalX\TelegramNotifier.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\Engines.mqh") "Include GSignalX\Engines.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\Core.mqh") "Include GSignalX\Core.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\EntryExec.mqh") "Include GSignalX\EntryExec.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\RosterStore.mqh") "Include GSignalX\RosterStore.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\MultisymbolPanel.mqh") "Include GSignalX\MultisymbolPanel.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\RosterViewModel.mqh") "Include GSignalX\RosterViewModel.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\ProfitScouter\Core.mqh") "Include ProfitScouter\Core.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\ProfitScouter\Inputs.mqh") "Include ProfitScouter\Inputs.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\ProfitScouter\AtrTrail.mqh") "Include ProfitScouter\AtrTrail.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\CandleMetrics.mqh") "Include GSignalX\CandleMetrics.mqh" | Out-Null
  Test-PathMark (Join-Path $RepoRoot "Include\ProfitScouter\Inputs.mqh") "Repo ProfitScouter\Inputs.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Experts\GsignalX_GocityGroup.mq5") "Experts GsignalX" | Out-Null
  Test-PathMark (Join-Path $mql5 "Experts\GsignalX_Multisymbol_Dashboard.mq5") "Experts Multisymbol Dashboard" | Out-Null
  Test-PathMark (Join-Path $mql5 "Experts\ProfitScouter_DollarTarget.mq5") "Experts ProfitScouter EA" | Out-Null
  Test-PathMark (Join-Path $mql5 "Services\GsignalX_Service.mq5") "Services GsignalX" | Out-Null
  Test-PathMark (Join-Path $mql5 "Services\ProfitScouter_Service.mq5") "Services ProfitScouter" | Out-Null
  Test-PathMark (Join-Path $mql5 "Services\ProfitOpportunity_Grader.mq5") "Services Grader" | Out-Null
  Test-PathMark (Join-Path $mql5 "Scripts\ProfitHarvest_Now.mq5") "Scripts Harvest" | Out-Null
}

function Confirm-Compile {
  Add-Line "=== GATE Compile ==="
  $ex5 = @(
    "Experts\GsignalX_GocityGroup.ex5",
    "Experts\GsignalX_Multisymbol_Dashboard.ex5",
    "Experts\ProfitScouter_DollarTarget.ex5",
    "Services\GsignalX_Service.ex5",
    "Services\ProfitScouter_Service.ex5",
    "Services\ProfitOpportunity_Grader.ex5",
    "Scripts\ProfitHarvest_Now.ex5"
  )
  foreach ($rel in $ex5) {
    Test-PathMark (Join-Path $mql5 $rel) $rel | Out-Null
  }

  $logs = @(
    "Services\ProfitScouter_Service.log",
    "Experts\ProfitScouter_DollarTarget.log",
    "Services\ProfitOpportunity_Grader.log",
    "Services\GsignalX_Service.log",
    "Experts\GsignalX_Multisymbol_Dashboard.log",
    "Experts\GsignalX_GocityGroup.log",
    "Scripts\ProfitHarvest_Now.log"
  )
  foreach ($rel in $logs) {
    $log = Join-Path $mql5 $rel
    if (-not (Test-Path $log)) {
      Add-Line "WARN  no log yet: $rel (compile once if .ex5 missing)"
      continue
    }
    $result = Select-String -Path $log -Pattern "^Result:" | Select-Object -Last 1
    if ($result -and $result.Line -match "0 errors") {
      Add-Line "PASS  $rel -> $($result.Line)"
    }
    elseif ($result) {
      Add-Line "FAIL  $rel -> $($result.Line)"
      $script:fail++
    }
    else {
      Add-Line "WARN  $rel has no Result line"
    }
  }
}

function Get-JsonTsAge([string] $path) {
  if (-not (Test-Path $path)) { return $null }
  $raw = Get-Content $path -Raw -ErrorAction SilentlyContinue
  if (-not $raw) { return $null }
  if ($raw -match '"ts"\s*:\s*(\d+)') {
    $ts = [int64]$Matches[1]
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    # MT5 TimeCurrent is often broker/server time; treat as rough age only
    return [int]([Math]::Abs($now - $ts))
  }
  return $null
}

function Confirm-ProdHardening {
  Add-Line "=== GATE ProdHardening (v2.01 static) ==="
  $busIo = Join-Path $RepoRoot "Include\GSignalX\BusIO.mqh"
  $core  = Join-Path $RepoRoot "Include\GSignalX\Core.mqh"
  $sig   = Join-Path $RepoRoot "Include\GSignalX\SignalBus.mqh"
  $svc   = Join-Path $RepoRoot "GsignalX_Service.mq5"
  $dash  = Join-Path $RepoRoot "GsignalX_Multisymbol_Dashboard.mq5"
  $panel = Join-Path $RepoRoot "Include\GSignalX\MultisymbolPanel.mqh"
  $tg    = Join-Path $RepoRoot "Include\GSignalX\TelegramNotifier.mqh"
  $preset = Join-Path $RepoRoot "deploy\presets\GSignalX_Service_PropDesk_30.set"

  $busIoText = if (Test-Path $busIo) { Get-Content $busIo -Raw } else { "" }
  $coreText  = if (Test-Path $core)  { Get-Content $core  -Raw } else { "" }
  $sigText   = if (Test-Path $sig)   { Get-Content $sig   -Raw } else { "" }
  $svcText   = if (Test-Path $svc)   { Get-Content $svc   -Raw } else { "" }
  $dashText  = if (Test-Path $dash)  { Get-Content $dash  -Raw } else { "" }
  $panelText = if (Test-Path $panel) { Get-Content $panel -Raw } else { "" }
  $tgText    = if (Test-Path $tg)    { Get-Content $tg    -Raw } else { "" }

  if ($busIoText -match 'GsxBusReadAllRetry' -and $busIoText -notmatch 'FileDelete\(relativePath') {
    Add-Line "PASS  BusIO atomic replace without delete-gap + read retry"
  }
  else {
    Add-Line "FAIL  BusIO v2.01 atomic/retry contract missing"
    $script:fail++
  }

  if ($sigText -match 'GsxBusFleetSnap' -and $sigText -match 'GsxSignalBusWriteSymbolEx' -and $sigText -match 'GsxSignalBusFingerprint') {
    Add-Line "PASS  SignalBus fleet snapshot + dirty fingerprint"
  }
  else {
    Add-Line "FAIL  SignalBus v2.01 fleet/fingerprint missing"
    $script:fail++
  }

  if ($coreText -match 'InpEngineBudgetPerCycle' -and $coreText -match 'g_engBudgetCursor' -and $coreText -match 'GsxEngStateCopy') {
    Add-Line "PASS  Core engine budget + roster preserve"
  }
  else {
    Add-Line "FAIL  Core engine budget / roster preserve missing"
    $script:fail++
  }

  if ($svcText -match 'InpPropEnable' -and $svcText -match 'SvcPropTick' -and $svcText -match 'GsxTgProcessQueueEx') {
    Add-Line "PASS  Service PropRisk + TG 1-msg budget"
  }
  else {
    Add-Line "FAIL  Service Prop/TG hardening missing"
    $script:fail++
  }

  if ($dashText -match 'g_lastSnapFp' -and $dashText -match 'GsxTgProcessQueueEx' -and
      ($dashText -match 'InpRefreshMs' -or $dashText -match 'g_lastForcedRedraw')) {
    Add-Line "PASS  Dashboard dirty redraw + TG budget (V2.13 cadence flexible)"
  }
  else {
    Add-Line "FAIL  Dashboard dirty redraw / TG budget missing"
    $script:fail++
  }

  if ($panelText -match 'GsxMsPanelApplyAdaptive' -and
      ($panelText -match 'signalStale' -or $panelText -match 'dirState' -or
       (Get-Content (Join-Path $RepoRoot "Include\GSignalX\RosterViewModel.mqh") -Raw) -match 'signalStale')) {
    Add-Line "PASS  Trade Center adaptive layout + STALE/DIR state"
  }
  else {
    Add-Line "FAIL  MultisymbolPanel adaptive/STALE missing"
    $script:fail++
  }

  if ($tgText -match 'GsxTgProcessQueueEx') {
    Add-Line "PASS  TelegramNotifier ProcessQueueEx"
  }
  else {
    Add-Line "FAIL  TelegramNotifier ProcessQueueEx missing"
    $script:fail++
  }

  Test-PathMark $preset "preset GSignalX_Service_PropDesk_30.set" | Out-Null
  $docsCss = Join-Path $RepoRoot "docs\assets\css\gsx-docs.css"
  $docsJs  = Join-Path $RepoRoot "docs\assets\js\gsx-theme.js"
  $icon    = Join-Path $RepoRoot "docs\assets\icons\group-icon.svg"
  Test-PathMark $docsCss "docs shared CSS" | Out-Null
  Test-PathMark $docsJs  "docs theme JS" | Out-Null
  Test-PathMark $icon    "docs brand icon SVG" | Out-Null
}

function Confirm-Bus {
  Add-Line "=== GATE Bus ==="
  if (-not (Test-Path $busRoot)) {
    Add-Line "WARN  bus root missing (idle publishers OK offline): $busRoot"
  }
  else {
    Add-Line "PASS  bus root"
  }
  $index = Join-Path $busRoot "terminals\_index.txt"
  $tidList = @()
  if (-not (Test-Path $index)) {
    Add-Line "WARN  terminals\_index.txt missing (start Service/Desk with InpBusEnable)"
  }
  else {
    Add-Line "PASS  terminals\_index.txt"
    $tidList = @(Get-Content $index | Where-Object { $_.Trim() -ne "" })
    Add-Line ("INFO  indexed tids: {0}" -f $tidList.Count)
    if ($tidList.Count -ge 2) {
      Add-Line "PASS  multi-tid index (>=2 terminals)"
    }
    else {
      Add-Line "WARN  multi-tid: only $($tidList.Count) indexed (start a second terminal for full multi-desk confirm)"
    }
    foreach ($tid in $tidList) {
      $hb = Join-Path $busRoot ("terminals\{0}\heartbeat.json" -f $tid.Trim())
      if (Test-Path $hb) {
        $age = Get-JsonTsAge $hb
        if ($null -eq $age) {
          Add-Line "PASS  heartbeat $tid (no ts parse)"
        }
        elseif ($age -le 120) {
          Add-Line "PASS  heartbeat $tid age~${age}s"
        }
        else {
          Add-Line "WARN  heartbeat $tid age~${age}s (stale if publishers stopped)"
        }
      }
      else {
        Add-Line "WARN  missing heartbeat for $tid (idle publisher)"
      }
      $sigDir = Join-Path $busRoot ("terminals\{0}\signals" -f $tid.Trim())
      if (Test-Path $sigDir) {
        $n = @(Get-ChildItem $sigDir -Filter "*.json" -ErrorAction SilentlyContinue).Count
        Add-Line "INFO  signals json count for $tid : $n"
        if ($n -ge 20) {
          Add-Line "PASS  roster-scale signals >=20 for $tid"
        }
        elseif ($n -gt 0) {
          Add-Line "WARN  signals count $n <20 (load PropDesk_30 preset for 20-30 scale)"
        }
      }
      $snap = Join-Path $busRoot ("terminals\{0}\scouter\snapshot.json" -f $tid.Trim())
      if (Test-Path $snap) {
        Add-Line "PASS  scouter snapshot $tid"
      }
      else {
        Add-Line "WARN  no scouter snapshot for $tid (start ProfitScouter with InpBusEnable)"
      }
    }
  }

  # Bus race probe: rapid re-read of existing signal JSONs - empty body = fail
  Add-Line "--- Bus race probe (rapid reads) ---"
  $emptyHits = 0
  $reads = 0
  foreach ($tid in $tidList) {
    $sigDir = Join-Path $busRoot ("terminals\{0}\signals" -f $tid.Trim())
    if (-not (Test-Path $sigDir)) { continue }
    $files = @(Get-ChildItem $sigDir -Filter "*.json" -ErrorAction SilentlyContinue | Select-Object -First 12)
    for ($i = 0; $i -lt 20; $i++) {
      foreach ($f in $files) {
        $raw = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        $reads++
        if ([string]::IsNullOrWhiteSpace($raw)) { $emptyHits++ }
        elseif ($raw.TrimEnd().EndsWith("}") -eq $false -and $raw.Contains("{")) {
          # truncated mid-write
          $emptyHits++
        }
      }
    }
  }
  if ($reads -eq 0) {
    Add-Line "WARN  bus race probe skipped (no signal JSON yet)"
  }
  elseif ($emptyHits -eq 0) {
    Add-Line "PASS  bus race probe: 0 empty/truncated of $reads reads"
  }
  else {
    Add-Line "FAIL  bus race probe: $emptyHits empty/truncated of $reads reads"
    $script:fail++
  }
}

function Confirm-Grades {
  Add-Line "=== GATE Grades ==="
  $grades = Join-Path $busRoot "grades\latest.json"
  if (-not (Test-Path $grades)) {
    Add-Line "WARN  grades\latest.json missing (idle grader OK offline)"
    return
  }
  Add-Line "PASS  grades\latest.json"
  $raw = Get-Content $grades -Raw
  if ($raw -notmatch '"version"\s*:\s*1') {
    Add-Line "FAIL  grades version missing or not 1"
    $script:fail++
  }
  else {
    Add-Line "PASS  grades version=1"
  }
  $age = Get-JsonTsAge $grades
  if ($null -ne $age) {
    if ($age -le 120) { Add-Line "PASS  grades ts age~${age}s" }
    else { Add-Line "WARN  grades ts age~${age}s (is Grader running?)" }
  }
  $entries = ([regex]::Matches($raw, '"kind"\s*:\s*"entry"')).Count
  $harvests = ([regex]::Matches($raw, '"kind"\s*:\s*"harvest"')).Count
  Add-Line "INFO  entry items~$entries  harvest items~$harvests"
  if ($entries -eq 0 -and $harvests -eq 0) {
    Add-Line "WARN  empty ranks (OK if no signals/positions yet)"
  }
}

Add-Line "GSignalX Confirm  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Add-Line "TerminalDataPath=$TerminalDataPath"
Add-Line "BusRoot=$busRoot"
Add-Line ""

function Confirm-Functional {
  Add-Line "=== GATE Functional (desk contracts static) ==="

  $scoutLink = Join-Path $RepoRoot "Include\GSignalX\ScoutLink.mqh"
  $fleet     = Join-Path $RepoRoot "Include\GSignalX\Fleet.mqh"
  $store     = Join-Path $RepoRoot "Include\GSignalX\RosterStore.mqh"
  $core      = Join-Path $RepoRoot "Include\GSignalX\Core.mqh"
  $entry     = Join-Path $RepoRoot "Include\GSignalX\EntryExec.mqh"
  $msPanel   = Join-Path $RepoRoot "Include\GSignalX\MultisymbolPanel.mqh"
  $prop      = Join-Path $RepoRoot "Include\GSignalX\PropRisk.mqh"
  $psCore    = Join-Path $RepoRoot "Include\ProfitScouter\Core.mqh"
  $dash      = Join-Path $RepoRoot "GsignalX_Multisymbol_Dashboard.mq5"
  $chart     = Join-Path $RepoRoot "GsignalX_GocityGroup.mq5"

  $scoutText  = if (Test-Path $scoutLink) { Get-Content $scoutLink -Raw } else { "" }
  $fleetText  = if (Test-Path $fleet) { Get-Content $fleet -Raw } else { "" }
  $storeText  = if (Test-Path $store) { Get-Content $store -Raw } else { "" }
  $coreText   = if (Test-Path $core) { Get-Content $core -Raw } else { "" }
  $entryText  = if (Test-Path $entry) { Get-Content $entry -Raw } else { "" }
  $msText     = if (Test-Path $msPanel) { Get-Content $msPanel -Raw } else { "" }
  $propText   = if (Test-Path $prop) { Get-Content $prop -Raw } else { "" }
  $psText     = if (Test-Path $psCore) { Get-Content $psCore -Raw } else { "" }
  $dashText   = if (Test-Path $dash) { Get-Content $dash -Raw } else { "" }
  $chartText  = if (Test-Path $chart) { Get-Content $chart -Raw } else { "" }

  Test-PathMark $scoutLink "ScoutLink.mqh" | Out-Null

  if ($scoutText -match 'GsxScoutRunVarName' -and $scoutText -match 'GsxScoutRunSetLinked' -and $scoutText -match 'PS%d_RUN') {
    Add-Line "PASS  ScoutLink shared PS{id}_RUN helpers"
  }
  else {
    Add-Line "FAIL  ScoutLink helpers missing"
    $script:fail++
  }

  if ($fleetText -match 'GSX_SVC_RUN_' -and $fleetText -match 'GSX_SVC_OWN_' -and $fleetText -match 'GsxFleetServiceOwnSet') {
    Add-Line "PASS  Service RUN/OWN GV helpers"
  }
  else {
    Add-Line "FAIL  Service RUN/OWN helpers missing"
    $script:fail++
  }

  if ($storeText -match 'GSX_MS_FLIPWAIT_' -and $storeText -match 'GsxRosterFlipWaitGet') {
    Add-Line "PASS  RosterStore FOLLOW/WAIT GV helpers"
  }
  else {
    Add-Line "FAIL  FlipWait GV helpers missing"
    $script:fail++
  }

  if ($coreText -match 'GsxRosterFlipWaitGet' -and $coreText -match 'g_flipWait') {
    Add-Line "PASS  Core hot-reloads FOLLOW/WAIT each cycle"
  }
  else {
    Add-Line "FAIL  Core flip-wait hot-reload missing"
    $script:fail++
  }

  $followGate = Join-Path $RepoRoot "Include\GSignalX\FollowGate.mqh"
  $fgText = if (Test-Path $followGate) { Get-Content $followGate -Raw } else { "" }

  if (($coreText -match 'GsxAllowEntry' -or $coreText -match 'GsxAllowNewDirEntry') -and
      ($fgText -match 'GsxAllowNewDirEntry') -and ($fgText -match 'GsxAllowEntry') -and
      ($entryText -match 'FollowGate.mqh')) {
    Add-Line "PASS  Single WAIT+FollowDir gate GsxAllowEntry"
  }
  else {
    Add-Line "FAIL  WAIT gate missing"
    $script:fail++
  }

  if ($msText -match 'BTN_HALT' -and $msText -match 'GsxScoutRunSetLinked' -and $msText -match 'HALT \(no closes\)') {
    Add-Line "PASS  Trade Center HALT pauses linked Scouter (no closes)"
  }
  else {
    Add-Line "FAIL  Trade Center HALT scout link missing"
    $script:fail++
  }

  if ($msText -match 'BTN_STOP' -and $msText -match 'Entries only') {
    Add-Line "PASS  Trade Center STOP entries-only (Scouter keeps harvesting)"
  }
  else {
    Add-Line "FAIL  Trade Center STOP contract missing"
    $script:fail++
  }

  if ($msText -match 'BTN_PLAY' -and $msText -match 'GsxScoutRunSetLinked') {
    Add-Line "PASS  Trade Center PLAY resumes Service RUN + Scouter"
  }
  else {
    Add-Line "FAIL  Trade Center PLAY scout resume missing"
    $script:fail++
  }

  if ($dashText -match 'InpScoutLinkEnable' -and $dashText -match 'InpScoutInstanceID' -and $dashText -match 'GsxMsPanelSetScoutLink') {
    Add-Line "PASS  Dashboard scout link inputs wired"
  }
  else {
    Add-Line "FAIL  Dashboard scout link inputs missing"
    $script:fail++
  }

  if ($chartText -match 'GSX_SPREADIGN_' -and $chartText -match 'GSX_AUTOLOT_' -and $chartText -match 'GSX_EQGUARD_') {
    Add-Line "PASS  Chart SPREAD/AUTOLOT/EQ GV names present"
  }
  else {
    Add-Line "FAIL  Chart SPREAD/AUTOLOT/EQ GVs missing"
    $script:fail++
  }

  if ($chartText -match 'BTN_FLAT' -and $chartText -match 'SetScoutRun\(false\)' -and $chartText -match 'SetRunState\(false') {
    Add-Line "PASS  Chart HALT pauses entries + Scouter"
  }
  else {
    Add-Line "FAIL  Chart HALT contract missing"
    $script:fail++
  }

  if ($propText -match 'GsxPropApplySoftStop' -and $propText -match 'GsxFleetServiceRunSet' -and $propText -notmatch 'PositionClose') {
    Add-Line "PASS  PropRisk soft STOP (RUN=0, no PositionClose)"
  }
  else {
    Add-Line "FAIL  PropRisk soft STOP contract broken"
    $script:fail++
  }

  if ($entryText -match 'never closes' -or $entryText -match 'BLOCKED' -or $entryText -match 'exits are owned by Profit Scouter') {
    Add-Line "PASS  EntryExec blocks reverse-closes"
  }
  else {
    Add-Line "FAIL  EntryExec close block missing"
    $script:fail++
  }

  if ($psText -match 'HarvestWinners' -and $psText -match 'IsProfitableTicket' -and $psText -match 'HandleAdverseBarLossCut') {
    Add-Line "PASS  Scouter winners-only harvest + adverse loser path"
  }
  else {
    Add-Line "FAIL  Scouter harvest/adverse path markers missing"
    $script:fail++
  }

  if ($psText -match 'GsxScoutRunVarName' -or $psText -match 'GsxScoutRunSet') {
    Add-Line "PASS  ProfitScouter uses shared ScoutLink"
  }
  else {
    Add-Line "FAIL  ProfitScouter not on ScoutLink helpers"
    $script:fail++
  }

  if ($coreText -match 'GsxFleetServiceOwnSet' -and $chartText -match 'ChartAutoEntriesAllowed' -and $chartText -match 'GsxFleetServiceOwns') {
    Add-Line "PASS  OWN double-fill deferral contract present"
  }
  else {
    Add-Line "FAIL  OWN double-fill contract missing"
    $script:fail++
  }

  if ($msText -match 'GSXMS_WIDTH\s+1280' -and $msText -match 'GSXMS_BTN_H\s+32') {
    Add-Line "PASS  Trade Center sizing 1280/32 (Functional)"
  }
  else {
    Add-Line "FAIL  Trade Center sizing assert (Functional expect 1280/32)"
    $script:fail++
  }

  # --- V2.04 must-not-change freeze (Lot / Spread / Floating P/L) ---
  $lot = Join-Path $RepoRoot "Include\GSignalX\LotSizing.mqh"
  $gates = Join-Path $RepoRoot "Include\GSignalX\MarketGates.mqh"
  $lotText = if (Test-Path $lot) { Get-Content $lot -Raw } else { "" }
  $gatesText = if (Test-Path $gates) { Get-Content $gates -Raw } else { "" }

  if ($lotText -match 'GsxCalcLot' -and $lotText -match 'GsxNormalizeLot' -and
      $lotText -match 'GsxAccountDrawdownPct' -and
      $lotText -match 'riskMoney / \(\(stopDist / tickSize\) \* tickValue\)') {
    Add-Line "PASS  LotSizing freeze (CalcLot/Normalize/DD signatures)"
  }
  else {
    Add-Line "FAIL  LotSizing freeze broken (must-not-change)"
    $script:fail++
  }

  if ($gatesText -match 'bool GsxSpreadOK' -and $gatesText -match 'SYMBOL_SPREAD' -and
      $gatesText -match 'spread .+ > limit') {
    Add-Line "PASS  MarketGates GsxSpreadOK freeze"
  }
  else {
    Add-Line "FAIL  GsxSpreadOK freeze broken (must-not-change)"
    $script:fail++
  }

  if ($gatesText -match 'GsxEffectiveMaxSpreadPt' -and $gatesText -match 'GSX_CLASS_CRYPTO' -and
      $gatesText -match '1500' -and $gatesText -match 'cryptoExempt') {
    Add-Line "PASS  V2.12 class-aware spread + crypto session/hour exempt"
  }
  else {
    Add-Line "FAIL  V2.12 CMD/CR spread/session gates missing"
    $script:fail++
  }

  if ($fleetText -match 'GsxFleetFloating' -and $fleetText -match 'POSITION_PROFIT' -and
      $fleetText -match 'POSITION_SWAP') {
    Add-Line "PASS  Fleet floating P/L freeze"
  }
  else {
    Add-Line "FAIL  Fleet floating P/L freeze broken"
    $script:fail++
  }

  # --- V2.04 FollowDir + desk TF (present after Phase 1+) ---
  if ($storeText -match 'GSX_MS_FOLLOWDIR_' -and $storeText -match 'GsxRosterFollowDirGet' -and
      $storeText -match 'GSX_FOLLOW_AUTO' -and $storeText -match 'GsxRosterTimeframeGet') {
    Add-Line "PASS  RosterStore FollowDir + TF GV helpers"
  }
  else {
    Add-Line "FAIL  FollowDir/TF GV helpers missing"
    $script:fail++
  }

  if ($entryText -match 'GsxFollowDirAllows' -and $entryText -match 'FollowGate.mqh') {
    Add-Line "PASS  EntryExec shared FollowDir gate"
  }
  else {
    $fg = Join-Path $RepoRoot "Include\GSignalX\FollowGate.mqh"
    $fgText = if (Test-Path $fg) { Get-Content $fg -Raw } else { "" }
    if ($fgText -match 'GsxFollowDirAllows' -and $fgText -match 'GsxAllowEntry') {
      Add-Line "PASS  EntryExec shared FollowDir gate"
    }
    else {
      Add-Line "FAIL  EntryExec FollowDir gate missing"
      $script:fail++
    }
  }

  if ($coreText -match 'GsxRosterFollowDirGet' -and $coreText -match 'GsxAllowEntry' -and
      $coreText -match 'GsxRosterTimeframeGet') {
    Add-Line "PASS  Core enforces FollowDir + live TF"
  }
  else {
    Add-Line "FAIL  Core FollowDir/TF wiring missing"
    $script:fail++
  }

  if ($msText -match 'BTN_FDIR_' -or $msText -match 'FollowDir' -or $msText -match 'FOLLOWDIR') {
    if ($msText -match 'new entries only' -or $msText -match 'Affects new entries only') {
      Add-Line "PASS  Trade Center FollowDir UI + entries-only copy"
    }
    else {
      Add-Line "FAIL  Trade Center FollowDir entries-only tooltip missing"
      $script:fail++
    }
  }
  else {
    Add-Line "FAIL  Trade Center FollowDir controls missing"
    $script:fail++
  }

  # --- V2.06 multi-symbol trading parity ---
  $fg206 = Join-Path $RepoRoot "Include\GSignalX\FollowGate.mqh"
  $fg206Text = if (Test-Path $fg206) { Get-Content $fg206 -Raw } else { "" }
  if ($storeText -match 'GSX_FOLLOW_WAIT' -and $fg206Text -match 'GSX_FOLLOW_WAIT' -and
      $storeText -match 'GsxRosterFollowDirCycle' -and $fg206Text -match 'GSX_FOLLOW_WAIT') {
    Add-Line "PASS  FollowDir Wait mode (Follow/Buy/Sell/Wait)"
  }
  else {
    Add-Line "FAIL  FollowDir Wait mode missing"
    $script:fail++
  }

  if ($msText -match 'GsxMsRetireSymbol' -and $msText -match 'BTN_SWAP' -and
      $msText -match 'BTN_PAIR_START_ALL' -and $coreText -match 'GsxCoreRetireSymbol') {
    Add-Line "PASS  Retire cleanup + SWAP + start/stop-all"
  }
  else {
    Add-Line "FAIL  Retire/SWAP/start-all wiring missing"
    $script:fail++
  }

  if ($coreText -match 'InpSignalMaxAgeSec|GsxCoreSignalFresh' -and
      $coreText -match 'GsxCoreFillsPerCycle|InpFleetFillsPerCycle' -and
      $coreText -match 'g_joinDirCache') {
    Add-Line "PASS  Signal-age gate + multi-fill + dir-change cache"
  }
  else {
    Add-Line "FAIL  Latency/stale fill path missing"
    $script:fail++
  }

  $gsxText = Get-Content (Join-Path $RepoRoot "GsignalX_GocityGroup.mq5") -Raw
  if ($gsxText -match 'GsxRosterContains' -and $gsxText -match 'ChartAutoEntriesAllowed' -and
      $gsxText -match 'Service owns this roster pair') {
    Add-Line "PASS  Chart defers roster symbols when Service owns"
  }
  else {
    Add-Line "FAIL  Chart single-owner roster defer missing"
    $script:fail++
  }

  $rvm = Join-Path $RepoRoot "Include\GSignalX\RosterViewModel.mqh"
  $rvmText = if (Test-Path $rvm) { Get-Content $rvm -Raw } else { "" }
  if ($rvmText -match 'signalAgeSec' -and $msText -match 'signalAgeSec') {
    Add-Line "PASS  Chart strip signal age + FollowDir status fields"
  }
  else {
    Add-Line "FAIL  Strip status age/mode fields missing"
    $script:fail++
  }

  $busIo = Join-Path $RepoRoot "Include\GSignalX\BusIO.mqh"
  $busIoText = if (Test-Path $busIo) { Get-Content $busIo -Raw } else { "" }
  $busProto = Join-Path $RepoRoot "Include\GSignalX\BusProtocol.mqh"
  $busProtoText = if (Test-Path $busProto) { Get-Content $busProto -Raw } else { "" }
  if ($busIoText -match 'GsxBusReadFreshestSignal' -and $busProtoText -match 'GsxBusDeskSignalPath' -and
      $rvmText -match 'GsxBusReadFreshestSignal') {
    Add-Line "PASS  Cross-terminal freshest signal + desk mirror"
  }
  else {
    Add-Line "FAIL  Freshest/desk signal path missing"
    $script:fail++
  }

  if ($coreText -match 'GsxCorePublishBus' -and $coreText -match 'g_svcEnabled' -and
      ($coreText -match 'Always refresh engines' -or $coreText -match 'directions live even when STOPPED')) {
    Add-Line "PASS  Service publishes signals while STOPPED"
  }
  else {
    # Fallback: publish before early return on !g_svcEnabled
    if ($coreText -match 'GsxCorePublishBus\(\);' -and $coreText -match 'if\(!g_svcEnabled\)') {
      Add-Line "PASS  Service publishes signals while STOPPED"
    }
    else {
      Add-Line "FAIL  Service bus-while-stopped wiring missing"
      $script:fail++
    }
  }

  if ($storeText -match 'GsxRosterDedupeInPlace' -and $storeText -match 'duplicate') {
    Add-Line "PASS  Roster canon dedupe on ADD/load"
  }
  else {
    Add-Line "FAIL  Roster dedupe helpers missing"
    $script:fail++
  }

  $chartPanel = Join-Path $RepoRoot "Include\GSignalX\ChartPanel.mqh"
  $cpText = if (Test-Path $chartPanel) { Get-Content $chartPanel -Raw } else { "" }
  $quadDraw = Join-Path $RepoRoot "Include\GSignalX\MultisymbolQuadDraw.mqh"
  $qdText = if (Test-Path $quadDraw) { Get-Content $quadDraw -Raw } else { "" }
  $layoutBlob = $msText + "`n" + $qdText

  if (($layoutBlob -match 'SEC_SYS') -and ($layoutBlob -match 'SEC_AUTO') -and
      ($layoutBlob -match 'GsxLaySplit2' -or $cpText -match 'GsxLaySplit2')) {
    Add-Line "PASS  Trade Center quadrant section markers"
  }
  else {
    Add-Line "FAIL  Trade Center quadrant layout markers missing"
    $script:fail++
  }

  if ($cpText -match 'GsxLaySplit2' -and $qdText -match 'GsxLaySplit2' -and
      $qdText -match 'GsxMsDrawQuadUL' -and $qdText -match 'GsxMsDrawQuadLL') {
    Add-Line "PASS  True dual-column GsxLaySplit2 + quad drawers"
  }
  else {
    Add-Line "FAIL  True quadrant split/draw helpers missing"
    $script:fail++
  }

  if ($dashText -match 'InpShowPractice' -and $msText -match 'g_msShowPractice') {
    Add-Line "PASS  Practice coach muted by InpShowPractice"
  }
  else {
    Add-Line "FAIL  InpShowPractice / g_msShowPractice missing"
    $script:fail++
  }

  # --- V2.07 instant desk fill + service reliability ---
  $sigBus = Join-Path $RepoRoot "Include\GSignalX\SignalBus.mqh"
  $sigBusText = if (Test-Path $sigBus) { Get-Content $sigBus -Raw } else { "" }

  if ($coreText -match 'g_onboardPending' -and $coreText -match 'GsxCorePublishBusIndex' -and
      $coreText -match 'onboard priority' -and $coreText -match 'GsxCoreCalcIndex') {
    Add-Line "PASS  V2.07 onboard priority calc + immediate bus"
  }
  else {
    Add-Line "FAIL  V2.07 onboard priority path missing"
    $script:fail++
  }

  if ($coreText -match 'cooldown bypass' -or $coreText -match 'onboard \? 0') {
    Add-Line "PASS  V2.07 onboard fill claim exception"
  }
  else {
    Add-Line "FAIL  V2.07 onboard claim exception missing"
    $script:fail++
  }

  if ($rvmText -match 'dirState' -and $rvmText -match 'COMPUTE' -and $rvmText -match 'FLAT' -and
      $msText -match 'GsxMsDirCellTxt' -and $qdText -match 'GsxMsDirCellTxt') {
    Add-Line "PASS  V2.07 COMPUTE/LIVE/STALE/FLAT DIR UX"
  }
  else {
    Add-Line "FAIL  V2.07 DIR state UX missing"
    $script:fail++
  }

  if ($storeText -match 'GSX_MS_LASTDIR_' -and $storeText -match 'GsxRosterLastDirSet' -and
      $coreText -match 'GsxRosterLastDirSet') {
    Add-Line "PASS  V2.07 lastDir GV persistence"
  }
  else {
    Add-Line "FAIL  V2.07 lastDir GV missing"
    $script:fail++
  }

  if (($msText -match 'SVC OFF' -or $qdText -match 'SVC OFF') -and
      $rvmText -match 'svcAlive' -and $busIoText -match 'GsxBusHeartbeatFresh') {
    Add-Line "PASS  V2.07 SVC OFF + heartbeat health chip"
  }
  else {
    Add-Line "FAIL  V2.07 SVC OFF health chip missing"
    $script:fail++
  }

  if ($sigBusText -match 'fill_skip' -and $coreText -match 'g_fillSkip' -and
      $rvmText -match 'fillSkip') {
    Add-Line "PASS  V2.07 fill_skip on bus + desk row"
  }
  else {
    Add-Line "FAIL  V2.07 fill_skip wiring missing"
    $script:fail++
  }

  if ($busIoText -match 'GsxBusDeskSignalPath' -and $busIoText -match 'g_gsxFreshestTick' -and
      $busIoText -match '250') {
    Add-Line "PASS  V2.07 desk-mirror-first + 250ms freshest cache"
  }
  else {
    Add-Line "FAIL  V2.07 freshest cache / desk-first missing"
    $script:fail++
  }

  if ($coreText -match 'joinDirCache\[idx\] == 0' -or $coreText -match 'First fill') {
    Add-Line "PASS  V2.07 first-fill SignalMaxAge exempt"
  }
  else {
    Add-Line "FAIL  V2.07 first-fill age exempt missing"
    $script:fail++
  }

  # --- V2.08 capability independence + desk UX ---
  if ($chartText -match 'ChartAutoEntriesAllowed' -and
      $chartText -match 'Single owner: defer on-roster' -and
      ($chartText -notmatch 'if\(ChartServiceOwnsFleet\(\)\)\s*\n\s*return')) {
    Add-Line "PASS  V2.08 FleetFillCheck uses ChartAutoEntriesAllowed only"
  }
  else {
    # Fallback: no OWN-only early return before ChartAutoEntriesAllowed in FleetFillCheck
    $ff = [regex]::Match($chartText, '(?s)void FleetFillCheck\(\)\s*\{.*?ChartAutoEntriesAllowed')
    if ($ff.Success -and ($ff.Value -notmatch 'ChartServiceOwnsFleet\(\)')) {
      Add-Line "PASS  V2.08 FleetFillCheck uses ChartAutoEntriesAllowed only"
    }
    else {
      Add-Line "FAIL  V2.08 FleetFillCheck OWN short-circuit still present"
      $script:fail++
    }
  }

  if (($msText -match 'auto-PLAY' -or $storeText -match 'GsxRosterActivatePair') -and
      $storeText -match 'do NOT force PLAY') {
    Add-Line "PASS  V2.08/V2.14 ActivatePair onboard without forced PLAY"
  }
  else {
    Add-Line "FAIL  V2.08/V2.14 ActivatePair STOP-preserve missing"
    $script:fail++
  }

  if ($coreText -match 'GsxCoreOnboardTerminalSkip' -and
      ($coreText -match 'Keep pending through gate' -or $coreText -match 'gate skips')) {
    Add-Line "PASS  V2.08 onboard settle only on fill/terminal"
  }
  else {
    Add-Line "FAIL  V2.08 onboard settle rule missing"
    $script:fail++
  }

  if ($storeText -match 'GSX_MS_SPREADIGN_' -and $storeText -match 'GsxRosterSpreadIgnGet' -and
      $coreText -match 'GsxRosterSpreadIgnGet' -and
      ($msText -match 'BTN_SPREAD' -or $qdText -match 'BTN_SPREAD')) {
    Add-Line "PASS  V2.08 desk SPREAD/IGN GV + UI"
  }
  else {
    Add-Line "FAIL  V2.08 desk SPREAD/IGN missing"
    $script:fail++
  }

  if ($msText -match 'BTN_REM_' -and $qdText -match 'BTN_REM_' -and
      $msText -match 'select roster pair on carousel') {
    Add-Line "PASS  V2.08 per-row REM + safe carousel REM"
  }
  else {
    Add-Line "FAIL  V2.08 per-row / carousel REM missing"
    $script:fail++
  }

  if ($dashText -match 'InpScoutLinkEnable\s*=\s*false' -and
      $rvmText -match 'hbFresh' -and ($qdText -match 'ST_HB' -or $msText -match 'ST_HB')) {
    Add-Line "PASS  V2.08 ScoutLink default false + OWN/HB split"
  }
  else {
    Add-Line "FAIL  V2.08 independence defaults / HB pill missing"
    $script:fail++
  }

  # --- V2.09 desk lot/EQ + Scouter manual exits ---
  if ($storeText -match 'GSX_MS_AUTOLOT_' -and $storeText -match 'GsxRosterAutoLotGet' -and
      $storeText -match 'GSX_MS_EQGUARD_' -and $storeText -match 'GsxRosterEqGuardSet' -and
      $coreText -match 'GsxRosterAutoLotGet' -and $coreText -match 'GsxRosterEqGuardGet' -and
      $coreText -match 'equity guard' -and
      ($msText -match 'BTN_AUTOLOT' -or $qdText -match 'BTN_AUTOLOT') -and
      ($qdText -match 'BTN_EQ_0' -or $msText -match 'BTN_EQ_0' -or
       $msText -match 'BTN_EQGUARD' -or $qdText -match 'BTN_EQGUARD')) {
    Add-Line "PASS  V2.09/V2.13 desk AUTOLOT/EQ GVs + Core poll/gate + UI"
  }
  else {
    Add-Line "FAIL  V2.09 desk AUTOLOT/EQ wiring missing"
    $script:fail++
  }

  if ($psText -match 'ManualCloseBySide' -and $psText -match 'ManualCloseConfirmAndRun' -and
      $psText -match 'MessageBox' -and
      $psText -match 'BANK' -and $psText -match 'CUT' -and $psText -match 'FLAT' -and
      $psText -match 'never closes a losing trade') {
    Add-Line "PASS  V2.09 Scouter BANK/CUT/FLAT + MessageBox (loser guard intact)"
  }
  else {
    Add-Line "FAIL  V2.09 Scouter manual exit buttons missing"
    $script:fail++
  }

  # --- V2.10 multi chart-parity + drill fill ---
  $svc = Join-Path $RepoRoot "GsignalX_Service.mq5"
  $svcText = if (Test-Path $svc) { Get-Content $svc -Raw } else { "" }
  $eng = Join-Path $RepoRoot "Include\GSignalX\Engines.mqh"
  $engText = if (Test-Path $eng) { Get-Content $eng -Raw } else { "" }
  $entryEx = Join-Path $RepoRoot "Include\GSignalX\EntryExec.mqh"
  $entryExText = if (Test-Path $entryEx) { Get-Content $entryEx -Raw } else { "" }

  if ($coreText -match 'joinDirOverride' -or ($coreText -match 'GsxCoreJoinDir' -and $sigBusText -match 'joinDirOverride')) {
    Add-Line "PASS  V2.10 bus DIR uses joinDir override"
  }
  else {
    if ($sigBusText -match 'joinDirOverride' -and $coreText -match 'GsxSignalBusWriteSymbolEx') {
      Add-Line "PASS  V2.10 bus DIR uses joinDir override"
    }
    else {
      Add-Line "FAIL  V2.10 joinDir bus unify missing"
      $script:fail++
    }
  }

  if ($engText -match 'GsxEnabledTriggerMajority' -and $coreText -match 'GsxEnabledTriggerMajority') {
    Add-Line "PASS  V2.10 enabled-trigger majority joinDir fallback"
  }
  else {
    Add-Line "FAIL  V2.10 joinDir fallback missing"
    $script:fail++
  }

  if ($coreText -match 'waiting for history' -and
      ($coreText -match 'GsxCoreOnboardTerminalSkip' -and
       ($coreText -notmatch 'StringFind\(skip, ."history".\)'))) {
    Add-Line "PASS  V2.10 onboard history retry (not terminal)"
  }
  else {
    Add-Line "FAIL  V2.10 onboard history settle fix missing"
    $script:fail++
  }

  if ($svcText -match 'InpDrillEnable' -and $svcText -match 'InpDrillMinutes' -and
      $coreText -match 'GsxCoreStartDrill' -and $coreText -match 'drill closed' -and
      $coreText -match 'GsxCoreDrillActive') {
    Add-Line "PASS  V2.10 Service/Core PLAY drill window + fill gate"
  }
  else {
    Add-Line "FAIL  V2.10 drill parity missing"
    $script:fail++
  }

  if ($storeText -match 'GSX_MS_DRILLKICK_' -and $coreText -match 'GsxRosterDrillKickTake' -and
      $coreText -match 'g_coreNewOnboard' -and
      ($msText -match 'GsxRosterDrillKickSet')) {
    Add-Line "PASS  V2.10.1 PLAY/ADD drill kick + ADD under PLAY refresh"
  }
  else {
    Add-Line "FAIL  V2.10.1 drill kick / ADD refresh missing"
    $script:fail++
  }

  if ($storeText -match 'GsxRosterActivatePair' -and $msText -match 'GsxRosterActivatePair' -and
      $chartText -match 'GsxRosterActivatePair') {
    Add-Line "PASS  V2.11 ActivatePair chart/desk parity"
  }
  else {
    Add-Line "FAIL  V2.11 ActivatePair wiring missing"
    $script:fail++
  }

  if ($storeText -match 'GsxRosterOnboardKickSet' -and $coreText -match 'GsxCoreApplyOnboardKicks' -and
      $storeText -notmatch 'GsxRosterLastDirClear\(magic, sym\)') {
    Add-Line "PASS  V2.12 ADD/re-ARM onboard kick (keep LastDir)"
  }
  else {
    Add-Line "FAIL  V2.12 onboard kick / LastDir preserve missing"
    $script:fail++
  }

  if ($dashText -match 'GSX_DESK_CORE_LIVE' -and $rvmText -match 'GsxCoreLiveRowForSymbol') {
    Add-Line "PASS  V2.12 desk live DIR from Core"
  }
  else {
    Add-Line "FAIL  V2.12 live DIR wiring missing"
    $script:fail++
  }

  if ($coreText -match 'GsxCoreSortFillOrderByClassDiversity' -and
      $fleetText -match 'GsxFleetActiveInClass') {
    $symRoster = Join-Path $RepoRoot "Include\GSignalX\SymbolRoster.mqh"
    $symRosterText = if (Test-Path $symRoster) { Get-Content $symRoster -Raw } else { "" }
    if ($symRosterText -match 'GsxSymbolFamilyKey' -and $symRosterText -match 'XTIUSD') {
      Add-Line "PASS  V2.12 CMD/CR fleet diversity + oil/crypto alias resolve"
    }
    else {
      Add-Line "FAIL  V2.12 oil/crypto alias resolve missing"
      $script:fail++
    }
  }
  else {
    Add-Line "FAIL  V2.12 CMD/CR fill diversity missing"
    $script:fail++
  }

  if ($engText -match 'GsxEngStateDetach' -and $engText -match 'st\.symbol = symbol' -and
      $coreText -match 'engine symbol mismatch' -and $coreText -match 'GsxCoreEngOwnsSymbol') {
    Add-Line "PASS  V2.12 per-pair engine series (no chart DIR bleed)"
  }
  else {
    Add-Line "FAIL  V2.12 per-pair engine isolation missing"
    $script:fail++
  }

  if ($entryExText -match 'pre-bracket' -and $entryExText -match '2\.0 \* atr' -and
      $coreText -match 'GsxCoreCancelAllRosterPendings') {
    Add-Line "PASS  V2.10 anchor clamp + pending hygiene"
  }
  else {
    Add-Line "FAIL  V2.10 bracket/pending hygiene missing"
    $script:fail++
  }

  if ($storeText -match 'GSX_MS_DRILLSEC_' -and $rvmText -match 'drillSecLeft' -and
      ($qdText -match 'ST_DRILL' -or $msText -match 'ST_DRILL')) {
    Add-Line "PASS  V2.10 desk DRILL status chip"
  }
  else {
    Add-Line "FAIL  V2.10 desk DRILL chip missing"
    $script:fail++
  }

  # --- V2.12 desk runtime (Dashboard hosts Core) ---
  if ($dashText -match 'InpDeskExecute' -and $dashText -match 'GsxCoreInitEx' -and
      $dashText -match 'GsxCoreCycle' -and $dashText -match 'g_deskCoreActive') {
    Add-Line "PASS  V2.12 Dashboard DeskExecute hosts Core"
  }
  else {
    Add-Line "FAIL  V2.12 Dashboard Core host missing"
    $script:fail++
  }

  if ($coreText -match 'GsxCoreInitEx' -and $coreText -match 'g_coreHostTag' -and
      $fleetText -match 'GSX_SVC_HOST_' -and $fleetText -match 'GSX_HOST_DESK') {
    Add-Line "PASS  V2.12 Core host tag + OWN claim"
  }
  else {
    Add-Line "FAIL  V2.12 Core/Fleet host mutex missing"
    $script:fail++
  }

  if ($svcText -match 'InpYieldToDesk' -and $svcText -match 'GSX_HOST_DESK' -and
      $dashText -match 'DashServicePeerAlive') {
    Add-Line "PASS  V2.12 Desk vs Service yield mutual exclusion"
  }
  else {
    Add-Line "FAIL  V2.12 yield/mutex wiring missing"
    $script:fail++
  }

  if ($qdText -match 'splitRow' -and $qdText -match 'BTN_ADD') {
    Add-Line "PASS  V2.12 ADD button survives tight UR layout"
  }
  else {
    Add-Line "FAIL  V2.12 ADD layout guard missing"
    $script:fail++
  }

  # --- V2.13 desk risk UI + Service reliability ---
  $propRisk = Join-Path $RepoRoot "Include\GSignalX\PropRisk.mqh"
  $propText = if (Test-Path $propRisk) { Get-Content $propRisk -Raw } else { "" }
  $busIoV = Join-Path $RepoRoot "Include\GSignalX\BusIO.mqh"
  $busIoVText = if (Test-Path $busIoV) { Get-Content $busIoV -Raw } else { "" }

  if ($qdText -match 'BTN_EQ_0' -and $qdText -match 'BTN_EQ_5' -and
      $qdText -match 'BTN_EQ_10' -and $qdText -match 'BTN_EQ_20' -and
      $msText -match 'BTN_EQ_0') {
    Add-Line "PASS  V2.13 discrete EQ OFF/5/10/20 pads"
  }
  else {
    Add-Line "FAIL  V2.13 discrete EQ pads missing"
    $script:fail++
  }

  if ($qdText -match 'Prop peak DD' -and $qdText -match 'Account DD' -and
      $rvmText -match 'propPeakDdPct' -and $rvmText -match 'sessionWins' -and
      $propText -match 'GsxPropSessionOutcomes' -and $propText -match 'GsxPropPeakDdPct') {
    Add-Line "PASS  V2.13 Trade Info EQ guide + Prop peak DD + session outcomes"
  }
  else {
    Add-Line "FAIL  V2.13 Trade Info risk guidance missing"
    $script:fail++
  }

  if ($propText -match 'auto-clear when window ends' -and
      $propText -match 'FRIDAY' -and $propText -match 'NEWS') {
    Add-Line "PASS  V2.13 Friday/NEWS non-sticky Prop windows"
  }
  else {
    Add-Line "FAIL  V2.13 Friday/NEWS auto-clear missing"
    $script:fail++
  }

  if ($propText -match 'GsxPropGrantEquityGrace' -and $propText -match 'GsxPropClearLock' -and
      $propText -match 'recoverBelow' -and
      $dashText -match 'InpPropMaxEquityDdPct\s*=\s*0\.0' -and
      $qdText -match 'BTN_PROP_CLEAR') {
    Add-Line "PASS  V2.13.1 eased EQUITY_DD (default off + grace + PROP CLEAR)"
  }
  else {
    Add-Line "FAIL  V2.13.1 equity ease / PROP CLEAR missing"
    $script:fail++
  }

  if ($coreText -match 'GsxPropOnNewEntry' -and $coreText -match 'InpContinuousFleet' -and
      $coreText -match 'cycle_ms' -and $dashText -match 'InpContinuousFleet' -and
      $svcText -match 'InpContinuousFleet') {
    Add-Line "PASS  V2.13 Core PropOnNewEntry + continuous fleet + cycle_ms"
  }
  else {
    Add-Line "FAIL  V2.13 Core Prop count / continuous fleet missing"
    $script:fail++
  }

  if ($busIoVText -match 'GsxBusHeartbeatFreshFromSource' -and
      $busIoVText -match 'GSX_BUS_FRESHEST_CACHE_MAX' -and
      $busIoVText -match 'GsxBusFreshestCachePut' -and
      $svcText -match 'SvcDeskAliveNow' -and $svcText -match 'InpYieldConfirmTicks') {
    Add-Line "PASS  V2.13 host-scoped HB + per-canon bus cache + yield hysteresis"
  }
  else {
    Add-Line "FAIL  V2.13 HB/bus/yield reliability missing"
    $script:fail++
  }

  if ($qdText -match 'BTN_DRILL_REKICK' -and $msText -match 'BTN_DRILL_REKICK' -and
      $engText -match 'GsxEngPrefetchHistory') {
    Add-Line "PASS  V2.13 Drill REKICK + engine prefetch"
  }
  else {
    Add-Line "FAIL  V2.13 Drill REKICK / prefetch missing"
    $script:fail++
  }

  if ($coreText -match 'GsxCleanupOrphanPendings' -and $entryExText -match 'GsxCleanupOrphanPendings' -and
      $msText -match 'GsxMsCancelRosterPendings' -and $msText -match 'GsxMsSoftStopSymbol' -and
      $coreText -match 'g_onboardPending\[i\] = false' -and
      $storeText -match 'GsxRosterOnboardKickClear') {
    Add-Line "PASS  V2.13.2 stale-pair trigger lifetime (orphan pendings + STOP hygiene)"
  }
  else {
    Add-Line "FAIL  V2.13.2 trigger lifetime hygiene missing"
    $script:fail++
  }

  # --- V2.14 input sync + service reliability ---
  if ($storeText -match 'GsxRosterAutoLotSeed' -and $storeText -match 'GsxRosterEqGuardSeed' -and
      $dashText -match 'GsxRosterAutoLotSeed' -and $svcText -match 'GsxRosterAutoLotSeed' -and
      $dashText -notmatch 'GsxRosterAutoLotSet\(InpMagic,\s*InpAutoLotDefault\)' -and
      $svcText -notmatch 'GsxRosterAutoLotSet\(InpMagic,\s*InpAutoLotDefault\)') {
    Add-Line "PASS  V2.14 AUTOLOT seed-if-missing (no OnInit stomp)"
  }
  else {
    Add-Line "FAIL  V2.14 AUTOLOT seed-if-missing missing"
    $script:fail++
  }

  if ($chartText -match 'GsxRosterAutoLotGet' -and $chartText -match 'GsxRosterAutoLotSet' -and
      $chartText -match 'GsxRosterEqGuardGet' -and $chartText -match 'GsxRosterEqGuardSet') {
    Add-Line "PASS  V2.14 chart AutoLot/EQ bridge to desk GSX_MS_* GVs"
  }
  else {
    Add-Line "FAIL  V2.14 chart AutoLot/EQ desk bridge missing"
    $script:fail++
  }

  if ($entryExText -match 'no ATR sizing distance' -and
      $entryExText -match 'v2\.14 parity' -and
      $entryExText -match 'if\(atr > 0\.0\)') {
    Add-Line "PASS  V2.14 EntryExec AUTOLOT ATR sizing + AUTO->FIX signal"
  }
  else {
    Add-Line "FAIL  V2.14 EntryExec AUTOLOT sizing parity missing"
    $script:fail++
  }

  if ($svcText -match 'Core paused immediately' -and
      $dashText -match 'GsxSignalBusHeartbeat\(\"gsignalx-desk\"\)' -and
      $storeText -match 'do NOT force PLAY') {
    Add-Line "PASS  V2.14 instant Desk yield + ActivatePair preserves STOP"
  }
  else {
    Add-Line "FAIL  V2.14 yield/ActivatePair STOP preserve missing"
    $script:fail++
  }

  if ($coreText -match 'fillsDoneThisCycle' -and $coreText -match 'FillsPerCycle works') {
    Add-Line "PASS  V2.14 fleet multi-fill claim cooldown bypass"
  }
  else {
    Add-Line "FAIL  V2.14 fleet multi-fill claim missing"
    $script:fail++
  }

  if ($propText -match 'clear sticky day money' -and
      $sigBusText -match 'fridayStopHr' -and $sigBusText -match 'fridayStop &&') {
    Add-Line "PASS  V2.14 Prop day-rollover clear + SignalBus Friday hour"
  }
  else {
    Add-Line "FAIL  V2.14 Prop day clear / Friday hour missing"
    $script:fail++
  }

  if ($dashText -match 'version\s+"2\.15"' -and $svcText -match 'version\s+"2\.15"') {
    Add-Line "PASS  V2.15 host versions Dashboard/Service"
  }
  else {
    Add-Line "FAIL  V2.15 host version bump missing"
    $script:fail++
  }

  # --- V2.14.1 publish-as-ready + persistence/perf ---
  if ($coreText -match 'Publish-as-ready' -and
      $coreText -match 'GsxCorePublishBusIndex\(i, true\)' -and
      $coreText -match 'g_engBudgetCursor') {
    Add-Line "PASS  V2.14.1 RR publish-as-ready (PublishBusIndex after bar recalc)"
  }
  else {
    Add-Line "FAIL  V2.14.1 publish-as-ready missing"
    $script:fail++
  }

  if ($storeText -match 'GsxRosterStoreCacheTry' -and $storeText -match 'GsxRosterStoreCachePut' -and
      $storeText -match 'g_gsxRosterCacheSeq') {
    Add-Line "PASS  V2.14.1 RosterStore seq-gated in-memory cache"
  }
  else {
    Add-Line "FAIL  V2.14.1 RosterStore seq cache missing"
    $script:fail++
  }

  if ($coreText -match 'GsxCoreRefreshFleetSnap' -and $coreText -match 'g_coreFleetSnapFresh' -and
      $coreText -match 'GsxCoreEnsureFleetSnap' -and $coreText -match 'g_coreFleetSnap') {
    Add-Line "PASS  V2.14.1 cycle fleet snap reuse (PublishBus + fills)"
  }
  else {
    Add-Line "FAIL  V2.14.1 cycle fleet snap missing"
    $script:fail++
  }

  if ($rvmText -match 'GsxMsBuildFloatingPlMap' -and $rvmText -match 'GsxMsFloatingPlLookup' -and
      $rvmText -match 'floatingPlKnown') {
    Add-Line "PASS  V2.14.1 snapshot batched floating PL map"
  }
  else {
    Add-Line "FAIL  V2.14.1 snapshot PL batch missing"
    $script:fail++
  }

  if ($busIoText -match '<= 15' -and $busIoText -match 'GsxBusReadFreshestSignal' -and
      $busIoText -match 'skip peer tid scan') {
    Add-Line "PASS  V2.14.1 desk-mirror fast path age <=15s"
  }
  else {
    Add-Line "FAIL  V2.14.1 desk-mirror age guard missing"
    $script:fail++
  }

  # --- V2.15 Memory Scale ---
  $candle     = Join-Path $RepoRoot "Include\GSignalX\CandleMetrics.mqh"
  $candleText = if (Test-Path $candle) { Get-Content $candle -Raw } else { "" }
  $presetSmall  = Join-Path $RepoRoot "deploy\presets\GSignalX_Service_Scale_Small.set"
  $presetMedium = Join-Path $RepoRoot "deploy\presets\GSignalX_Service_Scale_Medium.set"
  $presetLarge  = Join-Path $RepoRoot "deploy\presets\GSignalX_Service_PropDesk_30.set"

  if ($fleetText -match 'GsxAccountBookBuild' -and $fleetText -match 'GsxAccountBookBusy' -and
      $coreText -match 'g_coreAccountBook' -and $coreText -match 'GsxAccountBookBuild\(InpMagic' -and
      $rvmText -match 'GsxAccountBookBuild\(magic' -and $rvmText -match 'GsxAccountBookBusy') {
    Add-Line "PASS  V2.15 AccountBook one-scan (Fleet + Core + RosterViewModel)"
  }
  else {
    Add-Line "FAIL  V2.15 AccountBook missing"
    $script:fail++
  }

  if ($engText -match 'GsxEngStateCompactTip' -and $engText -match 'lastSigOpen' -and
      $engText -match 'compacted' -and $coreText -match 'GsxEngStateCompactTip\(g_eng' -and
      $entryExText -match 'lastSigOpen' -and $entryExText -match 'GsxEngTipAtr') {
    Add-Line "PASS  V2.15 EngCompactTip + tip scalars (Core/Service)"
  }
  else {
    Add-Line "FAIL  V2.15 EngCompactTip missing"
    $script:fail++
  }

  if ($busIoText -match 'FileReadArray' -and $busIoText -match 'CharArrayToString' -and
      $busIoText -match 'FILE_BIN' -and
      $sigBusText -match 'writeTidPath' -and $sigBusText -match 'GsxBusDeskSignalPath' -and
      $coreText -match 'writeTid' -and $coreText -match 'fullSync \|\| \(g_busFp') {
    Add-Line "PASS  V2.15 BusReadSized + desk-mirror coalesce (tid on full-sync/first)"
  }
  else {
    Add-Line "FAIL  V2.15 bus I/O coalesce missing"
    $script:fail++
  }

  if ($candleText -match 'GsxAtrCachePrune' -and $candleText -match 'handle' -and
      $candleText -match 'IndicatorRelease' -and $candleText -match 'GSX_ATR_CACHE_MAX' -and
      $coreText -match 'GsxAtrCachePruneSymbol' -and $coreText -match 'GsxAtrCachePrune\(newRoster') {
    Add-Line "PASS  V2.15 AtrHandleReuse + prune on REM/roster"
  }
  else {
    Add-Line "FAIL  V2.15 ATR pool/prune missing"
    $script:fail++
  }

  if ($dashText -match 'InpScaleProfile' -and $svcText -match 'InpScaleProfile' -and
      $coreText -match 'GsxCoreScaleLookback' -and $coreText -match 'GsxCoreScaleCycleMs' -and
      (Test-Path $presetSmall) -and (Test-Path $presetMedium) -and (Test-Path $presetLarge)) {
    Add-Line "PASS  V2.15 Scale presets Small/Medium/Large + InpScaleProfile"
  }
  else {
    Add-Line "FAIL  V2.15 Scale profile/presets missing"
    $script:fail++
  }

  # --- Wheel page scroll (Trade Center + chart roster strip) ---
  $msPanelScroll = Join-Path $RepoRoot "Include\GSignalX\MultisymbolPanel.mqh"
  $dashScroll    = Join-Path $RepoRoot "GsignalX_Multisymbol_Dashboard.mq5"
  $chartScroll   = Join-Path $RepoRoot "GsignalX_GocityGroup.mq5"
  $msScrollText  = if (Test-Path $msPanelScroll) { Get-Content $msPanelScroll -Raw } else { "" }
  $dashScrollText = if (Test-Path $dashScroll) { Get-Content $dashScroll -Raw } else { "" }
  $chartScrollText = if (Test-Path $chartScroll) { Get-Content $chartScroll -Raw } else { "" }

  if ($msScrollText -match 'GsxMsPageStep' -and $msScrollText -match 'GsxMsPageCountFromCat' -and
      $msScrollText -match 'GsxMsHitTestPanel' -and $msScrollText -match 'CHARTEVENT_MOUSE_WHEEL') {
    Add-Line "PASS  MultisymbolPanel GsxMsPageStep + wheel hit-test"
  }
  else {
    Add-Line "FAIL  MultisymbolPanel wheel page scroll missing"
    $script:fail++
  }

  if ($msScrollText -match 'next >= pc' -and $msScrollText -match 'GsxMsTrimCompactRows') {
    Add-Line "PASS  MultisymbolPanel page clamp + compact CR trim"
  }
  else {
    Add-Line "FAIL  MultisymbolPanel page clamp / compact trim missing"
    $script:fail++
  }

  if ($dashScrollText -match 'CHART_EVENT_MOUSE_WHEEL' -and
      $chartScrollText -match 'CHART_EVENT_MOUSE_WHEEL' -and
      $chartScrollText -match 'CHARTEVENT_MOUSE_WHEEL') {
    Add-Line "PASS  Dashboard + Chart EA CHART_EVENT_MOUSE_WHEEL enable"
  }
  else {
    Add-Line "FAIL  Dashboard/Chart mouse-wheel enable missing"
    $script:fail++
  }

  # --- V2.15 CloseTrigger + Telegram close reason ---
  $ctPath   = Join-Path $RepoRoot "Include\GSignalX\CloseTrigger.mqh"
  $tgwPath  = Join-Path $RepoRoot "Include\GSignalX\TgDealWatch.mqh"
  $tgPath   = Join-Path $RepoRoot "Include\GSignalX\TelegramNotifier.mqh"
  $ctText   = if (Test-Path $ctPath) { Get-Content $ctPath -Raw } else { "" }
  $tgwText  = if (Test-Path $tgwPath) { Get-Content $tgwPath -Raw } else { "" }
  $tgText   = if (Test-Path $tgPath) { Get-Content $tgPath -Raw } else { "" }

  if ($ctText -match 'GsxCtEmit' -and $ctText -match 'GsxCtConsume' -and
      $ctText -match 'GsxCtResolveReason' -and $ctText -match 'BROKER-SL' -and
      $ctText -match 'events\.jsonl' -and $ctText -match 'GSX_CT_') {
    Add-Line "PASS  V2.15 CloseTrigger emit/consume + audit jsonl + BROKER-SL"
  }
  else {
    Add-Line "FAIL  V2.15 CloseTrigger module incomplete"
    $script:fail++
  }

  if ($psText -match 'GsxCtEmit' -and $psText -match 'CloseTrigger\.mqh' -and
      $psText -match 'InpUseMagicFilter=false with PS_SCOPE_ALL') {
    Add-Line "PASS  V2.15 Scouter CloseTicket emit + magic-filter WARN"
  }
  else {
    Add-Line "FAIL  V2.15 Scouter CloseTrigger wire / WARN missing"
    $script:fail++
  }

  if ($tgText -match 'GsxTgFormatCloseEx' -and $tgText -match 'reason=') {
    Add-Line "PASS  V2.15 GsxTgFormatCloseEx reason= field"
  }
  else {
    Add-Line "FAIL  V2.15 FormatCloseEx missing"
    $script:fail++
  }

  if ($tgwText -match 'GsxCtResolveEvent' -and $tgwText -match 'GsxTgFormatCloseFull' -and
      $tgwText -match 'HistorySelect' -and $tgwText -match 'CloseTrigger\.mqh') {
    Add-Line "PASS  V2.15 TgDealWatch consume-before-history + CloseEx"
  }
  else {
    Add-Line "FAIL  V2.15 TgDealWatch reason path missing"
    $script:fail++
  }

  if ($chartText -match 'GSX_CT_TAG_OVERFILL' -and $chartText -match 'GsxCtEmit' -and
      $chartText -match 'catastrophe SL attached') {
    Add-Line "PASS  V2.15 OVERFILL emit + catastrophe SL open log"
  }
  else {
    Add-Line "FAIL  V2.15 OVERFILL / SL-open log missing"
    $script:fail++
  }

  if ($entryText -match 'catastrophe SL' -and $entryText -match 'stratDec\.reason') {
    Add-Line "PASS  V2.15 EntryExec catastrophe SL open log"
  }
  else {
    Add-Line "FAIL  V2.15 EntryExec SL open log missing"
    $script:fail++
  }

  # --- V2.16 SettingsNotify Telegram ---
  $setPath  = Join-Path $RepoRoot "Include\GSignalX\SettingsNotify.mqh"
  $atrPath  = Join-Path $RepoRoot "Include\ProfitScouter\AtrTrail.mqh"
  $setText  = if (Test-Path $setPath) { Get-Content $setPath -Raw } else { "" }
  $atrSetText = if (Test-Path $atrPath) { Get-Content $atrPath -Raw } else { "" }
  $tgNText  = if (Test-Path $tgPath) { Get-Content $tgPath -Raw } else { "" }

  if ($setText -match 'GsxSettingsNotify' -and $setText -match 'GsxSettingsNotifyLoad' -and
      $setText -match 'GsxSettingsAnnounce' -and $setText -match 'GsxSettingsPendingSetScout' -and
      $setText -match 'GsxTgEnqueueTagged' -and $setText -match 'SETTINGS') {
    Add-Line "PASS  V2.16 SettingsNotify LOAD/Announce/pending + EnqueueTagged"
  }
  else {
    Add-Line "FAIL  V2.16 SettingsNotify module incomplete"
    $script:fail++
  }

  if ($tgNText -match 'GsxTgEnqueueTagged' -and $tgNText -match 'without draining') {
    Add-Line "PASS  V2.16 GsxTgEnqueueTagged (no drain on enqueue)"
  }
  else {
    Add-Line "FAIL  V2.16 EnqueueTagged missing"
    $script:fail++
  }

  if ($msText -match 'GsxMsSettingsClick' -and $msText -match 'GsxMsSettingsClick\("PLAY"\)' -and
      $msText -match 'GsxMsSettingsClick\("STOP"\)' -and $msText -match 'GsxMsSettingsClick\("HALT"\)' -and
      $msText -notmatch 'GsxMsSettingsClick\("PAGE') {
    Add-Line "PASS  V2.16 MultisymbolPanel prop-critical SETTINGS (no PAGE)"
  }
  else {
    Add-Line "FAIL  V2.16 MultisymbolPanel SETTINGS wiring missing"
    $script:fail++
  }

  if ($dashText -match 'GsxSettingsNotifyLoad' -and $dashText -match 'GsxSettingsDrainPending' -and
      $dashText -match 'GsxSettingsBindHost') {
    Add-Line "PASS  V2.16 Desk LOAD + drain pending"
  }
  else {
    Add-Line "FAIL  V2.16 Desk SettingsNotify wire missing"
    $script:fail++
  }

  if ($psText -match 'PsEmitSettingsPending' -and $psText -match 'GsxSettingsPendingSetScout' -and
      $atrSetText -match 'GsxSettingsPendingSetScout') {
    Add-Line "PASS  V2.16 Scouter arm pending (no HTTP)"
  }
  else {
    Add-Line "FAIL  V2.16 Scouter settings pending missing"
    $script:fail++
  }
}

switch ($Gate) {
  "Files"          { Confirm-Files }
  "Compile"        { Confirm-Compile }
  "Bus"            { Confirm-Bus }
  "Grades"         { Confirm-Grades }
  "LoserSafety"    { Confirm-LoserSafety }
  "ProdHardening"  { Confirm-ProdHardening }
  "Functional"     { Confirm-Functional }
  "All"     {
    Confirm-Files
    Confirm-Compile
    Confirm-LoserSafety
    Confirm-ProdHardening
    Confirm-Functional
    Confirm-Bus
    Confirm-Grades
  }
}

Add-Line ""
if ($fail -eq 0) {
  Add-Line "SUMMARY: PASS (0 hard failures; see WARN lines)"
}
else {
  Add-Line "SUMMARY: FAIL ($fail hard failure(s))"
}

if ($WriteFeedback) {
  $dir = Join-Path $RepoRoot "deploy\feedback"
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $name = "CONFIRM_{0}_{1}.md" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"), $Gate
  $out = Join-Path $dir $name
  @(
    "# Auto confirm report",
    "",
    "- Gate: $Gate",
    "- Terminal: $TerminalDataPath",
    "- When: $(Get-Date -Format o)",
    "- Hard failures: $fail",
    "",
    '```',
    ($lines -join "`n"),
    '```',
    ""
  ) | Set-Content -Path $out -Encoding UTF8
  Write-Host "Wrote feedback: $out" -ForegroundColor Green
}

if ($fail -gt 0) { exit 1 } else { exit 0 }
