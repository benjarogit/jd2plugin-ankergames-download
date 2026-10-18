#!/usr/bin/env bash
# Prepare Firefox companion (.xpi) and print clear unsigned-install steps.
# Optional: if AMO_JWT_* is set, also try Mozilla signing for Release Firefox.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="${ROOT}/dist"
VER="$(python3 -c "import json; print(json.load(open('${ROOT}/firefox/manifest.json'))['version'])")"
XPI_UNSIGNED="${DIST}/jd-turnstile-companion-firefox-${VER}.xpi"
ADDON_ID="jd-turnstile-companion@benjarogit.github.io"

lang=en
case "${LANG:-}${LC_ALL:-}" in
  [Dd][Ee]*|*[Dd]eutsch*) lang=de ;;
esac
[[ "${1:-}" == "--de" ]] && lang=de && shift
[[ "${1:-}" == "--en" ]] && lang=en && shift

chmod +x "${ROOT}/build-packages.sh"
"${ROOT}/build-packages.sh" >/dev/null
[[ -f "${XPI_UNSIGNED}" ]] || { echo "ERROR: XPI missing after build"; exit 1; }

INSTALL_DIR="${HOME}/.local/share/jd-turnstile-companion"
mkdir -p "${INSTALL_DIR}"
cp -f "${XPI_UNSIGNED}" "${INSTALL_DIR}/jd-turnstile-companion.xpi"
XPI_FILE="${INSTALL_DIR}/jd-turnstile-companion.xpi"

# Optional AMO sign (not required)
if [[ -n "${AMO_JWT_ISSUER:-}" && -n "${AMO_JWT_SECRET:-}" ]]; then
  if [[ "${lang}" == de ]]; then
    echo "Optional: AMO-Signatur wird versucht…"
  else
    echo "Optional: trying AMO signature…"
  fi
  npx --yes web-ext sign \
    --source-dir "${ROOT}/firefox" \
    --channel unlisted \
    --api-key "${AMO_JWT_ISSUER}" \
    --api-secret "${AMO_JWT_SECRET}" \
    --artifacts-dir "${DIST}" \
    --timeout 120000 \
    && {
      newest="$(ls -t "${DIST}"/*.xpi 2>/dev/null | head -1 || true)"
      [[ -n "${newest}" ]] && cp -f "${newest}" "${XPI_FILE}"
    } || true
fi

FIREFOX=""
for bin in firefox-developer-edition firefox-nightly firefox firefox-bin; do
  if command -v "${bin}" >/dev/null 2>&1; then
    FIREFOX="${bin}"
    break
  fi
done

echo
if [[ "${lang}" == de ]]; then
  cat <<EOF
=== Firefox-Companion v${VER} ===
XPI bereit: ${XPI_FILE}
Add-on-ID: ${ADDON_ID}

Unsigniert installieren (empfohlen — keine AMO-Keys nötig):

  1) Firefox Developer Edition oder Nightly nutzen
     (Release-Firefox blockiert unsignierte Add-ons.)
  2) about:config  →  xpinstall.signatures.required  →  false
  3) about:addons  →  Zahnrad  →  „Add-on aus Datei installieren…“
     → Datei wählen: ${XPI_FILE}
  4) In JDownloader denselben Firefox für Captchas einstellen

Alternativ (nur bis zum Neustart):
  about:debugging#/runtime/this-firefox
  → „Temporäres Add-on laden…“ → companion/firefox/manifest.json

Ausführlich: companion/INSTALL-BROWSER.md
EOF
else
  cat <<EOF
=== Firefox companion v${VER} ===
XPI ready: ${XPI_FILE}
Add-on id: ${ADDON_ID}

Install unsigned (recommended — no AMO keys):

  1) Use Firefox Developer Edition or Nightly
     (Release Firefox blocks unsigned add-ons.)
  2) about:config  →  xpinstall.signatures.required  →  false
  3) about:addons  →  gear  →  “Install Add-on From File…”
     → pick: ${XPI_FILE}
  4) Point JDownloader captchas at that same Firefox

Alternative (until browser restart only):
  about:debugging#/runtime/this-firefox
  → “Load Temporary Add-on…” → companion/firefox/manifest.json

Details: companion/INSTALL-BROWSER.md
EOF
fi

if [[ -n "${FIREFOX}" ]]; then
  nohup "${FIREFOX}" "file://${XPI_FILE}" >/dev/null 2>&1 &
  if [[ "${lang}" == de ]]; then
    echo
    echo "Geöffnet: ${FIREFOX} mit der XPI — Dialog bestätigen (nur wenn Signaturen aus sind)."
  else
    echo
    echo "Opened ${FIREFOX} with the XPI — confirm if signature checks are disabled."
  fi
fi
