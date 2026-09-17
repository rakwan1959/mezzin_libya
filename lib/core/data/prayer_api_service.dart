import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// خدمة جلب أوقات الصلاة من API خارجية
/// تستخدم واجهة Aladhan.com التي تدعم المدن الليبية وطرق الحساب المتعددة
class PrayerApiService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.aladhan.com/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// أرقام طرق الحساب في Aladhan API
  /// ملاحظة: طريقة ليبيا تستخدم method=99 مع methodSettings للزوايا المخصصة
  /// لكل مدينة (بنغازي 18.4/18.2، طرابلس 17.9/18.1، ...) — مطابقة لتقويم المصلي
  static const Map<String, int> methodCodes = {
    'ليبيا (الأوقاف) — زوايا حسب المدينة': 99,
    'رابطة العالم الإسلامي': 3,
    'أم القرى (مكة)': 4,
    'الهيئة المصرية': 5,
    'الاتحاد الإسلامي (ISNA)': 2,
    'قطر': 8,
    'الكويت': 9,
    'دبي': 10,
    'فلسطين': 11,
    'تركيا (ديانة)': 13,
  };

  /// الزوايا المخصصة لطريقة ليبيا (method 99) تُبنى ديناميكياً حسب المدينة:
  /// (بنغازي 18.4°/18.2°، طرابلس 17.9°/18.1°، مصراتة 18.0°/18.1°،
  ///  درنة 17.9°/18.1°، سبها 17.9°/17.0°، والباقي كراتشي 18°/18°)
  static String libyaMethodSettings(double fajrAngle, double ishaAngle) =>
      '${fajrAngle.toStringAsFixed(1)},null,${ishaAngle.toStringAsFixed(1)}';

  /// جلب أوقات الصلاة من Aladhan.com API
  /// [latitude] - خط العرض
  /// [longitude] - خط الطول
  /// [method] - طريقة الحساب (رقم) - الافتراضي 99 (ليبيا: زوايا مخصصة)
  /// [fajrAngle]/[ishaAngle] - زاويتا الفجر والعشاء (تُستخدمان مع method=99 حسب المدينة)
  /// [madhab] - المذهب (0 = شافعي/مالكي/حنبلي, 1 = حنفي)
  static Future<Map<String, DateTime>?> fetchPrayerTimes({
    required double latitude,
    required double longitude,
    int method = 99, // ليبيا - زوايا مخصصة حسب المدينة
    double? fajrAngle,
    double? ishaAngle,
    int madhab = 0,
  }) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.day.toString().padLeft(2, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.year}';

      final response = await _dio.get(
        '/timings/$dateStr',
        queryParameters: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'method': method.toString(),
          if (method == 99)
            'methodSettings': libyaMethodSettings(fajrAngle ?? 18.0, ishaAngle ?? 18.0),
          'school': madhab.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final timings = data['data']['timings'] as Map<String, dynamic>;

        return {
          'الفجر': _parseTime(timings['Fajr'] as String, today),
          'الشروق': _parseTime(timings['Sunrise'] as String, today),
          'الظهر': _parseTime(timings['Dhuhr'] as String, today),
          'العصر': _parseTime(timings['Asr'] as String, today),
          'المغرب': _parseTime(timings['Maghrib'] as String, today),
          'العشاء': _parseTime(timings['Isha'] as String, today),
        };
      }
      return null;
    } catch (e) {
      debugPrint('PrayerApiService Error: $e');
      return null;
    }
  }

  /// جلب أوقات الصلاة لشهر كامل من Aladhan.com API
  static Future<List<Map<String, DateTime>>?> fetchMonthCalendar({
    required double latitude,
    required double longitude,
    required int year,
    required int month,
    int method = 99,
    double? fajrAngle,
    double? ishaAngle,
    int madhab = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/calendar',
        queryParameters: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'method': method.toString(),
          if (method == 99)
            'methodSettings': libyaMethodSettings(fajrAngle ?? 18.0, ishaAngle ?? 18.0),
          'school': madhab.toString(),
          'year': year.toString(),
          'month': month.toString(),
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        return data.map((dayData) {
          final timings = dayData['timings'] as Map<String, dynamic>;
          final dateInfo = dayData['date']['gregorian'];
          final date = DateTime(
            int.parse(dateInfo['year']),
            int.parse(dateInfo['month']['number']),
            int.parse(dateInfo['day']),
          );
          
          return {
            'الفجر': _parseTime(timings['Fajr'] as String, date),
            'الشروق': _parseTime(timings['Sunrise'] as String, date),
            'الظهر': _parseTime(timings['Dhuhr'] as String, date),
            'العصر': _parseTime(timings['Asr'] as String, date),
            'المغرب': _parseTime(timings['Maghrib'] as String, date),
            'العشاء': _parseTime(timings['Isha'] as String, date),
          };
        }).toList();
      }
      return null;
    } catch (e) {
      debugPrint('PrayerApiService Calendar Error: $e');
      return null;
    }
  }

  /// اختبار الاتصال بالـ API
  static Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/methods');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('PrayerApiService Connection Test Failed: $e');
      return false;
    }
  }

  /// تحويل نص الوقت من API (مثل "05:23" أو "05:23:45") إلى DateTime
  static DateTime _parseTime(String timeStr, DateTime date) {
    final cleanTime = timeStr.split(' ')[0]; // إزالة التوقيت الزمني إن وجد مثل (EET)
    final parts = cleanTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final second = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
    return DateTime(date.year, date.month, date.day, hour, minute, second);
  }

  /// الحصول على قائمة طرق الحساب المتاحة مع وصفها
  static List<Map<String, dynamic>> getAvailableMethods() {
    return [
      {'code': 99, 'name': 'ليبيا (الأوقاف) — زوايا حسب المدينة', 'desc': 'زوايا مخصصة لكل مدينة (بنغازي 18.4°/18.2°، طرابلس 17.9°/18.1°...) – مطابقة لتقويم المصلي'},
      {'code': 3, 'name': 'رابطة العالم الإسلامي', 'desc': 'زاوية فجر 18° وزاوية عشاء 17°'},
      {'code': 4, 'name': 'أم القرى (مكة المكرمة)', 'desc': 'زاوية فجر 18.5° والعشاء بعد 90 دقيقة'},
      {'code': 1, 'name': 'جامعة العلوم الإسلامية (كراتشي)', 'desc': 'زاوية فجر 18° وزاوية عشاء 18°'},
      {'code': 2, 'name': 'الاتحاد الإسلامي بأمريكا الشمالية (ISNA)', 'desc': 'زاوية فجر 15° وزاوية عشاء 15°'},
      {'code': 8, 'name': 'قطر', 'desc': 'زاوية فجر 18°'},
      {'code': 9, 'name': 'الكويت', 'desc': 'زاوية فجر 18° وزاوية عشاء 17.5°'},
      {'code': 10, 'name': 'دبي', 'desc': 'زاوية فجر 18.2° وزاوية عشاء 18.2°'},
    ];
  }
}

