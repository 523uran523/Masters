# ТЗ: универсальный учёт для малого бизнеса — план доработок Masters

Статус: **ТЗ финализировано, решения по §12 приняты, реализация не начата**.
Дата: 05.11.2026. База: **0.3.18+21**, схема БД **v21**, `flutter test` 131/131.
Документ заменяет прежнюю аналитику «кондитерка»: она сохранена в
Приложении A как обоснование, а рабочая часть — это ТЗ ниже.

Как читать:
- §0 — план действий по пунктам: что делаем, в каком порядке, чем закрываем;
- §1–§3 — цель, границы и правила, которые **экономят переделки**;
- §4 — целевая модель данных (что и когда добавляется в схему);
- §5 — последовательность разработки по этапам (слаги, объём, DoD, файлы);
- §6 — UI-спецификация: где что лежит, из чего собрано, какие состояния;
- §7–§11 — шаблоны работы, миграции/синхронизация, тесты, метрики, риски;
- §12 — принятые решения (ранее «открытые вопросы» — закрыты).

---

## 0. План действий по пунктам

Сводный порядок работ. Пункты 1–3 — подготовка, 4–12 — этапы разработки,
13–15 — приёмка и выпуск. Каждый этап заканчивается пунктом «DoD» (см. §5).

| № | Действие | Результат | Где описано |
|---|---|---|---|
| 1 | Зафиксировать правила П1–П10 как обязательные для всех этапов | раздел-контракт, нарушение = переделка | §3 |
| 2 | Ввести реестр таблиц `lib/data/schema_tables.dart` и перевести на него audit-триггеры, `sync_outbox`, `backupData`, `restoreFromBackup`, `mergeFromBackup` | добавление таблицы = 1 строка | §4.4, §5.1 |
| 3 | Поднять схему до v22 одной аддитивной миграцией (+ фикстура v21, тест, бэкфилл) | `migration_v22_test` зелёный | §4.1, §5.1 |
| 4 | Э0 `foundation-v22`: `adjustStock`, `MoneyFormat`, свой налоговый профиль, `jobCostCents` | релиз 0.4.0, analyze 0 ошибок | §5.1 |
| 5 | Э1 `catalog-order-lines`: строки заказа из каталога, маржа по строке, `CatalogScreen`, новая `JobFormScreen` | релиз 0.4.1 | §5.2 |
| 6 | Э2 `money-plan`: `obligations`, дебиторка по заказу, платёжный календарь, сегмент «План» в Деньгах | релиз 0.4.2 | §5.3 |
| 7 | Э3 `leads-quotes`: заявки, КП-снимок, конверсия в заказ | релиз 0.4.3 | §5.4 |
| 8 | Э4 `client-credits`: депозиты, абонементы, сертификаты, залоги (отложенная выручка) | релиз 0.4.4 | §5.5 |
| 9 | Э5 `stock-locations`: точки, партии/FEFO, приёмка, план производства | релиз 0.4.5 | §5.6 |
| 10 | Э6 `warranty-service`: гарантия по позиции, обращения, влияние на маржу | релиз 0.4.6 | §5.7 |
| 11 | Э7 `team-shifts`: смены, задания, роли (UI + сервер meaxis-sync) | релиз 0.4.7 | §5.8 |
| 12 | Э8 `owner-analytics`: показатели, экспорт PDF/XLSX, шаблоны работы T1–T10 | релиз 0.4.8 | §5.9, §7 |
| 13 | Проверка каждого этапа: `flutter analyze --no-pub` (0 ошибок), полный `flutter test`, сборка apk+web | обязательный шлюз | §9 |
| 14 | Проверка миграции на копии реальной базы (снятый с устройства бэкап) и на веб-профиле (wasm) | нет расхождений web/Android | §8, §9 |
| 15 | Выпуск: bump `pubspec.yaml`, запись в `docs/specs/_queue.md`, публикация (основной сервер, затем зеркало) | релиз закрыт | §5, `docs/specs/_queue.md` |

Правило порядка: **ни один этап не стартует до закрытия предыдущего**
(исключение — Э3 ∥ Э4: файлы не пересекаются). Любая новая идея по ходу
работы идёт в бэклог, а не в текущий этап.

---

## 1. Цель, границы, критерии успеха

### 1.1 Цель

Сделать Masters пригодным для **любого малого бизнеса**, где есть заказ,
исполнение и деньги: от соло-мастера до цеха с двумя точками. Бизнес
приходит за тремя вещами: **посчитать деньги** (доходы/расходы/маржа),
**не потерять работу** (сроки, ресурсы, обязательства), **увидеть, что
происходит** (отчёты и метрики). Всё остальное — следствия.

### 1.2 Границы: чего в этом ТЗ нет

- Полная бухгалтерия (регистры НДС, ТОРГ-12, партионный учёт «для
  налоговой»), интеграция с кассами и эквайрингом, ЭДО.
- Клиентский портал/онлайн-запись как продукт (только задел: лиды и ссылка
  на КП).
- Многоскладской учёт с пересортицей и инвентаризационными описями
  уровня ERP.
- Переписывание существующих экранов «с нуля». Только аддитивные
  изменения + точечная реструктуризация форм.

### 1.3 Критерии успеха (проверяемые)

1. Новый пользователь выбирает шаблон работы (T1–T10) и **получает рабочий
   процесс за 2 минуты**: каталог-пример, колонки, напоминания, отчёты.
2. Заказ создаётся из каталога в 2–3 действия, себестоимость и маржа
   считаются **автоматически** из состава и склада, без ручных чисел.
3. По каждому заказу видно: сколько должны, когда, и просрочено ли.
4. На вопрос «хватит ли денег 12-го» приложение отвечает на одном экране.
5. Ни одного `if (businessType == ...)` в коде; ни одного `₽` в `lib/`.
6. Каждый этап закрывается релизом: analyze 0 ошибок, полный `flutter test`
   зелёный, миграция с v21 проверена на фикстуре.
7. Депозит клиента не попадает в выручку до оказания услуги: выручка =
   поступления − Δ обязательств (§12.1), проверяется тестом.
8. Соло-мастер не видит ни одной сущности «локация», «роль», «смена», пока
   сам не включит соответствующий блок (§12.2, §12.3).
9. Согласованное КП невозможно изменить задним числом: правка создаёт
   ревизию (§12.4).
10. Цифры «Панели собственника» совпадают между экраном, PDF и XLSX
    (§12.5) — тест сравнивает три источника.

---

## 2. Исходные данные: что уже есть (сверка с кодом)

Проверено по `lib/data/app_database.dart` (v21), моделям, `MastersStore` и
экранам. Ключевое: часть «недостающего» уже реализована **как расчёт без
UI**, а часть цепочек разорвана.

| Область | Есть сейчас | Разрыв |
|---|---|---|
| Заказы | `jobs` (статус, приоритет, цена, себестоимость, срок, ответственный, теги, вложения), `job_stages`, `materials`, `work_sessions` | `materials` **без `item_id`** → строка заказа не связана со складом; `cost_cents` — ручное число |
| Склад | `inventory_items` (kind good/service, unit, sell/cost, category, track_stock, min_qty), `inventory_compositions` (is_labor), `stock_movements` (in/out/writeoff/adjust), `suppliers`, `purchases`+`purchase_lines` | две модели состава (`recipe_lines` почти не используется); у списания нет причины; нет локаций и партий |
| Деньги | `accounts`, `cash_shifts`, `money_transactions` (kind: income/expense/sale/payment/refund/transfer/debt/adjustment/payroll), `recurring_payments`, `period_closures`, прогноз до конца месяца | нет плана оплаты по заказу, нет дат у обязательств, `refund` не создаётся в UI |
| Долги | `paidForJob()`, `clientDebtCents()`, `supplierDebtCents()`, «закрыть с долгом», секция «Должны мне» в Деньгах | долг клиента считается по клиенту, а не по заказу; у долга нет даты и просрочки |
| Клиенты | `clients` (имя, телефон, заметка), `client_reminders` (type/due_at/status), авто-напоминание «проверить гарантию» через 180 дней | нет дня рождения, предпочтений, «как в прошлый раз», RFM |
| Команда | `employees`, `time_entries`, `employee_payments`, `payroll_periods`, таймер `work_sessions` | нет смен, заданий, ролей |
| Отчёты | «Итоги»: прибыль, маржа заказов, число заказов, наработка; PDF (наряд, P&L, ведомость, расчётный лист) | нет маржи по позиции, потерь, оборачиваемости, DSO, no-show |
| Настройки | `work_mode`, `modules`, `hidden_tabs_v2`, `team_enabled`, `calculator_enabled`, `job_tags`, налоговые профили, радар | валюта захардкожена (65 `₽`), налоговый профиль только из фиксированного списка |
| Синхронизация | `sync_outbox`, audit-триггеры, JSON-бэкап v8, Яндекс.Диск, meaxis-sync (LWW) | каждая новая таблица требует правок в 4 местах (backup/restore/merge/audit) |

**Шесть фактов, определяющих порядок работ:**

1. Строка заказа не знает, из какого складского товара она сделана →
   автоматическая себестоимость и списание невозможны. Это блокер №1.
2. Калькулятор умеет сохранить ресурс на склад, но не создаёт строку
   заказа — один расчёт живёт в двух местах.
3. Долг клиента = «цена всех заказов − все входящие платежи», поэтому
   переплата по одному заказу гасит долг по другому.
4. Прогноз денег не знает дат обязательств (поставщик, налог, зарплата) —
   это не платёжный календарь.
5. Две модели состава → нужна одна, иначе каталог и склад разойдутся.
6. Валюта и налоговые ставки зашиты → «универсальность» пока декларация.

---

## 3. Правила, которые экономят переделки

Это главный раздел: если их нарушить, каждый следующий этап потребует
переписывать предыдущий.

