package com.example.muezzin_libya_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.PowerManager
import android.util.Log

/**
 * BroadcastReceiver يستقبل Intent تشغيل الأذان من flutter_local_notifications
 * أو من AlarmManager مباشرة.
 *
 * يُطلق AdhanForegroundService لتشغيل الأذان حتى لو كان التطبيق مغلقاً.
 */
class AdhanBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AdhanBroadcastReceiver"

        // يجب أن يتطابق هذا الـ action مع ما يُرسَل من Dart
        const val ACTION_TRIGGER_ADHAN = "com.example.muezzin_libya_app.TRIGGER_ADHAN"
        const val ACTION_TRIGGER_FRIDAY_REMINDER = "com.example.muezzin_libya_app.TRIGGER_FRIDAY_REMINDER"

        const val EXTRA_SOUND_NAME  = "sound_name"
        const val EXTRA_PRAYER_NAME = "prayer_name"
        const val EXTRA_ADHAN_MODE  = "adhan_mode"   // "sound" | "vibration" | "silent"
        const val EXTRA_PLAY_DOAA   = "play_doaa"
        const val EXTRA_IS_VOICE_MESSAGE = "is_voice_message" // الرسالة الصوتية (الشروق / قبل المغرب)

        // اسم SharedPreferences المشترك مع Flutter (flutter_shared_preferences)
        private const val PREFS_NAME = "FlutterSharedPreferences"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive: action=${intent.action}")

        // استحواذ على WakeLock فوري لإيقاظ للمعالج والشاشة فوراً عند قفل الجهاز
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wl = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "AdhanBroadcastReceiver::WakeLock"
            )
            wl.acquire(15000L) // 15 ثانية كافية لبدء الخدمة بنجاح
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring WakeLock in receiver: ${e.message}")
        }

        // ── تذكير صلاة الجمعة بأصوات الطيور قبل 45 دقيقة ──
        if (intent.action == ACTION_TRIGGER_FRIDAY_REMINDER) {
            val reminderTitle = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "تذكير صلاة الجمعة"
            Log.d(TAG, "Triggering Friday reminder audio: $reminderTitle")
            startFridayReminderService(context, reminderTitle)
            return
        }

        // التحقق من الـ Action
        if (intent.action != ACTION_TRIGGER_ADHAN) {
            Log.w(TAG, "Unknown action: ${intent.action}")
            return
        }

        // ── الرسالة الصوتية (وقت الشروق / قبل المغرب بـ 20 دقيقة) ──
        // تُشغَّل مباشرة عبر الخدمة بدون شاشة أذان وبدون إشعار صوتي خاص.
        if (intent.getBooleanExtra(EXTRA_IS_VOICE_MESSAGE, false)) {
            val voiceTitle = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "رسالة صوتية"
            Log.d(TAG, "Triggering voice message: $voiceTitle")
            startVoiceMessageService(context, voiceTitle)
            return
        }

        val soundName  = intent.getStringExtra(EXTRA_SOUND_NAME)  ?: "abdulbaset"
        val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "الصلاة"
        val playDoaa   = intent.getBooleanExtra(EXTRA_PLAY_DOAA, true)
        
        // قراءة الإعدادات
        var adhanMode = intent.getStringExtra(EXTRA_ADHAN_MODE)
        if (adhanMode == null) {
            adhanMode = getAdhanModeFromPrefs(context)
        }

        Log.d(TAG, "Final adhanMode=$adhanMode, sound=$soundName, prayer=$prayerName")

        when (adhanMode) {
            "silent" -> {
                Log.d(TAG, "Mode is silent — skipping adhan playback")
            }
            "vibration" -> {
                Log.d(TAG, "Mode is vibration — no vibration (disabled by user)")
                // تم حذف الاهتزاز بناءً على طلب المستخدم
            }
            else -> {
                // "sound" — تشغيل الأذان فقط بدون اهتزاز
                // ── إظهار شاشة إيقاف الأذان فوراً (داخل نافذة استثناء المنبه المؤقتة) ──
                // عند انطلاق المنبه يمنح النظام التطبيق استثناءً مؤقتاً يسمح بإظهار
                // نشاط فوق شاشة القفل — لذلك نطلق الشاشة من هنا مباشرة وليس من الخدمة
                // (حتى لا تفوتنا النافذة الزمنية على أندرويد 10+).
                // تُعرض فقط في وضع «صوت» لأن وضعَي «صامت/اهتزاز» لا يشغّلان أذاناً.
                launchLockScreenIfNeeded(context, prayerName)
                startAdhanService(context, soundName, prayerName, 1.0f, playDoaa)
            }
        }
    }

    /**
     * إظهار شاشة إيقاف الأذان فوق شاشة القفل مباشرة من المستقبِل.
     *
     * تُستدعى لحظة انطلاق المنبه — وهي اللحظة الوحيدة التي يمنح فيها النظام
     * للتطبيق استثناءً مؤقتاً (temp-allowlist) يسمح بإظهار نشاط فوق القفل
     * حتى على أندرويد 10+ حيث تُقيَّد إظهار الأنشطة من الخلفية.
     *
     * الشروط: التطبيق مغلق (ليس في المقدمة) والشاشة مقفلة أو مطفأة.
     */
    private fun launchLockScreenIfNeeded(context: Context, prayerName: String) {
        try {
            // 1) التطبيق مفتوح في المقدمة؟ لا نظهر الشاشة
            if (MainActivity.isAppInForeground) {
                Log.d(TAG, "App in foreground — skipping lock screen")
                return
            }

            // 2) الشاشة مفتوحة وغير مقفلة؟ لا نظهر الشاشة
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val km = context.getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
            val screenOn = pm.isInteractive
            val keyguardLocked = km.isKeyguardLocked
            if (screenOn && !keyguardLocked) {
                Log.d(TAG, "Screen on & unlocked — skipping lock screen")
                return
            }

            // 3) التطبيق مغلق والشاشة مقفلة → نظهر شاشة الأذان فوق القفل
            Log.d(TAG, "Launching lock screen from receiver for $prayerName")
            val lockIntent = Intent(context, AdhanLockScreenActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra(AdhanLockScreenActivity.EXTRA_PRAYER_NAME, prayerName)
            }
            context.startActivity(lockIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Error launching lock screen from receiver: ${e.message}")
        }
    }

    // ─────────────────────────────────────────────────────────────
    private fun startVoiceMessageService(context: Context, voiceTitle: String) {
        val serviceIntent = Intent(context, AdhanForegroundService::class.java).apply {
            action = AdhanForegroundService.ACTION_PLAY_VOICE_MESSAGE
            putExtra(AdhanForegroundService.EXTRA_VOICE_TITLE, voiceTitle)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "Voice message service started: $voiceTitle")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start voice message service: ${e.message}", e)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // تشغيل صوت تذكير صلاة الجمعة (أصوات الطيور) قبل 45 دقيقة من الأذان
    private fun startFridayReminderService(context: Context, reminderTitle: String) {
        val serviceIntent = Intent(context, AdhanForegroundService::class.java).apply {
            action = AdhanForegroundService.ACTION_PLAY_FRIDAY_REMINDER
            putExtra(AdhanForegroundService.EXTRA_VOICE_TITLE, reminderTitle)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "Friday reminder service started: $reminderTitle")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Friday reminder service: ${e.message}", e)
        }
    }

    // ─────────────────────────────────────────────────────────────
    private fun startAdhanService(
        context: Context,
        soundName: String,
        prayerName: String,
        volume: Float,
        playDoaa: Boolean
    ) {
        val serviceIntent = Intent(context, AdhanForegroundService::class.java).apply {
            action = AdhanForegroundService.ACTION_PLAY_ADHAN
            putExtra(AdhanForegroundService.EXTRA_SOUND_NAME,  soundName)
            putExtra(AdhanForegroundService.EXTRA_PRAYER_NAME, prayerName)
            putExtra(AdhanForegroundService.EXTRA_VOLUME,      volume)
            putExtra(AdhanForegroundService.EXTRA_PLAY_DOAA,   playDoaa)
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "AdhanForegroundService started for prayer: $prayerName")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start AdhanForegroundService: ${e.message}", e)
        }
    }

    // ─────────────────────────────────────────────────────────────
    // قراءة وضع الأذان من SharedPreferences المشترك مع Flutter
    // ─────────────────────────────────────────────────────────────
    private fun getAdhanModeFromPrefs(context: Context): String {
        return try {
            val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.getString("flutter.adhanMode", "sound") ?: "sound"
        } catch (e: Exception) {
            Log.e(TAG, "Error reading adhanMode from prefs: ${e.message}")
            "sound"
        }
    }

    // تم حذف جميع دوال الاهتزاز بناءً على طلب المستخدم
}
