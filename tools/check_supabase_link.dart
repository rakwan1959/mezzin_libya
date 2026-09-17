// ══════════════════════════════════════════════════════════════════════════════
//  مؤذن ليبيا — فحص رابط Supabase (قراءة فقط)
// ══════════════════════════════════════════════════════════════════════════════
//
//  الغرض: التأكد أن قاعدة البيانات **مربوطة فعلاً** بكل ما يقرأه/يكتبه التطبيق:
//    1. صف الإعدادات المفرد (app_config.id = 1) موجود.
//    2. أعمدة app_config التي يستعملها الكود (الشريط العلوي + الرئيسية + الغرفة).
//    3. جدول الرسائل broadcasts: أعمده وعدد صفوفه وطريقة الحذف/الترتيب.
//
//  افتراضياً كل الطلبات **GET** — لا يكتب السكربت شيئاً في قاعدة البيانات.
//
//  التشغيل:   dart run tools/check_supabase_link.dart
//             dart run tools/check_supabase_link.dart --roundtrip
//  الرابط والمفتاح يُقرآن من `lib/remote_messaging_service.dart` (مصدر واحد).
//  الخروج: 0 = كل شيء سليم · 1 = يوجد نقص (الأعمدة الناقصة تُطبع بأسمائها).
//
//  ── الخيار --roundtrip (اختياري): اختبار **مسار الكتابة** لا القراءة فقط ──
//  يقرأ صف app_config ثم **يكتب عليه نفس القيم كما هي** (لا يغيّر شيئاً، ولا
//  يمسّ صفاً في broadcasts لأن أي صف هناك يُطلق إشعاراً على كل الأجهزة)، ثم
//  يعيد القراءة ويقارن: إن نجح فمفتاح anon الموجود في التطبيق يستطيع النشر
//  فعلاً إلى القاعدة؛ وإن فشل فالسبب RLS أو الأعمدة الناقصة.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';

/// أعمدة `app_config` التي يقرأها أو يكتبها التطبيق.
const List<String> requiredAppConfigColumns = <String>[
  // الشريط العلوي في شاشة الإعدادات (أسماء الله الحسنى / الأحاديث + وقت الظهور)
  'marquee_text',
  'marquee_messages',
  'marquee_interval_ms',
  'marquee_color',
  'marquee_font',
  'marquee_font_size',
  // النص المتحرك في الشاشة الرئيسية
  'home_dua_enabled',
  'home_dua_text',
  'home_dua_color',
  'home_dua_font',
  'home_dua_font_size',
  'home_dua_interval_ms',
  'home_dua_bold',
  'home_dua_after_minutes',
  // رقم غرفة المراسلة
  'room_passcode',
];

/// أعمدة جدول الرسائل `broadcasts` التي يستعملها التطبيق.
const List<String> requiredBroadcastColumns = <String>[
  'id',
  'title',
  'message',
  'btn_text',
  'btn_url',
  'target_uid',
  'target_city',
  'views',
  'created_at',
];

/// الرابط والمفتاح من ملف الخدمة — فلا تتكرر القيم في مكانين.
({String url, String key}) readSupabaseConfig(String serviceFile) {
  final String source = File(serviceFile).readAsStringSync();

  final RegExpMatch? url = RegExp(
    r"""static const String url\s*=\s*'([^']+)'""",
  ).firstMatch(source);
  final RegExpMatch? key = RegExp(
    r"""anonKey\s*=?\s*\n?\s*'([^']+)'""",
  ).firstMatch(source);

  if (url == null || key == null) {
    stderr.writeln('❌ لم أجد رابط/مفتاح Supabase في $serviceFile');
    exit(2);
  }
  return (url: url.group(1)!.trim(), key: key.group(1)!.trim());
}

/// كتابة صف عبر PATCH. يُعيد (رمز الحالة، جسم الرد).
Future<(int, String)> _patchJson(
  HttpClient client,
  Uri uri, {
  required String key,
  required Map<String, dynamic> payload,
}) async {
  final HttpClientRequest req = await client.patchUrl(uri);
  req.headers.set('apikey', key);
  req.headers.set('Authorization', 'Bearer $key');
  // UTF-8 صريح: ترميز HttpClient الافتراضي latin1، والقيم المكتوبة عربية،
  // فبغيره يفشل الطلب بـ «Contains invalid characters» بلا أي اتصال شبكة.
  req.headers.contentType = ContentType(
    'application',
    'json',
    charset: 'utf-8',
  );
  req.headers.set('Prefer', 'return=minimal');
  final List<int> payloadBytes = utf8.encode(jsonEncode(payload));
  req.headers.contentLength = payloadBytes.length;
  req.add(payloadBytes);
  final HttpClientResponse res = await req.close();
  final String body = await res.transform(utf8.decoder).join();
  return (res.statusCode, body);
}