**П1. Одна миграция на этап, только аддитивная.**
Новые колонки — nullable, новые таблицы — с нуля. Никаких `DROP`,
переименований и смены типов в том же релизе. Удаление старого — отдельным
этапом, после того как новый путь покрыт тестами.

**П2. Одна сущность — один смысл.**
`materials` остаётся таблицей строк заказа (имя не меняем, чтобы не ломать
миграции, бэкап и синхронизацию). `inventory_compositions` — единственная
модель состава; `recipe_lines` помечается устаревшей и не используется.
Новая функциональность расширяет существующее, а не заводит параллельное.

**П3. Все изменения остатка — через одну точку.**
`store.adjustStock(itemId, delta, {reason, refType, refId})` пишет
`stock_movements` и обновляет остаток. Сейчас остаток меняется в четырёх
местах — после введения локаций и партий это пришлось бы переделывать
целиком.

**П4. Деньги-обязательства — единая таблица.**
Дебиторка клиента, долг поставщику, налог, зарплата, аренда — это
`obligations` с направлением и датой. Из них автоматически собирается
платёжный календарь. Нельзя делать три отдельных механизма.

**П5. Реестр таблиц — один список.**
Названия синхронизируемых таблиц живут в одном месте и используются для
audit-триггеров, `sync_outbox`, `backupData`, `restoreFromBackup`,
`mergeFromBackup`. Добавление таблицы = одна строка, а не четыре правки.

**П6. Домен — в данных, не в коде.**
Параметры изделия/услуги/клиента (вес, вкус, VIN, аллергия, этаж) —
это `entity_attributes` (ключ-значение). Код не знает слов «торт» и
«аллергия».

**П7. Никаких новых нижних вкладок.**
Их уже шесть (Сегодня, Клиенты, События, Деньги, Склад, Ещё). Новые экраны
живут внутри существующих разделов, сегментов и карточек. Это сохраняет
`hidden_tabs_v2` и не ломает привычку.

**П8. Каждый блок — под флагом.**
Новый блок включается настройкой (`module_*`), при выключении экраны
скрыты, данные в схеме остаются. Это даёт «универсальность без режимов».

**П9. Деньги — через форматтер.**
`MoneyFormat` из настроек (символ, число знаков, разделители). Прямая
интерполяция `₽` в коде запрещена.

**П10. Этап без тестов не закрывается.**
Минимум: тест миграции (v21 → vN на фикстуре), тест расчёта, тест
backup/restore с новой таблицей.

---

## 4. Целевая модель данных

### 4.1 Схема v22 — «фундамент» (один релиз, покрывает этапы 0–2 и 4)

Все изменения аддитивные. Порядок применения внутри `_upgradeSchema`:
новые таблицы → новые колонки → бэкфилл → индексы.

**a) Строки заказа (`materials`) — расширение, не замена**

```sql
ALTER TABLE materials ADD COLUMN item_id TEXT REFERENCES inventory_items(id) ON DELETE SET NULL;
ALTER TABLE materials ADD COLUMN kind TEXT NOT NULL DEFAULT 'work';  -- work / good
ALTER TABLE materials ADD COLUMN cost_at_order_cents INTEGER NOT NULL DEFAULT 0;
ALTER TABLE materials ADD COLUMN discount_cents INTEGER NOT NULL DEFAULT 0;
CREATE INDEX idx_materials_item ON materials(item_id);
```

Смысл: `price_cents` — цена продажи строки, `cost_at_order_cents` —
**снимок** себестоимости на момент добавления (правка цены товара не
меняет историю). `jobs.cost_cents` становится производным: сумма
`cost_at_order_cents × quantity` по строкам (при отсутствии строк —
прежнее ручное значение, чтобы старые данные не «обнулились»).

**b) Движения склада (`stock_movements`) — причина и ссылки**

```sql
ALTER TABLE stock_movements ADD COLUMN reason TEXT;      -- spoilage / breakage / sample / expiry / inventory / other
ALTER TABLE stock_movements ADD COLUMN ref_type TEXT;    -- job / purchase / transfer / manual
ALTER TABLE stock_movements ADD COLUMN ref_id TEXT;
ALTER TABLE stock_movements ADD COLUMN location_id TEXT; -- NULL = основной склад (до этапа 5)
ALTER TABLE stock_movements ADD COLUMN unit_cost_cents INTEGER NOT NULL DEFAULT 0;
CREATE INDEX idx_stock_moves_ref ON stock_movements(ref_type, ref_id);
```

**c) Обязательства (`obligations`) — новая таблица**

```sql
CREATE TABLE obligations (
  id TEXT PRIMARY KEY,
  direction TEXT NOT NULL,             -- receivable (нам должны) / payable (мы должны)
  kind TEXT NOT NULL,                  -- client_payment / supplier_bill / tax / salary / rent / loan / other
  counterparty_type TEXT,              -- client / supplier / employee / none
  counterparty_id TEXT,
  job_id TEXT REFERENCES jobs(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  amount_cents INTEGER NOT NULL,
  paid_cents INTEGER NOT NULL DEFAULT 0,
  due_at INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'planned', -- planned / partial / paid / cancelled
  account_id TEXT REFERENCES accounts(id) ON DELETE SET NULL,
  note TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  device_id TEXT
);
CREATE INDEX idx_oblig_due ON obligations(due_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_oblig_job ON obligations(job_id);
CREATE INDEX idx_oblig_counterparty ON obligations(counterparty_type, counterparty_id);
```

`money_transactions` получает `obligation_id TEXT` — оплата обязательства
обновляет `paid_cents` и `status` (единая точка, никакой двойной
бухгалтерии).

**d) Деньги клиента (`client_credits`) — новая таблица**

```sql
CREATE TABLE client_credits (
  id TEXT PRIMARY KEY,
  client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  kind TEXT NOT NULL,                  -- deposit / pass / certificate / rental_deposit
  title TEXT NOT NULL,
  amount_cents INTEGER NOT NULL,       -- номинал
  remaining_cents INTEGER NOT NULL,    -- остаток денег
  units_total INTEGER,                 -- для абонемента: занятий куплено
  units_left INTEGER,                  -- осталось
  expires_at INTEGER,
  status TEXT NOT NULL DEFAULT 'active', -- active / used / expired / refunded
  note TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  device_id TEXT
);
CREATE INDEX idx_credits_client ON client_credits(client_id, status);
```

**e) Атрибуты сущностей (`entity_attributes`) — новая таблица**

```sql
CREATE TABLE entity_attributes (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,   -- item / job / client
  entity_id TEXT NOT NULL,
  key TEXT NOT NULL,
  value_text TEXT,
  value_num REAL,
  sort_order REAL NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  device_id TEXT
);
CREATE UNIQUE INDEX idx_attr_unique ON entity_attributes(entity_type, entity_id, key) WHERE deleted_at IS NULL;
CREATE INDEX idx_attr_entity ON entity_attributes(entity_type, entity_id);
```

Одна таблица закрывает: параметры изделия (вес/вкус/размер), параметры
заказа (адрес доставки, окно времени), свойства клиента (аллергии,
предпочтения, день рождения как `birthday`).

**f) Задел на этап 5 (колонки, без UI)**

```sql
ALTER TABLE inventory_items ADD COLUMN warranty_days INTEGER NOT NULL DEFAULT 0;
ALTER TABLE job_stages ADD COLUMN lead_hours REAL;   -- длительность операции
ALTER TABLE jobs ADD COLUMN delivered_at INTEGER;    -- факт выдачи
```

**g) Бэкфилл (в той же миграции, идемпотентно)**

1. Для каждой закупки с `paid < total` создать `obligation(payable,
   supplier_bill, counterparty=supplier, amount=total, paid_cents=paid,
   due_at=created_at)`.
2. Для каждого незакрытого по оплате заказа (`price > paidForJob`)
   создать `obligation(receivable, client_payment, counterparty=client,
   job_id, amount=price, paid_cents=paid, due_at=due_date ?? created_at)`.
3. `stock_movements.unit_cost_cents` заполнить текущей `cost_cents`
   позиции (для оценки потерь задним числом — приблизительно).
4. `materials.cost_at_order_cents` оставить 0 (историю не восстанавливаем,
   отчёт по марже начинает работать с новых заказов).

Бэкфилл выполняется только при переходе `oldVersion < 22`; повторный
запуск ничего не дублирует (проверка «уже есть obligation на этот
purchase/job»).

**h) Настройки (SharedPreferences, без схемы)**

`currency_code`, `currency_symbol`, `currency_decimals`,
`money_separators`, `custom_tax_profile` (ставка/лимит/период/название),
`daily_capacity_minutes`, `payment_reminder_days` (по умолчанию 2),
`default_prepayment_percent`, `app_role` (owner по умолчанию),
флаги блоков: `module_leads`, `module_credits`, `module_locations`,
`module_shifts`, `module_warranty`, `module_analytics`.

Правило: флаг только скрывает UI, данные в схеме остаются (П8). Ключи
добавляются в `settings_controller.dart` тем же этапом, что и UI, — чтобы
не тащить «настройку без потребителя».

### 4.1.1 Порядок работ внутри миграции v22

Строгий порядок, иначе бэкфилл не найдёт таблиц, а триггеры — колонок:

1. `ALTER TABLE materials` (+ индексы `idx_materials_item`);
2. `ALTER TABLE stock_movements` (+ индекс `idx_stock_moves_ref`);
3. `ALTER TABLE money_transactions ADD COLUMN obligation_id TEXT`;
4. `ALTER TABLE inventory_items ADD COLUMN warranty_days`,
   `ALTER TABLE job_stages ADD COLUMN lead_hours`,
   `ALTER TABLE jobs ADD COLUMN delivered_at`;
5. `CREATE TABLE obligations`, `client_credits`, `entity_attributes`
   (+ индексы, включая частичный уникальный по атрибутам);
6. бэкфилл обязательств и `unit_cost_cents` (пакетами по 200, в одной
   транзакции на пакет, с записью в `audit_log`);
