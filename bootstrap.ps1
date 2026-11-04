<#
.SYNOPSIS
    kickoff - Windows-11-Einstieg.
.DESCRIPTION
    irm https://raw.githubusercontent.com/leonkoellerwirth-arch/init-ai-workspace/main/bootstrap.ps1 | iex
    Mit Flags:  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/leonkoellerwirth-arch/init-ai-workspace/main/bootstrap.ps1))) -DryRun

    Diese Datei ist bewusst reines ASCII ohne BOM: `irm | iex` liefert ein BOM als Zeichen U+FEFF
    mit, an dem der Parser scheitert; ohne BOM liest Windows PowerShell 5.1 aber Nicht-ASCII falsch.
    Alle Texte mit Umlauten/Symbolen stehen deshalb in lib/common.ps1 (mit BOM, von der Platte geladen).
.PARAMETER DryRun
    Nur anzeigen, nichts ausfuehren.
.PARAMETER Only
    Nur diese Schritte (z. B. 30 oder 30-git).
.PARAMETER Skip
    Diese Schritte auslassen.
.PARAMETER NonInteractive
    Keine Prompts; Name/E-Mail aus KICKOFF_GIT_NAME / KICKOFF_GIT_EMAIL, Auth wird uebersprungen.
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

# Fruehe Versionspruefung mit Syntax, die auch alte PowerShell-Versionen noch verstehen,
# damit dort eine klare Meldung statt eines Parserfehlers erscheint.
if ($PSVersionTable.PSVersion.Major -lt 5 -or ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -lt 1)) {
    $ae = [char]0x00E4; $oe = [char]0x00F6; $ue = [char]0x00FC; $cross = [char]0x2718; $arrow = [char]0x2192
    [Console]::Error.WriteLine("$cross kickoff braucht mindestens Windows PowerShell 5.1 (gefunden: $($PSVersionTable.PSVersion)).")
    [Console]::Error.WriteLine("  $arrow Windows 11 enth${ae}lt sie: im Startmen$ue `"Windows PowerShell`" ${oe}ffnen und den Befehl dort erneut ausf${ue}hren.")
    return
}

$KickoffRepo = 'leonkoellerwirth-arch/init-ai-workspace'
if ($env:KICKOFF_REPO) { $KickoffRepo = $env:KICKOFF_REPO }
$KickoffRef = 'main'
if ($env:KICKOFF_REF) { $KickoffRef = $env:KICKOFF_REF }

# ---------------------------------------------------------------------------
# Pipe-Modus (irm | iex): ohne lokale Kopie das Repo als ZIP holen und von dort neu starten.
# Unter iex laeuft dieser Code im Scope der Nutzer-Session: deshalb kein `exit` (schloesse das
# Fenster) und ErrorActionPreference nur in einem eigenen Scriptblock-Scope setzen.
# ---------------------------------------------------------------------------
$KickoffRoot = $null
if ($PSCommandPath) { $KickoffRoot = Split-Path -Parent $PSCommandPath }

if (-not $KickoffRoot -or -not (Test-Path (Join-Path $KickoffRoot 'lib/common.ps1'))) {
    & {
        $ErrorActionPreference = 'Stop'
        $kickoffHome = Join-Path $HOME '.kickoff'
        if ($env:KICKOFF_HOME) { $kickoffHome = $env:KICKOFF_HOME }
        $src = Join-Path $kickoffHome 'src'
        [Console]::Out.WriteLine("$([char]0x279C) Lade kickoff ($KickoffRepo@$KickoffRef) nach $src")
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

# $env: bleibt in der aufrufenden Session stehen - Laufzustand daher jedes Mal neu setzen.
foreach ($name in @('KICKOFF_TS', 'KICKOFF_LOG')) { Remove-Item -Path "env:$name" -ErrorAction SilentlyContinue }
$env:KICKOFF_DRY_RUN = '0'
if ($DryRun) { $env:KICKOFF_DRY_RUN = '1' }
$env:KICKOFF_NON_INTERACTIVE = '0'
if ($NonInteractive) { $env:KICKOFF_NON_INTERACTIVE = '1' }

. (Join-Path $KickoffRoot 'lib/common.ps1')

# Out-Host: versehentliche Pipeline-Ausgaben aus Steps erscheinen am Bildschirm statt verloren zu gehen.
Invoke-KBootstrap -Only $Only -Skip $Skip -DoctorOnly:$Doctor | Out-Host
exit $script:KickoffExitCode
