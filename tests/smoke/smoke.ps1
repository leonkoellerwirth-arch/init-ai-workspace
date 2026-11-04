# Smoke-Tests (Windows): jeder Schritt läuft im -DryRun gegen ein leeres Profilverzeichnis. Geprüft wird,
# dass die erwarteten Befehle geplant werden und dass der Dry-Run nichts verändert.
# Läuft auch unter pwsh auf Linux/macOS (der OS-Guard erlaubt dort nur den Dry-Run).
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
$hostExe = (Get-Process -Id $PID).Path
$script:Fails = 0
$script:Out = ''
$script:Rc = 0

# Invoke-SmokeDryRun <args…> – bootstrap.ps1 im Dry-Run in einem eigenen Prozess mit leerem HOME.
function Invoke-SmokeDryRun {
    param([string[]]$BootstrapArgs = @())
    $home2 = Join-Path ([IO.Path]::GetTempPath()) ("kickoff-smoke-" + [guid]::NewGuid().ToString('N'))
    [void](New-Item -ItemType Directory -Path $home2 -Force)
    $saved = @{}
    $vars = @{
        HOME = $home2; USERPROFILE = $home2; APPDATA = (Join-Path $home2 'AppData\Roaming')
        LOCALAPPDATA = (Join-Path $home2 'AppData\Local'); KICKOFF_HOME = (Join-Path $home2 '.kickoff')
        KICKOFF_GIT_NAME = 'Smoke Test'; KICKOFF_GIT_EMAIL = 'smoke@example.invalid'
    }
    foreach ($k in $vars.Keys) {
        $saved[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, $vars[$k])
    }
    try {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $script:Out = (& $hostExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'bootstrap.ps1') -DryRun -NonInteractive @BootstrapArgs 2>&1 |
                ForEach-Object { "$_" }) -join "`n"
        $script:Rc = $LASTEXITCODE
        $ErrorActionPreference = $previous
    } finally {
        foreach ($k in $vars.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
    # Dry-Run darf außer dem Log nichts anlegen. Caches, die winget/npm/code beim Lesen selbst
    # anlegen (z. B. Microsoft\DeveloperTools\deviceid), sind keine Änderung durch kickoff.
    $changed = @(Get-ChildItem -Path $home2 -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/]\.kickoff[\\/]logs[\\/]' -and $_.FullName -notmatch '[\\/](Cache|cache|npm-cache|\.npm|\.cache|\.vscode|Code|DeveloperTools|\.docker|\.local)[\\/]' })
    Remove-Item -Path $home2 -Recurse -Force -ErrorAction SilentlyContinue
    if ($changed.Count -gt 0) {
        [Console]::Out.WriteLine("✘ Dry-Run ($($BootstrapArgs -join ' ')) hat Dateien angelegt: $($changed[0].FullName)")
        $script:Fails++
    }
}

function Assert-SmokeMatch {
    param([string]$Name, [string]$Pattern)
    if ($script:Out -match $Pattern) {
        [Console]::Out.WriteLine("✔ $Name")
    } else {
        [Console]::Out.WriteLine("✘ $Name – erwartet: $Pattern")
        [Console]::Out.WriteLine(($script:Out -split "`n" | ForEach-Object { "    $_" }) -join "`n")
        $script:Fails++
    }
}

function Assert-SmokeNoMatch {
    param([string]$Name, [string]$Text)
    if ($script:Out.Contains($Text)) {
        [Console]::Out.WriteLine("✘ $Name – unerwartet: $Text")
        $script:Fails++
    } else {
        [Console]::Out.WriteLine("✔ $Name")
    }
}

function Assert-SmokeExitCode {
    param([string]$Name, [int]$Expected)
    if ($script:Rc -eq $Expected) {
        [Console]::Out.WriteLine("✔ $Name")
    } else {
        [Console]::Out.WriteLine("✘ $Name – Exit $($script:Rc) statt $Expected")
        $script:Fails++
    }
}

Invoke-SmokeDryRun @('-Only', '10')
Assert-SmokeExitCode '10: Exit 0' 0
Assert-SmokeMatch '10: Pakete' '\[dry-run\] winget configure --file|bereits vorhanden'

Invoke-SmokeDryRun @('-Only', '20')
Assert-SmokeExitCode '20: Exit 0' 0
Assert-SmokeMatch '20: Profil-Block' 'Block mise wird eingetragen'
Assert-SmokeMatch '20: node über mise' 'node 26.* \(mise\) bereits vorhanden|\[dry-run\] mise use -g node@26'
Assert-SmokeMatch '20: claude-code' '@anthropic-ai/claude-code (bereits vorhanden|wird installiert)'
Assert-SmokeMatch '20: codex' '@openai/codex (bereits vorhanden|wird installiert)'

Invoke-SmokeDryRun @('-Only', '30')
Assert-SmokeExitCode '30: Exit 0' 0
Assert-SmokeMatch '30: user.name' '\[dry-run\] git config --global user.name|git kommt aus Schritt 10'
Assert-SmokeMatch '30: autocrlf' '\[dry-run\] git config --global core.autocrlf true|git kommt aus Schritt 10'
Assert-SmokeNoMatch '30: keine E-Mail im Klartext' 'smoke@example.invalid'

Invoke-SmokeDryRun @('-Only', '40')
Assert-SmokeExitCode '40: Exit 0' 0
Assert-SmokeMatch '40: Windows-Extension' 'Extension ms-vscode-remote\.remote-wsl (bereits vorhanden|wird installiert)'

Invoke-SmokeDryRun @('-Only', '50')
Assert-SmokeExitCode '50: Exit 0' 0
Assert-SmokeMatch '50: WSL2' 'WSL2 (bereits vorhanden|wird aktiviert)'
Assert-SmokeMatch '50: Docker' 'Docker läuft bereits|Start-Process|Neustart nötig'

Invoke-SmokeDryRun @('-Only', '60')
Assert-SmokeExitCode '60: Exit 0' 0
Assert-SmokeMatch '60: Key-Erzeugung' '\[dry-run\] ssh-keygen -q -t ed25519'
Assert-SmokeMatch '60: ssh config' 'config: Block github wird eingetragen'
Assert-SmokeMatch '60: known_hosts' 'api\.github\.com/meta'

Invoke-SmokeDryRun @('-Only', '90')
Assert-SmokeExitCode '90: Exit 0' 0
Assert-SmokeMatch '90: non-interactive überspringt Logins' 'Logins übersprungen'

Invoke-SmokeDryRun @()
Assert-SmokeExitCode 'voller Dry-Run: Exit 0' 0
Assert-SmokeMatch 'voller Dry-Run: Zeitmessung' 'gesamt +\d+s'
Assert-SmokeMatch 'Vorabprüfung: PowerShell-Version' '✔ PowerShell +\d+\.\d+'
Assert-SmokeMatch 'Vorabprüfung: Language Mode' 'Language Mode +FullLanguage'
Invoke-SmokeDryRun @('-Only', '30', '-Skip', '30')
Assert-SmokeNoMatch '-Skip schlägt -Only' '── 30-git'

[Console]::Out.WriteLine('')
if ($script:Fails -eq 0) { [Console]::Out.WriteLine('✔ Smoke-Tests sauber'); exit 0 }
[Console]::Out.WriteLine("✘ $($script:Fails) Smoke-Test(s) fehlgeschlagen")
exit 1
