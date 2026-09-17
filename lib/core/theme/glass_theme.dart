import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ════════════════════════════════════════════════════════════════════════════
///  نظام التصميم الزجاجي الموحّد — Glassmorphism Design System
///  مؤذن ليبيا · Muezzin Libya
///
///  مصدر واحد للحقيقة لكل ما يخص المظهر الزجاجي في التطبيق:
///    • [GlassPalette]  → الألوان والتدرّجات النابضة (بدقة لونية عالية)
///    • [GlassSpec]     → مقاييس الضبابية والشفافية والحدود والزوايا
///    • [GlassThemeData]→ يزيّن ThemeData حتى تصبح كل مكوّنات Material زجاجية
///
///  أي شاشة جديدة يجب أن تعتمد على هذه القيم بدل كتابة ألوان ثابتة.
/// ════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
//  0) شدّة شفافية الزجاج + الحالة اللونية الحالية للتطبيق
// ─────────────────────────────────────────────────────────────────────────────

/// شدّة شفافية الزجاج — يتحكّم بها المستخدم من الإعدادات وتُحفظ بين التشغيلات.
///
/// كل قيمة تُضاعف شفافية طبقات الزجاج والضبابية وتوهّج الأورورا، فينتج عنها
/// مظهر مختلف عبر كامل التطبيق دون تغيير أي شاشة.
enum GlassIntensity {
  /// زجاج شفاف فائق — أعلى شفافية وتشبّع للألوان (الافتراضي).
  ultra(
    id: 'ultra',
    label: 'شفاف فائق',
    description: 'أعلى شفافية وتشبّع للألوان',
    fillScale: 1.0,
    blurScale: 0.85,
    glowScale: 1.0,
  ),

  /// زجاج متوازن — شفافية متوسطة ووضوح أعلى للنصوص.
  balanced(
    id: 'balanced',
    label: 'متوازن',
    description: 'شفافية متوسطة ووضوح أعلى للنصوص',
    fillScale: 1.45,
    blurScale: 1.0,
    glowScale: 0.9,
  ),

  /// زجاج داكن فخم — طبقات أكثف وتباين أعلى للاستخدام الليلي.
  deep(
    id: 'deep',
    label: 'داكن فخم',
    description: 'زجاج أكثف بتباين عالٍ للاستخدام الليلي',
    fillScale: 2.4,
    blurScale: 1.35,
    glowScale: 0.7,
  );

  const GlassIntensity({
    required this.id,
    required this.label,
    required this.description,
    required this.fillScale,
    required this.blurScale,
    required this.glowScale,
  });

  final String id;
  final String label;
  final String description;

  /// مضاعف شفافية طبقات الزجاج (1.0 = الافتراضي).
  final double fillScale;

  /// مضاعف شدّة الضبابية.
  final double blurScale;

  /// مضاعف قوّة توهّج الأورورا خلف الزجاج.
  final double glowScale;

  static GlassIntensity fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => GlassIntensity.ultra);
}

/// يحمل إعدادات المظهر الحالية (وضع العرض، الصلاة القادمة، شدّة الشفافية
/// وحركة الخلفية) حتى تلتزم كل الشاشات الفرعية بها تلقائياً دون تمرير خصائص.
class GlassRuntime {
  const GlassRuntime._();

  static const String _kIntensity = 'glassIntensity';
  static const String _kMotion = 'glassMotion';

  static String _themeMode = 'black';
  static Prayer _nextPrayer = Prayer.none;
  static String _activePrayerName = '';
  static GlassIntensity _intensity = GlassIntensity.ultra;
  static bool _motion = true;

  static String get themeMode => _themeMode;
  static Prayer get nextPrayer => _nextPrayer;

  /// اسم الصلاة **النشطة** الآن (آخر صلاة مضى وقتها) — نفس ما تُلوَّن به
  /// أيقونات الشاشة الرئيسية وكاردات المواقيت. تضبطه الشاشة الرئيسية عند كل
  /// بناء، فتقرأ منه الشاشات الفرعية (شاشة «عن التطبيق» مثلًا) فتصبح كتابتها
  /// بلون الصلاة النشطة نفسه لا بلون آخر.
  static String get activePrayerName => _activePrayerName;

  static GlassIntensity get intensity => _intensity;

  /// حركة خلفية الأورورا (يمكن إيقافها لتوفير البطارية).
  static bool get motion => _motion;

  static double get fillScale => _intensity.fillScale;
  static double get blurScale => _intensity.blurScale;
  static double get glowScale => _intensity.glowScale;

  static set themeMode(String value) {
    // أي قيمة غير معروفة تُطبّع إلى وضع معروف — فلا تصل قيمة مجهولة إلى
    // تدرّج الخلفية (كان ذلك يجعلها حمراء عنابية عند المغرب).
    _themeMode = GlassPalette.normalizeThemeMode(value);
  }

  static set nextPrayer(Prayer value) => _nextPrayer = value;

  static set activePrayerName(String value) => _activePrayerName = value;

  /// يقرأ إعدادات المظهر المحفوظة — يُستدعى مرة واحدة عند فتح التطبيق.
  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _intensity = GlassIntensity.fromId(p.getString(_kIntensity));
      _motion = p.getBool(_kMotion) ?? true;
    } catch (_) {}
  }

  /// يضبط شدّة الشفافية ويحفظها.
  static Future<void> setIntensity(GlassIntensity value) async {
    _intensity = value;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kIntensity, value.id);
    } catch (_) {}
  }

  /// يفعّل/يوقف حركة الخلفية ويحفظ الاختيار.
  static Future<void> setMotion(bool value) async {
    _motion = value;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kMotion, value);
    } catch (_) {}
  }

  /// التدرّج الفعّال الآن حسب وضع العرض والصلاة القادمة.
  static List<Color> get gradient =>
      GlassPalette.gradientFor(_themeMode, nextPrayer: _nextPrayer);

  /// بقع الأورورا الفعّالة الآن.
  static List<Color> get glow =>
      GlassPalette.auroraGlowFor(_themeMode, nextPrayer: _nextPrayer);
}

// ─────────────────────────────────────────────────────────────────────────────
//  1) لوحة الألوان
// ─────────────────────────────────────────────────────────────────────────────
class GlassPalette {
  const GlassPalette._();

  // ── الألوان الأساسية للتطبيق ─────────────────────────────────────────────
  /// الذهبي الاحتفالي — لون التمييز الرئيسي
  static const Color gold = Color(0xFFDFBA6B);

  /// ذهبي فاتح — للحدود اللامعة والنصوص المميّزة
  static const Color goldSoft = Color(0xFFF3E3B3);

  /// ذهبي عميق — للظلال والتوهّجات الدافئة
  static const Color goldDeep = Color(0xFFA8791F);

  /// الكحلي الملكي
  static const Color royalNavy = Color(0xFF002855);

  /// الكحلي الملكي العميق
  static const Color royalNavyDeep = Color(0xFF001233);

