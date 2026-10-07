# -*- coding: utf-8 -*-
"""Daily Bias Follow chapter (EN HTML + i18n key catalog) for Velocity public manual."""
from _manual_version import MANUAL_VERSION

# i18n keys for bias-follow.json (English values; locales seed from these).
BIAS_I18N = {
    "bias-follow.kicker1": "Velocity " + MANUAL_VERSION + " · Daily Bias Follow",
    "bias-follow.h11": "Filter signal sides · stay one-directional",
    "bias-follow.lede1": (
        "Bias is <strong>chart-aligned</strong> to each D1 bar’s open→close outcome — "
        "<strong>not EMA</strong>, not MACD, and not joinDir. Engines still produce BUY/SELL; "
        "an armed bias lane <strong>filters</strong> which sides may enter via FollowDir."
    ),
    "bias-follow.riskDoNot": "DO NOT OVERRIDE · Desk contract",
    "bias-follow.riskDoNotBody": (
        "GSignalX opens · ProfitScouter closes · STOP ≠ FLAT. Bias never closes tickets. "
        "While a lane is armed, entries stay one-sided to that lane’s live direction."
    ),
    "bias-follow.h21": "Three lanes + Signal clear",
    "bias-follow.th1": "Lane",
    "bias-follow.th2": "Meaning",
    "bias-follow.th3": "While armed",
    "bias-follow.td1": "Daily",
    "bias-follow.td2": "Floating: live mid vs today’s D1 open (forming candle)",
    "bias-follow.td3": "BULL→BUY · BEAR→SELL · NEUT→WAIT (block)",
    "bias-follow.td4": "Pre-D",
    "bias-follow.td5": "Static: last closed D1 close vs that bar’s open",
    "bias-follow.td6": "Same live one-side mapping",
    "bias-follow.td7": "Third-D",
    "bias-follow.td8": "Static: two D1 bars back (rates[2])",
    "bias-follow.td9": "Same live one-side mapping",
    "bias-follow.td10": "Signal",
    "bias-follow.td11": "Clear armed lane — default any-dir follow",
    "bias-follow.td12": "AUTO (both joinDir sides)",
    "bias-follow.h22": "Desk vs chart",
    "bias-follow.li1": (
        "<strong>Trade Center</strong> — click Daily / Pre-D / Third-D / Signal. "
        "Desk-wide: each roster pair gets FollowDir from <em>that</em> pair’s bias for the chosen lane."
    ),
    "bias-follow.li2": "<strong>Chart panel</strong> — same chips apply to this symbol only.",
    "bias-follow.li3": (
        "Row bias cells arm the <strong>lane</strong> (not “copy this row’s value onto everyone”)."
    ),
    "bias-follow.li4": "Manual Mode / FDIR pads clear the armed bias lane.",
    "bias-follow.liveLabel": "Live one-side while armed",
    "bias-follow.liveBody": (
        "Effective FollowDir tracks the armed lane’s <strong>live</strong> direction. "
        "NEUT blocks new entries (WAIT). Signal returns to AUTO. Bias never closes positions — "
        "Scouter still banks winners. Plan: "
        "<a href=\"plans/DAILY_BIAS_FOLLOW_PLAN.md\"><code>docs/plans/DAILY_BIAS_FOLLOW_PLAN.md</code></a>."
    ),
    "bias-follow.h23": "Profit playbook",
    "bias-follow.lede2": "Structure first, then size, then harvest. Bias is a filter — not an exit.",
    "bias-follow.ol1": (
        "<strong>Topology A</strong> — Trade Center DeskExecute ON, FIXED practice lot, Scouter CASH ON."
    ),
    "bias-follow.ol2": (
        "<strong>Read the columns</strong> — Daily / Pre / Third. Prefer Daily when the session is open."
    ),
    "bias-follow.ol3": (
        "<strong>Arm once</strong> — click desk Daily to filter the fleet. Use Signal when you want any side again."
    ),
    "bias-follow.ol4": (
        "<strong>NEUT</strong> — if Daily is doji (WAIT), wait for structure or clear to Signal; do not force size."
    ),
    "bias-follow.ol5": (
        "<strong>Bank with Scouter</strong> — never use a bias click as an exit. STOP blocks entries; it does not flatten."
    ),
    "bias-follow.doHeader": "Do",
    "bias-follow.dontHeader": "Don’t",
    "bias-follow.do1": "Arm Daily when overall BULL/BEAR and liquidity is open",
    "bias-follow.dont1": "Expect bias to close losers or winners",
    "bias-follow.do2": "Use Signal to return to default any-dir follow",
    "bias-follow.dont2": "Fight Daily BEAR with forced BUY FollowDir",
    "bias-follow.do3": "Keep Scouter owning exits",
    "bias-follow.dont3": "Treat NEUT as “both sides allowed” — it is WAIT",
    "chapters.bias-follow.title": "Daily Bias Follow",
    "chapters.bias-follow.short": "Bias",
}

