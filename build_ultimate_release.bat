@echo off
chcp 65001 > nul
setlocal
title Muezzin Libya - Ultimate Release Builder

echo ======================================================
echo    Muezzin Libya - Ultimate Build: Universal + Splits
echo ======================================================
echo.

rem ============================================================
rem  Version is read from pubspec.yaml -- never hardcoded.
rem  A line like   version: 3.4.8+48   gives VER=3.4.8, BUILDNO=48
rem ============================================================
call :read_version
if errorlevel 1 exit /b 1
echo    Version read from pubspec.yaml: v%VER%+%BUILDNO%
echo.

rem ============================================================
rem  Clean is now OPTIONAL. With no argument the build is
rem  incremental: the cache is kept, so any other work running
rem  on this project folder is not disturbed.
rem  For a cold full build:  build_ultimate_release.bat clean
rem ============================================================
set "DO_CLEAN=0"
if /i "%~1"=="clean" set "DO_CLEAN=1"
if /i "%~1"=="--clean" set "DO_CLEAN=1"

if "%DO_CLEAN%"=="1" (
    echo [1/4] Cleaning project cache...
    call flutter clean >nul 2>&1
    if exist "build" rd /s /q "build"
    if exist ".dart_tool" rd /s /q ".dart_tool"
) else (
    echo [1/4] Skipping clean - incremental build. Cold build: %~nx0 clean
)

echo [2/4] Fetching packages...
call flutter pub get
if errorlevel 1 (
    echo [ERROR] flutter pub get failed
    pause
    exit /b 1
)

echo [3/4] Building Universal APK for ALL devices...
call flutter build apk --release --obfuscate --split-debug-info=build/debug-info
if errorlevel 1 (
    echo [ERROR] Universal APK build failed
    pause
    exit /b 1
)

echo [4/4] Building Split APKs per architecture...
call flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info --target-platform android-arm,android-arm64,android-x64
if errorlevel 1 echo [WARN] Some split APKs may have failed

set "OUT_DIR=build\app\outputs\flutter-apk"
set "FINAL_DIR=%USERPROFILE%\Desktop\MuezzinLibya_v%VER%_Build"

if not exist "%FINAL_DIR%" mkdir "%FINAL_DIR%"

rem -- Copy to the Desktop folder, names carry the parsed version --
copy /y "%OUT_DIR%\app-release.apk" "%FINAL_DIR%\MuezzinLibya_v%VER%_Universal_AllDevices.apk" >nul
copy /y "%OUT_DIR%\app-arm64-v8a-release.apk" "%FINAL_DIR%\MuezzinLibya_v%VER%_Modern_64bit_arm64.apk" >nul
copy /y "%OUT_DIR%\app-armeabi-v7a-release.apk" "%FINAL_DIR%\MuezzinLibya_v%VER%_Old_32bit_arm32.apk" >nul
copy /y "%OUT_DIR%\app-x86_64-release.apk" "%FINAL_DIR%\MuezzinLibya_v%VER%_x86_64_Emulator.apk" >nul

rem -- And a copy inside the project folder for quick archiving --
copy /y "%OUT_DIR%\app-release.apk" "MuezzinLibya_v%VER%_Universal_AllDevices.apk" >nul
copy /y "%OUT_DIR%\app-arm64-v8a-release.apk" "MuezzinLibya_v%VER%_Modern_64bit_arm64.apk" >nul
copy /y "%OUT_DIR%\app-armeabi-v7a-release.apk" "MuezzinLibya_v%VER%_Old_32bit_arm32.apk" >nul
copy /y "%OUT_DIR%\app-x86_64-release.apk" "MuezzinLibya_v%VER%_x86_64_Emulator.apk" >nul

echo ======================================================
echo    SUCCESS: v%VER% builds are ready
echo ======================================================
echo Output folder: %FINAL_DIR%
pause
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
    echo [ERROR] Cannot read the version from pubspec.yaml
    echo         Run this script from the project folder and make sure a line
    echo         such as "version: 3.4.8+48" exists in pubspec.yaml
    pause
    exit /b 1
)
exit /b 0
