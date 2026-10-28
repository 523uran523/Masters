@echo off
chcp 65001 >nul
title Masters Web Server

echo ╔════════════════════════════════════════╗
echo ║   Masters Web - Локальный сервер      ║
echo ╚════════════════════════════════════════╝
echo.

cd /d "%~dp0"

if not exist "build\web" (
    echo [1/2] Сборка web-версии...
    call flutter build web --release
    if errorlevel 1 (
        echo.
        echo ❌ Ошибка сборки!
        pause
        exit /b 1
    )
    echo ✅ Сборка завершена
    echo.
)

echo [2/2] Запуск сервера...
echo.
dart run web_server\server.dart 8080

pause
