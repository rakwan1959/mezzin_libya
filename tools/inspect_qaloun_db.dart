import 'dart:io';

void main() {
  // Let's check how verses table in quran_qaloun.db defines juz boundaries
  // We can search for the byte patterns in quran_qaloun.db or extract with a script!
  final file = File('assets/database/quran/quran_qaloun.db');
  print('quran_qaloun.db size: ${file.lengthSync()}');
}
