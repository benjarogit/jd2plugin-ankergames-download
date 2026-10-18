<p align="center">
  <img src="companion/assets/logo-512.png" width="220" alt="AnkerGames × JDownloader" />
</p>

<h1 align="center">AnkerGames → JDownloader&nbsp;2</h1>

<p align="center">
  <strong>Download AnkerGames titles with JDownloader</strong><br/>
  Manual install · No MyJD · No AnkerGames login
</p>

<p align="center">
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest/download/ankergames-jd2-full.zip"><img src="https://img.shields.io/badge/⬇_Download-0b1220?style=for-the-badge&labelColor=2aa9e0" alt="Download" /></a>
  &nbsp;
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest"><img src="https://img.shields.io/badge/All_release_files-1a5f7a?style=for-the-badge" alt="All release files" /></a>
</p>

<p align="center">
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/benjarogit/jd2plugin-ankergames-download/ci.yml?style=flat-square&label=CI" alt="CI" /></a>
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest"><img src="https://img.shields.io/github/v/release/benjarogit/jd2plugin-ankergames-download?style=flat-square" alt="Release" /></a>
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey?style=flat-square" alt="Platform" />
</p>

<p align="center">
  <a href="#-english">English</a> · <a href="README.de.md">Deutsch</a>
</p>

---

## Why this exists

[ankergames.net](https://ankergames.net) sits behind **Cloudflare**. JDownloader’s Java HTTP client gets blocked.  
This project adds:

1. a **JDownloader plugin** (plus a small Core patch), and  
2. a **browser add-on** that solves Turnstile and streams the file to JD over localhost.

> Unofficial. Not affiliated with AppWork, JDownloader, or AnkerGames.

---

<a id="-english"></a>

## English

### Quick start

| Step | What you do |
|:----:|-------------|
| **0** | Click **Download Latest Release** (or ZIP) above and unpack |
| **1** | Install the **JDownloader** plugin |
| **2** | Install the **browser** add-on |
| **3** | Paste a game URL in JD → solve captcha → keep the tab open |

---

### Step 1 — JDownloader plugin

#### First: find your JD folder (different on every PC)

Two levels — easy to mix up:

| Name | What’s inside? | Example |
|------|----------------|---------|
| **JD root** | `JDownloader.jar` + `Core.jar` | `…/.jd/` or your portable folder |
| **Plugin folder** | nested `jd/plugins/` | `…/.jd/jd/plugins/` |

**Find the correct folder (installer or portable):**

1. Search your PC for the file **`JDownloader.jar`**  
   (Windows: Win+S · Linux/macOS: file manager search or helper below)
2. **Right-click → Open file location**  
   → that folder is your **JD root**
3. Open the subfolder **`jd` → `plugins`**  
   → that is your **plugin folder**
4. Portable: usually wherever you extracted JD (Desktop, Downloads, USB…)

**Let a helper search for you:**

| System | In the ZIP |
|--------|------------|
| Windows | Double-click `plugin/find-jd-home.bat` |
| Linux / macOS | `cd plugin && chmod +x find-jd-home.sh && ./find-jd-home.sh` |

It prints JD root **and** the plugin path. If several installs show up, use the one you actually launch (check your shortcut).

---

1. **Quit JDownloader** completely.
2. Copy from the ZIP into **your** plugin folder  
   (`<JD-Root>/jd/plugins/…` — path from the helper / search):

| From the ZIP | Destination |
|--------------|-------------|
| Contents of `plugin/plugins/hoster/` | `<JD-Root>/jd/plugins/hoster/` |
| Contents of `plugin/plugins/decrypter/` | `<JD-Root>/jd/plugins/decrypter/` |
| Contents of `plugin/plugins/components/` | `<JD-Root>/jd/plugins/components/` |

Done when you have e.g.  
`<JD-Root>/jd/plugins/hoster/AnkergamesNet.class`

3. Patch **`Core.jar`** in the **JD root** (next to `JDownloader.jar` — it is a ZIP; open with 7-Zip):
   - Backup `Core.jar` first
   - Replace inside the archive:

| Path inside `Core.jar` | Replace with |
|------------------------|--------------|
| `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/turnstile.html` | `core-patch/turnstile.html` |
| `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/CloudflareTurnstileChallenge.class` | `core-patch/CloudflareTurnstileChallenge.class` |

4. Start JDownloader.

<details>
<summary>Optional: copy helper (after you know the path)</summary>

```bash
cd plugin
JD_HOME="/path/to/JD-root" ./install.sh   # Linux / macOS
# Windows: install.bat  (auto-detects; or set JD_HOME)
```

</details>

---

### Step 2 — Browser add-on

Use the **same browser** JDownloader opens for captchas.

#### Chrome · Vivaldi · Brave · Edge · Chromium

| # | Do this |
|---|---------|
| 1 | Open `chrome://extensions` *(or `vivaldi://` / `brave://` / `edge://extensions`)* |
| 2 | Turn **Developer mode** ON |
| 3 | **Load unpacked** → select `companion/chromium/` |
| 4 | Confirm **JD Turnstile Companion** is listed |

#### Firefox

Use **Firefox Developer Edition** or **Nightly** (Release blocks unsigned add-ons).

| # | Do this |
|---|---------|
| 1 | `about:config` → `xpinstall.signatures.required` → **false** |
| 2 | `about:addons` → ⚙ → **Install Add-on From File…** |
| 3 | Pick `companion/dist/jd-turnstile-companion-firefox-*.xpi` |

---

### Use it

1. In JDownloader, add e.g. `https://ankergames.net/game/…`
2. Start download → solve **Turnstile** in the browser
3. **Keep the AnkerGames tab open** until JD finishes

No AnkerGames account in JD. No MyJDownloader.

---

### How it works

```text
Turnstile (you)  →  Browser add-on fetches CDN (real TLS)
                 →  streams to http://127.0.0.1/…
                 →  JDownloader saves the file
```

---

### Troubleshooting

| Problem | Fix |
|---------|-----|
| Add-on missing | Step 2 again · Developer mode ON |
| Firefox “not verified” | Dev Edition/Nightly + signatures = false |
| JD at 0 B | Keep AnkerGames tab open |
| Browser saves the ZIP | Don’t open `*.dlproxy.uk` · reload add-on |
| Plugin missing in JD | Are `.class` files under `…/.jd/jd/plugins/…` (note nested `jd/`)? + Core patch in `…/.jd/Core.jar` |

---

### Developers

```bash
cd companion && ./build-packages.sh
python3 -m unittest discover -s tests -v
```
