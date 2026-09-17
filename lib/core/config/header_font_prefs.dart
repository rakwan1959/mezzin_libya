import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مفتاح حفظ تفضيل «حجم خط العناوين» في SharedPreferences.
const String kHeaderFontAdjustmentKey = 'headerFontAdjustment';

/// الحجم الأساسي (العادي) لعناوين النوافذ/اللوحات — قبل أي تصغير.
const double kHeaderFontBaseSize = 18.0;

/// التعديل العمومي على حجم خط العناوين (بالبكسل).
///
/// بدل ترميز "-3" بشكل ثابت في كل شاشة، يُقرأ هذا التعديل من الإعدادات
/// (الافتراضي -3 = نفس الشكل الحالي) ويُطبَّق على كل عنوان يستخدمه.
/// القيم المتاحة: -3 (تصغير) / 0 (عادي) / +3 (تكبير).
class HeaderFontPrefs {
  HeaderFontPrefs._();

  /// قيمة التعديل الحالية — بثّ مباشر للتحديث الفوري في كل الشاشات.
  static final ValueNotifier<int> adjustment = ValueNotifier<int>(-3);

  /// تحميل القيمة المحفوظة عند تشغيل التطبيق.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(kHeaderFontAdjustmentKey);
      if (saved != null && (saved == -3 || saved == 0 || saved == 3)) {
        adjustment.value = saved;
      }
    } catch (_) {
      // يبقى الافتراضي -3 عند أي خطأ.
    }
  }

  /// حفظ القيمة وتحديث كل الشاشات فوراً.
  static Future<void> save(int value) async {
    adjustment.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kHeaderFontAdjustmentKey, value);
    } catch (_) {}
  }

  /// حجم خط العنوان النهائي بعد تطبيق التعديل العمومي.
  static double sized(double baseSize) => baseSize + adjustment.value;

  /// اسم الخيار الحالي (للعرض في الإعدادات).
  static String currentLabel() => labelOf(adjustment.value);

  static String labelOf(int value) {
    switch (value) {
      case 0:
        return 'عادي';
      case 3:
        return 'تكبير (+3)';
      default:
        return 'تصغير (-3)';
    }
  }
}
