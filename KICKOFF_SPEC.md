# KICKOFF – Prompt Specification für Claude Code

> Diese Datei ist der Arbeitsauftrag. Lies sie vollständig, bevor du eine Datei anfasst. Führe die Phasen in der angegebenen Reihenfolge aus. Frage nur bei den unter „Offene Entscheidungen" markierten Punkten nach – alles andere entscheidest du anhand dieser Spezifikation.

---

## 1. Ziel

Ein Entwickler auf einem frischen macOS- oder Windows-11-Rechner soll mit **genau einem Befehl** eine vollständige, einheitliche Entwicklungsumgebung für agentisches Coding erhalten. Kein Download per Browser, kein Klick-Installer, keine Schritt-für-Schritt-Anleitung.

Der einzige Befehl, den ein Mensch tippt:

```bash
# macOS
curl -fsSL https://raw.githubusercontent.com/<OWNER>/kickoff/main/bootstrap.sh | bash
```

```powershell
# Windows 11 (PowerShell, nicht als Administrator gestartet – das Skript eskaliert selbst, wo nötig)
irm https://raw.githubusercontent.com/<OWNER>/kickoff/main/bootstrap.ps1 | iex
```

Am Ende steht ein grüner Statusreport (`doctor`) und eine geführte Login-Sequenz für die Dienste, die Credentials brauchen.

## 2. Zielumgebung (Scope)

Nach erfolgreichem Lauf sind installiert und konfiguriert:

| Komponente | macOS | Windows 11 |
|---|---|---|
| Paketmanager | Homebrew | winget (vorinstalliert, nur prüfen) |
| Git | brew | winget `Git.Git` |
| GitHub CLI (`gh`) | brew | winget `GitHub.cli` |
| Docker | Docker Desktop (brew cask) | Docker Desktop (winget) + WSL2 |
| Node.js / npm | via `mise` | via `mise` |
| VS Code | brew cask | winget `Microsoft.VisualStudioCode` |
| Claude Code | `npm i -g @anthropic-ai/claude-code` | identisch |
| Codex CLI | `npm i -g @openai/codex` | identisch |
| mise | brew | winget / Installer-Skript |
| Git-Konfiguration | global, siehe §5 | global, siehe §5 |
| VS-Code-Extensions + Settings | aus Repo | aus Repo |
| SSH-Key + GitHub-Upload | ja | ja |

**Nicht im Scope (Non-Goals):**
- Keine Linux-Unterstützung in v1 (Struktur so anlegen, dass `bootstrap-linux.sh` später ergänzbar ist).
- Keine Unternehmens-Proxy-/Zertifikatslogik.
- Keine Speicherung von Secrets im Repo oder in Logs. Niemals.
- Keine GUI, keine Electron-App. Reine Skripte.

## 3. Repo-Struktur

Lege exakt diese Struktur an:

```
kickoff/
├── bootstrap.sh                 # macOS-Einstieg (Bash, POSIX-nah, shellcheck-sauber)
├── bootstrap.ps1                # Windows-Einstieg (PowerShell 5.1-kompatibel, PSScriptAnalyzer-sauber)
├── manifests/
│   ├── Brewfile                 # macOS: alle Pakete, deklarativ
│   ├── windows.dsc.yaml         # Windows: winget configure (DSC) inkl. WSL2
│   └── mise.toml                # Toolchain-Versionen (node, ggf. python), plattformübergreifend
├── config/
│   ├── git/
│   │   └── gitconfig.template   # Platzhalter {{NAME}}, {{EMAIL}}; wird in ~/.gitconfig gemerged, nicht überschrieben
│   ├── vscode/
│   │   ├── extensions.txt       # eine Extension-ID pro Zeile
│   │   └── settings.json        # wird mit bestehenden Settings gemerged (bestehende Keys gewinnen)
│   └── shell/
│       ├── aliases.sh           # macOS/zsh
│       └── profile.ps1          # Windows
├── lib/
│   ├── common.sh                # Logging, Idempotenz-Helper, Fehlerbehandlung (Bash)
│   └── common.ps1               # dito (PowerShell)
├── steps/                       # je Schritt eine Datei, beide Plattformen spiegeln sich
│   ├── 10-packages.sh / .ps1
│   ├── 20-toolchain.sh / .ps1   # mise + node + global npm-Pakete
│   ├── 30-git.sh / .ps1
│   ├── 40-vscode.sh / .ps1
│   ├── 50-docker.sh / .ps1
│   ├── 60-ssh.sh / .ps1
│   └── 90-auth.sh / .ps1        # geführte Logins, immer zuletzt
├── doctor.sh
├── doctor.ps1
├── tests/
│   ├── lint.sh                  # shellcheck + PSScriptAnalyzer
│   └── smoke/                   # siehe §8
├── .github/workflows/ci.yml     # Lint auf jedem Push; macOS-Runner führt bootstrap in Dry-Run aus
├── README.md
└── KICKOFF_SPEC.md              # diese Datei
```

