# Stand und nächste Schritte

Stand: 2026-11-04. Alle Phasen 0–5 der Spec sind umgesetzt, gepusht, CI grün (lint, macOS, Windows PS 5.1).

## Verifiziert

- Dry-Run + Smoke-Tests aller Schritte, beide Plattformen (lokal und CI).
- Windows PowerShell 5.1 in CI; PowerShell 7.0 wird von der Vorabprüfung abgewiesen, 7.4 läuft.
- Echte Installation git/gh/mise/node in CI (macOS), zweiter Lauf ohne Änderung, 2 s.
- Steps 30/40/60 echt in isoliertem HOME (macOS) bzw. Container (pwsh).
- Pipe-Einstieg `curl | bash` und `irm | iex` gegen GitHub.
- **Ende-zu-Ende auf frischem macOS 26.6.2 (Tart-VM, echter `curl | bash`):** alle Schritte laufen durch.
  Lauf 1: 578 s (Homebrew + CLT 328 s). Lauf 2: keine Änderung in 10–40/60, 8 s ohne Docker-Wartezeit.
  doctor grün bis auf docker (VM auf M2 ohne nested virtualization) und GitHub-Login/SSH (Logins
  bei `--non-interactive` absichtlich übersprungen). Gefundener Bug (ssh-add ohne Agent) behoben.

## Offen

1. **macOS interaktiv**: Logins (Schritt 90) einmal von Hand in der VM durchspielen: `tart clone kickoff-base kickoff-run && tart run kickoff-run`, dort den README-Befehl ohne Flags.
2. **Windows end-to-end** (WSL2-Neustart, Docker Desktop): braucht echten Windows-11-PC oder Cloud-VM mit nested virtualization – Entscheidung des Betreibers.
3. **Entscheidungen des Betreibers** (siehe `docs/BACKLOG.md`): Commit-Trailer `noreply@anthropic.com` vs. Spec §11; VS-Code-Defaults; `claude auth login`; `RemoteSigned`.
