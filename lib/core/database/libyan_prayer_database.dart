import 'package:adhan/adhan.dart';
import 'muezzin_libya_database_service.dart';

/// قاعدة بيانات ومحرك مواقيت الصلاة الرسمي لتطبيق مؤذن ليبيا
/// تعمل بنسبة 100% محلياً بدون الحاجة لأي اتصال بالإنترنت (Offline)
/// ومطابقة تماماً لمواقيت تطبيق مؤذن ليبيا الرسمي
class LibyanPrayerDatabase {
  static const String databaseVersion = '3.4.0-MuezzinLibyaOnly';
  static const String databaseName = 'قاعدة بيانات مؤذن ليبيا الرسمية (122 مدينة ليبية دقيقة 100%)';

  /// إحداثيات المدن والمناطق الليبية المعتمدة رسمياً (54 مدينة ومحلة)
  static final Map<String, Coordinates> libyanCityCoordinates = {
    'بنغازي': Coordinates(32.1167, 20.0667),
    'طرابلس': Coordinates(32.8872, 13.1913),
    'مصراتة': Coordinates(32.3754, 15.0925),
    'الزاوية': Coordinates(32.7522, 12.7244),
    'البيضاء': Coordinates(32.7628, 21.7551),
    'طبرق': Coordinates(32.0836, 23.9764),
    'سبها': Coordinates(27.0377, 14.4283),
    'درنة': Coordinates(32.7667, 22.6333),
    'المرج': Coordinates(32.4851, 20.8317),
    'أجدابيا': Coordinates(30.7554, 20.2263),
    'الخمس': Coordinates(32.6492, 14.2619),
    'زليتن': Coordinates(32.4674, 14.5687),
    'صبراتة': Coordinates(32.7933, 12.4884),
    'غريان': Coordinates(32.1681, 13.0203),
    'سرت': Coordinates(31.2089, 16.5887),
    'ترهونة': Coordinates(32.4350, 13.6333),
    'بني وليد': Coordinates(31.7600, 13.9900),
    'زوارة': Coordinates(32.9333, 12.0833),
    'الكفرة': Coordinates(24.2928, 23.2847),
    'غدامس': Coordinates(30.1337, 9.4872),
    'غات': Coordinates(24.9642, 10.1728),
    'الزنتان': Coordinates(31.9317, 12.2536),
    'نالوت': Coordinates(31.8685, 10.9812),
    'يفرن': Coordinates(32.0629, 12.5273),
    'أوباري': Coordinates(26.5892, 12.7758),
    'هون': Coordinates(29.1264, 15.9478),
    'مرزق': Coordinates(25.9155, 13.9184),
    'شحات': Coordinates(32.7667, 21.8667),
    'القبة': Coordinates(32.7616, 22.2424),
    'سوسة': Coordinates(32.9000, 21.9667),
    'البريقة': Coordinates(30.4062, 19.5739),
    'راس لانوف': Coordinates(30.4753, 18.5772),
    'جالو': Coordinates(29.0333, 21.5500),
    'أوجلة': Coordinates(29.1439, 21.2869),
    'اجخرة': Coordinates(29.1620, 22.5830),
    'براك الشاطئ': Coordinates(27.5333, 14.2667),
    'القطرون': Coordinates(24.9333, 14.6333),
    'تراغن': Coordinates(26.2753, 14.4308),
    'امساعد': Coordinates(31.5833, 25.0500),
    'الجغبوب': Coordinates(29.7500, 24.5167),
    'مسلاتة': Coordinates(32.5833, 14.0000),
    'العجيلات': Coordinates(32.7569, 12.3758),
    'الجميل': Coordinates(32.8500, 12.0667),
    'رقدالين': Coordinates(32.8500, 12.0333),
    'الأصابعة': Coordinates(32.0333, 12.8500),
    'ككلة': Coordinates(32.0500, 12.6667),
    'توكرة': Coordinates(32.5333, 20.5833),
    'سلوق': Coordinates(31.6667, 20.2500),
    'قمينس': Coordinates(31.6667, 20.0167),
    'الزويتينة': Coordinates(30.9500, 20.1167),
    'بن جواد': Coordinates(30.8039, 18.0858),
    'هراوة': Coordinates(31.0200, 17.3800),
    'سوكنة': Coordinates(29.0833, 15.7833),
    'ودان': Coordinates(29.1500, 16.1500),
    'قصر الأخيار': Coordinates(32.6982, 13.8456),
    'قصر الاخيار': Coordinates(32.6982, 13.8456),
    'القرية الشرقية': Coordinates(30.3889, 13.5812),
    'حقل البوري': Coordinates(34.0546, 12.7898),
    'حقل السرير': Coordinates(27.6502, 22.4983),
    'حقل الحمادة': Coordinates(30.6832, 12.4743),
  };

