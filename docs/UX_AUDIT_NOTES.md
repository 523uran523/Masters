# UX gaps & docs notes (консолидация корневых аудитов)

Дата переноса: 2026-11-01.

Источники: `DOCS_AUDIT.md`, `UX_GAPS_AUDIT.md` (удалены из корня).

## 1. Документация — актуальное состояние (догнано)

- DB schema: **v19** (`lib/data/app_database.dart`, см. миграции v13–v19).
- App version: `0.3.12+15` (`pubspec.yaml`).
- Test baseline: `flutter test` зелёный (см. `ARCHITECTURE.md` §17).
- Analyze baseline: `flutter analyze --no-pub` без ошибок (`print` в сервере OK).

Актуализировано:
- `ARCHITECTURE.md` — версия БД v12→v19, миграции v13–v19, артефакты.
- `README.md` — обновлены ссылки и быстрый старт; предупреждение о `launch_masters.bat`.
- `WEB_HANDOFF.md` — ссылка на `docs/YANDEX_OAUTH.md`.
- `ROADMAP.md` — добавлен раздел актуальных slug'ов (см. ниже).

## 2. UX gaps (по сценариям, из UX_GAPS_AUDIT)

### Today
- Нет быстрых действий для частых операций (продажа, расход, запись) прямо с дашборда.
- Низкий остаток и регулярные платежи не раскрыты в отдельные actionable-экраны.
- Нет onboarding/empty-state пресетов для новых пользователей.

### Jobs / Kanban
- В канбане нет фильтров (по клиенту, исполнителю, приоритету, дате) — только переключение list/process.
- Нет swiping-actions для архивирования/удаления в list view.
- Нет bulk-действий.
- В job form нет автозаполнения цены из калькулятора до выбора (уже есть отдельная кнопка).

### Money
- Журнал без фильтров (по счёту, дате, категории, клиенту/заказу).
- Нет детального экрана транзакции.
- Нет tap-to-edit/delete с confirm; void есть, но UX не компактный.
- Смена кассы: нет автопроверки расхождения и сохранения фото чека.

### Inventory / Suppliers
- Нет поиска/фильтра по складу и поставщикам.
- Нет карточки закупки с деталями строк (только агрегаты).
- Нет внесения остатков/себестоимости истории.
- Поставщики не имеют детальной страницы (только долг).

### Clients
- Есть поиск, но нет фильтров по долгам/активности.
- Нет истории коммуникаций (только шаблоны).
- Нет merge/дублей контактов.

### Employees / Payroll
- Нет редактирования сотрудника (только создание/удаление).
- Payroll summary нет экспорта per employee / из карточки.
- Нет роли owner/manager разграничения доступа.

### Booking
- Нет быстрого создания записи из карточки клиента (частично).
- Нет конфликт-проверки ресурсов (частично, есть `StateError`).
- Нет напоминаний за день.

### Stats / P&L
- Тренды есть, но нет графиков (только цифры).
- Нет фильтра по услуге/сотруднику/tag.
- Экспорт Excel/PDF частичный.

### Settings
- Табы скрываются, но нет профиля мастерской/бизнес-настроек централизованно.
- Audit viewer без фильтров и detail.
- Бэкап: нет diff/conflict picker.
- Тема/язык/единицы частично зашиты.

### Global
- Нет tablet layout / responsive two-pane.
- Нет accessibility labels.
- Нет offline sync v2 conflict UI.
- Тесты миграций v1→v19 есть (`test/database/migration_upgrade_test.dart`? см. `_queue`).

### Рекомендуемый следующий пакет (из аудита)
1. Inventory/Supplier detail + filters
2. Employee edit + payroll export card
3. Money transaction filters + detail
4. Tags/notes autocompletion and bulk actions
5. Audit filter/detail viewer

## 3. Актуальные/закрытыеslug'и и ссылки

- `docs/specs/2026-11-01-tax-profiles.md` — налоговые профили (принято).
- `docs/specs/2026-11-01-unified-booking-design.md` + UI tight — унифицированный booking (DB v19).
- `docs/specs/2026-11-01-inventory-composition.md` — inventory BOM (DB v18).
- `docs/specs/2026-11-01-encoding-sweep.md` — исправления моибейк/CP866.
- `docs/specs/2026-11-01-db-migration-snapshots.md` — снапшоты БД v1→v19.
- Очередь задач: `docs/specs/_queue.md`.

См. `ROADMAP.md` → раздел «Актуально».
