@echo off
SETLOCAL EnableDelayedExpansion

:: Quick build - Android only (faster)
echo ========================================
echo   Quick Build - Android APK Only
echo ========================================
echo.

:: Check if Java/Android SDK is available
where java >nul 2>&1
if errorlevel 1 (
    echo Checking for Android Studio's JDK...
    if exist "C:\Program Files\Android\Android Studio\jbr\bin\java.exe" (
        set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
        set "PATH=%JAVA_HOME%\bin;%PATH%"
        echo ✓ Found Java at: !JAVA_HOME!
    ) else if exist "%LOCALAPPDATA%\Android\Sdk\jbr\bin\java.exe" (
        set "JAVA_HOME=%LOCALAPPDATA%\Android\Sdk\jbr"
        set "PATH=%JAVA_HOME%\bin;%PATH%"
        echo ✓ Found Java at: !JAVA_HOME!
    ) else (
        echo ❌ ERROR: Java not found - Android build will fail
        pause
        exit /b 1
    )
)

echo.
echo [1/2] Getting dependencies...
call flutter pub get
if errorlevel 1 (
    echo ❌ Pub get failed
    pause
    exit /b 1
)
echo ✓ Dependencies ready

echo.
echo [2/2] Building Android APK (this may take 2-3 minutes)...
call flutter build apk --release

if errorlevel 1 (
    echo.
    echo ❌ Build FAILED
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✓ BUILD SUCCESSFUL
echo ========================================
echo.
echo APK Location:
echo   build\app\outputs\flutter-apk\app-release.apk
echo.

:: Copy to easy location
copy "build\app\outputs\flutter-apk\app-release.apk" "ParkEase-Android.apk"
echo Copied to: ParkEase-Android.apk
echo.
pause
