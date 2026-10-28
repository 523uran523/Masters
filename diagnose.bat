@echo off
chcp 65001 >nul
echo ========================================
echo Masters Web - Diagnostics
echo ========================================
echo.

cd /d "%~dp0"

echo [1] Checking build files...
if exist "build\web\index.html" (
    echo   ✓ index.html exists
) else (
    echo   ✗ index.html NOT FOUND
)

if exist "build\web\main.dart.js" (
    for %%A in (build\web\main.dart.js) do echo   ✓ main.dart.js exists (%%~zA bytes)
) else (
    echo   ✗ main.dart.js NOT FOUND
)

if exist "build\web\flutter.js" (
    echo   ✓ flutter.js exists
) else (
    echo   ✗ flutter.js NOT FOUND
)

echo.
echo [2] Checking server status...
netstat -ano | findstr ":8080.*LISTENING" >nul 2>&1
if errorlevel 1 (
    echo   ✗ Server NOT running on port 8080
) else (
    echo   ✓ Server running on port 8080
)

echo.
echo [3] Testing server response...
echo   Opening test page in browser...
start http://localhost:8080/test.html
timeout /t 2 >nul

echo.
echo [4] Check browser console (F12) for errors
echo.
echo Press any key to close...
pause >nul
