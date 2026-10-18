"use strict";

/**
 * Runs in the PAGE world (manifest world: MAIN).
 * Blocks AnkerGames from navigating / opening dlproxy so the companion can
 * stream CDN→JD without a browser Save dialog.
 */
(function () {
  if (window.__jdtPageNavGuard) {
    return;
  }
  window.__jdtPageNavGuard = true;

  function isDl(u) {
    return !!(u && /dlproxy\.uk/i.test(String(u)));
  }

  function blockNav(u, why) {
    if (!isDl(u)) {
      return false;
    }
    try {
      console.log("[JD Turnstile] page-nav-guard block", why, String(u).slice(0, 60));
    } catch (e) {
      /* ignore */
    }
    try {
      window.stop();
    } catch (e2) {
      /* ignore */
    }
    return true;
  }

  try {
    var ro = window.open;
    window.open = function (u) {
      if (blockNav(u, "open")) {
        return null;
      }
      return ro.apply(this, arguments);
    };
  } catch (e) {
    /* ignore */
  }

  try {
    var la = Location.prototype.assign;
    Location.prototype.assign = function (u) {
      if (blockNav(u, "assign")) {
        return;
      }
      return la.call(this, u);
    };
    var lr = Location.prototype.replace;
    Location.prototype.replace = function (u) {
      if (blockNav(u, "replace")) {
        return;
      }
      return lr.call(this, u);
    };
  } catch (e2) {
    /* ignore */
  }

  try {
    var desc = Object.getOwnPropertyDescriptor(Location.prototype, "href");
    if (desc && desc.set) {
      Object.defineProperty(Location.prototype, "href", {
        configurable: true,
        enumerable: true,
        get: function () {
          return desc.get.call(this);
        },
        set: function (v) {
          if (blockNav(v, "href")) {
            return;
          }
          return desc.set.call(this, v);
        }
      });
    }
  } catch (e3) {
    /* ignore */
  }

  document.addEventListener(
    "click",
    function (e) {
      try {
        var a = e.target && e.target.closest && e.target.closest("a[href]");
        if (a && isDl(a.href)) {
          e.preventDefault();
          e.stopPropagation();
          e.stopImmediatePropagation();
          blockNav(a.href, "click");
        }
      } catch (x) {
        /* ignore */
      }
    },
    true
  );
})();
