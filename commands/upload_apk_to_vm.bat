@echo off
setlocal

for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
set "APK_FILE=%PROJECT_ROOT%\build\app\outputs\flutter-apk\app-release.apk"
set "MANIFEST_FILE=%TEMP%\doura-release-info-%RANDOM%.json"
set "SSH_KEY=C:\Users\test\Desktop\PROJECTIME\DOURA\VMS\OCI-DOURA-MAIN-SERVER\ssh-key-2026-10-05.key"
set "VM=ubuntu@84.8.218.66"

echo Doura APK release upload
echo =======================
echo.

if not exist "%APK_FILE%" goto missing_apk
if not exist "%SSH_KEY%" goto missing_key
where ssh.exe >nul 2>&1
if errorlevel 1 goto missing_ssh
where scp.exe >nul 2>&1
if errorlevel 1 goto missing_scp

powershell.exe -NoProfile -Command "$info = @{ filename = 'app-release.apk'; releasedAt = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'); sizeBytes = (Get-Item -LiteralPath $env:APK_FILE).Length }; [IO.File]::WriteAllText($env:MANIFEST_FILE, ($info | ConvertTo-Json), [Text.UTF8Encoding]::new($false))"
if errorlevel 1 goto manifest_failed

echo Connecting to the VM and uploading the new APK...
ssh.exe -i "%SSH_KEY%" %VM% "mkdir -p ~/apk"
if errorlevel 1 goto connection_failed

scp.exe -i "%SSH_KEY%" "%APK_FILE%" "%VM%:~/apk/.app-release.apk.uploading"
if errorlevel 1 goto upload_failed
scp.exe -i "%SSH_KEY%" "%MANIFEST_FILE%" "%VM%:~/apk/.release-info.json.uploading"
if errorlevel 1 goto upload_failed

echo Replacing the old APK and release metadata...
ssh.exe -i "%SSH_KEY%" %VM% "mv ~/apk/.app-release.apk.uploading ~/apk/app-release.apk && find ~/apk -maxdepth 1 -type f -name '*.apk' ! -name 'app-release.apk' -delete && mv ~/apk/.release-info.json.uploading ~/apk/release-info.json"
if errorlevel 1 goto finalize_failed

del "%MANIFEST_FILE%" >nul 2>&1
echo.
echo Upload complete. The APK and release-info.json are in ~/apk on the VM.
goto finished

:missing_apk
echo ERROR: Release APK not found: %APK_FILE%
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
if exist "%MANIFEST_FILE%" del "%MANIFEST_FILE%" >nul 2>&1
echo.

:finished
echo.
pause
endlocal
