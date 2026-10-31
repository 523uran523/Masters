# Реестр задач (dedup)

| slug | ТЗ | Исполнитель | Статус |
|------|----|-------------|--------|
| release-03710-status-check | docs/specs/2026-10-31-release-03710-status-check.md | senior | принято: APK собран (SHA 642839CB…), НЕ опубликован; решение: следующий релиз 0.3.8+11 после B0+B1 |
| mojibake-encoding-fix | docs/specs/2026-10-31-mojibake-encoding-fix.md | senior | В РАБОТЕ (повторный запуск: первый исполнитель упал на лимите вывода; инцидент: незакоммиченные правки потеряны в autostash параллельной задачи — перделает с нуля) |
| kanban-config | docs/specs/2026-10-31-jobs-kanban-config.md | senior | принято (commit 99628af, analyze 0 ошибок, тесты 21/21; финальная сверка — на полном цикле релиза 0.3.8+11) |
| jobs-config-slice-2 (статус-dropdown «Новая» по умолчанию) | план §Б3 | — | не выпущено (ждёт mojibake-encoding-fix: job_detail_screen занят) |
| calculator-v2 (units/persist/склад, DB v15) | docs/specs/2026-10-31-calculator-v2.md | — | ТЗ готово, ждёт B0 (masters_store занят) |
| today-main-v2 (timer/быстрые ₽/сводка/пиро, DB v16) | docs/specs/2026-10-31-today-main-v2.md | — | ТЗ готово, ждёт B0+B1 (v15 → v16) |
| money-reversal (возврат вместо void) | план §Б4 | — | не выпущено |
| settings-config (соло/тумблеры/пресеты) | план §Б5 | — | не выпущено |
| unified-booking (записи=основной workflow) | план §Б6 | — | не выпущено (большой блок) |
| release-03811 (после B0+B1, возможно +B2) | — | — | не выпущено: bump 0.3.8+11 → analyze+test → build → publish → verify |

## Правила
- Каждая задача выпускается один раз; дубль по slug — запрещён.
- Релиз — один исполнитель, строго после зелёного B0 (+B1 для 0.3.8+11).
- **ИНЦИДЕНТ (31.10.2026):** при параллельной работе в одном репо `git pull --rebase --autostash` уничтожил незакоммиченные правки другой задачи. Правило: в параллельных задачах `pull --rebase` БЕЗ autostash и только при чистом дереве; незакоммиченное — сначала коммит по файлу, потом pull.
