# =============================================================================
# المؤذن الليبي - قواعد ProGuard/R8 الشاملة
# يغطي جميع المكتبات المستخدمة في المشروع
# =============================================================================

# ─────────────────────────────────────────────
# Application Native Classes & Services (مؤذن ليبيا)
# ─────────────────────────────────────────────
-keep class com.example.muezzin_libya_app.** { *; }
-keepclassmembers class com.example.muezzin_libya_app.** { *; }

# ─────────────────────────────────────────────
# Flutter Core
# ─────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.android.FlutterActivity
-dontwarn io.flutter.**

# ─────────────────────────────────────────────
# Kotlin
# ─────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}
-assumenosideeffects class kotlin.jvm.internal.Intrinsics {
    static void checkParameterIsNotNull(java.lang.Object, java.lang.String);
}

# ─────────────────────────────────────────────
# Kotlin Coroutines
# ─────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**

# ─────────────────────────────────────────────
# Adhan (Prayer Times Library)
# ─────────────────────────────────────────────
-keep class com.batoulapps.adhan.** { *; }
-keepclassmembers class com.batoulapps.adhan.** { *; }

# ─────────────────────────────────────────────
# Just Audio, Audio Service & ExoPlayer / Media3
# ─────────────────────────────────────────────
-keep class com.ryanheise.just_audio.** { *; }
-keepclassmembers class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.just_audio.AudioPlayer { *; }
-keep class com.ryanheise.just_audio.AudioPlayer$* { *; }
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.audioservice.AudioService { *; }
-keep class com.ryanheise.audioservice.AudioServiceConfig { *; }
-dontwarn com.ryanheise.**

-keep class com.google.android.exoplayer2.** { *; }
-keep interface com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }
-keep interface androidx.media3.** { *; }
-keep class androidx.media.** { *; }
-keep interface androidx.media.** { *; }
-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**
-dontwarn androidx.media.**

# ─────────────────────────────────────────────
# Flutter Local Notifications
# ─────────────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.**

# ─────────────────────────────────────────────
# Supabase / Ktor / OkHttp / Networking
# ─────────────────────────────────────────────
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.** { *; }
-keep class io.ktor.client.** { *; }
-keep class io.ktor.client.engine.** { *; }
-keep class com.squareup.okhttp3.** { *; }
-keep interface com.squareup.okhttp3.** { *; }
-dontwarn io.ktor.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# ─────────────────────────────────────────────
# SQLite / SQFlite
# ─────────────────────────────────────────────
-keep class io.flutter.plugins.sqflite.** { *; }
-keep class com.tekartik.sqflite.** { *; }
-dontwarn io.flutter.plugins.sqflite.**

# ─────────────────────────────────────────────
# Hive (NoSQL Database)
# ─────────────────────────────────────────────
-keep class com.hive.** { *; }
-keep class io.flutter.plugins.hive.** { *; }
-keepclassmembers class * {
    @com.hive.annotations.HiveType <fields>;
    @com.hive.annotations.HiveField <fields>;
}

# ─────────────────────────────────────────────
# SharedPreferences
# ─────────────────────────────────────────────
-keep class com.russhwolf.settings.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ─────────────────────────────────────────────
# Speech to Text
# ─────────────────────────────────────────────
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class com.csdcorp.** { *; }
-dontwarn com.csdcorp.**

# ─────────────────────────────────────────────
# Flutter TTS (Text to Speech)
# ─────────────────────────────────────────────
-keep class com.tundralabs.fluttertts.** { *; }
-dontwarn com.tundralabs.**

# ─────────────────────────────────────────────
# Geolocator / Location Services
# ─────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }
-keep class com.google.android.gms.location.** { *; }
-dontwarn com.baseflow.geolocator.**

# ─────────────────────────────────────────────
# Flutter Compass
# ─────────────────────────────────────────────
-keep class com.hemanthraj.fluttercompass.** { *; }
-dontwarn com.hemanthraj.**

# ─────────────────────────────────────────────
# Permission Handler
# ─────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# ─────────────────────────────────────────────
# URL Launcher
# ─────────────────────────────────────────────
-keep class io.flutter.plugins.urllauncher.** { *; }

# ─────────────────────────────────────────────
# Path Provider
# ─────────────────────────────────────────────
-keep class io.flutter.plugins.pathprovider.** { *; }

# ─────────────────────────────────────────────
# Google Fonts
# ─────────────────────────────────────────────
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ─────────────────────────────────────────────
# Firebase / Google Play Services
# ─────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-dontwarn com.google.firebase.**

# ─────────────────────────────────────────────
# Timezone
# ─────────────────────────────────────────────
-keep class org.joda.time.** { *; }
-dontwarn org.joda.time.**

# ─────────────────────────────────────────────
# Gson / JSON Serialization
# ─────────────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ─────────────────────────────────────────────
# MultiDex Support
# ─────────────────────────────────────────────
-keep class androidx.multidex.** { *; }

# ─────────────────────────────────────────────
# Android / AndroidX
# ─────────────────────────────────────────────
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-keep class android.** { *; }
-dontwarn android.test.**
-dontwarn android.support.**
-dontwarn androidx.**

# ─────────────────────────────────────────────
# حفاظ على معلومات مفيدة للتصحيح (Stack Traces)
# ─────────────────────────────────────────────
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes SourceFile
-keepattributes LineNumberTable
-keepattributes *Annotation*
-keepattributes EnclosingMethod

# ─────────────────────────────────────────────
# تحسينات R8 / ProGuard المتقدمة
# ─────────────────────────────────────────────
-allowaccessmodification
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*,!code/allocation/variable
-optimizationpasses 5

# ─────────────────────────────────────────────
# تجاهل التحذيرات غير الحرجة
# ─────────────────────────────────────────────
-ignorewarnings
-dontnote **
