@echo off
title School tunnel - close this window to stop it
echo.
echo  Look for the line with  https://....trycloudflare.com  below.
echo  Open that address on the phones. Close this window to stop.
echo.
if exist "%~dp0server\.data\tunnel.log" del "%~dp0server\.data\tunnel.log"
"C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel --no-autoupdate --protocol http2 --url http://localhost:3000 --logfile "%~dp0server\.data\tunnel.log"
