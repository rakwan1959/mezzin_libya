// tools/make_release_package.dart
//
// يجمع حزمة الإصدار كاملة في مجلد واحد على سطح المكتب:
//   1) ليس صورةُ الكود المصدري النظيف  (ZIP) — بلا كاش ولا بقايا بناء.
//   2) ملف APK الشامل (يعمل على الأجهزة القديمة والحديثة).
//   3) SHA256SUMS.txt للتحقّق من سلامة الملفين، وREADME_BUILD.md لطريقة البناء.
//
// التشغيل من جذر المشروع:
//   dart run tools/make_release_package.dart
//   dart run tools/make_release_package.dart --out "D:\Some Folder"
//
// لماذا كاتب ZIP خاص؟ لأن كل أدوات الضغط الجاهزة على ويندوز
// (Compress-Archive و tar.exe و jar) تكتب أسماء الملفات غير الإنجليزية بترميز
// OEM بلا علم UTF-8، فيتشوّه اسم خط «alfont_com_خط-القران-اميري.ttf» عند
// الاستخراج على جهاز بترميز مختلف ويفشل البناء. هذا الكاتب يخزّن الأسماء
// بترميز UTF-8 مع تفعيل علم UTF-8 (0x0800) فتصل سليمة على أي جهاز.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// ── ما يُضمَّن في النسخة النظيفة ────────────────────────────────────────────
const List<String> _includeDirs = <String>[
  'lib',
  'assets',
  'android',
  'ios',
  'web',
  'test',
  'tools',
  'database',
  'plugins',
  'gemini_proxy',
];

const List<String> _includeFiles = <String>[
  'pubspec.yaml',
  'pubspec.lock',
  'analysis_options.yaml',
  '.gitignore',
  '.metadata',
  'README.md',
];

// ملاحظة: سكربتات الإصدار القديمة في جذر المشروع (clean_source_pro.bat و
// Make_Prayer_Times_Libya_Package.bat و build_ultimate_release.bat) لا
// تُضمَّن تلقائياً لأن الجذر يُنسخ بترخيص صريح (pubspec + README + القائمة
// أعلاه)، وتُستبدل بـ Build_APK.bat داخل الحزمة.

// مجلدات كاش/بناء لا معنى لها في نسخة نظيفة (يُطابق بالاسم في أي عمق).
const Set<String> _excludeDirNames = <String>{
  '.dart_tool',
  'build',
  '.gradle',
  '.kotlin',
  '.cxx',
  '.idea',
  '.git',
  'node_modules',
  'extracted_database',
};

// ملفات مؤقتة وبقايا تشغيل.
bool _isExcludedFile(String name) {
  if (name == '.flutter-plugins-dependencies') return true;
  if (name.startsWith('temp_')) return true;
  if (name.endsWith('.iml')) return true;
  if (name.endsWith('.apk')) return true;
  if (name.endsWith('.log')) return true;
  if (name.endsWith('.rar')) return true;
  if (name.endsWith('.tmp')) return true;
  final String lower = name.toLowerCase();
  return lower == 'thumbs.db' || lower == 'desktop.ini';
}

class _Version {
  const _Version(this.name, this.build);
  final String name;
  final int build;
  String get tag => 'v$name+$build';
}

