package com.example.muezzin_libya_app

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * AdhanLockScreenActivity
 *
 * شاشة الأذان فوق شاشة القفل — تظهر فقط عندما يكون التطبيق مغلقاً:
 * خلفية كحلية ملكية + نص أبيض في الوسط «حان الآن موعد أذان...»
 * + زر أزرق كلاسيكي «إيقاف الأذان».
 *
 * تنغلق تلقائياً عند نهاية الأذان (ADHAN_STOPPED) أو عند ضغط زر «إيقاف الأذان».
 */
class AdhanLockScreenActivity : Activity() {

    companion object {
        private const val TAG = "AdhanLockScreenActivity"
        const val EXTRA_PRAYER_NAME = "prayer_name"

        // الألوان المطلوبة — كحلي ملكي صريح (Royal Navy)
        private const val COLOR_NAVY_TOP = 0xFF002855.toInt()     // كحلي ملكي (Royal Navy)
        private const val COLOR_NAVY_BOTTOM = 0xFF001233.toInt()  // كحلي ملكي عميق
        private const val COLOR_BLUE = 0xFF0047AB.toInt()         // أزرق كلاسيكي
        private const val COLOR_WHITE = Color.WHITE
        private const val COLOR_GOLD = 0xFFFFD700.toInt()
    }

    private var adhanStoppedReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // إبقاء الشاشة مضيئة وإظهار فوق شاشة القفل
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )

        val prayerName = intent?.getStringExtra(EXTRA_PRAYER_NAME) ?: ""
        setContentView(buildUi(prayerName))
        registerAdhanStoppedReceiver()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // إعادة بناء الواجهة إذا أُعيد فتح الشاشة لصلاة أخرى (launchMode=singleTask)
        val prayerName = intent.getStringExtra(EXTRA_PRAYER_NAME) ?: ""
        setContentView(buildUi(prayerName))
    }

    private fun buildUi(prayerName: String): View {
        // الخلفية: تدرج كحلي ملكي
        val navyBackground = GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            intArrayOf(COLOR_NAVY_TOP, COLOR_NAVY_BOTTOM)
        )

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(32), dp(32), dp(32), dp(32))
            background = navyBackground
            // لمس أي مكان في الشاشة يوقف الأذان نهائياً
            setOnTouchListener { _, _ ->
                stopAdhanAndClose()
                true
            }
        }

        // شعار "حان موعد الأذان": مربع مستدير الحواف بخلفية كحلية ملكية وإطار خارجي رقيق جداً أبيض اللون
        val logoCardBackground = GradientDrawable().apply {
            setColor(COLOR_NAVY_TOP)
            cornerRadius = dp(18).toFloat()
            setStroke(dp(1), COLOR_WHITE) // إطار أبيض رقيق جداً
        }

        val logoCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(20), dp(20), dp(20), dp(20))
            background = logoCardBackground
        }

        val mosqueIcon = TextView(this).apply {
            text = "🕌"
            textSize = 54f
            gravity = Gravity.CENTER
        }
        logoCard.addView(mosqueIcon, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))

        // العنوان: حان الآن موعد أذان...
        val title = TextView(this).apply {
            text = "حان الآن موعد أذان..."
            textSize = 28f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(COLOR_WHITE)
            gravity = Gravity.CENTER
            setTextDirection(View.TEXT_DIRECTION_RTL)
        }
        logoCard.addView(title, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = dp(12) })

        root.addView(logoCard, LinearLayout.LayoutParams(
            dp(280),
            dp(200)
        ).apply { topMargin = dp(10) })

        // اسم الصلاة (إن وُجد)
        if (prayerName.isNotBlank() && prayerName != "معاينة") {
            val prayer = TextView(this).apply {
                text = "صلاة $prayerName"
                textSize = 24f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(COLOR_GOLD)
                gravity = Gravity.CENTER
                setTextDirection(View.TEXT_DIRECTION_RTL)
            }
            root.addView(prayer, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(12) })
        }

        // زر إيقاف الأذان — أزرق كلاسيكي بنص أبيض في الوسط
        val stopButton = Button(this).apply {
            text = "إيقاف الأذان"
            textSize = 22f
            typeface = Typeface.DEFAULT_BOLD
            setTextColor(COLOR_WHITE)
            isAllCaps = false
            gravity = Gravity.CENTER
            setTextDirection(View.TEXT_DIRECTION_RTL)
            background = GradientDrawable().apply {
                setColor(COLOR_BLUE)
                cornerRadius = dp(28).toFloat()
            }
            setOnClickListener { stopAdhanAndClose() }
        }
        root.addView(stopButton, LinearLayout.LayoutParams(dp(250), dp(64)).apply {
            topMargin = dp(44)
        })

        // تلميح أسفل الشاشة: المس أي مكان للإيقاف
        val hint = TextView(this).apply {
            text = "اضغط في أي مكان لإيقاف الأذان"
            textSize = 14f
            typeface = Typeface.DEFAULT
            setTextColor(COLOR_WHITE)
            alpha = 0.85f
            gravity = Gravity.CENTER
            setTextDirection(View.TEXT_DIRECTION_RTL)
        }
        root.addView(hint, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = dp(30) })

        return root
    }

    /**
     * زر «إيقاف الأذان»: يرسل نفس أمر الإيقاف الذي يستخدمه زر الإشعار
     * (يعمل حتى مع التطبيق المغلق)، ثم يغلق الشاشة.
     */
    private fun stopAdhanAndClose() {
        Log.d(TAG, "Stop button pressed -> stopping adhan")
        try {
            val stopIntent = Intent(AdhanForegroundService.ACTION_NOTIF_STOP).apply {
                setPackage(packageName)
            }
            sendBroadcast(stopIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Error sending stop broadcast: ${e.message}")
        }
        finish()
    }

    private fun registerAdhanStoppedReceiver() {
        val filter = IntentFilter(AdhanForegroundService.ACTION_ADHAN_STOPPED)
        adhanStoppedReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                Log.d(TAG, "Adhan stopped -> closing lock screen")
                finish()
            }
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(adhanStoppedReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(adhanStoppedReceiver, filter)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error registering stopped receiver: ${e.message}")
        }
    }

    private fun unregisterAdhanStoppedReceiver() {
        try {
            adhanStoppedReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {
        }
        adhanStoppedReceiver = null
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        // منع الخروج دون إيقاف الأذان
        stopAdhanAndClose()
    }

    override fun onDestroy() {
        unregisterAdhanStoppedReceiver()
        super.onDestroy()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
