@echo off
rem Builds the app for Google Play: an app bundle (.aab) signed with the
rem upload key (android\key.properties), talking to the real server.
rem   build-play.bat https://api.your-domain.iq
rem
rem Before each upload, raise the number after "+" in pubspec.yaml
rem (version: 1.0.0+1 -> 1.0.1+2): Google Play refuses a number it has seen.
rem
rem The result: build\app\outputs\bundle\release\app-release.aab
rem Keep build\symbols (it turns crash reports back into readable code).
cd /d "%~dp0"

set ADDRESS=%~1
if "%ADDRESS%"=="" (
  echo Give the server's https address, e.g.
  echo   build-play.bat https://api.your-domain.iq
  exit /b 1
)
if /i not "%ADDRESS:~0,8%"=="https://" (
  echo The store app talks to the server over https only: %ADDRESS%
  exit /b 1
)
if not exist android\key.properties (
  echo android\key.properties is missing: Google Play needs the upload key.
  exit /b 1
)

title Building for Google Play
echo Building the Play Store app for %ADDRESS% (about 5 minutes)...
call flutter build appbundle --release --obfuscate --split-debug-info=build\symbols --dart-define=API_URL=%ADDRESS%
if errorlevel 1 (
  echo.
  echo The build failed. See the messages above.
  pause
  exit /b 1
)
rem Gradle keeps about 3 GB of memory after a build: give it back.
call android\gradlew.bat -p android --stop >nul 2>&1
echo.
echo Done: build\app\outputs\bundle\release\app-release.aab
echo Upload it in Play Console: Test and release, then your track, Create new release.
