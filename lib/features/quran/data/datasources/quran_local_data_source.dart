import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/surah_model.dart';
import '../models/ayah_model.dart';
import '../../domain/entities/bookmark.dart';
import '../../../../core/database/user_database_helper.dart';

abstract class QuranLocalDataSource {
  Future<List<SurahModel>> getSurahs();
  Future<List<AyahModel>> getAyahsBySurah(int surahId);
  Future<List<AyahModel>> getAyahsByJuz(int juzNumber);
  Future<List<AyahModel>> searchAyahs(String query);
  Future<List<Bookmark>> getBookmarks();
  Future<void> addBookmark(Bookmark bookmark);
  Future<void> removeBookmark(int surahId, int ayahNumber);
  Future<String> fetchTafsir(int surahId, int ayahNumber, String identifier);
}

class QuranLocalDataSourceImpl implements QuranLocalDataSource {
  static const String _dbAssetPath = 'assets/database/quran/quran_qaloun.db';
  static const String _dbFileName = 'quran_qaloun_v3.db';

  Database? _quranDb;
  final UserDatabaseHelper userDbHelper = UserDatabaseHelper();

  static ValueNotifier<String> syncStatus = ValueNotifier("");

  /// فتح (أو تهيئة) قاعدة بيانات القرآن المضمّنة
  Future<Database> get quranDatabase async {
    if (_quranDb != null && _quranDb!.isOpen) return _quranDb!;
    _quranDb = await _initQuranDb();
    return _quranDb!;
  }

  /// إزالة أي رموز أو أحرف زائدة قديمة من نهايات الآيات
  static String _cleanAyahText(String text) {
    return text.replaceAll(RegExp(r'[\uFC00-\uFD3D\uFD40-\uFDCF]'), '').trim();
  }

  /// نسخ قاعدة البيانات من assets إلى ذاكرة التطبيق إن لم تكن موجودة
  Future<Database> _initQuranDb() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String dbPath = join(appDocDir.path, _dbFileName);

    // نسخ الملف من assets إذا لم يكن موجوداً
    if (!await File(dbPath).exists()) {
      debugPrint('QuranDB: نسخ قاعدة البيانات المحدثة من assets...');
      final ByteData data = await rootBundle.load(_dbAssetPath);
      final List<int> bytes = data.buffer.asUint8List();
      await File(dbPath).writeAsBytes(bytes, flush: true);
      debugPrint('QuranDB: تم نسخ قاعدة البيانات بنجاح (${bytes.length} bytes)');
    }

    return await openDatabase(dbPath, readOnly: false);
  }

  @override
  Future<List<SurahModel>> getSurahs() async {
    final db = await quranDatabase;
    final List<Map<String, dynamic>> rows = await db.query(
      'surahs',
      orderBy: 'number ASC',
    );
    return rows.map((row) => SurahModel(
      id: row['number'] as int,
      name: row['name'] as String,
      revelationType: '',
      ayahsCount: row['verse_count'] as int,
      nameArabic: row['name'] as String,
    )).toList();
  }

  @override
  Future<List<AyahModel>> getAyahsBySurah(int surahId) async {
    final db = await quranDatabase;
    final List<Map<String, dynamic>> rows = await db.query(
      'verses',
      where: 'surah = ?',
      whereArgs: [surahId],
      orderBy: 'number ASC',
    );
    return rows.map((row) {
      final String rawText = (row['text'] ?? '') as String;
      final String cleanText = _cleanAyahText(rawText);
      return AyahModel(
        id: row['id'] as int,
        surahId: row['surah'] as int,
        ayahNumber: row['number'] as int,
        text: cleanText,
        textUthmani: cleanText,
        page: row['page'] as int,
        juz: row['juz'] as int,
      );
    }).toList();
  }

  @override
  Future<List<AyahModel>> getAyahsByJuz(int juzNumber) async {
    final db = await quranDatabase;
    final List<Map<String, dynamic>> rows = await db.query(
      'verses',
      where: 'juz = ?',
      whereArgs: [juzNumber],
      orderBy: 'surah ASC, number ASC',
    );
    return rows.map((row) {
      final String rawText = (row['text'] ?? '') as String;
      final String cleanText = _cleanAyahText(rawText);
      return AyahModel(
        id: row['id'] as int,
        surahId: row['surah'] as int,
        ayahNumber: row['number'] as int,
        text: cleanText,
        textUthmani: cleanText,
        page: row['page'] as int,
        juz: row['juz'] as int,
      );
    }).toList();
  }

  @override
  Future<List<AyahModel>> searchAyahs(String query) async {
    final db = await quranDatabase;
    final List<Map<String, dynamic>> rows = await db.query(
      'verses',
      where: 'text LIKE ? OR text_pure LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'surah ASC, number ASC',
    );
    return rows.map((row) {
      final String rawText = (row['text'] ?? '') as String;
      final String cleanText = _cleanAyahText(rawText);
      return AyahModel(
        id: row['id'] as int,
        surahId: row['surah'] as int,
        ayahNumber: row['number'] as int,
        text: cleanText,
        textUthmani: cleanText,
        page: row['page'] as int,
        juz: row['juz'] as int,
      );
    }).toList();
  }

  static Map<String, dynamic>? _cachedTafsirMap;

  @override
  Future<String> fetchTafsir(int surahId, int ayahNumber, String identifier) async {
    try {
      if (_cachedTafsirMap == null) {
        final jsonStr = await rootBundle.loadString('assets/database/quran/tafseer_map.json');
        _cachedTafsirMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      }
      final key = '$surahId:$ayahNumber';
      final text = _cachedTafsirMap?[key];
      if (text != null && text.toString().trim().isNotEmpty) {
        return text.toString().trim();
      }
    } catch (e) {
      debugPrint("fetchTafsir error: $e");
    }
    return "التفسير غير متوفر لهذه الآية حالياً.";
  }

  @override
  Future<List<Bookmark>> getBookmarks() async {
    final db = await userDbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('bookmarks');
    return maps.map((json) => Bookmark(
      id: json['id'],
      surahId: json['surahId'],
      ayahNumber: json['ayahNumber'],
      surahName: json['surahName'],
      createdAt: DateTime.parse(json['createdAt']),
    )).toList();
  }

  @override
  Future<void> addBookmark(Bookmark b) async {
    final db = await userDbHelper.database;
    await db.insert(
      'bookmarks',
      {
        'surahId': b.surahId,
        'ayahNumber': b.ayahNumber,
        'surahName': b.surahName,
        'createdAt': b.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> removeBookmark(int sId, int aNo) async {
    final db = await userDbHelper.database;
    await db.delete(
      'bookmarks',
      where: 'surahId = ? AND ayahNumber = ?',
      whereArgs: [sId, aNo],
    );
  }
}
