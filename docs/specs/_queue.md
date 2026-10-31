# Реестр задач (dedup)

| slug | ТЗ | Исполнитель | Статус |
|------|----|-------------|--------|
| release-03710-status-check | …release-03710-status-check.md | senior | принято: APK собран, НЕ опубликован; решение: следующий релиз 0.3.8+11 |
| mojibake-encoding-fix | …mojibake-encoding-fix.md | senior | принято |
| kanban-config | …jobs-kanban-config.md | senior | принято (99628af) |
| jobs-status-dropdown | …jobs-status-dropdown.md | senior | принято (47a823b) |
| calculator-v2 | …calculator-v2.md | senior | принято (52d7e4d, fa03506, dcd8ff9, 47da26d; пуш через fec4274) |
| today-main-v2 | …today-main-v2.md | senior | **в работе** (фон) |
| client-debt-unpaid-indicator (метка «не оплачен» у закрытых заказов клиента, №16) | docs/specs/2026-10-31-client-debt-unpaid.md | junior | **выдано** |
| jobs-search-qa (лупа-поиск фильтрует по названию/тегам/клиенту, №1/№2) | docs/specs/2026-10-31-jobs-search-qa.md | junior | **выдано** |
| money-reversal (возврат вместо void, №15) | …money-reversal.md | — | ждёт today-main-v2 |
| settings-config (соло/тумблеры/пресеты, №8,13,21,23) | …settings-config.md | — | ждёт today-main-v2 |
| unified-booking (№19) | план §Б6 | — | не выпущено |
| release-03811 | — | — | после today-main-v2: bump 0.3.8+11 → analyze+test → build → publish → verify |

## Правила
- Одна задача = один выпуск; дубль по slug запрещён.
- Параллельные задачи в одном репо: rebase БЕЗ autostash, при чистом дереве; незакоммиченное — сначала коммит; файлы других задач не трогать (списки в ТЗ).
- Код правят только исполнители; документацию (docs/specs) может коммитить кто угодно.
