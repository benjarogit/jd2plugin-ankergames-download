#!/usr/bin/env bash
# Prepare Chromium-family companion and guide a reliable 2-click install.
# Policy force-install is attempted as a bonus; Load unpacked always works.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="${ROOT}/dist"
VER="$(python3 -c "import json; print(json.load(open('${ROOT}/chromium/manifest.json'))['version'])")"
EXT_ID="$(tr -d '[:space:]' < "${ROOT}/signing/chromium-extension-id.txt")"
ZIP="${DIST}/jd-turnstile-companion-chromium-${VER}.zip"
CRX="${DIST}/jd-turnstile-companion-chromium-${VER}.crx"
BROWSER_HINT="${1:-}"

lang=en
case "${LANG:-}${LC_ALL:-}" in
  [Dd][Ee]*|*[Dd]eutsch*) lang=de ;;
esac

chmod +x "${ROOT}/build-packages.sh"
"${ROOT}/build-packages.sh" >/dev/null

INSTALL_DIR="${HOME}/.local/share/jd-turnstile-companion/chromium"
EXT_DIR="${INSTALL_DIR}/ext"
mkdir -p "${INSTALL_DIR}"
rm -rf "${EXT_DIR}"
mkdir -p "${EXT_DIR}"

# Always keep an unpacked copy — most reliable install method
if [[ -f "${ZIP}" ]]; then
  unzip -qo "${ZIP}" -d "${EXT_DIR}"
else
  # Fallback: copy source tree
  cp -a "${ROOT}/chromium/." "${EXT_DIR}/"
  rm -f "${EXT_DIR}/README.md" 2>/dev/null || true
fi

if [[ -f "${CRX}" ]]; then
  cp -f "${CRX}" "${INSTALL_DIR}/companion.crx"
fi

# Bonus: managed policy (may auto-install on some Linux Chromium builds)
if [[ -f "${INSTALL_DIR}/companion.crx" ]]; then
  cat > "${INSTALL_DIR}/updates.xml" <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>
  <app appid='${EXT_ID}'>
    <updatecheck codebase='file://${INSTALL_DIR}/companion.crx' version='${VER}' />
  </app>
</gupdate>
EOF
  LOCAL_UPDATES="file://${INSTALL_DIR}/updates.xml"
  for policy_dir in \
    "${HOME}/.config/google-chrome/policies/managed" \
    "${HOME}/.config/chromium/policies/managed" \
    "${HOME}/.config/brave/policies/managed" \
    "${HOME}/.config/brave-browser/policies/managed" \
    "${HOME}/.config/microsoft-edge/policies/managed" \
    "${HOME}/.config/vivaldi/policies/managed"
  do
    mkdir -p "${policy_dir}"
    cat > "${policy_dir}/jd-turnstile-companion.json" <<EOF
{
  "ExtensionInstallAllowlist": ["${EXT_ID}"],
  "ExtensionInstallForcelist": ["${EXT_ID};${LOCAL_UPDATES}"],
  "ExtensionInstallSources": ["file://*"]
}
EOF
  done
fi

# Pick browser binary + extensions URL
pick_browser() {
  local want="${BROWSER_HINT:-}"
  want="$(printf '%s' "${want}" | tr '[:upper:]' '[:lower:]')"
  case "${want}" in
    chrome|google-chrome) echo "google-chrome-stable|chrome://extensions" ; return ;;
    chromium) echo "chromium|chrome://extensions" ; return ;;
    brave) echo "brave-browser|brave://extensions" ; return ;;
    edge) echo "microsoft-edge|edge://extensions" ; return ;;
    vivaldi|"") echo "vivaldi|vivaldi://extensions" ; return ;;
  esac
  echo "vivaldi|vivaldi://extensions"
}

IFS='|' read -r BIN EXT_URL <<<"$(pick_browser)"
for try in "${BIN}" google-chrome-stable google-chrome chromium vivaldi brave-browser microsoft-edge; do
  if command -v "${try}" >/dev/null 2>&1; then
    BIN="${try}"
    break
  fi
done

# Clipboard helper
if command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "${EXT_DIR}" | wl-copy 2>/dev/null || true
elif command -v xclip >/dev/null 2>&1; then
  printf '%s' "${EXT_DIR}" | xclip -selection clipboard 2>/dev/null || true
fi

echo
if [[ "${lang}" == de ]]; then
  cat <<EOF
============================================================
  Browser-Erweiterung v${VER}  (Chrome / Vivaldi / Brave / Edge)
============================================================

Ordner ist vorbereitet (Pfad liegt in der Zwischenablage, falls möglich):

  ${EXT_DIR}

Mach JETZT im Browser diese 3 Schritte:

  1) Seite „Erweiterungen“ ist gleich offen
  2) Rechts oben:  Entwicklermodus  EINSCHALTEN
  3) „Entpackte Erweiterung laden“  →  diesen Ordner wählen:
       ${EXT_DIR}

Falls die Erweiterung schon da ist: einmal „Aktualisieren“ klicken.
Danach sollte stehen:  JD Turnstile Companion  ${VER}

(Die .crx-Policy wird zusätzlich gesetzt — bei manchen Browsern
 reicht ein Neustart. Der sichere Weg sind die 3 Schritte oben.)
============================================================
EOF
else
  cat <<EOF
============================================================
  Browser add-on v${VER}  (Chrome / Vivaldi / Brave / Edge)
============================================================

Folder is ready (path copied to clipboard if possible):

  ${EXT_DIR}

Do these 3 steps in the browser NOW:

  1) The Extensions page will open
  2) Top-right: turn ON  Developer mode
  3) “Load unpacked”  →  select this folder:
       ${EXT_DIR}

If it is already listed: click Reload once.
You should see:  JD Turnstile Companion  ${VER}

(A .crx policy is also written — some browsers pick it up after
 a restart. The reliable path is the 3 steps above.)
============================================================
EOF
fi

if command -v "${BIN}" >/dev/null 2>&1; then
  nohup "${BIN}" "${EXT_URL}" >/dev/null 2>&1 &
  sleep 1
fi

echo
if [[ "${lang}" == de ]]; then
  read -r -p "Enter drücken, wenn die Erweiterung sichtbar ist… " _
else
  read -r -p "Press Enter when the add-on is visible… " _
fi

echo
if [[ "${lang}" == de ]]; then
  echo "OK. Denselben Browser für JDownloader-Captchas nutzen."
else
  echo "OK. Use this same browser for JDownloader captchas."
fi