7. audit-триггеры и `sync_outbox`-триггеры для новых таблиц — из реестра
   (§4.4), а не копипастой;
8. проверка `PRAGMA foreign_key_check` — пусто, иначе миграция падает и
   транзакция откатывается (пользователь видит сообщение с предложением
   восстановить бэкап).

Шаги 1–5 идемпотентны по своей природе (`ALTER ... ADD COLUMN` в
`try/catch`, `CREATE TABLE IF NOT EXISTS`), шаг 6 защищён проверкой
«obligation на этот job/purchase уже существует».

### 4.2 Схема v23–v26 — поздние этапы

| Версия | Этап | Что добавляется |
|---|---|---|
| v23 | Э3 | `leads` (источник, запрос, бюджет, статус, next_step_at, конвертация в job), `jobs.lead_id`, `quotes` (number, revision, total_cents, snapshot_json, pdf_path, sent_at, status — снимок КП по решению §12.4) |
| v24 | Э5 | `locations` (workshop/store/warehouse), `stock_levels` (item, location, qty, min_qty), `stock_batches` (item, location, qty, expires_at, unit_cost), `transfers`+`transfer_lines`, `purchases.received_at`/`purchase_lines.received_qty`; всё создаётся независимо от `module_locations` (решение §12.2) |
| v25 | Э6 | `warranty_claims` (job_id, item_id, opened_at, resolved_at, cost_cents, outcome) |
| v26 | Э7 | `work_shifts` (employee, starts_at, ends_at, location), `shift_tasks` (shift, title, qty_planned, qty_done, job_id, status), `employees.app_role`; серверный `role` в токене meaxis-sync (решение §12.3) |

Правило «одна миграция на этап» (П1) действует и здесь: каждая версия —
только `CREATE TABLE`/`ALTER TABLE ADD COLUMN` + индексы, без удалений и
переименований. Каждая новая таблица в том же коммите попадает в реестр
(§4.4), иначе она не будет ни в бэкапе, ни в синхронизации.

### 4.3 Правила миграций

- `onCreate` (новая установка) и `_upgradeSchema` (обновление) **и**
  `restoreFromBackup()` обновляются одновременно — иначе веб и Android
  разойдутся (в проекте это уже записано в README, соблюдаем).
- Каждая миграция имеет фикстуру: `test/fixtures/db_v21.db` + тест
  `test/migration_v22_test.dart` (создать схему v21, применить апгрейд,
  проверить наличие колонок/таблиц и результат бэкфилла).
- Веб (IndexedDB через wasm): миграция выполняется тем же SQL; запрещены
  `PRAGMA`-зависимые трюки, только стандартный DDL SQLite.
- Откат: приложение не умеет «вниз»; поэтому миграция сначала выходит в
  бета-канал зеркала, потом в stable.

### 4.4 Реестр таблиц (П5)

Единый список в `lib/data/schema_tables.dart`:

```dart
const kSyncedTables = <String>[
  'clients', 'objects', 'jobs', 'job_stages', 'materials', 'work_sessions',
  'accounts', 'cash_shifts', 'money_transactions', 'recurring_payments',
  'inventory_items', 'inventory_compositions', 'stock_movements',
  'suppliers', 'purchases', 'purchase_lines',
  'appointments', 'booking_resources', 'client_reminders',
  'employees', 'time_entries', 'employee_payments', 'payroll_periods',
  'period_closures',
  // v22
  'obligations', 'client_credits', 'entity_attributes',
];
```

Из него генерируются: audit-триггеры, `sync_outbox`-подписки, ключи
бэкапа, порядок restore/merge. Версия формата бэкапа: 8 → **9**.

---

## 5. Последовательность разработки

### 5.0 Обзор

| Этап | Слаг | Блоки | Схема | Новый UI | Объём | Решение §12 |
|---|---|---|---|---|---|---|
| Э0 | `foundation-v22` | П3, П5, П9, П10 | v22 | нет | M (3–4 дн) | — |
| Э1 | `catalog-order-lines` | B1, B2 | — | Каталог, форма заказа | L (5–6 дн) | — |
| Э2 | `money-plan` | B3, B17 | — | «План» в Деньгах, дебиторка | L (5–6 дн) | — |
| Э3 | `leads-quotes` | B15 | v23 | Заявки, КП | M (3–4 дн) | 12.4 (КП-снимок) |
| Э4 | `client-credits` | B16 | — | «Деньги клиента» | M (3–4 дн) | 12.1 (отложенная выручка) |
| Э5 | `stock-locations` | B6, B7, B18, B19 | v24 | Точки, партии, приёмка | XL (8–10 дн) | 12.2 (флаг локаций) |
| Э6 | `warranty-service` | B20 | v25 | Гарантия | S (2 дн) | — |
| Э7 | `team-shifts` | B8, B9 | v26 | Смены, задания, роли | L (6–7 дн) | 12.3 (серверные роли) |
| Э8 | `owner-analytics` | B22 | — | Аналитика собственника | M (4 дн) | 12.5 (PDF + XLSX) |

Порядок жёсткий: Э0 → Э1 → Э2 → (Э3 ∥ Э4) → Э5 → Э6 → Э7 → Э8.
Э3 и Э4 не зависят друг от друга (можно параллельно, файлы не пересекаются).
Э5 идёт после Э1/Э2, потому что опирается на `adjustStock` и обязательства.

Каждый этап = один коммит-релиз с бампом версии (0.4.x) и записью в
`docs/specs/_queue.md`. Спецификация этапа — отдельный файл в `docs/specs/`
(по образцу Э0: `2026-11-05-foundation-v22.md`), этот документ остаётся
общим ТЗ и картой.

**Что даёт каждый этап пользователю (проверка «не делаем лишнего»):**

| Этап | Пользователь после релиза может |
|---|---|
| Э0 | ничего нового не видит; получает валюту и свой налоговый профиль в настройках |
| Э1 | собрать заказ из каталога и увидеть маржу по каждой строке |
| Э2 | узнать, кто сколько должен и когда, и хватит ли денег на 6 недель вперёд |
| Э3 | не потерять обращение: вести заявку и отправить КП-снимок |
| Э4 | продать абонемент/сертификат и видеть, сколько он должен клиенту |
| Э5 | вести две точки, партии со сроками и понимать, что заказать на завтра |
| Э6 | принять изделие по гарантии и увидеть, как это съело маржу |
| Э7 | выдать смене задания и не пустить работника в зарплаты и закупки |
| Э8 | увидеть показатели бизнеса и выгрузить их в PDF/Excel |

---

### 5.1 Э0. Фундамент (`foundation-v22`)

**Цель:** подготовить схему и «проводку» так, чтобы Э1–Э4 не требовали
новых миграций и правок в четырёх местах.

**Работы:**

1. `schema_tables.dart` — реестр таблиц; переписать `backupData`,
   `restoreFromBackup`, `mergeFromBackup` и генерацию audit-триггеров на
   обход реестра. Формат бэкапа 8 → 9 (старые копии читаются: неизвестные
   ключи игнорируются, отсутствующие таблицы — пустые).
2. Миграция v22 (§4.1 a–g) + фикстура и тест.
3. `store.adjustStock(itemId, delta, {reason, refType, refId})`; перевести
   на него `createPurchase`, `writeOffStock`, сохранение из калькулятора.
   Добавить `store.applyJobStock(jobId)` — списание по строкам заказа.
4. `MoneyFormat` + `currency_*` в настройках; заменить 65 вхождений `₽`
   (включая PDF и Excel-экспорт).
5. `TaxProfile` — поддержка пользовательского профиля (не только список
   RU/KZ/US): ставка, лимит, период, название.
6. `store.jobCostCents(jobId)` — расчёт себестоимости из строк, с
   фолбэком на ручное значение.

**UI:** нет. Только настройки: раздел «Деньги» получает «Валюта» и
«Свой налоговый профиль» (существующие `SectionLabel`/`ListRow`/шиты).

**DoD:**
- `flutter analyze` — 0 ошибок; `flutter test` — все зелёные + 5 новых тестов
  (`migration_v22_test`, `backup_registry_test`, `money_format_test`,
  `stock_adjust_test`, `job_cost_test`);
- бэкап v8 восстанавливается на v22 без потерь (тест);
- создание/списание остатка идёт только через `adjustStock` (проверка
  grep по `stockQty:` в `masters_store.dart`).

**Риск:** бэкфилл обязательств может создать много записей на большой базе.
Решение: выполнять в транзакции пакетами по 200, лог в `audit_log`.

---

### 5.2 Э1. Каталог и строки заказа (`catalog-order-lines`)

**Цель:** заказ перестаёт быть «название + заметка»; цена, себестоимость и
маржа считаются из каталога.

**Работы:**

1. `store`:
   - `createJobLine(jobId, {itemId, kind, qty, unit, priceCents, costAtOrderCents})`,
     `updateJobLine`, `deleteJobLine`, `jobLines(jobId)`;
   - `addLineFromCatalog(jobId, itemId, qty)` — подставляет цену, единицу,
     себестоимость из позиции и её состава;
   - `store.itemAttributes(itemId)` / `setItemAttribute` (через
     `entity_attributes`);
   - `recalcJobTotals(jobId)` — цена = Σ строк, себестоимость = Σ снимков.
2. Модель `MaterialItem` расширяется полями `itemId`, `kind`,
   `costAtOrderCents`; `totalCents` учитывает `discountCents`.
3. Каталог = `inventory_items` с `kind` + атрибуты + `photo_path`.
   Экран `CatalogScreen` (см. §6.4).
4. Форма заказа перестраивается по §6.3; выбор из каталога — шит с поиском
   и фильтром «Товары/Услуги».
5. Калькулятор v2 получает кнопку «Добавить в заказ» (создаёт строку и,
   если пользователь подтвердил, списывает со склада через `adjustStock`).
6. При переходе заказа в `done` — предложение «Списать материалы по
   составу» (диалог со списком и возможностью снять галочки).

