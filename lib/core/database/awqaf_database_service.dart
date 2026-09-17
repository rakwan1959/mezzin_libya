import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

/// خدمة قاعدة بيانات الأوقاف الليبية المسبقة الحساب
/// تعمل 100% أوفلاين بدون أي اعتماد على خدمات سحابية
///
/// الأولوية في التحميل:
///    1. ملف محلي محفوظ مسبقاً (أسرع)
///    2. ملف JSON المدمج في التطبيق (يعمل مدى الحياة)
///    3. تحميل من رابط عام اختياري (GitHub Releases مثلاً)
///    4. حساب فلكي كخيار احتياطي نهائي
class AwqafDatabaseService {
  static AwqafDatabaseService? _instance;
  static AwqafDatabaseService get instance => _instance ??= AwqafDatabaseService._();

  AwqafDatabaseService._();

  Map<String, dynamic>? _database;
  int? _loadedYear;
  Directory? _cacheDir;

  /// ═══════════════════════════════════════════════════════════════
  /// رابط تحميل قاعدة البيانات الجديد (اختياري)
  /// يمكنك تغييره لأي رابط عام: GitHub Releases, موقع خاص, إلخ
  /// مثال: https://github.com/user/repo/releases/download/v2027/awqaf_database_2027.json
  /// ═══════════════════════════════════════════════════════════════
  static String? updateUrl;

  /// تحميل قاعدة البيانات
  Future<void> loadDatabase({int? year}) async {
    final targetYear = year ?? DateTime.now().year;
    if (_database != null && _loadedYear == targetYear) return;

    // 1. تحميل من ملف JSON المدمج في التطبيق أولاً (الأحدث والمحدث دائماً مع كل إصدار ✅)
    if (await _loadFromBundle(targetYear)) return;

    // 2. تحميل من التخزين المحلي (في حال كانت سنة مستقبلية تم تحميلها)
    if (await _loadFromLocalStorage(targetYear)) return;

    // 3. محاولة تحميل من رابط عام (اختياري)
    if (updateUrl != null) {
      await _downloadFromUrl(targetYear);
    }
  }

  /// تحديث تلقائي — يُستدعى عند بدء التشغيل
  Future<void> autoUpdateCheck() async {
    final currentYear = DateTime.now().year;
    if (_loadedYear == currentYear && _database != null) return;
    await loadDatabase(year: currentYear);
    if (_database != null) {
      await _cleanupOldDatabases(currentYear);
    }
  }

