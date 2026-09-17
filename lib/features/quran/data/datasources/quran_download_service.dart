import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'audio_player_service.dart';

class ReciterDownloadState {
  final String reciterKey;
  final bool isDownloading;
  final int completedItems;
  final int totalItems;
  final String currentStatus;
  final double progress; // 0.0 to 1.0

  const ReciterDownloadState({
    required this.reciterKey,
    this.isDownloading = false,
    this.completedItems = 0,
    this.totalItems = 0,
    this.currentStatus = '',
    this.progress = 0.0,
  });

  ReciterDownloadState copyWith({
    bool? isDownloading,
    int? completedItems,
    int? totalItems,
    String? currentStatus,
    double? progress,
  }) {
    return ReciterDownloadState(
      reciterKey: reciterKey,
      isDownloading: isDownloading ?? this.isDownloading,
      completedItems: completedItems ?? this.completedItems,
      totalItems: totalItems ?? this.totalItems,
      currentStatus: currentStatus ?? this.currentStatus,
      progress: progress ?? this.progress,
    );
  }
}

class QuranDownloadService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  CancelToken? _cancelToken;
  String? _currentlyDownloadingReciter;
  bool _isDownloadingAll = false;

  final ValueNotifier<Map<String, ReciterDownloadState>> downloadStates =
      ValueNotifier<Map<String, ReciterDownloadState>>({});

  final ValueNotifier<bool> isGlobalDownloading = ValueNotifier<bool>(false);
  final ValueNotifier<String> globalStatusText = ValueNotifier<String>('');

  static const List<int> surahAyahCounts = [
    7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, 135, 112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 11, 5, 4, 5, 6, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6
  ];

  static const List<String> surahNames = [
    "الفاتحة", "البقرة", "آل عمران", "النساء", "المائدة", "الأنعام", "الأعراف", "الأنفال", "التوبة", "يونس",
    "هود", "يوسف", "الرعد", "إبراهيم", "الحجر", "النحل", "الإسراء", "الكهف", "مريم", "طه",
    "الأنبياء", "الحج", "المؤمنون", "النور", "الفرقان", "الشعراء", "النمل", "القصص", "العنكبوت", "الروم",
    "لقمان", "السجدة", "الأحزاب", "سبأ", "فاطر", "يس", "الصافات", "ص", "الزمر", "غافر",
    "فصلت", "الشورى", "الزخرف", "الدخان", "الجاثية", "الأحقاف", "محمد", "الفتح", "الحجرات", "ق",
    "الذاريات", "الطور", "النجم", "القمر", "الرحمن", "الواقعة", "الحديد", "المجادلة", "الحشر", "الممتحنة",
    "الصف", "الجمعة", "المنافقون", "التغابن", "الطلاق", "التحريم", "الملك", "القلم", "الحاقة", "المعارج",
    "نوح", "الجن", "المزمل", "المدثر", "القيامة", "الإنسان", "المرسلات", "النبأ", "النازعات", "عبس",
    "التكوير", "الانفطار", "المطففين", "الانشقاق", "البروج", "الطارق", "الأعلى", "الغاشية", "الفجر", "البلد",
    "الشمس", "الليل", "الضحى", "الشرح", "التين", "العلق", "القدر", "البينة", "الزلزلة", "العاديات",
    "القارعة", "التكاثر", "العصر", "الهمزة", "الفيل", "قريش", "الماعون", "الكوثر", "الكافرون", "النصر",
    "المسد", "الإخلاص", "الفلق", "الناس"
  ];

  static const Map<String, String> reciterNames = {
    "ar.buajan": "عبدالله البعيجان (سور كاملة)",
    "ly.dokali": "الدوكالي العالم (قالون - سور كاملة)",
    "ly.daoub": "طارق دعوب (قالون - سور كاملة)",
    "ar.alafasy": "مشاري العفاسي (حفص - آيات)",
    "ar.abdulsamad": "عبدالباسط",
    "ar.minshawi": "محمد المنشاوي (حفص - آيات)",
    "ar.mahermuaiqly": "ماهر المعيقلي (حفص - آيات)",
    "ar.sudais": "السديس (حفص - آيات)",
  };

  bool isFullSurahReciter(String reciterKey) =>
      reciterKey.startsWith('ly.') || reciterKey == 'ar.buajan';

  int getTotalItemsForReciter(String reciterKey) {
    if (isFullSurahReciter(reciterKey)) {
      return 114; // 114 سور
    } else {
      return 6236; // 6236 آيات
    }
  }

  int getGlobalAyahId(int surahId, int ayahNumber) {
    int offset = 0;
    for (int i = 0; i < surahId - 1; i++) {
      offset += surahAyahCounts[i];
    }
    return offset + ayahNumber;
  }

  Future<Directory> getReciterDirectory(String reciterKey) async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, 'quran_audio', reciterKey));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// فحص الإحصائيات المحملة حالياً للقارئ (كم ملف تم تنزيله وصالح للاستماع)
  Future<int> getDownloadedCount(String reciterKey) async {
    try {
      final dir = await getReciterDirectory(reciterKey);
      if (!await dir.exists()) return 0;

      final files = dir.listSync().whereType<File>().toList();
      int validCount = 0;
      for (final f in files) {
        if (f.path.endsWith('.mp3') && !f.path.endsWith('.tmp')) {
          if (f.lengthSync() > 5000) {
            validCount++;
          }
        }
      }
      return validCount;
    } catch (_) {
      return 0;
    }
  }

  /// حجم التخزين المستهلك للقارئ بالبايت
  Future<int> getReciterStorageSize(String reciterKey) async {
    try {
      final dir = await getReciterDirectory(reciterKey);
      if (!await dir.exists()) return 0;

      int totalBytes = 0;
      final files = dir.listSync(recursive: false).whereType<File>();
      for (final file in files) {
        totalBytes += file.lengthSync();
      }
      return totalBytes;
    } catch (_) {
      return 0;
    }
  }

  /// الحجم الإجمالي لجميع الصوتيات المحملة بالبايت
  Future<int> getTotalStorageSize() async {
    int total = 0;
    for (final key in reciterNames.keys) {
      total += await getReciterStorageSize(key);
    }
    return total;
  }

  /// تنسيق حجم البيانات للقراءة البشرية (مثل 12.5 MB أو 1.4 GB)
  static String formatBytes(int bytes) {
    if (bytes <= 0) return "0 ميجابايت";
    const suffixes = ["بايت", "كيلوبايت", "ميجابايت", "جيجابايت"];
    var i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return "${count.toStringAsFixed(1)} ${suffixes[i]}";
  }

  /// تحديث حالة قارئ معينة في الـ ValueNotifier
  void _updateState(String reciterKey, ReciterDownloadState state) {
    final updated = Map<String, ReciterDownloadState>.from(downloadStates.value);
    updated[reciterKey] = state;
    downloadStates.value = updated;
  }

  /// بدء تحميل المصحف كاملاً لقارئ محدد
  Future<bool> downloadReciter(String reciterKey) async {
    if (_currentlyDownloadingReciter != null) {
      return false; // جاري تحميل بالفعل
    }

    _currentlyDownloadingReciter = reciterKey;
    _cancelToken = CancelToken();
    isGlobalDownloading.value = true;

    final isFullSurah = isFullSurahReciter(reciterKey);
    final totalItems = getTotalItemsForReciter(reciterKey);
    int completedItems = await getDownloadedCount(reciterKey);

    _updateState(
      reciterKey,
      ReciterDownloadState(
        reciterKey: reciterKey,
        isDownloading: true,
        completedItems: completedItems,
        totalItems: totalItems,
        currentStatus: "جاري بدء التحميل...",
        progress: totalItems > 0 ? (completedItems / totalItems) : 0.0,
      ),
    );

    final dir = await getReciterDirectory(reciterKey);

    try {
      if (isFullSurah) {
        // تحميل سور كاملة (114 سورة)
        for (int s = 1; s <= 114; s++) {
          if (_cancelToken?.isCancelled ?? false) break;

          final filePath = p.join(dir.path, "surah_$s.mp3");
          final file = File(filePath);

          final surahName = (s <= surahNames.length) ? surahNames[s - 1] : "سورة $s";

          if (await file.exists() && await file.length() > 5000 && AudioPlayerService.isValidMp3File(file)) {
            // موجود مسبقاً وصحيح
            continue;
          }

          _updateState(
            reciterKey,
            ReciterDownloadState(
              reciterKey: reciterKey,
              isDownloading: true,
              completedItems: completedItems,
              totalItems: totalItems,
              currentStatus: "جاري تنزيل سورة $surahName ($s/114)",
              progress: completedItems / totalItems,
            ),
          );
          globalStatusText.value = "تنزيل سورة $surahName لـ ${reciterNames[reciterKey] ?? ''}";

          final urls = AudioPlayerService.getAudioUrls(reciterKey, 0, s, 0);
          bool downloaded = false;

          for (final url in urls) {
            if (_cancelToken?.isCancelled ?? false) break;
            try {
              final tempPath = "$filePath.tmp";
              await _dio.download(
                url,
                tempPath,
                cancelToken: _cancelToken,
                deleteOnError: true,
              );

              final tmpFile = File(tempPath);
              if (await tmpFile.exists() &&
                  await tmpFile.length() > 5000 &&
                  AudioPlayerService.isValidMp3File(tmpFile)) {
                if (await file.exists()) await file.delete();
                await tmpFile.rename(filePath);
                downloaded = true;
                break;
              } else {
                if (await tmpFile.exists()) await tmpFile.delete();
              }
            } catch (e) {
              if (e is DioException && CancelToken.isCancel(e)) {
                rethrow;
              }
            }
          }

          if (downloaded) {
            completedItems++;
            _updateState(
              reciterKey,
              ReciterDownloadState(
                reciterKey: reciterKey,
                isDownloading: true,
                completedItems: completedItems,
                totalItems: totalItems,
                currentStatus: "تم تنزيل سورة $surahName",
                progress: completedItems / totalItems,
              ),
            );
          }
        }
      } else {
        // تحميل آية بآية (6236 آية)
        for (int s = 1; s <= 114; s++) {
          if (_cancelToken?.isCancelled ?? false) break;

          final surahAyahs = surahAyahCounts[s - 1];
          final surahName = (s <= surahNames.length) ? surahNames[s - 1] : "سورة $s";

          for (int a = 1; a <= surahAyahs; a++) {
            if (_cancelToken?.isCancelled ?? false) break;

            final ayahId = getGlobalAyahId(s, a);
            final filePath = p.join(dir.path, "$ayahId.mp3");
            final file = File(filePath);

            if (await file.exists() && await file.length() > 5000 && AudioPlayerService.isValidMp3File(file)) {
              continue;
            }

            if (a == 1 || a % 10 == 0 || a == surahAyahs) {
              _updateState(
                reciterKey,
                ReciterDownloadState(
                  reciterKey: reciterKey,
                  isDownloading: true,
                  completedItems: completedItems,
                  totalItems: totalItems,
                  currentStatus: "سورة $surahName - آية $a من $surahAyahs",
                  progress: completedItems / totalItems,
                ),
              );
              globalStatusText.value = "تنزيل سورة $surahName (آية $a) - ${reciterNames[reciterKey] ?? ''}";
            }

            final urls = AudioPlayerService.getAudioUrls(reciterKey, ayahId, s, a);
            bool downloaded = false;

            for (final url in urls) {
              if (_cancelToken?.isCancelled ?? false) break;
              try {
                final tempPath = "$filePath.tmp";
                await _dio.download(
                  url,
                  tempPath,
                  cancelToken: _cancelToken,
                  deleteOnError: true,
                );

                final tmpFile = File(tempPath);
                if (await tmpFile.exists() &&
                    await tmpFile.length() > 5000 &&
                    AudioPlayerService.isValidMp3File(tmpFile)) {
                  if (await file.exists()) await file.delete();
                  await tmpFile.rename(filePath);
                  downloaded = true;
                  break;
                } else {
                  if (await tmpFile.exists()) await tmpFile.delete();
                }
              } catch (e) {
                if (e is DioException && CancelToken.isCancel(e)) {
                  rethrow;
                }
              }
            }

            if (downloaded) {
              completedItems++;
            }
          }
        }
      }

      // اكتمل بنجاح
      final finalCount = await getDownloadedCount(reciterKey);
      _updateState(
        reciterKey,
        ReciterDownloadState(
          reciterKey: reciterKey,
          isDownloading: false,
          completedItems: finalCount,
          totalItems: totalItems,
          currentStatus: finalCount >= totalItems ? "مكتمل بالكامل ✅" : "تم حفظ $finalCount من $totalItems",
          progress: totalItems > 0 ? (finalCount / totalItems) : 1.0,
        ),
      );
      return true;
    } catch (e) {
      final currentCount = await getDownloadedCount(reciterKey);
      _updateState(
        reciterKey,
        ReciterDownloadState(
          reciterKey: reciterKey,
          isDownloading: false,
          completedItems: currentCount,
          totalItems: totalItems,
          currentStatus: _cancelToken?.isCancelled ?? false ? "تم الإلغاء" : "توقف التحميل",
          progress: totalItems > 0 ? (currentCount / totalItems) : 0.0,
        ),
      );
      return false;
    } finally {
      _currentlyDownloadingReciter = null;
      if (!_isDownloadingAll) {
        isGlobalDownloading.value = false;
        globalStatusText.value = '';
      }
    }
  }

  /// تحميل المصحف كاملاً لجميع القراء بالتتابع
  Future<void> downloadAllReciters() async {
    if (isGlobalDownloading.value) return;

    _isDownloadingAll = true;
    isGlobalDownloading.value = true;
    _cancelToken = CancelToken();

    try {
      final keys = reciterNames.keys.toList();
      for (int i = 0; i < keys.length; i++) {
        if (_cancelToken?.isCancelled ?? false) break;
        final key = keys[i];
        globalStatusText.value = "جاري تحميل القارئ (${i + 1}/${keys.length}): ${reciterNames[key]}";
        await downloadReciter(key);
      }
    } finally {
      _isDownloadingAll = false;
      isGlobalDownloading.value = false;
      globalStatusText.value = '';
    }
  }

  /// إيقاف وإلغاء عملية التحميل الجارية
  void cancelDownload() {
    _cancelToken?.cancel("Cancelled by user");
    _cancelToken = null;
    _isDownloadingAll = false;
    isGlobalDownloading.value = false;
    globalStatusText.value = 'تم إيقاف التنزيل';

    if (_currentlyDownloadingReciter != null) {
      final key = _currentlyDownloadingReciter!;
      final currentState = downloadStates.value[key];
      if (currentState != null) {
        _updateState(
          key,
          currentState.copyWith(
            isDownloading: false,
            currentStatus: "تم إيقاف التحميل",
          ),
        );
      }
      _currentlyDownloadingReciter = null;
    }
  }

  /// حذف التلاوات المحملة لقارئ معين
  Future<void> deleteReciterAudio(String reciterKey) async {
    try {
      final dir = await getReciterDirectory(reciterKey);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
      final total = getTotalItemsForReciter(reciterKey);
      _updateState(
        reciterKey,
        ReciterDownloadState(
          reciterKey: reciterKey,
          isDownloading: false,
          completedItems: 0,
          totalItems: total,
          currentStatus: "غير محمل",
          progress: 0.0,
        ),
      );
    } catch (_) {}
  }

  /// حذف جميع التلاوات المحملة لكافة القراء
  Future<void> deleteAllAudio() async {
    for (final key in reciterNames.keys) {
      await deleteReciterAudio(key);
    }
  }
}
