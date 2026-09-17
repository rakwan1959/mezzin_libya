import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/datasources/audio_player_service.dart';
import 'package:just_audio/just_audio.dart';

// Events
abstract class QuranAudioEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class PlayAyahAudioEvent extends QuranAudioEvent {
  final int surahId;
  final int ayahNumber;
  final String reciterIdentifier;
  final String surahName;

  PlayAyahAudioEvent({
    required this.surahId,
    required this.ayahNumber,
    required this.reciterIdentifier,
    required this.surahName,
  });

  @override
  List<Object?> get props => [surahId, ayahNumber, reciterIdentifier];
}

class ToggleAudioEvent extends QuranAudioEvent {}
class StopAudioEvent extends QuranAudioEvent {}

// State
class QuranAudioState extends Equatable {
  final PlayerState? playerState;
  final Duration position;
  final Duration duration;
  final int? currentSurahId;
  final int? currentAyahNumber;
  final String? surahName;
  final String? reciterIdentifier;
  final String? errorMessage;
  final int? lastHandledAyah; // تتبع آخر آية تم معالجة انتهائها لمنع التكرار

  const QuranAudioState({
    this.playerState,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.currentSurahId,
    this.currentAyahNumber,
    this.surahName,
    this.reciterIdentifier,
    this.errorMessage,
    this.lastHandledAyah,
  });

  @override
  List<Object?> get props => [playerState, position, duration, currentSurahId, currentAyahNumber, surahName, reciterIdentifier, errorMessage, lastHandledAyah];

  QuranAudioState copyWith({
    PlayerState? playerState,
    Duration? position,
    Duration? duration,
    int? currentSurahId,
    int? currentAyahNumber,
    String? surahName,
    String? reciterIdentifier,
    String? errorMessage,
    int? lastHandledAyah,
    bool clearError = false,
  }) {
    return QuranAudioState(
      playerState: playerState ?? this.playerState,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentSurahId: currentSurahId ?? this.currentSurahId,
      currentAyahNumber: currentAyahNumber ?? this.currentAyahNumber,
      surahName: surahName ?? this.surahName,
      reciterIdentifier: reciterIdentifier ?? this.reciterIdentifier,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastHandledAyah: lastHandledAyah ?? this.lastHandledAyah,
    );
  }
}

// Bloc
class QuranAudioBloc extends Bloc<QuranAudioEvent, QuranAudioState> {
  final AudioPlayerService audioService;
  int _retryCount = 0;

  QuranAudioBloc({required this.audioService}) : super(const QuranAudioState()) {
    audioService.playerStateStream.listen((state) {
      add(_InternalUpdateStateEvent(playerState: state));
    });

    audioService.positionStream.listen((pos) {
      if (pos != null) add(_InternalUpdateStateEvent(position: pos));
    });

    audioService.durationStream.listen((dur) {
      if (dur != null) add(_InternalUpdateStateEvent(duration: dur));
    });

    on<PlayAyahAudioEvent>((event, emit) async {
      _retryCount = 0;
      emit(state.copyWith(
        currentSurahId: event.surahId,
        currentAyahNumber: event.ayahNumber,
        surahName: event.surahName,
        reciterIdentifier: event.reciterIdentifier,
        lastHandledAyah: null, // إعادة تعيين التتبع عند بدء آية جديدة
        clearError: true,
      ));
      try {
        await audioService.playAyah(
          surahId: event.surahId,
          ayahNumber: event.ayahNumber,
          reciterIdentifier: event.reciterIdentifier,
          surahName: event.surahName,
        );
      } catch (e) {
        print("Quran audio playback error: $e");
        // إعادة المحاولة التلقائية في حال كان هناك انقطاع لحظي بالشبكة
        if (_retryCount < 2) {
          _retryCount++;
          await Future.delayed(const Duration(milliseconds: 500));
          if (!isClosed) {
            add(event);
            return;
          }
        }
        emit(state.copyWith(errorMessage: "فشل في تحميل الصوت. تأكد من اتصالك بالإنترنت."));
      }
    });

    on<ToggleAudioEvent>((event, emit) async {
      if (state.playerState?.playing == true) {
        await audioService.pause();
      } else {
        await audioService.resume();
      }
    });

    on<StopAudioEvent>((event, emit) async {
      await audioService.stop();
      emit(const QuranAudioState()); // مسح الحالة لإخفاء المشغل
    });

    on<_InternalUpdateStateEvent>((event, emit) async {
      final newState = state.copyWith(
        playerState: event.playerState,
        position: event.position,
        duration: event.duration,
      );
      emit(newState);

      // التأكد من اكتمال تشغيل الآية الحالية
      if (event.playerState != null && event.playerState!.processingState == ProcessingState.completed) {
        if (state.currentSurahId != null && state.currentAyahNumber != null && state.reciterIdentifier != null) {

          // منع تكرار المعالجة لنفس الآية
          if (state.lastHandledAyah == state.currentAyahNumber) return;

          final bool isFullSurahReciter = state.reciterIdentifier!.startsWith('ly.');

          if (isFullSurahReciter) {
            // قارئ السورة الكاملة: نتوقف عند انتهاء السورة
            add(StopAudioEvent());
          } else {
            // قارئ الآيات: ننتقل تلقائياً للآية التالية بسلاسة
            final int maxAyahs = _getSurahAyahCount(state.currentSurahId!);
            if (state.currentAyahNumber! < maxAyahs) {
              emit(state.copyWith(lastHandledAyah: state.currentAyahNumber));

              // فاصل زمني خفيف لضمان استقرار المشغل قبل الآية التالية
              await Future.delayed(const Duration(milliseconds: 150));
              if (!isClosed) {
                add(PlayAyahAudioEvent(
                  surahId: state.currentSurahId!,
                  ayahNumber: state.currentAyahNumber! + 1,
                  reciterIdentifier: state.reciterIdentifier!,
                  surahName: state.surahName ?? "",
                ));
              }
            } else {
              add(StopAudioEvent());
            }
          }
        }
      }
    });
  }

  int _getSurahAyahCount(int surahId) {
    final List<int> counts = [
      7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 11, 5, 4, 5, 6, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6
    ];
    return counts[surahId - 1];
  }
}

class _InternalUpdateStateEvent extends QuranAudioEvent {
  final PlayerState? playerState;
  final Duration? position;
  final Duration? duration;

  _InternalUpdateStateEvent({this.playerState, this.position, this.duration});

  @override
  List<Object?> get props => [playerState, position, duration];
}
