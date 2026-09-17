import '../../domain/entities/surah.dart';

class SurahModel extends Surah {
  const SurahModel({
    required super.id,
    required super.name,
    required super.revelationType,
    required super.ayahsCount,
    required super.nameArabic,
  });

  factory SurahModel.fromMap(Map<String, dynamic> map) {
    return SurahModel(
      id: map['id'],
      name: map['name'],
      revelationType: map['revelation_type'] ?? '',
      ayahsCount: map['ayahs_count'] ?? 0,
      nameArabic: map['name_arabic'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'revelation_type': revelationType,
      'ayahs_count': ayahsCount,
      'name_arabic': nameArabic,
    };
  }
}
