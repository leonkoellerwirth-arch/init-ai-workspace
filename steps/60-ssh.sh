#!/usr/bin/env bash
# shellcheck shell=bash
# 60-ssh – ed25519-Key, Keychain-Agent, ~/.ssh/config, GitHub-Host-Keys.
# Der Upload zu GitHub passiert erst in Schritt 90 nach `gh auth login`. Wird von bootstrap.sh dot-gesourct.

KICKOFF_SSH_KEY="$HOME/.ssh/id_ed25519"

# GitHub-Host-Keys über HTTPS (api.github.com/meta) holen statt blind ssh-keyscan zu vertrauen.
_step60_known_hosts() {
  local keys
  keys="$(curl -fsSL https://api.github.com/meta | node -e '
    let d = ""; process.stdin.on("data", c => d += c).on("end", () => {
      for (const k of JSON.parse(d).ssh_keys || []) console.log("github.com " + k);
    });')" || return 1
  [ -n "$keys" ] || return 1
  mkdir -p "$HOME/.ssh"
  printf '%s\n' "$keys" >>"$HOME/.ssh/known_hosts"
  chmod 600 "$HOME/.ssh/known_hosts"
}

_step60_keygen() {
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  ssh-keygen -q -t ed25519 -C "$1" -f "$KICKOFF_SSH_KEY" -N ""
}

step_60_ssh() {
  load_env_paths
  local email
  email="$(git config --global --get user.email 2>/dev/null || true)"

  if [ -f "$KICKOFF_SSH_KEY" ]; then
    ok "SSH-Key $KICKOFF_SSH_KEY bereits vorhanden"
  else
    [ -n "$email" ] || is_dry_run || die "Für den SSH-Key fehlt die Git-E-Mail." "./bootstrap.sh --only 30"
    doing "SSH-Key (ed25519) wird erzeugt"
    if is_interactive; then
      # Interaktiv fragt ssh-keygen selbst nach einer Passphrase (Enter = keine).
      if ! is_dry_run; then mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"; fi
      run_visible ssh-keygen -t ed25519 -C "${email:-<email>}" -f "$KICKOFF_SSH_KEY"
    else
      run _step60_keygen "${email:-<email>}"
    fi
  fi

  # shellcheck disable=SC2088 # ~ wertet ssh selbst aus
  ensure_block "$HOME/.ssh/config" github 'Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
Host *'

  local fp="" agent_keys agent_rc=0
  if [ -f "$KICKOFF_SSH_KEY.pub" ]; then fp="$(ssh-keygen -lf "$KICKOFF_SSH_KEY.pub" | awk '{print $2}')"; fi
  agent_keys="$(ssh-add -l 2>/dev/null)" || agent_rc=$?
  if [ "$agent_rc" -eq 2 ]; then
    # Exit 2 = kein Agent erreichbar (z. B. per SSH angemeldet). Kein Fehler: AddKeysToAgent im
    # github-Block lädt den Key beim ersten Gebrauch in den Agent und die Keychain.
    info "Kein ssh-agent in dieser Sitzung – der Key wird beim ersten Gebrauch automatisch geladen (AddKeysToAgent)."
  elif [ -n "$fp" ] && case "$agent_keys" in *"$fp"*) true ;; *) false ;; esac; then
    ok "SSH-Key bereits im Agent"
  else
    doing "SSH-Key wird dem Agent (Keychain) hinzugefügt"
    if is_interactive; then
      run_visible ssh-add --apple-use-keychain "$KICKOFF_SSH_KEY"
    else
      run ssh-add --apple-use-keychain "$KICKOFF_SSH_KEY"
    fi
  fi

  if [ -f "$HOME/.ssh/known_hosts" ] && ssh-keygen -F github.com -f "$HOME/.ssh/known_hosts" >/dev/null 2>&1; then
    ok "GitHub-Host-Keys bereits in known_hosts"
  else
    doing "GitHub-Host-Keys werden in known_hosts eingetragen"
    backup_file "$HOME/.ssh/known_hosts"
    run _step60_known_hosts
  fi
}

step_60_ssh