## 4. Verhaltensregeln für alle Skripte

Diese Regeln sind nicht verhandelbar. Prüfe jede Datei dagegen, bevor du sie als fertig betrachtest.

1. **Idempotenz.** Jeder Lauf darf beliebig oft wiederholt werden. Jeder Schritt prüft erst den Ist-Zustand und handelt nur bei Abweichung. Ausgabe pro Schritt: `✔ bereits vorhanden` oder `➜ wird installiert`.
2. **Kein Überschreiben von Nutzerdaten.** `~/.gitconfig`, VS-Code-`settings.json`, Shell-Profile werden gemerged, nie ersetzt. Vor jeder Änderung an einer bestehenden Datei: Backup nach `~/.kickoff/backups/<timestamp>/`.
3. **Fail loud, nicht fail silent.** `set -euo pipefail` in Bash, `$ErrorActionPreference = 'Stop'` in PowerShell. Jeder Fehler nennt den Schritt, den Befehl und den nächsten sinnvollen Handgriff für den Menschen.
4. **Logging.** Alles nach `~/.kickoff/logs/<timestamp>.log` (vollständig) und auf stdout (gekürzt). Keine Secrets im Log – Tokens, Keys, Passwörter werden maskiert, bevor sie irgendwo landen.
5. **Flags.** Beide Bootstraps unterstützen:
   - `--dry-run` – nur anzeigen, nichts ausführen
   - `--only <step>` / `--skip <step>` – einzelne Schritte
   - `--non-interactive` – Name/E-Mail aus `KICKOFF_GIT_NAME` / `KICKOFF_GIT_EMAIL`, keine Prompts, Auth-Schritt wird übersprungen
   - `--doctor` – nur den Statusreport
6. **Neustarts.** Wenn ein Schritt einen Neustart braucht (WSL2, Docker Desktop auf Windows), bricht das Skript sauber ab, schreibt einen Marker nach `~/.kickoff/state/`, erklärt dem Nutzer in zwei Sätzen, was passiert, und nimmt beim nächsten Aufruf exakt dort wieder auf.
7. **Keine Annahmen über Shell oder Rechte.** macOS: zsh ist Standard, Bash-Skripte müssen trotzdem laufen. Windows: PowerShell 5.1 ohne Admin ist die Baseline; Admin-Rechte werden pro Schritt per UAC angefordert, nicht pauschal.
8. **Timing.** Am Ende steht die Gesamtlaufzeit und die Laufzeit pro Schritt. Das ist die Messgröße, an der die Qualität des Repos gemessen wird.

## 5. Konfigurationsschicht – Details

### Git
- Abfrage von Name und E-Mail (einmalig, mit Vorschlag aus bestehender Config, falls vorhanden).
- Setzen: `user.name`, `user.email`, `init.defaultBranch=main`, `pull.rebase=false`, `core.editor="code --wait"`.
- Plattformabhängig: `core.autocrlf=input` (macOS), `core.autocrlf=true` (Windows).
- Credential Helper: macOS `osxkeychain`, Windows Git Credential Manager (im Git-Paket enthalten, nur prüfen).

