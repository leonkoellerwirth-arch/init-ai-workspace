# 10-packages – winget prüfen, alle Pakete aus manifests/windows.dsc.yaml per `winget configure`.
# Wird von bootstrap.ps1 dot-gesourct; nutzt lib/common.ps1.

function Get-Step10PackageId {
    $yaml = Join-Path $KickoffRoot 'manifests/windows.dsc.yaml'
    $ids = @()
    foreach ($line in (Get-Content -Path $yaml -Encoding UTF8)) {
        # Paket-IDs stehen unter settings: und enthalten immer einen Punkt (z. B. Git.Git).
        if ($line -match '^\s+id:\s+([A-Za-z0-9-]+\.[A-Za-z0-9.-]+)\s*$') { $ids += $Matches[1] }
    }
    return $ids
}

function Invoke-Step10Package {
    Import-KEnvPath
    if (Test-KCommand 'winget') {
        Write-KOk 'winget bereits vorhanden'
    } elseif (Test-KDryRun) {
        Write-KInfo 'winget fehlt auf diesem System (Dry-Run läuft weiter).'
    } else {
        Write-KFail 'winget fehlt.' 'Im Microsoft Store "App Installer" aktualisieren und erneut starten.'
    }

    $yaml = Join-Path $KickoffRoot 'manifests/windows.dsc.yaml'
    $missing = @()
    foreach ($id in (Get-Step10PackageId)) {
        $probe = Invoke-KProbe winget list --id $id --exact --accept-source-agreements --disable-interactivity
        if ($probe.ExitCode -eq 0) {
            Write-KOk "$id bereits vorhanden"
        } else {
            $missing += $id
        }
    }
    if ($missing.Count -eq 0) { return }

    Write-KDoing ("Pakete werden installiert: " + ($missing -join ', '))
    Invoke-KRun winget configure --file $yaml --accept-configuration-agreements --disable-interactivity
    Import-KEnvPath
}

Invoke-Step10Package
