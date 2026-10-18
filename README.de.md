# AnkerGames → JDownloader 2

<p align="center">
  <img src="companion/assets/logo-256.png" width="96" alt="Companion-Logo" />
</p>

<p align="center">
  <strong>Manuelle Installation · Kein MyJD · Kein AnkerGames-Login</strong><br/>
  <a href="#deutsch">Deutsch</a> · <a href="README.md">English</a>
</p>

[![CI](https://github.com/benjarogit/jd2plugin-ankergames-download/actions/workflows/ci.yml/badge.svg)](https://github.com/benjarogit/jd2plugin-ankergames-download/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/benjarogit/jd2plugin-ankergames-download)](https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest)

Spiele von [ankergames.net](https://ankergames.net) mit **JDownloader** laden.  
Cloudflare blockiert den Java-Client von JD — Captcha im **Browser**, kleine **Browser-Erweiterung** streamt die Datei zu JD.

> Inoffiziell. Nicht verbunden mit AppWork, JDownloader oder AnkerGames.

---

<a id="deutsch"></a>

## Was du brauchst

| Teil | Wofür |
|------|--------|
| JDownloader 2 | Speichert die Datei und zeigt den Fortschritt |
| Browser-Erweiterung | Spricht mit Cloudflare mit echtem Browser-TLS |
| Derselbe Browser für Captchas | JD öffnet das Captcha; die Erweiterung muss dort laufen |

**Kein AnkerGames-Konto** in JDownloader. **Kein MyJDownloader.**

---

## Installation (2 Schritte)

### Schritt 1 — JDownloader-Plugin

**Wo liegt mein JD-Ordner?**

| System | Typischer Pfad |
|--------|----------------|
| Linux | `~/.jd` |
| Windows | `%USERPROFILE%\.jd` oder dein JD-Installationsordner |
| macOS | `~/Library/Application Support/JDownloader` oder dein JD-Ordner |

Dort müssen `JDownloader.jar`, `Core.jar` und `jd/plugins/` liegen.

**So geht’s:**

1. **JDownloader komplett beenden.**
2. Plugin-Klassen nach JD kopieren:
   - Aus dem Repo: `plugin/plugins/hoster/` → JD `jd/plugins/hoster/`
   - `plugin/plugins/decrypter/` → `jd/plugins/decrypter/`
   - `plugin/plugins/components/` → `jd/plugins/components/`
3. `Core.jar` patchen (ist eine Zip-Datei — mit 7-Zip / unzip öffnen):
   - Zuerst **Backup** von `Core.jar` machen
   - Im Archiv ersetzen:
     - `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/turnstile.html`  
       ← Datei aus `core-patch/turnstile.html`
     - `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/CloudflareTurnstileChallenge.class`  
       ← Datei aus `core-patch/CloudflareTurnstileChallenge.class`
4. JDownloader starten.

**Optionaler Helfer** (kopiert nur die Dateien):

```bash
cd plugin
./install.sh      # Linux / macOS
install.bat       # Windows
```

---

### Schritt 2 — Browser-Erweiterung

Denselben Browser nutzen, den JDownloader für Captchas öffnet.

#### Chrome · Vivaldi · Brave · Edge · Chromium

| # | Aktion |
|---|--------|
| 1 | Erweiterungsseite öffnen: `chrome://extensions` / `vivaldi://extensions` / `brave://extensions` / `edge://extensions` |
| 2 | **Entwicklermodus** einschalten (oben rechts) |
| 3 | **Entpackte Erweiterung laden** klicken |
| 4 | Ordner wählen: `companion/chromium/` |
| 5 | Prüfen: **JD Turnstile Companion** steht in der Liste |

#### Firefox

Release-Firefox blockiert unsignierte Add-ons. **Firefox Developer Edition** oder **Nightly** nutzen.

| # | Aktion |
|---|--------|
| 1 | `about:config` öffnen → Warnung akzeptieren |
| 2 | `xpinstall.signatures.required` auf **`false`** setzen |
| 3 | `about:addons` → Zahnrad → **Add-on aus Datei installieren…** |
| 4 | Datei wählen: `companion/dist/jd-turnstile-companion-firefox-*.xpi` |

*Temporär:* `about:debugging` → Temporäres Add-on → `companion/firefox/manifest.json` (nach Neustart weg).

---

## Benutzung

1. Im Linkgrabber z. B. `https://ankergames.net/game/…` einfügen
2. Download starten → **Turnstile** im Browser lösen
3. **AnkerGames-Tab offen lassen**, bis JD fertig ist

Fortschritt nur in JDownloader — nicht als normaler Browser-Download.

---

## So funktioniert’s

```
Turnstile lösen  →  Erweiterung holt CDN (echtes TLS)
                 →  streamt an http://127.0.0.1/…
                 →  JDownloader speichert die Datei
```

---

## Probleme

| Problem | Lösung |
|---------|--------|
| Erweiterung fehlt | Schritt 2 wiederholen; Entwicklermodus muss an sein |
| Firefox „nicht verifiziert“ | Dev Edition/Nightly + `xpinstall.signatures.required = false` |
| JD bei 0 B | AnkerGames-Tab offen lassen; Captcha nicht überspringen |
| Browser speichert die ZIP | `*.dlproxy.uk` nicht öffnen; Erweiterung neu laden |
| Plugin fehlt in JD | Klassen unter `jd/plugins/` + Core-Patch prüfen |

---

## Für Entwickler

```bash
cd companion && ./build-packages.sh
python3 -m unittest discover -s tests -v
```

CI baut Pakete und führt Tests aus (`.github/workflows/ci.yml`).
