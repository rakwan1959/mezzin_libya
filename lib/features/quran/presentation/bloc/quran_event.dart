import 'package:equatable/equatable.dart';

abstract class QuranEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadSurahsEvent extends QuranEvent {}

class LoadAyahsEvent extends QuranEvent {
  final int surahId;
  LoadAyahsEvent(this.surahId);

  @override
  List<Object?> get props => [surahId];
}

class LoadJuzEvent extends QuranEvent {
  final int juzNumber;
  LoadJuzEvent(this.juzNumber);

  @override
  List<Object?> get props => [juzNumber];
}

class SearchQuranEvent extends QuranEvent {
  final String query;
  SearchQuranEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class UpdateFontSizeEvent extends QuranEvent {
  final double fontSize;
  UpdateFontSizeEvent(this.fontSize);

  @override
  List<Object?> get props => [fontSize];
}

class SaveLastReadEvent extends QuranEvent {
  final int surahId;
  final int ayahNumber;
  SaveLastReadEvent(this.surahId, this.ayahNumber);

  @override
  List<Object?> get props => [surahId, ayahNumber];
}

class ToggleBookmarkEvent extends QuranEvent {
  final int surahId;
  final int ayahNumber;
  final String surahName;

  ToggleBookmarkEvent({required this.surahId, required this.ayahNumber, required this.surahName});

  @override
  List<Object?> get props => [surahId, ayahNumber, surahName];
}
