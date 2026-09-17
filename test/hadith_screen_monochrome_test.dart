import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muezzin_libya_app/core/widgets/glass_container.dart';
import 'package:muezzin_libya_app/features/library/presentation/pages/prophetic_hadith_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ── شاشة الأحاديث النبوية: أبيض أحادي فقط ──────────────────────────────────
///
///  المطلوب من المستخدم: الكاردات — كبيرة كانت أو صغيرة — **أبيض فقط**،
///  بلا أي لون أصفر ولا أي لون آخر، مع شرائح لا تُقتطع عند تكبير خط الجهاز.
///
///  الاختبارات هنا تحرس هذا بأمرين لا يمكن تجاوزهما:
///    1. مسح **كل** قيم `Color(0x...)` في ملف الشاشة: يجب أن تكون محايدة
///       (r = g = b تقريباً) — فأي لون ملوّن يُسقط الاختبار فوراً.
///    2. قياس الشرائح فعلياً عند تكبير الخط 1× و3×: تنمو ولا تُقتطع.
///
///  وأُضيف لاحقاً — بحسب طلب المستخدم — حرسٌ على:
///    • «الكل» انتقلت إلى **منتصف الترويسة** بخط أصغر بمقدار واحد (11 بدل 12).
///    • نص الحديث في **الكارد الصغير** أصغر بمقدار 2 عن الحجم المختار.
///    • لا كلمة «نبوي عام» في الكاردات الصغيرة.
///    • تغيير الحجم ينتقل **بسلاسة** داخل الكاردات (بلا قفزة مفاجئة).

/// حجم الخط المحفوظ في التهيئة ([setUp]) — والأساس لكل مقارنات الخطوط.
const double _kSavedFontSize = 18.0;

/// محايد؟ أي فرق بين أعلى قناة وأدناها ≤ 6 من 255 (سواد/رمادي/أبيض).
bool _isNeutral(Color c) {
  final int r = (c.toARGB32() >> 16) & 0xFF;
  final int g = (c.toARGB32() >> 8) & 0xFF;
  final int b = c.toARGB32() & 0xFF;
  final int maxC = [r, g, b].reduce((a, b) => a > b ? a : b);
  final int minC = [r, g, b].reduce((a, b) => a < b ? a : b);
  return (maxC - minC) <= 6;
}

