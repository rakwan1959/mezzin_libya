import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/surah.dart';
import '../repositories/quran_repository.dart';

class GetSurahs implements UseCase<List<Surah>, NoParams> {
  final QuranRepository repository;

  GetSurahs(this.repository);

  @override
  Future<Either<Failure, List<Surah>>> call(NoParams params) async {
    return await repository.getSurahs();
  }
}
