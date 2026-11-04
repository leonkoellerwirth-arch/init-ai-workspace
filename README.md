# kickoff

Ein Befehl richtet auf einem frischen Rechner die komplette Umgebung für agentisches Coding ein: Git, GitHub CLI, Docker, Node (über mise), VS Code, Claude Code und Codex.

```bash
# macOS
curl -fsSL https://raw.githubusercontent.com/leonkoellerwirth-arch/init-ai-workspace/main/bootstrap.sh | bash
```

```powershell
# Windows 11 (PowerShell, nicht als Administrator – Rechte werden pro Schritt per UAC angefragt)
irm https://raw.githubusercontent.com/leonkoellerwirth-arch/init-ai-workspace/main/bootstrap.ps1 | iex
```

**Voraussetzungen:** macOS auf Apple Silicon oder Intel (Terminal nicht unter Rosetta) · Windows 11 mit Windows PowerShell 5.1 (oder PowerShell ≥ 7.2) und App Installer/winget ≥ 1.6.

## Was passiert

Zuerst prüft eine Vorabprüfung Versionen und Kompatibilität – ist etwas rot, bricht das Skript ab, bevor irgendetwas geändert wird, und nennt den einen Handgriff, der hilft. Danach prüft jeder Schritt den Ist-Zustand und ändert nur, was fehlt (`✔ bereits vorhanden` / `➜ wird installiert`). Am Ende führen kurze Logins (GitHub, Claude, Codex) durch den Rest, danach zeigt `doctor` den Status.

## Was auf deinem Rechner geändert wird – und wozu

Vorher ansehen, ohne etwas zu ändern: `--dry-run` (macOS) bzw. `-DryRun` (Windows).

| Was | Wo | Wozu |
|---|---|---|
| **Programme** installieren, falls sie fehlen: Git, GitHub CLI, mise, VS Code, Docker Desktop – macOS zusätzlich Homebrew samt Xcode Command Line Tools, Windows zusätzlich WSL2 | macOS: Homebrew · Windows: winget | Die Werkzeuge für agentisches Coding. Schon (auch ohne brew/winget) installierte Apps bleiben unangetastet. |
| **Node 26 (LTS)** über mise | `~/.config/mise/config.toml` (global) | Eine gepinnte Node-Version, ohne andere Node-Installationen zu überschreiben. |
| **Claude Code und Codex** per `npm i -g` | globale npm-Pakete unter mise-Node | Die beiden Coding-Agenten. Übersprungen, wenn `claude`/`codex` schon vorhanden ist. |
| **Shell-Profil**: ein markierter Block `# >>> kickoff:… >>>` | macOS: `~/.zprofile` (brew), `~/.zshrc` (mise, Aliase); `~/.bash_profile` nur, wenn es existiert · Windows: PowerShell-Profil für 5.1 und 7 | Damit `brew`, Node und die Agenten in jedem neuen Terminal gefunden werden. Rest der Datei bleibt unverändert. |
| **Git-Einstellungen** (nur abweichende Keys) | `~/.gitconfig` | `user.name`/`user.email`, `init.defaultBranch=main`, `pull.rebase=false`, `core.editor="code --wait"`, Zeilenenden (`core.autocrlf` input bzw. true), Passwortspeicher (macOS: Keychain eintragen; Windows: Git Credential Manager nur prüfen). Windows zusätzlich `core.sshCommand` auf Windows-OpenSSH, damit Git den ssh-agent nutzt. |
| **VS-Code-Extensions** (nur fehlende) und 3 Einstellungen (nur fehlende) | VS Code; `settings.json` | Extensions: `config/vscode/extensions.txt`. Einstellungen: Leerzeile am Dateiende, Leerzeichen am Zeilenende entfernen, Git-Autofetch. Eigene Werte gewinnen immer; eine `settings.json` mit Kommentaren wird nicht angefasst. |
| **SSH-Key** `id_ed25519` (nur wenn keiner existiert), Block für `github.com`, GitHub-Host-Keys | `~/.ssh/` | Git über SSH zu GitHub. Host-Keys kommen per HTTPS von `api.github.com/meta`. |
| **SSH-Key bei GitHub hinterlegen** (öffentlicher Teil, Titel `kickoff-<rechner>-<datum>`) | dein GitHub-Konto | Damit `git push` ohne Passwort funktioniert. Erst nach deinem Login; einzeln überspringbar. |
| **Logins** GitHub, Claude, Codex (Browser) | jeweiliges Tool | Jeder einzeln überspringbar (`s`); nichts davon landet im Repo oder im Log. |
| Nur **Windows**, jeweils mit UAC-Abfrage: WSL2 aktivieren, Gruppe `docker-users`, Dienst `ssh-agent` auf automatisch | Windows-Systemeinstellungen | Voraussetzungen für Docker Desktop und den SSH-Agent. WSL2 und `docker-users` brauchen einen Neustart – danach denselben Befehl erneut starten. |
| Nur **Windows**: ExecutionPolicy `RemoteSigned` für deinen Benutzer | PowerShell | Sonst laden weder das Profil noch die npm-Befehle (`claude`, `codex`). |
| **kickoff-Ordner** | `~/.kickoff/` | `logs/` (vollständiges Log, Secrets und E-Mail maskiert), `backups/<zeit>/` (Kopie jeder Datei vor der ersten Änderung), `state/` (Neustart-Marker), `shell/` (Aliase), `src/` (heruntergeladene Skripte). |

**Rückgängig machen:** Die Originale liegen in `~/.kickoff/backups/<zeit>/`; die kickoff-Blöcke in Profil- und SSH-Dateien sind durch `# >>> kickoff:… >>>` markiert und lassen sich gezielt löschen.

## doctor und Flags

| macOS | Windows | Wirkung |
|---|---|---|
| `--dry-run` | `-DryRun` | nur anzeigen, nichts ausführen |
| `--only 30` / `--skip 50` | `-Only 30` / `-Skip 50` | einzelne Schritte |
| `--non-interactive` | `-NonInteractive` | keine Prompts; `KICKOFF_GIT_NAME` / `KICKOFF_GIT_EMAIL`; Logins entfallen |
| `--doctor` | `-Doctor` | nur der Statusreport |

Flags beim Direktaufruf: `curl … | bash -s -- --dry-run` bzw. `& ([scriptblock]::Create((irm …/bootstrap.ps1))) -DryRun`. Mehrfache Läufe sind gefahrlos.

## Troubleshooting

- **Windows meldet „Neustart nötig" (WSL2/Docker):** neu starten und denselben Befehl erneut ausführen – es geht dort weiter.
  `Restart-Computer`
- **Docker Desktop läuft nicht:** einmal starten und im Fenster bestätigen.
  macOS `open -a Docker` · Windows `Start-Process "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"`
- **`code` nicht im PATH:** neues Terminal öffnen; auf macOS sonst
  `ln -sf "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "$(brew --prefix)/bin/code"`
