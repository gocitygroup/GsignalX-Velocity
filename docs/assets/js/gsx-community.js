/* Gsignalx Velocity — desk community (Telegram channel + group + WhatsApp)
 * URLs mirrored from GocitySignalXenon COMPANY_CONFIG.contacts
 * (lib/forex-dashboard/config/company.ts).
 *
 * Channel (PRIMARY this update) — macro overview for day trading:
 *   consult the composite current driver breakdown and cited data sources
 *   for the quantitative basis. Also broadcasts / testimonials.
 * Group (secondary) — feedback / trader chat / stuck deploy.
 * WhatsApp — live meet-up / desk chat (not a Telegram replacement).
 * Distinct from MT5 alert Telegram (BotFather / VERIFY / private chat IDs).
 */
(function () {
  var CHANNEL_URL = "https://t.me/+yURbcVkPi1kxNDg0";
  var GROUP_URL = "https://t.me/+ZDosSHfUCLU1ZGY0";
  var WHATSAPP_URL = "https://chat.whatsapp.com/EemGekqMwDgKrLj0tkqYlB";
  var TV_URL =
    "https://www.tradingview.com/script/wxa7lWXl-GsignalX-is-a-trend-following/";
  var BANNER_PANELS = { deploy: 1, telegram: 1, performance: 1, community: 1, welcome: 1 };

  var MACRO_LEAD =
    "Macro overview for day trading — consult the composite current driver breakdown and the cited data sources for the quantitative basis.";

  var INTENTS = {
    default: {
      lead: MACRO_LEAD,
      channelLabel: "Trading channel · primary",
      channelHint: "Macro drivers & day-trading basis",
      groupLabel: "Trading group",
      groupHint: "Feedback & peer desk",
      whatsappLabel: "WhatsApp · meet-up",
      whatsappHint: "Live desk chat"
    },
    feedback: {
      lead: MACRO_LEAD + " Then share desk feedback in the group.",
      channelLabel: "Channel · macro (main)",
      channelHint: "Driver breakdown + cited sources",
      groupLabel: "Group · feedback",
      groupHint: "Ask traders / stuck deploy",
      whatsappLabel: "WhatsApp · meet-up",
      whatsappHint: "Live session chat"
    },
    stuck: {
      lead: "Stuck on deploy? Ask the group — or follow the channel for the day's macro overview first.",
      channelLabel: "Channel · macro (main)",
      channelHint: "Day-trading driver breakdown",
      groupLabel: "Trading group",
      groupHint: "Share redacted CONFIRM notes",
      whatsappLabel: "WhatsApp · meet-up",
      whatsappHint: "Quick desk check-in"
    },
    testimonial: {
      lead: MACRO_LEAD,
      channelLabel: "Channel · primary",
      channelHint: "Macro + process tips",
      groupLabel: "Group · discuss",
      groupHint: "Peer setups & Q&A",
      whatsappLabel: "WhatsApp · meet-up",
      whatsappHint: "Live meet-up"
    },
    macro: {
      lead: MACRO_LEAD,
      channelLabel: "Open trading channel",
      channelHint: "Composite drivers · cited sources",
      groupLabel: "Trading group",
      groupHint: "Optional peer chat",
      whatsappLabel: "WhatsApp · meet-up",
      whatsappHint: "Live desk chat"
    },
    foundation: {
      lead:
        "Chart foundation — follow the GsignalX TradingView publication while Velocity owns the MT5 book.",
      channelLabel: "Trading channel · primary",
      channelHint: "Macro drivers & day-trading basis",
      groupLabel: "Trading group",
      groupHint: "Feedback & peer desk",
      whatsappLabel: "WhatsApp · meet-up",
      whatsappHint: "Live desk chat",
      tvLabel: "TradingView · chart study",
      tvHint: "Does not place MT5 orders"
    },
    banner: {
      lead: "Macro · day trading (channel)",
      channelLabel: "Channel · main",
      channelHint: "",
      groupLabel: "Group",
      groupHint: "",
      whatsappLabel: "WhatsApp",
      whatsappHint: "",
      tvLabel: "Chart",
      tvHint: ""
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

  function renderDualCtaHtml(intent) {
    var cfg = INTENTS[intent] || INTENTS.default;
    var lead = cfg.lead
      ? '<p class="gsx-community-lead">' + esc(cfg.lead) + "</p>"
      : "";
    var chHint = cfg.channelHint
      ? '<span class="gsx-community-hint">' + esc(cfg.channelHint) + "</span>"
      : "";
    var grHint = cfg.groupHint
      ? '<span class="gsx-community-hint">' + esc(cfg.groupHint) + "</span>"
      : "";
    var waHint = cfg.whatsappHint
      ? '<span class="gsx-community-hint">' + esc(cfg.whatsappHint) + "</span>"
      : "";
    var showTv = intent === "foundation" || !!cfg.tvLabel;
    var tvHint =
      showTv && cfg.tvHint
        ? '<span class="gsx-community-hint">' + esc(cfg.tvHint) + "</span>"
        : "";
    var tvBtn = showTv
      ? '<a class="gsx-community-btn tv" href="' +
        esc(TV_URL) +
        '" ' +
        linkAttrs() +
        ">" +
        esc(cfg.tvLabel || "TradingView · chart study") +
        tvHint +
        "</a>"
      : "";
    return (
      '<div class="gsx-community-dual channel-primary" data-intent="' +
      esc(intent || "default") +
      '">' +
      lead +
      '<div class="gsx-community-actions">' +
      '<a class="gsx-community-btn channel primary" href="' +
      esc(CHANNEL_URL) +
      '" ' +
      linkAttrs() +
      ">" +
      esc(cfg.channelLabel) +
      chHint +
      "</a>" +
      '<a class="gsx-community-btn group secondary" href="' +
      esc(GROUP_URL) +
      '" ' +
      linkAttrs() +
      ">" +
      esc(cfg.groupLabel) +
      grHint +
      "</a>" +
      '<a class="gsx-community-btn whatsapp" href="' +
      esc(WHATSAPP_URL) +
      '" ' +
      linkAttrs() +
      ">" +
      esc(cfg.whatsappLabel || "WhatsApp · meet-up") +
      waHint +
      "</a>" +
      tvBtn +
      "</div></div>"
    );
  }

  function renderBannerHtml() {
    var cfg = INTENTS.banner;
    return (
      '<div class="gsx-community-strip-inner">' +
      '<span class="gsx-community-strip-label">' +
      esc(cfg.lead) +
      "</span>" +
      '<div class="gsx-community-actions compact">' +
      '<a class="gsx-community-btn channel primary" href="' +
      esc(CHANNEL_URL) +
      '" ' +
      linkAttrs() +
      ">" +
      esc(cfg.channelLabel) +
      "</a>" +
      '<a class="gsx-community-btn group secondary" href="' +
      esc(GROUP_URL) +
      '" ' +
      linkAttrs() +
      ">" +
      esc(cfg.groupLabel) +
      "</a>" +
      '<a class="gsx-community-btn whatsapp" href="' +
      esc(WHATSAPP_URL) +
      '" ' +
      linkAttrs() +
      ">" +
      esc(cfg.whatsappLabel || "WhatsApp") +
      "</a>" +
      '<a class="gsx-community-btn tv" href="' +
      esc(TV_URL) +
      '" ' +
      linkAttrs() +
      ">" +
      esc(cfg.tvLabel || "Chart") +
      "</a>" +
      '<a class="gsx-community-btn more" href="#community" data-tab="community">More →</a>' +
      "</div></div>"
    );
  }

  function injectHeaderCtas(el) {
    // Header stays lean: community lives in Links menu + chapter mounts + banner.
    if (!el || el.querySelector(".header-links") || el.querySelector(".header-cta.community"))
      return;
  }

  function fillMounts(root) {
    var scope = root || document;
    scope.querySelectorAll("[data-gsx-community]").forEach(function (node) {
      var intent = node.getAttribute("data-gsx-community") || "default";
      node.innerHTML = renderDualCtaHtml(intent);
    });
  }

  function ensureBanner() {
    var existing = document.getElementById("gsxCommunityBanner");
    if (existing) return existing;
    var header = document.querySelector(".site-header");
    if (!header) return null;
    var banner = document.createElement("div");
    banner.id = "gsxCommunityBanner";
    banner.className = "gsx-community-strip";
    banner.hidden = true;
    banner.setAttribute("role", "region");
    banner.setAttribute("aria-label", "Macro day-trading channel");
    banner.innerHTML = renderBannerHtml();
    header.insertAdjacentElement("afterend", banner);
    return banner;
  }

  function syncBanner(panelId) {
    var banner = ensureBanner();
    if (!banner) return;
    var show = !!BANNER_PANELS[panelId];
    banner.hidden = !show;
    banner.classList.toggle("is-visible", show);
  }

  function boot() {
    var actions = document.querySelector(".header-actions");
    if (actions) injectHeaderCtas(actions);
    ensureBanner();
    fillMounts();
    var hash = (location.hash || "#welcome").slice(1) || "welcome";
    syncBanner(hash);
  }

  window.GsxCommunity = {
    channelUrl: CHANNEL_URL,
    groupUrl: GROUP_URL,
    whatsappUrl: WHATSAPP_URL,
    tvUrl: TV_URL,
    channelLabel: "Trading channel",
    groupLabel: "Trading group",
    whatsappLabel: "WhatsApp meet-up",
    tvLabel: "TradingView chart study",
    macroLead: MACRO_LEAD,
    primary: "channel",
    renderDualCtaHtml: renderDualCtaHtml,
    renderBannerHtml: renderBannerHtml,
    injectHeaderCtas: injectHeaderCtas,
    fillMounts: fillMounts,
    syncBanner: syncBanner,
    boot: boot
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
