import 'dart:convert';
import 'dart:io';

void main() async {
  // Step 1: Extract all files from APK
  print('Extracting from APK...');
  final extractDir = Directory('apk_extracted');
  if (!extractDir.existsSync()) extractDir.createSync();
  
  final result = await Process.run('unzip', [
    '-o',
    'C:/Users/Admin/Desktop/MuezzinLibya_v3.3.1_G_Universal_AllDevices.apk',
    'assets/flutter_assets/assets/database/Libya/*',
    '-d', 'apk_extracted'
  ]);
  
  if (result.exitCode != 0) {
    print('Error: ${result.stderr}');
    return;
  }
  
  // Step 2: Compare each file
  final apkDir = Directory('apk_extracted/assets/flutter_assets/assets/database/Libya');
  final currentDir = Directory('assets/database/Libya');
  
  if (!apkDir.existsSync()) {
    print('APK directory not found!');
    return;
  }
  
  int totalDiffs = 0;
  Map<String, int> cityDiffs = {};
  
  for (final file in apkDir.listSync().whereType<File>()) {
    final fileName = file.uri.pathSegments.last;
    final currentFile = File('${currentDir.path}/$fileName');
    
    if (!currentFile.existsSync()) {
      print('MISSING in current DB: $fileName');
      continue;
    }
    
    try {
      var apkContent = await file.readAsString();
      apkContent = utf8.decode(apkContent.codeUnits.where((c) => c < 128 || c > 191).toList(), allowMalformed: true);
      if (apkContent.startsWith('\ufeff')) apkContent = apkContent.substring(1);
      final apkData = jsonDecode(apkContent) as List;
      
      var currentContent = await currentFile.readAsString();
      currentContent = currentContent.replaceAll(',]', ']');
      final currentData = jsonDecode(currentContent) as List;
      
      int fileDiffs = 0;
      for (int i = 0; i < apkData.length && i < currentData.length; i++) {
        final apk = apkData[i];
        final curr = currentData[i];
        
        for (final key in ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']) {
          if (apk[key] != curr[key]) {
            fileDiffs++;
            if (fileDiffs <= 3) {
              print('  $fileName ${apk["date"]} $key: current=${curr[key]} apk=${apk[key]}');
            }
          }
        }
      }
      
      if (fileDiffs > 0) {
        totalDiffs += fileDiffs;
        cityDiffs[fileName] = fileDiffs;
        if (fileDiffs > 3) {
          print('  $fileName: ... and ${fileDiffs - 3} more differences');
        }
      }
    } catch (e) {
      print('Error parsing $fileName: $e');
    }
  }
  
  print('\n=== Summary ===');
  print('Total field differences: $totalDiffs');
  print('Cities with differences: ${cityDiffs.length}');
  cityDiffs.forEach((k, v) => print('  $k: $v'));
  
  // Cleanup
  await Process.run('rm', ['-rf', 'apk_extracted']);
}