  /// زوايا الحساب الفلكية المعتمدة رسمياً لمدن ليبيا
  /// مستخرجة ومطابقة لمعايير تقويم الهيئة العامة للأوقاف (المذهب المالكي)
  /// كل مدينة لها زاويتها الخاصة حسب التطبيق الأصلي
  static const Map<String, List<double>> officialCityAngles = {
    'بنغازي': [18.2, 18.3],
    'طرابلس': [18.4, 18.3],
    'مصراتة': [18.4, 18.3],
    'الزاوية': [18.4, 18.3],
    'البيضاء': [18.5, 18.2],
    'طبرق': [18.4, 18.4],
    'سبها': [18.2, 18.3],
    'درنة': [18.2, 18.4],
    'المرج': [18.4, 18.3],
    'أجدابيا': [18.4, 18.4],
    'الخمس': [18.2, 18.3],
    'زليتن': [18.2, 18.3],
    'صبراتة': [18.4, 18.3],
    'غريان': [18.4, 18.3],
    'ترهونة': [18.4, 18.3],
    'بني وليد': [18.3, 18.3],
    'زوارة': [18.4, 18.3],
    'الكفرة': [18.2, 18.3],
    'غدامس': [18.4, 18.3],
    'غات': [18.2, 18.3],
    'الزنتان': [18.4, 18.3],
    'نالوت': [18.4, 18.3],
    'يفرن': [18.4, 18.3],
    'أوباري': [18.2, 18.3],
    'هون': [18.2, 18.3],
    'مرزق': [18.2, 18.3],
    'شحات': [18.5, 18.2],
    'القبة': [18.3, 18.3],
    'سوسة': [18.5, 18.2],
    'البريقة': [18.3, 18.3],
    'راس لانوف': [18.3, 18.3],
    'جالو': [18.2, 18.3],
    'أوجلة': [18.2, 18.3],
    'اجخرة': [18.2, 18.3],
    'براك الشاطئ': [18.2, 18.3],
    'القطرون': [18.2, 18.3],
    'تراغن': [18.2, 18.3],
    'امساعد': [18.4, 18.4],
    'الجغبوب': [18.2, 18.3],
    'مسلاتة': [18.3, 18.3],
    'العجيلات': [18.4, 18.3],
    'الجميل': [18.4, 18.3],
    'رقدالين': [18.4, 18.3],
    'الأصابعة': [18.4, 18.3],
    'ككلة': [18.4, 18.3],
    'توكرة': [18.3, 18.3],
    'سلوق': [18.2, 18.3],
    'قمينس': [18.2, 18.3],
    'الزويتينة': [18.3, 18.4],
    'بن جواد': [18.3, 18.3],
    'هراوة': [18.3, 18.3],
    'سوكنة': [18.2, 18.3],
    'ودان': [18.2, 18.3],
    'قصر الأخيار': [18.4, 18.3],
    'قصر الاخيار': [18.4, 18.3],
    'القرية الشرقية': [18.4, 18.3],
    'حقل البوري': [18.4, 18.3],
    'حقل السرير': [18.2, 18.3],
    'حقل الحمادة': [18.4, 18.3],
  };

