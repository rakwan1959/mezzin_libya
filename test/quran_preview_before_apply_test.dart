import 'dart:async';
import 'dart:io';

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
import 'package:muezzin_libya_app/features/quran/domain/entities/surah.dart';
import 'package:muezzin_libya_app/features/quran/domain/repositories/quran_repository.dart';
import 'package:muezzin_libya_app/features/quran/domain/usecases/get_ayahs_by_juz.dart';
import 'package:muezzin_libya_app/features/quran/domain/usecases/get_ayahs_by_surah.dart';
import 'package:muezzin_libya_app/features/quran/domain/usecases/get_surahs.dart';
import 'package:muezzin_libya_app/features/quran/domain/usecases/search_ayahs.dart';
import 'package:muezzin_libya_app/features/quran/presentation/bloc/quran_audio_bloc.dart';
import 'package:muezzin_libya_app/features/quran/presentation/bloc/quran_bloc.dart';
import 'package:muezzin_libya_app/features/quran/presentation/pages/quran_view_page.dart';
import 'package:muezzin_libya_app/features/quran/presentation/pages/surah_list_page.dart';
import 'package:muezzin_libya_app/injection_container.dart';

/// ── نمط «معاينة قبل التطبيق» في نوافذ القرآن ────────────────────────────────
///
///  المطلوب من المستخدم: استعمال النمط نفسه الذي في نافذة حجم خط الأحاديث —
///  يرى المستخدم **الخط وحجمه** في معاينة مباشرة، ولا يُحفظ شيء في التفضيلات
///  قبل الضغط على «تطبيق».
///
///  الحرس هنا من جهتين:
///    1. المصدر: نافذة إعدادات القراءة لا تنادي أي `set*` في أثناء التعديل،
///       واختيار الخط في نافذتي الخطوط يصير «مسودة» لا حفظ.
///    2. العرض الفعلي: فتح النافذتين، تعديل المسودة، والتأكد أن **لا كتابة**
///       قبل «تطبيق» ثم كتابة واحدة مطابقة بعده.

/// نصوص المعاينة — مميّزة حتى تُقاس بعينها لا بالخطأ.
const String _kFontsPreviewSample =
    'وَلَقَدْ يَسَّرْنَا ٱلْقُرْءَانَ لِلذِّكْرِ فَهَلْ مِن مُّدَّكِرٍ';
const String _kSettingsPreviewSample =
    'وَلَقَدْ يَسَّرْنَا ٱلْقُرْءَانَ لِلذِّكْرِ';

/// مصدر إعدادات يسجّل **كل** عملية حفظ — يجب أن يبقى فارغاً حتى «تطبيق».
class _RecordingSettings implements QuranSettingsDataSource {
  double fontSize = 22.0;
  String readingMode = "black";
  String fontWeight = "semi_bold";
  double brightness = 1.0;
  String reciter = "ar.sudais";
  String fontFamily = "QuranAmiriRegular";

  final List<String> writes = <String>[];

  @override
  double getFontSize() => fontSize;
  @override
  String getReadingMode() => readingMode;
  @override
  String getFontWeight() => fontWeight;
  @override
  double getBrightness() => brightness;
  @override
  String getReciter() => reciter;
  @override
  String getFontFamily() => fontFamily;
  @override
  String getSelectedTafsir() => "ibnkathir";
  @override
  Map<String, int>? getLastRead() => null;

  @override
  Future<void> setFontSize(double size) async {
    writes.add('size:${size.toInt()}');
    fontSize = size;
  }

  @override
  Future<void> setFontWeight(String weight) async {
    writes.add('weight:$weight');
    fontWeight = weight;
  }

  @override
  Future<void> setReadingMode(String mode) async {
    writes.add('mode:$mode');
    readingMode = mode;
  }

  @override
  Future<void> setBrightness(double value) async {
    writes.add('brightness:${value.toStringAsFixed(2)}');
    brightness = value;
  }

  @override
  Future<void> setReciter(String value) async {
    writes.add('reciter:$value');
    reciter = value;
  }

