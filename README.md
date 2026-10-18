# AnkerGames → JDownloader 2

<p align="center">
  <img src="companion/assets/logo-256.png" width="96" alt="Companion logo" />
</p>

<p align="center">
  <strong>Manual install · No MyJD · No AnkerGames login</strong><br/>
  <a href="#english">English</a> · <a href="README.de.md">Deutsch</a>
</p>

[![CI](https://github.com/benjarogit/jd2plugin-ankergames-download/actions/workflows/ci.yml/badge.svg)](https://github.com/benjarogit/jd2plugin-ankergames-download/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/benjarogit/jd2plugin-ankergames-download)](https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest)

Download games from [ankergames.net](https://ankergames.net) with **JDownloader**.  
Cloudflare blocks JD’s Java client — you solve the captcha in a **browser**, and a small **browser add-on** streams the file to JD.

> Unofficial. Not affiliated with AppWork, JDownloader, or AnkerGames.

---

<a id="english"></a>

## What you need

| Item | Why |
|------|-----|
| JDownloader 2 | Saves the file and shows progress |
| Browser add-on | Talks to Cloudflare with real browser TLS |
| Same browser for captchas | JD opens the captcha; the add-on must run there |

**No AnkerGames account** in JDownloader. **No MyJDownloader.**

---

## Install (2 steps)

### Step 1 — JDownloader plugin

**Where is my JD folder?**

| System | Typical path |
|--------|----------------|
| Linux | `~/.jd` |
| Windows | `%USERPROFILE%\.jd` or the folder where you installed JD |
| macOS | `~/Library/Application Support/JDownloader` or your JD folder |

You need a folder that contains `JDownloader.jar`, `Core.jar`, and `jd/plugins/`.

**Do this:**

1. **Quit JDownloader** completely.
2. Copy plugin classes into JD:
   - From this repo: `plugin/plugins/hoster/` → JD’s `jd/plugins/hoster/`
   - `plugin/plugins/decrypter/` → `jd/plugins/decrypter/`
   - `plugin/plugins/components/` → `jd/plugins/components/`
3. Patch `Core.jar` (zip file — open with 7-Zip / unzip):
   - First **backup** `Core.jar`
   - Replace inside the jar:
     - `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/turnstile.html`  
       ← file from `core-patch/turnstile.html`
     - `org/jdownloader/captcha/v2/challenge/cloudflareturnstile/CloudflareTurnstileChallenge.class`  
       ← file from `core-patch/CloudflareTurnstileChallenge.class`
4. Start JDownloader.

**Optional helper** (only copies those files for you):

```bash
cd plugin
./install.sh      # Linux / macOS
install.bat       # Windows
```

---

### Step 2 — Browser add-on

Use the **same** browser JDownloader uses for captchas.

#### Chrome · Vivaldi · Brave · Edge · Chromium

| # | Action |
|---|--------|
| 1 | Open the extensions page: `chrome://extensions` / `vivaldi://extensions` / `brave://extensions` / `edge://extensions` |
| 2 | Enable **Developer mode** (top right) |
| 3 | Click **Load unpacked** |
| 4 | Select folder: `companion/chromium/` |
| 5 | Check the list shows **JD Turnstile Companion** |

#### Firefox

Release Firefox blocks unsigned add-ons. Use **Firefox Developer Edition** or **Nightly**.

| # | Action |
|---|--------|
| 1 | Open `about:config` → accept the warning |
| 2 | Set `xpinstall.signatures.required` to **`false`** |
| 3 | Open `about:addons` → gear → **Install Add-on From File…** |
| 4 | Choose `companion/dist/jd-turnstile-companion-firefox-*.xpi` |

*Temporary alternative:* `about:debugging` → Load Temporary Add-on → `companion/firefox/manifest.json` (gone after restart).

---

## Use

1. In JDownloader Linkgrabber, paste e.g. `https://ankergames.net/game/…`
2. Start the download → solve **Turnstile** in the browser when asked
3. **Keep the AnkerGames tab open** until JD finishes

Progress appears in JDownloader — not as a normal browser download.

---

## How it works

```
You solve Turnstile  →  Browser add-on fetches CDN (real TLS)
                     →  streams bytes to http://127.0.0.1/…
                     →  JDownloader saves the file
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Add-on not listed | Repeat Step 2; Developer mode must be ON |
| Firefox “could not be verified” | Dev Edition/Nightly + `xpinstall.signatures.required = false` |
| JD stuck at 0 B | Keep AnkerGames tab open; don’t skip the captcha |
| Browser downloads the ZIP itself | Don’t open `*.dlproxy.uk`; reload the add-on |
| Plugin not found in JD | Confirm classes are under `jd/plugins/` and Core patch applied |

---

## For developers

```bash
# Companion packages (.xpi / .crx / .zip)
cd companion && ./build-packages.sh

# Smoke tests (no browser needed)
python3 -m unittest discover -s tests -v
```

CI runs package build + tests on every push (see `.github/workflows/ci.yml`).