**UI:** `CatalogScreen`, шит позиции каталога, переработанная
`JobFormScreen`, блок «Работы и товары» и «Итого» в `JobDetailScreen`.

**DoD:**
- маржа заказа = Σ(цена − снимок себестоимости) по строкам; ручной ввод
  `cost_cents` остаётся только для заказов без строк (и помечен как
  «вручную»);
- изменение цены товара не меняет маржу прошлых заказов (тест);
- тесты: `job_lines_test`, `catalog_attributes_test`, `job_margin_test`.

**Зависимости:** Э0 (`adjustStock`, `entity_attributes`).

---

### 5.3 Э2. Деньги по плану (`money-plan`)

**Цель:** по каждому заказу видно «сколько, когда и просрочено ли»; по
бизнесу — «хватит ли денег».

**Работы:**

1. `store.syncJobObligations(jobId)` — поддерживает инвариант «Σ
   obligations по заказу = `price_cents`». Вызывается при создании заказа,
   изменении цены, оплате.
2. План оплаты: `setJobPaymentPlan(jobId, [аванс% с датой, доплата])` —
   создаёт/обновляет `obligations` (`kind=client_payment`).
3. `store.payObligation(id, {amountCents, accountId})` — создаёт
   `money_transactions` (`kind=sale`/`payment`, `obligation_id`) и обновляет
   `paid_cents`/`status`.
4. Дебиторка: `store.receivables()` → список obligations с
   `direction=receivable`, `status != paid`, с флагом `overdue`.
   `clientDebtCents` переписывается на сумму остатков (расчёт по заказам,
   а не по клиенту целиком).
5. Кредиторка: `store.payables()`; `supplierDebtCents` = сумма остатков
   obligations поставщика (закупки продолжают создавать obligations).
6. Платёжный календарь: `store.cashPlan({weeks})` → по дням: остаток на
   начало, поступления (receivable + `recurring_payments` in), платежи
   (payable + налог + зарплата + `recurring_payments` out), остаток на
   конец, флаг разрыва. Налог — obligation, создаваемая при закрытии
   периода (или вручную).
7. Напоминания: `client_reminders` с `type='payment_due'` за N дней до
   `due_at` (N в настройках, по умолчанию 2).

**UI:** 4-й сегмент «План» в Деньгах, блок «Должны мне» → карточки с датой
и просрочкой, блок «Оплата» в карточке заказа (§6.2, §6.5, §6.6).

**DoD:**
- переплата по одному заказу не гасит долг по другому (тест);
- «закрыть с долгом» создаёт obligation с датой, а не «вечный» долг;
- прогноз на 6 недель совпадает с ручным расчётом на фикстуре;
- тесты: `obligations_test`, `receivables_test`, `cash_plan_test`,
  `payment_reminders_test`.

**Зависимости:** Э0 (таблица obligations), Э1 (цена заказа из строк).

---

### 5.4 Э3. Заявки и КП (`leads-quotes`)

**Цель:** не терять обращения, которые ещё не стали заказом.

**Работы:**
1. Миграция v23: `leads` (id, name, phone, client_id, source, request,
   budget_cents, status, next_step_at, note, sync-колонки), `quotes`
   (id, job_id, lead_id, number, revision, total_cents, snapshot_json,
   pdf_path, sent_at, status, sync-колонки), `jobs.lead_id`.
2. Store: `createLead`, `updateLead`, `closeLead(reason)`,
   `convertLeadToJob(leadId, {title, priceCents, dueAt})`,
   `staleLeads()` (next_step_at в прошлом), `leadsFunnel()` (по статусам и
   источникам).
3. `DocumentService.buildQuotePdf(...)` + `store.saveQuoteSnapshot(jobId)`:
   КП — **снимок** (решение §12.4): номер `КП-2026-014`, ревизия, строки,
   итог, срок действия. Правка → новая ревизия, старая хранится.
4. `module_leads` в настройках: экран «Заявки» появляется под флагом.

**UI:** экран «Заявки» (§6.7), карточка заявки, кнопка «КП» в карточке
заказа (меню: «Отправить КП» / «История КП»).

**DoD:** конверсия лида создаёт заказ с перенесёнными клиентом, суммой и
сроком; повторное открытие КП отдаёт **тот же** PDF (снимок не меняется
при правке заказа); отчёт «конверсия лидов» в аналитике; тесты
`leads_test`, `quote_snapshot_test`.

**Зависимости:** Э1 (каталог для КП), Э2 (аванс при конверсии).

---

### 5.5 Э4. Обязательства клиента (`client-credits`)

**Цель:** учитывать чужие деньги — депозиты, абонементы, сертификаты,
залоги, и не путать их с выручкой.

**Работы:**
1. Store: `createClientCredit`, `useClientCredit` (списание денег или
   занятия), `refundClientCredit`, `expireCredits()` (по дате),
   `clientCredits(clientId)`, `clientCreditTotalCents()`.
2. Учёт по решению §12.1 (**отложенная выручка**):
   - поступление за депозит/сертификат создаёт `money_transactions`
     (`kind='income'` или `'sale'`, `direction='in'`) — деньги пришли, ДДС
     вырос;
   - списание кредита **не создаёт второй `money_transactions`** (денег
     снова не приходило). Оно уменьшает `remaining_cents` (и `units_left`)
     и пишется в `audit_log` (`credit.use`); факт оказания услуги виден в
     самом кредите и в карточке клиента;
   - выручка периода считается **одной формулой**:
     `store.revenueCents(period)` = Σ поступлений за период − Δ Σ
     `remaining_cents` за период (Δ = конец минус начало). Один источник,
     один тест, ноль параллельных расчётов; отдельного «счёта отложенной
     выручки» не заводим (§12.1).
3. Плитка «Обязательства перед клиентами» в Деньгах и в отчёте: Σ
   `remaining_cents` по активным кредитам; при `expires_at` в прошлом —
   `status='expired'` (деньги остаются на балансе, обязательство снимается
   только после решения владельца — вернуть или признать выручкой).
4. `module_credits` в настройках.

**UI:** секция «Деньги клиента» в карточке клиента (§6.8), плитка в
Деньгах, списание при закрытии записи/заказа.

**DoD:** списание занятия уменьшает `units_left`; истечение срока меняет
`status`; P&L не считает депозит выручкой дважды (тест: сертификат 3 000 ₽
+ списание 1 200 ₽ → выручка 1 200 ₽, обязательство 1 800 ₽); тесты
`client_credits_test`, `credit_expiry_test`, `deferred_revenue_test`.

**Зависимости:** Э0 (таблица), Э2 (связь с оплатой).

---

### 5.6 Э5. Производство и склад по точкам (`stock-locations`)

**Цель:** несколько точек/складов, партии со сроками, приёмка с
расхождениями, план производства.

**Работы:** миграция v24; `adjustStock` получает `locationId`;
`store.transferStock(from, to, lines)`; `store.receivePurchase(purchaseId,
receivedLines)` (расхождения → корректировка obligations и себестоимости);
`store.stockBatches(itemId)` и FEFO-списание; `store.productionPlan(day)` =
Σ(BOM × план) − остаток + min; `store.capacityWarning(day)`;
`store.ensureDefaultLocation()` — идемпотентный бэкфилл при первом
включении `module_locations` (решение §12.2).

**UI:** Склад получает сегмент «Точки» (под флагом `module_locations`),
экран перемещения, шит приёмки, экран «План производства» (§6.9).

**DoD:** остаток по локациям = Σ партий; FEFO списывает первым истекающий
(тест); приёмка с недопоставкой уменьшает долг поставщику (тест);
`productionPlan` считает потребность в сырье по составу (тест); при
выключенном флаге поведение склада не отличается от 0.4.4 (тест
`locations_flag_test`).

**Зависимости:** Э0 (`adjustStock`, `reason`), Э1 (состав), Э2
(обязательства).

---

### 5.7 Э6. Гарантия и сервис (`warranty-service`)

**Работы:** v25; `warranty_days` у позиции каталога и у заказа;
`store.openWarrantyClaim`, `closeWarrantyClaim(outcome, costCents)`;
авто-напоминание о гарантии вместо фиксированных 180 дней (берётся из
позиции); учёт «ремонт за свой счёт» как расхода с привязкой к заказу.

**UI:** секция «Гарантия» в карточке заказа, экран обращений в «Ещё» →
Сервис (под флагом), Pill «по гарантии» в списке заказов.

**DoD:** обращение уменьшает маржу заказа (видно в отчёте); тест
`warranty_test`.

---

### 5.8 Э7. Команда: роли, смены, задания (`team-shifts`)

**Работы:**
1. Миграция v26: `work_shifts` (employee_id, starts_at, ends_at,
   location_id, status), `shift_tasks` (shift_id, title, qty_planned,
   qty_done, job_id, status), `employees.app_role`.
2. Store: `planShift`, `assignTask`, `completeTask(qty)`,
   `shiftsForDay`, `employeeKpi(period)`.
3. Роли по решению §12.3 (**серверные обязательны**):
   - клиент: роли `owner / manager / worker / cashier` в настройках
     ограничивают экраны и действия;
   - сервер `meaxis-sync`: `role` в токене, allow-list таблиц и защищённых
     полей (`employee_payments`, `payroll_periods`, `purchases`,
     правка/удаление чужих `money_transactions`), отказ возвращается
     клиенту как «отклонено» с причиной в «Журнале»;
   - при отсутствии заданных ролей серверная проверка выключена — соло-режим
     работает как раньше.

**UI:** «Ещё» → Команда → Смены (§6.10); в карточке смены — задания с
отметкой; в «Сегодня» — карточка «Моя смена».

**DoD:** работник не может править зарплату и закупки (тест прав **на
клиенте**); сервер отклоняет такую же запись, отправленную в обход UI (тест
`sync_rbac_test` на стороне `meaxis-sync`); задание из плана производства
попадает в смену; тесты `shifts_test`, `roles_test`.

