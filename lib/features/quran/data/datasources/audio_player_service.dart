import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:audio_session/audio_session.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class AudioPlayerService {
  static const Map<String, String> _reciterDisplayNames = {
    "ar.buajan": "عبدالله البعيجان (سور كاملة)",
    "ar.alafasy": "مشاري العفاسي",
    "ar.abdulsamad": "عبدالباسط عبدالصمد",
    "ar.minshawi": "محمد المنشاوي",
    "ar.mahermuaiqly": "ماهر المعيقلي",
    "ar.sudais": "السديس",
    "ly.daoub": "طارق دعوب",
    "ly.dokali": "الدوكالي العالم",
  };

  final AudioPlayer _player = AudioPlayer();
  final Dio _dio = Dio();

  AudioPlayerService() {
    _initAudioSession();
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {}

    _player.playerStateStream.listen((state) {
      try {
        if (state.playing) {
          WakelockPlus.enable();
        } else if (state.processingState == ProcessingState.completed ||
                   state.processingState == ProcessingState.idle) {
          WakelockPlus.disable();
        }
      } catch (_) {}
    });
  }

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  Future<void> playAyah({
    required int surahId,
    required int ayahNumber,
    required String reciterIdentifier,
    required String surahName,
  }) async {
    try {
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
        await session.setActive(true);
      } catch (_) {}

      try {
        await WakelockPlus.enable();
      } catch (_) {}

      final ayahId = _getGlobalAyahId(surahId, ayahNumber);
      final isFullSurahReciter = reciterIdentifier.startsWith('ly.') || reciterIdentifier == 'ar.buajan';

      // قائمة المصادر بالترتيب: الأساسي أولاً ثم البديل عند فشله
      final List<String> urlCandidates =
          getAudioUrls(reciterIdentifier, ayahId, surahId, ayahNumber);

      final directory = await getApplicationDocumentsDirectory();
      final audioBaseDir = Directory(p.join(directory.path, 'quran_audio', reciterIdentifier));
      if (!await audioBaseDir.exists()) await audioBaseDir.create(recursive: true);

      final String fileName = isFullSurahReciter ? 'surah_$surahId.mp3' : '$ayahId.mp3';
      final localFilePath = p.join(audioBaseDir.path, fileName);
      final localFile = File(localFilePath);

      // ── التحقق من صحة الملف المحلي ──
      // لا نعتمد على الحجم فقط: ملف HTML خاطئ (مثلاً صفحة خطأ من السيرفر) قد يكون
      // أكبر من 5000 بايت، ولن يعمل عند التشغيل. نتأكد أنه ملف MP3 حقيقي.
      if (await localFile.exists()) {
        if (isValidMp3File(localFile)) {
          try {
            final mediaItem = MediaItem(
              id: 'quran-$reciterIdentifier-$surahId-$ayahNumber',
              album: "القرآن الكريم",
              title: isFullSurahReciter ? "سورة $surahName" : "سورة $surahName - آية $ayahNumber",
              artist: _reciterDisplayNames[reciterIdentifier] ?? reciterIdentifier,
            );
            await _player.setAudioSource(AudioSource.file(localFilePath, tag: mediaItem));
            await _player.play();
            return;
          } catch (_) {
            // فشل تشغيل الملف المحلي — نتجاهله ونعيد التنزيل
            try {
              await localFile.delete();
            } catch (_) {}
          }
        } else {
          // ملف تالف (صفحة HTML أو تنزيل ناقص) — حذفه وإعادة التنزيل
          try {
            await localFile.delete();
          } catch (_) {}
        }
      }

      // ── التشغيل من الإنترنت مع تجربة أكثر من مصدر ──
      String? lastError;
      for (final url in urlCandidates) {
        try {
          final mediaItem = MediaItem(
            id: 'quran-$reciterIdentifier-$surahId-$ayahNumber',
            album: "القرآن الكريم",
            title: isFullSurahReciter ? "سورة $surahName" : "سورة $surahName - آية $ayahNumber",
            artist: _reciterDisplayNames[reciterIdentifier] ?? reciterIdentifier,
          );
          await _player.setAudioSource(AudioSource.uri(Uri.parse(url), tag: mediaItem));
          await _player.play();
          _downloadAyahSafely(url, localFilePath);
          return;
        } catch (e) {
          lastError = e.toString();
        }
      }

      // فشلت جميع المصادر — إظهار الخطأ بدلاً من الفشل الصامت
      throw Exception('فشل تحميل الصوت من جميع المصادر: $lastError');
    } catch (e) {
      print("Audio Player Error: $e");
      rethrow;
    }
  }

  /// التحقق من أن الملف المحلي ملف صوتي MP3 حقيقي وليس صفحة HTML أو ملفاً تالفاً
  static bool isValidMp3File(File file) {
    try {
      final RandomAccessFile raf = file.openSync();
      try {
        final List<int> header = raf.readSync(4);
        if (header.length < 2) return false;
        // وسم ID3 في بداية ملف MP3: الأحرف 'ID3'
        if (header.length >= 3 &&
            header[0] == 0x49 &&
            header[1] == 0x44 &&
            header[2] == 0x33) {
          return true;
        }
        // إطار MPEG الصوتي يبدأ بايت المزامنة 0xFF متبوعاً بـ 0xE0-0xFF
        if (header[0] == 0xFF && (header[1] & 0xE0) == 0xE0) {
          return true;
        }
        return false;
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return false;
    }
  }

  void _downloadAyahSafely(String url, String finalPath) async {
    try {
      final tempPath = '$finalPath.tmp';
      await _dio.download(url, tempPath);
      final f = File(tempPath);
      // لا نحفظ الملف إلا إذا كان صوتاً حقيقياً (منع تخزين صفحات الخطأ HTML كملفات صوت)
      if (await f.exists() && await f.length() > 5000 && isValidMp3File(f)) {
        await f.rename(finalPath);
      } else {
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
  }

  int _getGlobalAyahId(int surahId, int ayahNumber) {
    final List<int> counts = [
      7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 11, 5, 4, 5, 6, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6
    ];
    int offset = 0;
    for (int i = 0; i < surahId - 1; i++) {
      offset += counts[i];
    }
    return offset + ayahNumber;
  }

  Future<void> resume() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  Future<void> stop() async {
    await _player.stop();
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  Future<void> seek(Duration position) async => await _player.seek(position);
  void dispose() {
    try {
      WakelockPlus.disable();
    } catch (_) {}
    _player.dispose();
  }

  /// قائمة روابط الصوت لكل قارئ بالترتيب: المصدر الأساسي أولاً ثم المصادر البديلة
  /// (يعمل البديل تلقائياً إذا تعطل المصدر الأساسي أو كان محجوباً في بلد المستخدم)
  static List<String> getAudioUrls(String reciterIdentifier, int globalAyahId, int surahId, int ayahNumber) {
    String sStr = surahId.toString().padLeft(3, '0');
    String aStr = ayahNumber.toString().padLeft(3, '0');

    switch (reciterIdentifier) {
      case 'ar.buajan':
        // تلاوة الشيخ عبدالله البعيجان — سور كاملة عبر خادم mp3quran.net السريع
        return [
          "https://server8.mp3quran.net/buajan/$sStr.mp3",
          "http://server8.mp3quran.net/buajan/$sStr.mp3",
        ];
      case 'ly.daoub':
        // سور كاملة — mp3quran.net يدعم HTTPS الآن
        return [
          "https://server10.mp3quran.net/tareq/$sStr.mp3",
          "http://server10.mp3quran.net/tareq/$sStr.mp3",
        ];
      case 'ly.dokali':
        return [
          "https://server7.mp3quran.net/dokali/$sStr.mp3",
          "http://server7.mp3quran.net/dokali/$sStr.mp3",
        ];
      case 'ar.alafasy':
        return [
          "https://everyayah.com/data/Alafasy_128kbps/$sStr$aStr.mp3",
          "https://cdn.islamic.network/quran/audio/128/ar.alafasy/$globalAyahId.mp3",
        ];
      case 'ar.abdulsamad':
        return [
          "https://everyayah.com/data/Abdul_Basit_Murattal_64kbps/$sStr$aStr.mp3",
          "https://cdn.islamic.network/quran/audio/64/ar.abdulsamad/$globalAyahId.mp3",
        ];
      case 'ar.minshawi':
        return [
          "https://everyayah.com/data/Minshawy_Murattal_128kbps/$sStr$aStr.mp3",
          "https://cdn.islamic.network/quran/audio/128/ar.minshawi/$globalAyahId.mp3",
        ];
      case 'ar.mahermuaiqly':
        return [
          "https://everyayah.com/data/MaherAlMuaiqly128kbps/$sStr$aStr.mp3",
          "https://cdn.islamic.network/quran/audio/128/ar.mahermuaiqly/$globalAyahId.mp3",
        ];
      case 'ar.sudais':
        // لا يوجد بديل موثوق على cdn.islamic.network لصوت السديس حالياً
        return [
          "https://everyayah.com/data/Abdurrahmaan_As-Sudais_64kbps/$sStr$aStr.mp3",
        ];
      default:
        return [
          "https://cdn.islamic.network/quran/audio/128/$reciterIdentifier/$globalAyahId.mp3",
        ];
    }
  }
}
