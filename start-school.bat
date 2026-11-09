@echo off
rem Starts the school server and database on this PC, then opens the app.
rem The server restarts by itself if it ever stops. To stop it: stop-school.bat
cd /d "%~dp0"

if not exist build\web\index.html (
  echo The app is not built yet. Building it first...
  call build-app.bat || exit /b 1
)

cd server
if not exist node_modules (
  echo Installing the server's packages (first time only)...
  call npm install || exit /b 1
)

title School server - http://localhost:3000
rem Open the app in the browser a few seconds after the server starts.
start "" cmd /c "ping -n 6 127.0.0.1 >nul & start http://localhost:3000"

:run
if exist stop.flag del stop.flag
node src/server.js
if exist stop.flag (
  del stop.flag
  echo Server stopped.
  exit /b
)
echo.
echo The server stopped. Restarting in 5 seconds... (run stop-school.bat to stop it)
ping -n 6 127.0.0.1 >nul
goto run
