# lib/common.ps1 – gemeinsame Helfer für bootstrap.ps1, steps/*.ps1 und doctor.ps1.
#
# Baseline: Windows PowerShell 5.1, ohne Admin. Kein `??`, kein Ternary, keine PS7-only-Cmdlets.
# Datei muss UTF-8 mit BOM bleiben, sonst liest 5.1 die Umlaute/Symbole als ANSI.
#
# Konventionen für Steps (Spiegel von lib/common.sh):
#   - Jeder ändernde Befehl läuft über Invoke-KRun (oder Invoke-KRunVisible für Logins/Prompts).
#     Im Dry-Run wird er nur geplant und als "[dry-run] …" ausgegeben.
#   - Invoke-KRun ist für native Programme (winget, git, code …): es prüft $LASTEXITCODE, denn
#     $ErrorActionPreference greift bei nativen Exit-Codes nicht. PowerShell-Logik direkt aufrufen.
#   - Ist-Zustand zuerst prüfen; danach Write-KOk "… bereits vorhanden" oder Write-KDoing "… wird installiert".
#   - Bestehende Nutzerdateien vor jeder Änderung mit Backup-KFile sichern.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { Write-Verbose 'Konsole ohne UTF-8-Umschaltung.' }

# ---------------------------------------------------------------------------
# Zustand
# ---------------------------------------------------------------------------
if (-not $env:KICKOFF_HOME) { $env:KICKOFF_HOME = Join-Path $HOME '.kickoff' }
if (-not $env:KICKOFF_TS) { $env:KICKOFF_TS = Get-Date -Format 'yyyyMMdd-HHmmss' }
$script:KickoffLogDir = Join-Path $env:KICKOFF_HOME 'logs'
$script:KickoffStateDir = Join-Path $env:KICKOFF_HOME 'state'
$script:KickoffBackupDir = Join-Path (Join-Path $env:KICKOFF_HOME 'backups') $env:KICKOFF_TS
if (-not $env:KICKOFF_LOG) { $env:KICKOFF_LOG = Join-Path $script:KickoffLogDir "$($env:KICKOFF_TS).log" }
if (-not $env:KICKOFF_DRY_RUN) { $env:KICKOFF_DRY_RUN = '0' }
if (-not $env:KICKOFF_NON_INTERACTIVE) { $env:KICKOFF_NON_INTERACTIVE = '0' }
$script:KickoffStep = 'bootstrap'
$script:KickoffStepStart = Get-Date
$script:KickoffTiming = New-Object System.Collections.ArrayList

