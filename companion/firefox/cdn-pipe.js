"use strict";

/**
 * Runs in the AnkerGames tab. Fetches CDN with page cookies/TLS, then hands
 * bytes to the background script which POSTs to the localhost relay
 * (avoids Private Network / CORS failures from the page context).
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

  function sendBg(msg) {
    try {
      var ret = api.runtime.sendMessage(msg);
      if (ret && typeof ret.then === "function") {
        return ret;
      }
    } catch (e) {
      /* chrome callback style */
    }
    return new Promise(function (resolve, reject) {
      try {
        api.runtime.sendMessage(msg, function (resp) {
          var err = api.runtime.lastError;
          if (err) {
            reject(new Error(err.message || String(err)));
            return;
          }
          resolve(resp);
        });
      } catch (e2) {
        reject(e2);
      }
    });
  }

  function relayStart(relayBase, headers) {
    return sendBg({
      type: "jdt-relay-start",
      relayBase: relayBase,
      headers: headers || {}
    }).then(function (r) {
      if (!r || !r.ok) {
        throw new Error((r && r.error) || "relay start failed");
      }
    });
  }

  function relayChunk(relayBase, bytes) {
    /* Structured clone ArrayBuffer to background — avoid SharedArrayBuffer issues. */
    var copy = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
    return sendBg({
      type: "jdt-relay-chunk",
      relayBase: relayBase,
      chunk: copy
    }).then(function (r) {
      if (!r || !r.ok) {
        throw new Error((r && r.error) || "relay chunk failed");
      }
    });
  }

  function relayEnd(relayBase) {
    return sendBg({ type: "jdt-relay-end", relayBase: relayBase }).catch(function () {});
  }

  function pipe(cdnUrl, relayBase) {
    setOverlayStatus("JD is downloading — keep this tab open until finished…");
    console.log("[JD Turnstile] tab CDN fetch", cdnUrl.slice(0, 70));
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
      return relayStart(relayBase, {
        "X-Orig-Content-Length": cl,
        "X-Orig-Content-Type": ct
      }).then(function () {
        if (!cdnResp.body || typeof cdnResp.body.getReader !== "function") {
          return cdnResp.arrayBuffer().then(function (buf) {
            return relayChunk(relayBase, new Uint8Array(buf)).then(function () {
              return relayEnd(relayBase);
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
              return relayEnd(relayBase);
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
                setOverlayStatus(
                  "Streaming to JD… " + Math.floor(bytes / 1048576) + " MiB — keep tab open"
                );
              }
            }
            return relayChunk(relayBase, result.value).then(next);
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
        setOverlayStatus("Pipe failed — retrying via background…");
        api.runtime
          .sendMessage({
            type: "jdt-pipe-done",
            ok: false,
            error: String(err && err.message ? err.message : err),
            cdnUrl: msg.cdnUrl,
            relayBase: msg.relayBase
          })
          .catch(function () {});
      });
    return Promise.resolve({ ok: true, started: true });
  });
})();
