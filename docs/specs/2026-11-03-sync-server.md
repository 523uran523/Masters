# Спека: синхронизация нескольких устройств через свой сервер (sync-server)

Статус: **реализовано** (DB v20, клиент + сервер)
Дата: 03.11.2026
Область: `lib/core/sync_client.dart`, `lib/state/sync_service.dart`, `lib/state/settings_controller.dart`, `lib/data/app_database.dart`, `lib/features/settings/sync_card.dart`; сервер — репозиторий `TecnoServer` (`server/`, `docs/SYNC_API.md`).

## 1. Цель и модель правды

Несколько мастеров/устройств работают с одними и теми же данными, но **источник правды остаётся на телефоне** — в локальной SQLite. Сервер не является базой приложения: он хранит только версии строк и историю изменений, чтобы раздавать их другим устройствам одной «рабочей области» (space).

- Офлайн-первичность: приложение работает без сети, изменения копятся в локальной очереди `sync_outbox`.
- Сервер — буфер обмена, а не владелец данных; потеря сервера не теряет данные на устройствах.
- Конфликты разрешаются детерминированно (last-write-wins + тай-брейк по `device_id`) одинаково на обеих сторонах.

## 2. Схема БД v20

`AppDatabase.version == 20`. Миграция `oldVersion < 20` добавляет:

1. Служебные колонки `updated_at INTEGER`, `deleted_at INTEGER`, `device_id TEXT` в 24 таблицы (`_ensureSyncColumns`; вызывается дважды — после базовых и после поздних схем).
2. Таблицу очереди:

```sql
CREATE TABLE sync_outbox (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,
  row_id TEXT NOT NULL,
  queued_at INTEGER NOT NULL
);
CREATE INDEX idx_sync_outbox_row ON sync_outbox(table_name, row_id);
```

3. Триггеры `sync_out_<table>_<insert|update|delete>` для каждой из 23 синхронизируемых таблиц. Триггер пишет `(table_name, row_id, queued_at = strftime('%s','now')*1000)`.

Триггеры нужны потому, что часть репозиториев пишет строки без меток и делает физические удаления: без очереди такие изменения нечем обнаружить.

### Синхронизируемые таблицы (23)

`clients`, `objects`, `jobs`, `job_stages`, `materials`, `accounts`, `cash_shifts`, `money_transactions`, `inventory_items`, `suppliers`, `purchases`, `purchase_lines`, `stock_movements`, `inventory_compositions`, `booking_resources`, `appointments`, `client_reminders`, `employees`, `time_entries`, `employee_payments`, `recurring_payments`, `payroll_periods`, `period_closures`.

**Не синхронизируются:** `work_sessions` (локальный autoincrement-идентификатор, строки несопоставимы между устройствами), `attachments` (файлы и пути локальны), `audit_log` (журнал конкретного устройства), `sync_outbox` (служебная).

### Порядок применения

`_syncApplyOrder`: справочники → зависимые строки (`clients`, `employees`, `suppliers`, `accounts`, `booking_resources`, `inventory_items`, `objects`, `jobs`, `job_stages`, `materials`, `appointments`, `client_reminders`, `cash_shifts`, `money_transactions`, `purchases`, `purchase_lines`, `stock_movements`, `inventory_compositions`, `time_entries`, `employee_payments`, `recurring_payments`, `payroll_periods`, `period_closures`). Это снижает число «висячих» вставок при первом полном снапшоте.

## 3. Модель строки и разрешение конфликтов

Одна версия строки (`SyncRow`):

```json
{
  "table": "clients",
  "id": "c_abc",
  "updated_at": 1793714113656,
  "device_id": "dev-7f3a",
  "deleted": false,
  "data": {"id": "c_abc", "name": "Иван", "updated_at": 1793714113656, "device_id": "dev-7f3a"}
}
```

- `updated_at` — миллисекунды; метка ставится клиентом при отправке (в БД не пишется, иначе триггер вернул бы строку в очередь).
- `deleted: true` — надгробие; физическое удаление превращается в `deleted_at != null` в payload.
- `device_id` — идентификатор устройства (`sync_device_id` в prefs, генерируется один раз).

Правило `IsNewer` (одинаково в `store.go` и `AppDatabase.applySyncRows`):

1. Больший `updated_at` побеждает.
2. При равенстве — лексикографически больший `device_id`.
3. Полное равенство трактуется как «локальная версия не хуже» — входящая строка пропускается (`keptLocal`).

