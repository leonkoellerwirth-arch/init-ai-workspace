# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Was dieses Repo ist

„kickoff": ein Ein-Befehl-Bootstrap für eine agentische Dev-Umgebung auf frischem macOS (`bootstrap.sh`) und Windows 11 (`bootstrap.ps1`). Reine Skripte, keine GUI, kein Linux in v1.

**Verbindlicher Arbeitsauftrag: `KICKOFF_SPEC.md`.** Vor jeder Phase die betroffenen Abschnitte neu lesen. Diese Datei fasst nur die Regeln zusammen, die beim Arbeiten ständig gelten; im Zweifel gilt die Spec.

## Befehle

```bash
tests/lint.sh                                        # shellcheck (*.sh) + PSScriptAnalyzer -Severity Warning (*.ps1); Ziel: 0 Warnungen
./bootstrap.sh --dry-run --non-interactive           # plant alle Schritte, führt nichts aus
./bootstrap.sh --dry-run --only 30-git               # einzelner Schritt (analog --skip <step>)
./bootstrap.sh --doctor                              # nur Statusreport; doctor.sh läuft auch eigenständig
pwsh -File bootstrap.ps1 -DryRun -NonInteractive     # Windows-Pendant
```

```bash
tests/smoke/smoke.sh                                 # je Schritt ein Dry-Run gegen leeres HOME: geplante Befehle + „nichts verändert"
docker run --rm -v "$PWD":/w -w /w mcr.microsoft.com/powershell:lts-7.4-ubuntu-22.04 pwsh -File tests/smoke/smoke.ps1
```

Nach jeder Änderung müssen `tests/lint.sh` und beide Smoke-Suiten sauber sein. Echte Läufe einzelner Schritte nur mit isoliertem `HOME` testen (ssh-agent/Keychain getrennt halten).

## Architektur

- `bootstrap.{sh,ps1}` parst Flags, lädt `lib/common.{sh,ps1}` und führt `steps/NN-*.{sh,ps1}` in numerischer Reihenfolge aus; am Ende läuft immer `doctor` und die Laufzeit gesamt + pro Schritt wird ausgegeben.
- `lib/common.*` bündelt alles Querschnittliche: Logging (voll nach `~/.kickoff/logs/<ts>.log`, gekürzt auf stdout, Secrets maskiert), Dry-Run-Mechanik (Befehle über einen Wrapper ausführen, damit Dry-Run sie nur plant), Backups nach `~/.kickoff/backups/<ts>/`, Neustart-Marker in `~/.kickoff/state/`.
- Deklarative Paketlisten in `manifests/` (Brewfile, `windows.dsc.yaml`, `mise.toml`); Nutzer-Configs in `config/` werden **gemerged, nie ersetzt** (bestehende Nutzer-Keys gewinnen).
- `90-auth` ist immer zuletzt und interaktiv; SSH-Key-Upload zu GitHub erst nach `gh auth login`.

## Harte Regeln (Spec §4, §9)

- **Plattformen spiegeln sich:** gleiche Schrittnummern, Ausgabetexte, Flags. Änderung auf einer Seite → auf der anderen nachziehen.
- Idempotent: Ist-Zustand prüfen, nur bei Abweichung handeln; Ausgabe `✔ bereits vorhanden` / `➜ wird installiert`.
- Bash: `set -euo pipefail`, muss unter macOS-System-Bash **3.2** laufen (keine assoziativen Arrays, kein `mapfile`, kein `${var,,}`; leere Arrays unter `set -u` absichern). PowerShell: 5.1-kompatibel (kein `??`/Ternary), `$ErrorActionPreference = 'Stop'`, Admin nur pro Schritt via UAC. `.ps1` als UTF-8 **mit BOM** speichern; für PSScriptAnalyzer nur approved verbs, kein `Write-Host` (Ausgabe über `Write-K*`), keine Set-/New-/Remove-Funktionen ohne ShouldProcess. Native Befehle über `Invoke-KRun` (prüft `$LASTEXITCODE`).
- Bash-Helfer und PS-Helfer sind 1:1 gespiegelt (`run`↔`Invoke-KRun`, `ok`↔`Write-KOk`, `die`↔`Write-KFail`, `needs_reboot`↔`Request-KReboot`, `backup_file`↔`Backup-KFile`, `state_*`↔`*-KState`).
- `tests/lint.sh` nutzt lokales `pwsh`, sonst Docker (`mcr.microsoft.com/powershell`), sonst Warnung; prüft auch den BOM. PS-Dry-Runs lassen sich im selben Container testen (`pwsh ./bootstrap.ps1 -DryRun -NonInteractive`) – der OS-Guard lässt Nicht-Windows nur im Dry-Run zu.
- PS-Steps werden dot-gesourct: `exit` dort beendet nur den Step. Abbrüche immer über `Write-KFail` / `Request-KReboot` (werfen `KickoffExitException`, bootstrap.ps1 übersetzt in Exit-Code).
- Fehlermeldungen nennen Schritt, Befehl und nächsten Handgriff.
- Paketnamen (winget/brew/npm) nie raten, sondern prüfen (`winget search`, `brew search`, `npm view`).
- Kein Feature außerhalb der Spec – Ideen nach `docs/BACKLOG.md`.
- Keine Secrets, Tokens oder E-Mail-Adressen im Repo oder in Logs.
- Commits nach jeder Phase, Conventional Commits auf Englisch (Präfixe siehe Spec §9).
- README max. eine Bildschirmseite; braucht es eine Schritt-für-Schritt-Anleitung, ist das Skript zu verbessern, nicht das README.
