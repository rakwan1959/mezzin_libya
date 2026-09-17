import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui' as ui;
import '../../../../main.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/glass_widgets.dart';
import '../../../../core/theme/glass_theme.dart';
import 'package:muezzin_libya_app/adhan_audio_service.dart';
import 'package:muezzin_libya_app/notification_service.dart';
import 'package:muezzin_libya_app/remote_messaging_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../../core/data/prayer_api_service.dart';
import 'package:hijri/hijri_calendar.dart';
import '../../../../core/services/screen_wake_service.dart';
import '../../../../core/config/header_font_prefs.dart';
import '../../../../core/config/home_date_font_prefs.dart';
import '../../../../core/config/prayer_card_font_prefs.dart';
import '../../../../core/config/quran_dark_prefs.dart';
import '../../../../advanced_settings_screen.dart';
import '../../../../core/database/libyan_prayer_database.dart';
import '../widgets/settings_marquee_header.dart';

class SettingsScreen extends StatefulWidget {
  final bool is24H,
      notif,
      duaEnabled,
      isManualMode,
      showGreeting,
      askNameOnStart,
      tapToStopAdhanEnabled;
  final String sound, city, method, themeMode, userName;
  final List<int> offsets;
  final int hijriOffset, duaOffsetMinutes;
  final Map<String, Coordinates> cities;
  final String initialLat, initialLong;
  final Function(String, String) onApplyManual;
  final Function(bool) onToggleNotif;
  final Function(bool) onToggle24H;
  final Function(String) onNameChanged;
  final VoidCallback onAutoDetect;
  final VoidCallback onUpdate;
  final VoidCallback onBack;

