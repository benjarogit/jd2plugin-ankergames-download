<p align="center">
  <img src="companion/assets/logo.png" width="180" alt="AnkerGames × JDownloader" />
</p>

<h1 align="center">AnkerGames → JDownloader&nbsp;2</h1>

<p align="center">
  <b>AnkerGames downloads that actually work in JD</b><br/>
  Manual install · No MyJD · No AnkerGames login
</p>

<p align="center">
  <a href="https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest/download/ankergames-jd2-full.zip"><img src="https://img.shields.io/badge/⬇_Plugin_ZIP-0b1220?style=for-the-badge&labelColor=2aa9e0" alt="Download Plugin ZIP" /></a>
  &nbsp;
  <a href="https://jdownloader.org/jdownloader2"><img src="https://img.shields.io/badge/⬇_JDownloader_2-1a5f7a?style=for-the-badge&labelColor=0b1220" alt="Download JDownloader 2" /></a>
</p>

<p align="center">
  <img src="https://img.shields.io/github/v/release/benjarogit/jd2plugin-ankergames-download?style=flat-square&label=release" alt="Release" />
  <img src="https://img.shields.io/github/actions/workflow/status/benjarogit/jd2plugin-ankergames-download/ci.yml?style=flat-square&label=CI" alt="CI" />
  <img src="https://img.shields.io/badge/Windows%20%7C%20Linux%20%7C%20macOS-lightgrey?style=flat-square" alt="Platform" />
  &nbsp;·&nbsp; <a href="README.de.md">Deutsch</a>
</p>

---

### Why?

[ankergames.net](https://ankergames.net) is behind Cloudflare. JD’s Java client gets blocked.  
This package adds a **JD plugin** + **browser add-on** so Turnstile runs in a real browser and the file streams to JD.

> Unofficial · not affiliated with AppWork / JDownloader / AnkerGames

---

### Install in 4 steps

| | Step | Action |
|:---:|:-----|:-------|
| 0️⃣ | **Need JD?** | [Download JDownloader 2](https://jdownloader.org/jdownloader2) if you don’t have it |
| 1️⃣ | **This ZIP** | [Download](https://github.com/benjarogit/jd2plugin-ankergames-download/releases/latest/download/ankergames-jd2-full.zip) & unpack |
| 2️⃣ | **Plugin** | Find JD folder → copy files → patch `Core.jar` |
| 3️⃣ | **Browser** | Load the companion in Chrome/Vivaldi/… or Firefox Dev |
| 4️⃣ | **Use** | Paste game URL in JD → solve captcha → **keep tab open** |

<details>
<summary><b>📁 Step 2 — Find your JD folder (Pathfinder)</b></summary>

<br/>

Every PC is different (installer vs portable). You need the folder with **`JDownloader.jar`**.

| Name | Meaning | Example |
|------|---------|---------|
| 🏠 **JD root** | `JDownloader.jar` + `Core.jar` | `C:\JDownloader\` · `~/.jd/` |
| 📦 **Plugin folder** | nested `jd/plugins/` | `…/jd/plugins/` |

**Easiest — run the Pathfinder from the ZIP:**

| OS | Command |
|----|---------|
| 🪟 Windows | Double-click `plugin/find-jd-home.bat` |
| 🐧 Linux / 🍎 macOS | `cd plugin && chmod +x find-jd-home.sh && ./find-jd-home.sh` |

It prints **JD root** and **plugin folder**. Multiple hits → use the one your shortcut starts.

<details>
<summary>Manual search instead</summary>

1. Search PC for `JDownloader.jar` (`Win+S`)  
2. Right-click → **Open file location** → that’s the JD root  
3. Open `jd` → `plugins` → plugin folder  

</details>

<details>
<summary>❓ Pathfinder finds nothing</summary>

1. Start JDownloader once  
2. Right-click shortcut → **Open file location**  
3. Portable: check Desktop / Downloads / USB / other drive  
4. Or search for `Core.jar` (must sit next to `JDownloader.jar`)  
5. Copy plugins into `<JD-Root>/jd/plugins/`  

</details>

</details>

<details>
<summary><b>🧩 Step 2 — Install plugin + Core patch</b></summary>

<br/>

1. **Quit JD** completely  
2. Copy into **your** plugin folder:

| From ZIP | Into |
|----------|------|
| `plugin/plugins/hoster/*` | `<JD-Root>/jd/plugins/hoster/` |
| `plugin/plugins/decrypter/*` | `<JD-Root>/jd/plugins/decrypter/` |
| `plugin/plugins/components/*` | `<JD-Root>/jd/plugins/components/` |

✅ Done when you see `<JD-Root>/jd/plugins/hoster/AnkergamesNet.class`

3. Patch **`Core.jar`** (in JD root, next to `JDownloader.jar`) with 7-Zip — **backup first**:

| Inside `Core.jar` | Replace with |
|-------------------|--------------|
| `…/cloudflareturnstile/turnstile.html` | `core-patch/turnstile.html` |
| `…/cloudflareturnstile/CloudflareTurnstileChallenge.class` | `core-patch/CloudflareTurnstileChallenge.class` |

4. Start JD  

</details>

<details>
<summary><b>🌐 Step 3 — Browser companion</b></summary>

<br/>

Use the **same browser** JD opens for captchas.

| Browser | How |
|---------|-----|
| 🟢 Chrome / Vivaldi / Brave / Edge | `chrome://extensions` → Developer mode ON → **Load unpacked** → `companion/chromium/` |
| 🦊 Firefox | **Dev Edition / Nightly** only → `about:config` → `xpinstall.signatures.required` = **false** → install `companion/dist/jd-turnstile-companion-firefox-*.xpi` |

</details>

<details>
<summary><b>▶️ Step 4 — Use it</b></summary>

<br/>

| # | Do this |
|---|---------|
| 1 | Add e.g. `https://ankergames.net/game/…` in JD |
| 2 | Start download → solve **Turnstile** in the browser |
| 3 | **Keep the AnkerGames tab open** until JD finishes |

No AnkerGames account in JD. No MyJDownloader.

```text
Turnstile (you) → companion fetches CDN → localhost → JD saves file
```

</details>

<details>
<summary><b>🛠️ Troubleshooting</b></summary>

<br/>

| Problem | Fix |
|---------|-----|
| Pathfinder empty | Expand “Pathfinder finds nothing” above |
| Plugin missing in JD | Files under `…/jd/plugins/…` + Core patch |
| Add-on missing | Developer mode ON · reload unpacked |
| Firefox “not verified” | Dev Edition / Nightly + signatures = false |
| JD at 0 B | Keep AnkerGames tab open |
| Browser saves the ZIP | Don’t open `*.dlproxy.uk` · reload add-on |

</details>

<details>
<summary><b>👨‍💻 Developers</b></summary>

```bash
cd companion && ./build-packages.sh
python3 -m unittest discover -s tests -v
```

</details>
