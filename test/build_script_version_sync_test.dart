import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// حارس «مصدر واحد» للإصدار: سكربت البناء `Build_Master_Pro.bat` يقرأ
/// `version: x.y.z+n` من `pubspec.yaml` ثم يكتبه في ثوابت `AppVersion`
/// (ملف Dart) قبل كل بناء، فلا يتباعد الرقمان أبداً.
///
/// الحالات المُغطّاة:
///   1. الدالة `:sync_app_version` موجودة ومُنادَى عليها بعد `bump` وقبل أول
///      خطوة بناء، فلو حُذف النداء عاد التباعد صامتاً.
///   2. القيم تُمرَّر من `pubspec.yaml` (`%VER%` / `%BUILDNO%`) لا مكتوبة في
///      السكربت، وإلا كتب الملف رقماً ثابتاً لا يتبعه.
///   3. أنماط PowerShell المستخدمة تُطبَّق فعلياً على ملف `app_version.dart`
///      الحقيقي: تُطابق مرة واحدة لكل ثابت، وتُنتج إصداراً مطابقاً لـ
///      `pubspec.yaml`، **ولا تغيّر بايتاً واحداً في سطر آخر** ولا مبتلعاً
///      لنهاية السطر (CRLF و LF سواء).
///   4. الملف يبقى UTF-8 بلا BOM.
void main() {
  late String script;
  late String dartSource;
  late RegExp versionRe;
  late RegExp buildRe;

  /// يقرأ نمطاً من السكربت: PowerShell يحمله داخل علامتَي اقتباس مفردتين،
  /// والنمط نفسه لا يحمل اقتباساً مفرداً لأنه يكتب الفاصلة العليا `\x27`.
  String patternOf(String variable) {
    final RegExpMatch? m =
        RegExp("\\\$$variable='([^']*)'").firstMatch(script);
    if (m == null) {
      throw StateError('النمط \$$variable غير موجود في Build_Master_Pro.bat');
    }
    return m.group(1)!;
  }

  /// Dart لا يفهم `(?m)` داخل النمط كما يفعل .NET، فتُنقل إلى مُعامل.
  RegExp compile(String pattern) {
    final bool multiLine = pattern.startsWith('(?m)');
    return RegExp(
      multiLine ? pattern.substring(4) : pattern,
      multiLine: multiLine,
    );
  }

  String apply(String text, RegExp re, String value) =>
      text.replaceAllMapped(re, (Match m) => '${m[1]}$value${m[2]}');

  setUpAll(() {
    script = File('Build_Master_Pro.bat').readAsStringSync();
    dartSource = File('lib/core/config/app_version.dart').readAsStringSync();
    versionRe = compile(patternOf('mv'));
    buildRe = compile(patternOf('mb'));
  });

  String pubspecVersion() {
    final RegExpMatch? m = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(m, isNotNull, reason: 'pubspec.yaml يجب أن يحمل سطر version');
    return m!.group(1)!;
  }

  int pubspecBuild() {
    final RegExpMatch? m = RegExp(
      r'^version:\s*[0-9]+\.[0-9]+\.[0-9]+(?:\+([0-9]+))?',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync());
    return int.parse(m!.group(1) ?? '1');
  }

  // ── 1) الدالة والنداء ────────────────────────────────────────────────────
  test('السكربت يعرّف دالة مزامنة AppVersion', () {
    expect(script, contains(':sync_app_version'));
    expect(
      script,
      contains('call :sync_app_version'),
      reason: 'دالة مزامنة معرّفة لكن لا أحد يناديها — الرقمان سيتباعدان',
    );
  });

  test('المزامنة تُنادى بعد bump وقبل أول خطوة بناء', () {
    final int sync = script.indexOf('call :sync_app_version');
    final int bump = script.indexOf('call :bump_build');
    final int firstBuild = script.indexOf('[1/8]');

    expect(bump, greaterThan(-1));
    expect(firstBuild, greaterThan(-1));
    expect(sync, greaterThan(bump), reason: 'المزامنة قبل الزيادة تكتب رقماً قديماً');
    expect(
      sync,
      lessThan(firstBuild),
      reason: 'المزامنة بعد البناء تجعل الـAPK يحمل رقماً قديماً',
    );
  });

  test('المزامنة تفشل بصوت عالٍ لا بصمت', () {
    // فشل الدالة يوقف البناء بدل أن يُبنى بإصدار متباعد بلا علم أحد.
    expect(script, contains('Failed to sync the AppVersion constants'));
    expect(script, contains('The AppVersion.version constant was not found'));
    expect(script, contains('The AppVersion.buildNumber constant was not found'));
  });

  test('القيم تُمرَّر من pubspec.yaml لا مكتوبة في السكربت', () {
    expect(script, contains(r"$ver='%VER%'"));
    expect(script, contains(r"$bno='%BUILDNO%'"));
  });

  // ── 2) الأنماط على الملف الحقيقي ─────────────────────────────────────────
  group('أنماط السكربت على app_version.dart الحقيقي', () {
    test('كل نمط يطابق الثابت مرة واحدة بالضبط', () {
      expect(
        versionRe.allMatches(dartSource).length,
        1,
        reason: 'نمط الإصدار لم يعد يطابق ثابت version في app_version.dart',
      );
      expect(
        buildRe.allMatches(dartSource).length,
        1,
        reason: 'نمط البناء لم يعد يطابق ثابت buildNumber في app_version.dart',
      );
    });

    test('التطبيق على الملف يعطي إصدار pubspec.yaml نفسه', () {
      final String out = apply(
        apply(dartSource, versionRe, pubspecVersion()),
        buildRe,
        '${pubspecBuild()}',
      );

      expect(out, contains("static const String version = '${pubspecVersion()}';"));
      expect(out, contains('static const int buildNumber = ${pubspecBuild()};'));
    });

    test('لا يمسّ سطراً آخر: كل الأسطر غير الثابتين تبقى كما هي', () {
      final List<String> before = dartSource.split('\n');
      final List<String> after = apply(
        apply(dartSource, versionRe, '9.9.9'),
        buildRe,
        '99',
      ).split('\n');

      expect(after.length, before.length, reason: 'عدد الأسطر تغيّر — سطر التُقم أو التُحم');
      for (int i = 0; i < before.length; i++) {
        final bool isConstant =
            before[i].contains('static const String version = ') ||
            before[i].contains('static const int buildNumber = ');
        if (!isConstant) {
          expect(after[i], before[i], reason: 'السطر $i تغيّر وهو ليس ثابتاً');
        }
      }
      expect(
        after.join('\n'),
        isNot(contains("static const String version = '3.4")),
        reason: 'الإصدار لم يُستبدل فعلاً',
      );
    });

    test('لا يبتلع نهاية السطر: CRLF تبقى CRLF و LF تبقى LF', () {
      // عطل حقيقي سابق: نمط بـ`\s*$` كان يمحو نهاية السطر فيلحم السطر التالي.
      final String lf = dartSource.contains('\r\n')
          ? dartSource.replaceAll('\r\n', '\n')
          : dartSource;
      final String crlf = lf.replaceAll('\n', '\r\n');

      final Map<String, String> samples = <String, String>{
        'LF': lf,
        'CRLF': crlf,
      };
      for (final MapEntry<String, String> entry in samples.entries) {
        final String sample = entry.value;
        final String out = apply(apply(sample, versionRe, '9.9.9'), buildRe, '99');
        expect(
          out.split('\n').length,
          sample.split('\n').length,
          reason: '${entry.key}: عدد الأسطر تغيّر',
        );
        if (entry.key == 'CRLF') {
          expect(
            '\r\n'.allMatches(out).length,
            '\r\n'.allMatches(sample).length,
            reason: '${entry.key}: عدد نهايات CRLF تغيّر',
          );
          expect(
            out.replaceAll('\r\n', '').contains('\n'),
            isFalse,
            reason: '${entry.key}: ظهر سطر بنهاية LF داخل ملف CRLF',
          );
        } else {
          expect(out.contains('\r'), isFalse, reason: '${entry.key}: ظهر CR في ملف LF');
        }
      }
    });

    test('الثابتان في مكان يُحدَّث آلياً: بلا BOM وبلا قيم مشتقّة مكتوبة', () {
      expect(dartSource.startsWith('\uFEFF'), isFalse, reason: 'الملف صار UTF-8 بـBOM');
      expect(dartSource, startsWith('///'));
      // `full` و`display` مشتقّان من الثابتين، فلا يحتاج السكربت كتابتهما.
      expect(dartSource, contains('static const String full'));
      expect(dartSource, contains('static const String display'));
    });
  });
}
