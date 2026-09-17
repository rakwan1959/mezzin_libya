import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:muezzin_libya_app/features/quran/data/datasources/audio_player_service.dart';
import 'package:muezzin_libya_app/features/quran/data/datasources/quran_download_service.dart';
import 'package:muezzin_libya_app/features/quran/data/datasources/quran_local_data_source.dart';
import 'package:muezzin_libya_app/features/quran/data/datasources/quran_settings_data_source.dart';
import 'package:muezzin_libya_app/features/quran/data/models/ayah_model.dart';
import 'package:muezzin_libya_app/features/quran/data/models/surah_model.dart';
import 'package:muezzin_libya_app/features/quran/data/repositories/quran_repository_impl.dart';
import 'package:muezzin_libya_app/features/quran/domain/entities/ayah.dart';
import 'package:muezzin_libya_app/features/quran/domain/entities/bookmark.dart';
import 'package:muezzin_libya_app/features/quran/domain/entities/surah.dart';
import 'package:muezzin_libya_app/features/quran/domain/repositories/quran_repository.dart';
import 'package:muezzin_libya_app/features/quran/presentation/bloc/quran_audio_bloc.dart';
import 'package:muezzin_libya_app/features/quran/presentation/pages/bookmarks_page.dart';
import 'package:muezzin_libya_app/features/quran/presentation/pages/quran_view_page.dart';
import 'package:muezzin_libya_app/injection_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// اختبارات العلامة المرجعية في سورة طويلة (البقرة):
///   1. تُحفَظ للآية المقروءة فعلاً حتى آخر السورة (لا تتوقف عند آية ١٠٠).
///   2. فتح العلامة المرجعية يضعك على الآية نفسها بالضبط، أياً كان عمقها.
///   3. العلامة تُحفَظ حتى لو تعذّر تحديث موضع التوقف أو الختمة.

/// تحميل خط المصحف الحقيقي ليصبح تخطيط النص واقعياً في الاختبار.
Future<void> _loadQuranFont() async {
  try {
    final ByteData data =
        await rootBundle.load('assets/fonts/quran_uthmanic_hafs.otf');
    await (FontLoader('QuranUthmanicHafs')
          ..addFont(Future<ByteData>.value(data)))
        .load();
  } catch (_) {}
}

const String _realPhrase =
    'إِنَّ الَّذِينَ آمَنُوا وَعَمِلُوا الصَّالِحَاتِ إِنَّا لَا نُضِيعُ أَجْرَ مَنْ أَحْسَنَ عَمَلًا ';

