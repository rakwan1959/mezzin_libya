import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// خدمة قاعدة بيانات "مؤذن ليبيا" الرسمية (122 مدينة ومنطقة ليبية)
/// تقرأ ملفات JSON المسبقة الحساب والمستخرجة من التطبيق الأصلي
/// مطابقة 100% لمواقيت وتوقيت مؤذن ليبيا الرسمي أوفلاين
class MuezzinLibyaDatabaseService {
  static MuezzinLibyaDatabaseService? _instance;
  static MuezzinLibyaDatabaseService get instance =>
      _instance ??= MuezzinLibyaDatabaseService._();

  MuezzinLibyaDatabaseService._();

  // ذاكرة تخزين مؤقت لملفات المدن المحملة
  final Map<String, List<dynamic>> _loadedCitiesCache = {};

  /// قاموس تحويل أسماء المدن بالعربية إلى أسماء ملفات JSON
  static const Map<String, String> cityToFileName = {
    'طرابلس': 'tripoli',
    'بنغازي': 'banghazi',
    'مصراتة': 'musratah',
    'الخمس': 'khomes',
    'الزاوية': 'zawia',
    'سبها': 'sabha',
    'أجدابيا': 'ejdabia',
    'اجدابيا': 'ejdabia',
    'سرت': 'siret',
    'البيضاء': 'baida',
    'زليتن': 'zleatin',
    'البريقة': 'braiga',
    'درنة': 'drna',
    'امساعد': 'emsaad',
    'إمساعد': 'emsaad',
    'غدامس': 'ghadames',
    'هون': 'hoon',
    'جالو': 'jalo',
    'رأس لانوف': 'lanoof',
    'راس لانوف': 'lanoof',
    'أوجلة': 'ojla',
    'اوجلة': 'ojla',
    'طبرق': 'topruq',
    'بني وليد': 'walead',
    'الكفرة': 'kofra',
    'المرج': 'marij',
    'الجغبوب': 'aljaghbub',
    'بن جواد': 'benjuwad',
    'شحات': 'shahat',
    'زوارة': 'zwara',
    'أوباري': 'ubari',
    'اوباري': 'ubari',
    'ترهونة': 'tarhona',
    'غريان': 'gherian',
    'غات': 'ghaat',
    'مرزق': 'morzuk',
    'نالوت': 'naloot',
    'زلطن': 'zultun',
    'قصر بن غشير': 'qasr',
    'القصر': 'qasr',
    'قصر الأخيار': 'gaser_lhiar',
    'قصر الاخيار': 'gaser_lhiar',
    'الرحيبات': 'rhaibat',
    'الرياينة': 'reyayna',
    'صبراتة': 'subratah',
    'تمسة': 'temesa',
    'مسلاتة': 'mesalatah',
    'الشويرف': 'shwayrif',
    'صرمان': 'surman',
    'أبو كماش': 'abokemmash',
    'الأصابعة': 'asabaa',
    'الاصابعة': 'asabaa',
    'الجميل': 'jomail',
    'رقدالين': 'reqdaleen',
    'الزنتان': 'zintan',
    'الشرقية': 'sharqeyah',
    'القرية الشرقية': 'qariat_shargea',
    'العجيلات': 'elajelat',
    'العزيزية': 'azizayah',
    'العسة': 'alessah',
    'الفقهاء': 'foqaha',
    'القره بوللي': 'qarabolle',
    'القره بولى': 'qarabolle',
    'القطرون': 'qatroun',
    'الهيشة': 'hesha',
    'بنت بيه': 'bentbeyah',
    'تازربو': 'tazerbo',
    'تراغن': 'trahgen',
    'جادو': 'jadou',
    'الأبرق': 'abraq',
    'الابرق': 'abraq',
    'عين غزالة': 'ainghazala',
    'القريات': 'alqaryat',
    'أولاد محمود': 'awladMahmoud',
    'بدر': 'badr',
    'حقل البيضاء': 'baidhafield',
    'حقل البوري': 'bore_field',
    'البوري': 'bori',
    'بئر الأشهب': 'beershahab',
    'براك الشاطئ': 'brakshatti',
    'درج': 'daraj',
    'ظاهر الجبل': 'dhaherjabal',
    'إدري الشاطئ': 'edrishatti',
    'اجخرة': 'ejkhara',
    'حقل الفيل': 'elfeel',
    'حقل الانتصار': 'entesar',
    'الحمادة': 'hamada',
    'حقل الحمادة': 'hamada_field',
    'الحرابة': 'harabah',
    'هراوة': 'harawa',
    'الحوامد': 'hawamid',
    'كاباو': 'kabaw',
    'ككلة': 'kikla',
    'مرادة': 'maradah',
    'مرسى دفنة': 'marsadefna',
    'مزدة': 'mezdah',
    'المشاشية': 'mshashia',
    'نسمة': 'nesmah',
    'قعرة': 'qaara',
    'القلعة': 'qalaa',
    'قصر الجدي': 'qaserjadi',
    'قمينس': 'qmenes',
    'قرضة الشاطئ': 'qordashatti',
    'القبة': 'qubba',
    'رأس اجدير': 'rasejdair',
    'الرجبان': 'rejban',
    'سلوق': 'salooq',
    'حقل السماح': 'samah',
    'السرير': 'sareer',
    'حقل السرير': 'sarir_field',
    'شكشوك': 'shakshouk',
    'حقل الشرارة': 'sharara',
    'الشقيقة': 'shqaiqa',
    'سوكنة': 'sokna',
    'سوسة': 'susah',
    'طبقة': 'tabaqah',
    'تمزين': 'tamzin',
    'تبستي': 'tebesti',
    'تيجي': 'tiji',
    'أم الرزم': 'umrezam',
    'العربان': 'urban',
    'وادي البوانيس': 'wadibawanees',
    'وادي عتبة': 'wadiutba',
    'وادي زمزم': 'wadizamzam',
    'حقل الوفاء': 'wafa',
    'حقل الواحة': 'waha',
    'وازن': 'wazin',
    'ودان': 'weddan',
    'الوشكة': 'wishka',
    'يفرن': 'yefren',
    'زلة': 'zallah',
  };

