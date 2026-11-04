#!/usr/bin/env bash
# shellcheck shell=bash
# 20-toolchain – mise, Node aus manifests/mise.toml, globale npm-Pakete, Shell-Hooks.
# Wird von bootstrap.sh dot-gesourct; nutzt lib/common.sh.

# CI setzt KICKOFF_NPM_GLOBALS="" (echte Installationen dort nur für git, gh, mise, node).
KICKOFF_NPM_GLOBALS="${KICKOFF_NPM_GLOBALS-@anthropic-ai/claude-code @openai/codex}"

# Gibt "tool version" je Zeile aus dem [tools]-Abschnitt von mise.toml aus.
_step20_tools() {
  awk '
    /^\[/ { section = $0; next }
    section == "[tools]" && /=/ {
      line = $0; sub(/#.*/, "", line)
      split(line, kv, "="); k = kv[1]; v = kv[2]
      gsub(/[ \t"]/, "", k); gsub(/[ \t"]/, "", v)
      if (k != "") print k, v
    }' "$KICKOFF_ROOT/manifests/mise.toml"
}

# Befehl, den ein npm-Paket bereitstellt.
_step20_bin() {
  case "$1" in
    @anthropic-ai/claude-code) echo claude ;;
    @openai/codex) echo codex ;;
  esac
}

step_20_toolchain() {
  load_env_paths
  if has_cmd mise; then
    ok "mise bereits vorhanden"
  elif is_dry_run; then
    info "mise kommt aus Schritt 10 (Brewfile)."
  else
    die "mise fehlt." "./bootstrap.sh --only 10"
  fi

  # Shell-Hooks: mise in zsh und bash aktivieren, Aliase laden.
  local shell_dir="$KICKOFF_HOME/shell"
  if ! is_dry_run; then mkdir -p "$shell_dir"; fi
  if ! cmp -s "$KICKOFF_ROOT/config/shell/aliases.sh" "$shell_dir/aliases.sh" 2>/dev/null; then
    doing "Aliase werden nach $shell_dir kopiert"
    run cp "$KICKOFF_ROOT/config/shell/aliases.sh" "$shell_dir/aliases.sh"
  else
    ok "Aliase bereits vorhanden"
  fi
  # shellcheck disable=SC2016 # $(…) gehört in die Profildatei, nicht in diese Shell
  ensure_block "$HOME/.zshrc" mise 'command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"
[ -f "$HOME/.kickoff/shell/aliases.sh" ] && . "$HOME/.kickoff/shell/aliases.sh"'
  # bash nur, wenn ~/.bash_profile schon existiert – eine neue Datei würde ~/.profile verdecken.
  if [ -f "$HOME/.bash_profile" ]; then
    # shellcheck disable=SC2016
    ensure_block "$HOME/.bash_profile" mise 'command -v mise >/dev/null 2>&1 && eval "$(mise activate bash)"
[ -f "$HOME/.kickoff/shell/aliases.sh" ] && . "$HOME/.kickoff/shell/aliases.sh"'
  fi

  # Toolchain-Versionen global setzen (mise use -g ergänzt ~/.config/mise/config.toml, ersetzt sie nicht).
  local tool version current
  while read -r tool version; do
    current=""
    if has_cmd mise; then current="$(cd "$HOME" || exit 0; mise current "$tool" 2>/dev/null || true)"; fi
    case "$current" in
      "$version" | "$version".*)
        ok "$tool $current (mise) bereits vorhanden" ;;
      *)
        doing "$tool $version (mise) wird installiert"
        run mise use -g "$tool@$version" ;;
    esac
  done < <(_step20_tools)
  load_env_paths

  # Globale npm-Pakete. Paketname wird vorher geprüft – nie raten (Spec §5).
  local pkg
  local bin
  for pkg in $KICKOFF_NPM_GLOBALS; do
    # Ist der Befehl schon da (z. B. über einen anderen Installer), nicht doppelt installieren.
    bin="$(_step20_bin "$pkg")"
    if [ -n "$bin" ] && has_cmd "$bin"; then
      ok "$pkg bereits vorhanden ($bin)"
      continue
    fi
    if has_cmd npm && npm ls -g --depth=0 "$pkg" >/dev/null 2>&1; then
      ok "$pkg bereits vorhanden"
      continue
    fi
    if has_cmd npm; then
      npm view "$pkg" version >/dev/null 2>&1 ||
        die "npm-Paket $pkg existiert nicht oder die Registry ist nicht erreichbar." "Netzwerk prüfen: npm view $pkg version"
    fi
    doing "$pkg wird installiert"
    run npm install -g "$pkg"
  done
  if has_cmd mise && ! is_dry_run; then run mise reshim; fi
}

step_20_toolchain