  /// بنفسجي ملكي عميق
  static const Color royalPurple = Color(0xFF240046);

  /// ليلك هادئ
  static const Color royalPurpleLight = Color(0xFF7E6BA7);

  /// كحلي بارد
  static const Color royalBlue = Color(0xFF003366);

  /// بنفسجي غامق — اللون الأول المضاف من المستخدم (#3C215E)
  static const Color deepViolet = Color(0xFF3C215E);

  /// نيلي عميق — اللون الثاني المضاف من المستخدم (#370F94)
  static const Color deepIndigo = Color(0xFF370F94);

  // ── ألوان الأورورا النابضة (طبقات التوهّج خلف الزجاج) ─────────────────────
  static const Color auroraViolet = Color(0xFF7C3AED);
  static const Color auroraIndigo = Color(0xFF4F46E5);
  static const Color auroraCyan = Color(0xFF06B6D4);
  static const Color auroraTeal = Color(0xFF0D9488);
  static const Color auroraMagenta = Color(0xFFC026D3);
  static const Color auroraRose = Color(0xFFE11D48);
  static const Color auroraAmber = Color(0xFFF59E0B);

  /// ألوان أوقات الصلاة — تُستخدم للأيقونات والحدود النشطة والعدّاد التنازلي
  /// **وإشعارات النظام**، فكلها تقرأ من هنا فلا يختلف لون الصلاة في الإشعار
  /// عن لونه في الشاشة أبداً.
  ///
  /// ⚠️ قيم الظهر/العصر/المغرب/العشاء محدَّدة من المستخدم بدقّة — تُعدَّل هنا
  /// فقط بنفس القيم، ولا يُكتب أي لون صلاة داخل أي شاشة.
  static const Color fajr = Color(0xFF7FB2FF);
  static const Color sunrise = Color(0xFFFFC46B);
  static const Color dhuhr = Color(0xFF73478A); // بنفسجي الظهر
  static const Color asr = Color(0xFFB788D3); // ليلكي العصر
  static const Color maghrib = Color(0xFF691A47); // عنابي المغرب
  static const Color isha = Color(0xFF80335F); // توتي العشاء

  static const Color success = Color(0xFF34D399);
  static const Color danger = Color(0xFFF87171);
  static const Color info = Color(0xFF60A5FA);

  /// كهرماني التحذير — أفتح من `auroraAmber` حتى يبقى واضحاً على الزجاج الداكن
  /// (نسبة تباين عالية للنص والأيقونة).
  static const Color warning = Color(0xFFFBBF24);

  // ── أوضاع العرض ──────────────────────────────────────────────────────────
  /// كل أوضاع العرض المعروفة (نفس المفاتيح المستخدمة في الإعدادات).
  static const List<String> themeModes = <String>[
    'black',
    'navy',
    'dark_blue',
    'royal_purple',
    'royal_purple_light',
    'royal_blue',
    'deep_violet',
    'deep_indigo',
    'system',
    // وضع داخلي صريح: تدرّج بألوان الصلاة القادمة. لا يُفعّله أي خيار في
    // الإعدادات — يُمرَّر صراحةً من شاشة تريد هذه الألوان (شاشة «عن التطبيق»).
    // وجوده هنا مهم: بدونه كان أي **وضع مجهول** يسقط عليه، فتظهر الشاشة
    // حمراء عنابية عند المغرب (وهو العطل الذي أُصلح).
    'prayer',
  ];

  /// يُطبّع وضع العرض إلى مفتاح معروف، وأي قيمة مجهولة أو فارغة تصير «أسود».
  ///
  /// سبب وجودها: كان أي وضع غير معروف يسقط على التدرّج المُتغيّر مع الصلاة
  /// (`dynamicGradient`) — وعند المغرب تدرّجه عنابيّ أحمر، فتظهر الشاشة حمراء
  /// رغم أن الإعدادات تعرض «أسود» (لأنها تُرجع «أسود» لأي قيمة مجهولة).
  /// وتقبل أيضاً القيم العربية القديمة وأسماء الأوضاع القديمة (dark/night…).
  static String normalizeThemeMode(String? mode) {
    final String m = (mode ?? '').trim();
    if (m.isEmpty) return 'black';

    final String lower = m.toLowerCase();
    for (final String known in themeModes) {
      if (known == lower) return known;
    }

    switch (lower) {
      case 'dark':
      case 'night':
      case 'dark_mode':
      case 'darkmode':
      case 'night_mode':
      case 'light':
      case 'white':
        return 'black';
      case 'تلقائي (النظام)':
      case 'تلقائي':
        return 'system';
    }

    switch (m) {
      case 'أسود':
        return 'black';
      case 'كحلي ملكي':
        return 'navy';
      case 'بنفسجي ملكي':
        return 'royal_purple';
      case 'ليلكي هادئ':
        return 'royal_purple_light';
      case 'كحلي بارد':
        return 'royal_blue';
      case 'أزرق داكن':
        return 'dark_blue';
      case 'بنفسجي غامق':
      case 'بنفسجي غامق (#3C215E)':
      case 'بنفسجي غامق (#3c215e)':
      case '#3c215e':
      case '3c215e':
        return 'deep_violet';
      case 'نيلي عميق':
      case 'نيلي عميق (#370F94)':
      case 'نيلي عميق (#370f94)':
      case '#370f94':
      case '370f94':
        return 'deep_indigo';
    }

    return 'black';
  }

  // ── تدرّج الخلفية حسب وضع العرض ─────────────────────────────────────────
  /// التدرّج الأساسي لخلفية الشاشات (3 → 4 طبقات لونية متدرّجة).
  ///
  /// أي وضع غير معروف يُعامَل كـ«أسود» — لا يسقط على تدرّج الصلاة (كان ذلك
  /// يجعل الشاشة عنابية حمراء عند المغرب).
  static List<Color> baseGradient(String themeMode, {Prayer nextPrayer = Prayer.none}) {
    switch (normalizeThemeMode(themeMode)) {
      case 'dark_blue':
        return const [Color(0xFF030E22), Color(0xFF0A192F), Color(0xFF103A6B)];
      case 'royal_purple':
        return const [Color(0xFF16002B), Color(0xFF240046), Color(0xFF4A1276), Color(0xFF003366)];
      case 'royal_purple_light':
        return const [Color(0xFF2A1740), Color(0xFF5B3F86), Color(0xFF7E6BA7)];
      case 'royal_blue':
        return const [Color(0xFF00152E), Color(0xFF003366), Color(0xFF0A4C8C)];
      case 'black':
        // أسود صافٍ (OLED): كان التدرّج `#030308 → #0D0D18 → #1B1030` أي
        // بنفسجيّاً داكناً، فيبدو الوضع «أسود» بنفسجيّاً لا أسود.
        return const [Color(0xFF000000), Color(0xFF000000), Color(0xFF050507)];
      case 'navy':
        return const [Color(0xFF001233), Color(0xFF002855), Color(0xFF0A3F7A)];
      case 'deep_violet':
        // بنفسجي غامق (#3C215E) — طبقتان من عمق اللون إلى ذروته
        return const [Color(0xFF0F0818), Color(0xFF1E0F32), Color(0xFF3C215E)];
      case 'deep_indigo':
        // نيلي عميق (#370F94) — أعمق نيلي يضرب إلى البنفسجي
        return const [Color(0xFF08041A), Color(0xFF1A0A50), Color(0xFF370F94)];
      case 'prayer':
        return dynamicGradient(nextPrayer);
      case 'system':
      default:
        // «تلقائي (النظام)» يتبع سطوع النظام في واجهة Material، أما خلفية
        // الشاشات فتبقى سوداء (لا يوجد تدرّج «فاتح» في نظام الزجاج هذا).
        return const [Color(0xFF000000), Color(0xFF000000), Color(0xFF050507)];
    }
  }

