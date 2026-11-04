#!/usr/bin/env bash
# shellcheck shell=bash
# 50-docker – Docker Desktop starten, bis `docker info` antwortet (max. 120 s, keine Endlosschleife).
# Installiert wird Docker Desktop in Schritt 10 (Brewfile). Wird von bootstrap.sh dot-gesourct.

KICKOFF_DOCKER_TIMEOUT="${KICKOFF_DOCKER_TIMEOUT:-120}"

step_50_docker() {
  load_env_paths
  if has_cmd docker && docker info >/dev/null 2>&1; then
    ok "Docker läuft bereits"
    return 0
  fi

  if [ ! -d /Applications/Docker.app ]; then
    doing "Docker Desktop wird installiert"
    run brew install --cask docker-desktop
  fi

  doing "Docker Desktop wird gestartet"
  run open -a Docker
  if is_dry_run; then
    info "[dry-run] warten, bis docker info antwortet (max. ${KICKOFF_DOCKER_TIMEOUT} s)"
    return 0
  fi

  local waited=0
  while [ "$waited" -lt "$KICKOFF_DOCKER_TIMEOUT" ]; do
    if has_cmd docker && docker info >/dev/null 2>&1; then
      ok "Docker läuft (nach ${waited} s)"
      return 0
    fi
    sleep 3
    waited=$((waited + 3))
    load_env_paths
  done
  warn "Docker antwortet nach ${KICKOFF_DOCKER_TIMEOUT} s noch nicht. Beim ersten Start will Docker Desktop eine Bestätigung im Fenster – danach: ./bootstrap.sh --only 50"
}

step_50_docker
