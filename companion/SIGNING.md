# Signing & automatic install

## Chromium / Chrome / Vivaldi / Brave / Edge (Linux)

**No store account needed.** `./install-chromium.sh` (or root `./install.sh`) writes a managed policy that **force-installs** the local `.crx` via `file://` updates.xml. The browser restarts; the add-on appears under `…://extensions` without drag-and-drop.

Windows/macOS: Chrome only allows force-install of non-store extensions on managed/enrolled devices. On those OSes, drag the `.crx` onto `chrome://extensions` (Developer mode) or use the Web Store if published later.

## Firefox (Release)

Mozilla **requires a signature**. Unsigned XPIs will not auto-install on Release Firefox (policy or file dialog).

### One-time AMO API key (free)

1. https://addons.mozilla.org → developer account  
2. https://addons.mozilla.org/developers/addon/api/key/ → JWT  
3. In the shell:

```bash
export AMO_JWT_ISSUER="user:xxxxxxxx:xxx"
export AMO_JWT_SECRET="your-secret"
cd companion
./install-firefox.sh
```

That signs an **unlisted** XPI (self-distribution on GitHub), writes Firefox enterprise policy, and restarts Firefox so the add-on installs automatically.

Attach the signed XPI to the GitHub Release and keep `updates/firefox.json` in sync for auto-updates.

### Without AMO

- Firefox Developer Edition / Nightly: `xpinstall.signatures.required` = `false`, then install the XPI once.  
- Or wait until a signed build is attached to [Releases](https://github.com/benjarogit/jd2plugin-ankergames-download/releases).