function Initialize-KDirectory {
    foreach ($dir in @($script:KickoffLogDir, $script:KickoffStateDir)) {
        if (-not (Test-Path $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    }
    if (-not (Test-Path $env:KICKOFF_LOG)) { [void](New-Item -ItemType File -Path $env:KICKOFF_LOG -Force) }
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
function Hide-KSecret {
    param([Parameter(ValueFromPipeline = $true)][AllowEmptyString()][string]$Text)
    process {
        $t = $Text
        $t = $t -replace '(gh[pousr]_)[A-Za-z0-9_]{10,}', '$1***'
        $t = $t -replace '(github_pat_)[A-Za-z0-9_]{10,}', '$1***'
        $t = $t -replace '(sk-ant-)[A-Za-z0-9_-]{6,}', '$1***'
        $t = $t -replace '(sk-)[A-Za-z0-9_-]{16,}', '$1***'
        $t = $t -replace '([Bb]earer )[A-Za-z0-9._~+/=-]+', '$1***'
        $t = $t -replace '((?i:password|token|secret|api[_-]?key)[=:]\s*)\S+', '$1***'
        $t
    }
}

function Write-KLogFile {
    param([string]$Message)
    if (-not $env:KICKOFF_LOG) { return }
    if (-not (Test-Path (Split-Path $env:KICKOFF_LOG -Parent))) { return }
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'HH:mm:ss'), $script:KickoffStep, $Message
    Add-Content -Path $env:KICKOFF_LOG -Value (Hide-KSecret $line) -Encoding UTF8
}

function Write-KConsole {
    param([string]$Message, [switch]$ToError)
    $masked = Hide-KSecret $Message
    if ($ToError) { [Console]::Error.WriteLine($masked) } else { [Console]::Out.WriteLine($masked) }
}

function Write-KInfo  { param([string]$Message) Write-KLogFile "INFO  $Message"; Write-KConsole "  $Message" }
function Write-KOk    { param([string]$Message) Write-KLogFile "OK    $Message"; Write-KConsole "✔ $Message" }
function Write-KDoing { param([string]$Message) Write-KLogFile "DO    $Message"; Write-KConsole "➜ $Message" }
function Write-KWarn  { param([string]$Message) Write-KLogFile "WARN  $Message"; Write-KConsole "⚠ $Message" -ToError }

# Write-KFail <Meldung> [nächster Handgriff] – bricht mit Exit 1 ab (Spiegel von `die`).
# `exit` würde in einem dot-gesourcten Step nur den Step beenden; deshalb wird eine
# KickoffExitException geworfen, die bootstrap.ps1 in einen Exit-Code übersetzt.
function Write-KFail {
    param([string]$Message, [string]$Next = '')
    $suffix = ''
    if ($Next) { $suffix = " | next: $Next" }
    Write-KLogFile "FAIL  $Message$suffix"
    Write-KConsole "✘ [$($script:KickoffStep)] $Message" -ToError
    if ($Next) { Write-KConsole "  Nächster Schritt: $Next" -ToError }
    Write-KConsole "  Log: $($env:KICKOFF_LOG)" -ToError
    throw (New-Object KickoffExitException(1))
}

# ---------------------------------------------------------------------------
# Modus
# ---------------------------------------------------------------------------
function Test-KDryRun { return ($env:KICKOFF_DRY_RUN -eq '1') }

function Test-KInteractive {
    if ($env:KICKOFF_NON_INTERACTIVE -eq '1') { return $false }
    if (-not [Environment]::UserInteractive) { return $false }
    try { return (-not [Console]::IsInputRedirected) } catch { return $false }
}

# ---------------------------------------------------------------------------
# Befehle ausführen
# ---------------------------------------------------------------------------
function Format-KCommand {
    param([string]$Command, [string[]]$Arguments)
    $parts = @($Command) + @($Arguments | ForEach-Object {
            if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
        })
    return ($parts -join ' ')
}

# Invoke-KRun prüft $LASTEXITCODE – das ist nur für native Programme sinnvoll.
function Assert-KNativeCommand {
    param([string]$Command)
    $info = Get-Command $Command -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($info -and $info.CommandType -ne 'Application' -and $info.CommandType -ne 'ExternalScript') {
        Write-KFail "Invoke-KRun ist nur für native Programme gedacht, nicht für '$Command' ($($info.CommandType))." 'PowerShell-Logik direkt aufrufen.'
    }
}

# Invoke-KRun <cmd> [args…] – Ausgabe nur ins Log; Exit-Code != 0 wird zum Fehler.
function Invoke-KRun {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string]$Command,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments = @()
    )
    $q = Format-KCommand $Command $Arguments
    Assert-KNativeCommand $Command
    if (Test-KDryRun) {
        Write-KLogFile "PLAN  $q"
        Write-KConsole "  [dry-run] $q"
        return
    }
    Write-KLogFile "RUN   $q"
    $previous = $ErrorActionPreference
    # In 5.1 würde stderr eines nativen Befehls unter 'Stop' sofort abbrechen – Exit-Code zählt.
    $ErrorActionPreference = 'Continue'
    try {
        & $Command @Arguments 2>&1 | ForEach-Object { "$_" } | Hide-KSecret |
            Add-Content -Path $env:KICKOFF_LOG -Encoding UTF8
        $rc = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($rc -ne 0) {
        Write-KLogFile "EXIT  $rc"
        throw (New-Object KickoffCommandException($q, $rc))
    }
}

# Invoke-KRunVisible <cmd> [args…] – für Befehle, die das Terminal brauchen (Logins, Prompts).
function Invoke-KRunVisible {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string]$Command,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments = @()
    )
    $q = Format-KCommand $Command $Arguments
    Assert-KNativeCommand $Command
    if (Test-KDryRun) {
        Write-KLogFile "PLAN  $q"
        Write-KConsole "  [dry-run] $q"
        return
    }
    Write-KLogFile "RUN   $q (interaktiv, Ausgabe nicht geloggt)"
    & $Command @Arguments
    $rc = $LASTEXITCODE
    if ($rc -ne 0) {
        Write-KLogFile "EXIT  $rc"
        throw (New-Object KickoffCommandException($q, $rc))
    }
}

# Read-KAnswer <Frage> [Vorschlag] – im Non-Interactive-Modus kommt der Vorschlag zurück.
function Read-KAnswer {
    param([string]$Prompt, [string]$Default = '')
    if (-not (Test-KInteractive)) { return $Default }
    $label = "? $Prompt"
    if ($Default) { $label = "$label [$Default]" }
    $answer = Read-Host $label
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer
}

