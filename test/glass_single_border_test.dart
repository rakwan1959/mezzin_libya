import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muezzin_libya_app/core/theme/glass_theme.dart';
import 'package:muezzin_libya_app/core/widgets/glass_widgets.dart';

/// ── خطّ واحد حول الرسائل ────────────────────────────────────────────────────
///
/// الشكوى التي وُلد منها هذا الملف: «خطوط صفراء تحت نصوص الرسائل» — كان سطح
/// الرسالة (الحوار والإشعار والزر) يُرسم بحدّين متوازيين: خطّ خارجي متدرّج
/// **وحافة داخلية ثانية** ([GlassPanel.showInnerEdge])، فيظهران كخطّين تحت
/// كلمات الرسالة. هذه الاختبارات تختم أن أسطح الرسائل صارت بخطّ واحد.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  /// كل أسطح الزجاج الظاهرة الآن في الشجرة.
  List<GlassPanel> panelsOf(WidgetTester tester) =>
      tester.widgetList<GlassPanel>(find.byType(GlassPanel)).toList();

  testWidgets('حوار الرسالة (showGlassDialog) يُرسم بخطّ واحد', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext ctx) => TextButton(
              onPressed: () => showGlassDialog<void>(
                context: ctx,
                kind: GlassNoticeKind.info,
                title: 'USR-R7UMAW',
                content: const Text('السلام عليكم'),
              ),
              child: const Text('افتح'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();

    // نافذة الرسالة ظهرت
    expect(find.text('السلام عليكم'), findsOneWidget);

    // ولا سطح فيها يُرسم بحافتين
    final List<GlassPanel> panels = panelsOf(tester);
    expect(panels, isNotEmpty, reason: 'لم يُبنَ سطح زجاجي للحوار');
    for (final GlassPanel p in panels) {
      expect(
        p.showInnerEdge,
        isFalse,
        reason: 'سطح الرسالة يرسم خطّين (خطّ + حافة داخلية)',
      );
    }
  });

  testWidgets('الزر الزجاجي (GlassButton) بخطّ واحد حوله', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(child: GlassButton(label: 'حسنا')),
        ),
      ),
    );
    await tester.pump();

    final List<GlassPanel> panels = panelsOf(tester);
    expect(panels, isNotEmpty);
    for (final GlassPanel p in panels) {
      expect(p.showInnerEdge, isFalse);
    }
  });

  testWidgets('الإشعار السريع (showGlassSnack) بخطّ واحد', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext ctx) => TextButton(
              onPressed: () => showGlassSnack(ctx, 'تم الإرسال'),
              child: const Text('أظهر'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('أظهر'));
    await tester.pumpAndSettle();

    expect(find.text('تم الإرسال'), findsOneWidget);
    for (final GlassPanel p in panelsOf(tester)) {
      expect(p.showInnerEdge, isFalse);
    }
  });

  test('القيمة الافتراضية للحافة الداخلية تبقى مفعّلة لبقية زجاج التطبيق', () {
    // لم نُلغِ الخطّ الثاني عن التطبيق كله — فقط عن أسطح الرسائل.
    expect(const GlassPanel(child: SizedBox()).showInnerEdge, isTrue);
  });
}
