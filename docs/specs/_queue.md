# Реестр задач (dedup)

| slug | ТЗ | Исполнитель | Статус |
|------|----|-------------|--------|
| release-03710-status-check | docs/specs/2026-10-31-release-03710-status-check.md | senior | принято: APK собран (SHA 642839CB…), НЕ опубликован; решение: следующий релиз 0.3.8+11 |
| mojibake-encoding-fix | docs/specs/2026-10-31-mojibake-encoding-fix.md | senior | **принято** (grep lib/ на сигнатуры — пусто; Excel-шапки восстановлены; scan-тест в репо) |
| kanban-config | docs/specs/2026-10-31-jobs-kanban-config.md | senior | принято (99628af) |
| jobs-status-dropdown | docs/specs/2026-10-31-jobs-status-dropdown.md | senior | **принято** (47a823b, пушён) |
| calculator-v2 (units/persist/склад, DB v15) | docs/specs/2026-10-31-calculator-v2.md | senior | **принято** (коммиты 52d7e4d/fa03506/dcd8ff9/47da26d локальные; пушён исполнителем по команде Architect'а) |
| today-main-v2 (timer/быстрые ₽/сводка/пиро, DB v16) | docs/specs/2026-10-31-today-main-v2.md | senior | **выдано** |
| money-reversal (возврат вместо void) | план §Б4 | — | не выпущено (ждёт today-main-v2 — masters_store занят) |
| settings-config (соло/тумблеры/пресеты) | план §Б5 | — | не выпущено |
| unified-booking (записи=основной workflow) | план §Б6 | — | не выпущено (большой блок) |
| release-03811 | — | — | не выпущено: после today-main-v2 → bump 0.3.8+11 → analyze+test → build → publish → verify |

## Правила
- Каждая задача выпускается один раз; дубль по slug — запрещён.
- Релиз — один исполнитель.
- **ИНЦИДЕНТ (31.10.2026):** `git pull --rebase --autostash` в параллельной работе уничтожил чужие незакоммиченные правки. Правило: rebase БЕЗ autostash, при чистом дереве; незакоммиченное — сначала коммит.
- Документация (`docs/specs/*`) может коммититься любым исполнителем — это не код.