  /// تدرّج يتغيّر بتغيّر الصلاة القادمة — يمنح التطبيق حياةً لونية على مدار اليوم.
  static List<Color> dynamicGradient(Prayer nextPrayer) {
    switch (nextPrayer) {
      case Prayer.fajr:
        return const [Color(0xFF01060F), Color(0xFF061335), Color(0xFF231063)];
      case Prayer.sunrise:
        return const [Color(0xFF07152B), Color(0xFF2A1A44), Color(0xFF6B3A52)];
      case Prayer.dhuhr: // تدرّج بنفسجي يطابق لون الظهر الجديد
        return const [Color(0xFF100723), Color(0xFF2E1650), Color(0xFF5B3A82)];
      case Prayer.asr: // تدرّج ليلكي يطابق لون العصر الجديد
        return const [Color(0xFF150E24), Color(0xFF3D2760), Color(0xFF7A5FA8)];
      case Prayer.maghrib: // تدرّج عنابي يطابق لون المغرب الجديد
        return const [Color(0xFF160210), Color(0xFF3B0C28), Color(0xFF691A47)];
      case Prayer.isha: // تدرّج توتي يطابق لون العشاء الجديد
        return const [Color(0xFF100418), Color(0xFF3A1230), Color(0xFF6E2B52)];
      default:
        return const [Color(0xFF000B1A), Color(0xFF010818), Color(0xFF0A1030)];
    }
  }

  /// تدرّج الخلفية المستخدم في الشاشات — نقطة الدخول الموحّدة.
  static List<Color> gradientFor(String themeMode, {Prayer nextPrayer = Prayer.none}) =>
      baseGradient(themeMode, nextPrayer: nextPrayer);

  // ── بقع الأورورا المضيئة خلف الزجاج ──────────────────────────────────────
  /// 3 بقع ضوئية ملوّنة تُرسم خلف الزجاج فتمنحه العمق والشفافية الملوّنة.
  static List<Color> auroraGlowFor(String themeMode, {Prayer nextPrayer = Prayer.none}) {
    switch (normalizeThemeMode(themeMode)) {
      case 'royal_purple':
        return const [auroraMagenta, auroraCyan, gold];
      case 'royal_purple_light':
        return const [auroraViolet, auroraCyan, goldSoft];
      case 'royal_blue':
        return const [auroraCyan, auroraIndigo, gold];
      case 'dark_blue':
        return const [auroraIndigo, auroraCyan, gold];
      case 'black':
        // بقع رمادية محايدة بلا مسحة بنفسجية/كحلية — تحفظ سواد الشاشة
        // وتمنحه عمقاً خفيفاً بدل أن تلونه. (كانت بنفسجية + نيلية + ذهبية
        // فتُذهب سواد الخلفية.)
        return const [Color(0xFF17171A), Color(0xFF0C0C0F), Color(0xFF232327)];
      case 'navy':
        return const [auroraCyan, auroraIndigo, gold];
      case 'deep_violet':
        // بنفسجي غامق (#3C215E) — توهّج بنفسجي + وردي + ذهبي
        return const [auroraViolet, auroraMagenta, goldSoft];
      case 'deep_indigo':
        // نيلي عميق (#370F94) — توهّج نيلي + بنفسجي + سماوي
        return const [auroraIndigo, auroraViolet, auroraCyan];
      case 'prayer':
        return glowForPrayer(nextPrayer);
      case 'system':
      default:
        // توهّج محايد مثل الوضع الأسود — بدل بقع الصلاة الحمراء/البنفسجية.
        return const [Color(0xFF17171A), Color(0xFF0C0C0F), Color(0xFF232327)];
    }
  }

  /// بقع الأورورا المتغيّرة مع الصلاة القادمة.
  static List<Color> glowForPrayer(Prayer nextPrayer) {
    switch (nextPrayer) {
      case Prayer.fajr:
        return const [auroraIndigo, auroraViolet, info];
      case Prayer.sunrise:
        return const [auroraAmber, auroraRose, gold];
      case Prayer.dhuhr:
        return const [auroraViolet, royalPurpleLight, goldSoft];
      case Prayer.asr:
        return const [auroraViolet, auroraCyan, gold];
      case Prayer.maghrib:
        return const [auroraMagenta, auroraRose, goldDeep];
      case Prayer.isha:
        return const [auroraMagenta, auroraViolet, gold];
      default:
        return const [auroraCyan, auroraViolet, gold];
    }
  }

  // ── ألوان أوقات الصلاة كما تظهر في شاشة المواقيت ─────────────────────────
  /// **مصدر الحقيقة الواحد للون كل صلاة.**
  ///
  /// شاشة المواقيت (الأيقونة + اسم الصلاة + وقتها + العدّاد) والنص المتحرك في
  /// الشاشة الرئيسية وشاشة «عن التطبيق» كلها تقرأ من هنا — فلا يختلف لون الصلاة
  /// من شاشة لأخرى أبداً. كانت هناك لوحة ثانية (`fajr`/`dhuhr`/`maghrib`…)
  /// تُستعمل للنص المتحرك و«عن التطبيق» فقط، فبدا لونهما مخالفاً لألوان
  /// المواقيت رغم أن كليهما «يتبع الصلاة».
  static const Color prayerFajr = Color(0xFF90CAF9); // أزرق الفجر الهادئ
  static const Color prayerSunrise = Color(0xFFFFCC80); // برتقالي الشروق
  static const Color prayerDhuhr = Color(0xFF80DEEA); // أزرق الظهيرة
  static const Color prayerAsr = Color(0xFFD9D9D8);
  static const Color prayerMaghrib = Color(0xFFFAA18F); // لون المغرب الجديد (#FAA18F)
  static const Color prayerIsha = Color(0xFFB39DDB); // بنفسجي العشاء

  /// لون صلاة باسمها العربي — كما في شاشة المواقيت بالضبط.
  static Color prayerTimesColor(String nameAr) {
    switch (nameAr) {
      case 'الفجر':
        return prayerFajr;
      case 'الشروق':
        return prayerSunrise;
      case 'الظهر':
        return prayerDhuhr;
      case 'العصر':
        return prayerAsr;
      case 'المغرب':
        return prayerMaghrib;
      case 'العشاء':
        return prayerIsha;
      default:
        return Colors.white;
    }
  }

