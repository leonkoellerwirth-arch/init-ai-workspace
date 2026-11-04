# Stand und nächste Schritte

Stand: 2026-11-04. Alle Phasen 0–5 der Spec sind umgesetzt, gepusht, CI grün (lint, macOS, Windows PS 5.1).

## Verifiziert

- Dry-Run + Smoke-Tests aller Schritte, beide Plattformen (lokal und CI).
- Windows PowerShell 5.1 in CI; PowerShell 7.0 wird von der Vorabprüfung abgewiesen, 7.4 läuft.
- Echte Installation git/gh/mise/node in CI (macOS), zweiter Lauf ohne Änderung, 2 s.
- Steps 30/40/60 echt in isoliertem HOME (macOS) bzw. Container (pwsh).
- Pipe-Einstieg `curl | bash` und `irm | iex` gegen GitHub.

## Offen

1. **macOS-VM-Test** (`tests/vm/macos.sh`): Basis-Image lädt bzw. muss laden.
   - Download wurde am 2026-11-04 angehalten und muss neu gestartet werden.
   - Fertig, wenn `tart list` die VM `kickoff-base` zeigt. Neu starten, falls nötig:
     `tart clone ghcr.io/cirruslabs/macos-tahoe-vanilla:26.6.2 kickoff-base` (~24 GB)
   - Dann: `tests/vm/macos.sh` (Ergebnis in `vm-results/`). Auf M1/M2 ist die docker-Zeile erwartbar rot (keine nested virtualization).
   - Tart 2.41.1 liegt in `~/Applications/tart.app` (Homebrew-Formel upstream defekt), Link `/opt/homebrew/bin/tart`.
2. **Windows end-to-end** (WSL2-Neustart, Docker Desktop): braucht echten Windows-11-PC oder Cloud-VM mit nested virtualization – Entscheidung des Betreibers.
3. **Entscheidungen des Betreibers** (siehe `docs/BACKLOG.md`): Commit-Trailer `noreply@anthropic.com` vs. Spec §11; VS-Code-Defaults; `claude auth login`; `RemoteSigned`.
