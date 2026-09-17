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
import 'package:muezzin_libya_app/features/quran/domain/entities/bookmark.dart';
import 'package:muezzin_libya_app/features/quran/domain/entities/surah.dart';
import 'package:muezzin_libya_app/features/quran/presentation/bloc/quran_audio_bloc.dart';
import 'package:muezzin_libya_app/features/quran/presentation/pages/quran_view_page.dart';
import 'package:muezzin_libya_app/injection_container.dart';

class _FakeQuranSettings implements QuranSettingsDataSource {
  @override
  double getFontSize() => 22.0;
  @override
  String getReadingMode() => "white";
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

class _FakeQuranLocal implements QuranLocalDataSource {
  final List<AyahModel> ayahs;
  _FakeQuranLocal(this.ayahs);

  @override
  Future<List<AyahModel>> getAyahsBySurah(int surahId) async => ayahs;

  @override
  Future<List<SurahModel>> getSurahs() async => [];

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

AyahModel _ayah(int id, int number, int juz) {
  return AyahModel(
    id: id,
    surahId: 2,
    ayahNumber: number,
    text: 'نص الآية $number',
    textUthmani: 'نص الآية $number',
    page: 1,
    juz: juz,
  );
}

const _surahBaqarah = Surah(
  id: 2,
  name: "البقرة",
  revelationType: "مدنية",
  ayahsCount: 286,
  nameArabic: "البقرة",
);

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('يعرض فاصل «جزء ١» الذهبي عند حدود الأجزاء داخل السورة', (tester) async {
    // GetIt.reset() غير متزامن، لذا يُستدعى مع await قبل التسجيل
    await sl.reset();
    sl.registerLazySingleton<QuranSettingsDataSource>(() => _FakeQuranSettings());
    // آخر آية في الجزء الأول (ج1) ثم أول آية في الجزء الثاني (ج2)
    sl.registerLazySingleton<QuranLocalDataSource>(
      () => _FakeQuranLocal([
        _ayah(1, 139, 1),
        _ayah(2, 140, 1),
        _ayah(3, 141, 2),
        _ayah(4, 142, 2),
      ]),
    );

    await tester.pumpWidget(
      BlocProvider<QuranAudioBloc>(
        create: (_) => QuranAudioBloc(audioService: _FakeAudioService()),
        child: const MaterialApp(home: QuranViewPage(surah: _surahBaqarah)),
      ),
    );
    await tester.pumpAndSettle();

    // يظهر فاصل «جزء ١» مرة واحدة بين آيتي (140) و (141)
    expect(find.text('جزء ١'), findsOneWidget);

    // يظهر بخط ذهبي عريض
    final Text markerText = tester.widget(find.text('جزء ١'));
    expect(markerText.style?.fontWeight, FontWeight.bold);
  });

  testWidgets('لا يظهر فاصل جزء عندما تكون كل الآيات في نفس الجزء', (tester) async {
    await sl.reset();
    sl.registerLazySingleton<QuranSettingsDataSource>(() => _FakeQuranSettings());
    sl.registerLazySingleton<QuranLocalDataSource>(
      () => _FakeQuranLocal([
        _ayah(1, 1, 1),
        _ayah(2, 2, 1),
        _ayah(3, 3, 1),
      ]),
    );

    await tester.pumpWidget(
      BlocProvider<QuranAudioBloc>(
        create: (_) => QuranAudioBloc(audioService: _FakeAudioService()),
        child: const MaterialApp(home: QuranViewPage(surah: _surahBaqarah)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('جزء '), findsNothing);
  });
}