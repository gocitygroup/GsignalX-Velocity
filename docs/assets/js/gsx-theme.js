/* Gsignalx Velocity theme boot + toggle (shared) */
(function () {
  var KEY = "gsx-velocity-theme";
  function preferred() {
    try {
      var s = localStorage.getItem(KEY);
      if (s === "light" || s === "dark") return s;
      return window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
    } catch (e) {
      return "dark";
    }
  }
  function apply(t) {
    document.documentElement.setAttribute("data-theme", t);
    document.documentElement.style.colorScheme = t;
  }
  apply(preferred());
  window.GsxDocsTheme = {
    key: KEY,
    get: preferred,
    set: function (t) {
      apply(t);
      try { localStorage.setItem(KEY, t); } catch (e) {}
    },
    toggle: function () {
      var next = preferred() === "dark" ? "light" : "dark";
      this.set(next);
      return next;
    }
  };
})();
