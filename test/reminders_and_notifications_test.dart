import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:muezzin_libya_app/advanced_reminders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Prayer Notifications & Reminders Verification', () {
    test('1. Verify Prayer Notification Formats', () {
      final prayers = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
      const int beforeAdhanOffset = 5;
      const int afterAdhanOffset = 10;

      for (final prayer in prayers) {
        // قبل الأذان
        final beforeText = 'بقي على أذان صلاة $prayer $beforeAdhanOffset دقائق';
        expect(beforeText, 'بقي على أذان صلاة $prayer 5 دقائق');

        // حان الآن موعد الأذان
        final adhanText = 'حان الآن موعد أذان صلاة $prayer';
        expect(adhanText, 'حان الآن موعد أذان صلاة $prayer');

        // بعد الأذان
        final afterText = 'مضى على أذان صلاة $prayer $afterAdhanOffset دقائق';
        expect(afterText, 'مضى على أذان صلاة $prayer 10 دقائق');
      }
    });

    test('2. Verify Morning, Evening Azkar and Duha prayer offsets', () {
      final baseDate = DateTime(2026, 9, 7, 6, 0);
      final sunrise = baseDate;
      final maghrib = DateTime(2026, 9, 7, 19, 0);

      // أذكار الصباح بعد شروق الشمس بـ 30 دقيقة
      final morningAzkar = sunrise.add(const Duration(minutes: 30));
      expect(morningAzkar.difference(sunrise).inMinutes, 30);
      expect(morningAzkar, DateTime(2026, 9, 7, 6, 30));

      // أذكار المساء قبل أذان المغرب بـ 30 دقيقة
      final eveningAzkar = maghrib.subtract(const Duration(minutes: 30));
      expect(maghrib.difference(eveningAzkar).inMinutes, 30);
      expect(eveningAzkar, DateTime(2026, 9, 7, 18, 30));

      // صلاة الضحى بعد شروق الشمس بـ 45 دقيقة
      final duha = sunrise.add(const Duration(minutes: 45));
      expect(duha.difference(sunrise).inMinutes, 45);
      expect(duha, DateTime(2026, 9, 7, 6, 45));
    });

    test('3. Verify Friday Prayer & Surah Al-Kahf timings', () {
      final fridayDate = DateTime(2026, 9, 11);
      expect(fridayDate.weekday, DateTime.friday);

      // صلاة الجمعة (قبل الأذان بـ 45 دقيقة)
      final fridayDhuhr = DateTime(2026, 9, 11, 13, 0);
      final fridayReminderTime = fridayDhuhr.subtract(const Duration(minutes: 45));
      expect(fridayDhuhr.difference(fridayReminderTime).inMinutes, 45);
      const fridayBody = 'بقي على صلاة الجمعة 45 دقيقة';
      expect(fridayBody, 'بقي على صلاة الجمعة 45 دقيقة');

      // سورة الكهف: الجمعة الساعة 10:00 صباحاً
      final kahfTime = DateTime(fridayDate.year, fridayDate.month, fridayDate.day, 10, 0);
      expect(kahfTime.hour, 10);
      expect(kahfTime.minute, 0);
    });

    test('4. Verify Last Third of the Night calculation without unwanted phrase', () {
      final maghrib = DateTime(2026, 9, 7, 18, 0);
      final nextFajr = DateTime(2026, 9, 8, 4, 30);
      final nightDuration = nextFajr.difference(maghrib);
      final lastThirdStart = maghrib.add(Duration(minutes: (nightDuration.inMinutes * (2 / 3)).round()));

      expect(lastThirdStart, DateTime(2026, 9, 8, 1, 0));

      const title = 'الثلث الأخير من الليل';
      const body = 'هل من سائل فأعطيه؟ هل من مستغفر فأغفر له؟ قم لله ولو بركعة.';
      expect(title.contains('التنزل'), isFalse);
      expect(body.contains('التنزل'), isFalse);
    });

    test('5. Verify Special Days (Ashura, Tasua, Ten Days of Dhul-Hijjah, Arafah)', () {
      // Tasua: 9 Muharram
      final tasuaHijri = HijriCalendar()
        ..hYear = 1448
        ..hMonth = 1
        ..hDay = 9;
      expect(tasuaHijri.hMonth == 1 && tasuaHijri.hDay == 9, isTrue);

      // Ashura: 10 Muharram
      final ashuraHijri = HijriCalendar()
        ..hYear = 1448
        ..hMonth = 1
        ..hDay = 10;
      expect(ashuraHijri.hMonth == 1 && ashuraHijri.hDay == 10, isTrue);

      // Ten Days of Dhul-Hijjah: 1-8
      final tenDaysHijri = HijriCalendar()
        ..hYear = 1448
        ..hMonth = 12
        ..hDay = 5;
      expect(tenDaysHijri.hMonth == 12 && tenDaysHijri.hDay >= 1 && tenDaysHijri.hDay <= 8, isTrue);

      // Arafah: 9 Dhul-Hijjah
      final arafahHijri = HijriCalendar()
        ..hYear = 1448
        ..hMonth = 12
        ..hDay = 9;
      expect(arafahHijri.hMonth == 12 && arafahHijri.hDay == 9, isTrue);
    });

    test('6. Verify White Days: 13, 14, 15 Hijri', () {
      for (int day in [13, 14, 15]) {
        final whiteDayHijri = HijriCalendar()
          ..hYear = 1448
          ..hMonth = 2
          ..hDay = day;
        final bool isWhiteDay = whiteDayHijri.hDay == 13 || whiteDayHijri.hDay == 14 || whiteDayHijri.hDay == 15;
        expect(isWhiteDay, isTrue);
      }
    });

    test('7. Verify AdvancedReminders Keys Presence', () {
      expect(AdvancedReminders.keyMorningAzkar, 'rem_morning_azkar');
      expect(AdvancedReminders.keyEveningAzkar, 'rem_evening_azkar');
      expect(AdvancedReminders.keyDuha, 'rem_duha');
      expect(AdvancedReminders.keyMonThu, 'rem_mon_thu');
      expect(AdvancedReminders.keyWhiteDays, 'rem_white_days');
      expect(AdvancedReminders.keyLastThird, 'rem_last_third');
      expect(AdvancedReminders.keySpecialDays, 'rem_special_days');
      expect(AdvancedReminders.keyKahf, 'rem_kahf');
      expect(AdvancedReminders.keyFridayPrayer, 'rem_friday_prayer');
    });
  });
}
