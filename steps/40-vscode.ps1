# 40-vscode – Extensions aus config/vscode/extensions.txt, Settings-Merge (bestehende Keys gewinnen).
# Wird von bootstrap.ps1 dot-gesourct; nutzt lib/common.ps1.

# Pfad zur code-CLI; nach einer frischen winget-Installation ist `code` oft noch nicht im PATH.
function Get-Step40Code {
    $cmd = Get-Command 'code' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    $candidates = @()
    if ($env:LOCALAPPDATA) { $candidates += Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd' }
    if ($env:ProgramFiles) { $candidates += Join-Path $env:ProgramFiles 'Microsoft VS Code\bin\code.cmd' }
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return $null
}

function Get-Step40Extension {
    $ids = @()
    foreach ($line in (Get-Content -Path (Join-Path $KickoffRoot 'config/vscode/extensions.txt') -Encoding UTF8)) {
        $fields = @(($line -replace '#.*$', '').Trim() -split '\s+' | Where-Object { $_ })
        if ($fields.Count -eq 0) { continue }
        if ($fields.Count -eq 1 -or $fields[1] -eq 'windows') { $ids += $fields[0].ToLowerInvariant() }
    }
    return $ids
}

function Invoke-Step40Vscode {
    Import-KEnvPath
    $code = Get-Step40Code
    $installed = @()
    if ($code) {
        $installed = @((Invoke-KProbe $code --list-extensions).Output -split "`n" |
                ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
    } elseif (Test-KDryRun) {
        Write-KInfo 'VS Code kommt aus Schritt 10 (windows.dsc.yaml).'
        $code = 'code'
    } else {
        Write-KFail 'VS Code (code-CLI) nicht gefunden.' '.\bootstrap.ps1 -Only 10'
    }

    foreach ($ext in (Get-Step40Extension)) {
        if ($installed -contains $ext) {
            Write-KOk "Extension $ext bereits vorhanden"
        } else {
            Write-KDoing "Extension $ext wird installiert"
            Invoke-KRun $code --install-extension $ext
        }
    }

    # Settings-Merge per node (Schritt 20); fehlende Keys ergänzen, bestehende gewinnen.
    $defaults = Join-Path $KickoffRoot 'config/vscode/settings.json'
    $appData = $env:APPDATA
    if (-not $appData) { $appData = Join-Path $HOME '.config' }
    $settings = Join-Path $appData 'Code\User\settings.json'
    if (-not (Test-KCommand 'node')) {
        if (-not (Test-KDryRun)) { Write-KFail 'node fehlt für den Settings-Merge.' '.\bootstrap.ps1 -Only 20' }
        Write-KInfo 'Settings-Merge braucht node aus Schritt 20.'
        return
    }
    $check = Invoke-KJsonMerge $settings $defaults 'check'
    switch ($check.ExitCode) {
        0 { Write-KOk 'VS-Code-Settings bereits vorhanden' }
        10 {
            Write-KDoing "VS-Code-Settings werden ergänzt: $($check.Missing)"
            Backup-KFile $settings
            if (Test-KDryRun) {
                Write-KConsole "  [dry-run] node lib/json-merge.js $settings $defaults write"
            } else {
                $write = Invoke-KJsonMerge $settings $defaults 'write'
                if ($write.ExitCode -ne 10 -and $write.ExitCode -ne 0) {
                    Write-KFail "Settings-Merge fehlgeschlagen (Exit $($write.ExitCode))." 'node -v prüfen und erneut starten.'
                }
            }
        }
        20 { Write-KWarn "VS-Code-settings.json enthält Kommentare o. Ä. und wird nicht automatisch geändert. Fehlende Keys bitte aus $defaults übernehmen." }
        default { Write-KFail "Settings-Merge fehlgeschlagen (Exit $($check.ExitCode))." 'node -v prüfen und erneut starten.' }
    }
}

Invoke-Step40Vscode
