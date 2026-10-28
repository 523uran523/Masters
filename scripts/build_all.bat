@echo off
setlocal
cd /d "%~dp0.."
echo Building web...
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run
if errorlevel 1 (echo WEB BUILD FAILED & exit /b 1)
echo Building Android APK...
flutter build apk --release --no-pub
if errorlevel 1 (echo APK BUILD FAILED & exit /b 1)
echo Done. Web: build\web\   APK: build\app\outputs\flutter-apk\app-release.apk
