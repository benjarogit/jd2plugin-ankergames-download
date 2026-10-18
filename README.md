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

| Browser | Package | Notes |
|---------|---------|--------|
| **Chrome / Chromium / Vivaldi / Brave / Edge** | unsigned `.crx` | Sideload / policy — no Web Store needed |
| **Firefox** | unsigned `.xpi` | Developer Edition / Nightly (or temporary load) — see [`companion/INSTALL-BROWSER.md`](companion/INSTALL-BROWSER.md) |

Safari is **not** supported. Companions also show a toolbar badge **↑** when a newer GitHub Release exists.

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

### Installation (recommended)

One wizard installs the **plugin** and the **browser add-on**. It speaks German or English (from your system language, or force with `--de` / `--en`).

```bash
git clone https://github.com/benjarogit/jd2plugin-ankergames-download.git
cd jd2plugin-ankergames-download
chmod +x install.sh
./install.sh
```

You will be asked:

1. Continue with the JDownloader plugin? → type **Y** / **J** (or **n** to skip)
2. Which browser for captchas? → type a **name**, e.g. `vivaldi`, `chrome`, `brave`, `edge`, `firefox`, or `all`  
   **Do not type a lone number into the shell** — that is not a command.

**Chromium family:** unsigned `.crx` — installer force-installs via policy, or drag onto `…://extensions` (Developer mode). Store signing not required.

**Firefox:** unsigned `.xpi` — use **Developer Edition / Nightly**, set `xpinstall.signatures.required` = `false`, then *Install Add-on From File…*.  
Step-by-step (EN/DE): [`companion/INSTALL-BROWSER.md`](companion/INSTALL-BROWSER.md).  
AMO signing is optional and not needed for normal use ([`SIGNING.md`](companion/SIGNING.md)).

Custom JD path: `JD_HOME="/path/to/jdownloader" ./install.sh`

Windows (plugin only): `plugin/install.bat` or `plugin/install.ps1`, then companion from [Releases](https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest) + INSTALL-BROWSER.md.

Stable Chromium id: `haopihkkdnnohoknooliddghpanmmedj`

### Updates

| Channel | How |
|---------|-----|
| Chrome / Vivaldi / Brave / Edge | Policy / `updates/chromium.xml` + re-run installer |
| Firefox (unsigned) | Toolbar badge **↑** → download new XPI → install from file again |
| All | Badge polls GitHub Releases |

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
| Firefox “could not be verified” | Use Dev Edition/Nightly + `xpinstall.signatures.required=false` — `INSTALL-BROWSER.md` |
| Browser downloads the ZIP itself | Old companion → update; never open CDN URL |
| JD stuck at 0 B | Keep AnkerGames tab open; restart download |
| No auto-update | Check feed URLs / Release assets; use badge **↑** |

### Package layout

```
plugin/          JD classes + installers
companion/
  chromium/      MV3 source → .crx
  firefox/       MV2 source → .xpi
  dist/          built packages
  INSTALL-BROWSER.md   unsigned install (EN/DE)
  install.sh     companion installer
core-patch/      Turnstile HTML + class for Core.jar
updates/         GitHub update feeds
src/             readable sources
```

### Legal

Personal use / research (HITL captcha + browser TLS bridging). Respect ankergames.net terms and local law. Do not redistribute copyrighted game files.

### License

Code in this repository: as-is for local JD plugin interoperability. JDownloader remains under AppWork’s license. AnkerGames / Cloudflare trademarks belong to their owners.
