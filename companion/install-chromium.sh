#!/usr/bin/env bash
# Install JD Turnstile Companion permanently into Chromium browsers (Chrome/Edge/Brave/Vivaldi).
# Uses a packed .crx + managed policy (ExtensionInstallForcelist) — no "Load unpacked".
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="${ROOT}/dist"
VER="$(python3 -c "import json; print(json.load(open('${ROOT}/chromium/manifest.json'))['version'])")"
EXT_ID="$(tr -d '[:space:]' < "${ROOT}/signing/chromium-extension-id.txt")"
ZIP="${DIST}/jd-turnstile-companion-chromium-${VER}.zip"
CRX="${DIST}/jd-turnstile-companion-chromium-${VER}.crx"

chmod +x "${ROOT}/build-packages.sh"
"${ROOT}/build-packages.sh"

INSTALL_DIR="${HOME}/.local/share/jd-turnstile-companion/chromium"
mkdir -p "${INSTALL_DIR}"

# Prefer CRX; fall back to unpacked folder from ZIP (still policy-installable via update xml + path tricks)
if [[ -f "${CRX}" ]]; then
  cp -f "${CRX}" "${INSTALL_DIR}/companion.crx"
  CODEBASE="file://${INSTALL_DIR}/companion.crx"
elif [[ -f "${ZIP}" ]]; then
  echo "No CRX — extracting ZIP for unpacked install under ${INSTALL_DIR}/ext"
  rm -rf "${INSTALL_DIR}/ext"
  mkdir -p "${INSTALL_DIR}/ext"
  unzip -qo "${ZIP}" -d "${INSTALL_DIR}/ext"
  CODEBASE=""
else
  echo "ERROR: no chromium package built"
  exit 1
fi

# Chrome/Chromium/Brave/Vivaldi update manifest for local CRX
if [[ -n "${CODEBASE}" ]]; then
  cat > "${INSTALL_DIR}/updates.xml" <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>
  <app appid='${EXT_ID}'>
    <updatecheck codebase='${CODEBASE}' version='${VER}' />
  </app>
</gupdate>
EOF
fi

write_policy() {
  local policy_dir="$1"
  local browser_name="$2"
  mkdir -p "${policy_dir}"
  local policy_file="${policy_dir}/jd-turnstile-companion.json"
  if [[ -n "${CODEBASE}" ]]; then
    cat > "${policy_file}" <<EOF
{
  "ExtensionSettings": {
    "${EXT_ID}": {
      "installation_mode": "normal_installed",
      "update_url": "file://${INSTALL_DIR}/updates.xml",
      "toolbar_pin": "default_unpinned"
    }
  },
  "ExtensionInstallAllowlist": ["${EXT_ID}"],
  "ExtensionInstallForcelist": ["${EXT_ID};file://${INSTALL_DIR}/updates.xml"]
}
EOF
  else
    # Unpacked fallback — user still needs allow; forcelist needs update URL.
    # Write allowlist + clear instructions to drag CRX next time.
    cat > "${policy_file}" <<EOF
{
  "ExtensionInstallAllowlist": ["${EXT_ID}"]
}
EOF
  fi
  echo "  Policy written for ${browser_name}: ${policy_file}"
}

echo "=== Install Chromium companion v${VER} (id=${EXT_ID}) ==="

# Per-browser managed policy directories (Linux)
[[ -d "${HOME}/.config/google-chrome" || true ]]
write_policy "${HOME}/.config/google-chrome/policies/managed" "Chrome" || true
write_policy "${HOME}/.config/chromium/policies/managed" "Chromium" || true
write_policy "${HOME}/.config/brave/policies/managed" "Brave" || true
write_policy "${HOME}/.config/microsoft-edge/policies/managed" "Edge" || true
write_policy "${HOME}/.config/vivaldi/policies/managed" "Vivaldi" || true
# Flatpak-ish / alternate Vivaldi paths
write_policy "${HOME}/.var/app/com.vivaldi.Vivaldi/config/vivaldi/policies/managed" "Vivaldi Flatpak" || true

echo
if [[ -f "${INSTALL_DIR}/companion.crx" ]]; then
  echo "CRX ready: ${INSTALL_DIR}/companion.crx"
  echo
  echo "Finish install (pick one):"
  echo "  A) Restart Vivaldi/Chrome — policy forcelist should auto-install the extension."
  echo "  B) Or open vivaldi://extensions (Developer mode) and drag-drop the .crx file onto the page."
  echo
  # Try to open the CRX with Vivaldi for an install prompt
  if command -v vivaldi >/dev/null 2>&1; then
    nohup vivaldi "file://${INSTALL_DIR}/companion.crx" >/dev/null 2>&1 &
    echo "Opened Vivaldi with the CRX — confirm if prompted, then restart the browser once."
  fi
else
  echo "Unpacked extension at: ${INSTALL_DIR}/ext"
  echo "Open chrome://extensions or vivaldi://extensions → Developer mode → Load unpacked → select that folder."
  echo "(Re-run build with a display available to produce a .crx for one-click install.)"
fi

echo
echo "Extension ID: ${EXT_ID}"
echo "Done. Use the SAME browser for JD captchas."
