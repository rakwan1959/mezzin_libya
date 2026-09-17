// ══════════════════════════════════════════════════════════════════════════════
//  مؤذن ليبيا — اختبار حيّ من طرف إلى طرف: نشر حديث + وقت ظهور من لوحة 1918
// ══════════════════════════════════════════════════════════════════════════════
//
//  ما يفعله هذا الملف، بالترتيب، على **قاعدة الإنتاج الحقيقية**:
//    1. ينشر الأحاديث ووقت الظهور بنفس الدالّة التي يستدعيها زر النشر في لوحة
//       التحكم (`RemoteMessagingService.publishSettingsMarquee`) — لا تقليداً
//       لحمولتها، بل الشيفرة نفسها.
//    2. يقرأ الصف مرة أخرى **بطلب خام** (REST/mفتاح anon) فلا يكون الحكم من
//       الكود الذي كتب، بل من القاعدة.
//    3. يمثّل «جهازاً آخر»: يفرّغ التخزين المحلي، ثم يقرأ الصف من السيرفر
//       ويمرّره على `applySettingsMarqueeConfig` — نفس مسار شاشة الإعدادات.
//    4. يعرض الناتج في `SettingsMarqueeHeader` ويتحقّق أن الحديث الأول يظهر
//       فوراً وأن التقليب يحدث **بعد وقت الظهور المنشور بالضبط**.
//
//  ⚠️ تنبيهان:
//    • هذا اختبار **كتابة على الإنتاج**: ما ينشره يصبح هو الشريط العلوي في
//      شاشة الإعدادات على **كل الأجهزة**. تغييره أو إرجاعه إلى أسماء الله
//      الحسنى يكون من لوحة 1918 (زر استعادة الافتراضي) أو بإعادة تشغيل هذا
//      الملف بقيم أخرى.
//    • يحتاج إنترنت، ولذلك هو **خارج مجلد `test/`**: أمر `flutter test` وحده
//      لا يشغّله (وإلا صار كل تشغيل للاختبارات كتابةً على الإنتاج).
//
//  التشغيل:
//      flutter test tools/live_marquee_e2e_test.dart
// ══════════════════════════════════════════════════════════════════════════════

// ملف اختبار خارج مجلد `test/` عن قصد (كي لا يشغّله `flutter test` تلقائياً
// فيكتب على الإنتاج)، فيحتاج تعطيل ممانعتين خاصّتين بمجلد الاختبارات.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:muezzin_libya_app/features/settings/presentation/widgets/settings_marquee_header.dart';
import 'package:muezzin_libya_app/remote_messaging_service.dart';

/// ── ما سيُنشر ───────────────────────────────────────────────────────────────
/// أحاديث مشهورة برواية البخاري ومسلم — تُعرض في الشريط العلوي لشاشة
/// الإعدادات واحداً بعد الآخر بوقت الظهور أدناه. (مكتوبة هنا بسطرين للقراءة،
/// و[storedHadiths] أدناه هي ما يُخزَّن فعلاً: سطر واحد = حديث واحد.)
const List<String> publishedHadiths = <String>[
  '«إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ، وَإِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى»\n'
      'رواه البخاري ومسلم',
  '«أَحَبُّ الْأَعْمَالِ إِلَى اللَّهِ الصَّلَاةُ عَلَى وَقْتِهَا»\n'
      'رواه البخاري ومسلم',
];

/// ما يجب أن يُخزَّن ويُعرض: الحديث والرواية على سطر واحد (تطبيق قاعدة
/// «سطر واحد = حديث واحد» في `normalizeMessages`).
final List<String> storedHadiths =
    SettingsMarqueeSettings.normalizeMessages(publishedHadiths);

/// وقت الظهور المنشور: 5 ثوانٍ لكل حديث (يختلف عن الافتراضي 6 ليكون النشر
/// ظاهراً في الفحص لا مجرد إعادة كتابة الافتراضي).
const int publishedIntervalMs = 5000;

/// قراءة خام لصف `app_config` بمفتاح التطبيق — مستقلة عن الـ SDK تماماً، فيكون
/// التحقق من القاعدة نفسها لا من الكود الذي كتب فيها.
Future<Map<String, dynamic>> rawAppConfigRow() async {
  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30);
  try {
    final HttpClientRequest req = await client.getUrl(
      Uri.parse(
        '${SupabaseConfig.url}/rest/v1/app_config'
        '?select=marquee_text,marquee_messages,marquee_interval_ms'
        '&id=eq.1',
      ),
    );
    req.headers.set('apikey', SupabaseConfig.anonKey);
    req.headers.set('Authorization', 'Bearer ${SupabaseConfig.anonKey}');
    final HttpClientResponse res = await req.close();
    final String body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      throw StateError('قراءة app_config فشلت (HTTP ${res.statusCode}): $body');
    }
    final List<dynamic> rows = jsonDecode(body) as List<dynamic>;
    if (rows.isEmpty) throw StateError('صف app_config id=1 غير موجود');
    return Map<String, dynamic>.from(rows.first as Map);
  } finally {
    client.close(force: true);
  }
}

