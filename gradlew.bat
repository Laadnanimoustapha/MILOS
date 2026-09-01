@echo off
set DIR=%~dp0
if "%ANDROID_HOME%"=="" if "%ANDROID_SDK_ROOT%"=="" set ANDROID_SDK_ROOT=C:\Users\test\AppData\Local\Android\Sdk
java -classpath "%DIR%gradle-wrapper\lib\*;%DIR%gradle-wrapper\*" org.gradle.wrapper.GradleWrapperMain %*
