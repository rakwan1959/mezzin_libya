import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/surah.dart';
import '../entities/ayah.dart';
import '../entities/bookmark.dart';

abstract class QuranRepository {
  Future<Either<Failure, List<Surah>>> getSurahs();
  Future<Either<Failure, List<Ayah>>> getAyahsBySurah(int surahId);
  Future<Either<Failure, List<Ayah>>> getAyahsByJuz(int juzNumber);
  Future<Either<Failure, List<Ayah>>> searchAyahs(String query);

  // Bookmarks
  Future<Either<Failure, List<Bookmark>>> getBookmarks();
  Future<Either<Failure, void>> addBookmark(Bookmark bookmark);
  Future<Either<Failure, void>> removeBookmark(int surahId, int ayahNumber);
}