  /// لون صلاة بكائن [Prayer] — نفس لوحة شاشة المواقيت.
  static Color prayerTimesColorFor(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return prayerFajr;
      case Prayer.sunrise:
        return prayerSunrise;
      case Prayer.dhuhr:
        return prayerDhuhr;
      case Prayer.asr:
        return prayerAsr;
      case Prayer.maghrib:
        return prayerMaghrib;
      case Prayer.isha:
        return prayerIsha;
      default:
        return Colors.white;
    }
  }

  /// لون نص «الكتابة المتحركة» في الشاشة الرئيسية وكتابة شاشة «عن التطبيق» —
  /// يتبع **ألوان أوقات الصلاة نفسها** (شاشة المواقيت).
  static Color prayerTextColor(String prayerNameAr) =>
      readableOnDark(prayerTimesColor(prayerNameAr));

  /// يُفتّح اللون حتى يتجاوز حدّ السطوع المطلوب **مع الحفاظ على درجته اللونية
  /// وتشبّعه** (رفع الإضاءة في فضاء HSL بدل المزج مع الأبيض).
  ///
  /// سبب ذلك: المزج مع الأبيض يُوهن التشبّع فتقترب الألوان الداكنة من بعضها
  /// (المغرب `#691A47` والعشاء `#80335F` والظهر `#73478A` كانت تصير ورديّاً
  /// رمادياً واحداً تقريباً)، فيبدو النص وكأنه لا يتبع الصلاة. رفع الإضاءة
  /// يُبقي كل صلاة بلونها المميّز ومقروءةً.
  static Color readableOnDark(Color color, {double minLuminance = 0.40}) {
    if (color.computeLuminance() >= minLuminance) return color;
    final HSLColor hsl = HSLColor.fromColor(color);
    double lightness = hsl.lightness;
    while (lightness < 1.0) {
      lightness = (lightness + 0.02).clamp(0.0, 1.0);
      final Color raised = hsl.withLightness(lightness).toColor();
      if (raised.computeLuminance() >= minLuminance) return raised;
    }
    return hsl.withLightness(1.0).toColor();
  }

  /// لون التمييز المطابق لصلاة (من `adhan`).
  static Color forPrayer(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return fajr;
      case Prayer.sunrise:
        return sunrise;
      case Prayer.dhuhr:
        return dhuhr;
      case Prayer.asr:
        return asr;
      case Prayer.maghrib:
        return maghrib;
      case Prayer.isha:
        return isha;
      default:
        return Colors.white;
    }
  }

  /// لون الكتابة المطابق للصلاة (مُفتَّحاً ليكون مقروءاً على الخلفية الداكنة).
  /// تُستعمله شاشة «عن التطبيق» فتتبع كتابتها ألوان أوقات الصلاة.
  static Color prayerTextColorFor(Prayer prayer) =>
      readableOnDark(prayerTimesColorFor(prayer));

  /// لون التمييز المطابق لاسم الصلاة العربي.
  static Color forPrayerName(String nameAr) {
    switch (nameAr) {
      case 'الفجر':
        return fajr;
      case 'الشروق':
        return sunrise;
      case 'الظهر':
        return dhuhr;
      case 'العصر':
        return asr;
      case 'المغرب':
        return maghrib;
      case 'العشاء':
        return isha;
      default:
        return Colors.white;
    }
  }

  /// لون الصلاة **المقروء** على الخلفية الداكنة.
  ///
  /// هو نفسه [forPrayerName] لكنه يمرّ على [legible]، فيُستخدم في الأيقونات
  /// والنصوص (شاشة المواقيت، الشريط السفلي، اسم المدينة) حيث الاحتياج للوضوح
  /// أعلى من الاحتياج للتدرّج اللوني.
  static Color forPrayerNameLegible(String nameAr) => legible(forPrayerName(nameAr));

  /// يرفع سطوع أي لون إلى الحدّ الأدنى المقروء على الخلفية الليلية، **مع
  /// الحفاظ على درجته نفسها** (خلط مع الأبيض لا تغيير للـ Hue).
  ///
  /// سبب الحاجة: العشاء `#80335F` والمغرب `#691A47` درجتان داكنتان جداً
  /// (إضاءة أقل من 0.10) فيكادان يغيبان فوق الكحلي الليلي؛ فلا يُصبح اللون
  /// مقروءاً إلا برفعه بأقلّ قدر لازم. الألوان الفاتحة أصلاً (كالعصر) يُعاد
  /// إرجاعها كما هي دون أي تغيير.
  static Color legible(Color accent, {double minLuminance = 0.10, double maxMix = 0.35}) {
    if (accent.computeLuminance() >= minLuminance) return accent;
    var mix = 0.0;
    var result = accent;
    while (mix < maxMix && result.computeLuminance() < minLuminance) {
      mix += 0.04;
      result = Color.lerp(accent, Colors.white, mix)!;
    }
    return result;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  2) مقياس أيقونات شريط التنقّل السفلي (التاسك بار)
// ─────────────────────────────────────────────────────────────────────────────
/// مقياس تصميمي **مستقل** لأيقونات الشريط السفلي وحده.
///
/// أيقونات التنقّل هي أكثر عنصر يلمسه المستخدم، لذا صُمِّم لها سُلّم أحجام
/// ووضوح خاص بها (أكبر وأبرز من أيقونات الواجهة العادية) مع كبسولة زجاجية
/// وتوهّج بلون الصلاة النشطة — كلها مشتقّة من [GlassPalette] و[GlassSpec]
/// حتى تبقى على نفس نسق نظام التطبيق وألوانه.
class GlassNavSpec {
  const GlassNavSpec._();

  // ── سُلّم الأحجام (أكبر من أيقونة الواجهة القياسية 24) ──────────────────
  /// أيقونة التبويب النشط — أكبر حجم في الواجهة ليكون بارزاً وواضحاً.
  static const double iconActive = 28.0;

  /// أيقونة التبويب غير النشط — تبقى واضحة دون أن تزاحم النشطة.
  static const double iconInactive = 25.0;

  /// حجم الهالة الدائرية خلف الأيقونة النشطة (ترفع تباينها عن الخلفية).
  static const double haloSize = 40.0;

  /// حشوة الكبسولة الزجاجية حول الأيقونة النشطة.
  static const EdgeInsets pillPadding =
      EdgeInsets.symmetric(horizontal: 14, vertical: 7);

  /// نصف قطر الكبسولة — منحنى أنعم يليق بالزجاج.
  static const double pillRadius = 20.0;

  // ── الوضوح والتباين ─────────────────────────────────────────────────────
  /// شفافية الأيقونة غير النشطة (0.60 سابقاً → أوضح الآن).
  static const double inactiveOpacity = 0.82;

