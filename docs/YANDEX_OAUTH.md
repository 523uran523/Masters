# Yandex OAuth + Disk backup — инструкция

Консолидация `YANDEX_APP_REGISTRATION.md`, `YANDEX_OAUTH_SETUP.md`,
`REUSABLE_PROMPT_YANDEX.md`.

## 1. Регистрация приложения (Яндекс ID)

Один раз на аккаунт пользователя: <https://oauth.yandex.ru/client/new>.

1. Название — любое, например `Masters`.
2. Тип приложения — **«Веб-сервисы»** (иначе localhost redirect отклонят).
3. Redirect URI — добавить оба:
   - `http://localhost:8080/oauth/yandex`
   - `https://oauth.yandex.ru/verification_code`
4. Доступ к Яндекс ID — можно оставить по умолчанию.
5. Доступ к Яндекс Диску — **чтение и запись**
   (scope `cloud_api:disk.read`, `cloud_api:disk.write`).
6. Создать приложение и скопировать **Client ID** и **Client secret**
   (секрет показывается один раз).

Если видите «Вход не настроен» — `YANDEX_CLIENT_ID` не передан при сборке;
пересоберите с `--dart-define`. Redirect URI должен точно совпадать (включая
порт `8080`); смена порта требует обновления `_webRedirect` в
`lib/core/yandex_oauth.dart`.

## 2. Env / конфигурация

- `YANDEX_CLIENT_ID` — через `--dart-define` при сборке:
  `set YANDEX_CLIENT_ID=...`
- `YANDEX_CLIENT_SECRET` — только сервер/мобильный fallback:
  `set YANDEX_CLIENT_SECRET=...`
- Web: сервер (`web_server/server.dart`) или прокси `:8081` подставляет
  секрет из env; `client_secret` в браузер не попадает.
- Порт сервера: `8080` (Web), прокси API: `8081` (dev).

## 3. Сборка/запуск

```bat
set YANDEX_CLIENT_ID=ваш_client_id
set YANDEX_CLIENT_SECRET=ваш_client_secret
launch_masters.bat --rebuild
```

Или вручную:

```bat
set YANDEX_CLIENT_ID=ваш_client_id
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run --dart-define=YANDEX_CLIENT_ID=%YANDEX_CLIENT_ID%
dart run web_server/server.dart 8080
```

`launch_masters.bat` подхватывает переменные окружения автоматически (если заданы
в системе или в начале bat-файла). Для Android/Windows секрет передаётся
через `--dart-define=YANDEX_CLIENT_SECRET=...`.

## 4. Как работает вход

1. Кнопка «Войти через Яндекс» открывает `oauth.yandex.ru` с PKCE-запросом.
2. Пользователь вводит пароль только на сайте Яндекса; приложение его не видит.
3. Яндекс возвращает приложение по `http://localhost:8080/oauth/yandex?code=...`.
4. Приложение обменивает код на токен через локальный сервер (обход CORS) и
   сохраняет только токен + refresh-токен. Код из адресной строки убирается.
5. Android/Windows используют страницу с кодом
   (`https://oauth.yandex.ru/verification_code`): код вводится в приложении.

Токен хранится в `shared_preferences`; кнопка «Отключить» удаляет токены.
Файл бэкапа: `disk:/Masters/masters-backup-latest.json` (общий для web и
Android). Приложение не хранит пароль Яндекса.

## 5. Ограничения / известные нюансы

- Redirect URI привязан к порту `8080`; смена порта требует обновления и
  `_webRedirect` в `lib/core/yandex_oauth.dart`, и настроек приложения в
  Яндексе.
- Токен лежит в `shared_preferences` (localStorage) — компромисс: пароль не
  хранится, но токен доступен скриптам страницы.
- Синхронизация пока снимок целиком («кто последний загрузил, тот прав»),
  без слияния по записям.
- `client_secret` в мобильном бинарнике извлекаем; для продакшена обмен
  токена лучше вынести на backend.

## 6. Для разработчиков: воспроизводимое добавление (reusable prompt)

Краткая версия задачи «browser-based Yandex Disk backup to Flutter app»:

- Заменить login/password/WebDAV на OAuth (browser-based), формат синхронизации
  JSON (один снимок БД).
- `lib/core/yandex_oauth.dart` — pure Dart, conditional imports запрещены:
  `clientId`/`clientSecret` из `String.fromEnvironment`, redirect URI (web
  `http://localhost:8080/oauth/yandex`, native
  `https://oauth.yandex.ru/verification_code`), PKCE, store code_verifier/state
  в shared_preferences, exchange/refresh/verifyState.
- `lib/core/yandex_disk_service.dart` — REST API
  `https://cloud-api.yandex.net/v1/disk`, папка `disk:/<APP>/`, файл
  `masters-backup-latest.json`, `testConnection/ensureFolder/getBackupMeta/
  uploadBackup/downloadBackup`; ошибки возвращают `null/false`, не бросают.
- Сервер (`web_server/server.dart` + `web_server/api_proxy.dart`) — прокси
  `/api/oauth/token`, `/api/disk/*`, `/api/upload`, `/api/fetch`; секрет
  подставляется только сервером из env; CORS только для хостов yandex.ru/net/com.
- `SettingsController` хранит токены/срок/`yandex_last_cloud_modified_at`/
  автобэкап; `setYandexTokens/disconnectYandex/ensureYandexToken`.
- `main.dart`: platform-выбор databaseFactory; `_completeYandexLoginIfNeeded`;
  автобэкап в фоне, если включено и подключено.
- Настройки: вход через Яндекс (web — in-place redirect, mobile — код),
  автобэкап, upload/restore/sync, disconnect; без автопуша без подтверждения.
- Web DB: не запускать `sqflite_common_ffi_web:setup` вслепую; проверять wasm
  (экспорты должны включать `sqlite3_initialize`, импорты только `dart:*` +
  `env:memory`); использовать `databaseFactoryFfiWebNoWebWorker`; не включать
  `PRAGMA foreign_keys=ON` на web.
- Синхронизация: JSON (`backupData`/`restoreFromBackup`), проверка версии схемы;
  LWW по времени последнего изменения, предупреждение о расхождениях.
- Делiverables: analyze/test green, server print infos (14) допустимы,
  обновить `WEB_HANDOFF.md`, скрипты и `DEV_WORKFLOW.md`, optionally `.github/
  workflows/ci.yml`.

## 7. Связанные документы

- `WEB_HANDOFF.md` — состояние web-сборки.
- `docs/YANDEX_OAUTH.md` — этот файл.
- `docs/UX_AUDIT_NOTES.md` — UX/doc debt.
- `docs/specs/_queue.md` — реестр задач.
