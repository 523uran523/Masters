# Реестр задач (dedup)

| slug | ТЗ | Исполнитель | Статус |
|------|----|-------------|--------|
| release-03811 | docs/specs/2026-11-01-release-03811.md | senior | **принято/опубликовано** (0.3.8+11, code 11, SHA EB6BA713…) |
| inventory-composition (BOM) | docs/specs/2026-11-01-inventory-composition.md | junior | **принято** (128a74b…6fe9c37; DB v18) |
| unified-booking-code (№19) | docs/specs/2026-11-01-unified-booking-design.md | senior | **принято** (25b232e…a12ebb7; DB v19) |
| release-03912 | docs/specs/2026-11-01-release-03912.md | senior | **принято/опубликовано** (6f58e54; 0.3.9+12, code 12, SHA 2f7dd425…) |
| server-crlf-shebang (опц.) | — | — | не выпущено: `/opt/vpn-updates/apk-updates.py` в CRLF; запускать `python3 /opt/…` (учтено в ТЗ 031013) |
| encoding-sweep (двойная CP866 в jobs/job_detail + сканер) | docs/specs/2026-11-01-encoding-sweep.md | senior | **принято** (fa24372/e7082f4/4b04a9b; 161 литерал) |
| unified-booking-ui-tight (вкладка «События», убран полоска, починена кнопка вида) | docs/specs/2026-11-01-unified-booking-ui-tight.md | junior | **принято** (1adfdd8; 57/57) |
| release-031013 | docs/specs/2026-11-01-release-031013.md | senior | **принято/опубликовано** (729a309; 0.3.10+13, code 13, SHA 264ac780…) |
| today-summary-donuts (сводка месяц+7д в donut-графиках на Today) | docs/specs/2026-11-01-today-summary-donuts.md | junior | **принято** (a476c86 + 09f0bc7; 57/57) |
| release-031114 | docs/specs/2026-11-01-release-031114.md | senior | **принято/опубликовано** (054c8a7; 0.3.11+14, code 14, SHA 7c538bff…) |
| today-legend-fix (убрать текст со значениями, оставить точки-легенду) | docs/specs/2026-11-01-today-legend-fix.md | junior | **принято** (85134a3, 57/57, pushed) |
| money-tabs-fix (восстановить текст + вкладки Операции/Счета/Категории) | docs/specs/2026-11-01-money-tabs-fix.md | senior | **принято** (pushed, 57/57) |
| release-031215 | docs/specs/2026-11-01-release-031215.md | senior | **принято/опубликовано** (151cfb4; 0.3.12+15, code 15, SHA 62A404C6…) |
| tax-profiles (налоговые профили по странам, настройки) | docs/specs/2026-11-01-tax-profiles.md | senior | **принято** (6583ef0/9b9d5e9/919f5a8 + integration fix 164276c) |
| db-migration-snapshots (снапшоты БД v1→v19 + regression-тесты) | docs/specs/2026-11-01-db-migration-snapshots.md | senior | **принято** (fb16f65/b96c99c) |
| code-audit-cleanup (audit + cleanup + UX text capitalization) | — | senior | **принято** (c1bfc1c, ddff84e; 101/101, 0 warn) |
| project-cleanup-consolidate (удалить мусор + консолидация md) | — | senior | **принято** (6896d9e, 913c4c2) |
| settings-ux-polish (compact / vibrant / иконки / статус-чип) | docs/specs/2026-11-01-settings-ux-polish.md | senior | **выдано** |
| release-031316 (после двух срезов) | docs/specs/2026-11-01-release-031316.md | senior | **выдано** (ждёт двух срезов) |

## Правила
- Одна задача = один выпуск; дубль по slug запрещён.
- Параллельные задачи в одном репо: rebase БЕЗ autostash, при чистом дереве; незакоммиченное — сначала коммит; файлы других задач не трогать.
- Код правят только исполнители; документацию (docs/specs) может коммитить кто угодно.
- Финальная проверка каждого среза: analyze 0 ошибок + полный flutter test (включая усиленный mojibake_scan_test и database_test v19).