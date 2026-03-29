@echo off
setlocal EnableDelayedExpansion
title CrimsonCamera - Camera Mod for Crimson Desert
color 0F
mode con cols=72 lines=50

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

:: ============================================================
:: PYTHON CHECK
:: ============================================================
set "PYTHON=%SD%python\python.exe"
if not exist "%PYTHON%" (
    echo.
    echo   ERROR: Embedded Python not found at:
    echo   %PYTHON%
    echo.
    echo   The python\ folder must be present alongside install.bat.
    echo.
    pause
    exit /b
)

:: ============================================================
:: GAME DETECTION - Steam, Epic, Xbox/Game Pass, manual
:: ============================================================
set "GAMEDIR="
set "PLATFORM=Unknown"

:: Method 1: Check relative to script (mod inside game folder)
for %%I in ("%SD%..") do set "UP=%%~fI"
if exist "%UP%\bin64\CrimsonDesert.exe" (
    set "GAMEDIR=%UP%"
    set "PLATFORM=Local"
)

:: Method 2: Steam - Registry + library folders
if "!GAMEDIR!"=="" (
    for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul') do (
        set "STEAMPATH=%%B"
        set "STEAMPATH=!STEAMPATH:/=\!"
        if exist "!STEAMPATH!\steamapps\common\Crimson Desert\bin64\CrimsonDesert.exe" (
            set "GAMEDIR=!STEAMPATH!\steamapps\common\Crimson Desert"
            set "PLATFORM=Steam"
        )
        if "!GAMEDIR!"=="" if exist "!STEAMPATH!\steamapps\libraryfolders.vdf" (
            for /f "tokens=2 delims=	 " %%P in ('findstr /C:"\"path\"" "!STEAMPATH!\steamapps\libraryfolders.vdf" 2^>nul') do (
                set "LPATH=%%~P"
                set "LPATH=!LPATH:\\=\!"
                if exist "!LPATH!\steamapps\common\Crimson Desert\bin64\CrimsonDesert.exe" (
                    if "!GAMEDIR!"=="" (
                        set "GAMEDIR=!LPATH!\steamapps\common\Crimson Desert"
                        set "PLATFORM=Steam"
                    )
                )
            )
        )
    )
)

:: Method 3: Epic Games - Registry + manifests
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
                        if "!GAMEDIR!"=="" (
                            set "GAMEDIR=!EPATH!"
                            set "PLATFORM=Epic"
                        )
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
                if "!GAMEDIR!"=="" (
                    set "GAMEDIR=%%~P"
                    set "PLATFORM=Xbox/GamePass"
                )
            )
        )
    )
)

:: Method 5: Brute force common paths
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

:: Manual path entry
:ASKPATH
if "!GAMEDIR!"=="" (
    cls
    echo.
    echo  ============================================================
    echo          CrimsonCamera - Camera Mod for Crimson Desert
    echo  ============================================================
    echo.
    echo   Could not find Crimson Desert automatically.
    echo.
    echo   Please enter the full path to your Crimson Desert folder.
    echo   This is the folder that contains the "bin64" subfolder.
    echo.
    echo   Example: D:\SteamLibrary\steamapps\common\Crimson Desert
    echo.
    set /p "GAMEDIR=  Path: "
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
    echo   Please check the path and try again.
    echo.
    set "GAMEDIR="
    pause
    goto ASKPATH
)

set "PAZ=!GAMEDIR!\0010\0.paz"
if not exist "!PAZ!" (
    echo.
    echo   ERROR: Game archive not found: !PAZ!
    echo   Your game installation may be incomplete.
    pause
    goto :EOF
)

:: Write permission check
powershell -NoProfile -Command ^
    "try{$fs=[IO.File]::Open('!PAZ!','Open','ReadWrite','Read');$fs.Close();exit 0}catch{exit 1}" 2>nul
if errorlevel 1 (
    echo.
    echo   ERROR: Cannot write to game files.
    echo.
    echo   If you are using Xbox App / Game Pass, the game folder
    echo   may be read-only. Try one of these fixes:
    echo.
    echo   1. Move the game: Xbox App ^> Crimson Desert ^> Manage ^>
    echo      Move to a different drive
    echo   2. Or right-click the game folder ^> Properties ^>
    echo      uncheck "Read-only" ^> Apply to all subfolders
    echo.
    pause
    goto :EOF
)

