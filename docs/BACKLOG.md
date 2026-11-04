# Backlog

Ideen außerhalb der Spec. Nicht bauen, nur notieren.

- Linux-Bootstrap (`bootstrap-linux.sh`) – Struktur ist vorbereitet, Spec §2 Non-Goal für v1.
- Windows-CI mit echten Installationen (git, gh, mise, node) – derzeit nur Dry-Run + Smoke unter PS 5.1.
- Login-Status für Claude/Codex als eigene doctor-Zeilen (Spec §6 verlangt sie nicht).

## Entscheidungen, wo die Spec offen war

- VS-Code-Settings (`config/vscode/settings.json`): drei neutrale Defaults; Inhalt nicht in der Spec.
- WSL2: Paket `Microsoft.WSL` in `windows.dsc.yaml`, Aktivierung + Neustart-Marker in Schritt 50 (§5 Docker).
- Claude-Login über `claude auth login` statt „claude einmal starten" – gleicher Browser-Login, prüfbar über `claude auth status`.
- Teilläufe (`--only`/`--skip`) enden nicht mit doctors Exit-Code, sonst wäre jeder Teillauf rot.
- `lib/json-merge.js` zusätzlich zur Struktur in §3, damit beide Plattformen identisch mergen.
- Windows: ExecutionPolicy `RemoteSigned` (CurrentUser) und `core.sshCommand` auf Windows-OpenSSH – sonst laden Profil/npm-Shims nicht bzw. sieht Git den ssh-agent nicht.
- README länger als eine Bildschirmseite (Spec §7): Betreiber wollte ausdrücklich sehen, was auf dem Rechner geändert wird und wozu (2026-11-04).