**Зависимости:** Э5 (план производства), серверная часть meaxis-sync.

---

### 5.9 Э8. Аналитика собственника (`owner-analytics`)

**Работы:**
1. Новые блоки в `StatsScreen` (без новых таблиц): маржа по позициям
   (top/bottom), потери и их доля, оборачиваемость, DSO/дебиторка по
   срокам, no-show, retention и «давно не было», точка безубыточности,
   конверсия лидов.
2. Экспорт (решение §12.5 — **PDF и XLSX**):
   - `DocumentService.buildOwnerDashboardPdf(...)` — плитки + детализация
     на одной странице;
   - `BackupService.saveExcel(rows, fileName: 'masters-owner-dashboard-*.xlsx')`
     — те же строки данными, без формул;
   - один слой расчёта: экран, PDF и XLSX читают одни и те же методы
     стора, поэтому расхождений между форматами быть не может.
3. Шаблоны работы T1–T10 (§7): `lib/features/onboarding/templates.dart`
   + расширение онбординга (5-й шаг «Чем занимаетесь»); шаблон = данные,
   не код (П6).

**UI:** `StatsScreen` получает сегмент «Показатели» с плитками `StatTile` и
списками (§6.11); кнопка экспорта — меню `Обзор | Показатели` → «Экспорт
PDF / Excel».

**DoD:** все метрики §10 считаются из существующих таблиц; тесты
`metrics_test` и `dashboard_export_test` (сумма строк XLSX = плитки PDF);
онбординг с шаблоном T2 создаёт каталог-пример, колонки канбана и
включает нужные флаги; цифры совпадают с ручным расчётом на демо-данных.

---

### 5.10 Карта файлов: где что менять

Чтобы этап не «расползался», у каждой работы заранее известно место.
Новые файлы — только там, где строка помечена «новый».

| Файл | Э0 | Э1 | Э2 | Э3 | Э4 | Э5 | Э6 | Э7 | Э8 |
|---|---|---|---|---|---|---|---|---|---|
| `lib/data/schema_tables.dart` (новый) | реестр таблиц | — | +`obligations` | +`leads`,`quotes` | +`client_credits` | +`locations`… | +`warranty_claims` | +`work_shifts`,`shift_tasks` | — |
| `lib/data/app_database.dart` | v22, триггеры из реестра, бэкфилл | индексы `materials.item_id` | индексы `obligations` | v23 | — | v24 | v25 | v26 | — |
| `lib/state/masters_store.dart` | `adjustStock`, `applyJobStock`, `jobCostCents`, backup/restore/merge из реестра | `createJobLine`…`recalcJobTotals` | `syncJobObligations`, `payables/receivables`, `cashPlan` | `createLead`, `convertLeadToJob`, КП | `createClientCredit`…`expireCredits` | `transferStock`, `receivePurchase`, `productionPlan` | `openWarrantyClaim` | `planShift`, `assignTask`, `employeeKpi` | метрики (только чтение) |
| `lib/state/settings_controller.dart` | `currency_*`, свой `TaxProfile` | — | `payment_reminder_days` | `module_leads` | `module_credits` | `module_locations` | `module_warranty` | `app_role` | `module_analytics` |
| `lib/data/models/job_items.dart` | — | `MaterialItem` +`itemId`,`kind`,`costAtOrderCents`,`discountCents` | — | — | — | — | +`warrantyDays` | — | — |
| `lib/data/models/` (новые) | — | — | `obligation.dart` | `lead.dart`, `quote.dart` | `client_credit.dart` | `location.dart`, `stock_batch.dart` | `warranty_claim.dart` | `work_shift.dart`, `shift_task.dart` | — |
| `lib/data/repositories/` (новые) | — | — | `obligation_repository.dart` | `lead_repository.dart`, `quote_repository.dart` | `client_credit_repository.dart` | `location_repository.dart`, `stock_batch_repository.dart` | `warranty_claim_repository.dart` | `work_shift_repository.dart`, `shift_task_repository.dart` | — |
| `lib/features/jobs/job_detail_screen.dart` | — | секция «Работы и товары» | секции «Оплата», «Материалы по составу» | кнопка «КП» | — | — | секция «Гарантия» | — | — |
| `lib/features/jobs/job_form_screen.dart` | — | полная перестройка по §6.3 | блок «Оплата» (аванс) | предзаполнение из лида | — | — | — | — | — |
| `lib/features/inventory/inventory_screen.dart` | «Каталог и услуги» в меню | — | — | — | — | сегменты «Точки»/«План» | — | — | — |
| `lib/features/inventory/catalog_screen.dart` (новый) | — | весь экран | — | источник строк для КП | — | — | — | — | — |
| `lib/features/money/money_screen.dart` | раздел «Валюта» | — | 4-й сегмент «План», дебиторка | — | плитка обязательств | — | — | — | — |
| `lib/features/clients/client_detail_screen.dart` | — | — | «Долг по заказам» | — | секция «Деньги клиента» | — | — | — | — |
| `lib/features/leads/leads_screen.dart` (новый) | — | — | — | весь экран | — | — | — | — | — |
| `lib/features/shifts/shifts_screen.dart` (новый) | — | — | — | — | — | — | — | весь экран | — |
| `lib/features/stats/stats_screen.dart` | — | — | — | — | — | — | — | — | сегмент «Показатели», экспорт |
| `lib/features/onboarding/onboarding_screen.dart`, `templates.dart` (новый) | — | — | — | — | — | — | — | — | шаблоны T1–T10 |
| `lib/core/document_service.dart` | PDF через `MoneyFormat` | — | — | `buildQuotePdf` | — | — | — | — | `buildOwnerDashboardPdf` |
| `lib/core/backup_service.dart` | — | — | — | — | — | — | — | — | XLSX панели |
| `meaxis-sync` (сервер) | — | — | — | — | — | — | — | `role` + allow-list | — |

Правило: файл, не указанный в колонке этапа, в этом этапе **не меняется**.
Если изменение всё же понадобилось — это признак, что этап спроектирован
неверно, и его нужно пересобрать, а не «дописать по месту».

---

## 6. UI-спецификация

### 6.1 Навигация: что где лежит

Никаких новых нижних вкладок (П7). Карта размещения:

| Новая возможность | Где живёт | Как попасть |
|---|---|---|
| Каталог | отдельный экран | Склад → «Каталог и услуги»; Заказ → «+ Из каталога»; Ещё |
| Строки и параметры заказа | форма/карточка заказа | События → заказ |
| План оплаты, дебиторка | Деньги → сегмент «План» | Деньги |
| Платёжный календарь | Деньги → сегмент «План» | Деньги |
| Заявки | отдельный экран | Сегодня (карточка «Заявки»), Ещё → Продажи |
| КП | карточка заказа/заявки | кнопка «КП» |
| Деньги клиента | карточка клиента | Клиенты → клиент |
| Точки, партии, приёмка | Склад → сегмент «Точки» (флаг) | Склад |
| План производства | Склад → «План» (флаг) | Склад |
| Гарантия | карточка заказа + Ещё → Сервис (флаг) | — |
| Смены и задания | Ещё → Команда → Смены | Ещё |
| Аналитика собственника | Итоги → сегмент «Показатели» | Ещё → Аналитика |

Деньги получают 4-й сегмент: `Операции | Счета | План | Категории`
(существующий `CupertinoSegmentedControl<int>` — добавить одну запись).
Итоги получают сегмент `Обзор | Показатели`.

### 6.2 Карточка заказа (`JobDetailScreen`)

Порядок секций (сверху вниз), все — существующими `SectionLabel` +
`AppCard` + `ListRow`/`KeyValueRow`:

1. **Шапка**: клиент, объект, статус (`Pill`), приоритет.
2. **Работы и товары (N)** — `AppCard` со строками:
   `ListRow(title: 'Замена масла', subtitle: '2 × 1 200 ₽ · себест. 800 ₽')`,
   trailing — `OverflowMenuButton` (Изменить / Удалить). Внизу карточки:
   `KeyValueRow('Итого', '2 400 ₽')`, `KeyValueRow('Себестоимость', '1 600 ₽')`,
   `KeyValueRow('Маржа', '800 ₽ (33%)')` — маржа красится в `green`, если
   > 0, и в `orange`, если ≤ 0.
3. **Параметры** — атрибуты заказа в виде `ChipButton`-строк
   (`вес 1.5 кг`, `вкус ваниль`, `адрес: ул. Мира 3`). Если атрибутов нет —
   секция скрыта (не пустая карточка).
4. **Сроки**: дата/время выдачи (`KeyValueRow`), `KeyValueRow('Начать не
   позже', '13.11, 09:00')`; при перегрузе дня — `Pill('перегруз дня')`
   цветом `orange`.
5. **Оплата**: `ProgressBar(paid/total)`, `KeyValueRow('Оплачено',
   '1 200 ₽ из 2 400 ₽')`, `KeyValueRow('Доплата к 15.11', '1 200 ₽')`;
   `ChipButton('Внести оплату')` открывает шит (сумма, счёт, дата);
   при просрочке — `Pill('просрочено 2 дня')` цветом `orange`.
6. **Материалы по составу** (если у строк есть `item_id`): список с
   галочками и кнопкой «Списать со склада»; после списания — `Pill('списано')`.
7. **Учёт времени**, **Вложения**, **Действия** — без изменений.

Правило: если блок выключен флагом или данных нет — блок не рисуется.
Никаких «серых заглушек» внутри карточки.

### 6.3 Форма заказа (`JobFormScreen`)

Была «Основное / Приоритет / Суммы / Срок и заметки». Становится:

