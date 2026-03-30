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

set "PAZ=!GAMEDIR!\0010\0.paz"
if not exist "!PAZ!" (
    echo.
    echo   ERROR: Game archive not found.
    echo.
    echo   This mod folder must be placed inside the Crimson Desert
    echo   game directory, for example:
    echo.
    echo     Crimson Desert\CrimsonCamera\start.bat
    echo.
    echo   The "0010" folder should be next to this mod folder.
    echo.
    pause
    exit /b
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
    exit /b
)

:: ============================================================
:: MENU
:: ============================================================

:: Initialize defaults
set "STYLE=shoulder"
set "HEIGHT=medium"
set "DISTANCE=default"
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
echo  ---- Step 1 of 6: Camera Style ----
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
echo          CrimsonCamera - Step 2 of 6
echo  ============================================================
echo   Style: !STYLE!
echo.
echo  ---- Step 2 of 6: Camera Height ----
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

:: ── Step 3: Camera Distance ──────────────────────────────
:STEP3
cls
echo.
echo  ============================================================
echo          CrimsonCamera - Step 3 of 6
echo  ============================================================
echo   Style: !STYLE!  /  Height: !HEIGHT!
echo.
echo  ---- Step 3 of 6: Camera Distance ----
echo.
echo   How far should the camera be from the character?
echo.
echo   [1] Very Close  - 60%% of default distance
echo   [2] Close       - 80%% of default distance
echo   [3] Default     - No change (recommended)
echo   [4] Far         - 125%% of default distance
echo   [5] Very Far    - 150%% of default distance
echo.
set /p "S3D=  Choose [1, 2, 3, 4, 5]: "

if "!S3D!"=="1" set "DISTANCE=vclose"& goto STEP4
if "!S3D!"=="2" set "DISTANCE=close"& goto STEP4
if "!S3D!"=="3" set "DISTANCE=default"& goto STEP4
if "!S3D!"=="4" set "DISTANCE=far"& goto STEP4
if "!S3D!"=="5" set "DISTANCE=vfar"& goto STEP4
echo   Invalid choice.
timeout /t 2 >nul
goto STEP3

:: ── Step 4: Field of View ─────────────────────────────────
:STEP4
cls
echo.
echo  ============================================================
echo          CrimsonCamera - Step 4 of 6
echo  ============================================================
echo   Style: !STYLE!  /  Height: !HEIGHT!  /  Distance: !DISTANCE!
echo.
echo  ---- Step 4 of 6: Field of View ----
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
    goto STEP5
)
if !FOVCHECK! LSS 50 (
    echo   Value must be 0, or between 50 and 100.
    timeout /t 2 >nul
    goto STEP4
)
if !FOVCHECK! GTR 100 (
    echo   Value must be 0, or between 50 and 100.
    timeout /t 2 >nul
    goto STEP4
)
set "FOV=!FOVCHECK!"
goto STEP5

:: ── Step 5: Steadycam ─────────────────────────────────────
:STEP5
cls
echo.
echo  ============================================================
echo          CrimsonCamera - Step 5 of 6
echo  ============================================================
echo   Style: !STYLE!  /  Height: !HEIGHT!  /  FoV: !FOV!
echo.
echo  ---- Step 5 of 6: Steadycam ----
echo.
echo   In vanilla, the camera bobs and sways when you run,
echo   sprint, or ride. Steadycam smooths this out.
echo.
echo   [Y] Yes - Smooth camera movement (recommended)
echo   [N] No  - Keep vanilla camera sway
echo.
set /p "S4=  Enable Steadycam? [Y/N]: "

if /i "!S4!"=="Y" set "STEADYCAM=--steadycam"& goto STEP6
if /i "!S4!"=="N" set "STEADYCAM="& goto STEP6
echo   Invalid choice.
timeout /t 2 >nul
goto STEP5

:: ── Step 6: Combat Camera ─────────────────────────────────
:STEP6
cls
echo.
echo  ============================================================
echo          CrimsonCamera - Step 6 of 6
echo  ============================================================
echo   Style: !STYLE!  /  Height: !HEIGHT!  /  FoV: !FOV!
if defined STEADYCAM (echo   Steadycam: ON) else (echo   Steadycam: OFF)
echo.
echo  ---- Step 6 of 6: Combat Camera ----
echo.
echo   Zoom out more during combat?
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
goto STEP6

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
echo   Distance:  !DISTANCE!
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

set "PYARGS=--style !STYLE! --height !HEIGHT! --distance !DISTANCE! --fov !FOV! --combat !COMBAT!"
if defined STEADYCAM set "PYARGS=!PYARGS! --steadycam"

echo   Running: python lib\camera_mod.py
echo   Game: !GAMEDIR!
echo   Args: !PYARGS!
echo.

!PYTHON! "%SD%lib\camera_mod.py" "!GAMEDIR!" !PYARGS!

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
echo   To change settings: run start.bat again
echo   To restore vanilla: choose [R] on the first screen
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
!PYTHON! "%SD%lib\camera_mod.py" "!GAMEDIR!" --restore

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
