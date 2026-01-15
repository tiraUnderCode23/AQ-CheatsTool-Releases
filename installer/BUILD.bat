@echo off
:: ============================================================================
:: AQ CheatsTool - Quick Build Script
:: ============================================================================

title AQ CheatsTool Installer Builder
color 0B

echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║                                                              ║
echo  ║              AQ CheatsTool - Installer Builder               ║
echo  ║                       Version 3.2.0                          ║
echo  ║                                                              ║
echo  ╚══════════════════════════════════════════════════════════════╝
echo.

:: Check if running as admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Not running as Administrator. Some features may fail.
    echo.
)

:: Navigate to installer directory
cd /d "%~dp0"

echo [1/3] Creating installer images...
powershell -ExecutionPolicy Bypass -File "create_images.ps1"

echo.
echo [2/3] Building installer...
powershell -ExecutionPolicy Bypass -File "build_installer.ps1"

echo.
echo [3/3] Build process completed!
echo.
echo Press any key to open the output folder...
pause >nul

explorer.exe output
