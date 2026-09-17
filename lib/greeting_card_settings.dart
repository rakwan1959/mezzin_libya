import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إعدادات كارد الرسالة (رسالة السلام) — تُدار بالكامل من اللوحة الأولى (1916)
/// في شاشة «عن التطبيق»:
///
///   • التفعيل      : يظهر الكارد عند فتح التطبيق أم لا.
///   • النص         : نص الرسالة — يُعرض في منتصف الكارد عند فتح التطبيق.
///   • اللون        : نمط جاهز يختاره المدير من مجموعة ألوان.
///   • النغمة       : نغمة خاصة مصاحبة لظهور الكارد.
///
/// التخزين: مفاتيح محلية في SharedPreferences + حقل واحد في `app_config`
/// هو `greeting_message` الذي يُكتب بصيغة JSON (نفس أسلوب `dedication_msg`).
/// بهذا تصل الألوان والنغمة لكل الأجهزة **بلا أي تعديل على قاعدة البيانات**.

/// ──────────────────────────────────────────────────────────────────────────────
///  نغمة كارد الرسالة
/// ──────────────────────────────────────────────────────────────────────────────
class GreetingTone {
  const GreetingTone({
    required this.id,
    required this.labelAr,
    required this.asset,
  });

  /// المعرّف الذي يُخزَّن ويُنشَر ويُمرَّر للجانب الأصلي (Android).
  final String id;

  /// الاسم المعروض في اللوحة.
  final String labelAr;

  /// مسار الملف في أصول التطبيق (احتياط التشغيل داخل Flutter).
  final String asset;

  /// الرنّة المميّزة للكارد (الافتراضية) — نوتتان صاعدتان هادئتان.
  static const GreetingTone chime = GreetingTone(
    id: 'greeting_chime',
    labelAr: 'رنّة الكارد (افتراضية)',
    asset: 'assets/audio/greeting_chime.wav',
  );

  /// جرس ثلاثي قصير — بديل أخفّ وأعلى قليلاً.
  static const GreetingTone bell = GreetingTone(
    id: 'greeting_bell',
    labelAr: 'جرس ثلاثي',
    asset: 'assets/audio/greeting_bell.wav',
  );

  /// بدون نغمة — للاختبار الصامت.
  static const GreetingTone silent = GreetingTone(
    id: 'silent',
    labelAr: 'بدون نغمة',
    asset: '',
  );

  /// كل النغمات المتاحة في اللوحة.
  static const List<GreetingTone> all = <GreetingTone>[chime, bell, silent];

  /// المعرّف الافتراضي.
  static const String defaultId = 'greeting_chime';

  /// نغمة آمنة دائماً (أي معرّف مجهول يعود إلى الرنّة الافتراضية).
  static GreetingTone byId(String? id) {
    final String key = (id ?? '').trim().toLowerCase();
    for (final GreetingTone t in all) {
      if (t.id.toLowerCase() == key) return t;
    }
    return chime;
  }

  bool get isSilent => id == silent.id;
}

/// ──────────────────────────────────────────────────────────────────────────────
///  لون كارد الرسالة (نمط جاهز)
/// ──────────────────────────────────────────────────────────────────────────────
class GreetingCardStyle {
  const GreetingCardStyle({
    required this.id,
    required this.labelAr,
    required this.accent,
    required this.surface,
  });

  final String id;
  final String labelAr;

  /// لون الحدّ والتوهّج (التمييز).
  final Color accent;

  /// خلفية الكارد.
  final Color surface;

