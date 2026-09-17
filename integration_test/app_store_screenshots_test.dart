// لقطات شاشة صفحة App Store — تُلتقط من داخل التطبيق نفسه على محاكي iOS.
//
//   flutter drive \
//     --driver=test_driver/screenshot_driver.dart \
//     --target=integration_test/app_store_screenshots_test.dart \
//     -d <simulator-udid>
//
// تُحفظ الصور في مجلد screenshots/ بأسماء مرتّبة (01-…، 02-…) بترتيب App Store.
//
// ملاحظتان تقنيّتان مهمّتان:
//  1. واجهة التطبيق **حيّة** (خلفية الأورورا + تنفّس أيقونات التبويب يتحرّكان
//     بلا نهاية)، فـ pumpAndSettle() لن يعود أبداً — لذلك نُقدّم الإطارات
//     بأنفسنا مع انتظار زمني حقيقي عبر runAsync.
//  2. أي كارد/حوار يظهر فوق الواجهة (رسالة السلام، رسالة تهنئة…) يُغلق قبل
//     كل لقطة حتى تكون الصور نظيفة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:muezzin_libya_app/core/widgets/glass_nav_icon.dart';
import 'package:muezzin_libya_app/main.dart' as app;
import 'package:muezzin_libya_app/main.dart' show navigatorKey;

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // الإطارات تُرسَم باستمرار حتى تعكس اللقطة الواجهة الحيّة كما يراها المستخدم.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('جولة لقطات شاشة App Store', (WidgetTester tester) async {
    app.main();

    // شاشة البداية (AppSplashScreen) تبقى 5 ثوانٍ قبل بناء الواجهة الفعلية.
    await _waitFor(
      tester,
      find.byType(GlassNavIcon),
      const Duration(seconds: 120),
    );

    await _shot(tester, binding, '01-home-prayer-times');

    // التبويبات الخمسة في شريط المهام السفلي (الشاشة الرئيسية هي 0).
    const Map<int, String> tour = <int, String>{
      1: '02-islamic-library',
      2: '03-qibla',
      3: '04-settings',
      4: '05-about',
    };

    for (final MapEntry<int, String> stop in tour.entries) {
      await _openTab(tester, stop.key);
      await _shot(tester, binding, stop.value);
    }

    // تنتهي الجولة على الشاشة الرئيسية.
    await _openTab(tester, 0);
  });
}

/// ينتظر ظهور [finder] بزمن حقيقي حتى انتهاء [timeout].
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder,
  Duration timeout,
) async {
  final Stopwatch watch = Stopwatch()..start();
  while (watch.elapsed < timeout) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await _tick(tester, const Duration(milliseconds: 200));
  }
  fail('انتهت المهلة (${timeout.inSeconds}s) قبل ظهور $finder');
}

/// ينتظر زمناً حقيقياً مع الاستمرار في تقديم الإطارات.
Future<void> _settle(
  WidgetTester tester, [
  Duration duration = const Duration(milliseconds: 1200),
]) async {
  final Stopwatch watch = Stopwatch()..start();
  while (watch.elapsed < duration) {
    await _tick(tester, const Duration(milliseconds: 120));
  }
}

/// انتظار حقيقي (لا يعتمد على مؤقّتات الوهم) + إطار واحد.
Future<void> _tick(WidgetTester tester, Duration step) async {
  await tester.runAsync(() => Future<void>.delayed(step));
  await tester.pump();
}

/// يفتح تبويب شريط المهام السفلي [index] وينتظر بناء الشاشة.
Future<void> _openTab(WidgetTester tester, int index) async {
  final Finder item = find.byType(GlassNavIcon).at(index);
  await _waitFor(tester, item, const Duration(seconds: 20));
  await tester.tap(item, warnIfMissed: false);
  await _settle(tester, const Duration(seconds: 4));
}

/// يُغلق أي كارد/حوار مفتوح (رسالة سلام، تهنئة…) قبل اللقطة.
Future<void> _dismissOverlays(WidgetTester tester) async {
  for (int i = 0; i < 3; i++) {
    final NavigatorState? navigator = navigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) {
      return;
    }
    navigator.pop();
    await _settle(tester, const Duration(milliseconds: 700));
  }
}

/// لقطة شاشة واحدة بعد تثبيت الواجهة وتنظيفها.
Future<void> _shot(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  await _dismissOverlays(tester);
  await _settle(tester);
  await binding.takeScreenshot(name);
}