| Секция | Содержимое |
|---|---|
| **Что делаем** | клиент (`ListRow` → шит выбора), объект, название; **строки**: `ListRow` на каждую + `ChipButton('+ Из каталога')`, `ChipButton('+ Свободная строка')` |
| **Параметры** | `ChipButton('+ Параметр')` → шит «ключ/значение»; подсказка из каталога («у торта обычно: вес, вкус») |
| **Когда** | дата выдачи (`CupertinoDatePicker` в шите), под ней автоматически: «Начать не позже …»; предупреждение о загрузке дня |
| **Оплата** | сегмент `Без предоплаты / 30% / 50% / Своя`; дата доплаты; сумма считается от итога |
| **Итог** | `KeyValueRow` цена / себестоимость / маржа; пересчёт на лету |
| **Заметки** | текст, теги, приоритет, ответственный |

Кнопка «Сохранить» активна всегда; при пустом названии подставляется
название первой строки каталога.

Клавиатура: числовые поля — `keyboardType: numberWithOptions(decimal: true)`,
как сейчас в форме. Никаких новых полей-простыней: всё в две колонки
`KeyValueRow`, кроме строк заказа.

### 6.4 Каталог (`CatalogScreen`, новый)

```
CupertinoNavigationBar: «Каталог»            [ + ]
Поиск (как в Складе) + ChipButton: Всё | Товары | Услуги | Популярное
SectionLabel('Позиций N · средняя маржа 34%')
AppCard (на позицию):
  [IconBadge]  Торт «Клубника-киви»
               от 850 ₽/кг · себест. 410 ₽ · маржа 52%
               [Pill 'популярное'] [Pill 'состав: 7]        [⋯]
EmptyState: «Каталог пуст» → «Создать первую позицию»
```

Шит позиции (bottom sheet, `SheetHandle`):
- название, сегмент `Товар | Услуга`;
- единица (`kUnitOptions`), цена продажи, категория;
- «Состав» → список компонентов (`ListRow` + qty + себестоимость), кнопка
  «+ компонент» (выбор со склада), итог себестоимости;
- «Параметры» — пары ключ/значение (вес, вкус, размер, гарантия);
- фото (`file_picker`), «популярное» (switch), архив;
- внизу: `PrimaryButton('Сохранить')`.

Действия в меню позиции: «Создать заказ», «Состав», «Дублировать»,
«В архив».

### 6.5 Деньги → сегмент «План» (новый)

```
Segmented: Операции | Счета | План | Категории
AppCard «Прогноз»:
   KeyValueRow('Сейчас на счетах', '84 200 ₽')
   KeyValueRow('Через 6 недель', '112 400 ₽')
   KeyValueRow('Минимум', '−3 100 ₽ · 12 нояб')      ← orange, если < 0
   Pill('разрыв 12 нояб') / Pill('запас 6 недель', green)
SectionLabel('Ближайшие платежи')
по дням: SectionLabel('12 нояб, чт · −12 300 ₽')
   ListRow('Аренда цеха', '−25 000 ₽', icon: house)      [⋯ Оплатить]
   ListRow('Иван Петров · торт', '+12 000 ₽', icon: person) [⋯ Напомнить]
EmptyState: «Обязательств нет» → «Добавить платёж»
ChipButton('+ Платёж')  (аренда, налог, зарплата, прочее)
```

Строка платежа: `ListRow` с `subtitle` = контрагент и `trailing` =
сумма + `Pill('просрочено')` при просрочке. Тап → шит: сумма, дата, счёт,
«Оплатить полностью / частично», «Отменить».

### 6.6 Дебиторка (внутри «План» и в карточке клиента)

В Деньгах вместо текущей секции «Должны мне · X» — карточка со строками:

```
ListRow('Иван Петров', 'торт 15.11 · просрочено 2 дня', trailing '12 000 ₽')
   меню: Напомнить (шаблон), Внести оплату, Перенести дату
```

Сортировка: сначала просроченные, затем по дате. Заголовок секции
показывает сумму и число должников.

### 6.7 Заявки (`LeadsScreen`, новый)

```
CupertinoNavigationBar: «Заявки»             [ + ]
Segmented: Активные | Отказ | Конвертированы
AppCard (заявка):
  [IconBadge] Анна · WhatsApp
              «торт на 15 кг, 20 ноября» · бюджет 8 000 ₽
              [Pill 'следующий шаг 07.11'] [Pill 'просрочено']  [⋯]
   меню: Создать заказ, КП, Напомнить, Отказ
EmptyState: «Заявок нет» → «Добавить заявку»
```

Карточка заявки: клиент (или имя+телефон для нового), источник
(`ChipButton`: WhatsApp, Авито, Сайт, Сарафан, Другое), запрос (текст),
бюджет, дата следующего шага, заметки. «Создать заказ» открывает
`JobFormScreen` с предзаполненными полями.

### 6.8 Деньги клиента (карточка клиента)

Новая секция «Деньги клиента» после «Заказы»:

```
AppCard:
  KeyValueRow('Депозит', '5 000 ₽')
  KeyValueRow('Абонемент', '2 из 8 занятий · до 30.12')
  KeyValueRow('Сертификат', '3 000 ₽ · до 01.02')
  ChipButton('Пополнить')  ChipButton('Списать')  ChipButton('Вернуть')
```

Списание: шит «Списать занятие / списать сумму / погасить сертификат».
При нулевом остатке — `Pill('использован')`.

### 6.9 Склад: точки, партии, приёмка, план

- Сегмент (только при `module_locations`): `Товары | Точки | План`.
- «Точки»: список локаций (`ListRow`: название, «12 позиций · 3 ниже
  минимума»), внутри — остатки и `ChipButton('Переместить')` → шит
  «откуда/куда/позиции/количество».
- Позиция: под остатком — `KeyValueRow('Партии', '2 · ближайшая до 07.11')`;
  истекающая партия → `Pill('истекает завтра')` `orange`.
- Приёмка: из закупки кнопка «Принять» → шит со строками
  `заказано / принято` (числовые поля), «Отклонить строку», итог
  расхождения; после приёмки — пересчёт долга и себестоимости.
- «План»: `CupertinoDatePicker` на день + список «что делать»:
  `ListRow('Круассаны', 'план 200 · остаток 12 · нужно 188')`, ниже
  «Сырьё: мука 4.2 кг, масло 1.1 кг» и `ChipButton('Заказать
  недостающее')` (создаёт закупку-черновик).

### 6.10 Смены и задания («Ещё» → Команда → Смены)

```
CupertinoNavigationBar: «Смены»              [ + ]
Полоса дней недели (как в календаре Событий)
AppCard (смена):
  [IconBadge] Мария · 09:00–18:00 · Цех
              задания: 3 из 5 выполнено
              [Pill 'сейчас идёт'] / [Pill 'закрыта']
   меню: Задания, Перенести, Закрыть смену
```

Шит задания: название, план (число), факт (число), «Готово», привязка к
заказу (опционально). В «Сегодня» — карточка «Моя смена» с заданиями, если
у пользователя есть назначенная смена.

### 6.11 Аналитика (`StatsScreen` → сегмент «Показатели»)

Плитки `StatTile` (2 в ряд): маржинальность, средний чек, потери, DSO,
оборачиваемость, no-show, retention, конверсия лидов. Ниже — списки:
«Топ-5 по марже», «Худшие 5 (в минус или ниже 10%)», «Долги по срокам»,
«Кто давно не был». Каждая плитка по тапу открывает детализацию
(шит со списком contributing-записей) — чтобы цифра была проверяемой.

Экспорт (решение §12.5): в шапке сегмента — `OverflowMenuButton` с двумя
пунктами, «Экспорт PDF» и «Экспорт Excel». Оба берут данные из одного
набора методов стора, поэтому цифры совпадают; Excel — только данные, без
формул и графиков.

### 6.12 Точные точки встраивания в код

Ниже — конкретные места, которые меняет каждый этап. Строки указаны по
состоянию **0.3.18+21**; перед правкой исполнитель сверяет их (файлы
большие, нумерация сдвигается).

| Этап | Файл | Место | Что делаем |
|---|---|---|---|
| Э0 | `lib/data/app_database.dart` | `open(version: 21)` (стр. 84) | поднять до 22 |
| Э0 | `lib/data/app_database.dart` | `_upgradeSchema` (стр. 791) | добавить блок `oldVersion < 22` |
| Э0 | `lib/data/app_database.dart` | `syncTables` (стр. 355), `_syncApplyOrder` (стр. 382), `_ensureSyncColumns` (стр. 308) | заменить на чтение реестра |
| Э0 | `lib/data/app_database.dart` | `_createAuditTriggers` (стр. 1303+) | сгенерировать циклом по реестру (сейчас ~500 строк копипасты) |
| Э0 | `lib/data/app_database.dart` | `mergeSnapshot` mappings (стр. 1145) | собирать из реестра |
| Э0 | `lib/state/masters_store.dart` | `backupData` (стр. 2382), `restoreFromBackup` (стр. 2408), `mergeFromBackup` (стр. 2700) | обход реестра, формат 8 → 9 |
| Э0 | `lib/state/masters_store.dart` | `receiveStock` (стр. 1636), `writeOffStock` (стр. 1674), `createPurchase` (стр. 3542) | перевести на `adjustStock` |
| Э0 | `lib/features/money/money_screen.dart` | `_moneySection` в настройках (стр. 455 `settings_screen.dart`) | раздел «Валюта» |
| Э1 | `lib/features/jobs/job_form_screen.dart` | секции «Основное»/«Суммы» (стр. 476, 559) | перестроить в «Что делаем»/«Итог» |
| Э1 | `lib/features/jobs/job_detail_screen.dart` | `SectionLabel('Материалы (N)')` (стр. 805) | → «Работы и товары (N)» + блок «Итого» |
| Э2 | `lib/features/money/money_screen.dart` | `CupertinoSegmentedControl` (стр. 1353), `_selectedTab` (стр. 36) | 4-й сегмент «План» |
| Э2 | `lib/features/money/money_screen.dart` | `SectionLabel('Должны мне · X')` (стр. 1841) | карточки с датой и просрочкой |
| Э4 | `lib/features/clients/client_detail_screen.dart` | после `SectionLabel` заказов (стр. 296) | секция «Деньги клиента» |
| Э5 | `lib/features/inventory/inventory_screen.dart` | `CupertinoSlidingSegmentedControl` (стр. 1384) | сегменты «Точки»/«План» под флагом |
| Э8 | `lib/features/stats/stats_screen.dart` | `_StatsScreenState` (стр. 25) | сегмент «Обзор | Показатели» + экспорт |
| Э8 | `lib/features/onboarding/onboarding_screen.dart` | `_pageController` (стр. 20), `_finish` (стр. 34) | 4-й шаг с шаблонами T1–T10 |

