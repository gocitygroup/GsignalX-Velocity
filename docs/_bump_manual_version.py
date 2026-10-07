# -*- coding: utf-8 -*-
"""Bump public manual / i18n / CACHE_VER markers to MANUAL_VERSION."""
from __future__ import annotations

import json
import re
from pathlib import Path

from _manual_version import MANUAL_VERSION

DOCS = Path(__file__).resolve().parent
ROOT = DOCS.parent
HTML = DOCS / "Gsignalx_Velocity_Users_Manual.html"
I18N_JS = DOCS / "assets" / "js" / "gsx-i18n.js"
LANGS = ("it", "fr", "ru", "ar", "zh", "es")

# Public-facing cuts previously advertised as 2.14 / 2.15
OLD_VERS = ("2.14", "2.15")


def bump_text(text: str) -> str:
    out = text
    for old in OLD_VERS:
        # Filename / RELEASE first — before bare "v{old}" eats the middle.
        out = out.replace(
            f"RELEASE_v{old}_Input_Reliability.md",
            f"RELEASE_v{MANUAL_VERSION}_Daily_Bias_Follow.md",
        )
        out = out.replace(
            f"RELEASE_v{MANUAL_VERSION}_Input_Reliability.md",
            f"RELEASE_v{MANUAL_VERSION}_Daily_Bias_Follow.md",
        )
        out = out.replace(f"Velocity {old}", f"Velocity {MANUAL_VERSION}")
        out = out.replace(f"Best Use {old}", f"Best Use {MANUAL_VERSION}")
        out = out.replace(f"Best Use ({old})", f"Best Use ({MANUAL_VERSION})")
        out = out.replace(f"UI {old}", f"UI {MANUAL_VERSION}")
        out = out.replace(
            f"version <strong>{old}</strong>",
            f"version <strong>{MANUAL_VERSION}</strong>",
        )
        out = out.replace(f"V{old}", f"V{MANUAL_VERSION}")
        out = out.replace(f"v{old}", f"v{MANUAL_VERSION}")
        out = re.sub(
            rf"(Gsignalx Velocity ){re.escape(old)}",
            rf"\g<1>{MANUAL_VERSION}",
            out,
        )
    return out


def bump_html() -> None:
    raw = HTML.read_text(encoding="utf-8")
    HTML.write_text(bump_text(raw), encoding="utf-8")
    print(f"bumped {HTML.name}")


def bump_cache_ver() -> None:
    raw = I18N_JS.read_text(encoding="utf-8")
    new = re.sub(
        r'var CACHE_VER = "[^"]+"',
        f'var CACHE_VER = "{MANUAL_VERSION}"',
        raw,
        count=1,
    )
    I18N_JS.write_text(new, encoding="utf-8")
    print(f"CACHE_VER -> {MANUAL_VERSION}")


def bump_i18n_json() -> None:
    root = DOCS / "assets" / "i18n"
    if not root.is_dir():
        return
    for path in sorted(root.rglob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        changed = False
        for k, v in list(data.items()):
            if not isinstance(v, str):
                continue
            nv = bump_text(v)
            nv = nv.replace(
                f"RELEASE_v{MANUAL_VERSION}_Input_Reliability.md",
                f"RELEASE_v{MANUAL_VERSION}_Daily_Bias_Follow.md",
            )
            if nv != v:
                data[k] = nv
                changed = True
        if changed:
            path.write_text(
                json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
            print(f"bumped {path.relative_to(DOCS)}")


def main() -> None:
    bump_html()
    bump_cache_ver()
    bump_i18n_json()
    print(f"done MANUAL_VERSION={MANUAL_VERSION}")


if __name__ == "__main__":
    main()
