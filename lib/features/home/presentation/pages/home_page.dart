import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:just_audio/just_audio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../main.dart';
import '../../../../notification_service.dart';
import '../../../../advanced_reminders.dart';
import '../../../../remote_messaging_service.dart';
import '../../../../adhan_audio_service.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import '../../../../voice_announcement_service.dart';
import '../../../../core/data/prayer_api_service.dart';
import '../../../../core/database/libyan_prayer_database.dart';


import '../widgets/prayer_times_screen.dart';
import '../../../qibla/presentation/pages/qibla_screen.dart';
import '../../../library/presentation/pages/library_screen.dart';
import '../../../settings/presentation/pages/settings_screen.dart';
import '../../../about/presentation/pages/about_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../quran/presentation/bloc/quran_audio_bloc.dart';
import '../../../../core/services/screen_wake_service.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_nav_icon.dart';
import '../../../../core/config/text_scale_boost.dart';
import '../../../../core/theme/glass_theme.dart';


class MainNavigationScreen extends StatefulWidget {
  final VoidCallback onThemeChanged;
  final int initialIndex;
  const MainNavigationScreen({super.key, required this.onThemeChanged, this.initialIndex = 0});

  static CalculationParameters getCalculationParameters(String method, String madhab, {double? fajrAngleOverride, double? ishaAngleOverride}) {
    CalculationParameters params;
    if (method == 'ليبيا (الأوقاف)') {
      // الزوايا ودقائق الاحتياط المعتمدة رسمياً لمدن ليبيا
      final fajr = fajrAngleOverride ?? 18.2;
      final isha = ishaAngleOverride ?? 18.3;
      params = CalculationParameters(fajrAngle: fajr, ishaAngle: isha);
      params.ishaInterval = 0;
      params.adjustments.fajr = 0;    // 0 دقيقة (الزاوية معايرة بدقة متناهية لكل مدينة)
      params.adjustments.dhuhr = 4;   // +4 دقائق احتساب زوال الأوقاف المعتمد
      params.adjustments.asr = 0;     // 0 دقيقة مطابقة تامة
      params.adjustments.maghrib = 4; // +4 دقائق احتساب غروب الأوقاف المعتمد
      params.adjustments.isha = 0;    // 0 دقيقة مطابقة تامة
    } else if (method == 'أم القرى') {
      params = CalculationMethod.umm_al_qura.getParameters();
    } else if (method == 'رابطة العالم الإسلامي') {
      params = CalculationMethod.muslim_world_league.getParameters();
    } else if (method == 'الهيئة المصرية') {
      params = CalculationMethod.egyptian.getParameters();
    } else if (method == 'جامعة العلوم الإسلامية (كراتشي)') {
      params = CalculationMethod.karachi.getParameters();
    } else if (method == 'الاتحاد الإسلامي (ISNA)') {
      params = CalculationMethod.north_america.getParameters();
    } else if (method == 'دبي') {
      params = CalculationMethod.dubai.getParameters();
    } else if (method == 'الكويت') {
      params = CalculationMethod.kuwait.getParameters();
    } else if (method == 'قطر') {
      params = CalculationMethod.qatar.getParameters();
    } else {
      params = CalculationParameters(fajrAngle: 19.5, ishaAngle: 18.3);
    }
    
    // تطبيق زوايا التعديل اليدوي فقط إذا كانت طريقة ليبيا (الأوقاف)
    if (method == 'ليبيا (الأوقاف)') {
      if (fajrAngleOverride != null) params.fajrAngle = fajrAngleOverride;
      if (ishaAngleOverride != null) params.ishaAngle = ishaAngleOverride;
    }
    
    params.madhab = (madhab == 'hanafi' || madhab == 'الحنفي') ? Madhab.hanafi : Madhab.shafi;
    return params;
  }

  // الزوايا الرسمية المعتمدة لجميع المدن الليبية من قاعدة بيانات الأوقاف
  static Map<String, List<double>> get cityAngles =>
      LibyanPrayerDatabase.officialCityAngles;

  /// الزوايا الرسمية الموصى بها لمدينة معينة من قاعدة بيانات مؤذن ليبيا
  static List<double> getCityAngles(String city) =>
      LibyanPrayerDatabase.getCityAngles(city);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  static const double DEFAULT_LATITUDE = 32.1167;
  static const double DEFAULT_LONGITUDE = 20.0667;
  static const String DEFAULT_CITY = 'بنغازي';

  String _toWestern(String s) => s
      .replaceAll('٠', '0')
      .replaceAll('١', '1')
      .replaceAll('٢', '2')
      .replaceAll('٣', '3')
      .replaceAll('٤', '4')
      .replaceAll('٥', '5')
      .replaceAll('٦', '6')
      .replaceAll('٧', '7')
      .replaceAll('٨', '8')
      .replaceAll('٩', '9');
  
  bool _isInitialized = false;
  int _selectedIndex = 0;
  bool _is24H = false, _notif = true;
  String _sound = 'abdulbaset', _city = DEFAULT_CITY, _method = 'ليبيا (الأوقاف)', _themeModeStr = 'black';
  String _adhanMode = 'sound', _userName = '', _madhab = 'maliki';
  double _fajrAngle = 18.1;
  double _ishaAngle = 18.3;
  bool _useCustomAngles = false;
  String _lastAnglesCity = ''; // يتتبع آخر مدينة طُبقت زواياها (لتحديد تغيير المدينة)
  bool _usePrayerApi = false;
  int _prayerApiMethod = 99; // ليبيا - زوايا مخصصة (فجر 18.4° / عشاء 18.2°)

  Map<String, DateTime>? _apiPrayerTimes;
  Map<String, DateTime>? _dailyPrayerTimes;

  bool _isAdhanWindow = false;
  bool _isForegroundAdhan = false;
  String _currentAdhanPrayer = '';
  int _fOff = 0, _dOff = 0, _aOff = 0, _mOff = 0, _iOff = 0, _sOff = 0, _hijriOffset = 0;
  bool _duaEnabled = true;
  bool _showGreeting = true;
  bool _askNameOnStart = true;
  int _duaOffsetMinutes = 5;
  bool _remBeforeAdhan = true;
  int _beforeAdhanOffset = 5;
  bool _remAfterAdhan = true;
  int _afterAdhanOffset = 10;
  PrayerTimes? _pt;

  Timer? _clockTimer;
  Timer? _adhanCheckTimer;
  Timer? _scheduleDebounce;
  String? _lastPlayedAdhanKey;
  String? _lastPlayedDuaKey;
  DateTime? _lastAdhanPlayedAt; // منع التشغيل المزدوج مع الإشعار
  String _activePrayerName = 'العشاء'; // الصلاة النشطة حالياً — تُلوَّن أيقونات التاسك بار بلونها
  
