# ТЗ: Э0 — фундамент v22 (`foundation-v22`)

Статус: **выдано** (senior)
Дата: 05.11.2026
База: `0.3.18+21`, схема БД **v21**, `flutter test` 131/131.
Общее ТЗ и обоснование: `docs/confectionery-use-cases-analysis.md` (§4.1, §5.1).
Целевая версия выпуска: **0.4.0+22**.

## Цель

Подготовить схему и «проводку» данных так, чтобы этапы Э1–Э4 (каталог и
строки заказа, деньги по плану, заявки, деньги клиента) не требовали новых
миграций и не заставляли править одно и то же в четырёх местах.

Это единственный этап, который пользователь **не видит**: новых экранов нет,
кроме двух строк в настройках. Всё остальное — внутренняя перестройка.

## Почему это делается первым

1. Строка заказа (`materials`) не знает, из какого складского товара она
   сделана → автоматическая себестоимость и списание невозможны.
2. Остаток склада меняется в четырёх местах (`receiveStock`, `writeOffStock`,
   `createPurchase`, калькулятор) → после введения локаций и партий это
   пришлось бы переписывать целиком.
3. Новая таблица требует правок в audit-триггерах, `sync_outbox`,
   `backupData`, `restoreFromBackup`, `mergeFromBackup` — четыре ручные
   правки на каждую таблицу.
4. Валюта захардкожена: 65 вхождений `₽` в `lib/`, включая PDF.

## Входит

### А. Реестр таблиц (`lib/data/schema_tables.dart`, новый файл)

Единый список синхронизируемых таблиц + порядок применения. Из него
генерируются: audit-триггеры, `sync_outbox`-подписки, ключи бэкапа, порядок
restore/merge.

```dart
const kSyncedTables = <String>[
  'clients', 'objects', 'jobs', 'job_stages', 'materials',
  'accounts', 'cash_shifts', 'money_transactions', 'recurring_payments',
  'inventory_items', 'inventory_compositions', 'stock_movements',
  'suppliers', 'purchases', 'purchase_lines',
  'appointments', 'booking_resources', 'client_reminders',
  'employees', 'time_entries', 'employee_payments', 'payroll_periods',
  'period_closures',
  // v22
  'obligations', 'client_credits', 'entity_attributes',
];
const kSyncApplyOrder = <String>[ /* справочники → зависимые строки */ ];
```

Текущие дубли (`AppDatabase.syncTables`, `_syncApplyOrder`,
`_ensureSyncColumns.tables`, `mergeSnapshot.mappings`, `mochibake`-карта)
остаются только как источник реестра; новые таблицы добавляются **в одном
месте**.

### Б. Миграция v22 (`lib/data/app_database.dart`)

Порядок строго по §4.1.1 общего ТЗ: колонки → таблицы → бэкфилл →
триггеры → `foreign_key_check`. Всё аддитивно (П1): никаких `DROP`,
переименований и смены типов.

Колонки:

```sql
ALTER TABLE materials ADD COLUMN item_id TEXT REFERENCES inventory_items(id) ON DELETE SET NULL;
ALTER TABLE materials ADD COLUMN kind TEXT NOT NULL DEFAULT 'work';
ALTER TABLE materials ADD COLUMN cost_at_order_cents INTEGER NOT NULL DEFAULT 0;
ALTER TABLE materials ADD COLUMN discount_cents INTEGER NOT NULL DEFAULT 0;
ALTER TABLE stock_movements ADD COLUMN reason TEXT;
ALTER TABLE stock_movements ADD COLUMN ref_type TEXT;
ALTER TABLE stock_movements ADD COLUMN ref_id TEXT;
ALTER TABLE stock_movements ADD COLUMN location_id TEXT;
ALTER TABLE stock_movements ADD COLUMN unit_cost_cents INTEGER NOT NULL DEFAULT 0;
ALTER TABLE money_transactions ADD COLUMN obligation_id TEXT;
ALTER TABLE inventory_items ADD COLUMN warranty_days INTEGER NOT NULL DEFAULT 0;
ALTER TABLE job_stages ADD COLUMN lead_hours REAL;
ALTER TABLE jobs ADD COLUMN delivered_at INTEGER;
```

Таблицы: `obligations`, `client_credits`, `entity_attributes` — полные
DDL в §4.1 общего ТЗ. Индексы: `idx_materials_item`,
`idx_stock_moves_ref`, `idx_oblig_due` (частичный), `idx_oblig_job`,
`idx_oblig_counterparty`, `idx_credits_client`, `idx_attr_unique`
(частичный уникальный), `idx_attr_entity`.

Бэкфилл (только при `oldVersion < 22`, идемпотентно):
1. закупки с недоплатой → `obligations(payable, supplier_bill)`;
2. заказы с недоплатой → `obligations(receivable, client_payment)`;
3. `stock_movements.unit_cost_cents` = текущая `cost_cents` позиции;
4. `materials.cost_at_order_cents` = 0 (историю не восстанавливаем).

Пакетами по 200 строк в транзакции, с записью в `audit_log`
(`backup.migrate`), чтобы на большой базе не блокировать приложение.

Обновляются **одновременно**: `onCreate`, `_upgradeSchema` и
`restoreFromBackup()` — иначе web и Android разойдутся.

### В. Единая точка изменения остатка (`lib/state/masters_store.dart`)

