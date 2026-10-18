#!/usr/bin/env bash
# Find JDownloader install folders on this computer (portable + normal).
# Prints JD root and the plugin path a dummy user should copy into.
set -euo pipefail

is_jd_home() {
  local d="$1"
  [[ -d "$d" && -f "$d/JDownloader.jar" && -f "$d/Core.jar" && -d "$d/jd/plugins" ]]
}

lang=en
case "${LANG:-}${LC_ALL:-}" in
  [Dd][Ee]*|*[Dd]eutsch*) lang=de ;;
esac

declare -a found=()

add_if_jd() {
  local d="$1"
  [[ -n "$d" ]] || return 0
  # resolve relative / ~
  d="$(cd "$d" 2>/dev/null && pwd)" || return 0
  if is_jd_home "$d"; then
    local i
    for i in "${found[@]:-}"; do
      [[ "$i" == "$d" ]] && return 0
    done
    found+=("$d")
  fi
}

# 1) Well-known locations
for c in \
  "${HOME}/.jd" \
  "${HOME}/jd2" \
  "${HOME}/JDownloader2" \
  "${HOME}/JDownloader 2.0" \
  "${HOME}/JDownloader" \
  "${HOME}/Applications/JDownloader 2.0" \
  "${HOME}/Library/Application Support/JDownloader" \
  "/opt/jdownloader2" \
  "/usr/local/jdownloader2" \
  "/usr/share/jdownloader2"
do
  add_if_jd "$c"
done

# 2) Shallow search under home (portable installs often live on Desktop/Downloads)
if [[ "${lang}" == de ]]; then
  echo "Suche nach JDownloader.jar unter dem Home-Verzeichnis (kann etwas dauern)…"
else
  echo "Searching for JDownloader.jar under your home folder (may take a moment)…"
fi

while IFS= read -r -d '' jar; do
  add_if_jd "$(dirname "$jar")"
done < <(
  find "${HOME}" \
    \( -path "${HOME}/.cache" -o -path "${HOME}/.local/share/Trash" -o -path "*/node_modules/*" -o -path "*/.git/*" \) -prune -o \
    -name "JDownloader.jar" -type f -print0 2>/dev/null | head -z -n 40
)

echo
if [[ "${#found[@]}" -eq 0 ]]; then
  if [[ "${lang}" == de ]]; then
    cat <<EOF
Kein JDownloader-Ordner gefunden.

So findest du ihn selbst:
  1) Dateimanager / Windows-Suche: nach  JDownloader.jar  suchen
  2) Der Ordner, in dem diese Datei liegt, ist dein JD-Root
     (dort liegen auch Core.jar und der Unterordner jd/)
  3) Portable Version: der Ordner, in den du JD entpackt hast

Dann Plugins hierhin kopieren:
  <JD-Root>/jd/plugins/hoster/
  <JD-Root>/jd/plugins/decrypter/
  <JD-Root>/jd/plugins/components/
EOF
  else
    cat <<EOF
No JDownloader folder found.

Find it yourself:
  1) File manager / Windows search: look for  JDownloader.jar
  2) The folder that contains that file is your JD root
     (Core.jar and a jd/ subfolder should be next to it)
  3) Portable: the folder you extracted JD into

Then copy plugins into:
  <JD-Root>/jd/plugins/hoster/
  <JD-Root>/jd/plugins/decrypter/
  <JD-Root>/jd/plugins/components/
EOF
  fi
  exit 1
fi

if [[ "${lang}" == de ]]; then
  echo "Gefundene JDownloader-Installation(en):"
  echo
else
  echo "Found JDownloader install(s):"
  echo
fi

i=1
for d in "${found[@]}"; do
  echo "────────────────────────────────────────"
  echo "  #$i"
  if [[ "${lang}" == de ]]; then
    echo "  JD-Root (JDownloader.jar + Core.jar):"
    echo "    $d"
    echo "  Plugin-Ordner (hierhin kopieren):"
    echo "    $d/jd/plugins/"
    echo "  Core.jar patchen:"
    echo "    $d/Core.jar"
  else
    echo "  JD root (JDownloader.jar + Core.jar):"
    echo "    $d"
    echo "  Plugin folder (copy files here):"
    echo "    $d/jd/plugins/"
    echo "  Patch Core.jar:"
    echo "    $d/Core.jar"
  fi
  echo
  i=$((i + 1))
done

if [[ "${#found[@]}" -gt 1 ]]; then
  if [[ "${lang}" == de ]]; then
    echo "Mehrere Installationen — nimm die, die du wirklich startest"
    echo "(Verknüpfung prüfen / portable Ordner)."
    echo "Installer:  JD_HOME=\"/pfad/zum/richtigen/root\" ./install.sh"
  else
    echo "Multiple installs — use the one you actually launch"
    echo "(check your shortcut / portable folder)."
    echo "Installer:  JD_HOME=\"/path/to/correct/root\" ./install.sh"
  fi
else
  if [[ "${lang}" == de ]]; then
    echo "Optionaler Helfer mit diesem Ordner:"
    echo "  JD_HOME=\"${found[0]}\" ./install.sh"
  else
    echo "Optional helper with this folder:"
    echo "  JD_HOME=\"${found[0]}\" ./install.sh"
  fi
fi