  /// مدى مزج الأيقونة غير النشطة مع الأبيض لرفع وضوحها على الخلفية الملوّنة.
  static const double inactiveWhiteMix = 0.62;

  /// مدى مزج الأيقونة النشطة مع الأبيض فتبدو مضيئة لا شاحبة.
  static const double activeWhiteMix = 0.30;

  /// ضبابية توهّج الأيقونة النشطة (Icon.shadows).
  static const double iconGlowBlur = 14.0;

  /// سماكة حدّ الكبسولة النشطة.
  static const double borderWidthActive = 1.3;

  // ── الحركة ──────────────────────────────────────────────────────────────
  /// مدّة انتقال التبويب — نطة قصيرة أنيقة (easeOutBack).
  static const Duration duration = Duration(milliseconds: 320);

  static const Curve curve = Curves.easeOutBack;

  /// كبسولة الزجاج الملوّنة للتبويب النشط.
  static LinearGradient pillGradient(Color accent) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha: 0.30 * GlassRuntime.fillScale.clamp(0.6, 1.6)),
          accent.withValues(alpha: 0.10 * GlassRuntime.fillScale.clamp(0.6, 1.6)),
        ],
        stops: const [0.0, 1.0],
      );

  /// هالة إشعاعية خلف الأيقونة النشطة تمنحها عمقاً ولمعاناً.
  static RadialGradient haloGradient(Color accent) => RadialGradient(
        colors: [
          accent.withValues(alpha: 0.34),
          accent.withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      );

  /// توهّج الكبسولة النشطة — لون الصلاة نفسه لا لون دخيل.
  static List<BoxShadow> pillGlow(Color accent) => [
        BoxShadow(
          color: accent.withValues(alpha: 0.38),
          blurRadius: 16,
          spreadRadius: 0.5,
        ),
        BoxShadow(
          color: accent.withValues(alpha: 0.16),
          blurRadius: 30,
          spreadRadius: -2,
        ),
      ];

  /// لون الأيقونة النشطة — مزيج مضيء من لون الصلاة والأبيض.
  static Color activeIconColor(Color accent) =>
      Color.lerp(accent, Colors.white, activeWhiteMix)!;

  /// لون الأيقونة غير النشطة — أبيض ممزوج بلون الصلاة ليبقى واضحاً.
  static Color inactiveIconColor(Color accent) =>
      Color.lerp(Colors.white, accent, 1 - inactiveWhiteMix)!
          .withValues(alpha: inactiveOpacity);

  // ══ العمق ثلاثي الأبعاد (3D) ═══════════════════════════════════════════
  //  كل قيمة هنا تصف "جسماً" لا رسماً: ارتفاع، وسماكة، وميل، ومنظور.
  //  تُقرأ جميعها من [GlassNavIcon] وحده، فتعديل رقم واحد يُغيّر الإحساس
  //  بالعمق في شريط المهام كله بلا لمس أي شاشة.

  /// قطر اللوح (الزر) الذي تظهر عليه الأيقونة النشطة.
  static const double plateSize = 34.0;

  /// سماكة اللوح — مقدار نزول الجدار الجانبي الداكن عن الوجه العلوي.
  static const double plateDepth = 2.6;

  /// حجم المؤشر الصغير أسفل الأيقونة.
  static const double indicatorSize = 5.0;

  /// ارتفاع عنصر التبويب — **ثابت**: أي حركة تحدث داخل هذا الصندوق، فلا
  /// يتغيّر ارتفاع شريط المهام ولا تهتز الشاشة فوقه أبداً.
  static const double itemHeight = plateSize + 3 + indicatorSize;

  /// عرض هدف اللمس — أوسع من اللوح ليصبح الضغط مريحاً للإصبع.
  static const double touchWidth = plateSize + 26.0;

  /// قوّة المنظور (Perspective). أكبر = غوص أعمق وأحسّ بالإبعاد.
  static const double perspective = 0.0016;

  /// ميل سطح اللوح عند السكون (راديان) — يقرأه العين كسطح أفقي مائل.
  static const double tiltIdle = 0.09;

  /// ميل إضافي للتبويب النشط — يرفع وجهه نحو المستخدم أكثر من الجالسين.
  static const double tiltActive = 0.05;

  /// ميل الغوص عند الضغط — الزر ينكبّ للخلف فتظهر سماكته (~15° في أقصاه،
  /// فلا يبدو ساقطاً على الشاشة).
  static const double tiltPressed = 0.16;

  /// تصغير الزر عند الضغط (الغوص في السطح).
  static const double pressScale = 0.86;

  /// نزول الزر عند الضغط (بكسل).
  static const double pressTravel = 2.4;

  /// ارتفاع التبويب النشط عن سطح الشريط (بكسل).
  static const double activeLift = 1.6;

  /// سُمك بروز الحرف المجسّم: عدد طبقات السماكة ومسافة الطبقة.
  static const int extrudeLayers = 3;
  static const double extrudeStep = 0.9;

  /// مدى "تنفّس" التبويب النشط (بكسل) — يعمل فقط إذا كانت الحركة مفعّلة
  /// في إعدادات المظهر ([GlassRuntime.motion]).
  static const double bobAmplitude = 1.3;

  /// زمن نزول الضغط (سريع كلمسة إصبع) وزمن ارتداده (أبطأ قليلاً فيُرى).
  static const Duration pressIn = Duration(milliseconds: 110);
  static const Duration pressOut = Duration(milliseconds: 260);

  /// دور تنفّس التبويب النشط.
  static const Duration bobDuration = Duration(milliseconds: 2200);

  /// وجه اللوح: لمعان أبيض أعلى + صبغة لون الصلاة تنزل إلى الأسفل.
  /// [appear] مدى ظهور اللوح (0 مخفي → 1 كامل) فيمكن تلاشيه دون قفزة.
  static LinearGradient plateFace(Color accent, double appear) {
    final double fill = GlassRuntime.fillScale.clamp(0.6, 1.6);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: 0.34 * appear),
        accent.withValues(alpha: 0.34 * appear * fill),
        accent.withValues(alpha: 0.14 * appear),
      ],
      stops: const [0.0, 0.58, 1.0],
    );
  }

  /// الجدار الجانبي (سماكة الزر): داكن في الأعلى يتلوّن بلون الصلاة أسفله.
  static LinearGradient plateWall(Color accent, double appear) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(Colors.black, accent, 0.35)!
              .withValues(alpha: 0.55 * appear),
          Color.lerp(Colors.black, accent, 0.12)!
              .withValues(alpha: 0.75 * appear),
        ],
      );

  /// ظل اللوح: توهّج بلون الصلاة + ظل أسود أسفله يفصله عن سطح الشريط.
  /// [sink] مقدار الغوص — الضغط يُقرّب الزر من السطح فيتقلّص ظله ويشتدّ.
  static List<BoxShadow> plateShadow(Color accent, double appear, double sink) => [
        BoxShadow(
          color: accent.withValues(alpha: (0.34 * appear * (1 - 0.45 * sink)).clamp(0.0, 1.0)),
          blurRadius: 14 * (1 - 0.30 * sink),
          spreadRadius: 0.5,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: (0.34 * (1 - 0.40 * sink)).clamp(0.0, 1.0)),
          blurRadius: 9,
          offset: Offset(0, 3 + 2 * sink),
        ),
      ];

  /// لون سماكة الحرف (الطبقات المنخفضة) — داكن مشوب بلون الصلاة.
  static Color extrudeColor(Color accent) => Color.lerp(Colors.black, accent, 0.42)!;
}

