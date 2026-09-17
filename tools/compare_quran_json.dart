import 'dart:convert';
import 'dart:io';

void main() async {
  // Let's check database/quran.qaloun.json and database/quran.qaloun2.json
  for (final name in ['assets/database/quran/quran.qaloun.json', 'database/quran.qaloun2.json', 'assets/database/quran/quran.hafs.json']) {
    final file = File(name);
    if (!file.existsSync()) continue;
    var content = await file.readAsString();
    content = content.replaceAllMapped(RegExp(r',\s*(\]|\})'), (m) => m.group(1)!);
    final List<dynamic> pages = jsonDecode(content);
    print('--- $name (pages: ${pages.length}) ---');
    // Check which page has jozz == 30
    final p30 = pages.firstWhere((p) => p['jozz'] == 30, orElse: () => null);
    if (p30 != null) {
      print('First page with jozz=30 is page ${p30['page']}, name=${p30['name']}');
      final firstV = (p30['verses'] as List).first;
      print('First verse on that page: ${firstV['text_pure'] ?? firstV['text']}');
    }
  }
}
