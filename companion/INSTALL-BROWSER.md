# Browser companion — unsigned install (recommended)

No app-store account needed. Safari is **not** supported.

Language: [English](#english) · [Deutsch](#deutsch)

---

<a id="english"></a>

## English

### Chrome / Chromium / Vivaldi / Brave / Edge

These browsers install our **self-packed `.crx`** without the Chrome Web Store.

**Easiest:** from the repo root run `./install.sh` and type `vivaldi` / `chrome` / `brave` / `edge`.  
The script writes a managed policy and restarts the browser — the add-on appears under `…://extensions`.

**Manual:**

1. Open `chrome://extensions` (Vivaldi: `vivaldi://extensions`, Brave: `brave://extensions`, Edge: `edge://extensions`).
2. Enable **Developer mode**.
3. Drag `companion/dist/jd-turnstile-companion-chromium-*.crx` onto the page  
   **or** use *Load unpacked* → folder `companion/chromium/`.
4. Confirm any warning (“not from the Chrome Web Store”) — that is normal for sideloaded CRXs.
5. Restart the browser once.

Use the **same** browser JDownloader opens for captchas.

### Firefox (unsigned `.xpi`)

**Release Firefox** blocks unsigned add-ons by default. Use one of these:

#### Option A — Firefox Developer Edition or Nightly (recommended for unsigned)

1. Install [Firefox Developer Edition](https://www.mozilla.org/firefox/developer/) or Nightly.
2. Address bar → `about:config` → accept the risk warning.
3. Search `xpinstall.signatures.required` → set to **`false`**.
4. `about:addons` → gear icon → **Install Add-on From File…**  
   → choose `companion/dist/jd-turnstile-companion-firefox-*.xpi`  
   (or `~/.local/share/jd-turnstile-companion/jd-turnstile-companion.xpi` after `./install-firefox.sh`).
5. Confirm the install. Point JDownloader’s captcha browser to this Firefox.

#### Option B — Temporary load (any Firefox, until restart)

1. `about:debugging#/runtime/this-firefox`
2. **Load Temporary Add-on…** → select `companion/firefox/manifest.json`
3. Re-load after every browser restart.

#### Option C — Mozilla-signed (optional later)

Only if you want Release Firefox + auto-update without Developer Edition. See `SIGNING.md` (AMO). Not required for normal use.

---

<a id="deutsch"></a>

## Deutsch

### Chrome / Chromium / Vivaldi / Brave / Edge

Diese Browser nehmen unsere **selbst gepackte `.crx`** ohne Chrome Web Store.

**Einfachste Variante:** im Repo `./install.sh` starten und `vivaldi` / `chrome` / `brave` / `edge` tippen.  
Das Skript setzt eine Policy und startet den Browser neu — die Erweiterung steht unter `…://extensions`.

**Manuell:**

1. `chrome://extensions` öffnen (Vivaldi: `vivaldi://extensions`, Brave: `brave://extensions`, Edge: `edge://extensions`).
2. **Entwicklermodus** einschalten.
3. `companion/dist/jd-turnstile-companion-chromium-*.crx` auf die Seite ziehen  
   **oder** *Entpackte Erweiterung laden* → Ordner `companion/chromium/`.
4. Warnung („nicht aus dem Chrome Web Store“) bestätigen — normal bei Sideload.
5. Browser einmal neu starten.

Denselben Browser nutzen, den JDownloader für Captchas öffnet.

### Firefox (unsignierte `.xpi`)

**Firefox Release** blockiert unsignierte Add-ons standardmäßig. Eine der Varianten:

#### Variante A — Firefox Developer Edition oder Nightly (empfohlen ohne Signatur)

1. [Firefox Developer Edition](https://www.mozilla.org/firefox/developer/) oder Nightly installieren.
2. Adresszeile → `about:config` → Warnung akzeptieren.
3. `xpinstall.signatures.required` suchen → auf **`false`** setzen.
4. `about:addons` → Zahnrad → **Add-on aus Datei installieren…**  
   → `companion/dist/jd-turnstile-companion-firefox-*.xpi`  
   (oder nach `./install-firefox.sh`: `~/.local/share/jd-turnstile-companion/jd-turnstile-companion.xpi`).
5. Installation bestätigen. In JDownloader diesen Firefox als Captcha-Browser nutzen.

#### Variante B — Temporär laden (jeder Firefox, bis zum Neustart)

1. `about:debugging#/runtime/this-firefox`
2. **Temporäres Add-on laden…** → `companion/firefox/manifest.json`
3. Nach jedem Browser-Neustart erneut laden.

#### Variante C — Mozilla-signiert (optional später)

Nur wenn du Release-Firefox ohne Developer Edition willst. Siehe `SIGNING.md` (AMO). Für den normalen Betrieb **nicht nötig**.
