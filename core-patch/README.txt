Core.jar patch files
====================

turnstile.html
  Captcha page with meta tags: sitekey, gameUrl, downloadId, relayUrl, fileToken, …

CloudflareTurnstileChallenge.class
  Fills those placeholders from the plugin challenge (getRelayUrl / getGameUrl / …).

The plugin installer (plugin/install.sh or install.ps1) copies these into Core.jar
and keeps a timestamped backup. Do not run jar updates while JDownloader is running.
