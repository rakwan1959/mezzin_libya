import 'package:equatable/equatable.dart';

class Bookmark extends Equatable {
  final int? id;
  final int surahId;
  final int ayahNumber;
  final String surahName;
  final DateTime createdAt;

  const Bookmark({
    this.id,
    required this.surahId,
    required this.ayahNumber,
    required this.surahName,
    required this.createdAt,
  });


  @override
  List<Object?> get props => [id, surahId, ayahNumber];
}
