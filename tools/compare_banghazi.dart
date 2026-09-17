import 'dart:convert';
import 'dart:io';

void main() async {
  // Current database
  final currentFile = File('assets/database/Libya/banghazi.json');
  var content = await currentFile.readAsString();
  content = content.replaceAll(',]', ']');
  final currentData = jsonDecode(content) as List;

  for (final item in currentData) {
    if (item['date'] == '08-31') {
      print('Current DB (banghazi.json):');
      print('  Fajr: ${item["fajr"]}');
      print('  Sunrise: ${item["sunrise"]}');
      print('  Dhuhr: ${item["dhuhr"]}');
      print('  Asr: ${item["asr"]}');
      print('  Maghrib: ${item["maghrib"]}');
      print('  Isha: ${item["isha"]}');
      break;
    }
  }

  // APK original
  final result = await Process.run('unzip', [
    '-p',
    'C:/Users/Admin/Desktop/MuezzinLibya_v3.3.1_G_Universal_AllDevices.apk',
    'assets/flutter_assets/assets/database/Libya/banghazi.json'
  ]);
  if (result.exitCode == 0) {
    final apkData = jsonDecode(result.stdout.toString()) as List;
    for (final item in apkData) {
      if (item['date'] == '08-31') {
        print('');
        print('APK Original (MuezzinLibya v3.3.1):');
        print('  Fajr: ${item["fajr"]}');
        print('  Sunrise: ${item["sunrise"]}');
        print('  Dhuhr: ${item["dhuhr"]}');
        print('  Asr: ${item["asr"]}');
        print('  Maghrib: ${item["maghrib"]}');
        print('  Isha: ${item["isha"]}');
        break;
      }
    }
  } else {
    print('Error extracting from APK: ${result.stderr}');
  }
}
