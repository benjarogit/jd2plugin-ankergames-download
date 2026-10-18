#!/usr/bin/env bash
# One entry point: install the companion into Firefox and/or Chromium family.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
chmod +x "${ROOT}/build-packages.sh" "${ROOT}/install-firefox.sh" "${ROOT}/install-chromium.sh"

echo "JD Turnstile Companion — build + install"
echo "  [1] Firefox (.xpi)"
echo "  [2] Chrome / Chromium / Vivaldi / Brave / Edge (.crx + GitHub updates)"
echo "  [3] Both"
echo "  [4] Safari info only (macOS + Apple Developer — see companion/safari/README.md)"
echo
read -r -p "Choice [3]: " choice
choice="${choice:-3}"

case "${choice}" in
  1) "${ROOT}/install-firefox.sh" ;;
  2) "${ROOT}/install-chromium.sh" ;;
  3)
    "${ROOT}/install-firefox.sh" || true
    echo
    "${ROOT}/install-chromium.sh"
    ;;
  4)
    echo "Safari cannot be packaged on Linux."
    echo "On a Mac, follow: ${ROOT}/safari/README.md"
    ;;
  *)
    echo "Invalid choice"
    exit 1
    ;;
esac
