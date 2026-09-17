// ══════════════════════════════════════════════════════════════════════════════
//  مؤذن ليبيا — تنفيذ ترقية قاعدة Supabase عبر واجهة الإدارة (DDL)
// ══════════════════════════════════════════════════════════════════════════════
//
//  لماذا هذا الملف؟
//  `alter table` لا يمكن تنفيذها بمفتاح `anon` ولا `service_role` — كلاهما
//  PostgREST ولا يقبل أوامر بنيوية. الطريق الوحيد برمجياً هو **واجهة إدارة
//  Supabase** بمفتاح شخصي (Personal Access Token بصلاحية database:write):
//
//      POST https://api.supabase.com/v1/projects/{ref}/database/query
//
//  هذا الملف يقرأ ملف الترقية كما هو ويرسله كما هو (بلا إعادة كتابة SQL في
//  الكود)، ثم **يتحقّق** من الأعمدة فعلياً في `information_schema`، فيكون
//  الناتج حكماً على القاعدة لا على الأوامر.
//
//  التشغيل (المفتاح من البيئة لا من سطر الأوامر، فلا يبقى في تاريخ الطرفية):
//      SUPABASE_ACCESS_TOKEN=sbp_xxx dart run tools/apply_supabase_migration.dart
//      SUPABASE_ACCESS_TOKEN=sbp_xxx dart run tools/apply_supabase_migration.dart --check
//
//  --check        : قراءة فقط، لا يرسل أي تعديل (للتحقق من الأعمدة).
//  --dry-run      : يعرض ما سيُرسل بلا شبكة (للتأكد من محتوى الملف).
//
//  المفتاح يُنشأ من:  https://supabase.com/dashboard/account/tokens
//  ويُبطَل (Revoke) فوراً بعد الاستعمال.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';

/// ملف الترقية — مصدر واحد، لا SQL مكرّر داخل هذا الكود.
const String sqlPath = 'database/supabase_app_config_and_broadcasts.sql';

/// ملف الخدمة الذي يحمل رابط المشروع (ومنه نستخرج الـ ref).
const String servicePath = 'lib/remote_messaging_service.dart';

/// الأعمال المطلوبة للتحقق بعد التنفيذ: الجدول → عدد الأعمدة المتوقّع.
const Map<String, int> expectedColumns = <String, int>{
  // 23 موجودة + 12 جديدة. (من الخمسة عشر التي يطلبها التطبيق توجد ثلاثة
  // مسبقاً: marquee_text · home_dua_text · home_dua_color → IF NOT EXISTS
  // لا يضيفها ثانية، فالمجموع 35 لا 38.)
  'app_config': 35,
  'broadcasts': 9,
};

/// مرجع المشروع من رابط Supabase داخل ملف الخدمة (مصدر واحد للرابط).
String projectRef(String serviceFile) {
  final String source = File(serviceFile).readAsStringSync();
  final RegExpMatch? m = RegExp(
    r'https://([a-z0-9]{15,})\.supabase\.(?:co|in)',
    caseSensitive: false,
  ).firstMatch(source);
  if (m == null) {
    stderr.writeln('❌ لم أجد رابط مشروع Supabase في $serviceFile');
    exit(2);
  }
  return m.group(1)!;
}

/// طلب واحد إلى واجهة الإدارة. يُعيد (رمز الحالة، الجسم).
Future<(int, String)> managementQuery({
  required String token,
  required String ref,
  required String sql,
  bool readOnly = false,
}) async {
  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30);
  try {
    final HttpClientRequest req = await client.postUrl(
      Uri.parse('https://api.supabase.com/v1/projects/$ref/database/query'),
    );
    req.headers.set('Authorization', 'Bearer $token');
    // صريح UTF-8: الترميز الافتراضي في HttpClient هو latin1، وملف الترقية
    // يحمل تعليقات عربية — بغير هذا السطر يفشل الإرسال بـ
    // «Invalid argument (string): Contains invalid characters» بلا أي طلب شبكة.
    req.headers.contentType = ContentType(
      'application',
      'json',
      charset: 'utf-8',
    );
    final List<int> payload = utf8.encode(jsonEncode(<String, dynamic>{
      'query': sql,
      'read_only': readOnly,
    }));
    req.headers.contentLength = payload.length;
    req.add(payload);
    final HttpClientResponse res = await req.close();
    final String body = await res.transform(utf8.decoder).join();
    return (res.statusCode, body);
  } finally {
    client.close(force: true);
  }
}

/// أسماء أعمدة جدول من `information_schema` (قراءة فقط).
Future<List<String>> _columnsOf({
  required String token,
  required String ref,
  required String table,
}) async {
  final (int code, String body) = await managementQuery(
    token: token,
    ref: ref,
    readOnly: true,
    sql: "select column_name from information_schema.columns "
        "where table_schema = 'public' and table_name = '$table' "
        'order by ordinal_position',
  );
  if (code != 200 && code != 201) {
    throw StateError('استعلام information_schema فشل (HTTP $code): $body');
  }
  final List<dynamic> rows = jsonDecode(body) as List<dynamic>;
  return <String>[
    for (final dynamic r in rows)
      (Map<String, dynamic>.from(r as Map)['column_name'] ?? '').toString(),
  ];
}

