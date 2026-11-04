#!/usr/bin/env bash
# shellcheck shell=bash
# 40-vscode – Extensions aus config/vscode/extensions.txt, Settings-Merge (bestehende Keys gewinnen).
# Wird von bootstrap.sh dot-gesourct; nutzt lib/common.sh.

KICKOFF_VSCODE_APP_CLI="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
KICKOFF_VSCODE_SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"

# Pfad zur code-CLI; nach einer frischen Cask-Installation ist `code` oft noch nicht im PATH.
_step40_code() {
  if has_cmd code; then command -v code
  elif [ -x "$KICKOFF_VSCODE_APP_CLI" ]; then printf '%s' "$KICKOFF_VSCODE_APP_CLI"
  fi
}

# Extension-IDs für macOS (Kommentare und fremde Plattformen ausgefiltert).
_step40_extensions() {
  awk '{ sub(/#.*/, "") } NF == 0 { next } NF == 1 || $2 == "macos" { print tolower($1) }' \
    "$KICKOFF_ROOT/config/vscode/extensions.txt"
}

step_40_vscode() {
  local code
  code="$(_step40_code)"
  if [ -z "$code" ]; then
    is_dry_run || die "VS Code (code-CLI) nicht gefunden." "./bootstrap.sh --only 10"
    info "VS Code kommt aus Schritt 10 (Brewfile)."
    code="code"
  fi

  local installed="" ext
  if [ "$code" != "code" ] || has_cmd code; then
    installed="$("$code" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"
  fi
  while IFS= read -r ext; do
    if case $'\n'"$installed"$'\n' in *$'\n'"$ext"$'\n'*) true ;; *) false ;; esac; then
      ok "Extension $ext bereits vorhanden"
    else
      doing "Extension $ext wird installiert"
      run "$code" --install-extension "$ext"
    fi
  done < <(_step40_extensions)

  # Settings-Merge per node (Schritt 20); fehlende Keys ergänzen, bestehende gewinnen.
  local defaults="$KICKOFF_ROOT/config/vscode/settings.json" rc=0 missing
  if ! has_cmd node; then
    is_dry_run || die "node fehlt für den Settings-Merge." "./bootstrap.sh --only 20"
    info "Settings-Merge braucht node aus Schritt 20."
    return 0
  fi
  missing="$(json_merge "$KICKOFF_VSCODE_SETTINGS" "$defaults" check)" || rc=$?
  case "$rc" in
    0)  ok "VS-Code-Settings bereits vorhanden" ;;
    10) doing "VS-Code-Settings werden ergänzt: $missing"
        backup_file "$KICKOFF_VSCODE_SETTINGS"
        if ! is_dry_run; then mkdir -p "$(dirname "$KICKOFF_VSCODE_SETTINGS")"; fi
        run _step40_merge "$defaults" ;;
    20) warn "VS-Code-settings.json enthält Kommentare o. Ä. und wird nicht automatisch geändert. Fehlende Keys bitte aus $defaults übernehmen." ;;
    *)  die "Settings-Merge fehlgeschlagen (Exit $rc)." "node -v prüfen und erneut starten." ;;
  esac
}

# Exit 10 heißt beim Schreiben „geändert" – für run ist das Erfolg.
_step40_merge() {
  local rc=0
  json_merge "$KICKOFF_VSCODE_SETTINGS" "$1" write || rc=$?
  [ "$rc" -eq 0 ] || [ "$rc" -eq 10 ]
}

step_40_vscode
