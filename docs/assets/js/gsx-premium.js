/* Gsignalx Velocity — Managed Premium upgrade rail
 * URLs MUST stay in sync with Include/GSignalX/BrandLinks.mqh
 *
 * Self-serve City toolkit (this manual) vs hosted Premium Managed desk (ccity).
 * Book install/maintenance via GSignalX Service pricing + Profile → My Services.
 * Optional mentorship for process / market understanding (educational).
 */
(function () {
  var PREMIUM_MANUAL_URL =
    "https://ccity.gsignalx.cloud/Gsignalx_Velocity_Premium_Users_Manual#welcome";
  var SERVICE_PRICING_URL = "https://www.gsignalx.cloud/pricing";
  var MENTORSHIP_URL = "https://www.gsignalx.cloud/mentorship";
  var SERVICE_HOME_URL = "https://www.gsignalx.cloud/";
  var DISMISS_KEY = "gsx-premium-rail-dismissed";

  var INTENTS = {
    welcome: {
      lead:
        "Prefer a hosted desk? Velocity Premium is managed for you — OF/VP tools, install & maintenance. Self-serve City stays free to run locally.",
      bookLabel: "Book Managed Premium",
      bookHint: "Pricing · Profile → My Services",
      manualLabel: "Premium Manual",
      manualHint: "ccity · trader guide",
      mentorLabel: "Mentorship",
      mentorHint: "Process & market understanding"
    },
    deploy: {
      lead:
        "Stuck on Windows deploy? Book Managed Premium for hosted install & maintenance — or keep self-serve with this manual.",
      bookLabel: "Book install & maintenance",
      bookHint: "gsignalx.cloud/pricing",
      manualLabel: "Premium Manual",
      manualHint: "Hosted desk guide",
      mentorLabel: "Mentorship",
      mentorHint: "Optional coaching"
    },
    community: {
      lead:
        "Community shares macro context. Managed Premium hosts the desk; mentorship tightens process — neither guarantees profit.",
      bookLabel: "Book Managed Premium",
      bookHint: "Register → My Services",
      manualLabel: "Premium Manual",
      manualHint: "Welcome chapter",
      mentorLabel: "Apply mentorship",
      mentorHint: "Profile application"
    },
    footer: {
      lead:
        "Upgrade path: hosted Premium Managed · book via Service · optional mentorship.",
      bookLabel: "Book Premium",
      bookHint: "Install & maintenance",
      manualLabel: "Manual",
      manualHint: "ccity",
      mentorLabel: "Mentorship",
      mentorHint: "Educational"
    },
    banner: {
      lead: "Managed Premium · hosted desk",
      bookLabel: "Book",
      bookHint: "",
      manualLabel: "Manual",
      manualHint: "",
      mentorLabel: "Mentor",
      mentorHint: ""
    },
    default: {
      lead:
        "Velocity Premium — hosted & managed. Pricing on GSignalX Service; register and book from Profile → My Services.",
      bookLabel: "Book Managed Premium",
      bookHint: "Install & maintenance pricing",
      manualLabel: "Premium Users Manual",
      manualHint: "ccity.gsignalx.cloud",
      mentorLabel: "Mentorship program",
      mentorHint: "Best process · market understanding"
    }
  };

  function esc(s) {
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function linkAttrs() {
    return 'target="_blank" rel="noopener noreferrer"';
  }

  function isDismissed() {
    try {
      return localStorage.getItem(DISMISS_KEY) === "1";
    } catch (e) {
      return false;
    }
  }

  function setDismissed(v) {
    try {
      if (v) localStorage.setItem(DISMISS_KEY, "1");
      else localStorage.removeItem(DISMISS_KEY);
    } catch (e) {}
  }

  function renderMountHtml(intent) {
    var cfg = INTENTS[intent] || INTENTS.default;
    var lead = cfg.lead
      ? '<p class="gsx-premium-lead">' + esc(cfg.lead) + "</p>"
      : "";
    function hint(h) {
      return h
        ? '<span class="gsx-premium-hint">' + esc(h) + "</span>"
        : "";
    }
    return (
      '<div class="gsx-premium-dual" data-intent="' +
      esc(intent || "default") +
      '">' +
      lead +
      '<div class="gsx-premium-actions">' +
      '<a class="gsx-premium-btn book primary" href="' +
      esc(SERVICE_PRICING_URL) +
      '" ' +
      linkAttrs() +
      ">" +
      esc(cfg.bookLabel) +
      hint(cfg.bookHint) +
      "</a>" +
      '<a class="gsx-premium-btn manual" href="' +
      esc(PREMIUM_MANUAL_URL) +
      '" ' +
      linkAttrs() +
      ">" +
      esc(cfg.manualLabel) +
      hint(cfg.manualHint) +
      "</a>" +
      '<a class="gsx-premium-btn mentor" href="' +
      esc(MENTORSHIP_URL) +
      '" ' +
      linkAttrs() +
      ">" +
      esc(cfg.mentorLabel) +
      hint(cfg.mentorHint) +
      "</a>" +
      "</div>" +
      '<p class="gsx-premium-fine">Register at <a href="' +
      esc(SERVICE_HOME_URL) +
      '" ' +
      linkAttrs() +
      ">gsignalx.cloud</a> → Profile → My Services to book Premium Velocity.</p>" +
      "</div>"
    );
  }

  function renderRailHtml() {
    var cfg = INTENTS.banner;
    return (
      '<div class="gsx-premium-rail-inner">' +
      '<div class="gsx-premium-rail-copy">' +
      '<span class="gsx-premium-rail-kicker">Upgrade</span>' +
      '<span class="gsx-premium-rail-label">' +
      esc(cfg.lead) +
      "</span>" +
      '<span class="gsx-premium-rail-sub">Book install &amp; maintenance · optional mentorship</span>' +
      "</div>" +
      '<div class="gsx-premium-actions compact">' +
      '<a class="gsx-premium-btn book primary" href="' +
      esc(SERVICE_PRICING_URL) +
      '" ' +
      linkAttrs() +
      ">" +
      esc(cfg.bookLabel) +
      "</a>" +
      '<a class="gsx-premium-btn manual" href="' +
      esc(PREMIUM_MANUAL_URL) +
      '" ' +
      linkAttrs() +
      ">" +
      esc(cfg.manualLabel) +
      "</a>" +
      '<a class="gsx-premium-btn mentor" href="' +
      esc(MENTORSHIP_URL) +
      '" ' +
      linkAttrs() +
      ">" +
      esc(cfg.mentorLabel) +
      "</a>" +
      '<button type="button" class="gsx-premium-btn dismiss" id="gsxPremiumRailDismiss" title="Hide for this browser">Dismiss</button>' +
      "</div></div>"
    );
  }

  function fillMounts(root) {
    var scope = root || document;
    scope.querySelectorAll("[data-gsx-premium]").forEach(function (node) {
      var intent = node.getAttribute("data-gsx-premium") || "default";
      node.innerHTML = renderMountHtml(intent);
    });
  }

  function injectHeaderCta(el) {
    // Header stays lean: Premium lives in Links menu + sticky rail + mounts.
    // No-op when .header-links already present (manual shell).
    if (!el || el.querySelector(".header-links") || el.querySelector(".header-cta.premium"))
      return;
  }

  function bindDismiss(rail) {
    var btn = rail.querySelector("#gsxPremiumRailDismiss");
    if (!btn || btn._gsxBound) return;
    btn._gsxBound = true;
    btn.addEventListener("click", function () {
      setDismissed(true);
      rail.hidden = true;
      rail.classList.remove("is-visible");
    });
  }

  function ensureSiteFooter() {
    var existing = document.getElementById("gsxPremiumRail");
    if (existing) {
      bindDismiss(existing);
      if (isDismissed()) {
        existing.hidden = true;
        existing.classList.remove("is-visible");
      } else {
        existing.hidden = false;
        existing.classList.add("is-visible");
      }
      return existing;
    }
    var rail = document.createElement("aside");
    rail.id = "gsxPremiumRail";
    rail.className = "gsx-premium-rail";
    rail.setAttribute("role", "complementary");
    rail.setAttribute("aria-label", "Managed Premium upgrade");
    rail.innerHTML = renderRailHtml();
    if (isDismissed()) {
      rail.hidden = true;
    } else {
      rail.classList.add("is-visible");
    }
    document.body.appendChild(rail);
    bindDismiss(rail);
    return rail;
  }

  function boot() {
    var actions = document.querySelector(".header-actions");
    if (actions) injectHeaderCta(actions);
    fillMounts();
    ensureSiteFooter();
  }

  window.GsxPremium = {
    premiumManualUrl: PREMIUM_MANUAL_URL,
    servicePricingUrl: SERVICE_PRICING_URL,
    mentorshipUrl: MENTORSHIP_URL,
    serviceHomeUrl: SERVICE_HOME_URL,
    renderMountHtml: renderMountHtml,
    renderRailHtml: renderRailHtml,
    fillMounts: fillMounts,
    injectHeaderCta: injectHeaderCta,
    ensureSiteFooter: ensureSiteFooter,
    isDismissed: isDismissed,
    setDismissed: setDismissed,
    boot: boot
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
