#!/usr/bin/env bash
# shellcheck shell=bash
# 90-auth – geführte Logins (GitHub + SSH-Key-Upload, Claude, Codex). Immer zuletzt, immer interaktiv.
# Speichert nichts im Repo. Wird von bootstrap.sh dot-gesourct.

# _step90_confirm <was> – 0 = weiter, 1 = übersprungen (Taste s).
_step90_confirm() {
  local answer=""
  is_dry_run && return 0
  printf '? %s – Enter = weiter, s = überspringen: ' "$1" >/dev/tty
  IFS= read -r answer </dev/tty || answer="s"
  case "$answer" in
    s | S) info "$1 übersprungen"; return 1 ;;
    *) return 0 ;;
  esac
}

_step90_github() {
  if has_cmd gh && gh auth status >/dev/null 2>&1; then
    ok "GitHub-Login bereits vorhanden"
  elif _step90_confirm "GitHub-Login (Browser)"; then
    doing "GitHub-Login wird gestartet"
    run_visible gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key --scopes admin:public_key
  else
    return 0
  fi

  local pub="$HOME/.ssh/id_ed25519.pub" body keys
  if [ ! -f "$pub" ]; then
    is_dry_run || warn "Kein SSH-Key gefunden – Upload übersprungen. Behebung: ./bootstrap.sh --only 60 --only 90"
    return 0
  fi
  if is_dry_run && ! gh auth status >/dev/null 2>&1; then
    run gh ssh-key add "$pub" --title "kickoff-$(hostname -s)-$(date +%Y-%m-%d)"
    return 0
  fi
  body="$(awk '{print $2}' "$pub")"
  if ! keys="$(gh api user/keys --jq '.[].key' 2>/dev/null)"; then
    doing "GitHub-Berechtigung für SSH-Keys wird ergänzt"
    run_visible gh auth refresh --hostname github.com --scopes admin:public_key
    keys="$(gh api user/keys --jq '.[].key' 2>/dev/null || true)"
  fi
  case "$keys" in
    *"$body"*) ok "SSH-Key bereits bei GitHub hinterlegt" ;;
    *)
      doing "SSH-Key wird zu GitHub hochgeladen"
      run gh ssh-key add "$pub" --title "kickoff-$(hostname -s)-$(date +%Y-%m-%d)" ;;
  esac

  is_dry_run && return 0
  # Exit 1 mit Begrüßung gilt als Erfolg.
  local out
  out="$(ssh -T -o BatchMode=yes -o ConnectTimeout=10 git@github.com 2>&1 || true)"
  case "$out" in
    *"successfully authenticated"*) ok "SSH → GitHub funktioniert" ;;
    *) warn "SSH → GitHub antwortet noch nicht wie erwartet. Prüfen: ssh -T git@github.com" ;;
  esac
}

_step90_claude() {
  local status=""
  if has_cmd claude; then status="$(claude auth status 2>/dev/null || true)"; fi
  if case "$status" in *'"loggedIn": true'*) true ;; *) false ;; esac; then
    ok "Claude-Login bereits vorhanden"
  elif _step90_confirm "Claude-Login"; then
    info "Es öffnet sich ein Browserfenster für den Anthropic-Login."
    run_visible claude auth login
  fi
}

_step90_codex() {
  if has_cmd codex && codex login status >/dev/null 2>&1; then
    ok "Codex-Login bereits vorhanden"
  elif _step90_confirm "Codex-Login"; then
    info "Es öffnet sich ein Browserfenster für den OpenAI-Login."
    run_visible codex login
  fi
}

step_90_auth() {
  if ! is_interactive; then
    info "Logins übersprungen (--non-interactive). Später nachholen: ./bootstrap.sh --only 90"
    return 0
  fi
  load_env_paths
  _step90_github
  _step90_claude
  _step90_codex
}

step_90_auth
