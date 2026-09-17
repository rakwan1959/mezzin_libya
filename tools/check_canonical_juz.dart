import 'dart:convert';
import 'dart:io';

void main() async {
  // Let's find the exact starting verse of each of the 30 canonical Ajzaa in Qaloun!
  // In Qaloun text:
  final targets = [
    {"juz": 1, "text_starts": "الحمد لله رب العالمين"},
    {"juz": 2, "text_starts": "سيقول السفهاء"},
    {"juz": 3, "text_starts": "تلك الرسل"},
    {"juz": 4, "text_starts": "كل الطعام"},
    {"juz": 5, "text_starts": "والمحصنات"},
    {"juz": 6, "text_starts": "لا يحب الله الجهر"},
    {"juz": 7, "text_starts": "لتجدن أشد الناس"},
    {"juz": 8, "text_starts": "ولو أننا نزلنا"},
    {"juz": 9, "text_starts": "قال الملأ الذين استكبروا"},
    {"juz": 10, "text_starts": "واعلموا أنما غنمتم"},
    {"juz": 11, "text_starts": "إنما السبيل"}, // أو يعتذرون
    {"juz": 12, "text_starts": "وما من دابة"},
    {"juz": 13, "text_starts": "وما أبرئ نفسي"},
    {"juz": 14, "text_starts": "الر تلك آيات"}, // الحجر
    {"juz": 15, "text_starts": "سبحان الذي أسرى"}, // الإسراء
    {"juz": 16, "text_starts": "قال ألم أقل لك"},
    {"juz": 17, "text_starts": "اقترب للناس"},
    {"juz": 18, "text_starts": "قد أفلح المؤمنون"},
    {"juz": 19, "text_starts": "وقال الذين لا يرجون"},
    {"juz": 20, "text_starts": "فما كان جواب قومه"}, // أو أمن خلق
    {"juz": 21, "text_starts": "اتل ما أوحي"},
    {"juz": 22, "text_starts": "ومن يقنت"},
    {"juz": 23, "text_starts": "وما أنزلنا على قومه"},
    {"juz": 24, "text_starts": "فمن أظلم ممن كذب"},
    {"juz": 25, "text_starts": "إليه يرد علم"},
    {"juz": 26, "text_starts": "حم تنزيل الكتاب"}, // الأحقاف
    {"juz": 27, "text_starts": "قال فما خطبكم"},
    {"juz": 28, "text_starts": "قد سمع الله"},
    {"juz": 29, "text_starts": "تبارك الذي بيده"},
    {"juz": 30, "text_starts": "عم يتساءلون"},
  ];

  print('Canonical target list created with ${targets.length} ajzaa.');
}
