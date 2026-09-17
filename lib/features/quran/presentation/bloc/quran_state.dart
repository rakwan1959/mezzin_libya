import 'package:equatable/equatable.dart';
import '../../domain/entities/surah.dart';
import '../../domain/entities/ayah.dart';

abstract class QuranState extends Equatable {
  const QuranState();
  @override
  List<Object?> get props => [];
}

class QuranInitial extends QuranState {}

class QuranLoading extends QuranState {}

class SurahsLoaded extends QuranState {
  final List<Surah> surahs;
  SurahsLoaded(this.surahs);

  @override
  List<Object?> get props => [surahs];
}

class AyahsLoaded extends QuranState {
  final List<Ayah> ayahs;
  AyahsLoaded(this.ayahs);

  @override
  List<Object?> get props => [ayahs];
}

class SearchResultsLoaded extends QuranState {
  final List<Ayah> results;
  final List<dynamic> filteredSurahs;

  const SearchResultsLoaded(this.results, [this.filteredSurahs = const []]);

  @override
  List<Object?> get props => [results, filteredSurahs];
}

class QuranSettingsState extends QuranState {
  final double fontSize;
  final Map<String, int>? lastRead;

  QuranSettingsState({required this.fontSize, this.lastRead});

  @override
  List<Object?> get props => [fontSize, lastRead];
}

class QuranError extends QuranState {
  final String message;
  QuranError(this.message);

  @override
  List<Object?> get props => [message];
}
