import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('assets/database/quran/quran.qaloun.json');
  if (!file.existsSync()) {
    print('Not found: assets/database/quran/quran.qaloun.json');
    return;
  }
  var content = await file.readAsString();
  content = content.replaceAllMapped(RegExp(r',\s*(\]|\})'), (m) => m.group(1)!);
  final List<dynamic> pages = jsonDecode(content);
  print('Total pages in quran.qaloun.json: ${pages.length}');

  // Track Juz boundaries
  Map<int, Map<String, dynamic>> juzBounds = {};
  int totalVerses = 0;

  for (final page in pages) {
    final int juz = page['jozz'] as int? ?? 0;
    final verses = page['verses'] as List<dynamic>? ?? [];
    totalVerses += verses.length;

    for (final v in verses) {
      final sName = v['surah']?.toString() ?? page['name']?.toString() ?? '';
      final int vId = v['id'] as int? ?? 0;

      if (!juzBounds.containsKey(juz)) {
        juzBounds[juz] = {
          'first_surah': sName,
          'first_ayah': vId,
          'first_text': v['text_pure'] ?? v['text'],
          'last_surah': sName,
          'last_ayah': vId,
          'last_text': v['text_pure'] ?? v['text'],
          'count': 0,
        };
      }
      juzBounds[juz]!['last_surah'] = sName;
      juzBounds[juz]!['last_ayah'] = vId;
      juzBounds[juz]!['last_text'] = v['text_pure'] ?? v['text'];
      juzBounds[juz]!['count'] = (juzBounds[juz]!['count'] as int) + 1;
    }
  }

  print('Total verses in quran.qaloun.json: $totalVerses');
  print('Juz bounds:');
  for (int j = 1; j <= 30; j++) {
    final b = juzBounds[j];
    if (b != null) {
      print('Juz $j: Start = ${b['first_surah']} (ayah ${b['first_ayah']}), End = ${b['last_surah']} (ayah ${b['last_ayah']}) [verses=${b['count']}]');
      print('   Start text: ${b['first_text']}');
    }
  }
}
