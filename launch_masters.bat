@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "MASTERS_DIR=%~dp0"
cd /d "%MASTERS_DIR%"

if /i "%~1"=="--rebuild" (
    if exist "build\web" rmdir /s /q "build\web"
)

if not exist "build\web\index.html" (
    title Masters - First Launch
    mode con: cols=60 lines=15
    color 0A
    
    echo.
    echo  ======================================================
    echo.
    echo              MASTERS WEB
    echo          First Launch - Building...
    echo.
    echo  ======================================================
    echo.
    echo  Building web version...
    echo  This will take 1-2 minutes.
    echo.

    if not exist "web\sqlite3.wasm" (
        echo  Preparing web database...
        call dart run sqflite_common_ffi_web:setup --force
        echo.
    )

    if not exist "web\sqflite_sw.js" (
        echo  Preparing web database worker...
        call dart run sqflite_common_ffi_web:setup --force
        echo.
    )
    
    set "YANDEX_ARG="
    if defined YANDEX_CLIENT_ID set "YANDEX_ARG=--dart-define=YANDEX_CLIENT_ID=%YANDEX_CLIENT_ID%"

    call flutter build web --release --no-web-resources-cdn --no-wasm-dry-run %YANDEX_ARG% 2>nul
    
    if errorlevel 1 (
        color 0C
        echo.
        echo  ERROR: Build failed!
        echo.
        echo  Try manually:
        echo   flutter pub get
        echo   flutter build web --release --no-web-resources-cdn
        echo.
        pause
        exit /b 1
    )
    
    echo.
    echo  Build completed!
    echo.
    timeout /t 2 >nul
)

netstat -ano | findstr ":8080.*LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo Server already running on port 8080
    start http://localhost:8080
    exit /b 0
)

title Masters Web Server
mode con: cols=70 lines=18
color 0B

echo.
echo  ===============================================================
echo.
echo                     MASTERS WEB SERVER
echo                Business Management System
echo.
echo  ===============================================================
echo.
echo  Server started
echo  Address:  http://localhost:8080
echo  Folder:   %MASTERS_DIR%build\web
echo.
echo  ---------------------------------------------------------------
echo.
echo  Opening browser...
echo.
echo  Do NOT close this window while using the application
echo  Press Ctrl+C to stop the server
echo.
echo  ---------------------------------------------------------------
echo.

start "" cmd /c "timeout /t 2 >nul && start http://localhost:8080"

dart run web_server\server.dart 8080
