import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/ayah.dart';
import '../repositories/quran_repository.dart';

class SearchAyahs implements UseCase<List<Ayah>, String> {
  final QuranRepository repository;

  SearchAyahs(this.repository);

  @override
  Future<Either<Failure, List<Ayah>>> call(String query) async {
    return await repository.searchAyahs(query);
  }
}
