import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muezzin_libya_app/core/theme/glass_theme.dart';
import 'package:muezzin_libya_app/core/widgets/glass_nav_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// اختبارات أيقونة شريط المهام ثلاثية الأبعاد [GlassNavIcon]:
/// الغوص عند الضغط، والارتداد الزنبركي، وسماكة الحروف واللوح، والمنظور،
/// وثبات ارتفاع الشريط، واحترام إعداد الحركة.
const Color _accent = Color(0xFF7FB2FF); // لون صلاة الفجر
const IconData _active = Icons.access_time_filled;
const IconData _idle = Icons.access_time;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  /// يضبط إعداد الحركة في المظهر كما يقرأه التطبيق من التخزين.
  Future<void> setMotion(bool on) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{'glassMotion': on},
    );
    await GlassRuntime.load();
  }

  Future<void> pumpIcon(
    WidgetTester tester, {
    required bool selected,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GlassNavIcon(
              selected: selected,
              selectedIcon: _active,
              unselectedIcon: _idle,
              accent: _accent,
              onTap: onTap ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// وجه الحرف (آخر طبقة في المكدّس، وهي المضيئة).
  Finder faceGlyph({required bool selected}) =>
      find.byIcon(selected ? _active : _idle).last;

  /// مصفوفة التحويل الثلاثية الأبعاد للزر كاملاً.
  Matrix4 bodyMatrix(WidgetTester tester, {required bool selected}) =>
      tester
          .widget<Transform>(
            find
                .ancestor(
                  of: faceGlyph(selected: selected),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform;

  /// الدوائر: جدار اللوح + وجهه + خرزة المؤشر.
  Finder circles() => find.byWidgetPredicate((Widget w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration! as BoxDecoration).shape == BoxShape.circle);

  group('الغوص والارتداد عند الضغط', () {
    testWidgets('الزر يغوص (تصغير + نزول) ثم يرتد فوق موضعه ويسكن', (
      WidgetTester tester,
    ) async {
      await setMotion(false);
      await pumpIcon(tester, selected: true);

      final Rect rest = tester.getRect(faceGlyph(selected: true));
      final double restDrop = bodyMatrix(tester, selected: true).getTranslation().y;

      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.byType(GlassNavIcon)));
      // الضغط يُعلَن بعد انتهاء مهلة اللمس، ثم تُقدَّم الحركة إطاراً آخر
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 130));

      final Rect pressed = tester.getRect(faceGlyph(selected: true));
      // غوص: تصغير الحرف + نزول الزر فعلباً بمقدار pressTravel
      expect(pressed.width, lessThan(rest.width * 0.93));
      expect(pressed.height, lessThan(rest.height * 0.95));
      expect(
        bodyMatrix(tester, selected: true).getTranslation().y,
        lessThan(restDrop - 1.5),
      );

      // الارتداد: easeInBack على القيمة المقلوبة يتجاوز السكون إلى الخارج
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      final Rect bounced = tester.getRect(faceGlyph(selected: true));
      expect(bounced.width, greaterThan(pressed.width + 0.5));
      expect(bounced.width, greaterThan(rest.width)); // تجاوز طور السكون

      // ثم يستقرّ في موضعه تماماً
      await tester.pump(const Duration(milliseconds: 600));
      final Rect settled = tester.getRect(faceGlyph(selected: true));
      expect((settled.center - rest.center).distance, lessThan(0.6));
      expect((settled.width - rest.width).abs(), lessThan(0.6));
      expect(
        bodyMatrix(tester, selected: true).getTranslation().y,
        closeTo(restDrop, 0.05),
      );
    });

    testWidgets('الضغط يزيد ميل السطح (المنظور ثلاثي الأبعاد)', (
      WidgetTester tester,
    ) async {
      await setMotion(false);
      await pumpIcon(tester, selected: true);

      final Matrix4 flat = bodyMatrix(tester, selected: true);
      // بُعد المنظور مضبوط في المصفوفة — وهو أصل الإحساس بالعمق
      expect(flat.entry(3, 2), isNot(0));

      await tester.startGesture(tester.getCenter(find.byType(GlassNavIcon)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 130));

      final Matrix4 deep = bodyMatrix(tester, selected: true);
      // sin(الميل) يزداد عند الضغط، وcos له يقلّ
      expect(deep.entry(2, 1), greaterThan(flat.entry(2, 1)));
      expect(deep.entry(1, 1), lessThan(flat.entry(1, 1)));
      // وتصغير الغوص ظاهر في المصفوفة
      expect(deep.entry(0, 0), lessThan(flat.entry(0, 0)));

      await tester.pump(const Duration(milliseconds: 600));
    });
  });

  group('الجسم ثلاثي الأبعاد: سماكة ولوح', () {
    testWidgets('الحرف مجسّم بطبقات سماكة تحت الوجه المضيء', (
      WidgetTester tester,
    ) async {
      await setMotion(false);
      await pumpIcon(tester, selected: true);

      // الوجه + طبقات السماكة
      expect(
        find.byIcon(_active),
        findsNWidgets(GlassNavSpec.extrudeLayers + 1),
      );

      final Rect deepest = tester.getRect(find.byIcon(_active).first);
      final Rect face = tester.getRect(faceGlyph(selected: true));
      // الطبقات تنزاح للأسفل قدر سماكة محدودة (لا تتلاصق ولا تتفرّق)
      final double depth = deepest.top - face.top;
      expect(depth, greaterThan(0.5));
      expect(depth, lessThan(3.0));
    });

    testWidgets('الزر النشط له جدار جانبي أسفل وجهه، وغير النشط بلا لوح', (
      WidgetTester tester,
    ) async {
      await setMotion(false);
      await pumpIcon(tester, selected: true);

      expect(circles(), findsNWidgets(3)); // جدار + وجه + خرزة المؤشر

      final Rect wall = tester.getRect(circles().first);
      final Rect plate = tester.getRect(circles().at(1));
      expect(wall.top - plate.top, greaterThan(1.5)); // سماكة ظاهرة
      expect(wall.top - plate.top, lessThan(3.5));

      await pumpIcon(tester, selected: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(circles(), findsNothing); // لا لوح للتبويب الخامل
    });

    testWidgets('مادّة اللوح: الوجه مضيء والجدار أغمق منه (إحساس العمق)', (
      WidgetTester tester,
    ) async {
      final List<Color> face =
          GlassNavSpec.plateFace(_accent, 1.0).colors;
      final List<Color> wall =
          GlassNavSpec.plateWall(_accent, 1.0).colors;

      // الوجه يبدأ بلمعان أبيض ثم يتلوّن، والجدار داكن في كل طبقاته
      expect(face.first.computeLuminance(), greaterThan(face.last.computeLuminance()));
      expect(
        wall.first.computeLuminance(),
        lessThan(face.last.computeLuminance()),
      );
      expect(
        wall.last.computeLuminance(),
        lessThan(face.first.computeLuminance()),
      );

      // توهّج اللوح بلون الصلاة، وظله الأسود يفصله عن الشريط
      final List<BoxShadow> shadows =
          GlassNavSpec.plateShadow(_accent, 1.0, 0.0);
      expect(shadows.length, 2);
      expect(shadows.first.color.a, greaterThan(0.0));
      expect(shadows.last.color, isA<Color>());
    });

    testWidgets('لون الحرف يتبع لون الصلاة النشطة في الحالتين', (
      WidgetTester tester,
    ) async {
      await setMotion(false);
      await pumpIcon(tester, selected: true);
      expect(
        tester.widget<Icon>(faceGlyph(selected: true)).color,
        GlassNavSpec.activeIconColor(_accent),
      );

      await pumpIcon(tester, selected: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<Icon>(faceGlyph(selected: false)).color,
        GlassNavSpec.inactiveIconColor(_accent),
      );
    });
  });

  group('ثبات شريط المهام', () {
    testWidgets('ارتفاع العنصر ثابت في كل الحالات فلا يقفز الشريط', (
      WidgetTester tester,
    ) async {
      await setMotion(true);
      await pumpIcon(tester, selected: true);

      final Size rest = tester.getSize(find.byType(GlassNavIcon));
      expect(rest.height, GlassNavSpec.itemHeight);
      expect(rest.width, GlassNavSpec.touchWidth);

      await tester.startGesture(tester.getCenter(find.byType(GlassNavIcon)));
      await tester.pump(const Duration(milliseconds: 130));
      expect(tester.getSize(find.byType(GlassNavIcon)), rest);

      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getSize(find.byType(GlassNavIcon)), rest);
    });
  });

  group('احترام إعداد الحركة', () {
    testWidgets('الحركة مفعّلة: التبويب النشط يتنفّس', (
      WidgetTester tester,
    ) async {
      await setMotion(true);
      await pumpIcon(tester, selected: true);

      final double restTop = tester.getRect(faceGlyph(selected: true)).top;
      await tester.pump(const Duration(milliseconds: 600));
      final double flying = tester.getRect(faceGlyph(selected: true)).top;

      expect(flying, lessThan(restTop - 0.1)); // ارتفع عن سطح الشريط
      await tester.pump(const Duration(milliseconds: 800));
    });

    testWidgets('الحركة موقوفة: لا تنفّس إطلاقاً (توفير بطارية)', (
      WidgetTester tester,
    ) async {
      await setMotion(false);
      await pumpIcon(tester, selected: true);

      final Rect rest = tester.getRect(faceGlyph(selected: true));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getRect(faceGlyph(selected: true)), rest);
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getRect(faceGlyph(selected: true)), rest);
    });
  });

  group('شريط المهام كاملاً (نفس هيكل التطبيق)', () {
    const List<List<IconData>> icons = <List<IconData>>[
      <IconData>[Icons.access_time_filled, Icons.access_time],
      <IconData>[Icons.menu_book, Icons.menu_book_outlined],
      <IconData>[Icons.explore, Icons.explore_outlined],
      <IconData>[Icons.settings, Icons.settings_outlined],
      <IconData>[Icons.info_rounded, Icons.info_outline_rounded],
    ];

    Future<void> pumpTaskBar(WidgetTester tester, Size size) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.11),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1.0,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        for (int i = 0; i < icons.length; i++)
                          Expanded(
                            child: GlassNavIcon(
                              selected: i == 0,
                              selectedIcon: icons[i][0],
                              unselectedIcon: icons[i][1],
                              accent: _accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('خمسة تبويبات بلا أوفرفلو ولا تراكب على الشاشات الضيقة', (
      WidgetTester tester,
    ) async {
      await setMotion(false);

      for (final Size size in <Size>[
        const Size(320, 640),
        const Size(360, 800),
        const Size(412, 915),
      ]) {
        await pumpTaskBar(tester, size);
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull);
        expect(find.byType(GlassNavIcon), findsNWidgets(5));

        // أهداف اللمس متجاورة بلا تراكب، وارتفاعها ثابت
        final List<Rect> rects = <Rect>[
          for (int i = 0; i < 5; i++)
            tester.getRect(find.byType(GlassNavIcon).at(i)),
        ];
        for (int i = 0; i < rects.length; i++) {
          expect(rects[i].height, GlassNavSpec.itemHeight);
          expect(rects[i].width, greaterThan(GlassNavSpec.touchWidth - 12));
          if (i > 0) {
            expect(rects[i].left, greaterThanOrEqualTo(rects[i - 1].right - 0.01));
          }
        }
      }
    });
  });
}
