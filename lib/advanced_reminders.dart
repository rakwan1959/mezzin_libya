import 'package:shared_preferences/shared_preferences.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:adhan/adhan.dart';
import 'core/database/libyan_prayer_database.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'notification_service.dart';

class AdvancedReminders {
  static const List<String> _hijriMonthsArabic = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];

  static const String keyMorningAzkar = 'rem_morning_azkar';
  static const String keyEveningAzkar = 'rem_evening_azkar';
  static const String keyDuha = 'rem_duha';
  static const String keyMonThu = 'rem_mon_thu';
  static const String keyWhiteDays = 'rem_white_days';
  static const String keyLastThird = 'rem_last_third';
  static const String keySpecialDays = 'rem_special_days';
  static const String keyKahf = 'rem_kahf';
  static const String keyFridayPrayer = 'rem_friday_prayer';

  static Future<void> scheduleAllReminders(Coordinates coordinates, List<int> offsets, {String city = 'بنغازي'}) async {
    final prefs = await SharedPreferences.getInstance();
    final hijriOffset = prefs.getInt('hijriOffset') ?? 0;
    
    final bool remMorningAzkar = prefs.getBool(keyMorningAzkar) ?? true;
    final bool remEveningAzkar = prefs.getBool(keyEveningAzkar) ?? true;
    final bool remDuha = prefs.getBool(keyDuha) ?? true;
    final bool remMonThu = prefs.getBool(keyMonThu) ?? true;
    final bool remWhiteDays = prefs.getBool(keyWhiteDays) ?? true;
    final bool remLastThird = prefs.getBool(keyLastThird) ?? true;
    final bool remSpecialDays = prefs.getBool(keySpecialDays) ?? true;
    final bool remKahf = prefs.getBool(keyKahf) ?? true;

    final ns = NotificationService();
    final now = DateTime.now();

    final fOff = offsets.isNotEmpty ? offsets[0] : 0;
    final dOff = offsets.length > 1 ? offsets[1] : 0;
    final aOff = offsets.length > 2 ? offsets[2] : 0;
    final mOff = offsets.length > 3 ? offsets[3] : 0;
    final iOff = offsets.length > 4 ? offsets[4] : 0;
    final sOff = offsets.length > 5 ? offsets[5] : 0;

    // Schedule for the next 30 days
    for (int i = 0; i < 30; i++) {
      final date = now.add(Duration(days: i));
      final nextDate = date.add(const Duration(days: 1));
      
      final String method = prefs.getString('method') ?? 'ليبيا (الأوقاف)';
      final madhabStr = prefs.getString('madhab') ?? 'maliki';

      DateTime sunrise;
      DateTime maghrib;
      DateTime isha;
      DateTime nextFajr;

      try {
        final dayTimes = await LibyanPrayerDatabase.getPrayerTimes(
          city: city,
          date: date,
          offsets: [fOff, dOff, aOff, mOff, iOff, sOff],
          madhab: madhabStr,
        );
        final nextDayTimes = await LibyanPrayerDatabase.getPrayerTimes(
          city: city,
          date: nextDate,
          offsets: [fOff, dOff, aOff, mOff, iOff, sOff],
          madhab: madhabStr,
        );

        sunrise = dayTimes['الشروق']!;
        maghrib = dayTimes['المغرب']!;
        isha    = dayTimes['العشاء']!;
        nextFajr = nextDayTimes['الفجر']!;
      } catch (_) {
        CalculationParameters params;
        if (method == 'ليبيا (الأوقاف)') {
          final cityAngles = MainNavigationScreen.getCityAngles(city);
          params = CalculationParameters(fajrAngle: cityAngles[0], ishaAngle: cityAngles[1]);
          params.ishaInterval = 0;
          params.adjustments.fajr = -1;
          params.adjustments.dhuhr = 4;
          params.adjustments.asr = 0;
          params.adjustments.maghrib = 4;
          params.adjustments.isha = 0;
        } else if (method == 'أم القرى') {
          params = CalculationMethod.umm_al_qura.getParameters();
        } else if (method == 'رابطة العالم الإسلامي') {
          params = CalculationMethod.muslim_world_league.getParameters();
        } else if (method == 'الهيئة المصرية') {
          params = CalculationMethod.egyptian.getParameters();
        } else if (method == 'جامعة العلوم الإسلامية (كراتشي)') {
          params = CalculationMethod.karachi.getParameters();
        } else if (method == 'الاتحاد الإسلامي (ISNA)') {
          params = CalculationMethod.north_america.getParameters();
        } else if (method == 'دبي') {
          params = CalculationMethod.dubai.getParameters();
        } else if (method == 'الكويت') {
          params = CalculationMethod.kuwait.getParameters();
        } else if (method == 'قطر') {
          params = CalculationMethod.qatar.getParameters();
        } else {
          params = CalculationParameters(fajrAngle: 18.4, ishaAngle: 18.2);
        }
        params.madhab = (madhabStr == 'hanafi' || madhabStr == 'الحنفي') ? Madhab.hanafi : Madhab.shafi;

        final pt = PrayerTimes(coordinates, DateComponents(date.year, date.month, date.day), params);
        final ptNext = PrayerTimes(coordinates, DateComponents(nextDate.year, nextDate.month, nextDate.day), params);

        sunrise = pt.sunrise.add(Duration(minutes: sOff));
        maghrib = pt.maghrib.add(Duration(minutes: mOff));
        isha    = pt.isha.add(Duration(minutes: iOff));
        nextFajr = ptNext.fajr.add(Duration(minutes: fOff));
      }
      
      // 1. أذكار الصباح (بعد شروق الشمس بـ 30 دقيقة)
      if (remMorningAzkar) {
        final morningTime = sunrise.add(const Duration(minutes: 30));
        if (morningTime.isAfter(now)) {
          ns.scheduleGeneralReminder(
            id: 10000 + i,
            title: 'أذكار الصباح',
            body: 'حان موعد أذكار الصباح، ابدأ يومك بذكر الله وتوكل عليه ☀️',
            scheduledTime: morningTime,
          );
        } else {
          ns.cancelNotification(id: 10000 + i);
        }
      } else {
        ns.cancelNotification(id: 10000 + i);
      }

      // 2. أذكار المساء (قبل أذان المغرب بـ 30 دقيقة)
      if (remEveningAzkar) {
        final eveningTime = maghrib.subtract(const Duration(minutes: 30));
        if (eveningTime.isAfter(now)) {
          ns.scheduleGeneralReminder(
            id: 20000 + i,
            title: 'أذكار المساء',
            body: 'حان موعد أذكار المساء، حصّن نفسك واذكر الله في المساء 🌙',
            scheduledTime: eveningTime,
          );
        } else {
          ns.cancelNotification(id: 20000 + i);
        }
      } else {
        ns.cancelNotification(id: 20000 + i);
      }

      // 3. صلاة الضحى (بعد شروق الشمس بـ 45 دقيقة)
      if (remDuha) {
        final duhaTime = sunrise.add(const Duration(minutes: 45));
        if (duhaTime.isAfter(now)) {
          ns.scheduleGeneralReminder(
            id: 30000 + i,
            title: 'صلاة الضحى',
            body: 'صلاة الضحى صلاة الأوابين، لا تنس ركعتي الضحى.',
            scheduledTime: duhaTime,
          );
        } else {
          ns.cancelNotification(id: 30000 + i);
        }
      } else {
        ns.cancelNotification(id: 30000 + i);
      }

      // حساب اليوم الهجري للغد مع الإزاحة
      final nextHijri = HijriCalendar.fromDate(nextDate.add(Duration(days: hijriOffset)));
      final bool isRamadan = nextHijri.hMonth == 9;

      // 4. صيام الإثنين والخميس (تذكير في الليلة السابقة بعد العشاء)
      if (remMonThu && !isRamadan) {
        if (nextDate.weekday == DateTime.monday || nextDate.weekday == DateTime.thursday) {
          final reminderTime = isha.add(const Duration(minutes: 15));
          if (reminderTime.isAfter(now)) {
            ns.scheduleGeneralReminder(
              id: 40000 + i,
              title: 'تذكير بصيام غداً',
              body: nextDate.weekday == DateTime.monday
                  ? 'غداً الإثنين، تُعرض فيه الأعمال، لا تنس نية الصيام.'
                  : 'غداً الخميس، تُعرض فيه الأعمال، لا تنس نية الصيام.',
              scheduledTime: reminderTime,
            );
          } else {
            ns.cancelNotification(id: 40000 + i);
          }
        } else {
          ns.cancelNotification(id: 40000 + i);
        }
      } else {
        ns.cancelNotification(id: 40000 + i);
      }

      // 5. صيام الأيام البيض (تذكير أيام 13، 14، 15 هجري في الليلة السابقة بعد العشاء)
      if (remWhiteDays && !isRamadan) {
        if (nextHijri.hDay == 13 || nextHijri.hDay == 14 || nextHijri.hDay == 15) {
          final whiteTime = isha.add(const Duration(minutes: 20));
          if (whiteTime.isAfter(now)) {
            final monthName = _hijriMonthsArabic[(nextHijri.hMonth - 1).clamp(0, 11)];
            ns.scheduleGeneralReminder(
              id: 50000 + i,
              title: 'صيام الأيام البيض',
              body: 'غداً يوم ${nextHijri.hDay} من $monthName، لا تنس نية صيام الأيام البيض.',
              scheduledTime: whiteTime,
            );
          } else {
            ns.cancelNotification(id: 50000 + i);
          }
        } else {
          ns.cancelNotification(id: 50000 + i);
        }
      } else {
        ns.cancelNotification(id: 50000 + i);
      }

      // 6. الثلث الأخير من الليل (تنبيه عند بدء الثلث الأخير)
      if (remLastThird) {
        final nightDuration = nextFajr.difference(maghrib);
        final lastThirdStart = maghrib.add(Duration(minutes: (nightDuration.inMinutes * (2 / 3)).round()));
        if (lastThirdStart.isAfter(now)) {
          ns.scheduleGeneralReminder(
            id: 60000 + i,
            title: 'الثلث الأخير من الليل',
            body: 'هل من سائل فأعطيه؟ هل من مستغفر فأغفر له؟ قم لله ولو بركعة.',
            scheduledTime: lastThirdStart,
          );
        } else {
          ns.cancelNotification(id: 60000 + i);
        }
      } else {
        ns.cancelNotification(id: 60000 + i);
      }

      // 7. الأيام الفاضلة (تاسوعاء، عاشوراء، عشر ذي الحجة، يوم عرفة وغيرها)
      if (remSpecialDays) {
        bool isSpecial = false;
        String specialTitle = '';
        String specialBody = '';

        if (nextHijri.hMonth == 1 && nextHijri.hDay == 9) {
          isSpecial = true;
          specialTitle = 'تذكير بصيام يوم تاسوعاء';
          specialBody = 'غداً يوم تاسوعاء، صيامه سنة مستحبة مع يوم عاشوراء.';
        } else if (nextHijri.hMonth == 1 && nextHijri.hDay == 10) {
          isSpecial = true;
          specialTitle = 'تذكير بصيام يوم عاشوراء';
          specialBody = 'غداً يوم عاشوراء، صيامه يكفّر ذنوب سنة ماضية، لا تفوّت أجره العظيم.';
        } else if (nextHijri.hMonth == 12 && nextHijri.hDay >= 1 && nextHijri.hDay <= 8) {
          isSpecial = true;
          specialTitle = 'أيام عشر ذي الحجة';
          specialBody = 'غداً يوم من أيام عشر ذي الحجة الفاضلة، يُستحب فيه الصيام والعمل الصالح.';
        } else if (nextHijri.hMonth == 12 && nextHijri.hDay == 9) {
          isSpecial = true;
          specialTitle = 'تذكير بصيام يوم عرفة';
          specialBody = 'غداً يوم عرفة لغير الحاج، صيامه يكفّر ذنوب سنة ماضية وباقية، لا تفوّت أجر هذا اليوم العظيم.';
        }
        
        if (isSpecial) {
          final specialTime = isha.add(const Duration(minutes: 25));
          if (specialTime.isAfter(now)) {
            ns.scheduleGeneralReminder(
              id: 70000 + i,
              title: specialTitle,
              body: specialBody,
              scheduledTime: specialTime,
            );
          } else {
            ns.cancelNotification(id: 70000 + i);
          }
        } else {
          ns.cancelNotification(id: 70000 + i);
        }
      } else {
        ns.cancelNotification(id: 70000 + i);
      }

      // 8. قراءة سورة الكهف (تذكير كل جمعة الساعة 10:00 صباحاً)
      if (remKahf) {
        if (date.weekday == DateTime.friday) {
          final kahfTime = DateTime(date.year, date.month, date.day, 10, 0);
          if (kahfTime.isAfter(now)) {
            ns.scheduleGeneralReminder(
              id: 80000 + i,
              title: 'سورة الكهف',
              body: 'نور ما بين الجمعتين، لا تنس قراءة سورة الكهف والصلاة على النبي ﷺ.',
              scheduledTime: kahfTime,
            );
          } else {
            ns.cancelNotification(id: 80000 + i);
          }
        } else {
          ns.cancelNotification(id: 80000 + i);
        }
      } else {
        ns.cancelNotification(id: 80000 + i);
      }

      // إلغاء أي إشعار قديم مجدول تحت ID 90000 + i لضمان عدم التكرار
      // حيث يُجدول تذكير صلاة الجمعة بدقة عبر NotificationService و AdhanAudioService
      ns.cancelNotification(id: 90000 + i);
    }
  }
}