  @override
  Future<void> setFontFamily(String family) async {
    writes.add('font:$family');
    fontFamily = family;
  }

  @override
  Future<void> setSelectedTafsir(String tafsir) async {}
  @override
  Future<void> saveLastRead(int surahId, int ayahNumber) async {}
  @override
  Future<void> clearLastRead() async {}
}

class _FakeQuranLocal implements QuranLocalDataSource {
  @override
  Future<List<SurahModel>> getSurahs() async => <SurahModel>[
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

  @override
  Future<List<AyahModel>> getAyahsBySurah(int surahId) async => <AyahModel>[
        const AyahModel(
          id: 1,
          surahId: 2,
          ayahNumber: 1,
          text: "نص الآية الأولى",
          textUthmani: "نص الآية الأولى",
          page: 1,
          juz: 1,
        ),
      ];

  @override
  Future<List<Bookmark>> getBookmarks() async => <Bookmark>[];
  @override
  Future<void> addBookmark(Bookmark bookmark) async {}
  @override
  Future<void> removeBookmark(int surahId, int ayahNumber) async {}
  @override
  Future<List<AyahModel>> getAyahsByJuz(int juzNumber) async => <AyahModel>[];
  @override
  Future<List<AyahModel>> searchAyahs(String query) async => <AyahModel>[];
  @override
  Future<String> fetchTafsir(
          int surahId, int ayahNumber, String identifier) async =>
      "";
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

const _surahBaqarah = Surah(
  id: 2,
  name: "البقرة",
  revelationType: "مدنية",
  ayahsCount: 286,
  nameArabic: "البقرة",
);

/// GetIt.reset() غير متزامن — يُستدعى مع await قبل التسجيل.
Future<_RecordingSettings> _registerDependencies() async {
  await sl.reset();
  final settings = _RecordingSettings();
  sl.registerLazySingleton<QuranSettingsDataSource>(() => settings);
  sl.registerLazySingleton<QuranLocalDataSource>(() => _FakeQuranLocal());
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
  return settings;
}

Widget _buildSurahListPage() {
  return BlocProvider<QuranAudioBloc>(
    create: (_) => QuranAudioBloc(audioService: _FakeAudioService()),
    child: BlocProvider<QuranBloc>(
      create: (_) => sl<QuranBloc>(),
      child: const MaterialApp(home: SurahListPage()),
    ),
  );
}

Widget _buildQuranViewPage() {
  return BlocProvider<QuranAudioBloc>(
    create: (_) => QuranAudioBloc(audioService: _FakeAudioService()),
    child: const MaterialApp(home: QuranViewPage(surah: _surahBaqarah)),
  );
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('المصدر: لا حفظ قبل «تطبيق»', () {
    final String view = File(
      'lib/features/quran/presentation/pages/quran_view_page.dart',
    ).readAsStringSync();
    final String list = File(
      'lib/features/quran/presentation/pages/surah_list_page.dart',
    ).readAsStringSync();

    test('نافذة إعدادات القراءة لا تحفظ شيئاً في أثناء التعديل', () {
      final int start = view.indexOf('void _showSettingsSheet()');
      final int end = view.indexOf('Widget _buildSheetActionsBar(', start);

      expect(start, greaterThan(0));
      expect(end, greaterThan(start), reason: 'لم يُعثر على نهاية النافذة');

      final String sheet = view.substring(start, end);
      for (final String call in <String>[
        'setFontSize',
        'setFontWeight',
        'setReadingMode',
        'setBrightness',
        'setReciter',
      ]) {
        expect(
          sheet.contains(call),
          isFalse,
          reason: 'حفظ فوري داخل النافذة: $call',
        );
      }
      // وفيها معاينة مباشرة وشريط تطبيق
      expect(sheet.contains('_buildReadingPreview'), isTrue);
      expect(sheet.contains('_applyReadingSettings'), isTrue);
    });

    test('نافذتا الخطوط: الاختيار مسودة لا حفظ', () {
      for (final String source in <String>[view, list]) {
        expect(source.contains('معاينة قبل التطبيق'), isTrue);
        expect(
          RegExp(r'onTap: \(\) => setSheetState\(\(\) => draftFont = key\)')
              .hasMatch(source),
          isTrue,
          reason: 'اختيار الخط يجب أن يصير مسودة بلا حفظ',
        );
      }
    });
  });

  group('نافذة خطوط القرآن الكريم', () {
    testWidgets('تعرض الخط وحجمه، ولا تُحفظ قبل «تطبيق»', (tester) async {
      final settings = await _registerDependencies();

      await tester.pumpWidget(_buildSurahListPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('خطوط القرآن الكريم'));
      await tester.pumpAndSettle();

      // معاينة مباشرة بالخط المحفوظ وحجم القراءة المحفوظ (22)
      expect(find.text('معاينة قبل التطبيق'), findsOneWidget);
      Text preview() => tester.widget<Text>(find.text(_kFontsPreviewSample));
      expect(preview().style?.fontFamily, 'QuranAmiriRegular');
      expect(preview().style?.fontSize, 22.0);

      // اختيار خط آخر (أول عنصر ظاهر في القائمة): المعاينة تتغيّر ولا شيء
      // يُحفظ، والنافذة تبقى مفتوحة
      await tester.tap(find.text('مصحف المدينة (الرسم العثماني لحفص)'));
      await tester.pumpAndSettle();

      expect(preview().style?.fontFamily, 'QuranUthmanicHafs');
      expect(settings.writes, isEmpty, reason: 'لا يُحفظ شيء قبل «تطبيق»');
      expect(find.text('تطبيق'), findsOneWidget);

      // «إلغاء» يُغلق بلا حفظ — ثم «تطبيق» يحفظ مرة واحدة
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(settings.writes, isEmpty);

      await tester.tap(find.byTooltip('خطوط القرآن الكريم'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مصحف المدينة (الرسم العثماني لحفص)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تطبيق'));
      await tester.pumpAndSettle();

      expect(settings.writes, <String>['font:QuranUthmanicHafs']);
      expect(find.text('تطبيق'), findsNothing, reason: 'النافذة تُغلق بعد الحفظ');
    });
  });

  group('نافذة إعدادات القراءة', () {
    testWidgets('المعاينة تتبع المسودة ولا تُحفظ قبل «تطبيق»', (tester) async {
      final settings = await _registerDependencies();

      await tester.pumpWidget(_buildQuranViewPage());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('إعدادات القراءة'));
      await tester.pumpAndSettle();

      expect(find.text('معاينة قبل التطبيق'), findsOneWidget);
      Text preview() =>
          tester.widget<Text>(find.text(_kSettingsPreviewSample));
      expect(preview().style?.fontSize, 22.0);

      // تكبير الحجم: المعاينة تتبعه فوراً بلا أي حفظ
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(preview().style?.fontSize, 24.0);
      expect(settings.writes, isEmpty, reason: 'لا يُحفظ شيء قبل «تطبيق»');

      // «إلغاء» لا يحفظ شيئاً
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(settings.writes, isEmpty);

      // الآن: تعديل ثم «تطبيق» فيُحفظ كل المسودة مرة واحدة
      await tester.tap(find.byTooltip('إعدادات القراءة'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      // النمط النهاري من خيارات النافذة (الأخير في الشجرة = داخل النافذة)،
      // مع تمرير النافذة إليه أولاً فهو في أسفل محتواها.
      final Finder lightMode = find.byIcon(Icons.light_mode_rounded).last;
      await tester.ensureVisible(lightMode);
      await tester.pumpAndSettle();
      await tester.tap(lightMode);
      await tester.pumpAndSettle();
      await tester.tap(find.text('تطبيق'));
      await tester.pumpAndSettle();

      expect(settings.writes, contains('size:24'));
      expect(settings.writes, contains('mode:white'));
      expect(find.text('تطبيق'), findsNothing, reason: 'النافذة تُغلق بعد التطبيق');

      // وفتح النافذة من جديد يُظهر الحجم المطبَّق
      await tester.tap(find.byTooltip('إعدادات القراءة'));
      await tester.pumpAndSettle();
      expect(find.text('24'), findsWidgets);
    });
  });
}
