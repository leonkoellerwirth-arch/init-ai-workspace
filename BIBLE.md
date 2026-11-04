# BIBLE — init-ai-workspace

The stable mind of this repo: invariants and the decision register. Public-safe (no business
internals). Wins on any in-repo conflict. Change it deliberately, with a commit.

## Zone

**Bridge / Tool** — öffentlich, MIT (`LICENSE`). Enthält nichts Geschäftsinternes.
See `dev/base/CONSTITUTION.md` §1.

## Invariants

Auftrag und Detailregeln: `KICKOFF_SPEC.md` (verbindlich), Arbeitsregeln: `CLAUDE.md`.

- INV-1: macOS und Windows spiegeln sich (gleiche Schrittnummern, Texte, Flags) — `scripts/gate.sh` (Schritt-Paare).
- INV-2: Jeder Schritt ist idempotent; Dry-Run ändert nichts — `tests/smoke/smoke.{sh,ps1}`.
- INV-3: Keine Secrets/E-Mail-Adressen im Repo oder Log (Maskierung in `lib/common.*`) — Smoke-Test 30, gitleaks.
- INV-4: `bootstrap.ps1` reines ASCII ohne BOM, alle anderen `.ps1` mit BOM; PS-5.1-kompatibel — `tests/lint.sh`.
- INV-5: Bash-Code läuft unter macOS-System-Bash 3.2 — `tests/lint.sh` (shellcheck), CI macOS.

## Decision register

Newest first. Each: date · decision · why · (superseded by …). Begründungen: `docs/BACKLOG.md`.

- **2026-11-05 — Betreiber-Entscheidungen bestätigt**: Commits **ohne** E-Mail-Trailer (`Co-Authored-By … noreply@…` entfällt, Spec §11 gilt ohne Ausnahme; ab jetzt, Historie bleibt unangetastet); `claude auth login` statt „claude starten“; `RemoteSigned` (CurrentUser); VS-Code-Defaults wie in `config/vscode/settings.json`. Status: aktiv.
- **2026-11-05 — Windows-Testweg A**: echter Teillauf der Schritte 20/30/60 in CI (`windows-real-run` in `.github/workflows/ci.yml`); 10 und 50 bleiben Dry-Run. Status: aktiv.
- **2026-11-04 — Repo auf `base` gebracht** (`base sync`, additiv) — Session-Skills, Gate, Guardrails. Status: aktiv.
- **2026-11-04 — README zeigt, was geändert wird und wozu** (länger als Spec §7) — Betreiber-Wunsch. `README.md`. Status: aktiv.
- **2026-11-04 — Vorabprüfung vor jedem Schritt** (Versionen/Kompatibilität, Abbruch vor Änderung) — Betreiber-Wunsch. `lib/common.*` (`check_platform`, `Test-KPlatform`). Status: aktiv.
- **2026-11-04 — `bootstrap.ps1` ASCII ohne BOM** — `irm | iex` bricht am BOM. Status: aktiv.
- **2026-11-04 — Offene Spec-Punkte entschieden** (WSL2 via Schritt 50, `claude auth login`, `RemoteSigned`, `lib/json-merge.js`, Teilläufe ohne doctor-Exit) — `docs/BACKLOG.md` § Entscheidungen. Status: aktiv.
- **2026-11-04 — Spec §10 beantwortet**: Repo `leonkoellerwirth-arch/init-ai-workspace`, Docker Desktop als Default, Extension-Liste aus Spec §5. Status: aktiv.

## Open decisions

_(Blocking questions. Do not start substantive work that depends on an open decision here.)_

- Windows-Volllauf (Schritte 10/50, WSL2-Neustart, Docker Desktop): B (Win11 ARM in UTM) / C (Win11-PC bzw. Cloud-VM) — `docs/STATUS.md`. Nicht blockierend.
