@echo off
setlocal
cd /d "%~dp0.."
set "DEVICE=%~1"
if "%DEVICE%"=="" set "DEVICE="
if exist dart_defines.json (
  if "%DEVICE%"=="" (
    flutter run --dart-define-from-file=dart_defines.json
  ) else (
    flutter run -d %DEVICE% --dart-define-from-file=dart_defines.json
  )
) else (
  if "%DEVICE%"=="" ( flutter run ) else ( flutter run -d %DEVICE% )
)
