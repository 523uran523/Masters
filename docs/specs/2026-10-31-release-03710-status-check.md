# ТЗ: проверить статус релиза 0.3.7+10 (read-only)

Статус: **выдано** (senior)
Дата: 31.10.2026

## Цель
Определить, завершён ли релиз 0.3.7+10 (APK-сборка, SCP, публикация на сервер, верификация).

## Шаги (только чтение, никаких изменений)
1. В `C:\Users\523ur\Documents\MyProjects\Apps\Masters`: `git log --oneline -6`, `git status --short --branch`.
2. Проверить наличие APK на диске:
   - `C:\Users\523ur\Documents\Masters\build\app\outputs\flutter-apk\app-release.apk` (или mirror `C:\M\Masters\build\...`)
   - копии `C:\Users\523ur\Documents\masters-v0.3.7*.apk`, `C:\Users\523ur\Downloads\masters-v0.3.7*.apk`
   - sizes + SHA-256 универсального (если есть).
3. Проверить сервер:
   `https://kzvk.212-19-134-251.sslip.io:8443/api/updates/check?app_id=com.mastersapp.masters&version_code=10`
   Ожидаем: `latest_version_code=10`, `latest_version_name=0.3.7`, SHA совпадает.
   (Если HTTP-метод GET не работает — посмотреть как это делалось ранее в dev-примечаниях/CI.)
4. В отчёте точно: опубликован или нет; какие артефакты на месте; что не дорделано из цепочки (build / scp / publish / verify); SHA-256 и размер если есть; commit HEAD.

## Запреты
- Не собирать, не публиковать, не менять код. Только чтение + HTTP-запросы к update endpoint.
