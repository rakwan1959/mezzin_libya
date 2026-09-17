import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('assets/database/quran/tafseer.json');
  var content = await file.readAsString();
  final fixed = content.replaceAllMapped(RegExp(r',\s*(\]|\})'), (m) => m.group(1)!);
  final List<dynamic> pages = jsonDecode(fixed);

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

  String normalizeName(String name) {
    return name
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .trim();
  }

  final Map<String, String> tafsirMap = {};

  String currentSurah = '';
  int currentSurahId = 0;
  int currentAyahInSurah = 0;

  for (final page in pages) {
    final verses = page['verses'] as List<dynamic>? ?? [];
    for (final v in verses) {
      final sName = v['surah']?.toString() ?? '';
      if (sName.isNotEmpty && sName != currentSurah) {
        currentSurah = sName;
        final norm = normalizeName(sName);
        int matchedId = 0;
        for (int i = 0; i < surahNamesOrder.length; i++) {
          if (normalizeName(surahNamesOrder[i]) == norm) {
            matchedId = i + 1;
            break;
          }
        }
        currentSurahId = matchedId;
        currentAyahInSurah = 0;
      }
      currentAyahInSurah++;
      final tafseerText = v['tafseer']?.toString().trim() ?? '';
      if (currentSurahId > 0 && currentAyahInSurah > 0) {
        tafsirMap['$currentSurahId:$currentAyahInSurah'] = tafseerText;
      }
    }
  }

  // Add Page 604: Al-Ikhlas (112), Al-Falaq (113), An-Nas (114)
  // Al-Ikhlas
  tafsirMap['112:1'] = "قل -أيها الرسول- لهؤلاء المشركين المستهزئين: هو الله المتفرد بالألوهية والربوبية والأسماء والصفات، لا شريك له.";
  tafsirMap['112:2'] = "الله وحده المستحق للعبادة، الذي تصمد إليه الخلائق وتقصده في جميع حوائجها ورغائبها.";
  tafsirMap['112:3'] = "تنزه سبحانه وتعالى عن أن يكون له ولد أو والد أو صاحبة.";
  tafsirMap['112:4'] = "ولم يكن له مماثل ولا شبيه ولا نظير من خلقه، سبحانه وتعالى عما يشركون.";

  // Al-Falaq
  tafsirMap['113:1'] = "قل -أيها الرسول-: أعتصم وألتجئ برب الصبح وفالقه ومبديه.";
  tafsirMap['113:2'] = "من شر جميع المخلوقات وأذاها ومفاسدها.";
  tafsirMap['113:3'] = "ومن شر الليل إذا دخل بظلامه وما ينتشر فيه من الشرور والمؤذيات.";
  tafsirMap['113:4'] = "ومن شر الساحرات والنفوس الشريرة اللاتي يعقدن العقد وينفثن فيها بالسحر.";
  tafsirMap['113:5'] = "ومن شر حاسد إذا تمنى زوال النعمة عن غيره وسعى في إيقاع الشر به والأذى.";

  // An-Nas
  tafsirMap['114:1'] = "قل -أيها الرسول-: أعتصم وألتجئ برب الناس، خالقهم ومدبر أمورهم.";
  tafsirMap['114:2'] = "ملك الناس ومالكهم والمتصرف في شؤونهم وسلطانهم الحق.";
  tafsirMap['114:3'] = "إله الناس ومعبودهم الحق الذي لا إله لهم سواه ولا معبود بحق إلا هو.";
  tafsirMap['114:4'] = "من شر الشيطان الموسوس الذي يلقي وسواسه إلى الإنسان عند الغفلة، ويختفي ويخنس عند ذكر الله تعالى.";
  tafsirMap['114:5'] = "الذي يبث الشر والشكوك والشبهات في صدور الناس وقلوبهم.";
  tafsirMap['114:6'] = "من شياطين الجن وشياطين الإنس، فالاستعاذة تكون من شر الفريقين جميعاً.";

  print('Total verses in complete map: ${tafsirMap.length}');

  // Save to assets/database/quran/tafseer_map.json
  final outFile = File('assets/database/quran/tafseer_map.json');
  final jsonStr = jsonEncode(tafsirMap);
  await outFile.writeAsString(jsonStr);
  print('Saved to assets/database/quran/tafseer_map.json (size: ${jsonStr.length} bytes)');

  // Also save to database/tafseer_map.json
  final dbOutFile = File('database/tafseer_map.json');
  await dbOutFile.writeAsString(jsonStr);
  print('Saved to database/tafseer_map.json');
}
