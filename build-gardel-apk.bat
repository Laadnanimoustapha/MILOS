@echo off
setlocal
set ANDROID_HOME=C:\Users\test\AppData\Local\Android\Sdk
set ANDROID_SDK_ROOT=C:\Users\test\AppData\Local\Android\Sdk

where gradle >nul 2>nul
if not errorlevel 1 (
    echo Using system Gradle...
    gradle assembleDebug
    exit /b %errorlevel%
)

where java >nul 2>nul
if not errorlevel 1 (
    echo Gradle is not installed or not on PATH.
    echo Install Gradle 8.x or add it to PATH before building.
    echo Then run: gradle assembleDebug
    exit /b 1
)

echo Java not found on PATH.
exit /b 1