  static const GreetingCardStyle gold = GreetingCardStyle(
    id: 'gold',
    labelAr: 'ذهبي',
    accent: Color(0xFFDFBA6B),
    surface: Color(0xFF1A1508),
  );
  static const GreetingCardStyle navy = GreetingCardStyle(
    id: 'navy',
    labelAr: 'كحلي',
    accent: Color(0xFF4C8FD6),
    surface: Color(0xFF001233),
  );
  static const GreetingCardStyle purple = GreetingCardStyle(
    id: 'purple',
    labelAr: 'بنفسجي',
    accent: Color(0xFF9B7BD4),
    surface: Color(0xFF16002B),
  );
  /// نيلي — `#4B0082` (اللون المطلوب إضافته).
  ///
  /// الكارد يأخذ `#4B0082` نفسه كخلفية، والحدّ والتوهّج بدرجة فاتحة منه حتى
  /// يُقرأ زر الإغلاق بوضوح على الخلفية الداكنة.
  static const GreetingCardStyle indigo = GreetingCardStyle(
    id: 'indigo',
    labelAr: 'نيلي',
    accent: Color(0xFFB98CE6),
    surface: Color(0xFF4B0082),
  );

  /// بنفسجي داكن — `#493267` (اللون المطلوب إضافته).
  static const GreetingCardStyle deepViolet = GreetingCardStyle(
    id: 'deep_violet',
    labelAr: 'بنفسجي داكن',
    accent: Color(0xFFC2A6EA),
    surface: Color(0xFF493267),
  );

  /// أرجواني — `#3C215E` (لون مضاف بطلب المستخدم).
  ///
  /// الكارد يأخذ `#3C215E` نفسه كخلفية، والحدّ والتوهّج بدرجة فاتحة منه حتى
  /// يُقرأ زر الإغلاق بوضوح على الخلفية الداكنة.
  static const GreetingCardStyle royalPurple = GreetingCardStyle(
    id: 'royal_purple',
    labelAr: 'أرجواني',
    accent: Color(0xFFA98CD9),
    surface: Color(0xFF3C215E),
  );

  /// نيلي ملكي — `#370F94` (لون مضاف بطلب المستخدم).
  static const GreetingCardStyle royalIndigo = GreetingCardStyle(
    id: 'royal_indigo',
    labelAr: 'نيلي ملكي',
    accent: Color(0xFF9C7DF0),
    surface: Color(0xFF370F94),
  );

  static const GreetingCardStyle teal = GreetingCardStyle(
    id: 'teal',
    labelAr: 'فيروزي',
    accent: Color(0xFF4DD0C0),
    surface: Color(0xFF06201E),
  );
  static const GreetingCardStyle green = GreetingCardStyle(
    id: 'green',
    labelAr: 'أخضر',
    accent: Color(0xFF5CC98A),
    surface: Color(0xFF08200F),
  );
  static const GreetingCardStyle red = GreetingCardStyle(
    id: 'red',
    labelAr: 'أحمر',
    accent: Color(0xFFE06A6A),
    surface: Color(0xFF260A0A),
  );
  static const GreetingCardStyle white = GreetingCardStyle(
    id: 'white',
    labelAr: 'أبيض',
    accent: Color(0xFFEDEDED),
    surface: Color(0xFF14141A),
  );
  static const GreetingCardStyle black = GreetingCardStyle(
    id: 'black',
    labelAr: 'أسود',
    accent: Color(0xFF6E6E78),
    surface: Color(0xFF000000),
  );

  /// كل الألوان المعروضة في اللوحة (بالترتيب).
  static const List<GreetingCardStyle> all = <GreetingCardStyle>[
    gold,
    navy,
    purple,
    indigo,
    deepViolet,
    royalPurple,
    royalIndigo,
    teal,
    green,
    red,
    white,
    black,
  ];

  /// اللون الافتراضي.
  static const String defaultId = 'gold';

  /// نمط آمن دائماً (أي معرّف مجهول يعود إلى الذهبي).
  static GreetingCardStyle byId(String? id) {
    final String key = (id ?? '').trim().toLowerCase();
    for (final GreetingCardStyle s in all) {
      if (s.id.toLowerCase() == key) return s;
    }
    return gold;
  }
}

