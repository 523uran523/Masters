# Masters — архитектура приложения (актуальная на состояние репозитория)

Дата: 29.10.2026
ОС проекта: Windows 10/11, Flutter (Dart), SQLite.
Стиль: локальный-first учёт, Cupertino UI, поддержка горизонтальной раскладки, пресеты по бизнес-типам.
Основной репозиторий: `C:\Users\523ur\Documents\MyProjects\Apps\Masters`.

---

## 3. Точка входа

`lib/main.dart`

Основные шаги:
1. `WidgetsFlutterBinding.ensureInitialized()`
2. Настройка `databaseFactory`:
   - Web: `databaseFactoryFfiWebNoWebWorker`
   - Windows/Linux: `databaseFactoryFfi`
3. Запуск `BrowserTabCoordinator.instance.start()` на Web
4. Инициализация дат
5. Открытие БД: `AppDatabase.open()`
6. Загрузка настроек `SettingsController.load()`
7. Yandex OAuth callback, если присутствует OAuth code
8. Планировщик напоминаний в фоновом Future
9. Настройка ориентации экрана
10. Загрузка `MastersStore`
11. Автобэкап (если включён)
12. `runApp(MastersApp(...))`

---

## 4. Сервисный слой `lib/core`

### Основные утилиты
- `app_utils.dart`
  - `newId()` — sortable идентификатор вида UUIDv7-ish
  - `formatMinutes`, `formatDay`, `formatFullDate`, `formatNumber`, `formatIsoDay`
  - `pluralRu`, `clamp*`, `timerLabel`.
- `app_pin_service.dart`: локальный PIN store/hash/verification
- `app_biometric.dart`: обёртка над `local_auth`, проверка доступности и auth request.
- `backup_service.dart`: JSON backup/import и CSV/Excel export/import.
- Yandex:
  - `yandex_oauth.dart`
  - `yandex_disk_service.dart`
  - `yandex_sync.dart`
  - browser-based OAuth, REST Disk API, auto upload/merge.
- `document_service.dart`:
  - `buildJobPdf`
  - `buildPayrollPdf`
  - `savePdf`
- `reminder_service.dart`, web URL wrappers, deep link service, single-tab warning.

---

## 5. Данные: модели

Директория: `lib/data/models`

Основные модели:
- `account.dart`
- `cash_shift.dart`
- `money_transaction.dart`
- `client.dart`
- `work_object.dart`
- `job.dart`, `job_items.dart`
- `inventory_item.dart`, `stock_movement.dart`
- `appointment.dart`, `booking_resource.dart`
- `client_reminder.dart`
- `employee.dart`, `time_entry.dart`, `employee_payment.dart`
- `recurring_payment.dart`, `closed_period.dart`-related embedded/default model.

Все суммы хранятся в центах (целые числа).

---

## 6. Репозитории

Директория: `lib/data/repositories`

Repository pattern: `getAll`, `byId`, `save`, `delete`/specific queries. Многие `getAll()` фильтруют `deleted_at IS NULL`.

Реализованные репозитории:
- ClientRepository
- ObjectRepository
- JobRepository
- StageRepository
- MaterialRepository
- SessionRepository
- AccountRepository
- CashShiftRepository
- MoneyTransactionRepository
- InventoryItemRepository
- StockMovementRepository
- AppointmentRepository
- BookingResourceRepository
- ClientReminderRepository
- EmployeeRepository
- TimeEntryRepository
- EmployeePaymentRepository
- RecurringPaymentRepository
- PayrollPeriodRepository

---

## 7. База данных

Файл: `lib/data/app_database.dart`

### Версия БД
**Version 11**.

### Миграции
- v1: ядро, money
- v2: money
- v3: inventory
- v4: booking
- v5: reminders
- v6: jobs assignee/team
- v7: sync columns (`updated_at`, `deleted_at`, `device_id`)
- v8: audit log
- v9: period closures
- v10: recurring payments + payroll periods
- v11: DB audit triggers

