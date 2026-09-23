/* Gsignalx Velocity — shared text catalog
 * English in the HTML is the source. Other locales lazy-load
 * assets/i18n/{lang}/ui.json and assets/i18n/{lang}/{chapter}.json.
 *
 * data-i18n="key"            replaces textContent
 * data-i18n-html="key"       replaces innerHTML (catalog strings only)
 * data-i18n-attr="attr:key"  replaces attributes (comma-separated)
 *
 * Chapter titles live in ui.json as chapters.{id}.title / .short.
 * A future admin page includes this script, marks data-i18n, and adds keys.
 * Dynamic copy: GsxI18n.t(key, englishFallback). Re-render on onChange.
 */
(function () {
  var STORAGE_KEY = "gsx-velocity-lang";
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
  var originalTitle = "";
  var originalDescription = "";

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

  function preferred() {
    return stored() || normalize(navigator.language || "en");
  }

  function metaOf(id) {
    for (var i = 0; i < LOCALES.length; i++) {
      if (LOCALES[i].id === id) return LOCALES[i];
    }
    return LOCALES[0];
  }

  function bag(lang) {
    if (!cache[lang]) cache[lang] = { ui: null, chapters: {} };
    return cache[lang];
  }

  function lookup(lang, key) {
    if (!lang || lang === "en") return null;
    var store = cache[lang];
    if (!store) return null;
    if (store.ui && Object.prototype.hasOwnProperty.call(store.ui, key)) return store.ui[key];
    var chapters = store.chapters;
    for (var id in chapters) {
      if (Object.prototype.hasOwnProperty.call(chapters, id) &&
          chapters[id] &&
          Object.prototype.hasOwnProperty.call(chapters[id], key)) {
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
    if (lang === "en") return Promise.resolve();
    var store = bag(lang);
    if (store.ui) return Promise.resolve();
    var token = lang + "/ui";
    if (pending[token]) return pending[token];
    pending[token] = fetchJson("assets/i18n/" + lang + "/ui.json").then(function (data) {
      store.ui = data || {};
      delete pending[token];
    }).catch(function () {
      store.ui = {};
      delete pending[token];
    });
    return pending[token];
  }

  function ensureChapter(lang, chapter) {
    if (!lang || lang === "en" || !chapter) return Promise.resolve();
    var store = bag(lang);
    if (store.chapters[chapter]) return Promise.resolve();
    var token = lang + "/" + chapter;
    if (pending[token]) return pending[token];
    pending[token] = fetchJson("assets/i18n/" + lang + "/" + chapter + ".json").then(function (data) {
      store.chapters[chapter] = data || {};
      delete pending[token];
    }).catch(function () {
      store.chapters[chapter] = { __empty: true };
      delete pending[token];
    });
    return pending[token];
  }

  function activeChapter() {
    var hash = (location.hash || "").replace(/^#/, "");
    if (hash && document.getElementById(hash) && document.getElementById(hash).classList.contains("panel")) {
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

  function applyAll(lang) {
    applyDocument(lang);
    document.querySelectorAll("[data-i18n],[data-i18n-html],[data-i18n-attr]").forEach(function (el) {
      applyNode(el, lang);
    });
    applyChapters(lang);
    applyMeta(lang);
    document.documentElement.removeAttribute("data-i18n-pending");
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

  var current = preferred();

  function setLang(lang) {
    lang = normalize(lang);
    var ticket = ++seq;
    current = lang;
    try { localStorage.setItem(STORAGE_KEY, lang); } catch (e) {}
    applyDocument(lang);
    updateSwitch(lang);
    if (lang === "en") {
      applyAll("en");
      notify();
      return Promise.resolve();
    }
    return ensureLang(lang).then(function () {
      return ensureChapter(lang, activeChapter());
    }).then(function () {
      if (ticket !== seq) return;
      applyAll(lang);
      notify();
      prefetch(lang);
    });
  }

  function globeSvg() {
    return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M3 12h18"/><path d="M12 3c2.6 2.8 3.9 5.8 3.9 9s-1.3 6.2-3.9 9c-2.6-2.8-3.9-5.8-3.9-9S9.4 5.8 12 3z"/></svg>';
  }

  function renderPanel() {
    var panel = document.getElementById("langPanel");
    if (!panel) return;
    panel.innerHTML = LOCALES.map(function (loc) {
      var active = loc.id === current;
      return '<button type="button" class="lang-option' + (active ? " is-active" : "") + '" role="option" data-lang="' + loc.id + '" aria-selected="' + (active ? "true" : "false") + '">' +
        '<span class="lang-option-name">' + loc.name + "</span>" +
        '<span class="lang-option-code">' + loc.code + "</span></button>";
    }).join("");
  }

  function updateSwitch(lang) {
    var code = document.querySelector("#langSwitch .lang-code");
    var btn = document.getElementById("langToggle");
    var meta = metaOf(lang || current);
    if (code) code.textContent = meta.code;
    if (btn) btn.setAttribute("aria-label", t("ui.lang.label", "Language") + ": " + meta.name);
    renderPanel();
  }

  function closePanel() {
    var panel = document.getElementById("langPanel");
    var btn = document.getElementById("langToggle");
    if (panel) panel.hidden = true;
    if (btn) btn.setAttribute("aria-expanded", "false");
  }

  function openPanel() {
    var panel = document.getElementById("langPanel");
    var btn = document.getElementById("langToggle");
    if (!panel || !btn) return;
    panel.hidden = false;
    btn.setAttribute("aria-expanded", "true");
    renderPanel();
    var active = panel.querySelector(".lang-option.is-active") || panel.querySelector(".lang-option");
    if (active) active.focus();
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
      '<button type="button" class="lang-toggle" id="langToggle" aria-haspopup="listbox" aria-expanded="false" aria-label="Language">' +
      globeSvg() +
      '<span class="lang-code">' + meta.code + "</span></button>" +
      '<div class="lang-panel" id="langPanel" role="listbox" aria-label="Language" hidden></div>';
    if (actions) {
      var theme = document.getElementById("themeToggle");
      if (theme) actions.insertBefore(wrap, theme);
      else actions.insertBefore(wrap, actions.firstChild);
    } else {
      splash.insertBefore(wrap, splash.firstChild);
    }
    var btn = wrap.querySelector("#langToggle");
    btn.addEventListener("click", function (event) {
      event.stopPropagation();
      var panel = document.getElementById("langPanel");
      if (panel && panel.hidden) openPanel();
      else closePanel();
    });
    wrap.addEventListener("click", function (event) {
      var opt = event.target.closest ? event.target.closest(".lang-option") : null;
      if (!opt) return;
      closePanel();
      setLang(opt.getAttribute("data-lang"));
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
      if (event.key !== "ArrowDown" && event.key !== "ArrowUp") return;
      if (panel.hidden) {
        openPanel();
        event.preventDefault();
        return;
      }
      var opts = Array.prototype.slice.call(panel.querySelectorAll(".lang-option"));
      var index = opts.indexOf(document.activeElement);
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
    mountSwitch();
    setLang(current);
  }

  window.GsxI18n = {
    key: STORAGE_KEY,
    locales: LOCALES,
    t: t,
    get: function () { return current; },
    set: setLang,
    onChange: function (fn) {
      if (typeof fn === "function") listeners.push(fn);
    },
    apply: function () { applyAll(current); },
    ensureChapter: function (id) {
      return ensureChapter(current, id).then(function () {
        if (current !== "en") applyAll(current);
      });
    }
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
  else boot();
})();
