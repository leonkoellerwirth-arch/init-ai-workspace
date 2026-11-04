# 60-ssh – ed25519-Key, ssh-agent-Dienst, ~/.ssh/config, GitHub-Host-Keys, Git nutzt Windows-OpenSSH.
# Der Upload zu GitHub passiert erst in Schritt 90 nach `gh auth login`. Wird von bootstrap.ps1 dot-gesourct.

function Invoke-Step60Ssh {
    Import-KEnvPath
    $sshDir = Join-Path $HOME '.ssh'
    $key = Join-Path $sshDir 'id_ed25519'
    $email = (Invoke-KProbe git config --global --get user.email).Output.Trim()

    if (Test-Path $key) {
        Write-KOk "SSH-Key $key bereits vorhanden"
    } else {
        if (-not $email -and -not (Test-KDryRun)) { Write-KFail 'Für den SSH-Key fehlt die Git-E-Mail.' '.\bootstrap.ps1 -Only 30' }
        if (-not $email) { $email = '<email>' }
        Write-KDoing 'SSH-Key (ed25519) wird erzeugt'
        if (-not (Test-KDryRun) -and -not (Test-Path $sshDir)) { [void](New-Item -ItemType Directory -Path $sshDir -Force) }
        if (Test-KInteractive) {
            # Interaktiv fragt ssh-keygen selbst nach einer Passphrase (Enter = keine).
            Invoke-KRunVisible ssh-keygen -t ed25519 -C $email -f $key
        } else {
            # Windows PowerShell 5.1 verwirft leere Argumente – dort muss '""' übergeben werden.
            $empty = ''
            if ($PSVersionTable.PSVersion.Major -lt 7) { $empty = '""' }
            Invoke-KRun ssh-keygen -q -t ed25519 -C $email -f $key -N $empty
        }
    }

    # ssh config ohne BOM – OpenSSH liest das BOM sonst als Teil der ersten Option.
    Sync-KBlock -Path (Join-Path $sshDir 'config') -Name 'github' -NoBom -Content @'
Host github.com
  AddKeysToAgent yes
  IdentityFile ~/.ssh/id_ed25519
Host *
'@

    if ($env:OS -eq 'Windows_NT') {
        # Der ssh-agent-Dienst ist unter Windows standardmäßig deaktiviert; Einschalten braucht Admin.
        $agent = Get-Service -Name 'ssh-agent' -ErrorAction SilentlyContinue
        if ($agent -and $agent.Status -eq 'Running') {
            Write-KOk 'ssh-agent-Dienst läuft bereits'
        } elseif ($agent) {
            Write-KDoing 'ssh-agent-Dienst wird aktiviert'
            Invoke-KElevated 'powershell.exe' @('-NoProfile', '-Command', 'Set-Service ssh-agent -StartupType Automatic; Start-Service ssh-agent')
        } else {
            Write-KWarn 'ssh-agent-Dienst fehlt. Behebung (Admin): Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0'
        }

        # Git for Windows bringt ein eigenes ssh mit, das den Windows-Agent nicht sieht.
        $sshExe = 'C:/Windows/System32/OpenSSH/ssh.exe'
        if ((Invoke-KProbe git config --global --get core.sshCommand).Output.Trim() -eq $sshExe) {
            Write-KOk 'git core.sshCommand bereits gesetzt'
        } else {
            Write-KDoing 'git core.sshCommand wird gesetzt'
            Backup-KFile (Join-Path $HOME '.gitconfig')
            Invoke-KRun git config --global core.sshCommand $sshExe
        }
    }

    $fp = ''
    if (Test-Path "$key.pub") { $fp = ((Invoke-KProbe ssh-keygen -lf "$key.pub").Output -split '\s+')[1] }
    $agentKeys = (Invoke-KProbe ssh-add -l).Output
    if ($fp -and $agentKeys.Contains($fp)) {
        Write-KOk 'SSH-Key bereits im Agent'
    } else {
        Write-KDoing 'SSH-Key wird dem Agent hinzugefügt'
        if (Test-KInteractive) { Invoke-KRunVisible ssh-add $key } else { Invoke-KRun ssh-add $key }
    }

    # GitHub-Host-Keys über HTTPS (api.github.com/meta) statt blind ssh-keyscan zu vertrauen.
    $knownHosts = Join-Path $sshDir 'known_hosts'
    if ((Test-Path $knownHosts) -and (Invoke-KProbe ssh-keygen -F github.com -f $knownHosts).ExitCode -eq 0) {
        Write-KOk 'GitHub-Host-Keys bereits in known_hosts'
    } else {
        Write-KDoing 'GitHub-Host-Keys werden in known_hosts eingetragen'
        Backup-KFile $knownHosts
        if (Test-KDryRun) {
            Write-KConsole "  [dry-run] api.github.com/meta → $knownHosts"
        } else {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            $meta = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/meta'
            $lines = @($meta.ssh_keys | ForEach-Object { "github.com $_" })
            if ($lines.Count -eq 0) { Write-KFail 'GitHub lieferte keine Host-Keys.' 'Netzwerk prüfen und erneut starten.' }
            Add-Content -Path $knownHosts -Value $lines -Encoding Ascii
        }
    }
}

Invoke-Step60Ssh