void main(List<String> args) {
  final Directory root = Directory.current;
  final File pubspec = File('${root.path}${Platform.pathSeparator}pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('✗ شغّل السكربت من جذر المشروع (pubspec.yaml غير موجود هنا).');
    exit(1);
  }

  final _Version version = _readVersion(pubspec);
  final String? outArg = _argValue(args, '--out');
  final Directory outDir = Directory(
    outArg ?? _defaultOutputDir(),
  );
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  stdout.writeln('═' * 64);
  stdout.writeln('  حزمة الإصدار — ${version.tag}');
  stdout.writeln('  مجلد الإخراج: ${outDir.path}');
  stdout.writeln('═' * 64);

  // ── 1) APK الشامل ────────────────────────────────────────────────────
  final File apkSrc = File(
    '${root.path}${Platform.pathSeparator}build${Platform.pathSeparator}'
    'app${Platform.pathSeparator}outputs${Platform.pathSeparator}'
    'flutter-apk${Platform.pathSeparator}app-release.apk',
  );
  if (!apkSrc.existsSync()) {
    stderr.writeln('✗ لم أجد ملف APK المبنى:');
    stderr.writeln('  ${apkSrc.path}');
    stderr.writeln('  ابنِه أولاً:  flutter build apk --release '
        '--target-platform android-arm,android-arm64,android-x64');
    exit(1);
  }

  // ── 2) شجرة الكود المصدري النظيف ─────────────────────────────────────
  final Directory stage = Directory.systemTemp.createTempSync('ptl_source_');
  try {
    final List<String> skipped = <String>[];
    int files = 0;
    int bytes = 0;

    for (final String dir in _includeDirs) {
      final Directory src = Directory('${root.path}${Platform.pathSeparator}$dir');
      if (!src.existsSync()) continue;
      final _CopyStats s = _copyTree(src, Directory('${stage.path}${Platform.pathSeparator}$dir'));
      files += s.files;
      bytes += s.bytes;
      skipped.addAll(s.skipped);
    }
    for (final String name in _includeFiles) {
      final File src = File('${root.path}${Platform.pathSeparator}$name');
      if (!src.existsSync()) continue;
      src.copySync('${stage.path}${Platform.pathSeparator}$name');
      files++;
      bytes += src.lengthSync();
    }

    stdout.writeln('  • نسخ $files ملفاً (${_mb(bytes)}) إلى نسخة نظيفة مؤقتة.');

    // ملفات تعريف الحزمة داخل الـ ZIP
    File('${stage.path}${Platform.pathSeparator}README_BUILD.md')
        .writeAsStringSync(_buildGuide(version), flush: true);
    File('${stage.path}${Platform.pathSeparator}Build_APK.bat')
        .writeAsStringSync(_buildBat(), flush: true);
    File('${stage.path}${Platform.pathSeparator}VERSION.txt')
        .writeAsStringSync(_versionFile(version).replaceAll('\n', '\r\n'),
            flush: true);

    // ── 3) الضغط ────────────────────────────────────────────────────────
    final String stem = 'Prayer_Times_Libya_${version.name}'
        '_Build${version.build}';
    final String zipPath =
        '${outDir.path}${Platform.pathSeparator}${stem}_Clean_SourceCode.zip';
    final String apkPath =
        '${outDir.path}${Platform.pathSeparator}${stem}_Universal_AllDevices.apk';

    final File zipFile = File(zipPath);
    if (zipFile.existsSync()) zipFile.deleteSync();
    final Stopwatch sw = Stopwatch()..start();
    final _ZipWriter writer = _ZipWriter(zipFile.openSync(mode: FileMode.write), zipFile);
    // كل الملفات داخل مجلد جذر واحد، فلا تتناثر عند فكّ الضغط.
    final String zipRoot = 'Prayer_Times_Libya_${version.name}_Source';
    writer.addDirectory(zipRoot);
    _zipTree(stage, zipRoot, writer);
    writer.close();
    sw.stop();
    stdout.writeln('  • أُنشئ الـ ZIP (${_mb(zipFile.lengthSync())}) في '
        '${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)} ثانية.');

    // ── 4) APK + بصمات التحقّق ──────────────────────────────────────────
    final File apkOut = File(apkPath);
    if (apkOut.existsSync()) apkOut.deleteSync();
    apkSrc.copySync(apkPath);

    final String zipSha = _sha256(zipPath);
    final String apkSha = _sha256(apkPath);
    final String readmePath =
        '${outDir.path}${Platform.pathSeparator}README.txt';
    File(readmePath).writeAsStringSync(
      _releaseReadme(version, apkOut, zipFile, apkSha, zipSha)
          .replaceAll('\n', '\r\n'),
      flush: true,
    );
    File('${outDir.path}${Platform.pathSeparator}SHA256SUMS.txt').writeAsStringSync(
      '${apkSha.toLowerCase()}  ${_fileName(apkPath)}\n'
      '${zipSha.toLowerCase()}  ${_fileName(zipPath)}\n',
      flush: true,
    );

    stdout.writeln('═' * 64);
    stdout.writeln('  ✓ APK  : ${_fileName(apkPath)}  (${_mb(apkOut.lengthSync())})');
    stdout.writeln('  ✓ ZIP  : ${_fileName(zipPath)}  (${_mb(zipFile.lengthSync())})');
    stdout.writeln('  ✓ SHA256 APK: ${apkSha.toLowerCase()}');
    stdout.writeln('  ✓ SHA256 ZIP: ${zipSha.toLowerCase()}');
    stdout.writeln('  ✓ المجلد: ${outDir.path}');
    if (skipped.isNotEmpty) {
      final Set<String> uniq = skipped.toSet();
      stdout.writeln('  • استُثني ${uniq.length} مجلداً احتياطياً/كاش '
          '(مثال: ${uniq.take(3).join(', ')}).');
    }
    stdout.writeln('═' * 64);
  } finally {
    // لا نترك نسخة مؤقتة على القرص
    try {
      stage.deleteSync(recursive: true);
    } on FileSystemException {
      stdout.writeln('  ! لم أستطع حذف المجلد المؤقت: ${stage.path}');
    }
  }
}

