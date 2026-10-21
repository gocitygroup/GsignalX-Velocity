# -*- coding: utf-8 -*-
"""Audit Users Manual i18n key coverage (no browser)."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from _tp_native_manual import TP_EN, catalog_for, tp_key_set

DOCS = Path(__file__).resolve().parent
HTML = DOCS / "Gsignalx_Velocity_Users_Manual.html"
LANGS = ("it", "fr", "ru", "ar", "zh", "es")

RE_I18N = re.compile(
    r'data-i18n(?:-html)?="([^"]+)"|data-i18n-attr="[^"]*?([a-zA-Z0-9_.]+)(?:"|,)'
)
RE_ATTR = re.compile(r"data-i18n-attr=\"([^\"]+)\"")
RE_SECTION = re.compile(
    r'<section\s+class="panel"[^>]*\sid="([^"]+)"(.*?)(?=<section\s+class="panel"|</main>)',
    re.S,
)


def html_keys() -> set[str]:
    text = HTML.read_text(encoding="utf-8")
    keys: set[str] = set()
    for m in re.finditer(r'data-i18n(?:-html)?="([^"]+)"', text):
        keys.add(m.group(1))
    for m in RE_ATTR.finditer(text):
        for part in m.group(1).split(","):
            part = part.strip()
            if ":" in part:
                keys.add(part.split(":", 1)[1].strip())
    return keys


def section_key_map() -> dict[str, set[str]]:
    """Map chapter id → keys referenced inside that section."""
    text = HTML.read_text(encoding="utf-8")
    # Simpler: split on section.panel id
    parts = re.split(r'(?=<section\s+class="panel")', text)
    mapping: dict[str, set[str]] = {}
    for part in parts:
        m = re.search(r'<section\s+class="panel"[^>]*\sid="([^"]+)"', part)
        if not m:
            continue
        sid = m.group(1)
        keys: set[str] = set()
        for km in re.finditer(r'data-i18n(?:-html)?="([^"]+)"', part):
            keys.add(km.group(1))
        for am in RE_ATTR.finditer(part):
            for piece in am.group(1).split(","):
                piece = piece.strip()
                if ":" in piece:
                    keys.add(piece.split(":", 1)[1].strip())
        mapping[sid] = keys
    return mapping


def load_locale(lang: str) -> dict[str, str]:
    root = DOCS / "assets" / "i18n" / lang
    bag: dict[str, str] = {}
    ui = root / "ui.json"
    if ui.is_file():
        bag.update(json.loads(ui.read_text(encoding="utf-8")))
    for path in root.glob("*.json"):
        if path.name == "ui.json":
            continue
        bag.update(json.loads(path.read_text(encoding="utf-8")))
    return bag


def main() -> int:
    if not HTML.is_file():
        print("FAIL  manual HTML missing", file=sys.stderr)
        return 1

    all_keys = html_keys()
    print(f"HTML keys: {len(all_keys)}")

    fail = 0
    warn = 0
    tp_keys = tp_key_set()

    for lang in LANGS:
        bag = load_locale(lang)
        missing = sorted(k for k in all_keys if k not in bag or bag.get(k) in (None, ""))
        # ui.* and chapter keys may live only in ui.json — already merged into bag
        if missing:
            # Only hard-fail on TP keys + brand-new keys we own; warn on legacy gaps
            hard = [k for k in missing if k in tp_keys or k.startswith("ui.")]
            soft = [k for k in missing if k not in hard]
            if hard:
                print(f"FAIL  {lang}: missing {len(hard)} keys e.g. {hard[:12]}")
                fail += 1
            if soft:
                print(f"WARN  {lang}: {len(soft)} legacy missing keys (not failing)")
                warn += 1
        else:
            print(f"PASS  {lang}: all HTML keys present")

        # TP EN-parity gate
        cat = catalog_for(lang)
        from _gen_tp_native_i18n import ALLOW_EN_PARITY

        parity = [
            k
            for k in tp_keys
            if k not in ALLOW_EN_PARITY and bag.get(k, "") == TP_EN.get(k, "")
        ]
        if parity:
            print(f"FAIL  {lang}: TP EN-parity {parity[:10]}")
            fail += 1
        else:
            # Ensure TP keys exist in bag
            miss_tp = sorted(k for k in tp_keys if k not in bag)
            if miss_tp:
                print(f"FAIL  {lang}: TP keys not merged {miss_tp}")
                fail += 1
            else:
                print(f"PASS  {lang}: TP keys translated")

    if fail:
        print(f"RESULT fail={fail} warn={warn}")
        return 1
    print(f"RESULT PASS warn={warn}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
