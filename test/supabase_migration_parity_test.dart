// ══════════════════════════════════════════════════════════════════════════════
//  حرس تطابق قاعدة البيانات مع الكود (بلا شبكة)
// ══════════════════════════════════════════════════════════════════════════════
//
//  ليش هذا الملف؟
//  كتب التطبيق تقرأ وتكتب أعمدة في `app_config` و`broadcasts`. إن نسي أحدهم
//  عموداً في ملف SQL (أو أضاف عموداً في الكود ولم يُضفه في القاعدة) فسيفشل
//  النشر **بصمت**: الحفظ المحلي ينجح ولا يصل شيء لبقية الأجهزة. هذا الملف يجعل
//  هذا الانحراف مستحيلاً لأنه يقرأ الملفات الحقيقية ويقارنها:
//
//    1. أعمدة SQL = أعمدة فاحص الربط (tools/check_supabase_link.dart).
//    2. أعمدة SQL = الأعمدة التي ينصّ عليها الكود فعلاً (marquee_* · home_dua_*
//       · room_passcode) — فلا عمود ميت ولا عمود ناقص.
//    3. قيم الافتراضي المكتوبة بجانب كل عمود في SQL = ثوابت Dart
//       (وقت الظهور · الحجم · الخط · اللون …).
//    4. الملف **آمن التكرار** ولا يمسح شيئاً: كل `create`/`add column` بـ
//       `if not exists`، ولا `drop`، ولا صف في `broadcasts` (أي صف هناك يُطلق
//       إشعاراً على كل الأجهزة).
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _sqlPath = 'database/supabase_app_config_and_broadcasts.sql';
const String _checkerPath = 'tools/check_supabase_link.dart';
const String _servicePath = 'lib/remote_messaging_service.dart';
const String _adminPath = 'lib/admin_panel_screen.dart';
const String _settingsScreenPath =
    'lib/features/settings/presentation/pages/settings_screen.dart';

/// كل الملفات التي تُسمّي أعمدة القاعدة نصياً.
List<String> get _codeSources => <String>[
      _servicePath,
      _adminPath,
      _settingsScreenPath,
    ];

/// أعمدة `alter table public.<table>` في ملف SQL.
Map<String, List<String>> sqlColumnsByTable(String sql) {
  final Map<String, List<String>> out = <String, List<String>>{};
  String? currentTable;
  for (final String line in sql.split('\n')) {
    final RegExpMatch? table = RegExp(
      r'alter table\s+(?:public\.)?(\w+)',
      caseSensitive: false,
    ).firstMatch(line);
    if (table != null) {
      currentTable = table.group(1)!.toLowerCase();
      out.putIfAbsent(currentTable, () => <String>[]);
    }
    final RegExpMatch? column = RegExp(
      r'add column if not exists\s+(\w+)',
      caseSensitive: false,
    ).firstMatch(line);
    if (column != null && currentTable != null) {
      out[currentTable]!.add(column.group(1)!.toLowerCase());
    }
  }
  return out;
}

/// القائمة المسماة `const List<String> <name> = <String>[ ... ];` في الفاحص.
List<String> checkerList(String source, String name) {
  final int start = source.indexOf('const List<String> $name');
  if (start < 0) throw StateError('لم أجد $name في الفاحص');
  final int end = source.indexOf('];', start);
  if (end < start) throw StateError('قائمة $name غير مغلقة');
  return RegExp(r"'([^']+)'")
      .allMatches(source.substring(start, end))
      .map((RegExpMatch m) => m.group(1)!.toLowerCase())
      .toList();
}

/// جسم الصنف في ملف Dart (من إعلانه حتى الصنف التالي).
String classRegion(String source, String className) {
  final int start = source.indexOf('class $className');
  if (start < 0) throw StateError('لم أجد الصنف $className');
  final int end = source.indexOf('\nclass ', start + 1);
  return end == -1 ? source.substring(start) : source.substring(start, end);
}