// ─────────────────────────────────────────────────────────────────────────────
//  3) مقاييس الزجاج
// ─────────────────────────────────────────────────────────────────────────────
class GlassSpec {
  const GlassSpec._();

  // ── درجات الضبابية (BackdropFilter blur) ────────────────────────────────
  /// زجاج رقيق — للشرائط والأشرطة السفلية والرقائق
  static const double blurThin = 10;

  /// زجاج قياسي — للبطاقات وعناصر القوائم
  static const double blurRegular = 16;

  /// زجاج كثيف — للبطاقات البارزة والحوارات
  static const double blurHeavy = 22;

  /// زجاج فائق — للتدرّجات التي تحتاج عمقاً كبيراً
  static const double blurUltra = 30;

  // ── شفافية طبقات الزجاج (زجاج شفاف فائق) ───────────────────────────────
  static const double fillTop = 0.16;
  static const double fillMid = 0.055;
  static const double fillBottom = 0.02;
  static const double fillActiveTop = 0.20;
  static const double fillActiveMid = 0.08;
  static const double fillActiveBottom = 0.03;

  /// زجاج داكن — للشاشات التي تحتاج تبايناً أعلى (القرآن، الفيديو)
  static const double fillScrimTop = 0.42;
  static const double fillScrimMid = 0.30;
  static const double fillScrimBottom = 0.22;

  // ── الحدود واللمعان ─────────────────────────────────────────────────────
  static const double borderOpacity = 0.22;
  static const double borderOpacityActive = 0.62;
  static const double borderWidth = 1.0;
  static const double borderWidthActive = 1.4;
  static const double sheenOpacity = 0.38;
  static const double sheenOpacityActive = 0.62;

  /// لمعان الحافة الداخلية (Inner Specular Highlight) — سرّ الإحساس بالزجاج
  static const double innerEdgeOpacity = 0.14;

  // ── الزوايا ─────────────────────────────────────────────────────────────
  static const double radiusXs = 10;
  static const double radiusSm = 14;
  static const double radiusMd = 18;
  static const double radiusLg = 24;
  static const double radiusXl = 32;

  static BorderRadius get brSm => BorderRadius.circular(radiusSm);
  static BorderRadius get brMd => BorderRadius.circular(radiusMd);
  static BorderRadius get brLg => BorderRadius.circular(radiusLg);
  static BorderRadius get brXl => BorderRadius.circular(radiusXl);

  // ── الظلال ──────────────────────────────────────────────────────────────
  /// ظل خارجي ناعم يمنح البطاقة انفصالاً عن الخلفية
  static List<BoxShadow> softShadow({double spread = 0}) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 18,
          spreadRadius: spread,
          offset: const Offset(0, 6),
        ),
      ];

  /// توهّج ملوّن للعناصر النشطة
  static List<BoxShadow> glowShadow(Color glow, {double intensity = 1.0}) => [
        BoxShadow(
          color: glow.withValues(alpha: 0.26 * intensity),
          blurRadius: 24,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: glow.withValues(alpha: 0.12 * intensity),
          blurRadius: 48,
          spreadRadius: -4,
        ),
      ];

  // ── التدرّجات القياسية للزجاج ───────────────────────────────────────────
  /// يحوّل الشفافية الأساسية إلى الشفافية الفعّالة حسب اختيار المستخدم،
  /// مع تثبيتها دائماً داخل المدى المسموح (0 → 1) حتى لا تتجاوز حدودها.
  static double _a(double base) =>
      (base * GlassRuntime.fillScale).clamp(0.0, 1.0);

  /// تدرّج الزجاج العادي — نزول من أعلى-يمين إلى أسفل-يسار (مناسب لواجهة RTL)
  static LinearGradient glassGradient({bool active = false, Color? tint}) => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Colors.white.withValues(alpha: _a(active ? fillActiveTop : fillTop)),
          Colors.white.withValues(alpha: _a(active ? fillActiveMid : fillMid)),
          (tint ?? Colors.white).withValues(alpha: _a(active ? fillActiveBottom + 0.02 : fillBottom)),
        ],
        stops: const [0.0, 0.45, 1.0],
      );

  /// تدرّج زجاجي ملوّن — يمزج لوناً مخصّصاً مع الأبيض لشفافية ملوّنة
  static LinearGradient tintedGlassGradient(Color tint, {bool active = false}) => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          tint.withValues(alpha: _a(active ? 0.28 : 0.16)),
          Colors.white.withValues(alpha: _a(active ? 0.10 : 0.05)),
          tint.withValues(alpha: _a(active ? 0.06 : 0.03)),
        ],
        stops: const [0.0, 0.5, 1.0],
      );

  // ── حركة الخلفية ────────────────────────────────────────────────────────
  /// مدّة الدورة الكاملة لتدرّج الخلفية النابض
  static const Duration backgroundCycle = Duration(seconds: 24);

  /// شدّة حركة الأورورا الافتراضية (0 = ثابتة)
  static const double auroraMotion = 1.0;
}

// ─────────────────────────────────────────────────────────────────────────────
//  4) نظام رسائل الإشعارات والتنبيهات — Glass Notice System
// ─────────────────────────────────────────────────────────────────────────────
/// نوع الرسالة المعروضة للمستخدم (حوار / إشعار سريع / رسالة من السيرفر).
///
/// كل نوع يحمل **لونه الدقيق** وأيقونته، فيبقى الترميز اللوني واحداً في كل
/// التطبيق: أخضر للنجاح، كهرماني للتحذير، أحمر للخطأ، أزرق للتحديث، وذهبي
/// (هوية التطبيق) للمعلومة والتهنئة.
///
/// الألوان مختارة بدرجة إضاءة مرتفعة عن قصد لتُقرأ بوضوح على الزجاج الداكن.
enum GlassNoticeKind {
  /// معلومة عامة — ذهبي التطبيق.
  info(label: 'معلومة', icon: Icons.info_rounded, accent: GlassPalette.gold),

  /// نجاح / تأكيد — أخضر.
  success(label: 'تم بنجاح', icon: Icons.check_circle_rounded, accent: GlassPalette.success),

  /// تحذير — كهرماني.
  warning(label: 'تحذير', icon: Icons.warning_amber_rounded, accent: GlassPalette.warning),

  /// خطأ / فشل — أحمر.
  danger(label: 'خطأ', icon: Icons.error_rounded, accent: GlassPalette.danger),

