# Production manual + Native TP i18n

## Goals

1. Document Native TP (uses, chips, broker apply, closeOnHit) in the Users Manual.
2. Extend lazy-load i18n for `it/fr/ru/ar/zh/es` via DRY content + generator.
3. Coverage audit gate for missing keys; TP keys must not stay EN-parity.

## Scope

- In: Users Manual HTML, locale JSON, `gsx-i18n.js` CACHE_VER, release note.
- Out: MT5 chart chip localization (English technical tokens).

## Checklist

- [x] Plan artifact present
- [x] EN HTML wired (`data-i18n*`) — integrations, desk213, welcome
- [x] Generator + real translations for TP keys
- [x] `_audit_i18n.py` PASS (missing keys); TP keys translated
- [x] CACHE_VER bumped; MANUAL_I18N updated
- [x] Python goldens + Confirm Compile

## Hosts

Stay **2.20** (docs cut only).
