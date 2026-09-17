import 'package:equatable/equatable.dart';

class Surah extends Equatable {
  final int id;
  final String name;
  final String revelationType;
  final int ayahsCount;
  final String nameArabic;

  const Surah({
    required this.id,
    required this.name,
    required this.revelationType,
    required this.ayahsCount,
    required this.nameArabic,
  });

  @override
  List<Object?> get props => [id, name, nameArabic];
}
