import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muezzin_libya_app/core/config/app_version.dart';
import 'package:muezzin_libya_app/core/theme/glass_theme.dart';
import 'package:muezzin_libya_app/core/widgets/aurora_background.dart';
import 'package:muezzin_libya_app/core/widgets/glass_container.dart';
import 'package:muezzin_libya_app/core/widgets/glass_widgets.dart';
import 'package:muezzin_libya_app/features/about/presentation/pages/about_screen.dart';
import 'package:muezzin_libya_app/features/home/presentation/widgets/prayer_times_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// اختبارات شاشة «عن التطبيق»: كل الكتابة والأيقونات بيضاء ومحفورة، والحفر
/// مشتقّ من لون خلفية التطبيق، ولون صلاة المغرب في الشاشة الرئيسية.
Future<void> _loadAppFonts() async {
  const Map<String, String> fonts = <String, String>{
    'Cairo': 'assets/fonts/alfont_com_Cairo-Bold-1.ttf',
    'Amiri': 'assets/fonts/alfont_com_خط-القران-اميري.ttf',
  };
  for (final MapEntry<String, String> entry in fonts.entries) {
    try {
      final ByteData data = await rootBundle.load(entry.value);
      await (FontLoader(entry.key)..addFont(Future<ByteData>.value(data)))
          .load();
    } catch (_) {
      // غير حرج: الاختبارات تقيس الألوان والظلال لا قياسات الخط
    }
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(_loadAppFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpAbout(
    WidgetTester tester, {
    String themeMode = 'navy',
    Size size = const Size(360, 640),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AboutAppScreen(
            onBack: () {},
            userName: 'رزق الله',
            themeMode: themeMode,
          ),
        ),
      ),
    );
    // دورتان: إتمام FutureBuilder «معرف الجهاز» ثم انتهاء دخول الحركة
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  /// الحافة الداكنة (أعلى الحرف) — دليل وجود الحفر
  Color darkEdgeOf(WidgetTester tester, String text) {
    final Text widget = tester.widget<Text>(find.text(text));
    return widget.style!.shadows!.firstWhere((Shadow s) => s.offset.dy < 0).color;
  }

  group('شاشة عن التطبيق: كتابتها تتبع لون الصلاة ومحفورة', () {
    testWidgets('بلا صلاة معروفة → الكتابة والأيقونات بيضاء', (
      WidgetTester tester,
    ) async {
      // لا صلاة قادمة ولا نشطة معروفة (الحالة الافتراضية قبل حساب الأوقات)
      GlassRuntime.nextPrayer = Prayer.none;
      GlassRuntime.activePrayerName = '';
      await pumpAbout(tester);

      final List<Text> texts = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(texts, isNotEmpty);
      for (final Text t in texts) {
        expect(
          t.style?.color,
          Colors.white,
          reason: 'نصّ ليس أبيض: «${t.data}»',
        );
      }

      final List<Icon> icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons, isNotEmpty);
      for (final Icon i in icons) {
        expect(i.color, Colors.white, reason: 'أيقونة ليست بيضاء: ${i.icon}');
      }

      // العنوان والاسم والإصدار والمدينة والبريد موجودة فعلاً
      expect(find.text('أوقات الصلاة'), findsOneWidget);
      // الرقم من المصدر الواحد AppVersion — لا يُكتب في الاختبار يدوياً
      expect(find.text('رقم الإصدار ${AppVersion.display}'), findsOneWidget);
      expect(find.text('رزق الله عطيه العريبي'), findsOneWidget);
      expect(find.text('بنغازي / ليبيا'), findsOneWidget);
      expect(find.text('rezgallahattya@gmail.com'), findsOneWidget);

      await unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('كتابة الشاشة وأيقوناتها تتغيّر مع لون الصلاة القادمة', (
      WidgetTester tester,
    ) async {
      GlassRuntime.activePrayerName = '';
      GlassRuntime.nextPrayer = Prayer.maghrib;
      await pumpAbout(tester);

      final Color expected = GlassPalette.prayerTextColorFor(Prayer.maghrib);
      expect(expected, isNot(Colors.white),
          reason: 'لون صلاة المغرب يجب أن يختلف عن الأبيض');

      // العنوان + الإصدار + الاسم + الصفوف كلها بنفس لون الصلاة
      for (final String label in <String>[
        'أوقات الصلاة',
        'رقم الإصدار ${AppVersion.display}',
        'رزق الله عطيه العريبي',
        'بنغازي / ليبيا',
      ]) {
        final Text t = tester.widget<Text>(find.text(label));
        expect(t.style?.color, expected, reason: '«$label» لم يتبع لون الصلاة');
      }

      // والأيقونات كذلك
      for (final Icon i in tester.widgetList<Icon>(find.byType(Icon))) {
        if (i.icon == Icons.arrow_back_ios_new_rounded) continue;
        expect(i.color, expected, reason: 'أيقونة لم تتبع لون الصلاة: ${i.icon}');
      }

      // ويبقى مقروءاً على الخلفية الداكنة
      expect(expected.computeLuminance(), greaterThanOrEqualTo(0.40));

      GlassRuntime.nextPrayer = Prayer.none;
      await unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('الكتابة تتبع لون الصلاة النشطة نفسه الذي تلوّن به المواقيت', (
      WidgetTester tester,
    ) async {
      // المغرب نشطة: هذا ما تضبطه الشاشة الرئيسية عالمياً
      GlassRuntime.activePrayerName = 'المغرب';
      await pumpAbout(tester);

      // اللون المتوقّع = لون صلاة المغرب في شاشة المواقيت بالضبط
      final Color expected = GlassPalette.prayerTimesColor('المغرب');
      expect(expected, const Color(0xFFFAA18F),
          reason: 'لون المواقيت تغيّر — هذا الاختبار يحرس المصدر الواحد');

      for (final String label in <String>[
        'أوقات الصلاة',
        'رقم الإصدار ${AppVersion.display}',
        'رزق الله عطيه العريبي',
        'بنغازي / ليبيا',
      ]) {
        final Text t = tester.widget<Text>(find.text(label));
        expect(t.style?.color, expected,
            reason: '«$label» لا يطابق لون المواقيت');
      }

      GlassRuntime.activePrayerName = '';
      await unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('كل نص له ظلال حفر (حافة داكنة + حافة مضيئة)', (
      WidgetTester tester,
    ) async {
      await pumpAbout(tester);

      for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
        final List<Shadow>? shadows = t.style?.shadows;
        expect(shadows, isNotNull, reason: 'نص بلا حفر: «${t.data}»');
        expect(
          shadows!.length,
          greaterThanOrEqualTo(2),
          reason: 'حفر ناقص: «${t.data}»',
        );
        expect(
          shadows.any((Shadow s) => s.offset.dy < 0),
          isTrue,
          reason: 'بلا حافة داكنة أعلى الحرف: «${t.data}»',
        );
        expect(
          shadows.any((Shadow s) => s.offset.dy > 0),
          isTrue,
          reason: 'بلا حافة مضيئة أسفل الحرف: «${t.data}»',
        );
      }

      await unmount(tester);
    });

    testWidgets('الحفر يتبع لون خلفية التطبيق (يتغيّر مع تغيّر الوضع)', (
      WidgetTester tester,
    ) async {
      await pumpAbout(tester, themeMode: 'navy');
      final Color navyEdge = darkEdgeOf(tester, 'أوقات الصلاة');

      await pumpAbout(tester, themeMode: 'royal_purple');
      final Color purpleEdge = darkEdgeOf(tester, 'أوقات الصلاة');

      expect(
        purpleEdge,
        isNot(navyEdge),
        reason: 'حافة الحفر يجب أن تُشتقّ من ألوان الخلفية لا أن تكون ثابتة',
      );

      await unmount(tester);
    });

    testWidgets('الخلفية تتبع لون الصلاة الحالية مثل الشاشة الرئيسية', (
      WidgetTester tester,
    ) async {
      // وضع «بلون الصلاة» (فرع الافتراضي في GlassPalette.baseGradient)
      GlassRuntime.nextPrayer = Prayer.maghrib;
      await pumpAbout(tester, themeMode: 'prayer');

      final AuroraBackground bg = tester.widget<AuroraBackground>(
        find.byType(AuroraBackground),
      );
      expect(bg.colors, GlassPalette.dynamicGradient(Prayer.maghrib));

      GlassRuntime.nextPrayer = Prayer.none;
      await unmount(tester);
    });

    testWidgets('بلا أي كاردات: كل المحتوى مباشر على الخلفية', (
      WidgetTester tester,
    ) async {
      await pumpAbout(tester);

      // لا كارد زجاجي ولا لوح ولا خلفية صندوقية — لا في الترويسة ولا في
      // بيانات المطور ولا في زر الرجوع
      expect(find.byType(AuroraGlassCard), findsNothing);
      expect(find.byType(GlassPanel), findsNothing);

      // وزر الرجوع موجود كأيقونة مباشرة
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

      await unmount(tester);
    });

    for (final Size size in const <Size>[
      Size(320, 568),
      Size(360, 640),
      Size(412, 915),
    ]) {
      testWidgets('بلا أوفرفلو على ${size.width.toInt()}×${size.height.toInt()}', (
        WidgetTester tester,
      ) async {
        await pumpAbout(tester, size: size);
        expect(tester.takeException(), isNull);
        expect(find.byType(AboutAppScreen), findsOneWidget);
        await unmount(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('الألوان المشتركة', () {
    test('لون صلاة المغرب في الشاشة الرئيسية هو #FAA18F', () {
      expect(prayerIconColor('المغرب'), const Color(0xFFFAA18F));
    });

    test('GlassEngraveSpec يأخذ أغمق لون في تدرّج الخلفية', () {
      const List<Color> background = <Color>[
        Color(0xFF001233),
        Color(0xFF002855),
        Color(0xFF0A3F7A),
      ];
      expect(GlassEngraveSpec.deepest(background), const Color(0xFF001233));
    });
  });
}
