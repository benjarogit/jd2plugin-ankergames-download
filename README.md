<p align="center">
  <img src="companion/assets/logo.png" width="200" alt="AnkerGames × JDownloader" />
</p>

<h1 align="center">AnkerGames → JDownloader&nbsp;2</h1>

<p align="center">
  Download AnkerGames titles with JDownloader<br/>
  <em>Manual install · No MyJD · No AnkerGames login</em>
</p>

<p align="center">
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest/download/ankergames-jd2-full.zip"><img src="https://img.shields.io/badge/⬇_Download_ZIP-0b1220?style=for-the-badge&labelColor=2aa9e0" alt="Download ZIP" /></a>
</p>

<p align="center">
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest"><img src="https://img.shields.io/github/v/release/benjarogit/jd2plugin-ankergames-download?style=flat-square" alt="Release" /></a>
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/benjarogit/jd2plugin-ankergames-download/ci.yml?style=flat-square&label=CI" alt="CI" /></a>
  <img src="https://img.shields.io/badge/Windows%20%7C%20Linux%20%7C%20macOS-lightgrey?style=flat-square" alt="Platform" />
</p>

<p align="center"><a href="README.de.md">Deutsch</a></p>

---

## What you get

[ankergames.net](https://ankergames.net) sits behind **Cloudflare**. JDownloader’s Java client gets blocked.

This ZIP adds two pieces that work together:

| Piece | Role |
|-------|------|
| **JDownloader plugin** (+ small Core patch) | Talks to AnkerGames inside JD |
| **Browser add-on** | Solves Turnstile and streams the file to JD over localhost |

> Unofficial. Not affiliated with AppWork, JDownloader, or AnkerGames.

---

## Quick start

1. [Download the ZIP](https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest/download/ankergames-jd2-full.zip) and unpack it  
2. Install the **JDownloader** plugin → [Step 1](#step-1--jdownloader-plugin)  
3. Install the **browser** add-on → [Step 2](#step-2--browser-add-on)  
4. Paste a game URL in JD → solve captcha → **keep the tab open**

---

## Step 1 — JDownloader plugin

### Find your JD folder first

Every PC is different (installer vs portable). You need the folder that contains **`JDownloader.jar`**.

| Name | What it is | Example |
|------|------------|---------|
| **JD root** | Folder with `JDownloader.jar` + `Core.jar` | `C:\JDownloader\` or `~/.jd/` |
| **Plugin folder** | Nested `jd/plugins/` inside that root | `…/jd/plugins/` |

#### Option A — Pathfinder (recommended)

| System | Run this from the unpacked ZIP |
|--------|--------------------------------|
| **Windows** | Double-click `plugin/find-jd-home.bat` |
| **Linux / macOS** | `cd plugin && chmod +x find-jd-home.sh && ./find-jd-home.sh` |

The helper prints:

- **JD root** — where `Core.jar` lives  
- **Plugin folder** — where you copy the `.class` files  

If several installs show up, pick the one your shortcut actually starts.

#### Option B — Search yourself

1. Search the PC for **`JDownloader.jar`** (Windows: `Win+S`)  
2. Right-click → **Open file location** → that folder is the **JD root**  
3. Open `jd` → `plugins` → that is the **plugin folder**

#### If nothing is found

1. Start JDownloader once (so it creates its folder)  
2. Right-click the desktop / Start-menu shortcut → **Open file location**  
3. Portable users: look where you extracted JD (Desktop, Downloads, USB, another drive)  
4. Still stuck: search again for **`Core.jar`** — it must sit next to `JDownloader.jar`  
5. Then copy plugins into: `<JD-Root>/jd/plugins/`

---

### Install the plugin files

1. **Quit JDownloader** completely.  
2. Copy from the ZIP into **your** plugin folder:

| From the ZIP | Into |
|--------------|------|
| `plugin/plugins/hoster/*` | `<JD-Root>/jd/plugins/hoster/` |
| `plugin/plugins/decrypter/*` | `<JD-Root>/jd/plugins/decrypter/` |
| `plugin/plugins/components/*` | `<JD-Root>/jd/plugins/components/` |

You should end up with e.g. `<JD-Root>/jd/plugins/hoster/AnkergamesNet.class`.

3. Patch **`Core.jar`** in the **JD root** (next to `JDownloader.jar`). Open it with 7-Zip / Archive Manager, **backup first**, then replace:

| Path inside `Core.jar` | File from ZIP |
|------------------------|---------------|
| `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/turnstile.html` | `core-patch/turnstile.html` |
| `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/CloudflareTurnstileChallenge.class` | `core-patch/CloudflareTurnstileChallenge.class` |

4. Start JDownloader.

<details>
<summary>Optional: let the install script copy for you</summary>

```bash
cd plugin
JD_HOME="/path/to/JD-root" ./install.sh   # Linux / macOS
# Windows: install.bat  (or set JD_HOME first)
```

</details>

---

## Step 2 — Browser add-on

Use the **same browser** JDownloader opens for captchas.

### Chrome · Vivaldi · Brave · Edge · Chromium

1. Open `chrome://extensions` (or `vivaldi://` / `brave://` / `edge://extensions`)  
2. Turn **Developer mode** ON  
3. **Load unpacked** → select `companion/chromium/`  
4. Confirm **JD Turnstile Companion** is listed  

### Firefox

Use **Firefox Developer Edition** or **Nightly** (Release blocks unsigned add-ons).

1. `about:config` → `xpinstall.signatures.required` → **false**  
2. `about:addons` → ⚙ → **Install Add-on From File…**  
3. Pick `companion/dist/jd-turnstile-companion-firefox-*.xpi`  

---

## Use it

1. In JDownloader, add e.g. `https://ankergames.net/game/…`  
2. Start the download → solve **Turnstile** in the browser  
3. **Keep the AnkerGames tab open** until JD finishes  

No AnkerGames account in JD. No MyJDownloader.

```text
You solve Turnstile  →  add-on fetches CDN (real browser TLS)
                     →  streams to http://127.0.0.1/…
                     →  JDownloader saves the file
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Pathfinder finds nothing | See [If nothing is found](#if-nothing-is-found) |
| Plugin missing in JD | Files must be under `…/jd/plugins/…` (note the nested `jd/`) + Core patch applied |
| Add-on missing | Step 2 again · Developer mode ON |
| Firefox “not verified” | Dev Edition / Nightly + signatures = false |
| JD stuck at 0 B | Keep the AnkerGames tab open |
| Browser downloads the ZIP itself | Don’t open `*.dlproxy.uk` · reload the add-on |

---

## Developers

```bash
cd companion && ./build-packages.sh
python3 -m unittest discover -s tests -v
```
