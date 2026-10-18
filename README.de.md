# AnkerGames für JDownloader 2

[Deutsch](#deutsch) · [English](README.md)

Inoffizielles **JDownloader-2**-Hoster/Crawler-Plugin plus **echte Browser-Erweiterungen** (`.crx` / `.xpi`), damit Downloads von [ankergames.net](https://ankergames.net) trotz Cloudflare funktionieren.

> Nicht verbunden mit AppWork / JDownloader. Der offizielle Support lehnt diesen Hoster ab, weil Cloudflare den Java-HTTP-Client von JD blockiert.

[![Release](https://img.shields.io/github/v/release/benjarogit/jd2plugin-ankergames-download?label=release)](https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest)

---

<a id="deutsch"></a>

## Deutsch

### Was du bekommst

| Teil | Aufgabe |
|------|---------|
| **JD-Plugin** | Erkennt AnkerGames-Links, öffnet Turnstile-HITL, lädt über localhost-Relay |
| **Browser-Companion** | Echtes Add-on — löst Turnstile, holt CDN mit **Browser-TLS**, streamt Bytes zu JD |
| **Core-Patch** | Ergänzt Relay-Metadaten auf der Turnstile-Captcha-Seite in JD |

### Unterstützte Browser

| Browser | Paket | Auto-Update über GitHub |
|---------|-------|-------------------------|
| **Chrome / Chromium** | `.crx` + Policy | Ja — `updates/chromium.xml` |
| **Vivaldi** | `.crx` + Policy | Ja |
| **Brave** | `.crx` + Policy | Ja |
| **Edge** | `.crx` + Policy | Ja |
| **Firefox** | `.xpi` | Ja **wenn Mozilla-signiert** — `updates/firefox.json`; sonst Badge **↑** |
| **Safari** | Safari Web Extension (Bau unter macOS) | Kein CRX-Feed — siehe [`companion/safari/README.md`](companion/safari/README.md) |

Zusätzlich prüfen alle Companions die **GitHub-Releases-API** und zeigen ein Toolbar-Badge **↑**, wenn eine neuere Version existiert (öffnet die Release-Seite).

### So funktioniert’s

Cloudflare vergleicht **TLS-Fingerprints (JA3/JA4)** mit dem User-Agent. JDownloader spricht **Java-TLS**, behauptet aber einen Browser-UA → Block. Selbst eine frische CDN-URL (`*.dlproxy.uk`) scheitert, wenn Java sie abruft.

```
┌─────────────────┐     Turnstile HITL      ┌──────────────────┐
│  ankergames.net │ ◄─────────────────────► │ Dein Browser     │
│  + Cloudflare   │     echtes Browser-TLS  │ + Companion      │
└────────┬────────┘                         └────────┬─────────┘
         │ CDN-URL (signiert)                        │ fetch(CDN)
         │                                           │ POST-Chunks
         │                                  ┌────────▼─────────┐
         │                                  │ 127.0.0.1-Relay  │
         │                                  │ AnkergamesCdnRelay│
         │                                  └────────┬─────────┘
         │                                           │ GET /file
         │                                  ┌────────▼─────────┐
         └──────────────────────────────────│  JDownloader     │
                                            │  (Fortschritt)   │
                                            └──────────────────┘
```

1. Spiel-URL im Linkgrabber hinzufügen.  
2. JD öffnet lokale Turnstile-Seite → Companion öffnet den Spiel-Tab.  
3. **Du** löst Cloudflare Turnstile einmal.  
4. Companion bekommt die CDN-URL, blockiert Tab-Navigation dorthin (kein Browser-„Speichern unter…“) und streamt in das localhost-Relay.  
5. JD lädt von `http://127.0.0.1:<port>/file` wie einen normalen Listeneintrag.

**AnkerGames-Tab offen lassen**, bis der Stream fertig ist.

### Voraussetzungen

- JDownloader 2 (`JDownloader.jar` + `Core.jar`)
- Ein unterstützter Desktop-Browser (derselbe, den JD für Captchas öffnet)
- Plugin-Installer: Linux / macOS / Windows; Companion-Skripte: bash (unter Windows WSL/Git Bash oder `.crx`/`.xpi` manuell aus Releases)

### Installation

#### 1) JDownloader-Plugin + Core-Patch

```bash
git clone https://github.com/benjarogit/jd2plugin-ankergames-download.git
cd jd2plugin-ankergames-download/plugin
chmod +x install.sh
./install.sh
```

Windows: `install.bat` oder `install.ps1`.

Eigener JD-Pfad:

```bash
JD_HOME="/pfad/zu/jdownloader" ./install.sh
```

#### 2) Browser-Companion (echtes Add-on)

```bash
cd ../companion
chmod +x install.sh
./install.sh
```

**[2]** = Chrome/Vivaldi/Brave/Edge, **[1]** = Firefox, **[3]** = beides.

**Oder aus [Releases](https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest):**

| Browser | Datei | Aktion |
|---------|-------|--------|
| Chromium-Familie | `jd-turnstile-companion-chromium-*.crx` | `…://extensions` → Entwicklermodus → `.crx` auf die Seite ziehen → einmal neu starten |
| Firefox | `jd-turnstile-companion-firefox-*.xpi` | `about:addons` → Zahnrad → *Add-on aus Datei installieren…* |

Stabile Chromium-ID: `haopihkkdnnohoknooliddghpanmmedj`

**Firefox-Signatur:** Release-Firefox lehnt unsignierte XPIs ab. [Firefox Developer Edition](https://www.mozilla.org/firefox/developer/) nutzen (`xpinstall.signatures.required` = `false`) oder über AMO signieren — [`companion/SIGNING.md`](companion/SIGNING.md).

**Safari:** auf dem Mac mit Xcode bauen — [`companion/safari/README.md`](companion/safari/README.md).

Companion-Version **1.4.0+** unter Erweiterungen prüfen.

### Updates — automatisch oder nicht?

| Kanal | Automatisch? | Mechanismus |
|-------|--------------|-------------|
| Chrome / Vivaldi / Brave / Edge | **Ja** | Native `update_url` → [`updates/chromium.xml`](updates/chromium.xml) → GitHub-Release-`.crx` |
| Firefox (signiert) | **Ja** | `gecko.update_url` → [`updates/firefox.json`](updates/firefox.json) → Release-`.xpi` |
| Firefox (unsigniert / Dev Edition) | Nur Badge | Toolbar **↑** → Release öffnen → XPI neu installieren |
| Safari | Manuell / App Store | Kein GitHub-CRX-Feed |
| Alle Browser | Badge-Fallback | Alle paar Stunden GitHub-Releases-API |

Bei jedem neuen Release aktualisiert eine GitHub Action die Update-Feeds auf `main`.

### Bedienung

1. Linkgrabber → z. B. `https://ankergames.net/game/silver-pines`  
2. Optional: Accounts → **ankergames**  
3. Download starten → Turnstile im Browser lösen  
4. Spiel-Tab offen lassen, bis JD fertig ist  
5. Fortschritt nur in JD, nicht als normaler Browser-Download

### Wichtig

- Captcha nicht mit „Überspringen“ abbrechen, während der Companion arbeitet.  
- `*.dlproxy.uk` nicht manuell öffnen — Java→CDN ist absichtlich gesperrt.  
- **Denselben** Browser für Captchas und Companion nutzen.

### Fehlerbehebung

| Symptom | Lösung |
|---------|--------|
| Captcha schließt, kein Download | Companion fehlt / falscher Browser → 1.4.0+ neu installieren |
| Firefox „konnte nicht verifiziert werden“ | XPI signieren oder Developer Edition — `SIGNING.md` |
| Browser speichert die ZIP selbst | Alten Companion aktualisieren; CDN-URL nie öffnen |
| JD bleibt bei 0 B | AnkerGames-Tab offen lassen; Download neu starten |
| Kein Auto-Update | Feed-URLs / Release-Assets prüfen; Badge **↑** nutzen |

### Paketstruktur

```
plugin/          JD-Klassen + Installer
companion/
  chromium/      MV3-Quellcode → .crx
  firefox/       MV2-Quellcode → .xpi
  safari/        Hinweise zur Konvertierung (macOS)
  dist/          gebaute Pakete
  install.sh     Ein-Klick-Installer
core-patch/      Turnstile-HTML + Klasse für Core.jar
updates/         GitHub-Auto-Update-Feeds
src/             lesbare Quellen
```

### Rechtliches

Nur persönlicher Gebrauch / Forschung (HITL-Captcha + Browser-TLS-Brücke). AGB von ankergames.net und lokales Recht beachten. Keine urheberrechtlich geschützten Spieldateien weiterverbreiten.

### Lizenz

Code in diesem Repository: as-is für lokale JD-Plugin-Interoperabilität. JDownloader unterliegt der Lizenz von AppWork. Marken AnkerGames / Cloudflare gehören den jeweiligen Inhabern.
