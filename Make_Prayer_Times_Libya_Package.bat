@echo off
chcp 65001 > nul
title 🕌 تجهيز حزمة تطبيق أوقات الصلاة - ليبيا
color 0A

echo ===================================================================
echo     🕌 تجهيز السورس كود النظيف وملف APK الشامل - أوقات الصلاة ليبيا
echo ===================================================================
echo.

set "DESKTOP_DIR=%USERPROFILE%\Desktop\Prayer Times Libya"
set "SOURCE_DIR=%~dp0"
set "TEMP_CLEAN=%~dp0temp_clean_export"

echo [1/5] إنشاء مجلد الإخراج على سطح المكتب...
if not exist "%DESKTOP_DIR%" (
    mkdir "%DESKTOP_DIR%"
)
echo     تم إنشاء/التأكد من المجلد: "%DESKTOP_DIR%"
echo.

echo [2/5] تجهيز نسخة الكود المصدري النظيف (بدون كاش وبدون مخلفات)...
if exist "%TEMP_CLEAN%" rd /s /q "%TEMP_CLEAN%"
mkdir "%TEMP_CLEAN%"

:: نسخ المجلدات الأساسية فقط
echo     - نسخ كود التطبيق (lib)...
xcopy "%SOURCE_DIR%lib" "%TEMP_CLEAN%\lib\" /E /I /Q /Y >nul

echo     - نسخ الموارد وقواعد البيانات (assets)...
xcopy "%SOURCE_DIR%assets" "%TEMP_CLEAN%\assets\" /E /I /Q /Y >nul

echo     - نسخ ملحقات النظام (plugins)...
xcopy "%SOURCE_DIR%plugins" "%TEMP_CLEAN%\plugins\" /E /I /Q /Y >nul

echo     - نسخ إعدادات أندرويد النظيفة (android)...
mkdir "%TEMP_CLEAN%\android"
xcopy "%SOURCE_DIR%android" "%TEMP_CLEAN%\android\" /E /I /Q /Y /EXCLUDE:%SOURCE_DIR%exclude_list.txt >nul 2>&1
if not exist "%TEMP_CLEAN%\android\app" (
    xcopy "%SOURCE_DIR%android\app" "%TEMP_CLEAN%\android\app\" /E /I /Q /Y >nul
    xcopy "%SOURCE_DIR%android\gradle" "%TEMP_CLEAN%\android\gradle\" /E /I /Q /Y >nul
    copy /Y "%SOURCE_DIR%android\build.gradle.kts" "%TEMP_CLEAN%\android\" >nul 2>&1
    copy /Y "%SOURCE_DIR%android\settings.gradle.kts" "%TEMP_CLEAN%\android\" >nul 2>&1
    copy /Y "%SOURCE_DIR%android\gradlew" "%TEMP_CLEAN%\android\" >nul 2>&1
    copy /Y "%SOURCE_DIR%android\gradlew.bat" "%TEMP_CLEAN%\android\" >nul 2>&1
    copy /Y "%SOURCE_DIR%android\local.properties" "%TEMP_CLEAN%\android\" >nul 2>&1
    copy /Y "%SOURCE_DIR%android\key.properties" "%TEMP_CLEAN%\android\" >nul 2>&1
    if exist "%TEMP_CLEAN%\android\.gradle" rd /s /q "%TEMP_CLEAN%\android\.gradle"
    if exist "%TEMP_CLEAN%\android\app\build" rd /s /q "%TEMP_CLEAN%\android\app\build"
)

echo     - نسخ منصة iOS و Web...
if exist "%SOURCE_DIR%ios" xcopy "%SOURCE_DIR%ios" "%TEMP_CLEAN%\ios\" /E /I /Q /Y >nul
if exist "%SOURCE_DIR%web" xcopy "%SOURCE_DIR%web" "%TEMP_CLEAN%\web\" /E /I /Q /Y >nul

echo     - نسخ ملفات المشروع الأساسية (pubspec, readme, إلخ)...
copy /Y "%SOURCE_DIR%pubspec.yaml" "%TEMP_CLEAN%\" >nul
copy /Y "%SOURCE_DIR%pubspec.lock" "%TEMP_CLEAN%\" >nul
copy /Y "%SOURCE_DIR%analysis_options.yaml" "%TEMP_CLEAN%\" >nul
copy /Y "%SOURCE_DIR%.gitignore" "%TEMP_CLEAN%\" >nul
copy /Y "%SOURCE_DIR%README.md" "%TEMP_CLEAN%\" >nul

