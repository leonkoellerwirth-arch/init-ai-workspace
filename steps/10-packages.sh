#!/usr/bin/env bash
# shellcheck shell=bash
# 10-packages – Homebrew (inkl. Xcode Command Line Tools) und alle Pakete aus manifests/Brewfile.
# Wird von bootstrap.sh dot-gesourct; nutzt lib/common.sh.

_step10_install_homebrew() {
  # Der offizielle Installer holt die Xcode CLT selbst; NONINTERACTIVE braucht gecachtes sudo.
  local script
  script="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
  NONINTERACTIVE=1 /bin/bash -c "$script"
}

step_10_packages() {
  local brewfile="$KICKOFF_ROOT/manifests/Brewfile"

  load_env_paths
  if has_cmd brew; then
    ok "Homebrew bereits vorhanden"
  else
    doing "Homebrew wird installiert (inkl. Xcode Command Line Tools)"
    if ! is_dry_run; then
      is_interactive || sudo -n true 2>/dev/null ||
        die "Homebrew braucht einmalig Administratorrechte." "Ohne --non-interactive starten oder vorher 'sudo -v' ausführen."
      is_interactive && run_visible sudo -v
    fi
    run _step10_install_homebrew
    load_env_paths
    is_dry_run || has_cmd brew || die "Homebrew ist nach der Installation nicht auffindbar." "Log prüfen; Homebrew-Installer manuell erneut starten."
  fi

  # shellcheck disable=SC2016 # $(…) gehört in die Profildatei, nicht in diese Shell
  ensure_block "$HOME/.zprofile" brew 'eval "$('"$(brew_prefix_hint)"'/bin/brew shellenv)"'

  # Casks, deren App schon (ohne brew) installiert ist, nicht erneut installieren –
  # brew würde sonst an der vorhandenen App scheitern.
  local skip="${HOMEBREW_BUNDLE_CASK_SKIP:-}" cask app
  while IFS='|' read -r cask app; do
    if [ -d "/Applications/$app" ] && ! brew_has_cask "$cask"; then
      ok "$app bereits vorhanden (ohne brew installiert)"
      skip="${skip:+$skip }$cask"
    fi
  done < <(sed -nE 's/^cask "([^"]+)".*# app: (.+)$/\1|\2/p' "$brewfile")

  if ! is_dry_run || has_cmd brew; then
    if HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_BUNDLE_CASK_SKIP="$skip" brew bundle check --file="$brewfile" >/dev/null 2>&1; then
      ok "Pakete aus Brewfile bereits vorhanden"
      return 0
    fi
  fi
  doing "Pakete aus Brewfile werden installiert"
  run env HOMEBREW_BUNDLE_CASK_SKIP="$skip" brew bundle install --file="$brewfile" --no-upgrade
}

brew_has_cask() { has_cmd brew && brew list --cask "$1" >/dev/null 2>&1; }

# /opt/homebrew auf Apple Silicon, /usr/local auf Intel.
brew_prefix_hint() {
  if [ "$(uname -m)" = "arm64" ]; then echo /opt/homebrew; else echo /usr/local; fi
}

step_10_packages
