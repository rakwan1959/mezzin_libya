import 'dart:io';
import 'dart:ui' as ui;

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muezzin_libya_app/core/theme/glass_theme.dart';
import 'package:muezzin_libya_app/core/widgets/aurora_background.dart';

/// خلفية الشاشة الرئيسية عند أول تشغيل = **أسود**.
///
/// كان الافتراضي مسجَّلاً «أسود» فعلاً في الكود، لكن وضع «أسود» نفسه كان
/// تدرّجاً بنفسجياً داكناً (`#030308 → #0D0D18 → #1B1030`) وفوقه بقع أورورا
/// بنفسجية/نيلية، فكان المستخدم يرى شاشة بنفسجية لا سوداء. هنا نقيس الخلفية
/// المرسومة بالبكسل — لا القيم النصّية — حتى لا يعود التلوّن مستقبلاً.
class _ScreenStats {
  _ScreenStats({
    required this.meanLuminance,
    required this.maxLuminance,
    required this.meanChannelSpread,
    required this.meanBlueMinusRed,
  });

  final double meanLuminance;
  final double maxLuminance;

  /// متوسّط (أقصى قناة − أدنى قناة) لكل بكسل: 0 = رمادي محايد،
  /// وكلما كبر دلّ على تلوّن (بنفسجي/كحلي…).
  final double meanChannelSpread;

  /// متوسّط (الأزرق − الأحمر): يفضح المسحة الكحلية/البنفسجية.
  final double meanBlueMinusRed;

  @override
  String toString() => 'سطوع متوسط=${meanLuminance.toStringAsFixed(4)}، '
      'أقصى=${maxLuminance.toStringAsFixed(4)}، '
      'تلوّن=${meanChannelSpread.toStringAsFixed(2)}، '
      'أزرق−أحمر=${meanBlueMinusRed.toStringAsFixed(2)}';
}

Future<_ScreenStats> _measureBackground(WidgetTester tester, String themeMode) async {
  final key = GlobalKey();

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.rtl,
      child: RepaintBoundary(
        key: key,
        child: AuroraBackground(
          // نفس ما تستعمله الشاشة الرئيسية حرفياً
          colors: GlassPalette.gradientFor(themeMode),
          glowColors: GlassPalette.auroraGlowFor(themeMode),
          animated: false,
          intensity: GlassIntensity.ultra.glowScale,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
  await tester.pump();

  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late List<int> rgba;
  late int width;
  late int height;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    width = image.width;
    height = image.height;
    rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  });

  var sumLuminance = 0.0;
  var maxLuminance = 0.0;
  var sumSpread = 0.0;
  var sumBlueMinusRed = 0.0;

  for (var y = 0; y < height; y += 4) {
    for (var x = 0; x < width; x += 4) {
      final i = (y * width + x) * 4;
      final r = rgba[i];
      final g = rgba[i + 1];
      final b = rgba[i + 2];
      final luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
      final maxChannel = r > g ? (r > b ? r : b) : (g > b ? g : b);
      final minChannel = r < g ? (r < b ? r : b) : (g < b ? g : b);

      sumLuminance += luminance;
      if (luminance > maxLuminance) maxLuminance = luminance;
      sumSpread += (maxChannel - minChannel).toDouble();
      sumBlueMinusRed += (b - r).toDouble();
    }
  }

  final samples = ((height + 3) ~/ 4) * ((width + 3) ~/ 4);
  return _ScreenStats(
    meanLuminance: sumLuminance / samples,
    maxLuminance: maxLuminance,
    meanChannelSpread: sumSpread / samples,
    meanBlueMinusRed: sumBlueMinusRed / samples,
  );
}

