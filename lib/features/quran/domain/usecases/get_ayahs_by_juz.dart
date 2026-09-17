import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/ayah.dart';
import '../repositories/quran_repository.dart';

class GetAyahsByJuz implements UseCase<List<Ayah>, int> {
  final QuranRepository repository;

  GetAyahsByJuz(this.repository);

  @override
  Future<Either<Failure, List<Ayah>>> call(int juzNumber) async {
    return await repository.getAyahsByJuz(juzNumber);
  }
}
