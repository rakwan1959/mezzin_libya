import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:muezzin_libya_app/features/settings/presentation/widgets/settings_marquee_header.dart';
import 'package:muezzin_libya_app/remote_messaging_service.dart';

/// ── هيدر شاشة الإعدادات: حديث متقلّب بوقت ظهور ──────────────────────────────
///
/// المطلوب من المستخدم: الشريط العلوي في شاشة الإعدادات يعرض **أحاديث**
/// تظهر واحداً بعد الآخر، و**وقت الظهور** يُحدَّد من لوحة التحكم (1918).
///
/// هذه الاختبارات تحرس:
///   1. أول حديث يظهر **فوراً** (بلا انتظار وقت الظهور).
///   2. التقليب يحدث **بعد** وقت الظهور بالضبط، ويدور على القائمة.
///   3. حديث واحد = لا تقليب ولا مؤقّت (نفس سلوك النسخ السابقة).
///   4. بلا أحاديث لا ينهار الهيدر ولا يُعرض نص.
///   5. اللوحة والشاشة موصولتان بالمكوّن الجديد (لا نسختان من الكود).
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> pumpHeader(
    WidgetTester tester, {
    required List<String> messages,
    SettingsMarqueeSettings settings = const SettingsMarqueeSettings(),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SettingsMarqueeHeader(
              messages: messages,
              settings: settings,
            ),
          ),
        ),
      ),
    );
    // إطار واحد فقط: الشريط متحرّك باستمرار فلا يصلح pumpAndSettle أبداً.
    await tester.pump();
  }

  /// يُزيل الشريط فيُلغى مؤقّته (فلا يبقى مؤقّت معلّق بعد الاختبار).
  Future<void> disposeHeader(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  group('التقليب ووقت الظهور', () {
    testWidgets('يعرض أول حديث فوراً ثم يتقلّب بعده بوقت الظهور', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        messages: const <String>['الحديث الأول', 'الحديث الثاني', 'الحديث الثالث'],
        settings: const SettingsMarqueeSettings(intervalMs: 1500),
      );

      expect(find.text('الحديث الأول'), findsWidgets, reason: 'يظهر فوراً');
      expect(find.text('الحديث الثاني'), findsNothing);

      // قبل انتهاء وقت الظهور لا يتغيّر شيء
      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.text('الحديث الأول'), findsWidgets);
      expect(find.text('الحديث الثاني'), findsNothing);

      // بعده ينتقل إلى التالي
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('الحديث الثاني'), findsWidgets);
      expect(find.text('الحديث الأول'), findsNothing);

      // ثم الثالث ثم يعود للأول (تقلّب دائري)
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('الحديث الثالث'), findsWidgets);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('الحديث الأول'), findsWidgets, reason: 'الدوران للبداية');

      await disposeHeader(tester);
    });

    testWidgets('حديث أطول من الشريط: التحرّك والتقليب المتكرّر بلا مؤقّت ثانٍ', (
      tester,
    ) async {
      // هذا الاختبار يحرس عيباً حقيقياً: المكوّن يخلط
      // `SingleTickerProviderStateMixin`، وكان **كل تقليب** يُنشئ
      // `AnimationController` جديداً فيُسقط الواجهة في وضع التصحيح (وفي
      // الإصدار يُسرّب مؤقّتاً قديماً). ولم يظهر ذلك إلا بنص **أطول من عرض
      // الشريط** يبدأ التحرّك فعلاً — أما الأحاديث القصيرة فلا تُشغّل المتحرّك.
      const String long =
          '«إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى» '
          'رواه البخاري ومسلم — حديث طويل يُحرَّك أفقياً بسرعة ثلاثين بكسل في '
          'الثانية فلا بد أن يتجاوز عرض الشريط بمسافة كافية للاختبار.';

      await pumpHeader(
        tester,
        messages: const <String>[long, 'حديث ثانٍ طويل أيضاً: $long'],
        settings: const SettingsMarqueeSettings(intervalMs: 1500),
      );

      final ScrollController scroll = tester
          .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .controller!;

      // الشريط يتحرّك فعلاً (وإلا كان الاختبار فارغاً بلا معنى)
      await tester.pump(const Duration(milliseconds: 400));
      expect(scroll.offset, greaterThan(0), reason: 'التحرّك بدأ' );

      // ثم تقليب: يعود الشريط لبداية الحديث الجديد
      await tester.pump(const Duration(milliseconds: 1200));
      expect(scroll.offset, 0, reason: 'يعود لبداية الحديث الجديد');

      // ثم يتحرّك من جديد — وإعادة التشغيل تُجدوَل في إطار يلي إطار التقليب،
      // فلا يكفي إطار واحد للحكم عليها.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(scroll.offset, greaterThan(0), reason: 'ويتحرّك من جديد');

      // تقليبات متكرّرة: كان كل واحد منها يُنشئ متحرّكاً جديداً فيسقط الهيدر
      // (والمتحرّك العائد لـ SingleTickerProviderStateMixin واحد فقط).
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 1500));

      final bool first = find.text(long).evaluate().isNotEmpty;
      final bool second = find
          .text('حديث ثانٍ طويل أيضاً: $long')
          .evaluate()
          .isNotEmpty;
      expect(first || second, isTrue, reason: 'الشريط يعرض حديثاً بعد التقليبات');
      expect(
        first && second,
        isFalse,
        reason: 'حديث واحد في كل مرة لا حديثان معاً',
      );

      await disposeHeader(tester);
    });

    testWidgets('تغيير وقت الظهور يسري فوراً', (tester) async {
      await pumpHeader(
        tester,
        messages: const <String>['أ', 'ب'],
        settings: const SettingsMarqueeSettings(intervalMs: 20000),
      );
      expect(find.text('أ'), findsWidgets);

      // نفس الحديثين بوقت ظهور قصير: التقليب صار أسرع
      await pumpHeader(
        tester,
        messages: const <String>['أ', 'ب'],
        settings: const SettingsMarqueeSettings(intervalMs: 1500),
      );
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text('ب'), findsWidgets);

      await disposeHeader(tester);
    });
  });

  group('حالات الحدود', () {
    testWidgets('حديث واحد: لا تقليب ولا مؤقّت معلّق', (tester) async {
      await pumpHeader(
        tester,
        messages: const <String>['حديث وحيد'],
        settings: const SettingsMarqueeSettings(intervalMs: 1500),
      );

      expect(find.text('حديث وحيد'), findsWidgets);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('حديث وحيد'), findsWidgets);

      await disposeHeader(tester);
    });

    testWidgets('بلا أحاديث: لا نص ولا انهيار', (tester) async {
      await pumpHeader(tester, messages: const <String>[]);

      expect(find.byType(Text), findsNothing);
      expect(find.byType(SettingsMarqueeHeader), findsOneWidget);

      await disposeHeader(tester);
    });

    test('messageFor يدور على القائمة', () {
      const List<String> list = <String>['أ', 'ب', 'ج'];
      expect(SettingsMarqueeHeader.messageFor(list, 0), 'أ');
      expect(SettingsMarqueeHeader.messageFor(list, 2), 'ج');
      expect(SettingsMarqueeHeader.messageFor(list, 3), 'أ');
      expect(SettingsMarqueeHeader.messageFor(list, 7), 'ب');
      expect(SettingsMarqueeHeader.messageFor(const <String>[], 4), '');
    });
  });

  group('المصدر: المكوّن واحد وموصول', () {
    final String screen = File(
      'lib/features/settings/presentation/pages/settings_screen.dart',
    ).readAsStringSync();
    final String admin = File('lib/admin_panel_screen.dart').readAsStringSync();

    test('شاشة الإعدادات تستعمل المكوّن المستقل بالأحاديث', () {
      expect(screen.contains('SettingsMarqueeHeader('), isTrue);
      expect(screen.contains('messages: _marqueeMessages'), isTrue);
      expect(
        screen.contains('_MarqueeTextHeader'),
        isFalse,
        reason: 'المكوّن القديم المكتوب داخل الشاشة أُزيل',
      );
    });

    test('لوحة التحكم تنشر الأحاديث ووقت الظهور', () {
      expect(admin.contains('messages: messages'), isTrue);
      expect(admin.contains('intervalMs: _settingsMarqueeIntervalMs'), isTrue);
      expect(admin.contains('_addMarqueeHadith'), isTrue);
      expect(admin.contains('_removeMarqueeHadith'), isTrue);
      // ومكوّن التحرير واحد في التبويبين لا نسختان
      expect(admin.contains('_buildSettingsMarqueeEditor()'), isTrue);
    });
  });
}