  /// البحث عن ملف المدينة
  String? getCityFileName(String cityName) {
    final clean = cityName.trim();
    if (cityToFileName.containsKey(clean)) {
      return cityToFileName[clean];
    }
    // البحث بالتقارب وتطبيع الهمزات
    final normalized = _normalize(clean);
    for (final entry in cityToFileName.entries) {
      if (_normalize(entry.key) == normalized) {
        return entry.value;
      }
    }
    return null;
  }

  /// تحميل ملف المدينة من الأصول
  Future<List<dynamic>?> _loadCityData(String fileName) async {
    if (_loadedCitiesCache.containsKey(fileName)) {
      return _loadedCitiesCache[fileName];
    }

    try {
      final path = 'assets/database/Libya/$fileName.json';
      final jsonStr = await rootBundle.loadString(path);
      String cleanStr = jsonStr.trim();
      if (cleanStr.endsWith(',]')) {
        cleanStr = '${cleanStr.substring(0, cleanStr.length - 2)}]';
      } else if (cleanStr.endsWith(',\n]') || cleanStr.endsWith(', \n]') || cleanStr.endsWith(',\r\n]')) {
        cleanStr = cleanStr.replaceAll(RegExp(r',\s*\]$'), ']');
      }
      final list = json.decode(cleanStr) as List<dynamic>;
      _loadedCitiesCache[fileName] = list;
      return list;
    } catch (e) {
      debugPrint('MuezzinLibyaDB Error loading $fileName: $e');
      return null;
    }
  }

  /// جلب مواقيت الصلاة لتاريخ معين ومدينة معينة
  Future<Map<String, DateTime>?> getPrayerTimes({
    required String cityName,
    required DateTime date,
  }) async {
    final fileName = getCityFileName(cityName);
    if (fileName == null) return null;

    final cityData = await _loadCityData(fileName);
    if (cityData == null || cityData.isEmpty) return null;

    // تنسيق التاريخ MM-dd مثل "01-01" أو "08-31"
    final monthStr = date.month.toString().padLeft(2, '0');
    final dayStr = date.day.toString().padLeft(2, '0');
    final targetDateStr = '$monthStr-$dayStr';

    final entry = cityData.firstWhere(
      (item) => item['date'] == targetDateStr,
      orElse: () => null,
    );

    if (entry == null) return null;

    try {
      final fajr = _parseTime(entry['fajr'] as String?, date);
      final sunrise = _parseTime(entry['sunrise'] as String?, date);
      final dhuhr = _parseTime(entry['dhuhr'] as String?, date);
      final asr = _parseTime(entry['asr'] as String?, date);
      final maghrib = _parseTime(entry['maghrib'] as String?, date);
      final isha = _parseTime(entry['isha'] as String?, date);

      if (fajr == null || dhuhr == null || asr == null || maghrib == null || isha == null) {
        return null;
      }

      return {
        'الفجر': fajr,
        'الشروق': sunrise ?? fajr.add(const Duration(minutes: 80)),
        'الظهر': dhuhr,
        'العصر': asr,
        'المغرب': maghrib,
        'العشاء': isha,
      };
    } catch (e) {
      debugPrint('MuezzinLibyaDB: parsing error: $e');
      return null;
    }
  }

  /// جلب جدول شهر كامل لمدينة
  Future<List<Map<String, dynamic>>?> getMonthSchedule({
    required String cityName,
    required int year,
    required int month,
  }) async {
    final fileName = getCityFileName(cityName);
    if (fileName == null) return null;

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final List<Map<String, dynamic>> schedule = [];

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final times = await getPrayerTimes(cityName: cityName, date: date);
      if (times != null) {
        schedule.add({
          'day': day,
          'date': date,
          'fajr': times['الفجر'],
          'sunrise': times['الشروق'],
          'dhuhr': times['الظهر'],
          'asr': times['العصر'],
          'maghrib': times['المغرب'],
          'isha': times['العشاء'],
        });
      }
    }

    return schedule.isNotEmpty ? schedule : null;
  }

  DateTime? _parseTime(String? timeStr, DateTime date) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final parts = timeStr.trim().split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        return DateTime(date.year, date.month, date.day, hour, minute);
      }
    }
    return null;
  }

  String _normalize(String input) {
    return input
        .trim()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(' ', '');
  }
}
