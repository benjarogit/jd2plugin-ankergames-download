"use strict";

/**
 * Runs in the AnkerGames tab. Streams CDN → JD localhost relay with browser TLS.
 * Keep this tab open until status says done — closing aborts the pipe (JD may stall).
 */
(function () {
  var api = typeof browser !== "undefined" ? browser : chrome;
  if (window.__jdtCdnPipeListening) {
    return;
  }
  window.__jdtCdnPipeListening = true;
  var piping = false;

  function setOverlayStatus(text) {
    var el = document.getElementById("jdt-turnstile-status");
    if (el) {
      el.textContent = text;
    }
  }

  function pushUrl(relayBase) {
    return String(relayBase).replace(/\/$/, "") + "/push";
  }

  function signalStart(push, headers) {
    var h = Object.assign({ "Content-Type": "application/json" }, headers || {});
    return fetch(push + "?phase=start", { method: "POST", headers: h, body: "{}" }).then(function (r) {
      if (!r.ok) {
        throw new Error("Relay start HTTP " + r.status);
      }
    });
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

  function pipe(cdnUrl, relayBase) {
    var push = pushUrl(relayBase);
    setOverlayStatus("JD is downloading — keep this tab open until finished…");
    console.log("[JD Turnstile] tab CDN pipe", cdnUrl.slice(0, 70));
    return fetch(cdnUrl, {
      credentials: "include",
      redirect: "follow",
      cache: "no-store",
      headers: {
        Accept: "application/octet-stream,*/*;q=0.8",
        Referer: "https://ankergames.net/"
      }
    }).then(function (cdnResp) {
      if (!cdnResp.ok) {
        throw new Error("CDN HTTP " + cdnResp.status);
      }
      var ct = cdnResp.headers.get("Content-Type") || "application/octet-stream";
      if (/text\/html/i.test(ct)) {
        throw new Error("CDN returned HTML (WAF) from tab fetch");
      }
      var cl = cdnResp.headers.get("Content-Length") || "";
      var total = cl ? parseInt(cl, 10) : 0;
      console.log("[JD Turnstile] tab CDN headers", ct, cl || "(chunked)");
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
        var bytes = 0;
        var lastUi = 0;
        function next() {
          return reader.read().then(function (result) {
            if (result.done) {
              console.log("[JD Turnstile] tab CDN done, bytes≈", bytes);
              setOverlayStatus("Stream finished — you can close this tab.");
              return signalEnd(push);
            }
            bytes += result.value ? result.value.byteLength : 0;
            if (Date.now() - lastUi > 2000) {
              lastUi = Date.now();
              if (total > 0) {
                setOverlayStatus(
                  "Streaming to JD… " +
                    Math.min(100, Math.floor((bytes / total) * 100)) +
                    "% — keep tab open"
                );
              } else {
                setOverlayStatus("Streaming to JD… " + Math.floor(bytes / 1048576) + " MiB — keep tab open");
              }
            }
            return pushChunk(push, result.value).then(next);
          });
        }
        return next();
      });
    });
  }

  api.runtime.onMessage.addListener(function (msg) {
    if (!msg || msg.type !== "jdt-pipe-cdn") {
      return;
    }
    if (piping) {
      return Promise.resolve({ ok: true, already: true });
    }
    if (!msg.cdnUrl || !msg.relayBase) {
      return Promise.resolve({ ok: false, error: "missing urls" });
    }
    piping = true;
    /* Acknowledge immediately so MV3 service worker is not held open for GB-hours. */
    pipe(msg.cdnUrl, msg.relayBase)
      .then(function () {
        piping = false;
        api.runtime.sendMessage({ type: "jdt-pipe-done", ok: true }).catch(function () {});
      })
      .catch(function (err) {
        piping = false;
        console.error("[JD Turnstile] tab CDN pipe failed", err);
        setOverlayStatus("Pipe failed: " + (err && err.message ? err.message : err));
        api.runtime
          .sendMessage({
            type: "jdt-pipe-done",
            ok: false,
            error: String(err && err.message ? err.message : err)
          })
          .catch(function () {});
      });
    return Promise.resolve({ ok: true, started: true });
  });
})();
