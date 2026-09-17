import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:muezzin_libya_app/core/theme/glass_theme.dart';
import 'package:muezzin_libya_app/features/home/presentation/widgets/prayer_times_screen.dart';
import 'package:muezzin_libya_app/remote_messaging_service.dart';

/// النص المتحرك في الشاشة الرئيسية — العرض الفعلي على الشاشة:
/// النص المخصص من لوحة التحكم، الخط والحجم واللون، وسرعة التقليب، والتعطيل.
void main() {
  // لا تحميل خطوط من الشبكة أثناء الاختبار
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pumpMarquee(
    WidgetTester tester,
    HomeMarqueeSettings settings, {
    Color? prayerColor,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: AnimatedDuaText(
              settings: settings,
              prayerColor: prayerColor,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('النص المخصص من لوحة التحكم يظهر على الشاشة الرئيسية', (
    WidgetTester tester,
  ) async {
    const HomeMarqueeSettings settings = HomeMarqueeSettings(
      text: 'اللهم ارزقنا الجنة\nواصرف عنا النار',
      fontFamily: 'Amiri',
      fontSize: 18,
      intervalMs: 3000,
      afterMinutes: 0,
    );

    await pumpMarquee(tester, settings);

    expect(find.text('اللهم ارزقنا الجنة'), findsOneWidget);
    expect(find.text('واصرف عنا النار'), findsNothing);
  });

  testWidgets('الخط والحجم واللون المختارون يُطبَّقون على النص', (
    WidgetTester tester,
  ) async {
    const HomeMarqueeSettings settings = HomeMarqueeSettings(
      text: 'سبحان الله وبحمده',
      fontFamily: 'Amiri',
      fontSize: 21,
      bold: true,
      color: 0xFF00E676,
      afterMinutes: 0,
    );

    await pumpMarquee(tester, settings);

    final Text text = tester.widget<Text>(find.text('سبحان الله وبحمده'));
    expect(text.style?.fontSize, 21);
    expect(text.style?.fontWeight, FontWeight.w700);
    expect(text.style?.color, const Color(0xFF00E676));
    expect(text.style?.fontFamily?.toLowerCase(), startsWith('amiri'));
  });

  testWidgets('التقليب ينتقل للعبارة التالية بعد المدة المضبوطة', (
    WidgetTester tester,
  ) async {
    const HomeMarqueeSettings settings = HomeMarqueeSettings(
      text: 'الأولى\nالثانية',
      intervalMs: 1500,
      afterMinutes: 0,
    );

    await pumpMarquee(tester, settings);
    expect(find.text('الأولى'), findsOneWidget);

    // قبل انتهاء المدة لم تتغير العبارة
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('الأولى'), findsOneWidget);

    // وبعدها تنتقل
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('الثانية'), findsOneWidget);
  });

  testWidgets('تعطيل النص من اللوحة يُخفيه تماماً', (
    WidgetTester tester,
  ) async {
    const HomeMarqueeSettings settings = HomeMarqueeSettings(
      enabled: false,
      text: 'نص لن يظهر',
    );

    await pumpMarquee(tester, settings);

    expect(find.text('نص لن يظهر'), findsNothing);
    // لا يُرسم أي نص إطلاقاً عند التعطيل
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('بلا نص مخصص تظهر الأدعية الافتراضية المضمّنة', (
    WidgetTester tester,
  ) async {
    await pumpMarquee(tester, const HomeMarqueeSettings());

    expect(find.text('- اللهم إنا :'), findsOneWidget);
  });

  testWidgets('تغيير النص من اللوحة يحدّث المعروض فوراً', (
    WidgetTester tester,
  ) async {
    await pumpMarquee(
      tester,
      const HomeMarqueeSettings(text: 'النص القديم', afterMinutes: 0),
    );
    expect(find.text('النص القديم'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AnimatedDuaText(
              settings: const HomeMarqueeSettings(
                text: 'النص الجديد',
                afterMinutes: 0,
              ),
            ),
          ),
        ),
      ),
    );
    // تجاوز مدة انتقال AnimatedSwitcher (450 مللي) فيختفي النص القديم
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('النص القديم'), findsNothing);
    expect(find.text('النص الجديد'), findsOneWidget);
  });

  // ── يتبع ألوان أوقات الصلاة ──────────────────────────────────────────────
  group('النص المتحرك يتبع ألوان أوقات الصلاة', () {
    testWidgets('الافتراضي (بلا اختيار) يأخذ لون الصلاة الحالية', (
      WidgetTester tester,
    ) async {
      const HomeMarqueeSettings settings = HomeMarqueeSettings(
        text: 'سبحان الله',
        afterMinutes: 0,
      );
      expect(settings.followsPrayerColors, isTrue,
          reason: 'الافتراضي يجب أن يكون تتبّع ألوان الصلاة');

      final Color prayer = GlassPalette.prayerTextColor('المغرب');
      await pumpMarquee(tester, settings, prayerColor: prayer);

      final Text text = tester.widget<Text>(find.text('سبحان الله'));
      expect(text.style?.color, prayer);
    });

    testWidgets('يتغير اللون مع كل صلاة (فجر ≠ مغرب ≠ عشاء)', (
      WidgetTester tester,
    ) async {
      const HomeMarqueeSettings settings = HomeMarqueeSettings(
        text: 'الله أكبر',
        afterMinutes: 0,
      );
      final Set<Color> seen = <Color>{};

      for (final String prayer in <String>[
        'الفجر',
        'الظهر',
        'العصر',
        'المغرب',
        'العشاء',
      ]) {
        await pumpMarquee(
          tester,
          settings,
          prayerColor: GlassPalette.prayerTextColor(prayer),
        );
        seen.add(
          tester.widget<Text>(find.text('الله أكبر')).style!.color!,
        );
      }

      expect(seen.length, 5, reason: 'ألوان الصلوات ليست مميزة عن بعضها');
    });

    testWidgets('اللون الثابت المختار يتجاهل لون الصلاة', (
      WidgetTester tester,
    ) async {
      const HomeMarqueeSettings settings = HomeMarqueeSettings(
        text: 'دعاء',
        color: 0xFF00E676,
        afterMinutes: 0,
      );
      expect(settings.followsPrayerColors, isFalse);

      await pumpMarquee(
        tester,
        settings,
        prayerColor: GlassPalette.prayerTextColor('الفجر'),
      );

      final Text text = tester.widget<Text>(find.text('دعاء'));
      expect(text.style?.color, const Color(0xFF00E676));
    });
  });

  group('قابلية القراءة على الخلفية الداكنة', () {
    const List<String> allPrayers = <String>[
      'الفجر',
      'الشروق',
      'الظهر',
      'العصر',
      'المغرب',
      'العشاء',
    ];

    test('لون نص كل صلاة مقروء على الأسود (سطوع كافٍ)', () {
      for (final String prayer in allPrayers) {
        final Color raw = GlassPalette.prayerTimesColor(prayer);
        final Color readable = GlassPalette.prayerTextColor(prayer);

        expect(readable.computeLuminance(), greaterThanOrEqualTo(0.40),
            reason: 'نص $prayer غير مقروء على الخلفية السوداء');
        // اللون الأصلي نفسه مقبول كما هو إن كان فاتحاً كفاية
        if (raw.computeLuminance() < 0.40) {
          expect(readable.computeLuminance(),
              greaterThan(raw.computeLuminance()),
              reason: 'لم يُفتَّح لون $prayer');
        }
        // عائلة اللون محفوظة: ليس أبيض صرفاً ولا رمادياً
        expect(readable, isNot(Colors.white));
      }
    });

    test('ألوان الصلوات الخمس مميزة عن بعضها (لا تتشابه بعد التفتيح)', () {
      final Set<int> distinct = <int>{};
      for (final String prayer in <String>[
        'الفجر',
        'الظهر',
        'العصر',
        'المغرب',
        'العشاء',
      ]) {
        distinct.add(GlassPalette.prayerTextColor(prayer).toARGB32());
      }
      expect(distinct.length, 5,
          reason: 'ألوان الصلوات انصهرت في بعضها بعد التفتيح');
    });

    test('اللون الفاتح أصلاً يُعاد كما هو بلا تفتيح', () {
      for (final String prayer in <String>[
        'الفجر',
        'الشروق',
        'الظهر',
        'العصر',
        'المغرب',
      ]) {
        expect(
          GlassPalette.prayerTextColor(prayer),
          GlassPalette.prayerTimesColor(prayer),
          reason: '$prayer فاتح أصلاً ولا يجب أن يتغيّر',
        );
      }
    });

    test('التفتيح يحفظ درجة اللون وتشبّعه (العشاء يبقى بنفسجياً)', () {
      final Color raw = GlassPalette.prayerTimesColor('العشاء');
      final Color readable = GlassPalette.prayerTextColor('العشاء');

      // البنفسجي: أزرقُه يقهر أحمرَه — ويبقى كذلك بعد التفتيح
      expect(raw.b - raw.r, greaterThan(0));
      expect(readable.b - readable.r, greaterThan(0),
          reason: 'البنفسجي صار رمادياً بعد التفتيح');

      final HSLColor hslRaw = HSLColor.fromColor(raw);
      final HSLColor hslRead = HSLColor.fromColor(readable);
      expect((hslRead.hue - hslRaw.hue).abs(), lessThan(2.0),
          reason: 'تغيّرت درجة اللون عند التفتيح');
      expect(hslRead.saturation, greaterThan(0.25),
          reason: 'التفتيح أذهب تشبّع اللون');
    });
  });
}
