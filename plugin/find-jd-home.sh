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

Was du jetzt tun kannst:
  1) JDownloader einmal starten (damit der Ordner entsteht)
  2) Rechtsklick auf die Verknüpfung → „Dateipfad öffnen“
  3) Am PC nach  JDownloader.jar  suchen (Dateimanager / Suche)
     → der Ordner mit dieser Datei ist dein JD-Root
  4) Portable: schau, wohin du JD entpackt hast
     (Desktop, Downloads, USB, anderes Laufwerk)
  5) Alternativ nach  Core.jar  suchen — muss neben JDownloader.jar liegen

Dann Plugins hierhin kopieren:
  <JD-Root>/jd/plugins/hoster/
  <JD-Root>/jd/plugins/decrypter/
  <JD-Root>/jd/plugins/components/

Mehr dazu: README.de.md → „Wenn nichts gefunden wird“
EOF
  else
    cat <<EOF
No JDownloader folder found.

What to try next:
  1) Start JDownloader once (so it creates its folder)
  2) Right-click the shortcut → “Open file location”
  3) Search the PC for  JDownloader.jar
     → the folder containing that file is your JD root
  4) Portable: look where you extracted JD
     (Desktop, Downloads, USB, another drive)
  5) Or search for  Core.jar  — it must sit next to JDownloader.jar

Then copy plugins into:
  <JD-Root>/jd/plugins/hoster/
  <JD-Root>/jd/plugins/decrypter/
  <JD-Root>/jd/plugins/components/

More detail: README.md → “If nothing is found”
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
    echo "Dann Plugins manuell nach …/jd/plugins/ kopieren (siehe README)."
  else
    echo "Multiple installs — use the one you actually launch"
    echo "(check your shortcut / portable folder)."
    echo "Then copy plugins manually into …/jd/plugins/ (see README)."
  fi
else
  if [[ "${lang}" == de ]]; then
    echo "Als Nächstes: Plugins manuell nach"
    echo "  ${found[0]}/jd/plugins/"
    echo "kopieren und Core.jar patchen (siehe README)."
  else
    echo "Next: copy plugins manually into"
    echo "  ${found[0]}/jd/plugins/"
    echo "and patch Core.jar (see README)."
  fi
fi
