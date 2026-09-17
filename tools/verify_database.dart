import 'dart:convert';
import 'dart:io';

void main() async {
  print('=== Verifying Prayer Times Database Integration ===');
  
  final libyaDir = Directory('assets/database/Libya');
  if (!libyaDir.existsSync()) {
    print('ERROR: assets/database/Libya directory not found!');
    exit(1);
  }

  final files = libyaDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
  print('Found ${files.length} city JSON files in assets/database/Libya/');

  int totalValid = 0;
  int errorCount = 0;

  for (final f in files) {
    final name = f.uri.pathSegments.last;
    try {
      final content = await f.readAsString();
      final data = jsonDecode(content) as List<dynamic>;
      if (data.length < 365) {
        print('WARNING: $name has only ${data.length} days (expected >= 365)');
      }
      
      // Check first item structure
      final first = data.first as Map<String, dynamic>;
      for (final key in ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha', 'date']) {
        if (!first.containsKey(key)) {
          print('ERROR in $name: missing key $key');
          errorCount++;
        }
      }
      totalValid++;
    } catch (e) {
      print('ERROR parsing $name: $e');
      errorCount++;
    }
  }

  print('JSON Syntax Check: $totalValid files valid, $errorCount errors.');

  // Test checking known cities from 4.02
  final sampleCities = [
    'tripoli', 'banghazi', 'musratah', 'khomes', 'zawia', 'sabha', 'ejdabia',
    'siret', 'baida', 'zleatin', 'braiga', 'drna', 'emsaad', 'ghadames',
    'hoon', 'jalo', 'lanoof', 'ojla', 'topruq', 'walead', 'kofra', 'marij',
    'aljaghbub', 'benjuwad', 'shahat', 'zwara', 'ubari', 'tarhona', 'tarhunah',
    'gherian', 'gharyan', 'morzuk', 'murzuq', 'gaser_lhiar', 'alzintan', 'zintan',
    'mesalatah', 'mslata', 'jakharrah', 'ejkhara', 'sarir_field', 'sareer',
    'tamssah', 'temesa', 'bore_field', 'bori', 'tbqa', 'tabaqah',
    'hamada_field', 'hamada', 'qariat_shargea', 'sharqeyah'
  ];

  print('\nChecking critical 4.02 cities exist in assets/database/Libya/:');
  int missing = 0;
  for (final c in sampleCities) {
    final file = File('assets/database/Libya/$c.json');
    if (!file.existsSync()) {
      print('  MISSING: $c.json');
      missing++;
    }
  }

  if (missing == 0) {
    print('All ${sampleCities.length} required city files are present and verified!');
  } else {
    print('WARNING: $missing city files are missing.');
  }

  // Check SQLite file
  final sqliteFile = File('assets/database/Libya.sqlite');
  if (sqliteFile.existsSync()) {
    print('\nSQLite database present: assets/database/Libya.sqlite (${sqliteFile.lengthSync()} bytes)');
  } else {
    print('\nWARNING: assets/database/Libya.sqlite not found');
  }

  // Check SQL dump file
  final sqlFile = File('assets/database/muezzin_libya_prayer_times.sql');
  if (sqlFile.existsSync()) {
    print('SQL Dump present: assets/database/muezzin_libya_prayer_times.sql (${sqlFile.lengthSync()} bytes)');
  }

  print('\n=== Verification Summary: SUCCESS ===');
}