:: ============================================================
:: MENU
:: ============================================================

:: Initialize defaults
set "STYLE=shoulder"
set "HEIGHT=medium"
set "FOV=0"
set "STEADYCAM="
set "COMBAT=default"

:: ── Step 1: Camera Style ──────────────────────────────────
:STEP1
cls
echo.
echo  ============================================================
echo          CrimsonCamera - Camera Mod for Crimson Desert
echo  ============================================================
echo   Game: !GAMEDIR!
echo.
echo  ---- Step 1 of 5: Camera Style ----
echo.
echo   [1] Shoulder Camera (default-like)
echo       Over-the-shoulder, vanilla positioning but lowered
echo.
echo   [2] Centered Camera
echo       Character centered on screen instead of offset
echo.
echo   [R] Restore Original   [Q] Quit
echo.
set /p "S1=  Choose [1, 2, R, Q]: "

if /i "!S1!"=="Q" goto :EOF
if /i "!S1!"=="R" goto RESTORE
if "!S1!"=="1" set "STYLE=shoulder"& goto STEP2
if "!S1!"=="2" set "STYLE=centered"& goto STEP2
echo   Invalid choice.
timeout /t 2 >nul
goto STEP1

:: ── Step 2: Camera Height ─────────────────────────────────
:STEP2
cls
echo.
echo  ============================================================
echo          CrimsonCamera - Step 2 of 5
echo  ============================================================
echo   Style: !STYLE!
echo.
echo  ---- Step 2 of 5: Camera Height ----
echo.
echo   How much should the camera be lowered?
echo.
echo   [1] Slightly Low
echo       Subtle lowering, close to vanilla
echo.
echo   [2] Medium Low  (Recommended)
echo       Noticeable difference, balanced feel
echo.
echo   [3] Very Low
echo       Hip-level camera, full body visible
echo.
set /p "S2=  Choose [1, 2, 3]: "

if "!S2!"=="1" set "HEIGHT=slight"& goto STEP3
if "!S2!"=="2" set "HEIGHT=medium"& goto STEP3
if "!S2!"=="3" set "HEIGHT=vlow"& goto STEP3
echo   Invalid choice.
timeout /t 2 >nul
goto STEP2

:: ── Step 3: Field of View ─────────────────────────────────
:STEP3
cls
echo.
echo  ============================================================
echo          CrimsonCamera - Step 3 of 5
echo  ============================================================
echo   Style: !STYLE!  /  Height: !HEIGHT!
echo.
echo  ---- Step 3 of 5: Field of View ----
echo.
echo   The vanilla game uses about 40 degrees (feels narrow).
echo   Enter a value between 50 and 100, or 0 for no change.
echo.
echo   Recommended: 60
echo.
echo   50 = Minimal wider view
echo   60 = Noticeably wider, no distortion
echo   70 = Very wide, great for exploration
echo   80 = Ultra wide, slight fisheye at edges
echo.
set /p "S3=  FoV value [0, or 50-100]: "

if "!S3!"=="" set "S3=0"
set /a "FOVCHECK=!S3!" 2>nul
if "!S3!"=="0" (
    set "FOV=0"
    goto STEP4
)
if !FOVCHECK! LSS 50 (
    echo   Value must be 0, or between 50 and 100.
    timeout /t 2 >nul
    goto STEP3
)
if !FOVCHECK! GTR 100 (
    echo   Value must be 0, or between 50 and 100.
    timeout /t 2 >nul
    goto STEP3
)
set "FOV=!FOVCHECK!"
goto STEP4

:: ── Step 4: Steadycam ─────────────────────────────────────
:STEP4
cls
echo.
echo  ============================================================
echo          CrimsonCamera - Step 4 of 5
echo  ============================================================
echo   Style: !STYLE!  /  Height: !HEIGHT!  /  FoV: !FOV!
echo.
echo  ---- Step 4 of 5: Steadycam ----
echo.
echo   In vanilla, the camera bobs and sways when you run,
echo   sprint, or ride. Steadycam smooths this out.
echo.
echo   [Y] Yes - Smooth camera movement (recommended)
echo   [N] No  - Keep vanilla camera sway
echo.
set /p "S4=  Enable Steadycam? [Y/N]: "

