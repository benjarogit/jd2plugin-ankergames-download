<p align="center">
  <img src="companion/assets/logo-512.png" width="220" alt="AnkerGames × JDownloader" />
</p>

<h1 align="center">AnkerGames → JDownloader&nbsp;2</h1>

<p align="center">
  <strong>AnkerGames-Titel mit JDownloader laden</strong><br/>
  Manuelle Installation · Kein MyJD · Kein AnkerGames-Login
</p>

<p align="center">
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest/download/ankergames-jd2-full.zip"><img src="https://img.shields.io/badge/⬇_Download-0b1220?style=for-the-badge&labelColor=2aa9e0" alt="Download" /></a>
  &nbsp;
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest"><img src="https://img.shields.io/badge/Alle_Release--Dateien-1a5f7a?style=for-the-badge" alt="Alle Release-Dateien" /></a>
</p>

<p align="center">
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/benjarogit/jd2plugin-ankergames-download/ci.yml?style=flat-square&label=CI" alt="CI" /></a>
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest"><img src="https://img.shields.io/github/v/release/benjarogit/jd2plugin-ankergames-download?style=flat-square" alt="Release" /></a>
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey?style=flat-square" alt="Platform" />
</p>

<p align="center">
  <a href="#-deutsch">Deutsch</a> · <a href="README.md">English</a>
</p>

---

## Wozu das?

[ankergames.net](https://ankergames.net) steckt hinter **Cloudflare**. Der Java-Client von JDownloader wird blockiert.  
Dieses Projekt liefert:

1. ein **JDownloader-Plugin** (plus kleinen Core-Patch), und  
2. eine **Browser-Erweiterung**, die Turnstile löst und die Datei per localhost an JD streamt.

> Inoffiziell. Nicht verbunden mit AppWork, JDownloader oder AnkerGames.

---

<a id="-deutsch"></a>

## Deutsch

### Schnellstart

| Schritt | Was du tust |
|:-------:|-------------|
| **0** | Oben **Download Latest Release** (oder ZIP) klicken und entpacken |
| **1** | **JDownloader**-Plugin installieren |
| **2** | **Browser**-Erweiterung installieren |
| **3** | Spiel-URL in JD einfügen → Captcha lösen → Tab offen lassen |

---

### Schritt 1 — JDownloader-Plugin

#### Zuerst: JD-Ordner finden (bei jedem anders)

Es gibt **zwei Ebenen** — die verwechseln viele:

| Name | Was liegt drin? | Beispiel |
|------|-----------------|----------|
| **JD-Root** | `JDownloader.jar` + `Core.jar` | `…/.jd/` oder dein Portable-Ordner |
| **Plugin-Ordner** | Unterordner `jd/plugins/` | `…/.jd/jd/plugins/` |

**So findest du den richtigen Ordner (egal ob Installer oder Portable):**

1. Suche auf dem PC nach der Datei **`JDownloader.jar`**  
   (Windows: Win+S · Linux/macOS: Dateimanager-Suche oder Helfer unten)
2. **Rechtsklick → Ordner öffnen / Open file location**  
   → Das ist dein **JD-Root**
3. Darin den Unterordner **`jd` → `plugins`** öffnen  
   → Das ist dein **Plugin-Ordner**
4. Portable: oft der Ordner, in den du JD entpackt hast (Desktop, Downloads, USB…)

**Automatisch suchen lassen:**

| System | Helfer im ZIP |
|--------|----------------|
| Windows | `plugin/find-jd-home.bat` doppelklicken |
| Linux / macOS | `cd plugin && chmod +x find-jd-home.sh && ./find-jd-home.sh` |

Der Helfer zeigt dir JD-Root **und** den Plugin-Pfad. Bei mehreren Installationen: die nehmen, die du wirklich startest (Verknüpfung prüfen).

---

1. **JDownloader komplett beenden.**
2. Aus dem ZIP in **deinen** Plugin-Ordner kopieren  
   (`<JD-Root>/jd/plugins/…` — Pfad kommt vom Helfer / der Suche):

| Aus dem ZIP | Ziel |
|-------------|------|
| Inhalt von `plugin/plugins/hoster/` | `<JD-Root>/jd/plugins/hoster/` |
| Inhalt von `plugin/plugins/decrypter/` | `<JD-Root>/jd/plugins/decrypter/` |
| Inhalt von `plugin/plugins/components/` | `<JD-Root>/jd/plugins/components/` |

Fertig ist es, wenn z. B. existiert:  
`<JD-Root>/jd/plugins/hoster/AnkergamesNet.class`

3. **`Core.jar`** im **JD-Root** patchen (neben `JDownloader.jar` — ist eine ZIP, mit 7-Zip öffnen):
   - Zuerst Backup von `Core.jar`
   - Im Archiv ersetzen:

| Pfad in `Core.jar` | Ersetzen durch |
|--------------------|----------------|
| `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/turnstile.html` | `core-patch/turnstile.html` |
| `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/CloudflareTurnstileChallenge.class` | `core-patch/CloudflareTurnstileChallenge.class` |

4. JDownloader starten.

<details>
<summary>Optional: Kopier-Skript (nach dem Finden)</summary>

```bash
cd plugin
JD_HOME="/pfad/zum/JD-Root" ./install.sh   # Linux / macOS
# Windows: install.bat  (sucht selbst; sonst JD_HOME setzen)
```

</details>

---

### Schritt 2 — Browser-Erweiterung

Denselben Browser nutzen, den JDownloader für Captchas öffnet.

#### Chrome · Vivaldi · Brave · Edge · Chromium

| # | Aktion |
|---|--------|
| 1 | `chrome://extensions` öffnen *(oder `vivaldi://` / `brave://` / `edge://extensions`)* |
| 2 | **Entwicklermodus** einschalten |
| 3 | **Entpackte Erweiterung laden** → Ordner `companion/chromium/` |
| 4 | Prüfen: **JD Turnstile Companion** steht in der Liste |

#### Firefox

**Firefox Developer Edition** oder **Nightly** (Release blockiert unsignierte Add-ons).

| # | Aktion |
|---|--------|
| 1 | `about:config` → `xpinstall.signatures.required` → **false** |
| 2 | `about:addons` → ⚙ → **Add-on aus Datei installieren…** |
| 3 | Datei: `companion/dist/jd-turnstile-companion-firefox-*.xpi` |

---

### Benutzung

1. In JDownloader z. B. `https://ankergames.net/game/…` einfügen
2. Download starten → **Turnstile** im Browser lösen
3. **AnkerGames-Tab offen lassen**, bis JD fertig ist

Kein AnkerGames-Konto in JD. Kein MyJDownloader.

---

### So funktioniert’s

```text
Turnstile (du)  →  Erweiterung holt CDN (echtes TLS)
                →  streamt an http://127.0.0.1/…
                →  JDownloader speichert die Datei
```

---

### Probleme

| Problem | Lösung |
|---------|--------|
| Erweiterung fehlt | Schritt 2 · Entwicklermodus an |
| Firefox „nicht verifiziert“ | Dev Edition/Nightly + Signaturen = false |
| JD bei 0 B | AnkerGames-Tab offen lassen |
| Browser speichert die ZIP | `*.dlproxy.uk` nicht öffnen · Erweiterung neu laden |
| Plugin fehlt in JD | Liegen die `.class` unter `…/.jd/jd/plugins/…` (mit `jd/` dazwischen)? + Core-Patch in `…/.jd/Core.jar` |

---

### Entwickler

```bash
cd companion && ./build-packages.sh
python3 -m unittest discover -s tests -v
```
