import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HadithItem {
  final int id;
  final String title;
  final String text;
  final String narrator;
  final bool? short;
  final String category;

  HadithItem({
    required this.id,
    required this.title,
    required this.text,
    required this.narrator,
    this.short,
    this.category = 'أحاديث نبوية عامة',
  });

  factory HadithItem.fromJson(Map<String, dynamic> json, {String category = 'أحاديث نبوية عامة'}) {
    final rawTitle = json['title']?.toString().trim() ?? '';
    return HadithItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: rawTitle.isNotEmpty ? rawTitle : 'قَالَ رَسُولُ اللَّهِ ﷺ',
      text: (json['hadeath'] ?? json['text'] ?? '').toString().trim(),
      narrator: json['narrator']?.toString().trim() ?? '',
      short: json['short'] == true,
      category: category,
    );
  }
}

class AyahTafseerItem {
  final int id;
  final String ayah;
  final String tafseer;
  final String surah;
  final String ayahNumber;
  final String source;

  AyahTafseerItem({
    required this.id,
    required this.ayah,
    required this.tafseer,
    required this.surah,
    required this.ayahNumber,
    required this.source,
  });

  factory AyahTafseerItem.fromJson(Map<String, dynamic> json) {
    return AyahTafseerItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      ayah: json['ayah']?.toString().trim() ?? '',
      tafseer: json['tafseer']?.toString().trim() ?? '',
      surah: json['sorah']?.toString().trim() ?? '',
      ayahNumber: json['ayahNumber']?.toString().trim() ?? '',
      source: json['source']?.toString().trim() ?? '',
    );
  }
}

/// خدمة الأحاديث النبوية والرمضانيات وآية وتفسير
class HadithDatabaseService {
  static HadithDatabaseService? _instance;
  static HadithDatabaseService get instance => _instance ??= HadithDatabaseService._();

  HadithDatabaseService._();

  List<HadithItem>? _prayerHadiths;
  List<HadithItem>? _ramadanHadiths;
  List<HadithItem>? _allHadiths;
  List<AyahTafseerItem>? _ayahTafseers;

  /// جلب أحاديث فضل الصلاة والعبادات (أحاديث عامة)
  Future<List<HadithItem>> getPrayerHadiths() async {
    if (_prayerHadiths != null) return _prayerHadiths!;
    try {
      final jsonStr = await rootBundle.loadString('assets/database/hadith/hadeath.json');
      final List<dynamic> list = json.decode(jsonStr);
      final seenTexts = <String>{};
      final items = <HadithItem>[];
      for (var i = 0; i < list.length; i++) {
        final item = list[i] as Map<String, dynamic>;
        final parsed = HadithItem.fromJson(item, category: 'أحاديث نبوية عامة');
        if (parsed.text.isNotEmpty && !seenTexts.contains(parsed.text)) {
          seenTexts.add(parsed.text);
          items.add(parsed);
        }
      }
      _prayerHadiths = items;
      return _prayerHadiths!;
    } catch (e) {
      debugPrint('HadithDB Error loading hadeath.json: $e');
      return [];
    }
  }

  /// جلب أحاديث وفضائل رمضان
  Future<List<HadithItem>> getRamadanHadiths() async {
    if (_ramadanHadiths != null) return _ramadanHadiths!;
    try {
      final jsonStr = await rootBundle.loadString('assets/database/hadith/ramadan.json');
      final List<dynamic> list = json.decode(jsonStr);
      final seenTexts = <String>{};
      final items = <HadithItem>[];
      for (var i = 0; i < list.length; i++) {
        final item = list[i] as Map<String, dynamic>;
        final parsed = HadithItem.fromJson(item, category: 'فضائل رمضان والصيام');
        if (parsed.text.isNotEmpty && !seenTexts.contains(parsed.text)) {
          seenTexts.add(parsed.text);
          items.add(parsed);
        }
      }
      _ramadanHadiths = items;
      return _ramadanHadiths!;
    } catch (e) {
      debugPrint('HadithDB Error loading ramadan.json: $e');
      return [];
    }
  }

  /// جلب كافة الأحاديث النبوية مجمعة ومصنفة
  Future<List<HadithItem>> getAllHadiths() async {
    if (_allHadiths != null) return _allHadiths!;
    final general = await getPrayerHadiths();
    final ramadan = await getRamadanHadiths();
    _allHadiths = [...general, ...ramadan];
    return _allHadiths!;
  }

  /// جلب آيات وتفاسير مختارة (آية وتفسير)
  Future<List<AyahTafseerItem>> getAyahTafseers() async {
    if (_ayahTafseers != null) return _ayahTafseers!;
    try {
      final jsonStr = await rootBundle.loadString('assets/database/quran/ayah.tafseer.json');
      final List<dynamic> list = json.decode(jsonStr);
      _ayahTafseers = list.map((item) => AyahTafseerItem.fromJson(item as Map<String, dynamic>)).toList();
      return _ayahTafseers!;
    } catch (e) {
      debugPrint('HadithDB Error loading ayah.tafseer.json: $e');
      return [];
    }
  }

  /// جلب حديث اليوم عشوائياً
  Future<HadithItem?> getDailyHadith() async {
    final list = await getAllHadiths();
    if (list.isEmpty) return null;
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return list[dayOfYear % list.length];
  }

  /// جلب آية وتفسير اليوم
  Future<AyahTafseerItem?> getDailyAyahTafseer() async {
    final list = await getAyahTafseers();
    if (list.isEmpty) return null;
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    return list[dayOfYear % list.length];
  }
}