// ── أدوات مساعدة ───────────────────────────────────────────────────────────

String _defaultOutputDir() {
  final String home = Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      Directory.current.path;
  return '$home${Platform.pathSeparator}Desktop'
      '${Platform.pathSeparator}Prayer Times Libya 2027 SEP';
}

String _fileName(String path) =>
    path.split(Platform.pathSeparator).last;

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

String? _argValue(List<String> args, String flag) {
  final int i = args.indexOf(flag);
  if (i == -1 || i + 1 >= args.length) return null;
  return args[i + 1];
}

_Version _readVersion(File pubspec) {
  final RegExp re = RegExp(
    r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?',
    multiLine: true,
  );
  final Match? m = re.firstMatch(pubspec.readAsStringSync());
  if (m == null) {
    stderr.writeln('✗ لا يوجد سطر إصدار (version: x.y.z+n) في pubspec.yaml');
    exit(1);
  }
  return _Version(m.group(1)!, int.tryParse(m.group(2) ?? '1') ?? 1);
}

class _CopyStats {
  _CopyStats(this.files, this.bytes, this.skipped);
  final int files;
  final int bytes;
  final List<String> skipped;
}

_CopyStats _copyTree(Directory src, Directory dst) {
  int files = 0;
  int bytes = 0;
  final List<String> skipped = <String>[];
  if (!dst.existsSync()) dst.createSync(recursive: true);

  for (final FileSystemEntity entity in src.listSync(followLinks: false)) {
    final String name = entity.uri.pathSegments.lastWhere((String s) => s.isNotEmpty);
    if (entity is Directory) {
      if (_excludeDirNames.contains(name)) {
        skipped.add(name);
        continue;
      }
      final _CopyStats sub = _copyTree(
        entity,
        Directory('${dst.path}${Platform.pathSeparator}$name'),
      );
      files += sub.files;
      bytes += sub.bytes;
      skipped.addAll(sub.skipped);
    } else if (entity is File) {
      if (_isExcludedFile(name)) continue;
      entity.copySync('${dst.path}${Platform.pathSeparator}$name');
      files++;
      bytes += entity.lengthSync();
    }
  }
  return _CopyStats(files, bytes, skipped);
}

void _zipTree(Directory src, String zipPrefix, _ZipWriter writer) {
  final List<FileSystemEntity> entries = src.listSync(followLinks: false);
  for (final FileSystemEntity entity in entries) {
    final String name =
        entity.uri.pathSegments.lastWhere((String s) => s.isNotEmpty);
    final String rel = '$zipPrefix/$name';
    if (entity is Directory) {
      writer.addDirectory(rel);
      _zipTree(entity, rel, writer);
    } else if (entity is File) {
      writer.addFile(rel, entity.readAsBytesSync(), entity.lastModifiedSync());
    }
  }
}

/// يحسب SHA-256 عبر certutil (ويندوز) ويرجع سلسلة فارغة إن تعذّر.
String _sha256(String path) {
  try {
    final ProcessResult r = Process.runSync('certutil', <String>['-hashfile', path, 'SHA256']);
    if (r.exitCode != 0) return '';
    for (final String line in const LineSplitter().convert(r.stdout.toString())) {
      final String t = line.trim();
      if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(t)) return t;
    }
  } on ProcessException {
    // certutil غير متاح — نتجاهل البصمة بهدوء.
  }
  return '';
}

// ── نصوص الملفات المرفقة داخل الحزمة ───────────────────────────────────────

String _versionFile(_Version v) => '''
تطبيق أوقات الصلاة — ليبيا
الإصدار: ${v.name}  (رقم البناء ${v.build})
البصمة الكاملة: ${v.tag}
رقم الحزمة: com.example.muezzin_libya_app
أقل إصدار أندرويد مدعوم: 7.0 (API 24)
إصدار الاستهداف: 30 (مقصود — لضبط بطاقة الإشعار المخصّصة)
المعماريات: arm32 + arm64 + x86_64
''';

