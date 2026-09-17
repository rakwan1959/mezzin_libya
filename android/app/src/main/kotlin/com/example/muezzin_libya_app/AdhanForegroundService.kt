package com.example.muezzin_libya_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

class AdhanForegroundService : Service() {

    companion object {
        private const val TAG = "AdhanForegroundService"

        const val ACTION_PLAY_ADHAN           = "ACTION_PLAY_ADHAN"
        const val ACTION_STOP_ADHAN           = "ACTION_STOP_ADHAN"
        const val ACTION_PLAY_DUA             = "ACTION_PLAY_DUA"
        const val ACTION_UPDATE_VOLUME        = "ACTION_UPDATE_VOLUME"
        const val ACTION_PLAY_VOICE_MESSAGE   = "ACTION_PLAY_VOICE_MESSAGE"
        const val ACTION_PLAY_FRIDAY_REMINDER = "ACTION_PLAY_FRIDAY_REMINDER"
        const val EXTRA_SOUND_NAME    = "sound_name"
        const val EXTRA_PRAYER_NAME   = "prayer_name"
        const val EXTRA_VOLUME        = "volume"
        const val EXTRA_PLAY_DOAA     = "play_doaa"
        const val EXTRA_SKIP_ANNOUNCEMENT = "skip_announcement"
        const val EXTRA_VOICE_TITLE   = "voice_title"

        // Action خاص بزر الإيقاف في الإشعار
        const val ACTION_NOTIF_STOP = "com.example.muezzin_libya_app.NOTIF_STOP_ADHAN"

        // Broadcast يُرسل عند توقف الأذان لإغلاق AdhanLockScreenActivity
        const val ACTION_ADHAN_STOPPED = "com.example.muezzin_libya_app.ADHAN_STOPPED"

        private const val NOTIF_CHANNEL_ID   = "adhan_foreground_v6"
        private const val NOTIF_ID           = 9999

        // ── هوية الألوان: كحلي ملكي (Royal Navy #002855) ────────────────────
        // يُستخدم مع setColorized(true) فيصبح **خلفية الإشعار نفسها** في شريط
        // النظام (setColor وحده لا يُغيّر الخلفية — إنه لون التمييز فقط).
        /** خلفية بطاقة الإشعار — أسود (مطابقة لبطاقة Dart المخصّصة). */
        private const val CARD_BLACK = 0xFF000000.toInt()
        private const val DOAA_DELAY_MS      = 2000L // تشغيل الدعاء بعد الأذان بـ 2 ثانية

        // Listener for Activity to notify Flutter
        var stateListener: AdhanStateListener? = null

        // تتبع حالة التشغيل بشكل موثوق بدلاً من getRunningServices
        var isServiceRunning: Boolean = false
    }

