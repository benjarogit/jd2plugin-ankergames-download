<p align="center">
  <img src="companion/assets/logo.png" width="180" alt="AnkerGames × JDownloader" />
</p>

<h1 align="center">AnkerGames → JDownloader&nbsp;2</h1>

<p align="center">
  AnkerGames downloads that work in JDownloader<br/>
  Manual install · No MyJD · No AnkerGames login
</p>

<p align="center">
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest/download/ankergames-jd2-full.zip"><img src="https://img.shields.io/badge/Download_Plugin_ZIP-0b1220?style=for-the-badge&labelColor=2aa9e0" alt="Download Plugin ZIP" /></a>
  &nbsp;
  <a href="https://jdownloader.org/jdownloader2"><img src="https://img.shields.io/badge/Download_JDownloader_2-1a5f7a?style=for-the-badge&labelColor=0b1220" alt="Download JDownloader 2" /></a>
</p>

<p align="center">
  <img src="https://img.shields.io/github/v/release/benjarogit/jd2plugin-ankergames-download?style=flat-square&label=release" alt="Release" />
  <img src="https://img.shields.io/badge/Windows%20%7C%20Linux%20%7C%20macOS-lightgrey?style=flat-square" alt="Platform" />
  · <a href="README.de.md">Deutsch</a>
</p>

---

[ankergames.net](https://ankergames.net) is behind Cloudflare. JD’s Java client gets blocked.  
This package adds a **JD plugin** + **browser companion** so Turnstile runs in a real browser and the file streams to JD.

> Unofficial — not affiliated with AppWork, JDownloader, or AnkerGames.

---

### Install

| Step | Action |
|:----:|--------|
| 0 | Need JD? → [Download JDownloader 2](https://jdownloader.org/jdownloader2) |
| 1 | [Download this ZIP](https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest/download/ankergames-jd2-full.zip) and unpack |
| 2 | Find JD folder → copy plugin files → patch `Core.jar` |
| 3 | Load the browser companion |
| 4 | Paste game URL in JD → solve captcha → **keep the tab open** |

<details>
<summary><b>Find your JD folder</b></summary>

<br/>

Every PC differs (installer vs portable). You need the folder with **`JDownloader.jar`**.

| Name | Meaning | Example |
|------|---------|---------|
| **JD root** | `JDownloader.jar` + `Core.jar` | `C:\JDownloader\` · `~/.jd/` |
| **Plugin folder** | nested `jd/plugins/` | `…/jd/plugins/` |

**Pathfinder (from the ZIP):**

| OS | Run |
|----|-----|
| Windows | Double-click `plugin/find-jd-home.bat` |
| Linux / macOS | `cd plugin && chmod +x find-jd-home.sh && ./find-jd-home.sh` |

Prints JD root and plugin folder. Multiple hits → use the one your shortcut starts.

<details>
<summary>Search manually</summary>

1. Search for `JDownloader.jar` (`Win+S`)  
2. Right-click → Open file location → JD root  
3. Open `jd` → `plugins` → plugin folder  

</details>

<details>
<summary>Nothing found</summary>

1. Start JDownloader once  
2. Right-click shortcut → Open file location  
3. Portable: Desktop / Downloads / USB / other drive  
4. Or search for `Core.jar` (next to `JDownloader.jar`)  
5. Copy plugins into `<JD-Root>/jd/plugins/`  

</details>

</details>

<details>
<summary><b>Install plugin + Core patch</b></summary>

<br/>

1. Quit JDownloader completely  
2. Copy into your plugin folder:

| From ZIP | Into |
|----------|------|
| `plugin/plugins/hoster/*` | `<JD-Root>/jd/plugins/hoster/` |
| `plugin/plugins/decrypter/*` | `<JD-Root>/jd/plugins/decrypter/` |
| `plugin/plugins/components/*` | `<JD-Root>/jd/plugins/components/` |

Done when `<JD-Root>/jd/plugins/hoster/AnkergamesNet.class` exists.

3. Patch **`Core.jar`** in the JD root (next to `JDownloader.jar`) with 7-Zip — backup first:

| Inside `Core.jar` | Replace with |
|-------------------|--------------|
| `…/cloudflareturnstile/turnstile.html` | `core-patch/turnstile.html` |
| `…/cloudflareturnstile/CloudflareTurnstileChallenge.class` | `core-patch/CloudflareTurnstileChallenge.class` |

4. Start JDownloader  

</details>

<details>
<summary><b>Browser companion</b></summary>

<br/>

Use the **same browser** JD opens for captchas.

| Browser | How |
|---------|-----|
| Chrome / Vivaldi / Brave / Edge | Open `chrome://extensions` (or `vivaldi://extensions`) → Developer mode ON → **Load unpacked** → select the folder `companion/chromium/` (not the ZIP root) |
| Firefox (normal) | `about:addons` → gear → **Install Add-on From File…** → signed `companion/dist/jd-turnstile-companion-firefox-1.0.0.xpi`. Until Mozilla finishes signing: `about:debugging` → This Firefox → Load Temporary Add-on → `companion/firefox/manifest.json` |

</details>

<details>
<summary><b>Use it</b></summary>

<br/>

1. Add e.g. `https://ankergames.net/game/…` in JD  
2. Start download → solve Turnstile in the browser  
3. Keep the AnkerGames tab open until JD finishes  

```text
Turnstile → companion fetches CDN → localhost → JD saves file
```

</details>

<details>
<summary><b>Troubleshooting</b></summary>

<br/>

| Problem | Fix |
|---------|-----|
| Pathfinder empty | See “Nothing found” above |
| Plugin missing in JD | Files under `…/jd/plugins/…` + Core patch |
| Companion missing | Load the `companion/chromium/` folder (unpacked) or the signed Firefox XPI |
| Firefox rejects XPI | Need Mozilla-signed build · or temporary load via `about:debugging` |
| JD at 0 B | Keep AnkerGames tab open |
| Browser saves the ZIP | Reload companion · don’t open `*.dlproxy.uk` |

</details>
