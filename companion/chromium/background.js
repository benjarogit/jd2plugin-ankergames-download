"use strict";

/* MV3 service worker: load GitHub update badge helper first. */
try {
  importScripts("update-check.js");
} catch (e) {
  console.warn("[JD Turnstile] update-check.js not loaded", e);
}

/**
 * Cross-browser API (Firefox MV2 `browser`, Chromium MV3 `chrome`).
 * CDN download must use the real browser stack so AnkerGames/Cloudflare
 * see a normal browser download — not JDownloader's Java HTTP client.
 */
const api = typeof browser !== "undefined" ? browser : chrome;

/** @type {Record<number, object>} */
const jobsByTab = Object.create(null);
/** @type {Record<number, string>} */
const localHandled = Object.create(null);
/** Latest captcha job — any ankergames tab can attach (manual Ready / Browser open). */
let activeCaptchaJob = null;
/** Prevent double do=solve / second download when tab closes or hook fires twice. */
const solvedGate = Object.create(null);
let pipeSession = null;
/** Last known AnkerGames URL per tab — restore if page navigates to dlproxy. */
const lastAnkerUrlByTab = Object.create(null);

const LOCAL_TURN_RE =
  /^https?:\/\/(127\.0\.0\.1|localhost|\[::1\]):\d+\/captcha\/turn\//i;
const DLPROXY_RE = /dlproxy\.uk/i;
const ANKER_RE = /ankergames\.net/i;

function isLocalTurnUrl(url) {
  return !!(url && LOCAL_TURN_RE.test(url));
}

function sleep(ms) {
  return new Promise(function (resolve) {
    setTimeout(resolve, ms);
  });
}

function readLocalMetas() {
  function g(n) {
    var el = document.getElementsByName(n)[0];
    return el ? el.content : "";
  }
  return {
    siteKey: g("sitekey"),
    siteUrl: g("siteUrl"),
    siteDomain: g("siteDomain"),
    fileToken: g("fileToken"),
    gameUrl: g("gameUrl"),
    downloadId: g("downloadId"),
    relayUrl: g("relayUrl"),
    challengeType: g("challengeType") || "CloudflareTurnstileChallenge",
    callbackUrl: location.href
  };
}

function markLocalReadyInPage() {
  var el = document.getElementById("jdt-companion-status");
  if (!el) {
    el = document.createElement("p");
    el.id = "jdt-companion-status";
    el.style.cssText = "color:#8fdf8f;font-size:.9rem;margin-top:10px;";
    var box = document.querySelector(".box") || document.body;
    box.appendChild(el);
  }
  el.textContent = "Companion connected — opening game page…";
}

function executeInTab(tabId, opts) {
  if (api.scripting && api.scripting.executeScript) {
    var target = { target: { tabId: tabId } };
    if (opts.file) {
      return api.scripting.executeScript(Object.assign({ files: [opts.file] }, target)).then(function () {
        return null;
      });
    }
    return api.scripting.executeScript(Object.assign({ func: opts.func }, target)).then(function (results) {
      return results && results[0] ? results[0].result : null;
    });
  }
  if (opts.file) {
    return api.tabs.executeScript(tabId, { file: opts.file, runAt: "document_idle" });
  }
  return api.tabs
    .executeScript(tabId, {
      code: "(" + opts.func.toString() + ")();"
    })
    .then(function (results) {
      return results && results[0] ? results[0] : null;
    });
}

function metaFromLocalPage(tabId) {
  return executeInTab(tabId, { func: readLocalMetas });
}

function metaFromLocalPageRetry(tabId, attempts) {
  attempts = attempts || 8;
  function step(left) {
    return metaFromLocalPage(tabId).then(function (data) {
      if (data && data.siteKey) {
        return data;
      }
      if (left <= 1) {
        return data;
      }
      return sleep(250).then(function () {
        return step(left - 1);
      });
    });
  }
  return step(attempts);
}

function sanitizeUrl(url, domain) {
  if (url && (url.indexOf("http://") === 0 || url.indexOf("https://") === 0)) {
    return url;
  }
  if (domain) {
    if (domain.indexOf("http://") === 0 || domain.indexOf("https://") === 0) {
      return domain;
    }
    return "https://" + domain;
  }
  return url || "";
}

/**
 * Start on the stable game page. Companion mints /download/ there so the ticket
 * is not already expired when Turnstile is shown.
 */