  bool _isManualMode = false;
  bool _tapToStopAdhanEnabled = true;
  final TextEditingController _latCtrl = TextEditingController();
  final TextEditingController _longCtrl = TextEditingController();

  final Map<String, Coordinates> _cities =
      LibyanPrayerDatabase.libyanCityCoordinates;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = widget.initialIndex;
    

    
    // تهيئة استماع الأذان من الخلفية
    AdhanAudioService().init();
    AdhanAudioService().isPlayingNotifier.addListener(_onAdhanStateChanged);

    _load(isInitial: true);
    _fetchRemoteConfig(); // سحب النصوص والأدعية من الإنترنت عند التشغيل
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // جلب الإعدادات من الخادم بصمت في الخلفية
      await RemoteMessagingService.checkRemoteConfig(context);
      // التحقق من الموقع تلقائياً عند فتح البرنامج لمرة واحدة
      final p = await SharedPreferences.getInstance();
      final lastAutoDetect = p.getString('lastAutoDetectDate') ?? '';
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      if (lastAutoDetect != today && !_isManualMode) {
        // عدم فتح نافذة صلاحية الموقع تلقائياً — كل الصلاحيات تُطلب من شاشة
        // التفعيل الموحّدة فقط، وهنا نتحقق بصمت دون إظهار أي نافذة نظام
        final autoPerm = await Geolocator.checkPermission();
        if (autoPerm == LocationPermission.whileInUse ||
            autoPerm == LocationPermission.always) {
          await _autoDetectCity(showErrors: false);
          await p.setString('lastAutoDetectDate', today);
        }
        _update();
      }

      // رسالة «السلام عليكم» عند فتح التطبيق — تُعرض مرة واحدة لكل إعداد جديد.
      // آخر خطوة في الإقلاع حتى لا يُنتظر إغلاق الكارد قبل باقي التهيئة.
      await _showGreetingIfEnabled();

