<#
.SYNOPSIS
  Remove previous GSignalX toolkit installs from MT5 terminal data folder(s).

.EXAMPLE
  .\Clean-GSignalX.ps1 -ListTerminals

.EXAMPLE
  .\Clean-GSignalX.ps1 -AllTerminals -CleanBus

.EXAMPLE
  .\Clean-GSignalX.ps1 -TerminalDataPath "$env:APPDATA\MetaQuotes\Terminal\<HASH>" -CleanBus
#>
[CmdletBinding(DefaultParameterSetName = "One")]
param(
  [Parameter(ParameterSetName = "One")]
  [string] $TerminalDataPath,

  [Parameter(ParameterSetName = "All")]
  [switch] $AllTerminals,

  [Parameter(ParameterSetName = "List")]
  [switch] $ListTerminals,

  [switch] $CleanBus,

  [string] $RepoRoot = ""
)

$ErrorActionPreference = "Continue"
$script:removed = 0
$script:missing = 0
$script:errors = 0

if (-not $RepoRoot) {
  $RepoRoot = Split-Path -Parent $PSScriptRoot
}

function Get-Mt5TerminalDataFolders {
  $root = Join-Path $env:APPDATA "MetaQuotes\Terminal"
  if (-not (Test-Path $root)) { return @() }
  Get-ChildItem $root -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName "MQL5") } |
    ForEach-Object { $_.FullName }
}

function Remove-PathSafe([string] $path) {
  if (-not (Test-Path -LiteralPath $path)) {
    Write-Host "  - (missing) $path"
    $script:missing++
    return
  }
  try {
    Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
    Write-Host "  - removed $path"
    $script:removed++
  }
  catch {
    Write-Host "  ! FAILED $path : $($_.Exception.Message)" -ForegroundColor Red
    $script:errors++
  }
}

function Clean-Terminal([string] $dataPath) {
  $mql5 = Join-Path $dataPath "MQL5"
  if (-not (Test-Path $mql5)) {
    Write-Host "  ! No MQL5 under $dataPath" -ForegroundColor Red
    $script:errors++
    return
  }

  $files = @(
    "Experts\GsignalX_GocityGroup.mq5",
    "Experts\GsignalX_GocityGroup.ex5",
    "Experts\GsignalX_GocityGroup.log",
    "Experts\ProfitScouter_DollarTarget.mq5",
    "Experts\ProfitScouter_DollarTarget.ex5",
    "Experts\ProfitScouter_DollarTarget.log",
    "Services\ProfitScouter_Service.mq5",
    "Services\ProfitScouter_Service.ex5",
    "Services\ProfitScouter_Service.log",
    "Services\ProfitOpportunity_Grader.mq5",
    "Services\ProfitOpportunity_Grader.ex5",
    "Services\ProfitOpportunity_Grader.log",
    "Scripts\ProfitHarvest_Now.mq5",
    "Scripts\ProfitHarvest_Now.ex5",
    "Scripts\ProfitHarvest_Now.log"
  )
  foreach ($rel in $files) {
    Remove-PathSafe (Join-Path $mql5 $rel)
  }

  Remove-PathSafe (Join-Path $mql5 "Include\GSignalX")
  Remove-PathSafe (Join-Path $mql5 "Include\ProfitScouter")
}

function Clean-BusTree {
  $bus = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\GSignalX\bus\v1"
  Write-Host "`nCleaning Common Files bus: $bus"
  if (Test-Path $bus) {
    Remove-PathSafe $bus
  }
  else {
    Write-Host "  - (missing) bus root"
    $script:missing++
  }
  # Also remove empty parent GSignalX folders if present
  $gsx = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\GSignalX"
  if ((Test-Path $gsx) -and -not (Get-ChildItem $gsx -Force -ErrorAction SilentlyContinue)) {
    Remove-PathSafe $gsx
  }
}

if ($ListTerminals) {
  $folders = @(Get-Mt5TerminalDataFolders)
  if ($folders.Count -eq 0) {
    Write-Host "No MT5 terminal data folders found under %APPDATA%\MetaQuotes\Terminal"
  }
  else {
    Write-Host "MT5 terminal data folders:"
    $folders | ForEach-Object { Write-Host "  $_" }
  }
  exit 0
}

$targets = @()
if ($AllTerminals) {
  $targets = @(Get-Mt5TerminalDataFolders)
  if ($targets.Count -eq 0) { throw "No terminals found. Use -ListTerminals or pass -TerminalDataPath." }
}
elseif ($TerminalDataPath) {
  $targets = @($TerminalDataPath)
}
else {
  throw "Specify -TerminalDataPath, -AllTerminals, or -ListTerminals."
}

Write-Host "GSignalX Clean  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "CleanBus=$CleanBus"
Write-Host ""

foreach ($td in $targets) {
  Write-Host "=== $td ===" -ForegroundColor Cyan
  Clean-Terminal $td
}

if ($CleanBus) {
  Clean-BusTree
}

Write-Host ""
Write-Host ("SUMMARY: removed={0} missing={1} errors={2}" -f $script:removed, $script:missing, $script:errors)
if ($script:errors -gt 0) {
  Write-Host "Clean finished with errors (files may be locked - stop MT5 Services/EA and retry)." -ForegroundColor Yellow
  exit 1
}
Write-Host "Clean OK." -ForegroundColor Green
exit 0
