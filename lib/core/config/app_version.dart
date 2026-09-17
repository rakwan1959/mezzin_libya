/// إصدار التطبيق المثبَّت — **مصدر واحد** لكل الشاشات وللفحص مع سوباباز.
///
/// قبل هذا الملف كان الرقم مكتوباً في مكانين يتخلّفان عن `pubspec.yaml`
/// (كانا 3.3.5 بينما المثبَّت 3.4.9)، فصار فحص التحديث يقارن رقماً خاطئاً:
/// إما ينبّه المستخدم على تحديث هو مثبَّته أصلاً، أو يمنعه عن تحديث حقيقي.
///
/// القاعدة: الثابتان أدناه يُكتبان **آلياً** من `pubspec.yaml` في كل بناء
/// عبر `Build_Master_Pro.bat` (دالة `sync_app_version`)، فلا حاجة لتعديل
/// هذا الملف يدوياً عند رفع الإصدار، ولا يمكن للرقمين أن يتباعدا.
/// ويبقى اختبار `test/app_update_check_test.dart` حارساً ثانياً يفشل
/// فوراً لو بُني المشروع يوماً بدون هذا السكربت.
class AppVersion {
  /// يطابق سطر `version:` في pubspec.yaml (الجزء قبل `+`).
  static const String version = '3.5.0';

  /// يطابق ما بعد `+` في pubspec.yaml (versionCode عند أندرويد).
  static const int buildNumber = 52;

  /// الصيغة الكاملة كما تُكتب في pubspec: `3.4.9+49`.
  static const String full = '$version+$buildNumber';

  /// ما يراه المستخدم في شاشة «عن التطبيق».
  static const String display = version;

  /// ينظّف رقم إصدار قادم من السيرفر قبل المقارنة:
  /// `v3.4.10+50 ` ← `3.4.10`، و`3.5.0-beta` ← `3.5.0`.
  static String normalize(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1).trim();
    final int plus = s.indexOf('+');
    if (plus >= 0) s = s.substring(0, plus);
    final int dash = s.indexOf('-');
    if (dash >= 0) s = s.substring(0, dash);
    return s.trim();
  }

  /// يحوّل `3.4.10` إلى [3, 4, 10]، ويعيد null لأي صيغة غير رقمية
  /// (فلا تُقارن قيم مثل "أحدث نسخة" ويُفتح باب تنبيه كاذب بلا نهاية).
  static List<int>? parse(String raw) {
    final String cleaned = normalize(raw);
    if (cleaned.isEmpty) return null;
    final List<int> parts = <int>[];
    for (final String segment in cleaned.split('.')) {
      final int? value = int.tryParse(segment.trim());
      if (value == null) return null;
      parts.add(value);
    }
    return parts.isEmpty ? null : parts;
  }

  /// -1 لو [a] أقدم، 0 لو متساويان، 1 لو [a] أحدث، وnull لو تعذّرت المقارنة.
  ///
  /// المقارنة رقمية جزءاً جزءاً، فتكون `3.4.10` أحدث من `3.4.9` (وهو ما
  /// لا تفعله المقارنة النصّية)، والأجزاء الناقصة تُعتبر أصفاراً
  /// (`3.4` = `3.4.0`)، ويُهمل رقم البناء بعد `+` لأن رفعه وحده لا يعني
  /// تحديثاً للنسخة المنشورة.
  static int? compare(String a, String b) {
    final List<int>? left = parse(a);
    final List<int>? right = parse(b);
    if (left == null || right == null) return null;
    final int length = left.length > right.length ? left.length : right.length;
    for (int i = 0; i < length; i++) {
      final int l = i < left.length ? left[i] : 0;
      final int r = i < right.length ? right[i] : 0;
      if (l != r) return l > r ? 1 : -1;
    }
    return 0;
  }

  /// هل المنشور [latest] أحدث من المثبَّت [installed] (الافتراضي: هذا الإصدار)؟
  /// أي قيمة غير قابلة للقراءة أو فارغة تُعطي false فلا تنبيه كاذب.
  static bool isNewer(String latest, {String? installed}) {
    final int? result = compare(latest, installed ?? version);
    return result != null && result > 0;
  }
}
