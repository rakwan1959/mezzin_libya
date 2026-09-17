import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class UserDatabaseHelper {
  static Database? _database;
  static const String tableName = 'bookmarks';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'user_data.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            surahId INTEGER,
            ayahNumber INTEGER,
            surahName TEXT,
            createdAt TEXT,
            UNIQUE(surahId, ayahNumber)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // إزالة العلامات المكررة (نفس السورة ونفس الآية) ثم فرض التفرد
          // حتى يعمل ConflictAlgorithm.replace في addBookmark بشكل صحيح
          await db.execute('''
            DELETE FROM $tableName
            WHERE id NOT IN (
              SELECT MIN(id) FROM $tableName GROUP BY surahId, ayahNumber
            )
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_bookmarks_unique_surah_ayah
            ON $tableName (surahId, ayahNumber)
          ''');
        }
      },
    );
  }
}
