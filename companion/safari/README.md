# Safari companion (macOS only)

Safari does **not** load Chrome/Firefox extension packages directly. Apple requires a **Safari Web Extension** wrapped in a macOS app (or App Store distribution), signed with an **Apple Developer** account.

This repository ships the Chromium sources as the conversion input. There is **no prebuilt `.safari` / `.appex` on Linux CI**.

## Convert on a Mac

1. Install Xcode (current) and sign in with your Apple ID / Developer Program.
2. Clone this repo and open Terminal:

```bash
cd companion
xcrun safari-web-extension-converter chromium \
  --project-location safari/generated \
  --app-name "JD Turnstile Companion" \
  --bundle-identifier "io.github.benjarogit.jd-turnstile-companion" \
  --swift \
  --force
```

3. Open the generated Xcode project → select your Team → Build & Run.
4. In Safari: **Settings → Advanced → Show features for web developers**, then **Developer → Allow unsigned extensions** (for local debug), enable **JD Turnstile Companion**.
5. For distribution to other Macs: Archive → Notarize (Developer ID) or submit via Mac App Store.

## Updates

Safari Web Extensions do **not** poll GitHub `updates.xml`. Updates go through:

- Mac App Store, or  
- a new notarized build the user installs, or  
- the in-extension GitHub badge check (same as Chromium/Firefox) pointing at Releases.

## Limits vs Chromium

- MV3 APIs differ slightly; re-test Turnstile + CDN pipe after conversion.
- `declarativeNetRequest` / host permissions must be reviewed in the Safari extension settings.
- Prefer the Chromium/Vivaldi companion on non-Mac systems.

See the root [README](../../README.md) for architecture and install of the supported browsers.
