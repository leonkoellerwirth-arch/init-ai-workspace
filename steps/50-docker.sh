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
  if [ "$(sysctl -n kern.hv_vmm_present 2>/dev/null || echo 0)" = "1" ]; then
    warn "Docker antwortet nach ${KICKOFF_DOCKER_TIMEOUT} s noch nicht. Dieser Mac ist eine VM – Docker Desktop braucht dort verschachtelte Virtualisierung (Apple M3+ als Host). Auf echter Hardware: ./bootstrap.sh --only 50"
  else
    warn "Docker antwortet nach ${KICKOFF_DOCKER_TIMEOUT} s noch nicht. Beim ersten Start will Docker Desktop eine Bestätigung im Fenster – danach: ./bootstrap.sh --only 50"
  fi
}

step_50_docker
