#!/usr/bin/env bash
# Browser companion only. Prefer repo-root ./install.sh for the full setup.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
chmod +x "${ROOT}/build-packages.sh" "${ROOT}/install-firefox.sh" "${ROOT}/install-chromium.sh"

lang=en
case "${LANG:-}${LC_ALL:-}" in
  [Dd][Ee]*|*[Dd]eutsch*) lang=de ;;
esac
[[ "${1:-}" == "--de" ]] && lang=de && shift
[[ "${1:-}" == "--en" ]] && lang=en && shift

if [[ "${lang}" == de ]]; then
  echo "JD Turnstile Companion — nur Browser-Erweiterung"
  echo
  echo "Welchen Browser nutzt du? Tippe den Namen (keine Nummer):"
  echo "  vivaldi | chrome | brave | edge | firefox | all | skip"
else
  echo "JD Turnstile Companion — browser add-on only"
  echo
  echo "Which browser do you use? Type the name (not a number):"
  echo "  vivaldi | chrome | brave | edge | firefox | all | skip"
fi
echo
read -r -p "$([[ "${lang}" == de ]] && echo 'Browser [vivaldi]: ' || echo 'Browser [vivaldi]: ')" browser
browser="$(printf '%s' "${browser:-vivaldi}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

case "${browser}" in
  vivaldi|chrome|chromium|brave|edge|all)
    "${ROOT}/install-chromium.sh"
    if [[ "${browser}" == all ]]; then
      "${ROOT}/install-firefox.sh" || true
    fi
    ;;
  firefox|ff)
    "${ROOT}/install-firefox.sh"
    ;;
  skip|s|n|no|nein)
    echo "$([[ "${lang}" == de ]] && echo 'Übersprungen.' || echo 'Skipped.')"
    ;;
  *)
    echo "Unknown: ${browser}"
    exit 1
    ;;
esac
