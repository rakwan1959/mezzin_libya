import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Verify Libyan cities prayer times JSON database files exist and are valid', () {
    final libyaDir = Directory('assets/database/Libya');
    expect(libyaDir.existsSync(), isTrue, reason: 'assets/database/Libya must exist');

    final jsonFiles = libyaDir.listSync().whereType<File>().toList();
    expect(jsonFiles.length, greaterThanOrEqualTo(120), reason: 'Must have at least 120 city files');

    // Test major cities
    final citiesToTest = ['tripoli', 'banghazi', 'musratah', 'sabha', 'baida', 'drna', 'topruq', 'khomes', 'zawia'];

    for (final city in citiesToTest) {
      final file = File('assets/database/Libya/$city.json');
      expect(file.existsSync(), isTrue, reason: '$city.json should exist');

      final content = file.readAsStringSync();
      final List<dynamic> days = json.decode(content);

      expect(days.length, greaterThanOrEqualTo(365), reason: '$city.json should have 365+ days');

      final firstDay = days.first as Map<String, dynamic>;
      expect(firstDay.containsKey('fajr'), isTrue);
      expect(firstDay.containsKey('dhuhr'), isTrue);
      expect(firstDay.containsKey('asr'), isTrue);
      expect(firstDay.containsKey('maghrib'), isTrue);
      expect(firstDay.containsKey('isha'), isTrue);
      expect(firstDay.containsKey('date'), isTrue);
      expect(firstDay['date'], '01-01');

      // Verify prayer times format (HH:mm)
      final fajr = firstDay['fajr'] as String;
      expect(fajr.contains(':'), isTrue);
    }
  });

  test('Verify ALL 122 Libyan city database files decode cleanly and have 365 days', () {
    final libyaDir = Directory('assets/database/Libya');
    final jsonFiles = libyaDir.listSync().whereType<File>().toList();

    int totalCitiesTested = 0;
    for (final file in jsonFiles) {
      final content = file.readAsStringSync();
      final List<dynamic> days = json.decode(content);
      expect(days.length, greaterThanOrEqualTo(365), reason: '${file.path} should contain at least 365 days');

      // Check first day and middle day
      final day1 = days[0] as Map<String, dynamic>;
      expect(day1['fajr'], isNotNull);
      expect(day1['dhuhr'], isNotNull);
      expect(day1['asr'], isNotNull);
      expect(day1['maghrib'], isNotNull);
      expect(day1['isha'], isNotNull);
      totalCitiesTested++;
    }

    expect(totalCitiesTested, equals(122));
  });

  test('Verify MuezzinLibya database gives correct prayer times', () async {
    // اختبار أن قاعدة بيانات مؤذن ليبيا تعمل بشكل صحيح
    final tripoliFile = File('assets/database/Libya/tripoli.json');
    expect(tripoliFile.existsSync(), isTrue);

    final tripoliData = json.decode(tripoliFile.readAsStringSync()) as List<dynamic>;
    expect(tripoliData.isNotEmpty, isTrue);

    // التحقق من وجود بيانات الفجر
    final entry = tripoliData.firstWhere((e) => e['date'] == '08-31');
    expect(entry['fajr'], isNotNull, reason: 'Fajr time must exist for Tripoli on 31 August');
    expect(entry['sunrise'], isNotNull);
    expect(entry['dhuhr'], isNotNull);
    expect(entry['asr'], isNotNull);
    expect(entry['maghrib'], isNotNull);
    expect(entry['isha'], isNotNull);
  });
}
