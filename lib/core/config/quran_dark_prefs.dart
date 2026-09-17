import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مفتاح حفظ خيار «القرآن الكريم: الوضع الليلي دائماً» في SharedPreferences.
const String kQuranAlwaysDarkKey = 'quranAlwaysDark';

/// مفتاح الوضع المحفوظ لشاشة القرآن — **نفس** المفتاح الذي يقرأه ويكتبه
/// `QuranSettingsDataSourceImpl` (`READING_MODE`)، فالتفعيل من الإعدادات وقراءة
/// الشاشة يتحدثان عن القيمة نفسها بلا مصدرين متعارضين.
const String kQuranReadingModeKey = 'READING_MODE';

/// «القرآن الكريم: الوضع الليلي دائماً» — خيار في شاشة الإعدادات ← المظهر.
///
/// المشكلة التي وُلد منها: كان الوضع الليلي افتراضياً في الكود، لكن **القيمة
/// المحفوظة على الجهاز** تسبق الافتراضي؛ ومن كتبت نسخة قديمة `white` فيها بقي
/// القرآن يفتح أبيض نهاري بعد كل تحديث مهما تغيّر الافتراضي.
///
/// الحل: خيار صريح **مفعّل افتراضاً** يكتب الوضع الليلي في `READING_MODE` عند
/// كل تشغيل ([applyAtStartup])، فيفتح القرآن ليلياً دائماً. ويبقى التبديل
/// اليدوي للمطالعة النهارية عاملاً أثناء الجلسة (زر الوضع في شريط شاشة القرآن)،
/// فإن أراد المستخدم أن يحتفظ باختياره النهاري أطفأ هذا الخيار فيصير القرآن
/// يفتح على آخر وضع اختاره.
class QuranDarkPrefs {
  QuranDarkPrefs._();

  /// هل الخيار مفعّل؟ بثّ مباشر لتحديث الشاشات فوراً بلا إعادة تشغيل.
  static final ValueNotifier<bool> alwaysDark = ValueNotifier<bool>(true);

  /// الحالة الحالية (مفعّل = يفتح القرآن ليلياً في كل تشغيل).
  static bool get enabled => alwaysDark.value;

  /// تحميل الحالة المحفوظة عند بدء التطبيق.
  ///
  /// الافتراضي **مفعّل** حتى لا يفتح القرآن نهارياً على أي جهاز، إلا إذا أطفأه
  /// المستخدم بنفسه من الإعدادات.
  static Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      alwaysDark.value = prefs.getBool(kQuranAlwaysDarkKey) ?? true;
    } catch (_) {
      alwaysDark.value = true;
    }
  }

  /// حفظ الخيار — وعند التفعيل يُكتب الوضع الليلي **فوراً** أيضاً، فيتغيّر
  /// القرآن في الحال بلا انتظار إعادة تشغيل.
  static Future<void> save(bool value) async {
    alwaysDark.value = value;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kQuranAlwaysDarkKey, value);
      if (value) await prefs.setString(kQuranReadingModeKey, 'black');
    } catch (_) {}
  }

  /// يُستدعى عند بدء التطبيق (من `main.dart`): إن كان الخيار مفعّلاً يُكتب الوضع
  /// الليلي في `READING_MODE`، فيفتح القرآن ليلياً في كل تشغيل.
  ///
  /// لا يكتب شيئاً إن كانت القيمة ليليّة أصلاً (لا كتابة زائدة على القرص).
  static Future<void> applyAtStartup(SharedPreferences prefs) async {
    if (!alwaysDark.value) return;
    if (prefs.getString(kQuranReadingModeKey) == 'black') return;
    await prefs.setString(kQuranReadingModeKey, 'black');
  }

  /// نصّ الحالة للعرض في شاشة الإعدادات.
  static String statusLabel() => enabled
      ? 'شاشة القرآن تفتح ليليّة في كل تشغيل'
      : 'شاشة القرآن تفتح على آخر وضع اخترته';
}
