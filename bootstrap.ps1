<#
.SYNOPSIS
    kickoff – Windows-11-Einstieg.
.DESCRIPTION
    irm https://raw.githubusercontent.com/leonkoellerwirth-arch/init-ai-workspace/main/bootstrap.ps1 | iex
    Mit Flags:  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/leonkoellerwirth-arch/init-ai-workspace/main/bootstrap.ps1))) -DryRun
.PARAMETER DryRun
    Nur anzeigen, nichts ausführen.
.PARAMETER Only
    Nur diese Schritte (z. B. 30 oder 30-git).
.PARAMETER Skip
    Diese Schritte auslassen.
.PARAMETER NonInteractive
    Keine Prompts; Name/E-Mail aus KICKOFF_GIT_NAME / KICKOFF_GIT_EMAIL, Auth wird übersprungen.
.PARAMETER Doctor
    Nur den Statusreport.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [string[]]$Only = @(),
    [string[]]$Skip = @(),
    [switch]$NonInteractive,
    [switch]$Doctor
)

$KickoffRepo = 'leonkoellerwirth-arch/init-ai-workspace'
if ($env:KICKOFF_REPO) { $KickoffRepo = $env:KICKOFF_REPO }
$KickoffRef = 'main'
if ($env:KICKOFF_REF) { $KickoffRef = $env:KICKOFF_REF }

# ---------------------------------------------------------------------------
# Pipe-Modus (irm | iex): ohne lokale Kopie das Repo als ZIP holen und von dort neu starten.
# Unter iex läuft dieser Code im Scope der Nutzer-Session: deshalb kein `exit` (schlösse das
# Fenster) und StrictMode/ErrorActionPreference nur in einem eigenen Scriptblock-Scope setzen.
# ---------------------------------------------------------------------------
$KickoffRoot = $null
if ($PSCommandPath) { $KickoffRoot = Split-Path -Parent $PSCommandPath }

if (-not $KickoffRoot -or -not (Test-Path (Join-Path $KickoffRoot 'lib/common.ps1'))) {
    & {
        $ErrorActionPreference = 'Stop'
        $kickoffHome = Join-Path $HOME '.kickoff'
        if ($env:KICKOFF_HOME) { $kickoffHome = $env:KICKOFF_HOME }
        $src = Join-Path $kickoffHome 'src'
        [Console]::Out.WriteLine("➜ Lade kickoff ($KickoffRepo@$KickoffRef) nach $src")
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("kickoff-" + [guid]::NewGuid().ToString('N'))
        [void](New-Item -ItemType Directory -Path $tmp -Force)
        $zip = Join-Path $tmp 'src.zip'
        Invoke-WebRequest -UseBasicParsing -Uri "https://codeload.github.com/$KickoffRepo/zip/$KickoffRef" -OutFile $zip
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        $extracted = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
        if (Test-Path $src) { Remove-Item -Path $src -Recurse -Force }
        [void](New-Item -ItemType Directory -Path (Split-Path $src -Parent) -Force)
        Move-Item -Path $extracted.FullName -Destination $src
        Remove-Item -Path $tmp -Recurse -Force

        $forward = @()
        if ($DryRun) { $forward += '-DryRun' }
        if ($NonInteractive) { $forward += '-NonInteractive' }
        if ($Doctor) { $forward += '-Doctor' }
        if ($Only.Count -gt 0) { $forward += '-Only'; $forward += ($Only -join ',') }
        if ($Skip.Count -gt 0) { $forward += '-Skip'; $forward += ($Skip -join ',') }
        $hostExe = (Get-Process -Id $PID).Path
        & $hostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $src 'bootstrap.ps1') @forward
    }
    return
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# $env: bleibt in der aufrufenden Session stehen – Laufzustand daher jedes Mal neu setzen.
foreach ($name in @('KICKOFF_TS', 'KICKOFF_LOG')) { Remove-Item -Path "env:$name" -ErrorAction SilentlyContinue }
$env:KICKOFF_DRY_RUN = '0'
if ($DryRun) { $env:KICKOFF_DRY_RUN = '1' }
$env:KICKOFF_NON_INTERACTIVE = '0'
if ($NonInteractive) { $env:KICKOFF_NON_INTERACTIVE = '1' }

