# AnkerGames für JDownloader 2

[Deutsch](#deutsch) · [English](README.md)

Spiele von [ankergames.net](https://ankergames.net) mit **JDownloader** laden.  
Cloudflare blockiert den Java-Client von JD — deshalb Captcha im **Browser**, und eine kleine **Browser-Erweiterung** schickt die Datei an JD.

**Nicht verbunden** mit AppWork / JDownloader / AnkerGames.  
**MyJDownloader wird nicht gebraucht.** Safari wird nicht unterstützt.

---

<a id="deutsch"></a>

## Installation (manuell, alle Plattformen)

Zwei Schritte. Es installiert sich nichts von allein im Hintergrund.

### 1) JDownloader-Plugin

1. JDownloader beenden.
2. JD-Installationsordner öffnen  
   (oft `~/.jd` unter Linux, `%USERPROFILE%\.jd` oder dein JD-Ordner unter Windows).
3. Alles aus `plugin/plugins/` nach `jd/plugins/` in JD kopieren  
   (Unterordner `hoster/`, `decrypter/`, `components/` beibehalten).
4. Core patchen (für das Relay nötig):
   - `Core.jar` sichern
   - Mit einem Zip-Tool in `Core.jar` ersetzen:
     - `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/turnstile.html`  
       ← aus `core-patch/turnstile.html`
     - `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/CloudflareTurnstileChallenge.class`  
       ← aus `core-patch/CloudflareTurnstileChallenge.class`
5. JDownloader starten.

**Optionaler Helfer** (kopiert nur die Dateien):

```bash
cd plugin
./install.sh          # Linux / macOS
install.bat           # Windows
```

### 2) Browser-Erweiterung

Denselben Browser nutzen, den JDownloader für Captchas öffnet.

#### Chrome / Chromium / Vivaldi / Brave / Edge

1. Erweiterungsseite öffnen:  
   `chrome://extensions` · `vivaldi://extensions` · `brave://extensions` · `edge://extensions`
2. **Entwicklermodus** einschalten.
3. **Entpackte Erweiterung laden** → Ordner:  
   `companion/chromium/`
4. Prüfen: **JD Turnstile Companion** steht in der Liste.

#### Firefox

Release-Firefox blockiert unsignierte Add-ons. **Firefox Developer Edition** oder **Nightly** nutzen:

1. `about:config` → `xpinstall.signatures.required` → **false**
2. `about:addons` → Zahnrad → **Add-on aus Datei installieren…**
3. Datei: `companion/dist/jd-turnstile-companion-firefox-*.xpi`  
   (oder temporär: `about:debugging` → Temporäres Add-on → `companion/firefox/manifest.json`)

---

## Benutzung

1. In JDownloader Link hinzufügen, z. B. `https://ankergames.net/game/…`
2. Turnstile im Browser lösen.
3. **AnkerGames-Tab offen lassen**, bis der Download in JD fertig ist.

---

## So funktioniert’s (ein Satz)

Der Browser holt die CDN-Datei (echtes TLS); die Erweiterung streamt sie an `127.0.0.1`; JD speichert von dort.

---

## Probleme

| Problem | Lösung |
|---------|--------|
| Erweiterung fehlt | Schritt 2 wiederholen; Entwicklermodus an |
| Firefox „nicht verifiziert“ | Dev Edition/Nightly + `xpinstall.signatures.required = false` |
| JD bei 0 B | AnkerGames-Tab offen lassen |
| Browser speichert die ZIP | `*.dlproxy.uk` nicht selbst öffnen; Erweiterung neu laden |
