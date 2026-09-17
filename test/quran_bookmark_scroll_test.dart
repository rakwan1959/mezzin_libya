import 'package:flutter_test/flutter_test.dart';
import 'package:muezzin_libya_app/features/quran/domain/entities/ayah.dart';
import 'package:muezzin_libya_app/features/quran/domain/entities/surah.dart';
import 'package:muezzin_libya_app/features/quran/presentation/pages/quran_view_page.dart';

void main() {
  test('QuranViewPage correctly accepts initialAyah and surah', () {
    const surah = Surah(
      id: 2,
      name: "البقرة",
      revelationType: "مدنية",
      ayahsCount: 286,
      nameArabic: "البقرة",
    );

    const page = QuranViewPage(
      surah: surah,
      initialAyah: 25,
    );

    expect(page.initialAyah, 25);
    expect(page.surah?.id, 2);
  });

  test('resolveAyahNumberInSurah handles positive and zero ayah numbers', () {
    const ayahValid = Ayah(
      id: 1,
      surahId: 2,
      ayahNumber: 25,
      text: 'آية 25',
      textUthmani: 'آية 25',
      page: 1,
      juz: 1,
    );

    const ayahZero = Ayah(
      id: 2,
      surahId: 2,
      ayahNumber: 0,
      text: 'آية 0',
      textUthmani: 'آية 0',
      page: 1,
      juz: 1,
    );

    expect(resolveAyahNumberInSurah(10, ayahValid), 25);
    expect(resolveAyahNumberInSurah(10, ayahZero), 10);
  });
}