/// ملف batch بنهايات أسطر CRLF — cmd لا يحب ملفات الـ batch بنهايات LF.
String _buildBat() => _buildBatLf.replaceAll('\n', '\r\n');

const String _buildBatLf = '''@echo off
chcp 65001 > nul
title بناء تطبيق أوقات الصلاة - ليبيا
echo ========================================================
echo    بناء تطبيق أوقات الصلاة - ليبيا
echo ========================================================
echo.
echo [1/2] تنزيل الحزم...
call flutter pub get
if errorlevel 1 (
    echo فشل تنزيل الحزم - تأكد من اتصال الإنترنت ومن تثبيت Flutter
    pause
    exit /b 1
)
echo [2/2] بناء APK شامل لكل الأجهزة القديمة والحديثة...
call flutter build apk --release --target-platform android-arm,android-arm64,android-x64
if errorlevel 1 (
    echo فشل البناء - راجع الرسائل أعلاه
    pause
    exit /b 1
)
echo.
echo تم البناء بنجاح. الملف الجاهز للتثبيت:
echo   build\\app\\outputs\\flutter-apk\\app-release.apk
echo.
explorer "build\\app\\outputs\\flutter-apk"
pause
''';

String _buildGuide(_Version v) => '''
# دليل البناء — ${v.tag}

## المتطلبات
- Flutter 3.41 أو أحدث (Dart 3.11) — `flutter --version`
- JDK 17 (المشروع يضبط مساره في `android/gradle.properties`)
- Android SDK بمنصة 36 و build-tools حديثة

## خطوات البناء (ضغطة واحدة)
انقر مرتين على `Build_APK.bat`، أو من الطرفية:

```
flutter pub get
flutter build apk --release --target-platform android-arm,android-arm64,android-x64
```

الناتج: `build/app/outputs/flutter-apk/app-release.apk`

للتقسيم حسب المعمارية (ملفات أصغر لكل جهاز):

```
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64,android-x64
```

## ملاحظات مهمة
1. **التوقيع**: `android/key.properties` و `android/app/muezzin-release.jks`
   مضمّنان كي يكون الـ APK المبنى **قابلاً للتحديث فوق النسخة المثبَّتة**.
   ⚠️ هذان الملفان سرّيان (يحتويان كلمة مرور مفتاح التوقيع).
   لا تشارك هذا الـ ZIP علناً.
   وإن أردت بناءً بلا توقيع الإصدار، احذف `android/key.properties`.
2. **الإصدار** يُقرأ من سطر `version:` في `pubspec.yaml`؛ ورقم البناء
   (`+${v.build}`) هو `versionCode` على أندرويد. ارفعه قبل كل نشر.
3. **`targetSdk = 30` مقصود**: أندرويد يفرض قالباً قياسياً على الإشعارات في
   API 31+، وهو ما يفسد بطاقة الإشعار المخصّصة لهذا التطبيق. لا تغيّره إلى
   35 إلا إذا أردت النشر على Google Play وقبلتَ تغيّر شكل الإشعار.
4. **أقل إصدار مدعوم 7.0 (API 24)**: هذه حدود إضافة الإشعارات المحلية
   (`plugins/flutter_local_notifications`)، وهي أيضاً أقدم إصدار يستفيد من
   واجهات الإشعارات المستخدمة.
5. **الكاش مستثنى**: لا `.dart_tool` ولا `build` ولا `.gradle` في هذه الحزمة،
   فأول بناء سيكون بارداً (أبطأ قليلاً) ثم يصبح تدريجياً.
''';