```dart
Future<void> adjustStock(
  String itemId,
  double delta, {
  String? reason,      // spoilage / breakage / sample / expiry / inventory / other
  String? refType,     // job / purchase / transfer / manual
  String? refId,
  String? locationId,  // NULL = основной склад (до Э5)
  int? unitCostCents,
  String? note,
});
Future<void> applyJobStock(String jobId, {Set<String>? lineIds}); // списание по строкам заказа
```

На `adjustStock` переводятся: `receiveStock`, `writeOffStock`,
`createPurchase` (часть про остаток), сохранение из калькулятора.
`applyJobStock` добавляется как API, использование — в Э1.

Критерий: `grep -n "stockQty:" lib/state/masters_store.dart` не находит
изменений остатка вне `adjustStock`.

### Г. Валюта и налоговый профиль

1. `MoneyFormat` (`lib/core/money_format.dart`, новый): символ, число знаков,
   разделители, форматирование отрицательных. Источник — настройки
   (`currency_code`, `currency_symbol`, `currency_decimals`,
   `money_separators`), значения по умолчанию — текущее поведение (₽, 0 знаков).
2. Замена всех 65 вхождений `₽` в `lib/` (включая `document_service.dart`
   PDF и Excel-экспорт) на `MoneyFormat`. Локальные хелперы
   `String _money(int cents) => '… ₽'` в экранах удаляются: остаётся один
   источник.
3. `TaxProfile`: поддержка пользовательского профиля (название, страна,
   ставка, лимит дохода, период). Пресеты RU/KZ/US остаются как быстрый
   выбор; список больше не является закрытым.

### Д. Себестоимость заказа (`store.jobCostCents(jobId)`)

Считает Σ `cost_at_order_cents × quantity` по строкам заказа; если строк нет
или у всех снимок 0 — возвращает прежнее `jobs.cost_cents` (ручное
значение), чтобы старые заказы не «обнулились».

### Е. UI (минимум)

Новых экранов нет. В настройках, раздел «Деньги» (существующие
`SectionLabel` / `AppCard` / `ListRow` / шиты):

- «Валюта» — символ, число знаков, разделитель (шит с полями);
- «Свой налоговый профиль» — название, ставка, лимит дохода, период
  (шит; после сохранения профиль выбирается активным).

## Не входит / запреты

- Никаких новых нижних вкладок и новых экранов (П7).
- Не менять `materials` структурно иначе как добавлением колонок; имя
  таблицы сохраняется (П2).
- Не удалять `recipe_lines` (помечается устаревшей, используется только
  `inventory_compositions`).
- Не трогать параллельные задачи: `unified_booking`, `work_sessions` (v16),
  логику закрытых периодов.
- Без новых зависимостей в `pubspec.yaml`.

## Тесты (обязательные)

| Файл | Что проверяет |
|---|---|
| `test/migration_v22_test.dart` | апгрейд с фикстуры v21 → v22: колонки, таблицы, индексы, `user_version=22`, идемпотентность бэкфилла |
| `test/backup_registry_test.dart` | каждая таблица реестра есть в бэкапе; restore не теряет строки; merge не дублирует; для каждой таблицы есть audit- и sync-триггер (`sqlite_master`) |
| `test/stock_adjust_test.dart` | остаток меняется только через `adjustStock`; движение пишется с причиной и ссылкой; откат при недостатке (если включено) |
| `test/job_cost_test.dart` | себестоимость = Σ снимков; заказ без строк возвращает ручное значение |
| `test/money_format_test.dart` | формат из настроек (символ, знаки, разделители); `grep` по `lib/` не находит `₽` |

Фикстура: `test/fixtures/dbs/v21.db` (генератор — `migration_fixture_test`).

## Критерии приёмки

- `flutter analyze --no-pub` — 0 ошибок.
- `flutter test` — все зелёные, включая 5 новых тестов и `database_test`
  с ожиданием v22.
- Бэкап v8 восстанавливается на v22 без потерь; новый бэкап — формат **9**.
- `flutter build apk --release` и `flutter build web --release` проходят.
- Миграция проверена на копии реальной базы (`backupData()` с устройства).
- В `lib/` нет `₽`; остаток меняется только через `adjustStock`.
- Версия `pubspec.yaml` → `0.4.0+22`, запись в `docs/specs/_queue.md`.

## Коммиты

1. `Add table registry and rebuild backup/sync/audit on it` — реестр, без
   смены схемы (тесты остаются зелёными на v21).
2. `Migrate schema to v22: order lines, obligations, credits, attributes` —
   миграция + фикстура + `migration_v22_test`.
3. `Route all stock changes through adjustStock` — точка изменения остатка.
4. `Add MoneyFormat and custom tax profile` — валюта, налоговый профиль,
   замена `₽`, bump `0.4.0+22`.

Push после каждого коммита: `git pull --rebase` **без** `--autostash`, при
чистом дереве.

## Риски

| Риск | Мера |
|---|---|
| Бэкфилл обязательств создаёт много записей | пакеты по 200, `audit_log`, тест на фикстуре с 500 заказами |
| Двойной учёт долгов после `obligations` | инвариант «Σ obligations по заказу = `price_cents`», тест; старые расчёты (`clientDebtCents`) в этом этапе **не** удаляются, но помечаются как подлежащие замене в Э2 |
| Реестр ломает существующие триггеры | тест `backup_registry_test` сравнивает набор триггеров до/после |
| Замена `₽` меняет вид сумм в PDF | тест форматирования + визуальная проверка PDF наряда и P&L |
| Миграция портит данные | бэкап перед апгрейдом предлагается пользователю; сначала бета-канал зеркала, затем stable |
