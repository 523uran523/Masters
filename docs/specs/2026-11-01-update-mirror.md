# ТЗ: Зеркало обновлений (mirror update server) (update-mirror)

Статус: **выдано** (senior)
Дата: 02.11.2026
Пользователь: «Добавь второй сервер для обновления apk и на этом сервере будем тестить все новые наработки по синхронизации пользователей и тд.» + «Зеркало обновлений».

## Цель
Сделать так, чтобы Masters мог проверять обновления **на двух endpoint'ах**: основной (стабильный, `https://kzvk.212-19-134-251.sslip.io:8443`) и зеркало (Техно-телефон, `http://10.181.239.143:8080` или cloudflare-туннель), мирно переключаясь между ними (настройка / автоматический fallback / сборка-режим). Зеркало будет принимать «нестабильные» бета-бинарники и новые API синхронизации пользователей.

## Входит — Masters (lib)
### A. `app/update_service.dart` / `core/update_service.dart`
- Поддержать два endpoint'а: primary + secondary (через настройку `update_mirror_url` в `settings_controller`).
- Метод `checkForUpdate({useMirror=false})` — проверяет выбранный; если `useMirror=true` и запрос не удался ИЛИ prod недоступен — fallback на mirror (для dev-режима).
- Новый флаг `args_factory`?
### B. `lib/app/update_service.dart` (если отличается) — проверить, что это один файл.
### C. `settings_controller.dart`: добавить:
  - `updateMirrorUrl` (string, nullable) getter/setter;
  - `updateMirrorEnabled` (bool, default false);
  - `updateChannel` (string, 'stable'/'beta', default 'stable').
### D. `settings_screen.dart`: в блок «Приложение» добавить подраздел «Канал обновлений»: segmented stable/beta + поле «URL зеркала» (по умолч.) + «Проверить зеркало» + статус (рамка/CupertinoButton). При channel=beta — первичная проверка зеркала.
### E. `UpdateService` should compute "update_available" using the selected channel (beta channel means code+1).
### F. Тесты: `test/update_service_test.dart` (если есть) — расширить 4 кейсами: primary/ mirror checks, fallback, decoding.

## Входит — TecnoServer repo
Создать файл `docs/mirror-apk-update.md` с инструкцией:
- Структура каталога `/data/data/com.termux/files/home/MirrorUpdates/masters/{version}/` (или на `/sdcard/Download/...`).
- Формат `versions.json` (mirrors prod API: `{app_id, latest_version_code, latest_version_name, min_supported_version_code, apk_url, sha256, changelog, force_update, update_available}`).
- Команды для генерации JSON и копирования apk через `adb push` / `scp` на порт 8022.
- Пример `nginx.conf` server-block `/updates/` (mime application/vnd.android.package-archive) + `changelog`.
- Флаг `--no-cache-control` / 5min.
- Чек-лист «после публикации».

## Не входит
- Сборка отдельных build variants (debug/release) — это Gradle-конфиг, отложено.
- Без новых зависимостей.
- Не трогать БД/миграции; не трогать unified booking, inventory.

## Критерии приёмки
- App-side: primary fails or mirror enabled + user chooses beta → check executes against mirror. Тесты зелёные.
- TecnoServer-side: документ с копируемым nginx-блоком + deploy-command sequence (достаточно для manual setup by user).
- analyze 0 errors; тесты 108+ (existing 107 + 1 unified mirror) зелёные.
- Коммиты с push (Masters) + commit/push (TecnoServer).
- Отчёт до 25 строк: файлы, hash, analyze/test, gcd-блокер (деплой на телефоне требует user involvement).

## Запреты
- Не трогать pubspec версию (сейчас 0.3.13+16).
- Документы only; код править только `update_service`, `settings_*`.