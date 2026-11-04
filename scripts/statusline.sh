#!/usr/bin/env bash
# statusline.sh — eine Zeile unter dem Prompt: wo bin ich, womit, wie voll ist der Kontext.
#
# Warum: 359x /clear und 51x /rate-limit-options in einem Quartal (reports/2026-09-01,
# Rang 1) — beides Handarbeit gegen eine Zahl, die niemand sieht. Wer die Fuellung liest,
# leert den Kontext, wenn es noetig ist, statt auf Verdacht.
#
# Vertrag: laeuft bei JEDEM Zug. Muss schnell sein und darf NIE scheitern — jeder Fehler
# wird geschluckt, im Zweifel steht weniger da, nie eine Fehlermeldung.
# Claude Code reicht das Status-JSON auf stdin (model, workspace, transcript_path, cost).
#
# Kontext-Messung wie scripts/kontext-fuelle.sh: die juengste usage-Zeile des Transkripts
# traegt input + cache_creation + cache_read = der komplette gelesene Prompt. Gelesen wird
# nur das Ende der Datei (tail), damit die Zeile auch bei 100-MB-Transkripten sofort steht.
#
# Die Fenstergroesse kommt aus der Modell-ID ("[1m]" -> 1M, sonst 200k); KONTEXT_WINDOW
# ueberschreibt sie.
set -uo pipefail

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

PAYLOAD="$payload" WINDOW_OVERRIDE="${KONTEXT_WINDOW:-}" python3 <<'PY' 2>/dev/null || true
import json, os, subprocess

R = "\033[0m"; DIM = "\033[2m"; B = "\033[1m"
GREEN = "\033[32m"; YELLOW = "\033[33m"; RED = "\033[31m"; BLUE = "\033[34m"

try:
    d = json.loads(os.environ["PAYLOAD"])
except Exception:
    raise SystemExit(0)

teile = []

cwd = (d.get("workspace") or {}).get("current_dir") or d.get("cwd") or ""
if cwd:
    teile.append(f"{B}{os.path.basename(cwd.rstrip('/'))}{R}")
    try:
        br = subprocess.run(["git", "-C", cwd, "symbolic-ref", "--short", "-q", "HEAD"],
                            capture_output=True, text=True, timeout=1).stdout.strip()
        if br:
            dirty = subprocess.run(["git", "-C", cwd, "status", "--porcelain"],
                                   capture_output=True, text=True, timeout=1).stdout.strip()
            teile.append(f"{DIM}⎇{R} {br}{(YELLOW + '*' + R) if dirty else ''}")
    except Exception:
        pass

modell = (d.get("model") or {}).get("display_name")
if modell:
    teile.append(f"{DIM}{modell}{R}")

# ---- Kontext-Fuellung aus dem Transkript-Ende ----
tp = d.get("transcript_path") or ""
belegt = 0
if tp and os.path.isfile(tp):
    def summe(o):
        if isinstance(o, dict):
            if "cache_read_input_tokens" in o or ("input_tokens" in o and "output_tokens" in o):
                t = ((o.get("input_tokens") or 0) + (o.get("cache_creation_input_tokens") or 0)
                     + (o.get("cache_read_input_tokens") or 0))
                if t:
                    return t
            for v in o.values():
                r = summe(v)
                if r:
                    return r
        elif isinstance(o, list):
            for v in o:
                r = summe(v)
                if r:
                    return r
        return 0
    try:
        with open(tp, "rb") as fh:
            fh.seek(0, os.SEEK_END)
            fh.seek(max(0, fh.tell() - 400_000))
            zeilen = fh.read().decode("utf-8", "ignore").splitlines()
        letzte = []
        for line in reversed(zeilen):
            if '"usage"' not in line:
                continue
            try:
                t = summe(json.loads(line))
            except Exception:
                continue
            if t:
                letzte.append(t)          # neueste zuerst
                if len(letzte) >= 16:
                    break
        # Ein Zug, der den advisor gerufen hat, traegt das Gespraech ZWEIMAL: den
        # eigenen Kontext und den weitergereichten Prompt. Er meldet rund das
        # Doppelte und ist am Sprung erkennbar - der Hauptfaden waechst um
        # Tausende, ein advisor-Zug auf ~200 %. Wir gehen vom juengsten Zug
        # rueckwaerts bis zum ersten ohne solchen Sprung.
        belegt = letzte[0] if letzte else 0
        for i in range(len(letzte) - 1):
            if letzte[i] <= letzte[i + 1] * 1.5:
                belegt = letzte[i]
                break
            belegt = letzte[i + 1]
    except Exception:
        pass

if belegt:
    # Das Fenster haengt am MODELL, nicht an einer globalen Zahl: settings.json ist global,
    # aber nur meinbuch faehrt opus[1m]. Mit fest 1.000.000 zeigte eine 200k-Session
    # 190k als "19 % gruen" statt als "95 % rot" — der /clear-Hinweis kaeme, wenn der
    # Kontext schon weg ist. Die Modell-ID traegt die Fenstergroesse ("[1m]").
    mid = str((d.get("model") or {}).get("id") or "")
    fenster = 1_000_000 if "[1m]" in mid else 200_000
    if d.get("exceeds_200k_tokens") and fenster == 200_000:
        fenster = 1_000_000        # die Oberflaeche sagt selbst, dass mehr als 200k passen
    ueberschreibung = os.environ.get("WINDOW_OVERRIDE")
    if ueberschreibung:
        fenster = int(ueberschreibung)
    pct = min(100, round(belegt * 100 / fenster))
    farbe = GREEN if pct < 60 else (YELLOW if pct < 80 else RED)
    voll = round(pct / 10)
    balken = "▓" * voll + "░" * (10 - voll)
    rat = f"  {RED}→ /clear{R}" if pct >= 80 else ""
    teile.append(f"{farbe}{balken} {pct}%{R} {DIM}({belegt // 1000}k){R}{rat}")

kosten = (d.get("cost") or {}).get("total_cost_usd")
if isinstance(kosten, (int, float)) and kosten > 0:
    teile.append(f"{DIM}${kosten:.2f}{R}")

print(f" {DIM}·{R} ".join(teile))
PY
