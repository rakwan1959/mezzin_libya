package com.example.muezzin_libya_app

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.app.AlarmManager
import android.app.PendingIntent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {

    companion object {
        /**
         * هل التطبيق في المقدمة (مفتوح أمام المستخدم)؟
         * يستخدمه AdhanForegroundService لاتخاذ قرار إظهار شاشة الأذان فوق القفل:
         * تُعرض الشاشة فقط عندما يكون التطبيق مغلقاً وليس مفتوحاً أو في الخلفية.
         */
        @Volatile
        var isAppInForeground: Boolean = false
    }

    private val BATTERY_CHANNEL = "com.example.muezzin_libya_app/battery"
    private val ADHAN_CHANNEL   = "com.example.muezzin_libya_app/adhan"
    private val OVERLAY_CHANNEL = "com.example.muezzin_libya_app/overlay"
    private val VOLUME_CHANNEL  = "com.example.muezzin_libya_app/volume"
    private var adhanMethodChannel: MethodChannel? = null
    private var volumeChannel: MethodChannel? = null
    private var audioManager: AudioManager? = null

    private var sensorManager: android.hardware.SensorManager? = null
    private var proximitySensor: android.hardware.Sensor? = null
    private var proximityEventListener: android.hardware.SensorEventListener? = null

    // ── معالجة أزرار الصوت: إرسال مستوى الصوت إلى Flutter فقط ──
    // (أزرار رفع/خفض الصوت لا توقف الأذان — الإيقاف حصراً بلمس الشاشة أو زر الإشعار)
    override fun dispatchKeyEvent(event: android.view.KeyEvent): Boolean {
        if (event.action == android.view.KeyEvent.ACTION_DOWN) {
            when (event.keyCode) {
                android.view.KeyEvent.KEYCODE_VOLUME_UP,
                android.view.KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    // إرسال مستوى الصوت الجديد إلى Flutter
                    sendCurrentVolumeToFlutter()
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }

    private fun sendCurrentVolumeToFlutter() {
        try {
            val am = audioManager ?: return
            val maxVol = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val curVol = am.getStreamVolume(AudioManager.STREAM_MUSIC)
            val volumeLevel = if (maxVol > 0) curVol.toDouble() / maxVol.toDouble() else 1.0
            runOnUiThread {
                volumeChannel?.invokeMethod("onVolumeChanged", volumeLevel)
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error sending volume to Flutter: ${e.message}")
        }
    }

    private fun setupProximitySensor() {
        // تم إلغاء حشاس التقارب بناءً على طلب المستخدم (التحكم حصراً عبر أزرار خفض ورفع الصوت)
    }

    private fun startListeningProximity() {
        try {
            if (proximitySensor != null && proximityEventListener != null) {
                sensorManager?.registerListener(proximityEventListener, proximitySensor, android.hardware.SensorManager.SENSOR_DELAY_NORMAL)
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error starting proximity listener: ${e.message}")
        }
    }

    private fun stopListeningProximity() {
        try {
            if (proximityEventListener != null) {
                sensorManager?.unregisterListener(proximityEventListener)
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error stopping proximity listener: ${e.message}")
        }
    }

    private fun wakeUpScreenAndShowOverLock() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
                val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
                keyguardManager.requestDismissKeyguard(this, null)
            }
            @Suppress("DEPRECATION")
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                android.view.WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        } catch (e: Exception) {
            Log.e("MainActivity", "wakeUpScreenAndShowOverLock error: ${e.message}")
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        isAppInForeground = true
    }

    override fun onPause() {
        super.onPause()
        isAppInForeground = false
    }

    override fun onStop() {
        super.onStop()
        isAppInForeground = false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ربط أزرار الصوت الفعلية بصوت الوسائط (STREAM_MUSIC) لضمان التحكم بأزرار الصوت
        volumeControlStream = AudioManager.STREAM_MUSIC

        setupProximitySensor()

        // Register Adhan Listener
        AdhanForegroundService.stateListener = object : AdhanForegroundService.AdhanStateListener {
            override fun onAdhanStarted() {
                runOnUiThread { 
                    wakeUpScreenAndShowOverLock()
                    startListeningProximity()
                    adhanMethodChannel?.invokeMethod("onAdhanStarted", null) 
                }
            }
            override fun onAdhanStopped() {
                runOnUiThread { 
                    stopListeningProximity()
                    adhanMethodChannel?.invokeMethod("onAdhanStopped", null) 
                }
            }
        }

        adhanMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ADHAN_CHANNEL)
        
        // ── قناة البطارية ──────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        result.success(isIgnoringBatteryOptimizations())
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        requestIgnoreBatteryOptimizations()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── قناة الصوت (volume) ────────────────────────────────────────
        volumeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        
        adhanMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkInitialIntent" -> {
                    val showOverlay = intent?.getBooleanExtra("show_adhan_overlay", false) == true
                    val prayerName = intent?.getStringExtra("prayer_name") ?: ""
                    if (showOverlay) {
                        intent.removeExtra("show_adhan_overlay")
                        result.success(mapOf("showOverlay" to true, "prayerName" to prayerName))
                    } else {
                        result.success(mapOf("showOverlay" to false))
                    }
                }

                "stopAdhan" -> {
                    try {
                        val stopIntent = Intent(this, AdhanForegroundService::class.java).apply {
                            action = AdhanForegroundService.ACTION_STOP_ADHAN
                        }
                        startService(stopIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "stopAdhan error: ${e.message}")
                        result.error("STOP_ERROR", e.message, null)
                    }
                }

                "playAdhan" -> {
                    try {
                        val soundName  = call.argument<String>("soundName")  ?: "abdulbaset"
                        val prayerName = call.argument<String>("prayerName") ?: "الصلاة"
                        val volume     = (call.argument<Double>("volume") ?: 1.0).toFloat()
                        val playDoaa   = call.argument<Boolean>("playDoaa") ?: true
                        val skipAnnouncement = call.argument<Boolean>("skipAnnouncement") ?: false

                        val serviceIntent = Intent(this, AdhanForegroundService::class.java).apply {
                            action = AdhanForegroundService.ACTION_PLAY_ADHAN
                            putExtra(AdhanForegroundService.EXTRA_SOUND_NAME,  soundName)
                            putExtra(AdhanForegroundService.EXTRA_PRAYER_NAME, prayerName)
                            putExtra(AdhanForegroundService.EXTRA_VOLUME,      volume)
                            putExtra(AdhanForegroundService.EXTRA_PLAY_DOAA,   playDoaa)
                            putExtra(AdhanForegroundService.EXTRA_SKIP_ANNOUNCEMENT, skipAnnouncement)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "playAdhan error: ${e.message}")
                        result.error("PLAY_ERROR", e.message, null)
                    }
                }

                "playDua" -> {
                    try {
                        val serviceIntent = Intent(this, AdhanForegroundService::class.java).apply {
                            action = AdhanForegroundService.ACTION_PLAY_DUA
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "playDua error: ${e.message}")
                        result.error("DUA_ERROR", e.message, null)
                    }
                }

                "scheduleAlarms" -> {
                    try {
                        val alarms = call.argument<List<Map<String, Any>>>("alarms")
                        if (alarms != null) {
                            scheduleAlarms(alarms)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "scheduleAlarms error: ${e.message}")
                        result.error("SCHEDULE_ERROR", e.message, null)
                    }
                }

                "cancelAllAlarms" -> {
                    try {
                        cancelAllAlarms()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "cancelAllAlarms error: ${e.message}")
                        result.error("CANCEL_ERROR", e.message, null)
                    }
                }

                "setSystemVolume" -> {
                    try {
                        val volumeLevel = (call.argument<Double>("volume") ?: 1.0).toFloat()
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val maxVol = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        val targetVol = (volumeLevel * maxVol).toInt().coerceIn(0, maxVol)
                        
                        // استخدام FLAG_SHOW_UI لإظهار شريط الصوت الخاص بالنظام
                        am.setStreamVolume(AudioManager.STREAM_MUSIC, targetVol, AudioManager.FLAG_SHOW_UI)
                        
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "setSystemVolume error: ${e.message}")
                        result.error("VOLUME_ERROR", e.message, null)
                    }
                }

                "getSystemAlarmVolume" -> {
                    try {
                        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val maxVol = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        val curVol = am.getStreamVolume(AudioManager.STREAM_MUSIC)
                        result.success(curVol.toDouble() / maxVol.toDouble())
                    } catch (e: Exception) {
                        result.success(1.0)
                    }
                }

                "isAdhanPlaying" -> {
                    // التحقق بشكل موثوق من حالة التشغيل عبر الـ flag الثابت
                    result.success(AdhanForegroundService.isServiceRunning)
                }

                // ── تجربة الأذان الكاملة بعد 60 ثانية (منبه → صوت → شاشة فوق القفل) ──
                "scheduleTestAdhan" -> {
                    try {
                        val triggerTime = System.currentTimeMillis() + 60_000L
                        val testIntent = Intent(this, AdhanBroadcastReceiver::class.java).apply {
                            action = AdhanBroadcastReceiver.ACTION_TRIGGER_ADHAN
                            putExtra(AdhanBroadcastReceiver.EXTRA_SOUND_NAME,  "abdulbaset")
                            putExtra(AdhanBroadcastReceiver.EXTRA_PRAYER_NAME, "أذان تجريبي")
                            putExtra(AdhanBroadcastReceiver.EXTRA_ADHAN_MODE,  "sound")
                            putExtra(AdhanBroadcastReceiver.EXTRA_PLAY_DOAA,   false)
                        }
                        val pendingIntent = PendingIntent.getBroadcast(
                            this,
                            999901, // معرف ثابت للأذان التجريبي — لا يتعارض مع أذان الصلوات
                            testIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        // استخدام setAlarmClock لنفس آلية الأذان الحقيقي (منبه + استثناء مؤقت للخلفية)
                        val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerTime, pendingIntent)
                        alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                        Log.d("MainActivity", "Scheduled TEST adhan in 60 seconds")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "scheduleTestAdhan error: ${e.message}")
                        result.error("SCHEDULE_TEST_ERROR", e.message, null)
                    }
                }

                // ── تجربة شاشة إيقاف الأذان مباشرة (للتحقق الفوري من عملها) ──
                "showLockScreenTest" -> {
                    try {
                        val prayerName = call.argument<String>("prayerName") ?: "المغرب"
                        val testIntent = Intent(this, AdhanLockScreenActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                            putExtra(AdhanLockScreenActivity.EXTRA_PRAYER_NAME, prayerName)
                        }
                        startActivity(testIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "showLockScreenTest error: ${e.message}")
                        result.error("TEST_ERROR", e.message, null)
                    }
                }

                // ── فحص إذن الشاشة الكاملة (أندرويد 14+) ──
                "canUseFullScreenIntent" -> {
                    val canUse = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        try {
                            (getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager)
                                .canUseFullScreenIntent()
                        } catch (e: Exception) {
                            Log.e("MainActivity", "canUseFullScreenIntent error: ${e.message}")
                            false
                        }
                    } else {
                        true // قبل أندرويد 14 الإذن تلقائي
                    }
                    result.success(canUse)
                }

                // ── فحص إذن «العرض فوق التطبيقات الأخرى» (يتجاوز قيود أندرويد 15/16) ──
                "canDrawOverlays" -> {
                    val can = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try { Settings.canDrawOverlays(this) } catch (e: Exception) { false }
                    } else true
                    result.success(can)
                }

                // ── فتح صفحة منح «العرض فوق التطبيقات الأخرى» ──
                "requestOverlayPermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val overlayIntent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(overlayIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "requestOverlayPermission error: ${e.message}")
                        result.success(true)
                    }
                }

                // ── فتح إعدادات التنبيهات الخاصة بالتطبيق (خطوة 1 من رسالة البداية) ──
                "openNotificationSettings" -> {
                    try {
                        val notifIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            }
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        }
                        startActivity(notifIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "openNotificationSettings error: ${e.message}")
                        try {
                            startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            })
                        } catch (e2: Exception) {
                            Log.e("MainActivity", "openNotificationSettings fallback error: ${e2.message}")
                        }
                        result.success(true)
                    }
                }

                // ── زر رسالة البداية: يفتح نفس رابط أول إصدار (صفحة «المنبهات والتذكيرات» على أندرويد 14+) ──
                //   لأنها الوحيدة التي تسمح بشاشة إيقاف الأذان فوق القفل.
                "openStartupPermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            // أندرويد 14+: نفس الرابط الصحيح من أول إصدار — صفحة «المنبهات والتذكيرات»
                            val settingsIntent = Intent(
                                Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT
                            ).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(settingsIntent)
                        } else {
                            // قبل أندرويد 14: إذن الشاشة الكاملة تلقائي — نفتح إعدادات التنبيهات مباشرة
                            val notifIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                }
                            } else {
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                            }
                            startActivity(notifIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "openStartupPermission error: ${e.message}")
                        result.success(true)
                    }
                }

                // ── عرض الرقم التسلسلي للجهاز (لمراسلة لوحة تحكم المدير) ──
                "getDeviceSerialInfo" -> {
                    try {
                        var serial = "غير متاح (أندرويد 10+ يقيد الوصول)"
                        try {
                            serial = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                Build.getSerial()
                            } else {
                                @Suppress("DEPRECATION")
                                Build.SERIAL
                            }
                        } catch (e: Exception) {
                            serial = "غير متاح (أندرويد 10+ يقيد الوصول)"
                        }
                        var imei = ""
                        try {
                            val tm = getSystemService(Context.TELEPHONY_SERVICE) as android.telephony.TelephonyManager
                            imei = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                @Suppress("DEPRECATION")
                                tm.imei ?: ""
                            } else {
                                @Suppress("DEPRECATION")
                                tm.deviceId ?: ""
                            }
                        } catch (e: Exception) {
                            imei = ""
                        }
                        val androidId = Settings.Secure.getString(
                            contentResolver, Settings.Secure.ANDROID_ID
                        ) ?: ""
                        result.success(mapOf(
                            "serial" to serial,
                            "imei" to imei,
                            "androidId" to androidId,
                            "model" to Build.MODEL,
                            "manufacturer" to Build.MANUFACTURER
                        ))
                    } catch (e: Exception) {
                        result.success(mapOf(
                            "serial" to "", "imei" to "", "androidId" to "",
                            "model" to Build.MODEL, "manufacturer" to Build.MANUFACTURER
                        ))
                    }
                }

                // ── فتح صفحة منح إذن "المنبهات والتذكيرات" (أندرويد 14+) ──
                "requestFullScreenIntentPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                        try {
                            val settingsIntent = Intent(
                                Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT
                            ).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(settingsIntent)
                        } catch (e: Exception) {
                            Log.e("MainActivity", "requestFullScreenIntentPermission error: ${e.message}")
                            // بديل: فتح إعدادات التطبيق العامة
                            try {
                                startActivity(
                                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                        data = Uri.parse("package:$packageName")
                                    }
                                )
                            } catch (e2: Exception) {
                                Log.e("MainActivity", "fallback settings error: ${e2.message}")
                            }
                        }
                    }
                    result.success(true)
                }

                // ── تشغيل نغمة رسالة التهنئة (admin_notification) من الملف الأصلي ──
                "playCongratsTone" -> {
                    try {
                        playCongratsToneWithMediaPlayer()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "playCongratsTone error: ${e.message}")
                        result.error("TONE_ERROR", e.message, null)
                    }
                }

                // ── تشغيل نغمة الكارد برسالة (اسم الملف يُمرَّر من جانب Dart) ──
                "playNoticeTone" -> {
                    try {
                        playNoticeToneWithMediaPlayer(
                            call.argument<String>("tone") ?: "admin_notification"
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "playNoticeTone error: ${e.message}")
                        result.error("TONE_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    /// تشغيل نغمة التنبيه لرسالة التهنئة عبر MediaPlayer (قناة الوسائط)
    /// — نغمة نظيفة غير موسيقية مناسبة لتطبيق إسلامي.
    private fun playCongratsToneWithMediaPlayer() {
        playNoticeToneWithMediaPlayer("admin_notification")
    }

    /// تشغيل نغمة إشعار باسم الملف المطلوب — النغمات المضمّنة:
    ///   admin_notification (رسالة التهنئة) · greeting_chime / greeting_bell (كارد الرسالة)
    private fun playNoticeToneWithMediaPlayer(tone: String) {
        val resId = when (tone) {
            "greeting_chime" -> R.raw.greeting_chime
            "greeting_bell" -> R.raw.greeting_bell
            else -> R.raw.admin_notification
        }
        val player = android.media.MediaPlayer.create(this, resId) ?: return
        try {
            player.setAudioAttributes(
                android.media.AudioAttributes.Builder()
                    .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            player.setOnCompletionListener { it.release() }
            player.setOnErrorListener { mp, _, _ -> mp.release(); true }
            player.start()
            Log.d("MainActivity", "playNoticeToneWithMediaPlayer: started ($tone)")
        } catch (e: Exception) {
            Log.e("MainActivity", "playNoticeToneWithMediaPlayer error: ${e.message}")
            try { player.release() } catch (_: Exception) {}
        }
    }

    private fun saveAlarmData(id: Int, timeMs: Long, prayerName: String, soundName: String, adhanMode: String, playDoaa: Boolean, isVoiceMessage: Boolean = false) {
        val prefs = getSharedPreferences("ScheduledAlarmsPrefs", Context.MODE_PRIVATE)
        val ids = prefs.getStringSet("alarm_ids", mutableSetOf()) ?: mutableSetOf()
        val newIds = ids.toMutableSet()
        newIds.add(id.toString())
        
        val dataStr = "$timeMs|$prayerName|$soundName|$adhanMode|$playDoaa|$isVoiceMessage"
        prefs.edit()
            .putStringSet("alarm_ids", newIds)
            .putString("alarm_data_$id", dataStr)
            .apply()
    }

    private fun cancelAllAlarms() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val prefs = getSharedPreferences("ScheduledAlarmsPrefs", Context.MODE_PRIVATE)
        val ids = prefs.getStringSet("alarm_ids", emptySet()) ?: emptySet()
        val editor = prefs.edit()
        for (idStr in ids) {
            val id = idStr.toIntOrNull() ?: continue
            val intent = Intent(this, AdhanBroadcastReceiver::class.java).apply {
                action = AdhanBroadcastReceiver.ACTION_TRIGGER_ADHAN
            }
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                id,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
            editor.remove("alarm_data_$id")
        }
        editor.remove("alarm_ids").apply()
        Log.d("MainActivity", "Canceled all scheduled alarms")
    }

    private fun scheduleAlarms(alarms: List<Map<String, Any>>) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (alarm in alarms) {
            val id = (alarm["id"] as? Number)?.toInt() ?: continue
            val timeMs = (alarm["time"] as? Number)?.toLong() ?: continue
            val prayerName = alarm["prayerName"] as? String ?: "الصلاة"
            val soundName = alarm["soundName"] as? String ?: "abdulbaset"
            val adhanMode = alarm["adhanMode"] as? String ?: "sound"
            val playDoaa = alarm["playDoaa"] as? Boolean ?: true
            val isVoiceMessage = alarm["voiceMessage"] == true
            val isFridayReminder = alarm["fridayReminder"] == true

            val intent = if (isFridayReminder) {
                // تذكير صلاة الجمعة: إرسال بث خاص لتشغيل صوت الطيور
                Intent(this, AdhanBroadcastReceiver::class.java).apply {
                    action = AdhanBroadcastReceiver.ACTION_TRIGGER_FRIDAY_REMINDER
                    putExtra(AdhanBroadcastReceiver.EXTRA_PRAYER_NAME, prayerName)
                }
            } else {
                Intent(this, AdhanBroadcastReceiver::class.java).apply {
                    action = AdhanBroadcastReceiver.ACTION_TRIGGER_ADHAN
                    putExtra(AdhanBroadcastReceiver.EXTRA_SOUND_NAME,  soundName)
                    putExtra(AdhanBroadcastReceiver.EXTRA_PRAYER_NAME, prayerName)
                    putExtra(AdhanBroadcastReceiver.EXTRA_ADHAN_MODE,  adhanMode)
                    putExtra(AdhanBroadcastReceiver.EXTRA_PLAY_DOAA,   playDoaa)
                    putExtra(AdhanBroadcastReceiver.EXTRA_IS_VOICE_MESSAGE, isVoiceMessage)
                }
            }

            val pendingIntent = PendingIntent.getBroadcast(
                this,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            saveAlarmData(id, timeMs, prayerName, soundName, adhanMode, playDoaa, isVoiceMessage)

            try {
                // استخدام setAlarmClock المضمن لمنع تجاهله أثناء قفل الشاشة وحالات وضع السكون العميق (Doze mode)
                val alarmClockInfo = AlarmManager.AlarmClockInfo(timeMs, pendingIntent)
                alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                Log.d("MainActivity", "Scheduled setAlarmClock $id for $prayerName at $timeMs${if (isFridayReminder) " [Friday Reminder - Birds Sound]" else ""}")
            } catch (e: Exception) {
                Log.w("MainActivity", "Error setting alarm clock, falling back: ${e.message}")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pendingIntent)
                    } catch (se: SecurityException) {
                        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pendingIntent)
                    }
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, timeMs, pendingIntent)
                }
            }
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            return pm.isIgnoringBatteryOptimizations(packageName)
        }
        return true
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent().apply {
                action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                startActivity(intent)
            } catch (e: Exception) {
                val fallbackIntent = Intent().apply {
                    action = Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(fallbackIntent)
            }
        }
    }
}
