@echo off
chcp 65001 > nul
title Muezzin Libya - Clean Source Utility

echo ======================================================
echo    Muezzin Libya - Professional Source Cleaner
echo ======================================================
echo.

set PROJECT=%~dp0
set OUTPUT=C:\Users\Admin\Desktop\MuezzinLibya_CleanSource_Zip

:: Clean Local Flutter
echo [1/5] Cleaning Flutter build files...
call flutter clean >nul 2>&1

:: Remove redundant folders
echo [2/5] Removing cache folders (.dart_tool, build, .gradle)...
if exist ".dart_tool" rmdir /s /q ".dart_tool"
if exist "build" rmdir /s /q "build"
if exist "android\.gradle" rmdir /s /q "android\.gradle"
if exist "android\app\build" rmdir /s /q "android\app\build"

:: Create output directory
if exist "%OUTPUT%" rmdir /s /q "%OUTPUT%"
mkdir "%OUTPUT%"

:: Copy essential files
echo [3/5] Copying essential source files to %OUTPUT%...
xcopy /s /q /e "lib" "%OUTPUT%\lib\" >nul
xcopy /s /q /e "android" "%OUTPUT%\android\" /EXCLUDE:android_exclude.txt >nul
xcopy /s /q /e "assets" "%OUTPUT%\assets\" >nul
copy /q "pubspec.yaml" "%OUTPUT%\" >nul
copy /q ".gitignore" "%OUTPUT%\" >nul
copy /q "build_ultimate_release.bat" "%OUTPUT%\" >nul

echo [4/5] Zipping the clean source...
powershell -Command "Compress-Archive -Path '%OUTPUT%\*' -DestinationPath 'C:\Users\Admin\Desktop\MuezzinLibya_CleanSource.zip' -Force"

echo [5/5] Finalizing...
if exist "%OUTPUT%" rmdir /s /q "%OUTPUT%"

echo.
echo ======================================================
echo    CLEANUP COMPLETE!
echo ======================================================
echo Clean Source Zip created on Desktop:
echo MuezzinLibya_CleanSource.zip
echo.
pause
