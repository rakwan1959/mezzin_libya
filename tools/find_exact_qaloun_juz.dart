import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('assets/database/quran/quran.qaloun.json');
  var content = await file.readAsString();
  content = content.replaceAllMapped(RegExp(r',\s*(\]|\})'), (m) => m.group(1)!);
  final List<dynamic> pages = jsonDecode(content);

  // List of standard Juz beginning texts
  final juzStartingPhrases = [
    {"juz": 1, "surah": 1, "phrase": "الحمد لله رب العالمين"},
    {"juz": 2, "surah": 2, "phrase": "سيقول السفهاء"},
    {"juz": 3, "surah": 2, "phrase": "تلك الرسل"},
    {"juz": 4, "surah": 3, "phrase": "كل الطعام"},
    {"juz": 5, "surah": 4, "phrase": "والمحصنات"},
    {"juz": 6, "surah": 4, "phrase": "لا يحب الله"},
    {"juz": 7, "surah": 5, "phrase": "لتجدن أشد الناس"},
    {"juz": 8, "surah": 6, "phrase": "ولو أننا نزلنا"},
    {"juz": 9, "surah": 7, "phrase": "قال الملأ الذين استكبروا"},
    {"juz": 10, "surah": 8, "phrase": "واعلموا أنما غنمتم"},
    {"juz": 11, "surah": 9, "phrase": "إنما السبيل"},
    {"juz": 12, "surah": 11, "phrase": "وما من دابة"},
    {"juz": 13, "surah": 12, "phrase": "وما أبرئ نفسي"},
    {"juz": 14, "surah": 15, "phrase": "الر تلك آيات"},
    {"juz": 15, "surah": 17, "phrase": "سبحان الذي أسرى"},
    {"juz": 16, "surah": 18, "phrase": "قال ألم أقل لك"},
    {"juz": 17, "surah": 21, "phrase": "اقترب للناس"},
    {"juz": 18, "surah": 23, "phrase": "قد أفلح المؤمنون"},
    {"juz": 19, "surah": 25, "phrase": "وقال الذين لا يرجون"},
    {"juz": 20, "surah": 27, "phrase": "فما كان جواب قومه"}, // أو أمن خلق
    {"juz": 21, "surah": 29, "phrase": "اتل ما أوحي"},
    {"juz": 22, "surah": 33, "phrase": "ومن يقنت"},
    {"juz": 23, "surah": 36, "phrase": "وما أنزلنا على قومه"},
    {"juz": 24, "surah": 39, "phrase": "فمن أظلم ممن كذب"},
    {"juz": 25, "surah": 41, "phrase": "إليه يرد علم"},
    {"juz": 26, "surah": 46, "phrase": "حم تنزيل"},
    {"juz": 27, "surah": 51, "phrase": "قال فما خطبكم"},
    {"juz": 28, "surah": 58, "phrase": "قد سمع الله"},
    {"juz": 29, "surah": 67, "phrase": "تبارك الذي بيده"},
    {"juz": 30, "surah": 78, "phrase": "عم يتساءلون"},
  ];

  final surahNamesOrder = [
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

  String normalize(String s) {
    return s
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Flatten all verses with their continuous surah index and ayah index
  List<Map<String, dynamic>> allVerses = [];
  String currentSurahName = '';
  int currentSurahId = 0;
  int currentAyahNum = 0;

  for (final page in pages) {
    final int pageNum = page['page'] as int? ?? 0;
    final verses = page['verses'] as List<dynamic>? ?? [];
    for (final v in verses) {
      final sName = v['surah']?.toString() ?? page['name']?.toString() ?? '';
      if (sName.isNotEmpty && sName != currentSurahName) {
        currentSurahName = sName;
        final norm = normalize(sName);
        for (int i = 0; i < surahNamesOrder.length; i++) {
          if (normalize(surahNamesOrder[i]) == norm) {
            currentSurahId = i + 1;
            break;
          }
        }
        currentAyahNum = 0;
      }
      currentAyahNum++;
      final rawText = v['text']?.toString() ?? '';
      final pureText = v['text_pure']?.toString() ?? rawText;
      allVerses.add({
        'surahId': currentSurahId,
        'surahName': surahNamesOrder[currentSurahId - 1],
        'ayahNumber': currentAyahNum,
        'page': pageNum,
        'text': rawText,
        'text_pure': pureText,
      });
    }
  }

  print('Loaded ${allVerses.length} verses from Qaloun.');

  // Find exact match for each Juz
  for (final jTarget in juzStartingPhrases) {
    final int jNum = jTarget['juz'] as int;
    final int targetSurah = jTarget['surah'] as int;
    final String phrase = normalize(jTarget['phrase'] as String);

    Map<String, dynamic>? matchedVerse;
    for (final v in allVerses) {
      if (v['surahId'] == targetSurah) {
        final normText = normalize(v['text_pure'] as String);
        if (normText.contains(phrase) || (phrase == "اتل ما اوحي" && normText.contains("اتل")) || (phrase == "فما كان جواب قومه" && (normText.contains("فما كان جواب") || normText.contains("امن خلق")))) {
          matchedVerse = v;
          break;
        }
      }
    }

    if (matchedVerse != null) {
      print('Juz $jNum -> Surah ${matchedVerse['surahId']} (${matchedVerse['surahName']}) Ayah ${matchedVerse['ayahNumber']} (Page ${matchedVerse['page']})');
      print('   Text: ${matchedVerse['text_pure'].toString().substring(0, 40)}...');
    } else {
      print('NOT FOUND: Juz $jNum (Surah $targetSurah, Phrase: $phrase)');
    }
  }
}
