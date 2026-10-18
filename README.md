# AnkerGames for JDownloader 2

[English](#english) · [Deutsch](README.de.md)

Download games from [ankergames.net](https://ankergames.net) with **JDownloader**.  
Cloudflare blocks JD’s Java client — so you solve the captcha in a **browser**, and a small **browser add-on** sends the file to JD.

**Not affiliated** with AppWork / JDownloader / AnkerGames.  
**MyJDownloader is not required.** Safari is not supported.

---

<a id="english"></a>

## Install (manual, all platforms)

Two steps. Nothing installs itself in the background.

### 1) JDownloader plugin

1. Stop JDownloader.
2. Open the folder where JD is installed  
   (often `~/.jd` on Linux, `%USERPROFILE%\.jd` or your JD folder on Windows).
3. Copy everything from `plugin/plugins/` into JD’s `jd/plugins/`  
   (keep the `hoster/`, `decrypter/`, `components/` subfolders).
4. Patch Core (needed for the relay):
   - Backup `Core.jar`
   - With any zip tool, replace inside `Core.jar`:
     - `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/turnstile.html`  
       ← from `core-patch/turnstile.html`
     - `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/CloudflareTurnstileChallenge.class`  
       ← from `core-patch/CloudflareTurnstileChallenge.class`
5. Start JDownloader.

**Optional helper** (Linux/macOS/Windows) — only copies those files for you:

```bash
cd plugin
./install.sh          # Linux / macOS
install.bat           # Windows
```

### 2) Browser add-on

Use the **same** browser that JDownloader opens for captchas.

#### Chrome / Chromium / Vivaldi / Brave / Edge

1. Open the extensions page:  
   `chrome://extensions` · `vivaldi://extensions` · `brave://extensions` · `edge://extensions`
2. Turn **Developer mode** ON.
3. **Load unpacked** → choose folder:  
   `companion/chromium/`
4. Confirm you see **JD Turnstile Companion**.

#### Firefox

Release Firefox blocks unsigned add-ons. Use **Firefox Developer Edition** or **Nightly**:

1. `about:config` → `xpinstall.signatures.required` → **false**
2. `about:addons` → gear → **Install Add-on From File…**
3. Choose: `companion/dist/jd-turnstile-companion-firefox-*.xpi`  
   (or load temporary: `about:debugging` → Load Temporary Add-on → `companion/firefox/manifest.json`)

---

## Use

1. In JDownloader, add e.g. `https://ankergames.net/game/…`
2. Solve Turnstile in the browser.
3. **Keep the AnkerGames tab open** until the download finishes in JD.

---

## How it works (one sentence)

The browser fetches the CDN file (real TLS); the add-on streams it to `127.0.0.1`; JD saves it from there.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Add-on missing | Repeat step 2; Developer mode on |
| Firefox “not verified” | Dev Edition/Nightly + `xpinstall.signatures.required = false` |
| JD at 0 B | Keep AnkerGames tab open |
| Browser downloads the ZIP | Don’t open `*.dlproxy.uk` yourself; reload the add-on |
