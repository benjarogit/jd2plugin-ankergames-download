#!/usr/bin/env bash
# AnkerGames plugin + Core Turnstile patch for JDownloader 2 (Linux / macOS)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLUGIN_HOSTER_DIR="${SCRIPT_DIR}/plugins/hoster"
PLUGIN_CRAWLER_DIR="${SCRIPT_DIR}/plugins/decrypter"
PLUGIN_COMPONENTS_DIR="${SCRIPT_DIR}/plugins/components"
CORE_PATCH_DIR="${ROOT_DIR}/core-patch"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

need_file() {
  [[ -f "$1" ]] || die "Missing file in package: $1"
}

need_file "${PLUGIN_HOSTER_DIR}/AnkergamesNet.class"
need_file "${PLUGIN_CRAWLER_DIR}/AnkergamesNetCrawler.class"
need_file "${PLUGIN_COMPONENTS_DIR}/AnkergamesCdnRelay.class"
need_file "${CORE_PATCH_DIR}/turnstile.html"
need_file "${CORE_PATCH_DIR}/CloudflareTurnstileChallenge.class"

is_jd_home() {
  local d="$1"
  [[ -d "$d" && -f "$d/JDownloader.jar" && -f "$d/Core.jar" && -d "$d/jd/plugins" ]]
}

detect_jd_home() {
  if [[ -n "${JD_HOME:-}" ]]; then
    is_jd_home "${JD_HOME}" || die "JD_HOME is set but invalid: ${JD_HOME}"
    echo "${JD_HOME}"
    return
  fi
  local candidates=(
    "${HOME}/.jd"
    "${HOME}/jd2"
    "${HOME}/JDownloader2"
    "${HOME}/JDownloader 2.0"
    "${HOME}/Library/Application Support/JDownloader"
    "/opt/jdownloader2"
    "/usr/local/jdownloader2"
  )
  local c
  for c in "${candidates[@]}"; do
    if is_jd_home "$c"; then
      echo "$c"
      return
    fi
  done
  die "JDownloader folder not found. Set JD_HOME to your JD directory (contains JDownloader.jar + Core.jar)."
}

wait_until_stopped() {
  local pid_file="$1"
  local i
  for i in $(seq 1 30); do
    if [[ -f "${pid_file}" ]]; then
      local pid
      pid="$(tr -d '[:space:]' < "${pid_file}" || true)"
      if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
        sleep 1
        continue
      fi
    fi
    if pgrep -f '[jJ]Downloader\.jar' >/dev/null 2>&1; then
      sleep 1
      continue
    fi
    return 0
  done
  return 1
}

stop_jd() {
  local jd_home="$1"
  local pid_file="${jd_home}/JDownloader.pid"
  echo "Stopping JDownloader ..."

  if [[ -f "${pid_file}" ]]; then
    local pid
    pid="$(tr -d '[:space:]' < "${pid_file}" || true)"
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      kill "${pid}" 2>/dev/null || true
    fi
  fi

  if command -v pgrep >/dev/null 2>&1; then
    local p
    for p in $(pgrep -u "$(id -u)" -f '[jJ]Downloader\.jar' || true); do
      kill "${p}" 2>/dev/null || true
    done
  fi

  if ! wait_until_stopped "${pid_file}"; then
    echo "JDownloader did not exit in time — forcing ..."
    if [[ -f "${pid_file}" ]]; then
      local pid
      pid="$(tr -d '[:space:]' < "${pid_file}" || true)"
      if [[ -n "${pid}" ]]; then
        kill -9 "${pid}" 2>/dev/null || true
      fi
    fi
    if command -v pkill >/dev/null 2>&1; then
      pkill -9 -u "$(id -u)" -f '[jJ]Downloader\.jar' 2>/dev/null || true
    fi
    sleep 1
  fi
  echo "JDownloader stopped."
}

