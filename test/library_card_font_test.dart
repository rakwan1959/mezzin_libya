import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muezzin_libya_app/features/library/presentation/pages/library_screen.dart';

/// ── كاردات شاشة «الأذكار والمكتبة»: خطّ واحد أقل ────────────────────────────
///
/// المطلوب من المستخدم: تنقيص خطّ عناوين كاردات الشاشة **بمقدار واحد** عن
/// 14.5 (أي 13.5)، **ما عدا** كارد «الأربعون النووية» فيبقى 14.5.
///
/// الحرس هنا من جهتين:
///   1. المصدر: القيمة الافتراضية لـ[_buildCard] هي 13.5، والاستثناء الوحيد
///      الذي يمرّر 14.5 هو نداء الأربعون النووية.
///   2. العرض الفعلي: كل عنوان كارد يُقاس فعلياً، فيُثبَّت 13.5 للجميع
///      و14.5 للأربعون النووية.
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
      // الخطوط ليست حرجة: نقيس قيم fontSize لا العرض
    }
  }
}

/// عناوين الكاردات كما هي في الشاشة.
const List<String> _titles = <String>[
  'القرآن الكريم',
  'الأحاديث النبوية',
  'حصن المسلم',
  'أذكار الصباح',
  'أذكار المساء',
  'الأربعون النووية',
  'تسبيح',
  'الرقية الشرعية',
  'بث مباشر الكعبة',
  'خرائط قوقل',
];

const String _kExemptTitle = 'الأربعون النووية';
const double _kCardFontSize = 13.5;
const double _kExemptFontSize = 14.5;

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(_loadAppFonts);

  group('المصدر', () {
    final String source = File(
      'lib/features/library/presentation/pages/library_screen.dart',
    ).readAsStringSync();

    test('القيمة الافتراضية لخط الكارد 13.5', () {
      expect(source.contains('double fontSize = 13.5'), isTrue);
    });

    test('الكارد نفسه يقرأ [fontSize] بدل رقم مكتوب داخله', () {
      expect(source.contains('fontSize: fontSize'), isTrue);
    });

    test('يمرّر 14.5 لكارد واحد فقط — الأربعون النووية', () {
      final List<String> withExplicitSize = <String>[
        for (final RegExpMatch m in RegExp(
          r'_buildCard\((?:[^()]|\([^()]*\))*\)',
        ).allMatches(source))
          if (m.group(0)!.contains('fontSize:')) m.group(0)!,
      ];

      expect(
        withExplicitSize.length,
        1,
        reason: 'لا يجوز تخصيص خطّ أكثر من كارد واحد: $withExplicitSize',
      );
      expect(withExplicitSize.single.contains('الأربعون النووية'), isTrue);
      expect(withExplicitSize.single.contains('fontSize: 14.5'), isTrue);
    });
  });

  group('العرض الفعلي', () {
    testWidgets('كل الكاردات 13.5 والأربعون النووية 14.5', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            // الشاشة في التطبيق تعيش داخل Scaffold الخاص بالرئيسية،
            // فالـ Material لازم هنا أيضاً لأزرار InkWell
            child: Scaffold(body: IslamicLibraryScreen(onBack: _noop)),
          ),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      for (final Text text in tester.widgetList<Text>(find.byType(Text))) {
        final String? label = text.data;
        if (label == null || !_titles.contains(label)) continue;
        expect(
          text.style?.fontSize,
          label == _kExemptTitle ? _kExemptFontSize : _kCardFontSize,
          reason: 'خطّ كارد «$label» غير مطابق',
        );
      }

      // كل عنوان ظاهر فعلاً (فلا يمرّ الاختبار بلا قياس)
      for (final String title in _titles) {
        expect(find.text(title), findsOneWidget, reason: 'كارد «$title» مفقود');
      }
    });
  });
}

void _noop() {}