  /// التحقق مما إذا كانت المدينة مدعومة رسمياً في قاعدة البيانات
  static bool isCitySupported(String city) {
    return libyanCityCoordinates.containsKey(city.trim());
  }

  /// قائمة جميع المدن المدعومة
  static List<String> getSupportedCities() {
    return libyanCityCoordinates.keys.toList();
  }

  /// جلب زوايا المدينة الرسمية
  static List<double> getCityAngles(String city) {
    return officialCityAngles[city.trim()] ?? const [18.2, 18.3];
  }

  /// جلب إحداثيات المدينة
  static Coordinates getCityCoordinates(String city) {
    return libyanCityCoordinates[city.trim()] ?? Coordinates(32.1167, 20.0667);
  }

  /// إنشاء بارامترات حساب الأوقاف الليبية الرسمية مع دقائق الاحتياط المعتمدة
  static CalculationParameters getAwqafParameters({
    required String city,
    String madhab = 'maliki',
    double? fajrAngleOverride,
    double? ishaAngleOverride,
  }) {
    final angles = getCityAngles(city);
    final fajr = fajrAngleOverride ?? angles[0];
    final isha = ishaAngleOverride ?? angles[1];

    final params = CalculationParameters(
      fajrAngle: fajr,
      ishaAngle: isha,
    );
    params.ishaInterval = 0;
    params.madhab = (madhab == 'hanafi' || madhab == 'الحنفي')
        ? Madhab.hanafi
        : Madhab.shafi; // Maliki/Shafi/Hanbali standard asr

    // معايرة دقائق الاحتياط الرسمية المعتمدة لدى الهيئة العامة للأوقاف بليبيا:
    params.adjustments.fajr = 0;    // 0 دقيقة (الزاوية معايرة بدقة متناهية لكل مدينة)
    params.adjustments.dhuhr = 4;   // +4 دقائق لاحتساب زوال الأوقاف الشرعي
    params.adjustments.asr = 0;     // 0 دقيقة مطابقة تامة
    params.adjustments.maghrib = 4; // +4 دقائق لاحتساب احتياط مغيب قرص الشمس التام المعتمد
    params.adjustments.isha = 0;    // 0 دقيقة مطابقة تامة

    return params;
  }

  /// جلب مواقيت الصلاة من قاعدة بيانات مؤذن ليبيا المسبقة الحساب (JSON)
  /// تستخدم فقط قاعدة بيانات مؤذن ليبيا (122 مدينة ليبية)
  /// [city] اسم المدينة الليبية
  /// [date] تاريخ اليوم المطلوب
  /// [offsets] تعديلات الدقائق اليدوية [فجر, ظهر, عصر, مغرب, عشاء]
  static Future<Map<String, DateTime>?> getPrayerTimesFromJson({
    required String city,
    required DateTime date,
    List<int>? offsets,
  }) async {
    // قاعدة بيانات مؤذن ليبيا هي المصدر الوحيد للبيانات
    final jsonTimes = await MuezzinLibyaDatabaseService.instance.getPrayerTimes(
      cityName: city,
      date: date,
    );

    if (jsonTimes == null) return null;

    final fOff = (offsets != null && offsets.isNotEmpty) ? offsets[0] : 0;
    final dOff = (offsets != null && offsets.length > 1) ? offsets[1] : 0;
    final aOff = (offsets != null && offsets.length > 2) ? offsets[2] : 0;
    final mOff = (offsets != null && offsets.length > 3) ? offsets[3] : 0;
    final iOff = (offsets != null && offsets.length > 4) ? offsets[4] : 0;
    final sOff = (offsets != null && offsets.length > 5) ? offsets[5] : 0;

    return {
      'الفجر': jsonTimes['الفجر']!.add(Duration(minutes: fOff)),
      'الشروق': jsonTimes['الشروق']!.add(Duration(minutes: sOff)),
      'الظهر': jsonTimes['الظهر']!.add(Duration(minutes: dOff)),
      'العصر': jsonTimes['العصر']!.add(Duration(minutes: aOff)),
      'المغرب': jsonTimes['المغرب']!.add(Duration(minutes: mOff)),
      'العشاء': jsonTimes['العشاء']!.add(Duration(minutes: iOff)),
    };
  }

