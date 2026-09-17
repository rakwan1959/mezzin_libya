import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muezzin_libya_app/core/theme/glass_theme.dart';
import 'package:muezzin_libya_app/features/about/presentation/pages/about_screen.dart';
import 'package:muezzin_libya_app/features/home/presentation/widgets/prayer_times_screen.dart';
import 'package:muezzin_libya_app/remote_messaging_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ── مصدر واحد لألوان أوقات الصلاة ──────────────────────────────────────────
///
///  الشكوى التي وُلد منها هذا الملف: «النص المتحرك وشاشة عن التطبيق لا تتبع
///  ألوان أوقات الصلاة». السبب كان وجود **لوحتين** للون الصلاة:
///    • لوحة شاشة المواقيت (`#90CAF9` فجر · `#80DEEA` ظهر · `#CFE2F3` مغرب…)
///    • ولوحة ثانية في [GlassPalette] (`#7FB2FF` فجر · `#73478A` ظهر…) كان
///      النص المتحرك وشاشة «عن التطبيق» يقرآن منها.
///  فيبدو لونهما مخالفاً للمواقيت رغم أن كليهما يزعم أنه «يتبع الصلاة».
///
///  هذه الاختبارات تختم المصدر الواحد: أي انحراف في أي شاشة يُسقطها فوراً.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  const Map<Prayer, String> byEnum = <Prayer, String>{
    Prayer.fajr: 'الفجر',
    Prayer.sunrise: 'الشروق',
    Prayer.dhuhr: 'الظهر',
    Prayer.asr: 'العصر',
    Prayer.maghrib: 'المغرب',
    Prayer.isha: 'العشاء',
  };

  /// اللوحة المعتمدة (نصّاً) — كما تُعرض في كاردات المواقيت.
  ///
  /// لون المغرب هو **`#FAA18F`** (اللون المعتمد للشاشة الرئيسية والمواقيت
  /// وكاردات الصلوات) — كان `#CFE2F3` قبل اعتماد اللون الجديد.
  const Map<String, int> expectedHex = <String, int>{
    'الفجر': 0xFF90CAF9,
    'الشروق': 0xFFFFCC80,
    'الظهر': 0xFF80DEEA,
    'العصر': 0xFFD9D9D8,
    'المغرب': 0xFFFAA18F,
    'العشاء': 0xFFB39DDB,
  };

  group('لوحة واحدة للصلوات', () {
    test('شاشة المواقيت تقرأ من GlassPalette (لا لوحة خاصة بها)', () {
      for (final MapEntry<String, int> e in expectedHex.entries) {
        expect(prayerIconColor(e.key).toARGB32(), e.value, reason: e.key);
        expect(
          prayerIconColor(e.key),
          GlassPalette.prayerTimesColor(e.key),
          reason: 'لون ${e.key} في المواقيت يخالف المصدر الواحد',
        );
      }
    });

    test('الاسم العربي وكائن Prayer يعطيان نفس اللون', () {
      for (final MapEntry<Prayer, String> e in byEnum.entries) {
        expect(
          GlassPalette.prayerTimesColorFor(e.key),
          GlassPalette.prayerTimesColor(e.value),
          reason: '${e.value}: المسارَان اختلفا',
        );
        expect(
          GlassPalette.prayerTextColorFor(e.key),
          GlassPalette.prayerTextColor(e.value),
          reason: '${e.value}: لون الكتابة اختلف بين المسارَين',
        );
      }
    });

    test('لون الكتابة = لون المواقيت نفسه (أو تفتيح يحفظ الدرجة)', () {
      for (final String prayer in expectedHex.keys) {
        final Color times = GlassPalette.prayerTimesColor(prayer);
        final Color ink = GlassPalette.prayerTextColor(prayer);

        if (times.computeLuminance() >= 0.40) {
          expect(ink, times, reason: '$prayer: فاتح أصلاً ولا يُفتَّح');
          continue;
        }
        // داكِن: يُفتَّح مع الحفاظ على الدرجة والتشبّع (لا مزج مع الأبيض)
        final HSLColor a = HSLColor.fromColor(times);
        final HSLColor b = HSLColor.fromColor(ink);
        expect((b.hue - a.hue).abs(), lessThan(2.0), reason: prayer);
        expect(b.lightness, greaterThan(a.lightness), reason: prayer);
        expect(b.saturation, closeTo(a.saturation, 0.01), reason: prayer);
      }
    });

    test('لا صلاة معروفة → أبيض (بلا انهيار)', () {
      expect(GlassPalette.prayerTimesColor('لا شيء'), Colors.white);
      expect(GlassPalette.prayerTimesColorFor(Prayer.none), Colors.white);
      expect(GlassPalette.prayerTextColor(''), Colors.white);
    });
  });

  group('الشاشات الثلاث تعرض اللون نفسه', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('النص المتحرك + شاشة «عن التطبيق» = لون المواقيت', (
      WidgetTester tester,
    ) async {
      const String active = 'المغرب';
      final Color timesColor = GlassPalette.prayerTimesColor(active);
      // اللون المعتمد للمغرب في الشاشة الرئيسية
      expect(timesColor, const Color(0xFFFAA18F));

      // 1) النص المتحرك كما تُمرّره الشاشة الرئيسية (لون الصلاة النشطة)
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: AnimatedDuaText(
              settings: const HomeMarqueeSettings(
                text: 'سبحان الله',
                afterMinutes: 0,
              ),
              prayerColor: GlassPalette.prayerTextColor(active),
            ),
          ),
        ),
      );
      await tester.pump();

      final Text marquee = tester.widget<Text>(find.text('سبحان الله'));
      expect(marquee.style?.color, timesColor,
          reason: 'النص المتحرك لا يطابق لون المواقيت');

      // 2) شاشة «عن التطبيق» بنفس الصلاة النشطة
      GlassRuntime.activePrayerName = active;
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: AboutAppScreen(
              onBack: () {},
              userName: 'رزق الله',
              themeMode: 'black',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final Text title = tester.widget<Text>(find.text('أوقات الصلاة'));
      expect(title.style?.color, timesColor,
          reason: 'شاشة «عن التطبيق» لا تطابق لون المواقيت');
      // والاثنان متطابقان — نفس اللون لا مجرد «ألوان صلاة»
      expect(title.style?.color, marquee.style?.color);

      GlassRuntime.activePrayerName = '';
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
