import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// خدمة إدارة إبقاء الشاشة مفتوحة ومضاءة (Keep Screen Awake)
/// تمنع إغلاق أو تعتيم الشاشة بمهلة النظام (Screen Timeout) طالما التطبيق مفتوح
class ScreenWakeService {
  static const String keyKeepScreenOn = 'keep_screen_on';

  /// فحص ما إذا كان خيار إبقاء الشاشة مفعل (افتراضياً: معطل false لتنطفئ الشاشة مع مهلة الموبايل)
  static Future<bool> isKeepScreenOnEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyKeepScreenOn) ?? false;
    } catch (e) {
      debugPrint('ScreenWakeService.isKeepScreenOnEnabled error: $e');
      return false;
    }
  }

  /// تهيئة إبقاء الشاشة مضاءة عند تشغيل التطبيق
  static Future<void> init() async {
    await applyCurrentState();
  }

  /// تطبيق الحالة الحالية بناءً على الإعداد المحفوظ
  static Future<void> applyCurrentState() async {
    try {
      final enabled = await isKeepScreenOnEnabled();
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (e) {
      debugPrint('ScreenWakeService.applyCurrentState error: $e');
    }
  }

  /// تغيير وتخزين حالة إبقاء الشاشة
  static Future<void> setKeepScreenOn(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyKeepScreenOn, enabled);
      if (enabled) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (e) {
      debugPrint('ScreenWakeService.setKeepScreenOn error: $e');
    }
  }
}
