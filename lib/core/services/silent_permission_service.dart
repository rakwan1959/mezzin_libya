import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// SilentPermissionService
///
/// تطلب هذه الخدمة صلاحيات الأذان والإشعارات بشكل هادئ تلقائياً عند أول
/// فتح للتطبيق فقط — بدون أي شاشة مخصصة أو مقاطعة للمستخدم.
///
/// الصلاحيات التي تُطلب:
/// 1. الإشعارات (POST_NOTIFICATIONS) — أندرويد 13+
/// 2. المنبهات الدقيقة (SCHEDULE_EXACT_ALARM)
/// 3. استثناء تحسين البطارية (IGNORE_BATTERY_OPTIMIZATIONS)
/// 4. شاشة الأذان فوق القفل (USE_FULL_SCREEN_INTENT) — أندرويد 14+
/// 5. الموقع (ACCESS_FINE_LOCATION)
/// ─────────────────────────────────────────────────────────────────────────────
class SilentPermissionService {
  static const _doneKey = 'silentPermissionRequested_v1';

  static const _adhanChannel =
      MethodChannel('com.example.muezzin_libya_app/adhan');
  static const _batteryChannel =
      MethodChannel('com.example.muezzin_libya_app/battery');

  /// استدعِ هذه الدالة مرة واحدة عند بدء التطبيق.
  /// تفحص إذا سبق طلب الصلاحيات؛ إذا لم يسبق تطلبها بهدوء.
  static Future<void> requestIfNeeded() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyRequested = prefs.getBool(_doneKey) ?? false;
      if (alreadyRequested) {
        debugPrint('SilentPermissionService: already requested — skipping');
        return;
      }

      debugPrint('SilentPermissionService: requesting permissions silently…');

      // 1. صلاحية الإشعارات (أندرويد 13+)
      try {
        await Permission.notification.request();
      } catch (e) {
        debugPrint('SilentPermissionService: notification error: $e');
      }

      // 2. المنبهات الدقيقة
      try {
        await Permission.scheduleExactAlarm.request();
      } catch (e) {
        debugPrint('SilentPermissionService: exact alarm error: $e');
      }

      // 3. استثناء تحسين البطارية
      try {
        await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
      } catch (_) {
        try {
          await Permission.ignoreBatteryOptimizations.request();
        } catch (e) {
          debugPrint('SilentPermissionService: battery opt error: $e');
        }
      }

      // 4. Full Screen Intent (شاشة الأذان فوق القفل) — أندرويد 14+
      try {
        await _adhanChannel.invokeMethod('requestFullScreenIntentPermission');
      } catch (e) {
        debugPrint('SilentPermissionService: full screen intent error: $e');
      }

      // 5. الموقع — يظهر حوار النظام الرسمي
      try {
        await Permission.location.request();
      } catch (e) {
        debugPrint('SilentPermissionService: location error: $e');
      }

      // حفظ أن الطلب تم لعدم التكرار
      await prefs.setBool(_doneKey, true);
      debugPrint('SilentPermissionService: done — all permissions requested');
    } catch (e) {
      debugPrint('SilentPermissionService: unexpected error: $e');
    }
  }
}
