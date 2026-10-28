@echo off
chcp 65001 >nul
title Masters Web Server (Быстрый старт)

cd /d "%~dp0"

if not exist "build\web" (
    echo Первый запуск - требуется сборка...
    echo Это займёт 1-2 минуты.
    echo.
    call flutter build web --release
    if errorlevel 1 (
        echo.
        echo ❌ Ошибка сборки!
        pause
        exit /b 1
    )
)

start http://localhost:8080
dart run web_server\server.dart 8080
