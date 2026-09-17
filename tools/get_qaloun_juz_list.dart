import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('assets/database/quran/quran.qaloun.json');
  var content = await file.readAsString();
  content = content.replaceAllMapped(RegExp(r',\s*(\]|\})'), (m) => m.group(1)!);
  final List<dynamic> pages = jsonDecode(content);

  // In 604-page Mushaf, standard starting pages for Ajzaa:
  final juzPages = {
    1: 1,
    2: 22,
    3: 42,
    4: 62,
    5: 82,
    6: 102,
    7: 122,
    8: 142,
    9: 162,
    10: 182,
    11: 202,
    12: 222,
    13: 242,
    14: 262,
    15: 282,
    16: 302,
    17: 322,
    18: 342,
    19: 362,
    20: 382,
    21: 402,
    22: 422,
    23: 442,
    24: 462,
    25: 482,
    26: 502,
    27: 522,
    28: 542,
    29: 562,
    30: 582,
  };

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

  // Flatten verses to know their exact surahId and in-surah ayahNumber
  String currentSurahName = '';
  int currentSurahId = 0;
  int currentAyahNum = 0;

  // Map each page to its verses
  Map<int, List<Map<String, dynamic>>> pageVerses = {};

  for (final page in pages) {
    final int pageNum = page['page'] as int? ?? 0;
    pageVerses[pageNum] = [];
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
      final vData = {
        'surahId': currentSurahId,
        'surahName': surahNamesOrder[currentSurahId - 1],
        'ayahNumber': currentAyahNum,
        'page': pageNum,
        'text': v['text'],
        'text_pure': v['text_pure'] ?? v['text'],
      };
      pageVerses[pageNum]!.add(vData);
    }
  }

  print('=== EXACT QALOUN JUZ LIST (6214 Verses) ===');
  List<Map<String, dynamic>> qalounJuzList = [];

  for (int j = 1; j <= 30; j++) {
    final pNum = juzPages[j]!;
    final versesOnPage = pageVerses[pNum] ?? [];
    if (versesOnPage.isNotEmpty) {
      final firstV = versesOnPage.first;
      print('{"id": $j, "name": "الجزء ${j}", "start_surah": ${firstV['surahId']}, "start_ayah": ${firstV['ayahNumber']}, "page": $pNum}, // ${firstV['surahName']} - ${firstV['text_pure'].toString().substring(0, 30)}...');
      qalounJuzList.add({
        "id": j,
        "name": "الجزء $j",
        "start_surah": firstV['surahId'],
        "start_ayah": firstV['ayahNumber'],
        "page": pNum,
      });
    }
  }
}
