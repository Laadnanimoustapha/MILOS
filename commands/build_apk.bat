@echo off
setlocal

for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "FLUTTER_BAT=C:\flutter\bin\flutter.bat"
set "APK_FILE=%PROJECT_ROOT%\build\app\outputs\flutter-apk\app-release.apk"

echo Building the Android release APK...
echo Flutter build progress will appear below.
echo.

pushd "%PROJECT_ROOT%"
if errorlevel 1 goto project_directory_failed

if exist "%FLUTTER_BAT%" (
    call "%FLUTTER_BAT%" build apk --release
) else (
    where flutter >nul 2>&1
    if errorlevel 1 goto flutter_not_found
    call flutter build apk --release
)

set "BUILD_RESULT=%ERRORLEVEL%"
popd
if not "%BUILD_RESULT%"=="0" goto build_failed

if not exist "%APK_FILE%" goto apk_not_found

echo.
echo APK created successfully:
echo %APK_FILE%
goto finished

:project_directory_failed
echo ERROR: Could not open the mobile project folder: %PROJECT_ROOT%
goto failed

:flutter_not_found
popd
echo ERROR: Flutter was not found at "%FLUTTER_BAT%" or on PATH.
goto failed

:build_failed
echo.
echo ERROR: Flutter build failed with exit code %BUILD_RESULT%.
goto failed

:apk_not_found
echo.
echo ERROR: Build succeeded, but the expected APK was not found:
echo %APK_FILE%
goto failed

:failed
set "EXIT_CODE=1"
goto finish_with_pause

:finished
set "EXIT_CODE=0"

:finish_with_pause
echo.
pause
endlocal & exit /b %EXIT_CODE%
