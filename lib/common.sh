#!/usr/bin/env bash
# lib/common.sh – gemeinsame Helfer für bootstrap.sh, steps/*.sh und doctor.sh.
#
# Muss unter macOS-System-Bash 3.2 laufen: keine assoziativen Arrays, kein mapfile,
# kein ${var,,}. Leere Arrays unter `set -u` nur mit ${arr[@]+"${arr[@]}"} expandieren.
#
# Konventionen für Steps:
#   - Jeder ändernde Befehl läuft über `run` (oder `run_visible`, wenn er das Terminal braucht).
#     Im Dry-Run wird er nur geplant und als "[dry-run] …" ausgegeben.
#   - `run` übergibt argv 1:1 – Pipes und Redirects gehen NICHT direkt. Solche Logik in eine
#     Funktion packen und die Funktion über `run` aufrufen. Solche Funktionen laufen in einer
#     Pipe-Subshell mit Ausgabe ins Log: sie geben Exit != 0 zurück, rufen aber nie `die`/`ask`.
#   - Ist-Zustand zuerst prüfen; danach `ok "… bereits vorhanden"` oder `doing "… wird installiert"`.
#   - Bestehende Nutzerdateien vor jeder Änderung mit `backup_file` sichern.

# ---------------------------------------------------------------------------
# Zustand
# ---------------------------------------------------------------------------
KICKOFF_HOME="${KICKOFF_HOME:-$HOME/.kickoff}"
KICKOFF_TS="${KICKOFF_TS:-$(date +%Y%m%d-%H%M%S)}"
KICKOFF_LOG_DIR="$KICKOFF_HOME/logs"
KICKOFF_STATE_DIR="$KICKOFF_HOME/state"
KICKOFF_BACKUP_DIR="$KICKOFF_HOME/backups/$KICKOFF_TS"
KICKOFF_LOG="${KICKOFF_LOG:-$KICKOFF_LOG_DIR/$KICKOFF_TS.log}"
KICKOFF_DRY_RUN="${KICKOFF_DRY_RUN:-0}"
KICKOFF_NON_INTERACTIVE="${KICKOFF_NON_INTERACTIVE:-0}"
KICKOFF_STEP="${KICKOFF_STEP:-bootstrap}"
KICKOFF_FAILED_CMD=""
export KICKOFF_HOME KICKOFF_TS KICKOFF_LOG KICKOFF_DRY_RUN KICKOFF_NON_INTERACTIVE

# Für die Zeitmessung (parallele Listen, weil Bash 3.2 keine assoziativen Arrays kennt).
KICKOFF_TIMING_NAMES=()
KICKOFF_TIMING_SECS=()
KICKOFF_STEP_START=0

