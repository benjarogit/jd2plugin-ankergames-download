#!/usr/bin/env bash
# Auto-install JD Turnstile Companion into Chromium browsers (Chrome / Edge / Brave / Vivaldi).
# On Linux, ExtensionInstallForcelist + local file:// CRX installs silently (no Web Store, no drag-drop).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="${ROOT}/dist"
REPO_UPDATES_URL="https://raw.githubusercontent.com/benjarogit/jd2plugin-ankergames-download/main/updates/chromium.xml"
VER="$(python3 -c "import json; print(json.load(open('${ROOT}/chromium/manifest.json'))['version'])")"
EXT_ID="$(tr -d '[:space:]' < "${ROOT}/signing/chromium-extension-id.txt")"
ZIP="${DIST}/jd-turnstile-companion-chromium-${VER}.zip"
CRX="${DIST}/jd-turnstile-companion-chromium-${VER}.crx"

lang=en
case "${LANG:-}${LC_ALL:-}" in
  [Dd][Ee]*|*[Dd]eutsch*) lang=de ;;
esac

chmod +x "${ROOT}/build-packages.sh"
"${ROOT}/build-packages.sh"

INSTALL_DIR="${HOME}/.local/share/jd-turnstile-companion/chromium"
mkdir -p "${INSTALL_DIR}"

if [[ -f "${CRX}" ]]; then
  cp -f "${CRX}" "${INSTALL_DIR}/companion.crx"
elif [[ -f "${ZIP}" ]]; then
  echo "WARN: no .crx — packing required a Chrome/Vivaldi binary with a display."
  rm -rf "${INSTALL_DIR}/ext"
  mkdir -p "${INSTALL_DIR}/ext"
  unzip -qo "${ZIP}" -d "${INSTALL_DIR}/ext"
else
  echo "ERROR: no chromium package built"
  exit 1
fi

[[ -f "${INSTALL_DIR}/companion.crx" ]] || {
  echo "ERROR: companion.crx missing — cannot auto-install without a packed CRX."
  exit 1
}

# Local Omaha feed — browsers install from this file:// URL (works on Linux without Web Store).
LOCAL_UPDATES="file://${INSTALL_DIR}/updates.xml"
cat > "${INSTALL_DIR}/updates.xml" <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>
  <app appid='${EXT_ID}'>
    <updatecheck codebase='file://${INSTALL_DIR}/companion.crx' version='${VER}' />
  </app>
</gupdate>
EOF

# Also keep a copy that points at GitHub for later manual checks
cat > "${INSTALL_DIR}/updates-github.xml" <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>
  <app appid='${EXT_ID}'>
    <updatecheck
      codebase='https://github.com/benjarogit/jd2plugin-ankergames-download/releases/download/v${VER}/jd-turnstile-companion-chromium-${VER}.crx'
      version='${VER}' />
  </app>
</gupdate>
EOF

write_policy() {
  local policy_dir="$1"
  local browser_name="$2"
  mkdir -p "${policy_dir}"
  local policy_file="${policy_dir}/jd-turnstile-companion.json"
  cat > "${policy_file}" <<EOF
{
  "ExtensionInstallSources": [
    "file://*",
    "https://github.com/*",
    "https://*.githubusercontent.com/*",
    "https://raw.githubusercontent.com/*"
  ],
  "ExtensionInstallAllowlist": ["${EXT_ID}"],
  "ExtensionInstallForcelist": ["${EXT_ID};${LOCAL_UPDATES}"],
  "ExtensionSettings": {
    "${EXT_ID}": {
      "installation_mode": "force_installed",
      "update_url": "${LOCAL_UPDATES}",
      "toolbar_pin": "default_unpinned",
      "override_update_url": true
    }
  }
}
EOF
  echo "  OK ${browser_name}: ${policy_file}"
}

