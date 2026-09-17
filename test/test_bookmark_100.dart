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

class _FakeSettings implements QuranSettingsDataSource {
  int? lastSavedSurah;
  int? lastSavedAyah;

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
  Map<String, int>? getLastRead() => lastSavedSurah != null ? {"surahId": lastSavedSurah!, "ayahNumber": lastSavedAyah!} : null;
  @override
  Future<void> saveLastRead(int surahId, int ayahNumber) async {
    lastSavedSurah = surahId;
    lastSavedAyah = ayahNumber;
    print('saveLastRead called with surahId: $surahId, ayahNumber: $ayahNumber');
  }
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

class _FakeAudio extends AudioPlayerService {
  final _stateController = StreamController<PlayerState>.broadcast();
  final _posController = StreamController<Duration?>.broadcast();
  final _durController = StreamController<Duration?>.broadcast();
  @override
  Stream<PlayerState> get playerStateStream => _stateController.stream;
  @override
  Stream<Duration?> get positionStream => _posController.stream;
  @override
  Stream<Duration?> get durationStream => _durController.stream;
  @override
  Future<void> playAyah({required int surahId, required int ayahNumber, required String reciterIdentifier, required String surahName}) async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration position) async {}
}

class _FakeLocal implements QuranLocalDataSource {
  final List<AyahModel> ayahs;
  final List<Bookmark> bookmarks = [];
  _FakeLocal(this.ayahs);
  @override
  Future<List<AyahModel>> getAyahsBySurah(int surahId) async => ayahs;
  @override
  Future<List<SurahModel>> getSurahs() async => [];
  @override
  Future<List<Bookmark>> getBookmarks() async => bookmarks;
  @override
  Future<void> addBookmark(Bookmark b) async {
    bookmarks.add(b);
    print('addBookmark called: surah ${b.surahId}, ayah ${b.ayahNumber}');
  }
  @override
  Future<void> removeBookmark(int sId, int aNo) async {}
  @override
  Future<List<AyahModel>> getAyahsByJuz(int j) async => [];
  @override
  Future<List<AyahModel>> searchAyahs(String q) async => [];
  @override
  Future<String> fetchTafsir(int s, int a, String id) async => "";
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Test bookmarking ayah > 100', (tester) async {
    await sl.reset();
    final fakeSettings = _FakeSettings();
    sl.registerLazySingleton<QuranSettingsDataSource>(() => fakeSettings);

    // Create 150 ayahs with realistic lengths
    final ayahs = List.generate(150, (i) {
      final num = i + 1;
      return AyahModel(
        id: num,
        surahId: 2,
        ayahNumber: num,
        text: 'ذَٰلِكَ الْكِتَابُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى لِّلْمُتَّقِينَ آية رقم $num نص تجريبي طويل بما فيه الكفاية لعدة أسطر في العرض القرآني ',
        textUthmani: 'ذَٰلِكَ الْكِتَابُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى لِّلْمُتَّقِينَ آية رقم $num نص تجريبي طويل بما فيه الكفاية لعدة أسطر في العرض القرآني ',
        page: (num ~/ 10) + 1,
        juz: num <= 140 ? 1 : 2,
      );
    });

    final fakeLocal = _FakeLocal(ayahs);
    sl.registerLazySingleton<QuranLocalDataSource>(() => fakeLocal);
    sl.registerLazySingleton<AudioPlayerService>(() => _FakeAudio());

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => QuranAudioBloc(audioService: sl<AudioPlayerService>())),
        ],
        child: const MaterialApp(
          home: QuranViewPage(
            surah: Surah(id: 2, name: 'البقرة', revelationType: 'مدنية', ayahsCount: 286, nameArabic: 'البقرة'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable);
    await tester.drag(scrollable, const Offset(0, -35000));
    await tester.pumpAndSettle();

    final bookmarkBtn = find.byIcon(Icons.bookmark_add_rounded);
    if (bookmarkBtn.evaluate().isNotEmpty) {
      await tester.tap(bookmarkBtn);
      await tester.pumpAndSettle();
    } else {
      final rmBtn = find.byIcon(Icons.bookmark_rounded);
      await tester.tap(rmBtn);
      await tester.pumpAndSettle();
    }

    print('Result after 35000 scroll: lastSavedAyah = ${fakeSettings.lastSavedAyah}');

    // Test drag to 70,000
    await tester.drag(scrollable, const Offset(0, -35000));
    await tester.pumpAndSettle();

    if (bookmarkBtn.evaluate().isNotEmpty) {
      await tester.tap(bookmarkBtn);
      await tester.pumpAndSettle();
    } else {
      final rmBtn = find.byIcon(Icons.bookmark_rounded);
      await tester.tap(rmBtn);
      await tester.pumpAndSettle();
    }

    print('Result after 70000 scroll: lastSavedAyah = ${fakeSettings.lastSavedAyah}');

  });
}
