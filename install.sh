#!/usr/bin/env bash
# AnkerGames + JDownloader 2 — simple bilingual installer
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

detect_lang() {
  local l="${LANG:-}${LC_ALL:-}${LC_MESSAGES:-}"
  l="$(printf '%s' "${l}" | tr '[:upper:]' '[:lower:]')"
  case "${l}" in de*|deutsch*) echo de ;; *) echo en ;; esac
}

LANG_UI="$(detect_lang)"
[[ "${1:-}" == "--de" ]] && LANG_UI=de && shift
[[ "${1:-}" == "--en" ]] && LANG_UI=en && shift

T() { if [[ "${LANG_UI}" == de ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

chmod +x \
  "${ROOT}/plugin/install.sh" \
  "${ROOT}/companion/build-packages.sh" \
  "${ROOT}/companion/install-chromium.sh" \
  "${ROOT}/companion/install-firefox.sh" \
  2>/dev/null || true

echo
echo "=============================================="
echo "  AnkerGames + JDownloader 2"
echo "  $(T 'Installer' 'Installer')"
echo "=============================================="
echo

# --- step 1 ---
echo "$(T 'STEP 1/2 — Install JDownloader plugin?' 'SCHRITT 1/2 — JDownloader-Plugin installieren?')"
read -r -p "$(T '[Y/n]: ' '[J/n]: ')" ans
ans="$(printf '%s' "${ans:-Y}" | tr '[:upper:]' '[:lower:]')"
if [[ "${ans}" != n && "${ans}" != no && "${ans}" != nein ]]; then
  "${ROOT}/plugin/install.sh"
else
  echo "$(T 'Skipped plugin.' 'Plugin übersprungen.')"
fi

# --- step 2 ---
echo
echo "$(T 'STEP 2/2 — Browser add-on (required)' 'SCHRITT 2/2 — Browser-Erweiterung (nötig)')"
echo
echo "$(T 'Type your captcha browser name:' 'Tippe den Namen deines Captcha-Browsers:')"
echo "  vivaldi | chrome | brave | edge | firefox | skip"
read -r -p "$(T 'Browser [vivaldi]: ' 'Browser [vivaldi]: ')" browser
browser="$(printf '%s' "${browser:-vivaldi}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

case "${browser}" in
  vivaldi|chrome|chromium|brave|edge)
    "${ROOT}/companion/install-chromium.sh" "${browser}"
    ;;
  firefox|ff)
    "${ROOT}/companion/install-firefox.sh"
    ;;
  skip|s|n|no|nein)
    echo "$(T 'Skipped. Run ./install.sh again later.' 'Übersprungen. Später erneut ./install.sh.')"
    ;;
  *)
    echo "$(T 'Unknown name.' 'Unbekannter Name.') ${browser}"
    exit 1
    ;;
esac

echo
echo "=============================================="
echo "  $(T 'DONE' 'FERTIG')"
echo "=============================================="
echo
echo "$(T 'In JDownloader:' 'In JDownloader:')"
echo "  1. $(T 'Add link' 'Link hinzufügen') https://ankergames.net/game/…"
echo "  2. $(T 'Solve Turnstile in the browser' 'Turnstile im Browser lösen')"
echo "  3. $(T 'Keep the AnkerGames tab open until JD finishes' 'AnkerGames-Tab offen lassen bis JD fertig ist')"
echo
echo "$(T 'Help:' 'Hilfe:') README.md  /  README.de.md"
echo
