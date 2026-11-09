@echo off
rem Stops the school server started by start-school.bat.
rem It asks the server to stop by itself (stop.flag), so the database closes
rem cleanly; only if it doesn't answer is it forced.
cd /d "%~dp0server"
echo stop > stop.flag
echo Stopping the server...
ping -n 4 127.0.0.1 >nul
for /f "tokens=5" %%p in ('netstat -ano ^| findstr /r /c:":3000 .*LISTENING"') do taskkill /f /pid %%p >nul 2>&1
echo The school server is stopped.
ping -n 2 127.0.0.1 >nul
if exist stop.flag del stop.flag
