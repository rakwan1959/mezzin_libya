import 'dart:io';

void main() {
  // Let's inspect the actual verses in quran_qaloun.db
  // We can read verses from database/quran.qaloun.json or database/quran.qaloun2.json to see the exact structure!
  final file = File('database/quran.qaloun.json');
  if (file.existsSync()) {
    print('Found database/quran.qaloun.json, size: ${file.lengthSync()}');
  }
  final file2 = File('database/quran.qaloun2.json');
  if (file2.existsSync()) {
    print('Found database/quran.qaloun2.json, size: ${file2.lengthSync()}');
  }
}
