<p align="center">
  <img src="companion/assets/logo-512.png" width="220" alt="AnkerGames × JDownloader" />
</p>

<h1 align="center">AnkerGames → JDownloader&nbsp;2</h1>

<p align="center">
  <strong>AnkerGames-Titel mit JDownloader laden</strong><br/>
  Manuelle Installation · Kein MyJD · Kein AnkerGames-Login
</p>

<p align="center">
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest"><img src="https://img.shields.io/badge/⬇_Download_Latest_Release-0b1220?style=for-the-badge&labelColor=2aa9e0" alt="Download Latest Release" /></a>
  &nbsp;
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/archive/refs/heads/main.zip"><img src="https://img.shields.io/badge/⬇_Download_ZIP-1a5f7a?style=for-the-badge" alt="Download ZIP" /></a>
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

<details>
<summary><strong>Wo liegt mein JDownloader-Ordner?</strong></summary>

| OS | Typischer Pfad |
|----|----------------|
| **Windows** | `%USERPROFILE%\.jd` oder dein JD-Installationsordner |
| **Linux** | `~/.jd` |
| **macOS** | `~/Library/Application Support/JDownloader` |

Dort liegen `JDownloader.jar`, `Core.jar` und `jd/plugins/`.

</details>

1. **JDownloader komplett beenden.**
2. Diese Ordner nach JD `jd/plugins/` kopieren:

| Aus dem ZIP | Nach JD |
|-------------|---------|
| `plugin/plugins/hoster/` | `jd/plugins/hoster/` |
| `plugin/plugins/decrypter/` | `jd/plugins/decrypter/` |
| `plugin/plugins/components/` | `jd/plugins/components/` |

3. **`Core.jar`** patchen (ist eine ZIP — mit 7-Zip öffnen):
   - Zuerst Backup von `Core.jar`
   - Im Archiv ersetzen:

| Pfad in `Core.jar` | Ersetzen durch |
|--------------------|----------------|
| `…/cloudflareturnstile/turnstile.html` | `core-patch/turnstile.html` |
| `…/cloudflareturnstile/CloudflareTurnstileChallenge.class` | `core-patch/CloudflareTurnstileChallenge.class` |

   Pfad-Präfix: `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/`

4. JDownloader starten.

<details>
<summary>Optional: Kopier-Skript</summary>

```bash
cd plugin
./install.sh      # Linux / macOS
install.bat       # Windows
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
| Plugin fehlt in JD | Klassen unter `jd/plugins/` + Core-Patch |

---

### Entwickler

```bash
cd companion && ./build-packages.sh
python3 -m unittest discover -s tests -v
```
