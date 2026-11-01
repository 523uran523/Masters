# Реестр задач (dedup)

| slug | ТЗ | Исполнитель | Статус |
|------|----|-------------|--------|
| release-03811 | docs/specs/2026-11-01-release-03811.md | senior | **принято/опубликовано** (0.3.8+11, code 11, SHA EB6BA713…, commit 0fc40c6) |
| inventory-composition (склад-калькулятор, BOM) | docs/specs/2026-11-01-inventory-composition.md | junior | **принято** (128a74b…6fe9c37; DB v18) |
| unified-booking-code (№19) | docs/specs/2026-11-01-unified-booking-design.md | senior | **принято** (25b232e…a12ebb7; UnifiedEvent, гибрид kanban/calendar, workMode, DB v19) |
| release-03912 | docs/specs/2026-11-01-release-03912.md | senior | **принято/опубликовано** (bump 6f58e54; 0.3.9+12, code 12, SHA 2f7dd425…; endpoint верифицирован) |
| server-crlf-shebang (опц.) | — | — | не выпущено: `/opt/vpn-updates/apk-updates.py` на сервере в CRLF (`env: python3\r`); фикс dos2unix на сервере, не в репо |
| encoding-sweep (двойная CP1251 в jobs/job_detail + весь lib + расширение сканера) | docs/specs/2026-11-01-encoding-sweep.md | senior | **выдано** |
| unified-booking-ui-tight (вкладка «События», убрать полоску вида, починить кнопку вида) | docs/specs/2026-11-01-unified-booking-ui-tight.md | junior | **выдано** |
| release-031013 (снимок после двух срезов) | — | senior | не выпущено: после encoding-sweep + unified-booking-ui-tight: bump 0.3.10+13 → analyze+test → build → publish → verify |

## Правила
- Одна задача = один выпуск; дубль по slug запрещён.
- Параллельные задачи в одном репо: rebase БЕЗ autostash, при чистом дереве; незакоммиченное — сначала коммит; файлы других задач не трогать.
- Код правят только исполнители; документацию (docs/specs) может коммитить кто угодно.
- Финальная проверка каждого среза: analyze 0 ошибок + полный flutter test (включая mojibake_scan_test и database_test v19).