if /i "!S4!"=="Y" set "STEADYCAM=--steadycam"& goto STEP5
if /i "!S4!"=="N" set "STEADYCAM="& goto STEP5
echo   Invalid choice.
timeout /t 2 >nul
goto STEP4

:: ── Step 5: Combat Camera ─────────────────────────────────
:STEP5
cls
echo.
echo  ============================================================
echo          CrimsonCamera - Step 5 of 5
echo  ============================================================
echo   Style: !STYLE!  /  Height: !HEIGHT!  /  FoV: !FOV!
if defined STEADYCAM (echo   Steadycam: ON) else (echo   Steadycam: OFF)
echo.
echo  ---- Step 5 of 5: Combat Camera ----
echo.
echo   Zoom out more during lock-on combat?
echo.
echo   [0] Default - No change to combat camera
echo   [1] Wider   - More room to see enemies
echo   [2] Maximum - Widest possible combat view
echo.
set /p "S5=  Combat zoom [0, 1, 2]: "

if "!S5!"=="0" set "COMBAT=default"& goto CONFIRM
if "!S5!"=="1" set "COMBAT=wide"& goto CONFIRM
if "!S5!"=="2" set "COMBAT=max"& goto CONFIRM
echo   Invalid choice.
timeout /t 2 >nul
goto STEP5

:: ── Confirmation ──────────────────────────────────────────
:CONFIRM
cls
echo.
echo  ============================================================
echo          CrimsonCamera - Confirm Settings
echo  ============================================================
echo.
echo   Game:      !GAMEDIR!
echo.
echo   Style:     !STYLE!
echo   Height:    !HEIGHT!
if "!FOV!"=="0" (echo   FoV:       No change) else (echo   FoV:       !FOV! degrees)
if defined STEADYCAM (echo   Steadycam: ON) else (echo   Steadycam: OFF)
echo   Combat:    !COMBAT!
echo.
echo   [Y] Install   [N] Start over   [Q] Quit
echo.
set /p "OK=  Continue? [Y/N/Q]: "

if /i "!OK!"=="Q" goto :EOF
if /i "!OK!"=="N" goto STEP1
if /i not "!OK!"=="Y" goto CONFIRM

:: ============================================================
:: INSTALL
:: ============================================================
:INSTALL
cls
echo.
echo  ============================================================
echo          CrimsonCamera - Installing...
echo  ============================================================
echo.

set "PYARGS=--style !STYLE! --height !HEIGHT! --fov !FOV! --combat !COMBAT!"
if defined STEADYCAM set "PYARGS=!PYARGS! --steadycam"

echo   Running: python lib\camera_mod.py
echo   Game: !GAMEDIR!
echo   Args: !PYARGS!
echo.

"%PYTHON%" "%SD%lib\camera_mod.py" "!GAMEDIR!" !PYARGS!

if errorlevel 1 (
    echo.
    echo  ============================================================
    echo   ERROR: Installation failed.
    echo  ============================================================
    echo.
    echo   Make sure the game is not running, then try again.
    echo   If the game was recently updated, try restoring first.
    echo.
    pause
    goto STEP1
)

echo.
echo  ============================================================
echo   SUCCESS! Camera mod installed.
echo  ============================================================
echo.
echo   Launch the game to see your new camera!
echo.
echo   To change settings: run install.bat again
echo   To restore vanilla: run uninstall.bat or choose [R]
echo.
pause
goto STEP1

:: ============================================================
:: RESTORE
:: ============================================================
:RESTORE
cls
echo.
echo  ============================================================
echo          CrimsonCamera - Restore Vanilla Camera
echo  ============================================================
echo.
echo   Game: !GAMEDIR!
echo.
echo   This will restore the original vanilla camera.
echo.
set /p "RC=  Continue? [Y/N]: "
if /i not "!RC!"=="Y" goto STEP1

echo.
"%PYTHON%" "%SD%lib\camera_mod.py" "!GAMEDIR!" --restore

if errorlevel 1 (
    echo.
    echo   Restore failed or no backup found.
    echo   Use Steam: Verify integrity of game files
    echo.
    pause
    goto STEP1
)

echo.
echo  ============================================================
echo   Original camera restored successfully!
echo  ============================================================
echo.
pause
goto STEP1
