#!/usr/bin/env bash
# Install JD Turnstile Companion into Firefox.
# Release Firefox only auto-installs *Mozilla-signed* XPIs (enterprise policy or file install).
# This script: signs via AMO if credentials exist, then force-installs via policies.json.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="${ROOT}/dist"
VER="$(python3 -c "import json; print(json.load(open('${ROOT}/firefox/manifest.json'))['version'])")"
XPI_UNSIGNED="${DIST}/jd-turnstile-companion-firefox-${VER}.xpi"
XPI_SIGNED="${DIST}/jd-turnstile-companion-firefox-${VER}-signed.xpi"
ADDON_ID="jd-turnstile-companion@benjarogit.github.io"
UPDATE_JSON="https://raw.githubusercontent.com/benjarogit/jd2plugin-ankergames-download/main/updates/firefox.json"

lang=en
case "${LANG:-}${LC_ALL:-}" in
  [Dd][Ee]*|*[Dd]eutsch*) lang=de ;;
esac

chmod +x "${ROOT}/build-packages.sh"
"${ROOT}/build-packages.sh" >/dev/null
[[ -f "${XPI_UNSIGNED}" ]] || { echo "ERROR: XPI missing after build"; exit 1; }

INSTALL_DIR="${HOME}/.local/share/jd-turnstile-companion"
mkdir -p "${INSTALL_DIR}"

XPI_USE="${XPI_UNSIGNED}"

# --- optional AMO signing (makes Release Firefox accept + auto-update) ---
try_sign() {
  if [[ -f "${XPI_SIGNED}" ]]; then
    XPI_USE="${XPI_SIGNED}"
    return 0
  fi
  if [[ -z "${AMO_JWT_ISSUER:-}" || -z "${AMO_JWT_SECRET:-}" ]]; then
    return 1
  fi
  if [[ "${lang}" == de ]]; then
    echo "Signiere XPI über AMO (unlisted)…"
  else
    echo "Signing XPI via AMO (unlisted)…"
  fi
  npx --yes web-ext sign \
    --source-dir "${ROOT}/firefox" \
    --channel unlisted \
    --api-key "${AMO_JWT_ISSUER}" \
    --api-secret "${AMO_JWT_SECRET}" \
    --artifacts-dir "${DIST}" || return 1
  # web-ext names vary; pick newest .xpi that is not our unsigned build name only
  local newest
  newest="$(ls -t "${DIST}"/*.xpi 2>/dev/null | head -1 || true)"
  if [[ -n "${newest}" ]]; then
    cp -f "${newest}" "${XPI_SIGNED}"
    XPI_USE="${XPI_SIGNED}"
    return 0
  fi
  return 1
}

SIGNED=0
if try_sign; then
  SIGNED=1
elif [[ -f "${XPI_SIGNED}" ]]; then
  XPI_USE="${XPI_SIGNED}"
  SIGNED=1
fi

cp -f "${XPI_USE}" "${INSTALL_DIR}/jd-turnstile-companion.xpi"
XPI_FILE="${INSTALL_DIR}/jd-turnstile-companion.xpi"
INSTALL_URL="file://${XPI_FILE}"

write_firefox_policies() {
  local policy_file="$1"
  mkdir -p "$(dirname "${policy_file}")"
  # Merge-friendly single-purpose file when using /etc drop-in style; for policies.json replace carefully
  python3 - <<PY
import json, os
path = "${policy_file}"
addon = "${ADDON_ID}"
url = "${INSTALL_URL}"
data = {}
if os.path.isfile(path):
    try:
        data = json.load(open(path))
    except Exception:
        data = {}
policies = data.setdefault("policies", {})
ext = policies.setdefault("ExtensionSettings", {})
ext[addon] = {
    "installation_mode": "force_installed",
    "install_url": url,
}
# Allow install from file
sources = policies.setdefault("ExtensionInstallForcelist", [])
# Firefox uses ExtensionSettings primarily
open(path, "w").write(json.dumps(data, indent=2) + "\n")
print(path)
PY
}

if [[ "${lang}" == de ]]; then
  echo "=== Firefox-Companion v${VER} ==="
else
  echo "=== Firefox companion v${VER} ==="
fi
echo "XPI: ${XPI_FILE}"
echo "Signed: ${SIGNED} (1=yes)"

