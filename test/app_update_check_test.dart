import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muezzin_libya_app/core/config/app_version.dart';
import 'package:muezzin_libya_app/features/about/presentation/pages/about_screen.dart';
import 'package:muezzin_libya_app/main.dart' show navigatorKey;
import 'package:muezzin_libya_app/remote_messaging_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// فحص التحديث داخل التطبيق: مقارنة الإصدار المثبَّت بآخر إصدار منشور على
/// سوباباز وإخبار المستخدم.
///
/// الحالات المُغطّاة:
///   1. الإصدار المثبَّت من مصدر واحد يطابق `pubspec.yaml` (وإلا يقارن التطبيق
///      رقماً خاطئاً: ينبّه على تحديث هو مثبَّته، أو يكتم تحديثاً حقيقياً).
///   2. المقارنة رقمية لا نصّية: `3.4.10` أحدث من `3.4.9`، ورقم البناء بعد `+`
///      يُهمل، والقيمة غير القابلة للقراءة لا تُنبّه أبداً.
///   3. تحليل ما ينشره المدير في `app_config` (بلا شبكة).
///   4. النافذة: تظهر مرة واحدة لكل إصدار، والإجباري يبقى يظهر، ولا تُحرق
///      «عُرض مرة واحدة» قبل أن تظهر فعلاً، وبلا رابط لا يوجد زر يفتح لا شيء.
///   5. شاشة «عن التطبيق» تعرض «يتوفر إصدار أحدث» وتفتح التفاصيل بالضغط.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  String readLib(String path) => File(path).readAsStringSync();

  final Map<String, String> fonts = <String, String>{
    'Cairo': 'assets/fonts/alfont_com_Cairo-Bold-1.ttf',
    'Amiri': 'assets/fonts/alfont_com_خط-القران-اميري.ttf',
  };

  setUpAll(() async {
    for (final MapEntry<String, String> entry in fonts.entries) {
      try {
        final ByteData data = await rootBundle.load(entry.value);
        await (FontLoader(entry.key)..addFont(Future<ByteData>.value(data)))
            .load();
      } catch (_) {
        // غير حرج: الاختبارات تقيس النصوص لا قياسات الخط
      }
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // المُخبر ثابت عام — يُصفَّر بين الاختبارات حتى لا يتسرب تحديث اختبار لآخر
    RemoteMessagingService.availableUpdate.value = null;
  });

  tearDown(() {
    RemoteMessagingService.availableUpdate.value = null;
  });

  /// إصدار أحدث من المثبَّت بمقدار محدَّد في أي جزء، مشتقّ من
  /// `AppVersion.version` نفسه — فلا تفشل هذه الاختبارات عند كل رفع لإصدار
  /// التطبيق (كما حدث عند الانتقال 3.4.9 ← 3.5.0).
  String newerThanInstalled({int major = 0, int minor = 0, int patch = 0}) {
    final List<int> v = AppVersion.parse(AppVersion.version)!;
    return '${v[0] + major}.${v[1] + minor}.${v[2] + patch}';
  }

  /// إصدار أقدم من المثبَّت بخطوة واحدة (يُنقص آخر جزء غير صفري).
  String olderThanInstalled() {
    final List<int> v = AppVersion.parse(AppVersion.version)!;
    if (v[2] > 0) return '${v[0]}.${v[1]}.${v[2] - 1}';
    if (v[1] > 0) return '${v[0]}.${v[1] - 1}.0';
    return '${v[0] - 1}.0.0';
  }

  AppUpdateInfo sample({
    String latest = '9.9.9',
    String url = 'https://example.com/app.apk',
    bool force = false,
  }) => AppUpdateInfo(
    latestVersion: latest,
    title: 'تحديث جديد متوفر',
    message: 'يرجى تحديث التطبيق للحصول على آخر الميزات.',
    url: url,
    force: force,
  );

  // ── 1) الإصدار المثبَّت: مصدر واحد ────────────────────────────────────────
  group('الإصدار المثبَّت من مصدر واحد', () {
    test('يطابق سطر version في pubspec.yaml', () {
      final String pubspec = readLib('pubspec.yaml');
      final RegExpMatch? line = RegExp(
        r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?',
        multiLine: true,
      ).firstMatch(pubspec);

      expect(line, isNotNull, reason: 'pubspec.yaml يجب أن يحمل سطر version');
      expect(
        AppVersion.version,
        line!.group(1),
        reason: 'رقم الإصدار في AppVersion تخلّف عن pubspec.yaml',
      );
      expect(
        AppVersion.buildNumber,
        int.parse(line.group(2) ?? '0'),
        reason: 'رقم البناء في AppVersion تخلّف عن pubspec.yaml',
      );
      expect(AppVersion.full, '${line.group(1)}+${line.group(2) ?? '0'}');
    });

    test('الخدمة تقرأ الإصدار من AppVersion لا من رقم مكتوب', () {
      final String service = readLib('lib/remote_messaging_service.dart');

      expect(
        service,
        contains('static String get currentVersion => AppVersion.version;'),
      );
      expect(
        service.contains('3.3.5'),
        isFalse,
        reason: 'الرقم القديم 3.3.5 كان سبب التنبيه الكاذب',
      );
    });

    test('شاشة «عن التطبيق» تعرض الرقم من المصدر نفسه', () {
      final String about = readLib(
        'lib/features/about/presentation/pages/about_screen.dart',
      );

      expect(
        about,
        contains(r"'رقم الإصدار ${AppVersion.display}'"),
        reason: 'الرقم يجب أن يأتي من AppVersion لا مكتوباً يدوياً',
      );
      expect(about.contains('رقم الإصدار 3.3.5'), isFalse);
    });
  });

  // ── 2) المقارنة ───────────────────────────────────────────────────────────
  group('مقارنة الإصدارات', () {
    test('مقارنة رقمية لا نصّية — بغض النظر عن إصدار التطبيق', () {
      // أهمّ حالة: لو قارن الأجزاء كنصوص لكان 3.5.10 أقدم من 3.5.9
      expect(AppVersion.isNewer('3.5.10', installed: '3.5.9'), isTrue);
      expect(AppVersion.isNewer('3.10.0', installed: '3.9.9'), isTrue);
      expect(AppVersion.isNewer('10.0.0', installed: '9.9.9'), isTrue);
      expect(AppVersion.isNewer('3.5.9', installed: '3.5.10'), isFalse);
    });

    test('مصفوفة منشورة مقابل المثبَّت ${AppVersion.version}', () {
      final List<int> v = AppVersion.parse(AppVersion.version)!;
      final String nextPatch = newerThanInstalled(patch: 1);
      final String nextMinor = newerThanInstalled(minor: 1);
      final String nextMajor = newerThanInstalled(major: 1);

      final Map<String, bool> cases = <String, bool>{
        nextPatch: true,
        nextMinor: true,
        nextMajor: true,
        '$nextMinor.1': true, // جزء رابع
        '${v[0]}.${v[1] + 1}': true, // صيغة مختصرة (جزءان)
        'v$nextPatch': true, // بادئة v
        ' $nextPatch ': true, // مسافات حول الرقم
        '$nextMinor+77': true, // رقم البناء لا يُلغي الأحدثية
        AppVersion.version: false, // نفس المثبَّت
        AppVersion.full: false, // نفس النسخة برقم بنائها
        '${AppVersion.version}+999': false, // بناء أعلى بلا نسخة أحدث
        olderThanInstalled(): false,
        '3.3.5': false, // أقدم (الرقم الذي كان مكتوباً خطأً في التطبيق)
        '': false, // فارغ
        '   ': false,
        'null': false, // غير قابل للقراءة
        'latest': false,
        '3.4.x': false,
        '${AppVersion.version}-beta': false,
      };

      cases.forEach((String published, bool expected) {
        expect(
          AppVersion.isNewer(published),
          expected,
          reason: 'المنشور «$published» مقارنةً بالمثبَّت ${AppVersion.version}',
        );
      });
    });

    test('التعادل مع أجزاء ناقصة وبلا اعتبار لرقم البناء', () {
      expect(AppVersion.compare('3.4', '3.4.0'), 0);
      expect(AppVersion.compare('3.4.9+49', '3.4.9+70'), 0);
      expect(AppVersion.compare('3.4.9', '3.4.10'), -1);
      expect(AppVersion.compare('3.4.10', '3.4.9'), 1);
      expect(AppVersion.compare('abc', '3.4.9'), isNull);
      expect(AppVersion.normalize('v3.4.10+50 '), '3.4.10');
    });
  });

  // ── 3) ما ينشره المدير في app_config ─────────────────────────────────────
  group('تحليل صف app_config المنشور', () {
    test('إصدار أحدث → تحديث مع النصوص الافتراضية', () {
      final String published = newerThanInstalled(patch: 1);
      final AppUpdateInfo? info = AppUpdateInfo.fromConfig(<String, dynamic>{
        'latest_version': published,
      });

      expect(info, isNotNull);
      expect(info!.latestVersion, published);
      expect(info.force, isFalse);
      expect(info.title, 'تحديث جديد متوفر');
      expect(info.message, isNotEmpty);
      expect(info.hasUrl, isFalse);
    });

    test('كل الحقول منشورة → تُحترم كما هي', () {
      final String published = newerThanInstalled(major: 1, minor: 1);
      final AppUpdateInfo? info = AppUpdateInfo.fromConfig(<String, dynamic>{
        'latest_version': '$published+77',
        'update_title': 'نسخة رمضان',
        'update_message': 'ميزات جديدة للأذكار',
        'update_url': 'https://example.com/app.apk',
        'force_update': true,
      });

      expect(info, isNotNull);
      expect(info!.latestVersion, published);
      expect(info.title, 'نسخة رمضان');
      expect(info.message, 'ميزات جديدة للأذكار');
      expect(info.url, 'https://example.com/app.apk');
      expect(info.hasUrl, isTrue);
      expect(info.force, isTrue);
    });

    test('لا تحديث: نفس الإصدار أو أقدم أو بلا قيمة', () {
      for (final Map<String, dynamic> data in <Map<String, dynamic>>[
        <String, dynamic>{'latest_version': AppVersion.version},
        <String, dynamic>{'latest_version': AppVersion.full},
        <String, dynamic>{'latest_version': olderThanInstalled()},
        <String, dynamic>{'latest_version': ''},
        <String, dynamic>{'latest_version': null},
        <String, dynamic>{'latest_version': 'نسخة جديدة'},
        <String, dynamic>{},
      ]) {
        expect(
          AppUpdateInfo.fromConfig(data),
          isNull,
          reason: 'صف بلا تحديث حقيقي: $data',
        );
      }
      expect(AppUpdateInfo.fromConfig(null), isNull);
    });
  });

  // ── 4) نافذة التحديث ─────────────────────────────────────────────────────
  group('نافذة التحديث', () {
    Future<void> pumpShell(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );

    Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

    testWidgets('لا تُحرق «عُرض مرة واحدة» إذا لم تكن الواجهة جاهزة', (
      WidgetTester tester,
    ) async {
      RemoteMessagingService.availableUpdate.value = sample();

      // لا شجرة واجهة مبنية بعد: navigatorKey.currentContext == null
      final bool handled = await RemoteMessagingService.showAvailableUpdate();

      expect(handled, isFalse, reason: 'يجب أن تُعاد المحاولة لاحقاً');
      expect(
        (await prefs()).getString('last_shown_update_version'),
        isNull,
        reason: 'لا تُستهلك البصمة قبل أن تُعرض النافذة',
      );
    });

    testWidgets('تظهر مرة واحدة لكل إصدار، ثم تُفتح يدوياً من الشاشة', (
      WidgetTester tester,
    ) async {
      RemoteMessagingService.availableUpdate.value = sample(latest: '9.9.9');
      await pumpShell(tester);

      expect(await RemoteMessagingService.showAvailableUpdate(), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('تحديث جديد متوفر'), findsOneWidget);
      expect(
        find.textContaining('يرجى تحديث التطبيق'),
        findsOneWidget,
        reason: 'نص الرسالة المنشورة يجب أن يظهر',
      );
      expect(find.text('تحديث الآن'), findsOneWidget);
      expect(
        (await prefs()).getString('last_shown_update_version'),
        '9.9.9',
        reason: 'البصمة تُحفظ مع العرض',
      );

      // إغلاق النافذة
      await tester.tap(find.text('لاحقاً'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('تحديث جديد متوفر'), findsNothing);

      // النداء التالي لا يُظهرها مرة أخرى لنفس الإصدار
      expect(await RemoteMessagingService.showAvailableUpdate(), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('تحديث جديد متوفر'), findsNothing);

      // لكن ضغط المستخدم على السطر يعيد فتحها صراحةً
      expect(
        await RemoteMessagingService.showAvailableUpdate(ignoreDismissed: true),
        isTrue,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('تحديث جديد متوفر'), findsOneWidget);
    });

    testWidgets('التحديث الإجباري يبقى يظهر حتى بعد عرضه', (
      WidgetTester tester,
    ) async {
      RemoteMessagingService.availableUpdate.value = sample(
        latest: '9.9.9',
        force: true,
      );
      await pumpShell(tester);

      // الإجباري لا زرّ تأجيل فيه، فكل نداء يضيف نافذة جديدة (لا يُغلق سابقتها)
      for (int round = 1; round <= 2; round++) {
        expect(await RemoteMessagingService.showAvailableUpdate(), isTrue);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.text('تحديث جديد متوفر').evaluate().length,
          round,
          reason: 'الجولة $round: الإجباري يبقى يظهر في كل مرة',
        );
        expect(
          find.text('لاحقاً'),
          findsNothing,
          reason: 'الإجباري بلا زر تأجيل',
        );
      }
    });

    testWidgets('بلا رابط منشور: لا زرّ يفتح رابطاً فارغاً', (
      WidgetTester tester,
    ) async {
      RemoteMessagingService.availableUpdate.value = sample(url: '');
      await pumpShell(tester);

      expect(await RemoteMessagingService.showAvailableUpdate(), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('تحديث الآن'), findsNothing);
      expect(find.text('حسناً'), findsOneWidget);
    });

    testWidgets('لا تحديث معلن → لا نافذة ولا انتظار', (
      WidgetTester tester,
    ) async {
      await pumpShell(tester);

      expect(await RemoteMessagingService.showAvailableUpdate(), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(Dialog), findsNothing);
    });

    test('الشاشة الرئيسية تطلب النافذة عند الإقلاع مع إعادة محاولة', () {
      final String home = readLib(
        'lib/features/home/presentation/pages/home_page.dart',
      );

      expect(home, contains('RemoteMessagingService.showAvailableUpdate()'));
      expect(
        home,
        contains('_showUpdateIfAvailable(attempt: attempt + 1)'),
        reason: 'عرض واحد فاشل في الإطار الأول كان يُضيّع التنبيه',
      );
    });
  });

  // ── 5) الطرف الناشر: لوحة السيطرة والتحكم ───────────────────────────────
  group('لوحة التحكم: لا يُنشر رقم قديم بصمت', () {
    test('حقل الإصدار يبدأ من المثبَّت ويحذّر إن لم يكن أحدث', () {
      final String panel = readLib('lib/admin_panel_screen.dart');

      expect(
        panel,
        contains('TextEditingController(text: AppVersion.version)'),
        reason: 'الافتراضي كان 2.0.0 — أي تحديث لا يراه أحد',
      );
      expect(panel.contains('TextEditingController(text: "2.0.0")'), isFalse);
      expect(panel, contains('!AppVersion.isNewer(published)'));
      expect(panel, contains('لن يظهر تنبيه تحديث للمستخدمين'));
    });
  });

  // ── 6) سطر «يتوفر إصدار أحدث» في شاشة «عن التطبيق» ──────────────────────
  group('شاشة «عن التطبيق»', () {
    Future<void> pumpAbout(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(420, 900);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: AboutAppScreen(
              onBack: () {},
              userName: 'رزق الله',
              themeMode: 'navy',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
    }

    testWidgets('بلا تحديث → لا سطر تحديث', (WidgetTester tester) async {
      await pumpAbout(tester);

      expect(find.textContaining('يتوفر إصدار أحدث'), findsNothing);
      expect(
        find.text('رقم الإصدار ${AppVersion.display}'),
        findsOneWidget,
        reason: 'الإصدار المعروض هو المثبَّت فعلاً',
      );
    });

    testWidgets('بتحديث منشور → يظهر السطر ويُفتح بالضغط', (
      WidgetTester tester,
    ) async {
      RemoteMessagingService.availableUpdate.value = sample(latest: '3.5.0');
      await pumpAbout(tester);

      final Finder notice = find.textContaining('يتوفر إصدار أحدث 3.5.0');
      expect(notice, findsOneWidget);

      await tester.tap(notice);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('تحديث جديد متوفر'),
        findsOneWidget,
        reason: 'الضغط على السطر يعرض تفاصيل التحديث',
      );
    });

    test('الشاشة تستمع للمُخبر وتفحص عند الفتح', () {
      final String about = readLib(
        'lib/features/about/presentation/pages/about_screen.dart',
      );

      expect(
        about,
        contains('RemoteMessagingService.availableUpdate.addListener'),
      );
      expect(about, contains('RemoteMessagingService.refreshAvailableUpdate()'));
    });
  });
}
