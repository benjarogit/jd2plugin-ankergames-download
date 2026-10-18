#!/usr/bin/env bash
# Prepare Firefox companion (.xpi) and guide unsigned install (Dev Edition / Nightly).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="${ROOT}/dist"
VER="$(python3 -c "import json; print(json.load(open('${ROOT}/firefox/manifest.json'))['version'])")"
XPI_UNSIGNED="${DIST}/jd-turnstile-companion-firefox-${VER}.xpi"

lang=en
case "${LANG:-}${LC_ALL:-}" in
  [Dd][Ee]*|*[Dd]eutsch*) lang=de ;;
esac

chmod +x "${ROOT}/build-packages.sh"
"${ROOT}/build-packages.sh" >/dev/null
[[ -f "${XPI_UNSIGNED}" ]] || { echo "ERROR: XPI missing"; exit 1; }

INSTALL_DIR="${HOME}/.local/share/jd-turnstile-companion"
mkdir -p "${INSTALL_DIR}"
cp -f "${XPI_UNSIGNED}" "${INSTALL_DIR}/jd-turnstile-companion.xpi"
XPI_FILE="${INSTALL_DIR}/jd-turnstile-companion.xpi"

if command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "${XPI_FILE}" | wl-copy 2>/dev/null || true
elif command -v xclip >/dev/null 2>&1; then
  printf '%s' "${XPI_FILE}" | xclip -selection clipboard 2>/dev/null || true
fi

FIREFOX=""
for bin in firefox-developer-edition firefox-nightly firefox; do
  if command -v "${bin}" >/dev/null 2>&1; then
    FIREFOX="${bin}"
    break
  fi
done

echo
if [[ "${lang}" == de ]]; then
  cat <<EOF
============================================================
  Firefox-Erweiterung v${VER}  (unsigniert)
============================================================

XPI-Datei (Pfad in Zwischenablage, falls möglich):

  ${XPI_FILE}

Release-Firefox blockiert unsignierte Add-ons.
Am einfachsten: Firefox Developer Edition oder Nightly.

Mach JETZT:

  1) about:config öffnen → Warnung akzeptieren
  2) Suchen:  xpinstall.signatures.required
     → Wert auf  false  setzen (Doppelklick)
  3) about:addons öffnen → Zahnrad oben rechts
     → „Add-on aus Datei installieren…“
     → Datei wählen:  ${XPI_FILE}
  4) Installation bestätigen

Alternativ nur bis zum Neustart:
  about:debugging#/runtime/this-firefox
  → „Temporäres Add-on laden…“
  → Datei: companion/firefox/manifest.json
============================================================
EOF
else
  cat <<EOF
============================================================
  Firefox add-on v${VER}  (unsigned)
============================================================

XPI file (path copied to clipboard if possible):

  ${XPI_FILE}

Release Firefox blocks unsigned add-ons.
Easiest: Firefox Developer Edition or Nightly.

Do this NOW:

  1) Open about:config → accept the warning
  2) Search:  xpinstall.signatures.required
     → set to  false  (double-click)
  3) Open about:addons → gear (top right)
     → “Install Add-on From File…”
     → choose:  ${XPI_FILE}
  4) Confirm install

Alternative until restart only:
  about:debugging#/runtime/this-firefox
  → “Load Temporary Add-on…”
  → file: companion/firefox/manifest.json
============================================================
EOF
fi

if [[ -n "${FIREFOX}" ]]; then
  nohup "${FIREFOX}" "about:config" >/dev/null 2>&1 &
  sleep 1
  nohup "${FIREFOX}" "about:addons" >/dev/null 2>&1 &
fi

echo
if [[ "${lang}" == de ]]; then
  read -r -p "Enter drücken, wenn das Add-on unter about:addons sichtbar ist… " _
  echo "OK. Denselben Firefox für JDownloader-Captchas nutzen."
else
  read -r -p "Press Enter when the add-on is visible in about:addons… " _
  echo "OK. Use this same Firefox for JDownloader captchas."
fi
