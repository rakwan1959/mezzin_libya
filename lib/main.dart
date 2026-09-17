import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'remote_messaging_service.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'adhan_audio_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'notification_service.dart';
import 'voice_announcement_service.dart';
import 'injection_container.dart' as di;
import 'package:muezzin_libya_app/features/quran/data/datasources/quran_settings_data_source.dart';
import 'package:muezzin_libya_app/features/quran/presentation/bloc/quran_bloc.dart';
import 'package:muezzin_libya_app/features/quran/presentation/bloc/quran_audio_bloc.dart';
import 'package:muezzin_libya_app/features/quran/presentation/bloc/quran_event.dart';
import 'package:muezzin_libya_app/features/home/presentation/pages/home_page.dart';
import 'core/widgets/app_splash_screen.dart';
import 'core/services/screen_wake_service.dart';
import 'core/services/silent_permission_service.dart';
import 'core/config/header_font_prefs.dart';
import 'core/config/quran_dark_prefs.dart';
import 'core/config/home_date_font_prefs.dart';
import 'core/config/prayer_card_font_prefs.dart';
import 'core/theme/glass_theme.dart';

final adhanAudioService = AdhanAudioService();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AlMaathenTheme {
  static const Color accent = GlassPalette.royalNavy;

  /// اللون الكحلي الملكي (Royal Navy) — يستخدم لخلفية كل الإشعارات والتنبيهات
  static const Color royalNavy = GlassPalette.royalNavy;

  /// درجة الكحلي الملكي العميقة — للخلفيات الأساسية والوضع الافتراضي
  static const Color royalNavyDeep = GlassPalette.royalNavyDeep;

  /// بنفسجي ملكي عميق — أساس مجموعة الألوان الجديدة (#240046)
  static const Color royalPurple = GlassPalette.royalPurple;

  /// ليلك هادئ — لون التمييز الرئيسي للمجموعة (#7E6BA7)
  static const Color royalPurpleLight = GlassPalette.royalPurpleLight;

  /// كحلي بارد — درجة مكملة للتدرجات (#003366)
  static const Color royalBlue = GlassPalette.royalBlue;

  /// مصدر الحقيقة الوحيد للتدرّجات — نظام التصميم الزجاجي الموحّد.
  static List<Color> getDynamicGradient(Prayer nextPrayer) =>
      GlassPalette.dynamicGradient(nextPrayer);

  /// التدرج الموحّد لخلفية الشاشة الرئيسية وشاشة «عن التطبيق» —
  /// كلاهما يتبع نفس وضع العرض، فكلما تغيّر لون الشاشة الرئيسية
  /// تغيّر معه لون شاشة «عن التطبيق» تلقائياً.
  static List<Color> appScreenGradient(String themeMode, {Prayer nextPrayer = Prayer.none}) =>
      GlassPalette.gradientFor(themeMode, nextPrayer: nextPrayer);

  /// تدرّج جاهز لاستخدامه مع [AuroraBackground].
  static List<Color> glowFor(String themeMode, {Prayer nextPrayer = Prayer.none}) =>
      GlassPalette.auroraGlowFor(themeMode, nextPrayer: nextPrayer);

  /// تزيين كل ثيمات التطبيق بالمظهر الزجاجي الموحّد (حوارات، حقول، أزرار…).
  static ThemeData _glass(ThemeData base) => GlassThemeData.decorate(base);

  static ThemeData get lightTheme => _glass(ThemeData(brightness: Brightness.light, useMaterial3: true, colorSchemeSeed: accent, scaffoldBackgroundColor: Colors.transparent));
  static ThemeData get darkTheme => _glass(ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.transparent, useMaterial3: true, colorSchemeSeed: accent));

  /// وضع العرض "أسود" — بذرة محايدة (لا كحلية) حتى لا يتلوّن زجاج الواجهة
  /// بنفسجيّاً/كحليّاً فوق الخلفية السوداء.
  static ThemeData get blackTheme => _glass(ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.transparent, useMaterial3: true, colorSchemeSeed: const Color(0xFF101014)));

  /// الوضع عند فتح التطبيق — كحلي ملكي صريح
  static ThemeData get navyTheme => _glass(ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.transparent, useMaterial3: true, colorSchemeSeed: royalNavy));
  static ThemeData get darkBlueTheme => _glass(ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.transparent, useMaterial3: true, colorSchemeSeed: const Color(0xFF0D253F)));

  /// وضع العرض «بنفسجي ملكي» (#240046)
  static ThemeData get royalPurpleTheme => _glass(ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.transparent, useMaterial3: true, colorSchemeSeed: royalPurpleLight));

  /// وضع العرض «ليلكي هادئ» (#7E6BA7)
  static ThemeData get royalPurpleLightTheme => _glass(ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.transparent, useMaterial3: true, colorSchemeSeed: royalPurple));

  /// وضع العرض «كحلي بارد» (#003366)
  static ThemeData get royalBlueTheme => _glass(ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.transparent, useMaterial3: true, colorSchemeSeed: royalPurpleLight));

  /// وضع العرض «بنفسجي غامق» (#3C215E)
  static ThemeData get deepVioletTheme => _glass(ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.transparent, useMaterial3: true, colorSchemeSeed: const Color(0xFF3C215E)));

  /// وضع العرض «نيلي عميق» (#370F94)
  static ThemeData get deepIndigoTheme => _glass(ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: Colors.transparent, useMaterial3: true, colorSchemeSeed: const Color(0xFF370F94)));
}

class DarkFadeRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  DarkFadeRoute({required this.builder});
  @override Color? get barrierColor => null;
  @override String? get barrierLabel => null;
  @override bool get maintainState => true;
  @override Duration get transitionDuration => const Duration(milliseconds: 250);
  @override Duration get reverseTransitionDuration => const Duration(milliseconds: 200);
  @override bool get opaque => true;
  @override Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => builder(context);
  @override Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) => FadeTransition(opacity: animation, child: child);
}

Future<T?> pushDark<T>(BuildContext context, Widget page) => Navigator.push<T>(context, DarkFadeRoute(builder: (_) => page));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool permissionGateDone = true; // تخطي شاشة الأذونات دائماً
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString('adhanMode', 'sound');
    await p.setBool('duaEnabled', true);
    await HeaderFontPrefs.load();
    // حجم خطّ تاريخي الشاشة الرئيسية (الهجري والميلادي) — تفضيل المستخدم
    await HomeDateFontPrefs.load();
    // مفتاح تكبير خط كاردات أوقات الصلاة (الاسم والوقت) — تفضيل المستخدم
    await PrayerCardFontPrefs.load();
    // إعدادات المظهر الزجاجي (شدّة الشفافية وحركة الخلفية) المحفوظة سابقاً
    await GlassRuntime.load();
    // حفظ الحالة كـ done دائماً حتى لا تظهر الشاشة مستقبلاً
    await p.setBool('permissionGateDone', true);
  } catch (_) {}
  adhanAudioService.init();
  try {
    await Supabase.initialize(url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
    await di.init();
    RemoteMessagingService.initRealtimeListener();
    await JustAudioBackground.init(androidNotificationChannelId: 'com.muezzin.libya.audio', androidNotificationChannelName: 'Muezzin Audio', androidNotificationOngoing: true);
    await initializeDateFormatting('ar', null);
    HijriCalendar.setLocal('ar');
    await NotificationService().init();
    await VoiceAnnouncementService().init();
    await ScreenWakeService.init();
    // طلب الصلاحيات بشكل هادئ عند أول فتح فقط — بدون شاشة مخصصة
    SilentPermissionService.requestIfNeeded();
  } catch (e) { debugPrint("Init Error: $e"); }
  runApp(AlMaathenApp(initialPermissionGateDone: permissionGateDone));
}

class AlMaathenApp extends StatefulWidget {
  final bool initialPermissionGateDone;
  const AlMaathenApp({super.key, this.initialPermissionGateDone = false});
  @override State<AlMaathenApp> createState() => _AlMaathenAppState();
}

