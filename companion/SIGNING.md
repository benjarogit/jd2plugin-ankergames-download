# Signing the Firefox companion (AMO)

Release Firefox only installs **Mozilla-signed** XPIs. Chromium/Vivaldi use the `.crx` + policy installer and do not need AMO.

## One-time: AMO API credentials

1. Create / log into https://addons.mozilla.org  
2. https://addons.mozilla.org/developers/addon/api/key/ → generate JWT  
3. Export:

```bash
export AMO_JWT_ISSUER="user:xxxxxxxx:xxx"
export AMO_JWT_SECRET="your-secret"
```

## Sign (unlisted — self-distribution on GitHub Releases)

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

Replace `dist/jd-turnstile-companion-firefox-*.xpi` with the signed file from web-ext, then:

```bash
./install-firefox.sh
# or attach the signed XPI to a GitHub Release
```

Listed (AMO public page) uses `--channel listed` after filling the AMO listing.

## Without signing

- **Firefox Developer Edition / Nightly**: `about:config` → `xpinstall.signatures.required` = `false`, then install the unsigned XPI via *Install Add-on From File*.  
- **Chromium / Vivaldi**: use `./install-chromium.sh` (no AMO needed).
