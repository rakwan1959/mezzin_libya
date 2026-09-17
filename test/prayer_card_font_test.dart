import 'dart:io';

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muezzin_libya_app/core/config/prayer_card_font_prefs.dart';
import 'package:muezzin_libya_app/core/config/text_scale_boost.dart';
import 'package:muezzin_libya_app/core/widgets/glass_container.dart';
import 'package:muezzin_libya_app/features/home/presentation/widgets/prayer_times_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ── درجة «تكبير خط كاردات أوقات الصلاة» ─────────────────────────────────────
///
/// المطلوب من المستخدم: في شاشة الإعدادات ← المظهر، درجة تُكبّر/تُصغّر خطّ
/// **الاسم والوقت** في كاردات أوقات الصلاة: تكبير (+2) / عادي (0) / تصغير (−2).
///
/// الحرس من أربع جهات:
///   1. التفضيل نفسه: الافتراضي، والحفظ، والتحميل، والترحيل من المفتاح
///      القديم (تشغيل/إيقاف)، وتجاهل القيم الشاذة.
///   2. الكاردات فعلاً: الأحجام تُقاس من الـText المبني داخل كارد الصلاة —
///      الاسم والوقت وحرف الفترة والأيقونة، عند +2 و−2.
///   3. الوصول الفوري: تغيير الدرجة يعيد بناء الكاردات بلا rebuild من
///      الشاشة الأم (ValueListenableBuilder)، ولا أوفرفلو على 320×568.
///   4. الوصل: الاختيار موجود في الإعدادات ويُحمَّل عند الإقلاع، ولا حجم
///      مكتوب في مكانه داخل الشاشة.
Future<void> _loadAppFonts() async {
  const Map<String, String> fonts = <String, String>{
    'Cairo': 'assets/fonts/alfont_com_Cairo-Bold-1.ttf',
  };
  for (final MapEntry<String, String> entry in fonts.entries) {
    try {
      final ByteData data = await rootBundle.load(entry.value);
      await (FontLoader(entry.key)..addFont(Future<ByteData>.value(data)))
          .load();
    } catch (_) {
      // الخطوط ليست حرجة: نقيس قيم fontSize لا عرض النص
    }
  }
}

/// ارتفاع شريط المهام السفلي — ننقصه حتى تكون المساحة مطابقة للجهاز فعلاً.
const double _kTaskBarHeight = 76;

/// «الشروق» موجود في كاردات المواقيت وحدها (العدّاد التنازلي لا يعرضه)، فهو
/// مرساة موثوقة لكارد واحد بعينه.
Finder get _sunriseName => find.text('الشروق');

Finder get _sunriseTile =>
    find.ancestor(of: _sunriseName, matching: find.byType(AuroraGlassCard));

Finder get _sunriseTime => find.descendant(
      of: _sunriseTile,
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is Text && RegExp(r'^\d{1,2}:\d{2}$').hasMatch(w.data ?? ''),
        description: 'وقت الصلاة داخل الكارد',
      ),
    );

