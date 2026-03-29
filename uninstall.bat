@echo off
setlocal EnableDelayedExpansion
title CrimsonCamera - Uninstall / Restore
color 0F

set "SD=%~dp0"

:: Verify we're not running from inside a zip
if not exist "%SD%lib\camera_mod.py" (
    echo.
    echo   ERROR: Cannot find mod files.
    echo   Right-click the zip and choose "Extract All" first.
    echo   Do NOT run from inside the zip file.
    echo.
    pause
    exit /b
)

:: Python check
set "PYTHON="

:: Try Python Launcher first (py -3), then python on PATH
where py >nul 2>nul
if not errorlevel 1 (
    py -3 --version >nul 2>nul
    if not errorlevel 1 set "PYTHON=py -3"
)
if "!PYTHON!"=="" (
    where python >nul 2>nul
    if not errorlevel 1 (
        python --version >nul 2>nul
        if not errorlevel 1 set "PYTHON=python"
    )
)
if "!PYTHON!"=="" (
    echo.
    echo   ERROR: Python 3 is not installed or not in PATH.
    echo.
    echo   Please install Python 3.10 or newer from:
    echo   https://www.python.org/downloads/
    echo.
    echo   IMPORTANT: Check "Add python.exe to PATH" during install.
    echo.
    pause
    exit /b
)

:: Check required packages
!PYTHON! -c "import cryptography, lz4" >nul 2>nul
if errorlevel 1 (
    echo.
    echo   Installing required Python packages...
    echo.
    !PYTHON! -m pip install cryptography lz4
    if errorlevel 1 (
        echo.
        echo   ERROR: Failed to install required packages.
        echo   Try running manually: pip install cryptography lz4
        echo.
        pause
        exit /b
    )
)

:: ============================================================
:: GAME DIRECTORY (mod folder must be inside the game folder)
:: ============================================================
for %%I in ("%SD%..") do set "GAMEDIR=%%~fI"

if not exist "!GAMEDIR!\0010\0.paz" (
    echo.
    echo   ERROR: Game archive not found.
    echo.
    echo   This mod folder must be placed inside the Crimson Desert
    echo   game directory, for example:
    echo.
    echo     Crimson Desert\CrimsonCamera\uninstall.bat
    echo.
    echo   The "0010" folder should be next to this mod folder.
    echo.
    pause
    exit /b
)

:: ============================================================
:: RESTORE
:: ============================================================
echo.
echo  ============================================================
echo          CrimsonCamera - Uninstall / Restore
echo  ============================================================
echo.
echo   Game: !GAMEDIR!
echo.
echo   This will restore the original vanilla camera.
echo.
echo   NOTE: If a game update just dropped, the camera may
echo   already be restored automatically. In that case, this
echo   uninstaller is not needed.
echo.
set /p "CONFIRM=  Continue? [Y/N]: "
if /i not "!CONFIRM!"=="Y" goto :EOF

echo.
echo   Restoring original camera...
echo.

!PYTHON! "%SD%lib\camera_mod.py" "!GAMEDIR!" --restore

if errorlevel 1 (
    echo.
    echo   Restore failed or no backup found.
    echo.
    echo   This usually means:
    echo   - No backup exists (camera may already be vanilla)
    echo   - A game update changed the file layout
    echo   - The game is currently running
    echo.
    echo   To be safe: Steam ^> Verify integrity of game files
    echo.
    pause
    goto :EOF
)

echo.
echo  ============================================================
echo   Original camera restored successfully!
echo  ============================================================
echo.
pause
