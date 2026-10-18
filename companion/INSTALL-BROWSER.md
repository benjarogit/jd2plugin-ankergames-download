# Browser add-on — install help

[Deutsch](#deutsch) · [English](#english)

Safari is not supported.

---

<a id="deutsch"></a>

## Deutsch

### Vivaldi / Chrome / Brave / Edge

Nach `./install.sh` (Browsername tippen):

1. Seite **Erweiterungen** ist offen  
2. **Entwicklermodus** einschalten  
3. **Entpackte Erweiterung laden** → Ordner  
   `~/.local/share/jd-turnstile-companion/chromium/ext`

Fertig, wenn „JD Turnstile Companion“ in der Liste steht.

### Firefox

Release-Firefox blockiert unsignierte Add-ons.

1. **Firefox Developer Edition** oder **Nightly**  
2. `about:config` → `xpinstall.signatures.required` = **false**  
3. `about:addons` → Zahnrad → **Add-on aus Datei installieren**  
   → `~/.local/share/jd-turnstile-companion/jd-turnstile-companion.xpi`

Oder kurzzeitig: `about:debugging` → Temporäres Add-on → `companion/firefox/manifest.json`

---

<a id="english"></a>

## English

### Vivaldi / Chrome / Brave / Edge

After `./install.sh` (type browser name):

1. **Extensions** page opens  
2. Enable **Developer mode**  
3. **Load unpacked** → folder  
   `~/.local/share/jd-turnstile-companion/chromium/ext`

Done when “JD Turnstile Companion” appears in the list.

### Firefox

Release Firefox blocks unsigned add-ons.

1. **Firefox Developer Edition** or **Nightly**  
2. `about:config` → `xpinstall.signatures.required` = **false**  
3. `about:addons` → gear → **Install Add-on From File**  
   → `~/.local/share/jd-turnstile-companion/jd-turnstile-companion.xpi`

Or temporary: `about:debugging` → Load Temporary Add-on → `companion/firefox/manifest.json`
