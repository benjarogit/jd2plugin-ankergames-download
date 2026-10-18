#!/usr/bin/env bash
# AnkerGames for JDownloader 2 — one installer (plugin + browser companion).
# Bilingual DE/EN. Run from the repo root:  ./install.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

# --- language ---
detect_lang() {
  local l="${LANG:-}${LC_ALL:-}${LC_MESSAGES:-}"
  l="$(printf '%s' "${l}" | tr '[:upper:]' '[:lower:]')"
  case "${l}" in
    de*|deutsch*) echo de ;;
    *) echo en ;;
  esac
}

LANG_UI="$(detect_lang)"
if [[ "${1:-}" == "--de" ]]; then LANG_UI=de; shift; fi
if [[ "${1:-}" == "--en" ]]; then LANG_UI=en; shift; fi

T() {
  # T en_text de_text
  if [[ "${LANG_UI}" == de ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi
}

chmod +x \
  "${ROOT}/plugin/install.sh" \
  "${ROOT}/companion/build-packages.sh" \
  "${ROOT}/companion/install-chromium.sh" \
  "${ROOT}/companion/install-firefox.sh" \
  2>/dev/null || true

echo
echo "=============================================="
echo "  AnkerGames + JDownloader 2"
echo "  $(T 'Installer (plugin + browser add-on)' 'Installer (Plugin + Browser-Erweiterung)')"
echo "=============================================="
echo "  $(T 'Language' 'Sprache'): ${LANG_UI}  ($(T 'use --de / --en to force' 'mit --de / --en erzwingen'))"
echo

# --- step 1: plugin ---
echo "----------------------------------------------"
echo "  $(T 'STEP 1 of 2 — JDownloader plugin' 'SCHRITT 1 von 2 — JDownloader-Plugin')"
echo "----------------------------------------------"
echo "  $(T 'This installs the hoster/crawler and patches Core.jar.' 'Installiert Hoster/Crawler und patcht Core.jar.')"
echo
read -r -p "$(T 'Continue? [Y/n]: ' 'Weiter? [J/n]: ')" ans
ans="$(printf '%s' "${ans:-Y}" | tr '[:upper:]' '[:lower:]')"
if [[ "${ans}" == n || "${ans}" == no || "${ans}" == nein ]]; then
  echo "$(T 'Aborted.' 'Abgebrochen.')"
  exit 0
fi

"${ROOT}/plugin/install.sh"

echo
echo "----------------------------------------------"
echo "  $(T 'STEP 2 of 2 — Browser companion' 'SCHRITT 2 von 2 — Browser-Erweiterung')"
echo "----------------------------------------------"
echo "  $(T 'Required: Cloudflare must see a real browser, not Java.' 'Pflicht: Cloudflare muss einen echten Browser sehen, nicht Java.')"
echo
echo "  $(T 'Which browser do you use for captchas?' 'Welchen Browser nutzt du für Captchas?')"
echo
echo "    vivaldi   — Vivaldi"
echo "    chrome    — Google Chrome"
echo "    brave     — Brave"
echo "    edge      — Microsoft Edge"
echo "    firefox   — Firefox"
echo "    all       — $(T 'Chromium family + Firefox' 'Chromium-Familie + Firefox')"
echo "    skip      — $(T 'skip for now' 'jetzt überspringen')"
echo
read -r -p "$(T 'Type the name (default: vivaldi): ' 'Namen tippen (Standard: vivaldi): ')" browser
browser="$(printf '%s' "${browser:-vivaldi}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

case "${browser}" in
  vivaldi|chrome|chromium|brave|edge|all|chromium-family|chrome-family)
    echo
    echo "$(T 'Installing Chromium-family add-on (.crx)…' 'Installiere Chromium-Erweiterung (.crx)…')"
    "${ROOT}/companion/install-chromium.sh"
    if [[ "${browser}" == all ]]; then
      echo
      echo "$(T 'Installing Firefox add-on (.xpi)…' 'Installiere Firefox-Erweiterung (.xpi)…')"
      "${ROOT}/companion/install-firefox.sh" || true
    fi
    ;;
  firefox|ff)
    echo
    echo "$(T 'Installing Firefox add-on (.xpi)…' 'Installiere Firefox-Erweiterung (.xpi)…')"
    "${ROOT}/companion/install-firefox.sh"
    ;;
  skip|s|nein|no|n)
    echo
    echo "$(T 'Skipped. Later run:' 'Übersprungen. Später ausführen:')"
    echo "  cd \"${ROOT}\" && ./install.sh"
    echo "  $(T '(answer n on step 1 if plugin is already installed)' '(bei Schritt 1 n tippen, wenn das Plugin schon installiert ist)')"
    ;;
  *)
    echo "$(T 'Unknown browser name.' 'Unbekannter Browsername.') „${browser}“"
    echo "$(T 'Allowed: vivaldi chrome brave edge firefox all skip' 'Erlaubt: vivaldi chrome brave edge firefox all skip')"
    exit 1
    ;;
esac

echo
echo "=============================================="
echo "  $(T 'DONE' 'FERTIG')"
echo "=============================================="
echo
echo "  $(T 'Browser add-on:' 'Browser-Erweiterung:')"
echo "  • Chrome/Vivaldi/Brave/Edge: $(T 'should install automatically via policy (browser was restarted).' 'sollte per Policy automatisch installiert sein (Browser wurde neu gestartet).')"
echo "    $(T 'Check' 'Prüfen'): vivaldi://extensions / chrome://extensions / chrome://policy"
echo "  • Firefox Release: $(T 'needs a free Mozilla signature once — see companion/SIGNING.md' 'braucht einmalig eine kostenlose Mozilla-Signatur — siehe companion/SIGNING.md')"
echo "    $(T 'Or set AMO_JWT_ISSUER + AMO_JWT_SECRET and re-run step 2.' 'Oder AMO_JWT_ISSUER + AMO_JWT_SECRET setzen und Schritt 2 erneut.')"
echo
echo "  $(T 'Then in JDownloader:' 'Dann in JDownloader:')"
echo "  • $(T 'Add' 'Link hinzufügen'): https://ankergames.net/game/…"
echo "  • $(T 'Solve Turnstile; keep the AnkerGames tab open.' 'Turnstile lösen; AnkerGames-Tab offen lassen.')"
echo
echo "  $(T 'Docs:' 'Doku:') README.md  |  README.de.md"
echo
