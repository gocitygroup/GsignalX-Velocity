/* Gsignalx Velocity — shared text catalog
 * English in the HTML is the source. Other locales lazy-load
 * /assets/i18n/{lang}/ui.json and /assets/i18n/{lang}/{chapter}.json.
 *
 * data-i18n="key"            replaces textContent
 * data-i18n-html="key"       replaces innerHTML (catalog strings only)
 * data-i18n-attr="attr:key"  replaces attributes (comma-separated)
 *
 * Resolve order: ?lang= → localStorage → navigator.language → en
 * Dynamic copy: GsxI18n.t(key, englishFallback). Re-render on onChange.
 */
(function () {
  var STORAGE_KEY = "gsx-velocity-lang";
  var HINT_KEY = "gsx-velocity-lang-hint";
  var CACHE_VER = "2.14";
  var PENDING_MS = 2500;
  var LOCALES = [
    { id: "en", code: "EN", name: "English", dir: "ltr" },
    { id: "it", code: "IT", name: "Italiano", dir: "ltr" },
    { id: "fr", code: "FR", name: "Français", dir: "ltr" },
    { id: "ru", code: "RU", name: "Русский", dir: "ltr" },
    { id: "ar", code: "AR", name: "العربية", dir: "rtl" },
    { id: "zh", code: "ZH", name: "中文", dir: "ltr" },
    { id: "es", code: "ES", name: "Español", dir: "ltr" }
  ];
  var SUPPORTED = { en: 1, it: 1, fr: 1, ru: 1, ar: 1, zh: 1, es: 1 };
  var cache = {};
  var pending = {};
  var originals = new WeakMap();
  var listeners = [];
  var seq = 0;
  var busy = false;
  var originalTitle = "";
  var originalDescription = "";
  var pendingTimer = null;

  function normalize(lang) {
    if (!lang) return "en";
    var value = String(lang).toLowerCase().replace(/_/g, "-");
    if (value.indexOf("zh") === 0) return "zh";
    var primary = value.split("-")[0];
    return SUPPORTED[primary] ? primary : "en";
  }

  function stored() {
    try {
      var value = localStorage.getItem(STORAGE_KEY);
      if (value && SUPPORTED[value]) return value;
    } catch (e) {}
    return null;
  }

  function queryLang() {
    try {
      var params = new URLSearchParams(location.search || "");
      var q = params.get("lang");
      if (q) {
        var n = normalize(q);
        if (SUPPORTED[n]) return n;
      }
      var hash = location.hash || "";
      var qi = hash.indexOf("?");
      if (qi >= 0) {
        var hp = new URLSearchParams(hash.slice(qi + 1));
        q = hp.get("lang");
        if (q) {
          n = normalize(q);
          if (SUPPORTED[n]) return n;
        }
      }
    } catch (e) {}
    return null;
  }

  function preferred() {
    return queryLang() || stored() || normalize(navigator.language || "en");
  }

  function metaOf(id) {
    for (var i = 0; i < LOCALES.length; i++) {
      if (LOCALES[i].id === id) return LOCALES[i];
    }
    return LOCALES[0];
  }

  function catalogUrl(lang, file) {
    var base =
      /^https?:$/i.test(location.protocol) ? "/assets/i18n/" : "assets/i18n/";
    return base + lang + "/" + file + "?v=" + encodeURIComponent(CACHE_VER);
  }

  function bag(lang) {
    if (!cache[lang]) cache[lang] = { ui: null, chapters: {}, uiFailed: false };
    return cache[lang];
  }

  function lookup(lang, key) {
    if (!lang || lang === "en") return null;
    var store = cache[lang];
    if (!store) return null;
    if (store.ui && Object.prototype.hasOwnProperty.call(store.ui, key)) return store.ui[key];
    var chapters = store.chapters;
    for (var id in chapters) {
      if (
        Object.prototype.hasOwnProperty.call(chapters, id) &&
        chapters[id] &&
        Object.prototype.hasOwnProperty.call(chapters[id], key)
      ) {
        return chapters[id][key];
      }
    }
    return null;
  }

  function t(key, fallback) {
    var value = lookup(current, key);
    if (value != null && value !== "") return value;
    return fallback != null ? fallback : key;
  }

  function fetchJson(url) {
    return fetch(url, { credentials: "same-origin" }).then(function (res) {
      if (!res.ok) throw new Error(url);
      return res.json();
    });
  }

  function ensureLang(lang) {
    if (lang === "en") return Promise.resolve(true);
    var store = bag(lang);
    if (store.ui && !store.uiFailed) return Promise.resolve(true);
    if (store.uiFailed) {
      store.ui = null;
      store.uiFailed = false;
    }
    var token = lang + "/ui";
    if (pending[token]) return pending[token];
    pending[token] = fetchJson(catalogUrl(lang, "ui.json"))
      .then(function (data) {
        store.ui = data || {};
        store.uiFailed = false;
        delete pending[token];
        return true;
      })
      .catch(function () {
        store.ui = {};
        store.uiFailed = true;
        delete pending[token];
        return false;
      });
    return pending[token];
  }

  function ensureChapter(lang, chapter) {
    if (!lang || lang === "en" || !chapter) return Promise.resolve(true);
    var store = bag(lang);
    if (store.chapters[chapter]) return Promise.resolve(true);
    var token = lang + "/" + chapter;
    if (pending[token]) return pending[token];
    pending[token] = fetchJson(catalogUrl(lang, chapter + ".json"))
      .then(function (data) {
        store.chapters[chapter] = data || {};
        delete pending[token];
        return true;
      })
      .catch(function () {
        delete pending[token];
        return false;
      });
    return pending[token];
  }

  function activeChapter() {
    var hash = (location.hash || "").replace(/^#/, "").split("?")[0];
    if (
      hash &&
      document.getElementById(hash) &&
      document.getElementById(hash).classList.contains("panel")
    ) {
      return hash;
    }
    var active = document.querySelector("section.panel.active");
    return active ? active.id : "welcome";
  }

  function capture(el) {
    var rec = originals.get(el);
    if (!rec) {
      rec = { attrs: {} };
      originals.set(el, rec);
    }
    return rec;
  }

  function applyNode(el, lang) {
    var htmlKey = el.getAttribute("data-i18n-html");
    var textKey = el.getAttribute("data-i18n");
    if (htmlKey) {
      var rec = capture(el);
      if (rec.html == null) rec.html = el.innerHTML;
      var html = lang === "en" ? null : lookup(lang, htmlKey);
      el.innerHTML = html != null ? html : rec.html;
    } else if (textKey) {
      var recText = capture(el);
      if (recText.text == null) recText.text = el.textContent;
      var text = lang === "en" ? null : lookup(lang, textKey);
      el.textContent = text != null ? text : recText.text;
    }
    var spec = el.getAttribute("data-i18n-attr");
    if (!spec) return;
    spec.split(",").forEach(function (pair) {
      var bits = pair.split(":");
      var attr = (bits[0] || "").trim();
      var key = (bits.slice(1).join(":") || "").trim();
      if (!attr || !key) return;
      var recAttr = capture(el);
      if (recAttr.attrs[attr] == null) recAttr.attrs[attr] = el.getAttribute(attr) || "";
      var next = lang === "en" ? null : lookup(lang, key);
      el.setAttribute(attr, next != null ? next : recAttr.attrs[attr]);
    });
  }

  function applyChapters(lang) {
    document.querySelectorAll("section.panel[id]").forEach(function (sec) {
      if (!sec.hasAttribute("data-title-en")) {
        sec.setAttribute("data-title-en", sec.getAttribute("data-title") || "");
        sec.setAttribute("data-short-en", sec.getAttribute("data-short") || "");
      }
      var title = lang === "en" ? null : lookup(lang, "chapters." + sec.id + ".title");
      var short = lang === "en" ? null : lookup(lang, "chapters." + sec.id + ".short");
      sec.setAttribute("data-title", title != null ? title : sec.getAttribute("data-title-en"));
      sec.setAttribute("data-short", short != null ? short : sec.getAttribute("data-short-en"));
    });
  }

  function applyMeta(lang) {
    if (!originalTitle) originalTitle = document.title;
    var desc = document.querySelector('meta[name="description"]');
    if (desc && !originalDescription) originalDescription = desc.getAttribute("content") || "";
    var titleKey = document.querySelector(".splash") ? "ui.splash.title" : "ui.meta.title";
    var descKey = document.querySelector(".splash") ? "ui.splash.description" : "ui.meta.description";
    var title = lang === "en" ? null : lookup(lang, titleKey);
    document.title = title != null ? title : originalTitle;
    if (desc) {
      var description = lang === "en" ? null : lookup(lang, descKey);
      desc.setAttribute("content", description != null ? description : originalDescription);
    }
  }

  function ensureFont(lang) {
    var id = "gsx-i18n-font";
    var existing = document.getElementById(id);
    var href = null;
    if (lang === "ar") {
      href = "https://fonts.googleapis.com/css2?family=Noto+Sans+Arabic:wght@400;600;700&display=swap";
    } else if (lang === "zh") {
      href = "https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;600;700&display=swap";
    }
    if (!href) {
      if (existing && existing.parentNode) existing.parentNode.removeChild(existing);
      document.documentElement.removeAttribute("data-i18n-font");
      return;
    }
    if (existing && existing.getAttribute("href") === href) return;
    if (existing && existing.parentNode) existing.parentNode.removeChild(existing);
    var link = document.createElement("link");
    link.id = id;
    link.rel = "stylesheet";
    link.href = href;
    document.head.appendChild(link);
    document.documentElement.setAttribute("data-i18n-font", lang);
  }

  function applyDocument(lang) {
    var meta = metaOf(lang);
    document.documentElement.lang = lang === "zh" ? "zh-Hans" : lang;
    document.documentElement.dir = meta.dir;
    ensureFont(lang);
  }

  function clearPending() {
    document.documentElement.removeAttribute("data-i18n-pending");
    if (pendingTimer) {
      clearTimeout(pendingTimer);
      pendingTimer = null;
    }
  }

  function armPendingTimeout() {
    if (pendingTimer) clearTimeout(pendingTimer);
    pendingTimer = setTimeout(function () {
      clearPending();
    }, PENDING_MS);
  }

  function applyAll(lang) {
    applyDocument(lang);
    document.querySelectorAll("[data-i18n],[data-i18n-html],[data-i18n-attr]").forEach(function (el) {
      applyNode(el, lang);
    });
    applyChapters(lang);
    applyMeta(lang);
    clearPending();
    updateSwitch(lang);
  }

  function chapterIds() {
    var ids = [];
    document.querySelectorAll("section.panel[id]").forEach(function (sec) {
      ids.push(sec.id);
    });
    return ids;
  }

  function prefetch(lang) {
    if (lang === "en") return;
    var ids = chapterIds();
    var index = 0;
    function step() {
      if (index >= ids.length) return;
      var id = ids[index++];
      ensureChapter(lang, id).then(function () {
        var schedule = window.requestIdleCallback || function (fn) { setTimeout(fn, 50); };
        schedule(step);
      });
    }
    var schedule = window.requestIdleCallback || function (fn) { setTimeout(fn, 80); };
    schedule(step);
  }

  function notify() {
    listeners.forEach(function (fn) {
      try { fn(current); } catch (e) {}
    });
  }

  function syncUrl(lang) {
    try {
      var url = new URL(location.href);
      if (lang === "en") url.searchParams.delete("lang");
      else url.searchParams.set("lang", lang);
      history.replaceState(null, "", url.pathname + url.search + url.hash);
    } catch (e) {}
  }

  function setBusy(on) {
    busy = !!on;
    var wrap = document.getElementById("langSwitch");
    var btn = document.getElementById("langToggle");
    if (wrap) wrap.classList.toggle("is-busy", busy);
    if (btn) {
      btn.setAttribute("aria-busy", busy ? "true" : "false");
    }
    document.querySelectorAll("#langPanel .lang-option").forEach(function (opt) {
      opt.disabled = busy;
    });
  }

  function ensureLive() {
    var el = document.getElementById("langLive");
    if (el) return el;
    el = document.createElement("div");
    el.id = "langLive";
    el.className = "lang-live";
    el.setAttribute("aria-live", "polite");
    el.setAttribute("role", "status");
    document.body.appendChild(el);
    return el;
  }

  function announce(msg) {
    var el = ensureLive();
    el.textContent = "";
    window.setTimeout(function () {
      el.textContent = msg;
    }, 30);
  }

  function closeLinks() {
    var links = document.querySelector(".header-links");
    if (links) links.open = false;
  }

  var current = preferred();

  function setLang(lang, opts) {
    opts = opts || {};
    lang = normalize(lang);
    var ticket = ++seq;
    var userInitiated = !!opts.userInitiated;
    current = lang;
    try { localStorage.setItem(STORAGE_KEY, lang); } catch (e) {}
    if (userInitiated) syncUrl(lang);
    applyDocument(lang);
    updateSwitch(lang);

    if (lang === "en") {
      setBusy(false);
      applyAll("en");
      notify();
      return Promise.resolve();
    }

    if (userInitiated) setBusy(true);
    else if (document.documentElement.hasAttribute("data-i18n-pending")) armPendingTimeout();

    return ensureLang(lang)
      .then(function (uiOk) {
        return ensureChapter(lang, activeChapter()).then(function (chOk) {
          return { uiOk: uiOk, chOk: chOk };
        });
      })
      .then(function (result) {
        if (ticket !== seq) return;
        var store = bag(lang);
        var failed = store.uiFailed || !result.uiOk;
        if (failed && userInitiated) {
          current = "en";
          try { localStorage.setItem(STORAGE_KEY, "en"); } catch (e) {}
          syncUrl("en");
          applyAll("en");
          setBusy(false);
          notify();
          announce("Language pack unavailable — showing English.");
          return;
        }
        applyAll(lang);
        setBusy(false);
        notify();
        prefetch(lang);
        if (failed && !userInitiated) {
          announce("Language pack unavailable — showing English.");
        }
      });
  }

  function globeSvg() {
    return (
      '<svg class="lang-globe" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
      '<circle cx="12" cy="12" r="9"/><path d="M3 12h18"/>' +
      '<path d="M12 3c2.6 2.8 3.9 5.8 3.9 9s-1.3 6.2-3.9 9c-2.6-2.8-3.9-5.8-3.9-9S9.4 5.8 12 3z"/></svg>' +
      '<span class="lang-spinner" aria-hidden="true"></span>'
    );
  }

  function renderPanel() {
    var panel = document.getElementById("langPanel");
    if (!panel) return;
    panel.innerHTML = LOCALES.map(function (loc) {
      var active = loc.id === current;
      return (
        '<button type="button" class="lang-option' +
        (active ? " is-active" : "") +
        '" role="option" id="langOpt-' +
        loc.id +
        '" data-lang="' +
        loc.id +
        '" aria-selected="' +
        (active ? "true" : "false") +
        '"' +
        (busy ? " disabled" : "") +
        ">" +
        '<span class="lang-option-name">' +
        loc.name +
        "</span>" +
        '<span class="lang-option-code">' +
        loc.code +
        "</span></button>"
      );
    }).join("");
  }

  function updateSwitch(lang) {
    var code = document.querySelector("#langSwitch .lang-code");
    var btn = document.getElementById("langToggle");
    var panel = document.getElementById("langPanel");
    var meta = metaOf(lang || current);
    if (code) code.textContent = meta.code;
    if (btn) {
      btn.setAttribute("aria-label", t("ui.lang.label", "Language") + ": " + meta.name);
    }
    if (panel) {
      panel.setAttribute("aria-label", t("ui.lang.label", "Language"));
    }
    renderPanel();
  }

  function closePanel() {
    var panel = document.getElementById("langPanel");
    var btn = document.getElementById("langToggle");
    if (panel) {
      panel.hidden = true;
      panel.classList.remove("is-open");
    }
    if (btn) btn.setAttribute("aria-expanded", "false");
  }

  function openPanel() {
    var panel = document.getElementById("langPanel");
    var btn = document.getElementById("langToggle");
    if (!panel || !btn || busy) return;
    closeLinks();
    panel.hidden = false;
    panel.classList.add("is-open");
    btn.setAttribute("aria-expanded", "true");
    renderPanel();
    var active =
      panel.querySelector(".lang-option.is-active") || panel.querySelector(".lang-option");
    if (active) active.focus();
  }

  function selectLang(id) {
    if (busy) return;
    closePanel();
    setLang(id, { userInitiated: true });
  }

  function maybePulse() {
    if (stored() || queryLang()) return;
    var browser = normalize(navigator.language || "en");
    if (browser === "en" || !SUPPORTED[browser]) return;
    try {
      if (localStorage.getItem(HINT_KEY) === "1") return;
      localStorage.setItem(HINT_KEY, "1");
    } catch (e) {
      return;
    }
    var wrap = document.getElementById("langSwitch");
    var btn = document.getElementById("langToggle");
    if (!wrap || !btn) return;
    wrap.classList.add("is-hint");
    btn.title = metaOf(browser).name;
    window.setTimeout(function () {
      wrap.classList.remove("is-hint");
      if (btn.getAttribute("title") === metaOf(browser).name) btn.removeAttribute("title");
    }, 4200);
  }

  function bindLinksExclusive() {
    var links = document.querySelector(".header-links");
    if (!links || links._gsxLangBound) return;
    links._gsxLangBound = true;
    links.addEventListener("toggle", function () {
      if (links.open) closePanel();
    });
  }

  function mountSwitch() {
    if (document.getElementById("langSwitch")) return;
    var actions = document.querySelector(".header-actions");
    var splash = document.querySelector(".splash");
    var host = actions || splash;
    if (!host) return;
    var wrap = document.createElement("div");
    wrap.className = "lang-switch";
    wrap.id = "langSwitch";
    var meta = metaOf(current);
    wrap.innerHTML =
      '<button type="button" class="lang-toggle" id="langToggle" aria-haspopup="listbox" aria-expanded="false" aria-controls="langPanel" aria-busy="false" aria-label="Language">' +
      globeSvg() +
      '<span class="lang-code">' +
      meta.code +
      "</span></button>" +
      '<div class="lang-panel" id="langPanel" role="listbox" aria-label="Language" hidden></div>';
    if (actions) {
      var theme = document.getElementById("themeToggle");
      if (theme) actions.insertBefore(wrap, theme);
      else actions.insertBefore(wrap, actions.firstChild);
    } else {
      splash.insertBefore(wrap, splash.firstChild);
    }
    ensureLive();
    bindLinksExclusive();

    var btn = wrap.querySelector("#langToggle");
    btn.addEventListener("click", function (event) {
      event.stopPropagation();
      if (busy) return;
      var panel = document.getElementById("langPanel");
      if (panel && panel.hidden) openPanel();
      else closePanel();
    });
    wrap.addEventListener("click", function (event) {
      var opt = event.target.closest ? event.target.closest(".lang-option") : null;
      if (!opt || opt.disabled) return;
      selectLang(opt.getAttribute("data-lang"));
    });
    wrap.addEventListener("keydown", function (event) {
      var panel = document.getElementById("langPanel");
      if (!panel) return;
      if (event.key === "Escape") {
        closePanel();
        btn.focus();
        event.stopPropagation();
        return;
      }
      var opts = Array.prototype.slice.call(panel.querySelectorAll(".lang-option:not([disabled])"));
      var index = opts.indexOf(document.activeElement);

      if (event.key === "Enter" || event.key === " ") {
        if (document.activeElement && document.activeElement.classList.contains("lang-option")) {
          event.preventDefault();
          selectLang(document.activeElement.getAttribute("data-lang"));
        }
        return;
      }
      if (event.key === "Home" && !panel.hidden && opts.length) {
        event.preventDefault();
        opts[0].focus();
        return;
      }
      if (event.key === "End" && !panel.hidden && opts.length) {
        event.preventDefault();
        opts[opts.length - 1].focus();
        return;
      }
      if (event.key !== "ArrowDown" && event.key !== "ArrowUp") return;
      if (panel.hidden) {
        openPanel();
        event.preventDefault();
        return;
      }
      if (event.key === "ArrowDown") index = Math.min(opts.length - 1, index + 1);
      else index = Math.max(0, index - 1);
      if (index < 0) index = 0;
      if (opts[index]) opts[index].focus();
      event.preventDefault();
    });
    document.addEventListener("click", function (event) {
      if (!wrap.contains(event.target)) closePanel();
    });
    renderPanel();
  }

  function boot() {
    if (current !== "en") {
      document.documentElement.setAttribute("data-i18n-pending", "");
      armPendingTimeout();
    }
    mountSwitch();
    setLang(current, { userInitiated: false }).then(function () {
      maybePulse();
    });
  }

  window.GsxI18n = {
    key: STORAGE_KEY,
    locales: LOCALES,
    t: t,
    get: function () {
      return current;
    },
    set: function (lang) {
      return setLang(lang, { userInitiated: true });
    },
    onChange: function (fn) {
      if (typeof fn === "function") listeners.push(fn);
    },
    apply: function () {
      applyAll(current);
    },
    ensureChapter: function (id) {
      return ensureChapter(current, id).then(function () {
        if (current !== "en") applyAll(current);
      });
    }
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
  else boot();
})();
