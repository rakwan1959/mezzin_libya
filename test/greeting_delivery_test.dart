import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muezzin_libya_app/core/widgets/greeting_card.dart';
import 'package:muezzin_libya_app/greeting_card_settings.dart';
import 'package:muezzin_libya_app/main.dart' show navigatorKey;
import 'package:muezzin_libya_app/remote_messaging_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// رسالة «السلام عليكم» عند فتح التطبيق + مسارات الرسائل.
///
/// الحالات المُغطّاة:
///   1. بصمة التسليم لا تُستهلك قبل أن تصير الواجهة جاهزة (وإلا ضاعت الرسالة
///      نهائياً في كل الأجهزة التي يفتح التطبيق عليها قبل بناء الـNavigator).
///   2. الكارد يظهر فعلاً عند فتح التطبيق، ثم لا يتكرر.
///   3. النشر يمرّ بعمودَي `app_config` المخصّصين للرسالة، بلا مسار صامت
///      يقول «تم النشر» والرسالة لم تصل.
///   4. كل رسائل اللوحتين تمرّ عبر Supabase — لا اتصال SQLite في مسارها.
///   5. الرمز السري لشاشة «عن التطبيق» يُدخل مرة واحدة للّوحتين.
///   6. النصّ المنشور يصل إلى الكارد من كل مسار (لا كارد بلا كتابة).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String readLib(String path) => File(path).readAsStringSync();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // ── 1) التسليم عند فتح التطبيق ────────────────────────────────────────────
  group('رسالة السلام عند فتح التطبيق', () {
    Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

    Future<void> enableGreeting() => RemoteMessagingService.saveGreetingLocal(
      const GreetingSettings(
        enabled: true,
        message: 'السلام عليكم',
        colorId: 'teal',
        // نغمة صامتة حتى لا يدخل الصوت في اختبار الواجهة
        toneId: 'silent',
      ),
    );

    testWidgets('لا تُعلَّم مُسلَّمة إذا لم تكن الواجهة جاهزة بعد', (
      tester,
    ) async {
      await enableGreeting();

      // لا شجرة واجهة مبنيّة بعد: navigatorKey.currentContext == null
      final bool done = await RemoteMessagingService.showGreetingIfNeeded();

      expect(
        done,
        isFalse,
        reason: 'يجب أن يُقال «لم تنتهِ» حتى يُعاد النداء لاحقاً',
      );
      final SharedPreferences p = await prefs();
      expect(
        p.getString('last_greeting_msg_seen'),
        isNull,
        reason: 'لا تُستهلك بصمة التسليم قبل أن تُعرض الرسالة',
      );
    });

    test('رسالة غير مفعّلة → لا شيء معلّق ولا بصمة', () async {
      final bool done = await RemoteMessagingService.showGreetingIfNeeded();

      expect(done, isTrue);
      expect(
        (await prefs()).getString('last_greeting_msg_seen'),
        isNull,
      );
    });

    testWidgets('تظهر بعد جاهزية الواجهة، وتُسلَّم مرة واحدة بلا تكرار', (
      tester,
    ) async {
      await enableGreeting();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: SizedBox.shrink()),
          ),
        ),
      );

      // ملاحظة: النداء لا يعود حتى يُغلق الكارد، فلا ننتظره هنا
      final Future<bool> pending =
          RemoteMessagingService.showGreetingIfNeeded();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(GreetingCard),
        findsOneWidget,
        reason: 'الكارد يجب أن يظهر عند فتح التطبيق',
      );
      // الكارد يعرض النصّ المنشور ("السلام عليكم") لا كارد فارغاً
      expect(
        find.descendant(
          of: find.byType(GreetingCard),
          matching: find.text('السلام عليكم'),
        ),
        findsOneWidget,
        reason: 'رسالة السلام كانت تظهر على الكارد بلا كتابة',
      );

      final SharedPreferences p = await prefs();
      expect(p.getString('last_greeting_msg_seen'), 'السلام عليكم|teal|silent');

      // إغلاق الكارد يُنهي النداء بنجاح
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(await pending, isTrue);
      expect(find.byType(GreetingCard), findsNothing);

      // النداء الثاني لا يُظهر كارداً آخر (نفس البصمة)
      expect(await RemoteMessagingService.showGreetingIfNeeded(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(GreetingCard), findsNothing);
    });

    test('الشاشة الرئيسية تطلب الرسالة عند الإقلاع لا أن تُشغَّل بالحظ', () {
      final String home = readLib(
        'lib/features/home/presentation/pages/home_page.dart',
      );

      expect(
        home,
        contains('_showGreetingIfEnabled();'),
        reason: 'الشاشة الرئيسية هي نقطة فتح التطبيق، وعليها طلب الرسالة',
      );
      expect(
        home,
        contains('RemoteMessagingService.showGreetingIfNeeded()'),
      );
      // إعادة محاولة بدل عرض واحد فاشل في الإطار الأول
      expect(home, contains('attempt <'));
    });
  });

  // ── 2) النشر إلى Supabase بعمودَي الرسالة ────────────────────────────────
  group('نشر رسالة السلام إلى Supabase', () {
    test('عمودان فقط: greeting_enabled و greeting_message', () {
      final String service = readLib('lib/remote_messaging_service.dart');

      expect(
        service,
        contains('static Future<bool> publishGreeting(GreetingSettings'),
      );
      // الكتابة تستخدم حمولة العمودين نفسها لا حمولة عامة
      expect(
        service,
        contains('...settings.toRemotePayload(),'),
        reason: 'عمودا الرسالة يجب أن يكونا مصدر الكتابة الوحيد',
      );
    });

    test('لا مسار صامت: الحمولة الأساسية لا تُعيد نجاحاً كاذباً لرسالة السلام', () {
      final String service = readLib('lib/remote_messaging_service.dart');

      // الحمولة الأساسية (fallback) لا تحمل أعمدة الرسالة إطلاقاً
      final int basicIndex = service.indexOf('final basicPayload');
      expect(basicIndex, greaterThan(-1));

      final String basicBlock = service.substring(
        basicIndex,
        service.indexOf('return true;', basicIndex),
      );
      expect(
        basicBlock,
        isNot(contains('greeting')),
        reason:
            'لو حملت الرسالة في المسار الأساسي لكان النشر الكاذب ممكناً — '
            'الرسالة لها مسارها المستقل الآن',
      );
    });

    test('اللوحة الأولى (1916) تنشر عبر publishGreeting لا publishConfig', () {
      final String about = readLib(
        'lib/features/about/presentation/pages/about_screen.dart',
      );

      expect(about, contains('RemoteMessagingService.publishGreeting(settings)'));
      expect(
        about,
        isNot(contains('remoteGreetingMessage:')),
        reason: 'لا تُمرَّر رسالة السلام عبر حمولة عامة',
      );
    });
  });

  // ── 3) لا SQLITE في مسار الرسائل ─────────────────────────────────────────
  group('كل الرسائل عبر Supabase — بلا أي اتصال SQLite', () {
    const List<String> messageFiles = <String>[
      'lib/remote_messaging_service.dart',
      'lib/admin_panel_screen.dart',
      'lib/user_messaging_screen.dart',
      'lib/features/about/presentation/pages/about_screen.dart',
      'lib/greeting_card_settings.dart',
      'lib/core/widgets/greeting_card.dart',
    ];

    test('ملفات الرسائل واللوحتين لا تلمس SQLite إطلاقاً', () {
      for (final String path in messageFiles) {
        final String src = readLib(path);
        expect(src, isNot(contains('sqflite')), reason: path);
        expect(src, isNot(contains('openDatabase')), reason: path);
        expect(src, isNot(contains('getDatabasesPath')), reason: path);
        expect(src, isNot(contains('sqlite')), reason: path);
      }
    });

    test('الجداول المستخدمة للرسائل هي جداول Supabase فقط', () {
      for (final String path in messageFiles) {
        final String src = readLib(path);
        final Iterable<String> tables = RegExp(
          r"\.from\('([a-z_]+)'\)",
        ).allMatches(src).map((RegExpMatch m) => m.group(1)!);
        for (final String table in tables) {
          expect(
            <String>{'app_config', 'broadcasts'},
            contains(table),
            reason: 'الجدول $table في $path ليس من جداول Supabase المعروفة',
          );
        }
      }
    });

    test('مستخدمو sqflite الوحيدون: القرآن والعلامات المرجعية فقط', () {
      final List<String> users = <String>[];
      for (final FileSystemEntity entity in Directory('lib').listSync(
        recursive: true,
      )) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final String src = entity.readAsStringSync();
        if (src.contains("package:sqflite/sqflite.dart")) {
          users.add(entity.path.replaceAll('\\', '/'));
        }
      }

      expect(
        users..sort(),
        <String>[
          'lib/core/database/user_database_helper.dart',
          'lib/features/quran/data/datasources/quran_local_data_source.dart',
        ]..sort(),
        reason: 'أي ملف جديد يستورد sqflite يكسر قاعدة «الرسائل على Supabase»',
      );
    });
  });

  // ── 4) الرمز السري مرة واحدة ─────────────────────────────────────────────
  group('الرمز السري في شاشة «عن التطبيق»', () {
    String passcodeMethod() {
      final String src = readLib(
        'lib/features/about/presentation/pages/about_screen.dart',
      );
      final int start = src.indexOf('void _showHiddenBroadcastDialog(');
      expect(start, greaterThan(-1));
      final int end = src.indexOf('\n  }\n', start);
      expect(end, greaterThan(start));
      return src.substring(start, end);
    }

    test('نافذة إدخال واحدة فقط — لا خطوة تأكيد ثانية', () {
      final String method = passcodeMethod();

      expect(
        RegExp(r'showDialog<bool>\(').allMatches(method).length,
        1,
        reason: 'إدخال واحد للرمز يكفي لفتح اللوحة',
      );
      expect(method, isNot(contains('تأكيد الرمز السري')));
      expect(method, isNot(contains('أعد إدخال الرمز السري')));
      expect(method, isNot(contains('secondCtrl')));
      expect(method, isNot(contains('secondResult')));
    });

    test('زر الإدخال يفتح مباشرة، والرقمان ما زالا مقبولين', () {
      final String method = passcodeMethod();

      expect(method, contains("'فتح'"));
      expect(method, contains('_secondPanelPasscodeOld'));
      expect(method, contains('entered == expected'));

      final String src = readLib(
        'lib/features/about/presentation/pages/about_screen.dart',
      );
      expect(src, contains("'1916'"));
      expect(src, contains("'1918'"));
      expect(src, contains("'1619'"));
    });

    test('الضغطات الخمس تفتح لوحة السيطرة والتحكم مباشرة', () {
      final String src = readLib(
        'lib/features/about/presentation/pages/about_screen.dart',
      );

      expect(src, contains('_showHiddenBroadcastDialog(openFirstPanel: false)'));
      expect(
        src,
        isNot(contains('كلمة السر مرتين')),
        reason: 'التعليق القديم يصف خطوة أُلغيت',
      );
    });
  });

  // ── 5) النصّ المكتوب يصل إلى الكارد من كل مسار ───────────────────────────
  group('نصّ الرسالة على الكارد', () {
    test('الكارد يستقبل النصّ كمعامل مطلوب (لا يُبنى بلا كتابة سهواً)', () {
      final String card = readLib('lib/core/widgets/greeting_card.dart');

      expect(card, contains('required this.message'));
      expect(
        card,
        contains('required String message'),
        reason: 'دالة العرض يجب أن تُطالب بالنصّ من كل منادٍ',
      );
      // ويُرسم فعلاً داخل الكارد (لا معامل يُتجاهل)
      expect(card, contains('Text('));
    });

    test('اللوحة الأولى تُمرّر ما كُتب في الحقل إلى الكارد', () {
      final String panel = readLib(
        'lib/features/about/presentation/pages/about_screen.dart',
      );

      expect(panel, contains('message: _greetingMsgCtrl.text'));
      expect(
        panel,
        isNot(contains('الكارد يظهر بلا كتابة')),
        reason: 'التلميح القديم يصف عطلاً أُصلح',
      );
    });

    test('مسار الأجهزة يُمرّر النصّ المنشور لا فراغاً', () {
      final String service = readLib('lib/remote_messaging_service.dart');

      expect(service, contains('message: s.message'));
      expect(service, isNot(contains('بلا أي كتابة')));
    });
  });
}