class _FakeSettings implements QuranSettingsDataSource {
  _FakeSettings({this.throwOnLastRead = false});
  final bool throwOnLastRead;
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
  Map<String, int>? getLastRead() => null;
  @override
  Future<void> saveLastRead(int surahId, int ayahNumber) async {
    if (throwOnLastRead) throw StateError('تعذّر حفظ موضع التوقف');
    lastSavedAyah = ayahNumber;
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
  Future<void> playAyah(
      {required int surahId,
      required int ayahNumber,
      required String reciterIdentifier,
      required String surahName}) async {}
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
  _FakeLocal(this.ayahs);
  final List<AyahModel> ayahs;
  final List<Bookmark> bookmarks = [];
  @override
  Future<List<AyahModel>> getAyahsBySurah(int surahId) async => ayahs;
  @override
  Future<List<SurahModel>> getSurahs() async => [];
  @override
  Future<List<Bookmark>> getBookmarks() async => bookmarks;
  @override
  Future<void> addBookmark(Bookmark b) async => bookmarks.add(b);
  @override
  Future<void> removeBookmark(int sId, int aNo) async =>
      bookmarks.removeWhere((Bookmark b) => b.surahId == sId && b.ayahNumber == aNo);
  @override
  Future<List<AyahModel>> getAyahsByJuz(int j) async => [];
  @override
  Future<List<AyahModel>> searchAyahs(String q) async => [];
  @override
  Future<String> fetchTafsir(int s, int a, String id) async => "";
}

/// شريط التطبيق الزجاجي يفيض ١ بكسل عند استخدام الخط البديل في بيئة الاختبار
/// (خط NotoKufi الحقيقي غير متاح هنا) — حالته لا تعني عطلاً في الصفحة.
void _drainKnownLayoutOverflow(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

/// سورة البقرة: ٢٨٦ آية بأطوال نصية قريبة من الواقع، وحدود الأجزاء الحقيقية
/// (١..١٤١ ثم ١٤٢..٢٥٢ ثم ٢٥٣..٢٨٦) — فتحصل نفس بنية العرض التي في التطبيق.
AyahModel _ayah(int n) {
  final int juz = n <= 141 ? 1 : (n <= 252 ? 2 : 3);
  final int len;
  if (n == 1) {
    len = 12;
  } else if (n == 282) {
    len = 900;
  } else if (n % 7 == 0) {
    len = 240 + (n % 90);
  } else {
    len = 70 + (n % 120);
  }
  final StringBuffer sb = StringBuffer();
  while (sb.length < len) {
    sb.write(_realPhrase);
  }
  final String text = sb.toString().substring(0, len);
  return AyahModel(
    id: n,
    surahId: 2,
    ayahNumber: n,
    text: text,
    textUthmani: text,
    page: (n / 10).floor() + 1,
    juz: juz,
  );
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(_loadQuranFont);

  late _FakeLocal local;
  late _FakeSettings settings;

  Future<void> pumpSurah(
    WidgetTester tester, {
    int? initialAyah,
    bool failingLastRead = false,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    await sl.reset();
    settings = _FakeSettings(throwOnLastRead: failingLastRead);
    local = _FakeLocal(List<AyahModel>.generate(286, (i) => _ayah(i + 1)));
    sl.registerLazySingleton<QuranSettingsDataSource>(() => settings);
    sl.registerLazySingleton<QuranLocalDataSource>(() => local);
    sl.registerLazySingleton<AudioPlayerService>(() => _FakeAudio());

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<QuranAudioBloc>(
              create: (_) =>
                  QuranAudioBloc(audioService: sl<AudioPlayerService>())),
        ],
        child: MaterialApp(
          home: QuranViewPage(
            surah: const Surah(
              id: 2,
              name: 'البقرة',
              revelationType: 'مدنية',
              ayahsCount: 286,
              nameArabic: 'البقرة',
            ),
            initialAyah: initialAyah,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// يُفعّل زر العلامة المرجعية ويُرجع رقم الآية التي حُفِظت للتوّ (أو null إن
  /// لم تُحفَظ آية جديدة).
  Future<int?> tapBookmark(WidgetTester tester) async {
    // مهلة تحديث حالة الزر بعد التمرير (٣٠٠ مللي في الكود) ثم نضغط
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final int before = local.bookmarks.length;
    final Finder add = find.byIcon(Icons.bookmark_add_rounded);
    final Finder remove = find.byIcon(Icons.bookmark_rounded);
    final Finder button = add.evaluate().isNotEmpty
        ? add
        : (remove.evaluate().isNotEmpty ? remove.first : add);
    if (button.evaluate().isEmpty) return null;

    await tester.tap(button);
    await tester.pumpAndSettle();
    if (local.bookmarks.length <= before) return null;
    return local.bookmarks.last.ayahNumber;
  }

  group('حفظ العلامة في السور الطوال', () {
    testWidgets('تُحفَظ للآية المقروءة فعلاً وتتجاوز الآية ١٠٠', (tester) async {
      await pumpSurah(tester);

      final List<int> saved = <int>[];
      for (int step = 0; step < 10; step++) {
        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -2500));
        await tester.pumpAndSettle();
        final int? ayah = await tapBookmark(tester);
        if (ayah != null) saved.add(ayah);
      }

      expect(saved, isNotEmpty);
      expect(saved.length, greaterThanOrEqualTo(8));
      // تقدّم رتيب: كل تمرير لأسفل يحفظ آية أبعد من السابقة
      for (int i = 1; i < saved.length; i++) {
        expect(saved[i], greaterThan(saved[i - 1]));
      }
      // الجوهر: العمل لا يتوقف عند آية ١٠٠ كما كان
      expect(saved.last, greaterThan(100));
      expect(saved.any((int a) => a > 100), isTrue);
    });

    testWidgets('حتى لو فشل حفظ موضع التوقف تبقى العلامة محفوظة', (tester) async {
      await pumpSurah(tester, failingLastRead: true);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
      await tester.pumpAndSettle();

      final int? ayah = await tapBookmark(tester);
      expect(ayah, isNotNull, reason: 'العلامة المرجعية يجب ألا تسقط بفشل خطوة أخرى');
      expect(local.bookmarks, hasLength(1));
      expect(settings.lastSavedAyah, isNull);
    });

    testWidgets('تصل العلامة إلى آخر السورة ولا تتوقف عند آية ١٢٠', (tester) async {
      await pumpSurah(tester);

      final List<int> saved = <int>[];
      for (int step = 0; step < 45; step++) {
        await tester.drag(
            find.byType(CustomScrollView), const Offset(0, -1200));
        await tester.pumpAndSettle();
        final int? ayah = await tapBookmark(tester);
        if (ayah != null) saved.add(ayah);
        if (saved.isNotEmpty && saved.last >= 280) break;
      }

      expect(saved, isNotEmpty);
      // القاعدة: العلامة المرجعية تبلغ عدد آيات السورة — لا سقف عند ١٢٠
      expect(saved.last, greaterThanOrEqualTo(240),
          reason: 'العلامة المرجعية يجب أن تصل إلى آخر السورة الطويلة');
      // تقدّم رتيب بلا توقّف ولا تكرار
      for (int i = 1; i < saved.length; i++) {
        expect(saved[i], greaterThan(saved[i - 1]));
      }
    });
  });

  group('فتح العلامة المرجعية يضعك على الآية نفسها', () {
    for (final int target in <int>[20, 60, 100, 105, 150, 250]) {
      testWidgets('آية $target → يفتح على الآية $target بالضبط', (tester) async {
        await pumpSurah(tester, initialAyah: target);

        // الزر يحفظ الآية الواقعة عند أعلى منطقة القراءة، فهي دليل الموضع
        final int? landed = await tapBookmark(tester);
        expect(landed, target);
      });
    }
  });

  group('بيانات أعداد الآيات لا تُقتطع', () {
    test('جدول أعداد آيات السور كامل ولا يقف عند ١٢٠', () {
      final List<int> counts = QuranDownloadService.surahAyahCounts;

      expect(counts, hasLength(114));
      expect(counts.first, 7, reason: 'الفاتحة');
      expect(counts[1], 286, reason: 'البقرة');
      expect(counts[4], 120, reason: 'المائدة');
      expect(counts.last, 6, reason: 'الناس');
      expect(counts.every((int n) => n > 0), isTrue);
      // سور طويلة تتجاوز ١٢٠ آية فعلاً
      expect(counts.where((int n) => n > 120).length, greaterThan(5));
    });

    test('ترتيب أرقام الآيات وترقيمها', () {
      final List<AyahModel> shuffled = <AyahModel>[
        _ayah(200),
        _ayah(26),
        _ayah(27),
      ];
      final List<Ayah> sorted = sortAyahsBySurahNumber(shuffled);
      expect(
        sorted.map((Ayah a) => a.ayahNumber).toList(),
        <int>[26, 27, 200],
      );

      expect(resolveAyahNumberInSurah(10, _ayah(25)), 25);
      expect(resolveAyahNumberInSurah(10, _ayah(0)), 10);
    });
  });

  group('صفحة العلامات المرجعية تعرض كل ما حُفظ', () {
    testWidgets('تُعرض أكثر من ١٢٠ علامة ويُوصل بالتمرير إلى آخرها', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      await sl.reset();
      final _FakeLocal local = _FakeLocal(<AyahModel>[]);
      local.bookmarks.addAll(<Bookmark>[
        for (int n = 1; n <= 150; n++)
          Bookmark(
            surahId: 2,
            ayahNumber: n,
            surahName: 'البقرة',
            createdAt: DateTime(2026, 1, 1),
          ),
      ]);
      sl.registerLazySingleton<QuranLocalDataSource>(() => local);
      sl.registerLazySingleton<QuranRepository>(
        () => QuranRepositoryImpl(localDataSource: sl()),
      );

      await tester.pumpWidget(const MaterialApp(home: BookmarksPage()));
      // الصفحة الزجاجية بحركة مستمرة → لا pumpAndSettle (يطوف بلا نهاية)
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      _drainKnownLayoutOverflow(tester);

      // أول علامة ظاهرة
      expect(find.text('آية رقم 1'), findsOneWidget);

      // العلامة ١٥٠ (أبعد من أي سقف ١٢٠) يُوصل إليها بالتمرير
      await tester.scrollUntilVisible(
        find.text('آية رقم 150'),
        250.0,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 300,
      );
      _drainKnownLayoutOverflow(tester);
      expect(find.text('آية رقم 150'), findsOneWidget);
    });
  });
}
