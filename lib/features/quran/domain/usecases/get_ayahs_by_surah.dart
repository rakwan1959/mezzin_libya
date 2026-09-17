import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/ayah.dart';
import '../repositories/quran_repository.dart';

class GetAyahsBySurah implements UseCase<List<Ayah>, int> {
  final QuranRepository repository;

  GetAyahsBySurah(this.repository);

  @override
  Future<Either<Failure, List<Ayah>>> call(int surahId) async {
    return await repository.getAyahsBySurah(surahId);
  }
}
