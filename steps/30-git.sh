#!/usr/bin/env bash
# shellcheck shell=bash
# 30-git – globale Git-Konfiguration aus config/git/gitconfig.template (Key für Key gemerged).
# Wird von bootstrap.sh dot-gesourct; nutzt lib/common.sh.

# _step30_identity <key> <env-wert> <frage> – Name/E-Mail bestimmen (Env > Abfrage mit Vorschlag > bestehend).
_step30_identity() {
  local key="$1" from_env="$2" question="$3" existing answer
  existing="$(git config --global --get "$key" 2>/dev/null || true)"
  if [ -n "$from_env" ]; then
    printf '%s' "$from_env"
  elif state_has git-identity && [ -n "$existing" ]; then
    printf '%s' "$existing"
  else
    answer="$(ask "$question" "$existing")"
    printf '%s' "$answer"
  fi
}

# Template mit Name/E-Mail füllen.
_step30_render() {
  # Wörtliche Ersetzung: in gsub() hätte "&" im Namen eine Sonderbedeutung.
  KO_NAME="$1" KO_EMAIL="$2" awk '
    function lit(s, ph, val,   i) {
      while ((i = index(s, ph)) > 0) s = substr(s, 1, i - 1) val substr(s, i + length(ph))
      return s
    }
    { print lit(lit($0, "{{NAME}}", ENVIRON["KO_NAME"]), "{{EMAIL}}", ENVIRON["KO_EMAIL"]) }
  ' "$KICKOFF_ROOT/config/git/gitconfig.template"
}

# "section.key=wert" je Zeile, Schreibweise der Keys wie im Template (git config --list schreibt klein).
_step30_pairs() {
  awk '
    /^[[:space:]]*[#;]/ || NF == 0 { next }
    /^[[:space:]]*\[/ { sec = $0; gsub(/[][[:space:]]/, "", sec); next }
    {
      line = $0; i = index(line, "=")
      k = substr(line, 1, i - 1); v = substr(line, i + 1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", k); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      print sec "." k "=" v
    }' "$1"
}

# _step30_set <key> <wert> – nur bei Abweichung setzen.
_step30_set() {
  local key="$1" value="$2" current
  current="$(git config --global --get "$key" 2>/dev/null || true)"
  if [ "$current" = "$value" ]; then
    ok "git $key bereits gesetzt"
    return 0
  fi
  doing "git $key wird gesetzt"
  backup_file "$HOME/.gitconfig"
  run git config --global "$key" "$value"
}

step_30_git() {
  load_env_paths
  if ! has_cmd git; then
    is_dry_run || die "git fehlt." "./bootstrap.sh --only 10"
    info "git kommt aus Schritt 10 (Brewfile); Konfiguration wird beim echten Lauf gesetzt."
    return 0
  fi

  local name email
  name="$(_step30_identity user.name "${KICKOFF_GIT_NAME:-}" "Git-Name")"
  email="$(_step30_identity user.email "${KICKOFF_GIT_EMAIL:-}" "Git-E-Mail")"
  if [ -z "$name" ] || [ -z "$email" ]; then
    if is_dry_run; then
      name="${name:-<name>}"; email="${email:-<email>}"
    else
      die "Git-Name oder -E-Mail fehlt." "KICKOFF_GIT_NAME und KICKOFF_GIT_EMAIL setzen oder ohne --non-interactive starten."
    fi
  fi

  local tmp line key value
  tmp="$(mktemp)"
  _step30_render "$name" "$email" >"$tmp"
  while IFS= read -r line; do
    key="${line%%=*}"; value="${line#*=}"
    _step30_set "$key" "$value"
  done < <(_step30_pairs "$tmp")
  rm -f "$tmp"

  _step30_set core.autocrlf input

  if git config --global --get-all credential.helper 2>/dev/null | grep -qx osxkeychain; then
    ok "git credential.helper osxkeychain bereits gesetzt"
  else
    doing "git credential.helper osxkeychain wird gesetzt"
    backup_file "$HOME/.gitconfig"
    run git config --global --add credential.helper osxkeychain
  fi

  state_set git-identity
}

step_30_git
