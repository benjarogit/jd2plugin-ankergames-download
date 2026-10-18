#!/usr/bin/env bash
# Install JD Turnstile Companion into Firefox as a normal add-on (from .xpi file).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="${ROOT}/dist"
VER="$(python3 -c "import json; print(json.load(open('${ROOT}/firefox/manifest.json'))['version'])")"
XPI="${DIST}/jd-turnstile-companion-firefox-${VER}.xpi"
ADDON_ID="jd-turnstile-companion@benjarogit.github.io"

chmod +x "${ROOT}/build-packages.sh"
"${ROOT}/build-packages.sh" >/dev/null
[[ -f "${XPI}" ]] || { echo "ERROR: XPI missing after build"; exit 1; }

echo "=== Install Firefox companion v${VER} ==="
echo "XPI: ${XPI}"

# Prefer opening the standard Firefox install dialog for a local .xpi
FIREFOX=""
for bin in firefox firefox-bin firefox-developer-edition firefox-nightly; do
  if command -v "${bin}" >/dev/null 2>&1; then
    FIREFOX="${bin}"
    break
  fi
done

# Also place a copy for "Install Add-on From File…"
INSTALL_DIR="${HOME}/.local/share/jd-turnstile-companion"
mkdir -p "${INSTALL_DIR}"
cp -f "${XPI}" "${INSTALL_DIR}/jd-turnstile-companion.xpi"
echo "Copied to ${INSTALL_DIR}/jd-turnstile-companion.xpi"

# Enterprise-style policy (works with *signed* XPIs; unsigned needs Dev Edition or AMO signing)
POLICY_DIR=""
for d in \
  "${HOME}/.mozilla/firefox" \
  "/etc/firefox/policies" \
  "/usr/lib/firefox/distribution"; do
  if [[ -d "$(dirname "${d}")" ]] || [[ -d "${d}" ]]; then
    :
  fi
done

# User Firefox policies (distribution/policies.json next to binary is system-wide;
# for per-user, use policies in the profile via native messaging — use file install instead.)
echo
echo "Installing via Firefox UI (recommended):"
echo "  1) Firefox opens → confirm add-on install, OR"
echo "  2) about:addons → gear → Install Add-on From File…"
echo "     → choose: ${INSTALL_DIR}/jd-turnstile-companion.xpi"
echo
echo "Note: Release Firefox only accepts *Mozilla-signed* XPIs."
echo "      If install is blocked as 'not verified':"
echo "      - Use Firefox Developer Edition, or"
echo "      - Sign the XPI (AMO self-distribution) — see companion/SIGNING.md"
echo

if [[ -n "${FIREFOX}" ]]; then
  # file:// URL often triggers the install doorhanger for XPIs
  nohup "${FIREFOX}" "file://${INSTALL_DIR}/jd-turnstile-companion.xpi" >/dev/null 2>&1 &
  echo "Started ${FIREFOX} with the XPI — confirm the install prompt."
else
  echo "Firefox binary not found in PATH. Open the XPI manually:"
  echo "  ${INSTALL_DIR}/jd-turnstile-companion.xpi"
fi

echo
echo "Add-on id: ${ADDON_ID}"
echo "Done."
