# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/de/1.1.0/). Details je Änderung: `git log`.

## [Unreleased]

### Added
- Ein-Befehl-Bootstrap für macOS (`bootstrap.sh`) und Windows 11 (`bootstrap.ps1`), Einstieg per `curl | bash` bzw. `irm | iex`.
- Schritte 10 Pakete · 20 Toolchain (mise, Node 26, Claude Code, Codex) · 30 Git · 40 VS Code · 50 Docker/WSL2 · 60 SSH · 90 Logins – idempotent, mit Backups und Log.
- Flags `--dry-run`, `--only`, `--skip`, `--non-interactive`, `--doctor` (Windows: `-DryRun` usw.).
- Vorabprüfung von Versionen und Kompatibilität vor jeder Änderung (PowerShell, Windows-Build, winget, Language Mode, Rosetta).
- `doctor` mit einem Behebungsbefehl je roter Zeile.
- README-Übersicht, was auf dem Rechner geändert wird und wozu.
- Tests: Smoke-Tests je Schritt, Lint mit PS-5.1/7-Kompatibilitätsregeln, CI (Lint, macOS, Windows PS 5.1), Ende-zu-Ende-Test in einer macOS-VM (`tests/vm/macos.sh`).
