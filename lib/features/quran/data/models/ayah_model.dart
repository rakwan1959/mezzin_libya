import '../../domain/entities/ayah.dart';

class AyahModel extends Ayah {
  const AyahModel({
    required super.id,
    required super.surahId,
    required super.ayahNumber,
    required super.text,
    required super.textUthmani,
    super.translation,
    super.tafsir,
    super.tafsirIbnKathir,
    super.tafsirJalalayn,
    required super.page,
    required super.juz,
  });

  factory AyahModel.fromMap(Map<String, dynamic> map) {
    return AyahModel(
      id: map['id'],
      surahId: map['surah_id'],
      ayahNumber: map['ayah_number'],
      text: map['text'] ?? '',
      textUthmani: map['text_uthmani'] ?? '',
      translation: map['translation'] ?? '',
      tafsir: map['tafsir'] ?? '',
      tafsirIbnKathir: map['tafsir_ibn_kathir'] ?? '',
      tafsirJalalayn: map['tafsir_jalalayn'] ?? '',
      page: map['page'] ?? 0,
      juz: map['juz'] ?? 0,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'surah_id': surahId,
      'ayah_number': ayahNumber,
      'text': text,
      'text_uthmani': textUthmani,
      'translation': translation,
      'tafsir': tafsir,
      'tafsir_ibn_kathir': tafsirIbnKathir,
      'tafsir_jalalayn': tafsirJalalayn,
      'page': page,
      'juz': juz,
    };
  }
}
