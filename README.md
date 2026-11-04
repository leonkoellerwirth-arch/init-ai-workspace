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

## Was passiert

Das Skript prüft jeden Schritt (Pakete, Toolchain, Git, VS Code, Docker, SSH) und ändert nur, was fehlt. Bestehende Dateien werden vorher nach `~/.kickoff/backups/` gesichert; das Log steht in `~/.kickoff/logs/`. Am Ende führen kurze Logins (GitHub, Claude, Codex) durch den Rest, danach zeigt `doctor` den Status.

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
