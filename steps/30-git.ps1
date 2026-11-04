# 30-git – globale Git-Konfiguration aus config/git/gitconfig.template (Key für Key gemerged).
# Wird von bootstrap.ps1 dot-gesourct; nutzt lib/common.ps1.

function Get-Step30Identity {
    param([string]$Key, [string]$FromEnv, [string]$Question)
    $existing = (Invoke-KProbe git config --global --get $Key).Output.Trim()
    if ($FromEnv) { return $FromEnv }
    if ((Test-KState 'git-identity') -and $existing) { return $existing }
    return (Read-KAnswer $Question $existing)
}

# "section.key=wert" je Eintrag, Schreibweise wie im Template; Platzhalter wörtlich ersetzt.
function Get-Step30Pair {
    param([string]$Name, [string]$Email)
    $section = ''
    $pairs = @()
    foreach ($line in (Get-Content -Path (Join-Path $KickoffRoot 'config/git/gitconfig.template') -Encoding UTF8)) {
        $l = $line.Trim()
        if ($l -eq '' -or $l.StartsWith('#') -or $l.StartsWith(';')) { continue }
        if ($l -match '^\[(.+)\]$') { $section = $Matches[1].Trim(); continue }
        $i = $l.IndexOf('=')
        if ($i -lt 1) { continue }
        $value = $l.Substring($i + 1).Trim().Replace('{{NAME}}', $Name).Replace('{{EMAIL}}', $Email)
        $pairs += [pscustomobject]@{ Key = "$section." + $l.Substring(0, $i).Trim(); Value = $value }
    }
    return $pairs
}

function Set-Step30Value {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Key, [string]$Value)
    $current = (Invoke-KProbe git config --global --get $Key).Output.Trim()
    if ($current -eq $Value) {
        Write-KOk "git $Key bereits gesetzt"
        return
    }
    Write-KDoing "git $Key wird gesetzt"
    Backup-KFile (Join-Path $HOME '.gitconfig')
    if ($PSCmdlet.ShouldProcess($Key)) { Invoke-KRun git config --global $Key $Value }
}

function Invoke-Step30Git {
    Import-KEnvPath
    if (-not (Test-KCommand 'git')) {
        if (-not (Test-KDryRun)) { Write-KFail 'git fehlt.' '.\bootstrap.ps1 -Only 10' }
        Write-KInfo 'git kommt aus Schritt 10 (windows.dsc.yaml); Konfiguration wird beim echten Lauf gesetzt.'
        return
    }

    $name = Get-Step30Identity 'user.name' $env:KICKOFF_GIT_NAME 'Git-Name'
    $email = Get-Step30Identity 'user.email' $env:KICKOFF_GIT_EMAIL 'Git-E-Mail'
    if (-not $name -or -not $email) {
        if (-not (Test-KDryRun)) {
            Write-KFail 'Git-Name oder -E-Mail fehlt.' 'KICKOFF_GIT_NAME und KICKOFF_GIT_EMAIL setzen oder ohne -NonInteractive starten.'
        }
        if (-not $name) { $name = '<name>' }
        if (-not $email) { $email = '<email>' }
    }

    foreach ($pair in (Get-Step30Pair $name $email)) { Set-Step30Value $pair.Key $pair.Value }
    Set-Step30Value 'core.autocrlf' 'true'

    # Git Credential Manager kommt mit Git for Windows (System-Config) – nur prüfen.
    $helper = (Invoke-KProbe git config --get-all credential.helper).Output
    if ($helper -match 'manager') {
        Write-KOk 'Git Credential Manager bereits vorhanden'
    } else {
        Write-KWarn 'Git Credential Manager nicht konfiguriert. Behebung: winget install --id Git.Git --exact --force'
    }

    Save-KState 'git-identity'
}

Invoke-Step30Git
