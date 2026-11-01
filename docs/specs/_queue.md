# Реестр задач (dedup)

| slug | ТЗ | Исполнитель | Статус |
|------|----|-------------|--------|
| release-03811 | docs/specs/2026-11-01-release-03811.md | senior | **принято/опубликовано** (0.3.8+11, code 11, SHA EB6BA713…) |
| inventory-composition (BOM) | docs/specs/2026-11-01-inventory-composition.md | junior | **принято** (128a74b…6fe9c37; DB v18) |
| unified-booking-code (№19) | docs/specs/2026-11-01-unified-booking-design.md | senior | **принято** (25b232e…a12ebb7; DB v19) |
| release-03912 | docs/specs/2026-11-01-release-03912.md | senior | **принято/опубликовано** (6f58e54; 0.3.9+12, code 12, SHA 2f7dd425…) |
| server-crlf-shebang (опц.) | — | — | не выпущено: `/opt/vpn-updates/apk-updates.py` в CRLF; запускать `python3 /opt/…` (учтено в ТЗ 031013) |
| encoding-sweep (двойная CP866 в jobs/job_detail + сканер) | docs/specs/2026-11-01-encoding-sweep.md | senior | **принято** (fa24372/e7082f4/4b04a9b; 161 литерал, расширен mojibake_scan_test, 57/57) |
| unified-booking-ui-tight (вкладка «События», убран полоска, починена кнопка вида) | docs/specs/2026-11-01-unified-booking-ui-tight.md | junior | **принято** (1adfdd8; инвертированная логика onPressed исправлена, 57/57; проверить, что 1adfdd8 на main) |
| release-031013 | docs/specs/2026-11-01-release-031013.md | senior | **принято/опубликовано** (bump 729a309; 0.3.10+13, code 13, универсальный SHA 264ac780…, endpoint-verify для 13/12 пройден) |
| today-summary-donuts (сводка месяц+7д в donut-графиках на Today) | docs/specs/2026-11-01-today-summary-donuts.md | junior | **выдано** |

## Правила
- Одна задача = один выпуск; дубль по slug запрещён.
- Параллельные задачи в одном репо: rebase БЕЗ autostash, при чистом дереве; незакоммиченное — сначала коммит; файлы других задач не трогать.
- Код правят только исполнители; документацию (docs/specs) может коммитить кто угодно.
- Финальная проверка каждого среза: analyze 0 ошибок + полный flutter test (включая усиленный mojibake_scan_test и database_test v19).
