#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PARENT="$(cd "${ROOT}/.." && pwd)"
FF_XPI="${ROOT}/jd-turnstile-companion.xpi"
CHROME_DIR="${PARENT}/jd-turnstile-companion-chromium"

cd "${ROOT}"
zip -r -FS "${FF_XPI}" manifest.json background.js solver.js local-hook.js ankergames-hook.js cdn-pipe.js icon48.png >/dev/null

mkdir -p "${CHROME_DIR}"
cp -f background.js solver.js local-hook.js ankergames-hook.js cdn-pipe.js icon48.png "${CHROME_DIR}/"

cat <<EOF

JD Turnstile Companion 1.0.0 — Firefox + Chromium/Vivaldi
========================================================
CDN-Fetch im AnkerGames-Tab (Browser-TLS) → localhost-Relay → JD.
Tab offen lassen bis Overlay „Stream finished“ / Download fertig.

Firefox:
  about:debugging → Temporäres Add-on → ${ROOT}/manifest.json

Chrome / Edge / Brave / Vivaldi:
  chrome://extensions (bzw. vivaldi://extensions)
  → Entwicklermodus → Entpackt laden → ${CHROME_DIR}

Gleicher Browser wie JD-Captcha („Browser öffnen“).
EOF
