# -*- coding: utf-8 -*-
"""EN catalog + per-locale translations for Native TP manual keys (DRY)."""
from __future__ import annotations

# Stable keys only. HTML embeds EN via data-i18n*; generator merges into chapter JSON.

TP_EN: dict[str, str] = {
    # --- welcome ---
    "welcome.liTp": (
        "<strong>Native TP</strong> — optional Median/Average tip level; "
        "ON applies broker TP to matching open positions "
        '(<a href="#integrations">Integrations</a> · <a href="#desk213">Best Use</a>).'
    ),
    "welcome.p1": (
        'All on-chart controls: <a href="#desk213">System UI Best Use</a> · '
        '<a href="#integrations">Integrations</a> (Cloud · TG · bus · OCO · Native TP) · '
        "Deploy: <code>docs/RELEASE_v2.20_Integrations_OCO.md</code> · "
        "TP cut: <code>docs/RELEASE_v2.20_Native_TP.md</code> · "
        "Practice: <code>docs/PRACTICE_LIVE_SIM_20_50_100.md</code>"
    ),
    # --- integrations capability row ---
    "integrations.td29": "<strong>Native TP</strong>",
    "integrations.td30": "Structure tip level + broker TP on open tickets",
    "integrations.td31": (
        "Default <strong>OFF</strong> · Chart + Trade Center chips · shared GVs · "
        "ON applies tip to matching positions · optional Scouter "
        "<code>NATIVE-TP</code> when closeOnHit"
    ),
    "integrations.h24": "Native TP (Chart + Trade Center)",
    "integrations.p3": (
        "Desk-wide <strong>BTN_TP</strong> / <strong>BTN_TPTYPE</strong> share "
        "<code>GSX_MS_TPENABLE_*</code> / <code>GSX_MS_TPTYPE_*</code>. "
        "Toggle is O(1); Desk drains open pairs on the timer (no click bootstrap). "
        "Engineer deep-dive: <code>docs/TP_NATIVE.md</code>."
    ),
    "integrations.th6": "Chip",
    "integrations.th7": "Meaning",
    "integrations.td32": "Master OFF — no HLINE, no broker TP push, no pending hits",
    "integrations.td33": "Tip active; matching open tickets get PositionModify TP (SL kept)",
    "integrations.td34": "Distance = median of swing diffs (even → mean of middles)",
    "integrations.td35": "Distance = average of all swing diffs",
    "integrations.li7": (
        "Native TP default <strong>OFF</strong>; turn ON only when you want structure TP "
        "on the book."
    ),
    "integrations.p2": (
        "Operator cut notes: <code>docs/RELEASE_v2.20_Integrations_OCO.md</code> · "
        "<code>docs/RELEASE_v2.20_Native_TP.md</code> · "
        'Cloud how-to: <a href="#cloud" data-tab="cloud">Cloud Trading</a> · '
        "<code>docs/CLOUD_TRADING.md</code>."
    ),
    # --- desk213 ---
    "desk213.tdTp": "<strong>TP ON / OFF</strong>",
    "desk213.tdTp2": (
        "Native tip master (shared desk GV). ON draws level and pushes broker TP to "
        "matching open positions. See <a href=\"#integrations\">Integrations</a>."
    ),
    "desk213.tdTpType": "<strong>Median / Average</strong>",
    "desk213.tdTpType2": "Tip distance type (visible when TP ON)",
    "desk213.tdTpChart": "<strong>TP ON / OFF</strong>",
    "desk213.tdTpChart2": (
        "Same desk GV as Trade Center; chart tip HLINE + broker TP sync for this magic"
    ),
    "desk213.tdTpTypeChart": "<strong>Median / Average</strong>",
    "desk213.tdTpTypeChart2": "Tip type (shown when TP ON)",
    # --- ui ---
    "ui.links.integrations.hint": "Cloud · TG · bus · OCO · ScoutLink · TP",
}