/// ──────────────────────────────────────────────────────────────────────────────
///  إعدادات الرسالة كاملة (تفعيل + نص + لون + نغمة)
/// ──────────────────────────────────────────────────────────────────────────────
class GreetingSettings {
  const GreetingSettings({
    this.enabled = false,
    this.message = '',
    this.colorId = GreetingCardStyle.defaultId,
    this.toneId = GreetingTone.defaultId,
  });

  final bool enabled;
  final String message;
  final String colorId;
  final String toneId;

  GreetingCardStyle get style => GreetingCardStyle.byId(colorId);
  GreetingTone get tone => GreetingTone.byId(toneId);

  // ── مفاتيح التخزين المحلي (تُقرأ من الشاشة الرئيسية واللوحة معاً) ──────────
  static const String enabledKey = 'remote_greeting_enabled';
  static const String messageKey = 'remote_greeting_message';
  static const String colorKey = 'remote_greeting_color';
  static const String toneKey = 'remote_greeting_tone';

  /// بصمة الرسالة الحالية — تُستخدم لمنع تكرار الكارد والنغمة لكل إعداد جديد.
  String get deliveryKey => '$message|$colorId|$toneId';

  GreetingSettings copyWith({
    bool? enabled,
    String? message,
    String? colorId,
    String? toneId,
  }) {
    return GreetingSettings(
      enabled: enabled ?? this.enabled,
      message: message ?? this.message,
      colorId: colorId ?? this.colorId,
      toneId: toneId ?? this.toneId,
    );
  }

  static GreetingSettings fromPrefs(SharedPreferences p) => GreetingSettings(
    enabled: p.getBool(enabledKey) ?? false,
    message: p.getString(messageKey) ?? '',
    colorId: p.getString(colorKey) ?? GreetingCardStyle.defaultId,
    toneId: p.getString(toneKey) ?? GreetingTone.defaultId,
  );

  Future<void> saveLocally(SharedPreferences p) async {
    await p.setBool(enabledKey, enabled);
    await p.setString(messageKey, message.trim());
    await p.setString(colorKey, style.id);
    await p.setString(toneKey, tone.id);
  }

  /// الحمولة المرسلة إلى `app_config`.
  ///
  /// النص يُغلَّف في JSON داخل عمود `greeting_message` الموجود أصلاً، فيسافر
  /// اللون والنغمة معه بلا أي عمود جديد ولا تعديل SQL.
  Map<String, dynamic> toRemotePayload() => <String, dynamic>{
    'greeting_enabled': enabled,
    'greeting_message': encode(message: message, colorId: colorId, toneId: toneId),
  };

  /// تغليف الإعدادات في نص JSON واحد.
  static String encode({
    required String message,
    required String colorId,
    required String toneId,
  }) {
    return jsonEncode(<String, dynamic>{
      'v': 1,
      'text': message,
      'color': GreetingCardStyle.byId(colorId).id,
      'tone': GreetingTone.byId(toneId).id,
    });
  }

  /// فك التغليف. يقبل أيضاً النص القديم العادي (قبل إضافة الألوان والنغمات)
  /// فيتعامل معه كنصٍ بلون ونغمة افتراضية — فلا تتعطّل رسالة منشورة سابقاً.
  static GreetingSettings decode(String? raw) {
    final String value = (raw ?? '').trim();
    if (value.isEmpty) return const GreetingSettings();

    if (!value.startsWith('{')) {
      return GreetingSettings(
        message: value,
        colorId: GreetingCardStyle.defaultId,
        toneId: GreetingTone.defaultId,
      );
    }

    try {
      final dynamic parsed = jsonDecode(value);
      if (parsed is! Map) {
        return GreetingSettings(message: value);
      }
      return GreetingSettings(
        message: (parsed['text'] ?? '').toString(),
        colorId: GreetingCardStyle.byId(parsed['color']?.toString()).id,
        toneId: GreetingTone.byId(parsed['tone']?.toString()).id,
      );
    } catch (_) {
      // JSON تالف (رسالة قديمة أو بثّ نصي) → نتعامل معه كنص عادي.
      return GreetingSettings(message: value);
    }
  }
}
