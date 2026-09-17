import 'dart:io';

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:muezzin_libya_app/core/config/home_date_font_prefs.dart';
import 'package:muezzin_libya_app/core/config/text_scale_boost.dart';
import 'package:muezzin_libya_app/features/home/presentation/widgets/prayer_times_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ── إعداد «حجم خط التاريخ (الهجري والميلادي)» ───────────────────────────────
///
/// المطلوب من المستخدم: تكبير/تصغير خطّ تاريخ الشاشة الرئيسية من الإعدادات
/// **مع حفظ الاختيار** — فلا يعود الحجم الأصلي عند كل تشغيل.
///
/// الحرس هنا من ثلاث جهات:
///   1. التفضيل نفسه: القيمة الافتراضية والحفظ والتحميل وتجاهل القيم التالفة.
///   2. الشاشة الرئيسية فعلاً: حجم خطّي التاريخين يقاس من الـText المبني.
///   3. التكبير لا يُحدث أوفرفلو على أصغر شاشة (شاشة 320×568).
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
      // الخطوط ليست حرجة: نقيس قيم fontSize لا العرض
    }
  }
}

/// ارتفاع شريط المهام السفلي في التطبيق — ننقصه من ارتفاع الاختبار حتى تكون
/// المساحة المتاحة للشاشة الرئيسية مطابقة لما يحدث على الجهاز فعلاً.
const double _kTaskBarHeight = 76;

/// نصّ التاريخ الهجري (ينتهي بـ«هـ») — لا يلتبس مع أي نصّ آخر في الشاشة.
Finder get _hijriDate => find.byWidgetPredicate(
      (Widget w) => w is Text && (w.data?.endsWith('هـ') ?? false),
      description: 'نصّ التاريخ الهجري',
    );