function Test-KCommand {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------------------
# Backups und State
# ---------------------------------------------------------------------------
function Backup-KFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    $full = (Resolve-Path $Path).Path
    $homeFull = (Resolve-Path $HOME).Path
    if ($full.StartsWith($homeFull, [StringComparison]::OrdinalIgnoreCase)) {
        $rel = $full.Substring($homeFull.Length).TrimStart('\', '/')
    } else {
        $rel = $full -replace '^[A-Za-z]:', '' -replace '^[\\/]+', ''
    }
    $dest = Join-Path $script:KickoffBackupDir $rel
    if (Test-KDryRun) { Write-KConsole "  [dry-run] Backup $full → $dest"; return }
    if (Test-Path $dest) { return }
    [void](New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force)
    Copy-Item -Path $full -Destination $dest
    Write-KLogFile "BACKUP $full → $dest"
}

function Save-KState {
    param([string]$Name, [string]$Value = '1')
    if (Test-KDryRun) { return }
    if (-not (Test-Path $script:KickoffStateDir)) { [void](New-Item -ItemType Directory -Path $script:KickoffStateDir -Force) }
    Set-Content -Path (Join-Path $script:KickoffStateDir $Name) -Value $Value -Encoding UTF8
}

function Get-KState {
    param([string]$Name)
    $p = Join-Path $script:KickoffStateDir $Name
    if (Test-Path $p) { return (Get-Content -Path $p -Raw).Trim() }
    return $null
}

function Test-KState { param([string]$Name) return (Test-Path (Join-Path $script:KickoffStateDir $Name)) }

function Clear-KState {
    param([string]$Name)
    if (Test-KDryRun) { return }
    $p = Join-Path $script:KickoffStateDir $Name
    if (Test-Path $p) { Remove-Item -Path $p -Force }
}

# Request-KReboot <marker> <Erklärung> – Neustart-Marker setzen, erklären, sauber beenden (Exit 3).
function Request-KReboot {
    param([string]$Marker, [string]$Reason)
    Save-KState "reboot-$Marker" $script:KickoffStep
    Write-KLogFile "REBOOT marker=$Marker"
    Write-KConsole ''
    Write-KConsole "↻ $Reason"
    Write-KConsole '  Nach dem Neustart denselben Befehl erneut ausführen – es geht genau hier weiter.'
    throw (New-Object KickoffExitException(3))
}

# ---------------------------------------------------------------------------
# Zeitmessung
# ---------------------------------------------------------------------------
function Enter-KStep {
    param([string]$Name)
    $script:KickoffStep = $Name
    $script:KickoffStepStart = Get-Date
    Write-KLogFile 'BEGIN'
    Write-KConsole ''
    Write-KConsole "── $Name"
}

function Exit-KStep {
    $secs = [int]((Get-Date) - $script:KickoffStepStart).TotalSeconds
    [void]$script:KickoffTiming.Add([pscustomobject]@{ Name = $script:KickoffStep; Seconds = $secs })
    Write-KLogFile "END   ${secs}s"
}

function Write-KTiming {
    param([int]$Total)
    Write-KConsole ''
    Write-KConsole 'Laufzeit'
    foreach ($t in $script:KickoffTiming) {
        Write-KConsole ('  {0,-20} {1,4}s' -f $t.Name, $t.Seconds)
    }
    Write-KConsole ('  {0,-20} {1,4}s' -f 'gesamt', $Total)
    Write-KLogFile "TOTAL ${Total}s"
}

# KickoffCommandException: Fehler eines über Invoke-KRun gestarteten Befehls (Befehl + Exit-Code).
# KickoffExitException: gewollter Abbruch (Meldung ist schon ausgegeben) mit Exit-Code.
if (-not ('KickoffExitException' -as [type])) {
    Add-Type -TypeDefinition @'
public class KickoffCommandException : System.Exception {
    public string Command;
    public int ExitCode;
    public KickoffCommandException(string command, int exitCode)
        : base("Befehl fehlgeschlagen (Exit " + exitCode + "): " + command) {
        Command = command;
        ExitCode = exitCode;
    }
}
public class KickoffExitException : System.Exception {
    public int ExitCode;
    public KickoffExitException(int exitCode) : base("kickoff exit " + exitCode) {
        ExitCode = exitCode;
    }
}
'@
}
