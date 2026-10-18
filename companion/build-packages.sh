#!/usr/bin/env bash
# Build Chromium companion packages: .zip + .crx
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="${ROOT}/dist"
CH="${ROOT}/chromium"
VER="$(python3 -c "import json; print(json.load(open('${CH}/manifest.json'))['version'])")"

mkdir -p "${DIST}"
rm -f "${DIST}/jd-turnstile-companion-chromium-${VER}.zip" \
  "${DIST}/jd-turnstile-companion-chromium-${VER}.crx" 2>/dev/null || true

echo "Building Chromium ZIP v${VER} ..."
(
  cd "${CH}"
  zip -r -FS "${DIST}/jd-turnstile-companion-chromium-${VER}.zip" \
    manifest.json background.js update-check.js solver.js local-hook.js ankergames-hook.js cdn-pipe.js \
    dnr-rules.json hold.html offscreen.html offscreen.js \
    icons icon48.png \
    -x "*.md" -x ".git*"
)

KEY="${ROOT}/signing/chromium.pem"
if [[ -f "${KEY}" ]]; then
  PACKER=""
  for bin in vivaldi google-chrome-stable google-chrome chromium chromium-browser microsoft-edge brave-browser; do
    if command -v "${bin}" >/dev/null 2>&1; then
      PACKER="${bin}"
      break
    fi
  done
  if [[ -n "${PACKER}" ]]; then
    echo "Packing CRX with ${PACKER} ..."
    WORK="$(mktemp -d)"
    cp -a "${CH}/." "${WORK}/ext/"
    "${PACKER}" --pack-extension="${WORK}/ext" --pack-extension-key="${KEY}" >/dev/null 2>&1 || true
    if [[ -f "${WORK}/ext.crx" ]]; then
      cp -f "${WORK}/ext.crx" "${DIST}/jd-turnstile-companion-chromium-${VER}.crx"
      echo "CRX OK"
    else
      echo "WARN: CRX pack did not produce a file (browser may need a display). ZIP is still available."
    fi
    rm -rf "${WORK}"
  else
    echo "WARN: No Chrome/Vivaldi binary for CRX pack — ZIP only."
  fi
fi

EXT_ID_FILE="${ROOT}/signing/chromium-extension-id.txt"
if [[ -f "${EXT_ID_FILE}" ]]; then
  cp -f "${EXT_ID_FILE}" "${DIST}/chromium-extension-id.txt"
fi

echo
echo "Artifacts in ${DIST}:"
ls -la "${DIST}"
echo
echo "Chromium: jd-turnstile-companion-chromium-${VER}.zip (+ .crx if packed)"
echo "Extension ID: $(cat "${EXT_ID_FILE}" 2>/dev/null || echo unknown)"