  /// تهنئة / إهداء — ذهبي احتفالي.
  celebration(label: 'تهنئة', icon: Icons.celebration_rounded, accent: GlassPalette.gold),

  /// تحديث التطبيق — أزرق معلومي.
  update(label: 'تحديث', icon: Icons.system_update_rounded, accent: GlassPalette.info);

  const GlassNoticeKind({
    required this.label,
    required this.icon,
    required this.accent,
  });

  /// وصف مختصر للنوع (للإتاحة/القارئ الشاشي).
  final String label;

  /// أيقونة النوع.
  final IconData icon;

  /// لون النوع الدقيق على الزجاج الداكن.
  final Color accent;
}

/// مقاييس وألوان رسائل الإشعارات والتنبيهات — مصدر واحد لكل الحوارات
/// والتنبيهات السريعة، فلا يُكتب لون أو حجم داخل أي شاشة.
class GlassNoticeSpec {
  const GlassNoticeSpec._();

  // ── الخط: أميري أبيض في كل رسالة ────────────────────────────────────────
  /// خط **كل** الإشعارات والتنبيهات: أميري (خط التطبيق المضمَّن، يعمل بلا
  /// إنترنت). تُستهلك في ثيم الحوارات والإشعارات السريعة وفي رسائل
  /// [showGlassDialog] و[showGlassSnack]، فلا يبقى تنبيه بخط آخر.
  ///
  /// وفي إشعارات النظام يُطبَّق نفس الخط من موارد أندرويد
  /// (`android/app/src/main/res/font/amiri.ttf`) فيبقى الشكل واحداً خارج
  /// التطبيق وداخله.
  static const String fontFamily = 'Amiri';

  // ── ألوان النصوص: مضبوطة يدوياً للقراءة على الكحلي الملكي ────────────────
  /// عنوان الرسالة — أبيض ناصع (أقصى وضوح).
  static const Color titleColor = Colors.white;

  /// متن الرسالة — أبيض ناصع كذلك: كل نصوص الرسائل بيضاء كما هو مطلوب،
  /// ووضوحها مضمون على الكحلي الملكي المثبّت خلفها.
  static const Color bodyColor = Colors.white;

  /// نص ثانوي (تلميحات/عدّادات) — رمادي مزرق لا يقلّ وضوحاً عن 0.70.
  static const Color mutedColor = Color(0xFFB4BFD0);

  /// شفافية المتن — لا تُنقص عن 0.85 حتى يبقى النص واضحاً فوق أي تدرّج.
  static const double bodyAlpha = 0.95;

  /// شفافية النص الثانوي.
  static const double mutedAlpha = 0.80;

  // ── سطح الرسالة: الكحلي الملكي الموحّد ──────────────────────────────────
  /// خلفية **كل** الإشعارات والتنبيهات في التطبيق — الكحلي الملكي.
  /// تُستهلك في ثيم الحوارات والإشعارات السريعة وفي [GlassPanel] الرسائل،
  /// فلا يبقى في التطبيق أي تنبيه بخلفية أخرى.
  static const Color surface = GlassPalette.royalNavy;

  /// الطبقة الأعمق للسطح (التدرّج والحدود).
  static const Color surfaceDeep = GlassPalette.royalNavyDeep;

  /// شفافية سطح الحوار — عالية كفاية ليبقى النص واضحاً فوق أي خلفية خلفها.
  static const double dialogSurfaceAlpha = 0.94;

  /// شفافية سطح الإشعار السريع (Snack).
  static const double snackSurfaceAlpha = 0.96;

  /// لون زر الإجراء داخل الرسالة — ذهبي التطبيق.
  static const Color actionColor = GlassPalette.gold;

  /// حدّ سطح الرسالة: ذهبي التطبيق بشفافية دقيقة، فينتمي التنبيه لهوية
  /// التطبيق بدل حدّ أبيض عام يجعله يبدو غريباً عنه.
  static Color surfaceBorder({double alpha = 0.30}) =>
      GlassPalette.gold.withValues(alpha: alpha);

  // ── الأحجام ───────────────────────────────────────────────────────────
  static const double cardWidth = 380;
  static const double iconBubble = 54;
  static const double iconSize = 26;
  static const double titleSize = 17.5;
  static const double bodySize = 15;
  static const double snackFontSize = 13.5;

  /// تباعد الأسطر في متن الرسالة — مريح للنصوص العربية.
  static const double bodyHeight = 1.75;

  /// نصف قطر بطاقة الرسالة.
  static const double radius = GlassSpec.radiusLg;

  // ── الحركة ────────────────────────────────────────────────────────────
  static const Duration duration = Duration(milliseconds: 220);
  static const Curve curve = Curves.easeOutCubic;

  /// لون النوع (افتراضياً ذهبي التطبيق).
  static Color accentOf(GlassNoticeKind? kind) => kind?.accent ?? GlassPalette.gold;

  /// أيقونة النوع (افتراضياً أيقونة المعلومة).
  static IconData iconOf(GlassNoticeKind? kind) => kind?.icon ?? Icons.info_rounded;

  /// هالة إشعاعية بلون النوع خلف أيقونته — تعطي ترميزاً لونياً فورياً.
  static RadialGradient iconHalo(Color accent) => RadialGradient(
        colors: [
          accent.withValues(alpha: 0.34),
          accent.withValues(alpha: 0.06),
        ],
        stops: const [0.0, 1.0],
      );

  /// توهّج خارجي دقيق بلون النوع يفصل الرسالة عن الخلفية بلونها نفسه.
  static List<BoxShadow> glow(Color accent) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: accent.withValues(alpha: 0.22),
          blurRadius: 34,
          spreadRadius: -6,
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
//  5) تزيين ThemeData — يجعل كل مكوّنات Material زجاجية تلقائياً
// ─────────────────────────────────────────────────────────────────────────────
/// ─────────────────────────────────────────────────────────────────────────────
/// نص **محفور** في خلفية الشاشة.
///
/// الحيلة بصرية بحتة: الحرف نفسه **أبيض ناصع**، ويُرسم خلفه حافتان:
/// حافة داكنة أعلى الحرف (عمق الحفر) وحافة مضيئة رقيقة أسفله (الضوء الذي
/// يلمس قاع الحفر) — فيقرأها العين كحرف منقوش داخل السطح لا واقفاً فوقه.
///
/// والظلال تُشتقّ من **ألوان خلفية الشاشة نفسها**، فيبقى الانطباع صحيحاً على
/// كل تدرّج (كحلي/أسود/بنفسجي/بلون الصلاة الحالية) بلا لون حفر ثابت.
class GlassEngraveSpec {
  const GlassEngraveSpec._();

  /// أغمق لون في تدرّج الخلفية — أساس الحافة الداكنة.
  static Color deepest(List<Color> background) {
    if (background.isEmpty) return GlassPalette.royalNavyDeep;
    return background.reduce(
      (Color a, Color b) =>
          a.computeLuminance() <= b.computeLuminance() ? a : b,
    );
  }

