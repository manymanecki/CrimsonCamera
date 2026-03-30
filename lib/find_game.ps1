# find_game.ps1 — Auto-detect Crimson Desert install across Steam, Epic, Xbox
# Outputs the game directory path to stdout if found, nothing otherwise.

$ErrorActionPreference = 'SilentlyContinue'

# --- Steam ---
$steamDir = $null
foreach ($key in 'HKLM:\SOFTWARE\Valve\Steam',
                 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
                 'HKCU:\SOFTWARE\Valve\Steam') {
    $val = (Get-ItemProperty $key).InstallPath
    if ($val) { $steamDir = $val; break }
}

if ($steamDir) {
    # Default library
    $try = Join-Path $steamDir 'steamapps\common\Crimson Desert'
    if (Test-Path (Join-Path $try '0010\0.paz')) { Write-Output $try; exit 0 }

    # Additional Steam libraries from libraryfolders.vdf
    $vdf = Join-Path $steamDir 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        foreach ($line in Get-Content $vdf) {
            if ($line -match '"path"\s+"(.+?)"') {
                $libPath = $matches[1] -replace '\\\\', '\'
                $try = Join-Path $libPath 'steamapps\common\Crimson Desert'
                if (Test-Path (Join-Path $try '0010\0.paz')) { Write-Output $try; exit 0 }
            }
        }
    }
}

# --- Epic Games Store ---
$manifests = "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests"
if (Test-Path $manifests) {
    foreach ($f in Get-ChildItem $manifests -Filter '*.item') {
        try {
            $json = Get-Content $f.FullName -Raw | ConvertFrom-Json
            if ($json.DisplayName -like '*Crimson Desert*' -or
                $json.InstallLocation -like '*Crimson Desert*') {
                $try = $json.InstallLocation
                if (Test-Path (Join-Path $try '0010\0.paz')) { Write-Output $try; exit 0 }
            }
        } catch {}
    }
}

# Also check LauncherInstalled.dat
$launcherDat = "$env:ProgramData\Epic\UnrealEngineLauncher\LauncherInstalled.dat"
if (Test-Path $launcherDat) {
    try {
        $json = Get-Content $launcherDat -Raw | ConvertFrom-Json
        foreach ($entry in $json.InstallationList) {
            if ($entry.InstallLocation -like '*Crimson Desert*') {
                $try = $entry.InstallLocation
                if (Test-Path (Join-Path $try '0010\0.paz')) { Write-Output $try; exit 0 }
            }
        }
    } catch {}
}

# --- Xbox / Microsoft Store / Game Pass ---
Get-AppxPackage | Where-Object {
    $_.Name -like '*CrimsonDesert*' -or
    $_.Name -like '*PearlAbyss*' -or
    $_.Name -like '*Crimson*Desert*'
} | ForEach-Object {
    $loc = $_.InstallLocation
    # Resolve junction points to real path
    $item = Get-Item $loc -Force
    if ($item.LinkType -eq 'Junction' -and $item.Target) { $loc = $item.Target }
    if (Test-Path (Join-Path $loc '0010\0.paz')) { Write-Output $loc; exit 0 }
    # Xbox games sometimes nest the content folder
    Get-ChildItem $loc -Directory | ForEach-Object {
        if (Test-Path (Join-Path $_.FullName '0010\0.paz')) { Write-Output $_.FullName; exit 0 }
    }
}

# --- Fallback: scan XboxGames folders on all drives ---
foreach ($drive in [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady -and $_.DriveType -eq 'Fixed' }) {
    $root = $drive.RootDirectory.FullName
    foreach ($sub in 'XboxGames\Crimson Desert\Content',
                     'XboxGames\Crimson Desert',
                     'WindowsApps\Crimson Desert') {
        $try = Join-Path $root $sub
        if (Test-Path (Join-Path $try '0010\0.paz')) { Write-Output $try; exit 0 }
    }
}

# Nothing found
exit 1