install_plugin_files() {
  local jd_home="$1"
  local hoster_dir="${jd_home}/jd/plugins/hoster"
  local crawler_dir="${jd_home}/jd/plugins/decrypter"
  local components_dir="${jd_home}/jd/plugins/components"
  mkdir -p "${hoster_dir}" "${crawler_dir}" "${components_dir}"
  cp -f "${PLUGIN_HOSTER_DIR}"/AnkergamesNet*.class "${hoster_dir}/"
  cp -f "${PLUGIN_CRAWLER_DIR}"/AnkergamesNetCrawler*.class "${crawler_dir}/"
  cp -f "${PLUGIN_COMPONENTS_DIR}"/AnkergamesCdnRelay*.class "${components_dir}/"
  mkdir -p "${jd_home}/tmp"
  : > "${jd_home}/tmp/hosterCache"
  : > "${jd_home}/tmp/crawlerCache"
  echo "Plugin classes installed (hoster + crawler + AnkergamesCdnRelay)."
}

patch_core_jar() {
  local jd_home="$1"
  local core="${jd_home}/Core.jar"
  local stamp
  stamp="$(date +%Y%m%d%H%M%S)"
  cp -f "${core}" "${core}.bak-ankergames-${stamp}"
  echo "Backed up Core.jar → Core.jar.bak-ankergames-${stamp}"

  local work
  work="$(mktemp -d)"
  mkdir -p "${work}/org/jdownloader/captcha/v2/challenge/cloudflareturnstile"
  cp -f "${CORE_PATCH_DIR}/turnstile.html" \
    "${work}/org/jdownloader/captcha/v2/challenge/cloudflareturnstile/"
  cp -f "${CORE_PATCH_DIR}/CloudflareTurnstileChallenge.class" \
    "${work}/org/jdownloader/captcha/v2/challenge/cloudflareturnstile/"

  (
    cd "${work}"
    jar uf "${core}" \
      org/jdownloader/captcha/v2/challenge/cloudflareturnstile/turnstile.html \
      org/jdownloader/captcha/v2/challenge/cloudflareturnstile/CloudflareTurnstileChallenge.class
  )
  rm -rf "${work}"
  echo "Core.jar patched (Turnstile HTML + challenge class with relay metas)."
}

start_jd() {
  local jd_home="$1"
  echo "Starting JDownloader ..."
  (
    cd "${jd_home}"
    if [[ -x "./JDownloader2" ]]; then
      nohup ./JDownloader2 >/dev/null 2>&1 &
    elif [[ -x "./jdownloader2" ]]; then
      nohup ./jdownloader2 >/dev/null 2>&1 &
    else
      nohup java -jar JDownloader.jar >/dev/null 2>&1 &
    fi
  )
  echo "JDownloader start requested."
}

main() {
  local lang="en"
  case "${LANG:-}${LC_ALL:-}" in
    [Dd][Ee]*|*[Dd]eutsch*) lang=de ;;
  esac

  if [[ "${lang}" == de ]]; then
    echo "=== AnkerGames JDownloader — Plugin-Installer ==="
  else
    echo "=== AnkerGames JDownloader — Plugin Installer ==="
  fi

  local jd_home
  jd_home="$(detect_jd_home)"
  echo "JD home: ${jd_home}"
  stop_jd "${jd_home}"
  install_plugin_files "${jd_home}"
  patch_core_jar "${jd_home}"
  start_jd "${jd_home}"
  echo
  if [[ "${lang}" == de ]]; then
    echo "Plugin fertig."
    echo
    echo "WICHTIG — tippe keine Zahl in die Shell."
    echo "Wenn du von der Repo-Wurzel kommst, macht ./install.sh als Nächstes"
    echo "die Browser-Erweiterung. Sonst dort ausführen:"
    echo
    echo "  cd \"${ROOT_DIR}\" && ./install.sh"
    echo
    echo "Danach in JDownloader: Link ankergames.net/game/… hinzufügen,"
    echo "Turnstile lösen, Tab offen lassen."
  else
    echo "Plugin done."
    echo
    echo "IMPORTANT — do not type a number into the shell."
    echo "From the repo root, ./install.sh continues with the browser add-on."
    echo "Or run:"
    echo
    echo "  cd \"${ROOT_DIR}\" && ./install.sh"
    echo
    echo "Then in JDownloader: add ankergames.net/game/…,"
    echo "solve Turnstile, keep the tab open."
  fi
}

main "$@"
