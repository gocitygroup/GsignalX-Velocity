# -*- coding: utf-8 -*-
"""Merge Native TP keys into welcome / integrations / desk213 / ui locale JSON."""
from __future__ import annotations

import json
from pathlib import Path

from _tp_native_manual import TP_EN, catalog_for, chapter_buckets, tp_key_set

DOCS = Path(__file__).resolve().parent
LANGS = ("it", "fr", "ru", "ar", "zh", "es")

# Keys that intentionally keep English chip tokens / shared hint across locales.
ALLOW_EN_PARITY = {
    "ui.links.integrations.hint",
    "desk213.tdTp",
    "desk213.tdTpType",
    "desk213.tdTpChart",
    "desk213.tdTpTypeChart",
}


def merge_json(path: Path, updates: dict[str, str]) -> None:
    data: dict[str, str] = {}
    if path.is_file():
        data = json.loads(path.read_text(encoding="utf-8"))
    data.update(updates)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    expected = tp_key_set()
    for lang in LANGS:
        cat = catalog_for(lang)
        missing = expected - set(cat.keys())
        if missing:
            raise SystemExit(f"{lang}: missing overlay keys {sorted(missing)}")

        body_parity = [
            k for k in expected if k not in ALLOW_EN_PARITY and cat[k] == TP_EN[k]
        ]
        if body_parity:
            raise SystemExit(f"{lang}: still EN-parity for {body_parity}")

        buckets = chapter_buckets(cat)
        root = DOCS / "assets" / "i18n" / lang
        merge_json(root / "welcome.json", buckets["welcome"])
        merge_json(root / "integrations.json", buckets["integrations"])
        merge_json(root / "desk213.json", buckets["desk213"])
        merge_json(root / "ui.json", buckets["ui"])
        print(f"merged TP keys -> {lang} ({len(expected)} keys)")
    print("done")


if __name__ == "__main__":
    main()
