# 20-toolchain – mise, Node aus manifests/mise.toml, globale npm-Pakete, PowerShell-Profil.
# Wird von bootstrap.ps1 dot-gesourct; nutzt lib/common.ps1.

function Get-Step20Tool {
    $section = ''
    $tools = @()
    foreach ($line in (Get-Content -Path (Join-Path $KickoffRoot 'manifests/mise.toml') -Encoding UTF8)) {
        $l = ($line -replace '#.*$', '').Trim()
        if ($l -match '^\[(.+)\]$') { $section = $Matches[1]; continue }
        if ($section -eq 'tools' -and $l -match '^([A-Za-z0-9_-]+)\s*=\s*"?([^"]+)"?$') {
            $tools += [pscustomobject]@{ Name = $Matches[1]; Version = $Matches[2].Trim() }
        }
    }
    return $tools
}

function Invoke-Step20Toolchain {
    Import-KEnvPath
    if (Test-KCommand 'mise') {
        Write-KOk 'mise bereits vorhanden'
    } elseif (Test-KDryRun) {
        Write-KInfo 'mise kommt aus Schritt 10 (windows.dsc.yaml).'
    } else {
        Write-KFail 'mise fehlt.' '.\bootstrap.ps1 -Only 10'
    }

    # Ohne RemoteSigned laden weder das Profil noch die npm-Shims (claude.ps1, codex.ps1).
    if ($env:OS -eq 'Windows_NT') {
        $policy = Get-ExecutionPolicy
        if (@('RemoteSigned', 'Unrestricted', 'Bypass') -contains "$policy") {
            Write-KOk "ExecutionPolicy $policy bereits ausreichend"
        } else {
            Write-KDoing 'ExecutionPolicy RemoteSigned (CurrentUser) wird gesetzt'
            if (Test-KDryRun) {
                Write-KConsole '  [dry-run] Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
            } else {
                Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
            }
        }
    }

    # Profil: mise-Shims in den PATH, kickoff-Profil laden – für Windows PowerShell 5.1 und PowerShell 7.
    $shellDir = Join-Path $env:KICKOFF_HOME 'shell'
    $source = Join-Path $KickoffRoot 'config/shell/profile.ps1'
    $target = Join-Path $shellDir 'profile.ps1'
    $same = (Test-Path $target) -and ((Get-FileHash $source).Hash -eq (Get-FileHash $target).Hash)
    if ($same) {
        Write-KOk 'Profil-Ergänzungen bereits vorhanden'
    } else {
        Write-KDoing "Profil-Ergänzungen werden nach $shellDir kopiert"
        if (Test-KDryRun) {
            Write-KConsole "  [dry-run] Copy-Item $source $target"
        } else {
            if (-not (Test-Path $shellDir)) { [void](New-Item -ItemType Directory -Path $shellDir -Force) }
            Copy-Item -Path $source -Destination $target -Force
        }
    }
    $block = @'
$kickoffShims = Join-Path $env:LOCALAPPDATA 'mise\shims'
if ((Test-Path $kickoffShims) -and ($env:Path -notlike "*$kickoffShims*")) { $env:Path = "$kickoffShims;$env:Path" }
$kickoffProfile = Join-Path $HOME '.kickoff\shell\profile.ps1'
if (Test-Path $kickoffProfile) { . $kickoffProfile }
'@
    $docs = [Environment]::GetFolderPath('MyDocuments')
    if (-not $docs) { $docs = Join-Path $HOME 'Documents' }
    foreach ($dir in @('WindowsPowerShell', 'PowerShell')) {
        Sync-KBlock -Path (Join-Path (Join-Path $docs $dir) 'Microsoft.PowerShell_profile.ps1') -Name 'mise' -Content $block
    }

    # Toolchain-Versionen global setzen (mise use -g ergänzt die globale Config, ersetzt sie nicht).
    foreach ($tool in (Get-Step20Tool)) {
        $current = ''
        if (Test-KCommand 'mise') {
            Push-Location $HOME
            try { $current = (Invoke-KProbe mise current $tool.Name).Output.Trim() } finally { Pop-Location }
        }
        if ($current -eq $tool.Version -or $current.StartsWith("$($tool.Version).")) {
            Write-KOk "$($tool.Name) $current (mise) bereits vorhanden"
        } else {
            Write-KDoing "$($tool.Name) $($tool.Version) (mise) wird installiert"
            Invoke-KRun mise use -g "$($tool.Name)@$($tool.Version)"
        }
    }
    Import-KEnvPath

    # Globale npm-Pakete. Paketname wird vorher geprüft – nie raten (Spec §5).
    # CI setzt KICKOFF_NPM_GLOBALS="" (echte Installationen dort nur für git, gh, mise, node).
    $globals = '@anthropic-ai/claude-code @openai/codex'
    if ($null -ne $env:KICKOFF_NPM_GLOBALS) { $globals = $env:KICKOFF_NPM_GLOBALS }
    foreach ($pkg in ($globals -split '\s+' | Where-Object { $_ })) {
        if ((Invoke-KProbe npm ls -g --depth=0 $pkg).ExitCode -eq 0) {
            Write-KOk "$pkg bereits vorhanden"
            continue
        }
        if ((Test-KCommand 'npm') -and (Invoke-KProbe npm view $pkg version).ExitCode -ne 0) {
            Write-KFail "npm-Paket $pkg existiert nicht oder die Registry ist nicht erreichbar." "Netzwerk prüfen: npm view $pkg version"
        }
        Write-KDoing "$pkg wird installiert"
        Invoke-KRun npm install -g $pkg
    }
    if ((Test-KCommand 'mise') -and -not (Test-KDryRun)) { Invoke-KRun mise reshim }
}

Invoke-Step20Toolchain