void main() {
  testWidgets('خلفية الشاشة الرئيسية الافتراضية (وضع أسود) سوداء بلا تلوّن',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final black = await _measureBackground(tester, 'black');
    final reason = 'الخلفية ليست سوداء: $black';

    expect(black.meanLuminance, lessThan(0.02), reason: reason);
    expect(black.maxLuminance, lessThan(0.10), reason: reason);
    // رمادي محايد: لا مسحة بنفسجية ولا كحلية
    expect(black.meanChannelSpread, lessThan(8), reason: reason);
    expect(black.meanBlueMinusRed, lessThan(5), reason: reason);
  });

  testWidgets('الوضع الكحلي يبقى كحلياً — فالقياس يميّز فعلاً', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final navy = await _measureBackground(tester, 'navy');
    final reason = 'الوضع الكحلي فقد لونه: $navy';

    expect(navy.meanBlueMinusRed, greaterThan(10), reason: reason);
    expect(navy.meanLuminance, greaterThan(0.01), reason: reason);
  });

  test('ألوان وضع «أسود» نفسها محايدة تماماً (تدرّج + أورورا)', () {
    int channel8(double value) => (value * 255).round().clamp(0, 255);

    for (final Color c in GlassPalette.baseGradient('black')) {
      expect(channel8(c.r), lessThanOrEqualTo(10), reason: 'تدرّج أسود ملوّن: $c');
      expect(channel8(c.g), lessThanOrEqualTo(10), reason: 'تدرّج أسود ملوّن: $c');
      expect(channel8(c.b), lessThanOrEqualTo(10), reason: 'تدرّج أسود ملوّن: $c');
    }

    for (final Color c in GlassPalette.auroraGlowFor('black')) {
      final List<int> channels = [channel8(c.r), channel8(c.g), channel8(c.b)];
      final maxChannel = channels.reduce((a, b) => a > b ? a : b);
      final minChannel = channels.reduce((a, b) => a < b ? a : b);
      expect(maxChannel - minChannel, lessThanOrEqualTo(6),
          reason: 'بقعة أورورا ملوّنة في الوضع الأسود: $c');
      expect(maxChannel, lessThanOrEqualTo(45),
          reason: 'بقعة أورورا ساطعة تكسر سواد الخلفية: $c');
    }
  });

  test('الوضع العام الافتراضي قبل أي اختيار للمستخدم هو «أسود»', () {
    expect(GlassRuntime.themeMode, 'black');
  });

  // ── العطل الذي ظهر على الجهاز ────────────────────────────────────────────
  // «علامة الصح على الأسود لكن الشاشة حمراء»: أي وضع غير معروف كان يسقط
  // على تدرّج الصلاة القادمة — وعند المغرب يصير عنابياً أحمر.
  group('وضع عرض غير معروف لا يُنتج شاشة حمراء', () {
    double redness(Color c) => c.r - c.b; // أحمر يقهر الأزرق

    test('القيم المجهولة والقديمة والفارغة كلها تعود إلى «أسود»', () {
      for (final String? weird in <String?>[
        null,
        '',
        '   ',
        'dark',
        'night_mode',
        'light',
        'أزرق',
        'unknown-mode',
        'black ', // ‏مسافة زائدة
      ]) {
        expect(GlassPalette.normalizeThemeMode(weird), 'black',
            reason: 'القيمة «$weird» لم تُطبَّع إلى أسود');
      }
    });

    test('الأوضاع المعروفة تُقبل كما هي (وتلقائي يبقى تلقائياً)', () {
      for (final String mode in GlassPalette.themeModes) {
        expect(GlassPalette.normalizeThemeMode(mode), mode);
      }
      expect(GlassPalette.normalizeThemeMode('navy'), 'navy');
      expect(GlassPalette.normalizeThemeMode('أسود'), 'black');
      expect(GlassPalette.normalizeThemeMode('كحلي ملكي'), 'navy');
      expect(GlassPalette.normalizeThemeMode('تلقائي (النظام)'), 'system');
    });

    test('تدرّج الصلاة عند المغرب أحمر فعلاً (شاهد على خطورة السقوط إليه)', () {
      final List<Color> maghrib =
          GlassPalette.dynamicGradient(Prayer.maghrib);
      final double worst = maghrib
          .map(redness)
          .reduce((double a, double b) => a > b ? a : b);
      expect(worst, greaterThan(0.10),
          reason: 'تدرّج المغرب ليس أحمر — الاختبار لم يعد يمثّل العطل');
    });

    test('ولا وضع مجهول أو «تلقائي» يعطيه هذا التدرّج الأحمر', () {
      final List<Color> maghrib =
          GlassPalette.dynamicGradient(Prayer.maghrib);

      for (final String weird in <String>['', 'unknown', 'dark', 'system']) {
        final List<Color> gradient =
            GlassPalette.baseGradient(weird, nextPrayer: Prayer.maghrib);
        final List<Color> glows =
            GlassPalette.auroraGlowFor(weird, nextPrayer: Prayer.maghrib);

        expect(gradient, isNot(maghrib),
            reason: 'الوضع «$weird» ما زال يسقط على تدرّج المغرب الأحمر');
        for (final Color c in <Color>[...gradient, ...glows]) {
          expect(redness(c), lessThan(0.05),
              reason: 'الوضع «$weird» أنتج لوناً أحمر: $c');
        }
      }
    });

    test('الوضع العالمي لا يقبل قيمة مجهولة (فلا تصل إلى الخلفية)', () {
      final String before = GlassRuntime.themeMode;
      addTearDown(() => GlassRuntime.themeMode = before);

      GlassRuntime.themeMode = 'قيمة غير معروفة';
      expect(GlassRuntime.themeMode, 'black');

      GlassRuntime.themeMode = 'navy';
      expect(GlassRuntime.themeMode, 'navy');
    });
  });

  test('أول تشغيل: الافتراضي المُعلن في الكود أسود (حراسة ضد الرجوع)', () {
    String read(String path) => File(path).readAsStringSync();

    final mainSrc = read('lib/main.dart');
    expect(RegExp(r"_currentTheme\s*=\s*'black'").hasMatch(mainSrc), isTrue,
        reason: 'الوضع الابتدائي لأول إطار لم يعد أسود');
    // الوضع المحفوظ يُطبَّع ويُعاد كتابته — فلا تبقى قيمة مجهولة في التخزين
    expect(RegExp(r"normalizeThemeMode\(stored\)").hasMatch(mainSrc), isTrue,
        reason: 'الوضع المحفوظ لم يعد يُطبَّع في main.dart');
    expect(RegExp(r"setString\('themeMode',\s*m\)").hasMatch(mainSrc), isTrue,
        reason: 'الوضع المُطبَّع لم يعد يُحفظ (فتعود القيمة المجهولة كل مرة)');

    final homeSrc = read('lib/features/home/presentation/pages/home_page.dart');
    expect(RegExp(r"_themeModeStr\s*=\s*'black'").hasMatch(homeSrc), isTrue,
        reason: 'الافتراضي في الشاشة الرئيسية لم يعد أسود');
    expect(homeSrc, contains('normalizeThemeMode'),
        reason: 'الشاشة الرئيسية لم تعد تُطبّع الوضع المحفوظ');

    final settingsSrc =
        read('lib/features/settings/presentation/pages/settings_screen.dart');
    expect(settingsSrc, contains('normalizeThemeMode'),
        reason: 'شاشة الإعدادات تعرض وضعاً غير الذي تراه على الشاشة');
  });
}