Правило проверки после правки: `grep -rn "₽" lib` не находит ничего,
`grep -c "stockQty:" lib/state/masters_store.dart` — только внутри
`adjustStock`, а `flutter test` остаётся зелёным.

### 6.13 Тексты, пустые состояния, ошибки

- Все суммы — через `MoneyFormat`; валюта из настроек.
- Просрочка — только `orange` + `Pill('просрочено N дн.')`, не красный
  (красный занят ошибками).
- Пустые состояния: заголовок + одно предложение + одно действие
  (`EmptyState` уже есть).
- Ошибки миграции/синхронизации — `showAppAlert` с действием «Открыть
  журнал» (уже есть в настройках).
- Отклонённая сервером запись (роли, §12.3) — `Pill('отклонено', orange)`
  в «Журнале» с причиной; локальные данные не удаляются.
- Никаких «Сохранить» в шапке карточки: сохранение — в форме, карточка
  редактируется через шиты (как сейчас).

### 6.14 Компоненты и стиль

Используем только существующий кит `lib/app/ui.dart`: `AppCard`,
`SectionLabel`, `KeyValueRow`, `ListRow`, `ChipButton`, `OverflowMenuButton`,
`Pill`, `ProgressBar`, `StatTile`, `IconBadge`, `EmptyState`, `SheetHandle`,
`PrimaryButton`/`SecondaryButton`, `Hairline`. Новые виджеты не вводим;
если нужен «список с чекбоксами» — `ListRow` + `CupertinoCheckbox` внутри
`leading`, как в онбординге.

---

## 7. Шаблоны работы (данные онбординга)

Шаблон = набор данных, а не код (П6). Онбординг после вопроса «чем
занимаетесь» применяет шаблон: создаёт каталог-пример, колонки канбана,
типы напоминаний, включает блоки.

| # | Шаблон | Этапы канбана | Включает блоки | Триггеры |
|---|---|---|---|---|
| T1 | Заказ-наряд | заявка → диагностика → согласование → работа → готово → выдан | каталог, оплата, гарантия | согласовать смету, готово — позвонить, гарантия N мес. |
| T2 | Изготовление под заказ | заявка → образец → предоплата → закупка → производство → декор → выдача | каталог, состав, оплата, лиды | запечь не позже, доплата за 2 дня, фото готового |
| T3 | Ремонт/монтаж по смете | замер → смета → аванс → этапы → акт → гарантия | каталог, строки, оплата, вложения | этап принят — акт, допработы — согласовать |
| T4 | Запись в салон | запись → подтверждена → выполнена / неявка | события, абонементы, депозиты | за 24 ч и за 2 ч, no-show 2 раза — предоплата |
| T5 | Розница/точка | поставка → выкладка → продажа → списание | склад, партии, касса | истекает завтра — уценить, остаток < min |
| T6 | Цех + точки | план → задание смене → выпечка → перемещение → продажа | план производства, локации, смены | план на завтра, не хватает сырья, перегруз дня |
| T7 | Прокат/аренда | бронь → выдача → возврат → проверка | залоги, партии | вернуть завтра, повреждение — удержать |
| T8 | Абонемент/регулярная услуга | график → визит → списание → продление | абонементы, события | осталось 2 занятия, абонемент истекает |
| T9 | Доставка/выезд | принят → собран → в пути → доставлен | адрес/окно, оплата | выехал, клиент не открыл |
| T10 | Проект с вехами | бриф → КП → договор → вехи → сдача | лиды, КП, этапы, оплата по вехам | веха просрочена, платёж по вехе |

Реализация: `lib/features/onboarding/templates.dart` — статические наборы
(`name`, `columns`, `catalogSamples`, `flags`, `reminderRules`). Онбординг
показывает 4 вопроса + выбор шаблона; «Загрузить демо-данные» остаётся.

---

## 8. Миграции, бэкап, синхронизация, web

1. Бэкап: формат 8 → 9. Правило совместимости — новые таблицы
   экспортируются всегда, при восстановлении старой копии отсутствующие
   ключи = пустые списки (не ошибка).
2. `mergeFromBackup` для новых таблиц — LWW по `updated_at` (как сейчас),
   но для `obligations` дополнительное правило: не перезаписывать
   `paid_cents` значением меньше текущего (деньги нельзя «откатить»
   синхронизацией).
3. Audit-триггеры: генерируются из реестра; в `sync_outbox` попадают все
   таблицы реестра. Проверка: тест, что для каждой таблицы реестра есть
   триггер (запрос к `sqlite_master`).
4. Веб: миграция та же; для `entity_attributes` уникальный индекс с
   `WHERE deleted_at IS NULL` поддержан SQLite в wasm — проверить на
   `sqlite3.wasm` 3.5.2 (в тесте web-профиля).
5. Откат: миграция v22 идёт в бета-канал зеркала, затем в stable. При
   ошибке health-check релиз откатывается на прежний образ (механика
   автодеплоя уже есть), данные пользователя — только через бэкап.

---

## 9. Тесты и приёмочные критерии

Обязательный минимум на каждый этап:

| Тест | Что проверяет |
|---|---|
| `migration_v22_test` (+v23…v26) | апгрейд с фикстуры, наличие колонок/таблиц, идемпотентность бэкфилла |
| `backup_registry_test` | каждая таблица реестра есть в бэкапе, restore не теряет, merge не дублирует |
| `stock_adjust_test` | остаток меняется только через `adjustStock`, движения пишутся с причиной |
| `job_cost_test` | себестоимость = Σ снимков; правка цены товара не меняет историю |
| `job_lines_test` | добавление из каталога, пересчёт цены/маржи, удаление строки |
| `obligations_test` | инвариант Σ obligations = цена заказа; частичная оплата; отмена |
| `receivables_test` | долг по заказу, а не по клиенту; переплата не гасит чужой заказ |
| `cash_plan_test` | календарь на 6 недель, разрыв в правильный день |
| `leads_test` | конверсия лида в заказ, «зависшие» заявки |
| `quote_snapshot_test` | КП не меняется после правки заказа; новая ревизия вместо правки старой |
| `client_credits_test` | списание денег и занятий, истечение, возврат |
| `deferred_revenue_test` | выручка признаётся по списанию, а не по поступлению (§12.1) |
| `stock_batches_test` | FEFO, остаток по локациям = Σ партий |
| `locations_flag_test` | при выключенном `module_locations` склад ведёт себя как до Э5 (§12.2) |
| `receive_purchase_test` | расхождение приёмки → корректировка долга и себестоимости |
| `warranty_test` | обращение уменьшает маржу заказа |
| `shifts_test`, `roles_test` | задания, права на клиенте |
| `sync_rbac_test` | сервер meaxis-sync отклоняет запись, запрещённую ролью (§12.3) |
| `metrics_test` | метрики §10 совпадают с ручным расчётом на демо-данных |
| `dashboard_export_test` | сумма строк XLSX = плитки PDF (§12.5) |
| `money_format_test` | формат валюты из настроек, ноль `₽` в выводе |

### 9.1 Чек-лист закрытия этапа

Копируется в отчёт по этапу, каждый пункт — «да/нет»:

1. Миграция применена на фикстуре предыдущей версии, апгрейд идемпотентен.
2. `flutter analyze --no-pub` — 0 ошибок (info/warning — перечислить).
3. `flutter test` — все зелёные, включая усиленный `mojibake_scan_test` и
   `database_test` (ожидание новой версии схемы).
4. Новые тесты из таблицы выше для этого этапа написаны и проходят.
5. Бэкап: снят `backupData()`, восстановлен на чистой базе, данные целы;
   формат совместим с предыдущим (старая копия читается).
6. Синхронизация: для каждой новой таблицы реестра есть audit-триггер и
   подписка `sync_outbox` (тест по `sqlite_master`).
7. Веб-профиль: та же миграция на wasm проходит, экран открывается.
8. `flutter build apk --release` и `flutter build web --release` проходят.
9. Версия в `pubspec.yaml` поднята, запись в `docs/specs/_queue.md` есть.
10. Правила П1–П10 не нарушены: нет `DROP`, нет `₽` в `lib/`,
    нет новых нижних вкладок, остаток меняется только через `adjustStock`.

Приёмка этапа: пункты 1–10 — «да»; иначе этап не закрыт и релиз не
выпускается.

---

## 10. Метрики (появляются вместе с этапами)

| Метрика | Формула в терминах схемы | Этап |
|---|---|---|
| Маржа по позиции | Σ(`price_cents` − `cost_at_order_cents`) по строкам | Э1 |
| Маржинальность | (выручка − себестоимость) / выручка | Э1 |
| Средний чек | выручка / число закрытых заказов | Э1 |
| Дебиторка, DSO | остатки `receivable` / выручка × дни | Э2 |
| Просрочка | Σ `receivable` с `due_at < now` | Э2 |
| Кассовый разрыв | min по дням плана за 6 недель | Э2 |
| Долг поставщикам, DPO | остатки `payable` / закупки × дни | Э2 |
| Конверсия лидов | заказы из лидов / лиды | Э3 |
| Обязательства перед клиентами | Σ `client_credits.remaining_cents` | Э4 |
| Выручка периода (с учётом §12.1) | поступления − Δ обязательств перед клиентами | Э4 |
| Доля потерь | Σ списаний по `unit_cost_cents` / выработка | Э5 |
| Оборачиваемость (DIO) | средний остаток / себестоимость продаж × дни | Э5 |
| Загрузка | часы из `work_sessions` / доступные часы | Э7 |
| No-show | `appointments.no_show` / все записи | Э8 |
| Retention, «давно не было» | клиенты с ≥2 заказами; > средний цикл × 1.5 | Э8 |
| Точка безубыточности | постоянные расходы / маржинальность | Э8 |