    /**
     * BroadcastReceiver داخلي يستقبل أمر الإيقاف من زر الإشعار
     * يعمل حتى عندما يكون التطبيق مغلقاً تماماً
     */
    private val stopFromNotifReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_NOTIF_STOP) {
                Log.d(TAG, "Stop button in notification pressed -> stopping Adhan")
                isServiceRunning = false
                stopAdhan()
                sendAdhanStoppedBroadcast()
                mainHandler.post { stateListener?.onAdhanStopped() }
                stopSelf()
            }
        }
    }
    private var isStopReceiverRegistered = false

    interface AdhanStateListener {
        fun onAdhanStarted()
        fun onAdhanStopped()
    }

    private var mediaPlayer: MediaPlayer? = null
    private var doaaPlayer: MediaPlayer? = null
    private var voicePlayer: MediaPlayer? = null
    private var voiceMsgPlayer: MediaPlayer? = null
    private var fridayReminderPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var audioManager: AudioManager? = null
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var pendingDoaaRunnable: Runnable? = null
    private var currentVolume: Float = 1.0f
    private var currentPrayerName: String = ""

    // ─────────────────────────────────────────────────────────────
    /**
     * إرسال broadcast إيقاف الأذان لإغلاق AdhanLockScreenActivity إذا كانت مفتوحة.
     */
    private fun sendAdhanStoppedBroadcast() {
        try {
            val closeBroadcast = Intent(ACTION_ADHAN_STOPPED)
            closeBroadcast.setPackage(packageName)
            sendBroadcast(closeBroadcast)
        } catch (e: Exception) {
            Log.e(TAG, "Error sending stopped broadcast: ${e.message}")
        }
    }

    // ─────────────────────────────────────────────────────────────
    override fun onBind(intent: Intent?): IBinder? = null

    // ─────────────────────────────────────────────────────────────
    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        createNotificationChannel()
        // تسجيل Receiver زر الإيقاف في الإشعار
        registerStopFromNotifReceiver()
    }

    private fun registerStopFromNotifReceiver() {
        if (!isStopReceiverRegistered) {
            try {
                val filter = IntentFilter(ACTION_NOTIF_STOP)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(stopFromNotifReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    registerReceiver(stopFromNotifReceiver, filter)
                }
                isStopReceiverRegistered = true
                Log.d(TAG, "StopFromNotif receiver registered")
            } catch (e: Exception) {
                Log.e(TAG, "Error registering stop receiver: ${e.message}")
            }
        }
    }

    private fun unregisterStopFromNotifReceiver() {
        if (isStopReceiverRegistered) {
            try {
                unregisterReceiver(stopFromNotifReceiver)
                isStopReceiverRegistered = false
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering stop receiver: ${e.message}")
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: return START_NOT_STICKY

        when (action) {
            ACTION_PLAY_ADHAN -> {
                val soundName  = intent.getStringExtra(EXTRA_SOUND_NAME)  ?: "abdulbaset"
                val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: "الصلاة"
                val volume     = intent.getFloatExtra(EXTRA_VOLUME, 1.0f)
                val playDoaa   = intent.getBooleanExtra(EXTRA_PLAY_DOAA, true)
                val skipAnn    = intent.getBooleanExtra(EXTRA_SKIP_ANNOUNCEMENT, false)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(NOTIF_ID, buildNotification(prayerName, soundName), ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
                } else {
                    startForeground(NOTIF_ID, buildNotification(prayerName, soundName))
                }

                acquireWakeLock()
                isServiceRunning = true
                playAdhan(soundName, volume, playDoaa, prayerName, skipAnn)
                // إظهار شاشة الأذان فوق شاشة القفل — فقط عندما يكون التطبيق مغلقاً
                launchActivityOverLock(prayerName)
                mainHandler.post { 
                    stateListener?.onAdhanStarted()
                }
            }
            ACTION_STOP_ADHAN -> {
                isServiceRunning = false
                stopAdhan()
                sendAdhanStoppedBroadcast()
                mainHandler.post { 
                    stateListener?.onAdhanStopped()
                }
                stopSelf()
            }
            ACTION_PLAY_DUA -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(NOTIF_ID, buildNotification("دعاء ما بعد الأذان", "مشاري العفاسي"), ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
                } else {
                    startForeground(NOTIF_ID, buildNotification("دعاء ما بعد الأذان", "مشاري العفاسي"))
                }
                acquireWakeLock()
                isServiceRunning = true
                playDuaAudio()
            }
            ACTION_UPDATE_VOLUME -> {
                val volume = intent.getFloatExtra(EXTRA_VOLUME, 1.0f)
                updateVolume(volume)
            }
            ACTION_PLAY_VOICE_MESSAGE -> {
                val voiceTitle = intent.getStringExtra(EXTRA_VOICE_TITLE) ?: "رسالة صوتية"
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(NOTIF_ID, buildVoiceNotification(voiceTitle), ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
                } else {
                    startForeground(NOTIF_ID, buildVoiceNotification(voiceTitle))
                }
                // صوت فقط بدون أي إشعار ظاهر: على أندرويد 13+ يُحذف إشعار
                // الخدمة الأمامية فوراً مع بقاء الخدمة تعمل لإكمال التشغيل.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    stopForeground(STOP_FOREGROUND_DETACH)
                }
                acquireWakeLock()
                playVoiceMessage()
            }
            ACTION_PLAY_FRIDAY_REMINDER -> {
                // تشغيل صوت تذكير صلاة الجمعة (أصوات الطيور) قبل 45 دقيقة من الأذان
                val reminderTitle = intent.getStringExtra(EXTRA_VOICE_TITLE) ?: "تذكير صلاة الجمعة"
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(NOTIF_ID, buildVoiceNotification(reminderTitle), ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
                } else {
                    startForeground(NOTIF_ID, buildVoiceNotification(reminderTitle))
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    stopForeground(STOP_FOREGROUND_DETACH)
                }
                acquireWakeLock()
                playFridayReminderAudio()
            }
        }
        return START_NOT_STICKY
    }

    /**
     * إظهار شاشة الأذان فوق شاشة القفل — فقط عندما يكون التطبيق مغلقاً فعلاً.
     * لا تظهر أبداً والتطبيق مفتوح (في المقدمة) أو في الخلفية (الشاشة مفتوحة وغير مقفلة).
     */
    private fun launchActivityOverLock(prayerName: String) {
        try {
            // 1) التطبيق مفتوح في المقدمة؟ لا نظهر الشاشة
            if (MainActivity.isAppInForeground) {
                Log.d(TAG, "App is in foreground — skipping lock screen")
                return
            }

            // 2) التطبيق في الخلفية والشاشة مفتوحة وغير مقفلة؟ لا نظهر الشاشة
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            val km = getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
            val screenOn = pm.isInteractive
            val keyguardLocked = km.isKeyguardLocked
            if (screenOn && !keyguardLocked) {
                Log.d(TAG, "App in background (screen on & unlocked) — skipping lock screen")
                return
            }

            // 3) التطبيق مغلق (الشاشة مقفلة أو مطفأة) → نظهر شاشة الأذان
            Log.d(TAG, "App closed — launching lock screen for $prayerName")
            val intent = Intent(this, AdhanLockScreenActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra(AdhanLockScreenActivity.EXTRA_PRAYER_NAME, prayerName)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error launching lock screen: ${e.message}")
        }
    }

    private fun updateVolume(volume: Float) {
        currentVolume = volume
        try {
            mediaPlayer?.setVolume(volume, volume)
            doaaPlayer?.setVolume(volume, volume)
            voicePlayer?.setVolume(volume, volume)
            voiceMsgPlayer?.setVolume(volume, volume)
            Log.d(TAG, "Dynamic volume update: $volume")
        } catch (e: Exception) {
            Log.e(TAG, "Error updating volume: ${e.message}")
        }
    }

    // ─────────────────────────────────────────────────────────────
    private fun isPreAdhanVoiceEnabled(context: Context): Boolean {
        return try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.getBoolean("flutter.preAdhanVoiceEnabled", true)
        } catch (e: Exception) {
            Log.e(TAG, "Error reading preAdhanVoiceEnabled: ${e.message}")
            true
        }
    }

    private fun isVibrationEnabled(context: Context): Boolean {
        return try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.getBoolean("flutter.vibrateOnAdhan", true)
        } catch (e: Exception) {
            Log.e(TAG, "Error reading vibrateOnAdhan: ${e.message}")
            true
        }
    }

    private fun playAdhan(soundName: String, volume: Float, playDoaa: Boolean, prayerName: String, skipAnnouncement: Boolean = false) {
        if (mediaPlayer?.isPlaying == true) {
            Log.d(TAG, "Adhan MediaPlayer is already playing! Skipping duplicate start request.")
            return
        }
        currentPrayerName = prayerName
        stopAdhan()
        requestAudioFocus()
        Log.d(TAG, "Playing adhan directly.")
        playAdhanMediaPlayer(soundName, volume, playDoaa)
    }

    private fun playAdhanMediaPlayer(soundName: String, volume: Float, playDoaa: Boolean) {
        val resId = when (soundName) {
            "minshawi" -> R.raw.minshawi
            "al_luhaidan" -> R.raw.al_luhaidan
            "makkah", "alharm_almakke" -> R.raw.makkah
            "madinah" -> R.raw.madinah
            "sherif_mostafa", "sherif" -> R.raw.sherif_mostafa
            "hamd_deghrer" -> R.raw.hamd_deghrer
            "mohamed_dokale" -> R.raw.mohamed_dokale
            else -> R.raw.abdulbaset
        }

        currentVolume = volume

        try {
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setDataSource(applicationContext, android.net.Uri.parse(
                    "android.resource://$packageName/$resId"
                ))
                setVolume(volume, volume)
                prepare()
                setOnCompletionListener {
                    Log.d(TAG, "Adhan completed. Releasing player and playing Dua in 2 seconds.")
                    try {
                        it.stop()
                        it.release()
                    } catch (e: Exception) {}
                    mediaPlayer = null

                    // إغلاق شاشة الأذان عند نهاية صوت الأذان
                    sendAdhanStoppedBroadcast()
                    showDuaAfterDelay(playDoaa)
                }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error: what=$what extra=$extra")
                    releaseResources()
                    stopSelf()
                    true
                }
                start()
                Log.d(TAG, "Playing adhan: $soundName (resId=$resId)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error playing adhan: ${e.message}", e)
            stopSelf()
        }
    }

    private fun showDuaAfterDelay(playDoaa: Boolean) {
        pendingDoaaRunnable?.let { mainHandler.removeCallbacks(it) }
        val runnable = Runnable {
            pendingDoaaRunnable = null
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            val duaTitle = "دعاء بعد الأذان"
            // دعاء ما بعد الأذان الثابت الكامل دائماً
            val duaBody = "اللهم رب هذه الدعوة التامة، والصلاة القائمة، آتِ محمداً الوسيلة والفضيلة، وابعثه مقاماً محموداً الذي وعدته"
            try {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.edit().remove("flutter.remote_post_prayer_dua_text").apply()
            } catch (e: Exception) {}

            val largeIcon = try {
                BitmapFactory.decodeResource(resources, R.drawable.notif_logo)
            } catch (e: Exception) {
                null
            }

            val notification = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notif_mosque)
                .setColor(CARD_BLACK)   // خلفية البطاقة: أسود
                .setColorized(true)     // خلفية الإشعار نفسها كحلية ملكية
                .setContentTitle(duaTitle)
                .setContentText(duaBody)
                .setLargeIcon(largeIcon)
                // ── البطاقة المخصّصة: هي الإشعار كله بلا تكرار أو إطار داخلي ──
                .setCustomContentView(
                    PrayerNotificationCard.collapsed(
                        this, duaTitle, duaBody, PrayerNotificationCard.clockText()
                    )
                )
                .setCustomHeadsUpContentView(
                    PrayerNotificationCard.collapsed(
                        this, duaTitle, duaBody, PrayerNotificationCard.clockText()
                    )
                )
                .setCustomBigContentView(
                    PrayerNotificationCard.expanded(
                        this, duaTitle, duaBody, PrayerNotificationCard.clockText()
                    )
                )
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .setTimeoutAfter(10 * 60 * 1000L) // يختفي بعد 10 دقائق
                .build()

            nm.notify(NOTIF_ID + 600, notification)
            
            val shouldPlayDoaa = try {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.getBoolean("flutter.duaEnabled", true)
            } catch (e: Exception) {
                playDoaa
            }

            if (shouldPlayDoaa) {
                playDuaAudio()
            } else {
                releaseResources()
                stopSelf()
            }
        }
        pendingDoaaRunnable = runnable
        mainHandler.postDelayed(runnable, DOAA_DELAY_MS)
    }

    private fun playDuaAudio() {
        try {
            requestAudioFocus()
            val vol = if (currentVolume > 0f) currentVolume else 1.0f
            
            try {
                doaaPlayer?.stop()
                doaaPlayer?.release()
            } catch (_: Exception) {}
            doaaPlayer = null

            val player = MediaPlayer.create(applicationContext, R.raw.doaa_after_azan)
            if (player == null) {
                Log.e(TAG, "MediaPlayer.create returned null for doaa_after_azan")
                releaseResources()
                stopSelf()
                return
            }

            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            player.setVolume(vol, vol)
            player.setOnCompletionListener {
                Log.d(TAG, "Dua completed. Stopping service.")
                releaseResources()
                stopSelf()
            }
            player.setOnErrorListener { _, what, extra ->
                Log.e(TAG, "Dua MediaPlayer error: what=$what extra=$extra")
                releaseResources()
                stopSelf()
                true
            }
            player.start()
            doaaPlayer = player
            Log.d(TAG, "Playing Dua audio successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error playing Dua audio: ${e.message}", e)
            releaseResources()
            stopSelf()
        }
    }

    /**
     * تشغيل الرسالة الصوتية (voice_message.mp3) عند وقت الشروق وقبل المغرب بـ 20 دقيقة.
     * — تُشغَّل على قناة الوسائط مثل الأذان وتعمل حتى مع إغلاق التطبيق.
     */
    private fun playVoiceMessage() {
        try {
            voiceMsgPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setDataSource(applicationContext, android.net.Uri.parse(
                    "android.resource://$packageName/${R.raw.voice_message}"
                ))
                setVolume(currentVolume, currentVolume)
                prepare()
                setOnCompletionListener {
                    Log.d(TAG, "Voice message completed. Stopping service.")
                    releaseResources()
                    stopSelf()
                }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "Voice message MediaPlayer error: what=$what extra=$extra")
                    releaseResources()
                    stopSelf()
                    true
                }
                start()
                Log.d(TAG, "Playing voice message")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error playing voice message: ${e.message}", e)
            releaseResources()
            stopSelf()
        }
    }

    private fun releaseVoicePlayer() {
        try {
            voicePlayer?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
            voicePlayer = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing voice player: ${e.message}")
        }
    }

    /**
     * تشغيل صوت تذكير صلاة الجمعة (أصوات الطيور) قبل 45 دقيقة من الأذان
     */
    private fun playFridayReminderAudio() {
        try {
            fridayReminderPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setDataSource(applicationContext, android.net.Uri.parse(
                    "android.resource://$packageName/${R.raw.sound_of_birds}"
                ))
                setVolume(1.0f, 1.0f)
                prepare()
                setOnCompletionListener {
                    Log.d(TAG, "Friday reminder audio completed. Stopping service.")
                    releaseResources()
                    stopSelf()
                }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "Friday reminder MediaPlayer error: what=$what extra=$extra")
                    releaseResources()
                    stopSelf()
                    true
                }
                start()
                Log.d(TAG, "Playing Friday reminder audio (sound_of_birds)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error playing Friday reminder audio: ${e.message}", e)
            releaseResources()
            stopSelf()
        }
    }

    private fun stopAdhan() {
        pendingDoaaRunnable?.let { mainHandler.removeCallbacks(it) }
        pendingDoaaRunnable = null

        releaseVoicePlayer()
        try {
            mediaPlayer?.let {
                it.setOnCompletionListener(null)
                if (it.isPlaying) it.stop()
                it.release()
            }
            mediaPlayer = null

            doaaPlayer?.let {
                it.setOnCompletionListener(null)
                if (it.isPlaying) it.stop()
                it.release()
            }
            doaaPlayer = null

            voiceMsgPlayer?.let {
                it.setOnCompletionListener(null)
                if (it.isPlaying) it.stop()
                it.release()
            }
            voiceMsgPlayer = null

            fridayReminderPlayer?.let {
                it.setOnCompletionListener(null)
                if (it.isPlaying) it.stop()
                it.release()
            }
            fridayReminderPlayer = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping: ${e.message}")
        }
        abandonAudioFocus()
        releaseWakeLock()
    }

    // ─────────────────────────────────────────────────────────────
    private fun releaseResources() {
        isServiceRunning = false
        stopAdhan()
        sendAdhanStoppedBroadcast()
        mainHandler.post { 
            stateListener?.onAdhanStopped()
        }
    }

    // ─────────────────────────────────────────────────────────────
    override fun onDestroy() {
        super.onDestroy()
        stopAdhan()
        unregisterStopFromNotifReceiver()
        stopForeground(STOP_FOREGROUND_REMOVE)
        // إغلاق شاشة الأذان في كل مسارات التدمير (حتى لو أنهت النظام الخدمة قسرياً).
        // الشرط يمنع الإرسال المكرر: كل مسارات الإيقاف المنظمة تُسقط isServiceRunning قبل stopSelf().
        if (isServiceRunning) {
            sendAdhanStoppedBroadcast()
        }
    }

    // ─────────────────────────────────────────────────────────────
    // WakeLock: يمنع الجهاز من النوم أثناء الأذان ويضيء الشاشة عند القفل
    // ─────────────────────────────────────────────────────────────
    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        @Suppress("DEPRECATION")
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            "AdhanForegroundService::WakeLock"
        ).apply {
            acquire(10 * 60 * 1000L) // 10 دقائق كحد أقصى
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let { if (it.isHeld) it.release() }
            wakeLock = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing wake lock: ${e.message}")
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Audio Focus
    // ─────────────────────────────────────────────────────────────
    private fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setOnAudioFocusChangeListener { }
                .build()
            audioManager?.requestAudioFocus(request)
            audioFocusRequest = request
        } else {
            @Suppress("DEPRECATION")
            audioManager?.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        }
    }

    private fun abandonAudioFocus() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                audioManager?.abandonAudioFocus(null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error abandoning audio focus: ${e.message}")
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Notification
    // ─────────────────────────────────────────────────────────────
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // تحقق مما إذا كانت القناة موجودة
            val existingChannel = nm.getNotificationChannel(NOTIF_CHANNEL_ID)
            if (existingChannel == null) {
                val channel = NotificationChannel(
                    NOTIF_CHANNEL_ID,
                    "الأذان (خلفية)",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "قناة تشغيل صوت الأذان في الخلفية"
                    setSound(null, null)
                    enableVibration(false) // تم إيقاف الاهتزاز هنا بناءً على طلب المستخدم لتجنب صوت الهزاز المزعج في البداية
                    enableLights(true)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    setShowBadge(true)
                }
                nm.createNotificationChannel(channel)
            }
        }
    }

    /**
     * بناء إشعار الخدمة الأمامية — يتيح فتح التطبيق وإيقاف الأذان باللمس أثناء وجود التطبيق في الخلفية أو الشاشة مغلقة.
     */
    private fun buildNotification(prayerName: String, soundName: String = "abdulbaset"): Notification {
        val isPreview = prayerName == "معاينة" || prayerName.isEmpty()
        
        val title = if (isPreview) {
            "🔊 تجربة الصوت"
        } else {
            "صلاة $prayerName"
        }
        
        val content = if (isPreview) {
            "جارٍ تشغيل معاينة صوت الأذان"
        } else {
            "حان الآن موعد أذان صلاة $prayerName"
        }

        // 1. Intent لفتح التطبيق عند لمس الإشعار
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // 2. Intent لزر "إيقاف الأذان" في الإشعار — يعمل حتى عند إغلاق التطبيق تماماً
        val stopIntent = Intent(ACTION_NOTIF_STOP).apply {
            setPackage(packageName)
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            this,
            1001,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // قالب النظام الرسمي — عنوان موحد في الأعلى وإظهار الجملة كاملة دون أي نقص
        val builder = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notif_mosque) // مسجد أبيض نقّي — لوغو مخصص واحد
            .setColor(CARD_BLACK)   // خلفية البطاقة: أسود
            .setColorized(true)     // خلفية الإشعار نفسها كحلية ملكية
            .setContentTitle(title)
            .setContentText(content)
            // ── البطاقة المخصّصة: هي الإشعار كله، بلا زخرفة نظام فوقها ──
            //    (ولذلك تُمرّر حبّة إيقاف داخل البطاقة: أزرار النظام لا تُرسم
            //    مع الإشعار المخصّص، والمطوية تعرضها بدل وقت الصلاة.)
            .setCustomContentView(
                PrayerNotificationCard.collapsed(
                    this, title, content, PrayerNotificationCard.clockText(),
                    actionLabel = PrayerNotificationCard.STOP_LABEL_COMPACT,
                    actionIntent = if (isPreview) null else stopPendingIntent
                )
            )
            .setCustomHeadsUpContentView(
                PrayerNotificationCard.collapsed(
                    this, title, content, PrayerNotificationCard.clockText(),
                    actionLabel = PrayerNotificationCard.STOP_LABEL_COMPACT,
                    actionIntent = if (isPreview) null else stopPendingIntent
                )
            )
            //    وبلا نصّ تذييل عن قصد: جملة «يمكنك إيقاف الأذان في أي وقت من
            //    حبّة الإيقاف» كانت تكراراً لنصّ الحبّة نفسها، فحُذفت وصفّ الإجراء
            //    وحده يبقى (مع الفاصل فوقه)، وتبقى الحبّة في نهاية الصفّ.
            .setCustomBigContentView(
                PrayerNotificationCard.expanded(
                    this, title, content, PrayerNotificationCard.clockText(),
                    actionLabel = PrayerNotificationCard.STOP_LABEL_FULL,
                    actionIntent = if (isPreview) null else stopPendingIntent
                )
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setContentIntent(contentPendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            // ── زر إيقاف الأذان انتقل **داخل** البطاقة المخصّصة ──
            //    (حبّة مربوطة بنفس stopPendingIntent): أزرار النظام لا تُرسم
            //    مع إشعار مخصّص، فلو أُضيف هنا لن يظهر شيئاً أو يتكرّر الزر.
            //    ويبقى الإيقاف يعمل بلا فتح التطبيق — عبر نفس المتلقي.

        // 3. Full-Screen Intent — الآلية الرسمية والموثوقة على Android 10+
        //    لعرض شاشة إيقاف الأذان فوق شاشة القفل تلقائياً عندما يكون التطبيق مغلقاً.
        //    (عندما تكون الشاشة مفتوحة وغير مقفلة يظهر الإشعار كـ Heads-up فقط —
        //    أي لا تظهر الشاشة الكاملة أبداً والتطبيق مفتوح أو في الخلفية.)
        if (!isPreview) {
            // Android 14+: قد يتطلب إذن "المنبهات والتذكيرات" الخاص — نسجّل حالة الإذن للتشخيص
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                try {
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    Log.d(TAG, "canUseFullScreenIntent (Android 14+): ${nm.canUseFullScreenIntent()}")
                } catch (e: Exception) {
                    Log.e(TAG, "Error checking full-screen intent: ${e.message}")
                }
            }
            val lockScreenIntent = Intent(this, AdhanLockScreenActivity::class.java).apply {
                putExtra(AdhanLockScreenActivity.EXTRA_PRAYER_NAME, prayerName)
            }
            val fullScreenPendingIntent = PendingIntent.getActivity(
                this,
                2002,
                lockScreenIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder.setFullScreenIntent(fullScreenPendingIntent, true)
        }

        return builder.build()
    }

    /**
     * إشعار الخدمة الأمامية للرسالة الصوتية (وقت الشروق / قبل المغرب بـ 20 دقيقة)
     * — بدون شاشة أذان، مع زر إيقاف يعمل حتى مع إغلاق التطبيق.
     */
    private fun buildVoiceNotification(voiceTitle: String): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notif_mosque)
            .setColor(CARD_BLACK)   // خلفية البطاقة: أسود
            .setColorized(true)     // خلفية الإشعار نفسها كحلية ملكية
            .setContentTitle("أوقات الصلاة")
            .setContentText(voiceTitle)
            // ── البطاقة المخصّصة: هي الإشعار كله بلا تكرار أو إطار داخلي ──
            .setCustomContentView(
                PrayerNotificationCard.collapsed(
                    this, "أوقات الصلاة", voiceTitle, PrayerNotificationCard.clockText()
                )
            )
            .setCustomHeadsUpContentView(
                PrayerNotificationCard.collapsed(
                    this, "أوقات الصلاة", voiceTitle, PrayerNotificationCard.clockText()
                )
            )
            .setCustomBigContentView(
                PrayerNotificationCard.expanded(
                    this, "أوقات الصلاة", voiceTitle, PrayerNotificationCard.clockText()
                )
            )
            // إشعار صامت تماماً: لا صوت ولا اهتزاز ولا وميض — صوت فقط
            .setSound(null)
            .setSilent(true)
            .setVibrate(null)
            .setDefaults(0)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setContentIntent(contentPendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .build()
    }
}