kickoff_init_dirs() {
  mkdir -p "$KICKOFF_LOG_DIR" "$KICKOFF_STATE_DIR"
  : >>"$KICKOFF_LOG"
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
# Maskiert Tokens, Keys und Passwörter, bevor irgendetwas geloggt oder ausgegeben wird.
mask_secrets() {
  sed -E \
    -e 's/(gh[pousr]_)[A-Za-z0-9_]{10,}/\1***/g' \
    -e 's/(github_pat_)[A-Za-z0-9_]{10,}/\1***/g' \
    -e 's/(sk-ant-)[A-Za-z0-9_-]{6,}/\1***/g' \
    -e 's/(sk-)[A-Za-z0-9_-]{16,}/\1***/g' \
    -e 's/([Bb]earer )[A-Za-z0-9._~+\/=-]+/\1***/g' \
    -e 's/(([Pp]assword|[Tt]oken|[Ss]ecret|[Aa]pi[_-]?[Kk]ey)[=:][[:space:]]*)[^[:space:]]+/\1***/g'
}

_log_file() {
  [ -n "${KICKOFF_LOG:-}" ] || return 0
  [ -d "$(dirname "$KICKOFF_LOG")" ] || return 0
  printf '%s [%s] %s\n' "$(date +%H:%M:%S)" "$KICKOFF_STEP" "$*" | mask_secrets >>"$KICKOFF_LOG"
}

_say() { printf '%s\n' "$*" | mask_secrets; }

info()  { _log_file "INFO  $*"; _say "  $*"; }
ok()    { _log_file "OK    $*"; _say "✔ $*"; }
doing() { _log_file "DO    $*"; _say "➜ $*"; }
warn()  { _log_file "WARN  $*"; _say "⚠ $*" >&2; }

# die <Meldung> [nächster Handgriff]
die() {
  _log_file "FAIL  $1${2:+ | next: $2}"
  _say "✘ [$KICKOFF_STEP] $1" >&2
  [ -n "${2:-}" ] && _say "  Nächster Schritt: $2" >&2
  _say "  Log: $KICKOFF_LOG" >&2
  exit 1
}

# Vom ERR-Trap in bootstrap.sh aufgerufen.
on_error() {
  local code="$1" cmd="${KICKOFF_FAILED_CMD:-$2}" line="$3"
  _log_file "FAIL  exit=$code line=$line cmd=$cmd"
  _say "✘ [$KICKOFF_STEP] Befehl fehlgeschlagen (Exit $code): $cmd" >&2
  _say "  Nächster Schritt: Log prüfen, Ursache beheben und denselben Befehl erneut starten – fertige Schritte werden übersprungen." >&2
  _say "  Log: $KICKOFF_LOG" >&2
}

# ---------------------------------------------------------------------------
# Modus
# ---------------------------------------------------------------------------
is_dry_run() { [ "$KICKOFF_DRY_RUN" = "1" ]; }

is_interactive() {
  [ "$KICKOFF_NON_INTERACTIVE" != "1" ] || return 1
  # Unter `curl | bash` ist stdin die Pipe – Eingaben kommen nur über /dev/tty.
  { : </dev/tty; } 2>/dev/null
}

# ---------------------------------------------------------------------------
# Befehle ausführen
# ---------------------------------------------------------------------------
_quote_cmd() { printf '%q ' "$@"; }

# run <cmd> [args…] – Ausgabe des Befehls nur ins Log.
run() {
  local q; q="$(_quote_cmd "$@")"
  KICKOFF_FAILED_CMD=""
  if is_dry_run; then
    _log_file "PLAN  $q"
    _say "  [dry-run] $q"
    return 0
  fi
  _log_file "RUN   $q"
  local rc=0
  # Ausgabe läuft durch die Maskierung; pipefail liefert den Exit-Code des Befehls.
  if ! "$@" 2>&1 | mask_secrets >>"$KICKOFF_LOG"; then
    rc="${PIPESTATUS[0]}"
    _log_file "EXIT  $rc"
    KICKOFF_FAILED_CMD="$q"
    return "$rc"
  fi
}

# run_visible <cmd> [args…] – für Befehle, die das Terminal brauchen (Logins, Prompts).
run_visible() {
  local q; q="$(_quote_cmd "$@")"
  KICKOFF_FAILED_CMD=""
  if is_dry_run; then
    _log_file "PLAN  $q"
    _say "  [dry-run] $q"
    return 0
  fi
  _log_file "RUN   $q (interaktiv, Ausgabe nicht geloggt)"
  local rc=0
  "$@" </dev/tty || rc=$?
  if [ "$rc" -ne 0 ]; then
    _log_file "EXIT  $rc"
    KICKOFF_FAILED_CMD="$q"
  fi
  return "$rc"
}

# ask <Frage> [Vorschlag] – Antwort auf stdout. Liest von /dev/tty.
ask() {
  local prompt="$1" default="${2:-}" answer=""
  if ! is_interactive; then
    printf '%s' "$default"
    return 0
  fi
  if [ -n "$default" ]; then
    printf '? %s [%s]: ' "$prompt" "$default" >/dev/tty
  else
    printf '? %s: ' "$prompt" >/dev/tty
  fi
  IFS= read -r answer </dev/tty || true
  printf '%s' "${answer:-$default}"
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# Backups und State
# ---------------------------------------------------------------------------
# backup_file <Pfad> – kopiert eine bestehende Datei nach ~/.kickoff/backups/<ts>/ (Pfad relativ zu $HOME).
backup_file() {
  local src="$1" rel dest
  [ -e "$src" ] || return 0
  case "$src" in
    "$HOME"/*) rel="${src#"$HOME"/}" ;;
    *) rel="${src#/}" ;;
  esac
  dest="$KICKOFF_BACKUP_DIR/$rel"
  if is_dry_run; then
    _say "  [dry-run] Backup $src → $dest"
    return 0
  fi
  [ -e "$dest" ] && return 0
  mkdir -p "$(dirname "$dest")"
  cp -p "$src" "$dest"
  _log_file "BACKUP $src → $dest"
}

state_set()   { is_dry_run && return 0; mkdir -p "$KICKOFF_STATE_DIR"; printf '%s\n' "${2:-1}" >"$KICKOFF_STATE_DIR/$1"; }
state_get()   { [ -f "$KICKOFF_STATE_DIR/$1" ] && cat "$KICKOFF_STATE_DIR/$1"; }
state_has()   { [ -f "$KICKOFF_STATE_DIR/$1" ]; }
state_clear() { is_dry_run && return 0; rm -f "$KICKOFF_STATE_DIR/$1"; }

# needs_reboot <marker> <Erklärung> – Neustart-Marker setzen, erklären, sauber beenden (Exit 3).
needs_reboot() {
  state_set "reboot-$1" "$KICKOFF_STEP"
  _log_file "REBOOT marker=$1"
  _say ""
  _say "↻ $2"
  _say "  Nach dem Neustart denselben Befehl erneut ausführen – es geht genau hier weiter."
  exit 3
}

# ---------------------------------------------------------------------------
# Zeitmessung
# ---------------------------------------------------------------------------
step_begin() {
  KICKOFF_STEP="$1"
  KICKOFF_STEP_START="$(date +%s)"
  _log_file "BEGIN"
  _say ""
  _say "── $1"
}

step_end() {
  local secs=$(( $(date +%s) - KICKOFF_STEP_START ))
  KICKOFF_TIMING_NAMES+=("$KICKOFF_STEP")
  KICKOFF_TIMING_SECS+=("$secs")
  _log_file "END   ${secs}s"
}

print_timing() {
  local total="$1" i=0 n=${#KICKOFF_TIMING_NAMES[@]}
  _say ""
  _say "Laufzeit"
  while [ "$i" -lt "$n" ]; do
    printf '  %-20s %4ss\n' "${KICKOFF_TIMING_NAMES[$i]}" "${KICKOFF_TIMING_SECS[$i]}"
    i=$((i + 1))
  done
  printf '  %-20s %4ss\n' "gesamt" "$total"
  _log_file "TOTAL ${total}s"
}
