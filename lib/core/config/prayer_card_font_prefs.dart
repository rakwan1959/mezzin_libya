import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مفتاح حفظ تفضيل «تكبير خط كاردات أوقات الصلاة» في SharedPreferences.
///
/// التفضيل صار **درجة** لا مفتاحاً: تكبير (+2) / عادي (0) / تصغير (−2) — كما
/// هو مطلوب في شاشة الإعدادات ← المظهر.
const String kPrayerCardFontAdjustKey = 'prayerCardFontAdjust';

/// المفتاح القديم (تشغيل/إيقاف) — يُقرأ مرة واحدة للترحيل ثم لا يُستعمل.
const String kPrayerCardFontEnlargedKey = 'prayerCardFontEnlarged';

/// الأحجام الأساسية (العادية) داخل كارد الصلاة — قبل أي تعديل للمستخدم.
///
/// هذه القيم هي **المصدر الوحيد**: كانت مكتوبة في `prayer_times_screen.dart`
/// مباشرةً، وصارت تُقرأ من هنا فيقرأها الكارد عبر [PrayerCardFontPrefs].
const double kPrayerNameBaseFontSize = 11.0;
const double kPrayerTimeBaseFontSize = 12.5;
const double kPrayerPeriodBaseFontSize = 10.0;
const double kPrayerIconBaseSize = 13.0;

/// حدود الدرجة: أكبر تكبير وأكبر تصغير (±2 بكسل).
const int kPrayerCardFontMax = 2;
const int kPrayerCardFontMin = -2;

/// الدرجات المعروضة في الإعدادات (بالترتيب): تكبير ثم عادي ثم تصغير.
const List<int> kPrayerCardFontOptions = <int>[
  kPrayerCardFontMax,
  0,
  kPrayerCardFontMin,
];

/// أدنى مقاس للأيقونة حتى لا تتلاشى عند التصغير.
const double kPrayerIconMinSize = 11.0;

/// أدنى حجم خط بعد التصغير — حاجز أمان ضد أي قيمة شاذة.
const double kPrayerMinFontSize = 7.0;

/// درجة «تكبير خط كاردات أوقات الصلاة» (الاسم والوقت وحرف الفترة والأيقونة).
///
/// كانت مفتاحاً (تشغيل/إيقاف) بمقدار +3، وصارت **ثلاث درجات صريحة**:
///   • `+2` تكبير  • `0` عادي (الافتراضي)  • `−2` تصغير
///
/// والتفضيل يُحفظ فيبقى كما تركه المستخدم عند كل تشغيل، ويُبَثّ عبر
/// [ValueNotifier] فيتحدّث الكارد فوراً بلا إعادة تشغيل (انظر
/// `ValueListenableBuilder` في شريط الكاردات).
///
/// ملاحظة: زيادة [TextScaleBoost] (+1.5) الخاصة بالشاشة الرئيسية تبقى فوق هذه
/// الأحجام كما هي، لأنّها دالة لخط النظام لا لهذا التفضيل.
class PrayerCardFontPrefs {
  PrayerCardFontPrefs._();

  /// الدرجة الحالية — بثّ مباشر للتحديث الفوري في الكاردات.
  static final ValueNotifier<int> adjustment = ValueNotifier<int>(0);

  /// الدرجات المعروضة في الإعدادات.
  static List<int> get options => kPrayerCardFontOptions;

  /// أي رقم → أقرب درجة مسموحة (‏±2 أو 0)، فلا تدخل قيمة شاذة إلى الأحجام.
  static int normalize(int value) {
    if (value >= kPrayerCardFontMax) return kPrayerCardFontMax;
    if (value <= kPrayerCardFontMin) return kPrayerCardFontMin;
    return 0;
  }

  /// تحميل الحالة المحفوظة عند تشغيل التطبيق (+ ترحيل المفتاح القديم).
  static Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final int? saved = prefs.getInt(kPrayerCardFontAdjustKey);
      if (saved != null) {
        adjustment.value = normalize(saved);
        return;
      }

      // ترحيل نسخة قديمة استعملت مفتاح تشغيل/إيقاف: «مشغّل» يعني تكبيراً (+2).
      if (prefs.getBool(kPrayerCardFontEnlargedKey) == true) {
        adjustment.value = kPrayerCardFontMax;
      }
    } catch (_) {
      // تبقى القيمة الافتراضية (عادي) عند أي خطأ.
    }
  }

  /// حفظ الدرجة وتحديث الكاردات فوراً.
  static Future<void> save(int value) async {
    final int clamped = normalize(value);
    adjustment.value = clamped;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kPrayerCardFontAdjustKey, clamped);
    } catch (_) {}
  }

  /// الحجم النهائي لأي أساس بعد تطبيق الدرجة.
  static double sized(double baseSize) {
    final double v = baseSize + adjustment.value;
    return v < kPrayerMinFontSize ? kPrayerMinFontSize : v;
  }

  /// خطّ اسم الصلاة.
  static double get nameFontSize => sized(kPrayerNameBaseFontSize);

  /// خطّ وقت الصلاة.
  static double get timeFontSize => sized(kPrayerTimeBaseFontSize);

  /// خطّ حرف الفترة (ص/م).
  static double get periodFontSize => sized(kPrayerPeriodBaseFontSize);

  /// مقاس أيقونة الصلاة — لا ينزل تحت [kPrayerIconMinSize].
  static double get iconSize {
    final double v = kPrayerIconBaseSize + adjustment.value;
    return v < kPrayerIconMinSize ? kPrayerIconMinSize : v;
  }

  /// نصّ الحالة للعرض في الإعدادات.
  static String currentLabel() => labelOf(adjustment.value);

  /// اسم الدرجة كما يُعرض في القائمة وفي سطر الحالة.
  static String labelOf(int value) {
    switch (normalize(value)) {
      case kPrayerCardFontMax:
        return 'تكبير (+$kPrayerCardFontMax)';
      case kPrayerCardFontMin:
        return 'تصغير (−${-kPrayerCardFontMin})';
      default:
        return 'عادي (0)';
    }
  }
}
