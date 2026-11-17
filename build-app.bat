@echo off
cd /d "%~dp0"

title Building the school app
echo Building the app (close other programs if your PC is low on memory)...
call flutter build web --release --no-wasm-dry-run --no-web-resources-cdn --dart-define=API_URL=origin --dart-define=DEMO=true
if errorlevel 1 (
  echo.
  echo The build failed. See the messages above.
  pause
  exit /b 1
)
echo.
echo Done. Start the school with start-school.bat
