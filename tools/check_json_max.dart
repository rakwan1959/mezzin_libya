import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('assets/database/quran/quran.qaloun.json');
  var content = await file.readAsString();
  content = content.replaceAllMapped(RegExp(r',\s*(\]|\})'), (m) => m.group(1)!);
  final List<dynamic> pages = jsonDecode(content);
  
  for (var page in pages) {
    var verses = page['verses'] as List<dynamic>;
    for (var v in verses) {
      if (v['surah'].toString().contains('البقرة') || v['surah'].toString().contains('البَقَرَة')) {
        print('Surah: "${v['surah']}", id: ${v['id']}');
      }
    }
  }
}
