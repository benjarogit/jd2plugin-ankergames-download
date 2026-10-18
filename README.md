# AnkerGames for JDownloader 2

[English](#install) · [Deutsch](README.de.md)

Downloads games from [ankergames.net](https://ankergames.net) in **JDownloader** even though Cloudflare blocks JD’s Java client.

**In short:** You solve the captcha in your browser. A small browser add-on streams the file to JD. JD saves it and shows progress.

---

## Install

```bash
git clone https://github.com/benjarogit/jd2plugin-ankergames-download.git
cd jd2plugin-ankergames-download
chmod +x install.sh
./install.sh
```

### What the script does

1. Install the **JDownloader plugin** → confirm with `Y` / Enter  
2. Type your **browser** name: `vivaldi`, `chrome`, `brave`, `edge`, or `firefox`  
   *(don’t type a number — only the name)*

### Finish the browser add-on

The script prepares the files and opens the right page. **You still do a few clicks:**

**Vivaldi / Chrome / Brave / Edge**

1. Turn on Developer mode  
2. Click “Load unpacked”  
3. Select the folder the script shows (also copied to the clipboard)

**Firefox**

1. Prefer **Firefox Developer Edition** or **Nightly**  
2. `about:config` → `xpinstall.signatures.required` → **false**  
3. `about:addons` → gear → Install Add-on From File → the `.xpi` from the script

More detail: [companion/INSTALL-BROWSER.md](companion/INSTALL-BROWSER.md)

---

## Use it

1. In JDownloader add a link, e.g. `https://ankergames.net/game/…`  
2. Solve Turnstile in the browser  
3. **Keep the AnkerGames tab open** until JD finishes  

Use the same browser for captchas and the add-on. MyJDownloader is **not** required.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Add-on not visible | Run `./install.sh` again (skip plugin with `n`); Developer mode + Load unpacked |
| Firefox “could not be verified” | Developer Edition + `xpinstall.signatures.required = false` |
| JD stuck at 0 bytes | Keep AnkerGames tab open; companion v1.4.2+ |
| Browser downloads the ZIP itself | Update companion; don’t open the CDN link manually |

---

## How it works (short)

Cloudflare blocks JDownloader (Java). The **browser add-on** fetches the file and posts it to `127.0.0.1` — JD only downloads locally.

---

Not affiliated with AppWork / JDownloader / AnkerGames.