Future<void> _loadAppFonts() async {
  const Map<String, String> fonts = <String, String>{
    'Amiri': 'assets/fonts/alfont_com_خط-القران-اميري.ttf',
  };
  for (final MapEntry<String, String> entry in fonts.entries) {
    try {
      final ByteData data = await rootBundle.load(entry.value);
      await (FontLoader(entry.key)..addFont(Future<ByteData>.value(data)))
          .load();
    } catch (_) {
      // غير حرج: نقيس الألوان والهندسة لا مقاييس الخط
    }
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(_loadAppFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues(
      <String, Object>{'hadith_font_size': _kSavedFontSize},
    );
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    double textScale = 1.0,
    Size size = const Size(390, 800),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: PropheticHadithScreen(),
        ),
      ),
    );
    // خلفية الأورورا تتحرّك باستمرار، فلا نستعمل pumpAndSettle أبداً
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  // ── 1) حراسة المصدر: لا لون ملوّن إطلاقاً ───────────────────────────────
  group('المصدر: أبيض أحادي بلا أي لون', () {
    final String source = File(
      'lib/features/library/presentation/pages/prophetic_hadith_screen.dart',
    ).readAsStringSync();

    test('كل قيم Color(0x...) في الشاشة محايدة (أبيض/رمادي/أسود)', () {
      final RegExp hex = RegExp(r'0[xX]([0-9A-Fa-f]{8})');
      final List<String> offenders = <String>[];

      for (final RegExpMatch m in hex.allMatches(source)) {
        final int argb = int.parse(m.group(1)!, radix: 16);
        final Color color = Color(argb);
        if (!_isNeutral(color)) {
          offenders.add('0x${m.group(1)}');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'ألوان ملوّنة تسلّلت إلى شاشة الأحاديث: $offenders',
      );
      // شاهد: يوجد فعلاً لون في الملف، فالفحص ليس فارغاً
      expect(hex.allMatches(source), isNotEmpty);
    });

    test('لا أصفر ولا ذهبي ولا أي لون مسمّى ملوّن', () {
      for (final String forbidden in <String>[
        'Colors.amber',
        'Colors.yellow',
        'Colors.orange',
        'Colors.lime',
        'Colors.teal',
        'Colors.cyan',
        'Colors.purple',
        'Colors.indigo',
        'Colors.blue',
        'Colors.green',
        'Colors.red',
        'GlassPalette.gold',
        'GlassPalette.goldSoft',
        'GlassPalette.goldDeep',
      ]) {
        expect(
          source.contains(forbidden),
          isFalse,
          reason: '$forbidden ممنوع في شاشة الأحاديث — الأبيض فقط',
        );
      }
    });

    test('لا تدرّجات ملوّنة (كحلي/سينمائي) في خلفيات الكاردات', () {
      for (final String forbidden in <String>[
        '0xFF1E293B', // سينمائي أزرق
        '0xFF0F172A', // كحلي غامق
        '0xFF061426', // كحلي
        '0xFF07152B', // كحلي نافذة الخط
        '0xFF002855', // الكحلي الملكي
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });
  });

  // ── 2) شريحة «الكل» في الترويسة تنمو ولا تُقتطع — وفي المنتصف ────────────
  group('شريحة «الكل» في الترويسة', () {
    Finder allChip() => find.ancestor(
          of: find.text('الكل'),
          matching: find.byType(AnimatedContainer),
        );

    testWidgets('تنمو مع تكبير خط الجهاز بدل الاقتطاع', (tester) async {
      await pumpScreen(tester, textScale: 1.0);
      final Size chipAt1x = tester.getSize(allChip());
      final Size labelAt1x = tester.getSize(find.text('الكل'));

      await pumpScreen(tester, textScale: 3.0);
      final Size chipAt3x = tester.getSize(allChip());
      final Size labelAt3x = tester.getSize(find.text('الكل'));

      // النص كبر فعلاً (فالقياس له أسنان)
      expect(labelAt3x.height, greaterThan(labelAt1x.height));
      // والشريحة كبرت معه — وليس بقيت على ارتفاع ثابت
      expect(chipAt3x.height, greaterThan(chipAt1x.height));
      // الحشو الرأسي لشريحة الترويسة (5 أعلى + 5 أسفل) محفوظ كاملاً حول
      // النص — فلا اقتطاع عند أي تكبير
      expect(chipAt3x.height, greaterThanOrEqualTo(labelAt3x.height + 10));
      expect(chipAt1x.height, greaterThanOrEqualTo(labelAt1x.height + 10));
    });

    testWidgets('في منتصف الترويسة تماماً', (tester) async {
      await pumpScreen(tester);

      final Size screen = tester.view.physicalSize;
      final double center = tester.getCenter(allChip()).dx;
      expect(
        (center - screen.width / 2).abs(),
        lessThan(2),
        reason: 'شريحة «الكل» يجب أن تكون في منتصف الترويسة (${screen.width / 2})',
      );
    });
  });

  // ── 3) العرض الفعلي: كل نص وأيقونة أبيض ─────────────────────────────────
  group('العرض الفعلي', () {
    testWidgets('تُبنى الشاشة وتُعرض شرائح التصنيف الثلاث', (tester) async {
      await pumpScreen(tester);

      // الترويسة بلا عنوان ولا عدّاد ولا وصف — زرّا الرجوع وحجم الخط فقط
      expect(find.text('الأحاديث النبوية'), findsNothing);
      expect(
        find.text('أحاديث نبوية صحيحة ومختارة من السنة المطهرة'),
        findsNothing,
      );
      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('أحاديث عامة'), findsOneWidget);
      expect(find.text('فضائل رمضان'), findsOneWidget);

      // «الكل» فوق صفّ الشرائح: إنها في الترويسة لا في الصفّ
      expect(
        tester.getCenter(find.text('الكل')).dy,
        lessThan(tester.getCenter(find.text('أحاديث عامة')).dy),
        reason: '«الكل» يجب أن تكون في الترويسة (أعلى الشرائح)',
      );
    });

    testWidgets('«الكل» بخط 11 (تصغير واحد عن 12) والبقية 12', (tester) async {
      await pumpScreen(tester);

      expect(
        tester.widget<Text>(find.text('الكل')).style?.fontSize,
        11,
        reason: 'شريحة «الكل» في الترويسة يجب أن تكون أصغر بمقدار واحد',
      );
      for (final String label in <String>[
        'أحاديث عامة',
        'فضائل رمضان',
      ]) {
        expect(
          tester.widget<Text>(find.text(label)).style?.fontSize,
          12,
          reason: 'شريحة «$label» يجب أن تكون بخط 12',
        );
      }
    });

    testWidgets('نص الحديث في الكارد الصغير أصغر بـ2 عن الحجم المختار', (
      tester,
    ) async {
      await pumpScreen(tester);

      final Finder cards = find.byType(AuroraGlassCard);
      expect(cards, findsWidgets);

      int smallCards = 0;
      for (int i = 0; i < cards.evaluate().length; i++) {
        final Finder card = cards.at(i);
        final bool isDaily =
            find.descendant(of: card, matching: find.text('حديث اليوم')).evaluate().isNotEmpty;
        final Finder quote = find.descendant(
          of: card,
          matching: find.byWidgetPredicate(
            (Widget w) => w is Text && (w.data ?? '').startsWith('«'),
          ),
        );
        if (quote.evaluate().isEmpty) continue;

        final double? size = tester.widget<Text>(quote.first).style?.fontSize;
        if (isDaily) {
          expect(size, _kSavedFontSize,
              reason: 'كارد حديث اليوم يبقى على الحجم المختار');
        } else {
          smallCards++;
          expect(
            size,
            _kSavedFontSize - 2,
            reason: 'نص الكارد الصغير يجب أن يكون أصغر بـ2 عن الحجم المختار',
          );
        }
      }
      expect(smallCards, greaterThan(0), reason: 'لم يُقس أي كارد صغير');
    });

    testWidgets('لا كلمة «نبوي عام» في الكاردات الصغيرة', (tester) async {
      await pumpScreen(tester);

      expect(find.text('نبوي عام'), findsNothing);
    });

    testWidgets('كل نص وأيقونة في الشاشة محايد (أبيض) — لا لون', (tester) async {
      await pumpScreen(tester);

      final List<String> offenders = <String>[];

      for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
        final Color? c = t.style?.color;
        if (c != null && c.a > 0 && !_isNeutral(c)) {
          offenders.add('نص «${t.data}» بلون ${c.toARGB32().toRadixString(16)}');
        }
      }

      for (final Icon i in tester.widgetList<Icon>(find.byType(Icon))) {
        final Color? c = i.color;
        if (c != null && c.a > 0 && !_isNeutral(c)) {
          offenders.add('أيقونة ${i.icon?.codePoint} بلون '
              '${c.toARGB32().toRadixString(16)}');
        }
      }

      expect(offenders, isEmpty, reason: 'ألوان ملوّنة ظاهرة: $offenders');
    });

    testWidgets('الكاردات الظاهرة بيضاء الحدود والنصوص', (tester) async {
      await pumpScreen(tester);

      // الكاردات مبنية من AuroraGlassCard؛ إن حُمّلت الأحاديث فسنجدها
      final Finder cards = find.byType(AuroraGlassCard);
      expect(cards, findsWidgets, reason: 'لم تُعرض أي كاردات');

      for (final AuroraGlassCard card
          in tester.widgetList<AuroraGlassCard>(cards)) {
        // التوهّج (إن وُجد) أبيض لا ملوّن
        if (card.glowColor != null) {
          expect(_isNeutral(card.glowColor!), isTrue,
              reason: 'توهّج الكارد ملوّن: ${card.glowColor}');
        }
        // وخلفية الكارد محايدة (بلا مسحة كحلية)
        for (final Color c in card.gradientColors ?? const <Color>[]) {
          expect(_isNeutral(c), isTrue, reason: 'خلفية الكارد ملوّنة: $c');
        }
        // والحدّ أبيض
        final Border? border =
            card.border is Border ? card.border as Border : null;
        if (border != null) {
          expect(_isNeutral(border.top.color), isTrue,
              reason: 'حدّ الكارد ملوّن: ${border.top.color}');
        }
      }
    });
  });

  // ── 4) نافذة حجم الخط: نسبة الكارد الصغير + معاينة مباشرة قبل الحفظ ────────
  group('نافذة حجم الخط', () {
    /// يفتح الشاشة ثم نافذة حجم الخط (بحركة — بلا pumpAndSettle).
    Future<void> openDialog(WidgetTester tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.format_size_rounded));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    /// ضغطة داخل النافذة مع تقديم الإطارات (بحركة — بلا pumpAndSettle).
    Future<void> tapStep(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.tap(finder);
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    Future<double?> savedFontSize() async =>
        (await SharedPreferences.getInstance()).getDouble('hadith_font_size');

    testWidgets('تعرض حجم الكارد الصغير كنسبة مئوية واضحة', (tester) async {
      await openDialog(tester);

      expect(find.text('الكارد الكبير'), findsOneWidget);
      expect(find.text('الكارد الصغير'), findsOneWidget);
      // المحفوظ 18 → الكارد الصغير 16 وهو ‎89٪ من الكارد الكبير
      expect(find.text('16'), findsOneWidget);
      expect(find.text('89٪ من الكارد الكبير'), findsOneWidget);
      // ومعاينتان مباشرتان: للكارد الكبير وللكارد الصغير
      expect(find.text('معاينة الكارد الكبير'), findsOneWidget);
      expect(find.text('معاينة الكارد الصغير'), findsOneWidget);
    });

    testWidgets('المعاينة تتبع المسودة ولا يُحفظ شيء قبل «حفظ»', (tester) async {
      await openDialog(tester);

      // المسودة 18 → 19 والمعاينة الصغيرة 16 → 17
      await tapStep(tester, find.byIcon(Icons.add_circle_outline_rounded));
      expect(find.text('19'), findsWidgets);
      expect(find.text('17'), findsOneWidget,
          reason: 'معاينة الكارد الصغير يجب أن تتبع المسودة لا المحفوظ');
      expect(await savedFontSize(), _kSavedFontSize,
          reason: 'لا يُحفظ شيء قبل الضغط على «حفظ»');

      await tapStep(tester, find.text('حفظ'));
      expect(await savedFontSize(), _kSavedFontSize + 1);
      expect(find.text('حفظ'), findsNothing, reason: 'النافذة تُغلق بعد الحفظ');
    });

    testWidgets('«إلغاء» يُغلق النافذة بلا حفظ', (tester) async {
      await openDialog(tester);

      await tapStep(tester, find.byIcon(Icons.add_circle_outline_rounded));
      await tapStep(tester, find.text('إلغاء'));

      expect(await savedFontSize(), _kSavedFontSize);
    });

    /// حجم خط نص الحديث في أول كارد صغير معروض على الشاشة.
    double smallQuoteSize(WidgetTester tester) {
      final Finder cards = find.byType(AuroraGlassCard);
      for (int i = 0; i < cards.evaluate().length; i++) {
        final Finder card = cards.at(i);
        final bool isDaily = find
            .descendant(of: card, matching: find.text('حديث اليوم'))
            .evaluate()
            .isNotEmpty;
        if (isDaily) continue;
        final Finder quote = find.descendant(
          of: card,
          matching: find.byWidgetPredicate(
            (Widget w) => w is Text && (w.data ?? '').startsWith('«'),
          ),
        );
        if (quote.evaluate().isEmpty) continue;
        return tester.widget<Text>(quote.first).style!.fontSize!;
      }
      fail('لم يُوجد أي كارد صغير لقياسه');
    }

    testWidgets('الحجم ينتقل بسلاسة بعد الحفظ بدل القفزة المفاجئة',
        (tester) async {
      await openDialog(tester);
      expect(smallQuoteSize(tester), 16.0); // 18 المحفوظ ‎- 2

      // المسودة 19 ثم «حفظ»
      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
      await tester.pump();
      await tester.ensureVisible(find.text('حفظ'));
      await tester.pump();
      await tester.tap(find.text('حفظ'));
      await tester.pump();

      // الإطار الأول بعد الحفظ: لا قفزة — لا يزال على الحجم السابق
      expect(
        smallQuoteSize(tester),
        16.0,
        reason: 'القفزة المفاجئة ممنوعة: البداية من الحجم المعروض',
      );

      // تدرّج فعلي: قيم وسطية بين القديم والجديد
      final List<double> samples = <double>[];
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        samples.add(smallQuoteSize(tester));
      }
      expect(
        samples.any((double s) => s > 16.0 && s < 17.0),
        isTrue,
        reason: 'الانتقال يجب أن يمرّ بقيم وسطية لا أن يقفز: $samples',
      );
      expect(samples.first, lessThan(17.0));

      // ويستقرّ في النهاية على الحجم الجديد
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(smallQuoteSize(tester), 17.0);
      expect(await savedFontSize(), _kSavedFontSize + 1);
    });

    testWidgets('كل نصوص النافذة محايدة (أبيض) — لا لون', (tester) async {
      await openDialog(tester);

      final List<String> offenders = <String>[];
      for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
        final Color? c = t.style?.color;
        if (c != null && c.a > 0 && !_isNeutral(c)) {
          offenders.add('نص «${t.data}» بلون ${c.toARGB32().toRadixString(16)}');
        }
      }
      expect(offenders, isEmpty, reason: 'ألوان ملوّنة في نافذة الحجم: $offenders');
    });
  });
}
