import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/ayah.dart';
import '../../domain/entities/surah.dart';
import '../../domain/repositories/quran_repository.dart';
import '../datasources/quran_local_data_source.dart';

import '../../domain/entities/bookmark.dart';

class QuranRepositoryImpl implements QuranRepository {
  final QuranLocalDataSource localDataSource;

  QuranRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, List<Surah>>> getSurahs() async {
    try {
      final surahs = await localDataSource.getSurahs();
      return Right(surahs);
    } catch (e) {
      return Left(DatabaseFailure());
    }
  }

  @override
  Future<Either<Failure, List<Ayah>>> getAyahsBySurah(int surahId) async {
    try {
      final ayahs = await localDataSource.getAyahsBySurah(surahId);
      return Right(ayahs);
    } catch (e) {
      return Left(DatabaseFailure());
    }
  }

  @override
  Future<Either<Failure, List<Ayah>>> getAyahsByJuz(int juzNumber) async {
    try {
      final ayahs = await localDataSource.getAyahsByJuz(juzNumber);
      return Right(ayahs);
    } catch (e) {
      return Left(DatabaseFailure());
    }
  }

  @override
  Future<Either<Failure, List<Ayah>>> searchAyahs(String query) async {
    try {
      final ayahs = await localDataSource.searchAyahs(query);
      return Right(ayahs);
    } catch (e) {
      return Left(DatabaseFailure());
    }
  }

  @override
  Future<Either<Failure, List<Bookmark>>> getBookmarks() async {
    try {
      final bookmarks = await localDataSource.getBookmarks();
      return Right(bookmarks);
    } catch (e) {
      return Left(DatabaseFailure());
    }
  }

  @override
  Future<Either<Failure, void>> addBookmark(Bookmark bookmark) async {
    try {
      await localDataSource.addBookmark(bookmark);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure());
    }
  }

  @override
  Future<Either<Failure, void>> removeBookmark(int surahId, int ayahNumber) async {
    try {
      await localDataSource.removeBookmark(surahId, ayahNumber);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure());
    }
  }
}
