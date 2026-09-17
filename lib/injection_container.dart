import 'package:get_it/get_it.dart';
import 'features/quran/data/datasources/quran_local_data_source.dart';
import 'features/quran/data/repositories/quran_repository_impl.dart';
import 'features/quran/domain/repositories/quran_repository.dart';
import 'features/quran/domain/usecases/get_surahs.dart';
import 'features/quran/domain/usecases/get_ayahs_by_surah.dart';
import 'features/quran/domain/usecases/get_ayahs_by_juz.dart';
import 'features/quran/domain/usecases/search_ayahs.dart';
import 'features/quran/presentation/bloc/quran_bloc.dart';
import 'features/quran/presentation/bloc/quran_audio_bloc.dart';

import 'features/quran/data/datasources/quran_settings_data_source.dart';
import 'features/quran/data/datasources/audio_player_service.dart';
import 'features/quran/data/datasources/quran_download_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

Future<void> init() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  // Features - Quran
  // Bloc
  sl.registerFactory(() => QuranBloc(
        getSurahs: sl(),
        getAyahsBySurah: sl(),
        getAyahsByJuz: sl(),
        searchAyahs: sl(),
        settingsDataSource: sl(),
        repository: sl(),
      ));
  sl.registerFactory(() => QuranAudioBloc(audioService: sl()));

  // Services
  sl.registerLazySingleton<QuranSettingsDataSource>(
    () => QuranSettingsDataSourceImpl(sharedPreferences: sl()),
  );
  sl.registerLazySingleton(() => AudioPlayerService());
  sl.registerLazySingleton(() => QuranDownloadService());

  // Use cases
  sl.registerLazySingleton(() => GetSurahs(sl()));
  sl.registerLazySingleton(() => GetAyahsBySurah(sl()));
  sl.registerLazySingleton(() => GetAyahsByJuz(sl()));
  sl.registerLazySingleton(() => SearchAyahs(sl()));

  // Repository
  sl.registerLazySingleton<QuranRepository>(
    () => QuranRepositoryImpl(localDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<QuranLocalDataSource>(
    () => QuranLocalDataSourceImpl(),
  );
}
