"use strict";

/**
 * Always-on content script for ankergames.net.
 * Attaches to the active JD captcha job even if the tab was opened manually
 * ("Browser öffnen" / Ready page left open) so the overlay + /link → relay runs.
 */
(function () {
  var api = typeof browser !== "undefined" ? browser : chrome;
  if (window.__jdtAnkerHook) {
    return;
  }
  window.__jdtAnkerHook = true;

  function installPageFetchHook() {
    if (document.documentElement.getAttribute("data-jdt-fetch-hook") === "1") {
      return;
    }
    document.documentElement.setAttribute("data-jdt-fetch-hook", "1");
    var script = document.createElement("script");
    /*
     * Must run in the PAGE world (not the isolated content-script world).
     * Chromium isolation means location/open patches in solver.js never see
     * AnkerGames' own navigation → browser Save dialog for dlproxy.
     */
    script.textContent =
      "(function(){" +
      "if(window.__jdtFetchHooked)return;window.__jdtFetchHooked=true;" +
      "function isDl(u){return !!(u&&/dlproxy\\.uk/i.test(String(u)));}" +
      "function emit(link){try{window.postMessage({source:'jdt-turnstile',type:'jdt-cdn-link',link:String(link||'')},'*');}catch(e){}}" +
      "function blockNav(u,why){if(!isDl(u))return false;try{console.log('[JD Turnstile] page-world block',why,String(u).slice(0,60));}catch(e){}try{window.stop();}catch(e2){}return true;}" +
      "var of=window.fetch;" +
      "if(typeof of==='function'){window.fetch=function(){var args=arguments;return of.apply(this,args).then(function(r){" +
      "try{var u='';var a0=args[0];if(typeof a0==='string')u=a0;else if(a0&&a0.url)u=a0.url;" +
      "if(/\\/link(\\?|$)/i.test(u)||/dlproxy\\.uk/i.test(u)){r.clone().text().then(function(t){" +
      "if(!t)return;if(t.charAt(0)==='{'){try{var j=JSON.parse(t);if(j&&j.link)emit(j.link);}catch(e){}} " +
      "else if(/^https?:\\/\\//i.test(t.trim()))emit(t.trim());" +
      "else if(/dlproxy\\.uk/i.test(u)&&r.url)emit(r.url);" +
      "});}" +
      "}catch(e){}return r;});};}" +
      "var ox=window.XMLHttpRequest&&window.XMLHttpRequest.prototype.open;" +
      "var sx=window.XMLHttpRequest&&window.XMLHttpRequest.prototype.send;" +
      "if(ox&&sx){window.XMLHttpRequest.prototype.open=function(m,u){this.__jdtUrl=u;return ox.apply(this,arguments);};" +
      "window.XMLHttpRequest.prototype.send=function(){var x=this;x.addEventListener('load',function(){" +
      "try{var u=String(x.__jdtUrl||'');if(!/\\/link(\\?|$)/i.test(u))return;var t=x.responseText||'';" +
      "if(t.charAt(0)==='{'){var j=JSON.parse(t);if(j&&j.link)emit(j.link);}" +
      "}catch(e){}});return sx.apply(this,arguments);};}" +
      "try{var ro=window.open;window.open=function(u){if(blockNav(u,'open'))return null;return ro.apply(this,arguments);};}catch(e){}" +
      "try{var la=Location.prototype.assign;Location.prototype.assign=function(u){if(blockNav(u,'assign'))return;return la.call(this,u);};" +
      "var lr=Location.prototype.replace;Location.prototype.replace=function(u){if(blockNav(u,'replace'))return;return lr.call(this,u);};}catch(e){}" +
      "try{var desc=Object.getOwnPropertyDescriptor(Location.prototype,'href');" +
      "if(desc&&desc.set){Object.defineProperty(Location.prototype,'href',{configurable:true,enumerable:true," +
      "get:function(){return desc.get.call(this);}," +
      "set:function(v){if(blockNav(v,'href'))return;return desc.set.call(this,v);}});}}catch(e){}" +
      "document.addEventListener('click',function(e){try{var a=e.target&&e.target.closest&&e.target.closest('a[href]');" +
      "if(a&&isDl(a.href)){e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();blockNav(a.href,'click');}}catch(x){}},true);" +
      "})();";
    (document.documentElement || document.head || document.body).appendChild(script);
    script.remove();
  }

  window.addEventListener("message", function (ev) {
    if (!ev.data || ev.data.source !== "jdt-turnstile" || ev.data.type !== "jdt-cdn-link") {
      return;
    }
    if (!ev.data.link) {
      return;
    }
    api.runtime.sendMessage({
      type: "jdt-page-cdn-link",
      link: ev.data.link,
      pageUrl: location.href
    });
  });

  function announce() {
    installPageFetchHook();
    var body = (document.body && document.body.innerText) || "";
    api.runtime.sendMessage({
      type: "jdt-ankergames-page",
      url: location.href,
      ready: /Download Ready|\bReady!\b/i.test(body),
      treasure: /\/download\//i.test(location.pathname),
      game: /\/game\//i.test(location.pathname)
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", announce);
  } else {
    announce();
  }
  setTimeout(announce, 1500);
  setTimeout(announce, 4000);
})();