### SSH
- Erzeuge `~/.ssh/id_ed25519`, falls nicht vorhanden (`ssh-keygen -t ed25519 -C "<email>"`, ohne Passphrase-Prompt in `--non-interactive`).
- Füge den Key dem Agent hinzu (macOS: Keychain-Integration in `~/.ssh/config`).
- Upload zu GitHub erst **nach** erfolgreichem `gh auth login` (Schritt 90): `gh ssh-key add ~/.ssh/id_ed25519.pub --title "kickoff-<hostname>-<date>"`.
- Verifikation: `ssh -T git@github.com` – Exit-Code 1 mit Begrüßung gilt als Erfolg.

### VS Code
- Extensions aus `config/vscode/extensions.txt` per `code --install-extension`, nur die, die noch fehlen.
- Startliste (du darfst nichts entfernen, nur begründet ergänzen):
  `anthropic.claude-code`, `openai.chatgpt`, `ms-azuretools.vscode-docker`, `ms-vscode-remote.remote-containers`, `eamodio.gitlens`, `editorconfig.editorconfig`, `esbenp.prettier-vscode`, `dbaeumer.vscode-eslint`.
- Windows zusätzlich: `ms-vscode-remote.remote-wsl`.
- Settings-Merge: bestehende Nutzer-Keys gewinnen immer.

### Toolchain
- `mise` installieren, `manifests/mise.toml` global aktivieren (`mise use -g`), Shell-Hook in Profil eintragen.
- Node: aktuelle LTS, in `mise.toml` auf Major gepinnt.
- Global via npm: `@anthropic-ai/claude-code`, `@openai/codex`. Vor der Installation per `npm view <pkg> version` prüfen, dass der Paketname existiert; wenn nicht, abbrechen und melden – keine Alternativnamen raten.

### Docker
- macOS: Docker Desktop als Cask; starten, bis `docker info` antwortet (Timeout 120 s, dann Hinweis, keine Endlosschleife).
- Windows: WSL2 aktivieren (`wsl --install --no-distribution`, Neustart-Marker), danach Docker Desktop mit WSL2-Backend. Prüfen: `docker info` aus PowerShell.

### Auth (Schritt 90, immer zuletzt, immer interaktiv)
Reihenfolge und Wortlaut gegenüber dem Nutzer:
1. `gh auth login --git-protocol ssh --web` → danach SSH-Key-Upload (§5 SSH).
2. `claude` einmal starten, Hinweis: „Es öffnet sich ein Browserfenster für den Anthropic-Login."
3. `codex login`, analoger Hinweis.
Jeder Schritt ist einzeln überspringbar (`s` drücken). Kein Schritt speichert etwas im Repo.

## 6. `doctor`

Ein eigenständiges Skript, das ohne Installation läuft und eine Tabelle ausgibt:

```
Komponente        Soll        Ist          Status
git               ≥ 2.40      2.47.0       ✔
gh                vorhanden   2.63.1       ✔
docker            läuft       –            ✘  Docker Desktop ist nicht gestartet
node (mise)       22.x        22.11.0      ✔
claude            vorhanden   –            ✘  npm i -g @anthropic-ai/claude-code
...
GitHub-Login      ja          nein         ✘  gh auth login
SSH → GitHub      ja          ja           ✔
```

- Exit-Code 0 nur, wenn alles grün. Sonst 1.
- Jede rote Zeile enthält den **einen** Befehl, der sie grün macht.
- `doctor` wird automatisch am Ende jedes Bootstrap-Laufs ausgeführt.

## 7. README

Kurz. Maximal eine Bildschirmseite:
1. Die zwei Einstiegsbefehle (§1).
2. Was danach passiert (drei Sätze).
3. `doctor` und die Flags (§4.5).
4. Troubleshooting: die drei wahrscheinlichsten Fehler (Neustart nach WSL2, Docker Desktop nicht gestartet, `code` nicht im PATH) mit je einem Befehl.

Keine Installationsanleitungen für einzelne Werkzeuge. Wenn du beim Schreiben des README den Drang verspürst, eine Schritt-für-Schritt-Anleitung zu formulieren, ist das ein Signal, dass das Skript an dieser Stelle noch nicht gut genug ist – behebe das Skript, nicht das README.

## 8. Tests und CI

