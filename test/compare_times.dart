import 'dart:convert';
import 'dart:io';
import 'package:adhan/adhan.dart';
import 'package:muezzin_libya_app/core/database/libyan_prayer_database.dart';

void main() {
  final date = DateTime(2026, 8, 31);
  print('=== مقارنة أوقات الصلاة لطرابلس في 31 أغسطس ===');

  // 1. قاعدة بيانات مؤذن ليبيا
  final tripoliFile = File('assets/database/Libya/tripoli.json');
  if (tripoliFile.existsSync()) {
    final tripoliData = json.decode(tripoliFile.readAsStringSync()) as List<dynamic>;
    final entry = tripoliData.firstWhere((e) => e['date'] == '08-31');
    print('1. مؤذن ليبيا (طرابلس): الفجر=${entry['fajr']}, الشروق=${entry['sunrise']}, الظهر=${entry['dhuhr']}, العصر=${entry['asr']}, المغرب=${entry['maghrib']}, العشاء=${entry['isha']}');
  }

  // 2. الحساب الفلكي
  final params = LibyanPrayerDatabase.getAwqafParameters(city: 'طرابلس');
  final coord = LibyanPrayerDatabase.getCityCoordinates('طرابلس');
  final pt = PrayerTimes(coord, DateComponents(2026, 8, 31), params);
  print('2. الحساب الفلكي (طرابلس): الفجر=${pt.fajr.hour.toString().padLeft(2, '0')}:${pt.fajr.minute.toString().padLeft(2, '0')}, الشروق=${pt.sunrise.hour.toString().padLeft(2, '0')}:${pt.sunrise.minute.toString().padLeft(2, '0')}');
}
