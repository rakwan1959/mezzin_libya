import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muezzin_libya_app/core/widgets/glass_widgets.dart';
import 'package:muezzin_libya_app/core/widgets/greeting_card.dart';
import 'package:muezzin_libya_app/greeting_card_settings.dart';
import 'package:muezzin_libya_app/remote_messaging_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// رسالة السلام (كارد الرسالة) — تُدار كلها من اللوحة الأولى (1916):
///   1. الكارد يعرض **نصّ الرسالة** المكتوب في اللوحة في منتصفه، وفيه زر
///      إغلاق صغير فقط (وإن لم يُكتب نصّ يبقى كارد لون فقط بلا كتابة).
///   2. ألوان جاهزة يختارها المدير، ونغمات خاصة مصاحبة للرسالة.
///   3. النص واللون والنغمة يسافرون في عمود `greeting_message` واحد بصيغة
///      JSON — فلا يحتاج التطبيق أي عمود جديد في قاعدة البيانات.
///   4. الحفظ محلي أولاً: يعمل بلا إنترنت ولا ينتظر نجاح النشر.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  // ── الكارد نفسه ─────────────────────────────────────────────────────────
  group('كارد الرسالة', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      required VoidCallback onClose,
      String message = 'السلام عليكم ورحمة الله',
      GreetingCardStyle style = GreetingCardStyle.gold,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: GreetingCard(
                  style: style,
                  message: message,
                  onClose: onClose,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('يعرض النص المكتوب في اللوحة داخل الكارد', (tester) async {
      await pumpCard(tester, onClose: () {});

      expect(
        find.text('السلام عليكم ورحمة الله'),
        findsOneWidget,
        reason: 'النصّ المكتوب يجب أن يظهر على الكارد لا أن يبقى مخفياً',
      );

      // لونه من نمط الكارد حتى يبقى مقروءاً على الخلفية الداكنة
      final Text text = tester.widget<Text>(
        find.text('السلام عليكم ورحمة الله'),
      );
      expect(text.style?.color, GreetingCardStyle.gold.accent);
      expect(text.style?.fontSize, greaterThanOrEqualTo(12));
    });

    testWidgets('نصّ بلا كتابة: الكارد يبقى لوناً بلا نصّ غريب', (
      tester,
    ) async {
      for (final String empty in <String>['', '   ']) {
        await pumpCard(tester, onClose: () {}, message: empty);
        expect(
          find.byType(Text),
          findsNothing,
          reason: 'لا يُرسم نصّ فارغ داخل الكارد',
        );
      }
    });

    testWidgets('رسالة طويلة تبقى داخل حدود الكارد بلا أوفرفلو', (
      tester,
    ) async {
      await pumpCard(
        tester,
        onClose: () {},
        message: 'السلام عليكم ورحمة الله وبركاته، نسأل الله أن يتقبل منكم '
            'صيامكم وقيامكم، وأن يجعله في ميزان حسناتكم، وكل عام وأنتم بخير '
            'وعلى خير حال.',
      );

      expect(tester.takeException(), isNull, reason: 'أوفرفلو على الكارد');
      final Rect card = tester.getRect(find.byType(GreetingCard));
      final Rect text = tester.getRect(find.byType(Text));

      // النصّ كاملاً (بموضعه لا بمقاسه فقط) داخل حدود الكارد
      expect(text.left, greaterThanOrEqualTo(card.left));
      expect(text.top, greaterThanOrEqualTo(card.top));
      expect(text.right, lessThanOrEqualTo(card.right));
      expect(text.bottom, lessThanOrEqualTo(card.bottom));
      expect(text.height, greaterThan(0), reason: 'نصّ مطموس بارتفاع صفر');
    });

    testWidgets('لا يوجد فيه إلا زر إغلاق صغير واحد', (tester) async {
      await pumpCard(tester, onClose: () {});

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      // زر صغير فعلاً (وليس زراً عريضاً بعرض الكارد)
      final Size closeSize = tester.getSize(find.byIcon(Icons.close_rounded));
      final Size cardSize = tester.getSize(find.byType(GreetingCard));
      expect(closeSize.width, lessThanOrEqualTo(32));
      expect(cardSize.width, greaterThan(closeSize.width * 4));
    });

    testWidgets('إطار إسلامي للرسالة: بلا خطوط مستقيمة والكتابة داخله', (
      tester,
    ) async {
      await pumpCard(tester, onClose: () {});

      // لا حدود زجاجية مستقيمة حول الكتابة — الإطار المرسوم هو الحدّ الوحيد
      final GlassPanel panel = tester.widget<GlassPanel>(
        find.byType(GlassPanel),
      );
      expect(
        panel.showBorder,
        isFalse,
        reason: 'الخطوط المستقيمة تحت الكتابة تُستبدل بالإطار الإسلامي',
      );

      // الإطار الإسلامي مرسوم داخل الكارد
      expect(
        find.descendant(
          of: find.byType(GreetingCard),
          matching: find.byType(IslamicFrame),
        ),
        findsOneWidget,
        reason: 'إطار الرسالة الإسلامي يجب أن يُرسم',
      );

      // والكتابة تبقى بعيدة عن خطوط الإطار من كل الجهات
      final Rect card = tester.getRect(find.byType(GreetingCard));
      final Rect text = tester.getRect(find.text('السلام عليكم ورحمة الله'));
      expect(text.left - card.left, greaterThanOrEqualTo(12));
      expect(card.right - text.right, greaterThanOrEqualTo(12));
      expect(text.top - card.top, greaterThanOrEqualTo(12));
      expect(card.bottom - text.bottom, greaterThanOrEqualTo(12));
      expect(tester.takeException(), isNull);
    });

    testWidgets('الضغط على زر الإغلاق يُغلق الكارد', (tester) async {
      var closed = 0;
      await pumpCard(tester, onClose: () => closed++);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(closed, 1);
    });

    testWidgets('عند عرضه كنافذة: يظهر بنصّه ويُغلق بزر الإغلاق', (tester) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showGreetingCard(
                    context: context,
                    style: GreetingCardStyle.navy,
                    message: 'السلام عليكم',
                  ),
                  child: const Text('فتح'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();

      expect(find.byType(GreetingCard), findsOneWidget);
      // النصّ المعروض داخل الكارد هو نصّ الرسالة لا زر الفتح
      expect(
        find.descendant(
          of: find.byType(GreetingCard),
          matching: find.text('السلام عليكم'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(GreetingCard), findsNothing);
    });

    testWidgets('لون الكارد يتبع النمط المختار', (tester) async {
      for (final GreetingCardStyle style in GreetingCardStyle.all) {
        await pumpCard(tester, onClose: () {}, style: style);
        final Finder card = find.byType(GreetingCard);
        expect(card, findsOneWidget);
        expect(
          tester.widget<GreetingCard>(card).style.id,
          style.id,
          reason: 'الكارد لم يأخذ النمط ${style.id}',
        );
      }
    });
  });

  // ── الألوان والأنماط ────────────────────────────────────────────────────
  group('ألوان الكارد', () {
    test('اثنا عشر نمطاً بمعرّفات فريدة وأسماء عربية', () {
      final Set<String> ids = <String>{};
      for (final GreetingCardStyle s in GreetingCardStyle.all) {
        expect(ids.add(s.id), isTrue, reason: 'معرّف مكرر: ${s.id}');
        expect(s.labelAr.trim(), isNotEmpty);
        // خلفية داكنة حتى يبقى الكارد أنيقاً على أي خلفية
        expect(s.surface.computeLuminance(), lessThan(0.2), reason: s.id);
      }
      expect(GreetingCardStyle.all.length, 12);
    });

    test('النيلي #4B0082 موجود بالقائمة بألوانه الصحيحة', () {
      final GreetingCardStyle indigo = GreetingCardStyle.byId('indigo');

      expect(GreetingCardStyle.all, contains(indigo));
      expect(indigo.labelAr, 'نيلي');
      // الخلفية هي اللون المطلوب نصّاً (#4B0082)
      expect(indigo.surface.toARGB32(), 0xFF4B0082);
      // والتمييز أفتح حتى يُرى زر الإغلاق على خلفية داكنة
      expect(
        indigo.accent.computeLuminance(),
        greaterThan(indigo.surface.computeLuminance()),
      );
    });

    test('البنفسجي الداكن #493267 موجود بالقائمة بألوانه الصحيحة', () {
      final GreetingCardStyle deep = GreetingCardStyle.byId('deep_violet');

      expect(GreetingCardStyle.all, contains(deep));
      expect(deep.labelAr, 'بنفسجي داكن');
      // الخلفية هي اللون المطلوب نصّاً (#493267)
      expect(deep.surface.toARGB32(), 0xFF493267);
      expect(
        deep.accent.computeLuminance(),
        greaterThan(deep.surface.computeLuminance()),
      );
    });

    test('#3C215E (أرجواني) و#370F94 (نيلي ملكي) في القائمة بألوانهما', () {
      final GreetingCardStyle royal = GreetingCardStyle.byId('royal_purple');
      expect(GreetingCardStyle.all, contains(royal));
      expect(royal.labelAr, 'أرجواني');
      expect(royal.surface.toARGB32(), 0xFF3C215E);

      final GreetingCardStyle royalIndigo =
          GreetingCardStyle.byId('royal_indigo');
      expect(GreetingCardStyle.all, contains(royalIndigo));
      expect(royalIndigo.labelAr, 'نيلي ملكي');
      expect(royalIndigo.surface.toARGB32(), 0xFF370F94);

      for (final GreetingCardStyle s in <GreetingCardStyle>[
        royal,
        royalIndigo,
      ]) {
        expect(
          s.accent.computeLuminance(),
          greaterThan(s.surface.computeLuminance()),
          reason: 'يجب أن يُقرأ زر الإغلاق على ${s.id}',
        );
      }

      // المعرّفان يعودان فعلاً لهذين اللونين لا للافتراضي
      expect(GreetingCardStyle.byId('royal_purple').id, 'royal_purple');
      expect(GreetingCardStyle.byId('royal_indigo').id, 'royal_indigo');
    });

    test('معرّف مجهول يعود إلى اللون الافتراضي (ذهبي)', () {
      expect(GreetingCardStyle.byId('غير موجود').id, GreetingCardStyle.defaultId);
      expect(GreetingCardStyle.byId(null).id, 'gold');
      expect(GreetingCardStyle.byId('purple').id, 'purple');
      expect(GreetingCardStyle.defaultId, 'gold');
    });
  });

  // ── النغمة الخاصة ───────────────────────────────────────────────────────
  group('نغمة الرسالة', () {
    test('المعرّف الافتراضي هو الرنّة المميزة للكارد', () {
      expect(GreetingTone.defaultId, 'greeting_chime');
      expect(GreetingTone.byId(null).id, 'greeting_chime');
      expect(GreetingTone.byId('لا شيء').id, 'greeting_chime');
    });

    test('النغمتان المصاحبتان مختلفتان عن نغمة رسالة التهنئة', () {
      expect(GreetingTone.chime.asset, isNot(contains('admin_notification')));
      expect(GreetingTone.bell.asset, isNot(contains('admin_notification')));
      expect(GreetingTone.chime.asset, isNot(GreetingTone.bell.asset));
    });

    test('ملفّا النغمة موجودان فعلاً في أصول التطبيق وللجانب الأصلي', () {
      for (final GreetingTone tone in GreetingTone.all) {
        if (tone.isSilent) continue;
        final File asset = File(tone.asset);
        expect(asset.existsSync(), isTrue, reason: 'ملف مفقود: ${tone.asset}');
        expect(asset.lengthSync(), greaterThan(1000),
            reason: 'ملف نغمة فارغ: ${tone.asset}');

        final File native = File(
          'android/app/src/main/res/raw/${tone.id}.wav',
        );
        expect(native.existsSync(), isTrue,
            reason: 'بدون نسخة أصلية لن تُسمع النغمة على أندرويد: ${tone.id}');
      }
    });

    test('الجانب الأصلي يعرف كل معرّفات النغمات (وإلا لا صوت على الجهاز)', () {
      final String native = File(
        'android/app/src/main/kotlin/com/example/muezzin_libya_app/MainActivity.kt',
      ).readAsStringSync();

      expect(native, contains('playNoticeTone'),
          reason: 'دالة تشغيل النغمة غير موجودة في الجانب الأصلي');
      for (final GreetingTone tone in GreetingTone.all) {
        if (tone.isSilent) continue;
        expect(native, contains('"${tone.id}"'),
            reason: 'النغمة ${tone.id} غير مربوطة في MainActivity');
      }
    });
  });

  // ── الحمولة: عمود واحد بلا أي SQL إضافي ─────────────────────────────────
  group('الحمولة المنشورة', () {
    test('عمودان موجودان أصلاً فقط: greeting_enabled و greeting_message', () {
      final Map<String, dynamic> payload = const GreetingSettings(
        enabled: true,
        message: 'السلام عليكم',
        colorId: 'teal',
        toneId: 'greeting_bell',
      ).toRemotePayload();

      expect(payload.keys.toSet(), <String>{'greeting_enabled', 'greeting_message'});
      expect(payload['greeting_enabled'], isTrue);

      final Map<String, dynamic> envelope =
          jsonDecode(payload['greeting_message'] as String) as Map<String, dynamic>;
      expect(envelope['text'], 'السلام عليكم');
      expect(envelope['color'], 'teal');
      expect(envelope['tone'], 'greeting_bell');
    });

    test('الرحلة كاملة: تغليف ثم فك يعيد نفس الإعدادات', () {
      const GreetingSettings original = GreetingSettings(
        enabled: true,
        message: 'رسالة خاصة',
        colorId: 'red',
        toneId: 'greeting_bell',
      );

      final GreetingSettings back = GreetingSettings.decode(
        original.toRemotePayload()['greeting_message'] as String,
      );

      expect(back.message, original.message);
      expect(back.colorId, 'red');
      expect(back.toneId, 'greeting_bell');
      expect(back.style.id, 'red');
      expect(back.tone.id, 'greeting_bell');
    });

    test('رسالة قديمة نصّية (قبل الألوان) تُقبل بنصها وتأخذ الافتراضي', () {
      final GreetingSettings legacy = GreetingSettings.decode('السلام عليكم');

      expect(legacy.message, 'السلام عليكم');
      expect(legacy.colorId, GreetingCardStyle.defaultId);
      expect(legacy.toneId, GreetingTone.defaultId);
    });

    test('قيمة فارغة أو JSON تالف لا تُسقط التطبيق', () {
      expect(GreetingSettings.decode('').enabled, isFalse);
      expect(GreetingSettings.decode(null).message, isEmpty);

      final GreetingSettings broken = GreetingSettings.decode('{ليس JSON');
      expect(broken.message, '{ليس JSON');
      expect(broken.toneId, GreetingTone.defaultId);
    });

    test('معرّفات مجهولة من السيرفر تُصحَّح ولا تُخزَّن كما هي', () {
      final GreetingSettings s = GreetingSettings.decode(
        jsonEncode(<String, dynamic>{
          'text': 'ن',
          'color': 'لا يوجد',
          'tone': 'نغمة وهمية',
        }),
      );
      expect(s.colorId, GreetingCardStyle.defaultId);
      expect(s.toneId, GreetingTone.defaultId);
    });

    test('بصمة التسليم تتغير بتغير النص أو اللون أو النغمة', () {
      const GreetingSettings base = GreetingSettings(
        enabled: true,
        message: 'ن',
        colorId: 'gold',
        toneId: 'greeting_chime',
      );

      expect(base.copyWith(message: 'ن٢').deliveryKey, isNot(base.deliveryKey));
      expect(base.copyWith(colorId: 'navy').deliveryKey, isNot(base.deliveryKey));
      expect(
        base.copyWith(toneId: 'greeting_bell').deliveryKey,
        isNot(base.deliveryKey),
      );
    });
  });

  // ── الحفظ المحلي أولاً ──────────────────────────────────────────────────
  group('الحفظ المحلي (قبل النشر وبلا إنترنت)', () {
    test('يُحفظ التفعيل والنص واللون والنغمة على الجهاز', () async {
      const GreetingSettings settings = GreetingSettings(
        enabled: true,
        message: 'السلام عليكم ورحمة الله',
        colorId: 'purple',
        toneId: 'greeting_bell',
      );

      await RemoteMessagingService.saveGreetingLocal(settings);
      final SharedPreferences p = await prefs();

      expect(p.getBool(GreetingSettings.enabledKey), isTrue);
      expect(p.getString(GreetingSettings.messageKey), 'السلام عليكم ورحمة الله');
      expect(p.getString(GreetingSettings.colorKey), 'purple');
      expect(p.getString(GreetingSettings.toneKey), 'greeting_bell');
    });

    test('القراءة ترجع نفس ما حُفظ (رحلة كاملة عبر التخزين)', () async {
      const GreetingSettings settings = GreetingSettings(
        enabled: true,
        message: 'رسالة',
        colorId: 'green',
        toneId: 'greeting_chime',
      );

      await RemoteMessagingService.saveGreetingLocal(settings);
      final GreetingSettings read = GreetingSettings.fromPrefs(await prefs());

      expect(read.enabled, isTrue);
      expect(read.message, 'رسالة');
      expect(read.colorId, 'green');
      expect(read.toneId, 'greeting_chime');
    });

    test('التعطيل يُحفظ محلياً بلا مساس باللون والنغمة المختارين', () async {
      await RemoteMessagingService.saveGreetingLocal(
        const GreetingSettings(
          enabled: true,
          message: 'رسالة',
          colorId: 'teal',
          toneId: 'greeting_bell',
        ),
      );
      await RemoteMessagingService.saveGreetingLocal(
        const GreetingSettings(
          enabled: false,
          colorId: 'teal',
          toneId: 'greeting_bell',
        ),
      );

      final GreetingSettings read = GreetingSettings.fromPrefs(await prefs());
      expect(read.enabled, isFalse);
      expect(read.colorId, 'teal');
      expect(read.toneId, 'greeting_bell');
    });

    test('لا شيء محفوظ بعد → الرسالة غير مفعّلة والافتراضيات سليمة', () async {
      final GreetingSettings empty = GreetingSettings.fromPrefs(await prefs());

      expect(empty.enabled, isFalse);
      expect(empty.message, isEmpty);
      expect(empty.style.id, GreetingCardStyle.defaultId);
      expect(empty.tone.id, GreetingTone.defaultId);
    });
  });

  // ── زر حذف الرسالة على الكارد (من التطبيق ومن قاعدة البيانات) ────────
  group('زر الحذف على الكارد', () {
    Future<void> pumpCardWithDelete(
      WidgetTester tester, {
      required VoidCallback onDelete,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: GreetingCard(
                  style: GreetingCardStyle.gold,
                  message: 'السلام عليكم',
                  onClose: () {},
                  onDelete: onDelete,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('يظهر عند تمرير onDelete ويُنفّذ الحذف عند الضغط', (
      tester,
    ) async {
      int taps = 0;
      await pumpCardWithDelete(tester, onDelete: () => taps++);

      final Finder deleteIcon = find.byIcon(Icons.delete_outline_rounded);
      expect(
        deleteIcon,
        findsOneWidget,
        reason: 'أيقونة الحذف يجب أن تكون على الكارد',
      );

      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();
      expect(taps, 1, reason: 'الضغط يجب أن يُنفّذ الحذف فعلاً');
    });

    testWidgets('لا يظهر إن لم يُمرَّر onDelete (ولا يتعطّل زر الإغلاق)', (
      tester,
    ) async {
      bool closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: GreetingCard(
                  style: GreetingCardStyle.gold,
                  message: 'السلام عليكم',
                  onClose: () => closed = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });

    testWidgets('الإغلاق والحذف معاً: كل زر في زاويته بلا تعارض', (
      tester,
    ) async {
      int deletes = 0;
      int closes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: GreetingCard(
                  style: GreetingCardStyle.teal,
                  message: 'رسالة',
                  onClose: () => closes++,
                  onDelete: () => deletes++,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(closes, 0, reason: 'الحذف لا يُغلق الكارد بيده — يتولّاه المستدعي');

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(closes, 1);
      expect(deletes, 1);
    });
  });

  // ── الحذف الكامل من التطبيق ومن قاعدة البيانات ───────────────────────
  group('حذف رسالة السلام نهائياً', () {
    test('يُعطّل الرسالة ويمسح نصّها محلياً حتى لو تعذّر النشر', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        GreetingSettings.enabledKey: true,
        GreetingSettings.messageKey: 'السلام عليكم ورحمة الله',
        GreetingSettings.colorKey: 'teal',
        GreetingSettings.toneKey: 'greeting_bell',
      });

      // بلا Supabase مُهيّأ تفشل الكتابة على السحابة، والوعد بالحذف محلياً
      // يجب أن يبقى صادقاً: الرسالة تختفي من الجهاز في كل الأحوال.
      await RemoteMessagingService.deleteGreetingEverywhere();

      final GreetingSettings after = GreetingSettings.fromPrefs(await prefs());
      expect(after.enabled, isFalse, reason: 'الرسالة تُعطَّل');
      expect(after.message, isEmpty, reason: 'والنصّ يُمحى فلا يظهر كارد');
    });
  });
}
