# AnkerGames for JDownloader 2

[English](#english) · [Deutsch](README.de.md)

Unofficial **JDownloader 2** hoster/crawler plugin + **real browser extensions** (`.crx` / `.xpi`) so [ankergames.net](https://ankergames.net) downloads work despite Cloudflare.

> Not affiliated with AppWork / JDownloader. Official support declined this hoster because Cloudflare blocks JD’s Java HTTP client.

[![Release](https://img.shields.io/github/v/release/benjarogit/jd2plugin-ankergames-download?label=release)](https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest)
[![License](https://img.shields.io/badge/license-as--is-lightgrey)](#license)

---

<a id="english"></a>

## English

### What you get

| Piece | Role |
|-------|------|
| **JD plugin** | Detects AnkerGames links, opens Turnstile HITL, downloads via localhost relay |
| **Browser companion** | Real add-on in your browser — solves Turnstile, fetches CDN with **browser TLS**, pipes bytes to JD |
| **Core patch** | Adds relay metadata to JD’s Turnstile captcha page |

### Supported browsers

| Browser | Package | Auto-update via GitHub |
|---------|---------|------------------------|
| **Chrome / Chromium** | `.crx` + policy | Yes — `updates/chromium.xml` |
| **Vivaldi** | `.crx` + policy | Yes |
| **Brave** | `.crx` + policy | Yes |
| **Edge** | `.crx` + policy | Yes |
| **Firefox** | `.xpi` | Yes **if Mozilla-signed** — `updates/firefox.json`; otherwise badge **↑** |
| **Safari** | Safari Web Extension (build on macOS) | No CRX feed — see [`companion/safari/README.md`](companion/safari/README.md) |

All companions also poll the **GitHub Releases API** and show a toolbar badge **↑** when a newer version exists (opens the release page).

### How it works

Cloudflare compares **TLS fingerprints (JA3/JA4)** with the User-Agent. JDownloader speaks **Java TLS** while advertising a browser UA → blocked. A CDN URL from AnkerGames (`*.dlproxy.uk`) still fails if Java fetches it.

```
┌─────────────────┐     Turnstile HITL      ┌──────────────────┐
│  ankergames.net │ ◄─────────────────────► │ Your browser     │
│  + Cloudflare   │     real browser TLS    │ + Companion      │
└────────┬────────┘                         └────────┬─────────┘
         │ CDN URL (signed)                          │ fetch(CDN)
         │                                           │ POST chunks
         │                                  ┌────────▼─────────┐
         │                                  │ 127.0.0.1 relay  │
         │                                  │ AnkergamesCdnRelay│
         │                                  └────────┬─────────┘
         │                                           │ GET /file
         │                                  ┌────────▼─────────┐
         └──────────────────────────────────│  JDownloader     │
                                            │  (progress/path) │
                                            └──────────────────┘
```

1. You add a game URL in JD Linkgrabber.  
2. JD opens a local Turnstile page → companion opens the game tab.  
3. **You** solve Cloudflare Turnstile once.  
4. Companion receives the CDN URL, blocks tab navigation to it (so the browser does not “Save as…”), and streams the file into a localhost relay.  
5. JD downloads from `http://127.0.0.1:<port>/file` as a normal list entry.

**Keep the AnkerGames tab open** until the stream finishes.

### Requirements

- JDownloader 2 (`JDownloader.jar` + `Core.jar`)
- One supported desktop browser (same one JD uses for captchas)
- Linux / macOS / Windows for the plugin installer; companion scripts are bash (WSL/Git Bash on Windows, or install `.crx`/`.xpi` from Releases manually)

### Installation

#### 1) JDownloader plugin + Core patch

```bash
git clone https://github.com/benjarogit/jd2plugin-ankergames-download.git
cd jd2plugin-ankergames-download/plugin
chmod +x install.sh
./install.sh
```

Windows: `install.bat` or `install.ps1`.

Custom JD path:

```bash
JD_HOME="/path/to/jdownloader" ./install.sh
```

#### 2) Browser companion (real add-on)

```bash
cd ../companion
chmod +x install.sh
./install.sh
```

Choose **[2]** for Chrome/Vivaldi/Brave/Edge, **[1]** for Firefox, or **[3]** for both.

**Or install from [Releases](https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest):**

| Browser | File | Action |
|---------|------|--------|
| Chromium family | `jd-turnstile-companion-chromium-*.crx` | `…://extensions` → Developer mode → drag the `.crx` onto the page → restart once |
| Firefox | `jd-turnstile-companion-firefox-*.xpi` | `about:addons` → gear → *Install Add-on From File…* |

Stable Chromium extension id: `haopihkkdnnohoknooliddghpanmmedj`

**Firefox signing:** Release Firefox rejects unsigned XPIs. Use [Firefox Developer Edition](https://www.mozilla.org/firefox/developer/) (`xpinstall.signatures.required` = `false`) or sign via AMO — see [`companion/SIGNING.md`](companion/SIGNING.md).

**Safari:** build on a Mac with Xcode — [`companion/safari/README.md`](companion/safari/README.md).

Confirm companion version **1.4.0+** on the extensions page.

### Updates — automatic or not?

| Channel | Automatic? | Mechanism |
|---------|------------|-----------|
| Chrome / Vivaldi / Brave / Edge | **Yes** | Native `update_url` → [`updates/chromium.xml`](updates/chromium.xml) → GitHub Release `.crx` |
| Firefox (signed) | **Yes** | `gecko.update_url` → [`updates/firefox.json`](updates/firefox.json) → Release `.xpi` |
| Firefox (unsigned / Dev Edition) | Badge only | Toolbar **↑** → open Release page → reinstall XPI |
| Safari | Manual / App Store | No GitHub CRX feed |
| All browsers | Badge fallback | Polls GitHub Releases API every few hours |

When we publish a new Release, a GitHub Action refreshes the update feeds on `main`.

### Usage

1. Linkgrabber → add e.g. `https://ankergames.net/game/silver-pines`  
2. Optional: Accounts → **ankergames**  
3. Start download → solve Turnstile in the browser  
4. Leave the game tab open until JD finishes  
5. Progress lives in JD, not as a normal browser download

### Important

- Do **not** click Skip on the captcha while the companion is working.  
- Do **not** open `*.dlproxy.uk` manually — the plugin refuses Java→CDN on purpose.  
- Use the **same** browser for captchas and the companion.

### Troubleshooting

| Symptom | Fix |
|---------|-----|
| Captcha closes, no download | Companion missing / wrong browser → reinstall 1.4.0+ |
| Firefox “could not be verified” | Sign XPI or use Developer Edition — `SIGNING.md` |
| Browser downloads the ZIP itself | Old companion → update; never open CDN URL |
| JD stuck at 0 B | Keep AnkerGames tab open; restart download |
| No auto-update | Check feed URLs / Release assets; use badge **↑** |

### Package layout

```
plugin/          JD classes + installers
companion/
  chromium/      MV3 source → .crx
  firefox/       MV2 source → .xpi
  safari/        conversion notes (macOS)
  dist/          built packages
  install.sh     one-shot installer
core-patch/      Turnstile HTML + class for Core.jar
updates/         GitHub auto-update feeds
src/             readable sources
```

### Legal

Personal use / research (HITL captcha + browser TLS bridging). Respect ankergames.net terms and local law. Do not redistribute copyrighted game files.

### License

Code in this repository: as-is for local JD plugin interoperability. JDownloader remains under AppWork’s license. AnkerGames / Cloudflare trademarks belong to their owners.
