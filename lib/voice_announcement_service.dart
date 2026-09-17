import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';

class VoiceAnnouncementService {
  static final VoiceAnnouncementService _instance = VoiceAnnouncementService._internal();
  factory VoiceAnnouncementService() => _instance;
  VoiceAnnouncementService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  VoidCallback? _onStart;
  VoidCallback? _onComplete;

  /// تسجيل callback عند بدء التحدث
  void setStartHandler(VoidCallback handler) {
    _onStart = handler;
    _flutterTts.setStartHandler(() => _onStart?.call());
  }

  /// تسجيل callback عند انتهاء التحدث
  void setCompletionHandler(VoidCallback handler) {
    _onComplete = handler;
    _flutterTts.setCompletionHandler(() => _onComplete?.call());
    _flutterTts.setCancelHandler(() => _onComplete?.call());
    _flutterTts.setErrorHandler((msg) => _onComplete?.call());
  }

  Future<void> init() async {
    if (Platform.isAndroid) {
      try {
        await _flutterTts.setEngine("com.google.android.tts");
      } catch (e) {
        debugPrint('VoiceAnnouncementService: could not set Google TTS engine: $e');
      }
    }
    await _flutterTts.setLanguage("ar-SA");
    await _flutterTts.setSpeechRate(0.45); // Slightly slower for better Arabic articulation
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(0.9); // Slightly lower pitch for a deeper, more natural male voice

    try {
      final voices = List<dynamic>.from(await _flutterTts.getVoices);
      final arabicVoices = voices.where((voice) {
        final name = (voice is Map ? voice['name'] : voice).toString().toLowerCase();
        final locale = (voice is Map ? voice['locale'] : '').toString().toLowerCase();
        return locale.startsWith('ar') || name.contains('ar');
      }).toList();

      // Priority list for high-quality male voices
      final maleKeywords = [
        'ar-xa-x-arc-local', // Google Neural Arabic C (Male - High Quality)
        'ar-xa-x-ard-local', // Google Neural Arabic D (Male - High Quality)
        'ar-xa-x-arf-local', // Google Neural Arabic F (Male - High Quality)
        'male', 'man', 'ahmed', 'omar', 'sultan', 'hamzah', 'ali', 
        'khalid', 'mustafa', 'youssef', 'ibrahim', 'nizar', 'zayd',
      ];

      Map? bestMale;
      
      // 1. Search by explicit gender and name
      for (var voice in arabicVoices.cast<Map>()) {
        final name = (voice['name'] ?? '').toString().toLowerCase();
        final gender = (voice['gender'] ?? '').toString().toLowerCase();
        
        if (gender == 'male' || maleKeywords.any((k) => name.contains(k))) {
          bestMale = voice;
          // If it's a high-quality Google voice, break early
          if (name.contains('ar-xa-x')) break;
        }
      }

      if (bestMale != null) {
        await _flutterTts.setVoice({
          'name': bestMale['name'],
          'locale': bestMale['locale'],
        });
      } else if (arabicVoices.isNotEmpty) {
        final firstArabic = arabicVoices.first;
        await _flutterTts.setVoice({
          'name': firstArabic['name'],
          'locale': firstArabic['locale'],
        });
      }
    } catch (e) {
      debugPrint('VoiceAnnouncementService: could not pick Arabic voice: $e');
    }
  }

  Future<void> announcePrayerTimeElapsed(String prayerName, int minutes) async {
    String text = "مضى على أذان $prayerName 10 دقائق";
    
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("Error speaking text: $e");
    }
  }

  Future<void> announcePrePrayer(String prayerName, int minutes) async {
    String text = "بقي $minutes دقائق حتى وقت $prayerName";
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("Error speaking text: $e");
    }
  }

  String _getAssetPath(String prayerName) {
    switch (prayerName) {
      case 'الفجر':
        return 'assets/audio/fajr_announcement.mp3';
      case 'الظهر':
        return 'assets/audio/dhuhr_announcement.mp3';
      case 'العصر':
        return 'assets/audio/asr_announcement.mp3';
      case 'المغرب':
        return 'assets/audio/maghrib_announcement.mp3';
      case 'العشاء':
        return 'assets/audio/isha_announcement.mp3';
      default:
        return 'assets/audio/fajr_announcement.mp3';
    }
  }

  /// إعلان صوتي عربي أصيل قبل الأذان بـ 3 ثوانٍ
  /// "حان الآن موعد أذان صلاة ..."
  Future<void> announceAdhanTime(String prayerName) async {
    final assetPath = _getAssetPath(prayerName);
    try {
      debugPrint("Playing pre-recorded male voice announcement for $prayerName from assets...");
      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint("Error playing voice announcement audio asset: $e. Skipping announcement to avoid female TTS.");
      // تم حذف الـ TTS هنا لتجنب صوت المرأة غير المرغوب فيه
    }
  }



  Future<void> speakText(String text) async {
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("Error speaking text: $e");
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint("Error stopping TTS: $e");
    }
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint("Error stopping AudioPlayer: $e");
    }
  }
}
