@echo off
setlocal
cd /d "%~dp0.."
if not exist dart_defines.json copy dart_defines.example.json dart_defines.json
start "YandexProxy" cmd /k "dart run web_server/proxy_server.dart 8081"
flutter run -d web-server --web-port 8080 --dart-define=YANDEX_API_BASE=http://localhost:8081 --dart-define-from-file=dart_defines.json