# Per-lang overlays (must cover every TP_EN key for audit EN-parity FAIL).
TP_I18N: dict[str, dict[str, str]] = {
    "it": {
        "welcome.liTp": (
            "<strong>TP nativo</strong> — livello tip Median/Average opzionale; "
            "ON applica il TP broker alle posizioni aperte corrispondenti "
            '(<a href="#integrations">Integrazioni</a> · <a href="#desk213">Best Use</a>).'
        ),
        "welcome.p1": (
            'Tutti i controlli on-chart: <a href="#desk213">System UI Best Use</a> · '
            '<a href="#integrations">Integrazioni</a> (Cloud · TG · bus · OCO · TP nativo) · '
            "Deploy: <code>docs/RELEASE_v2.20_Integrations_OCO.md</code> · "
            "TP: <code>docs/RELEASE_v2.20_Native_TP.md</code> · "
            "Practice: <code>docs/PRACTICE_LIVE_SIM_20_50_100.md</code>"
        ),
        "integrations.td29": "<strong>TP nativo</strong>",
        "integrations.td30": "Livello tip di struttura + TP broker sui ticket aperti",
        "integrations.td31": (
            "Default <strong>OFF</strong> · chip Chart + Trade Center · GV condivise · "
            "ON applica il tip alle posizioni · Scouter opzionale "
            "<code>NATIVE-TP</code> con closeOnHit"
        ),
        "integrations.h24": "TP nativo (Chart + Trade Center)",
        "integrations.p3": (
            "I chip desk <strong>BTN_TP</strong> / <strong>BTN_TPTYPE</strong> condividono "
            "<code>GSX_MS_TPENABLE_*</code> / <code>GSX_MS_TPTYPE_*</code>. "
            "Il toggle è O(1); il Desk scarica le coppie aperte sul timer. "
            "Dettaglio tecnico: <code>docs/TP_NATIVE.md</code>."
        ),
        "integrations.th6": "Pulsante",
        "integrations.th7": "Significato",
        "integrations.td32": "Master OFF — niente HLINE, niente push TP broker, niente hit pending",
        "integrations.td33": "Tip attivo; i ticket aperti corrispondenti ricevono PositionModify TP (SL invariato)",
        "integrations.td34": "Distanza = mediana delle differenze di swing",
        "integrations.td35": "Distanza = media di tutte le differenze di swing",
        "integrations.li7": (
            "TP nativo default <strong>OFF</strong>; attiva ON solo se vuoi il TP di struttura sul book."
        ),
        "integrations.p2": (
            "Note operative: <code>docs/RELEASE_v2.20_Integrations_OCO.md</code> · "
            "<code>docs/RELEASE_v2.20_Native_TP.md</code> · "
            'Cloud: <a href="#cloud" data-tab="cloud">Cloud Trading</a> · '
            "<code>docs/CLOUD_TRADING.md</code>."
        ),
        "desk213.tdTp": "<strong>TP ON / OFF</strong>",
        "desk213.tdTp2": (
            "Master tip nativo (GV desk condivisa). ON disegna il livello e invia il TP broker "
            'alle posizioni corrispondenti. Vedi <a href="#integrations">Integrazioni</a>.'
        ),
        "desk213.tdTpType": "<strong>Median / Average</strong>",
        "desk213.tdTpType2": "Tipo distanza tip (visibile con TP ON)",
        "desk213.tdTpChart": "<strong>TP ON / OFF</strong>",
        "desk213.tdTpChart2": (
            "Stessa GV del Trade Center; HLINE tip + sync TP broker per questo magic"
        ),
        "desk213.tdTpTypeChart": "<strong>Median / Average</strong>",
        "desk213.tdTpTypeChart2": "Tipo tip (mostrato con TP ON)",
        "ui.links.integrations.hint": "Cloud · TG · bus · OCO · ScoutLink · TP",
    },
    "fr": {
        "welcome.liTp": (
            "<strong>TP natif</strong> — niveau tip Median/Average optionnel ; "
            "ON applique le TP courtier aux positions ouvertes correspondantes "
            '(<a href="#integrations">Intégrations</a> · <a href="#desk213">Best Use</a>).'
        ),
        "welcome.p1": (
            'Tous les contrôles on-chart : <a href="#desk213">System UI Best Use</a> · '
            '<a href="#integrations">Intégrations</a> (Cloud · TG · bus · OCO · TP natif) · '
            "Deploy : <code>docs/RELEASE_v2.20_Integrations_OCO.md</code> · "
            "TP : <code>docs/RELEASE_v2.20_Native_TP.md</code> · "
            "Practice : <code>docs/PRACTICE_LIVE_SIM_20_50_100.md</code>"
        ),
        "integrations.td29": "<strong>TP natif</strong>",
        "integrations.td30": "Niveau tip de structure + TP courtier sur tickets ouverts",
        "integrations.td31": (
            "Par défaut <strong>OFF</strong> · chips Chart + Trade Center · GV partagées · "
            "ON applique le tip aux positions · Scouter optionnel "
            "<code>NATIVE-TP</code> si closeOnHit"
        ),
        "integrations.h24": "TP natif (Chart + Trade Center)",
        "integrations.p3": (
            "Les chips desk <strong>BTN_TP</strong> / <strong>BTN_TPTYPE</strong> partagent "
            "<code>GSX_MS_TPENABLE_*</code> / <code>GSX_MS_TPTYPE_*</code>. "
            "Le basculement est O(1) ; le Desk draine les paires ouvertes au timer. "
            "Détail ingénieur : <code>docs/TP_NATIVE.md</code>."
        ),
        "integrations.th6": "Puce",
        "integrations.th7": "Signification",
        "integrations.td32": "Master OFF — pas de HLINE, pas de push TP courtier, pas d’hits pending",
        "integrations.td33": "Tip actif ; tickets ouverts correspondants reçoivent PositionModify TP (SL conservé)",
        "integrations.td34": "Distance = médiane des écarts de swing",
        "integrations.td35": "Distance = moyenne de tous les écarts de swing",
        "integrations.li7": (
            "TP natif par défaut <strong>OFF</strong> ; activez ON seulement pour un TP de structure sur le book."
        ),
        "integrations.p2": (
            "Notes opérateur : <code>docs/RELEASE_v2.20_Integrations_OCO.md</code> · "
            "<code>docs/RELEASE_v2.20_Native_TP.md</code> · "
            'Cloud : <a href="#cloud" data-tab="cloud">Cloud Trading</a> · '
            "<code>docs/CLOUD_TRADING.md</code>."
        ),
        "desk213.tdTp": "<strong>TP ON / OFF</strong>",
        "desk213.tdTp2": (
            "Master tip natif (GV desk partagée). ON trace le niveau et pousse le TP courtier "
            'vers les positions correspondantes. Voir <a href="#integrations">Intégrations</a>.'
        ),
        "desk213.tdTpType": "<strong>Median / Average</strong>",
        "desk213.tdTpType2": "Type de distance tip (visible si TP ON)",
        "desk213.tdTpChart": "<strong>TP ON / OFF</strong>",
        "desk213.tdTpChart2": (
            "Même GV que Trade Center ; HLINE tip + sync TP courtier pour ce magic"
        ),
        "desk213.tdTpTypeChart": "<strong>Median / Average</strong>",
        "desk213.tdTpTypeChart2": "Type tip (affiché si TP ON)",
        "ui.links.integrations.hint": "Cloud · TG · bus · OCO · ScoutLink · TP",
    },
    "ru": {
        "welcome.liTp": (
            "<strong>Нативный TP</strong> — опциональный уровень tip Median/Average; "
            "ON ставит брокерский TP на подходящие открытые позиции "
            '(<a href="#integrations">Интеграции</a> · <a href="#desk213">Best Use</a>).'
        ),
        "welcome.p1": (
            'Все on-chart элементы: <a href="#desk213">System UI Best Use</a> · '
            '<a href="#integrations">Интеграции</a> (Cloud · TG · bus · OCO · Native TP) · '
            "Deploy: <code>docs/RELEASE_v2.20_Integrations_OCO.md</code> · "
            "TP: <code>docs/RELEASE_v2.20_Native_TP.md</code> · "
            "Practice: <code>docs/PRACTICE_LIVE_SIM_20_50_100.md</code>"
        ),
        "integrations.td29": "<strong>Нативный TP</strong>",
        "integrations.td30": "Структурный tip + брокерский TP на открытых тикетах",
        "integrations.td31": (
            "По умолчанию <strong>OFF</strong> · чипы Chart + Trade Center · общие GV · "
            "ON применяет tip к позициям · опционально Scouter "
            "<code>NATIVE-TP</code> при closeOnHit"
        ),
        "integrations.h24": "Нативный TP (Chart + Trade Center)",
        "integrations.p3": (
            "Чипы desk <strong>BTN_TP</strong> / <strong>BTN_TPTYPE</strong> делят "
            "<code>GSX_MS_TPENABLE_*</code> / <code>GSX_MS_TPTYPE_*</code>. "
            "Переключение O(1); Desk дренирует открытые пары по таймеру. "
            "Инженерно: <code>docs/TP_NATIVE.md</code>."
        ),
        "integrations.th6": "Чип",
        "integrations.th7": "Смысл",
        "integrations.td32": "Master OFF — нет HLINE, нет push брокерского TP, нет pending hit",
        "integrations.td33": "Tip активен; подходящие открытые тикеты получают PositionModify TP (SL сохранён)",
        "integrations.td34": "Дистанция = медиана swing-разниц",
        "integrations.td35": "Дистанция = среднее всех swing-разниц",
        "integrations.li7": (
            "Нативный TP по умолчанию <strong>OFF</strong>; включайте ON только для структурного TP на книге."
        ),
        "integrations.p2": (
            "Операторские заметки: <code>docs/RELEASE_v2.20_Integrations_OCO.md</code> · "
            "<code>docs/RELEASE_v2.20_Native_TP.md</code> · "
            'Cloud: <a href="#cloud" data-tab="cloud">Cloud Trading</a> · '
            "<code>docs/CLOUD_TRADING.md</code>."
        ),
        "desk213.tdTp": "<strong>TP ON / OFF</strong>",
        "desk213.tdTp2": (
            "Master нативного tip (общий desk GV). ON рисует уровень и ставит брокерский TP "
            'на подходящие позиции. См. <a href="#integrations">Интеграции</a>.'
        ),
        "desk213.tdTpType": "<strong>Median / Average</strong>",
        "desk213.tdTpType2": "Тип дистанции tip (виден при TP ON)",
        "desk213.tdTpChart": "<strong>TP ON / OFF</strong>",
        "desk213.tdTpChart2": (
            "Тот же GV, что у Trade Center; HLINE tip + sync брокерского TP для этого magic"
        ),
        "desk213.tdTpTypeChart": "<strong>Median / Average</strong>",
        "desk213.tdTpTypeChart2": "Тип tip (показан при TP ON)",
        "ui.links.integrations.hint": "Cloud · TG · bus · OCO · ScoutLink · TP",
    },
    "ar": {
        "welcome.liTp": (
            "<strong>Native TP</strong> — مستوى tip اختياري Median/Average؛ "
            "عند التشغيل يطبّق TP الوسيط على الصفقات المفتوحة المطابقة "
            '(<a href="#integrations">التكاملات</a> · <a href="#desk213">Best Use</a>).'
        ),
        "welcome.p1": (
            'كل عناصر الرسم: <a href="#desk213">System UI Best Use</a> · '
            '<a href="#integrations">التكاملات</a> (Cloud · TG · bus · OCO · Native TP) · '
            "Deploy: <code>docs/RELEASE_v2.20_Integrations_OCO.md</code> · "
            "TP: <code>docs/RELEASE_v2.20_Native_TP.md</code> · "
            "Practice: <code>docs/PRACTICE_LIVE_SIM_20_50_100.md</code>"
        ),
        "integrations.td29": "<strong>جني ربح أصلي</strong>",
        "integrations.td30": "مستوى tip هيكلي + TP وسيط على التذاكر المفتوحة",
        "integrations.td31": (
            "الافتراضي <strong>OFF</strong> · شرائح Chart + Trade Center · متغيرات مشتركة · "
            "ON يطبّق tip على الصفقات · Scouter اختياري "
            "<code>NATIVE-TP</code> مع closeOnHit"
        ),
        "integrations.h24": "جني الربح الأصلي (Chart + Trade Center)",
        "integrations.p3": (
            "شرائح المكتب <strong>BTN_TP</strong> / <strong>BTN_TPTYPE</strong> تشارك "
            "<code>GSX_MS_TPENABLE_*</code> / <code>GSX_MS_TPTYPE_*</code>. "
            "التبديل فوري O(1)؛ المكتب يصرف الأزواج المفتوحة عبر المؤقت. "
            "مرجع هندسي: <code>docs/TP_NATIVE.md</code>."
        ),
        "integrations.th6": "الشريحة",
        "integrations.th7": "المعنى",
        "integrations.td32": "Master OFF — بلا HLINE ولا دفع TP وسيط ولا hits معلّقة",
        "integrations.td33": "tip نشط؛ التذاكر المفتوحة المطابقة تحصل على PositionModify TP (مع الإبقاء على SL)",
        "integrations.td34": "المسافة = وسيط فروقات الـ swing",
        "integrations.td35": "المسافة = متوسط كل فروقات الـ swing",
        "integrations.li7": (
            "Native TP افتراضيًا <strong>OFF</strong>؛ فعّل ON فقط عندما تريد TP هيكليًا على الدفتر."
        ),
        "integrations.p2": (
            "ملاحظات التشغيل: <code>docs/RELEASE_v2.20_Integrations_OCO.md</code> · "
            "<code>docs/RELEASE_v2.20_Native_TP.md</code> · "
            'Cloud: <a href="#cloud" data-tab="cloud">Cloud Trading</a> · '
            "<code>docs/CLOUD_TRADING.md</code>."
        ),
        "desk213.tdTp": "<strong>TP ON / OFF</strong>",
        "desk213.tdTp2": (
            "مفتاح tip الأصلي (GV مشترك). ON يرسم المستوى ويدفع TP الوسيط "
            'للصفقات المطابقة. انظر <a href="#integrations">التكاملات</a>.'
        ),
        "desk213.tdTpType": "<strong>Median / Average</strong>",
        "desk213.tdTpType2": "نوع مسافة tip (يظهر عند TP ON)",
        "desk213.tdTpChart": "<strong>TP ON / OFF</strong>",
        "desk213.tdTpChart2": (
            "نفس GV لـ Trade Center؛ HLINE tip ومزامنة TP الوسيط لهذا magic"
        ),
        "desk213.tdTpTypeChart": "<strong>Median / Average</strong>",
        "desk213.tdTpTypeChart2": "نوع tip (يُعرض عند TP ON)",
        "ui.links.integrations.hint": "Cloud · TG · bus · OCO · ScoutLink · TP",
    },
    "zh": {
        "welcome.liTp": (
            "<strong>原生 TP</strong> — 可选 Median/Average tip 水平；"
            "开启后对匹配的持仓写入券商 TP"
            '（<a href="#integrations">集成</a> · <a href="#desk213">Best Use</a>）。'
        ),
        "welcome.p1": (
            '全部图表控件：<a href="#desk213">System UI Best Use</a> · '
            '<a href="#integrations">集成</a>（Cloud · TG · bus · OCO · 原生 TP）· '
            "Deploy：<code>docs/RELEASE_v2.20_Integrations_OCO.md</code> · "
            "TP：<code>docs/RELEASE_v2.20_Native_TP.md</code> · "
            "Practice：<code>docs/PRACTICE_LIVE_SIM_20_50_100.md</code>"
        ),
        "integrations.td29": "<strong>原生 TP</strong>",
        "integrations.td30": "结构 tip 水平 + 对持仓写入券商 TP",
        "integrations.td31": (
            "默认 <strong>OFF</strong> · Chart + Trade Center 芯片 · 共享 GV · "
            "开启后对匹配仓位应用 tip · 可选 Scouter "
            "<code>NATIVE-TP</code>（closeOnHit）"
        ),
        "integrations.h24": "原生 TP（Chart + Trade Center）",
        "integrations.p3": (
            "桌面 <strong>BTN_TP</strong> / <strong>BTN_TPTYPE</strong> 共享 "
            "<code>GSX_MS_TPENABLE_*</code> / <code>GSX_MS_TPTYPE_*</code>。"
            "切换为 O(1)；Desk 在定时器上消化未平仓品种。"
            "工程说明：<code>docs/TP_NATIVE.md</code>。"
        ),
        "integrations.th6": "芯片",
        "integrations.th7": "含义",
        "integrations.td32": "总开关 OFF — 无线、不推送券商 TP、无 pending hit",
        "integrations.td33": "tip 生效；匹配持仓 PositionModify TP（保留 SL）",
        "integrations.td34": "距离 = swing 差值中位数",
        "integrations.td35": "距离 = 全部 swing 差值平均",
        "integrations.li7": (
            "原生 TP 默认 <strong>OFF</strong>；仅在需要结构 TP 时打开。"
        ),
        "integrations.p2": (
            "运营说明：<code>docs/RELEASE_v2.20_Integrations_OCO.md</code> · "
            "<code>docs/RELEASE_v2.20_Native_TP.md</code> · "
            'Cloud：<a href="#cloud" data-tab="cloud">Cloud Trading</a> · '
            "<code>docs/CLOUD_TRADING.md</code>。"
        ),
        "desk213.tdTp": "<strong>TP ON / OFF</strong>",
        "desk213.tdTp2": (
            "原生 tip 总开关（共享 desk GV）。开启后画线并对匹配持仓写入券商 TP。"
            '见 <a href="#integrations">集成</a>。'
        ),
        "desk213.tdTpType": "<strong>Median / Average</strong>",
        "desk213.tdTpType2": "tip 距离类型（TP ON 时可见）",
        "desk213.tdTpChart": "<strong>TP ON / OFF</strong>",
        "desk213.tdTpChart2": (
            "与 Trade Center 相同 GV；本 magic 的 tip 水平线 + 券商 TP 同步"
        ),
        "desk213.tdTpTypeChart": "<strong>Median / Average</strong>",
        "desk213.tdTpTypeChart2": "tip 类型（TP ON 时显示）",
        "ui.links.integrations.hint": "Cloud · TG · bus · OCO · ScoutLink · TP",
    },
    "es": {
        "welcome.liTp": (
            "<strong>TP nativo</strong> — nivel tip Median/Average opcional; "
            "ON aplica el TP del bróker a las posiciones abiertas coincidentes "
            '(<a href="#integrations">Integraciones</a> · <a href="#desk213">Best Use</a>).'
        ),
        "welcome.p1": (
            'Todos los controles on-chart: <a href="#desk213">System UI Best Use</a> · '
            '<a href="#integrations">Integraciones</a> (Cloud · TG · bus · OCO · TP nativo) · '
            "Deploy: <code>docs/RELEASE_v2.20_Integrations_OCO.md</code> · "
            "TP: <code>docs/RELEASE_v2.20_Native_TP.md</code> · "
            "Practice: <code>docs/PRACTICE_LIVE_SIM_20_50_100.md</code>"
        ),
        "integrations.td29": "<strong>TP nativo</strong>",
        "integrations.td30": "Nivel tip de estructura + TP de bróker en tickets abiertos",
        "integrations.td31": (
            "Por defecto <strong>OFF</strong> · chips Chart + Trade Center · GV compartidas · "
            "ON aplica el tip a posiciones · Scouter opcional "
            "<code>NATIVE-TP</code> con closeOnHit"
        ),
        "integrations.h24": "TP nativo (Chart + Trade Center)",
        "integrations.p3": (
            "Los chips desk <strong>BTN_TP</strong> / <strong>BTN_TPTYPE</strong> comparten "
            "<code>GSX_MS_TPENABLE_*</code> / <code>GSX_MS_TPTYPE_*</code>. "
            "El toggle es O(1); el Desk drena pares abiertos en el timer. "
            "Detalle técnico: <code>docs/TP_NATIVE.md</code>."
        ),
        "integrations.th6": "Botón",
        "integrations.th7": "Significado",
        "integrations.td32": "Master OFF — sin HLINE, sin push de TP de bróker, sin hits pendientes",
        "integrations.td33": "Tip activo; tickets abiertos coincidentes reciben PositionModify TP (SL intacto)",
        "integrations.td34": "Distancia = mediana de diferencias de swing",
        "integrations.td35": "Distancia = media de todas las diferencias de swing",
        "integrations.li7": (
            "TP nativo por defecto <strong>OFF</strong>; actívelo solo si quiere TP de estructura en el libro."
        ),
        "integrations.p2": (
            "Notas de operador: <code>docs/RELEASE_v2.20_Integrations_OCO.md</code> · "
            "<code>docs/RELEASE_v2.20_Native_TP.md</code> · "
            'Cloud: <a href="#cloud" data-tab="cloud">Cloud Trading</a> · '
            "<code>docs/CLOUD_TRADING.md</code>."
        ),
        "desk213.tdTp": "<strong>TP ON / OFF</strong>",
        "desk213.tdTp2": (
            "Master tip nativo (GV desk compartida). ON dibuja el nivel y empuja el TP de bróker "
            'a posiciones coincidentes. Ver <a href="#integrations">Integraciones</a>.'
        ),
        "desk213.tdTpType": "<strong>Median / Average</strong>",
        "desk213.tdTpType2": "Tipo de distancia tip (visible con TP ON)",
        "desk213.tdTpChart": "<strong>TP ON / OFF</strong>",
        "desk213.tdTpChart2": (
            "Misma GV que Trade Center; HLINE tip + sync de TP de bróker para este magic"
        ),
        "desk213.tdTpTypeChart": "<strong>Median / Average</strong>",
        "desk213.tdTpTypeChart2": "Tipo tip (se muestra con TP ON)",
        "ui.links.integrations.hint": "Cloud · TG · bus · OCO · ScoutLink · TP",
    },
}


def catalog_for(lang: str) -> dict[str, str]:
    if lang == "en":
        return dict(TP_EN)
    base = dict(TP_EN)
    overlay = TP_I18N.get(lang, {})
    base.update(overlay)
    return base


def tp_key_set() -> set[str]:
    return set(TP_EN.keys())


def chapter_buckets(catalog: dict[str, str]) -> dict[str, dict[str, str]]:
    buckets: dict[str, dict[str, str]] = {
        "welcome": {},
        "integrations": {},
        "desk213": {},
        "ui": {},
    }
    for key, value in catalog.items():
        if key.startswith("welcome."):
            buckets["welcome"][key] = value
        elif key.startswith("integrations."):
            buckets["integrations"][key] = value
        elif key.startswith("desk213."):
            buckets["desk213"][key] = value
        elif key.startswith("ui."):
            buckets["ui"][key] = value
    return buckets
