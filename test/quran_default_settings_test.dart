import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:muezzin_libya_app/core/theme/glass_theme.dart';
import 'package:muezzin_libya_app/features/quran/data/datasources/quran_settings_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// الإعدادات الافتراضية عند أول تشغيل للتطبيق:
///   1. شاشة سور القرآن تفتح على الوضع الليلي (أسود).
///   2. الخط الافتراضي أميري.
///   3. خلفية الشاشة الرئيسية سوداء (وضع «أسود» أغمق الأوضاع فعلاً).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QuranSettingsDataSourceImpl settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    settings = QuranSettingsDataSourceImpl(
      sharedPreferences: await SharedPreferences.getInstance(),
    );
  });

  group('الإعدادات الافتراضية لأول تشغيل', () {
    test('وضع القراءة الافتراضي ليلي (أسود)', () {
      expect(settings.getReadingMode(), 'black');
    });

    test('الخط الافتراضي أميري', () {
      expect(settings.getFontFamily(), 'QuranAmiriRegular');
    });

    test('بقية الإعدادات الافتراضية مستقرة', () {
      expect(settings.getFontSize(), 22.0);
      expect(settings.getFontWeight(), 'semi_bold');
      expect(settings.getReciter(), 'ar.sudais');
      expect(settings.getBrightness(), 1.0);
      expect(settings.getLastRead(), isNull);
    });

    test('اختيار المستخدم يسبق الافتراضي', () async {
      await settings.setReadingMode('white');
      await settings.setFontFamily('QuranUthmanicHafs');

      expect(settings.getReadingMode(), 'white');
      expect(settings.getFontFamily(), 'QuranUthmanicHafs');
    });
  });

  group('ترحيل الوضع الليلي (شاشة القرآن تفتح ليلية دائماً)', () {
    test('جهاز قديم محفوظ فيه «white» يفتح ليلياً بعد الترحيل', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'READING_MODE': 'white',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // قبل الترحيل: القيمة القديمة تفتح نهارياً
      expect(
        QuranSettingsDataSourceImpl(sharedPreferences: prefs).getReadingMode(),
        'white',
      );

      await QuranSettingsDataSourceImpl.migrateToDarkReadingMode(prefs);

      expect(
        QuranSettingsDataSourceImpl(sharedPreferences: prefs).getReadingMode(),
        'black',
        reason: 'الترحيل لم يمحُ الوضع النهاري القديم',
      );
      // وهذا هو الوضع الذي يعتمد عليه بناء الشاشة:
      //   _isDarkMode = getReadingMode() != "white"
      final bool isDark =
          QuranSettingsDataSourceImpl(sharedPreferences: prefs)
                  .getReadingMode() !=
              'white';
      expect(isDark, isTrue, reason: 'الشاشة ستبنى نهارية');
    });

    test('يُطبَّق مرّة واحدة فقط — اختيار المستخدم بعده يبقى', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await QuranSettingsDataSourceImpl.migrateToDarkReadingMode(prefs);
      // المستخدم اختار النهاري بنفسه في الشاشة
      await QuranSettingsDataSourceImpl(sharedPreferences: prefs)
          .setReadingMode('white');

      // تشغيل التطبيق مرّة أخرى لا يفرض الليلي مرة ثانية
      await QuranSettingsDataSourceImpl.migrateToDarkReadingMode(prefs);

      expect(
        QuranSettingsDataSourceImpl(sharedPreferences: prefs).getReadingMode(),
        'white',
      );
    });

    test('جهاز جديد بلا أي قيمة يبقى ليلياً بعد الترحيل', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await QuranSettingsDataSourceImpl.migrateToDarkReadingMode(prefs);

      expect(
        QuranSettingsDataSourceImpl(sharedPreferences: prefs).getReadingMode(),
        'black',
      );
    });
  });

  test('وضع «أسود» هو الأغمق بين أوضاع خلفية الشاشة', () {
    final List<Color> black = GlassPalette.baseGradient('black');
    final List<Color> navy = GlassPalette.baseGradient('navy');

    double luminance(Color c) => c.computeLuminance();

    expect(black, isNotEmpty);
    // كل ألوان التدرّج الأسود داكنة فعلاً
    expect(black.every((Color c) => luminance(c) < 0.15), isTrue);
    // وأغمق من الوضع الكحلي
    expect(luminance(black.first), lessThan(luminance(navy.first)));
  });
}
