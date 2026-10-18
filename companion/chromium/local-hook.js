"use strict";

(function () {
  var api = typeof browser !== "undefined" ? browser : chrome;
  if (!/^\/captcha\/turn\//i.test(location.pathname)) {
    return;
  }
  function g(n) {
    var el = document.getElementsByName(n)[0];
    return el ? el.content : "";
  }
  api.runtime.sendMessage({
    type: "jdt-local-turnstile",
    siteKey: g("sitekey"),
    siteUrl: g("siteUrl"),
    siteDomain: g("siteDomain"),
    fileToken: g("fileToken"),
    gameUrl: g("gameUrl"),
    downloadId: g("downloadId"),
    relayUrl: g("relayUrl"),
    challengeType: g("challengeType") || "CloudflareTurnstileChallenge",
    callbackUrl: location.href
  });
})();