### Таблицы
`clients`, `objects`, `jobs`, `job_stages`, `materials`, `work_sessions`, `accounts`, `cash_shifts`, `money_transactions`, `inventory_items`, `suppliers`, `purchases`, `purchase_lines`, `stock_movements`, `recipe_lines`, `booking_resources`, `appointments`, `client_reminders`, `employees`, `time_entries`, `employee_payments`, `audit_log`, `period_closures`, `recurring_payments`, `payroll_periods`.

### Integrity
- `integrityIssues()` — `PRAGMA foreign_key_check` + `PRAGMA quick_check`.
- trigger-based audit.

---

## 8. Центральное состояние: `MastersStore`

Файл: `lib/state/masters_store.dart`

### Роль
Хранит все typed-списки, агрегаты и бизнес-логику.

### Кэши
- `_intCache`, `_earnedCache`, `_balanceCache`
- view caches, invalidation in `notifyListeners()`.

### API (кратко)
**Clients / Objects / Jobs**
- create/update/delete
- materials, sessions, stages
- `jobById`, `materialsForJob`, `totalMaterialCents`, `totalMinutesForJob`

**Money**
- accounts, balances, cash shifts
- `addTransaction`, `transferBetweenAccounts`, `voidTransaction`
- Excel import
- recurring payments + `runDueRecurringPayments()`
- closed periods
- `forecastCashToEndOfMonth()`

**Employees**
- employees, time entries, payments
- `earnedCents`, `employeeBalanceOwed`
- `earnedCentsForPeriod`
- `paymentTotalsForPeriod`
- `payrollSummary(start, end)`

**Sync / backup**
- `backupData()`
- `restoreFromBackup()`
- `mergeFromBackup()`

**Safety**
- `checkDataIntegrity()`
- `_reconcileEmployeePayments()`
- closed period guard `ensurePeriodOpen()`.

---

## 9. Настройки

`lib/state/settings_controller.dart` + `lib/features/settings/settings_screen.dart`.

- theme, business type, modules, terms;
- Yandex OAuth tokens, auto backup;
- hidden tabs;
- reminders, DND;
- PIN, unlock, biometrics;
- audit log UI;
- integrity check UI;
- backup import/export.

---

## 10. UI экраны

- Today: money/day summary.
- Money: accounts, balances, cash shifts, transfers, recurring payments, Excel, forecast.
- Stats: P&L by category/client/staff/day/margin/account/trend.
- Jobs: pipeline, details, cost calculator.
- Clients/Objects: client objects and job history.
- Inventory: items, stock stats, low stock, Excel import/export.
- Booking: calendar, appointments, deadlines.
- Employees: payroll, time, payments, PDF payslip.
- Settings: config, sync, security, integrity, audit.

---

## 11. Синхронизация и резервные копии

### JSON backup
`backupData()` экспортирует все сущности, включая period closures и recurring payments.

### Restore
- `restoreFromBackup` fully replaces tables transactionally.
- `mergeFromBackup` uses per-ID merge by `updated_at`.

### Incremental merge result
`BackupMergeResult { affected, keptLocal, conflicts }`.

### Audit
- app-level audit calls;
- DB triggers from v11 write insert/update/delete snapshots.

---

## 12. Soft delete / sync columns

- v7 adds `updated_at`, `deleted_at`, `device_id`.
- Repositories `getAll()` filter `deleted_at IS NULL`.
- `delete()` marks deleted.
- `mergeSnapshot` preserves fallback.

---

## 13. PDF и Excel

### PDF
- `buildJobPdf`: quote/invoice job PDF.
- `buildPayrollPdf`: payroll ledger.
- `savePdf`.

### Excel
- export inventory/money;
- import inventory and transactions.
- JSON remains canonical for sync.

---

## 14. Yandex Disk

- browser-based OAuth and REST Disk API.
- `YandexSyncService.sync` downloads and merges if remote newer, otherwise uploads.
- Auto backup on app start if enabled and newer.
- No user password stored; only token.

---

## 15. Web / сервер

- Web SQLite via wasm + persistent IndexedDB.
- `web/index.html`: bootstrap, loading/error UI, strftime wasm.
- `web_server/server.dart`: static server and SPA fallback.
- Yandex proxy files.

---

## 16. Android / release

