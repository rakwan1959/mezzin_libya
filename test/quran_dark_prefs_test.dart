import 'package:flutter_test/flutter_test.dart';
import 'package:muezzin_libya_app/core/config/quran_dark_prefs.dart';
import 'package:muezzin_libya_app/features/quran/data/datasources/quran_settings_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ── خيار «القرآن الكريم: الوضع الليلي دائماً» ──────────────────────────────
///
/// الشكوى التي وُلد منها: «لماذا يفتح القرآن الوضع النهاري الأبيض؟» — السبب أن
/// القيمة المحفوظة على الجهاز (`READING_MODE`) كانت تسبق الافتراضي في الكود.
/// هذا الخيار (في شاشة الإعدادات ← المظهر) مفعّل افتراضاً ويكتب الوضع الليلي في
/// كل تشغيل، فيفتح القرآن ليلياً دائماً — ويبقى التبديل اليدوي عاملاً في الجلسة.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // الحالة ثابتة (static) بين الاختبارات — تُعاد إلى الافتراضي قبل كل اختبار
    QuranDarkPrefs.alwaysDark.value = true;
  });

  group('الحالة الافتراضية', () {
    test('الخيار مفعّل افتراضاً — القرآن يفتح ليلياً بلا أي إعداد من المستخدم', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await QuranDarkPrefs.load();
      expect(QuranDarkPrefs.enabled, isTrue);
      expect(QuranDarkPrefs.statusLabel(), contains('ليليّة'));
    });

    test('القيمة المحفوظة (مُطفأ) تُقرأ كما هي', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kQuranAlwaysDarkKey: false,
      });
      await QuranDarkPrefs.load();
      expect(QuranDarkPrefs.enabled, isFalse);
      expect(QuranDarkPrefs.statusLabel(), contains('آخر وضع'));
    });
  });

  group('تطبيق الخيار عند بدء التطبيق', () {
    test('مفعّل: يمحو «white» المحفوظة فيفتح القرآن ليلياً', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kQuranReadingModeKey: 'white',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await QuranDarkPrefs.load();

      await QuranDarkPrefs.applyAtStartup(prefs);

      expect(
        QuranSettingsDataSourceImpl(sharedPreferences: prefs).getReadingMode(),
        'black',
      );
    });

    test('مُطفأ: يترك اختيار المستخدم كما هو (لا يفرض الليلي)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kQuranAlwaysDarkKey: false,
        kQuranReadingModeKey: 'white',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await QuranDarkPrefs.load();

      await QuranDarkPrefs.applyAtStartup(prefs);

      expect(
        QuranSettingsDataSourceImpl(sharedPreferences: prefs).getReadingMode(),
        'white',
      );
    });

    test('ليليّة أصلاً: لا كتابة إضافية على القرص', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kQuranReadingModeKey: 'black',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await QuranDarkPrefs.load();

      await QuranDarkPrefs.applyAtStartup(prefs);

      expect(prefs.getString(kQuranReadingModeKey), 'black');
    });
  });

  group('الحفظ من شاشة الإعدادات', () {
    test('التفعيل يكتب الخيار ويحوّل الوضع إلى ليلي فوراً', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kQuranReadingModeKey: 'white',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await QuranDarkPrefs.save(true);

      expect(QuranDarkPrefs.enabled, isTrue);
      expect(prefs.getBool(kQuranAlwaysDarkKey), isTrue);
      expect(prefs.getString(kQuranReadingModeKey), 'black');
    });

    test('الإطفاء يحفظ الخيار فقط ولا يغيّر الوضع الحالي', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kQuranReadingModeKey: 'white',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await QuranDarkPrefs.save(false);

      expect(QuranDarkPrefs.enabled, isFalse);
      expect(prefs.getBool(kQuranAlwaysDarkKey), isFalse);
      // المستخدم يقرأ نهارياً الآن كما اختار
      expect(prefs.getString(kQuranReadingModeKey), 'white');
    });

    test('القيمة تبقى بعد إعادة تحميل التطبيق', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kQuranAlwaysDarkKey: false,
      });
      await QuranDarkPrefs.load();
      expect(QuranDarkPrefs.enabled, isFalse);

      // تشغيل جديد
      await QuranDarkPrefs.load();
      expect(QuranDarkPrefs.enabled, isFalse);
    });
  });
}
