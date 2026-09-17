import 'package:flutter_test/flutter_test.dart';
import 'package:muezzin_libya_app/features/quran/domain/entities/ayah.dart';
import 'package:muezzin_libya_app/features/quran/presentation/pages/quran_view_page.dart';

void main() {
  test('sortAyahsBySurahNumber keeps ayah numbers in correct order', () {
    final ayahs = [
      const Ayah(
        id: 10,
        surahId: 2,
        ayahNumber: 200,
        text: 'text 200',
        textUthmani: 'text 200',
        page: 1,
        juz: 1,
      ),
      const Ayah(
        id: 11,
        surahId: 2,
        ayahNumber: 26,
        text: 'text 26',
        textUthmani: 'text 26',
        page: 1,
        juz: 1,
      ),
      const Ayah(
        id: 12,
        surahId: 2,
        ayahNumber: 27,
        text: 'text 27',
        textUthmani: 'text 27',
        page: 1,
        juz: 1,
      ),
    ];

    final sorted = sortAyahsBySurahNumber(ayahs);

    expect(sorted.map((a) => a.ayahNumber).toList(), [26, 27, 200]);
  });
}