BIAS_FOLLOW_CHAPTER = r'''
    <!-- DAILY BIAS FOLLOW -->
    <section class="panel" id="bias-follow" data-title="Daily Bias Follow" data-short="Bias">
      <div class="kicker" data-i18n="bias-follow.kicker1">Velocity ''' + MANUAL_VERSION + r''' · Daily Bias Follow</div>
      <h1 data-i18n="bias-follow.h11">Filter signal sides · stay one-directional</h1>
      <p class="lede" data-i18n-html="bias-follow.lede1">Bias is <strong>chart-aligned</strong> to each D1 bar’s open→close outcome — <strong>not EMA</strong>, not MACD, and not joinDir. Engines still produce BUY/SELL; an armed bias lane <strong>filters</strong> which sides may enter via FollowDir.</p>

      <div class="risk-block risk-do-not-override" data-gsx-risk-block="do-not-override">
        <strong class="risk-block-label" data-i18n="bias-follow.riskDoNot">DO NOT OVERRIDE · Desk contract</strong>
        <div class="risk-block-body">
          <p data-i18n="bias-follow.riskDoNotBody">GSignalX opens · ProfitScouter closes · STOP ≠ FLAT. Bias never closes tickets. While a lane is armed, entries stay one-sided to that lane’s live direction.</p>
        </div>
      </div>

      <h2 data-i18n="bias-follow.h21">Three lanes + Signal clear</h2>
      <table>
        <thead><tr>
          <th data-i18n="bias-follow.th1">Lane</th>
          <th data-i18n="bias-follow.th2">Meaning</th>
          <th data-i18n="bias-follow.th3">While armed</th>
        </tr></thead>
        <tbody>
          <tr>
            <td><strong data-i18n="bias-follow.td1">Daily</strong></td>
            <td data-i18n="bias-follow.td2">Floating: live mid vs today’s D1 open (forming candle)</td>
            <td data-i18n="bias-follow.td3">BULL→BUY · BEAR→SELL · NEUT→WAIT (block)</td>
          </tr>
          <tr>
            <td><strong data-i18n="bias-follow.td4">Pre-D</strong></td>
            <td data-i18n="bias-follow.td5">Static: last closed D1 close vs that bar’s open</td>
            <td data-i18n="bias-follow.td6">Same live one-side mapping</td>
          </tr>
          <tr>
            <td><strong data-i18n="bias-follow.td7">Third-D</strong></td>
            <td data-i18n="bias-follow.td8">Static: two D1 bars back (rates[2])</td>
            <td data-i18n="bias-follow.td9">Same live one-side mapping</td>
          </tr>
          <tr>
            <td><strong data-i18n="bias-follow.td10">Signal</strong></td>
            <td data-i18n="bias-follow.td11">Clear armed lane — default any-dir follow</td>
            <td data-i18n="bias-follow.td12">AUTO (both joinDir sides)</td>
          </tr>
        </tbody>
      </table>

      <h2 data-i18n="bias-follow.h22">Desk vs chart</h2>
      <ul>
        <li data-i18n-html="bias-follow.li1"><strong>Trade Center</strong> — click Daily / Pre-D / Third-D / Signal. Desk-wide: each roster pair gets FollowDir from <em>that</em> pair’s bias for the chosen lane.</li>
        <li data-i18n-html="bias-follow.li2"><strong>Chart panel</strong> — same chips apply to this symbol only.</li>
        <li data-i18n-html="bias-follow.li3">Row bias cells arm the <strong>lane</strong> (not “copy this row’s value onto everyone”).</li>
        <li data-i18n="bias-follow.li4">Manual Mode / FDIR pads clear the armed bias lane.</li>
      </ul>

      <div class="callout gold">
        <strong class="label" data-i18n="bias-follow.liveLabel">Live one-side while armed</strong>
        <span data-i18n-html="bias-follow.liveBody">Effective FollowDir tracks the armed lane’s <strong>live</strong> direction. NEUT blocks new entries (WAIT). Signal returns to AUTO. Bias never closes positions — Scouter still banks winners. Plan: <a href="plans/DAILY_BIAS_FOLLOW_PLAN.md"><code>docs/plans/DAILY_BIAS_FOLLOW_PLAN.md</code></a>.</span>
      </div>

      <h2 data-i18n="bias-follow.h23">Profit playbook</h2>
      <p class="lede" data-i18n="bias-follow.lede2">Structure first, then size, then harvest. Bias is a filter — not an exit.</p>
      <ol>
        <li data-i18n-html="bias-follow.ol1"><strong>Topology A</strong> — Trade Center DeskExecute ON, FIXED practice lot, Scouter CASH ON.</li>
        <li data-i18n-html="bias-follow.ol2"><strong>Read the columns</strong> — Daily / Pre / Third. Prefer Daily when the session is open.</li>
        <li data-i18n-html="bias-follow.ol3"><strong>Arm once</strong> — click desk Daily to filter the fleet. Use Signal when you want any side again.</li>
        <li data-i18n-html="bias-follow.ol4"><strong>NEUT</strong> — if Daily is doji (WAIT), wait for structure or clear to Signal; do not force size.</li>
        <li data-i18n-html="bias-follow.ol5"><strong>Bank with Scouter</strong> — never use a bias click as an exit. STOP blocks entries; it does not flatten.</li>
      </ol>

      <table>
        <thead><tr>
          <th data-i18n="bias-follow.doHeader">Do</th>
          <th data-i18n="bias-follow.dontHeader">Don’t</th>
        </tr></thead>
        <tbody>
          <tr><td data-i18n="bias-follow.do1">Arm Daily when overall BULL/BEAR and liquidity is open</td><td data-i18n="bias-follow.dont1">Expect bias to close losers or winners</td></tr>
          <tr><td data-i18n="bias-follow.do2">Use Signal to return to default any-dir follow</td><td data-i18n="bias-follow.dont2">Fight Daily BEAR with forced BUY FollowDir</td></tr>
          <tr><td data-i18n="bias-follow.do3">Keep Scouter owning exits</td><td data-i18n="bias-follow.dont3">Treat NEUT as “both sides allowed” — it is WAIT</td></tr>
        </tbody>
      </table>
    </section>
'''