String _releaseReadme(
  _Version v,
  File apk,
  File zip,
  String apkSha,
  String zipSha,
) =>
    '''
تطبيق أوقات الصلاة — ليبيا
الإصدار ${v.name}  •  رقم البناء ${v.build}
جاهز في: ${DateTime.now().toString().substring(0, 16)}
════════════════════════════════════════════════════════════

①  ${_fileName(apk.path)}
     ${_mb(apk.lengthSync())} — APK شامل يعمل على الأجهزة القديمة والحديثة:
     • arm64-v8a  للأجهزة الحديثة (64-بت)
     • armeabi-v7a للأجهزة القديمة (32-بت)
     • x86_64     للمحاكيات
     • أقل إصدار مدعوم: أندرويد 7.0 (API 24)
     • موقّع بمفتاح الإصدار نفسه ⇒ يُحدَّث فوق النسخة المثبَّتة بلا حذف.
     التثبيت: انسخ الملف إلى الهاتف وافتحه، واسمح بـ«تثبيت من مصادر غير معروفة».

②  ${_fileName(zip.path)}
     ${_mb(zip.lengthSync())} — الكود المصدري النظيف الكامل:
     • بلا كاش ولا بقايا بناء: لا .dart_tool ولا build ولا .gradle ولا ملفات
       مؤقتة ولا قواعد بيانات مستخرجة ولا سكربتات قديمة.
     • أسماء الملفات بخِطاط UTF-8 كي لا يتشوّه اسم خط أميري العربي عند
       الاستخراج على أي جهاز.
     • بداخله README_BUILD.md (دليل البناء) و Build_APK.bat (بناء بضغطة).
     • يُفتح بـ 7-Zip أو WinRAR أو مستكشف الملفات، والمحتوى داخل مجلد واحد.

③  التحقّق من سلامة الملفين (SHA-256)
     APK: ${apkSha.toLowerCase()}
     ZIP: ${zipSha.toLowerCase()}
     تحقّق:  certutil -hashfile "${_fileName(apk.path)}" SHA256

④  بعد التثبيت
     • الإذن المطلوب: الموقع (للمواقيت)، والإشعارات، والمنبهات الدقيقة.
     • وافتح التطبيق مرة واحدة ليضبط المواقيت وإشعارات الأذان.
════════════════════════════════════════════════════════════
''';

// ── كاتب ZIP بترميز UTF-8 ─────────────────────────────────────────────────

class _Entry {
  _Entry(this.name, this.crc, this.comp, this.size, this.method, this.time,
      this.date, this.offset, this.isDir);
  final String name;
  final int crc;
  final int comp;
  final int size;
  final int method;
  final int time;
  final int date;
  final int offset;
  final bool isDir;
}

class _ZipWriter {
  _ZipWriter(this._raf, this._file);

  final RandomAccessFile _raf;
  final File _file;
  final List<_Entry> _entries = <_Entry>[];
  bool _closed = false;

  /// موضع الكتابة الفعلي في الملف — مصدر الحقيقة الوحيد للإزاحات، فلا يمكن
  /// أن تنحرف حساباتي اليدوية عن البايتات المكتوبة فعلاً.
  int get _position => _raf.positionSync();

  // علم UTF-8 (bit 11) — يجعل أدوات فك الضغط تقرأ الاسم بترميز UTF-8.
  static const int _flagUtf8 = 0x0800;
  static const int _methodStore = 0;
  static const int _methodDeflate = 8;

  void addDirectory(String path) {
    final String name = path.endsWith('/') ? path : '$path/';
    final List<int> nameBytes = utf8.encode(name);
    final int entryOffset = _position;
    _writeLocalHeader(
      nameBytes: nameBytes,
      method: _methodStore,
      crc: 0,
      comp: 0,
      size: 0,
      dosTime: 0,
      dosDate: 0x0021, // 1980-01-01
    );
    _raf.writeFromSync(nameBytes);
    _entries.add(_Entry(name, 0, 0, 0, _methodStore, 0, 0x0021,
        entryOffset, true));
  }