  /// ظلال الحفر للنص والأيقونة.
  ///
  /// [strength] يزيد العمق للخطوط الكبيرة التي تحتاج حفراً أوضح
  /// ، ويُخفّض للخطوط الصغيرة حتى لا تتلخبط حروفها.
  static List<Shadow> shadows(List<Color> background, {double strength = 1.0}) {
    final Color deep = deepest(background);
    return <Shadow>[
      // 1) ظل ضبابي خفيف يفصل الحرف عن التدرّج — وضوح القراءة
      Shadow(
        color: Colors.black.withValues(alpha: 0.26 * strength),
        blurRadius: 6,
      ),
      // 2) الحافة الداكنة أعلى الحرف = عمق الحفر (لونها من الخلفية نفسها)
      Shadow(
        color: Color.alphaBlend(
          Colors.black.withValues(alpha: 0.62),
          deep,
        ),
        blurRadius: 1.3,
        offset: const Offset(0, -1.1),
      ),
      // 3) الحافة المضيئة أسفل الحرف = قاع الحفر الذي يلمسه الضوء
      Shadow(
        color: Colors.white.withValues(alpha: 0.22 * strength),
        blurRadius: 1.1,
        offset: const Offset(0, 1.1),
      ),
    ];
  }
}

class GlassThemeData {
  const GlassThemeData._();

  /// يطبّق المظهر الزجاجي على كل مكوّنات Material في التطبيق:
  /// الأشرطة العلوية، الحوارات، القوائم السفلية، الحقول، الأزرار، الشرائح…
  ///
  /// يُستدعى من `main.dart` على كل ثيم حتى تلتزم كل الشاشات بالنظام تلقائياً.
  static ThemeData decorate(ThemeData base) {
    final isDark = base.brightness == Brightness.dark;
    final onGlass = isDark ? Colors.white : const Color(0xFF0B1020);

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,

      // ── الشرائط العلوية ─────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: base.appBarTheme.systemOverlayStyle,
        iconTheme: const IconThemeData(color: Colors.white, size: 22),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),

      // ── الحوارات (التنبيهات) ─────────────────────────────────────────────
      // خلفية موحّدة: الكحلي الملكي نفسه لكل حوار، مع حدّ ذهبي رقيق.
      dialogTheme: DialogThemeData(
        backgroundColor:
            GlassNoticeSpec.surface.withValues(alpha: GlassNoticeSpec.dialogSurfaceAlpha),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: GlassSpec.brLg,
          side: BorderSide(color: GlassNoticeSpec.surfaceBorder(alpha: 0.32), width: 1.1),
        ),
        titleTextStyle: const TextStyle(
          color: GlassNoticeSpec.titleColor,
          fontFamily: GlassNoticeSpec.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(
          color: GlassNoticeSpec.bodyColor.withValues(alpha: GlassNoticeSpec.bodyAlpha),
          fontFamily: GlassNoticeSpec.fontFamily,
          fontSize: 14,
          height: 1.7,
        ),
      ),

      // ── القوائم السفلية ─────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: GlassNoticeSpec.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: GlassNoticeSpec.surface.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(GlassSpec.radiusXl)),
          side: BorderSide(color: GlassNoticeSpec.surfaceBorder(alpha: 0.26)),
        ),
        showDragHandle: true,
        dragHandleColor: Colors.white.withValues(alpha: 0.28),
      ),

      // ── الحقول ──────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42), fontSize: 14),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 14),
        floatingLabelStyle: const TextStyle(color: GlassPalette.gold, fontSize: 14),
        prefixIconColor: Colors.white.withValues(alpha: 0.66),
        suffixIconColor: Colors.white.withValues(alpha: 0.66),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: GlassSpec.brMd,
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: GlassSpec.brMd,
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: GlassSpec.brMd,
          borderSide: const BorderSide(color: GlassPalette.gold, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: GlassSpec.brMd,
          borderSide: const BorderSide(color: GlassPalette.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: GlassSpec.brMd,
          borderSide: const BorderSide(color: GlassPalette.danger, width: 1.4),
        ),
      ),

      // ── الفواصل ─────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),

      // ── البطاقات ────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: GlassSpec.brLg,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── عناصر القوائم ───────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        iconColor: Colors.white.withValues(alpha: 0.86),
        textColor: Colors.white,
        subtitleTextStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.60),
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: GlassSpec.brMd),
      ),

      // ── الأزرار ─────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.10),
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: GlassSpec.brMd,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GlassPalette.gold,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
          shape: RoundedRectangleBorder(borderRadius: GlassSpec.brMd),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: GlassPalette.gold.withValues(alpha: 0.92),
        foregroundColor: const Color(0xFF1A1206),
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GlassSpec.radiusMd)),
      ),

      // ── الشرائح والعلامات ───────────────────────────────────────────────
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        selectedColor: GlassPalette.gold.withValues(alpha: 0.22),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GlassSpec.radiusXs + 4)),
        labelStyle: TextStyle(color: onGlass, fontSize: 13),
      ),

      // ── القوائم المنبثقة ────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF0C1330).withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: GlassSpec.brMd,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 14),
      ),

      // ── الشرائح السفلية والتبويبات ──────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: GlassPalette.gold,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.56),
        indicatorColor: GlassPalette.gold,
        dividerColor: Colors.white.withValues(alpha: 0.10),
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),

      // ── الإشعارات السريعة (Snack) ──────────────────────────────────────
      // نفس سطح الحوارات: كحلي ملكي، فيبدو التنبيه والحوار قطعة واحدة
      // من هوية التطبيق، بنص أبيض عالي الوضوح وحدّ ذهبي رقيق.
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            GlassNoticeSpec.surface.withValues(alpha: GlassNoticeSpec.snackSurfaceAlpha),
        contentTextStyle: const TextStyle(
          color: GlassNoticeSpec.titleColor,
          fontFamily: GlassNoticeSpec.fontFamily,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
        actionTextColor: GlassNoticeSpec.actionColor,
        closeIconColor: Colors.white70,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: GlassSpec.brMd,
          side: BorderSide(color: GlassNoticeSpec.surfaceBorder(alpha: 0.28)),
        ),
      ),

      // ── المؤشرات والمفاتيح ─────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: GlassPalette.gold),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? GlassPalette.gold : Colors.white70,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? GlassPalette.gold.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.10),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.20)),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: GlassPalette.gold,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
        thumbColor: GlassPalette.gold,
        overlayColor: GlassPalette.gold.withValues(alpha: 0.16),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? GlassPalette.gold
              : Colors.white.withValues(alpha: 0.08),
        ),
        checkColor: WidgetStateProperty.all(const Color(0xFF1A1206)),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? GlassPalette.gold
              : Colors.white.withValues(alpha: 0.34),
        ),
      ),

      // ── شريط التقدّم ────────────────────────────────────────────────────
      iconTheme: base.iconTheme.copyWith(color: Colors.white),
    );
  }
}
