@echo off
setlocal enabledelayedexpansion
chcp 65001 > nul
title Muezzin Libya - Master Pro Build System

rem -- ANSI colors: a real ESC byte, not the literal text [92m --
set "green=[92m"
set "yellow=[93m"
set "red=[91m"
set "blue=[94m"
set "cyan=[96m"
set "white=[97m"
set "magenta=[95m"
set "reset=[0m"

rem ============================================================
rem  Arguments (any order, all optional):
rem    bump  / --bump   increment the build number in pubspec.yaml
rem    clean / --clean  cold build: flutter clean first
rem  No argument: incremental build with the current version.
rem  One-shot release:  Build_Master_Pro.bat bump
rem  In every run the version is read from pubspec.yaml and AppVersion
rem  in lib\core\config\app_version.dart is re-synced from it, so the
rem  installed-version constants and pubspec.yaml can never drift apart.
rem
rem  Output names and the desktop folder carry version AND build number
rem  (MuezzinLibya_v3.5.0+51_...), and every older
rem  Desktop\MuezzinLibya_v*_Build folder is deleted so the desktop keeps
rem  exactly one build folder: the newest one.
rem ============================================================
rem  %0 is shifted by the loop below, so remember our own name first.
set "SELF=%~nx0"
set "DO_CLEAN=0"
set "DO_BUMP=0"
:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="clean"   set "DO_CLEAN=1"
if /i "%~1"=="--clean" set "DO_CLEAN=1"
if /i "%~1"=="bump"    set "DO_BUMP=1"
if /i "%~1"=="--bump"  set "DO_BUMP=1"
shift
goto parse_args
:args_done

rem ============================================================
rem  Version is read from pubspec.yaml -- never hardcoded.
rem  A line like   version: 3.4.8+48   gives VER=3.4.8, BUILDNO=48
rem ============================================================
call :read_version
if errorlevel 1 exit /b 1

if "%DO_BUMP%"=="1" (
    call :bump_build
    if errorlevel 1 exit /b 1
    call :read_version
    if errorlevel 1 exit /b 1
)

rem ---- Keep the Dart source in step with pubspec.yaml ----
rem  Doing it here means both bump and a plain build end up consistent,
rem  and the build stops instead of shipping a stale version number.
call :sync_app_version
if errorlevel 1 exit /b 1

echo.
echo %cyan%==================================================================%reset%
echo %cyan% %white%Muezzin Libya - Prayer times and Adhan%reset%
echo %cyan% %yellow%Master Pro APK build system v%VER%+%BUILDNO% - all devices%reset%
echo %cyan%==================================================================%reset%
echo.

rem ---- 1/8 Flutter environment ----
echo %blue%[1/8]%reset% Checking the Flutter environment...
where flutter >nul 2>&1
if errorlevel 1 (
    echo %red%[ERROR] Flutter is not in PATH. Install the Flutter SDK first.%reset%
    pause
    exit /b 1
)
for /f "tokens=*" %%v in ('flutter --version 2^>nul ^| findstr /i "Flutter"') do echo %green%    %%v%reset%
echo %green%[OK] Flutter environment is ready.%reset%
echo.

rem ---- 2/8 Clean is OPTIONAL ----
rem  With no argument the cache is kept: the build is incremental, faster,
rem  and it does not disturb any other work on the same project folder.
rem  For a cold full build:  Build_Master_Pro.bat clean
if "%DO_CLEAN%"=="1" (
    echo %blue%[2/8]%reset% Full clean: flutter clean, build and .dart_tool...
    call flutter clean > nul 2>&1
    if exist "build"      rd /s /q "build"      2>nul
    if exist ".dart_tool" rd /s /q ".dart_tool" 2>nul
    echo %green%[OK] Project cache cleaned.%reset%
) else (
    echo %blue%[2/8]%reset% Skipping clean - incremental build. Cold build: %SELF% clean
)
echo.

rem ---- 3/8 Packages ----
echo %blue%[3/8]%reset% Fetching and updating packages...
call flutter pub get
if errorlevel 1 (
    echo %red%[ERROR] flutter pub get failed.%reset%
    pause
    exit /b 1
)
echo %green%[OK] All packages are ready.%reset%
echo.

rem ---- 4/8 Universal APK, runs on every device ----
echo %blue%[4/8]%reset% Building the %yellow%Universal APK%reset% - runs on all devices...
call flutter build apk --release --obfuscate --split-debug-info=build/debug-info
if errorlevel 1 (
    echo %red%[ERROR] The Universal APK build failed.%reset%
    pause
    exit /b 1
)
echo %green%[OK] Universal APK is ready.%reset%
echo.

rem ---- 5/8 Split APKs, one per architecture ----
echo %blue%[5/8]%reset% Building the %yellow%Split APKs%reset% - arm64, arm32, x64...
call flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info --target-platform android-arm,android-arm64,android-x64
if errorlevel 1 (
    echo %yellow%[WARN] Split APKs reported an error - some may be missing.%reset%
) else (
    echo %green%[OK] Split APKs are ready - 3 files.%reset%
)
echo.

rem ---- 6/8 App Bundle for Google Play ----
echo %blue%[6/8]%reset% Building the %yellow%App Bundle%reset% for Google Play...
call flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
if errorlevel 1 (
    echo %yellow%[WARN] App Bundle build reported an error.%reset%
) else (
    echo %green%[OK] App Bundle is ready.%reset%
)
echo.

rem ---- 7/8 Output folder, names carry version AND build number ----
echo %blue%[7/8]%reset% Preparing the output folder...

set "APK_SRC=build\app\outputs\flutter-apk"
set "AAB_SRC=build\app\outputs\bundle\release"
rem  The name carries version AND build number, so "which copy do I have?"
rem  is always answerable even when only the build number moves
rem  (3.5.0+50 then 3.5.0+51 while the version name stays the same).
set "TAG=v%VER%+%BUILDNO%"
set "DEST=%USERPROFILE%\Desktop\MuezzinLibya_%TAG%_Build"

if not exist "%DEST%" mkdir "%DEST%"

echo.
echo %cyan%  Copying the build files:%reset%

copy /y "%APK_SRC%\app-release.apk" "%DEST%\MuezzinLibya_%TAG%_Universal_AllDevices.apk" >nul 2>&1
if exist "%DEST%\MuezzinLibya_%TAG%_Universal_AllDevices.apk" (
    echo %green%  [OK] Universal APK - all devices%reset%
) else (
    echo %red%  [ERROR] Universal APK was not copied%reset%
)

copy /y "%APK_SRC%\app-arm64-v8a-release.apk" "%DEST%\MuezzinLibya_%TAG%_Modern_64bit_arm64.apk" >nul 2>&1
if exist "%DEST%\MuezzinLibya_%TAG%_Modern_64bit_arm64.apk" (
    echo %green%  [OK] Modern 64-bit arm64 - recent devices%reset%
) else (
    echo %yellow%  [WARN] arm64 APK is missing%reset%
)

copy /y "%APK_SRC%\app-armeabi-v7a-release.apk" "%DEST%\MuezzinLibya_%TAG%_Old_32bit_arm32.apk" >nul 2>&1
if exist "%DEST%\MuezzinLibya_%TAG%_Old_32bit_arm32.apk" (
    echo %green%  [OK] Old 32-bit arm32 - Android 5.0 and newer%reset%
) else (
    echo %yellow%  [WARN] arm32 APK is missing%reset%
)

copy /y "%APK_SRC%\app-x86_64-release.apk" "%DEST%\MuezzinLibya_%TAG%_x86_64_Emulator.apk" >nul 2>&1
if exist "%DEST%\MuezzinLibya_%TAG%_x86_64_Emulator.apk" (
    echo %green%  [OK] x86_64 - emulators%reset%
) else (
    echo %yellow%  [WARN] x86_64 APK is missing%reset%
)

copy /y "%AAB_SRC%\app-release.aab" "%DEST%\MuezzinLibya_%TAG%_GooglePlay.aab" >nul 2>&1
if exist "%DEST%\MuezzinLibya_%TAG%_GooglePlay.aab" (
    echo %green%  [OK] Google Play bundle%reset%
) else (
    echo %yellow%  [WARN] App Bundle is missing%reset%
)

rem ---- Keep exactly one build folder on the desktop: the newest ----
rem  Only folders matching this suite's own name (MuezzinLibya_v*_Build) are
rem  touched, the folder produced by this run is always skipped, and anything
rem  else on the desktop (documents, other folders) is left alone.
echo.
echo %cyan%  Cleaning older build folders from the desktop:%reset%
set "OLDCOUNT=0"
for /d %%d in ("%USERPROFILE%\Desktop\MuezzinLibya_v*_Build") do (
    if /i not "%%~nxd"=="MuezzinLibya_%TAG%_Build" (
        echo %yellow%  [OLD] %%~nxd%reset%
        rd /s /q "%%~fd" 2>nul
        if exist "%%~fd" (
            echo %red%        could not be removed - is it open in Explorer?%reset%
        ) else (
            set /a OLDCOUNT+=1
        )
    )
)
if "%OLDCOUNT%"=="0" (
    echo %green%  [OK] No older build folder to remove - %TAG% is the only one.%reset%
) else (
    echo %green%  [OK] Removed %OLDCOUNT% older build folder^(s^). Only %TAG% is kept.%reset%
)

rem ---- 8/8 Final report ----
echo.
echo %blue%[8/8]%reset% Build finished.
echo.
echo %cyan%==================================================================%reset%
echo %cyan% %green%BUILD COMPLETE - v%VER%+%BUILDNO%%reset%
echo %cyan%==================================================================%reset%
echo   Output folder:
echo   %DEST%
echo.
echo   file names (all carry %TAG%):
echo   MuezzinLibya_%TAG%_Universal_AllDevices.apk  - direct distribution, all devices
echo   MuezzinLibya_%TAG%_Modern_64bit_arm64.apk   - modern devices, smaller size
echo   MuezzinLibya_%TAG%_Old_32bit_arm32.apk      - older devices, Android 5.0 and newer
echo   MuezzinLibya_%TAG%_x86_64_Emulator.apk      - emulators
echo   MuezzinLibya_%TAG%_GooglePlay.aab           - upload to the Play Store
echo %cyan%==================================================================%reset%
echo.

explorer "%DEST%"
echo.
pause
exit /b 0

rem ============================================================
rem  bump_build - increment the build number of the version line
rem  in pubspec.yaml:    version: 3.4.9+49  becomes  version: 3.4.9+50
rem  The rest of the file is left byte-for-byte untouched (UTF-8, no BOM).
rem  PowerShell does the edit because cmd cannot rewrite multi-byte files safely.
rem ============================================================
:bump_build
echo %blue%[BUMP]%reset% Incrementing the build number in pubspec.yaml...
where powershell >nul 2>&1
if errorlevel 1 (
    echo %red%[ERROR] PowerShell was not found, cannot update pubspec.yaml.%reset%
    pause
    exit /b 1
)
rem  The lookahead (?=[ \t]*\r?$) keeps the line ending byte-for-byte intact,
rem  so no blank line is swallowed and no following line is merged into it.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f='pubspec.yaml'; $p=(Resolve-Path $f).Path; $t=[System.IO.File]::ReadAllText($p); $m='(?m)^version:[ \t]*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?(?=[ \t]*\r?$)'; if($t -notmatch $m){ Write-Host '  [ERROR] No version line (version: x.y.z+n) in pubspec.yaml'; exit 1 }; $base=$Matches[1]; $old=1; if($Matches[2]){ $old=[int]$Matches[2] }; $new=$old+1; $t=[regex]::Replace($t,$m,('version: '+$base+'+'+$new)); [System.IO.File]::WriteAllText($p,$t,(New-Object System.Text.UTF8Encoding($false))); Write-Host ('  [OK] version '+$base+'  build '+$old+' is now '+$new+'  (version: '+$base+'+'+$new+')')"
if errorlevel 1 (
    echo %red%[ERROR] Failed to increment the build number - pubspec.yaml is unchanged.%reset%
    pause
    exit /b 1
)
exit /b 0

rem ============================================================
rem  sync_app_version - copy the version of pubspec.yaml into the Dart
rem  source lib\core\config\app_version.dart, so the installed-version
rem  constants used by the update check can never lag behind a release.
rem  Encoding (UTF-8, no BOM) and line endings are left untouched.
rem ============================================================
:sync_app_version
echo %blue%[SYNC]%reset% Syncing AppVersion (Dart) from pubspec.yaml...
where powershell >nul 2>&1
if errorlevel 1 (
    echo %red%[ERROR] PowerShell was not found, cannot sync app_version.dart.%reset%
    pause
    exit /b 1
)
if not exist "lib\core\config\app_version.dart" (
    echo %red%[ERROR] lib\core\config\app_version.dart was not found.%reset%
    pause
    exit /b 1
)
rem  \x27 stands for the apostrophe, which a PowerShell single quoted
rem  string cannot contain. The lookahead keeps the line ending intact,
rem  so nothing is swallowed and no following line is merged into it.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f='lib/core/config/app_version.dart'; $p=(Resolve-Path $f).Path; $t=[System.IO.File]::ReadAllText($p); $ver='%VER%'; $bno='%BUILDNO%'; $mv='(?m)^(\s*static const String version = \x27)[^\x27]*(\x27;)(?=[ \t]*\r?$)'; $mb='(?m)^(\s*static const int buildNumber = )[0-9]+(;)(?=[ \t]*\r?$)'; $oldv='?'; $oldb='?'; if($t -match '(?m)^\s*static const String version = \x27([^\x27]*)\x27;'){ $oldv=$Matches[1] }; if($t -match '(?m)^\s*static const int buildNumber = ([0-9]+);'){ $oldb=$Matches[1] }; if($t -notmatch $mv){ Write-Host '  [ERROR] The AppVersion.version constant was not found in app_version.dart'; exit 1 }; if($t -notmatch $mb){ Write-Host '  [ERROR] The AppVersion.buildNumber constant was not found in app_version.dart'; exit 1 }; $out=[regex]::Replace($t,$mv,('${1}'+$ver+'${2}')); $out=[regex]::Replace($out,$mb,('${1}'+$bno+'${2}')); if($out -eq $t){ Write-Host ('  [OK] AppVersion is already '+$ver+'+'+$bno+' - nothing to change') } else { [System.IO.File]::WriteAllText($p,$out,(New-Object System.Text.UTF8Encoding($false))); Write-Host ('  [OK] AppVersion '+$oldv+'+'+$oldb+' is now '+$ver+'+'+$bno) }"
if errorlevel 1 (
    echo %red%[ERROR] Failed to sync the AppVersion constants - app_version.dart is unchanged.%reset%
    pause
    exit /b 1
)
exit /b 0

rem ============================================================
rem  read_version - parse the "version: x.y.z+n" line of pubspec.yaml
rem  Output: VER=x.y.z and BUILDNO=n (BUILDNO defaults to 1)
rem ============================================================
:read_version
set "VER="
set "BUILDNO=1"
for /f "tokens=2 delims=: " %%a in ('findstr /b /c:"version:" pubspec.yaml 2^>nul') do (
    for /f "tokens=1,2 delims=+" %%v in ("%%a") do (
        set "VER=%%v"
        if not "%%w"=="" set "BUILDNO=%%w"
    )
)
if not defined VER (
    echo %red%[ERROR] Cannot read the version from pubspec.yaml%reset%
    echo         Run this script from the project folder and make sure a line
    echo         such as "version: 3.4.8+48" exists in pubspec.yaml
    pause
    exit /b 1
)
exit /b 0
