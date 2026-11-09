@echo off
rem Builds the app for the browser. It talks to the server it is opened from,
rem so it works on this PC (http://localhost:3000) and on phones on the same
rem Wi-Fi (http://<this PC's address>:3000).
rem Run it again after changing the Flutter code. Takes a few minutes.
rem The result goes to build\web, which the server shows at http://localhost:3000
cd /d "%~dp0"

title Building the school app
echo Building the app (close other programs if your PC is low on memory)...
rem --no-web-resources-cdn: the drawing engine (CanvasKit) comes from this
rem server, not Google's CDN (works offline; the security rules allow only it).
call flutter build web --release --no-wasm-dry-run --no-web-resources-cdn --dart-define=API_URL=origin --dart-define=DEMO=true
if errorlevel 1 (
  echo.
  echo The build failed. See the messages above.
  pause
  exit /b 1
)
echo.
echo Done. Start the school with start-school.bat
