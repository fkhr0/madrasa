@echo off
rem Gives the school server a temporary secure address (https://....trycloudflare.com)
rem so phones can use GPS. Start the server first (start-school.bat).
rem
rem Anyone who has the link can open the app's sign-in page while this window
rem is open. Close this window to switch the link off. The link changes every time.
title School tunnel - close this window to stop it
echo.
echo  Look for the line with  https://....trycloudflare.com  below.
echo  Open that address on the phones. Close this window to stop.
echo.
rem The address is also written to server\.data\tunnel.log (for scripts).
if exist "%~dp0server\.data\tunnel.log" del "%~dp0server\.data\tunnel.log"
"C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel --no-autoupdate --protocol http2 --url http://localhost:3000 --logfile "%~dp0server\.data\tunnel.log"
