#!/usr/bin/env bash
# Lint: shellcheck für alle .sh, PSScriptAnalyzer (Warning/Error + Kompatibilität PS 5.1/7, siehe
# tests/PSScriptAnalyzerSettings.psd1) für alle .ps1. Exit 1 bei jeder Warnung.
# scripts/ und .claude/ kommen aus dev/base (base sync) und werden von scripts/gate.sh mit
# Stufe "warning" geprüft, nicht hier mit Stufe "style".
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
rc=0

sh_files=()
while IFS= read -r f; do [ -f "$f" ] && sh_files+=("$f"); done < <(git ls-files --cached --others --exclude-standard -- '*.sh' ':(exclude)scripts/*' ':(exclude).claude/*')

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "✘ shellcheck fehlt (brew install shellcheck)" >&2
  rc=1
elif [ ${#sh_files[@]} -gt 0 ]; then
  echo "➜ shellcheck: ${#sh_files[@]} Dateien"
  shellcheck -x -S style "${sh_files[@]}" || rc=1
fi

ps_files=()
while IFS= read -r f; do [ -f "$f" ] && ps_files+=("$f"); done < <(git ls-files --cached --others --exclude-standard -- '*.ps1')

# shellcheck disable=SC2016 # PowerShell-Code, $-Ausdrücke sind für pwsh bestimmt
PSSA='
  $ErrorActionPreference = "Stop"
  if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
    Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck | Out-Null
  }
  $files = $env:KICKOFF_PS_FILES -split "`n" | Where-Object { $_ }
  $settings = Join-Path (Get-Location) "tests/PSScriptAnalyzerSettings.psd1"
  $results = $files | ForEach-Object { Invoke-ScriptAnalyzer -Path $_ -Settings $settings }
  if ($results) { $results | Format-Table -AutoSize | Out-String -Width 200 | Write-Output; exit 1 }
'
KICKOFF_PS_FILES="$(printf '%s\n' ${ps_files[@]+"${ps_files[@]}"})"
export KICKOFF_PS_FILES

if [ ${#ps_files[@]} -eq 0 ]; then
  echo "  PSScriptAnalyzer: keine .ps1-Dateien"
elif command -v pwsh >/dev/null 2>&1; then
  echo "➜ PSScriptAnalyzer: ${#ps_files[@]} Dateien"
  pwsh -NoProfile -Command "$PSSA" || rc=1
elif command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo "➜ PSScriptAnalyzer (Docker): ${#ps_files[@]} Dateien"
  docker run --rm --platform linux/amd64 -e KICKOFF_PS_FILES -v "$ROOT":/w -w /w \
    mcr.microsoft.com/powershell:lts-7.4-ubuntu-22.04 pwsh -NoProfile -Command "$PSSA" || rc=1
else
  echo "⚠ PSScriptAnalyzer übersprungen: weder pwsh noch Docker verfügbar (wird in CI geprüft; lokal: brew install powershell)"
fi

# PowerShell 5.1 liest .ps1 ohne BOM als ANSI – BOM ist Pflicht. Ausnahme bootstrap.ps1: `irm | iex`
# bricht am BOM, deshalb muss diese Datei reines ASCII ohne BOM sein.
for f in ${ps_files[@]+"${ps_files[@]}"}; do
  bom="$(head -c3 "$f" | od -An -tx1 | tr -d ' \n')"
  if [ "$f" = "bootstrap.ps1" ]; then
    if [ "$bom" = "efbbbf" ] || LC_ALL=C grep -q '[^ -~	]' "$f"; then
      echo "✘ $f: muss reines ASCII ohne BOM sein (irm | iex)" >&2
      rc=1
    fi
  elif [ "$bom" != "efbbbf" ]; then
    echo "✘ $f: UTF-8-BOM fehlt" >&2
    rc=1
  fi
done

[ "$rc" -eq 0 ] && echo "✔ Lint sauber"
exit "$rc"