# User-writable locations some Firefox builds read + system path via sudo
USER_POLICY="${HOME}/.mozilla/policies/policies.json"
write_firefox_policies "${USER_POLICY}"
echo "  OK user policy: ${USER_POLICY}"

# System policy (most reliable on Linux Release Firefox)
SYS_POLICY="/etc/firefox/policies/policies.json"
if [[ -w "/etc/firefox/policies" ]] || sudo -n true 2>/dev/null; then
  if [[ "${lang}" == de ]]; then
    echo "Schreibe System-Policy (sudo)…"
  else
    echo "Writing system policy (sudo)…"
  fi
  sudo mkdir -p /etc/firefox/policies
  TMP_POL="$(mktemp)"
  write_firefox_policies "${TMP_POL}"
  if [[ -f "${SYS_POLICY}" ]]; then
    # merge with existing
    sudo python3 - <<PY
import json
sys_p = "${SYS_POLICY}"
new_p = "${TMP_POL}"
try:
    a = json.load(open(sys_p))
except Exception:
    a = {"policies": {}}
b = json.load(open(new_p))
a.setdefault("policies", {}).setdefault("ExtensionSettings", {}).update(
    b.get("policies", {}).get("ExtensionSettings", {})
)
open("/tmp/jd-ff-policies-merged.json", "w").write(json.dumps(a, indent=2) + "\n")
PY
    sudo cp /tmp/jd-ff-policies-merged.json "${SYS_POLICY}"
  else
    sudo cp "${TMP_POL}" "${SYS_POLICY}"
  fi
  rm -f "${TMP_POL}"
  echo "  OK system policy: ${SYS_POLICY}"
else
  if [[ "${lang}" == de ]]; then
    echo "Hinweis: ohne sudo keine System-Policy unter /etc/firefox/policies/"
    echo "  Einmalig: sudo mkdir -p /etc/firefox/policies && sudo cp ${USER_POLICY} ${SYS_POLICY}"
  else
    echo "Note: without sudo, no system policy at /etc/firefox/policies/"
    echo "  Once: sudo mkdir -p /etc/firefox/policies && sudo cp ${USER_POLICY} ${SYS_POLICY}"
  fi
fi

# Restart Firefox
if pgrep -x firefox >/dev/null 2>&1; then
  if [[ "${lang}" == de ]]; then
    echo "Starte Firefox neu…"
  else
    echo "Restarting Firefox…"
  fi
  pkill -x firefox 2>/dev/null || true
  sleep 2
fi
if command -v firefox >/dev/null 2>&1; then
  nohup firefox >/dev/null 2>&1 &
fi

echo
if [[ "${SIGNED}" -eq 1 ]]; then
  if [[ "${lang}" == de ]]; then
    echo "Signiertes XPI + Policy gesetzt → Auto-Install nach Firefox-Neustart."
    echo "Prüfen: about:addons"
  else
    echo "Signed XPI + policy set → auto-install after Firefox restart."
    echo "Check: about:addons"
  fi
else
  if [[ "${lang}" == de ]]; then
    echo "XPI ist NOCH NICHT Mozilla-signiert — Release-Firefox blockiert Auto-Install."
    echo
    echo "Damit es automatisch geht (einmalig, kostenlos):"
    echo "  1) https://addons.mozilla.org/developers/addon/api/key/"
    echo "  2) export AMO_JWT_ISSUER='…'"
    echo "  3) export AMO_JWT_SECRET='…'"
    echo "  4) ./install-firefox.sh   # signiert und installiert"
    echo
    echo "Sofort ohne Signatur: Firefox Developer Edition,"
    echo "  about:config → xpinstall.signatures.required = false"
    echo "  dann: about:addons → Zahnrad → Add-on aus Datei → ${XPI_FILE}"
  else
    echo "XPI is NOT Mozilla-signed yet — Release Firefox blocks auto-install."
    echo
    echo "To make it automatic (one-time, free):"
    echo "  1) https://addons.mozilla.org/developers/addon/api/key/"
    echo "  2) export AMO_JWT_ISSUER='…'"
    echo "  3) export AMO_JWT_SECRET='…'"
    echo "  4) ./install-firefox.sh   # signs and installs"
    echo
    echo "Immediate without signing: Firefox Developer Edition,"
    echo "  about:config → xpinstall.signatures.required = false"
    echo "  then: about:addons → gear → Install from file → ${XPI_FILE}"
  fi
fi
