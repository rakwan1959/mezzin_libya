package com.example.muezzin_libya_app

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log

/**
 * مستقبل إشارات إقلاع الهاتف (BOOT_COMPLETED) وتحديث التطبيق (MY_PACKAGE_REPLACED).
 *
 * - عند إعادة تشغيل الهاتف: يعيد جدولة كافة أوقات الصلاة المخزنة في AlarmManager تلقائياً
 *   دون الحاجة لفتح التطبيق يدوياً.
 * - عند تثبيت تحديث جديد للتطبيق: يمسح كل المنبهات والإشعارات القديمة من النظام فوراً
 *   حتى لا تظهر إشعارات النسخة القديمة بالتصميم القديم بجانب الجديدة —
 *   ثم يعيد التطبيق جدولة كل شيء بالتصميم الجديد عند فتحه.
 */
class AdhanBootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AdhanBootReceiver"
        private const val PREFS_NAME = "ScheduledAlarmsPrefs"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "onReceive: action=$action")

        if (action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            // ── تثبيت تحديث جديد: امسح كل المنبهات والإشعارات القديمة فوراً ──
            // حتى لا تستمر إشعارات النسخة القديمة (بالشعار الملوّن والتصميم القديم)
            // في الظهور. التطبيق يعيد الجدولة بالتصميم الجديد عند فتحه.
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "AdhanBootReceiver::WakeLock")
            wl.acquire(15000L)
            try {
                cancelAllOldAlarms(context)
                clearShownNotifications(context)
                Log.d(TAG, "App updated — old alarms & notifications cleared. New version will reschedule on open.")
            } catch (e: Exception) {
                Log.e(TAG, "Error clearing old alarms on update: ${e.message}", e)
            } finally {
                if (wl.isHeld) wl.release()
            }
            return
        }

        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "AdhanBootReceiver::WakeLock")
            wl.acquire(15000L)

            try {
                rescheduleAlarms(context)
            } catch (e: Exception) {
                Log.e(TAG, "Error rescheduling alarms on boot: ${e.message}", e)
            } finally {
                if (wl.isHeld) wl.release()
            }
        }
    }

    /** إلغاء كل المنبهات النيتف المخزنة (تُستدعى عند تثبيت تحديث جديد). */
    private fun cancelAllOldAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val ids = prefs.getStringSet("alarm_ids", emptySet()) ?: emptySet()
        val editor = prefs.edit()

        for (idStr in ids) {
            val id = idStr.toIntOrNull() ?: continue
            val alarmIntent = Intent(context, AdhanBroadcastReceiver::class.java).apply {
                action = AdhanBroadcastReceiver.ACTION_TRIGGER_ADHAN
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                alarmIntent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
            editor.remove("alarm_data_$id")
        }
        editor.remove("alarm_ids").apply()
        Log.d(TAG, "Cancelled ${ids.size} old scheduled alarms after update.")
    }

    /** مسح الإشعارات المعروضة حالياً من درج الإشعارات. */
    private fun clearShownNotifications(context: Context) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancelAll()
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing shown notifications: ${e.message}")
        }
    }

    private fun rescheduleAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val ids = prefs.getStringSet("alarm_ids", emptySet()) ?: emptySet()
        val now = System.currentTimeMillis()
        val remainingIds = mutableSetOf<String>()

        Log.d(TAG, "Rescheduling ${ids.size} saved alarms after boot...")

        for (idStr in ids) {
            val id = idStr.toIntOrNull() ?: continue
            val dataStr = prefs.getString("alarm_data_$id", null) ?: continue
            
            // البيانات المخزنة بالصيغة: timeMs|prayerName|soundName|adhanMode|playDoaa|isVoiceMessage
            val parts = dataStr.split("|")
            if (parts.size < 5) continue

            val timeMs     = parts[0].toLongOrNull() ?: continue
            val prayerName = parts[1]
            val soundName  = parts[2]
            val adhanMode  = parts[3]
            val playDoaa   = parts[4].toBoolean()
            val isVoiceMessage = parts.getOrNull(5)?.toBoolean() ?: false

            if (timeMs > now) {
                val alarmIntent = Intent(context, AdhanBroadcastReceiver::class.java).apply {
                    action = AdhanBroadcastReceiver.ACTION_TRIGGER_ADHAN
                    putExtra(AdhanBroadcastReceiver.EXTRA_SOUND_NAME,  soundName)
                    putExtra(AdhanBroadcastReceiver.EXTRA_PRAYER_NAME, prayerName)
                    putExtra(AdhanBroadcastReceiver.EXTRA_ADHAN_MODE,  adhanMode)
                    putExtra(AdhanBroadcastReceiver.EXTRA_PLAY_DOAA,   playDoaa)
                    putExtra(AdhanBroadcastReceiver.EXTRA_IS_VOICE_MESSAGE, isVoiceMessage)
                }

                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    id,
                    alarmIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                try {
                    val alarmClockInfo = AlarmManager.AlarmClockInfo(timeMs, pendingIntent)
                    alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                    remainingIds.add(idStr)
                    Log.d(TAG, "Boot rescheduled alarm $id ($prayerName) at $timeMs")
                } catch (e: Exception) {
                    Log.e(TAG, "Error setting alarm $id on boot: ${e.message}")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pendingIntent)
                            remainingIds.add(idStr)
                        } catch (_: Exception) {}
                    }
                }
            } else {
                // انقضى وقت التنبيه، نحذفه من التخزين
                prefs.edit().remove("alarm_data_$id").apply()
            }
        }

        prefs.edit().putStringSet("alarm_ids", remainingIds).apply()
        Log.d(TAG, "Boot rescheduling finished. Active alarms remaining: ${remainingIds.size}")
    }
}
