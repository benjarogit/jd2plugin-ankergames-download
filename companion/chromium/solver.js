"use strict";

(function () {
  var api = typeof browser !== "undefined" ? browser : chrome;
  if (window.__jdtTurnstileSolving) {
    return;
  }
  window.__jdtTurnstileSolving = true;

  function setStatus(text) {
    var el = document.getElementById("jdt-turnstile-status");
    if (el) {
      el.textContent = text;
    }
  }

  function ensureOverlay(job) {
    if (document.getElementById("jdt-turnstile-overlay")) {
      return;
    }
    var overlay = document.createElement("div");
    overlay.id = "jdt-turnstile-overlay";
    overlay.style.cssText =
      "position:fixed;inset:0;z-index:2147483646;margin:0;" +
      "font-family:system-ui,sans-serif;background:rgba(27,58,65,.92);color:#e8f1f2;" +
      "display:flex;align-items:center;justify-content:center;";
    overlay.innerHTML =
      "<div style='background:#24474f;border-radius:12px;padding:28px 32px;max-width:480px;width:90%;" +
      "text-align:center;box-shadow:0 8px 32px rgba(0,0,0,.35)'>" +
      "<h1 style='margin:0 0 8px;color:#eebb1b;font-size:1.15rem'>Cloudflare Turnstile</h1>" +
      "<div style='font-weight:700;margin-bottom:14px;word-break:break-all'>" +
      (job.siteDomain || location.hostname) +
      "</div>" +
      "<p style='opacity:.9;margin:0 0 16px'>Minting a fresh download ticket, then solve the check.</p>" +
      "<div id='jdt-turnstile-host' style='display:flex;justify-content:center;min-height:70px'></div>" +
      "<p id='jdt-turnstile-status' style='margin:14px 0 0;font-size:.85rem;opacity:.8'>Preparing…</p>" +
      "</div>";
    document.documentElement.appendChild(overlay);
  }

  function isExpiredPage() {
    var body = (document.body && document.body.innerText) || "";
    return /Invalid or expired download link|download link has expired|Download nicht verfügbar/i.test(
      body
    );
  }

  function isTreasurePath() {
    return /\/download\//i.test(location.pathname);
  }

  function isGamePath() {
    return /\/game\//i.test(location.pathname);
  }

  function isCloudflareInterstitial() {
    var t = (document.title || "").toLowerCase();
    return (
      t.indexOf("just a moment") !== -1 ||
      !!document.getElementById("challenge-error-text") ||
      !!document.querySelector("#challenge-stage, .cf-browser-verification")
    );
  }

  function pageWin() {
    return window.wrappedJSObject || window;
  }

  function extractFileTokenFromPage() {
    var html = document.documentElement ? document.documentElement.innerHTML : "";
    var m = html.match(/download-file(?:\\\/|\/)([a-f0-9]{16,})/i);
    return m ? m[1] : "";
  }

  function getCookie(name) {
    var m = document.cookie.match(new RegExp("(?:^|; )" + name.replace(/([.$?*|{}()[\]\\/+^])/g, "\\$1") + "=([^;]*)"));
    return m ? decodeURIComponent(m[1]) : "";
  }

  function fetchCsrfToken() {
    return fetch(location.origin + "/csrf-token", {
      credentials: "include",
      headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" }
    }).then(function (r) {
      return r.json().then(function (j) {
        return (j && j.token) || getCookie("XSRF-TOKEN") || "";
      });
    });
  }

  function mintDownloadUrl(downloadId) {
    return fetchCsrfToken().then(function (csrf) {
      var xsrf = getCookie("XSRF-TOKEN") || csrf;
      return fetch(location.origin + "/generate-download-url/" + downloadId, {
        method: "POST",
        credentials: "include",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-Requested-With": "XMLHttpRequest",
          "X-CSRF-TOKEN": csrf,
          "X-XSRF-TOKEN": xsrf,
          Origin: location.origin,
          Referer: location.href
        },
        body: "{}"
      }).then(function (r) {
        return r.json().then(function (j) {
          if (j && j.success && j.download_url) {
            return String(j.download_url);
          }
          var err = (j && (j.error || j.message)) || "generate-download-url failed";
          throw new Error(String(err));
        });
      });
    });
  }

  function readNativeToken() {
    try {
      var pw = pageWin();
      if (pw.agTurnstile && typeof pw.agTurnstile.token === "function") {
        var t = pw.agTurnstile.token();
        if (t) {
          return String(t);
        }
      }
    } catch (e) {
      /* ignore */
    }
    var input =
      document.querySelector("[name='cf-turnstile-response']") ||
      document.querySelector("textarea[name='cf-turnstile-response']");
    return input && input.value ? String(input.value).trim() : "";
  }

  function waitForNativeToken(timeoutMs) {
    return new Promise(function (resolve) {
      var started = Date.now();
      try {
        var pw = pageWin();
        if (pw.agTurnstile && typeof pw.agTurnstile.tokenAsync === "function") {
          Promise.resolve(pw.agTurnstile.tokenAsync(timeoutMs))
            .then(function (t) {
              resolve(t ? String(t) : "");
            })
            .catch(function () {
              resolve("");
            });
          return;
        }
      } catch (e) {
        /* poll */
      }
      var handle = setInterval(function () {
        var t = readNativeToken();
        if (t || Date.now() - started > timeoutMs) {
          clearInterval(handle);
          resolve(t || "");
        }
      }, 400);
    });
  }

  function resolveDirectLink(fileToken, cfToken) {
    var api =
      location.origin +
      "/download-file/" +
      fileToken +
      "/link?cf-turnstile-response=" +
      encodeURIComponent(cfToken);
    return fetch(api, {
      credentials: "include",
      headers: {
        Accept: "application/json",
        "X-Requested-With": "XMLHttpRequest",
        Referer: location.href
      }
    }).then(function (res) {
      return res.text().then(function (body) {
        if (body && body.charAt(0) === "{") {
          var json = JSON.parse(body);
          if (json && json.link) {
            return String(json.link);
          }
          if (json && json.error) {
            throw new Error(String(json.error));
          }
        }
        throw new Error("Unexpected /link response (" + res.status + ")");
      });
    });
  }

  function finish(job, payload) {
    if (window.__jdtFinishSent) {
      return;
    }
    window.__jdtFinishSent = true;
    setStatus("JD is downloading — keep this tab open until finished…");
    var directUrl = payload.directUrl || "";
    api.runtime.sendMessage({
      type: "jdt-turnstile-solved",
      token: payload.token || "",
      directUrl: JSON.stringify({
        url: directUrl,
        userAgent: navigator.userAgent || "",
        via: "relay"
      }),
      callbackUrl: job.callbackUrl
    });
  }

  function onTurnstileToken(job, cfToken) {
    var fileToken = job.fileToken || extractFileTokenFromPage();
    if (!fileToken) {
      setStatus("No file token on treasure page.");
      return;
    }
    setStatus("Resolving CDN link…");
    resolveDirectLink(fileToken, cfToken)
      .then(function (directUrl) {
        if (!directUrl) {
          throw new Error("Empty link");
        }
        finish(job, { token: cfToken, directUrl: directUrl });
      })
      .catch(function (err) {
        console.error("[JD Turnstile] /link failed", err);
        setStatus("Link failed: " + (err && err.message ? err.message : err));
      });
  }

  function renderFallbackWidget(job) {
    ensureOverlay(job);
    setStatus("Complete the check below.");
    var host = document.getElementById("jdt-turnstile-host");
    if (!host) {
      return;
    }

    function tryRender() {
      var pw = pageWin();
      var ts = pw.turnstile;
      if (!ts || typeof ts.render !== "function") {
        return false;
      }
      try {
        var cb = function (token) {
          onTurnstileToken(job, String(token));
        };
        if (typeof exportFunction === "function") {
          cb = exportFunction(cb, pw);
        }
        var opts = { sitekey: job.siteKey, callback: cb, theme: "dark" };
        if (typeof cloneInto === "function") {
          opts = cloneInto(opts, pw, { cloneFunctions: true });
        }
        ts.render(host, opts);
        return true;
      } catch (e) {
        console.error("[JD Turnstile] render failed", e);
        return false;
      }
    }

    if (tryRender()) {
      return;
    }
    var s = document.createElement("script");
    s.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
    s.async = true;
    s.onload = function () {
      var n = 0;
      var t = setInterval(function () {
        n += 1;
        if (tryRender() || n > 50) {
          clearInterval(t);
        }
      }, 100);
    };
    s.onerror = function () {
      setStatus("Turnstile API blocked — allow challenges.cloudflare.com");
    };
    (document.head || document.documentElement).appendChild(s);
  }

  function blockPageCdnNavigation() {
    /* AnkerGames navigates to dlproxy after Turnstile — that would leave this tab and abort the CDN pipe. */
    function isDlproxy(url) {
      return !!(url && /dlproxy\.uk/i.test(String(url)));
    }
    document.addEventListener(
      "click",
      function (e) {
        var a = e.target && e.target.closest ? e.target.closest("a[href]") : null;
        if (a && isDlproxy(a.href || "")) {
          e.preventDefault();
          e.stopPropagation();
          e.stopImmediatePropagation();
        }
      },
      true
    );
    document.addEventListener(
      "submit",
      function (e) {
        try {
          var action = e.target && e.target.action;
          if (isDlproxy(action)) {
            e.preventDefault();
            e.stopPropagation();
          }
        } catch (e2) {
          /* ignore */
        }
      },
      true
    );
    try {
      var pw = pageWin();
      var realOpen = pw.open.bind(pw);
      pw.open = function (url) {
        if (isDlproxy(url)) {
          console.log("[JD Turnstile] blocked window.open → CDN");
          return null;
        }
        return realOpen.apply(pw, arguments);
      };
      function blockAssign(url) {
        if (isDlproxy(url)) {
          console.log("[JD Turnstile] blocked location → CDN (keep tab for pipe)");
          return true;
        }
        return false;
      }
      var loc = pw.location;
      try {
        var desc =
          Object.getOwnPropertyDescriptor(pw.Location.prototype, "href") ||
          Object.getOwnPropertyDescriptor(loc, "href");
        if (desc && desc.set) {
          Object.defineProperty(loc, "href", {
            configurable: true,
            enumerable: true,
            get: function () {
              return desc.get.call(loc);
            },
            set: function (v) {
              if (blockAssign(v)) return;
              return desc.set.call(loc, v);
            }
          });
        }
      } catch (e1) {
        /* ignore */
      }
      try {
        Object.defineProperty(pw, "location", {
          configurable: true,
          get: function () {
            return loc;
          },
          set: function (v) {
            if (blockAssign(v)) return;
            loc.href = v;
          }
        });
      } catch (eLoc) {
        /* ignore — page may forbid redefining location */
      }
      var assign = loc.assign.bind(loc);
      var replace = loc.replace.bind(loc);
      loc.assign = function (u) {
        if (blockAssign(u)) return;
        return assign(u);
      };
      loc.replace = function (u) {
        if (blockAssign(u)) return;
        return replace(u);
      };
    } catch (e) {
      /* ignore */
    }
  }

  function isReadyPage() {
    var body = (document.body && document.body.innerText) || "";
    return /Download Ready|\bReady!\b/i.test(body);
  }

  function startTreasurePhase(job) {
    ensureOverlay(job);
    blockPageCdnNavigation();
    if (isExpiredPage()) {
      setStatus("Fresh ticket expired instantly — retry from JDownloader.");
      return;
    }
    job.fileToken = extractFileTokenFromPage() || job.fileToken;
    setStatus(isReadyPage() ? "Page ready — reading Turnstile token…" : "Looking for site Turnstile…");
    var existing = readNativeToken();
    if (existing) {
      onTurnstileToken(job, existing);
      return;
    }
    /*
     * Ready pages already passed Turnstile; token may be gone. Poll briefly, then
     * remint from the game page (fresh ticket) instead of sitting forever.
     */
    var waitMs = isReadyPage() ? 8000 : 45000;
    waitForNativeToken(waitMs).then(function (nativeTok) {
      if (nativeTok) {
        onTurnstileToken(job, nativeTok);
        return;
      }
      if (isReadyPage() && job.downloadId) {
        setStatus("Ready but no token — minting a fresh ticket…");
        startGamePhase(job);
        return;
      }
      renderFallbackWidget(job);
    });
  }

  function startGamePhase(job) {
    ensureOverlay(job);
    if (!job.downloadId) {
      setStatus("Missing downloadId — re-add the game page in JDownloader.");
      return;
    }
    setStatus("Minting fresh download ticket…");
    mintDownloadUrl(job.downloadId)
      .then(function (downloadUrl) {
        setStatus("Opening treasure page…");
        api.runtime.sendMessage({
          type: "jdt-navigate-treasure",
          url: downloadUrl + (downloadUrl.indexOf("?") >= 0 ? "&" : "?") + "jdt=1",
          fileToken: ""
        });
      })
      .catch(function (err) {
        console.error("[JD Turnstile] mint failed", err);
        setStatus("Could not mint ticket: " + (err && err.message ? err.message : err));
      });
  }

  function waitReady(maxMs) {
    return new Promise(function (resolve) {
      var started = Date.now();
      var handle = setInterval(function () {
        if (!isCloudflareInterstitial()) {
          clearInterval(handle);
          resolve(true);
          return;
        }
        if (Date.now() - started > maxMs) {
          clearInterval(handle);
          resolve(false);
        }
      }, 400);
    });
  }

  function start(job) {
    if (!job || !job.siteKey) {
      return;
    }
    ensureOverlay(job);
    setStatus("Waiting for page…");
    waitReady(90000).then(function () {
      if (isTreasurePath()) {
        startTreasurePhase(job);
        return;
      }
      if (isGamePath() || job.downloadId) {
        startGamePhase(job);
        return;
      }
      setStatus("Unexpected page — expected game or download URL.");
    });
  }

  api.runtime.onMessage.addListener(function (msg) {
    if (msg && msg.type === "jdt-status" && msg.text) {
      ensureOverlay(msg.job || { siteDomain: location.hostname });
      setStatus(msg.text);
      return;
    }
    if (msg && msg.type === "jdt-turnstile-init" && msg.job) {
      if (msg.job.solved || window.__jdtFinishSent) {
        setStatus("JD is downloading — keep this tab open until finished…");
        return;
      }
      start(msg.job);
    }
  });
})();
