# AnkerGames for JDownloader 2

Unofficial **JDownloader 2** hoster/crawler plugin plus a **real browser add-on** (`.xpi` / `.crx`) so downloads from [ankergames.net](https://ankergames.net) work despite Cloudflare.

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
| `companion/firefox/` | Firefox source → built as **`.xpi`** |
| `companion/chromium/` | Chromium source → built as **`.crx` / `.zip`** |
| `companion/dist/` | Ready-to-install packages (versioned) |
| `companion/install.sh` | One-shot companion installer |
| `core-patch/` | Patched Turnstile captcha HTML + class (relay metas) for `Core.jar` |
| `src/` | Java / HTML sources for transparency |

## Requirements

- JDownloader 2 (local install with `JDownloader.jar` + `Core.jar`)
- One desktop browser: Firefox **or** Chromium (Chrome / Edge / Brave / **Vivaldi**)
- Companion installed in the **same** browser JD opens for captchas

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

### 2) Browser companion (real add-on — no “Load unpacked”)

```bash
cd companion
chmod +x install.sh
./install.sh
```

That builds packages into `companion/dist/` and installs them:

| Browser | What you get | How |
|---------|--------------|-----|
| **Vivaldi / Chrome / Edge / Brave** | `.crx` + managed policy (`ExtensionInstallForcelist`) | Restart the browser once, or drag `companion.crx` onto `…://extensions` |
| **Firefox** | `.xpi` file install | Confirm the install prompt, or *about:addons → gear → Install Add-on From File…* |

Prebuilt artifacts (also on [GitHub Releases](https://github.com/benjarogit/jd2plugin-ankergames-download/releases)):

- `companion/dist/jd-turnstile-companion-chromium-1.3.0.crx`
- `companion/dist/jd-turnstile-companion-firefox-1.3.0.xpi`

Stable Chromium extension id: `haopihkkdnnohoknooliddghpanmmedj`

**Firefox signing note:** Release Firefox only accepts Mozilla-signed XPIs. The shipped XPI works immediately in **Firefox Developer Edition / Nightly** (`xpinstall.signatures.required` = `false`), or after AMO unlisted signing — see [`companion/SIGNING.md`](companion/SIGNING.md). Chromium/Vivaldi need no AMO account.

Confirm companion version **1.3.0+** under the browser’s extensions page.

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
| Captcha closes with no download | Companion not installed / wrong browser | Run `companion/install.sh`; use the captcha browser |
| Firefox rejects XPI as unverified | Unsigned release XPI | Dev Edition, or sign via `SIGNING.md` |
| Browser download of the ZIP | Old companion / CDN tab opened | Use 1.3.0+; never open the CDN URL manually |
| JD stuck at 0 B | Work tab closed during stream | Keep AnkerGames tab open; restart download |
| “Companion must stream via relay” | `do=solve` without `via=relay` | Update companion; ensure Core patch applied |
| Cloudflare / empty HTML from CDN | Java or non-browser fetch | Only tab/background browser fetch is supported |

## Building from source (developers)

Against a local JD install (`JD_HOME=~/.jd`):

```bash
# from the upstream jdownloader workspace that contains trunk/ + build-plugin-package.sh
JD_HOME="$HOME/.jd" ./build-plugin-package.sh
```

Companion packages only:

```bash
cd companion
./build-packages.sh   # → dist/*.xpi + *.crx + *.zip
./install-firefox.sh
./install-chromium.sh
```

## Legal / ethics

- For personal use and research (e.g. HITL captcha + browser TLS bridging).
- Respect ankergames.net terms and local law.
- Do not use this to bypass paywalls or redistribute copyrighted game files.

## License

Plugin and companion code in this repository: provided as-is for interoperability with JDownloader’s local plugin API. JDownloader itself remains under AppWork’s license. AnkerGames / Cloudflare trademarks belong to their owners.
