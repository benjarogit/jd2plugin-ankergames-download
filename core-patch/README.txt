Core.jar patch files
====================

turnstile.html
  Captcha page with meta tags: sitekey, gameUrl, downloadId, relayUrl, fileToken, …

CloudflareTurnstileChallenge.class
  Fills those placeholders from the plugin challenge (getRelayUrl / getGameUrl / …).

Manual install only: open Core.jar with 7-Zip / Archive Manager, replace the two
files under org/jdownloader/captcha/v2/challenge/cloudflareturnstile/, backup first.
Do not patch while JDownloader is running.
Full steps: ../README.md or ../README.de.md