function solvePageUrl(data) {
  const gameUrl = sanitizeUrl(data.gameUrl, data.siteDomain);
  if (gameUrl && /\/game\//i.test(gameUrl)) {
    const sep = gameUrl.indexOf("?") >= 0 ? "&" : "?";
    return gameUrl.split("#")[0] + sep + "jdt=1";
  }
  const siteUrl = sanitizeUrl(data.siteUrl, data.siteDomain);
  if (siteUrl) {
    const sep = siteUrl.indexOf("?") >= 0 ? "&" : "?";
    return siteUrl.split("#")[0] + sep + "jdt=1";
  }
  const domain = (data.siteDomain || "").replace(/^https?:\/\//i, "").split("/")[0];
  return domain ? "https://" + domain + "/?jdt=1" : "";
}

function markLocalReady(tabId) {
  return executeInTab(tabId, { func: markLocalReadyInPage }).catch(function () {});
}

function startSolveFlow(tabId, data, force) {
  if (!data.siteKey || !data.callbackUrl) {
    console.error("[JD Turnstile] missing params", data);
    return;
  }
  if (!force && wasSolved(gateKey(data, data.callbackUrl, ""))) {
    console.log("[JD Turnstile] skip startSolveFlow — already solved this download");
    return;
  }
  if (!force && localHandled[tabId] === data.callbackUrl) {
    return;
  }
  localHandled[tabId] = data.callbackUrl;

  const target = solvePageUrl(data);
  if (!target) {
    console.error("[JD Turnstile] no target URL", data);
    return;
  }
  /*
   * CRITICAL: Keep the JD captcha tab on 127.0.0.1. Navigating it away unloads
   * browserCaptcha.js and BrowserSolver closes with Response=null (seen in logs).
   * Do all AnkerGames work in a separate tab.
   */
  const baseJob = {
    callbackUrl: data.callbackUrl,
    siteKey: data.siteKey,
    siteUrl: data.siteUrl || "",
    siteDomain: data.siteDomain || "",
    fileToken: data.fileToken || "",
    gameUrl: data.gameUrl || "",
    downloadId: data.downloadId || "",
    relayUrl: data.relayUrl || "",
    phase: "game",
    captchaTabId: tabId
  };
  jobsByTab[tabId] = Object.assign({}, baseJob, { phase: "captcha-keepalive" });
  activeCaptchaJob = Object.assign({}, baseJob);
  console.log(
    "[JD Turnstile] open work tab",
    target,
    "downloadId=",
    data.downloadId || "(none)",
    "relay=",
    data.relayUrl || "(none)"
  );
  markLocalReady(tabId);

  /* Prefer an already-open ankergames Ready/game tab instead of a blank new one. */
  api.tabs
    .query({ url: ["*://ankergames.net/*", "*://*.ankergames.net/*"] })
    .then(function (existing) {
      const ready = (existing || []).find(function (t) {
        return t.id != null && t.url && /\/download\//i.test(t.url);
      });
      const game = (existing || []).find(function (t) {
        return t.id != null && t.url && /\/game\//i.test(t.url);
      });
      const reuse = ready || game;
      if (reuse) {
        console.log("[JD Turnstile] reuse open tab", reuse.id, reuse.url.slice(0, 80));
        jobsByTab[reuse.id] = Object.assign({}, baseJob, {
          phase: ready ? "treasure" : "game",
          workTabId: reuse.id
        });
        api.tabs.update(reuse.id, { active: true }).catch(function () {});
        return injectSolver(reuse.id, jobsByTab[reuse.id]);
      }
      return api.tabs.create({ url: target, active: true }).then(function (tab) {
        if (!tab || tab.id == null) {
          return;
        }
        jobsByTab[tab.id] = Object.assign({}, baseJob, { phase: "game", workTabId: tab.id });
      });
    })
    .catch(console.error);
}

function injectSolver(tabId, job) {
  return executeInTab(tabId, { file: "solver.js" }).then(function () {
    return api.tabs.sendMessage(tabId, {
      type: "jdt-turnstile-init",
      job: job
    });
  });
}

function handleLocalCaptchaTab(tabId, url, force) {
  if (!isLocalTurnUrl(url)) {
    return Promise.resolve();
  }
  if (!force && localHandled[tabId] === url) {
    return Promise.resolve();
  }
  return metaFromLocalPageRetry(tabId)
    .then(function (data) {
      if (!data) {
        console.warn("[JD Turnstile] no meta on local page", url);
        return;
      }
      data.callbackUrl = data.callbackUrl || url;
      startSolveFlow(tabId, data, !!force);
    })
    .catch(console.error);
}

function scanLocalCaptchaTabs() {
  return api.tabs.query({}).then(function (tabs) {
    tabs.forEach(function (tab) {
      if (tab.id == null || !isLocalTurnUrl(tab.url)) {
        return;
      }
      if (localHandled[tab.id] === tab.url) {
        return;
      }
      handleLocalCaptchaTab(tab.id, tab.url, false);
    });
  });
}

function parseSolvePayload(raw) {
  if (!raw) {
    return { url: "", userAgent: "", via: "" };
  }
  if (typeof raw === "string" && raw.charAt(0) === "{") {
    try {
      const obj = JSON.parse(raw);
      return {
        url: obj.url || "",
        userAgent: obj.userAgent || "",
        via: obj.via || ""
      };
    } catch (e) {
      /* fall through */
    }
  }
  if (typeof raw === "string" && /^https?:\/\//i.test(raw)) {
    return { url: raw, userAgent: "", via: "" };
  }
  return { url: "", userAgent: "", via: "", token: String(raw) };
}

function reportSolvedToJd(callbackUrl, payload) {
  const body = JSON.stringify(payload);
  const url =
    callbackUrl +
    (callbackUrl.indexOf("?") >= 0 ? "&" : "?") +
    "do=solve&response=" +
    encodeURIComponent(body);
  return fetch(url);
}

function relayPushUrl(relayBase) {
  return String(relayBase).replace(/\/$/, "") + "/push";
}

function signalRelayStart(pushUrl, extraHeaders) {
  const startHeaders = Object.assign({ "Content-Type": "application/json" }, extraHeaders || {});
  function once() {
    return fetch(pushUrl + "?phase=start", {
      method: "POST",
      headers: startHeaders,
      body: "{}"
    }).then(function (s) {
      if (!s.ok) {
        throw new Error("Relay start HTTP " + s.status);
      }
      console.log("[JD Turnstile] relay phase=start OK");
    });
  }
  /* JD may still be opening the relay — retry connection refused / Failed to fetch. */
  function attempt(left) {
    return once().catch(function (err) {
      const msg = String(err && err.message ? err.message : err);
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

function signalRelayEnd(pushUrl) {
  return fetch(pushUrl + "?phase=end", { method: "POST", body: "" }).catch(function (e) {
    console.warn("[JD Turnstile] relay phase=end", e);
  });
}

function pushRelayChunk(pushUrl, bytes) {
  /* Fresh ArrayBuffer — Firefox rejects some TypedArray views as fetch body. */
  const copy = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
  return fetch(pushUrl + "?phase=chunk", {
    method: "POST",
    headers: { "Content-Type": "application/octet-stream" },
    body: copy
  }).then(function (c) {
    if (!c.ok) {
      throw new Error("Relay chunk HTTP " + c.status);
    }
  });
}

/**
 * Background fetch fallback (tabId -1). Same browser TLS stack as Firefox/Chrome —
 * NOT Java — so JA4 matches a real browser. Still weaker than tab-context fetch
 * because CF inter-request signals prefer the Turnstile tab.
 */
function fetchCdnBytes(cdnUrl) {
  /* Never set Referer — forbidden fetch header → Failed to fetch. */
  return fetch(cdnUrl, { credentials: "include", redirect: "follow", cache: "no-store" }).catch(function (err) {
    console.warn("[JD Turnstile] CDN fetch credentials=include failed, retry omit", err);
    return fetch(cdnUrl, { credentials: "omit", redirect: "follow", cache: "no-store" });
  }).then(function (cdnResp) {
    if (!cdnResp.ok) {
      throw new Error("CDN HTTP " + cdnResp.status);
    }
    const contentType = cdnResp.headers.get("Content-Type") || "application/octet-stream";
    if (/text\/html/i.test(contentType)) {
      throw new Error("CDN returned HTML (WAF/challenge)");
    }
    return cdnResp;
  }).catch(function (err) {
    throw new Error("CDN: " + (err && err.message ? err.message : err));
  });
}

function pipeCdnViaBackground(cdnUrl, relayBase) {
  const pushUrl = relayPushUrl(relayBase);
  console.log("[JD Turnstile] CDN fetch→relay (background)", cdnUrl.slice(0, 80));
  return fetchCdnBytes(cdnUrl).then(function (cdnResp) {
    const contentType = cdnResp.headers.get("Content-Type") || "application/octet-stream";
    const cl = cdnResp.headers.get("Content-Length");
    console.log("[JD Turnstile] CDN headers OK", contentType, cl || "(unknown size)");
    return signalRelayStart(pushUrl, {
      "X-Orig-Content-Length": cl || "",
      "X-Orig-Content-Type": contentType
    }).then(function () {
      if (!cdnResp.body || typeof cdnResp.body.getReader !== "function") {
        return cdnResp.arrayBuffer().then(function (buf) {
          return pushRelayChunk(pushUrl, new Uint8Array(buf)).then(function () {
            return signalRelayEnd(pushUrl);
          });
        });
      }
      const reader = cdnResp.body.getReader();
      let bytes = 0;
      function next() {
        return reader.read().then(function (result) {
          if (result.done) {
            console.log("[JD Turnstile] fetch pump done, bytes≈", bytes);
            return signalRelayEnd(pushUrl);
          }
          bytes += result.value ? result.value.byteLength : 0;
          return pushRelayChunk(pushUrl, result.value).then(next);
        });
      }
      return next();
    });
  });
}

/**
 * Preferred: fetch CDN inside the AnkerGames tab that passed Turnstile, stream to
 * localhost relay. Cloudflare sees browser TLS + session continuity; JD only ever
 * GETs http://127.0.0.1/…/file (never dlproxy).
 */
function sendTabMessage(tabId, msg) {
  try {
    const ret = api.tabs.sendMessage(tabId, msg);
    if (ret && typeof ret.then === "function") {
      return ret;
    }
  } catch (e) {
    /* chrome callback style below */
  }
  return new Promise(function (resolve, reject) {
    try {
      api.tabs.sendMessage(tabId, msg, function (resp) {
        const err = api.runtime.lastError;
        if (err) {
          reject(new Error(err.message || String(err)));
          return;
        }
        resolve(resp);
      });
    } catch (e) {
      reject(e);
    }
  });
}


function ensureOffscreenDocument() {
  if (!api.offscreen || !api.offscreen.createDocument) {
    return Promise.resolve(false);
  }
  const offUrl = api.runtime.getURL("offscreen.html");
  function create() {
    return api.offscreen.createDocument({
      url: "offscreen.html",
      reasons: ["BLOBS"],
      justification: "Stream AnkerGames CDN file into JDownloader localhost relay"
    });
  }
  const ready = api.runtime.getContexts
    ? api.runtime.getContexts({ contextTypes: ["OFFSCREEN_DOCUMENT"], documentUrls: [offUrl] }).then(function (ctxs) {
        if (ctxs && ctxs.length) {
          return true;
        }
        return create().then(function () {
          return true;
        });
      })
    : create().then(function () {
        return true;
      });
  return ready
    .then(function () {
      /* Wait until offscreen.js listener is alive (Brave/Vivaldi race). */
      function ping(left) {
        return new Promise(function (resolve, reject) {
          try {
            api.runtime.sendMessage({ type: "jdt-offscreen-ping" }, function (resp) {
              const err = api.runtime.lastError;
              if (!err && resp && resp.ok) {
                resolve(true);
                return;
              }
              if (left <= 0) {
                reject(new Error("offscreen not ready"));
                return;
              }
              setTimeout(function () {
                ping(left - 1).then(resolve, reject);
              }, 50);
            });
          } catch (e) {
            reject(e);
          }
        });
      }
      return ping(40);
    })
    .catch(function (err) {
      console.warn("[JD Turnstile] offscreen unavailable", err);
      return false;
    });
}

function pipeCdnViaOffscreen(cdnUrl, relayBase) {
  return ensureOffscreenDocument().then(function (ok) {
    if (!ok) {
      return Promise.reject(new Error("offscreen unavailable"));
    }
    return new Promise(function (resolve, reject) {
      try {
        api.runtime.sendMessage(
          { type: "jdt-offscreen-pipe", cdnUrl: cdnUrl, relayBase: relayBase },
          function (resp) {
            const err = api.runtime.lastError;
            if (err) {
              reject(new Error(err.message || String(err)));
              return;
            }
            if (!resp || !resp.ok) {
              reject(new Error((resp && resp.error) || "offscreen pipe failed"));
              return;
            }
            resolve(resp);
          }
        );
      } catch (e) {
        reject(e);
      }
    });
  });
}

/**
 * Stream CDN→relay. Never use tab-page fetch as fallback: page CORS → Failed to fetch
 * and AnkerGames then navigates to dlproxy (browser save dialog). Firefox MV2 background
 * page ≈ Chromium offscreen document.
 */
function startCdnPipe(cdnUrl, relayBase, tabId) {
  if (tabId != null) {
    sendTabMessage(tabId, {
      type: "jdt-status",
      text: "JD is downloading — closing this tab…"
    }).catch(function () {});
  }
  /* Offscreen owns the stream — close AnkerGames UI tabs. */
  dismissPipeUiTabs();
  function okDone() {
    endPipeSession();
  }
  function failDone(err) {
    const msg = String(err && err.message ? err.message : err);
    console.error("[JD Turnstile] pipe failed", msg);
    if (tabId != null) {
      sendTabMessage(tabId, { type: "jdt-status", text: "Pipe failed: " + msg }).catch(function () {});
    }
    return Promise.reject(err);
  }

  return pipeCdnViaOffscreen(cdnUrl, relayBase)
    .then(okDone)
    .catch(function (err) {
      console.warn("[JD Turnstile] offscreen failed, trying SW fetch", err);
      return pipeCdnViaBackground(cdnUrl, relayBase).then(okDone).catch(failDone);
    });
}

function gateKey(job, callbackUrl, cdnUrl) {
  if (job && job.downloadId) {
    return "dl:" + job.downloadId;
  }
  if (callbackUrl) {
    return "cb:" + String(callbackUrl).split("&do=")[0];
  }
  return cdnUrl ? "cdn:" + String(cdnUrl).slice(0, 80) : "";
}

function markSolved(key) {
  if (!key) {
    return;
  }
  solvedGate[key] = Date.now();
  if (activeCaptchaJob) {
    activeCaptchaJob.solved = true;
  }
}

function wasSolved(key) {
  if (!key || !solvedGate[key]) {
    return false;
  }
  /* Gate expires after 2h so later re-downloads of same game work. */
  return Date.now() - solvedGate[key] < 2 * 60 * 60 * 1000;
}

/** Close captcha/AnkerGames UI tabs; keep pipeSession for download-kill until stream ends. */
function dismissPipeUiTabs() {
  if (!pipeSession || pipeSession.uiDismissed) {
    return;
  }
  pipeSession.uiDismissed = true;
  const ids = [];
  if (pipeSession.workTabId != null) {
    ids.push(pipeSession.workTabId);
  }
  if (pipeSession.captchaTabId != null && pipeSession.captchaTabId !== pipeSession.workTabId) {
    ids.push(pipeSession.captchaTabId);
  }
  ids.forEach(function (id) {
    delete jobsByTab[id];
    delete localHandled[id];
  });
  /* Short delay so the status flash is visible; then remove ugly redirect tabs. */
  setTimeout(function () {
    ids.forEach(function (id) {
      api.tabs.remove(id).catch(function () {});
    });
  }, 600);
}

function endPipeSession() {
  if (!pipeSession) {
    activeCaptchaJob = null;
    return;
  }
  dismissPipeUiTabs();
  pipeSession = null;
  activeCaptchaJob = null;
  if (api.alarms && api.alarms.clear) {
    try {
      api.alarms.clear("jdt-pipe-keepalive");
    } catch (e) {
      /* ignore */
    }
  }
}

/** @deprecated use endPipeSession */
function closePipeSessionTabs() {
  endPipeSession();
}

if (api.alarms && api.alarms.onAlarm) {
  api.alarms.onAlarm.addListener(function (alarm) {
    if (alarm && alarm.name === "jdt-pipe-keepalive" && pipeSession) {
      console.log("[JD Turnstile] SW keepalive (pipe active)");
    }
  });
}

/**
 * Single entry: do=solve once, then start CDN→relay. Ignores duplicates (loop fix).
 */
function beginRelayTransfer(opts) {
  const callbackUrl = opts.callbackUrl;
  const relayBase = opts.relayBase;
  const cdnUrl = opts.cdnUrl;
  const tabId = opts.tabId;
  const job = opts.job;
  const key = gateKey(job, callbackUrl, cdnUrl);

  if (wasSolved(key)) {
    console.log("[JD Turnstile] ignore duplicate transfer", key);
    return Promise.resolve();
  }
  if (!callbackUrl || !cdnUrl || !relayBase || relayBase.indexOf("127.0.0.1") === -1) {
    console.error("[JD Turnstile] beginRelayTransfer missing params");
    return Promise.reject(new Error("missing params"));
  }

  markSolved(key);
  pipeSession = {
    key: key,
    workTabId: tabId,
    captchaTabId: job && job.captchaTabId,
    relayBase: relayBase,
    cdnUrl: cdnUrl
  };
  if (job) {
    job.solved = true;
  }
  /* Keep Chromium MV3 service worker alive while tab streams (alarms = event wakeups). */
  if (api.alarms && api.alarms.create) {
    try {
      api.alarms.create("jdt-pipe-keepalive", { periodInMinutes: 0.5 });
    } catch (e) {
      /* ignore */
    }
  }

  console.log("[JD Turnstile] do=solve then pipe", key, cdnUrl.slice(0, 60));
  armDlproxySessionRules();
  sweepDlproxyDownloads();
  /* Notify JD and start CDN→relay in parallel — JD waits on /file for phase=start. */
  const solved = reportSolvedToJd(callbackUrl, {
    url: cdnUrl,
    userAgent: opts.userAgent || (typeof navigator !== "undefined" ? navigator.userAgent : "") || "",
    via: "relay",
    relayUrl: relayBase.replace(/\/$/, "") + "/file"
  }).then(function (resp) {
    console.log("[JD Turnstile] do=solve HTTP", resp && resp.status);
  });
  const piped = startCdnPipe(cdnUrl, relayBase, tabId);
  return Promise.all([solved, piped]).then(function () {});
}

/** High-priority session redirect while a pipe is active (Brave/Vivaldi sometimes miss static rules). */
function armDlproxySessionRules() {
  if (!api.declarativeNetRequest || !api.declarativeNetRequest.updateSessionRules) {
    return;
  }
  /* Block main_frame only — never block xmlhttprequest (CDN→relay fetch). */
  api.declarativeNetRequest
    .updateSessionRules({
      removeRuleIds: [9001],
      addRules: [
        {
          id: 9001,
          priority: 100,
          action: { type: "block" },
          condition: {
            urlFilter: "||dlproxy.uk^",
            resourceTypes: ["main_frame", "sub_frame"]
          }
        }
      ]
    })
    .then(function () {
      console.log("[JD Turnstile] session DNR armed (block main_frame)");
    })
    .catch(function (err) {
      console.warn("[JD Turnstile] session DNR failed", err);
    });
}

function sweepDlproxyDownloads() {
  if (!api.downloads || !api.downloads.search) {
    return;
  }
  api.downloads
    .search({ state: "in_progress" })
    .then(function (items) {
      (items || []).forEach(function (it) {
        const url = String(it.url || it.finalUrl || "");
        const name = String(it.filename || "");
        if (DLPROXY_RE.test(url) || /\.zip$/i.test(name)) {
          killDownload(it.id, "sweep");
        }
      });
    })
    .catch(function () {});
  setTimeout(function () {
    if (!pipeSession) {
      return;
    }
    api.downloads
      .search({})
      .then(function (items) {
        (items || []).forEach(function (it) {
          const url = String(it.url || it.finalUrl || "");
          if (DLPROXY_RE.test(url) && it.state !== "complete") {
            killDownload(it.id, "sweep2");
          }
        });
      })
      .catch(function () {});
  }, 1500);
}

/*
 * No webRequestBlocking: content-script hooks + downloads.cancel + webNavigation
 * bounce keep the AnkerGames tab alive (also friendlier for AMO auto-signing).
 */

/** Cancel browser downloads of the CDN file so only JD receives the stream. */
function killDownload(id, why) {
  console.warn("[JD Turnstile] cancelling browser download", id, why || "");
  api.downloads.cancel(id).catch(function () {});
  setTimeout(function () {
    api.downloads.erase({ id: id }).catch(function () {});
  }, 200);
  setTimeout(function () {
    api.downloads.cancel(id).catch(function () {});
    api.downloads.erase({ id: id }).catch(function () {});
  }, 800);
}

function installDownloadGuard() {
  if (!api.downloads || !api.downloads.onCreated) {
    return;
  }
  try {
    api.downloads.onCreated.addListener(function (item) {
      if (!item) {
        return;
      }
      const url = String(item.url || item.finalUrl || "");
      const name = String(item.filename || "");
      const fromDlproxy = DLPROXY_RE.test(url);
      const zipWhilePiping = !!(pipeSession && /\.zip$/i.test(name));
      if (!fromDlproxy && !zipWhilePiping) {
        return;
      }
      killDownload(item.id, (url || name).slice(0, 80));
    });
  } catch (e) {
    console.warn("[JD Turnstile] downloads guard unavailable", e);
  }
  if (api.downloads.onChanged) {
    try {
      api.downloads.onChanged.addListener(function (delta) {
        if (!pipeSession || !delta || delta.id == null) {
          return;
        }
        if (delta.state && delta.state.current === "in_progress") {
          api.downloads
            .search({ id: delta.id })
            .then(function (items) {
              const it = items && items[0];
              if (!it) {
                return;
              }
              const url = String(it.url || it.finalUrl || "");
              if (DLPROXY_RE.test(url) || /\.zip$/i.test(String(it.filename || ""))) {
                killDownload(delta.id, "onChanged");
              }
            })
            .catch(function () {});
        }
      });
    } catch (e2) {
      /* ignore */
    }
  }
}
installDownloadGuard();

/** Close the tab if AnkerGames still navigates to dlproxy while piping. */
function installDlproxyNavGuard() {
  if (!api.webNavigation || !api.webNavigation.onBeforeNavigate) {
    return;
  }
  try {
    api.webNavigation.onBeforeNavigate.addListener(function (details) {
      if (!details || details.frameId !== 0) {
        return;
      }
      const url = details.url || "";
      if (!DLPROXY_RE.test(url)) {
        return;
      }
      if (pipeSession) {
        console.warn("[JD Turnstile] closing dlproxy tab", url.slice(0, 80));
        api.tabs.remove(details.tabId).catch(function () {});
        return;
      }
      const back = lastAnkerUrlByTab[details.tabId];
      if (back) {
        api.tabs.update(details.tabId, { url: back }).catch(function () {});
      } else {
        api.tabs.remove(details.tabId).catch(function () {});
      }
    });
  } catch (e) {
    console.warn("[JD Turnstile] webNavigation guard unavailable", e);
  }
}
installDlproxyNavGuard();

api.tabs.onUpdated.addListener(function (tabId, changeInfo, tab) {
  if (tab && tab.url && ANKER_RE.test(tab.url)) {
    lastAnkerUrlByTab[tabId] = tab.url;
  }
  if (changeInfo.status === "complete" && isLocalTurnUrl(tab.url)) {
    handleLocalCaptchaTab(tabId, tab.url, false);
    return;
  }

  const job = jobsByTab[tabId];
  if (!job || job.solved || changeInfo.status !== "complete") {
    return;
  }
  if (!tab.url || tab.url.indexOf("ankergames.net") === -1) {
    return;
  }
  injectSolver(tabId, job).catch(console.error);
});


api.runtime.onMessage.addListener(function (msg, sender) {
  if (!msg || !msg.type) {
    return;
  }
  if (msg.type === "jdt-ankergames-page") {
    const tabId = sender.tab && sender.tab.id;
    if (tabId == null || !activeCaptchaJob || activeCaptchaJob.solved) {
      return;
    }
    if (wasSolved(gateKey(activeCaptchaJob, activeCaptchaJob.callbackUrl, ""))) {
      return;
    }
    if (jobsByTab[tabId] && jobsByTab[tabId].callbackUrl === activeCaptchaJob.callbackUrl) {
      return;
    }
    console.log(
      "[JD Turnstile] attach active job to ankergames tab",
      tabId,
      "ready=",
      !!msg.ready,
      "treasure=",
      !!msg.treasure
    );
    const job = Object.assign({}, activeCaptchaJob, {
      phase: msg.treasure || msg.ready ? "treasure" : "game",
      workTabId: tabId
    });
    jobsByTab[tabId] = job;
    injectSolver(tabId, job).catch(console.error);
    return;
  }
  if (msg.type === "jdt-page-cdn-link") {
    const tabId = sender.tab && sender.tab.id;
    const job =
      (tabId != null && jobsByTab[tabId]) ||
      activeCaptchaJob ||
      null;
    if (!job || !job.callbackUrl || !msg.link || job.solved) {
      return;
    }
    beginRelayTransfer({
      callbackUrl: job.callbackUrl,
      relayBase: job.relayUrl || "",
      cdnUrl: String(msg.link),
      tabId: tabId,
      job: job,
      userAgent: typeof navigator !== "undefined" ? navigator.userAgent : ""
    }).catch(function (err) {
      console.error("[JD Turnstile] page-cdn relay failed", err);
    });
    return;
  }
  if (msg.type === "jdt-local-turnstile") {
    const tabId = sender.tab && sender.tab.id;
    if (tabId == null) {
      return;
    }
    startSolveFlow(
      tabId,
      {
        siteKey: msg.siteKey,
        siteUrl: msg.siteUrl,
        siteDomain: msg.siteDomain,
        fileToken: msg.fileToken,
        gameUrl: msg.gameUrl,
        downloadId: msg.downloadId,
        relayUrl: msg.relayUrl,
        callbackUrl: msg.callbackUrl || (sender.tab && sender.tab.url) || ""
      },
      false
    );
    return;
  }
  if (msg.type === "jdt-navigate-treasure") {
    const tabId = sender.tab && sender.tab.id;
    if (tabId == null || !msg.url) {
      return;
    }
    const job = jobsByTab[tabId];
    if (job) {
      job.phase = "treasure";
      if (msg.fileToken) {
        job.fileToken = msg.fileToken;
      }
    }
    api.tabs.update(tabId, { url: msg.url }).catch(console.error);
    return;
  }
  if (msg.type === "jdt-turnstile-solved") {
    const tabId = sender.tab && sender.tab.id;
    const job = (tabId != null && jobsByTab[tabId]) || activeCaptchaJob || null;
    const callbackUrl = (job && job.callbackUrl) || msg.callbackUrl;
    const relayBase = (job && job.relayUrl) || "";
    const parsed = parseSolvePayload(msg.directUrl || msg.token);
    const cdnUrl = parsed.url;
    if (!callbackUrl || !cdnUrl) {
      console.error("[JD Turnstile] missing callback or CDN url", parsed);
      return;
    }
    if (job && job.solved) {
      return;
    }
    if (!relayBase || relayBase.indexOf("127.0.0.1") === -1) {
      console.error("[JD Turnstile] no relay URL — refusing browser download.");
      reportSolvedToJd(callbackUrl, {
        url: cdnUrl,
        userAgent: parsed.userAgent || "",
        via: "error",
        error: "missing_relay"
      }).catch(function () {});
      return;
    }
    const workTab = tabId != null ? tabId : job && job.workTabId;
    beginRelayTransfer({
      callbackUrl: callbackUrl,
      relayBase: relayBase,
      cdnUrl: cdnUrl,
      tabId: workTab,
      job: job,
      userAgent: parsed.userAgent || ""
    }).catch(function (err) {
      console.error("[JD Turnstile] relay failed", err);
    });
  }
});

function onActionClicked(tab) {
  if (typeof self.jdtOpenUpdateIfAny === "function") {
    Promise.resolve(self.jdtOpenUpdateIfAny()).then(function (opened) {
      if (opened) return;
      onActionClickedCore(tab);
    });
    return;
  }
  onActionClickedCore(tab);
}

function onActionClickedCore(tab) {
  if (!tab || tab.id == null) {
    return;
  }
  if (isLocalTurnUrl(tab.url)) {
    delete localHandled[tab.id];
    handleLocalCaptchaTab(tab.id, tab.url, true);
    return;
  }
  scanLocalCaptchaTabs();
}

if (api.action && api.action.onClicked) {
  api.action.onClicked.addListener(onActionClicked);
} else if (api.browserAction && api.browserAction.onClicked) {
  api.browserAction.onClicked.addListener(onActionClicked);
}

api.tabs.onRemoved.addListener(function (tabId) {
  const job = jobsByTab[tabId];
  delete jobsByTab[tabId];
  delete localHandled[tabId];
  delete lastAnkerUrlByTab[tabId];
  /* Closing the work tab mid-stream aborts tab-pipe; do NOT start a new captcha job. */
  if (pipeSession && pipeSession.workTabId === tabId) {
    console.warn("[JD Turnstile] work tab closed during pipe — keep JD running; do not open a new captcha");
  }
});

api.runtime.onInstalled.addListener(function () {
  scanLocalCaptchaTabs();
});

setInterval(function () {
  scanLocalCaptchaTabs().catch(function () {});
}, 2000);

scanLocalCaptchaTabs().catch(function () {});
