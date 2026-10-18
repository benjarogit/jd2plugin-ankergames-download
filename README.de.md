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

| Browser | Paket | Hinweis |
|---------|-------|---------|
| **Chrome / Chromium / Vivaldi / Brave / Edge** | unsignierte `.crx` | Sideload / Policy — kein Web Store nötig |
| **Firefox** | unsignierte `.xpi` | Developer Edition / Nightly (oder temporär laden) — [`companion/INSTALL-BROWSER.md`](companion/INSTALL-BROWSER.md) |

Safari wird **nicht** unterstützt. Toolbar-Badge **↑** bei neuerem GitHub-Release.

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

### Installation (empfohlen)

Ein Assistent installiert **Plugin** und **Browser-Erweiterung**. Sprache DE/EN (Systemsprache, oder erzwingen mit `--de` / `--en`).

```bash
git clone https://github.com/benjarogit/jd2plugin-ankergames-download.git
cd jd2plugin-ankergames-download
chmod +x install.sh
./install.sh
```

Du wirst gefragt:

1. JDownloader-Plugin installieren? → **J** / **Y** (oder **n** zum Überspringen)
2. Welcher Browser für Captchas? → einen **Namen** tippen, z. B. `vivaldi`, `chrome`, `brave`, `edge`, `firefox` oder `all`  
   **Keine einzelne Zahl in die Shell tippen** — das ist kein Befehl.

**Chromium-Familie:** unsignierte `.crx` — Installer per Policy, oder auf `…://extensions` ziehen (Entwicklermodus). Keine Store-Signatur nötig.

**Firefox:** unsignierte `.xpi` — **Developer Edition / Nightly**, `xpinstall.signatures.required` = `false`, dann *Add-on aus Datei installieren…*.  
Schritt für Schritt (DE/EN): [`companion/INSTALL-BROWSER.md`](companion/INSTALL-BROWSER.md).  
AMO-Signatur ist optional und für den Normalbetrieb nicht nötig ([`SIGNING.md`](companion/SIGNING.md)).

Eigener JD-Pfad: `JD_HOME="/pfad/zu/jdownloader" ./install.sh`

Windows (nur Plugin): `plugin/install.bat` / `plugin/install.ps1`, Companion aus [Releases](https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest) + INSTALL-BROWSER.md.

Stabile Chromium-ID: `haopihkkdnnohoknooliddghpanmmedj`

### Updates

| Kanal | Wie |
|-------|-----|
| Chrome / Vivaldi / Brave / Edge | Policy / `updates/chromium.xml` + Installer erneut |
| Firefox (unsigniert) | Badge **↑** → neue XPI → erneut aus Datei installieren |
| Alle | Badge prüft GitHub Releases |

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
| Firefox „konnte nicht verifiziert werden“ | Dev Edition/Nightly + `xpinstall.signatures.required=false` — `INSTALL-BROWSER.md` |
| Browser speichert die ZIP selbst | Alten Companion aktualisieren; CDN-URL nie öffnen |
| JD bleibt bei 0 B | AnkerGames-Tab offen lassen; Download neu starten |
| Kein Auto-Update | Feed-URLs / Release-Assets prüfen; Badge **↑** nutzen |

### Paketstruktur

```
plugin/          JD-Klassen + Installer
companion/
  chromium/      MV3-Quellcode → .crx
  firefox/       MV2-Quellcode → .xpi
  dist/          gebaute Pakete
  INSTALL-BROWSER.md   unsignierte Installation (DE/EN)
  install.sh     Companion-Installer
core-patch/      Turnstile-HTML + Klasse für Core.jar
updates/         GitHub-Update-Feeds
src/             lesbare Quellen
```

### Rechtliches

Nur persönlicher Gebrauch / Forschung (HITL-Captcha + Browser-TLS-Brücke). AGB von ankergames.net und lokales Recht beachten. Keine urheberrechtlich geschützten Spieldateien weiterverbreiten.

### Lizenz

Code in diesem Repository: as-is für lokale JD-Plugin-Interoperabilität. JDownloader unterliegt der Lizenz von AppWork. Marken AnkerGames / Cloudflare gehören den jeweiligen Inhabern.
