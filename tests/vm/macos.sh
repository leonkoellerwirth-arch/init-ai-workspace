#!/usr/bin/env bash
# Ende-zu-Ende-Test auf einem frischen macOS in einer Tart-VM (Apple Silicon).
#   tests/vm/macos.sh [--keep] [--ref <branch>]
# Voraussetzung: tart und eine Basis-VM aus einem vanilla-Image, z. B.
#   tart clone ghcr.io/cirruslabs/macos-tahoe-vanilla:latest kickoff-base
# Ablauf: frische Kopie der Basis → Bootstrap über den echten curl|bash-Einstieg (non-interactive)
# → zweiter Lauf (Idempotenz + Laufzeit) → doctor → Kopie löschen (außer mit --keep).
# Hinweis: Docker Desktop startet in der VM nur auf M3+ (nested virtualization); auf M1/M2 ist
# die docker-Zeile im doctor deshalb erwartbar rot.
set -euo pipefail

BASE="${KICKOFF_VM_BASE:-kickoff-base}"
VM="kickoff-run"
REPO="${KICKOFF_REPO:-leonkoellerwirth-arch/init-ai-workspace}"
REF="main"
KEEP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --keep) KEEP=1 ;;
    --ref) REF="$2"; shift ;;
    *) echo "Unbekannte Option: $1" >&2; exit 2 ;;
  esac
  shift
done

command -v tart >/dev/null || { echo "✘ tart fehlt: https://tart.run" >&2; exit 1; }
tart list --quiet 2>/dev/null | grep -qx "$BASE" || {
  echo "✘ Basis-VM $BASE fehlt: tart clone ghcr.io/cirruslabs/macos-tahoe-vanilla:latest $BASE" >&2; exit 1; }

WORK="$(mktemp -d)"
KEY="$WORK/id_ed25519"
RESULT="$WORK/result"
mkdir -p "$RESULT"

cleanup() {
  if [ "$KEEP" = "0" ]; then
    tart stop "$VM" >/dev/null 2>&1 || true
    tart delete "$VM" >/dev/null 2>&1 || true
  else
    echo "  VM bleibt erhalten: tart run $VM (Login admin/admin)"
  fi
}
trap cleanup EXIT

echo "➜ Frische VM $VM aus $BASE"
tart stop "$VM" >/dev/null 2>&1 || true
tart delete "$VM" >/dev/null 2>&1 || true
tart clone "$BASE" "$VM"
tart run "$VM" --no-graphics >"$WORK/tart.log" 2>&1 &
IP="$(tart ip "$VM" --wait 180)"
echo "  IP: $IP"

# SSH-Zugang: Testkey einmal per Passwort (admin/admin der vanilla-Images) hinterlegen.
ssh-keygen -q -t ed25519 -N "" -f "$KEY"
SSH_OPTS=(-i "$KEY" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=10)
PUB="$(cat "$KEY.pub")"
# Ohne ssh-copy-id: das hängt unter expect. Feste Zeitgrenze je Versuch, bis sshd in der VM bereit ist.
for _ in $(seq 1 30); do
  if expect -c "
      set timeout 30
      spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PubkeyAuthentication=no -o ConnectTimeout=10 admin@$IP {mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$PUB' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo KEY_OK}
      expect {
        -re {[Pp]assword:} { send \"admin\r\"; exp_continue }
        KEY_OK { exit 0 }
        timeout { exit 1 }
        eof { exit 1 }
      }" >/dev/null 2>&1; then
    break
  fi
  sleep 5
done
# Befehle werden bewusst lokal zusammengesetzt und als ein String an die VM übergeben.
# shellcheck disable=SC2029
vm() { ssh "${SSH_OPTS[@]}" "admin@$IP" "$@"; }
vm true || { echo "✘ SSH in die VM klappt nicht" >&2; exit 1; }
echo "  macOS in der VM: $(vm sw_vers -productVersion), sudo ohne Passwort: $(vm 'sudo -n true 2>/dev/null && echo ja || echo nein')"

# Genau der Einstiegsbefehl aus der README – nur non-interactive und mit Testidentität.
ENTRY="curl -fsSL https://raw.githubusercontent.com/$REPO/$REF/bootstrap.sh | KICKOFF_REF=$REF KICKOFF_GIT_NAME='kickoff VM' KICKOFF_GIT_EMAIL='vm@example.invalid' bash -s -- --non-interactive"

run_pass() {
  local n="$1" start end rc=0
  echo "➜ Lauf $n"
  start="$(date +%s)"
  vm "zsh -lc \"$ENTRY\"" >"$RESULT/run$n.log" 2>&1 || rc=$?
  end="$(date +%s)"
  echo "  Lauf $n: Exit $rc, $((end - start)) s"
  eval "RC$n=$rc; SECS$n=$((end - start))"
}

run_pass 1
run_pass 2

# "➜ Lade kickoff" ist der Download des Einstiegs, keine Änderung am System.
CHANGES2="$(grep '➜' "$RESULT/run2.log" | grep -vc 'Lade kickoff' || true)"
echo
echo "── doctor nach Lauf 2"
vm 'zsh -lc "bash ~/.kickoff/src/doctor.sh"' | tee "$RESULT/doctor.log" || true

cp -R "$RESULT" "${KICKOFF_VM_RESULTS:-$PWD/vm-results}"
echo
echo "Ergebnis"
echo "  Lauf 1: Exit $RC1, $SECS1 s"
echo "  Lauf 2: Exit $RC2, $SECS2 s, geplante Änderungen (➜): $CHANGES2"
echo "  Logs:   ${KICKOFF_VM_RESULTS:-$PWD/vm-results}/"
