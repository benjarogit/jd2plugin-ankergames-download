#!/usr/bin/env bash
# Install JD Turnstile Companion into Firefox as a normal add-on (.xpi).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="${ROOT}/dist"
VER="$(python3 -c "import json; print(json.load(open('${ROOT}/firefox/manifest.json'))['version'])")"
XPI="${DIST}/jd-turnstile-companion-firefox-${VER}.xpi"
ADDON_ID="jd-turnstile-companion@benjarogit.github.io"
UPDATE_JSON="https://raw.githubusercontent.com/benjarogit/jd2plugin-ankergames-download/main/updates/firefox.json"

chmod +x "${ROOT}/build-packages.sh"
"${ROOT}/build-packages.sh" >/dev/null
[[ -f "${XPI}" ]] || { echo "ERROR: XPI missing after build"; exit 1; }

echo "=== Install Firefox companion v${VER} ==="
echo "XPI: ${XPI}"
echo "Update feed: ${UPDATE_JSON}"

INSTALL_DIR="${HOME}/.local/share/jd-turnstile-companion"
mkdir -p "${INSTALL_DIR}"
cp -f "${XPI}" "${INSTALL_DIR}/jd-turnstile-companion.xpi"
echo "Copied to ${INSTALL_DIR}/jd-turnstile-companion.xpi"

FIREFOX=""
for bin in firefox firefox-bin firefox-developer-edition firefox-nightly; do
  if command -v "${bin}" >/dev/null 2>&1; then
    FIREFOX="${bin}"
    break
  fi
done

echo
echo "Finish in Firefox (do not type numbers into the terminal):"
echo "  • Confirm the add-on install prompt, OR"
echo "  • about:addons → gear → Install Add-on From File…"
echo "    → ${INSTALL_DIR}/jd-turnstile-companion.xpi"
echo
echo "Signing:"
echo "  • Release Firefox needs a Mozilla-signed XPI (see companion/SIGNING.md)."
echo "  • Developer Edition / Nightly: about:config → xpinstall.signatures.required = false"
echo
echo "Updates: signed XPIs poll ${UPDATE_JSON} ; else toolbar badge ↑"
echo

if [[ -n "${FIREFOX}" ]]; then
  nohup "${FIREFOX}" "file://${INSTALL_DIR}/jd-turnstile-companion.xpi" >/dev/null 2>&1 &
  echo "Started ${FIREFOX} with the XPI — confirm the install prompt."
else
  echo "Firefox binary not found in PATH. Open the XPI manually:"
  echo "  ${INSTALL_DIR}/jd-turnstile-companion.xpi"
fi

echo
echo "Add-on id: ${ADDON_ID}"
echo "Done."
