#!/usr/bin/env bash
# kickoff – macOS-Einstieg.
#   curl -fsSL https://raw.githubusercontent.com/leonkoellerwirth-arch/init-ai-workspace/main/bootstrap.sh | bash
#   curl -fsSL …/bootstrap.sh | bash -s -- --dry-run
set -Eeuo pipefail

KICKOFF_REPO="${KICKOFF_REPO:-leonkoellerwirth-arch/init-ai-workspace}"
KICKOFF_REF="${KICKOFF_REF:-main}"

usage() {
  cat <<'EOF'
Verwendung: bootstrap.sh [Optionen]

  --dry-run           nur anzeigen, nichts ausführen
  --only <step>       nur diesen Schritt (wiederholbar; z. B. 30 oder 30-git)
  --skip <step>       diesen Schritt auslassen (wiederholbar)
  --non-interactive   keine Prompts; Name/E-Mail aus KICKOFF_GIT_NAME / KICKOFF_GIT_EMAIL, Auth wird übersprungen
  --doctor            nur den Statusreport
  -h, --help          diese Hilfe
EOF
}

# ---------------------------------------------------------------------------
# Pipe-Modus: ohne lokale Kopie das Repo als Tarball holen und von dort neu starten.
# (Auf frischem macOS gibt es vor den Xcode CLT kein git, curl und tar sind immer da.)
# ---------------------------------------------------------------------------
KICKOFF_ROOT=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  KICKOFF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -z "$KICKOFF_ROOT" ] || [ ! -f "$KICKOFF_ROOT/lib/common.sh" ]; then
  src="${KICKOFF_HOME:-$HOME/.kickoff}/src"
  echo "➜ Lade kickoff ($KICKOFF_REPO@$KICKOFF_REF) nach $src"
  tmp="$(mktemp -d)"
  curl -fsSL "https://codeload.github.com/$KICKOFF_REPO/tar.gz/$KICKOFF_REF" | tar -xz -C "$tmp" --strip-components 1
  rm -rf "$src"
  mkdir -p "$(dirname "$src")"
  mv "$tmp" "$src"
  exec bash "$src/bootstrap.sh" "$@"
fi

# shellcheck source=lib/common.sh
. "$KICKOFF_ROOT/lib/common.sh"

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
ONLY=()
SKIP=()
DOCTOR_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)          KICKOFF_DRY_RUN=1 ;;
    --non-interactive)  KICKOFF_NON_INTERACTIVE=1 ;;
    --doctor)           DOCTOR_ONLY=1 ;;
    --only)             [ $# -ge 2 ] || { usage >&2; exit 2; }; ONLY+=("$2"); shift ;;
    --only=*)           ONLY+=("${1#--only=}") ;;
    --skip)             [ $# -ge 2 ] || { usage >&2; exit 2; }; SKIP+=("$2"); shift ;;
    --skip=*)           SKIP+=("${1#--skip=}") ;;
    -h|--help)          usage; exit 0 ;;
    *)                  echo "Unbekannte Option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done
export KICKOFF_DRY_RUN KICKOFF_NON_INTERACTIVE

# step_matches <step-name> <muster…> – Muster: "30", "30-git" oder "30-git.sh"
step_matches() {
  local name="$1" pat; shift
  for pat in "$@"; do
    pat="${pat%.sh}"
    if [ "$pat" = "$name" ] || [ "$pat" = "${name%%-*}" ]; then
      return 0
    fi
  done
  return 1
}

run_doctor() {
  if [ -f "$KICKOFF_ROOT/doctor.sh" ]; then
    bash "$KICKOFF_ROOT/doctor.sh"
  else
    warn "doctor ist noch nicht implementiert."
  fi
}

# ---------------------------------------------------------------------------
# Ablauf
# ---------------------------------------------------------------------------
kickoff_init_dirs
trap 'on_error $? "$BASH_COMMAND" $LINENO' ERR

if [ "$DOCTOR_ONLY" = "1" ]; then
  rc=0
  run_doctor || rc=$?
  exit "$rc"
fi

[ "$(uname -s)" = "Darwin" ] || die "bootstrap.sh unterstützt in v1 nur macOS." "Unter Windows bootstrap.ps1 verwenden."

info "kickoff – Log: $KICKOFF_LOG"
is_dry_run && info "Dry-Run: es wird nichts verändert."

TOTAL_START="$(date +%s)"
found=0
for step_file in "$KICKOFF_ROOT"/steps/[0-9][0-9]-*.sh; do
  [ -f "$step_file" ] || continue
  found=1
  name="$(basename "$step_file" .sh)"
  if [ ${#ONLY[@]} -gt 0 ] && ! step_matches "$name" "${ONLY[@]}"; then continue; fi
  if [ ${#SKIP[@]} -gt 0 ] && step_matches "$name" "${SKIP[@]}"; then continue; fi

  step_begin "$name"
  # Steps laufen in derselben Shell und nutzen lib/common.sh direkt.
  # shellcheck source=/dev/null
  . "$step_file"
  step_end
done
[ "$found" = "1" ] || warn "Keine Schritte gefunden in $KICKOFF_ROOT/steps."

KICKOFF_STEP="doctor"
doctor_rc=0
if is_dry_run; then
  info "[dry-run] doctor wird nach einem echten Lauf ausgeführt."
else
  run_doctor || doctor_rc=$?
fi

print_timing "$(( $(date +%s) - TOTAL_START ))"
exit "$doctor_rc"
