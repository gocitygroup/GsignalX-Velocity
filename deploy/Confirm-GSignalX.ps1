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
  [ValidateSet("Files", "Compile", "Bus", "Grades", "LoserSafety", "All")]
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
}

function Confirm-Files {
  Add-Line "=== GATE Files ==="
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\BusIO.mqh") "Include GSignalX\BusIO.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\OpportunityGrade.mqh") "Include GSignalX\OpportunityGrade.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\LotSizing.mqh") "Include GSignalX\LotSizing.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\GSignalX\ChartPanel.mqh") "Include GSignalX\ChartPanel.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Include\ProfitScouter\Core.mqh") "Include ProfitScouter\Core.mqh" | Out-Null
  Test-PathMark (Join-Path $mql5 "Experts\GsignalX_GocityGroup.mq5") "Experts GsignalX" | Out-Null
  Test-PathMark (Join-Path $mql5 "Experts\ProfitScouter_DollarTarget.mq5") "Experts ProfitScouter EA" | Out-Null
  Test-PathMark (Join-Path $mql5 "Services\ProfitScouter_Service.mq5") "Services ProfitScouter" | Out-Null
  Test-PathMark (Join-Path $mql5 "Services\ProfitOpportunity_Grader.mq5") "Services Grader" | Out-Null
  Test-PathMark (Join-Path $mql5 "Scripts\ProfitHarvest_Now.mq5") "Scripts Harvest" | Out-Null
}

function Confirm-Compile {
  Add-Line "=== GATE Compile ==="
  $ex5 = @(
    "Experts\GsignalX_GocityGroup.ex5",
    "Experts\ProfitScouter_DollarTarget.ex5",
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

function Confirm-Bus {
  Add-Line "=== GATE Bus ==="
  Test-PathMark $busRoot "bus root" | Out-Null
  $index = Join-Path $busRoot "terminals\_index.txt"
  if (Test-PathMark $index "terminals\_index.txt") {
    $tids = @(Get-Content $index | Where-Object { $_.Trim() -ne "" })
    Add-Line ("INFO  indexed tids: {0}" -f $tids.Count)
    foreach ($tid in $tids) {
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
  "Files"        { Confirm-Files }
  "Compile"      { Confirm-Compile }
  "Bus"          { Confirm-Bus }
  "Grades"       { Confirm-Grades }
  "LoserSafety"  { Confirm-LoserSafety }
  "All"     {
    Confirm-Files
    Confirm-Compile
    Confirm-LoserSafety
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
