import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import 'package:muezzin_libya_app/features/quran/data/datasources/audio_player_service.dart';
import 'package:muezzin_libya_app/features/quran/data/datasources/quran_local_data_source.dart';
import 'package:muezzin_libya_app/features/quran/data/datasources/quran_settings_data_source.dart';
import 'package:muezzin_libya_app/features/quran/data/models/ayah_model.dart';
import 'package:muezzin_libya_app/features/quran/data/models/surah_model.dart';
import 'package:muezzin_libya_app/features/quran/data/repositories/quran_repository_impl.dart';
import 'package:muezzin_libya_app/features/quran/domain/entities/bookmark.dart';
import 'package:muezzin_libya_app/features/quran/domain/repositories/quran_repository.dart';
import 'package:muezzin_libya_app/features/quran/domain/usecases/get_ayahs_by_juz.dart';
import 'package:muezzin_libya_app/features/quran/domain/usecases/get_ayahs_by_surah.dart';
import 'package:muezzin_libya_app/features/quran/domain/usecases/get_surahs.dart';
import 'package:muezzin_libya_app/features/quran/domain/usecases/search_ayahs.dart';
import 'package:muezzin_libya_app/features/quran/presentation/bloc/quran_audio_bloc.dart';
import 'package:muezzin_libya_app/features/quran/presentation/bloc/quran_bloc.dart';
import 'package:muezzin_libya_app/features/quran/presentation/pages/surah_list_page.dart';
import 'package:muezzin_libya_app/injection_container.dart';

class _FakeQuranSettings implements QuranSettingsDataSource {
  @override
  double getFontSize() => 22.0;
  @override
  String getReadingMode() => "black";
  @override
  String getFontWeight() => "semi_bold";
  @override
  String getReciter() => "ar.sudais";
  @override
  String getSelectedTafsir() => "ibnkathir";
  @override
  double getBrightness() => 1.0;
  @override
  String getFontFamily() => "QuranUthmanicHafs";
  @override
  Map<String, int>? getLastRead() => null;
  @override
  Future<void> saveLastRead(int surahId, int ayahNumber) async {}
  @override
  Future<void> clearLastRead() async {}
  @override
  Future<void> setFontSize(double size) async {}
  @override
  Future<void> setReadingMode(String mode) async {}
  @override
  Future<void> setFontWeight(String weight) async {}
  @override
  Future<void> setBrightness(double brightness) async {}
  @override
  Future<void> setReciter(String reciter) async {}
  @override
  Future<void> setSelectedTafsir(String tafsir) async {}
  @override
  Future<void> setFontFamily(String family) async {}
}

class _FakeQuranLocal implements QuranLocalDataSource {
  final List<SurahModel> surahs;
  final List<AyahModel> ayahs;
  _FakeQuranLocal(this.surahs, this.ayahs);

  @override
  Future<List<SurahModel>> getSurahs() async => surahs;

  @override
  Future<List<AyahModel>> getAyahsBySurah(int surahId) async => ayahs;

  @override
  Future<List<Bookmark>> getBookmarks() async => [];

  @override
  Future<void> addBookmark(Bookmark bookmark) async {}
  @override
  Future<void> removeBookmark(int surahId, int ayahNumber) async {}
  @override
  Future<List<AyahModel>> getAyahsByJuz(int juzNumber) async => [];
  @override
  Future<List<AyahModel>> searchAyahs(String query) async => [];
  @override
  Future<String> fetchTafsir(int surahId, int ayahNumber, String identifier) async => "";
}

class _FakeAudioService extends AudioPlayerService {
  final _stateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration?>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();

  @override
  Stream<PlayerState> get playerStateStream => _stateController.stream;
  @override
  Stream<Duration?> get positionStream => _positionController.stream;
  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Future<void> playAyah({
    required int surahId,
    required int ayahNumber,
    required String reciterIdentifier,
    required String surahName,
  }) async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration position) async {}
}

