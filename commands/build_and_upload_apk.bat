@echo off
setlocal

for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "FLUTTER_BAT=C:\flutter\bin\flutter.bat"
set "APK_FILE=%PROJECT_ROOT%\build\app\outputs\flutter-apk\app-release.apk"
set "MANIFEST_FILE=%TEMP%\doura-release-info-%RANDOM%.json"
set "SSH_KEY=C:\Users\test\Desktop\PROJECTIME\DOURA\VMS\OCI-DOURA-MAIN-SERVER\ssh-key-2026-10-05.key"
set "VM=ubuntu@84.8.218.66"

echo Doura APK build and upload
echo ==========================
echo.

echo [1/6] Checking the project folder...
if not exist "%PROJECT_ROOT%\pubspec.yaml" goto project_directory_failed

echo [2/6] Checking SSH prerequisites...
if not exist "%SSH_KEY%" goto missing_key
where ssh.exe >nul 2>&1
if errorlevel 1 goto missing_ssh
where scp.exe >nul 2>&1
if errorlevel 1 goto missing_scp

echo.
echo [3/6] Building the Android release APK...
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
echo [4/6] Preparing release metadata...
powershell.exe -NoProfile -Command "$info = @{ filename = 'app-release.apk'; releasedAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'); sizeBytes = (Get-Item -LiteralPath $env:APK_FILE).Length }; [IO.File]::WriteAllText($env:MANIFEST_FILE, ($info | ConvertTo-Json), [Text.UTF8Encoding]::new($false))"
if errorlevel 1 goto manifest_failed

echo.
echo [5/6] Connecting to the VM and preparing the upload folder...
ssh.exe -i "%SSH_KEY%" %VM% "mkdir -p ~/apk"
if errorlevel 1 goto connection_failed

echo.
echo [6/6] Uploading the APK and metadata...
scp.exe -i "%SSH_KEY%" "%APK_FILE%" "%VM%:~/apk/.app-release.apk.uploading"
if errorlevel 1 goto upload_failed
scp.exe -i "%SSH_KEY%" "%MANIFEST_FILE%" "%VM%:~/apk/.release-info.json.uploading"
if errorlevel 1 goto upload_failed

echo Publishing the uploaded files as the current release...
ssh.exe -i "%SSH_KEY%" %VM% "mv ~/apk/.app-release.apk.uploading ~/apk/app-release.apk && find ~/apk -maxdepth 1 -type f -name '*.apk' ! -name 'app-release.apk' -delete && mv ~/apk/.release-info.json.uploading ~/apk/release-info.json"
if errorlevel 1 goto finalize_failed

del "%MANIFEST_FILE%" >nul 2>&1
echo.
echo SUCCESS: Build and upload completed.
echo The APK and release-info.json are in ~/apk on the VM.
goto finished

:project_directory_failed
echo ERROR: Could not find or open the mobile project folder: %PROJECT_ROOT%
goto failed

:missing_key
echo ERROR: SSH key not found: %SSH_KEY%
goto failed

:missing_ssh
echo ERROR: ssh.exe was not found. Install or enable the Windows OpenSSH Client.
goto failed

:missing_scp
echo ERROR: scp.exe was not found. Install or enable the Windows OpenSSH Client.
goto failed

:flutter_not_found
popd
echo ERROR: Flutter was not found at "%FLUTTER_BAT%" or on PATH.
goto failed

:build_failed
echo.
echo ERROR: Flutter build failed with exit code %BUILD_RESULT%. The APK was not uploaded.
goto failed

:apk_not_found
echo ERROR: Build succeeded, but the expected APK was not found:
echo %APK_FILE%
goto failed

:manifest_failed
echo ERROR: Could not create release metadata.
goto failed

:connection_failed
echo ERROR: Could not connect to the VM or create ~/apk.
goto failed

:upload_failed
echo ERROR: APK or metadata upload failed. The current release on the VM was left in place.
goto failed

:finalize_failed
echo ERROR: Uploaded files could not be installed as the current release on the VM.
goto failed

:failed
set "EXIT_CODE=1"
if exist "%MANIFEST_FILE%" del "%MANIFEST_FILE%" >nul 2>&1
goto finish_with_pause

:finished
set "EXIT_CODE=0"

:finish_with_pause
echo.
pause
endlocal & exit /b %EXIT_CODE%