/// طلب GET فقط. يُعيد (رمز الحالة، جسم الرد، ترويسة content-range).
Future<(int, String, String)> _get(
  HttpClient client,
  Uri uri, {
  required String key,
  bool count = false,
}) async {
  final HttpClientRequest req = await client.getUrl(uri);
  req.headers.set('apikey', key);
  req.headers.set('Authorization', 'Bearer $key');
  req.headers.set('Accept', 'application/json');
  if (count) req.headers.set('Prefer', 'count=exact');
  final HttpClientResponse res = await req.close();
  final String body = await res.transform(utf8.decoder).join();
  return (
    res.statusCode,
    body,
    res.headers.value('content-range') ?? '',
  );
}

/// ── اختبار مسار الكتابة (يُشغَّل فقط مع --roundtrip) ─────────────────────
///
///  يكتب على صف `app_config` **نفس القيم المقروءة** فلا تتغيّر بيانات الإنتاج،
///  ثم يعيد قراءتها ويقارنها. هذا يفصل بين سببين مختلفين لفشل النشر في التطبيق:
///    • نجاح الكتابة = مفتاح anon وسياسات RLS تسمح بالنشر (بقيّة المشكلة أعمدة).
///    • فشل الكتابة = RLS تمنع التحديث، فلا يصل شيء لبقية الأجهزة مهما أُضيفت أعمدة.
Future<void> _writeProbe(
  HttpClient client,
  ({String url, String key}) config,
  Map<String, dynamic> row,
  List<String> problems,
) async {
  stdout.writeln('\n── اختبار الكتابة (--roundtrip) ──');

  // نرسل الأعمدة الموجودة فقط: إرسال عمود ناقص يعطي 400 من PostgREST ولا
  // يقيس صلاحية الكتابة أصلاً (والأعمدة الناقصة مُبلَّغ عنها أعلاه).
  final Map<String, dynamic> payload = <String, dynamic>{'id': 1};
  for (final String c in requiredAppConfigColumns) {
    if (row.containsKey(c) && row[c] != null) payload[c] = row[c];
  }

  final (int code, String body) = await _patchJson(
    client,
    Uri.parse('${config.url}/rest/v1/app_config?id=eq.1'),
    key: config.key,
    payload: payload,
  );

  if (code != 200 && code != 204) {
    problems.add('كتابة app_config فشلت (HTTP $code): $body');
    stdout.writeln('❌ الكتابة مرفوضة (HTTP $code) — راجع سياسات RLS لـ anon');
    return;
  }
  stdout.writeln('✅ الكتابة مسموحة (HTTP $code) — ${payload.length - 1} عموداً');

  // ثم نقرأ ونقارن: يجب أن تعود نفس القيم حرفياً.
  final (int readCode, String readBody, String _) = await _get(
    client,
    Uri.parse('${config.url}/rest/v1/app_config?select=*&id=eq.1'),
    key: config.key,
  );
  if (readCode != 200) {
    problems.add('إعادة القراءة بعد الكتابة فشلت (HTTP $readCode)');
    stdout.writeln('❌ إعادة القراءة فشلت (HTTP $readCode)');
    return;
  }

  final List<dynamic> rows = jsonDecode(readBody) as List<dynamic>;
  if (rows.isEmpty) {
    problems.add('صف app_config اختفى بعد الكتابة!');
    stdout.writeln('❌ الصف اختفى بعد الكتابة');
    return;
  }
  final Map<String, dynamic> after =
      Map<String, dynamic>.from(rows.first as Map);

  final List<String> drifted = <String>[];
  payload.forEach((String c, dynamic v) {
    if (c == 'id') return;
    if (after[c] != v) drifted.add(c);
  });

  if (drifted.isEmpty) {
    stdout.writeln('✅ القيم عادت كما هي — الدورة كاملة (كتابة ← قراءة) سليمة');
  } else {
    problems.add('قيم تغيّرت بعد الكتابة: ${drifted.join(', ')}');
    stdout.writeln('❌ قيم مختلفة بعد الكتابة: ${drifted.join(', ')}');
  }
}

