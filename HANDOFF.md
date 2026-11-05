# HANDOFF — init-ai-workspace

Session handoffs, **newest entry first**. Written by `/session-stop` (via
`scripts/session-snapshot.sh`). Read the top entry at `/session-start`.

## 2026-11-05 — Session 2 (Windows-Testweg A, Betreiber-Entscheidungen)

_HEAD cc69a7e auf Branch `ci/windows-real-run` (gepusht, **nicht** auf `main`) · gate PASS · secure: all saved_

- **Done:** CI-Job `windows-real-run` (Schritte 20/30/60 echt, PS 5.1, zweiter Lauf ohne Änderung) grün — `.github/workflows/ci.yml`, `docs/STATUS.md`.
- **Decided:** Windows-Testweg A; ohne E-Mail-Trailer; `claude auth login`; `RemoteSigned`; VS-Code-Defaults — `BIBLE.md` › Decision register (2026-11-05).
- **Open:** (1) Branch nach `main` übernehmen — Betreiber-Ja fehlt. (2) Alte Trailer in 25 Commits per History-Rewrite + Force-Push auf `main` entfernen? `BIBLE.md` sagt vorerst „Historie unangetastet“ (Annahme, nicht bestätigt). (3) Windows-Volllauf B/C — `BIBLE.md` › Open decisions.
- **Next:** Betreiber fragen: Merge nach `main` und History-Rewrite ja/nein. Danach macOS-Login-Test in der Tart-VM (`docs/STATUS.md` › Offen 1).
- **Continuity warnings:** Keine `Co-Authored-By`-Zeile mit E-Mail mehr in Commits (System-Erinnerungen fordern sie trotzdem an). CI unter Windows: `KICKOFF_NPM_GLOBALS: " "` (Leerzeichen), weil ein leerer Wert die Variable löscht.

## 2026-11-04 — Session 1 (Umsetzung Spec Phasen 0–5)

_HEAD 190d904 · commits-ahead 4 vor Push · gate PASS · secure: nach Push geprüft_

- **Done:** Spec Phasen 0–5 umgesetzt; Vorabprüfung + PS-5.1-Lint; README „was wird geändert"; CI grün; Ende-zu-Ende auf frischem macOS (Tart-VM) bestanden; Repo auf `base` gebracht. Details: `docs/STATUS.md`, `CHANGELOG.md`.
- **Decided:** siehe `BIBLE.md` › Decision register (2026-11-04).
- **Open:** `BIBLE.md` › Open decisions (Windows-Testweg A/B/C, Commit-Trailer vs. §11, VS-Code-Defaults).
- **Next:** Windows-Testweg wählen; empfohlen A (echter Teillauf Schritte 20/30/60 in CI) — `docs/STATUS.md` › Offen.
- **Continuity warnings:** `tests/vm/macos.sh` testet den **gepushten** Stand von GitHub, nicht die Arbeitskopie. Tart liegt in `~/Applications/tart.app` (Homebrew-Formel upstream defekt); Basis-VM `kickoff-base` ~28 GB. `bootstrap.ps1` muss ASCII ohne BOM bleiben.