При слиянии применяются только колонки, присутствующие в payload; остальные берутся из локальной строки. `updated_at`/`device_id` проставляются из входящей версии, `deleted_at` — из `deleted`, если не пришёл в данных.

## 4. Клиент

### 4.1. `SyncClient` (`lib/core/sync_client.dart`)

Тонкая обёртка над `http` (таймаут 25 с), база URL нормализуется (обрезка `/`), ошибки — `SyncException{message, code, statusCode, isUnauthorized}`.

| Метод | HTTP |
|---|---|
| `health()` | `GET /api/health` |
| `signUp/signIn/signOut/me` | `/api/auth/*` |
| `spaces/createSpace/joinSpace/leaveSpace/stats` | `/api/spaces*` |
| `push({token, spaceId, rows})` | `POST /api/sync/push` |
| `pull({token, spaceId, since, limit, cursor})` | `GET /api/sync/pull` |

`createSpace`/`joinSpace` читают объект из `data['space']`, `spaces()` — массив из `data['spaces']` (сервер оборачивает одиночные объекты).

### 4.2. `SyncService` (`lib/state/sync_service.dart`)

Состояние в `SettingsController` (prefs): `sync_base_url`, `sync_email`, `sync_token`, `sync_token_expires_at`, `sync_space_id/name/invite`, `sync_last_seq`, `sync_device_id`, `sync_last_at`, `sync_auto` (по умолчанию `true`).

Один проход `syncNow()`:

1. **Push-цикл**: `collectSyncBatch(limit: 200)` → `client.push` → `confirmSyncBatch` → применение `conflicts` через `applySyncRows`; повтор, пока пачка не опустеет.
2. **Pull-цикл**: `client.pull(since: syncLastSeq, limit: 500, cursor)` → `applySyncRows` → `since = next`, `cursor = cursor`; повтор, пока `more == true`.
3. `setSyncLastSeq(since)`, `store.load()` при `applied > 0`, `markSyncedNow()`.
4. `401` → `signOutSync()` и сообщение «Сессия истекла» (повторный вход нужен вручную).

Автозапуск: `MastersApp` при старте и на `AppLifecycleState.resumed` вызывает `_tryServerSync()` — только если пользователь вошёл, есть space, включён автосинк и `pending > 0`.

Выход из аккаунта/области очищает `sync_outbox`: очередь относится к прошлой области и не должна утечь в новую.

### 4.3. Сборка пачки (`collectSyncBatch`)

- Записи читаются из `sync_outbox` пачками, дедуплицируются по `table\0id`; повторы помечаются `staleIds` и удаляются.
- Неизвестные таблицы (например, из старой версии схемы) тоже уходят в `staleIds`, а не ломают проход.
- Если строки в таблице уже нет — отправляется надгробие с меткой `queued_at` (или `now`).
- Иначе метка = `max(updated_at, created_at, queued_at)`, устройство = сохранённый `device_id` (или текущий).
- `confirmSyncBatch` удаляет только те записи очереди, что ушли; изменения, сделанные во время отправки, остаются.

## 5. Сервер (`TecnoServer`, Go, stdlib-only)

- Бинарник `meaxis-sync`, слушает `127.0.0.1:8090`, наружу — nginx на `:8080` (`location /api/`).
- Состояние: `~/MeAxisSync/data.json` (атомарная запись, всё в памяти).
- API `1.0.0`, сессии 30 дней, пароли PBKDF2-HMAC-SHA256 (60000 итераций, соль на пользователя), токены после `signout` не переиспользуются.
- Рабочая область: `id`, `name`, `invite_code`, `members`, `owner_id`; вход по инвайт-коду, выход — `DELETE /api/spaces/{id}`.

| Метод | Путь | Ответ |
|---|---|---|
| GET | `/api/health` | `{ok, service, api, uptime_sec, users, spaces}` |
| POST | `/api/auth/signup` | `{token, expires_at, user}` (201) |
| POST | `/api/auth/signin` | `{token, expires_at, user}` |
| POST | `/api/auth/signout` | отзыв токена |
| GET | `/api/auth/me` | `{user}` |
| GET | `/api/spaces` | `{spaces: [...]}` |
| POST | `/api/spaces` | `{space}` |
| POST | `/api/spaces/join` | `{space}` |
| DELETE | `/api/spaces/{id}` | выход из области |
| GET | `/api/spaces/{id}/stats` | `{records, tombstones, tables, seq, updated_at}` |
| POST | `/api/sync/push` | `{applied, seq, conflicts}` |
| GET | `/api/sync/pull` | `{rows, next, latest, more, reset, cursor}` |

