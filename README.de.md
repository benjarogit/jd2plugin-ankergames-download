<p align="center">
  <img src="companion/assets/logo-512.png" width="200" alt="AnkerGames × JDownloader" />
</p>

<h1 align="center">AnkerGames → JDownloader&nbsp;2</h1>

<p align="center">
  AnkerGames-Titel mit JDownloader laden<br/>
  <em>Manuelle Installation · Kein MyJD · Kein AnkerGames-Login</em>
</p>

<p align="center">
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest/download/ankergames-jd2-full.zip"><img src="https://img.shields.io/badge/⬇_Download_ZIP-0b1220?style=for-the-badge&labelColor=2aa9e0" alt="Download ZIP" /></a>
</p>

<p align="center">
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest"><img src="https://img.shields.io/github/v/release/benjarogit/jd2plugin-ankergames-download?style=flat-square" alt="Release" /></a>
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/benjarogit/jd2plugin-ankergames-download/ci.yml?style=flat-square&label=CI" alt="CI" /></a>
  <img src="https://img.shields.io/badge/Windows%20%7C%20Linux%20%7C%20macOS-lightgrey?style=flat-square" alt="Platform" />
</p>

<p align="center"><a href="README.md">English</a></p>

---

## Was du bekommst

[ankergames.net](https://ankergames.net) steckt hinter **Cloudflare**. Der Java-Client von JDownloader wird blockiert.

Dieses ZIP liefert zwei Teile, die zusammenarbeiten:

| Teil | Aufgabe |
|------|---------|
| **JDownloader-Plugin** (+ kleiner Core-Patch) | Spricht in JD mit AnkerGames |
| **Browser-Erweiterung** | Löst Turnstile und streamt die Datei per localhost an JD |

> Inoffiziell. Nicht verbunden mit AppWork, JDownloader oder AnkerGames.

---

## Schnellstart

1. [ZIP herunterladen](https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest/download/ankergames-jd2-full.zip) und entpacken  
2. **JDownloader**-Plugin installieren → [Schritt 1](#schritt-1--jdownloader-plugin)  
3. **Browser**-Erweiterung installieren → [Schritt 2](#schritt-2--browser-erweiterung)  
4. Spiel-URL in JD einfügen → Captcha lösen → **Tab offen lassen**

---

## Schritt 1 — JDownloader-Plugin

### Zuerst den JD-Ordner finden

Bei jedem PC anders (Installer oder Portable). Du brauchst den Ordner mit **`JDownloader.jar`**.

| Name | Bedeutung | Beispiel |
|------|-----------|----------|
| **JD-Root** | Ordner mit `JDownloader.jar` + `Core.jar` | `C:\JDownloader\` oder `~/.jd/` |
| **Plugin-Ordner** | Unterordner `jd/plugins/` im Root | `…/jd/plugins/` |

#### Variante A — Pathfinder (empfohlen)

| System | Im entpackten ZIP ausführen |
|--------|-----------------------------|
| **Windows** | `plugin/find-jd-home.bat` doppelklicken |
| **Linux / macOS** | `cd plugin && chmod +x find-jd-home.sh && ./find-jd-home.sh` |

Der Helfer zeigt dir:

- **JD-Root** — dort liegt `Core.jar`  
- **Plugin-Ordner** — hierhin kommen die `.class`-Dateien  

Bei mehreren Treffern: die Installation nehmen, die deine Verknüpfung wirklich startet.

#### Variante B — Selbst suchen

1. Am PC nach **`JDownloader.jar`** suchen (Windows: `Win+S`)  
2. Rechtsklick → **Dateipfad öffnen** → das ist der **JD-Root**  
3. Darin `jd` → `plugins` öffnen → das ist der **Plugin-Ordner**

#### Wenn nichts gefunden wird

1. JDownloader einmal starten (damit der Ordner entsteht)  
2. Rechtsklick auf Desktop-/Startmenü-Verknüpfung → **Dateipfad öffnen**  
3. Portable: schau, wohin du JD entpackt hast (Desktop, Downloads, USB, anderer Laufwerk)  
4. Immer noch nichts: nach **`Core.jar`** suchen — muss neben `JDownloader.jar` liegen  
5. Danach Plugins hierhin kopieren: `<JD-Root>/jd/plugins/`

---

### Plugin-Dateien installieren

1. **JDownloader komplett beenden.**  
2. Aus dem ZIP in **deinen** Plugin-Ordner kopieren:

| Aus dem ZIP | Ziel |
|-------------|------|
| `plugin/plugins/hoster/*` | `<JD-Root>/jd/plugins/hoster/` |
| `plugin/plugins/decrypter/*` | `<JD-Root>/jd/plugins/decrypter/` |
| `plugin/plugins/components/*` | `<JD-Root>/jd/plugins/components/` |

Fertig, wenn z. B. existiert: `<JD-Root>/jd/plugins/hoster/AnkergamesNet.class`.

3. **`Core.jar`** im **JD-Root** patchen (neben `JDownloader.jar`). Mit 7-Zip / Archivmanager öffnen, **zuerst Backup**, dann ersetzen:

| Pfad in `Core.jar` | Datei aus dem ZIP |
|--------------------|-------------------|
| `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/turnstile.html` | `core-patch/turnstile.html` |
| `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/CloudflareTurnstileChallenge.class` | `core-patch/CloudflareTurnstileChallenge.class` |

4. JDownloader starten.

<details>
<summary>Optional: Install-Skript kopieren lassen</summary>

```bash
cd plugin
JD_HOME="/pfad/zum/JD-Root" ./install.sh   # Linux / macOS
# Windows: install.bat  (oder vorher JD_HOME setzen)
```

</details>

---

## Schritt 2 — Browser-Erweiterung

Denselben Browser nutzen, den JDownloader für Captchas öffnet.

### Chrome · Vivaldi · Brave · Edge · Chromium

1. `chrome://extensions` öffnen (oder `vivaldi://` / `brave://` / `edge://extensions`)  
2. **Entwicklermodus** einschalten  
3. **Entpackte Erweiterung laden** → Ordner `companion/chromium/`  
4. Prüfen: **JD Turnstile Companion** steht in der Liste  

### Firefox

**Firefox Developer Edition** oder **Nightly** (Release blockiert unsignierte Add-ons).

1. `about:config` → `xpinstall.signatures.required` → **false**  
2. `about:addons` → ⚙ → **Add-on aus Datei installieren…**  
3. Datei: `companion/dist/jd-turnstile-companion-firefox-*.xpi`  

---

## Benutzung

1. In JDownloader z. B. `https://ankergames.net/game/…` einfügen  
2. Download starten → **Turnstile** im Browser lösen  
3. **AnkerGames-Tab offen lassen**, bis JD fertig ist  

Kein AnkerGames-Konto in JD. Kein MyJDownloader.

```text
Du löst Turnstile  →  Erweiterung holt CDN (echtes Browser-TLS)
                   →  streamt an http://127.0.0.1/…
                   →  JDownloader speichert die Datei
```

---

## Probleme

| Problem | Lösung |
|---------|--------|
| Pathfinder findet nichts | Siehe [Wenn nichts gefunden wird](#wenn-nichts-gefunden-wird) |
| Plugin fehlt in JD | Dateien müssen unter `…/jd/plugins/…` liegen (mit `jd/` dazwischen) + Core-Patch |
| Erweiterung fehlt | Schritt 2 · Entwicklermodus an |
| Firefox „nicht verifiziert“ | Dev Edition / Nightly + Signaturen = false |
| JD bleibt bei 0 B | AnkerGames-Tab offen lassen |
| Browser speichert die ZIP selbst | `*.dlproxy.uk` nicht öffnen · Erweiterung neu laden |

---

## Entwickler

```bash
cd companion && ./build-packages.sh
python3 -m unittest discover -s tests -v
```
