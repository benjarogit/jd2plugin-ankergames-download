# Signing & updates

## Chromium / Chrome / Vivaldi / Brave / Edge

No store account required for self-distribution.

1. Build `.crx` with the stable key in `signing/chromium.pem` (keeps id `haopihkkdnnohoknooliddghpanmmedj`).
2. Attach the CRX to a GitHub Release.
3. Point `updates/chromium.xml` at that asset (done automatically by `.github/workflows/companion-release.yml`).

Browsers poll:

`https://raw.githubusercontent.com/benjarogit/jd2plugin-ankergames-download/main/updates/chromium.xml`

The extension also checks the GitHub Releases API every few hours and shows a toolbar badge **↑** if a newer version exists.

## Firefox (AMO)

Release Firefox only installs / auto-updates **Mozilla-signed** XPIs.

### One-time: AMO API credentials

1. https://addons.mozilla.org → developer hub  
2. https://addons.mozilla.org/developers/addon/api/key/ → JWT  
3. Export:

```bash
export AMO_JWT_ISSUER="user:xxxxxxxx:xxx"
export AMO_JWT_SECRET="your-secret"
```

### Sign (unlisted — GitHub self-distribution)

```bash
cd companion
./build-packages.sh
npx --yes web-ext sign \
  --source-dir firefox \
  --channel unlisted \
  --api-key "$AMO_JWT_ISSUER" \
  --api-secret "$AMO_JWT_SECRET" \
  --artifacts-dir dist
```

Replace the unsigned XPI in the Release with the signed file. Firefox then polls:

`https://raw.githubusercontent.com/benjarogit/jd2plugin-ankergames-download/main/updates/firefox.json`

### Without signing

- **Firefox Developer Edition / Nightly**: `about:config` → `xpinstall.signatures.required` = `false`, then install the XPI.  
- Native `update_url` will not apply on Release Firefox for unsigned builds; the **↑** badge still opens the GitHub Release page.

## Safari

No GitHub CRX/XPI feed. Distribute via notarized macOS app / App Store. See `safari/README.md`.
