import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/get_surahs.dart';
import '../../domain/usecases/get_ayahs_by_surah.dart';
import '../../domain/usecases/get_ayahs_by_juz.dart';
import '../../domain/usecases/search_ayahs.dart';
import '../../domain/repositories/quran_repository.dart';
import '../../domain/entities/bookmark.dart';
import '../../domain/entities/surah.dart';
import '../../data/datasources/quran_settings_data_source.dart';
import 'quran_event.dart';
import 'quran_state.dart';

class QuranBloc extends Bloc<QuranEvent, QuranState> {
  final GetSurahs getSurahs;
  final GetAyahsBySurah getAyahsBySurah;
  final GetAyahsByJuz getAyahsByJuz;
  final SearchAyahs searchAyahs;
  final QuranSettingsDataSource settingsDataSource;
  final QuranRepository repository;

  QuranBloc({
    required this.getSurahs,
    required this.getAyahsBySurah,
    required this.getAyahsByJuz,
    required this.searchAyahs,
    required this.settingsDataSource,
    required this.repository,
  }) : super(QuranInitial()) {
    on<LoadSurahsEvent>((event, emit) async {
      emit(QuranLoading());
      final result = await getSurahs(NoParams());
      result.fold(
        (failure) => emit(QuranError("فشل في تحميل السور. تأكد من اتصالك بالإنترنت.")),
        (surahs) {
          // التأكد من ترتيب السور حسب الرقم
          final sortedSurahs = surahs.toList()
            ..sort((a, b) => a.id.compareTo(b.id));
          emit(SurahsLoaded(sortedSurahs));
        },
      );
    });

    on<LoadAyahsEvent>((event, emit) async {
      emit(QuranLoading());
      try {
        final result = await getAyahsBySurah(event.surahId);
        result.fold(
          (failure) => emit(QuranError("فشل في تحميل الآيات. تأكد من اتصالك بالإنترنت.")),
          (ayahs) {
            if (ayahs.isEmpty) {
              emit(QuranError("لا توجد بيانات لهذه السورة حالياً. يرجى الاتصال بالإنترنت لتحميلها."));
            } else {
              emit(AyahsLoaded(ayahs));
            }
          },
        );
      } catch (e) {
        emit(QuranError("حدث خطأ غير متوقع أثناء تحميل السورة."));
      }
    });

    on<LoadJuzEvent>((event, emit) async {
      emit(QuranLoading());
      try {
        final result = await getAyahsByJuz(event.juzNumber);
        result.fold(
          (failure) => emit(QuranError("فشل في تحميل آيات الجزء. تأكد من اتصالك بالإنترنت.")),
          (ayahs) {
            if (ayahs.isEmpty) {
              emit(QuranError("لا توجد بيانات لهذا الجزء حالياً. يرجى الاتصال بالإنترنت لتحميله."));
            } else {
              emit(AyahsLoaded(ayahs));
            }
          },
        );
      } catch (e) {
        emit(QuranError("حدث خطأ أثناء تحميل الجزء."));
      }
    });

    on<SearchQuranEvent>((event, emit) async {
      if (event.query.isEmpty) {
        add(LoadSurahsEvent());
        return;
      }
      
      // جلب قائمة السور الكاملة للتصفية
      final surahsResult = await getSurahs(NoParams());
      List<Surah> filteredSurahs = [];
      
      String normalize(String s) {
        return s.replaceAll(RegExp(r'[\u064B-\u065F]'), '') // remove tashkeel
                .replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا'); // normalize alifs
      }

      final queryNormalized = normalize(event.query);

      surahsResult.fold((_) => null, (surahs) {
        filteredSurahs = surahs.where((s) => 
          normalize(s.name).contains(queryNormalized)
        ).toList();
      });

      // جلب نتائج الآيات
      final ayahsResult = await searchAyahs(event.query);
      ayahsResult.fold(
        (failure) => emit(QuranError("فشل في عملية البحث")),
        (results) => emit(SearchResultsLoaded(results, filteredSurahs)),
      );
    });

    on<UpdateFontSizeEvent>((event, emit) async {
      await settingsDataSource.setFontSize(event.fontSize);
    });

    on<SaveLastReadEvent>((event, emit) async {
      await settingsDataSource.saveLastRead(event.surahId, event.ayahNumber);
    });

    on<ToggleBookmarkEvent>((event, emit) async {
      final bookmarksResult = await repository.getBookmarks();
      bookmarksResult.fold((f) => null, (bookmarks) async {
        final isBookmarked = bookmarks.any((b) => b.surahId == event.surahId && b.ayahNumber == event.ayahNumber);
        if (isBookmarked) {
          await repository.removeBookmark(event.surahId, event.ayahNumber);
        } else {
          await repository.addBookmark(Bookmark(
            id: 0,
            surahId: event.surahId,
            ayahNumber: event.ayahNumber,
            surahName: event.surahName,
            createdAt: DateTime.now(),
          ));
        }
      });
    });
  }
}
