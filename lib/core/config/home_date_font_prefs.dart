import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مفتاح حفظ تفضيل «حجم خط تاريخ الشاشة الرئيسية» في SharedPreferences.
const String kHomeDateFontAdjustmentKey = 'homeDateFontAdjustment';

/// الحجم الأساسي لخطّ التاريخ الهجري في الشاشة الرئيسية (قبل تعديل المستخدم).
const double kHijriDateBaseFontSize = 15.0;

/// الحجم الأساسي لخطّ التاريخ الميلادي في الشاشة الرئيسية (قبل تعديل المستخدم).
const double kGregorianDateBaseFontSize = 10.0;

/// تعديل المستخدم على خطّ تاريخي الشاشة الرئيسية (الهجري والميلادي).
///
/// إعداد **واحد** يقيس على التاريخين معاً، فلا يبقى أي حجم مكتوب في الشاشة
/// الرئيسية نفسه: [kHijriDateBaseFontSize] و[kGregorianDateBaseFontSize] هما
/// المصدر الوحيد، ومنهما يشتقّ [hijriFontSize] و[gregorianFontSize].
/// والقيم المتاحة هي قيم «حجم خط العناوين» نفسها (-3 / 0 / +3) فلا يتعلّم
/// المستخدم منطقين مختلفين لحجم الخط في التطبيق.
///
/// وزيادة [TextScaleBoost] (+1.5 بكسل) الخاصة بالشاشة الرئيسية تبقى فوق هذه
/// الأحجام كما هي، لأنّها دالة لخط النظام لا لتفضيل التاريخين.
class HomeDateFontPrefs {
  HomeDateFontPrefs._();

  /// القيم المسموح بها — مصدر واحد يقرأه التحقّق عند التحميل.
  static const List<int> options = <int>[-3, 0, 3];

  /// قيمة التعديل الحالية — بثّ مباشر للتحديث الفوري في الشاشة الرئيسية.
  static final ValueNotifier<int> adjustment = ValueNotifier<int>(0);

  /// تحميل القيمة المحفوظة عند تشغيل التطبيق.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(kHomeDateFontAdjustmentKey);
      // أي قيمة خارج المسموح (من نسخة قديمة أو تالفة) تُتجاهل ويبقى الافتراضي
      if (saved != null && options.contains(saved)) {
        adjustment.value = saved;
      }
    } catch (_) {
      // تبقى القيمة الافتراضية (0) عند أي خطأ.
    }
  }

  /// حفظ القيمة وتحديث كل الشاشات فوراً.
  static Future<void> save(int value) async {
    adjustment.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kHomeDateFontAdjustmentKey, value);
    } catch (_) {}
  }

  /// الحجم النهائي لأي أساس بعد تعديل المستخدم.
  static double sized(double baseSize) => baseSize + adjustment.value;

  /// خطّ التاريخ الهجري بعد التعديل.
  static double get hijriFontSize => sized(kHijriDateBaseFontSize);

  /// خطّ التاريخ الميلادي بعد التعديل.
  static double get gregorianFontSize => sized(kGregorianDateBaseFontSize);

  /// اسم الخيار الحالي (للعرض في الإعدادات).
  static String currentLabel() => labelOf(adjustment.value);

  static String labelOf(int value) {
    switch (value) {
      case 3:
        return 'تكبير (+3)';
      case -3:
        return 'تصغير (-3)';
      default:
        return 'عادي';
    }
  }
}
