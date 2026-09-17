import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ThikrItem {
  final int id;
  final String title;
  final String body;
  final String repetition;
  final int count;
  final String narrator;
  final String reason;
  final String type;
  final bool isQuran;

  ThikrItem({
    required this.id,
    required this.title,
    required this.body,
    required this.repetition,
    required this.count,
    required this.narrator,
    required this.reason,
    required this.type,
    required this.isQuran,
  });

  factory ThikrItem.fromJson(Map<String, dynamic> json) {
    final repStr = json['repetition']?.toString() ?? '';
    int count = 1;
    if (repStr.contains('ثلاث') || repStr.contains('3')) {
      count = 3;
    } else if (repStr.contains('أربع') || repStr.contains('4')) {
      count = 4;
    } else if (repStr.contains('سبع') || repStr.contains('7')) {
      count = 7;
    } else if (repStr.contains('عشر') || repStr.contains('10')) {
      count = 10;
    } else if (repStr.contains('100') || repStr.contains('مائة') || repStr.contains('مئة')) {
      count = 100;
    } else if (repStr.contains('33')) {
      count = 33;
    }

    return ThikrItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: json['title']?.toString().trim() ?? '',
      body: json['body']?.toString().trim() ?? '',
      repetition: repStr.trim(),
      count: count,
      narrator: json['narrator']?.toString().trim() ?? '',
      reason: json['reason']?.toString().trim() ?? '',
      type: json['type']?.toString().trim() ?? '',
      isQuran: json['isQuran'] == true,
    );
  }
}

class AthkarCategory {
  final String key;
  final String name;
  final String icon;
  final String fileName;

  const AthkarCategory({
    required this.key,
    required this.name,
    required this.icon,
    required this.fileName,
  });
}

/// خدمة قاعدة بيانات الأذكار والأدعية المستخرجة من مؤذن ليبيا
class AthkarDatabaseService {
  static AthkarDatabaseService? _instance;
  static AthkarDatabaseService get instance => _instance ??= AthkarDatabaseService._();

  AthkarDatabaseService._();

  static const List<AthkarCategory> categories = [
    AthkarCategory(key: 'morning', name: 'أذكار الصباح', icon: '☀️', fileName: 'morning.json'),
    AthkarCategory(key: 'evening', name: 'أذكار المساء', icon: '🌙', fileName: 'evening.json'),
    AthkarCategory(key: 'after_prayer', name: 'أذكار بعد الصلاة', icon: '📿', fileName: 'after.prayer.json'),
    AthkarCategory(key: 'salah', name: 'أذكار الصلاة والأذان', icon: '🕌', fileName: 'salah.json'),
    AthkarCategory(key: 'ruqyah', name: 'الرقية الشرعية', icon: '🛡️', fileName: 'ruqyah.json'),
    AthkarCategory(key: 'sleep', name: 'أذكار النوم', icon: '🛌', fileName: 'sleep.json'),
    AthkarCategory(key: 'after_sleep', name: 'أذكار الاستيقاظ', icon: '🌅', fileName: 'after.sleep.json'),
    AthkarCategory(key: 'duaa', name: 'الأدعية المأثورة', icon: '🤲', fileName: 'duaa.json'),
    AthkarCategory(key: 'karob', name: 'أدعية تفريج الكرب والهم', icon: '🌿', fileName: 'karob.json'),
    AthkarCategory(key: 'fasting', name: 'أذكار الصيام والإفطار', icon: '🥣', fileName: 'fasting.json'),
    AthkarCategory(key: 'eating', name: 'أذكار الطعام والشراب', icon: '🍽️', fileName: 'eating.json'),
    AthkarCategory(key: 'travel', name: 'أذكار السفر وركوب الدابة', icon: '🚗', fileName: 'travel.json'),
    AthkarCategory(key: 'home', name: 'أذكار دخول وخروج المنزل', icon: '🏠', fileName: 'home.json'),
    AthkarCategory(key: 'taharah', name: 'أذكار الوضوء والخلاء', icon: '💧', fileName: 'taharah.json'),
    AthkarCategory(key: 'duaa_widget', name: 'جوامع الدعاء اليومية', icon: '✨', fileName: 'duaa.widget.json'),
  ];

  final Map<String, List<ThikrItem>> _cache = {};

  /// جلب الأذكار حسب التصنيف
  Future<List<ThikrItem>> getAthkarByCategory(String key) async {
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final category = categories.firstWhere(
      (c) => c.key == key || c.fileName == key || c.fileName == '$key.json',
      orElse: () => categories.first,
    );

    try {
      final path = 'assets/database/athkar/${category.fileName}';
      final jsonStr = await rootBundle.loadString(path);
      final List<dynamic> raw = json.decode(jsonStr);
      final list = raw.map((item) => ThikrItem.fromJson(item as Map<String, dynamic>)).toList();
      _cache[key] = list;
      return list;
    } catch (e) {
      debugPrint('AthkarDatabaseService Error loading ${category.fileName}: $e');
      return [];
    }
  }

  /// جلب ذكر أو دعاء عشوائي يومي
  Future<ThikrItem?> getRandomDuaa() async {
    final list = await getAthkarByCategory('duaa_widget');
    if (list.isEmpty) return null;
    list.shuffle();
    return list.first;
  }
}
