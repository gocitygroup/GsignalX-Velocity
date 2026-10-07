# -*- coding: utf-8 -*-
"""Emit bias-follow.json catalogs and register chapter keys in ui.json."""
from __future__ import annotations

import json
from pathlib import Path

from _bias_follow_content import BIAS_I18N

DOCS = Path(__file__).resolve().parent
LANGS = ("it", "fr", "ru", "ar", "zh", "es")

# Light native titles/shorts only; body keys keep EN until translators update.
NATIVE_CHAPTER = {
    "it": ("Daily Bias Follow", "Bias"),
    "fr": ("Daily Bias Follow", "Biais"),
    "ru": ("Daily Bias Follow", "Bias"),
    "ar": ("Daily Bias Follow", "Bias"),
    "zh": ("Daily Bias Follow", "偏向"),
    "es": ("Seguimiento de sesgo diario", "Sesgo"),
}


def write_bias_json(lang: str) -> None:
    folder = DOCS / "assets" / "i18n" / lang
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / "bias-follow.json"
    # Seed EN strings so keys resolve (no missing-key flash).
    path.write_text(
        json.dumps(BIAS_I18N, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {lang}/bias-follow.json ({len(BIAS_I18N)} keys)")


def patch_ui(lang: str) -> None:
    path = DOCS / "assets" / "i18n" / lang / "ui.json"
    if not path.is_file():
        return
    data = json.loads(path.read_text(encoding="utf-8"))
    title, short = NATIVE_CHAPTER[lang]
    data["chapters.bias-follow.title"] = title
    data["chapters.bias-follow.short"] = short
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"ui.json chapters.bias-follow -> {lang}")


def main() -> None:
    for lang in LANGS:
        write_bias_json(lang)
        patch_ui(lang)
    print("done bias i18n")


if __name__ == "__main__":
    main()
