@echo off
SETLOCAL EnableDelayedExpansion

echo ========================================
echo   ParkEase Manager - Release Builder
echo   v4.3 - Taxi Service Edition
echo ========================================
echo.

:: Check Flutter
where flutter >nul 2>&1
if errorlevel 1 (
    echo ERROR: Flutter not found in PATH
    echo Please install Flutter and add to PATH
    pause
    exit /b 1
)

:: Check Java for Android build
where java >nul 2>&1
if errorlevel 1 (
    echo WARNING: Java not found in PATH
    echo Checking for Android Studio's JDK...

    :: Check common Android Studio JDK locations
    set "JAVA_FOUND=0"
    if exist "C:\Program Files\Android\Android Studio\jbr\bin\java.exe" (
        set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
        set "PATH=%JAVA_HOME%\bin;%PATH%"
        echo Found Java at: %JAVA_HOME%
        set "JAVA_FOUND=1"
        set SKIP_ANDROID=0
    ) else if exist "%LOCALAPPDATA%\Android\Sdk\jbr\bin\java.exe" (
        set "JAVA_HOME=%LOCALAPPDATA%\Android\Sdk\jbr"
        set "PATH=%JAVA_HOME%\bin;%PATH%"
        echo Found Java at: %JAVA_HOME%
        set "JAVA_FOUND=1"
        set SKIP_ANDROID=0
    )

    if "!JAVA_FOUND!"=="0" (
        echo Java not found - Android build will be skipped
        echo.
        choice /C YN /M "Continue with Windows-only build"
        if errorlevel 2 exit /b 1
        set SKIP_ANDROID=1
    )
) else (
    set SKIP_ANDROID=0
)

:: Get current timestamp (simple version)
set BUILD_TIME=%date:~-4%-%date:~3,2%-%date:~0,2%_%time:~0,2%-%time:~3,2%
set BUILD_TIME=%BUILD_TIME: =0%

echo Build Time: %BUILD_TIME%
echo.
echo ========================================
echo [STEP 1/6] Cleaning previous builds...
echo ========================================
call flutter clean
if errorlevel 1 (
    echo ERROR: Flutter clean failed
    pause
    exit /b 1
)
echo + Clean complete
echo.

echo ========================================
echo [STEP 2/6] Getting dependencies...
echo ========================================
call flutter pub get
if errorlevel 1 (
    echo ERROR: Failed to get dependencies
    pause
    exit /b 1
)
echo + Dependencies installed
echo.

if %SKIP_ANDROID%==0 (
    echo ========================================
    echo [STEP 3/6] Building Android APK...
    echo ========================================
    call flutter build apk --release
    if errorlevel 1 (
        echo ERROR: Android build failed
        echo.
        choice /C YN /M "Continue with Windows-only build"
        if errorlevel 2 (
            pause
            exit /b 1
        )
        set ANDROID_FAILED=1
    ) else (
        echo + Android APK built successfully
        set ANDROID_FAILED=0
    )
    echo.
) else (
    echo ========================================
    echo [STEP 3/6] Skipping Android build...
    echo ========================================
    echo Android build skipped - Java not found
    set ANDROID_FAILED=1
    echo.
)

echo ========================================
echo [STEP 4/6] Building Windows Release...
echo ========================================
call flutter build windows --release
if errorlevel 1 (
    echo ERROR: Windows build failed
    pause
    exit /b 1
)
echo + Windows release built successfully
echo.

echo ========================================
echo [STEP 5/6] Creating release packages...
echo ========================================

:: Create releases directory
if not exist "releases" mkdir releases
if not exist "releases\%BUILD_TIME%" mkdir "releases\%BUILD_TIME%"

:: Copy Android APK if build succeeded
if %ANDROID_FAILED%==0 (
    echo Packaging Android APK...
    if exist "build\app\outputs\flutter-apk\app-release.apk" (
        copy "build\app\outputs\flutter-apk\app-release.apk" "releases\%BUILD_TIME%\ParkEase-v4.3-Android.apk" >nul
        echo + Android APK copied
    ) else (
        echo ! Android APK not found
    )
)

:: Copy Windows release folder
echo Packaging Windows release...
if exist "build\windows\x64\runner\Release" (
    xcopy "build\windows\x64\runner\Release" "releases\%BUILD_TIME%\ParkEase-v4.3-Windows" /E /I /Y /Q >nul
    echo + Windows release copied
) else (
    echo ! Windows release not found
)

:: Create version info file
echo Creating version info...
(
echo ParkEase Manager - Release Build
echo ================================
echo Version: 4.3
echo Build Date: %BUILD_TIME%
echo.
echo Features in this release:
echo - Parking Management ^(Entry/Exit/List/Reports^)
echo - Taxi Service ^(Complete booking system^)
echo - USB Printer Support ^(Android/Desktop^)
echo - Bluetooth Printer Support
echo - Receipt Customization
echo - Multi-platform ^(Android + Windows^)
echo.
echo File Locations:
if %ANDROID_FAILED%==0 (
    echo - Android APK: ParkEase-v4.3-Android.apk
) else (
    echo - Android APK: NOT BUILT ^(Java required^)
)
echo - Windows: ParkEase-v4.3-Windows\ folder
echo.
echo Installation:
echo - Android: Install APK on device
echo - Windows: Run parkease_manager.exe from the Windows folder
echo.
) > "releases\%BUILD_TIME%\BUILD_INFO.txt"

echo + Version info created
echo.

echo ========================================
echo [STEP 6/6] Build Summary
echo ========================================
echo.
if %ANDROID_FAILED%==0 (
    echo + Android APK: SUCCESS
) else (
    echo ! Android APK: SKIPPED or FAILED
)
echo + Windows EXE: SUCCESS
echo.
echo Release Location:
echo   releases\%BUILD_TIME%\
echo.
echo Files created:
dir "releases\%BUILD_TIME%" /B 2>nul
echo.

:: Calculate APK size if exists
if %ANDROID_FAILED%==0 (
    if exist "releases\%BUILD_TIME%\ParkEase-v4.3-Android.apk" (
        for %%A in ("releases\%BUILD_TIME%\ParkEase-v4.3-Android.apk") do (
            set /a SIZE_MB=%%~zA/1024/1024
            echo Android APK Size: !SIZE_MB! MB
        )
    )
)
echo.

echo ========================================
if %ANDROID_FAILED%==0 (
    echo   BUILD COMPLETE - READY TO DEPLOY
) else (
    echo   PARTIAL BUILD - Windows Only
    echo.
    echo To build Android APK:
    echo 1. Install Java JDK 17 or higher
    echo 2. Add Java to PATH
    echo 3. Run this script again
)
echo ========================================
echo.
echo Next steps:
if %ANDROID_FAILED%==0 (
    echo 1. Test Android APK on device
)
echo 2. Test Windows executable
echo 3. Distribute from: releases\%BUILD_TIME%\
echo.
pause

:: Optional: Open release folder
explorer "releases\%BUILD_TIME%"

ENDLOCAL
