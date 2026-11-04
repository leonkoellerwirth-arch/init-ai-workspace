# 90-auth – geführte Logins (GitHub + SSH-Key-Upload, Claude, Codex). Immer zuletzt, immer interaktiv.
# Speichert nichts im Repo. Wird von bootstrap.ps1 dot-gesourct.

# Confirm-Step90 <was> – $true = weiter, $false = übersprungen (Taste s).
function Confirm-Step90 {
    param([string]$What)
    if (Test-KDryRun) { return $true }
    $answer = Read-Host "? $What – Enter = weiter, s = überspringen"
    if ($answer -eq 's' -or $answer -eq 'S') {
        Write-KInfo "$What übersprungen"
        return $false
    }
    return $true
}

function Invoke-Step90Github {
    $ghOk = (Invoke-KProbe gh auth status).ExitCode -eq 0
    if ($ghOk) {
        Write-KOk 'GitHub-Login bereits vorhanden'
    } elseif (Confirm-Step90 'GitHub-Login (Browser)') {
        Write-KDoing 'GitHub-Login wird gestartet'
        Invoke-KRunVisible gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key --scopes admin:public_key
    } else {
        return
    }

    $pub = Join-Path $HOME '.ssh\id_ed25519.pub'
    $title = "kickoff-$([Environment]::MachineName)-$(Get-Date -Format 'yyyy-MM-dd')"
    if (-not (Test-Path $pub)) {
        if (-not (Test-KDryRun)) { Write-KWarn 'Kein SSH-Key gefunden – Upload übersprungen. Behebung: .\bootstrap.ps1 -Only 60,90' }
        return
    }
    if ((Test-KDryRun) -and -not $ghOk) {
        Invoke-KRun gh ssh-key add $pub --title $title
        return
    }
    $body = ((Get-Content -Path $pub -Raw).Trim() -split '\s+')[1]
    $keys = Invoke-KProbe gh api user/keys --jq '.[].key'
    if ($keys.ExitCode -ne 0) {
        Write-KDoing 'GitHub-Berechtigung für SSH-Keys wird ergänzt'
        Invoke-KRunVisible gh auth refresh --hostname github.com --scopes admin:public_key
        $keys = Invoke-KProbe gh api user/keys --jq '.[].key'
    }
    if ($keys.Output.Contains($body)) {
        Write-KOk 'SSH-Key bereits bei GitHub hinterlegt'
    } else {
        Write-KDoing 'SSH-Key wird zu GitHub hochgeladen'
        Invoke-KRun gh ssh-key add $pub --title $title
    }

    if (Test-KDryRun) { return }
    # Exit 1 mit Begrüßung gilt als Erfolg.
    $ssh = Invoke-KProbe ssh -T -o BatchMode=yes -o ConnectTimeout=10 git@github.com
    if ($ssh.Output -match 'successfully authenticated') {
        Write-KOk 'SSH → GitHub funktioniert'
    } else {
        Write-KWarn 'SSH → GitHub antwortet noch nicht wie erwartet. Prüfen: ssh -T git@github.com'
    }
}

function Invoke-Step90Claude {
    if ((Invoke-KProbe claude auth status).Output -match '"loggedIn":\s*true') {
        Write-KOk 'Claude-Login bereits vorhanden'
    } elseif (Confirm-Step90 'Claude-Login') {
        Write-KInfo 'Es öffnet sich ein Browserfenster für den Anthropic-Login.'
        Invoke-KRunVisible claude auth login
    }
}

function Invoke-Step90Codex {
    if ((Invoke-KProbe codex login status).ExitCode -eq 0) {
        Write-KOk 'Codex-Login bereits vorhanden'
    } elseif (Confirm-Step90 'Codex-Login') {
        Write-KInfo 'Es öffnet sich ein Browserfenster für den OpenAI-Login.'
        Invoke-KRunVisible codex login
    }
}

function Invoke-Step90Auth {
    if (-not (Test-KInteractive)) {
        Write-KInfo 'Logins übersprungen (-NonInteractive). Später nachholen: .\bootstrap.ps1 -Only 90'
        return
    }
    Import-KEnvPath
    Invoke-Step90Github
    Invoke-Step90Claude
    Invoke-Step90Codex
}

Invoke-Step90Auth