  /// ─── التحميل من التخزين المحلي ───
  Future<bool> _loadFromLocalStorage(int year) async {
    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/awqaf_database_$year.json');
      if (await file.exists()) {
        final jsonString = await file.readAsString(encoding: utf8);
        _database = json.decode(jsonString) as Map<String, dynamic>;
        _loadedYear = year;
        debugPrint('AwqafDatabase: ✅ تم تحميل قاعدة بيانات $year من التخزين المحلي');
        return true;
      }
    } catch (e) {
      debugPrint('AwqafDatabase: ⚠️ خطأ في التخزين المحلي: $e');
    }
    return false;
  }

  /// ─── التحميل من ملف JSON المدمج في assets (يعمل مدى الحياة) ───
  Future<bool> _loadFromBundle(int year) async {
    try {
      final jsonString = await rootBundle.loadString('assets/awqaf_database_$year.json');
      _database = json.decode(jsonString) as Map<String, dynamic>;
      _loadedYear = year;

      // نسخ محلياً لتسريع التحميل القادم
      await _saveToLocalStorage(year, jsonString);

      debugPrint('AwqafDatabase: ✅ تم تحميل قاعدة بيانات $year من ملف التطبيق');
      return true;
    } catch (e) {
      debugPrint('AwqafDatabase: ⚠️ لا يوجد ملف مدمج للسنة $year');
    }
    return false;
  }

  /// ─── التحميل من رابط عام (GitHub Releases مثلاً) ───
  Future<void> _downloadFromUrl(int year) async {
    try {
      final url = '$updateUrl/awqaf_database_$year.json';
      debugPrint('AwqafDatabase: 🔄 جاري تحميل قاعدة بيانات $year من: $url');

      final dio = Dio();
      final response = await dio.get(
        url,
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );

      if (response.statusCode == 200) {
        final jsonString = response.data is String
            ? response.data as String
            : utf8.decode(response.data as List<int>);

        _database = json.decode(jsonString) as Map<String, dynamic>;
        _loadedYear = year;

        // حفظ محلياً
        await _saveToLocalStorage(year, jsonString);

        debugPrint('AwqafDatabase: ✅ تم تحميل قاعدة بيانات $year من الإنترنت وحفظها محلياً');
      }
    } catch (e) {
      debugPrint('AwqafDatabase: ⚠️ فشل التحميل من الإنترنت: $e');
    }
  }

  /// حفظ ملف JSON في التخزين المحلي
  Future<void> _saveToLocalStorage(int year, String jsonString) async {
    try {
      final dir = await _getCacheDir();
      final file = File('${dir.path}/awqaf_database_$year.json');
      await file.writeAsString(jsonString, encoding: utf8);
      debugPrint('AwqafDatabase: 💾 تم حفظ قاعدة بيانات $year محلياً');
    } catch (e) {
      debugPrint('AwqafDatabase: ⚠️ فشل الحفظ المحلي: $e');
    }
  }

  /// حذف ملفات قاعدة البيانات القديمة
  Future<void> _cleanupOldDatabases(int currentYear) async {
    try {
      final dir = await _getCacheDir();
      final files = dir.listSync().whereType<File>();
      for (final file in files) {
        final name = file.path.split(Platform.pathSeparator).last;
        if (name.startsWith('awqaf_database_') && name.endsWith('.json')) {
          final yearStr = name.replaceAll('awqaf_database_', '').replaceAll('.json', '');
          final fileYear = int.tryParse(yearStr);
          if (fileYear != null && fileYear < currentYear) {
            await file.delete();
            debugPrint('AwqafDatabase: 🗑️ تم حذف قاعدة بيانات $fileYear القديمة');
          }
        }
      }
    } catch (e) {
      debugPrint('AwqafDatabase: ⚠️ خطأ في تنظيف الملفات القديمة: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// واجهات الاستعلام
  /// ═══════════════════════════════════════════════════════════════

  bool isAvailable({int? year}) {
    final targetYear = year ?? DateTime.now().year;
    return _loadedYear == targetYear && _database != null;
  }

  Map<String, String>? getPrayerTimesRaw({
    required String city,
    required int year,
    required int month,
    required int day,
  }) {
    if (_database == null) return null;

    try {
      final cities = _database!['cities'] as Map<String, dynamic>?;
      if (cities == null) return null;

      final cleanCity = city.trim();
      Map<String, dynamic>? cityData = cities[cleanCity] as Map<String, dynamic>?;

      if (cityData == null) {
        // البحث بالاسم المقارب/المعدل في حال اختلاف الهمزات والياء/الألف المقصورة
        final normalizedTarget = _normalizeName(cleanCity);
        for (final entry in cities.entries) {
          if (_normalizeName(entry.key) == normalizedTarget) {
            cityData = entry.value as Map<String, dynamic>?;
            break;
          }
        }
      }

      if (cityData == null) return null;

      final monthData = cityData[month.toString()] as Map<String, dynamic>?;
      if (monthData == null) return null;

      final dayData = monthData[day.toString()] as Map<String, dynamic>?;
      if (dayData == null) return null;

      return {
        'fajr': dayData['fajr'] as String,
        'sunrise': dayData['sunrise'] as String,
        'dhuhr': dayData['dhuhr'] as String,
        'asr': dayData['asr'] as String,
        'maghrib': dayData['maghrib'] as String,
        'isha': dayData['isha'] as String,
      };
    } catch (e) {
      debugPrint('AwqafDatabase: خطأ في جلب البيانات: $e');
      return null;
    }
  }

  Map<String, DateTime>? getPrayerTimes({
    required String city,
    required DateTime date,
  }) {
    final raw = getPrayerTimesRaw(
      city: city,
      year: date.year,
      month: date.month,
      day: date.day,
    );

    if (raw == null) return null;

    return {
      'الفجر': _parseTimeString(raw['fajr']!, date),
      'الشروق': _parseTimeString(raw['sunrise']!, date),
      'الظهر': _parseTimeString(raw['dhuhr']!, date),
      'العصر': _parseTimeString(raw['asr']!, date),
      'المغرب': _parseTimeString(raw['maghrib']!, date),
      'العشاء': _parseTimeString(raw['isha']!, date),
    };
  }

  List<Map<String, dynamic>> getMonthSchedule({
    required String city,
    required int year,
    required int month,
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final schedule = <Map<String, dynamic>>[];

    for (int day = 1; day <= daysInMonth; day++) {
      final times = getPrayerTimes(
        city: city,
        date: DateTime(year, month, day),
      );
      schedule.add({'day': day, 'times': times});
    }

    return schedule;
  }

  DateTime _parseTimeString(String timeStr, DateTime date) {
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  List<String> getAvailableCities() {
    if (_database == null) return [];
    final cities = _database!['cities'] as Map<String, dynamic>?;
    return cities?.keys.toList() ?? [];
  }

  Map<String, dynamic>? getDatabaseInfo() {
    if (_database == null) return null;
    return {
      'name': _database!['database_name'],
      'version': _database!['version'],
      'year': _database!['year'],
      'cities_count': _database!['cities_count'],
      'calculation_method': _database!['calculation_method'],
    };
  }

  String _normalizeName(String name) {
    return name
        .trim()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(' ', '');
  }

  Future<Directory> _getCacheDir() async {
    _cacheDir ??= await getApplicationDocumentsDirectory();
    return _cacheDir!;
  }
}