Future<void> main(List<String> args) async {
  final bool checkOnly = args.contains('--check');
  final bool dryRun = args.contains('--dry-run');

  final String sql = File(sqlPath).readAsStringSync();
  final String ref = projectRef(servicePath);

  stdout.writeln('🗂️  ملف الترقية: $sqlPath (${sql.split('\n').length} سطراً)');
  stdout.writeln('🔗 المشروع: $ref');

  // حرس قبل أي شبكة: الملف يجب أن يحمل أوامر التعديل فعلاً، فلا نُرسل ملفاً
  // بلا `alter table` ونظن أننا أضفنا شيئاً (هذا بالضبط ما ضيّع محاولة سابقة).
  final int alterCount =
      RegExp(r'^alter table', multiLine: true).allMatches(sql).length;
  final int addColumnCount =
      RegExp('add column if not exists').allMatches(sql).length;
  stdout.writeln('   أوامر alter table: $alterCount · أسطر add column: '
      '$addColumnCount');
  if (alterCount < 2 || addColumnCount < 15) {
    stderr.writeln(
      '❌ الملف لا يحمل التعديلات المتوقّعة (alter table ≥ 2 و add column ≥ 15) '
      '— توقّفت قبل إرسال أي شيء.',
    );
    exit(3);
  }

  if (dryRun) {
    stdout.writeln('\n── dry-run: أول 12 سطراً مما سيُرسل ──');
    stdout.writeln(sql.split('\n').take(12).join('\n'));
    stdout.writeln('… (المجموع ${sql.length} حرفاً)');
    exit(0);
  }

  final String? token = Platform.environment['SUPABASE_ACCESS_TOKEN'];
  if (token == null || token.trim().isEmpty) {
    stderr.writeln(
      '\n❌ لا يوجد مفتاح في البيئة. شغّل:\n'
      '   SUPABASE_ACCESS_TOKEN=sbp_xxx dart run tools/apply_supabase_migration.dart\n'
      '   (نُنشئ المفتاح من https://supabase.com/dashboard/account/tokens)',
    );
    exit(2);
  }

  try {
    // ── 1) التنفيذ (يُتخطّى مع --check) ───────────────────────────────────
    if (!checkOnly) {
      stdout.writeln('\n── إرسال الترقية ──');
      final (int code, String body) =
          await managementQuery(token: token.trim(), ref: ref, sql: sql);
      final bool ok = code == 200 || code == 201;
      stdout.writeln(ok
          ? '✅ نُفِّذت الترقية (HTTP $code)'
          : '❌ فشل التنفيذ (HTTP $code): $body');
      if (!ok) {
        if (code == 401 || code == 403) {
          stdout.writeln(
            '   ↳ المفتاح بلا صلاحية database:write أو منتهٍ/مُبطل.',
          );
        }
        exit(1);
      }
    } else {
      stdout.writeln('\n── --check: قراءة فقط، بلا أي تعديل ──');
    }

    // ── 2) التحقق: نقرأ الأعمدة من القاعدة نفسها ─────────────────────────
    stdout.writeln('\n── التحقق من الأعمدة في القاعدة ──');
    bool allGood = true;
    for (final MapEntry<String, int> entry in expectedColumns.entries) {
      final List<String> cols = await _columnsOf(
        token: token.trim(),
        ref: ref,
        table: entry.key,
      );
      final bool ok = cols.length >= entry.value;
      if (!ok) allGood = false;
      stdout.writeln('${ok ? '✅' : '❌'} ${entry.key}: ${cols.length} عموداً '
          '(المتوقّع ≥ ${entry.value})');
    }

    final List<String> appConfig = await _columnsOf(
      token: token.trim(),
      ref: ref,
      table: 'app_config',
    );
    const List<String> required = <String>[
      'marquee_messages',
      'marquee_interval_ms',
      'marquee_color',
      'marquee_font',
      'marquee_font_size',
      'home_dua_enabled',
      'home_dua_font',
      'home_dua_font_size',
      'home_dua_interval_ms',
      'home_dua_bold',
      'home_dua_after_minutes',
      'room_passcode',
    ];
    final List<String> missing =
        required.where((String c) => !appConfig.contains(c)).toList();
    if (missing.isEmpty) {
      stdout.writeln('✅ أعمدة الميزة كلها موجودة في app_config');
    } else {
      allGood = false;
      stdout.writeln('❌ ما زالت ناقصة: ${missing.join(', ')}');
    }

    stdout.writeln(allGood
        ? '\n🎉 الربط مكتمل: يمكن للأحاديث ووقت الظهور أن تصل لبقية الأجهزة.'
        : '\n⚠️ الترقية لم تكتمل — أعد التنفيذ أو افحص المشروع.');
    exit(allGood ? 0 : 1);
  } catch (e) {
    stderr.writeln('❌ تعذّر الاتصال بواجهة الإدارة: $e');
    exit(2);
  }
}
