import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muezzin_libya_app/core/config/text_scale_boost.dart';
import 'package:muezzin_libya_app/core/widgets/glass_container.dart';
import 'package:muezzin_libya_app/features/home/presentation/widgets/prayer_times_screen.dart';

/// اختبارات الشاشة الرئيسية: زيادة الخط (+1.5) والتخطيط المتكيّف.
///
/// الهدف — وهو الأهم — إثبات عدم حدوث أوفرفلو في كل الحالات:
///   • مقاسات هواتف من 320×568 إلى 412×915.
///   • خط نظام مكبَّر (إمكانية الوصول) مع زيادة الـ1.5 معاً.
///   • مساحة أضيق من أن تكفي التصميم الثابت → يجب أن تتحوّل لكاردات قابلة
///     للسكرول بارتفاع أدنى ثابت لا يتلاصق محتواه.
///   • نافذة قصيرة جداً → الشاشة كلها تُسحب.
Future<void> _loadAppFonts() async {
  const Map<String, String> fonts = <String, String>{
    'Cairo': 'assets/fonts/alfont_com_Cairo-Bold-1.ttf',
    'Amiri': 'assets/fonts/alfont_com_خط-القران-اميري.ttf',
  };
  int loaded = 0;
  for (final MapEntry<String, String> entry in fonts.entries) {
    try {
      final ByteData data = await rootBundle.load(entry.value);
      final FontLoader loader = FontLoader(entry.key)
        ..addFont(Future<ByteData>.value(data));
      await loader.load();
      loaded++;
    } catch (_) {
      // لو تعذّر تحميل خط ما يبقى الاختبار صالحاً للأوفرفلو الأفقي
    }
  }
  debugPrint('⏲ خطوط التطبيق المحمّلة في الاختبار: $loaded/${fonts.length}');
}

/// ارتفاع شريط المهام السفلي في التطبيق — ننقصه من ارتفاع الاختبار حتى تكون
/// المساحة المتاحة للشاشة الرئيسية مطابقة لما يحدث على الجهاز فعلاً
/// (بهذا تظهر الحالات الضيقة الحقيقية بدل حالة اختبار أوسع من الواقع).
const double _kTaskBarHeight = 76;

