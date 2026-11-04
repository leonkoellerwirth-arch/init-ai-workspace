# kickoff doctor (Windows) – Statusreport. Ändert nichts. Exit 0 nur, wenn alles grün ist.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$KickoffRoot = Split-Path -Parent $PSCommandPath
. (Join-Path $KickoffRoot 'lib/common.ps1')
Import-KEnvPath

$script:DoctorFailed = 0
$nodeMajor = ''
foreach ($line in (Get-Content -Path (Join-Path $KickoffRoot 'manifests/mise.toml') -Encoding UTF8)) {
    if ($line -match '^node\s*=\s*"?(\d+)') { $nodeMajor = $Matches[1] }
}

function Write-DoctorRow {
    param([string]$Component, [string]$Want, [string]$Have, [bool]$Ok, [string]$Fix = '')
    if (-not $Have) { $Have = '–' }
    $status = '✔'
    $hint = ''
    if (-not $Ok) {
        $status = '✘'
        $hint = "  $Fix"
        $script:DoctorFailed = 1
    }
    Write-KConsole ('{0,-17} {1,-11} {2,-12} {3}{4}' -f $Component, $Want, $Have, $status, $hint)
}

function Get-DoctorVersion {
    param([string]$Command, [string[]]$Arguments = @('--version'))
    $probe = Invoke-KProbe $Command @Arguments
    if ($probe.ExitCode -ne 0) { return '' }
    if ($probe.Output -match '(\d+(\.\d+)+)') { return $Matches[1] }
    return ''
}

Write-KConsole ('{0,-17} {1,-11} {2,-12} {3}' -f 'Komponente', 'Soll', 'Ist', 'Status')

$v = Get-DoctorVersion 'winget'
Write-DoctorRow 'winget' 'vorhanden' $v ([bool]$v) 'Im Microsoft Store "App Installer" aktualisieren'

$v = Get-DoctorVersion 'git'
$gitOk = $false
if ($v) { $gitOk = ([version](($v -split '\.')[0..1] -join '.')) -ge [version]'2.40' }
Write-DoctorRow 'git' '≥ 2.40' $v $gitOk 'winget install --id Git.Git --exact'

$v = Get-DoctorVersion 'gh'
Write-DoctorRow 'gh' 'vorhanden' $v ([bool]$v) 'winget install --id GitHub.cli --exact'

$v = Get-DoctorVersion 'mise'
Write-DoctorRow 'mise' 'vorhanden' $v ([bool]$v) 'winget install --id jdx.mise --exact'

$v = ''
if (Test-KCommand 'mise') {
    Push-Location $HOME
    try { $v = (Invoke-KProbe mise current node).Output.Trim() } finally { Pop-Location }
}
Write-DoctorRow 'node (mise)' "$nodeMajor.x" $v ($v -eq $nodeMajor -or $v.StartsWith("$nodeMajor.")) "mise use -g node@$nodeMajor"

$v = Get-DoctorVersion 'claude'
Write-DoctorRow 'claude' 'vorhanden' $v ([bool]$v) 'npm i -g @anthropic-ai/claude-code'
$v = Get-DoctorVersion 'codex'
Write-DoctorRow 'codex' 'vorhanden' $v ([bool]$v) 'npm i -g @openai/codex'

$v = Get-DoctorVersion 'code'
Write-DoctorRow 'code' 'im PATH' $v ([bool]$v) 'winget install --id Microsoft.VisualStudioCode --exact'

$wsl = Invoke-KProbe wsl --status
$wslOk = ($wsl.ExitCode -eq 0)
$wslHave = 'nein'
if ($wslOk) { $wslHave = 'ja' }
Write-DoctorRow 'WSL2' 'aktiv' $wslHave $wslOk '.\bootstrap.ps1 -Only 50'

if (-not (Test-KCommand 'docker')) {
    Write-DoctorRow 'docker' 'läuft' '' $false 'winget install --id Docker.DockerDesktop --exact'
} elseif ((Invoke-KProbe docker info).ExitCode -eq 0) {
    Write-DoctorRow 'docker' 'läuft' (Get-DoctorVersion 'docker') $true
} else {
    Write-DoctorRow 'docker' 'läuft' 'gestoppt' $false "Start-Process '$env:ProgramFiles\Docker\Docker\Docker Desktop.exe'"
}

$identity = (Invoke-KProbe git config --global --get user.name).Output.Trim() -and (Invoke-KProbe git config --global --get user.email).Output.Trim()
$identityHave = 'nein'
if ($identity) { $identityHave = 'ja' }
Write-DoctorRow 'Git-Identität' 'gesetzt' $identityHave ([bool]$identity) '.\bootstrap.ps1 -Only 30'

$ghOk = (Invoke-KProbe gh auth status).ExitCode -eq 0
$ghHave = 'nein'
if ($ghOk) { $ghHave = 'ja' }
Write-DoctorRow 'GitHub-Login' 'ja' $ghHave $ghOk 'gh auth login --git-protocol ssh --web'

# Exit 1 mit Begrüßung gilt als Erfolg. Read-only: unbekannter Host-Key = rot.
$ssh = Invoke-KProbe ssh -T -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes git@github.com
$sshOk = $ssh.Output -match 'successfully authenticated'
$sshHave = 'nein'
if ($sshOk) { $sshHave = 'ja' }
Write-DoctorRow 'SSH → GitHub' 'ja' $sshHave $sshOk '.\bootstrap.ps1 -Only 60,90'

exit $script:DoctorFailed