/// حرف الفترة داخل الكارد — «ص» قبل الظهر و«م» بعده، فلا يُثبَّت أحدهما
/// (وقت الشروق يتبع التاريخ المُمرَّر، وقد يقع بعد الظهر).
Finder get _sunrisePeriod => find.descendant(
      of: _sunriseTile,
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is Text && RegExp(r'^[صم]$').hasMatch(w.data ?? ''),
        description: 'حرف الفترة داخل الكارد',
      ),
    );

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    await initializeDateFormatting();
    await _loadAppFonts();
  });

  // الحالة static في الذاكرة — تُصفَّر بين الاختبارات
  setUp(() => PrayerCardFontPrefs.adjustment.value = 0);

  // ── 1) التفضيل المحفوظ ──────────────────────────────────────────────────
  group('التفضيل المحفوظ', () {
    test('الدرجات المتاحة +2 / 0 / −2 بأسمائها العربية', () {
      expect(kPrayerCardFontOptions, <int>[2, 0, -2]);
      expect(PrayerCardFontPrefs.options, <int>[2, 0, -2]);
      expect(PrayerCardFontPrefs.labelOf(2), 'تكبير (+2)');
      expect(PrayerCardFontPrefs.labelOf(0), 'عادي (0)');
      expect(PrayerCardFontPrefs.labelOf(-2), 'تصغير (−2)');
      // أي قيمة شاذة تُقرَّب إلى إحدى الدرجات الثلاث
      expect(PrayerCardFontPrefs.normalize(9), 2);
      expect(PrayerCardFontPrefs.normalize(-7), -2);
      expect(PrayerCardFontPrefs.normalize(1), 0);
    });

    test('الافتراضي «عادي (0)» والأحجام الأساسية 11 / 12.5 / 10 / 13', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await PrayerCardFontPrefs.load();

      expect(PrayerCardFontPrefs.adjustment.value, 0);
      expect(PrayerCardFontPrefs.currentLabel(), 'عادي (0)');
      expect(PrayerCardFontPrefs.nameFontSize, kPrayerNameBaseFontSize);
      expect(PrayerCardFontPrefs.timeFontSize, kPrayerTimeBaseFontSize);
      expect(PrayerCardFontPrefs.periodFontSize, kPrayerPeriodBaseFontSize);
      expect(PrayerCardFontPrefs.iconSize, kPrayerIconBaseSize);
    });

    test('التكبير (+2) والتصغير (−2) يُحفظان ويُبثّان فوراً', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await PrayerCardFontPrefs.save(2);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(kPrayerCardFontAdjustKey), 2);
      expect(PrayerCardFontPrefs.adjustment.value, 2);
      expect(PrayerCardFontPrefs.nameFontSize, 11 + 2);
      expect(PrayerCardFontPrefs.timeFontSize, 12.5 + 2);
      expect(PrayerCardFontPrefs.periodFontSize, 10 + 2);
      expect(PrayerCardFontPrefs.iconSize, 13 + 2);
      expect(PrayerCardFontPrefs.currentLabel(), 'تكبير (+2)');

      // التصغير ينزل بالكتابة والأيقونة معاً (والأيقونة لا تتلاشى)
      await PrayerCardFontPrefs.save(-2);
      expect(prefs.getInt(kPrayerCardFontAdjustKey), -2);
      expect(PrayerCardFontPrefs.nameFontSize, 11 - 2);
      expect(PrayerCardFontPrefs.timeFontSize, 12.5 - 2);
      expect(PrayerCardFontPrefs.periodFontSize, 10 - 2);
      expect(PrayerCardFontPrefs.iconSize, 13 - 2);
      expect(PrayerCardFontPrefs.currentLabel(), 'تصغير (−2)');

      // والعودة للعادي
      await PrayerCardFontPrefs.save(0);
      expect(prefs.getInt(kPrayerCardFontAdjustKey), 0);
      expect(PrayerCardFontPrefs.nameFontSize, 11);
      expect(PrayerCardFontPrefs.timeFontSize, 12.5);
      expect(PrayerCardFontPrefs.periodFontSize, 10);
      expect(PrayerCardFontPrefs.iconSize, 13);
      expect(PrayerCardFontPrefs.currentLabel(), 'عادي (0)');
    });

    test('قيمة شاذة محفوظة تُقرَّب ولا تخرج عن الدروج الثلاث', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kPrayerCardFontAdjustKey: 9,
      });
      await PrayerCardFontPrefs.load();
      expect(PrayerCardFontPrefs.adjustment.value, 2);
      expect(PrayerCardFontPrefs.currentLabel(), 'تكبير (+2)');
    });

    test('التحميل يقرأ المحفوظ، والغائب يبقي الحالي بلا انفجار', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kPrayerCardFontAdjustKey: -2,
      });
      await PrayerCardFontPrefs.load();
      expect(PrayerCardFontPrefs.adjustment.value, -2);

      // لا مفتاح محفوظ (أول تشغيل) → تبقى القيمة القائمة بلا انفجار
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await PrayerCardFontPrefs.load();
      expect(PrayerCardFontPrefs.adjustment.value, -2);

      // قيمة بنوع آخر (نسخة قديمة كتبت نصاً) → لا انفجار
      SharedPreferences.setMockInitialValues(<String, Object>{
        kPrayerCardFontAdjustKey: 'big',
      });
      await PrayerCardFontPrefs.load();
      expect(PrayerCardFontPrefs.currentLabel(), isNotEmpty);
    });

    test('الترحيل من المفتاح القديم: «مشغّل» يعني تكبيراً (+2)', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kPrayerCardFontEnlargedKey: true,
      });
      await PrayerCardFontPrefs.load();
      expect(PrayerCardFontPrefs.adjustment.value, 2);

      // والقديم المُطفأ يبقى عادياً
      SharedPreferences.setMockInitialValues(<String, Object>{
        kPrayerCardFontEnlargedKey: false,
      });
      PrayerCardFontPrefs.adjustment.value = 0;
      await PrayerCardFontPrefs.load();
      expect(PrayerCardFontPrefs.adjustment.value, 0);

      // والدرجة الجديدة تسبق المفتاح القديم
      SharedPreferences.setMockInitialValues(<String, Object>{
        kPrayerCardFontAdjustKey: -2,
        kPrayerCardFontEnlargedKey: true,
      });
      await PrayerCardFontPrefs.load();
      expect(PrayerCardFontPrefs.adjustment.value, -2);
    });
  });

  // ── 2) الكاردات فعلاً: الحجم المقاس ─────────────────────────────────────
  group('كاردات أوقات الصلاة', () {
    PrayerTimes buildPrayerTimes() => PrayerTimes(
          Coordinates(32.1167, 20.0667), // بنغازي
          DateComponents.from(DateTime(2026, 9, 14)),
          CalculationMethod.egyptian.getParameters(),
        );

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

    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(home: buildHomeTab()));
      await tester.pump(const Duration(milliseconds: 50));
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    double sizeOf(WidgetTester tester, Finder finder) =>
        tester.widget<Text>(finder).style!.fontSize!;

    double nameSize(WidgetTester tester) => sizeOf(tester, _sunriseName);
    double timeSize(WidgetTester tester) => sizeOf(tester, _sunriseTime);
    double periodSize(WidgetTester tester) => sizeOf(tester, _sunrisePeriod);

    double iconSize(WidgetTester tester) => tester
        .widget<Icon>(
          find.descendant(of: _sunriseTile, matching: find.byType(Icon)),
        )
        .size!;

    testWidgets('عند الدرجة 0: الاسم 11 والوقت 12.5 والفترة 10 والأيقونة 13', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const Size(390, 844));

      expect(nameSize(tester), 11);
      expect(timeSize(tester), 12.5);
      expect(periodSize(tester), 10);
      expect(iconSize(tester), 13);

      await unmount(tester);
    });

    testWidgets('التكبير (+2) يكبّر الاسم والوقت والفترة والأيقونة معاً', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const Size(390, 844));

      PrayerCardFontPrefs.adjustment.value = 2;
      await tester.pump();
      expect(nameSize(tester), 13);
      expect(timeSize(tester), 14.5);
      expect(periodSize(tester), 12);
      expect(iconSize(tester), 15);

      // والعودة إلى 0 تُرجع الأحجام الأصلية فوراً
      PrayerCardFontPrefs.adjustment.value = 0;
      await tester.pump();
      expect(nameSize(tester), 11);
      expect(timeSize(tester), 12.5);
      expect(periodSize(tester), 10);
      expect(iconSize(tester), 13);

      await unmount(tester);
    });

    testWidgets('التصغير (−2) يصغّر الاسم والوقت والفترة والأيقونة معاً', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const Size(390, 844));

      PrayerCardFontPrefs.adjustment.value = -2;
      await tester.pump();
      expect(nameSize(tester), 9);
      expect(timeSize(tester), 10.5);
      expect(periodSize(tester), 8);
      expect(iconSize(tester), 11);

      await unmount(tester);
    });

    testWidgets('التكبير يصل بلا rebuild من الشاشة الأم وبلا أوفرفلو على 320×568', (
      WidgetTester tester,
    ) async {
      // الدرجة مشغّلة قبل الإقلاع — أصعب حالة على المساحة
      PrayerCardFontPrefs.adjustment.value = 2;
      await pumpAt(tester, const Size(320, 568));

      expect(tester.takeException(), isNull, reason: 'أوفرفلو بالتکبير');
      expect(nameSize(tester), 13);
      expect(_sunriseTime, findsOneWidget);

      // ثم التصغير والشاشة قائمة
      PrayerCardFontPrefs.adjustment.value = -2;
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(nameSize(tester), 9);

      // ثم العادي
      PrayerCardFontPrefs.adjustment.value = 0;
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(nameSize(tester), 11);

      await unmount(tester);
    });
  });

  // ── 3) الوصل: الإعداد في الشاشة والإقلاع والشاشة الرئيسية ───────────────
  group('الوصل في الواجهة', () {
    test('الإعدادات فيها اختيار يقرأ ويكتب الدرجة', () {
      final String settings = File(
        'lib/features/settings/presentation/pages/settings_screen.dart',
      ).readAsStringSync();

      expect(settings.contains("'تكبير خط كاردات الصلاة'"), isTrue);
      expect(settings.contains('PrayerCardFontPrefs.adjustment.value'), isTrue);
      expect(settings.contains('await PrayerCardFontPrefs.save(v)'), isTrue);
      expect(settings.contains('PrayerCardFontPrefs.currentLabel()'), isTrue);
      expect(settings.contains('PrayerCardFontPrefs.labelOf(v)'), isTrue);
      // قائمة اختيار لا مفتاح تشغيل/إيقاف: لا قيمة منطقية تُمرَّر للتفضيل
      expect(
        settings.contains('value: PrayerCardFontPrefs'),
        isFalse,
        reason: 'الدرجة تُختار من قائمة الاختيار لا من مفتاح',
      );
    });

    test('التطبيق يُحمِّل الحالة المحفوظة عند الإقلاع', () {
      final String mainSource = File('lib/main.dart').readAsStringSync();
      expect(mainSource.contains('PrayerCardFontPrefs.load()'), isTrue);
      expect(
        mainSource.contains("core/config/prayer_card_font_prefs.dart"),
        isTrue,
      );
    });

    test('الكارد يقرأ الأحجام من التفضيل لا من أرقام مكتوبة', () {
      final String home = File(
        'lib/features/home/presentation/widgets/prayer_times_screen.dart',
      ).readAsStringSync();

      expect(home.contains('PrayerCardFontPrefs.nameFontSize'), isTrue);
      expect(home.contains('PrayerCardFontPrefs.timeFontSize'), isTrue);
      expect(home.contains('PrayerCardFontPrefs.periodFontSize'), isTrue);
      expect(home.contains('PrayerCardFontPrefs.iconSize'), isTrue);
      // ويُعاد بناؤه عند تغيير الدرجة من الإعدادات
      expect(home.contains('PrayerCardFontPrefs.adjustment'), isTrue);
      expect(home.contains('ValueListenableBuilder'), isTrue);
      // لا تبقى أحجام الكارد مكتوبة في مكانها
      expect(home.contains('fontSize: 12.5,'), isFalse);
      expect(home.contains('size: 13,'), isFalse);
    });
  });
}
