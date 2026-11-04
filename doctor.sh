#!/usr/bin/env bash
# kickoff doctor (macOS) – Statusreport. Ändert nichts. Exit 0 nur, wenn alles grün ist.
set -Eeuo pipefail

KICKOFF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$KICKOFF_ROOT/lib/common.sh"
load_env_paths

FAILED=0
NODE_MAJOR="$(sed -nE 's/^node[[:space:]]*=[[:space:]]*"?([0-9]+).*/\1/p' "$KICKOFF_ROOT/manifests/mise.toml")"
CODE_APP_CLI="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

# row <Komponente> <Soll> <Ist> <ok|fail> [Befehl, der die Zeile grün macht]
row() {
  local status="✔" hint=""
  if [ "$4" != "ok" ]; then
    status="✘"
    hint="  $5"
    FAILED=1
  fi
  printf '%s %s %s %s%s\n' "$(pad "$1" 17)" "$(pad "$2" 11)" "$(pad "${3:-–}" 12)" "$status" "$hint" | mask_secrets
}

# pad <text> <breite> – nach Zeichen auffüllen (printf in Bash 3.2 zählt Bytes, nicht Zeichen).
pad() {
  local LC_ALL=en_US.UTF-8 s="$1" n
  n=$(( $2 - ${#s} ))
  [ "$n" -gt 0 ] || n=0
  printf '%s%*s' "$s" "$n" ''
}

# ver_ge <ist> <soll> – numerischer Versionsvergleich (Bash 3.2, ohne sort -V).
ver_ge() {
  local IFS=. i a b
  # shellcheck disable=SC2206 # gewolltes Aufteilen an Punkten
  local have=($1) want=($2)
  for i in 0 1 2; do
    a="${have[$i]:-0}"; b="${want[$i]:-0}"
    a="${a%%[!0-9]*}"; b="${b%%[!0-9]*}"
    [ "${a:-0}" -gt "${b:-0}" ] && return 0
    [ "${a:-0}" -lt "${b:-0}" ] && return 1
  done
  return 0
}

ver_of() { "$@" 2>/dev/null | head -n1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || true; }

printf '%s %s %s %s\n' "$(pad Komponente 17)" "$(pad Soll 11)" "$(pad Ist 12)" "Status"

# Homebrew
if has_cmd brew; then row "Homebrew" "vorhanden" "$(ver_of brew --version)" ok
else row "Homebrew" "vorhanden" "" fail "curl -fsSL https://raw.githubusercontent.com/leonkoellerwirth-arch/init-ai-workspace/main/bootstrap.sh | bash"; fi

# git
v=""; has_cmd git && v="$(ver_of git --version)"
if [ -n "$v" ] && ver_ge "$v" 2.40; then row "git" "≥ 2.40" "$v" ok
else row "git" "≥ 2.40" "$v" fail "brew install git"; fi

# gh
v=""; has_cmd gh && v="$(ver_of gh --version)"
if [ -n "$v" ]; then row "gh" "vorhanden" "$v" ok; else row "gh" "vorhanden" "" fail "brew install gh"; fi

# mise
v=""; has_cmd mise && v="$(ver_of mise --version)"
if [ -n "$v" ]; then row "mise" "vorhanden" "$v" ok; else row "mise" "vorhanden" "" fail "brew install mise"; fi

# node über mise
v=""; if has_cmd mise; then v="$(cd "$HOME" || exit 0; mise current node 2>/dev/null || true)"; fi
case "$v" in
  "$NODE_MAJOR" | "$NODE_MAJOR".*) row "node (mise)" "$NODE_MAJOR.x" "$v" ok ;;
  *) row "node (mise)" "$NODE_MAJOR.x" "$v" fail "mise use -g node@$NODE_MAJOR" ;;
esac

# Claude Code, Codex
v=""; has_cmd claude && v="$(ver_of claude --version)"
if [ -n "$v" ]; then row "claude" "vorhanden" "$v" ok; else row "claude" "vorhanden" "" fail "npm i -g @anthropic-ai/claude-code"; fi
v=""; has_cmd codex && v="$(ver_of codex --version)"
if [ -n "$v" ]; then row "codex" "vorhanden" "$v" ok; else row "codex" "vorhanden" "" fail "npm i -g @openai/codex"; fi

# VS Code
if has_cmd code; then row "code" "im PATH" "$(ver_of code --version)" ok
elif [ -x "$CODE_APP_CLI" ]; then row "code" "im PATH" "nicht im PATH" fail "ln -sf \"$CODE_APP_CLI\" \"$(brew --prefix 2>/dev/null || echo /usr/local)/bin/code\""
else row "code" "im PATH" "" fail "brew install --cask visual-studio-code"; fi

# Docker
if ! has_cmd docker && [ ! -d /Applications/Docker.app ]; then row "docker" "läuft" "" fail "brew install --cask docker-desktop"
elif docker info >/dev/null 2>&1; then row "docker" "läuft" "$(ver_of docker --version)" ok
else row "docker" "läuft" "gestoppt" fail "open -a Docker"; fi

# Git-Identität
if [ -n "$(git config --global --get user.name 2>/dev/null || true)" ] && [ -n "$(git config --global --get user.email 2>/dev/null || true)" ]; then
  row "Git-Identität" "gesetzt" "ja" ok
else
  row "Git-Identität" "gesetzt" "nein" fail "bash \"$KICKOFF_ROOT/bootstrap.sh\" --only 30"
fi

# GitHub-Login
if has_cmd gh && gh auth status >/dev/null 2>&1; then row "GitHub-Login" "ja" "ja" ok
else row "GitHub-Login" "ja" "nein" fail "gh auth login --git-protocol ssh --web"; fi

# SSH → GitHub: Exit 1 mit Begrüßung gilt als Erfolg. Read-only: unbekannter Host-Key = rot.
ssh_out="$(ssh -T -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes git@github.com 2>&1 || true)"
case "$ssh_out" in
  *"successfully authenticated"*) row "SSH → GitHub" "ja" "ja" ok ;;
  *) row "SSH → GitHub" "ja" "nein" fail "bash \"$KICKOFF_ROOT/bootstrap.sh\" --only 60 --only 90" ;;
esac

exit "$FAILED"