- Namespace/applicationId: `com.mastersapp.masters`.
- Release config via `key.properties.example`.
- `ci.yml` for CI.
- ADB deployment path `build/app/outputs/flutter-apk/app-debug.apk` / `app-release.apk`.

---

## 17. Тесты

Файлы:
- `test/database_test.dart`
- `test/integrations_test.dart`
- `test/store_aggregates_test.dart`
- `test/widget_test.dart`

Покрыто:
- DB/store load;
- employee balances;
- transfer invariant;
- payment journal;
- integrity;
- newId uniqueness;
- minutes/paid/debt/balance;
- hourly earned;
- recurring due;
- payroll summary;
- closed-period guard.

---

## 18. Реализованные элементы roadmap

1. Offline DB + Web persistence.
2. Multi-tab helper.
3. Calendar jobs/deadlines.
4. Settings hidden tabs.
5. Finance transfers.
6. Team earnings chart and payroll on-fly.
7. Inventory CRUD and low stock.
8. Clients/objects/jobs and materials.
9. Booking/reminders.
10. Yandex OAuth + sync + auto backup.
11. PIN/biometrics unlock.
12. DB integrity.
13. Export/import JSON.
14. Soft delete repository filtering.
15. Audit log + DB triggers.
16. Closed accounting period.
17. Recurring payment execution.
18. Excel import/export.
19. P&L analytics, accounts, trends, forecast.
20. Payroll PDF ledger.
21. Printable documents.
22. Web wasm and local server.

---

## 19. Что осталось по планам

### A. Sync v2 / multi-device
- Полное применение `device_id`, `deleted_at`, `updated_at` на уровне моделей.
- Правильное merge по ключам и UI conflicts.
- Безопасная обработка IndexedDB reset/multi-tabs.
- Ручной выбор replace vs merge в UI (уже есть import choice).

### B. Финансовая аналитика
- Deep P&L over periods with richer charting.
- Supplier debts / prepayments / refunds.
- recurring frequencies forms.
- richer forecast inclusing recurring due schedule.
- account-level analytics modularity.

### C. Зарплата
- Salary rules by service, `pay_rules`, `payroll_accruals`.
- no on-fly recalc snapshots.
- period close UI for payroll;
- per-employee payslip export;
- advances/bonuses policies.

### D. Надежность
- migrations matrix from old DB snapshots;
- richer conflict view;
- web `foreign_keys` still off but app checks exist.

### E. Планшет и доступность
- responsive tiers;
- accessibility screen-reader/tap targets;
- landscape polish;
- onboarding demos.

### F. Релиз
- real keystore in two safe places;
- release CI artifacts;
- remove debug fallback for production.

---

## 20. Команды запуска и тестирования

```bash
flutter pub get
flutter analyze --no-pub
flutter test
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run
flutter build apk --release
dart run web_server/server.dart
```

Device install:
```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell monkey -p com.mastersapp.masters -c android.intent.category.LAUNCHER 1
```

---

## 21. Текущие артефакты

- Release APK path:
  `build/app/outputs/flutter-apk/app-release.apk`
- Phone installed app:
  - package `com.mastersapp.masters`
  - version `0.2.0`
  - APK copied to phone `/sdcard/Download/Masters-release.apk`.
- GitHub:
  - `origin/main`
  - latest pushed commits include app, tests, DB and triggers.
- Текущий test baseline:
  - `flutter test`: 12/12.
  - `flutter analyze --no-pub`: info/warning issues without errors.

---

## 22. Структура путей (фокус на разработку)

- `lib/main.dart`: entry + boot
- `lib/app/app.dart`: app/PIN/biometrics/auto sync
- `lib/state/masters_store.dart`: central domain/state
- `lib/data/app_database.dart`: schema versions/migrations/triggers
- `lib/data/repositories/*`: CRUD
- `lib/data/models/*`: entity models
- `lib/features/*`: UI screens
- `lib/core/*`: auth, backup, pdf, oauth, services
- `test/*`: automated tests
- `web/*`: wasm bootstrap and static assets
- `web_server/*`: local static server and Yandex proxy
EOF
