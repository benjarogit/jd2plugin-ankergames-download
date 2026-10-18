# Optional: Mozilla AMO signing (Firefox Release only)

**Normal users can skip this.** Prefer unsigned install via [INSTALL-BROWSER.md](INSTALL-BROWSER.md) (Developer Edition / Nightly, or temporary load).

AMO signing is only useful if you insist on **Release Firefox** with permanent install + `updates/firefox.json` auto-update.

```bash
export AMO_JWT_ISSUER="user:xxxxxxxx:xxx"
export AMO_JWT_SECRET="your-secret"
cd companion
./install-firefox.sh   # signs if credentials are set, then installs
```

Keys: https://addons.mozilla.org/developers/addon/api/key/
