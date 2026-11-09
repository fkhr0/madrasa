@echo off
rem Builds the Android app for testing on a phone.
rem   build-android.bat          -> the sign-in page asks for the server's
rem                                 address (type the tunnel's https address;
rem                                 one APK works with every new tunnel)
rem   build-android.bat https://something.trycloudflare.com  -> fixed address
rem The result: build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
rem (copy it to the phone and open it to install).
cd /d "%~dp0"

set ADDRESS=%~1
if "%ADDRESS%"=="" set ADDRESS=ask

title Building the Android app
echo Building the Android app (server: %ADDRESS%, takes about 5 minutes)...
call flutter build apk --release --split-per-abi --dart-define=API_URL=%ADDRESS% --dart-define=DEMO=true
if errorlevel 1 (
  echo.
  echo The build failed. See the messages above.
  pause
  exit /b 1
)
echo.
echo Done: build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
echo Copy it to the phone (WhatsApp to yourself, a cable, or Google Drive) and open it.
