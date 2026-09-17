import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('inspect quran_qaloun.db', () async {
    final db = await databaseFactory.openDatabase('assets/database/quran/quran_qaloun.db');

    // Total verses count
    final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM verses');
    print('Total verses in quran_qaloun.db: ${countResult.first['count']}');

    // Total surahs count
    final surahCount = await db.rawQuery('SELECT COUNT(*) as count FROM surahs');
    print('Total surahs: ${surahCount.first['count']}');

    // Check Juz boundaries in verses table
    final juzBounds = await db.rawQuery('''
      SELECT juz, MIN(surah) as min_surah, MIN(number) as min_number,
             MAX(surah) as max_surah, MAX(number) as max_number,
             COUNT(*) as verse_count
      FROM verses
      GROUP BY juz
      ORDER BY juz ASC
    ''');
    print('Juz boundaries from verses table:');
    for (final j in juzBounds) {
      print('  Juz ${j['juz']}: start=${j['min_surah']}:${j['min_number']}, end=${j['max_surah']}:${j['max_number']} (verses=${j['verse_count']})');
    }

    // Let's also check for each juz what the first verse is (surah and number where this juz starts):
    print('\nExact starting verse for each Juz (where verse is first with that juz):');
    for (int j = 1; j <= 30; j++) {
      final firstV = await db.rawQuery('''
        SELECT surah, number, text
        FROM verses
        WHERE juz = ?
        ORDER BY id ASC
        LIMIT 1
      ''', [j]);
      final lastV = await db.rawQuery('''
        SELECT surah, number, text
        FROM verses
        WHERE juz = ?
        ORDER BY id DESC
        LIMIT 1
      ''', [j]);
      if (firstV.isNotEmpty && lastV.isNotEmpty) {
        final f = firstV.first;
        final l = lastV.first;
        print('Juz $j: Start = Surah ${f['surah']} Ayah ${f['number']}, End = Surah ${l['surah']} Ayah ${l['number']}');
      }
    }

    await db.close();
  });
}
