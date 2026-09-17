import 'package:equatable/equatable.dart';

class Ayah extends Equatable {
  final int id;
  final int surahId;
  final int ayahNumber;
  final String text;
  final String textUthmani;
  final String translation;
  final String tafsir; // Default or currently selected tafsir
  final String tafsirIbnKathir;
  final String tafsirJalalayn;
  final int page;
  final int juz;

  const Ayah({
    required this.id,
    required this.surahId,
    required this.ayahNumber,
    required this.text,
    required this.textUthmani,
    this.translation = '',
    this.tafsir = '',
    this.tafsirIbnKathir = '',
    this.tafsirJalalayn = '',
    required this.page,
    required this.juz,
  });

  @override
  List<Object?> get props => [id, surahId, ayahNumber, text, tafsirIbnKathir, tafsirJalalayn];
}