Future<void> main(List<String> args) async {
  final bool roundtrip = args.contains('--roundtrip');
  final List<String> positional =
      args.where((String a) => !a.startsWith('--')).toList();
  final String serviceFile = positional.isNotEmpty
      ? positional.first
      : 'lib/remote_messaging_service.dart';
  final ({String url, String key}) config = readSupabaseConfig(serviceFile);

  stdout.writeln(
    roundtrip
        ? '🔗 فحص رابط Supabase (قراءة + اختبار كتابة بلا تغيير القيم)'
        : '🔗 فحص رابط Supabase (قراءة فقط)',
  );
  stdout.writeln('   المشروع: ${config.url}');

  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);
  final List<String> problems = <String>[];

  try {
    // ── 1) صف الإعدادات المفرد ────────────────────────────────────────────
    stdout.writeln('\n── app_config ──');
    final (int code, String body, String _) = await _get(
      client,
      Uri.parse('${config.url}/rest/v1/app_config?select=*&id=eq.1'),
      key: config.key,
    );

    if (code != 200) {
      problems.add('قراءة app_config فشلت (HTTP $code): $body');
      stdout.writeln('❌ قراءة الصف فشلت (HTTP $code)');
    } else {
      final List<dynamic> rows = jsonDecode(body) as List<dynamic>;
      if (rows.isEmpty) {
        problems.add('لا يوجد صف إعدادات (app_config.id = 1)');
        stdout.writeln('❌ لا يوجد صف id = 1 — نفّذ ملف SQL الإضافي');
      } else {
        final Map<String, dynamic> row =
            Map<String, dynamic>.from(rows.first as Map);
        stdout.writeln('✅ الصف id = 1 موجود (${row.length} عموداً)');
        final List<String> missing = <String>[
          for (final String c in requiredAppConfigColumns)
            if (!row.containsKey(c)) c,
        ];
        if (missing.isEmpty) {
          stdout.writeln('✅ كل أعمدة التطبيق موجودة');
        } else {
          problems.add('أعمدة ناقصة في app_config: ${missing.join(', ')}');
          stdout.writeln('❌ أعمدة ناقصة (${missing.length}):');
          for (final String m in missing) {
            stdout.writeln('   • $m');
          }
          stdout.writeln(
            '   ↳ نفّذ database/supabase_app_config_and_broadcasts.sql',
          );
        }

        if (roundtrip) {
          await _writeProbe(client, config, row, problems);
        }
      }
    }

    // ── 2) جدول الرسائل: الأعمدة + العدد ──────────────────────────────────
    stdout.writeln('\n── broadcasts (رسائل البث والمستخدمين) ──');
    final List<String> missingBroadcast = <String>[];
    for (final String column in requiredBroadcastColumns) {
      final (int status, String _, String _) = await _get(
        client,
        Uri.parse('${config.url}/rest/v1/broadcasts?select=$column&limit=0'),
        key: config.key,
      );
      if (status != 200) missingBroadcast.add(column);
    }
    if (missingBroadcast.isEmpty) {
      stdout.writeln('✅ كل الأعمدة موجودة');
    } else {
      problems.add('أعمدة ناقصة في broadcasts: ${missingBroadcast.join(', ')}');
      stdout.writeln('❌ أعمدة ناقصة: ${missingBroadcast.join(', ')}');
    }

    final (int countCode, String _, String range) = await _get(
      client,
      Uri.parse('${config.url}/rest/v1/broadcasts?select=id&limit=0'),
      key: config.key,
      count: true,
    );
    if (countCode == 200 && range.contains('/')) {
      final String total = range.split('/').last;
      stdout.writeln('✅ الجدول مقروء — عدد الصفوف الحالي: $total');
      if (total == '0') {
        stdout.writeln(
          '   ℹ️ لا رسائل بعد: تُضاف من لوحة التحكم (1918) ← الرسائل.',
        );
      }
    } else {
      problems.add('قراءة broadcasts فشلت (HTTP $countCode)');
      stdout.writeln('❌ قراءة الجدول فشلت (HTTP $countCode)');
    }
  } catch (e) {
    problems.add('تعذّر الوصول إلى الشبكة/Supabase: $e');
    stdout.writeln('❌ تعذّر الاتصال: $e');
  } finally {
    client.close(force: true);
  }

  stdout.writeln('');
  if (roundtrip) {
    stdout.writeln(
      'ℹ️ لم يُكتب أي تغيير: الاختبار أعاد كتابة نفس القيم وقرأها مرة أخرى.',
    );
    stdout.writeln('');
  }
  if (problems.isEmpty) {
    stdout.writeln('✅ الربط سليم: كل ما يقرأه/يكتبه التطبيق موجود في القاعدة.');
    exit(0);
  }
  stdout.writeln('⚠️ نقاط تحتاج معالجة (${problems.length}):');
  for (final String p in problems) {
    stdout.writeln('   • $p');
  }
  exit(1);
}
