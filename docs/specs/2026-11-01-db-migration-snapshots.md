# ТЗ: Снапшоты миграций БД v1→v19 (db-migration-snapshots)

Статус: **выдано** (senior)
Дата: 01.11.2026
Блокер снят: нужны сохранённые файлы БД для регрессии миграций (раньше: «Snapshot-тесты миграций v1→v19: need saved DB files»).

## Цель
Сделать генерируемые снапшоты (фикстуры) БД на каждую версию схемы (v1…v19) + регрессионный тест: открыть фикстурную БД старой версии с апгрейдом до v19 и проверить, что схема после миграций = целевая v19 (таблицы/колонки/индексы на месте, user_version=19).

## Входит
### А. Генератор фикстур (test, изолирован)
- Новый тест-файл `test/migration_fixture_test.dart` с `@Tags(['fixtures'])` (или условная генерация в setUp):
  - Для каждой версии `v in 1..19`: `openDatabase('test/fixtures/dbs/v$v.db', version: v, onCreate: (db, ver) => при вызове на версії v создать схему ровно на v (см. примечание), onUpgrade: (db, old, new) {})` → закрыть файл.
  - **Примечание (важно)**: `AppDatabase._createSchema` создаёт базовую схему (как v1), а `_upgradeSchema` гоняет гварды `oldVersion < N`. Поэтому фикстуру v-й версии строить так: открыть db c `version: v, onCreate: _createSchema, onUpgrade: _upgradeSchema`, но в onConfigure/после — `db.execute('PRAGMA user_version = $v')` и докинуть недостающие гварды вручную (или, проще: создать db c `version: 1` c `_createSchema` и прогнать `_upgradeSchema(db, 1, v)` явно). Выбери корректный способ, который даёт схему ровно v-й версии (проверяй: например, для v17 колонка `reverses_id` есть, для v16 — нет).
  - Файлы коммитить в репо: `test/fixtures/dbs/v1.db … v19.db` (размер каждого ~几十 KB, без данных, только схема — допустимо в репо; данные не класть).
- Если sqflite в тестах пишет файлы нормально (текущие тесты используют in-memory или temp — проверить `test/database_test.dart`, как он открывает БД) — генератор должен писать **файловые** БД в `test/fixtures/dbs/`.

### Б. Регрессионный тест апгрейда
- Новый `test/migration_upgrade_test.dart`:
  - Для каждой фикстуры v1…v19 (файловая копия во временный каталог, чтобы не мять фикстур): `openDatabase(copyPath, version: 19, onUpgrade: AppDatabase._upgradeSchema)` (если `_upgradeSchema` приватный — добавить публичный геттер/обёртку в `lib/data/app_database.dart`, это единственное изменение либ-кода; либо дублировать логику — предпочтительнее публичная обёртка `AppDatabase.upgradeSchema`).
  - Проверки на каждом: `PRAGMA user_version = 19`; ключевые таблицы/колонки присутствуют: `jobs.pinned`, `jobs.calculator_state`, `work_sessions`, `money_transactions.reverses_id`, `inventory_compositions`, `idx_appts_start`, `idx_jobs_due`; `PRAGMA integrity_check = 'ok'`; `PRAGMA foreign_key_check` пусто.
- Не ломать существующий `database_test.dart` (там уже есть ожидания v19) — новые тесты дополняют.

## Не входит / запреты
- Не менять production-схему (либ-код — только публичная обёртка upgrade, если нужна).
- Не трогать `settings_controller`/`settings_screen`/`masters_store`/`today_screen`/`money_screen` (параллельная задача tax-profiles их правит).
- Без новых зависимостей.

## Критерии приёмки
- `test/fixtures/dbs/v1.db … v19.db` в репо (19 файлов, скоммичены).
- `flutter test` зелёные, включая новый `migration_upgrade_test` (19× проверка схемы).
- `flutter analyze --no-pub` 0 ошибок.
- Коммит(ы): `test: DB schema fixtures v1..v19`, `test: migration upgrade regression v1..v19`, push (pull --rebase БЕЗ --autostash, при чистом дереве).
- Отчёт до 20 строк: как генерировались фикстуры (метод), какие проверки в regression-тесте, analyze/test, хеши. Не релиз, не bump pubspec.