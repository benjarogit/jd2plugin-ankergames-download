# AnkerGames for JDownloader 2

Unofficial **JDownloader 2** hoster/crawler plugin plus a **browser companion** so downloads from [ankergames.net](https://ankergames.net) work despite Cloudflare.

> Not affiliated with AppWork / JDownloader. Official support declined this hoster because Cloudflare blocks JDownloader’s Java HTTP client.

## Why a companion is required

Cloudflare compares **TLS fingerprints (JA3/JA4)** with the claimed User-Agent. JDownloader speaks **Java TLS** while advertising a Firefox UA → bot score → block. Even a freshly generated CDN link (`*.dlproxy.uk`) fails when opened by Java.

So:

| Who | What Cloudflare / AnkerGames see |
|-----|----------------------------------|
| Browser (+ companion) | Real Firefox/Chrome/Vivaldi TLS + Turnstile session |
| JDownloader | Only `http://127.0.0.1:<port>/file` (localhost relay) |

**Human-in-the-loop:** you solve Cloudflare Turnstile in a real browser. The companion then streams the CDN file into a localhost relay; JD manages progress, path, and the download list as usual.

```
AnkerGames / Cloudflare          Your browser                 JDownloader
─────────────────────          ─────────────────            ──────────────
Turnstile (HITL)  ───────────►  Companion solves
CDN URL (signed)  ───────────►  fetch(CDN) [browser TLS]
                                POST chunks ───────────────►  localhost /push
                                (tab stays open)              GET /file
                                                              → silver-pines.zip
```

## Package contents

| Path | Purpose |
|------|---------|
| `plugin/` | JD hoster + crawler + `AnkergamesCdnRelay` + installers |
| `companion/firefox/` | Firefox MV2 temporary add-on |
| `companion/chromium/` | Chrome / Edge / Brave / **Vivaldi** MV3 unpacked extension |
| `core-patch/` | Patched Turnstile captcha HTML + class (relay metas) for `Core.jar` |
| `src/` | Java / HTML sources for transparency |

## Requirements

- JDownloader 2 (local install with `JDownloader.jar` + `Core.jar`)
- One desktop browser: Firefox **or** a Chromium browser (Chrome / Edge / Brave / Vivaldi)
- Companion loaded in the **same** browser JD opens for captchas

## Install

### 1) Plugin + Core patch (Linux / macOS)

```bash
cd plugin
chmod +x install.sh
./install.sh
```

The installer stops JD, copies plugin classes (including `AnkergamesCdnRelay`), patches `Core.jar` with `../core-patch/`, clears plugin caches, and starts JD again.

Windows: run `install.bat` or `install.ps1` from `plugin/`.

If JD is not auto-detected:

```bash
JD_HOME="/path/to/your/jdownloader" ./install.sh
```

### 2) Browser companion (required)

**Firefox**

1. Open `about:debugging#/runtime/this-firefox`
2. Temporary Add-on → select  
   `companion/firefox/manifest.json`
3. Confirm version **1.2.9+**

**Chrome / Edge / Brave / Vivaldi**

1. Open `chrome://extensions` (Vivaldi: `vivaldi://extensions`)
2. Enable Developer mode
3. Load unpacked → select folder  
   `companion/chromium/`
4. Confirm version **1.2.9+**

Use the **same** browser as JD’s captcha (“Browser öffnen” / auto-open).

## Usage

1. Add a game URL in Linkgrabber, e.g.  
   `https://ankergames.net/game/silver-pines`
2. Optional: Accounts → add **ankergames** (site signup happens on the website)
3. Start the download → solve Turnstile in the browser when prompted
4. Leave the **AnkerGames tab open** until the overlay shows the stream is finished (or the JD download completes). Closing it aborts the CDN→relay pipe.
5. Progress appears in JD (localhost relay), not as a normal browser file download

## Important behaviour

- **Do not** click “Überspringen” / Skip on the captcha dialog while the companion is working.
- **Do not** expect JD to download `dlproxy.uk` directly — the plugin refuses that path on purpose.
- The companion blocks navigating the CDN URL in a tab (that would trigger a browser download). Bytes go only through the relay.
- After a successful solve, a second captcha for the same download is suppressed (avoids double starts if a tab is closed mid-stream).

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Captcha closes with no download | Companion not loaded / wrong browser | Reload companion 1.2.9 in the captcha browser |
| Browser download of the ZIP | Old companion / CDN tab opened | Use 1.2.9+; never open the CDN URL manually |
| JD stuck at 0 B | Work tab closed during stream | Keep AnkerGames tab open; restart download |
| “Companion must stream via relay” | `do=solve` without `via=relay` | Update companion; ensure Core patch applied |
| Cloudflare / empty HTML from CDN | Java or non-browser fetch | Only tab/background browser fetch is supported |

## Building from source (developers)

Against a local JD install (`JD_HOME=~/.jd`):

```bash
# from the upstream jdownloader workspace that contains trunk/ + build-plugin-package.sh
JD_HOME="$HOME/.jd" ./build-plugin-package.sh
```

Companion:

```bash
cd companion/firefox && ./install.sh   # packs XPI + syncs chromium/
```

## Legal / ethics

- For personal use and research (e.g. HITL captcha + browser TLS bridging).
- Respect ankergames.net terms and local law.
- Do not use this to bypass paywalls or redistribute copyrighted game files.

## License

Plugin and companion code in this repository: provided as-is for interoperability with JDownloader’s local plugin API. JDownloader itself remains under AppWork’s license. AnkerGames / Cloudflare trademarks belong to their owners.
