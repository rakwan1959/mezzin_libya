import 'package:flutter_test/flutter_test.dart';
import 'package:muezzin_libya_app/features/quran/domain/entities/ayah.dart';
import 'package:muezzin_libya_app/features/quran/presentation/pages/quran_view_page.dart';

void main() {
  group('Quran ayah numbering', () {
    test('uses the actual ayah number instead of the scroll index', () {
      final ayah = Ayah(
        id: 123,
        surahId: 2,
        ayahNumber: 26,
        text: 'بعض النص',
        textUthmani: 'بعض النص',
        page: 1,
        juz: 1,
      );

      expect(resolveAyahNumberInSurah(200, ayah), 26);
    });

    test('falls back to list position only when number is missing', () {
      final ayah = Ayah(
        id: 124,
        surahId: 2,
        ayahNumber: 0,
        text: 'بعض النص',
        textUthmani: 'بعض النص',
        page: 1,
        juz: 1,
      );

      expect(resolveAyahNumberInSurah(7, ayah), 7);
    });
  });
}