---

## 11. Риски

| Риск | Вероятность | Влияние | Мера |
|---|---|---|---|
| Миграция v22 портит данные | средняя | высокое | фикстура + бета-канал + бэкап перед апгрейдом (предложить пользователю) |
| Бэкфилл обязательств создаёт мусор | средняя | среднее | пакеты, лог в `audit_log`, тест на фикстуре с 500 заказами |
| Двойной учёт после `obligations` | высокая | высокое | инвариант «Σ obligations = цена», тесты, отказ от параллельных расчётов |
| Депозит снова посчитан выручкой (§12.1) | средняя | высокое | одна формула выручки в сторе, тест `deferred_revenue_test`, запрет прямого суммирования поступлений в отчётах |
| Серверные роли блокируют нужную работу (§12.3) | средняя | высокое | при отсутствии ролей проверка выключена; отклонённая запись не удаляется, показывается причина и кнопка «Разрешить» для владельца |
| Локации включены случайно и путают остаток (§12.2) | низкая | среднее | флаг по умолчанию выключен, при включении — идемпотентный бэкфилл и подсказка-шит «что изменится» |
| Рост объёма карточки заказа | высокая | среднее | секции скрываются при отсутствии данных; ничего не «серое» |
| Синхронизация новых таблиц ломает merge | средняя | высокое | реестр + тест на каждую таблицу; `paid_cents` не откатывается |
| Web-профиль отличается от мобильного | средняя | среднее | прогон миграции и тестов на wasm-профиле в CI |
| Расползание этапов | высокая | среднее | этап = один слаг = один релиз; новые идеи — в бэклог, не в текущий этап |

---

## 12. Принятые решения (открытые вопросы закрыты)

Пять вопросов решены до старта: они влияли на схему и на объём этапов,
поэтому «решим потом» означало бы переделку v22. Для каждого решения
указано, что именно оно меняет в ТЗ и чем подтверждается.

### 12.1 Депозит клиента: деньги — да, выручка — по мере оказания (Э4)

**Решение: отложенная выручка.** Депозит/сертификат/абонемент — это
полученные деньги (ДДС растёт сразу, `money_transactions` создаётся в
момент поступления), но **не выручка**: в P&L выручка признаётся в момент
списания (оказания услуги, отгрузки), а непогашенный остаток
`client_credits.remaining_cents` показывается как **обязательство перед
клиентом** (отдельная плитка и строка в отчёте).

Почему не «сразу выручка»: полученная предоплата — это обязательство
оказать услугу, а не заработанное; если считать её выручкой сразу, маржа
и прибыль периода завышаются, а при возврате денег придётся сторнировать
уже показанную выручку. Это же правило делает корректным сценарий
«сертификат куплен в декабре, услуга оказана в январе».

Что это меняет в ТЗ:
- `client_credits` остаётся таблицей обязательств; добавляется обязательный
  учёт `remaining_cents` и `status` (это уже в v22);
- в P&L (§10) выручка = поступления + списания кредитов − возвраты; плитка
  «невыполненные обязательства» = Σ `remaining_cents`;
- отдельный счёт отложенной выручки в бухгалтерском смысле **не заводим**
  (полноценная бухгалтерия вне границ, §1.2) — вместо счёта используем
  метрику обязательства, этого достаточно для малого бизнеса.

Приёмка: тест `client_credits_test` — после продажи сертификата на 3 000 ₽
и списания 1 200 ₽ выручка = 1 200 ₽, обязательство = 1 800 ₽.

### 12.2 Локации: только под флагом (Э5)

**Решение: `module_locations`, по умолчанию выключен.** Пока флаг снят,
остаток живёт в единственном «Основном складе» (`location_id = NULL` в
движениях), и весь склад работает ровно как сейчас. При включении флага
создаётся локация «Основной склад», и все остатки считаются принадлежащими
ей.

Почему так: у соло-мастера и домашнего производства нет второго склада —
обязательные локации добавили бы лишний шаг в каждое списание и списание
стало бы «в два действия»; при этом выключенный блок не должен ломать
данные, поэтому таблицы создаются миграцией v22 сразу, а UI появляется
только под флагом (П8). Это стандартный приём: функциональность уровня
«несколько точек» включается тогда, когда у бизнеса действительно появилась
вторая точка.

Что это меняет в ТЗ:
- миграция v24 создаёт `locations`, `stock_levels`, `stock_batches`,
  `transfers` **независимо** от флага;
- при первом включении флага выполняется идемпотентный бэкфилл: локация
  «Основной склад» + перенос текущих `inventory_items.stock_qty`;
- в Складе сегмент «Точки» и «План» появляются только при включённом
  `module_locations`; при выключении данные остаются в схеме.

### 12.3 Роли: обязательны на сервере meaxis-sync (Э7)

**Решение: серверные права обязательны.** Роли `owner / manager / worker /
cashier` живут в настройках (кто что видит) **и** в токене синхронизации;
сервер применяет их при приёме записи. Роль передаётся в запросе
синхронизации, и запрещённые таблицы/поля отклоняются с понятной ошибкой,
которая показывается в «Журнале» настроек.

Почему не только UI: клиентская проверка защищает лишь от ошибки, а не от
намерения — запись можно отправить в обход интерфейса. Плюс при нескольких
устройствах и LWW роль на клиенте ничего не решает: побеждает тот, кто
записал позже. Серверная проверка — единственное место, где правило
действует для всех устройств.

Что это меняет в ТЗ:
- Э7 включает работы на `meaxis-sync` (не только Flutter): поле `role` в
  токене/сессии, allow-list таблиц и защищённых полей
  (`employee_payments`, `payroll_periods`, `purchases`, `money_transactions`
  на удаление/правку чужих записей);
- при отказе сервер возвращает запись как «отклонено», клиент не теряет
  данные и показывает причину;
- «нет роли» = прежнее поведение (полный доступ) — для соло-режима
  серверная проверка не включается, пока в настройках не заданы роли.

### 12.4 КП: PDF-снимок с номером и версией (Э3)

**Решение: снимок.** КП — неизменяемый PDF, который формируется в момент
отправки, получает номер и версию (`КП-2026-014`, ревизия 2), и хранится
вместе с заказом. Правка КП создаёт новую ревизию, старая остаётся
доступной.

Почему: клиент должен видеть ровно то, что согласовал; живой документ,
меняющийся после согласования, — источник споров о цене и объёме. Снимок
заодно даёт доказательство при разногласии, а «живой» вариант всегда можно
посмотреть в карточке заказа (актуальные строки).

Что это меняет в ТЗ:
- `quotes` (v23) хранит `number`, `revision`, `snapshot_json`,
  `pdf_path`, `sent_at`, `status`;
- в карточке заказа кнопка «КП» открывает выбор: «Отправить КП» (создаёт
  новую ревизию) или «История КП»;
- при конверсии заявки в заказ КП создаётся автоматически из строк заказа.

### 12.5 Экспорт панели собственника: PDF сразу, XLSX — тоже сразу (Э8)

**Решение: и PDF, и XLSX.** PDF — «прочитать и отправить» (одна страница
показателей + детализация), XLSX — «посчитать самому»: те же цифры
построчно, чтобы владелец мог сложить их со своей таблицей или отдать
бухгалтеру. Оба экспорта используют один и тот же слой расчёта метрик, то
есть расхождений между форматами нет.

Почему не откладывать XLSX: в проекте уже подключены `excel` и `csv`
(`lib/core/backup_service.dart`, `saveExcel`), а отчёт по P&L уже имеет
PDF-версию — добавление XLSX стоит один метод, а не отдельный этап.
Ограничение: Excel-экспорт не делает формул и графиков, только данные.

Что это меняет в ТЗ:
- §10 остаётся без изменений (метрики), но в Э8 добавляется
  `DocumentService.buildOwnerDashboardPdf(...)` и
  `BackupService.saveExcel(...)` с тем же набором строк;
- тест `dashboard_export_test` проверяет, что сумма строк XLSX равна
  плиткам PDF, а `metrics_test` — что обе версии совпадают с экраном.

---

## Приложение A. Резюме анализа (обоснование, итерация 1)

- Ниша-эталон (кондитерка) дала конкретику, но план построен на
  **14 универсальных блоках** (B1–B14): каталог, параметрический заказ,
  оплата по плану, lead-time, профиль клиента, мультиточки, потери,
  смены/задания, роли, отчёты, лояльность, обязательный домен, портал,
  шаблоны сообщений.
- Архетипы (соло-мастер, домашнее производство, магазин, услуга с
  командой, цех+точки, стройка, доставка) определяют, какие блоки P0.
  Ядро для всех: каталог, оплата, планирование, напоминания, отчёт,
  шаблоны.
- Anti-паттерны: домен в коде, «все блоки всем сразу», LWW без ролей при
  команде, дублирование сущностей.
- Итерация 2 добавила B15–B23 (лиды, обязательства клиента, платёжный
  календарь, партии/FEFO, приёмка, гарантия, универсальность денег,
  аналитика, выездные сценарии) и зафиксировала разрывы из §2.

## Приложение B. Что уже закрыто и не входит

Календарь/канбан/бронирование, напоминания клиенту, многоустройственная
синхронизация (LWW), счета и регулярные платежи, закрытые периоды,
налоговый радар НПД, PIN/биометрия, аудит, экспорт Excel/PDF — есть.
Бумажный документооборот, кассы-онлайн, ЭДО, полноценная бухгалтерия — не
входят (см. §1.2).
