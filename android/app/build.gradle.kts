import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.example.muezzin_libya_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"
    // ترك نسخة الـ NDK للنظام لضمان التوافق مع 64-bit

    signingConfigs {
        // نتحقق من وجود المفتاح قبل المحاولة لتجنب أخطاء البناء
        if (keystoreProperties.containsKey("storeFile")) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.muezzin_libya_app"

        minSdk = flutter.minSdkVersion

        // ── targetSdk = 30 مقصود ومهم ─────────────────────────────────────────
        // توثيق أندرويد: «التطبيقات التي تستهدف أندرويد 12 (API 31) أو أحدث
        // لا تستطيع إنشاء إشعارات مخصّصة كاملة؛ يطبّق النظام قالباً قياسياً
        // شبيهاً بـ DecoratedCustomViewStyle» — أي أنه يضع إطاره وزخرفته فوق
        // بطاقتنا فيظهر «إشعار صغير داخل إشعار كبير» ولا يمكن منع ذلك من كود
        // التطبيق مهما فُعل (جرّبناه 12 مرة).
        //
        // 30 هو آخر إصدار قبل هذا القيد، فتُرسم بطاقة الإشعار المخصّصة
        // (الكحلي الملكي + خط أميري أبيض) **وحدها** بلا قالب نظام فوقها.
        //
        // وفائدة جانبية مهمة لهذا التطبيق بعينه: القيود التالية كلها لا تُفرض
        // على targetSdk 30 — فتصبح أوقات الصلاة والأذان أكثر موثوقية لا أقل:
        //   • إذن SCHEDULE_EXACT_ALARM لمنبهات المواقيت (فُرض على 31+)
        //   • شاشة الأذان الكاملة على أندرويد 14+ بلا إذن «المنبهات والتذكيرات»
        //     (فُرض على 34+)
        //   • قيود تشغيل الخدمة في الخلفية (فُرضت على 31+ / 34+)
        //   • حظر فتح الشاشات من الخلفية على أندرويد 15/16 (فُرض على 34+)
        //
        // ⚠️ للرجوع: أعد القيمة 35 — ولا شيء آخر يتغير.
        targetSdk = 30
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // دعم التطبيقات الكبيرة على الأجهزة القديمة
        multiDexEnabled = true

        // دعم SVG والرسومات المتجهة على Android القديم
        vectorDrawables.useSupportLibrary = true
    }

    buildTypes {
        release {
            // نستخدم التوقيع فقط إذا كان متاحاً فعلياً في الملف
            val releaseConfig = signingConfigs.findByName("release")
            signingConfig = if (releaseConfig != null) {
                releaseConfig
            } else {
                signingConfigs.getByName("debug")
            }

            // تفعيل تقليص الكود والموارد بـ R8
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // تحسينات إضافية للإصدار
            isDebuggable = false
            isJniDebuggable = false
        }

        debug {
            isMinifyEnabled = false
            isShrinkResources = false
            isDebuggable = true
        }
    }

    // تحسين حجم APK النهائي
    packaging {
        resources {
            excludes += listOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/*.kotlin_module",
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
                "**/*.proto",
                "**/*.bin",
                "**/*.java",
                "**/*.properties",
                "kotlin/**",
                "okhttp3/**",
                "DebugProbesKt.bin"
            )
        }
        jniLibs {
            // تفعيل ضغط المكتبات البرمجية لتخفيض حجم ملف الـ APK بشكل كبير
            useLegacyPackaging = true
        }
    }

    // lint: تجاهل الأخطاء غير الحرجة أثناء البناء
    lint {
        abortOnError = false
        checkReleaseBuilds = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    // دعم API الحديثة على Android 5.0+
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
