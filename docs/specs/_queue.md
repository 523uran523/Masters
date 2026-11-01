# Реестр задач (dedup)

| slug | ТЗ | Исполнитель | Статус |
|------|----|-------------|--------|
| release-03811 | docs/specs/2026-11-01-release-03811.md | senior | **принято/опубликовано** (0.3.8+11, code 11, SHA EB6BA713…) |
| inventory-composition (BOM) | docs/specs/2026-11-01-inventory-composition.md | junior | **принято** (128a74b…6fe9c37; DB v18) |
| unified-booking-code (№19) | docs/specs/2026-11-01-unified-booking-design.md | senior | **принято** (25b232e…a12ebb7; DB v19) |
| release-03912 | docs/specs/2026-11-01-release-03912.md | senior | **принято/опубликовано** (6f58e54; 0.3.9+12, code 12, SHA 2f7dd425…) |
| server-crlf-shebang (опц.) | — | — | не выпущено: `/opt/vpn-updates/apk-updates.py` в CRLF; запускать `python3 /opt/…` (учтено в ТЗ 031013) |
| encoding-sweep | docs/specs/2026-11-01-encoding-sweep.md | senior | **принято** (fa24372/e7082f4/4b04a9b; 161 литерал) |
| unified-booking-ui-tight | docs/specs/2026-11-01-unified-booking-ui-tight.md | junior | **принято** (1adfdd8; 57/57) |
| release-031013 | docs/specs/2026-11-01-release-031013.md | senior | **принято/опубликовано** (729a309; 0.3.10+13, code 13, SHA 264ac780…) |
| today-summary-donuts | docs/specs/2026-11-01-today-summary-donuts.md | junior | **принято** (a476c86 + 09f0bc7) |
| release-031114 | docs/specs/2026-11-01-release-031114.md | senior | **принято/опубликовано** (054c8a7; 0.3.11+14, code 14, SHA 7c538bff…) |
| today-legend-fix | docs/specs/2026-11-01-today-legend-fix.md | junior | **принято** (85134a3, 57/57) |
| money-tabs-fix | docs/specs/2026-11-01-money-tabs-fix.md | senior | **принято** (pushed, 57/57) |
| release-031215 | docs/specs/2026-11-01-release-031215.md | senior | **принято/опубликовано** (151cfb4; 0.3.12+15, code 15, SHA 62A404C6…) |
| tax-profiles | docs/specs/2026-11-01-tax-profiles.md | senior | **принято** (6583ef0/9b9d5e9/919f5a8 + integration fix 164276c) |
| db-migration-snapshots | docs/specs/2026-11-01-db-migration-snapshots.md | senior | **принято** (fb16f65/b96c99c) |
| code-audit-cleanup | — | senior | **принято** (c1bfc1c, ddff84e; 101/101, 0 warn) |
| project-cleanup-consolidate | — | senior | **принято** (6896d9e, 913c4c2) |
| settings-ux-polish | docs/specs/2026-11-01-settings-ux-polish.md | senior | **принято** (fc93bdc, 9702a7f, 101/101) |
| tax-radar | docs/specs/2026-11-01-tax-radar.md | senior | **принято** (aee3ae4/dfb0b39/4c9a57b/6e9e9ec/e87a1c4; 107/107) |
| release-031316 | docs/specs/2026-11-01-release-031316.md | senior | **принято/опубликовано** (390af5b9; 0.3.13+16, code 16, SHA a707e94a…) |

## Правила
- Одна задача = один выпуск; дубль по slug запрещён.
- Параллельные задачи в одном репо: rebase БЕЗ autostash, при чистом дереве; незакоммиченное — сначала коммит; файлы других задач не трогать.
- Код правят только исполнители; документацию (docs/specs) может коммитить кто угодно.
- Финальная проверка каждого среза: analyze 0 ошибок + полный flutter test (включая усиленный mojibake_scan_test и database_test v19).