  void addFile(String path, List<int> data, DateTime modified) {
    final String name = path.replaceAll(r'\', '/');
    final List<int> nameBytes = utf8.encode(name);
    final int crc = _crc32(data);
    final List<int> deflated = ZLibEncoder(raw: true).convert(data);
    final bool useDeflate = deflated.length < data.length;
    final List<int> payload = useDeflate ? deflated : data;
    final int method = useDeflate ? _methodDeflate : _methodStore;
    final int dosTime = _dosTime(modified);
    final int dosDate = _dosDate(modified);

    final int entryOffset = _position;
    _writeLocalHeader(
      nameBytes: nameBytes,
      method: method,
      crc: crc,
      comp: payload.length,
      size: data.length,
      dosTime: dosTime,
      dosDate: dosDate,
    );
    _raf.writeFromSync(nameBytes);
    _raf.writeFromSync(payload);
    _entries.add(_Entry(name, crc, payload.length, data.length, method,
        dosTime, dosDate, entryOffset, false));
  }

  void _writeLocalHeader({
    required List<int> nameBytes,
    required int method,
    required int crc,
    required int comp,
    required int size,
    required int dosTime,
    required int dosDate,
  }) {
    final BytesBuilder b = BytesBuilder();
    b.add(_u32(0x04034b50)); // التوقيع
    b.add(_u16(20)); // نسخة الاستخراج المطلوبة (2.0)
    b.add(_u16(_flagUtf8)); // الأعلام: UTF-8
    b.add(_u16(method));
    b.add(_u16(dosTime));
    b.add(_u16(dosDate));
    b.add(_u32(crc));
    b.add(_u32(comp));
    b.add(_u32(size));
    b.add(_u16(nameBytes.length));
    b.add(_u16(0)); // طول الحقل الإضافي
    _raf.writeFromSync(b.toBytes());
  }

  void close() {
    if (_closed) return;
    _closed = true;
    final int cdStart = _position;
    final BytesBuilder b = BytesBuilder();
    for (final _Entry e in _entries) {
      final List<int> nameBytes = utf8.encode(e.name);
      b.add(_u32(0x02014b50)); // توقيع الفهرس المركزي
      b.add(_u16(0x0014)); // النسخة المُنتِجة (2.0 / MS-DOS)
      b.add(_u16(20));
      b.add(_u16(_flagUtf8));
      b.add(_u16(e.method));
      b.add(_u16(e.time));
      b.add(_u16(e.date));
      b.add(_u32(e.crc));
      b.add(_u32(e.comp));
      b.add(_u32(e.size));
      b.add(_u16(nameBytes.length));
      b.add(_u16(0)); // حقل إضافي
      b.add(_u16(0)); // تعليق
      b.add(_u16(0)); // رقم القرص
      b.add(_u16(0)); // الخصائص الداخلية
      b.add(_u32(e.isDir ? 0x10 : 0x20)); // خصائص MS-DOS
      b.add(_u32(e.offset));
      b.add(nameBytes);
    }
    final Uint8List cd = b.toBytes();
    _raf.writeFromSync(cd);

    final BytesBuilder end = BytesBuilder();
    end.add(_u32(0x06054b50)); // نهاية الفهرس المركزي
    end.add(_u16(0));
    end.add(_u16(0));
    end.add(_u16(_entries.length));
    end.add(_u16(_entries.length));
    end.add(_u32(cd.length));
    end.add(_u32(cdStart));
    end.add(_u16(0));
    _raf.writeFromSync(end.toBytes());
    _raf.flushSync();
    final int total = _position;
    _raf.closeSync();
    _selfCheck(total, cdStart, cd.length);
  }

  /// تحقّق ذاتي بعد الإغلاق: يقرأ سجل نهاية الفهرس من آخر 22 بايت ويتأكد أن
  /// الإزاحات والأحجام تطابق ما كُتب فعلاً، فلا تخرج حزمة معطوبة بصمت.
  void _selfCheck(int total, int cdStart, int cdSize) {
    final RandomAccessFile raf = _file.openSync();
    try {
      if (raf.lengthSync() != total) {
        throw StateError('حجم ملف الـ ZIP غير متوقع');
      }
      raf.setPositionSync(total - 22);
      final Uint8List tail = raf.readSync(22);
      final ByteData bd = tail.buffer.asByteData();
      if (bd.getUint32(0, Endian.little) != 0x06054b50) {
        throw StateError('سجل نهاية الفهرس مفقود');
      }
      final int entries = bd.getUint16(10, Endian.little);
      if (entries != _entries.length ||
          bd.getUint32(12, Endian.little) != cdSize ||
          bd.getUint32(16, Endian.little) != cdStart ||
          cdStart + cdSize != total - 22) {
        throw StateError('إزاحات الفهرس المركزي غير متسقة');
      }
    } finally {
      raf.closeSync();
    }
  }

  static Uint8List _u16(int v) =>
      Uint8List(2)..buffer.asByteData().setUint16(0, v & 0xFFFF, Endian.little);

  static Uint8List _u32(int v) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, v & 0xFFFFFFFF, Endian.little);

  static int _dosTime(DateTime d) =>
      (d.hour << 11) | (d.minute << 5) | (d.second ~/ 2);

  static int _dosDate(DateTime d) {
    final int year = d.year < 1980 ? 1980 : d.year;
    return ((year - 1980) << 9) | (d.month << 5) | d.day;
  }

  static final List<int> _crcTable = _buildCrcTable();

  static List<int> _buildCrcTable() {
    final List<int> table = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      int c = i;
      for (int k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
      }
      table[i] = c & 0xFFFFFFFF;
    }
    return table;
  }

  static int _crc32(List<int> data) {
    int c = 0xFFFFFFFF;
    for (int i = 0; i < data.length; i++) {
      c = _crcTable[(c ^ data[i]) & 0xFF] ^ (c >> 8);
    }
    return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
}
