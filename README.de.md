# AnkerGames für JDownloader 2

[Deutsch](#installation) · [English](README.md)

Lädt Spiele von [ankergames.net](https://ankergames.net) in **JDownloader**, obwohl Cloudflare den Java-Client von JD blockiert.

**Kurz:** Du löst Captcha im Browser. Eine kleine Browser-Erweiterung schickt die Datei an JD. JD speichert und zeigt den Fortschritt.

---

## Installation

```bash
git clone https://github.com/benjarogit/jd2plugin-ankergames-download.git
cd jd2plugin-ankergames-download
chmod +x install.sh
./install.sh
```

### Was das Skript macht

1. **JDownloader-Plugin** installieren → mit `J` / Enter bestätigen  
2. **Browser** tippen: `vivaldi`, `chrome`, `brave`, `edge` oder `firefox`  
   *(keine Zahl tippen — nur den Namen)*

### Browser-Erweiterung fertigmachen

Das Skript bereitet die Dateien vor und öffnet die richtige Seite. **Du klickst noch kurz selbst:**

**Vivaldi / Chrome / Brave / Edge**

1. Entwicklermodus einschalten  
2. „Entpackte Erweiterung laden“  
3. Den Ordner wählen, den das Skript anzeigt (auch in der Zwischenablage)

**Firefox**

1. Am besten **Firefox Developer Edition** oder **Nightly**  
2. `about:config` → `xpinstall.signatures.required` → **false**  
3. `about:addons` → Zahnrad → Add-on aus Datei → die `.xpi` vom Skript

Ausführlicher: [companion/INSTALL-BROWSER.md](companion/INSTALL-BROWSER.md)

---

## Benutzung

1. In JDownloader Link hinzufügen, z. B. `https://ankergames.net/game/…`  
2. Turnstile im Browser lösen  
3. **AnkerGames-Tab offen lassen**, bis der Download in JD fertig ist  

Denselben Browser für Captchas und Erweiterung nutzen. MyJDownloader wird **nicht** gebraucht.

---

## Wenn etwas hakt

| Problem | Lösung |
|---------|--------|
| Erweiterung nicht sichtbar | `./install.sh` → Schritt 1 mit `n`, Schritt 2 Browser nochmal; Entwicklermodus + entpackt laden |
| Firefox „nicht verifiziert“ | Developer Edition + `xpinstall.signatures.required = false` |
| JD bei 0 Byte | AnkerGames-Tab offen lassen; Companion v1.4.2+ |
| Browser speichert die ZIP selbst | Companion aktualisieren; CDN-Link nicht manuell öffnen |

---

## So funktioniert’s (kurz)

Cloudflare erkennt JDownloader (Java). Deshalb holt die **Browser-Erweiterung** die Datei und schickt sie an `127.0.0.1` — JD lädt nur lokal weiter.

---

Nicht verbunden mit AppWork / JDownloader / AnkerGames.
