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
  [ValidateSet("Files", "Compile", "Bus", "Grades", "LoserSafety", "ProdHardening", "All")]
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
  $gsxText  = if (Test-Path $gsx)  { Get-Content $gsx  -Raw } else { "" }
  $svcText  = if (Test-Path $svc)  { Get-Content $svc  -Raw } else { "" }
  $eaText   = if (Test-Path $ea)   { Get-Content $ea   -Raw } else { "" }
  $harvText = if (Test-Path $harv) { Get-Content $harv -Raw } else { "" }

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

  if ($svcText -match 'InpAdverseMinAgeMin' -and $eaText -match 'InpAdverseMinAgeMin') {
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

  if ($tgText -match 'WebRequest' -and $tgText -match 'GsxTgVerifyConnection' -and $tgText -match 'GSX_TG_QUEUE_CAP') {
    Add-Line "PASS  TelegramNotifier WebRequest + verify + queue"
  }
  else {
    Add-Line "FAIL  TelegramNotifier incomplete"
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

  if ($dashText -match 'InpTgBotToken' -and $dashText -match 'InpPropEnable' -and $dashText -match '#property\s+version\s+"2\.00"') {
    Add-Line "PASS  Dashboard 2.00 Telegram + Prop inputs"
  }
  else {
    Add-Line "FAIL  Dashboard 2.00 wiring / version missing"
    $script:fail++
  }

  if ($msPanelText -match 'GSXMS_WIDTH\s+640' -and $msPanelText -match 'GSXMS_BTN_H\s+28') {
    Add-Line "PASS  Trade Center button sizing 640/28"
  }
  else {
    Add-Line "FAIL  Trade Center sizing not updated (expect 640/28)"
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

  if ($dashText -match 'InpEvtCalendarEnable' -and $dashText -match 'GsxEventGatePoll' -and $dashText -match 'v1\.26') {
    Add-Line "PASS  Dashboard EventGate + v1.26 wiring"
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
    if ($t -match '#property\s+version\s+"2\.00"') {
      $verOk++
    }
    else {
      Add-Line ("FAIL  {0} missing #property version `"2.00`"" -f $h.Label)
      $script:fail++
    }
  }
  if ($verOk -eq $hosts200.Count) {
    Add-Line "PASS  Velocity 2.00 host versions (6/6)"
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
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\Engines.mqh") "Include GSignalX\Engines.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\Core.mqh") "Include GSignalX\Core.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\EntryExec.mqh") "Include GSignalX\EntryExec.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\RosterStore.mqh") "Include GSignalX\RosterStore.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\MultisymbolPanel.mqh") "Include GSignalX\MultisymbolPanel.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\RosterViewModel.mqh") "Include GSignalX\RosterViewModel.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\ProfitScouter\Core.mqh") "Include ProfitScouter\Core.mqh" | Out-Null
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

  if ($dashText -match 'InpRefreshMs\s*=\s*1000' -and $dashText -match 'g_lastSnapFp' -and $dashText -match 'GsxTgProcessQueueEx') {
    Add-Line "PASS  Dashboard cadence 1000ms + dirty redraw + TG budget"
  }
  else {
    Add-Line "FAIL  Dashboard v2.01 cadence/dirty redraw missing"
    $script:fail++
  }

  if ($panelText -match 'GsxMsPanelApplyAdaptive' -and $panelText -match 'signalStale') {
    Add-Line "PASS  Trade Center adaptive layout + STALE rows"
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
  Test-PathMark $busRoot "bus root" | Out-Null
  $index = Join-Path $busRoot "terminals\_index.txt"
  $tidList = @()
  if (Test-PathMark $index "terminals\_index.txt") {
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
        Add-Line "FAIL  missing heartbeat for $tid"
        $script:fail++
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
  if (-not (Test-PathMark $grades "grades\latest.json")) { return }
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

switch ($Gate) {
  "Files"          { Confirm-Files }
  "Compile"        { Confirm-Compile }
  "Bus"            { Confirm-Bus }
  "Grades"         { Confirm-Grades }
  "LoserSafety"    { Confirm-LoserSafety }
  "ProdHardening"  { Confirm-ProdHardening }
  "All"     {
    Confirm-Files
    Confirm-Compile
    Confirm-LoserSafety
    Confirm-ProdHardening
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
