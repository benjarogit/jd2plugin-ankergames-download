#!/usr/bin/env bash
# Install JD Turnstile Companion permanently into Chromium browsers
# (Chrome / Edge / Brave / Vivaldi). Uses packed .crx + managed policy with
# GitHub HTTPS update feed so the browser can auto-update.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="${ROOT}/dist"
REPO_UPDATES_URL="https://raw.githubusercontent.com/benjarogit/jd2plugin-ankergames-download/main/updates/chromium.xml"
VER="$(python3 -c "import json; print(json.load(open('${ROOT}/chromium/manifest.json'))['version'])")"
EXT_ID="$(tr -d '[:space:]' < "${ROOT}/signing/chromium-extension-id.txt")"
ZIP="${DIST}/jd-turnstile-companion-chromium-${VER}.zip"
CRX="${DIST}/jd-turnstile-companion-chromium-${VER}.crx"

chmod +x "${ROOT}/build-packages.sh"
"${ROOT}/build-packages.sh"

INSTALL_DIR="${HOME}/.local/share/jd-turnstile-companion/chromium"
mkdir -p "${INSTALL_DIR}"

if [[ -f "${CRX}" ]]; then
  cp -f "${CRX}" "${INSTALL_DIR}/companion.crx"
elif [[ -f "${ZIP}" ]]; then
  echo "No CRX — extracting ZIP for unpacked install under ${INSTALL_DIR}/ext"
  rm -rf "${INSTALL_DIR}/ext"
  mkdir -p "${INSTALL_DIR}/ext"
  unzip -qo "${ZIP}" -d "${INSTALL_DIR}/ext"
else
  echo "ERROR: no chromium package built"
  exit 1
fi

# Local updates.xml mirrors GitHub feed but serves the local CRX for first install.
# Browsers also poll REPO_UPDATES_URL via policy forcelist (HTTPS → GitHub Releases).
if [[ -f "${INSTALL_DIR}/companion.crx" ]]; then
  cat > "${INSTALL_DIR}/updates.xml" <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>
  <app appid='${EXT_ID}'>
    <updatecheck codebase='file://${INSTALL_DIR}/companion.crx' version='${VER}' />
  </app>
</gupdate>
EOF
fi

write_policy() {
  local policy_dir="$1"
  local browser_name="$2"
  mkdir -p "${policy_dir}"
  local policy_file="${policy_dir}/jd-turnstile-companion.json"
  # Prefer GitHub HTTPS feed for ongoing updates; allowlist stable id.
  cat > "${policy_file}" <<EOF
{
  "ExtensionSettings": {
    "${EXT_ID}": {
      "installation_mode": "normal_installed",
      "update_url": "${REPO_UPDATES_URL}",
      "toolbar_pin": "default_unpinned"
    }
  },
  "ExtensionInstallAllowlist": ["${EXT_ID}"],
  "ExtensionInstallForcelist": ["${EXT_ID};${REPO_UPDATES_URL}"]
}
EOF
  echo "  Policy written for ${browser_name}: ${policy_file}"
}

echo "=== Install Chromium companion v${VER} (id=${EXT_ID}) ==="
echo "Update feed: ${REPO_UPDATES_URL}"

write_policy "${HOME}/.config/google-chrome/policies/managed" "Chrome"
write_policy "${HOME}/.config/chromium/policies/managed" "Chromium"
write_policy "${HOME}/.config/brave/policies/managed" "Brave"
write_policy "${HOME}/.config/brave-browser/policies/managed" "Brave (alt)"
write_policy "${HOME}/.config/microsoft-edge/policies/managed" "Edge"
write_policy "${HOME}/.config/vivaldi/policies/managed" "Vivaldi"
write_policy "${HOME}/.var/app/com.vivaldi.Vivaldi/config/vivaldi/policies/managed" "Vivaldi Flatpak"
write_policy "${HOME}/.var/app/com.google.Chrome/config/google-chrome/policies/managed" "Chrome Flatpak"
write_policy "${HOME}/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/policies/managed" "Brave Flatpak"

echo
if [[ -f "${INSTALL_DIR}/companion.crx" ]]; then
  echo "CRX ready: ${INSTALL_DIR}/companion.crx"
  echo
  echo "Finish install (pick one):"
  echo "  A) Restart the browser — policy forcelist pulls from GitHub when online,"
  echo "     or drag-drop the local .crx onto …://extensions (Developer mode)."
  echo "  B) Drag-drop: ${INSTALL_DIR}/companion.crx"
  echo
  for bin in vivaldi google-chrome-stable google-chrome chromium brave-browser microsoft-edge; do
    if command -v "${bin}" >/dev/null 2>&1; then
      nohup "${bin}" "file://${INSTALL_DIR}/companion.crx" >/dev/null 2>&1 &
      echo "Opened ${bin} with the CRX — confirm if prompted, then restart once."
      break
    fi
  done
else
  echo "Unpacked extension at: ${INSTALL_DIR}/ext"
  echo "Open …://extensions → Developer mode → Load unpacked → that folder."
fi

echo
echo "Extension ID: ${EXT_ID}"
echo "Auto-update: browser polls GitHub updates/chromium.xml (Release CRX)."
echo "Fallback: toolbar badge ↑ when a newer GitHub Release exists."
echo "Done. Use the SAME browser for JD captchas."
