"use strict";

/**
 * Fallback update check via GitHub Releases API.
 * Chromium also uses native update_url (updates/chromium.xml).
 * Firefox uses gecko.update_url (updates/firefox.json) when the XPI is signed.
 * This badge notifies even when native update feeds are unavailable (e.g. unsigned Firefox).
 */
(function () {
  var api = typeof browser !== "undefined" ? browser : chrome;
  var GH_LATEST =
    "https://api.github.com/repos/benjarogit/jd2plugin-ankergames-download/releases/latest";
  var ALARM = "jdt-update-check";
  var STORAGE_KEY = "jdtUpdateAvailable";

  function parseVer(v) {
    return String(v || "0")
      .split(/[.+-]/)
      .map(function (p) {
        var n = parseInt(p, 10);
        return isNaN(n) ? 0 : n;
      });
  }

  function isNewer(remote, local) {
    var a = parseVer(remote);
    var b = parseVer(local);
    var n = Math.max(a.length, b.length);
    for (var i = 0; i < n; i++) {
      var x = a[i] || 0;
      var y = b[i] || 0;
      if (x > y) return true;
      if (x < y) return false;
    }
    return false;
  }

  function setBadge(text, title) {
    var action = api.action || api.browserAction;
    if (!action) return;
    try {
      if (action.setBadgeText) action.setBadgeText({ text: text || "" });
      if (action.setBadgeBackgroundColor) {
        action.setBadgeBackgroundColor({ color: "#c45c26" });
      }
      if (action.setTitle && title) {
        action.setTitle({ title: title });
      }
    } catch (e) {
      /* ignore */
    }
  }

  function check() {
    var local = (api.runtime.getManifest() || {}).version || "0";
    return fetch(GH_LATEST, {
      headers: { Accept: "application/vnd.github+json" }
    })
      .then(function (r) {
        if (!r.ok) throw new Error("GitHub HTTP " + r.status);
        return r.json();
      })
      .then(function (data) {
        var tag = String(data.tag_name || "").replace(/^v/i, "");
        var url = data.html_url ||
          "https://github.com/benjarogit/jd2plugin-ankergames-download/releases";
        if (tag && isNewer(tag, local)) {
          var msg =
            "Update available: v" + tag + " (you have v" + local + "). Click for release.";
          setBadge("↑", "JD Turnstile Companion — " + msg);
          return api.storage.local.set({
            jdtUpdateAvailable: { version: tag, url: url, checkedAt: Date.now() }
          });
        }
        setBadge("", "JD Turnstile Companion");
        return api.storage.local.remove(STORAGE_KEY);
      })
      .catch(function (err) {
        console.warn("[JD Turnstile] update check failed", err);
      });
  }

  function schedule() {
    if (api.alarms && api.alarms.create) {
      try {
        api.alarms.create(ALARM, { periodInMinutes: 360 });
      } catch (e) {
        /* ignore */
      }
    }
    check();
    setInterval(check, 6 * 60 * 60 * 1000);
  }

  if (api.alarms && api.alarms.onAlarm) {
    api.alarms.onAlarm.addListener(function (alarm) {
      if (alarm && alarm.name === ALARM) check();
    });
  }

  /* Click toolbar icon while badge ↑ → open release page (then normal click behaviour still runs). */
  function openUpdateIfAny() {
    return api.storage.local.get(STORAGE_KEY).then(function (obj) {
      var info = obj && obj[STORAGE_KEY];
      if (info && info.url) {
        api.tabs.create({ url: info.url });
        return true;
      }
      return false;
    });
  }

  /* Expose for background.js action handler */
  self.jdtCheckGitHubUpdate = check;
  self.jdtOpenUpdateIfAny = openUpdateIfAny;

  if (api.runtime && api.runtime.onInstalled) {
    api.runtime.onInstalled.addListener(function () {
      check();
    });
  }
  schedule();
})();
