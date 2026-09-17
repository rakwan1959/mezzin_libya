import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await databaseFactory.openDatabase('assets/database/quran/quran_qaloun.db');
  
  final countRes = await db.rawQuery('SELECT surah, count(*), max(number) FROM verses GROUP BY surah ORDER BY surah ASC');
  for (final row in countRes) {
    print('Surah ${row['surah']}: count=${row['count(*)']}, max=${row['max(number)']}');
  }
  await db.close();
}