- `tests/lint.sh`: `shellcheck` für alle `.sh`, `PSScriptAnalyzer` (`Invoke-ScriptAnalyzer -Severity Warning`) für alle `.ps1`. Null Warnungen ist das Ziel.
- `tests/smoke/`: Für jeden Schritt ein Test, der den Schritt im `--dry-run` ausführt und prüft, dass die erwarteten Befehle geplant werden.
- CI (`.github/workflows/ci.yml`):
  - Job `lint` auf `ubuntu-latest`.
  - Job `macos-dry-run` auf `macos-latest`: `bootstrap.sh --dry-run --non-interactive`.
  - Job `windows-dry-run` auf `windows-latest`: `bootstrap.ps1 -DryRun -NonInteractive`.
  - Echte Installationen in CI nur für Git, gh, mise, node (schnell, kein Neustart). Docker Desktop wird in CI übersprungen.

## 9. Arbeitsweise für dich (Claude Code)

Arbeite in dieser Reihenfolge und committe nach jeder Phase mit einer aussagekräftigen Message (Conventional Commits, Englisch):

| Phase | Inhalt | Commit-Prefix |
|---|---|---|
| 0 | Repo-Struktur, `lib/common.*`, Logging, Flags, Dry-Run-Mechanik. Noch kein Schritt. | `chore: scaffold` |
| 1 | `bootstrap.sh` + `Brewfile` + Schritte 10–40 für macOS. `doctor.sh`. | `feat(macos):` |
| 2 | `bootstrap.ps1` + `windows.dsc.yaml` + Schritte 10–40 für Windows. `doctor.ps1`. | `feat(windows):` |
| 3 | Docker (50) und SSH (60) beide Plattformen inkl. Neustart-Marker. | `feat(docker):` / `feat(ssh):` |
| 4 | Auth (90) beide Plattformen. | `feat(auth):` |
| 5 | Tests, CI, README. | `test:` / `ci:` / `docs:` |

Weitere Regeln:
- Bevor du eine Phase beginnst: lies die betroffenen Abschnitte dieser Spec erneut und schreibe in zwei Sätzen, was du bauen wirst. Dann bau es.
- Nach jeder Phase: `tests/lint.sh` ausführen. Nicht weiter, bevor es sauber ist.
- Wenn du einen winget-Paketnamen, einen Cask-Namen oder einen npm-Paketnamen nicht sicher weißt: prüfe ihn (`winget search`, `brew search`, `npm view`). Rate nie.
- Die beiden Plattformen sollen sich **spiegeln**: gleiche Schrittnummern, gleiche Ausgabetexte, gleiche Flags. Wenn du auf einer Plattform ein Verhalten änderst, ändere es auf der anderen mit.
- Kein Feature, das nicht in dieser Spec steht. Wenn dir etwas fehlt, notiere es unter `docs/BACKLOG.md` statt es zu bauen.

## 10. Offene Entscheidungen (nur hier nachfragen)

Frage den Nutzer am Anfang von Phase 0 genau diese drei Punkte, gesammelt in einer Nachricht, und arbeite dann durch:

1. GitHub-Owner/Repo-Name für die `raw.githubusercontent.com`-URLs in §1 und im README.
2. Soll Docker Desktop oder eine leichtere Alternative (macOS: OrbStack / Colima; Windows: nur WSL2 + Docker Engine) der Default sein? Default laut Spec: Docker Desktop.
3. Soll die VS-Code-Extension-Liste aus §5 so übernommen werden, oder gibt es eine bestehende Liste, die stattdessen gilt?

## 11. Definition of Done

Das Repo ist fertig, wenn:

- [ ] Auf einem frischen macOS und einem frischen Windows 11 je ein Befehl aus §1 ohne weiteren Eingriff (außer Logins und ggf. einem Neustart) zu einem vollständig grünen `doctor` führt.
- [ ] Ein zweiter Lauf des gleichen Befehls unter 30 Sekunden bleibt und nichts verändert.
- [ ] `tests/lint.sh` ohne Warnung durchläuft und CI grün ist.
- [ ] Das README auf eine Bildschirmseite passt.
- [ ] Kein Secret, kein Token, keine E-Mail-Adresse im Repo oder in den Logs.
