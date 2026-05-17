@echo off
:: Windows build only
echo ========================================
echo   Windows Build Only
echo ========================================
echo.

flutter clean
flutter pub get
flutter build windows --release

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
echo Windows Release Location:
echo   build\windows\x64\runner\Release\parkease_manager.exe
echo.
pause

:: Open folder
explorer "build\windows\x64\runner\Release"