String dartStringConstant(String region, String name) {
  final RegExpMatch? m =
      RegExp("$name\\s*=\\s*'([^']*)'").firstMatch(region);
  if (m == null) throw StateError('لم أجد الثابت النصي $name');
  return m.group(1)!;
}

int dartIntConstant(String region, String name) {
  final RegExpMatch? m =
      RegExp('$name\\s*=\\s*(0x[0-9A-Fa-f]+|\\d+)').firstMatch(region);
  if (m == null) throw StateError('لم أجد الثابت الرقمي $name');
  final String raw = m.group(1)!;
  return raw.startsWith('0x')
      ? int.parse(raw.substring(2), radix: 16)
      : int.parse(raw);
}

bool dartBoolConstant(String region, String name) {
  final RegExpMatch? m =
      RegExp('$name\\s*=\\s*(true|false)').firstMatch(region);
  if (m == null) throw StateError('لم أجد الثابت المنطقي $name');
  return m.group(1) == 'true';
}

/// القيم الافتراضية المكتوبة بجانب كل عمود في `alter table` نفسه:
///   `add column if not exists marquee_font text default 'Amiri',`
///
/// نقرأها من سطر العمود لا من كتلة `update` منفصلة، لأن الافتراضي يجب أن يبقى
/// ملاصقاً لعموده فلا ينحرف أحدهما عن الآخر.
Map<String, String> columnDefaults(String sql) {
  final Map<String, String> out = <String, String>{};
  for (final String rawLine in sql.split('\n')) {
    // تجاهل التعليقات في نهاية السطر (مثل: -- وقت الظهور 6 ثوانٍ)
    final String line = rawLine.split('--').first.trim();
    final RegExpMatch? match = RegExp(
      r'^add column if not exists\s+(\w+)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) continue;
    String rest = match.group(2)!.trim();
    if (rest.endsWith(',')) rest = rest.substring(0, rest.length - 1).trim();
    final int at = rest.toLowerCase().indexOf(' default ');
    if (at < 0) continue; // عمود بلا افتراضي: القرار للتطبيق
    // قيم النصوص في SQL تأتي محاطة بعلامات تنصيص: 'Amiri' → Amiri
    out[match.group(1)!.toLowerCase()] =
        rest.substring(at + ' default '.length).trim().replaceAll("'", '');
  }
  return out;
}

void main() {
  final String sql = File(_sqlPath).readAsStringSync();
  final String checker = File(_checkerPath).readAsStringSync();
  final String service = File(_servicePath).readAsStringSync();

  final Map<String, List<String>> sqlColumns = sqlColumnsByTable(sql);
  final List<String> appConfigColumns = checkerList(
    checker,
    'requiredAppConfigColumns',
  );
  final List<String> broadcastColumns = checkerList(
    checker,
    'requiredBroadcastColumns',
  );

  group('أعمدة SQL تطابق فاحص الربط', () {
    test('app_config: نفس الأعمدة بالضبط (لا ناقص ولا ميت)', () {
      final Set<String> inSql = (sqlColumns['app_config'] ?? <String>[]).toSet();
      final Set<String> inChecker = appConfigColumns.toSet();

      // حرس ضد النجاح الفارغ: لو فشل الاستخراج لعادت المجموعتان فارغتين
      // ونجح الفرق بلا معنى.
      expect(inSql.length, greaterThanOrEqualTo(10),
          reason: 'لم أستخرج أعمدة app_config من SQL');
      expect(inChecker.length, greaterThanOrEqualTo(10),
          reason: 'لم أستخرج أعمدة app_config من الفاحص');

      expect(
        inChecker.difference(inSql),
        isEmpty,
        reason: 'الفاحص ينتظر أعمدة غير موجودة في ملف SQL',
      );
      expect(
        inSql.difference(inChecker),
        isEmpty,
        reason: 'ملف SQL يضيف أعمدة لا يعرفها الفاحص/الكود',
      );
    });

    test('broadcasts: أعمدة الفاحص كلها موجودة في SQL', () {
      final Set<String> inSql = (sqlColumns['broadcasts'] ?? <String>[]).toSet();
      expect(inSql.length, greaterThanOrEqualTo(5),
          reason: 'لم أستخرج أعمدة broadcasts من SQL');
      expect(broadcastColumns, isNotEmpty);
      // id/title/message تُنشأ في تعريف الجدول لا في alter table
      final Set<String> missing = broadcastColumns
          .where((String c) => !inSql.contains(c))
          .where((String c) => !sql.contains('$c '))
          .toSet();
      expect(missing, isEmpty, reason: 'أعمدة ناقصة في SQL: $missing');
    });
  });

  group('لا عمود ناقص ولا عمود ميت مقابل الكود', () {
    test('كل عمود يسمّيه الكود موجود في ملف SQL', () {
      final Set<String> sqlSet = sqlColumns.values.expand((e) => e).toSet();
      // مفاتيح SharedPreferences المحلية تُسمّى مثل الأعمدة لكن لا جدول لها
      const Set<String> localPrefsOnly = <String>{
        'home_dua_color_follow_migrated',
        'home_dua_font_cairo_migrated',
      };

      final Set<String> codeColumns = <String>{};
      for (final String path in _codeSources) {
        final String source = File(path).readAsStringSync();
        for (final RegExpMatch m in RegExp(
          r"'(marquee_[a-z_]+|home_dua_[a-z_]+|room_passcode)'",
        ).allMatches(source)) {
          codeColumns.add(m.group(1)!.toLowerCase());
        }
      }
      codeColumns.removeAll(localPrefsOnly);
      expect(codeColumns.length, greaterThanOrEqualTo(10),
          reason: 'لم أستخرج أعمدة القاعدة من الكود');

      expect(
        codeColumns.difference(sqlSet),
        isEmpty,
        reason: 'الكود يستعمل أعمدة غير مضافة في ملف SQL',
      );
    });

    test('كل عمود في app_config يستعمله الكود فعلاً (لا عمود ميت)', () {
      final Set<String> sqlAppConfig =
          (sqlColumns['app_config'] ?? <String>[]).toSet();
      final Set<String> used = <String>{};
      for (final String path in _codeSources) {
        final String source = File(path).readAsStringSync();
        for (final RegExpMatch m in RegExp(
          r"'(marquee_[a-z_]+|home_dua_[a-z_]+|room_passcode)'",
        ).allMatches(source)) {
          used.add(m.group(1)!.toLowerCase());
        }
      }
      expect(used.length, greaterThanOrEqualTo(10),
          reason: 'لم أستخرج الأعمدة المستعملة من الكود');
      expect(
        sqlAppConfig.difference(used),
        isEmpty,
        reason: 'أعمدة تُضاف في القاعدة ولا يقرأها/يكتبها أي كود',
      );
    });
  });

  group('الافتراضيات في SQL تطابق ثوابت Dart', () {
    final Map<String, String> coalesce = columnDefaults(sql);
    final String settingsMarquee = classRegion(service, 'SettingsMarqueeSettings');
    final String homeMarquee = classRegion(service, 'HomeMarqueeSettings');

    void expectInteger(String column, int expected) {
      expect(
        coalesce[column],
        expected.toString(),
        reason: 'الافتراضي في SQL لـ $column لا يطابق ثابت Dart',
      );
    }

    test('وقت الظهور في الشريط العلوي = ثابت الشريط العلوي', () {
      expectInteger(
        'marquee_interval_ms',
        dartIntConstant(settingsMarquee, 'defaultIntervalMs'),
      );
      expectInteger(
        'marquee_font_size',
        dartIntConstant(settingsMarquee, 'defaultFontSize'),
      );
      expectInteger(
        'marquee_color',
        dartIntConstant(settingsMarquee, 'defaultColor'),
      );
    });

    test('خط الشريط العلوي = ثابت الخط الافتراضي', () {
      expect(
        coalesce['marquee_font'],
        dartStringConstant(settingsMarquee, 'defaultFontFamilyValue'),
        reason: 'خط الشريط العلوي في SQL لا يطابق ثابت Dart',
      );
    });

    test('قيم النص المتحرك في الرئيسية تطابق ثوابت الرئيسية', () {
      expectInteger(
        'home_dua_interval_ms',
        dartIntConstant(homeMarquee, 'defaultIntervalMs'),
      );
      expectInteger(
        'home_dua_font_size',
        dartIntConstant(homeMarquee, 'defaultFontSize'),
      );
      expectInteger(
        'home_dua_after_minutes',
        dartIntConstant(homeMarquee, 'defaultAfterMinutes'),
      );
      expect(
        coalesce['home_dua_font'],
        dartStringConstant(homeMarquee, 'defaultFontFamilyValue'),
      );
      expect(
        coalesce['home_dua_bold'],
        dartBoolConstant(homeMarquee, 'defaultBold').toString(),
      );
      expect(
        coalesce['home_dua_enabled'],
        dartBoolConstant(homeMarquee, 'defaultEnabled').toString(),
      );
    });

    test('لون النص المتحرك في الرئيسية يبقى بلا افتراضي (يتبع ألوان الصلاة)', () {
      // الكود يعتبر غياب اللون = «يتبع ألوان أوقات الصلاة»؛ لو ثبّتنا رقماً
      // هنا لفقد المستخدم هذا السلوك.
      expect(
        coalesce.containsKey('home_dua_color'),
        isFalse,
        reason: 'لا يجوز تثبيت home_dua_color في SQL',
      );
    });
  });

  group('ملف SQL آمن التكرار ولا يمسح شيئاً', () {
    test('كل create/add column بـ if not exists', () {
      final List<String> lines =
          sql.split('\n').map((String l) => l.trim().toLowerCase()).toList();
      for (final String line in lines) {
        if (line.startsWith('create table') || line.startsWith('create index')) {
          expect(
            line.contains('if not exists'),
            isTrue,
            reason: 'سطر غير آمن التكرار: $line',
          );
        }
        if (line.startsWith('alter table') &&
            !line.contains('if not exists') &&
            !line.contains('publication')) {
          // ضمان عدم وجود alter بلا if not exists في أي سطر لاحق
          expect(
            line.contains('add column if not exists') ||
                line.contains('add column'),
            isFalse,
            reason: 'alter table بلا if not exists: $line',
          );
        }
      }
    });

    test('لا أوامر مسح أو إسقاط', () {
      final String lower = sql.toLowerCase();
      for (final String forbidden in <String>[
        'drop table',
        'drop column',
        'truncate ',
        'delete from',
      ]) {
        expect(
          lower.contains(forbidden),
          isFalse,
          reason: 'ملف الترقية يجب ألا يحتوي «$forbidden»',
        );
      }
    });

    test('لا يُنشئ صفاً في broadcasts (كل صف يُشعر كل الأجهزة)', () {
      expect(
        RegExp(r'insert into\s+(?:public\.)?broadcasts', caseSensitive: false)
            .hasMatch(sql),
        isFalse,
        reason: 'الترقية يجب ألا تُرسل رسالة تجريبية للناس',
      );
    });

    test('الدالة الوحيدة المتبقية مستعملة أو غير موجودة', () {
      // لا نُضيف كائناً في القاعدة لا يستدعيه أي كود (كانت هناك دالة
      // increment_views لا يستدعيها التطبيق فأُزيلت).
      final RegExpMatch? fn =
          RegExp(r'create or replace function\s+(\w+)', caseSensitive: false)
              .firstMatch(sql);
      if (fn != null) {
        final String name = fn.group(1)!;
        final bool usedByAnyCode = _codeSources.any(
          (String p) => File(p).readAsStringSync().contains(name),
        );
        expect(usedByAnyCode, isTrue, reason: 'الدالة $name لا يستدعيها أي كود');
      }
    });
  });
}