      // نافذة التحديث (إن كان المنشور على سوباباز أحدث من المثبَّت):
      // إعادة محاولة قصيرة حتى تصير الواجهة جاهزة — والبصمة لا تُحرق بلا عرض.
      await _showUpdateIfAvailable();
    });

    _adhanCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkAdhanTime();
      _syncActivePrayerColor();
    });
  }

  /// تحديد اسم الصلاة النشطة (آخر صلاة مضى وقتها) — لتلوين أيقونات التاسك بار بنفس لونها
  String _getActivePrayerName() {
    final now = DateTime.now();
    final activePrayers = <String, DateTime>{};
    if (_usePrayerApi && _apiPrayerTimes != null && _apiPrayerTimes!.isNotEmpty) {
      activePrayers.addAll(_apiPrayerTimes!);
    } else if (_dailyPrayerTimes != null && _dailyPrayerTimes!.isNotEmpty) {
      activePrayers.addAll(_dailyPrayerTimes!);
    } else if (_pt != null) {
      activePrayers['الفجر'] = _pt!.fajr.add(Duration(minutes: _fOff));
      activePrayers['الظهر'] = _pt!.dhuhr.add(Duration(minutes: _dOff));
      activePrayers['العصر'] = _pt!.asr.add(Duration(minutes: _aOff));
      activePrayers['المغرب'] = _pt!.maghrib.add(Duration(minutes: _mOff));
      activePrayers['العشاء'] = _pt!.isha.add(Duration(minutes: _iOff));
    }
    if (activePrayers.isEmpty) return 'العشاء';

    final sortedPrayers = [
      {'name': 'الفجر', 'time': activePrayers['الفجر']!},
      {'name': 'الظهر', 'time': activePrayers['الظهر']!},
      {'name': 'العصر', 'time': activePrayers['العصر']!},
      {'name': 'المغرب', 'time': activePrayers['المغرب']!},
      {'name': 'العشاء', 'time': activePrayers['العشاء']!},
    ];

    for (int i = sortedPrayers.length - 1; i >= 0; i--) {
      if (now.isAfter(sortedPrayers[i]['time'] as DateTime)) {
        return sortedPrayers[i]['name'] as String;
      }
    }
    return 'العشاء'; // إذا كان قبل الفجر
  }

  /// مزامنة لون أيقونات التاسك بار مع الصلاة النشطة — يُستدعى كل ثانية
  void _syncActivePrayerColor() {
    if (!mounted) return;
    final name = _getActivePrayerName();
    // تُحفظ عالمياً أيضاً حتى تلتزم بها الشاشات الفرعية عند تغيّر الصلاة
    GlassRuntime.activePrayerName = name;
    if (name != _activePrayerName) {
      setState(() => _activePrayerName = name);
    }
  }

  void _onAdhanStateChanged() {
    if (mounted) {
      if (!AdhanAudioService().isPlayingNotifier.value) {
        setState(() {
          _isAdhanWindow = false;
          _isForegroundAdhan = false;
        });
      }
    }
  }

  @override
  void dispose() {
    AdhanAudioService().isPlayingNotifier.removeListener(_onAdhanStateChanged);
    _clockTimer?.cancel();
    _adhanCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _stopAdhan() async {
    // حفظ المفتاح لمنع التكرار نهائياً بعد إيقافه
    if (_currentAdhanPrayer.isNotEmpty) {
      final now = DateTime.now();
      final key = '${_currentAdhanPrayer}_${now.day}_${now.month}_${now.year}';
      try {
        final prefs = await SharedPreferences.getInstance();
        final stoppedKeys = prefs.getStringList('stoppedAdhanKeys') ?? [];
        if (!stoppedKeys.contains(key)) {
          stoppedKeys.add(key);
          await prefs.setStringList('stoppedAdhanKeys', stoppedKeys);
        }
      } catch (_) {}
    }
    if (_lastPlayedAdhanKey != null && _lastPlayedAdhanKey!.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final stoppedKeys = prefs.getStringList('stoppedAdhanKeys') ?? [];
        if (!stoppedKeys.contains(_lastPlayedAdhanKey!)) {
          stoppedKeys.add(_lastPlayedAdhanKey!);
          await prefs.setStringList('stoppedAdhanKeys', stoppedKeys);
        }
      } catch (_) {}
    }

    // إيقاف جميع خدمات الصوت والإشعارات بشكل مطلق وبدون شروط
    AdhanAudioService().stop();
    NotificationService().stopActiveAdhan();
    VoiceAnnouncementService().stop();

    if (mounted) {
      setState(() {
        _isAdhanWindow = false;
        _isForegroundAdhan = false;
      });
    }

    try {
      final quranAudioBloc = context.read<QuranAudioBloc>();
      if (quranAudioBloc.state.playerState?.playing == true) {
        quranAudioBloc.add(StopAudioEvent());
      }
    } catch (_) {}
  }



  /// عرض نافذة "السلام عليكم" عند فتح التطبيق إذا كانت مفعّلة من لوحة التحكم
  /// (تُفوض إلى RemoteMessagingService.showGreetingIfNeeded لضمان عرض واحد فقط
  ///  حتى لو وصلت عبر Realtime أو من بدء التشغيل).
  ///
  /// إن كانت الواجهة غير جاهزة في أول إطار نُعيد المحاولة بضع مرات قصيرة
  /// حتى لا تبقى الرسالة بلا عرض.
  Future<void> _showGreetingIfEnabled({int attempt = 0}) async {
    try {
      if (!mounted) return;
      final bool done = await RemoteMessagingService.showGreetingIfNeeded();
      if (!done && attempt < 6) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!mounted) return;
        await _showGreetingIfEnabled(attempt: attempt + 1);
      }
    } catch (e) {
      debugPrint('Greeting error: $e');
    }
  }

  /// يُعيد المحاولة بضع مرات قصيرة لو لم تكن الواجهة جاهزة بعد، فلا يضيع
  /// تنبيه التحديث في الإطار الأول (نفس ما تفعله رسالة السلام).
  Future<void> _showUpdateIfAvailable({int attempt = 0}) async {
    try {
      if (!mounted) return;
      final bool handled = await RemoteMessagingService.showAvailableUpdate();
      if (!handled && attempt < 6) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!mounted) return;
        await _showUpdateIfAvailable(attempt: attempt + 1);
      }
    } catch (e) {
      debugPrint('Update notice error: $e');
    }
  }

  Future<void> _fetchRemoteConfig() async {
    try {
      final p = await SharedPreferences.getInstance();
      final config = await Supabase.instance.client
          .from('app_config')
          .select('dua_text, marquee_text')
          .eq('id', 1)
          .maybeSingle();

      if (config != null) {
        if (config['dua_text'] != null) await p.setString('remote_dua_text', config['dua_text']);
        if (config['marquee_text'] != null) await p.setString('remote_marquee_text', config['marquee_text']);
        if (mounted) setState(() {}); // تحديث الشاشة بعد السحب
      }
    } catch (_) {}
  }

  /// ─── فحص وقت الأذان ────────────────────────────────────────────────────────
  /// يعتمد دائماً على ساعة الجهاز الفعلية (DateTime.now())
  void _checkAdhanTime() async {
    if (!mounted) return;

    final now = DateTime.now();

    // ── إعادة تعيين مفتاح اليوم عند منتصف الليل ──
    final todayPrefix = '${now.day}_${now.month}_${now.year}';
    if (_lastPlayedAdhanKey != null && !_lastPlayedAdhanKey!.contains(todayPrefix)) {
      _lastPlayedAdhanKey = null;
      debugPrint('HomePage: Day changed, adhan key reset');
    }

    // ── احسب أوقات الصلاة من ساعة الجهاز الحقيقية الآن ────────────────────────
    Coordinates coord;
    if (_isManualMode && _latCtrl.text.isNotEmpty && _longCtrl.text.isNotEmpty) {
      coord = Coordinates(
        double.tryParse(_toWestern(_latCtrl.text)) ?? DEFAULT_LATITUDE,
        double.tryParse(_toWestern(_longCtrl.text)) ?? DEFAULT_LONGITUDE,
      );
    } else {
      coord = _cities[_city] ?? Coordinates(DEFAULT_LATITUDE, DEFAULT_LONGITUDE);
    }

    final params = MainNavigationScreen.getCalculationParameters(_method, _madhab,
      fajrAngleOverride: _fajrAngle, ishaAngleOverride: _ishaAngle);
    final livePt = PrayerTimes(coord, DateComponents.from(now), params);

    // استخدام أوقات API إذا كانت متاحة ومفعلة، وإلا قاعدة بيانات الأوقاف الرسمية، وإلا الحساب المحلي
    // ملاحظة: يتم استبعاد 'الشروق' من API لأنه ليس وقت أذان
    final prayers = <String, DateTime>{};
    if (_usePrayerApi && _apiPrayerTimes != null && _apiPrayerTimes!.isNotEmpty) {
      final apiTimes = Map<String, DateTime>.from(_apiPrayerTimes!);
      apiTimes.remove('الشروق'); // لا يوجد أذان للشروق
      prayers.addAll(apiTimes);
      // تطبيق الإزاحات اليدوية للمكتوبة
      if (prayers.containsKey('الفجر')) prayers['الفجر'] = prayers['الفجر']!.add(Duration(minutes: _fOff));
      if (prayers.containsKey('الظهر')) prayers['الظهر'] = prayers['الظهر']!.add(Duration(minutes: _dOff));
      if (prayers.containsKey('العصر')) prayers['العصر'] = prayers['العصر']!.add(Duration(minutes: _aOff));
      if (prayers.containsKey('المغرب')) prayers['المغرب'] = prayers['المغرب']!.add(Duration(minutes: _mOff));
      if (prayers.containsKey('العشاء')) prayers['العشاء'] = prayers['العشاء']!.add(Duration(minutes: _iOff));
    } else if (_dailyPrayerTimes != null && _dailyPrayerTimes!.isNotEmpty) {
      final dbTimes = Map<String, DateTime>.from(_dailyPrayerTimes!);
      dbTimes.remove('الشروق');
      prayers.addAll(dbTimes);
    } else {
      prayers['الفجر'] = livePt.fajr.add(Duration(minutes: _fOff));
      prayers['الظهر'] = livePt.dhuhr.add(Duration(minutes: _dOff));
      prayers['العصر'] = livePt.asr.add(Duration(minutes: _aOff));
      prayers['المغرب'] = livePt.maghrib.add(Duration(minutes: _mOff));
      prayers['العشاء'] = livePt.isha.add(Duration(minutes: _iOff));
    }

    // تم حذف الإعلان الصوتي الذي يسبق الأذان بناءً على طلب المستخدم

    String? currentKey;
    String? currentPrayerName;
    prayers.forEach((name, time) {
      final diffSecs = now.difference(time).inSeconds;
      // نافذة 60 ثانية بدقة عالية
      if (diffSecs >= 0 && diffSecs < 60) {
        currentKey = '${name}_${time.day}_${time.month}_${time.year}';
        currentPrayerName = name;
      }
    });

    if (currentKey != null) {
      final prefs = await SharedPreferences.getInstance();
      final stoppedKeys = prefs.getStringList('stoppedAdhanKeys') ?? [];
      final bool isManuallyStopped = stoppedKeys.contains(currentKey);

      if (_lastPlayedAdhanKey != currentKey && !isManuallyStopped) {
        _lastPlayedAdhanKey = currentKey;
        _currentAdhanPrayer = currentPrayerName ?? '';
        debugPrint('HomePage: 🕌 Adhan time reached: $currentKey.');

        // ── منع الأذان المزدوج: التحقق من الخدمة النيتف قبل التشغيل ──
        final nativeAlreadyPlaying = await AdhanAudioService.isNativeServiceRunning();

        if (nativeAlreadyPlaying || AdhanAudioService().isPlaying) {
          if (!_isForegroundAdhan) setState(() => _isForegroundAdhan = true);
          debugPrint('HomePage: Native service already playing, skipping Flutter playback');
        } else if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
          // تشغيل الأذان عند وجود التطبيق في المقدمة فقط إذا لم يسبق إيقافه يدوياً ولم تكن الخدمة تعمل حصراً
          AdhanAudioService().playAdhan(_sound, prayerName: _currentAdhanPrayer);
          if (!_isForegroundAdhan) setState(() => _isForegroundAdhan = true);
        }
      }
    } else {
      // إغلاق نافذة الأذان بعد مرور الوقت
      if (_isForegroundAdhan || _isAdhanWindow) {
        final prayersList = prayers.values.toList();
        bool anyActive = false;
        for (var p in prayersList) {
          if (now.difference(p).inSeconds >= 0 && now.difference(p).inSeconds < 300) {
            anyActive = true;
            break;
          }
        }
        if (!anyActive) {
          setState(() {
            _isForegroundAdhan = false;
            _isAdhanWindow = false;
          });
        }
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _update();
      // استعادة إبقاء الشاشة مضاءة بناءً على الإعدادات
      ScreenWakeService.applyCurrentState();
      // إعادة تهيئة قنوات Realtime عند العودة للمقدمة (لضمان وصول
      // رسالة السلام والإعدادات فوراً حتى بعد انقطاع الاتصال)
      RemoteMessagingService.initRealtimeListener();
      RemoteMessagingService.checkRemoteConfig(context);
    }
  }

  void _load({bool isInitial = false}) async {
    try {
      final p = await SharedPreferences.getInstance();

      // التأكد من تفعيل جميع الإشعارات والأذان كوضع افتراضي مفعل دائماً لضمان عملها
      await p.setBool('tapToStopAdhanEnabled', true);
      await p.setBool('duaEnabled', true);
      await p.setBool('notif', true);
      await p.setString('adhanMode', 'sound'); // إجبار وضع الصوت لضمان سماع الأذان
      await p.setBool('remBeforeAdhan', true);
      await p.setBool('remAfterAdhan', true);
      await p.setBool('vibrateOnAdhan', true);

      // ── تصفير تعديلات الدقائق اليدوية القديمة (إذا كانت موجودة من نسخة سابقة) ──
      // قاعدة بيانات الأوقاف الرسمية (v3.2.0) تتضمن التعديلات مدمجة في الحساب،
      // لذا نصفّر أي offsets يدوية قديمة محفوظة لتفادي التراكم
      const String _calibrationKey = 'awqaf_db_calibrated_v320';
      if (!(p.getBool(_calibrationKey) ?? false)) {
        await p.setInt('fOff', 0);
        await p.setInt('dOff', 0);
        await p.setInt('aOff', 0);
        await p.setInt('mOff', 0);
        await p.setInt('iOff', 0);
        await p.setBool(_calibrationKey, true);
        debugPrint('HomePage: تم تصفير التعديلات اليدوية القديمة (معايرة الأوقاف v3.2.0)');
      }

      final String savedName = p.getString('userName') ?? '';
      final String savedCity = p.getString('city') ?? DEFAULT_CITY;
      final bool isManual = p.getBool('isManualMode') ?? false;
      final String savedMethod = p.getString('method') ?? 'ليبيا (الأوقاف)';

      // ── تصحيح تلقائي: الزوايا المثالية لكل مدينة ──
      // الفجر: 19.5° (الطريقة المصرية الرسمية المعتمدة لدى مؤذن ليبيا)
      // العشاء: حسب المدينة (18.2° - 18.4°)
      final cityAngles = MainNavigationScreen.cityAngles[savedCity] ?? const [19.5, 18.3];
      double savedFajrAngle = p.getDouble('fajrAngle') ?? cityAngles[0];
      double savedIshaAngle = p.getDouble('ishaAngle') ?? cityAngles[1];
      if (savedMethod == 'ليبيا (الأوقاف)') {
        // عند تغيير المدينة (أو أول تشغيل) نطبق الزوايا المثالية لتلك المدينة
        // — لا نمس الزوايا المعدلة يدوياً داخل نفس المدينة
        final bool cityChanged = savedCity != _lastAnglesCity;
        if (cityChanged || !p.containsKey('fajrAngle') || !p.containsKey('ishaAngle')) {
          bool fajrNeedsFix = savedFajrAngle != cityAngles[0] ||
              savedFajrAngle < 15.0 || savedFajrAngle > 25.0;
          bool ishaNeedsFix = savedIshaAngle != cityAngles[1] ||
              savedIshaAngle < 15.0 || savedIshaAngle > 25.0;
          if (fajrNeedsFix) {
            savedFajrAngle = cityAngles[0];
            await p.setDouble('fajrAngle', savedFajrAngle);
            debugPrint('HomePage: تم تصحيح زاوية الفجر إلى المعتمدة في $savedCity (${cityAngles[0]}°)');
          }
          if (ishaNeedsFix) {
            savedIshaAngle = cityAngles[1];
            await p.setDouble('ishaAngle', savedIshaAngle);
            debugPrint('HomePage: تم تصحيح زاوية العشاء إلى المعتمدة في $savedCity (${cityAngles[1]}°)');
          }
        }
        _lastAnglesCity = savedCity;
        // تصحيح طريقة API المحفوظة إلى المعتمدة (99 = زوايا مخصصة حسب المدينة)
        final int savedApiMethod = p.getInt('prayerApiMethod') ?? 99;
        if (savedApiMethod == 5 || savedApiMethod == 1) {
          await p.setInt('prayerApiMethod', 99);
          debugPrint('HomePage: تم تصحيح طريقة API إلى المعتمدة (زوايا مخصصة حسب المدينة)');
        }
      }

      if (mounted) {
        setState(() {
          _userName = savedName;
          _is24H = p.getBool('is24H') ?? false;
          _city = savedCity;
          _sound = p.getString('sound') ?? 'abdulbaset';
          _method = savedMethod;
          _madhab = p.getString('madhab') ?? 'maliki';
          _notif = p.getBool('notif') ?? true;
          // يُطبَّع الوضع: أي قيمة مجهولة/قديمة → «أسود» بدل السقوط على
          // تدرّج الصلاة (الذي يظهر عنابياً أحمر عند المغرب).
          _themeModeStr = GlassPalette.normalizeThemeMode(
            p.getString('themeMode'),
          );
          _fOff = p.getInt('fOff') ?? 0;
          _dOff = p.getInt('dOff') ?? 0;
          _aOff = p.getInt('aOff') ?? 0;
          _mOff = p.getInt('mOff') ?? 0;
          _iOff = p.getInt('iOff') ?? 0;
          _sOff = p.getInt('sOff') ?? 0;
          _hijriOffset = p.getInt('hijriOffset') ?? 0;
          _adhanMode = p.getString('adhanMode') ?? 'sound';
          _tapToStopAdhanEnabled = p.getBool('tapToStopAdhanEnabled') ?? true;
          _duaEnabled = p.getBool('duaEnabled') ?? true;
          _showGreeting = p.getBool('showGreeting') ?? true;
          _duaOffsetMinutes = p.getInt('duaOffsetMinutes') ?? 5;
          _askNameOnStart = p.getBool('askNameOnStart') ?? true;
          _remBeforeAdhan = p.getBool('remBeforeAdhan') ?? true;
          _remAfterAdhan = p.getBool('remAfterAdhan') ?? true;
          _beforeAdhanOffset = p.getInt('beforeAdhanOffset') ?? 5;
          _afterAdhanOffset = p.getInt('afterAdhanOffset') ?? 10;
          _isManualMode = isManual;
          _latCtrl.text = _toWestern(p.getString('manualLat') ?? DEFAULT_LATITUDE.toString());
          _longCtrl.text = _toWestern(p.getString('manualLong') ?? DEFAULT_LONGITUDE.toString());
          _fajrAngle = savedFajrAngle;
          _ishaAngle = savedIshaAngle;
          _useCustomAngles = p.getBool('useCustomAngles') ?? false;
          _usePrayerApi = p.getBool('usePrayerApi') ?? false;
          _prayerApiMethod = p.getInt('prayerApiMethod') ?? 99;
        });
      }
    } catch (e) {
      debugPrint('HomePage _load Error: $e');
    }

    _update();
    try {
      widget.onThemeChanged();
    } catch (_) {}
  }

  bool _isInappropriate(String name) {
    final List<String> blacklist = [
      'حمار', 'كلب', 'قرد', 'خنزير', 'تيس', 'حيوان', 
      'حقير', 'واطي', 'سافل', 'غبي', 'حمارة', 'كلبة',
      'صهيون', 'يهود', 'شيطان', 'ابليس'
    ];
    
    final normalized = name.trim().toLowerCase();
    return blacklist.any((word) => normalized.contains(word));
  }

  void _update() async {
    try {
      Coordinates coord;
      if (_isManualMode && _latCtrl.text.isNotEmpty && _longCtrl.text.isNotEmpty) {
        coord = Coordinates(
          double.tryParse(_toWestern(_latCtrl.text)) ?? DEFAULT_LATITUDE,
          double.tryParse(_toWestern(_longCtrl.text)) ?? DEFAULT_LONGITUDE,
        );
      } else {
        coord = _cities[_city] ?? Coordinates(DEFAULT_LATITUDE, DEFAULT_LONGITUDE);
      }
      
      final cityAngles = MainNavigationScreen.getCityAngles(_city);
      final double? fajrOverride = _useCustomAngles ? _fajrAngle : cityAngles[0];
      final double? ishaOverride = _useCustomAngles ? _ishaAngle : cityAngles[1];
      final params = MainNavigationScreen.getCalculationParameters(_method, _madhab,
        fajrAngleOverride: fajrOverride, ishaAngleOverride: ishaOverride);

      final now = DateTime.now();
      final ptFallback = PrayerTimes(coord, DateComponents.from(now), params);

      // جلب المواقيت اليومية من قاعدة بيانات الأوقاف الرسمية المسبقة الحساب (JSON / SQLite)
      Map<String, DateTime>? dailyTimes;
      try {
        dailyTimes = await LibyanPrayerDatabase.getPrayerTimes(
          city: _city,
          date: now,
          offsets: [_fOff, _dOff, _aOff, _mOff, _iOff, _sOff],
          madhab: _madhab,
          customCoordinates: _isManualMode ? coord : null,
          fajrAngleOverride: fajrOverride,
          ishaAngleOverride: ishaOverride,
        );
      } catch (e) {
        debugPrint('HomePage getPrayerTimes DB error: $e');
      }

      if (mounted) {
        setState(() {
          _pt = ptFallback;
          _dailyPrayerTimes = dailyTimes;
          _isInitialized = true;
          _activePrayerName = _getActivePrayerName();
        });
      }
      _schedule();
      
      // إذا كان API مفعّلاً، حاول جلب الأوقات من API
      if (_usePrayerApi) {
        _fetchApiPrayerTimes(coord);
      }
    } catch (e) {
      debugPrint('HomePage _update Error: $e');
      if (mounted) {
        setState(() {
          _pt ??= PrayerTimes(Coordinates(DEFAULT_LATITUDE, DEFAULT_LONGITUDE), DateComponents.from(DateTime.now()), MainNavigationScreen.getCalculationParameters('ليبيا (الأوقاف)', 'maliki'));
          _isInitialized = true;
        });
      }
    }
  }
  
  Future<void> _fetchApiPrayerTimes(Coordinates coord) async {
    try {
      final cityAngles =
          MainNavigationScreen.cityAngles[_city] ?? const [18.0, 18.0];
      final double? fajrAngle = _useCustomAngles ? _fajrAngle : cityAngles[0];
      final double? ishaAngle = _useCustomAngles ? _ishaAngle : cityAngles[1];
      final apiTimes = await PrayerApiService.fetchPrayerTimes(
        latitude: coord.latitude,
        longitude: coord.longitude,
        method: _prayerApiMethod,
        fajrAngle: fajrAngle,
        ishaAngle: ishaAngle,
        madhab: _madhab == 'hanafi' ? 1 : 0,
      );
      if (apiTimes != null && mounted) {
        setState(() {
          _apiPrayerTimes = apiTimes;
          _activePrayerName = _getActivePrayerName();
        });
        debugPrint('HomePage: Prayer times fetched from API successfully');
      }
    } catch (e) {
      debugPrint('HomePage: API prayer times fetch failed, using local calculation: $e');
    }
  }

  void _schedule() async {
    _scheduleDebounce?.cancel();
    _scheduleDebounce = Timer(const Duration(milliseconds: 1000), () async {
      final ns = NotificationService();

      // نلغي الكل فقط إذا كان الصوت صامتاً وجميع الإشعارات مغلقة
      if (_adhanMode == 'silent' && !_notif && !_remBeforeAdhan && !_remAfterAdhan) {
        await ns.cancelAllNotifications();
        await AdhanAudioService().cancelAllAlarms();
        return;
      }

      // ✅ تنظيف كامل قبل إعادة الجدولة: إلغاء كل الإشعارات المجدولة والمنبهات
      //    النيتف من أي نسخة سابقة — يمنع ظهور إشعارين لنفس الصلاة أو الدعاء
      //    (إشعار قديم بجانب/فوق الجديد) بعد التحديث أو تغيير الإعدادات.
      await ns.cancelAllNotifications();
      await AdhanAudioService().cancelAllAlarms();

      final now = DateTime.now();
      // إعدادات الرسالة الصوتية المخصصة — تُشغَّل مع تذكيرات أذكار الصباح والمساء
      // (نفس مفتاحي التذكير في الإعدادات حتى لا تُشغَّل الرسالة الصوتية
      //  عندما يكون التذكير مطفأً)
      final voicePrefs = await SharedPreferences.getInstance();
      final voiceMsgMorningAzkar =
          voicePrefs.getBool('rem_morning_azkar') ?? true;
      final voiceMsgEveningAzkar =
          voicePrefs.getBool('rem_evening_azkar') ?? true;
      Coordinates coord;
      if (_isManualMode && _latCtrl.text.isNotEmpty && _longCtrl.text.isNotEmpty) {
        coord = Coordinates(
          double.tryParse(_toWestern(_latCtrl.text)) ?? DEFAULT_LATITUDE,
          double.tryParse(_toWestern(_longCtrl.text)) ?? DEFAULT_LONGITUDE,
        );
      } else {
        coord = _cities[_city] ?? Coordinates(DEFAULT_LATITUDE, DEFAULT_LONGITUDE);
      }

      final cityAngles = MainNavigationScreen.getCityAngles(_city);
      final double? fajrOverride = _useCustomAngles ? _fajrAngle : cityAngles[0];
      final double? ishaOverride = _useCustomAngles ? _ishaAngle : cityAngles[1];
      final params = MainNavigationScreen.getCalculationParameters(_method, _madhab,
        fajrAngleOverride: fajrOverride, ishaAngleOverride: ishaOverride);

      // ✅ جدولة 10 أيام قادمة باستخدام مواقيت قاعدة بيانات الأوقاف الرسمية ومعرفات ثابتة (Stable IDs)
      int scheduled = 0;
      final List<Map<String, dynamic>> alarmsToSchedule = [];

      for (int i = 0; i < 10; i++) {
        final date = now.add(Duration(days: i));
        final dayBase = (date.year % 100) * 10000 + (date.month * 100) + date.day;
        
        Map<String, DateTime> dayTimes;
        try {
          dayTimes = await LibyanPrayerDatabase.getPrayerTimes(
            city: _city,
            date: date,
            offsets: [_fOff, _dOff, _aOff, _mOff, _iOff, _sOff],
            madhab: _madhab,
            customCoordinates: _isManualMode ? coord : null,
            fajrAngleOverride: fajrOverride,
            ishaAngleOverride: ishaOverride,
          );
        } catch (_) {
          final pt = PrayerTimes(coord, DateComponents.from(date), params);
          dayTimes = {
            'الفجر': pt.fajr.add(Duration(minutes: _fOff)),
            'الشروق': pt.sunrise.add(Duration(minutes: _sOff)),
            'الظهر': pt.dhuhr.add(Duration(minutes: _dOff)),
            'العصر': pt.asr.add(Duration(minutes: _aOff)),
            'المغرب': pt.maghrib.add(Duration(minutes: _mOff)),
            'العشاء': pt.isha.add(Duration(minutes: _iOff)),
          };
        }

        final prayers = [
          {'idx': 1, 'name': 'الفجر',  'time': dayTimes['الفجر']!},
          {'idx': 2, 'name': 'الظهر',  'time': dayTimes['الظهر']!},
          {'idx': 3, 'name': 'العصر',  'time': dayTimes['العصر']!},
          {'idx': 4, 'name': 'المغرب', 'time': dayTimes['المغرب']!},
          {'idx': 5, 'name': 'العشاء', 'time': dayTimes['العشاء']!},
        ];

        for (var p in prayers) {
          final time = p['time'] as DateTime;
          // نُجدوِل الصلاة إذا لم يحن وقتها بعد، أو إذا انتهى أذانها للتو
          // لكن تذكير «مضى على الأذان» (بعدها بـ _afterAdhanOffset دقيقة)
          // لا يزال في المستقبل — حتى لا نفقد التذكير عند كل إعادة جدولة.
          final afterReminderTime = time.add(Duration(minutes: _afterAdhanOffset));
          if (time.isAfter(now) || afterReminderTime.isAfter(now)) {
            final prayerId = dayBase * 1000 + (p['idx'] as int);
            final prayerName = p['name'] as String;
            await ns.schedulePrayerNotification(
              id: prayerId,
              title: 'صلاة $prayerName',
              body: 'حان الآن موعد أذان صلاة $prayerName',
              prayerName: prayerName,
              scheduledTime: time,
              sound: _sound,
              adhanMode: _adhanMode,
              duaEnabled: _duaEnabled,
              duaOffsetMinutes: _duaOffsetMinutes,
              remBeforeAdhan: _remBeforeAdhan,
              beforeAdhanOffset: _beforeAdhanOffset,
              remAfterAdhan: _remAfterAdhan,
              afterAdhanOffset: _afterAdhanOffset,
              showVisual: _notif,
            );

            // المنبه النيتف للأذان يُجدوَل فقط إذا لم يحن وقت الأذان بعد
            // (الأذان الذي مضى شُغِّل بالفعل ولا يُعاد تشغيله)
            if (time.isAfter(now)) {
              alarmsToSchedule.add({
                'id': prayerId,
                'time': time.millisecondsSinceEpoch,
                'prayerName': prayerName,
                'soundName': _sound,
                'adhanMode': _adhanMode,
                'playDoaa': _duaEnabled,
              });
              
              // تذكير صلاة الجمعة قبل الأذان بـ 45 دقيقة (تشغيل صوت أصوات الطيور)
              if (date.weekday == DateTime.friday && (p['idx'] as int) == 2) {
                final fridayTime = time.subtract(const Duration(minutes: 45));
                if (fridayTime.isAfter(now)) {
                  alarmsToSchedule.add({
                    'id': prayerId + 145,
                    'time': fridayTime.millisecondsSinceEpoch,
                    'prayerName': 'صلاة الجمعة',
                    'soundName': 'sound_of_birds',
                    'adhanMode': 'sound',
                    'playDoaa': false,
                    'fridayReminder': true,
                  });
                }
              }
            }

            scheduled++;
          }
        }

        // ── الرسالة الصوتية المخصصة ──────────────────────────────────
        // تُشغَّل عند وقت أذكار الصباح (بعد الشروق بـ 30 دقيقة) ووقت
        // أذكار المساء (قبل المغرب بـ 30 دقيقة) — نفس توقيت تذكيرات
        // الأذكار في الإعدادات — صوت فقط بدون إشعارات.
        final sunriseTime = dayTimes['الشروق'];
        final maghribTime = dayTimes['المغرب'];
        final voiceMessages = <Map<String, dynamic>>[
          if (voiceMsgMorningAzkar && sunriseTime != null)
            {
              'idx': 6,
              'name': 'حان موعد اذكار الصباح لا تنسى ذكر الله',
              'time': sunriseTime.add(const Duration(minutes: 30)),
            },
          if (voiceMsgEveningAzkar && maghribTime != null)
            {
              'idx': 7,
              'name': 'حان موعد اذكار المساء لا تنسى ذكر الله',
              'time': maghribTime.subtract(const Duration(minutes: 30)),
            },
        ];
        for (var vm in voiceMessages) {
          final vmTime = vm['time'] as DateTime;
          if (vmTime.isAfter(now)) {
            final voiceId = dayBase * 1000 + (vm['idx'] as int);
            alarmsToSchedule.add({
              'id': voiceId,
              'time': vmTime.millisecondsSinceEpoch,
              'prayerName': vm['name'],
              'soundName': 'voice_message',
              'adhanMode': 'sound',
              'playDoaa': false,
              'voiceMessage': true,
            });
            scheduled++;
          }
        }
      }

      // جدولة المنبهات النيتف لضمان تشغيل الأذان بدقة عند قفل الجهاز أو إغلاق التطبيق
      await AdhanAudioService().scheduleAlarms(alarmsToSchedule);

      AdvancedReminders.scheduleAllReminders(coord, [_fOff, _dOff, _aOff, _mOff, _iOff, _sOff], city: _city);
      debugPrint('HomePage: Rescheduled $scheduled prayer notifications and native alarms for 10 days');
    });
  }

  Future<void> _autoDetectCity({bool showErrors = true}) async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // 1. تحقق من تفعيل خدمات الموقع
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted && showErrors) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خدمات الموقع غير مفعلة، يرجى تفعيلها')));
        }
        return;
      }

      // 2. تحقق من الصلاحيات
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted && showErrors) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض صلاحية الموقع')));
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted && showErrors) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('صلاحية الموقع مرفوضة نهائياً، يرجى تفعيلها من الإعدادات')));
        }
        return;
      }

      // 3. جلب الموقع الحالي
      if (mounted && showErrors) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('جاري تحديد الموقع...', textAlign: TextAlign.right, style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: GlassNoticeSpec.surface,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, 
          timeLimit: Duration(seconds: 15)
        )
      );

      String? closestCity;
      double minSafeDist = double.infinity;
      _cities.forEach((name, coord) {
        double dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, coord.latitude, coord.longitude);
        if (dist < minSafeDist) { minSafeDist = dist; closestCity = name; }
      });

      if (closestCity != null) {
        final p = await SharedPreferences.getInstance();
        await p.setString('city', closestCity!);
        await p.setBool('isManualMode', false);
        setState(() { _city = closestCity!; _isManualMode = false; });
        _update();
        if (mounted && showErrors) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تحديد موقعك: $_city', textAlign: TextAlign.right, style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: GlassNoticeSpec.surface,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('AutoDetectError: $e');
      if (mounted && showErrors) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تحديد الموقع: ${e.toString().contains('timeout') ? 'انتهى الوقت' : 'خطأ غير متوقع'}')));
      }
    }
  }

  /// ── تبويب الرئيسية (الشاشة الرئيسية) ────────────────────────────────────
  ///
  /// يلفّه [TextScaleBoost] الذي يضيف **1.5 بكسل** على حجم كل نص ورقم في
  /// الشاشة: التاريخ الهجري والميلادي، اسم المدينة، نصوص العدّاد التنازلي
  /// وأرقامه، أسماء الصلوات وأوقاتها، وكذلك نصوص الدعاء المتحرك.
  ///
  /// الغلاف في الجذر — لا في كل نص — فالتعديل المستقبلي على المقدار مطلب
  /// واحد في مكان واحد، ومقاييس الأيقونات تبقى كما هي بلا تغيير.
  ///
  /// ولا يشمل التكبير بقية التبويبات (المكتبة/القبلة/الإعدادات/عن التطبيق)
  /// لأنها شاشات مستقلة لكل منها مقاسه.
  Widget _buildHomeScreen(Coordinates activeCoord) => TextScaleBoost(
    child: PrayerTimesScreen(
      is24H: _is24H,
      pt: _pt,
      dailyPrayerTimes: _dailyPrayerTimes,
      apiPrayerTimes: _usePrayerApi ? _apiPrayerTimes : null,
      offsets: [_fOff, _dOff, _aOff, _mOff, _iOff, _sOff],
      city: _city,
      hijriOffset: _hijriOffset,
      coordinates: activeCoord,
      method: _method,
      madhab: _madhab,
      onAutoDetect: _autoDetectCity,
    ),
  );

  /// أيقونة تبويب في الشريط السفلي (التاسك بار).
  ///
  /// الشكل والحركة كلاهما في [GlassNavIcon] (الزر ثلاثي الأبعاد: جدار جانبي
  /// وسماكة ووجه زجاجي ومنظور وغوص عند الضغط) — وهنا يُمرَّر له الاختيار
  /// ولون الصلاة النشطة فقط، فلا تتكرّر مقاييس العمق في أي شاشة.
  Widget _buildNavItem(int index, IconData selectedIcon, IconData unselectedIcon) {
    return GlassNavIcon(
      selected: _selectedIndex == index,
      selectedIcon: selectedIcon,
      unselectedIcon: unselectedIcon,
      // لون الصلاة النشطة الحالي — تتلوّن أيقونات التاسك بار بهذا اللون
      accent: prayerIconColor(_getActivePrayerName()),
      // اللمس والاهتزاز يقعان داخل الزر نفسه (FeedBack واحد لا اثنان)
      onTap: () => setState(() => _selectedIndex = index),
    );
  }


  @override
  Widget build(BuildContext context) {

    // تحديث الصلاة التالية فقط عند الحاجة وليس كل ثانية
    final nextPrayer = _pt?.nextPrayer() ?? Prayer.none;
    
    // تدرج موحّد مع شاشة «عن التطبيق» — كلاهما يتبع وضع العرض المختار
    final gradient = AlMaathenTheme.appScreenGradient(_themeModeStr, nextPrayer: nextPrayer);
    // تُحفظ الحالة اللونية عالمياً لتلتزم بها كل الشاشات الفرعية تلقائياً
    GlassRuntime.themeMode = _themeModeStr;
    GlassRuntime.nextPrayer = nextPrayer;
    // اسم الصلاة النشطة — حتى تتبع كتابة الشاشات الفرعية (شاشة «عن التطبيق»)
    // لون الصلاة نفسه الذي تلوّن به أيقونات الشاشة الرئيسية
    GlassRuntime.activePrayerName = _getActivePrayerName();

    Coordinates activeCoord;
    if (_isManualMode && _latCtrl.text.isNotEmpty && _longCtrl.text.isNotEmpty) {
      activeCoord = Coordinates(double.tryParse(_latCtrl.text) ?? DEFAULT_LATITUDE, double.tryParse(_longCtrl.text) ?? DEFAULT_LONGITUDE);
    } else {
      activeCoord = _cities[_city] ?? Coordinates(DEFAULT_LATITUDE, DEFAULT_LONGITUDE);
    }

    return GestureDetector(
        // إيقاف الأذان بلمس الشاشة — يُفعَّل فقط إذا كان الأذان يعزف والخيار مفعَّل
        // ملاحظة: GestureDetector لا يلتقط أزرار الصوت الفعلية (هاردوير) إطلاقاً
        onTap: () {
          if (_tapToStopAdhanEnabled && AdhanAudioService().isPlaying) {
            _stopAdhan();
          }
        },
        behavior: HitTestBehavior.translucent,
        // ── الخلفية الأورورا النابضة: الأساس الذي يجعل كل الزجاج فوقه حيّاً ──
        child: AuroraBackground(
        colors: gradient,
        glowColors: AlMaathenTheme.glowFor(_themeModeStr, nextPrayer: nextPrayer),
        // الحركة وقوّة التوهّج تتبعان اختيار المستخدم من الإعدادات
        animated: GlassRuntime.motion,
        intensity: GlassRuntime.glowScale,
        child: PopScope(
          canPop: _selectedIndex == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_selectedIndex != 0) {
              setState(() => _selectedIndex = 0);
            }
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: !_isInitialized
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFDFBA6B)))
                : IndexedStack(
                              index: _selectedIndex,
                              children: [
                                _buildHomeScreen(activeCoord),
                          IslamicLibraryScreen(coordinates: activeCoord, offsets: [_fOff, _dOff, _aOff, _mOff, _iOff, _sOff], onBack: () => setState(() => _selectedIndex = 0)),
                          QiblaScreen(onBack: () => setState(() => _selectedIndex = 0)),
                          SettingsScreen(
                            is24H: _is24H,
                            sound: _sound,
                            city: _city,
                            method: _method,
                            notif: _notif,
                            themeMode: _themeModeStr,
                            userName: _userName,
                            offsets: [_fOff, _dOff, _aOff, _mOff, _iOff, _sOff],
                            hijriOffset: _hijriOffset,
                            duaEnabled: _duaEnabled,
                            duaOffsetMinutes: _duaOffsetMinutes,
                            cities: _cities,
                            isManualMode: _isManualMode,
                            initialLat: _latCtrl.text,
                            initialLong: _longCtrl.text,
                            showGreeting: _showGreeting,
                            askNameOnStart: _askNameOnStart,
                            tapToStopAdhanEnabled: _tapToStopAdhanEnabled,
                            onApplyManual: (lat, long) async {
                              final p = await SharedPreferences.getInstance();
                              final wLat = _toWestern(lat);
                              final wLong = _toWestern(long);
                              await p.setString('manualLat', wLat);
                              await p.setString('manualLong', wLong);
                              await p.setBool('isManualMode', true);
                              setState(() {
                                _latCtrl.text = wLat;
                                _longCtrl.text = wLong;
                                _isManualMode = true;
                              });
                              _update();
                            },
                            onToggleNotif: (v) {
                              setState(() => _notif = v);
                              _schedule();
                            },
                            onToggle24H: (v) {
                              setState(() => _is24H = v);
                            },
                            onNameChanged: (newName) {
                              setState(() => _userName = newName);
                            },
                            onAutoDetect: _autoDetectCity,
                            onUpdate: _load,
                            onBack: () => setState(() => _selectedIndex = 0),
                          ),
                                AboutAppScreen(onBack: () => setState(() => _selectedIndex = 0), userName: _userName, themeMode: _themeModeStr),
                              ],
                            ),
            bottomNavigationBar: ClipRRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    // ── شريط زجاجي شفاف بدل الأسود الصلب ──
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.11),
                        Colors.white.withValues(alpha: 0.045),
                        Colors.white.withValues(alpha: 0.02),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                    // ── التاسك بار **لا يتبع** ألوان أوقات الصلاة ──
                    // كان حدّه العلوي وتوهّجه بلون الصلاة الحالية فيتلون الشريط
                    // كله؛ الآن لونه ثابت كخلفية الواجهة الزجاجية، والأيقونات
                    // داخله وحدها تتلوّن بلون الصلاة (انظر _buildNavItem).
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 1.0,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      // Expanded: التبويبات تتوزّع على عرض الشاشة، فلا
                      // يزاحم شريط المهام الشاشات الضيقة (الوضع المنقسم)
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(child: _buildNavItem(0, Icons.access_time_filled, Icons.access_time)),
                          Expanded(child: _buildNavItem(1, Icons.menu_book, Icons.menu_book_outlined)),
                          Expanded(child: _buildNavItem(2, Icons.explore, Icons.explore_outlined)),
                          Expanded(child: _buildNavItem(3, Icons.settings, Icons.settings_outlined)),
                          Expanded(child: _buildNavItem(4, Icons.info_rounded, Icons.info_outline_rounded)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ), // نهاية AuroraBackground
    ); // نهاية GestureDetector
  }
}

// تم حذف كارد وبانر الأذان بناءً على طلب المستخدم (البقاء فقط على إشعار الإيقاف)
