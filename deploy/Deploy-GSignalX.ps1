<#
.SYNOPSIS
  Deploy GSignalX MQL5 toolkit (Includes + Experts/Services/Scripts) into MT5 terminal data folder(s).

.EXAMPLE
  .\Deploy-GSignalX.ps1 -ListTerminals

.EXAMPLE
  .\Deploy-GSignalX.ps1 -TerminalDataPath "$env:APPDATA\MetaQuotes\Terminal\010E047102812FC0C18890992854220E"

.EXAMPLE
  .\Deploy-GSignalX.ps1 -AllTerminals -Compile -MetaEditorPath "C:\Program Files\MetaTrader 5 IC Markets Global\MetaEditor64.exe"
#>
[CmdletBinding(DefaultParameterSetName = "One")]
param(
  [Parameter(ParameterSetName = "One")]
  [string] $TerminalDataPath,

  [Parameter(ParameterSetName = "All")]
  [switch] $AllTerminals,

  [Parameter(ParameterSetName = "List")]
  [switch] $ListTerminals,

  [switch] $Compile,

  [string] $MetaEditorPath = "",

  [string] $RepoRoot = ""
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot) {
  $RepoRoot = Split-Path -Parent $PSScriptRoot
}
if (-not (Test-Path (Join-Path $RepoRoot "Include\GSignalX"))) {
  throw "RepoRoot does not look like the toolkit root (missing Include\GSignalX): $RepoRoot"
}

function Get-Mt5TerminalDataFolders {
  $root = Join-Path $env:APPDATA "MetaQuotes\Terminal"
  if (-not (Test-Path $root)) { return @() }
  Get-ChildItem $root -Directory |
    Where-Object { Test-Path (Join-Path $_.FullName "MQL5") } |
    ForEach-Object { $_.FullName }
}

function Deploy-ToTerminal([string] $dataPath) {
  $mql5 = Join-Path $dataPath "MQL5"
  if (-not (Test-Path $mql5)) {
    throw "No MQL5 folder under: $dataPath"
  }

  $includePairs = @(
    @{ Src = "Include\GSignalX";      Dst = "Include\GSignalX" },
    @{ Src = "Include\ProfitScouter"; Dst = "Include\ProfitScouter" }
  )
  foreach ($pair in $includePairs) {
    $dstDir = Join-Path $mql5 $pair.Dst
    New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
    Copy-Item (Join-Path $RepoRoot ($pair.Src + "\*.mqh")) $dstDir -Force
    Write-Host ("  + {0}\ (*.mqh)" -f $pair.Dst)
  }

  $fileMap = @(
    @{ Rel = "Experts";  Name = "GsignalX_GocityGroup.mq5" },
    @{ Rel = "Experts";  Name = "GsignalX_Multisymbol_Dashboard.mq5" },
    @{ Rel = "Experts";  Name = "ProfitScouter_DollarTarget.mq5" },
    @{ Rel = "Services"; Name = "GsignalX_Service.mq5" },
    @{ Rel = "Services"; Name = "ProfitScouter_Service.mq5" },
    @{ Rel = "Services"; Name = "ProfitOpportunity_Grader.mq5" },
    @{ Rel = "Scripts";  Name = "ProfitHarvest_Now.mq5" }
  )
  foreach ($item in $fileMap) {
    $dstDir = Join-Path $mql5 $item.Rel
    New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
    $from = Join-Path $RepoRoot $item.Name
    if (-not (Test-Path $from)) { throw "Missing source file: $from" }
    Copy-Item $from (Join-Path $dstDir $item.Name) -Force
    Write-Host ("  + {0}\{1}" -f $item.Rel, $item.Name)
  }

  Write-Host "Deployed to $mql5" -ForegroundColor Green
  return $mql5
}

function Compile-Toolkit([string] $mql5, [string] $editor) {
  if (-not (Test-Path $editor)) {
    throw "MetaEditor not found: $editor"
  }

  $order = @(
    "Services\ProfitScouter_Service.mq5",
    "Experts\ProfitScouter_DollarTarget.mq5",
    "Services\ProfitOpportunity_Grader.mq5",
    "Services\GsignalX_Service.mq5",
    "Experts\GsignalX_Multisymbol_Dashboard.mq5",
    "Experts\GsignalX_GocityGroup.mq5",
    "Scripts\ProfitHarvest_Now.mq5"
  )

  foreach ($rel in $order) {
    $file = Join-Path $mql5 $rel
    Write-Host "Compiling $rel ..."
    & $editor /compile:"$file" /log | Out-Null
    Start-Sleep -Seconds 2
    $log = [System.IO.Path]::ChangeExtension($file, ".log")
    if (Test-Path $log) {
      $result = Select-String -Path $log -Pattern "^Result:" | Select-Object -Last 1
      if ($result) {
        Write-Host "  $($result.Line)"
        if ($result.Line -notmatch "0 errors") {
          Write-Host "  FAILED - see $log" -ForegroundColor Red
        }
      }
      else {
        Write-Host "  (no Result line yet - open $log)" -ForegroundColor Yellow
      }
    }
    else {
      Write-Host "  (no log written)" -ForegroundColor Yellow
    }
  }
}

function Find-DefaultMetaEditor {
  $candidates = @(
    (Join-Path $env:ProgramFiles "MetaTrader 5\MetaEditor64.exe"),
    (Join-Path $env:ProgramFiles "MetaTrader 5 IC Markets Global\MetaEditor64.exe")
  )
  $pf86 = ${env:ProgramFiles(x86)}
  if ($pf86) {
    $candidates += (Join-Path $pf86 "MetaTrader 5\MetaEditor64.exe")
  }
  foreach ($c in $candidates) {
    if ($c -and (Test-Path $c)) { return $c }
  }
  $hit = Get-ChildItem $env:ProgramFiles -Filter "MetaEditor64.exe" -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
  return $hit
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
  throw "Specify -TerminalDataPath, -AllTerminals, or -ListTerminals. See DEPLOYMENT.md."
}

if ($Compile -and -not $MetaEditorPath) {
  $MetaEditorPath = Find-DefaultMetaEditor
  if (-not $MetaEditorPath) {
    throw "Could not find MetaEditor64.exe. Pass -MetaEditorPath."
  }
  Write-Host "Using MetaEditor: $MetaEditorPath"
}

foreach ($td in $targets) {
  Write-Host "`n=== $td ===" -ForegroundColor Cyan
  $mql5 = Deploy-ToTerminal $td
  if ($Compile) {
    Compile-Toolkit $mql5 $MetaEditorPath
  }
}

Write-Host "`nDone. Next: enable Algo Trading, start Services, attach Trade Center." -ForegroundColor Green
Write-Host "Non-tech guide: docs\WINDOWS_DEPLOY_SIMPLE.md"
Write-Host "Full detail: DEPLOYMENT.md"
