import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:muezzin_libya_app/core/database/libyan_prayer_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Tripoli'));
  });

  test('Verify LibyanPrayerDatabase with new adjustments', () async {
    final date = DateTime(2026, 8, 19);
    final tripoliTimes = await LibyanPrayerDatabase.getPrayerTimes(city: 'طرابلس', date: date);
    final benghaziTimes = await LibyanPrayerDatabase.getPrayerTimes(city: 'بنغازي', date: date);

    expect(tripoliTimes.containsKey('الفجر'), isTrue);
    expect(tripoliTimes.containsKey('الظهر'), isTrue);
    expect(tripoliTimes.containsKey('العصر'), isTrue);
    expect(tripoliTimes.containsKey('المغرب'), isTrue);
    expect(tripoliTimes.containsKey('العشاء'), isTrue);
    expect(benghaziTimes.containsKey('الفجر'), isTrue);

    final params = LibyanPrayerDatabase.getAwqafParameters(city: 'طرابلس');
    expect(params.adjustments.fajr, 0);
    expect(params.adjustments.dhuhr, 4);
    expect(params.adjustments.asr, 0);
    expect(params.adjustments.maghrib, 4);
    expect(params.adjustments.isha, 0);
  });
}
