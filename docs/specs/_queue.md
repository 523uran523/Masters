# Реестр задач (dedup)

| slug | ТЗ | Исполнитель | Статус |
|------|----|-------------|--------|
| release-03710-status-check | …release-03710-status-check.md | senior | принято: APK собран, НЕ опубликован; решение: следующий релиз 0.3.8+11 |
| mojibake-encoding-fix | …mojibake-encoding-fix.md | senior | **принято** |
| kanban-config | …jobs-kanban-config.md | senior | принято (99628af) |
| jobs-status-dropdown | …jobs-status-dropdown.md | senior | принято (47a823b) |
| calculator-v2 | …calculator-v2.md | senior | принято (52d7e4d, fa03506, dcd8ff9, 47da26d; пуш через fec4274) |
| today-main-v2 | …today-main-v2.md | senior | **принято** (64fc2c3/3f5c41e/f36ce13/26ede62/8eab6de/431dc71; DB v16 work_sessions, таймер, быстрые ₽, карточка месяца + пиро, fix overflow stats) |
| client-debt-unpaid-indicator (№16) | …client-debt-unpaid.md | junior | **принято** (ccaeaaf + syntax-fix 9eaeb20) |
| jobs-search-qa (№1/№2) | …jobs-search-qa.md | junior | **принято** (3a67de6/bc1b664) |
| money-reversal (возврат вместо void, №15) | …money-reversal.md | senior | **принято** (e853c2e/beeec51/9f92933/0bf7bc1/b893765, DB v17, pushed) |
| settings-config (соло/тумблеры/пресеты, №8,13,21,23) | …settings-config.md | senior | **принято** (651e097/088a7f7/0f38737: ключи+пресеты в controller, UI-gating team/calculator, 4 блока settings + тумблеры + пресеты-карта + terms card; B6/calendar-записи нет в спеке) |
| unified-booking-RESEARCH (№19, read-only+дизайн) | docs/specs/2026-11-01-unified-booking-design.md | senior | **принято** (адаптер UnifiedEvent, гибрид kanban/calendar, workMode, миграция v18 non-destructive) |
| unified-booking-code (№19, реализация) | docs/specs/2026-11-01-unified-booking-design.md | senior | не выпущено (ждёт settings-config — флаги workMode) |
| release-03811 | docs/specs/2026-11-01-release-03811.md | senior | не выпущено: после settings-config (+ по решению unified-booking-code): bump 0.3.8+11 → analyze+test → build → publish → verify |

## Правила
- Одна задача = один выпуск; дубль по slug запрещён.
- Параллельные задачи в одном репо: rebase БЕЗ autostash, при чистом дереве; незакоммиченное — сначала коммит; файлы других задач не трогать (списки в ТЗ).
- Код правят только исполнители; документацию (docs/specs) может коммитить кто угодно.
- Финальная проверка каждого среза: analyze 0 ошибок + полный flutter test (включая mojibake_scan_test и database_test v17).
