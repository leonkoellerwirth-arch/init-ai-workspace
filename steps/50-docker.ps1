# 50-docker – WSL2 aktivieren (Neustart-Marker), docker-users-Gruppe, Docker Desktop starten (max. 120 s).
# Installiert werden WSL und Docker Desktop in Schritt 10 (windows.dsc.yaml). Wird von bootstrap.ps1 dot-gesourct.

function Test-Step50Wsl {
    if ($env:OS -ne 'Windows_NT') { return $false }
    $feature = Get-CimInstance -ClassName Win32_OptionalFeature -Filter "Name='VirtualMachinePlatform'" -ErrorAction SilentlyContinue
    if (-not $feature -or $feature.InstallState -ne 1) { return $false }
    return ((Invoke-KProbe wsl --status).ExitCode -eq 0)
}

# Ist seit dem Setzen des Markers neu gestartet worden?
function Test-Step50Rebooted {
    param([string]$Marker)
    $file = Join-Path $script:KickoffStateDir $Marker
    if (-not (Test-Path $file)) { return $false }
    $boot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    return ($boot -gt (Get-Item $file).LastWriteTime)
}

function Invoke-Step50Wsl {
    if (Test-Step50Wsl) {
        if (Test-KState 'reboot-wsl') {
            Clear-KState 'reboot-wsl'
            Write-KOk 'WSL2 nach dem Neustart aktiv'
        } else {
            Write-KOk 'WSL2 bereits vorhanden'
        }
        return
    }
    if ((Test-KState 'reboot-wsl') -and (Test-Step50Rebooted 'reboot-wsl')) {
        Write-KFail 'WSL2 ist auch nach dem Neustart nicht aktiv.' 'Als Administrator: wsl --install --no-distribution; danach neu starten und erneut ausführen.'
    }
    if (-not (Test-KState 'reboot-wsl')) {
        Write-KDoing 'WSL2 wird aktiviert'
        Invoke-KElevated 'wsl.exe' @('--install', '--no-distribution')
    }
    Request-KReboot 'wsl' 'WSL2 ist eingerichtet, Windows muss dafür einmal neu starten. Nach dem Neustart denselben Befehl erneut ausführen.'
}

# Docker Desktop verlangt die Gruppe docker-users; neue Gruppen gelten erst nach Ab-/Anmelden.
function Invoke-Step50Group {
    if ($env:OS -ne 'Windows_NT') { return }
    $user = "$env:USERDOMAIN\$env:USERNAME"
    $token = (Invoke-KProbe whoami /groups).Output
    if ($token -match 'docker-users') { Write-KOk 'Gruppe docker-users bereits aktiv'; return }
    $members = Invoke-KProbe net localgroup docker-users
    if ($members.ExitCode -ne 0) { return }  # Gruppe gibt es (noch) nicht – Docker Desktop legt sie an.
    if ($members.Output -notmatch [regex]::Escape($env:USERNAME)) {
        Write-KDoing 'Benutzer wird zur Gruppe docker-users hinzugefügt'
        Invoke-KElevated 'net.exe' @('localgroup', 'docker-users', $user, '/add')
    }
    Request-KReboot 'docker' 'Die Gruppe docker-users gilt erst nach einem Neustart (oder Ab- und Anmelden). Danach denselben Befehl erneut ausführen.'
}

function Invoke-Step50Docker {
    Import-KEnvPath
    Invoke-Step50Wsl

    if ((Test-KCommand 'docker') -and (Invoke-KProbe docker info).ExitCode -eq 0) {
        Clear-KState 'reboot-docker'
        Write-KOk 'Docker läuft bereits'
        return
    }
    Invoke-Step50Group

    $programFiles = $env:ProgramFiles
    if (-not $programFiles) { $programFiles = 'C:\Program Files' }
    $exe = "$programFiles\Docker\Docker\Docker Desktop.exe"
    if (-not (Test-Path $exe) -and -not (Test-KDryRun)) {
        Write-KFail 'Docker Desktop ist nicht installiert.' '.\bootstrap.ps1 -Only 10'
    }
    Write-KDoing 'Docker Desktop wird gestartet'
    $timeout = 120
    if ($env:KICKOFF_DOCKER_TIMEOUT) { $timeout = [int]$env:KICKOFF_DOCKER_TIMEOUT }
    if (Test-KDryRun) {
        Write-KConsole "  [dry-run] Start-Process '$exe'"
        Write-KInfo "[dry-run] warten, bis docker info antwortet (max. $timeout s)"
        return
    }
    Start-Process -FilePath $exe
    $waited = 0
    while ($waited -lt $timeout) {
        Import-KEnvPath
        if ((Test-KCommand 'docker') -and (Invoke-KProbe docker info).ExitCode -eq 0) {
            Write-KOk "Docker läuft (nach $waited s)"
            return
        }
        Start-Sleep -Seconds 3
        $waited += 3
    }
    Write-KWarn "Docker antwortet nach $timeout s noch nicht. Beim ersten Start will Docker Desktop eine Bestätigung im Fenster – danach: .\bootstrap.ps1 -Only 50"
}

Invoke-Step50Docker