class _AlMaathenAppState extends State<AlMaathenApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  String _currentTheme = 'black';
  late bool _gateDone;

  @override
  void initState() {
    super.initState();
    _gateDone = widget.initialPermissionGateDone;
    _loadSettings();
  }

  void _loadSettings() async {
    final p = await SharedPreferences.getInstance();
    // تخطي شاشة الأذونات دائماً — الدخول المباشر للتطبيق
    await p.setBool('permissionGateDone', true);
    // اعتماد «الأسود» كخلفية افتراضية للشاشة الرئيسية عند التثبيت الجديد:
    // يُكتب اللون الافتراضي فقط إن لم يكن المستخدم قد اختار لوناً من قبل
    // (لا يُستبدل ولا يُحذف أي اختيار سابق — المستخدمون الحاليون كما هم).
    final migratedTo = p.getString('migratedToVersion') ?? '';
    if (migratedTo != '3.4.7') {
      if (!p.containsKey('themeMode')) {
        await p.setString('themeMode', 'black');
      }
      await p.setString('migratedToVersion', '3.4.7');
    }
    // يُطبَّع الوضع المحفوظ: أي قيمة مجهولة/قديمة/فارغة → «أسود».
    // (بدون ذلك كانت قيمة غير معروفة تُسقط الخلفية على تدرّج الصلاة، فتظهر
    // الشاشة حمراء عنابية عند المغرب رغم أن الإعدادات تقول «أسود».)
    // ── القرآن الكريم: الوضع الليلي هو الافتراضي ──
    // ترحيل **مرّة واحدة** يمحو «white» التي كتبتها النسخ القديمة في
    // READING_MODE، فيفتح القرآن ليلياً كما هو المطلوب، ثم يُحترم اختيار
    // المستخدم بعد ذلك (لا يُفرض الوضع الليلي في كل تشغيل).
    await QuranSettingsDataSourceImpl.migrateToDarkReadingMode(p);
    // وخيار «القرآن: الوضع الليلي دائماً» (مفعّل افتراضاً من شاشة الإعدادات ←
    // المظهر): يُكتب الوضع الليلي في READING_MODE في كل تشغيل، فيفتح القرآن
    // ليلياً دائماً، ويبقى التبديل اليدوي للمطالعة النهارية عاملاً في الجلسة.
    await QuranDarkPrefs.load();
    await QuranDarkPrefs.applyAtStartup(p);

    // النص المتحرك في الشاشة الرئيسية يتبع ألوان أوقات الصلاة افتراضياً
    // (ترحيل مرة واحدة للون الذهبي الافتراضي القديم).
    await HomeMarqueeSettings.migrateMarqueeColorFollowPrayer(p);
    // وخطّه «كايرو عادي» بلا غلظ (ترحيل مرة واحدة للأميري الغليظ القديم).
    await HomeMarqueeSettings.migrateMarqueeFontToCairoRegular(p);

    final stored = p.getString('themeMode');
    final m = GlassPalette.normalizeThemeMode(stored);
    if (stored != m) {
      await p.setString('themeMode', m);
    }
    // يُخزَّن الوضع الحالي عالمياً حتى تتبع كل الشاشات الفرعية نفس الألوان
    GlassRuntime.themeMode = m;
    if (mounted) setState(() {
      _gateDone = true; // دائماً true
      _currentTheme = m;
      if (m == 'system') _themeMode = ThemeMode.system;
      else if (m == 'light') _themeMode = ThemeMode.light;
      else _themeMode = ThemeMode.dark;
    });
  }
  @override Widget build(BuildContext context) {
    ThemeData darkTheme;
    switch (_currentTheme) {
      case 'navy': darkTheme = AlMaathenTheme.navyTheme; break;
      case 'dark_blue': darkTheme = AlMaathenTheme.darkBlueTheme; break;
      case 'royal_purple': darkTheme = AlMaathenTheme.royalPurpleTheme; break;
      case 'royal_purple_light': darkTheme = AlMaathenTheme.royalPurpleLightTheme; break;
      case 'royal_blue': darkTheme = AlMaathenTheme.royalBlueTheme; break;
      case 'deep_violet': darkTheme = AlMaathenTheme.deepVioletTheme; break;
      case 'deep_indigo': darkTheme = AlMaathenTheme.deepIndigoTheme; break;
      case 'black': darkTheme = AlMaathenTheme.blackTheme; break;
      default: darkTheme = AlMaathenTheme.darkTheme;
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => di.sl<QuranBloc>()..add(LoadSurahsEvent())),
        BlocProvider(create: (context) => di.sl<QuranAudioBloc>()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'أوقات الصلاة',
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        theme: AlMaathenTheme.lightTheme,
        darkTheme: darkTheme,
        themeMode: _themeMode,
        home: AppSplashScreen(
          child: Directionality(
            textDirection: ui.TextDirection.rtl,
            // تخطي شاشة الأذونات — الدخول المباشر للتطبيق دائماً
            child: MainNavigationScreen(onThemeChanged: _loadSettings),
          ),
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