. (Join-Path $KickoffRoot 'lib/common.ps1')

# -File übergibt "-Only 10,30" als einen String – hier wieder aufteilen.
$Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$Skip = @($Skip | ForEach-Object { $_ -split ',' } | Where-Object { $_ })

# Test-StepMatch <step-name> <muster> – Muster: "30", "30-git" oder "30-git.ps1"
function Test-StepMatch {
    param([string]$Name, [string[]]$Pattern)
    foreach ($p in $Pattern) {
        $p = $p -replace '\.ps1$', ''
        if ($p -eq $Name -or $p -eq ($Name -split '-', 2)[0]) { return $true }
    }
    return $false
}

function Invoke-Doctor {
    $doctorPath = Join-Path $KickoffRoot 'doctor.ps1'
    if (Test-Path $doctorPath) {
        & $doctorPath | Out-Host
        return $LASTEXITCODE
    }
    Write-KWarn 'doctor ist noch nicht implementiert.'
    return 0
}

# ---------------------------------------------------------------------------
# Ablauf
# ---------------------------------------------------------------------------
$exitCode = 0
$retry = 'Log prüfen, Ursache beheben und denselben Befehl erneut starten – fertige Schritte werden übersprungen.'
Initialize-KDirectory
if ($Doctor) { exit (Invoke-Doctor) }

try {
    if ($env:OS -ne 'Windows_NT' -and -not (Test-KDryRun)) {
        Write-KFail 'bootstrap.ps1 unterstützt in v1 nur Windows 11.' 'Unter macOS bootstrap.sh verwenden.'
    }

    Write-KInfo "kickoff – Log: $($env:KICKOFF_LOG)"
    if (Test-KDryRun) { Write-KInfo 'Dry-Run: es wird nichts verändert.' }

    $totalStart = Get-Date
    $stepDir = Join-Path $KickoffRoot 'steps'
    $stepFiles = @(Get-ChildItem -Path $stepDir -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d\d-' } | Sort-Object Name)
    if ($stepFiles.Count -eq 0) { Write-KWarn "Keine Schritte gefunden in $stepDir." }

    foreach ($stepFile in $stepFiles) {
        $name = $stepFile.BaseName
        if ($Only.Count -gt 0 -and -not (Test-StepMatch $name $Only)) { continue }
        if ($Skip.Count -gt 0 -and (Test-StepMatch $name $Skip)) { continue }

        Enter-KStep $name
        . $stepFile.FullName
        Exit-KStep
    }

    $script:KickoffStep = 'doctor'
    $doctorRc = 0
    if (Test-KDryRun) {
        Write-KInfo '[dry-run] doctor wird nach einem echten Lauf ausgeführt.'
    } else {
        $doctorRc = Invoke-Doctor
    }

    Write-KTiming ([int]((Get-Date) - $totalStart).TotalSeconds)
    $exitCode = $doctorRc
} catch [KickoffExitException] {
    $exitCode = $_.Exception.ExitCode
} catch [KickoffCommandException] {
    $ex = $_.Exception
    Write-KLogFile "FAIL  exit=$($ex.ExitCode) cmd=$($ex.Command)"
    Write-KConsole "✘ [$($script:KickoffStep)] $($ex.Message)" -ToError
    Write-KConsole "  Nächster Schritt: $retry" -ToError
    Write-KConsole "  Log: $($env:KICKOFF_LOG)" -ToError
    $exitCode = 1
} catch {
    Write-KLogFile "FAIL  $($_.Exception.Message) @ $($_.InvocationInfo.PositionMessage)"
    Write-KConsole "✘ [$($script:KickoffStep)] $($_.Exception.Message)" -ToError
    Write-KConsole "  Nächster Schritt: $retry" -ToError
    Write-KConsole "  Log: $($env:KICKOFF_LOG)" -ToError
    $exitCode = 1
}
exit $exitCode
