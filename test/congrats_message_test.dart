import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muezzin_libya_app/remote_messaging_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// رسالة التهنئة (اللوحة الأولى 1916 — «الرسالة الخفية»):
///   1. لها **مفتاح تفعيل صريح** يوضح حالتها، لا تفعيل ضمنيّ مبهم.
///   2. التفعيل والنص يُحفظان محلياً **قبل** النشر ولا يعتمد عليه — وهذه كانت
///      العلّة: الحفظ كان مشروطاً بنجاح النشر، فإن تعثّر الاتصال لا يُفعَّل شيء.
///   3. تسافر في عمود `dedication_msg` الموجود بصيغة JSON — بلا أي SQL.
///   4. المعطَّلة أو الفارغة لا تظهر للمستخدم.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  group('الحالة الافتراضية', () {
    test('لا شيء محفوظ بعد → غير مفعّلة وليست نشطة', () async {
      final CongratsSettings s = await RemoteMessagingService.readCongratsSettings();

      expect(s.enabled, isFalse);
      expect(s.message, isEmpty);
      expect(s.target, isEmpty);
      expect(s.isActive, isFalse);
    });

    test('المعطَّلة أو الفارغة لا تظهر للمستخدم', () async {
      expect(await RemoteMessagingService.getActiveCongrats(), isEmpty);

      // نص بلا تفعيل
      await RemoteMessagingService.saveCongratsLocally(
        const CongratsSettings(message: 'كل عام وأنتم بخير'),
      );
      expect(await RemoteMessagingService.getActiveCongrats(), isEmpty);

      // تفعيل بلا نص
      await RemoteMessagingService.saveCongratsLocally(
        const CongratsSettings(enabled: true),
      );
      expect(await RemoteMessagingService.getActiveCongrats(), isEmpty);
    });
  });

  group('التفعيل الصريح', () {
    test('المفعّلة ولها نص → نشطة وتظهر', () async {
      await RemoteMessagingService.saveCongratsLocally(
        const CongratsSettings(enabled: true, message: 'عيدكم مبارك'),
      );

      final CongratsSettings saved =
          await RemoteMessagingService.readCongratsSettings();
      expect(saved.enabled, isTrue);
      expect(saved.isActive, isTrue);
      expect(await RemoteMessagingService.getActiveCongrats(), 'عيدكم مبارك');
    });

    test('إطفاء المفتاح يُخفيها فوراً مع بقاء النص محفوظاً', () async {
      await RemoteMessagingService.saveCongratsLocally(
        const CongratsSettings(enabled: true, message: 'تهنئة'),
      );
      await RemoteMessagingService.saveCongratsLocally(
        const CongratsSettings(enabled: false, message: 'تهنئة'),
      );

      expect(await RemoteMessagingService.getActiveCongrats(), isEmpty);
      final CongratsSettings saved =
          await RemoteMessagingService.readCongratsSettings();
      expect(saved.message, 'تهنئة', reason: 'النص يجب أن يبقى للتعديل عليه');
      expect(saved.enabled, isFalse);
    });
  });

  group('الحفظ المحلي بلا إنترنت (العلّة الأصلية)', () {
    test('يُحفظ ويُفعَّل على الجهاز حتى لو تعذّر النشر تماماً', () async {
      // Supabase غير مُهيّأ في الاختبار → النشر يفشل حتماً
      final bool published = await RemoteMessagingService.publishCongrats(
        const CongratsSettings(enabled: true, message: 'مبروك النجاح'),
      );

      expect(published, isFalse, reason: 'النشر بلا سيرفر يجب أن يُرجع false بلا استثناء');

      // ثم الحفظ المحلي (وهو ما يفعله الزر أولاً) يعمل دائماً
      await RemoteMessagingService.saveCongratsLocally(
        const CongratsSettings(enabled: true, message: 'مبروك النجاح'),
      );
      expect(await RemoteMessagingService.getActiveCongrats(), 'مبروك النجاح');
    });

    test('الحمولة المرسلة عمودان فقط: id و dedication_msg', () {
      const CongratsSettings s = CongratsSettings(
        enabled: true,
        message: 'تهنئة',
      );
      final Map<String, dynamic> envelope = s.toEnvelope();

      expect(envelope['t'], 'congrats');
      expect(envelope['enabled'], isTrue);
      expect(envelope['msg'], 'تهنئة');
      expect(envelope['target'], isEmpty);
      // وبهذا يبقى النشر على عمود موجود أصلاً
      expect(jsonEncode(envelope), contains('congrats'));
    });
  });

  group('فك التغليف من السيرفر', () {
    test('نص JSON وكائن JSON يعطيان نفس النتيجة', () {
      const String json =
          '{"t":"congrats","enabled":true,"msg":"كل عام بخير","target":""}';

      final CongratsSettings fromString = CongratsSettings.decode(json);
      final CongratsSettings fromMap = CongratsSettings.decode(
        jsonDecode(json) as Map<String, dynamic>,
      );

      expect(fromString.message, 'كل عام بخير');
      expect(fromString.enabled, isTrue);
      expect(fromMap.message, fromString.message);
      expect(fromMap.enabled, fromString.enabled);
    });

    test('قيم غير تالفة أخرى تُفسَّر كـ«غير مفعّلة» فلا يظهر شيء', () {
      for (final dynamic raw in <dynamic>[
        null,
        '',
        '   ',
        'نص عادي ليس JSON',
        '{تالف',
        '{"t":"greeting","enabled":true,"msg":"ليست تهنئة"}',
        <String, dynamic>{'t': 'other'},
      ]) {
        final CongratsSettings s = CongratsSettings.decode(raw);
        expect(s.enabled, isFalse, reason: 'قيمة «$raw» فُعِّلت بلا وجه حق');
        expect(s.isActive, isFalse);
      }
    });

    test('تطبيق حمولة السيرفر يحدّث الكاش المحلي (تفعيل وتعطيل)', () async {
      // تفعيل من لوحة التحكم
      await RemoteMessagingService.applyCongratsPayload(
        '{"t":"congrats","enabled":true,"msg":"عيد سعيد","target":""}',
      );
      expect(await RemoteMessagingService.getActiveCongrats(), 'عيد سعيد');

      // تعطيل من لوحة التحكم
      await RemoteMessagingService.applyCongratsPayload(
        '{"t":"congrats","enabled":false,"msg":"عيد سعيد","target":""}',
      );
      expect(await RemoteMessagingService.getActiveCongrats(), isEmpty);
    });
  });

  group('الرقم التسلسلي', () {
    test('رسالة موجّهة لجهاز آخر لا تظهر هنا', () async {
      await RemoteMessagingService.saveCongratsLocally(
        const CongratsSettings(
          enabled: true,
          message: 'خاصة بجهاز معيّن',
          target: 'USR-XXXXXX',
        ),
      );

      final String mine = await RemoteMessagingService.getOrCreateUserId();
      expect(mine, isNotEmpty);
      expect(await RemoteMessagingService.getActiveCongrats(), isEmpty,
          reason: 'الرسالة موجّهة لجهاز آخر فيجب ألا تظهر هنا');
    });

    test('رسالة موجّهة لهذا الجهاز تظهر', () async {
      final String mine = await RemoteMessagingService.getOrCreateUserId();
      await RemoteMessagingService.saveCongratsLocally(
        CongratsSettings(enabled: true, message: 'لك أنت', target: mine),
      );

      expect(await RemoteMessagingService.getActiveCongrats(), 'لك أنت');
    });
  });

  group('معاينة الرسالة (زر الاختبار في اللوحة)', () {
    testWidgets('المعاينة تعرض نص التهنئة كما يراه المستخدم', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      // كارد التهنئة فقط (بلا نغمة: طبقة الصوت تتعلّق في بيئة الاختبار).
      // لا ننتظر النافذة — فهي تبقى مفتوحة حتى يغلقها المستخدم.
      unawaited(
        RemoteMessagingService.showCongratsCard(ctx, 'تهانينا بمناسبة العيد'),
      );
      await tester.pumpAndSettle();

      expect(find.text('تهانينا بمناسبة العيد'), findsOneWidget);

      // إغلاق النافذة بزرّها
      await tester.tap(find.text('تقبل الله طاعتكم'));
      await tester.pumpAndSettle();
      expect(find.text('تهانينا بمناسبة العيد'), findsNothing);
    });
  });
}
