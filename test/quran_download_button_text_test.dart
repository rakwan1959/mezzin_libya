import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muezzin_libya_app/features/quran/data/datasources/quran_download_service.dart';
import 'package:muezzin_libya_app/features/quran/presentation/pages/quran_offline_manager_screen.dart';
import 'package:muezzin_libya_app/injection_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نص زر الكارد الأصفر («ابدأ التحميل») لا يُقتطع:
///   1. حبر الحروف يبقى كاملاً داخل الزر حتى مع تكبير خط الجهاز (فحص بالبكسل).
///   2. الارتفاع في الشاشة الحقيقية ينمو مع تكبير الخط بدل التثبيت على 46.
///   3. نفس الزر مستعمل في نافذة التأكيد فلا يقع الاقتطاع هناك أيضاً.

/// الشاشة فيها قصّ/تجاوز تخطيط قديم لا علاقة له بالزر — نتجاهله هنا.
void _drainOverflow(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

Future<void> _loadAmiri() async {
  final bytes = await rootBundle.load('assets/fonts/alfont_com_خط-القران-اميري.ttf');
  await (FontLoader('Amiri')..addFont(Future<ByteData>.value(bytes))).load();
}

class _FakeDownloader extends QuranDownloadService {
  @override
  Future<int> getDownloadedCount(String reciterKey) async => 0;
  @override
  Future<int> getReciterStorageSize(String reciterKey) async => 0;
  @override
  int getTotalItemsForReciter(String reciterKey) => 1;
  @override
  bool isFullSurahReciter(String reciterKey) => true;
}

class _InkBounds {
  _InkBounds(this.top, this.bottom, this.buttonTop, this.buttonBottom, this.pixels);
  final int top;
  final int bottom;
  final int buttonTop;
  final int buttonBottom;
  final int pixels;

  bool get inside => top >= buttonTop && bottom <= buttonBottom;
  int get spillAbove => top >= buttonTop ? 0 : buttonTop - top;
  int get spillBelow => bottom <= buttonBottom ? 0 : bottom - buttonBottom;
}

/// يرسم الزر على خلفية بيضاء بلا ظل، ثم يقيس أقصى امتداد لحبر الحروف رأسياً.
Future<_InkBounds> _measureInk(WidgetTester tester, double textScale) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: RepaintBoundary(
            key: key,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: buildStartDownloadButton(onPressed: () {}, elevation: 0),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  final buttonRect = tester.getRect(find.byType(ElevatedButton));
  final labelRect = tester.getRect(find.text('ابدأ التحميل'));

  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late List<int> rgba;
  late int imgW;
  late int imgH;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    imgW = image.width;
    imgH = image.height;
    rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
  });

  final x0 = (labelRect.left - 8).clamp(0, imgW - 1).toInt();
  final x1 = (labelRect.right + 8).clamp(0, imgW - 1).toInt();
  var minY = 1 << 30;
  var maxY = -1;
  var pixels = 0;
  for (var y = 0; y < imgH; y++) {
    for (var x = x0; x <= x1; x++) {
      final i = (y * imgW + x) * 4;
      if (rgba[i] < 60 && rgba[i + 1] < 60 && rgba[i + 2] < 90) {
        pixels++;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  return _InkBounds(minY, maxY, buttonRect.top.round(), buttonRect.bottom.round(), pixels);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(_loadAmiri);

  testWidgets('حبر «ابدأ التحميل» يبقى داخل الزر عند كل تكبيرات الخط', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 320);
    addTearDown(tester.view.reset);

    for (final scale in <double>[1.0, 1.3, 1.5, 2.0, 2.5]) {
      final ink = await _measureInk(tester, scale);
      expect(
        ink.inside,
        isTrue,
        reason: 'تكبير $scale: النص مقتطع (فوق=${ink.spillAbove}px، تحت=${ink.spillBelow}px)',
      );
      expect(ink.bottom - ink.top, greaterThan(5),
          reason: 'تكبير $scale: لم يُرسم أي نص');
      // حبر حقيقي لحروف أميري (خطوط رفيعة) لا مربعات خط احتياطي ممتلئة
      expect(ink.pixels, inInclusiveRange(40, 600 * scale),
          reason: 'تكبير $scale: عدد بكسلات الحبر غير متوقع (${ink.pixels})');
    }
  });

  testWidgets('ارتفاع زر الكارد ينمو مع تكبير الخط ولا يُثبَّت', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await sl.reset();
    sl.registerLazySingleton<QuranDownloadService>(() => _FakeDownloader());

    Future<double> buttonHeightAt(double scale) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const MaterialApp(home: QuranOfflineManagerScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final label = find.text('ابدأ التحميل');
      expect(label, findsOneWidget, reason: 'نص الزر يجب أن يظهر كاملاً لا مقتطعاً');
      return tester.getSize(find.ancestor(of: label, matching: find.byType(ElevatedButton))).height;
    }

    final normal = await buttonHeightAt(1.0);
    final enlarged = await buttonHeightAt(2.0);

    expect(normal, greaterThanOrEqualTo(52),
        reason: 'الارتفاع العادي أصغر من أن يستوعب حبر الخط الأميري');
    expect(enlarged, greaterThan(normal),
        reason: 'عند تكبير خط الجهاز يجب أن يرتفع الزر بدل قصّ النص');
  });

  testWidgets('زر «ابدأ التحميل» داخل نافذة التأكيد بنفس الحجم الآمن', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: QuranOfflineManagerScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    _drainOverflow(tester);

    await tester.tap(find.ancestor(
      of: find.text('ابدأ التحميل'),
      matching: find.byType(ElevatedButton),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    _drainOverflow(tester);

    expect(find.text('تحميل القرآن لجميع القراء'), findsOneWidget,
        reason: 'نافذة تأكيد التحميل لم تُفتح');

    // زر النافذة فقط (زر الشاشة خلفها يبقى في الشجرة)
    final dialogButton = find.ancestor(
      of: find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('ابدأ التحميل'),
      ),
      matching: find.byType(ElevatedButton),
    );
    expect(dialogButton, findsOneWidget);
    expect(tester.getSize(dialogButton).height, greaterThanOrEqualTo(52),
        reason: 'زر التأكيد قصير فيُقتطع نصه');
  });
}
