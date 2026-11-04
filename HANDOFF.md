# HANDOFF — init-ai-workspace

Session handoffs, **newest entry first**. Written by `/session-stop` (via
`scripts/session-snapshot.sh`). Read the top entry at `/session-start`.

## 2026-11-04 — Session 1 (Umsetzung Spec Phasen 0–5)

_HEAD 190d904 · commits-ahead 4 vor Push · gate PASS · secure: nach Push geprüft_

- **Done:** Spec Phasen 0–5 umgesetzt; Vorabprüfung + PS-5.1-Lint; README „was wird geändert"; CI grün; Ende-zu-Ende auf frischem macOS (Tart-VM) bestanden; Repo auf `base` gebracht. Details: `docs/STATUS.md`, `CHANGELOG.md`.
- **Decided:** siehe `BIBLE.md` › Decision register (2026-11-04).
- **Open:** `BIBLE.md` › Open decisions (Windows-Testweg A/B/C, Commit-Trailer vs. §11, VS-Code-Defaults).
- **Next:** Windows-Testweg wählen; empfohlen A (echter Teillauf Schritte 20/30/60 in CI) — `docs/STATUS.md` › Offen.
- **Continuity warnings:** `tests/vm/macos.sh` testet den **gepushten** Stand von GitHub, nicht die Arbeitskopie. Tart liegt in `~/Applications/tart.app` (Homebrew-Formel upstream defekt); Basis-VM `kickoff-base` ~28 GB. `bootstrap.ps1` muss ASCII ohne BOM bleiben.
