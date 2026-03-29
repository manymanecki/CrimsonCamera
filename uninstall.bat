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
set "PYTHON=%SD%python\python.exe"
if not exist "%PYTHON%" (
    echo.
    echo   ERROR: Embedded Python not found at:
    echo   %PYTHON%
    echo.
    echo   The python\ folder must be present alongside uninstall.bat.
    echo.
    pause
    exit /b
)

:: ============================================================
:: GAME DETECTION
:: ============================================================
set "GAMEDIR="

:: Method 1: Relative to script
for %%I in ("%SD%..") do set "UP=%%~fI"
if exist "%UP%\bin64\CrimsonDesert.exe" set "GAMEDIR=%UP%"

:: Method 2: Steam registry
if "!GAMEDIR!"=="" (
    for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul') do (
        set "STEAMPATH=%%B"
        set "STEAMPATH=!STEAMPATH:/=\!"
        if exist "!STEAMPATH!\steamapps\common\Crimson Desert\bin64\CrimsonDesert.exe" (
            set "GAMEDIR=!STEAMPATH!\steamapps\common\Crimson Desert"
        )
        if "!GAMEDIR!"=="" if exist "!STEAMPATH!\steamapps\libraryfolders.vdf" (
            for /f "tokens=2 delims=	 " %%P in ('findstr /C:"\"path\"" "!STEAMPATH!\steamapps\libraryfolders.vdf" 2^>nul') do (
                set "LPATH=%%~P"
                set "LPATH=!LPATH:\\=\!"
                if exist "!LPATH!\steamapps\common\Crimson Desert\bin64\CrimsonDesert.exe" (
                    if "!GAMEDIR!"=="" set "GAMEDIR=!LPATH!\steamapps\common\Crimson Desert"
                )
            )
        )
    )
)

:: Method 3: Epic Games
if "!GAMEDIR!"=="" (
    for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\WOW6432Node\Epic Games\EpicGamesLauncher" /v AppDataPath 2^>nul') do (
        set "EPICDATA=%%B"
        if exist "!EPICDATA!\Manifests" (
            for /f "delims=" %%M in ('findstr /s /m /C:"Crimson Desert" "!EPICDATA!\Manifests\*.item" 2^>nul') do (
                for /f "tokens=2 delims=:, " %%V in ('findstr /C:"InstallLocation" "%%M" 2^>nul') do (
                    set "EPATH=%%~V"
                    set "EPATH=!EPATH:\\=\!"
                    set "EPATH=!EPATH:"=!"
                    if exist "!EPATH!\bin64\CrimsonDesert.exe" (
                        if "!GAMEDIR!"=="" set "GAMEDIR=!EPATH!"
                    )
                )
            )
        )
    )
)

:: Method 4: Xbox / Game Pass
if "!GAMEDIR!"=="" (
    for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
        for %%P in (
            "%%D:\XboxGames\Crimson Desert\Content"
            "%%D:\XboxGames\Crimson Desert"
            "%%D:\Xbox Games\Crimson Desert\Content"
            "%%D:\Xbox Games\Crimson Desert"
        ) do (
            if exist %%P\bin64\CrimsonDesert.exe (
                if "!GAMEDIR!"=="" set "GAMEDIR=%%~P"
            )
        )
    )
)

:: Method 5: Brute force
if "!GAMEDIR!"=="" (
    for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
        for %%P in (
            "%%D:\SteamLibrary\steamapps\common\Crimson Desert"
            "%%D:\Steam\steamapps\common\Crimson Desert"
            "%%D:\Games\Steam\steamapps\common\Crimson Desert"
            "%%D:\Games\Crimson Desert"
            "%%D:\Games\Epic Games\Crimson Desert"
            "%%D:\Program Files (x86)\Steam\steamapps\common\Crimson Desert"
            "%%D:\Program Files\Steam\steamapps\common\Crimson Desert"
            "%%D:\Program Files\Epic Games\Crimson Desert"
            "%%D:\Epic Games\Crimson Desert"
        ) do (
            if exist %%P\bin64\CrimsonDesert.exe (
                if "!GAMEDIR!"=="" set "GAMEDIR=%%~P"
            )
        )
    )
)

:: Manual path
if "!GAMEDIR!"=="" (
    echo.
    echo   Could not find Crimson Desert automatically.
    echo.
    set /p "GAMEDIR=  Enter game folder path: "
)
if "!GAMEDIR!"=="" (
    echo.
    echo   No path entered. Cannot continue.
    pause
    goto :EOF
)
set "GAMEDIR=!GAMEDIR:"=!"
if not exist "!GAMEDIR!\bin64\CrimsonDesert.exe" (
    echo.
    echo   ERROR: CrimsonDesert.exe not found in: !GAMEDIR!\bin64\
    echo.
    echo   If a game update already restored the original camera,
    echo   no action is needed.
    echo.
    echo   To be safe: Steam ^> Verify integrity of game files
    echo.
    pause
    goto :EOF
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

"%PYTHON%" "%SD%lib\camera_mod.py" "!GAMEDIR!" --restore

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