/// نصّ التاريخ الميلادي (يضمّ الفاصل «|» بين التاريخ واليوم).
Finder get _gregorianDate => find.byWidgetPredicate(
      (Widget w) => w is Text && (w.data?.contains(' | ') ?? false),
      description: 'نصّ التاريخ الميلادي',
    );

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    await initializeDateFormatting();
    await _loadAppFonts();
  });

  // القيمة إعداد ثابت (static) في الذاكرة — تُصفَّر بين الاختبارات
  setUp(() => HomeDateFontPrefs.adjustment.value = 0);

  // ── 1) التفضيل: الافتراضي والحفظ والتحميل ───────────────────────────────
  group('التفضيل المحفوظ', () {
    test('الافتراضي «عادي» والأساسان 15 و10', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await HomeDateFontPrefs.load();

      expect(HomeDateFontPrefs.adjustment.value, 0);
      expect(HomeDateFontPrefs.currentLabel(), 'عادي');
      expect(HomeDateFontPrefs.hijriFontSize, kHijriDateBaseFontSize);
      expect(HomeDateFontPrefs.gregorianFontSize, kGregorianDateBaseFontSize);
      // القيم المُتفَق عليها مع «حجم خط العناوين»
      expect(HomeDateFontPrefs.options, <int>[-3, 0, 3]);
    });

    test('الحفظ يُكتب في التخزين ويُبثّ فوراً على التاريخين معاً', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await HomeDateFontPrefs.save(3);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(kHomeDateFontAdjustmentKey), 3);
      expect(HomeDateFontPrefs.adjustment.value, 3);
      expect(HomeDateFontPrefs.hijriFontSize, 15 + 3);
      expect(HomeDateFontPrefs.gregorianFontSize, 10 + 3);

      await HomeDateFontPrefs.save(-3);
      expect(prefs.getInt(kHomeDateFontAdjustmentKey), -3);
      expect(HomeDateFontPrefs.hijriFontSize, 15 - 3);
      expect(HomeDateFontPrefs.gregorianFontSize, 10 - 3);
      expect(HomeDateFontPrefs.currentLabel(), 'تصغير (-3)');
    });

    test('التحميل يقرأ المحفوظ ويتجاهل أي قيمة غير مسموح بها', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kHomeDateFontAdjustmentKey: 3,
      });
      await HomeDateFontPrefs.load();
      expect(HomeDateFontPrefs.adjustment.value, 3);

      // قيمة تالفة (من نسخة قديمة) → يبقى الافتراضي بلا انفجار
      HomeDateFontPrefs.adjustment.value = 0;
      SharedPreferences.setMockInitialValues(<String, Object>{
        kHomeDateFontAdjustmentKey: 7,
      });
      await HomeDateFontPrefs.load();
      expect(HomeDateFontPrefs.adjustment.value, 0);
      expect(HomeDateFontPrefs.currentLabel(), 'عادي');
    });
  });

  // ── 2) الشاشة الرئيسية: الحجم المقاس فعلاً ─────────────────────────────
  group('الشاشة الرئيسية', () {
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

    double hijriSize(WidgetTester tester) =>
        tester.widget<Text>(_hijriDate).style!.fontSize!;
    double gregorianSize(WidgetTester tester) =>
        tester.widget<Text>(_gregorianDate).style!.fontSize!;

    testWidgets('الحجم الافتراضي 15 للهجري و10 للميلادي', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const Size(390, 844));
      expect(hijriSize(tester), 15);
      expect(gregorianSize(tester), 10);
      await unmount(tester);
    });

    testWidgets('التكبير والتصغير يصلان إلى التاريخين من التفضيل', (
      WidgetTester tester,
    ) async {
      await pumpAt(tester, const Size(390, 844));

      HomeDateFontPrefs.adjustment.value = 3;
      // الشاشة تُعاد بناؤها بدقّة مؤقّت الساعة (كل ثانية) — كما تفعل فعلاً
      // عندما يستدعي الإعدادات `widget.onUpdate()` بعد الحفظ
      await tester.pump(const Duration(milliseconds: 1100));
      expect(hijriSize(tester), 18);
      expect(gregorianSize(tester), 13);

      HomeDateFontPrefs.adjustment.value = -3;
      await tester.pump(const Duration(milliseconds: 1100));
      expect(hijriSize(tester), 12);
      expect(gregorianSize(tester), 7);

      await unmount(tester);
    });

    testWidgets('التكبير + التصغير لا يُحدثان أوفرفلو على 320×568', (
      WidgetTester tester,
    ) async {
      for (final int delta in <int>[3, -3]) {
        HomeDateFontPrefs.adjustment.value = delta;
        await pumpAt(tester, const Size(320, 568));
        expect(tester.takeException(), isNull, reason: 'أوفرفلو عند $delta');
        expect(_hijriDate, findsOneWidget);
        await unmount(tester);
      }
    });
  });

  // ── 3) الوصل: الإعداد موجود في الشاشة ويُحمَّل عند تشغيل التطبيق ─────────
  group('الوصل في الواجهة', () {
    test('صفّ الإعداد في شاشة الإعدادات يقرأ ويكتب التفضيل', () {
      final String settings = File(
        'lib/features/settings/presentation/pages/settings_screen.dart',
      ).readAsStringSync();

      expect(settings.contains("'حجم خط التاريخ (الهجري والميلادي)'"), isTrue);
      expect(settings.contains('HomeDateFontPrefs.currentLabel()'), isTrue);
      expect(settings.contains('HomeDateFontPrefs.adjustment.value'), isTrue);
      expect(settings.contains('await HomeDateFontPrefs.save(v)'), isTrue);
      // والاختيار يُحدّث الشاشة الرئيسية فوراً
      expect(settings.contains('widget.onUpdate()'), isTrue);
    });

    test('التطبيق يُحمِّل التفضيل المحفوظ عند الإقلاع', () {
      final String mainSource = File('lib/main.dart').readAsStringSync();
      expect(mainSource.contains('HomeDateFontPrefs.load()'), isTrue);
      expect(mainSource.contains("core/config/home_date_font_prefs.dart"), isTrue);
    });

    test('الشاشة الرئيسية لا تُثبّت أحجام التاريخين في مكانها', () {
      final String home = File(
        'lib/features/home/presentation/widgets/prayer_times_screen.dart',
      ).readAsStringSync();

      expect(home.contains('HomeDateFontPrefs.hijriFontSize'), isTrue);
      expect(home.contains('HomeDateFontPrefs.gregorianFontSize'), isTrue);
    });
  });
}