Future<void> _registerDependencies() async {
  // GetIt.reset() غير متزامن — يُستدعى مع await
  await sl.reset();
  sl.registerLazySingleton<QuranSettingsDataSource>(() => _FakeQuranSettings());

  final surahs = [
    const SurahModel(
      id: 1,
      name: "الفاتحة",
      revelationType: "مكية",
      ayahsCount: 7,
      nameArabic: "الفاتحة",
    ),
    const SurahModel(
      id: 2,
      name: "البقرة",
      revelationType: "مدنية",
      ayahsCount: 286,
      nameArabic: "البقرة",
    ),
  ];
  final ayahs = [
    const AyahModel(
      id: 1,
      surahId: 1,
      ayahNumber: 1,
      text: "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ",
      textUthmani: "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ",
      page: 1,
      juz: 1,
    ),
  ];
  sl.registerLazySingleton<QuranLocalDataSource>(
    () => _FakeQuranLocal(surahs, ayahs),
  );
  sl.registerLazySingleton<QuranRepository>(
    () => QuranRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton(() => GetSurahs(sl()));
  sl.registerLazySingleton(() => GetAyahsBySurah(sl()));
  sl.registerLazySingleton(() => GetAyahsByJuz(sl()));
  sl.registerLazySingleton(() => SearchAyahs(sl()));
  sl.registerFactory(
    () => QuranBloc(
      getSurahs: sl(),
      getAyahsBySurah: sl(),
      getAyahsByJuz: sl(),
      searchAyahs: sl(),
      settingsDataSource: sl(),
      repository: sl(),
    ),
  );
}

Widget _buildApp() {
  return BlocProvider<QuranAudioBloc>(
    create: (_) => QuranAudioBloc(audioService: _FakeAudioService()),
    child: BlocProvider<QuranBloc>(
      create: (_) => sl<QuranBloc>(),
      child: const MaterialApp(home: SurahListPage()),
    ),
  );
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'الشاشة تفتح على قائمة السور وحدها (كل سورة على حدة) بلا بطاقة «سور | أجزاء»',
    (tester) async {
      await _registerDependencies();

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // عنوان الشاشة = قائمة السور
      expect(find.text('سور القرآن الكريم'), findsOneWidget);
      // لا بطاقة تبديل مقسمة أعلى القائمة، ولا أي نص لأجزاء القرآن
      expect(find.text('أجزاء القرآن الكريم'), findsNothing);
      expect(find.text('الجزء 1'), findsNothing);

      // قائمة السور تظهر (سورة الفاتحة أولاً ثم البقرة)
      expect(find.text('سورة الفاتحة'), findsOneWidget);
      expect(find.text('سورة البقرة'), findsOneWidget);
    },
  );

  testWidgets(
    'زر «أجزاء القرآن الكريم» في الشريط العلوي يعرض الأجزاء الثلاثين',
    (tester) async {
      await _registerDependencies();

      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('أجزاء القرآن الكريم'));
      await tester.pumpAndSettle();

      // العنوان صار للأجزاء، والسور وحدها اختفت من القائمة
      expect(find.text('أجزاء القرآن الكريم'), findsOneWidget);
      expect(find.text('سورة الفاتحة'), findsNothing);

      // أول الأجزاء «الجزء 1» بنطاقه المسند إلى أسماء السور
      expect(find.text('الجزء 1'), findsOneWidget);
      expect(find.textContaining('سورة الفاتحة'), findsWidgets);
      expect(find.textContaining('إلى آية'), findsWidgets);
    },
  );

  testWidgets('زر «العودة إلى قائمة السور» يرجع إلى السور', (tester) async {
    await _registerDependencies();

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('أجزاء القرآن الكريم'));
    await tester.pumpAndSettle();
    expect(find.text('الجزء 1'), findsOneWidget);

    await tester.tap(find.byTooltip('العودة إلى قائمة السور'));
    await tester.pumpAndSettle();

    expect(find.text('سورة الفاتحة'), findsOneWidget);
    expect(find.text('الجزء 1'), findsNothing);
  });
}