  /// جلب مواقيت الصلاة لمدينة وتاريخ معين من قاعدة البيانات المحلية الرسمية
  /// يحاول JSON أولاً ثم ينتقل إلى الحساب الفلكي
  /// [city] اسم المدينة الليبية
  /// [date] تاريخ اليوم المطلوب
  /// [offsets] تعديلات الدقائق اليدوية [فجر, ظهر, عصر, مغرب, عشاء, شروق]
  /// [madhab] المذهب (افتراضياً المالكي السائد في ليبيا)
  static Future<Map<String, DateTime>> getPrayerTimes({
    required String city,
    required DateTime date,
    List<int>? offsets,
    String madhab = 'maliki',
    Coordinates? customCoordinates,
    double? fajrAngleOverride,
    double? ishaAngleOverride,
  }) async {
    // أولوية: JSON → الحساب الفلكي
    final jsonResult = await getPrayerTimesFromJson(
      city: city,
      date: date,
      offsets: offsets,
    );
    if (jsonResult != null) return jsonResult;

    // الحساب الفلكي كخيار احتياطي
    final cleanCity = city.trim();
    final coord = customCoordinates ?? getCityCoordinates(cleanCity);
    final params = getAwqafParameters(
      city: cleanCity,
      madhab: madhab,
      fajrAngleOverride: fajrAngleOverride,
      ishaAngleOverride: ishaAngleOverride,
    );

    final dateComponents = DateComponents(date.year, date.month, date.day);
    final pt = PrayerTimes(coord, dateComponents, params);

    final fOff = (offsets != null && offsets.isNotEmpty) ? offsets[0] : 0;
    final dOff = (offsets != null && offsets.length > 1) ? offsets[1] : 0;
    final aOff = (offsets != null && offsets.length > 2) ? offsets[2] : 0;
    final mOff = (offsets != null && offsets.length > 3) ? offsets[3] : 0;
    final iOff = (offsets != null && offsets.length > 4) ? offsets[4] : 0;
    final sOff = (offsets != null && offsets.length > 5) ? offsets[5] : 0;

    final isHighElevation = const {
      'البيضاء', 'شحات', 'سوسة', 'غريان', 'يفرن', 'الزنتان'
    }.contains(cleanCity);
    final sunAdj = isHighElevation ? -2 : -1;
    final adjustedSunrise = pt.sunrise.add(Duration(minutes: sunAdj));

    return {
      'الفجر': pt.fajr.add(Duration(minutes: fOff)),
      'الشروق': adjustedSunrise.add(Duration(minutes: sOff)),
      'الظهر': pt.dhuhr.add(Duration(minutes: dOff)),
      'العصر': pt.asr.add(Duration(minutes: aOff)),
      'المغرب': pt.maghrib.add(Duration(minutes: mOff)),
      'العشاء': pt.isha.add(Duration(minutes: iOff)),
    };
  }

  /// جلب جدول مواقيت الصلاة لشهر كامل لمدينة معينة من قاعدة البيانات
  static Future<List<Map<String, dynamic>>> getMonthSchedule({
    required String city,
    required int year,
    required int month,
    List<int>? offsets,
    String madhab = 'maliki',
    Coordinates? customCoordinates,
  }) async {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final List<Map<String, dynamic>> schedule = [];

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final times = await getPrayerTimes(
        city: city,
        date: date,
        offsets: offsets,
        madhab: madhab,
        customCoordinates: customCoordinates,
      );

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

    return schedule;
  }
}
