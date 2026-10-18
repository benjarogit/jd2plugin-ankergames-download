"use strict";

/**
 * Persistent-ish MV3 context (closer to Firefox's background page) for CDN→relay.
 * Service-worker fetch is flaky in some Chromium builds; this document stays alive
 * for the stream.
 */
(function () {
  var api = typeof browser !== "undefined" ? browser : chrome;

  function pushUrl(relayBase) {
    return String(relayBase).replace(/\/$/, "") + "/push";
  }

  function sleep(ms) {
    return new Promise(function (resolve) {
      setTimeout(resolve, ms);
    });
  }

  function signalStart(push, headers) {
    var hdrs = Object.assign({ "Content-Type": "application/json" }, headers || {});
    function once() {
      return fetch(push + "?phase=start", {
        method: "POST",
        headers: hdrs,
        body: "{}"
      }).then(function (r) {
        if (!r.ok) {
          throw new Error("Relay start HTTP " + r.status);
        }
      });
    }
    function attempt(left) {
      return once().catch(function (err) {
        var msg = String(err && err.message ? err.message : err);
        if (left <= 0) {
          throw new Error("Relay: " + msg);
        }
        return sleep(200).then(function () {
          return attempt(left - 1);
        });
      });
    }
    return attempt(25);
  }

  function signalEnd(push) {
    return fetch(push + "?phase=end", { method: "POST", body: "" }).catch(function () {});
  }

  function pushChunk(push, bytes) {
    var copy = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
    return fetch(push + "?phase=chunk", {
      method: "POST",
      headers: { "Content-Type": "application/octet-stream" },
      body: copy
    }).then(function (r) {
      if (!r.ok) {
        throw new Error("Relay chunk HTTP " + r.status);
      }
    });
  }

  function fetchCdn(cdnUrl) {
    /* Forbidden headers (Referer) must not be set — they cause Failed to fetch. */
    return fetch(cdnUrl, {
      credentials: "include",
      redirect: "follow",
      cache: "no-store"
    })
      .catch(function () {
        return fetch(cdnUrl, {
          credentials: "omit",
          redirect: "follow",
          cache: "no-store"
        });
      })
      .catch(function (err) {
        throw new Error("CDN: " + (err && err.message ? err.message : err));
      });
  }

  function pipe(cdnUrl, relayBase) {
    var push = pushUrl(relayBase);
    console.log("[JD Turnstile] offscreen CDN pipe", cdnUrl.slice(0, 70));
    return fetchCdn(cdnUrl).then(function (cdnResp) {
      if (!cdnResp.ok) {
        throw new Error("CDN HTTP " + cdnResp.status);
      }
      var ct = cdnResp.headers.get("Content-Type") || "application/octet-stream";
      if (/text\/html/i.test(ct)) {
        throw new Error("CDN returned HTML (WAF)");
      }
      var cl = cdnResp.headers.get("Content-Length") || "";
      return signalStart(push, {
        "X-Orig-Content-Length": cl,
        "X-Orig-Content-Type": ct
      }).then(function () {
        if (!cdnResp.body || typeof cdnResp.body.getReader !== "function") {
          return cdnResp.arrayBuffer().then(function (buf) {
            return pushChunk(push, new Uint8Array(buf)).then(function () {
              return signalEnd(push);
            });
          });
        }
        var reader = cdnResp.body.getReader();
        function next() {
          return reader.read().then(function (result) {
            if (result.done) {
              return signalEnd(push);
            }
            return pushChunk(push, result.value).then(next);
          });
        }
        return next();
      });
    });
  }

  api.runtime.onMessage.addListener(function (msg, _sender, sendResponse) {
    if (msg && msg.type === "jdt-offscreen-ping") {
      sendResponse({ ok: true });
      return;
    }
    if (!msg || msg.type !== "jdt-offscreen-pipe") {
      return;
    }
    pipe(msg.cdnUrl, msg.relayBase)
      .then(function () {
        sendResponse({ ok: true });
      })
      .catch(function (err) {
        sendResponse({
          ok: false,
          error: String(err && err.message ? err.message : err)
        });
      });
    return true;
  });
})();
