import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../quran/data/datasources/quran_local_data_source.dart';
import '../../injection_container.dart';

enum VoiceCommandType { 
  playSurah, 
  webSearch, 
  chatGpt, 
  playAyah, 
  navHome, 
  navQibla, 
  navSettings, 
  navAbout,
  navLibrary,
  unknown 
}

class VoiceCommandResult {
  final VoiceCommandType type;
  final String? payload; // اسم السورة أو رقم الآية أو نص البحث
  final int? surahId;
  final int? ayahNumber;

  VoiceCommandResult({required this.type, this.payload, this.surahId, this.ayahNumber});
}

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  final ValueNotifier<bool> isListeningNotifier = ValueNotifier<bool>(false);

  bool get isListening => _speech.isListening;

  /// قاعدة بيانات أسماء سور القرآن الكريم: رقم السورة ← الاسم الرسمي
  /// (ربط كل اسم برقم سورته مباشرة بدلاً من الاعتماد على ترتيب القائمة)
  static const Map<int, String> _surahNamesById = {
    1: "الفاتحة", 2: "البقرة", 3: "آل عمران", 4: "النساء", 5: "المائدة",
    6: "الأنعام", 7: "الأعراف", 8: "الأنفال", 9: "التوبة", 10: "يونس",
    11: "هود", 12: "يوسف", 13: "الرعد", 14: "إبراهيم", 15: "الحجر",
    16: "النحل", 17: "الإسراء", 18: "الكهف", 19: "مريم", 20: "طه",
    21: "الأنبياء", 22: "الحج", 23: "المؤمنون", 24: "النور", 25: "الفرقان",
    26: "الشعراء", 27: "النمل", 28: "القصص", 29: "العنكبوت", 30: "الروم",
    31: "لقمان", 32: "السجدة", 33: "الأحزاب", 34: "سبأ", 35: "فاطر",
    36: "يس", 37: "الصافات", 38: "ص", 39: "الزمر", 40: "غافر",
    41: "فصلت", 42: "الشورى", 43: "الزخرف", 44: "الدخان", 45: "الجاثية",
    46: "الأحقاف", 47: "محمد", 48: "الفتح", 49: "الحجرات", 50: "ق",
    51: "الذاريات", 52: "الطور", 53: "النجم", 54: "القمر", 55: "الرحمن",
    56: "الواقعة", 57: "الحديد", 58: "المجادلة", 59: "الحشر", 60: "الممتحنة",
    61: "الصف", 62: "الجمعة", 63: "المنافقون", 64: "التغابن", 65: "الطلاق",
    66: "التحريم", 67: "الملك", 68: "القلم", 69: "الحاقة", 70: "المعارج",
    71: "نوح", 72: "الجن", 73: "المزمل", 74: "المدثر", 75: "القيامة",
    76: "الإنسان", 77: "المرسلات", 78: "النبأ", 79: "النازعات", 80: "عبس",
    81: "التكوير", 82: "الانفطار", 83: "المطففين", 84: "الانشقاق", 85: "البروج",
    86: "الطارق", 87: "الأعلى", 88: "الغاشية", 89: "الفجر", 90: "البلد",
    91: "الشمس", 92: "الليل", 93: "الضحى", 94: "الشرح", 95: "التين",
    96: "العلق", 97: "القدر", 98: "البينة", 99: "الزلزلة", 100: "العاديات",
    101: "القارعة", 102: "التكاثر", 103: "العصر", 104: "الهمزة", 105: "الفيل",
    106: "قريش", 107: "الماعون", 108: "الكوثر", 109: "الكافرون", 110: "النصر",
    111: "المسد", 112: "الإخلاص", 113: "الفلق", 114: "الناس",
  };

  static const List<String> _googleTriggers = ["قوقل", "جوجل", "google"];
  static const List<String> _chatGptTriggers = ["شات", "شات جي بي تي", "chatgpt"];

  static const Map<String, VoiceCommandType> _navCommands = {
    "1": VoiceCommandType.navHome,
    "واحد": VoiceCommandType.navHome,
    "2": VoiceCommandType.navQibla,
    "اثنان": VoiceCommandType.navQibla,
    "اتنين": VoiceCommandType.navQibla,
    "3": VoiceCommandType.navSettings,
    "ثلاثه": VoiceCommandType.navSettings,
    "ثلاثة": VoiceCommandType.navSettings,
    "4": VoiceCommandType.navAbout,
    "اربع": VoiceCommandType.navAbout,
    "اربعة": VoiceCommandType.navAbout,
    "أربعة": VoiceCommandType.navAbout,
    "5": VoiceCommandType.navLibrary,
    "خمسه": VoiceCommandType.navLibrary,
    "خمسة": VoiceCommandType.navLibrary,
  };

  /// قاعدة بيانات الأسماء البديلة: رقم السورة ← قائمة الأسماء الأخرى المعروفة لها
  /// (تشمل الألقاب المشهورة وصيغ النطق المختلفة التي قد يخرجها التعرف الصوتي)
  static const Map<int, List<String>> _surahAliases = {
    1: ["الحمد", "فاتحة الكتاب"],
    2: ["البقره"],
    3: ["عمران"],
    9: ["براءة", "البراءة", "التوبه"],
    17: ["بني اسرائيل", "بني إسرائيل", "الاسراء"],
    20: ["طاها"],
    36: ["ياسين"],
    38: ["صاد"],
    40: ["المومن", "المؤمن"],
    41: ["حم السجدة", "حم السجده"],
    42: ["حم عسق"],
    47: ["القتال"],
    50: ["قاف"],
    67: ["تبارك"],
    76: ["الدهر", "الأبرار"],
    78: ["عما"],
    94: ["الانشراح"],
    107: ["ارايت", "أرأيت"],
    111: ["تبت", "اللهب", "ابي لهب", "أبي لهب"],
    112: ["قل هو الله احد", "قل هو الله أحد"],
  };

  Future<bool> initialize({Function(String)? onStatus}) async {
    // طلب الإذن يدوياً للتأكد
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) return false;
    }

    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          debugPrint('STT Status: $status');
          if (status == 'listening') {
            isListeningNotifier.value = true;
          } else {
            isListeningNotifier.value = false;
          }
          if (onStatus != null) onStatus(status);
        },
        onError: (error) {
          debugPrint('STT Error: $error');
          isListeningNotifier.value = false;
        },
        finalTimeout: const Duration(milliseconds: 10000),
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('STT Init Exception: $e');
      return false;
    }
  }

  Future<void> listen({required Function(String) onResult, Function(String)? onStatus}) async {
    try {
      if (!_isInitialized) {
        bool init = await initialize(onStatus: onStatus);
        if (!init) {
          debugPrint('VoiceService: Failed to initialize');
          return;
        }
      }
      
      if (_speech.isListening) return;

      isListeningNotifier.value = true;
      await _speech.listen(
        onResult: (val) {
          onResult(val.recognizedWords);
        },
        localeId: 'ar_SA',
        cancelOnError: false,
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 15),
      );
    } catch (e) {
      debugPrint('VoiceService Listen Error: $e');
      isListeningNotifier.value = false;
    }
  }

  Future<void> stop() async {
    await _speech.stop();
    isListeningNotifier.value = false;
  }

  Future<VoiceCommandResult> processCommand(String text) async {
    String input = text.toLowerCase().trim();
    String normalizedInput = _normalizeArabic(input);

    // 1. التحقق من أرقام التنقل
    for (var entry in _navCommands.entries) {
      if (normalizedInput == _normalizeArabic(entry.key) || input == entry.key) {
        return VoiceCommandResult(type: entry.value);
      }
    }

    // 2. التحقق من قوقل
    for (var trigger in _googleTriggers) {
      if (normalizedInput.startsWith(_normalizeArabic(trigger))) {
        String query = normalizedInput.replaceFirst(_normalizeArabic(trigger), "").trim();
        return VoiceCommandResult(type: VoiceCommandType.webSearch, payload: query);
      }
    }

    // 3. التحقق من شات
    for (var trigger in _chatGptTriggers) {
      if (normalizedInput.startsWith(_normalizeArabic(trigger))) {
        String query = normalizedInput.replaceFirst(_normalizeArabic(trigger), "").trim();
        return VoiceCommandResult(type: VoiceCommandType.chatGpt, payload: query);
      }
    }

    String normalizedInputNoSpaces = normalizedInput.replaceAll(' ', '');

    // 3. التحقق من السورة والآية (بحث محسن بالألقاب والأسماء)
    // جمع كل الأسماء (الرسمية + البديلة) مع رقم سورتها، ثم ترتيبها من الأطول إلى الأقصر
    // حتى لا يخطف الاسم القصير (مثل "ق" أو "ص" أو "الحج") أسماء أطول تحتوي على حروفه
    // مثال: "القمر" يجب أن تطابق سورة القمر (54) وليس سورة ق (50) لمجرد احتوائها على حرف القاف
    final List<(int, String)> nameCandidates = [];
    _surahNamesById.forEach((surahId, name) {
      nameCandidates.add((surahId, name));
      final aliases = _surahAliases[surahId];
      if (aliases != null) {
        for (final alias in aliases) {
          nameCandidates.add((surahId, alias));
        }
      }
    });
    nameCandidates.sort((a, b) {
      final int lenA = _normalizeArabic(a.$2).replaceAll(' ', '').length;
      final int lenB = _normalizeArabic(b.$2).replaceAll(' ', '').length;
      if (lenA != lenB) return lenB.compareTo(lenA);
      return a.$1.compareTo(b.$1);
    });

    for (final (surahId, name) in nameCandidates) {
      String normName = _normalizeArabic(name).replaceAll(' ', '');
      if (normName.isNotEmpty && normalizedInputNoSpaces.contains(normName)) {
        // محاولة استخراج رقم الآية
        RegExp regExp = RegExp(r'(\d+)');
        Match? match = regExp.firstMatch(input);
        if (match != null) {
          int ayahNo = int.parse(match.group(0)!);
          return VoiceCommandResult(
            type: VoiceCommandType.playAyah,
            payload: _surahNamesById[surahId],
            surahId: surahId,
            ayahNumber: ayahNo,
          );
        }
        return VoiceCommandResult(
          type: VoiceCommandType.playSurah,
          payload: _surahNamesById[surahId],
          surahId: surahId,
        );
      }
    }

    // 4. البحث الذكي في نص الآيات (إذا لم يطابق اسم سورة)
    if (normalizedInput.length > 5) {
      final localSource = sl<QuranLocalDataSource>();
      final results = await localSource.searchAyahs(text);
      if (results.isNotEmpty) {
        final firstMatch = results.first;
        return VoiceCommandResult(
          type: VoiceCommandType.playAyah,
          payload: _surahNamesById[firstMatch.surahId],
          surahId: firstMatch.surahId,
          ayahNumber: firstMatch.ayahNumber,
        );
      }
    }

    return VoiceCommandResult(type: VoiceCommandType.unknown, payload: text);
  }

  String _normalizeArabic(String text) {
    return text
        .replaceAll(RegExp(r'[\u064B-\u065F]'), '') // حذف التشكيل
        .replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه').replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و').replaceAll('ئ', 'ي')
        .replaceAll('ء', '')
        .trim();
  }
}