:: إنشاء ملف تشغيل وبناء تلقائي بضغطة زر داخل السورس كود
(
echo @echo off
echo chcp 65001 ^> nul
echo title بناء تطبيق أوقات الصلاة - ليبيا
echo echo ========================================
echo echo    بناء تطبيق أوقات الصلاة - ليبيا
echo echo ========================================
echo call flutter clean
echo call flutter pub get
echo call flutter build apk --release
echo echo.
echo echo اكتمل البناء! تجد ملف APK في: build\app\outputs\flutter-apk\app-release.apk
echo pause
) > "%TEMP_CLEAN%\Build_APK.bat"

echo.
echo [3/5] ضغط السورس كود إلى ملف ZIP احترافي...
set "ZIP_OUT=%DESKTOP_DIR%\Prayer_Times_Libya_Clean_SourceCode.zip"
if exist "%ZIP_OUT%" del /f /q "%ZIP_OUT%"

powershell -NoProfile -Command "Compress-Archive -Path '%TEMP_CLEAN%\*' -DestinationPath '%ZIP_OUT%' -CompressionLevel Optimal -Force"

if exist "%ZIP_OUT%" (
    echo     ✅ تم إنشاء ملف الـ ZIP بنجاح!
) else (
    tar -a -c -f "%ZIP_OUT%" -C "%TEMP_CLEAN%" *
    echo     ✅ تم إنشاء ملف الـ ZIP بواسطة tar!
)

:: تنظيف مجلد النسخ المؤقت
if exist "%TEMP_CLEAN%" rd /s /q "%TEMP_CLEAN%"
echo.

echo [4/5] تجهيز ونقل ملف APK الشامل (Universal - لجميع الأجهزة)...
set "APK_TARGET=%DESKTOP_DIR%\Prayer_Times_Libya_v3.4.8_Universal_AllDevices.apk"

if exist "%SOURCE_DIR%MuezzinLibya_v3.4.8_Quran_Cleaned_NoExtraLetters.apk" (
    copy /Y "%SOURCE_DIR%MuezzinLibya_v3.4.8_Quran_Cleaned_NoExtraLetters.apk" "%APK_TARGET%" >nul
    echo     ✅ تم نسخ ملف الـ APK الشامل المعتمد v3.4.8 بنجاح.
) else if exist "%SOURCE_DIR%..\MuezzinLibya_v3.4.8_Quran_Cleaned_NoExtraLetters.apk" (
    copy /Y "%SOURCE_DIR%..\MuezzinLibya_v3.4.8_Quran_Cleaned_NoExtraLetters.apk" "%APK_TARGET%" >nul
    echo     ✅ تم نسخ ملف الـ APK الشامل المعتمد v3.4.8 بنجاح.
) else if exist "%SOURCE_DIR%build\app\outputs\flutter-apk\app-release.apk" (
    copy /Y "%SOURCE_DIR%build\app\outputs\flutter-apk\app-release.apk" "%APK_TARGET%" >nul
    echo     ✅ تم نسخ ملف APK الإصدار من مجلد البناء.
) else (
    echo     ⚠️ جارٍ بناء APK جديد...
    call flutter pub get
    call flutter build apk --release
    copy /Y "%SOURCE_DIR%build\app\outputs\flutter-apk\app-release.apk" "%APK_TARGET%" >nul
)

:: نسخ نسخة إضافية إذا وجدت معمارية منفصلة
if exist "%SOURCE_DIR%build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" (
    copy /Y "%SOURCE_DIR%build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" "%DESKTOP_DIR%\Prayer_Times_Libya_Modern_arm64.apk" >nul 2>&1
)
if exist "%SOURCE_DIR%build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" (
    copy /Y "%SOURCE_DIR%build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk" "%DESKTOP_DIR%\Prayer_Times_Libya_Old_arm32.apk" >nul 2>&1
)

echo.
echo [5/5] التحقق النهائي...
echo ===================================================================
echo     🎉 تم تجهيز الملفات بنجاح في مجلد:
echo     "%DESKTOP_DIR%"
echo ===================================================================
dir "%DESKTOP_DIR%"
echo.
echo فتح المجلد الآن...
explorer "%DESKTOP_DIR%"
pause
