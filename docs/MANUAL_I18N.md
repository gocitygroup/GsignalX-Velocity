# Trader manual — easy version & i18n updates

**Current cut:** see [`_manual_version.py`](_manual_version.py) (`MANUAL_VERSION`).

## Bump public version (HTML + locales + cache)

```bash
cd docs
python _bump_manual_version.py
```

Updates:

- `Gsignalx_Velocity_Users_Manual.html` version chips / titles that still say 2.14–2.15
- all `assets/i18n/{lang}/*.json` version + current RELEASE filename strings
- `assets/js/gsx-i18n.js` → `CACHE_VER`

## Regenerate Bias Follow locale catalogs

```bash
cd docs
python _gen_bias_i18n.py
```

Writes `assets/i18n/{it,fr,ru,ar,zh,es}/bias-follow.json` from [`_bias_follow_content.py`](_bias_follow_content.py) and registers `chapters.bias-follow.*` in each `ui.json`.

English lives in the HTML via `data-i18n` / `data-i18n-html` on section `#bias-follow`.

## Edit bias copy

1. Change EN strings in `_bias_follow_content.py` (`BIAS_I18N` + `BIAS_FOLLOW_CHAPTER`).
2. Re-paste / sync the HTML chapter body if structure changed.
3. Run `_gen_bias_i18n.py`.
4. Optionally translate values inside each `bias-follow.json` (keys must stay stable).

## Languages

`en` (HTML source) · `it` · `fr` · `ru` · `ar` (RTL) · `zh` · `es`
