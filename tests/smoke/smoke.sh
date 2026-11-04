#!/usr/bin/env bash
# Smoke-Tests (macOS): jeder Schritt läuft im --dry-run gegen ein leeres HOME. Geprüft wird,
# dass die erwarteten Befehle geplant werden und dass der Dry-Run nichts verändert.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILS=0
OUT=""

# dry <args…> – bootstrap im Dry-Run mit frischem, leerem HOME; Ausgabe in $OUT, Exit-Code in $RC.
dry() {
  local home
  home="$(mktemp -d)"
  RC=0
  OUT="$(HOME="$home" KICKOFF_GIT_NAME="Smoke Test" KICKOFF_GIT_EMAIL="smoke@example.invalid" \
    bash "$ROOT/bootstrap.sh" --dry-run --non-interactive "$@" 2>&1)" || RC=$?
  # Dry-Run darf außer dem Log nichts anlegen. Caches, die brew/npm/code beim Lesen selbst
  # anlegen, sind keine Änderung durch kickoff.
  local changed
  changed="$(cd "$home" && find . -mindepth 1 -type f \
    -not -path './.kickoff/logs/*' \
    -not -path './Library/Caches/*' -not -path './.npm/*' -not -path './.cache/*' \
    -not -path './.vscode/*' -not -path './Library/Application Support/Code/*' \
    -not -path './Library/Application Support/Microsoft/*' -not -path './.local/*' 2>/dev/null || true)"
  rm -rf "$home"
  if [ -n "$changed" ]; then
    echo "✘ Dry-Run ($*) hat Dateien angelegt: $changed"
    FAILS=$((FAILS + 1))
  fi
}

# expect <name> <erweiterter Regex> – Ausgabe des letzten dry-Laufs muss passen.
expect() {
  if printf '%s\n' "$OUT" | grep -Eq -- "$2"; then
    echo "✔ $1"
  else
    echo "✘ $1 – erwartet: $2"
    printf '%s\n' "$OUT" | sed 's/^/    /'
    FAILS=$((FAILS + 1))
  fi
}

# expect_not <name> <fester Text> – darf in der Ausgabe nicht vorkommen.
expect_not() {
  case "$OUT" in
    *"$2"*) echo "✘ $1 – unerwartet: $2"; FAILS=$((FAILS + 1)) ;;
    *) echo "✔ $1" ;;
  esac
}

expect_rc() {
  if [ "$RC" -eq "$2" ]; then echo "✔ $1"; else echo "✘ $1 – Exit $RC statt $2"; FAILS=$((FAILS + 1)); fi
}

test_10_packages() {
  dry --only 10
  expect_rc "10: Exit 0" 0
  expect "10: Homebrew" 'Homebrew bereits vorhanden|\[dry-run\] _step10_install_homebrew'
  expect "10: Brewfile" 'Pakete aus Brewfile bereits vorhanden|\[dry-run\] env HOMEBREW_BUNDLE_CASK_SKIP=.* brew bundle install'
  expect "10: brew shellenv in .zprofile" '\.zprofile: Block brew wird eingetragen'
}

test_20_toolchain() {
  dry --only 20
  expect_rc "20: Exit 0" 0
  expect "20: mise-Hook in .zshrc" '\.zshrc: Block mise wird eingetragen'
  expect "20: node über mise" 'node 26.* \(mise\) bereits vorhanden|\[dry-run\] mise use -g node@26'
  expect "20: claude-code" '@anthropic-ai/claude-code (bereits vorhanden|wird installiert)'
  expect "20: codex" '@openai/codex (bereits vorhanden|wird installiert)'
}

test_30_git() {
  dry --only 30
  expect_rc "30: Exit 0" 0
  expect "30: user.name" '\[dry-run\] git config --global user.name|git kommt aus Schritt 10'
  expect "30: autocrlf" '\[dry-run\] git config --global core.autocrlf input|git kommt aus Schritt 10'
  expect_not "30: keine E-Mail im Klartext" 'smoke@example.invalid'
}

test_40_vscode() {
  dry --only 40
  expect_rc "40: Exit 0" 0
  expect "40: Extension geplant" 'Extension anthropic\.claude-code wird installiert'
  expect_not "40: keine Windows-Extension auf macOS" 'remote-wsl'
}

test_50_docker() {
  dry --only 50
  expect_rc "50: Exit 0" 0
  expect "50: Docker" 'Docker läuft bereits|\[dry-run\] open -a Docker'
}

test_60_ssh() {
  dry --only 60
  expect_rc "60: Exit 0" 0
  expect "60: Key-Erzeugung" '\[dry-run\] _step60_keygen'
  expect "60: ssh config" 'config: Block github wird eingetragen'
  expect "60: known_hosts" '\[dry-run\] _step60_known_hosts'
}

test_90_auth() {
  dry --only 90
  expect_rc "90: Exit 0" 0
  expect "90: non-interactive überspringt Logins" 'Logins übersprungen'
}

test_flags() {
  dry
  expect_rc "voller Dry-Run: Exit 0" 0
  expect "voller Dry-Run: Zeitmessung" 'gesamt +[0-9]+s'
  expect "Vorabprüfung: bash" '✔ bash +3\.2|✔ bash +[4-9]'
  expect "Vorabprüfung: Architektur" '✔ Architektur'

  dry --only 30 --skip 30
  expect_not "--skip schlägt --only" '── 30-git'
  dry --gibt-es-nicht
  expect_rc "unbekannte Option: Exit 2" 2
}

test_10_packages
test_20_toolchain
test_30_git
test_40_vscode
test_50_docker
test_60_ssh
test_90_auth
test_flags

echo
if [ "$FAILS" -eq 0 ]; then echo "✔ Smoke-Tests sauber"; else echo "✘ $FAILS Smoke-Test(s) fehlgeschlagen"; fi
[ "$FAILS" -eq 0 ]