  const SettingsScreen({
    super.key,
    required this.is24H,
    required this.sound,
    required this.city,
    required this.method,
    required this.notif,
    required this.themeMode,
    required this.userName,
    required this.offsets,
    required this.hijriOffset,
    required this.duaEnabled,
    required this.duaOffsetMinutes,
    required this.cities,
    required this.isManualMode,
    required this.initialLat,
    required this.initialLong,
    required this.showGreeting,
    required this.askNameOnStart,
    required this.tapToStopAdhanEnabled,
    required this.onApplyManual,
    required this.onToggleNotif,
    required this.onToggle24H,
    required this.onNameChanged,
    required this.onAutoDetect,
    required this.onUpdate,
    required this.onBack,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _batteryChannel = MethodChannel(
    'com.example.muezzin_libya_app/battery',
  );
  static const _adhanChannel = MethodChannel(
    'com.example.muezzin_libya_app/adhan',
  );
  late TextEditingController _latCtrl;
  late TextEditingController _longCtrl;
  late bool _localNotif;
  late bool _localIs24H;
  late bool _localDuaEnabled;
  late bool _localShowGreeting;
  late bool _localAskNameOnStart;
  late bool _remMorning = true,
      _remEvening = true,
      _remDuha = true,
      _remBeforeAdhan = true,
      _remAfterAdhan = true;
  bool _tapToStopAdhanEnabled = true;
  bool _localKeepScreenOn = false; // إبقاء الشاشة مضاءة دائماً
  bool _vibrateOnAdhan = true; // الاهتزاز عند بداية الأذان
  late int _localHijriOffset;
  double _localVolume = 1.0;
  String _localAdhanMode = 'sound';
  String _localMadhab = 'maliki';
  double _localFajrAngle = 18.5;
  double _localIshaAngle = 18.2;
  bool _useCustomAngles = false;
  bool _localUseApi = false;
  int _localApiMethod = 99; // ليبيا - زوايا مخصصة حسب المدينة
  int _localSplashDuration = 5; // مدة ظهور اللوقو (3/4/5 ثوانٍ)
  // الزوايا الرسمية الموصى بها لكل مدينة (مطابقة لتقويم المصلي - مدار للبرمجة)
  // — مصدر موحد واحد في MainNavigationScreen.cityAngles
  double get _recommendedFajrAngle =>
      MainNavigationScreen.getCityAngles(widget.city)[0];
  double get _recommendedIshaAngle =>
      MainNavigationScreen.getCityAngles(widget.city)[1];
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _updateDebounce;

  static const String _allahNamesStr =
      "اللَّهُ • الرَّحْمَنُ • الرَّحِيمُ • الْمَلِكُ • الْقُدُّوسُ • السَّلَامُ • الْمُؤْمِنُ • الْمُهَيْمِنُ • الْعَزِيزُ • الْجَبَّارُ • الْمُتَكَبِّرُ • الْخَالِقُ • الْبَارِئُ • الْمُصَوِّرُ • الْغَفَّارُ • الْقَهَّارُ • الْوَهَّابُ • الرَّزَّاقُ • الْفَتَّاحُ • الْعَلِيمُ • الْقَابِضُ • الْبَاسِطُ • الْخَافِضُ • الرَّافِعُ • الْمُعِزُّ • الْمُذِلُّ • السَّمِيعُ • الْبَصِيرُ • الْحَكَمُ • الْعَدْلُ • اللَّطِيفُ • الْخَبِيرُ • الْحَلِيمُ • الْعَظِيمُ • الْغَفُورُ • الشَّكُورُ • الْعَلِيُّ • الْكَبِيرُ • الْحَفِيظُ • الْمُقِيتُ • الْحَسِيبُ • الْجَلِيلُ • الْكَرِيمُ • الرَّقِيبُ • الْمُجِيبُ • الْوَاسِعُ • الْحَكِيمُ • الْوَدُودُ • الْمَجِيدُ • الْبَاعِثُ • الشَّهِيدُ • الْحَقُّ • الْوَكِيلُ • الْقَوِيُّ • الْمَتِينُ • الْوَلِيُّ • الْحَمِيدُ • الْمُحْصِي • الْمُبْدِئُ • الْمُعِيدُ • الْمُحْيِي • الْمُمِيتُ • الْحَيُّ • الْقَيُّومُ • الْوَاجِدُ • الْمَاجِدُ • الْوَاحِدُ • الْأَحَدُ • الصَّمَدُ • الْقَادِرُ • الْمُقْتَدِرُ • الْمُقَدِّمُ • الْمُؤَخِّرُ • الْأَوَّلُ • الْآخِرُ • الظَّاهِرُ • الْبَاطِنُ • الْوَالِي • الْمُتَعَالِي • الْبَرُّ • التَّوَّابُ • الْمُنْتَقِمُ • الْعَفُوُّ • الرَّؤُوفُ • مَالِكُ الْمُلْكِ • ذُو الْجَلَالِ وَالْإِكْرَامِ • الْمُقْسِطُ • الْجَامِعُ • الْغَنِيُّ • الْمُغْنِي • الْمَانِعُ • الضَّارُّ • النَّافِعُ • النُّورُ • الْهَادِي • الْبَدِيعُ • الْبَاقِي • الْوَارِثُ • الرَّشِيدُ • الصَّبُورُ";
  /// إعدادات النص المتحرك في الهيدر (النص + اللون + نوع الخط + الحجم).
  /// تُتحكَّم كلها من لوحة التحكم وتصل عبر `RemoteMessagingService`.
  SettingsMarqueeSettings _marqueeSettings = const SettingsMarqueeSettings();

  /// ما يُعرض فعلاً في الهيدر: **الأحاديث المخصصة**، أو النص الواحد،
  /// وإلا أسماء الله الحسنى المضمّنة — ويتقلّب عليها الهيدر بوقت الظهور
  /// المحدَّد من لوحة التحكم.
  List<String> get _marqueeMessages {
    final List<String> custom = _marqueeSettings.effectiveMessages;
    return custom.isEmpty ? <String>[_allahNamesStr] : custom;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _latCtrl = TextEditingController(text: widget.initialLat);
    _longCtrl = TextEditingController(text: widget.initialLong);
    _localNotif = widget.notif;
    _localIs24H = widget.is24H;
    _localDuaEnabled = true; // مفعّل دائماً كوضع افتراضي ثابت
    _localShowGreeting = widget.showGreeting;
    _localAskNameOnStart = widget.askNameOnStart;
    _localHijriOffset = widget.hijriOffset;
    _loadVolume();
    _loadAdhanMode();
    _loadMarqueeText();

    // الاستماع لتغيرات مستوى الصوت من الأزرار الفعلية
    adhanAudioService.systemVolumeNotifier.addListener(_onSystemVolumeChanged);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeIn),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
    _entranceController.forward();
  }

  /// قراءة إعدادات النص المتحرك: المحفوظ على الجهاز أولاً (فلا يظهر الهيدر
  /// فارغاً بلا إنترنت)، ثم محاولة تحديثها من صف `app_config` على السيرفر.
  Future<void> _loadMarqueeText() async {
    final SettingsMarqueeSettings local =
        await RemoteMessagingService.readSettingsMarqueeSettings();
    if (mounted) setState(() => _marqueeSettings = local);

    try {
      // قراءة الصف كاملاً (select بلا أسماء أعمدة): فإن لم تكن أعمدة التنسيق
      // الجديدة مضافة في الجدول يعود الصف بلا خطأ، ونُطبِّق ما وُجد فقط —
      // أما طلب أسماء أعمدة غير موجودة فيُرجع 400 ويُعطّل القراءة كلها.
      final config = await Supabase.instance.client
          .from('app_config')
          .select()
          .eq('id', 1)
          .maybeSingle();
      final SettingsMarqueeSettings remote =
          await RemoteMessagingService.applySettingsMarqueeConfig(config);
      if (mounted) setState(() => _marqueeSettings = remote);
    } catch (_) {
      // بلا إنترنت أو الأعمدة الجديدة غير مضافة: نُبقي المحفوظ على الجهاز
    }
  }

  void _loadAdhanMode() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        // تصحيح تلقائي: إذا كانت القيمة المخزنة غير صالحة (من نسخة قديمة أو
        // تالفة) يتم تفعيل وضع الصوت تلقائياً وحفظ القيمة الصحيحة حتى لا
        // يظهر «وضع صوت الأذان» بدون خيار مفعّل عند فتح التطبيق.
        final rawMode = p.getString('adhanMode');
        _localAdhanMode = (rawMode == 'silent' ||
                rawMode == 'vibration' ||
                rawMode == 'sound')
            ? rawMode!
            : 'sound';
        if (rawMode != _localAdhanMode) {
          p.setString('adhanMode', _localAdhanMode);
        }
        _localMadhab = p.getString('madhab') ?? 'maliki';
        _localFajrAngle = p.getDouble('fajrAngle') ?? 18.4;
        _localIshaAngle = p.getDouble('ishaAngle') ?? 18.2;
        _useCustomAngles = p.getBool('useCustomAngles') ?? false;
        _localUseApi = p.getBool('usePrayerApi') ?? false;
        _localApiMethod = p.getInt('prayerApiMethod') ?? 99;
        _tapToStopAdhanEnabled = p.getBool('tapToStopAdhanEnabled') ?? true;
        _localSplashDuration = p.getInt('splashDuration') ?? 5;
        _vibrateOnAdhan = p.getBool('vibrateOnAdhan') ?? true;
        _remMorning = p.getBool('rem_morning_azkar') ?? true;
        _remEvening = p.getBool('rem_evening_azkar') ?? true;
        _remDuha = p.getBool('rem_duha') ?? true;
        _remBeforeAdhan = p.getBool('remBeforeAdhan') ?? true;
        _remAfterAdhan = p.getBool('remAfterAdhan') ?? true;
        _localDuaEnabled = p.getBool('duaEnabled') ?? true;
        _localKeepScreenOn = p.getBool(ScreenWakeService.keyKeepScreenOn) ?? false;
      });
    }
  }

  void _loadVolume() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      // سنحاول جلب مستوى الصوت الحقيقي من النظام إذا كان متاحاً
      try {
        final am = const MethodChannel('com.example.muezzin_libya_app/adhan');
        final double? systemVol = await am.invokeMethod<double>(
          'getSystemAlarmVolume',
        );
        if (systemVol != null) {
          setState(() => _localVolume = systemVol);
          return;
        }
      } catch (_) {}

      setState(() {
        _localVolume = p.getDouble('adhanVolume') ?? 1.0;
      });
    }
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.notif != oldWidget.notif) _localNotif = widget.notif;
    if (widget.is24H != oldWidget.is24H) _localIs24H = widget.is24H;
    if (widget.duaEnabled != oldWidget.duaEnabled)
      _localDuaEnabled = widget.duaEnabled;
    if (widget.hijriOffset != oldWidget.hijriOffset)
      _localHijriOffset = widget.hijriOffset;
    if (widget.initialLat != oldWidget.initialLat)
      _latCtrl.text = widget.initialLat;
    if (widget.initialLong != oldWidget.initialLong)
      _longCtrl.text = widget.initialLong;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    adhanAudioService.systemVolumeNotifier.removeListener(
      _onSystemVolumeChanged,
    );
    _updateDebounce?.cancel();
    _latCtrl.dispose();
    _longCtrl.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _onSystemVolumeChanged() {
    if (mounted) {
      setState(() {
        _localVolume = adhanAudioService.systemVolumeNotifier.value;
      });
    }
  }

  Future<void> _testApiConnection() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xE0002855), // زجاج كحلي شفاف
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white, width: 1.0),
          ),
          child: const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );

    final isOk = await PrayerApiService.testConnection();

    if (mounted) {
      Navigator.pop(context); // إغلاق لودينج

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOk
                ? 'تم الاتصال بالخادم بنجاح ✓'
                : 'تعذر الاتصال بالخادم، يرجى التحقق من الإنترنت ✗',
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        ),
      );
    }
  }

  void _debouncedUpdate() {
    _updateDebounce?.cancel();
    _updateDebounce = Timer(const Duration(milliseconds: 1000), () {
      widget.onUpdate();
    });
  }

  /// فحص شامل لجاهزية الجهاز لعرض شاشة الأذان فوق القفل — يعرض النتيجة للمستخدم
  Future<void> _showDiagnostics() async {
    String result = '';
    try {
      // 1) إشعارات النظام
      final notifStatus = await Permission.notification.status;
      result +=
          '• التنبيهات: ${notifStatus.isGranted ? "مفعّلة ✅" : "غير مفعّلة ❌"}\n';

      // 2) إذن الشاشة الكاملة (أندرويد 14+)
      final bool? fsi = await _adhanChannel.invokeMethod<bool>(
        'canUseFullScreenIntent',
      );
      result +=
          '• إذن الشاشة الكاملة (14+): ${(fsi ?? false) ? "مفعّل ✅" : "غير مفعّل ❌"}\n';

      // 3) العرض فوق التطبيقات الأخرى
      final bool? overlay = await _adhanChannel.invokeMethod<bool>(
        'canDrawOverlays',
      );
      result +=
          '• العرض فوق التطبيقات: ${(overlay ?? false) ? "مفعّل ✅" : "غير مفعّل ❌"}\n';

      // 4) تحسين البطارية
      final bool battery =
          await _batteryChannel.invokeMethod(
            'isIgnoringBatteryOptimizations',
          ) ??
          false;
      result +=
          '• تحسين البطارية: ${battery ? "معطّل للتطبيق ✅" : "مفعّل — قد يمنع المنبه ❌"}\n';

      // 5) وضع الأذان
      final modeLabel = _localAdhanMode == 'sound'
          ? 'يعمل (صوت)'
          : (_localAdhanMode == 'silent' ? 'صامت' : 'اهتزاز');
      result += '• وضع الأذان: $modeLabel\n';

      result +=
          '\nالنسخة: 2.1 — VER7 (01/08/2026) — شاشة إيقاف الأذان الكحلية باللمس';
    } catch (e) {
      result = 'تعذر الفحص: $e';
    }
    if (mounted) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white, width: 1.0),
          ),
          title: Text(
            'فحص جاهزية شاشة إيقاف الأذان',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            result,
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(
              color: Colors.white70,
              fontSize: 12,
              height: 1.8,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                _requestFullScreenPermission();
              },
              child: Text(
                'إصلاح إذن الشاشة الكاملة',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                _requestOverlayPermission();
              },
              child: Text(
                'إصلاح العرض فوق التطبيقات',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(
                'إغلاق',
                style: GoogleFonts.cairo(color: Colors.white54),
              ),
            ),
          ],
        ),
      );
    }
  }

  /// ── أدوات التشخيص المخفية ───────────────────────────────────────────────
  ///
  /// تُفتح بـ**ضغط مطوّل** على عنوان الهيدر (الاسم المتحرك): قائمة سفلية زجاجية
  /// تجمع تجارب الإشعارات والأذان وحالة خدمات النظام في مكان واحد، بلا أي زر
  /// ظاهر يشغل واجهة المستخدم العادي.
  Future<void> _openHiddenDiagnostics() async {
    HapticFeedback.mediumImpact(); // تأكيد لمسي يخبر أن الإيماءة اشتغلت
    await showGlassSheet<void>(
      context: context,
      accent: GlassPalette.gold,
      child: _DiagnosticsSheet(
        sound: widget.sound,
        // الفحص الشامل نفسُه المستخدَم في قسم «شاشة إيقاف الأذان»
        onRunFullDiagnostics: _showDiagnostics,
      ),
    );
  }

  /// فحص إذن «العرض فوق التطبيقات الأخرى» وفتح صفحة المنح إذا كان غير مفعّل
  /// — هذا الإذن يجعل الشاشة تظهر فوق القفل حتى على أندرويد 15/16 مهما كانت القيود
  Future<void> _requestOverlayPermission() async {
    try {
      final bool? canDraw = await _adhanChannel.invokeMethod<bool>(
        'canDrawOverlays',
      );
      if (canDraw == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '«العرض فوق التطبيقات الأخرى» مفعّل بالفعل ✓',
                textAlign: TextAlign.right,
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
            ),
          );
        }
      } else {
        await _adhanChannel.invokeMethod('requestOverlayPermission');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر فتح الإعدادات: $e',
              textAlign: TextAlign.right,
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
          ),
        );
      }
    }
  }

  /// فحص إذن الشاشة الكاملة (أندرويد 14+) وفتح صفحة المنح إذا كان غير مفعّل
  Future<void> _requestFullScreenPermission() async {
    try {
      final bool? canUse = await _adhanChannel.invokeMethod<bool>(
        'canUseFullScreenIntent',
      );
      if (canUse == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'إذن الشاشة الكاملة مفعّل بالفعل ✓',
                textAlign: TextAlign.right,
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
            ),
          );
        }
      } else {
        await _adhanChannel.invokeMethod('requestFullScreenIntentPermission');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر فتح الإعدادات: $e',
              textAlign: TextAlign.right,
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
            backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onBack,
                      child: AuroraGlassCard(
                        padding: const EdgeInsets.all(10),
                        borderRadius: BorderRadius.circular(15),
                        isActive: true,
                        glowColor: Colors.white,
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      // ── إيماءة مخفية: ضغط مطوّل على العنوان يفتح أدوات
                      // التشخيص (إشعارات وأذان) — لا زر ظاهر للمستخدم ──
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPress: _openHiddenDiagnostics,
                        child: SettingsMarqueeHeader(
                          messages: _marqueeMessages,
                          settings: _marqueeSettings,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _searchToolsCard(),
                      const SizedBox(height: 16),
                      _sectionHeader(
                        'الموقع والإحداثيات',
                        color: Colors.white,
                      ),
                      _card([
                        _switchItem(
                          icon: Icons.edit_location_alt_rounded,
                          title: 'إدخال الإحداثيات يدوياً',
                          value: widget.isManualMode,
                          onChanged: (v) => _saveBool('isManualMode', v),
                          iconColor: Colors.white,
                        ),
                        if (widget.isManualMode) ...[
                          _divider(),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildManualInput(
                                        _latCtrl,
                                        'خط العرض',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildManualInput(
                                        _longCtrl,
                                        'خط الطول',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Colors.white,
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize: const Size(
                                      double.infinity,
                                      45,
                                    ),
                                  ),
                                  onPressed: () {
                                    widget.onApplyManual(
                                      _latCtrl.text,
                                      _longCtrl.text,
                                    );
                                    FocusScope.of(context).unfocus();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'تم حفظ الإحداثيات بنجاح',
                                          textAlign: TextAlign.right,
                                          style: GoogleFonts.cairo(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'تطبيق وحفظ الإحداثيات',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        _divider(),
                        _premiumItem(
                          icon: Icons.location_city_rounded,
                          title: 'المدينة',
                          subtitle: widget.isManualMode
                              ? 'موقف (يدوي)'
                              : widget.city,
                          iconColor: Colors.white,
                          onTap: widget.isManualMode
                              ? () {}
                              : () => _selectionDialog(
                                  context,
                                  'اختر المدينة',
                                  Map.fromIterable(
                                    widget.cities.keys,
                                    key: (k) => k,
                                    value: (v) => v,
                                  ),
                                  widget.city,
                                  (v) => _save('city', v),
                                ),
                        ),
                        _divider(),
                        _premiumItem(
                          icon: Icons.my_location_rounded,
                          title: 'تحديد تلقائي للموقع',
                          subtitle: 'البحث عن أقرب مدينة لموقعك الحالي',
                          iconColor: Colors.white,
                          onTap: () {
                            widget.onAutoDetect();
                          },
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _sectionHeader(
                        'الأذان والصوت',
                        color: Colors.white,
                      ),
                      _card([
                        _premiumItem(
                          icon: Icons.record_voice_over_rounded,
                          title: 'المؤذن',
                          subtitle: _adhanSoundLabel(widget.sound),
                          iconColor: Colors.white,
                          onTap: () => _selectionDialog(
                            context,
                            'اختر المؤذن',
                            {
                              'عبد الباسط عبد الصمد': 'abdulbaset',
                              'محمد الصديق المنشاوي': 'minshawi',
                              'أذان الحرم المكي': 'makkah',
                              'شريف مصطفى': 'sherif_mostafa',
                              'حمد دغرير': 'hamd_deghrer',
                              'محمد الدوكالي': 'mohamed_dokale',
                            },
                            widget.sound,
                            (v) => _save('sound', v),
                          ),
                        ),
                        _divider(),
                        _adhanModeSelectorItem(),
                        _divider(),
                        _switchItem(
                          icon: Icons.touch_app_rounded,
                          title: 'إيقاف الأذان بلمس الشاشة',
                          value: _tapToStopAdhanEnabled,
                          iconColor: Colors.white,
                          onChanged: (v) async {
                            setState(() => _tapToStopAdhanEnabled = v);
                            final p = await SharedPreferences.getInstance();
                            await p.setBool('tapToStopAdhanEnabled', v);
                            widget.onUpdate();
                          },
                        ),
                        _divider(),
                        _switchItem(
                          icon: Icons.graphic_eq_rounded,
                          title: 'دعاء ما بعد الأذان',
                          value: _localDuaEnabled,
                          iconColor: Colors.white,
                          onChanged: (v) async {
                            setState(() => _localDuaEnabled = v);
                            final p = await SharedPreferences.getInstance();
                            await p.setBool('duaEnabled', v);
                            widget.onUpdate();
                          },
                        ),

                        _divider(),
                        _volumeSliderItem(),
                        _divider(),
                      ]),
                      const SizedBox(height: 20),

                      _sectionHeader(
                        'شاشة إيقاف الأذان',
                        color: Colors.white,
                      ),
                      _card([
                        _premiumItem(
                          icon: Icons.verified_user_rounded,
                          title: 'فحص شاشة إيقاف الأذان',
                          subtitle: 'اضغط لفحص جاهزية جهازك لشاشة إيقاف الأذان',
                          iconColor: Colors.white,
                          onTap: _showDiagnostics,
                        ),

                        _divider(),
                        _premiumItem(
                          icon: Icons.fullscreen_rounded,
                          title: 'إذن الشاشة الكاملة',
                          subtitle:
                              'يفتح صفحة "المنبهات والتذكيرات" لمنح الإذن',
                          iconColor: Colors.white,
                          onTap: _requestFullScreenPermission,
                        ),
                        _divider(),
                        _premiumItem(
                          icon: Icons.picture_in_picture_alt_rounded,
                          title: 'العرض فوق التطبيقات الأخرى',
                          subtitle:
                              'الأضمن لظهور الشاشة فوق القفل (أندرويد 15/16)',
                          iconColor: Colors.white,
                          onTap: _requestOverlayPermission,
                        ),
                      ]),
                      const SizedBox(height: 20),

                      _sectionHeader(
                        'التنبيهات والوقت',
                        color: Colors.white,
                      ),
                      _card([
                        _switchItem(
                          icon: Icons.notifications_active_rounded,
                          title: 'ظهور إشعارات الأذان (نصي)',
                          value: _localNotif,
                          iconColor: Colors.white,
                          onChanged: (v) {
                            setState(() => _localNotif = v);
                            _saveBool('notif', v);
                            widget.onToggleNotif(v);
                          },
                        ),
                        _divider(),
                        _switchItem(
                          icon: Icons.notification_important_rounded,
                          title: 'تذكير قبل الأذان (5 دقائق)',
                          value: _remBeforeAdhan,
                          iconColor: Colors.white,
                          onChanged: (v) async {
                            setState(() => _remBeforeAdhan = v);
                            final p = await SharedPreferences.getInstance();
                            await p.setBool('remBeforeAdhan', v);
                            widget.onUpdate();
                          },
                        ),
                        _divider(),
                        _switchItem(
                          icon: Icons.notifications_active_rounded,
                          title: 'تذكير بعد الأذان (10 دقائق)',
                          value: _remAfterAdhan,
                          iconColor: Colors.white,
                          onChanged: (v) async {
                            setState(() => _remAfterAdhan = v);
                            final p = await SharedPreferences.getInstance();
                            await p.setBool('remAfterAdhan', v);
                            widget.onUpdate();
                          },
                        ),
                        _divider(),
                        _premiumItem(
                          icon: Icons.alarm_on_rounded,
                          title: 'إعدادات التنبيهات والسنن والأذكار',
                          subtitle: 'أذكار الصباح والمساء، الضحى، صيام الإثنين والخميس والبيض، الجمعة، الكهف',
                          iconColor: const Color(0xFFDFBA6B),
                          onTap: () {
                            final coord = widget.cities[widget.city] ??
                                LibyanPrayerDatabase.getCityCoordinates(widget.city);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdvancedSettingsScreen(
                                  coordinates: coord,
                                  offsets: widget.offsets,
                                ),
                              ),
                            );
                          },
                        ),
                        _divider(),
                        _timeFormatSelectorItem(),
                      ]),
                      const SizedBox(height: 20),
                      _sectionHeader('المظهر', color: Colors.white),
                      _card([
                        _premiumItem(
                          icon: Icons.dark_mode_rounded,
                          title: 'وضع العرض',
                          subtitle: _getThemeName(widget.themeMode),
                          iconColor: Colors.white,
                          onTap: () => _selectionDialog(
                            context,
                            'وضع العرض',
                            {
                              'أسود': 'black',
                              'بنفسجي ملكي': 'royal_purple',
                              'ليلكي هادئ': 'royal_purple_light',
                              'كحلي بارد': 'royal_blue',
                              'كحلي ملكي': 'navy',
                              'أزرق داكن': 'dark_blue',
                              'بنفسجي غامق (#3C215E)': 'deep_violet',
                              'نيلي عميق (#370F94)': 'deep_indigo',
                              'تلقائي (النظام)': 'system',
                            },
                            // الوضع المُطبَّع: فتقع علامة الاختيار على الوضع
                            // الفعّال فعلاً (وما عدا ذلك يُعامَل كـ«أسود»)
                            GlassPalette.normalizeThemeMode(widget.themeMode),
                            (v) => _save('themeMode', v),
                          ),
                          ),
                          _premiumItem(
                            icon: Icons.format_size_rounded,
                            title: 'حجم خط العناوين',
                            subtitle: HeaderFontPrefs.currentLabel(),
                            iconColor: Colors.white,
                            onTap: () => _selectionDialog<int>(
                              context,
                              'حجم خط العناوين',
                              {
                                'تصغير (-3)': -3,
                                'عادي (0)': 0,
                                'تكبير (+3)': 3,
                              },
                              HeaderFontPrefs.adjustment.value,
                              (v) async {
                                await HeaderFontPrefs.save(v);
                                if (mounted) setState(() {});
                                widget.onUpdate();
                              },
                            ),
                          ),
                          // ── حجم خطّ تاريخي الشاشة الرئيسية (الهجري والميلادي)
                          // إعداد واحد يقيس على التاريخين معاً ويُحفظ فيتفادى
                          // العودة للحجم الأصلي عند كل تشغيل
                          _premiumItem(
                            icon: Icons.event_note_rounded,
                            title: 'حجم خط التاريخ (الهجري والميلادي)',
                            subtitle: HomeDateFontPrefs.currentLabel(),
                            iconColor: Colors.white,
                            onTap: () => _selectionDialog<int>(
                              context,
                              'حجم خط التاريخ (الهجري والميلادي)',
                              {
                                for (final int v in HomeDateFontPrefs.options)
                                  HomeDateFontPrefs.labelOf(v): v,
                              },
                              HomeDateFontPrefs.adjustment.value,
                              (v) async {
                                await HomeDateFontPrefs.save(v);
                                if (mounted) setState(() {});
                                widget.onUpdate();
                              },
                            ),
                          ),
                          // ── درجة خطّ كاردات أوقات الصلاة (الاسم والوقت) ──
                          // التكبير (+2) / العادي (0) / التصغير (−2): اختيار
                          // واحد يُحفظ فيبقى كما تركه المستخدم عند كل تشغيل
                          _premiumItem(
                            icon: Icons.text_fields_rounded,
                            title: 'تكبير خط كاردات الصلاة',
                            subtitle:
                                'اسم الصلاة والوقت: ${PrayerCardFontPrefs.currentLabel()}',
                            iconColor: Colors.white,
                            onTap: () => _selectionDialog<int>(
                              context,
                              'تكبير خط كاردات الصلاة',
                              {
                                for (final int v
                                    in PrayerCardFontPrefs.options)
                                  PrayerCardFontPrefs.labelOf(v): v,
                              },
                              PrayerCardFontPrefs.adjustment.value,
                              (v) async {
                                await PrayerCardFontPrefs.save(v);
                                if (mounted) setState(() {});
                                widget.onUpdate();
                              },
                            ),
                          ),
                          _divider(),
                          _splashDurationSelectorItem(),
                          _divider(),
                          // ── شدّة شفافية الزجاج (يتحكم بها المستخدم) ──
                          _premiumItem(
                            icon: Icons.blur_on_rounded,
                            title: 'شدّة الشفافية',
                            subtitle: GlassRuntime.intensity.label,
                            iconColor: Colors.white,
                            onTap: () => _selectionDialog<GlassIntensity>(
                              context,
                              'شدّة الشفافية',
                              {
                                for (final i in GlassIntensity.values) i.description: i,
                              },
                              GlassRuntime.intensity,
                              (v) async {
                                await GlassRuntime.setIntensity(v);
                                if (mounted) setState(() {});
                                widget.onUpdate();
                              },
                            ),
                          ),
                          _switchItem(
                            icon: Icons.animation_rounded,
                            title: 'حركة الخلفية',
                            subtitle: 'تدرّج ملوّن نابض خلف الزجاج',
                            value: GlassRuntime.motion,
                            onChanged: (v) async {
                              await GlassRuntime.setMotion(v);
                              if (mounted) setState(() {});
                              widget.onUpdate();
                            },
                          ),
                          // ── القرآن الكريم: الوضع الليلي دائماً ──
                          // مفعّل افتراضاً: يفتح القرآن ليلياً في كل تشغيل حتى
                          // لو جُرّب الوضع النهاري قبل ذلك. وإطفاؤه يجعل الشاشة
                          // تفتح على آخر وضع اختاره المستخدم.
                          _switchItem(
                            icon: Icons.nightlight_round,
                            title: 'القرآن: الوضع الليلي دائماً',
                            subtitle: QuranDarkPrefs.statusLabel(),
                            value: QuranDarkPrefs.enabled,
                            onChanged: (v) async {
                              await QuranDarkPrefs.save(v);
                              if (mounted) setState(() {});
                              widget.onUpdate();
                            },
                          ),
                      ]),
                      const SizedBox(height: 20),
                      _sectionHeader(
                        'البطارية والنظام',
                        color: Colors.white,
                      ),
                      _card([
                        _premiumItem(
                          icon: Icons.battery_saver_rounded,
                          title: 'تحسين البطارية',
                          subtitle: 'لضمان عمل الأذان بدقة',
                          iconColor: Colors.white,
                          onTap: () async {
                            try {
                              final bool isIgnored = await _batteryChannel
                                  .invokeMethod(
                                    'isIgnoringBatteryOptimizations',
                                  );
                              if (!isIgnored) {
                                await _batteryChannel.invokeMethod(
                                  'requestIgnoreBatteryOptimizations',
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'تحسين البطارية مُلغى بالفعل للتطبيق',
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.cairo(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
                                  ),
                                );
                              }
                            } catch (e) {
                              final status = await Permission
                                  .ignoreBatteryOptimizations
                                  .status;
                              if (!status.isGranted)
                                await Permission.ignoreBatteryOptimizations
                                    .request();
                            }
                          },
                        ),
                        _divider(),
                        _switchItem(
                          icon: Icons.screen_lock_portrait_rounded,
                          title: 'إبقاء الشاشة مضاءة دائماً',
                          subtitle: 'منع قفل أو انطفاء الشاشة التلقائي أثناء فتح التطبيق',
                          value: _localKeepScreenOn,
                          iconColor: Colors.white,
                          onChanged: (v) async {
                            setState(() => _localKeepScreenOn = v);
                            await ScreenWakeService.setKeepScreenOn(v);
                          },
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _sectionHeader('الحساب', color: Colors.white),
                      _card([
                        _premiumItem(
                          icon: Icons.calculate_rounded,
                          title: 'طريقة الحساب',
                          subtitle: widget.method == 'ليبيا (الأوقاف)'
                              ? 'قاعدة بيانات الأوقاف الليبية (محلية أوفلاين)'
                              : widget.method,
                          iconColor: Colors.white,
                          onTap: () => _selectionDialog(
                            context,
                            'طريقة الحساب',
                            {
                              'قاعدة بيانات الأوقاف الليبية (محلية أوفلاين) – مطابقة للمساجد':
                                  'ليبيا (الأوقاف)',
                              'أم القرى (مكة المكرمة)': 'أم القرى',
                              'رابطة العالم الإسلامي': 'رابطة العالم الإسلامي',
                              'الهيئة المصرية العامة': 'الهيئة المصرية',
                              'جامعة العلوم الإسلامية (كراتشي)':
                                  'جامعة العلوم الإسلامية (كراتشي)',
                              'الاتحاد الإسلامي (ISNA)':
                                  'الاتحاد الإسلامي (ISNA)',
                              'دبي': 'دبي',
                              'الكويت': 'الكويت',
                              'قطر': 'قطر',
                            },
                            widget.method,
                            (v) => _save('method', v),
                          ),
                        ),
                        _divider(),
                        _premiumItem(
                          icon: Icons.menu_book_rounded,
                          title: 'المذهب الفقهي',
                          subtitle: _localMadhab == 'hanafi'
                              ? 'الحنفي'
                              : _localMadhab == 'shafi'
                              ? 'الشافعي'
                              : _localMadhab == 'hanbali'
                              ? 'الحنبلي'
                              : 'المالكي (السائد في ليبيا)',
                          iconColor: Colors.white,
                          onTap: () => _selectionDialog(
                            context,
                            'اختر المذهب الفقهي',
                            {
                              'المالكي (السائد في ليبيا)': 'maliki',
                              'الشافعي': 'shafi',
                              'الحنفي': 'hanafi',
                              'الحنبلي': 'hanbali',
                            },
                            _localMadhab,
                            (v) async {
                              setState(() => _localMadhab = v);
                              final p = await SharedPreferences.getInstance();
                              await p.setString('madhab', v);
                              widget.onUpdate();
                            },
                          ),
                        ),
                        _divider(),
                        _premiumItem(
                          icon: Icons.tune_rounded,
                          title: 'تعديل يدوي',
                          subtitle: 'ضبط الدقائق',
                          iconColor: Colors.white,
                          onTap: () => _offDialog(context),
                        ),
                        _divider(),
                        _anglesOptionSection(),
                        _divider(),
                        _apiOptionItem(),
                        _divider(),
                        _premiumItem(
                          icon: Icons.calendar_month_rounded,
                          title: 'تعديل التاريخ الهجري',
                          subtitle: _localHijriOffset == 0
                              ? 'تلقائي'
                              : (_localHijriOffset > 0
                                    ? '+$_localHijriOffset يوم'
                                    : '$_localHijriOffset يوم'),
                          iconColor: Colors.white,
                          onTap: () => _hijriDialog(context),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchToolsCard() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => launchUrl(
              Uri.parse("https://chatgpt.com"),
              mode: LaunchMode.externalApplication,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10a37f).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF10a37f).withOpacity(0.35),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10a37f),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: CustomPaint(painter: ChatGptLogoPainter()),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    "ChatGPT",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => launchUrl(
              Uri.parse("https://www.google.com"),
              mode: LaunchMode.externalApplication,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF4285F4).withOpacity(0.35),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "G",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF4285F4),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    "Google",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.search_rounded,
                    color: Colors.white54,
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildManualInput(TextEditingController ctrl, String label) =>
      TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        style: const TextStyle(color: Colors.white, fontSize: 11),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 9),
          isDense: true,
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      );

  Widget _sectionHeader(
    String title, {
    Color color = Colors.white,
  }) => Padding(
    padding: const EdgeInsets.only(right: 4, bottom: 8, top: 4),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withOpacity(0.3)],
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.3), blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.amiri(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );

  void _showNameEditDialog() {
    final ctrl = TextEditingController(text: widget.userName);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white, width: 1.0),
        ),
        title: Text(
          'تعديل الاسم',
          textAlign: TextAlign.right,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: ctrl,
          textAlign: TextAlign.right,
          style: const TextStyle(color: Colors.white),
          maxLength: 10,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\u0621-\u064A\s]')),
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            counterText: "",
            hintText: 'اكتب اسمك الأول بالعربية',
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final p = await SharedPreferences.getInstance();
              await p.remove('userName');
              widget.onNameChanged('');
              Navigator.pop(c);
            },
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                // فلتر أخلاقي صامت
                final List<String> blacklist = [
                  'حمار',
                  'كلب',
                  'قرد',
                  'خنزير',
                  'تيس',
                  'حيوان',
                  'حقير',
                  'سافل',
                ];
                if (blacklist.any((word) => newName.contains(word))) {
                  return;
                }
                final p = await SharedPreferences.getInstance();
                await p.setString('userName', newName);
                widget.onNameChanged(newName);
              }
              Navigator.pop(c);
            },
            child: Text(
              'حفظ',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => AuroraGlassCard(
    borderRadius: BorderRadius.circular(18),
    blur: 16,
    padding: EdgeInsets.zero,
    child: Column(children: children),
  );

  Widget _divider() => Divider(
    color: Colors.white.withOpacity(0.05),
    height: 1,
    indent: 16,
    endIndent: 16,
  );

  Widget _premiumItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color iconColor = Colors.white,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    splashColor: iconColor.withOpacity(0.08),
    highlightColor: iconColor.withOpacity(0.04),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  iconColor.withOpacity(0.15),
                  iconColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: iconColor.withOpacity(0.1), width: 0.5),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 8.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 10,
            color: iconColor.withOpacity(0.3),
          ),
        ],
      ),
    ),
  );

  Widget _switchItem({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool) onChanged,
    String? subtitle,
    Color iconColor = Colors.white,
    Widget? trailingAction,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                iconColor.withOpacity(0.15),
                iconColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: iconColor.withOpacity(0.1), width: 0.5),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 8.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailingAction != null) trailingAction,
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: iconColor,
            activeTrackColor: iconColor.withOpacity(0.3),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white.withOpacity(0.08),
          ),
        ),
      ],
    ),
  );

  void _save(String k, String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(k, v);
    widget.onUpdate();
  }

  void _saveBool(String k, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(k, v);
    widget.onUpdate();
  }

  void _selectionDialog<T>(
    BuildContext context,
    String title,
    Map<String, T> options,
    T currentValue,
    Function(T) onSelected,
  ) {
    showDialog(
      context: context,
      // المظهر الزجاجي (اللون والحدود والزوايا) يأتي من الثيم الموحّد
      builder: (c) => AlertDialog(
        title: Text(
          title,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.entries
                  .map(
                    (e) => RadioListTile<T>(
                      title: Text(
                        e.key,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      value: e.value,
                      groupValue: currentValue,
                      activeColor: Colors.white,
                      onChanged: (v) {
                        if (v != null) onSelected(v);
                        Navigator.pop(c);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _hijriDialog(BuildContext context) {
    const List<String> hijriMonthsArabic = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الآخر',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setST) {
          final currentHijri = HijriCalendar.fromDate(
            DateTime.now().add(Duration(days: _localHijriOffset)),
          );
          final monthName =
              hijriMonthsArabic[(currentHijri.hMonth - 1).clamp(0, 11)];
          final hijriDateStr =
              '${currentHijri.hDay} $monthName ${currentHijri.hYear} هـ';

          return AlertDialog(
            title: const Text(
              'تعديل التاريخ الهجري',
              textAlign: ui.TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'يمكنك زيادة أو إنقاص التاريخ الهجري بالأيام لمطابقة الرؤية المحلية الهلالية.',
                    textAlign: ui.TextAlign.right,
                    style: GoogleFonts.cairo(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hijriDateStr,
                    textAlign: ui.TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FittedBox(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: () async {
                            final p = await SharedPreferences.getInstance();
                            int newVal = _localHijriOffset - 1;
                            await p.setInt('hijriOffset', newVal);
                            setST(() => _localHijriOffset = newVal);
                            setState(() {});
                            _debouncedUpdate();
                          },
                        ),
                        const SizedBox(width: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _localHijriOffset == 0
                                ? 'تلقائي'
                                : (_localHijriOffset > 0
                                      ? '+$_localHijriOffset يوم'
                                      : '$_localHijriOffset يوم'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: () async {
                            final p = await SharedPreferences.getInstance();
                            int newVal = _localHijriOffset + 1;
                            await p.setInt('hijriOffset', newVal);
                            setST(() => _localHijriOffset = newVal);
                            setState(() {});
                            _debouncedUpdate();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(
                  'إغلاق',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _apiOptionItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'API خارجي لأوقات الصلاة',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Aladhan.com – طريقة ليبيا الرسمية (فجر 18° / عشاء 18°)',
                      style: GoogleFonts.cairo(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 8.5,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _localUseApi,
                  onChanged: (v) async {
                    setState(() => _localUseApi = v);
                    final p = await SharedPreferences.getInstance();
                    await p.setBool('usePrayerApi', v);
                    widget.onUpdate();
                  },
                  activeColor: Colors.white,
                  activeTrackColor: Colors.white.withOpacity(0.3),
                  inactiveThumbColor: Colors.white38,
                ),
              ),
            ],
          ),
          if (_localUseApi) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'عند التفعيل، يتم جلب أوقات الصلاة من API خارجي (Aladhan).\nطريقة ليبيا الرسمية = فجر 18° / عشاء 18° (كراتشي) المطابقة لتقويم المصلي.',
                      style: GoogleFonts.cairo(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // طريقة API
            InkWell(
              onTap: () => _selectionDialog(
                context,
                'طريقة API',
                {
                  'ليبيا (الأوقاف) – زوايا حسب المدينة (مطابقة للمصلي)': 99,
                  'رابطة العالم الإسلامي (18°)': 3,
                  'أم القرى (مكة المكرمة)': 4,
                  'جامعة العلوم الإسلامية (كراتشي) (18°/18°)': 1,
                  'الاتحاد الإسلامي (ISNA) (15°)': 2,
                  'قطر': 8,
                  'الكويت': 9,
                  'دبي': 10,
                },
                _localApiMethod,
                (v) async {
                  setState(() => _localApiMethod = v);
                  final p = await SharedPreferences.getInstance();
                  await p.setInt('prayerApiMethod', v);
                  widget.onUpdate();
                },
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.api_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'طريقة API: ${_getApiMethodName(_localApiMethod)}',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white38,
                      size: 8,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // زر اختبار الاتصال
            InkWell(
              onTap: _testApiConnection,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.flash_on_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'اختبار اتصال API',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getApiMethodName(int code) {
    switch (code) {
      case 99:
        return 'ليبيا (الأوقاف) – زوايا حسب المدينة';
      case 1:
        return 'كراتشي (18°/18°)';
      case 3:
        return 'رابطة العالم الإسلامي (18°)';
      case 4:
        return 'أم القرى (مكة)';
      case 5:
        return 'الهيئة المصرية (19.5°)';
      case 2:
        return 'ISNA (15°)';
      case 8:
        return 'قطر';
      case 9:
        return 'الكويت';
      case 10:
        return 'دبي';
      default:
        return 'ليبيا (الأوقاف) – زوايا حسب المدينة';
    }
  }

  Widget _anglesOptionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.architecture_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تعديل زوايا الأهلة (الفجر والعشاء)',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _useCustomAngles
                          ? 'تخصيص زوايا حساب الفجر والعشاء يدوياً'
                          : 'مضبوط تلقائياً: فجر ${_recommendedFajrAngle}° • عشاء ${_recommendedIshaAngle}° (الأوقاف)',
                      style: GoogleFonts.cairo(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 8.5,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _useCustomAngles,
                  onChanged: (v) async {
                    setState(() => _useCustomAngles = v);
                    final p = await SharedPreferences.getInstance();
                    await p.setBool('useCustomAngles', v);
                    if (!v) {
                      // عند التعطيل نستعيد الزوايا الرسمية المعتمدة لمدينة المستخدم
                      final recF = _recommendedFajrAngle;
                      final recI = _recommendedIshaAngle;
                      setState(() {
                        _localFajrAngle = recF;
                        _localIshaAngle = recI;
                      });
                      await p.setDouble('fajrAngle', recF);
                      await p.setDouble('ishaAngle', recI);
                    }
                    widget.onUpdate();
                  },
                  activeColor: Colors.white,
                  activeTrackColor: Colors.white.withValues(alpha: 0.3),
                  inactiveThumbColor: Colors.white38,
                ),
              ),
            ],
          ),
          if (_useCustomAngles) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تعديل زوايا الأهلة مفعّل: يمكنك ضبط زاوية الفجر والعشاء أدناه.',
                      style: GoogleFonts.cairo(
                        color: Colors.white70,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _angleSliderItem(isFajr: true),
            const Divider(color: Colors.white10, height: 16),
            _angleSliderItem(isFajr: false),
          ],
        ],
      ),
    );
  }

  Widget _angleSliderItem({required bool isFajr}) {
    final currentAngle = isFajr ? _localFajrAngle : _localIshaAngle;
    final key = isFajr ? 'fajrAngle' : 'ishaAngle';
    final title = isFajr ? 'زاوية الفجر' : 'زاوية العشاء';
    final icon = isFajr ? Icons.nights_stay_rounded : Icons.dark_mode_rounded;
    final min = 15.0;
    final max = 25.0;
    final recFajr = _recommendedFajrAngle;
    final recIsha = _recommendedIshaAngle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // زر الزاوية الرسمية الليبية (تُضبط تلقائياً حسب المدينة المختارة)
              if ((isFajr && currentAngle != recFajr) ||
                  (!isFajr && currentAngle != recIsha))
                GestureDetector(
                  onTap: () async {
                    final recommended = isFajr ? recFajr : recIsha;
                    setState(() {
                      if (isFajr)
                        _localFajrAngle = recommended;
                      else
                        _localIshaAngle = recommended;
                    });
                    final p = await SharedPreferences.getInstance();
                    await p.setDouble(key, recommended);
                    _debouncedUpdate();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم تطبيق الزاوية الرسمية الليبية ($recommended°) – مطابقة للمصلي',
                          textAlign: ui.TextAlign.right,
                          style: GoogleFonts.cairo(fontSize: 10),
                        ),
                        duration: const Duration(seconds: 1),
                        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Text(
                      'الرسمي في ليبيا',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${currentAngle.toStringAsFixed(1)}°',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${min.toInt()}°',
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: const Color(
                      0xFF9FA8DA,
                    ).withOpacity(0.2),
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withOpacity(0.12),
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                  ),
                  child: Slider(
                    value: currentAngle,
                    min: min,
                    max: max,
                    divisions: 20,
                    onChanged: (v) async {
                      setState(() {
                        if (isFajr) {
                          _localFajrAngle = v;
                        } else {
                          _localIshaAngle = v;
                        }
                      });
                      final p = await SharedPreferences.getInstance();
                      await p.setDouble(key, v);
                      _debouncedUpdate();
                    },
                  ),
                ),
              ),
              Text(
                '${max.toInt()}°',
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9),
              ),
            ],
          ),
          Text(
            isFajr
                ? 'الرسمي في ليبيا: فجر $_recommendedFajrAngle° (مطابق للمصلي)\nزاوية أكبر = أذان أبكر • زاوية أصغر = أذان متأخر'
                : 'الرسمي في ليبيا: عشاء $_recommendedIshaAngle° (مطابق للمصلي)\nزاوية أصغر = أذان أبكر • زاوية أكبر = أذان متأخر',
            style: GoogleFonts.cairo(
              color: Colors.white.withOpacity(0.3),
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  void _offDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setST) {
          return AlertDialog(
            backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white, width: 1.0),
            ),
            title: Text(
              'تعديل يدوي (بالدقائق)',
              textAlign: ui.TextAlign.right,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _offItem('الفجر', 'fOff', widget.offsets[0], (v) {
                      setST(() => widget.offsets[0] = v);
                    }),
                    _offItem('الشروق', 'sOff', widget.offsets.length > 5 ? widget.offsets[5] : 0, (v) {
                      setST(() {
                        if (widget.offsets.length > 5) {
                          widget.offsets[5] = v;
                        } else {
                          widget.offsets.add(v);
                        }
                      });
                    }),
                    _offItem('الظهر', 'dOff', widget.offsets[1], (v) {
                      setST(() => widget.offsets[1] = v);
                    }),
                    _offItem('العصر', 'aOff', widget.offsets[2], (v) {
                      setST(() => widget.offsets[2] = v);
                    }),
                    _offItem('المغرب', 'mOff', widget.offsets[3], (v) {
                      setST(() => widget.offsets[3] = v);
                    }),
                    _offItem('العشاء', 'iOff', widget.offsets[4], (v) {
                      setST(() => widget.offsets[4] = v);
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final p = await SharedPreferences.getInstance();
                  final keys = ['fOff', 'dOff', 'aOff', 'mOff', 'iOff', 'sOff'];
                  for (var k in keys) await p.setInt(k, 0);
                  setST(() {
                    for (int i = 0; i < widget.offsets.length; i++) widget.offsets[i] = 0;
                  });
                  setState(() {});
                  _debouncedUpdate();
                },
                child: Text(
                  'تصفير الكل',
                  style: GoogleFonts.cairo(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(
                  'إغلاق',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _offItem(String l, String k, int cur, Function(int) onUIUpdate) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(l, style: const TextStyle(color: Colors.white, fontSize: 12)),
      Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () async {
              final p = await SharedPreferences.getInstance();
              int newVal = cur - 1;
              await p.setInt(k, newVal);
              onUIUpdate(newVal);
              _debouncedUpdate();
            },
          ),
          Text(
            '$cur',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () async {
              final p = await SharedPreferences.getInstance();
              int newVal = cur + 1;
              await p.setInt(k, newVal);
              onUIUpdate(newVal);
              _debouncedUpdate();
            },
          ),
        ],
      ),
    ],
  );

  Widget _adhanModeSelectorItem() {
    final modes = [
      {
        'key': 'silent',
        'label': 'صامت',
        'icon': Icons.volume_off_rounded,
        'color': Colors.white,
      },
      {
        'key': 'vibration',
        'label': 'اهتزاز',
        'icon': Icons.vibration_rounded,
        'color': Colors.white,
      },
      {
        'key': 'sound',
        'label': 'يعمل',
        'icon': Icons.volume_up_rounded,
        'color': Colors.white,
      },
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'وضع صوت الأذان',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: modes.map((m) {
              final isSelected = _localAdhanMode == m['key'];
              return Expanded(
                child: GestureDetector(
                  onTap: () async {
                    setState(() => _localAdhanMode = m['key'] as String);
                    final p = await SharedPreferences.getInstance();
                    await p.setString('adhanMode', m['key'] as String);
                    widget.onUpdate();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(                    color: isSelected
                        ? Colors.white.withOpacity(0.28)
                        : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.08),
                        width: isSelected ? 1.8 : 0.8,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          m['icon'] as IconData,
                          color: isSelected
                              ? Colors.white
                              : Colors.white60,
                          size: 16,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isSelected
                              ? '✓ ${m['label']}'
                              : m['label'] as String,
                          style: GoogleFonts.cairo(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 9,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _volumeSliderItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
                child: const Icon(
                  Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'التحكم في مستوى الصوت',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.volume_mute_rounded, color: Colors.white38, size: 16),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: const Color(
                      0xFFCE93D8,
                    ).withOpacity(0.2),
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withOpacity(0.12),
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                  ),
                  child: Slider(
                    value: _localVolume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    onChanged: (v) async {
                      setState(() => _localVolume = v);
                      await AdhanAudioService().setVolume(v);
                      final p = await SharedPreferences.getInstance();
                      await p.setDouble('adhanVolume', v);
                    },
                  ),
                ),
              ),
              Icon(Icons.volume_up_rounded, color: Colors.white38, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeFormatSelectorItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'نظام عرض الوقت',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTimeFormatOption('نظام 12 ساعة', false),
              const SizedBox(width: 12),
              _buildTimeFormatOption('نظام 24 ساعة', true),
            ],
          ),
        ],
      ),
    );
  }

  /// محدد مدة ظهور اللوقو (3 / 4 / 5 ثوانٍ)
  Widget _splashDurationSelectorItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'مدة ظهور اللوقو',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [3, 4, 5].map((seconds) {
              final isSelected = _localSplashDuration == seconds;
              return Expanded(
                child: GestureDetector(
                  onTap: () async {
                    setState(() => _localSplashDuration = seconds);
                    final p = await SharedPreferences.getInstance();
                    await p.setInt('splashDuration', seconds);
                    widget.onUpdate();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.15)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white.withOpacity(0.8)
                            : Colors.white.withOpacity(0.08),
                        width: isSelected ? 1.2 : 0.8,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$seconds ثوانٍ',
                        style: GoogleFonts.cairo(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 9,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFormatOption(String label, bool value) {
    final isSelected = _localIs24H == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _localIs24H = value);
          _saveBool('is24H', value);
          widget.onToggle24H(value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.15)
                : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withOpacity(0.8)
                  : Colors.white.withOpacity(0.08),
              width: isSelected ? 1.2 : 0.8,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.cairo(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getThemeName(String mode) {
    // يُطبَّع أولاً: أي قيمة مجهولة/قديمة تُعرض في صورة الوضع الفعّال («أسود»)
    // فلا يظهر للمستخدم وضع غير الذي يراه على الشاشة.
    switch (GlassPalette.normalizeThemeMode(mode)) {
      case 'black':
        return 'أسود';
      case 'royal_purple':
        return 'بنفسجي ملكي';
      case 'royal_purple_light':
        return 'ليلكي هادئ';
      case 'royal_blue':
        return 'كحلي بارد';
      case 'navy':
        return 'كحلي ملكي';
      case 'dark_blue':
        return 'أزرق داكن';
      case 'deep_violet':
        return 'بنفسجي غامق (#3C215E)';
      case 'deep_indigo':
        return 'نيلي عميق (#370F94)';
      case 'system':
        return 'تلقائي (النظام)';
      default:
        return 'أسود';
    }
  }
}

class ChatGptLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 4;

    for (int i = 0; i < 6; i++) {
      final angle = i * (math.pi / 3);
      final offset = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawCircle(offset, radius * 0.9, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// الاسم العربي للمؤذّن من مفتاح الإعداد — مصدر واحد.
///
/// يستخدمه صف «المؤذن» في قسم الأذان والصوت **و**قائمة أدوات التشخيص المخفية،
/// فلا يختلف اسم المؤذن بين موضعين (كان مكرراً كتابةً في مكانين).
String _adhanSoundLabel(String sound) {
  switch (sound) {
    case 'minshawi':
      return 'محمد الصديق المنشاوي';
    case 'makkah':
    case 'alharm_almakke':
      return 'أذان الحرم المكي';
    case 'sherif_mostafa':
    case 'sherif':
      return 'شريف مصطفى';
    case 'hamd_deghrer':
      return 'حمد دغرير';
    case 'mohamed_dokale':
      return 'محمد الدوكالي';
    case 'abdulbasit':
    case 'abdulbaset':
    default:
      return 'عبد الباسط عبد الصمد';
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  أدوات التشخيص المخفية — الإشعارات والأذان.
///
///  لا يصل إليها المستخدم العادي: تُفتح بـ**ضغط مطوّل** على عنوان هيدر شاشة
///  الإعدادات. كل ما فيها تجارب فورية وحالة خدمات النظام الحيّة، حتى يتحقق
///  المطوّر من الإشعار والأذان على الجهاز بلا انتظار وقت الصلاة وبلا أن يبقى
///  في الواجهة أي زر تشخيص يشغل المستخدم.
/// ─────────────────────────────────────────────────────────────────────────────
class _DiagnosticsSheet extends StatefulWidget {
  const _DiagnosticsSheet({
    required this.sound,
    required this.onRunFullDiagnostics,
  });

  /// مفتاح المؤذن المختار حالياً — تُشغَّل تجربة الأذان بصوته.
  final String sound;

  /// فتح فحص الجاهزية الشامل (نفس فحص قسم «شاشة إيقاف الأذان»).
  final VoidCallback onRunFullDiagnostics;

  @override
  State<_DiagnosticsSheet> createState() => _DiagnosticsSheetState();
}

class _DiagnosticsSheetState extends State<_DiagnosticsSheet> {
  bool? _nativeRunning; // null = جارٍ الفحص
  int? _pendingCount; // null = جارٍ الفحص
  bool _busy = false; // يمنع تشغيل تجربتين معاً

  @override
  void initState() {
    super.initState();
    _refreshSystemState();
  }

  /// يقرأ حالتين من النظام: خدمة الأذان النيتف، وعدد الإشعارات المجدولة.
  Future<void> _refreshSystemState() async {
    final running = await AdhanAudioService.isNativeServiceRunning();
    final pending = await NotificationService().pendingNotificationsCount();
    if (!mounted) return;
    setState(() {
      _nativeRunning = running;
      _pendingCount = pending;
    });
  }

  /// ينفّذ تجربة واحدة: يمنع الضغط المزدوج، يلتقط أخطاء المنصة، ثم يعيد قراءة
  /// الحالة لأن معظم التجارب تغيّرها (تشغّل أذاناً أو توقفه أو تُطلق إشعاراً).
  ///
  /// الإجراء يُعيد **نص النتيجة** بدلاً من إظهاره بنفسه: فيبقى استخدام
  /// `context` في هذه الدالة بعد الـ`await` داخل حماية [mounted] فقط.
  Future<void> _run(
    Future<String?> Function() action, {
    GlassNoticeKind kind = GlassNoticeKind.info,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);

    String? message;
    bool failed = false;
    try {
      message = await action();
    } catch (e) {
      message = 'تعذّر تنفيذ التجربة: $e';
      failed = true;
    }

    if (!mounted) return;
    setState(() => _busy = false);
    _refreshSystemState();
    if (message != null) {
      showGlassSnack(
        context,
        message,
        kind: failed ? GlassNoticeKind.danger : kind,
      );
    }
  }

  Widget _sectionTitle(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
    child: Text(
      label,
      style: GoogleFonts.amiri(
        color: GlassPalette.gold,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _row({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? accent,
    Widget? trailing,
  }) => GlassListTile(
    icon: icon,
    title: title,
    subtitle: subtitle,
    onTap: onTap,
    accent: accent,
    trailing: trailing,
    dense: true,
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  );

  Widget _refreshTrailing() => IconButton(
    icon: const Icon(Icons.refresh_rounded, color: GlassPalette.gold, size: 18),
    tooltip: 'تحديث الحالة',
    onPressed: _refreshSystemState,
  );

  @override
  Widget build(BuildContext context) {
    final runningLabel = _nativeRunning == null
        ? 'جارٍ الفحص…'
        : (_nativeRunning! ? 'يعمل حالياً ✅' : 'متوقفة ❌');
    final pendingLabel = _pendingCount == null
        ? 'جارٍ الفحص…'
        : '$_pendingCount إشعاراً في قائمة النظام';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            // مقبض السحب — نفس نمط القوائم السفلية في التطبيق
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 8, 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: GlassPalette.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: GlassPalette.gold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.build_circle_rounded,
                      color: GlassPalette.gold,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أدوات تشخيص الإشعارات والأذان',
                          style: GoogleFonts.amiri(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'قائمة مخفية — ضغط مطوّل على عنوان الشاشة',
                          style: GoogleFonts.amiri(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.10), height: 1),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.72,
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 14),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // ── الإشعارات ──────────────────────────────────────
                    _sectionTitle('الإشعارات'),
                    _row(
                      icon: Icons.notifications_none_rounded,
                      title: 'إشعار صلاة تجريبي',
                      subtitle:
                          'دورة على المواقيت الست — كل ضغطة تُطلق الوقت التالي',
                      onTap: () => _run(() async {
                        final name = await NotificationService()
                            .showTestPrayerNotification();
                        return 'تم إطلاق إشعار صلاة $name — افتح شريط الإشعارات.';
                      }),
                    ),
                    _row(
                      icon: Icons.schedule_rounded,
                      title: 'الإشعارات المجدولة في النظام',
                      subtitle: pendingLabel,
                      trailing: _refreshTrailing(),
                      onTap: _refreshSystemState,
                    ),
                    _row(
                      icon: Icons.notifications_active_rounded,
                      title: 'طلب إذن الإشعارات',
                      subtitle: 'يفتح نافذة إذن النظام إن كانت مرفوضة',
                      onTap: () => _run(() async {
                        await NotificationService().requestPermissions();
                        return 'طُلب إذن الإشعارات — راجع نافذة النظام.';
                      }),
                    ),

                    // ── الأذان ────────────────────────────────────────
                    _sectionTitle('الأذان'),
                    _row(
                      icon: Icons.record_voice_over_rounded,
                      title: 'أذان تجريبي فوري',
                      subtitle:
                          'بصوت ${_adhanSoundLabel(widget.sound)} — بلا إعلان صوتي مسبق',
                      onTap: () => _run(() async {
                        await AdhanAudioService().playAdhan(
                          widget.sound,
                          prayerName: 'تجربة',
                          ignoreMode: true, // تعمل التجربة حتى في الوضع الصامت
                          skipAnnouncement: true, // بلا إعلان «حان الآن…»
                        );
                        return 'بدأ تشغيل الأذان التجريبي — بصوت ${_adhanSoundLabel(widget.sound)}.';
                      }),
                    ),
                    _row(
                      icon: Icons.self_improvement_rounded,
                      title: 'دعاء ما بعد الأذان',
                      subtitle: 'يُشغّل الدعاء مباشرةً للاستماع',
                      onTap: () => _run(() async {
                        await AdhanAudioService().playDua();
                        return 'يُشغّل دعاء ما بعد الأذان الآن.';
                      }),
                    ),
                    _row(
                      icon: Icons.sensors_rounded,
                      title: 'حالة خدمة الأذان في الخلفية',
                      subtitle: runningLabel,
                      accent: _nativeRunning == false
                          ? GlassPalette.danger
                          : GlassPalette.success,
                      trailing: _refreshTrailing(),
                      onTap: _refreshSystemState,
                    ),
                    _row(
                      icon: Icons.stop_circle_rounded,
                      title: 'إيقاف الأذان النشط',
                      subtitle: 'يوقف الصوت والخدمة في الخلفية فوراً',
                      accent: GlassPalette.danger,
                      onTap: () => _run(
                        () async {
                          await NotificationService().stopActiveAdhan();
                          await AdhanAudioService().stop();
                          return 'تم إيقاف الأذان النشط.';
                        },
                        kind: GlassNoticeKind.success,
                      ),
                    ),

                    // ── تشخيص الجهاز ─────────────────────────────────
                    _sectionTitle('تشخيص الجهاز'),
                    _row(
                      icon: Icons.health_and_safety_rounded,
                      title: 'فحص الإشعارات والأذونات الشامل',
                      subtitle:
                          'تنبيهات، شاشة كاملة، فوق التطبيقات، البطارية، وضع الأذان',
                      onTap: () {
                        // نُغلق القائمة أولاً بـ context القائمة نفسها، ثم يظهر
                        // الفحص فوق شاشة الإعدادات (ولو أغلقناها لخرجنا للرئيسية)
                        Navigator.pop(context);
                        widget.onRunFullDiagnostics();
                      },
                    ),
                    _row(
                      icon: Icons.fingerprint_rounded,
                      title: 'بصمة بطاقة الإشعار',
                      subtitle: kNotificationCardStamp,
                      accent: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