void main() {
  // الخطوط من الأصول لا من الشبكة (وإلا انتظر الهيدر تحميلاً لا يحدث).
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // flutter_test يبدّل HttpClient بنسخة وهمية تُرجع 400 لكل طلب، فيصير أي
    // نداء شبكة حقيقي مستحيلاً. إعادة التجاوز إلى null تُرجع HttpClient
    // الحقيقي — بدون هذا لا يصل شيء إلى Supabase ويبدو كل شيء «فاشلاً» بلا سبب.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  });

  // ── 1) النشر بنفس مسار زر اللوحة ────────────────────────────────────────
  test('لوحة 1918: النشر ينجح عبر دالّة اللوحة نفسها', () async {
    final bool published = await RemoteMessagingService.publishSettingsMarquee(
      SettingsMarqueeSettings(
        text: publishedHadiths.first,
        messages: publishedHadiths,
        intervalMs: publishedIntervalMs,
        color: SettingsMarqueeSettings.defaultColor,
        fontFamily: SettingsMarqueeSettings.defaultFontFamily,
        fontSize: SettingsMarqueeSettings.defaultFontSize,
      ),
    );
    expect(
      published,
      isTrue,
      reason: 'فشل النشر — راجع الأعمدة أو سياسات RLS',
    );
  });

  // ── 2) الوصول إلى قاعدة Supabase (قراءة خام) ────────────────────────────
  test('قاعدة Supabase: الأحاديث ووقت الظهور وصلت فعلاً', () async {
    final Map<String, dynamic> row = await rawAppConfigRow();

    final List<String> stored =
        SettingsMarqueeSettings.parseMessages('${row['marquee_messages']}');
    expect(stored, storedHadiths, reason: 'الأحاديث كما نُشرت حرفياً');
    expect(
      stored.length,
      storedHadiths.length,
      reason: 'لم يُفقد حديث ولم يُضف آخر — حديث السطرين حديث واحد',
    );

    expect(
      row['marquee_interval_ms'],
      publishedIntervalMs,
      reason: 'وقت الظهور المنشور هو المحفوظ لا الافتراضي',
    );

    // النسخ القديمة تقرأ `marquee_text` وحده: يجب أن تحمل الحديث الأول.
    expect(
      '${row['marquee_text']}'.trim(),
      storedHadiths.first,
      reason: 'التوافق الخلفي: marquee_text = الحديث الأول',
    );
  });

  // ── 3) جهاز آخر: من السيرفر إلى هيدر شاشة الإعدادات ────────────────────
  testWidgets('جهاز آخر: يقرأ من السيرفر ثم يعرض الحديث ويتقلّب بوقت الظهور', (
    WidgetTester tester,
  ) async {
    // جهاز جديد: بلا أي تخصيص محلي — فلا بد أن يأتي كل شيء من السيرفر.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    // شبكة حقيقية داخل اختبار widget تحتاج runAsync.
    final SettingsMarqueeSettings? remote = await tester.runAsync(() async {
      // نفس ما تفعله `SettingsScreen._loadMarqueeText` بالحرف.
      final dynamic config = await Supabase.instance.client
          .from('app_config')
          .select()
          .eq('id', 1)
          .maybeSingle();
      return RemoteMessagingService.applySettingsMarqueeConfig(
        config == null ? null : Map<String, dynamic>.from(config as Map),
      );
    });
    expect(remote, isNotNull, reason: 'فشل جلب الصف من السيرفر');
    expect(remote!.messages, storedHadiths, reason: 'الأحاديث وصلت للجهاز');
    expect(remote.intervalMs, publishedIntervalMs, reason: 'وقت الظهور وصل');

    // وبنفس طريقة شاشة الإعدادات: الناتج يُغذّى إلى الهيدر مباشرة.
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SettingsMarqueeHeader(
              messages: remote.effectiveMessages,
              settings: remote,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(storedHadiths[0]), findsWidgets, reason: 'يظهر فوراً');
    expect(find.text(storedHadiths[1]), findsNothing);

    // قبل انتهاء وقت الظهور المنشور لا يتغيّر شيء (وقت الظهور هو المرجع).
    await tester.pump(Duration(milliseconds: publishedIntervalMs - 300));
    expect(find.text(storedHadiths[0]), findsWidgets);
    expect(find.text(storedHadiths[1]), findsNothing);

    // وبعده بالضبط ينتقل إلى الحديث التالي.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(storedHadiths[1]), findsWidgets, reason: 'التقليب');
    expect(find.text(storedHadiths[0]), findsNothing);

    // نُزيل الهيدر فيُلغى مؤقّته (فلا يبقى مؤقّت معلّق بعد الاختبار).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
