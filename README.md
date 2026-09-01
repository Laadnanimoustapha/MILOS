# Gardel Mobile APK

This project was initialized as a minimal Android application scaffold for the Gardel mobile APK.

## Structure

- `app/src/main/java/com/gardel/app/MainActivity.kt` — main app activity
- `app/src/main/res/layout/activity_main.xml` — app layout
- `app/build.gradle.kts` — Android app module config
- `build.gradle.kts` — root build config
- `settings.gradle.kts` — project settings

## Build

From a machine with Android SDK and Gradle installed:

```bat
set ANDROID_HOME=C:\Users\test\AppData\Local\Android\Sdk
set ANDROID_SDK_ROOT=C:\Users\test\AppData\Local\Android\Sdk
gradle assembleDebug
```

or run:

```bat
build-gardel-apk.bat
```

The expected APK output is under:

```text
app\build\outputs\apk\debug\
```

## Notes

This environment already contains an Android SDK at `C:\Users\test\AppData\Local\Android\Sdk`, but no working Gradle wrapper or system Gradle was available in PATH during initialization, so the project files were created without a verified APK build in this session.
