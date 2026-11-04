# Masters — локальный трекер для мастера / бригады

Локальный учёт: клиенты, объекты, заказы/наряды, этапы, материалы, время,
деньги, склад, зарплата. Работает без интернета на Android, iOS, Windows
и в браузере. Архитектура, схема данных и конвенции UI — в `ARCHITECTURE.md`.

## Быстрый старт

**Web:** ярлык «Masters Web» на рабочем столе или `launch_masters.bat`
первый запуск ~2 мин (сборка), дальше мгновенно. Адрес `http://localhost:8080`,
данные в IndexedDB этого браузера, приложение офлайн.

**Android:** `.\scripts\dev_android.bat` (или `scripts\dev_android.bat emulator-5554`).
**Windows:** `flutter run -d windows`. **iOS:** `flutter run -d ios`.

## Разработка

```bat
scripts\dev_web.bat        # прокси Яндекса :8081 + flutter run web-server :8080 (hot restart)
scripts\dev_android.bat    # Android в другом терминале, параллельно
scripts\build_all.bat      # web-release + APK одним запуском
```

- Один код на все платформы: платформенные различия только через `kIsWeb`
  и условные импорты, `dart:io`/`dart:html` в общей логике запрещены.
- Секреты не коммитим: `dart_defines.json` (gitignored) из шаблона
  `dart_defines.example.json`, сервер берёт `YANDEX_CLIENT_SECRET` из окружения.
- `web/sqlite3.wasm` зафиксирован под пакет `sqlite3 3.5.2`.
  `dart run sqflite_common_ffi_web:setup` вслепую не запускать — перезапишет
  неподходящий бинарник. Пересборка web: `launch_masters.bat --rebuild`.
- На порту 8080 может стоять только один сервер. `flutter run -d chrome`
  открывает временный профиль браузера — IndexedDB не сохраняется.
- Меняете схему — обновляйте `onCreate`, `onUpgrade` **и** `restoreFromBackup()`,
  иначе веб- и мобильные данные разойдутся.

## Проверки

По договорённости `flutter analyze` и `flutter test` не запускаются после
каждой задачи — только по запросу или перед релизом. Перед релизом:
`flutter pub get`, `flutter analyze --no-pub`, `flutter test`,
`flutter build apk --release` и `flutter build web --release`.
Текущая база: analyze — 0 ошибок, `flutter test` — 131/131.

## Сборка релиза

```bat
flutter build apk --release
flutter build windows --release
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run
```

APK: `build\app\outputs\flutter-apk\app-release.apk`.

**Подпись.** По умолчанию релиз собирается debug-ключом. Для Google Play и
обновлений нужен собственный keystore: `.\scripts\create-release-keystore.ps1`
создаст `android/upload-keystore.jks` и `android/key.properties`, Gradle
подхватит их автоматически. `key.properties` и `*.jks` в `.gitignore`.
Сохраните keystore в двух независимых местах: потеря ключа делает обновления
невозможными, менять ключ после выпуска нельзя.

## Обновления приложения

Клиент сверяет `version_code` на `https://kzvk.212-19-134-251.sslip.io:8443`,
скачивает APK с дозагрузкой (HTTP Range), проверяет SHA-256 — при несовпадении
файл удаляется — и предлагает установить. Зеркало в LAN:
`http://192.168.1.112:8080/master-updates/`.

Обновление срабатывает **только по `version_code`**, поэтому каждый выпуск
обязан поднимать build-номер в `pubspec.yaml` (`version: 0.3.16+19`).

## Синхронизация

- **JSON-бэкап** — снимок всех таблиц: `backupData()`, `restoreFromBackup()`
  (замена), `mergeFromBackup()` (слияние по `updated_at`).
- **Яндекс.Диск** — OAuth с PKCE, файл `disk:/Masters/masters-backup-latest.json`,
  общий для web и Android. Регистрация: `oauth.yandex.ru/client/new`, тип
  «Веб-сервисы», redirect URI `http://localhost:8080/oauth/yandex` **и**
  `https://oauth.yandex.ru/verification_code`, scopes `cloud_api:disk.read`
  и `cloud_api:disk.write`. `YANDEX_CLIENT_ID` передаётся при сборке через
  `--dart-define`, секрет остаётся на сервере и в браузер не попадает.
  Порт 8080 зашит в `_webRedirect` — при смене порта правьте и его, и
  настройки приложения в Яндексе.
- **meaxis-sync** — собственный сервер, слияние по записям (БД v20).
- CSV — только ручная выгрузка «для Excel», на синхронизацию не влияет.

## Платформы: отличия web

- IndexedDB вместо SQLite (через wasm), `PRAGMA foreign_keys` не включается —
  целостность проверяет приложение.
- Нет push-уведомлений и фоновой работы; экспорт через загрузку файлов.
- Очистка данных браузера удаляет базу — держите включённый бэкап.
- Две вкладки пишут в одну базу: `single_tab_coordinator` предупреждает.

## Что дальше

Синхронизация: разрешение конфликтов в UI, вынос обмена токена с мобильных
сборок на backend. Зарплата: ставки по услугам и снимки начислений (сейчас
`earnedCents` считает на лету — правка ставки меняет историю). Пилот на
3–5 реальных бизнесах. Очередь задач — в `docs/specs/_queue.md`.