Push применяет строку, только если она новее текущей (`IsNewer`); устаревшие возвращаются в `conflicts`, чтобы клиент забрал актуальную версию. Успешные строки получают монотонный `seq`.

### Pull: два режима

- **Инкрементальный** (`since > 0` и `since >= MinSeq-1`): изменения с `seq > since` в порядке роста, не более `limit` (по умолчанию 500, максимум 2000). `next` — последний отданный `seq`, по завершении — `latest`.
- **Полный снапшот** (`since == 0` или история обрезана): все живые и удалённые строки, отсортированные по ключу `table\0id`. Пагинация идёт не по `seq`, а по `cursor` — base64url от последнего отданного ключа. `reset: true` только при `since == 0`. Пока `more == true`, `next` остаётся равным `since`, а клиент продолжает с `cursor`; после последней страницы `next == latest`.

Сервер хранит до 40 000 изменений на область и обрезает до 25 000; клиент со слишком старым `since` автоматически получает полный снапшот.

## 6. Деплой

Приложение: ошибок нет при `DB v20` + `flutter analyze`.

Сервер (`TecnoServer`):

```powershell
# сборка linux/arm64 + scp + перезапуск + health
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/deploy-sync.ps1

# только сборка
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-sync.ps1 -Arch arm64 -Out server/meaxis-sync-arm64
```

- Доступ к телефону: `adb forward tcp:8022 tcp:8022` (sshd Termux), `ssh -p 8022 -i ~/.ssh/termux_phone u0_a235@127.0.0.1`.
- Удалённый скрипт перезапуска передаётся в `ssh ... sh -s` **через stdin** (одинарный here-string), чтобы PowerShell не раскрывал `$()`.
- Процесс ищется по `/proc/<pid>/comm == meaxis-sync` (в Termux `pgrep -x` его не видит).
- Запуск: `nohup setsid ~/meaxis-sync -addr 127.0.0.1:8090 -data ~/MeAxisSync >> ~/meaxis-sync.log 2>&1 &`.
- Автозапуск и keepalive — `~/.termux/boot/start-autonomous.sh` (Termux:Boot, цикл 120 с).
- nginx: `upstream meaxis_sync { server 127.0.0.1:8090; keepalive 16; }`, `client_max_body_size 64m`, `proxy_buffering off`. Файл `config/nginx.conf` в репозитории равен рабочему конфигу телефона — правки синхронизировать в обе стороны.

## 7. Проверка

Сквозной сценарий через nginx (`http://127.0.0.1:8080`), выполнен на устройстве:

1. `health` → 200, `api 1.0.0`.
2. `signup` ×2, `createSpace` (owner, инвайт), `join` → `members = 2`.
3. `push` 3 строк → `applied 3`, `seq 3`.
4. Снапшот `limit=2` → 2 строки, `more`, `cursor`; следующая страница → 3-я строка, `more=false`.
5. `since=3` → 0 строк; устаревший push → `applied 0`, `conflicts 1`.
6. Тай-брейк по `device_id` → `applied 1`, `seq 4`.
7. Надгробие → `tombstones 1`, `records 2`.
8. `signout` → `me` 401.

Тесты схемы: `test/database_test.dart` (v20, outbox, триггеры, миграция v19→v20), `test/migration_upgrade_test.dart` (фикстуры v1…v19 → v20). Сервер: `go test ./...` в `TecnoServer` (LWW, пагинация снапшота, инкремент, членство).

## 8. Ограничения и известные риски

- Нет HTTPS «из коробки»: только локальная сеть или туннель (cloudflared). Токен передаётся по HTTP — не выводить сервер в публичный интернет без TLS.
- Один файл состояния на все области, полностью в памяти: при росте данных нужен переход на БД.
- Нет разрешения конфликтов на уровне полей/операций: только версия строки целиком.
- `work_sessions`, вложения и журнал аудита не синхронизируются — известное и намеренное ограничение.
- Часы устройств влияют на LWW; при сильном расхождении времени побеждает «часы вперёд». Тай-брейк по `device_id` делает результат детерминированным, но не «правильным».
- Первый снапшот большой области идёт страницами по `cursor`; до его завершения `syncLastSeq` не двигается.
- Выход из области очищает очередь: несохранённые локальные изменения останутся только на этом устройстве (они уже в локальной БД, но другим не уйдут).