# Optional: classic External Extensions JSON (some Chromium builds honor this too)
write_external() {
  local ext_dir="$1"
  local browser_name="$2"
  mkdir -p "${ext_dir}"
  cat > "${ext_dir}/${EXT_ID}.json" <<EOF
{
  "external_crx": "${INSTALL_DIR}/companion.crx",
  "external_version": "${VER}"
}
EOF
  echo "  OK external ${browser_name}: ${ext_dir}/${EXT_ID}.json"
}

if [[ "${lang}" == de ]]; then
  echo "=== Chromium-Companion v${VER} — automatische Installation ==="
  echo "Extension-ID: ${EXT_ID}"
  echo "Lokal: ${INSTALL_DIR}/companion.crx"
else
  echo "=== Chromium companion v${VER} — automatic install ==="
  echo "Extension id: ${EXT_ID}"
  echo "Local: ${INSTALL_DIR}/companion.crx"
fi

write_policy "${HOME}/.config/google-chrome/policies/managed" "Chrome"
write_policy "${HOME}/.config/chromium/policies/managed" "Chromium"
write_policy "${HOME}/.config/brave/policies/managed" "Brave"
write_policy "${HOME}/.config/brave-browser/policies/managed" "Brave (alt)"
write_policy "${HOME}/.config/microsoft-edge/policies/managed" "Edge"
write_policy "${HOME}/.config/vivaldi/policies/managed" "Vivaldi"
write_policy "${HOME}/.var/app/com.vivaldi.Vivaldi/config/vivaldi/policies/managed" "Vivaldi Flatpak"
write_policy "${HOME}/.var/app/com.google.Chrome/config/google-chrome/policies/managed" "Chrome Flatpak"
write_policy "${HOME}/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/policies/managed" "Brave Flatpak"

write_external "${HOME}/.config/google-chrome/External Extensions" "Chrome" || true
write_external "${HOME}/.config/chromium/External Extensions" "Chromium" || true
write_external "${HOME}/.config/vivaldi/External Extensions" "Vivaldi" || true
write_external "${HOME}/.config/brave/External Extensions" "Brave" || true
write_external "${HOME}/.config/microsoft-edge/External Extensions" "Edge" || true

# Soft-restart browser so managed policy is applied (user session)
restart_browser() {
  local bin="$1"
  command -v "${bin}" >/dev/null 2>&1 || return 0
  if pgrep -x "${bin}" >/dev/null 2>&1 || pgrep -f "${bin}" >/dev/null 2>&1; then
    if [[ "${lang}" == de ]]; then
      echo "Starte ${bin} neu, damit die Policy greift…"
    else
      echo "Restarting ${bin} so the policy applies…"
    fi
    pkill -x "${bin}" 2>/dev/null || pkill -f "/${bin}" 2>/dev/null || true
    sleep 2
  fi
  nohup "${bin}" >/dev/null 2>&1 &
  echo "  started ${bin}"
}

echo
# Prefer the browser the user actually runs
for bin in vivaldi google-chrome-stable google-chrome chromium brave-browser microsoft-edge; do
  if command -v "${bin}" >/dev/null 2>&1; then
    restart_browser "${bin}"
    break
  fi
done

echo
if [[ "${lang}" == de ]]; then
  echo "Fertig. Die Erweiterung sollte ohne Drag&Drop erscheinen."
  echo "Prüfen: vivaldi://extensions  oder  chrome://extensions"
  echo "  → „JD Turnstile Companion“ v${VER} (ID ${EXT_ID})"
  echo "Falls sie fehlt: Browser einmal komplett beenden und neu öffnen."
  echo "  Kontrolle der Policy: chrome://policy  (ExtensionInstallForcelist)"
  echo "Updates: Installer erneut ausführen, oder später GitHub-Feed ${REPO_UPDATES_URL}"
else
  echo "Done. The add-on should appear without drag-and-drop."
  echo "Check: vivaldi://extensions  or  chrome://extensions"
  echo "  → “JD Turnstile Companion” v${VER} (id ${EXT_ID})"
  echo "If missing: fully quit the browser and open it again."
  echo "  Policy check: chrome://policy  (ExtensionInstallForcelist)"
  echo "Updates: re-run this installer, or GitHub feed ${REPO_UPDATES_URL}"
fi