void main() {
  // بلا تحميل خطوط من الإنترنت داخل الاختبار
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    // التطبيق يهيّئها في main() — وبدونها يرمي DateFormat('MMMM','ar')
    await initializeDateFormatting();
    await _loadAppFonts();
  });

  PrayerTimes buildPrayerTimes() {
    final Coordinates coordinates = Coordinates(32.1167, 20.0667); // بنغازي
    final CalculationParameters params =
        CalculationMethod.egyptian.getParameters();
    return PrayerTimes(
      coordinates,
      DateComponents.from(DateTime(2026, 9, 14)),
      params,
    );
  }

  /// الشاشة الرئيسية داخل هيكل التطبيق: غلاف التكبير + مكان شريط المهام.
  Widget buildHomeTab() => TextScaleBoost(
        child: Column(
          children: [
            Expanded(
              child: PrayerTimesScreen(
                is24H: false,
                pt: buildPrayerTimes(),
                dailyPrayerTimes: null,
                apiPrayerTimes: null,
                offsets: const [0, 0, 0, 0, 0, 0],
                city: 'بنغازي',
                hijriOffset: 0,
                coordinates: Coordinates(32.1167, 20.0667),
                method: 'ليبيا (الأوقاف)',
                madhab: 'maliki',
                onAutoDetect: () {},
              ),
            ),
            const SizedBox(height: _kTaskBarHeight),
          ],
        ),
      );

  /// يُركّب الشاشة على مقاس محدّد ثم يُفرّغها حتى لا تبقى مؤقتات معلّقة.
  ///
  /// [systemScale] يحاكي إعداد حجم الخط في النظام (إمكانية الوصول).
  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    double systemScale = 1.0,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(systemScale),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: buildHomeTab(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 30));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  List<double> tileHeights(WidgetTester tester) => <double>[
        for (int i = 0; i < 6; i++)
          tester.getSize(find.byType(AuroraGlassCard).at(i)).height,
      ];

  testWidgets('الزيادة إضافية بالضبط: 12 تصبح 13.5 ولا تتضاعف', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(360, 640));

    final BuildContext ctx = tester.element(find.byType(PrayerTimesScreen));
    final TextScaler scaler = MediaQuery.textScalerOf(ctx);

    expect(scaler.scale(12), 13.5);
    expect(scaler.scale(18), 19.5);
    // ولا تتضاعف الزيادة لو تكرّر الغلاف في الشجرة
    expect(scaler.scale(10), 11.5);

    await unmount(tester);
  });

  testWidgets('مقياس خط النظام يُحترم ثم تُضاف الزيادة فوقه', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(360, 640), systemScale: 1.3);

    final BuildContext ctx = tester.element(find.byType(PrayerTimesScreen));
    // 10 × 1.3 ثم + 1.5 — لا العكس
    expect(MediaQuery.textScalerOf(ctx).scale(10), closeTo(14.5, 0.001));

    await unmount(tester);
  });

  group('لا أوفرفلو بعد التكبير على مقاسات مختلفة', () {
    for (final Size size in const <Size>[
      Size(320, 568), // صغيرة الحجم
      Size(360, 640), // الأكثر شمولاً
      Size(360, 800),
      Size(390, 844),
      Size(412, 915),
    ]) {
      testWidgets('${size.width.toInt()}×${size.height.toInt()}', (
        WidgetTester tester,
      ) async {
        await pumpAt(tester, size);

        // أي RenderFlex overflow يُرمى كاستثناء داخل الاختبار
        expect(tester.takeException(), isNull);

        expect(find.text('بنغازي'), findsOneWidget);
        expect(find.text('الفجر'), findsOneWidget);
        expect(find.text('العشاء'), findsOneWidget);

        // كل كارد صلاة يبقى بارتفاع كافٍ لمحتواه
        expect(find.byType(AuroraGlassCard), findsNWidgets(6));
        for (final double h in tileHeights(tester)) {
          expect(h, greaterThanOrEqualTo(kMinPrayerTileHeight - 0.5));
        }
        expect(
          tester.getSize(find.byType(AuroraGlassCard).first).width,
          greaterThan(200),
        );

        await unmount(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('أسوأ حالة: أصغر شاشة + خط نظام 1.5 مع الزيادة', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const Size(320, 568), systemScale: 1.5);

      expect(tester.takeException(), isNull);
      expect(find.byType(AuroraGlassCard), findsNWidgets(6));
      for (final double h in tileHeights(tester)) {
        expect(h, greaterThanOrEqualTo(kMinPrayerTileHeight - 0.5));
      }

      await unmount(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('التخطيط المتكيّف: ثابت عند الكفاية وسكرول عند الضيق', () {
    testWidgets('شاشة عالية: يبقى التصميم الثابت (كاردات أكبر من الحد)', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const Size(412, 915));

      expect(tester.takeException(), isNull);
      for (final double h in tileHeights(tester)) {
        expect(h, greaterThan(kMinPrayerTileHeight + 10));
      }

      await unmount(tester);
    });

    testWidgets('شاشة ضيقة: الكاردات تصير على الحد الأدنى وتُسحب فعلاً', (
      WidgetTester tester,
    ) async {
      // 320×568 بعد خصم شريط المهام: لا تكفي للتصميم الثابت
      await pumpAt(tester, const Size(320, 480));

      expect(tester.takeException(), isNull);
      for (final double h in tileHeights(tester)) {
        expect(h, closeTo(kMinPrayerTileHeight, 0.01));
      }

      // القائمة تُسحب: آخر صلاة ترتفع بعد السحب للأعلى
      final double prayerBefore = tester.getTopLeft(find.text('العشاء')).dy;
      final double headerBefore = tester.getTopLeft(find.text('بنغازي')).dy;
      await tester.drag(find.text('الفجر'), const Offset(0, -60));
      await tester.pump();
      final double prayerAfter = tester.getTopLeft(find.text('العشاء')).dy;
      expect(prayerAfter, lessThan(prayerBefore));

      // والترويسة (وبالتالي العدّاد) تبقى مثبّتة ولا تتحرك بالسحب
      expect(tester.getTopLeft(find.text('بنغازي')).dy, headerBefore);

      await unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('نافذة قصيرة جداً: الشاشة كلها تُسحب ولا أوفرفلو', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const Size(320, 220));

      expect(tester.takeException(), isNull);
      expect(find.byType(AuroraGlassCard), findsNWidgets(6));
      for (final double h in tileHeights(tester)) {
        expect(h, greaterThanOrEqualTo(kMinPrayerTileHeight - 0.5));
      }

      await unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('الخط الكبير للنظام يشغّل السكرول بدل تلاصق الكاردات', (
      WidgetTester tester,
    ) async {
      // شاشة قصيرة + خط نظام كبير: أسوأ اجتماع
      await pumpAt(tester, const Size(360, 480), systemScale: 1.6);

      expect(tester.takeException(), isNull);
      for (final double h in tileHeights(tester)) {
        expect(h, closeTo(kMinPrayerTileHeight, 0.01));
      }

      await unmount(tester);
      expect(tester.takeException(), isNull);
    });
  });

  // ── الترويسة: الترتيب والخطوط وأماكنها ──────────────────────────────────
  group('ترويسة الشاشة الرئيسية', () {
    final Finder hijriDate = find.byWidgetPredicate(
      (Widget w) => w is Text && (w.data?.endsWith('هـ') ?? false),
      description: 'نصّ التاريخ الهجري',
    );
    final Finder gregorianDate = find.byWidgetPredicate(
      (Widget w) => w is Text && (w.data?.contains(' | ') ?? false),
      description: 'نصّ التاريخ الميلادي',
    );

    testWidgets('بنغازي تحت التاريخ الميلادي وفي منتصف العرض', (
      WidgetTester tester,
    ) async {
      const double width = 390;
      await pumpAt(tester, const Size(width, 844));

      final Rect hijri = tester.getRect(hijriDate);
      final Rect gregorian = tester.getRect(gregorianDate);
      final Rect city = tester.getRect(find.text('بنغازي'));

      // الترتيب العمودي: الهجري، ثم الميلادي، ثم اسم المدينة تحته
      expect(hijri.bottom, lessThanOrEqualTo(gregorian.top));
      expect(gregorian.bottom, lessThanOrEqualTo(city.top));
      // واسم المدينة في المنتصف (لا بجانب التاريخ كما كان)
      expect(city.center.dx, closeTo(width / 2, 1.0));

      await unmount(tester);
    });

    testWidgets('خطوط الترويسة: الهجري 15 والميلادي 10 والمدينة 11', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const Size(390, 844));

      expect(tester.widget<Text>(hijriDate).style?.fontSize, 15);
      expect(tester.widget<Text>(gregorianDate).style?.fontSize, 10);
      expect(tester.widget<Text>(find.text('بنغازي')).style?.fontSize, 11);

      await unmount(tester);
    });
  });
}
