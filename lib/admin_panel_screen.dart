import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muezzin_libya_app/core/config/app_version.dart';
import 'package:muezzin_libya_app/remote_messaging_service.dart';
import 'package:muezzin_libya_app/user_messaging_screen.dart';
import 'package:muezzin_libya_app/core/theme/glass_theme.dart';
import 'package:muezzin_libya_app/core/widgets/glass_scaffold.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  bool _isAuthenticated = false;
  final _passcodeCtrl = TextEditingController();
  // كلمتا السر المقبولتان: 1918 (الرئيسية) و1619 (من الإصدارات السابقة)
  static const _correctPasscodes = {"1918", "1619"};

  late TabController _tabs;

  // Update fields
  // الرقم الافتراضي = الإصدار المثبَّت من المصدر الواحد، فلا يبدأ المدير
  // من رقم قديم (كان 2.0.0) فينشر تحديثاً لا يراه أحد لأنه ليس أحدث.
  final _versionCtrl = TextEditingController(text: AppVersion.version);
  final _updateTitleCtrl = TextEditingController(text: "تحديث جديد متوفر!");
  final _updateMsgCtrl = TextEditingController(
    text: "تم إطلاق إصدار جديد يحتوي على ميزات هامة.",
  );
  final _updateUrlCtrl = TextEditingController(
    text: "https://example.com/download",
  );
  bool _forceUpdate = false;

  // الرقم السري الذي يفتح الغرفة (يُنشر إلى app_config.room_passcode)
  final _roomPasscodeCtrl = TextEditingController(text: '1959');

  // Broadcast fields
  final _broadcastIdCtrl = TextEditingController(
    text: "msg_${DateTime.now().millisecondsSinceEpoch}",
  );
  final _broadcastTitleCtrl = TextEditingController(text: "");
  final _broadcastMsgCtrl = TextEditingController(
    text: "تقبل الله طاعاتكم وصالح أعمالكم.",
  );
  final _broadcastBtnTextCtrl = TextEditingController(text: "حسنا");
  final _broadcastBtnUrlCtrl = TextEditingController();
  final _broadcastTargetUserIdCtrl = TextEditingController();

  // Dua fields
  bool _duaEnabled = true;
  int _duaOffset = 4;

  // Post-prayer dua settings
  bool _postPrayerDuaEnabled = true;
  int _postPrayerDuaOffset = 20;
  final _postPrayerDuaTextCtrl = TextEditingController();
  bool _postPrayerDuaLoop = false;
  final _duaMsgCtrl = TextEditingController(
    text: "اللهم اغفر لنا ولوالدينا وارحمهما كما ربيانا صغارا",
  );

  static const String _defaultAllahNames =
      "اللَّهُ • الرَّحْمَنُ • الرَّحِيمُ • الْمَلِكُ • الْقُدُّوسُ • السَّلَامُ • الْمُؤْمِنُ • الْمُهَيْمِنُ • الْعَزِيزُ • الْجَبَّارُ • الْمُتَكَبِّرُ • الْخَالِقُ • الْبَارِئُ • الْمُصَوِّرُ • الْغَفَّارُ • الْقَهَّارُ • الْوَهَّابُ • الرَّزَّاقُ • الْفَتَّاحُ • الْعَلِيمُ • الْقَابِضُ • الْبَاسِطُ • الْخَافِضُ • الرَّافِعُ • الْمُعِزُّ • الْمُذِلُّ • السَّمِيعُ • الْبَصِيرُ • الْحَكَمُ • الْعَدْلُ • اللَّطِيفُ • الْخَبِيرُ • الْحَلِيمُ • الْعَظِيمُ • الْغَفُورُ • الشَّكُورُ • الْعَلِيُّ • الْكَبِيرُ • الْحَفِيظُ • الْمُقِيتُ • الْحَسِيبُ • الْجَلِيلُ • الْكَرِيمُ • الرَّقِيبُ • الْمُجِيبُ • الْوَاسِعُ • الْحَكِيمُ • الْوَدُودُ • الْمَجِيدُ • الْبَاعِثُ • الشَّهِيدُ • الْحَقُّ • الْوَكِيلُ • الْقَوِيُّ • الْمَتِينُ • الْوَلِيُّ • الْحَمِيدُ • الْمُحْصِي • الْمُبْدِئُ • الْمُعِيدُ • الْمُحْيِي • الْمُمِيتُ • الْحَيُّ • الْقَيُّومُ • الْوَاجِدُ • الْمَاجِدُ • الْوَاحِدُ • الْأَحَدُ • الصَّمَدُ • الْقَادِرُ • الْمُقْتَدِرُ • الْمُقَدِّمُ • الْمُؤَخِّرُ • الْأَوَّلُ • الْآخِرُ • الظَّاهِرُ • الْبَاطِنُ • الْوَالِي • الْمُتَعَالِي • الْبَرُّ • التَّوَّابُ • الْمُنْتَقِمُ • الْعَفُوُّ • الرَّؤُوفُ • مَالِكُ الْمُلْكِ • ذُو الْجَلَالِ وَالْإِكْرَامِ • الْمُقْسِطُ • الْجَامِعُ • الْغَنِيُّ • الْمُغْنِي • الْمَانِعُ • الضَّارُّ • النَّافِعُ • النُّورُ • الْهَادِي • الْبَدِيعُ • الْبَاقِي • الْوَارِثُ • الرَّشِيدُ • الصَّبُورُ";
  /// أحدايث/رسائل الشريط العلوي في شاشة الإعدادات — **قائمة** تتقلّب في الهيدر:
  /// الأول هو «نص الهيدر» كما كان، وما بعده أحاديث إضافية. ولا تكون فارغة
  /// أبداً (حقل واحد على الأقل في اللوحة).
  final List<TextEditingController> _marqueeCtrls =
      <TextEditingController>[TextEditingController(text: _defaultAllahNames)];

  /// أول حديث = نص الهيدر المعتاد (كل مواضع اللوحة القديمة تقرأ منه).
  TextEditingController get _marqueeTextCtrl => _marqueeCtrls.first;

  /// **وقت ظهور** كل حديث في الهيدر قبل الانتقال إلى التالي (مللي ثانية).
  int _settingsMarqueeIntervalMs = SettingsMarqueeSettings.defaultIntervalMs;

  /// الأحاديث التي ستُنشر في الشريط العلوي (حديث لكل حقل، بلا فراغات ولا
  /// تكرار، وبسقف العدد والطول في [SettingsMarqueeSettings]).
  List<String> get _marqueeMessages => SettingsMarqueeSettings.normalizeMessages(
        _marqueeCtrls.map((TextEditingController c) => c.text).toList(),
      );

  /// يضع الأحاديث في حقول اللوحة (تُستعمل عند التحميل والاستعادة).
  ///
  /// يُعيد استخدام الحقول القائمة قدر الإمكان فلا تُستبدل الحقول تحت المستخدم.
  /// وقائمة فارغة = أسماء الله الحسنى المضمّنة.
  void _setMarqueeMessages(List<String> list) {
    final List<String> clean = SettingsMarqueeSettings.normalizeMessages(list);
    final List<String> effective =
        clean.isEmpty ? <String>[_defaultAllahNames] : clean;

    while (_marqueeCtrls.length < effective.length) {
      _marqueeCtrls.add(TextEditingController());
    }
    while (_marqueeCtrls.length > effective.length) {
      _marqueeCtrls.removeLast().dispose();
    }
    for (int i = 0; i < effective.length; i++) {
      _marqueeCtrls[i].text = effective[i];
    }
  }

  /// إضافة حقل حديث جديد (حتى سقف [SettingsMarqueeSettings.maxMessages]).
  void _addMarqueeHadith() {
    if (_marqueeCtrls.length >= SettingsMarqueeSettings.maxMessages) return;
    setState(() => _marqueeCtrls.add(TextEditingController()));
  }

  /// حذف حديث (يبقى حقل واحد على الأقل).
  void _removeMarqueeHadith(int index) {
    if (_marqueeCtrls.length <= 1) return;
    if (index < 0 || index >= _marqueeCtrls.length) return;
    setState(() => _marqueeCtrls.removeAt(index).dispose());
  }

  // Home Screen Animated Dua fields (النص المتحرك في الشاشة الرئيسية)
  final _homeDuaTextCtrl = TextEditingController();
  // اللون الافتراضي في اللوحة = «يتبع ألوان أوقات الصلاة»
  int _homeDuaColor = HomeMarqueeSettings.followPrayerColorsValue;
  bool _homeDuaEnabled = HomeMarqueeSettings.defaultEnabled;
  String _homeDuaFont = HomeMarqueeSettings.defaultFontFamily;
  int _homeDuaFontSize = HomeMarqueeSettings.defaultFontSize;
  int _homeDuaIntervalMs = HomeMarqueeSettings.defaultIntervalMs;
  bool _homeDuaBold = HomeMarqueeSettings.defaultBold;
  int _homeDuaAfterMinutes = HomeMarqueeSettings.defaultAfterMinutes;

  // تنسيق النص المتحرك في هيدر شاشة الإعدادات (تُحفظ في marquee_color ·
  // marquee_font · marquee_font_size وتقرأها شاشة الإعدادات فوراً)
  int _settingsMarqueeColor = SettingsMarqueeSettings.defaultColor;
  String _settingsMarqueeFont = SettingsMarqueeSettings.defaultFontFamily;
  int _settingsMarqueeFontSize = SettingsMarqueeSettings.defaultFontSize;

  // General Content Management fields (from Settings)
  final _duaUnderCounterCtrl = TextEditingController();
  int _duaUnderCounterColor = 0xFFDFBA6B;

  bool _isLoading = false;
  List<Map<String, dynamic>> _recentBroadcasts = [];
  Map<String, dynamic>? _currentConfig;

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _passcodeCtrl.dispose();
    _tabs.dispose();
    for (final TextEditingController c in _marqueeCtrls) {
      c.dispose();
    }
    _homeDuaTextCtrl.dispose();
    _duaUnderCounterCtrl.dispose();
    _postPrayerDuaTextCtrl.dispose();
    _broadcastTargetUserIdCtrl.dispose();
    _roomPasscodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFromSupabase() async {
    setState(() => _isLoading = true);
    try {
      // Load app_config
      final config = await _db
          .from('app_config')
          .select()
          .eq('id', 1)
          .maybeSingle();
      // إعدادات النص المتحرك المحفوظة على هذا الجهاز — تُستخدم للأعمدة
      // التي لا توجد بعد في جدول app_config (حتى لا تختلط الافتراضيات)
      final HomeMarqueeSettings localMarquee =
          await RemoteMessagingService.readHomeMarqueeSettings();
      final SettingsMarqueeSettings localSettingsMarquee =
          await RemoteMessagingService.readSettingsMarqueeSettings();
      if (config != null) {
        final d = Map<String, dynamic>.from(config);
        setState(() {
          _currentConfig = d;
          final String pub = (d['latest_version'] ?? '').toString().trim();
          // عمود فارغ أو غير موجود ⇒ لا نضع رقماً قديماً بل المثبَّت حالياً
          _versionCtrl.text = pub.isEmpty ? AppVersion.version : pub;
          _updateTitleCtrl.text = d['update_title'] ?? '';
          _updateMsgCtrl.text = d['update_message'] ?? '';
          _updateUrlCtrl.text = d['update_url'] ?? '';
          _forceUpdate = d['force_update'] == true;
          _duaEnabled = d['dua_enabled'] != false;
          _duaOffset = (d['dua_offset'] as int?) ?? 4;
          _duaMsgCtrl.text = d['dua_message'] ?? _duaMsgCtrl.text;
          // ── أحاديث الشريط العلوي: العمود الجديد (حديث/سطر) أولاً، ثم النص الواحد ──
          final List<String> remoteMarqueeMsgs =
              SettingsMarqueeSettings.parseMessages(
            (d['marquee_messages'] ?? '').toString(),
          );
          final String singleMarqueeText =
              (d['marquee_text'] ?? '').toString().trim();
          _setMarqueeMessages(remoteMarqueeMsgs.isNotEmpty
              ? remoteMarqueeMsgs
              : <String>[
                  singleMarqueeText.isEmpty
                      ? _defaultAllahNames
                      : singleMarqueeText,
                ]);
          // وقت الظهور: العمود الجديد إن وُجد، وإلا المحفوظ على هذا الجهاز
          final dynamic rawInterval = d['marquee_interval_ms'];
          _settingsMarqueeIntervalMs = d.containsKey('marquee_interval_ms')
              ? SettingsMarqueeSettings.clampInterval(rawInterval is num
                  ? rawInterval.round()
                  : int.tryParse('${rawInterval ?? ''}'))
              : localSettingsMarquee.intervalMs;
          _homeDuaTextCtrl.text = d['home_dua_text'] ?? localMarquee.text;
          _homeDuaColor =
              (d['home_dua_color'] as int?) ?? localMarquee.color;
          _homeDuaEnabled = d.containsKey('home_dua_enabled')
              ? d['home_dua_enabled'] == true
              : localMarquee.enabled;
          _homeDuaFont = d.containsKey('home_dua_font')
              ? HomeMarqueeSettings.normalizeFont(d['home_dua_font']?.toString())
              : localMarquee.fontFamily;
          _homeDuaFontSize = d.containsKey('home_dua_font_size')
              ? HomeMarqueeSettings.clampFontSize(
                  (d['home_dua_font_size'] as num?)?.round(),
                )
              : localMarquee.fontSize;
          _homeDuaIntervalMs = d.containsKey('home_dua_interval_ms')
              ? HomeMarqueeSettings.clampInterval(
                  (d['home_dua_interval_ms'] as num?)?.round(),
                )
              : localMarquee.intervalMs;
          _homeDuaBold = d.containsKey('home_dua_bold')
              ? d['home_dua_bold'] == true
              : localMarquee.bold;
          _homeDuaAfterMinutes = d.containsKey('home_dua_after_minutes')
              ? HomeMarqueeSettings.clampAfterMinutes(
                  (d['home_dua_after_minutes'] as num?)?.round(),
                )
              : localMarquee.afterMinutes;
          // ── تنسيق نص هيدر شاشة الإعدادات ──
          _settingsMarqueeColor =
              (d['marquee_color'] as int?) ?? localSettingsMarquee.color;
          _settingsMarqueeFont = d.containsKey('marquee_font')
              ? SettingsMarqueeSettings.normalizeFont(
                  d['marquee_font']?.toString(),
                )
              : localSettingsMarquee.fontFamily;
          _settingsMarqueeFontSize = d.containsKey('marquee_font_size')
              ? SettingsMarqueeSettings.clampFontSize(
                  (d['marquee_font_size'] as num?)?.round(),
                )
              : localSettingsMarquee.fontSize;
          _duaUnderCounterCtrl.text = d['dua_text'] ?? '';
          _duaUnderCounterColor = (d['dua_text_color'] as int?) ?? 0xFFDFBA6B;
          // ── دعاء ما بعد الأذان ──
          _postPrayerDuaEnabled = d['post_prayer_dua_enabled'] != false;
          _postPrayerDuaOffset = (d['post_prayer_dua_offset'] as int?) ?? 20;
          _postPrayerDuaTextCtrl.text = d['post_prayer_dua_text'] ?? '';
          _postPrayerDuaLoop = d['post_prayer_dua_loop'] == true;
          // ── الرقم السري للغرفة (فارغ/غير موجود → الرقم المضمَّن) ──
          final String remoteRoomCode = (d['room_passcode'] ?? '')
              .toString()
              .trim();
          _roomPasscodeCtrl.text = remoteRoomCode.isEmpty
              ? UserMessagingScreen.roomPasscode
              : remoteRoomCode;
        });
      } else {
        // لا يوجد صف إعدادات على السيرفر → تُعرض حالة هذا الجهاز
        setState(() {
          _homeDuaTextCtrl.text = localMarquee.text;
          _homeDuaColor = localMarquee.color;
          _homeDuaEnabled = localMarquee.enabled;
          _homeDuaFont = localMarquee.fontFamily;
          _homeDuaFontSize = localMarquee.fontSize;
          _homeDuaIntervalMs = localMarquee.intervalMs;
          _homeDuaBold = localMarquee.bold;
          _homeDuaAfterMinutes = localMarquee.afterMinutes;
          _settingsMarqueeColor = localSettingsMarquee.color;
          _settingsMarqueeFont = localSettingsMarquee.fontFamily;
          _settingsMarqueeFontSize = localSettingsMarquee.fontSize;
          _setMarqueeMessages(localSettingsMarquee.effectiveMessages);
          _settingsMarqueeIntervalMs = localSettingsMarquee.intervalMs;
        });
      }

      // Load recent broadcasts
      final broadcasts = await _db
          .from('broadcasts')
          .select()
          .order('created_at', ascending: false)
          .limit(20);
      setState(() {
        _recentBroadcasts = List<Map<String, dynamic>>.from(broadcasts);
      });
    } catch (e) {
      _showSnack('خطأ في تحميل البيانات: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _publishUpdate() async {
    setState(() => _isLoading = true);
    try {
      final success = await RemoteMessagingService.publishConfig(
        latestVersion: _versionCtrl.text.trim(),
        updateTitle: _updateTitleCtrl.text.trim(),
        updateMessage: _updateMsgCtrl.text.trim(),
        updateUrl: _updateUrlCtrl.text.trim(),
        forceUpdate: _forceUpdate,
        targetUserId: '',
        targetCity: '',
        remoteDuaEnabled: _duaEnabled,
        remoteDuaMessage: _duaMsgCtrl.text.trim(),
        remoteDuaOffset: _duaOffset,
        remotePostPrayerDuaEnabled: _postPrayerDuaEnabled,
        remotePostPrayerDuaOffset: _postPrayerDuaOffset,
        remotePostPrayerDuaText: _postPrayerDuaTextCtrl.text.trim(),
        remotePostPrayerDuaLoop: _postPrayerDuaLoop,
      );

      if (success) {
        final String published = _versionCtrl.text.trim();
        if (published.isNotEmpty && !AppVersion.isNewer(published)) {
          // تحذير صريح: أُرسلت الإعدادات لكن مستخدمي الإصدار المثبَّت
          // لن يرى أحدهم تنبيه تحديث، فلا يظن المدير أن التنبيه وصل.
          _showSnack(
            '✅ تم حفظ الإعدادات، لكن «$published» ليس أحدث من المثبَّت '
            '${AppVersion.version}: لن يظهر تنبيه تحديث للمستخدمين',
            isError: true,
          );
        } else {
          _showSnack('✅ تم نشر الإعدادات بنجاح إلى الجميع!');
        }
      } else {
        _showSnack('❌ فشل النشر، تأكد من اتصال الإنترنت', isError: true);
      }
    } catch (e) {
      _showSnack('❌ خطأ غير متوقع: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  /// نشر الرقم السري الذي يفتح الغرفة إلى إعدادات السيرفر — يُطبَّق على كل
  /// الأجهزة فوراً (Realtime) أو عند فتح التطبيق، بلا إعادة بناء.
  Future<void> _publishRoomPasscode() async {
    final String code = _roomPasscodeCtrl.text.trim();
    setState(() => _isLoading = true);
    final bool ok = await RemoteMessagingService.publishRoomPasscode(code);
    setState(() => _isLoading = false);

    if (ok) {
      _showSnack(
        code.isEmpty
            ? '✅ تم مسح الرقم السري: التطبيق سيعود للرقم المضمَّن (${UserMessagingScreen.roomPasscode})'
            : '✅ تم حفظ الرقم السري للغرفة: $code — يُطبَّق على جميع الأجهزة',
      );
    } else {
      _showSnack(
        '❌ تعذّر الحفظ: أضِف عمود room_passcode (نوع text) إلى جدول app_config في Supabase ثم أعد المحاولة',
        isError: true,
      );
    }
  }

  Future<void> _publishMarqueeText() async {
    final List<String> messages = _marqueeMessages;
    if (messages.isEmpty) {
      _showSnack('الرجاء إدخال نص/أحاديث الشريط العلوي', isError: true);
      return;
    }
    final String msg = messages.first;
    setState(() => _isLoading = true);
    try {
      // 1. الأحاديث + وقت الظهور + التنسيق (اللون ونوع الخط وحجم الخط) معاً
      final bool styled = await RemoteMessagingService.publishSettingsMarquee(
        SettingsMarqueeSettings(
          text: msg,
          messages: messages,
          intervalMs: _settingsMarqueeIntervalMs,
          color: _settingsMarqueeColor,
          fontFamily: _settingsMarqueeFont,
          fontSize: _settingsMarqueeFontSize,
        ),
      );
      if (styled) {
        _showSnack(
          messages.length > 1
              ? '✅ تم نشر ${messages.length} حديثاً تتقلّب كل '
                  '${(_settingsMarqueeIntervalMs / 1000).toStringAsFixed(1)} ثانية!'
              : '✅ تم نشر النص المتحرك وتنسيقه (اللون ونوع الخط والحجم)!',
        );
      } else {
        // 2. أعمدة التنسيق غير مضافة في app_config → ننشر النص وحده حتى
        //    لا يتعطّل التحديث، ونُخبر المدير بما ينقص.
        final bool textOnly = await RemoteMessagingService.publishConfig(
          latestVersion: _versionCtrl.text.trim(),
          updateTitle: '',
          updateMessage: '',
          updateUrl: '',
          forceUpdate: false,
          targetUserId: '',
          targetCity: '',
          remoteMarqueeText: msg,
        );        _showSnack(
          textOnly
              ? '⚠️ تم نشر الحديث الأول فقط — أضِف أعمدة marquee_messages '
                  'وmarquee_interval_ms وmarquee_color وmarquee_font '
                  'وmarquee_font_size في جدول app_config ليصل بقية الأحاديث '
                  'ووقت الظهور والتنسيق لبقية الأجهزة'
              : '❌ فشل نشر النص المتحرك',
          isError: !textOnly,
        );
      }
    } catch (e) {
      _showSnack('❌ خطأ: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _resetMarqueeTextToDefault() async {
    setState(() => _isLoading = true);
    try {
      // يعيد النص إلى أسماء الله الحسنى والتنسيق إلى الافتراضي (أبيض · أميري · 12)
      final bool styled = await RemoteMessagingService.resetSettingsMarquee();
      if (!styled) {
        // أعمدة التنسيق غير مضافة → نمسح النص وحده من السيرفر
        await RemoteMessagingService.publishConfig(
          latestVersion: _versionCtrl.text.trim(),
          updateTitle: '',
          updateMessage: '',
          updateUrl: '',
          forceUpdate: false,
          targetUserId: '',
          targetCity: '',
          remoteMarqueeText: '',
        );
      }
      setState(() {
        _setMarqueeMessages(<String>[_defaultAllahNames]);
        _settingsMarqueeIntervalMs = SettingsMarqueeSettings.defaultIntervalMs;
        _settingsMarqueeColor = SettingsMarqueeSettings.defaultColor;
        _settingsMarqueeFont = SettingsMarqueeSettings.defaultFontFamily;
        _settingsMarqueeFontSize = SettingsMarqueeSettings.defaultFontSize;
      });
      _showSnack(
        styled
            ? '✅ تم استعادة النص الافتراضي (أسماء الله الحسنى) وتنسيقه!'
            : '✅ تم الاستعادة على هذا الجهاز — أضِف أعمدة marquee_* ليصل التنسيق لبقية الأجهزة',
      );
    } catch (e) {
      _showSnack('❌ خطأ: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteMarqueeText() async {
    // تأكيد الحذف
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white, width: 1.0),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.delete_forever_rounded,
              color: Colors.redAccent,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'حذف النص المتحرك',
              style: GoogleFonts.amiri(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سيتم حذف النص المتحرك الحالي نهائياً من قاعدة البيانات والتطبيق.',
              style: GoogleFonts.amiri(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سيعود التطبيق لعرض أسماء الله الحسنى كنص افتراضي',
                      style: GoogleFonts.amiri(
                        color: Colors.amber.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.amiri(color: Colors.white38),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(
              Icons.delete_forever_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: Text(
              'حذف نهائياً',
              style: GoogleFonts.amiri(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      // حذف النص من Supabase بإرسال نص فارغ
      await Supabase.instance.client
          .from('app_config')
          .update({'marquee_text': ''})
          .eq('id', 1);

      // مسح الكاش المحلي (النص والأحاديث ووقت الظهور)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('remote_marquee_text');
      await prefs.remove(RemoteMessagingService.settingsMarqueeMessagesKey);

      // تصفير حقول النص في اللوحة
      setState(() => _setMarqueeMessages(<String>[_defaultAllahNames]));

      _showSnack('✅ تم حذف النص المتحرك وسيعود التطبيق للنص الافتراضي!');
    } catch (e) {
      _showSnack('❌ خطأ في الحذف: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _resetPostPrayerDuaToDefault() async {
    setState(() => _isLoading = true);
    try {
      final success = await RemoteMessagingService.publishConfig(
        latestVersion: _versionCtrl.text.trim(),
        updateTitle: '',
        updateMessage: '',
        updateUrl: '',
        forceUpdate: false,
        targetUserId: '',
        targetCity: '',
        remotePostPrayerDuaEnabled: true,
        remotePostPrayerDuaOffset: 20,
        remotePostPrayerDuaText: '',
        remotePostPrayerDuaLoop: false,
      );
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('postPrayerDuaEnabled');
        await prefs.remove('postPrayerDuaOffset');
        await prefs.remove('remote_post_prayer_dua_text');
        await prefs.remove('postPrayerDuaLoop');
        if (mounted) {
          setState(() {
            _postPrayerDuaEnabled = true;
            _postPrayerDuaOffset = 20;
            _postPrayerDuaTextCtrl.clear();
            _postPrayerDuaLoop = false;
          });
        }
        _showSnack('✅ تم استعادة الإعدادات الافتراضية لدعاء ما بعد الأذان!');
      } else {
        _showSnack('❌ فشل استعادة الإعدادات الافتراضية', isError: true);
      }
    } catch (e) {
      _showSnack('❌ خطأ: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  /// حذف دعاء ما بعد الأذان نهائياً مع تأكيد
  Future<void> _deletePostPrayerDua() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white, width: 1.0),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.delete_forever_rounded,
              color: Colors.redAccent,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'حذف دعاء ما بعد الأذان',
              style: GoogleFonts.amiri(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'سيتم حذف الدعاء المخصص وإيقاف دعاء ما بعد الأذان.\nيمكنك تفعيله مرة أخرى من الإعدادات.',
          style: GoogleFonts.amiri(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.amiri(color: Colors.white38),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(
              Icons.delete_forever_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: Text(
              'حذف نهائياً',
              style: GoogleFonts.amiri(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      // إرسال إعدادات فارغة لتعطيل الدعاء
      final success = await RemoteMessagingService.publishConfig(
        latestVersion: _versionCtrl.text.trim(),
        updateTitle: '',
        updateMessage: '',
        updateUrl: '',
        forceUpdate: false,
        targetUserId: '',
        targetCity: '',
        remotePostPrayerDuaEnabled: false,
        remotePostPrayerDuaOffset: 20,
        remotePostPrayerDuaText: '',
        remotePostPrayerDuaLoop: false,
      );
      if (success) {
        // مسح الكاش المحلي
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('postPrayerDuaEnabled');
        await prefs.remove('postPrayerDuaOffset');
        await prefs.remove('remote_post_prayer_dua_text');
        await prefs.remove('postPrayerDuaLoop');
        if (mounted) {
          setState(() {
            _postPrayerDuaEnabled = false;
            _postPrayerDuaOffset = 20;
            _postPrayerDuaTextCtrl.clear();
            _postPrayerDuaLoop = false;
          });
        }
        _showSnack('✅ تم حذف وإيقاف دعاء ما بعد الأذان بنجاح!');
      } else {
        _showSnack('❌ فشل حذف الدعاء', isError: true);
      }
    } catch (e) {
      _showSnack('❌ خطأ: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  /// إعدادات النص المتحرك كما هي في الحقول الآن (مصدر واحد للنشر والمعاينة).
  HomeMarqueeSettings _homeMarqueeFromFields() {
    return HomeMarqueeSettings(
      enabled: _homeDuaEnabled,
      text: _homeDuaTextCtrl.text,
      color: _homeDuaColor,
      fontFamily: _homeDuaFont,
      fontSize: _homeDuaFontSize,
      intervalMs: _homeDuaIntervalMs,
      bold: _homeDuaBold,
      afterMinutes: _homeDuaAfterMinutes,
    );
  }

  /// حفظ كل إعدادات النص المتحرك على هذا الجهاز وعلى السيرفر معاً.
  Future<void> _publishHomeDua() async {
    final HomeMarqueeSettings settings = _homeMarqueeFromFields();
    setState(() => _isLoading = true);
    try {
      final bool okServer = await RemoteMessagingService.publishHomeMarquee(
        settings,
      );
      if (okServer) {
        _showSnack('✅ تم حفظ إعدادات النص المتحرك وإرسالها لجميع الأجهزة!');
      } else {
        _showSnack(
          '✅ حُفظت الإعدادات على هذا الجهاز، لكن تعذّر النشر لبقية الأجهزة — تأكد من إضافة أعمدة home_dua_* في جدول app_config بـ Supabase.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnack('❌ خطأ: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _resetHomeDuaToDefault() async {
    setState(() => _isLoading = true);
    try {
      final bool okServer = await RemoteMessagingService.resetHomeMarquee();
      _homeDuaTextCtrl.clear();
      setState(() {
        _homeDuaEnabled = HomeMarqueeSettings.defaultEnabled;
        _homeDuaColor = HomeMarqueeSettings.followPrayerColorsValue;
        _homeDuaFont = HomeMarqueeSettings.defaultFontFamily;
        _homeDuaFontSize = HomeMarqueeSettings.defaultFontSize;
        _homeDuaIntervalMs = HomeMarqueeSettings.defaultIntervalMs;
        _homeDuaBold = HomeMarqueeSettings.defaultBold;
        _homeDuaAfterMinutes = HomeMarqueeSettings.defaultAfterMinutes;
      });
      _showSnack(
        okServer
            ? '✅ تم إعادة النص المتحرك للشاشة الرئيسية إلى الوضع الأصلي!'
            : '✅ عاد هذا الجهاز للوضع الأصلي (تعذّر النشر لبقية الأجهزة)',
        isError: !okServer,
      );
    } catch (e) {
      _showSnack('❌ خطأ: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteHomeDua() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white, width: 1.0),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.delete_forever_rounded,
              color: Colors.redAccent,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'حذف الدعاء المتحرك',
              style: GoogleFonts.amiri(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'سيتم حذف الدعاء المخصص للشاشة الرئيسية وسيعود التطبيق للوضع الأصلي.',
          style: GoogleFonts.amiri(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.amiri(color: Colors.white38),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(
              Icons.delete_forever_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: Text(
              'حذف نهائياً',
              style: GoogleFonts.amiri(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _resetHomeDuaToDefault();
  }

  Future<void> _publishDuaUnderCounter() async {
    final msg = _duaUnderCounterCtrl.text.trim();
    setState(() => _isLoading = true);
    try {
      final success = await RemoteMessagingService.publishConfig(
        latestVersion: _versionCtrl.text.trim(),
        updateTitle: '',
        updateMessage: '',
        updateUrl: '',
        forceUpdate: false,
        targetUserId: '',
        targetCity: '',
        remoteDuaUnderCounterText: msg,
        remoteDuaUnderCounterColor: _duaUnderCounterColor,
      );
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('remote_dua_text', msg);
        await prefs.setInt('dua_text_color', _duaUnderCounterColor);
        _showSnack('✅ تم نشر نص الأدعية (تحت العداد) بنجاح!');
      } else {
        _showSnack('❌ فشل النشر', isError: true);
      }
    } catch (e) {
      _showSnack('❌ خطأ: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _restoreDefaultDuaUnderCounter() async {
    setState(() => _isLoading = true);
    try {
      final success = await RemoteMessagingService.publishConfig(
        latestVersion: _versionCtrl.text.trim(),
        updateTitle: '',
        updateMessage: '',
        updateUrl: '',
        forceUpdate: false,
        targetUserId: '',
        targetCity: '',
        remoteDuaUnderCounterText: '',
      );
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('remote_dua_text');
        _duaUnderCounterCtrl.clear();
        _showSnack('✅ تم استعادة النص الافتراضي');
      } else {
        _showSnack('❌ فشل الاستعادة', isError: true);
      }
    } catch (e) {
      _showSnack('❌ خطأ: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _publishBroadcast() async {
    final id = _broadcastIdCtrl.text.trim();
    final msg = _broadcastMsgCtrl.text
        .replaceAll('إهداء القلوب', '')
        .replaceAll('اهداء القلوب', '')
        .replaceAll('إهداء', '')
        .replaceAll('اهداء', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (id.isEmpty || msg.isEmpty) {
      _showSnack('الرجاء إدخال معرف ونص الرسالة', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final success = await RemoteMessagingService.sendBroadcast(
        id: id,
        title: _broadcastTitleCtrl.text
            .trim()
            .replaceAll(RegExp(r'^تنبيه(\s+هام)?[:\- ]*'), '')
            .replaceAll('تنبيه', '')
            .replaceAll('إهداء القلوب', '')
            .replaceAll('اهداء القلوب', '')
            .replaceAll('إهداء', '')
            .replaceAll('اهداء', '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
        message: msg,
        btnText: _broadcastBtnTextCtrl.text.trim().isEmpty
            ? 'حسنا'
            : _broadcastBtnTextCtrl.text.trim(),
        btnUrl: _broadcastBtnUrlCtrl.text.trim(),
        targetUserId: _broadcastTargetUserIdCtrl.text.trim(),
      );

      if (success) {
        final targetId = _broadcastTargetUserIdCtrl.text.trim();
        _showSnack(
          targetId.isEmpty
              ? '✅ تم إرسال الرسالة لجميع المستخدمين بنجاح!'
              : '✅ تم إرسال الرسالة للمستخدم المحدد بنجاح!',
        );
        setState(() {
          _broadcastIdCtrl.text =
              'msg_${DateTime.now().millisecondsSinceEpoch}';
        });
        await _loadFromSupabase();
      } else {
        _showSnack('❌ فشل الإرسال، يرجى التأكد من الإنترنت', isError: true);
      }
    } catch (e) {
      _showSnack('❌ خطأ في الإرسال: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteBroadcast(String id) async {
    try {
      await _db.from('broadcasts').delete().eq('id', id);
      _showSnack('تم حذف الرسالة');
      await _loadFromSupabase();
    } catch (e) {
      _showSnack('فشل الحذف: $e', isError: true);
    }
  }

  /// إرسال رسالة بث اختبارية إلى جهاز المدير نفسه
  Future<void> _sendTestBroadcast() async {
    setState(() => _isLoading = true);
    try {
      // الحصول على الرقم التسلسلي للمدير
      final myUserId = await RemoteMessagingService.getOrCreateUserId();

      final testId = 'test_broadcast_${DateTime.now().millisecondsSinceEpoch}';
      const testTitle = '🧪 رسالة اختبارية';
      final testBody =
          '✅ نظام البث يعمل بشكل صحيح!\n\n'
          'هذه رسالة اختبارية تم إرسالها إلى جهازك فقط.\n'
          'إذا كنت ترى هذه الرسالة، فالنظام جاهز.\n\n'
          '🆔 رقمك التسلسلي: $myUserId';

      final success = await RemoteMessagingService.sendBroadcast(
        id: testId,
        title: testTitle,
        message: testBody,
        btnText: 'تم',
        btnUrl: '',
        targetUserId: myUserId,
        targetCity: '',
      );

      if (success) {
        _showSnack('✅ تم إرسال رسالة الاختبار إلى جهازك! (الرقم: $myUserId)');
        await _loadFromSupabase();
      } else {
        _showSnack('❌ فشل إرسال رسالة الاختبار', isError: true);
      }
    } catch (e) {
      _showSnack('❌ خطأ في الإرسال: $e', isError: true);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _clearUpdateSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white, width: 1.0),
        ),
        title: Text(
          'مسح إعدادات التحديث',
          style: GoogleFonts.amiri(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'سيتم مسح بيانات التحديث من قاعدة البيانات والتطبيق نهائياً. هل أنت متأكد؟',
          style: GoogleFonts.amiri(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.amiri(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'مسح نهائياً',
              style: GoogleFonts.amiri(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final success = await RemoteMessagingService.publishConfig(
          latestVersion: '2.0.0',
          updateTitle: '',
          updateMessage: '',
          updateUrl: '',
          forceUpdate: false,
          targetUserId: '',
          targetCity: '',
          remoteDuaEnabled: _duaEnabled,
          remoteDuaMessage: _duaMsgCtrl.text.trim(),
          remoteDuaOffset: _duaOffset,
        );

        if (success) {
          _versionCtrl.text = '2.0.0';
          _updateTitleCtrl.clear();
          _updateMsgCtrl.clear();
          _updateUrlCtrl.clear();
          _forceUpdate = false;
          _showSnack(
            '✅ تم مسح إعدادات التحديث من قاعدة البيانات والتطبيق بنجاح!',
          );
          await _loadFromSupabase();
        } else {
          _showSnack('❌ فشل مسح إعدادات التحديث', isError: true);
        }
      } catch (e) {
        _showSnack('❌ خطأ: $e', isError: true);
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearDuaSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white, width: 1.0),
        ),
        title: Text(
          'مسح إعدادات ما قبل الأذان',
          style: GoogleFonts.amiri(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'سيتم إيقاف ومسح إعدادات إشعار ما قبل الأذان من قاعدة البيانات والتطبيق نهائياً. هل أنت متأكد؟',
          style: GoogleFonts.amiri(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.amiri(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'مسح نهائياً',
              style: GoogleFonts.amiri(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final success = await RemoteMessagingService.publishConfig(
          latestVersion: _versionCtrl.text.trim(),
          updateTitle: _updateTitleCtrl.text.trim(),
          updateMessage: _updateMsgCtrl.text.trim(),
          updateUrl: _updateUrlCtrl.text.trim(),
          forceUpdate: _forceUpdate,
          targetUserId: '',
          targetCity: '',
          remoteDuaEnabled: false,
          remoteDuaMessage: '',
          remoteDuaOffset: 4,
        );

        if (success) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('duaEnabled');
          await prefs.remove('duaOffsetMinutes');
          await prefs.remove('remote_dua_custom_text');

          _duaEnabled = false;
          _duaOffset = 4;
          _duaMsgCtrl.clear();
          _showSnack('✅ تم مسح إشعار ما قبل الأذان وإيقافه نهائياً!');
          await _loadFromSupabase();
        } else {
          _showSnack('❌ فشل مسح إعدادات ما قبل الأذان', isError: true);
        }
      } catch (e) {
        _showSnack('❌ خطأ: $e', isError: true);
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearBroadcasts() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white, width: 1.0),
        ),
        title: Text(
          'مسح جميع رسائل البث',
          style: GoogleFonts.amiri(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'سيتم حذف كافة رسائل البث السابقة من قاعدة البيانات وتصفيرها لدى المستخدمين نهائياً. هل أنت متأكد؟',
          style: GoogleFonts.amiri(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.amiri(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'مسح نهائياً',
              style: GoogleFonts.amiri(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _db.from('broadcasts').delete().neq('id', 'zero_id_placeholder');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_seen_broadcast_id');

        _broadcastIdCtrl.text = 'msg_${DateTime.now().millisecondsSinceEpoch}';
        _broadcastTitleCtrl.clear();
        _broadcastMsgCtrl.clear();
        _broadcastBtnTextCtrl.text = 'حسنا';
        _broadcastBtnUrlCtrl.clear();

        _showSnack('✅ تم مسح جميع رسائل البث نهائياً!');
        await _loadFromSupabase();
      } catch (e) {
        _showSnack('❌ خطأ في حذف الرسائل: $e', isError: true);
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white, width: 1.0),
        ),
        title: Text(
          'إعادة ضبط شاملة',
          style: GoogleFonts.amiri(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'سيتم مسح كافة الإعدادات وسجل الرسائل نهائياً. هل أنت متأكد؟',
          style: GoogleFonts.amiri(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.amiri(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'مسح الكل الآن',
              style: GoogleFonts.amiri(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        // 1. إعادة ضبط الإعدادات الافتراضية
        await RemoteMessagingService.publishConfig(
          latestVersion: '2.0.0',
          updateTitle: 'تحديث جديد متوفر',
          updateMessage: 'يرجى تحديث التطبيق للحصول على آخر الميزات.',
          updateUrl: '',
          forceUpdate: false,
          targetUserId: '',
          targetCity: '',
          remoteDuaEnabled: true,
          remoteDuaMessage:
              'اللهم اغفر لنا ولوالدينا وارحمهما كما ربيانا صغارا',
          remoteDuaOffset: 4,
          // ── إعادة ضبط دعاء ما بعد الأذان ──
          remotePostPrayerDuaEnabled: true,
          remotePostPrayerDuaOffset: 20,
          remotePostPrayerDuaText: '',
          remotePostPrayerDuaLoop: false,
        );

        // 2. مسح سجل الرسائل بالكامل من Supabase
        await _db.from('broadcasts').delete().neq('id', 'zero_id_placeholder');

        _showSnack('✅ تم مسح كافة الإعدادات والسجل بنجاح');
        await _loadFromSupabase();
      } catch (e) {
        _showSnack('❌ فشل المسح الشامل: $e', isError: true);
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cleanOldMessages() async {
    setState(() => _isLoading = true);
    final count = await RemoteMessagingService.cleanOldBroadcasts();
    setState(() => _isLoading = false);
    _showSnack('✅ تم تنظيف السجل وحذف $count رسالة قديمة بنجاح');
    await _loadFromSupabase();
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.amiri()),
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) return _buildPasscodeScreen();

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.opaque,
      child: GlassScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white70,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'لوحة التحكم',
                style: GoogleFonts.amiri(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.amber),
              onPressed: _loadFromSupabase,
              tooltip: 'تحديث من Supabase',
            ),
            IconButton(
              icon: const Icon(
                Icons.cleaning_services_rounded,
                color: Colors.cyanAccent,
              ),
              onPressed: _cleanOldMessages,
              tooltip: 'تنظيف الرسائل القديمة (30 يوم)',
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.redAccent,
              ),
              onPressed: _resetToDefaults,
              tooltip: 'إعادة ضبط كافة الإعدادات',
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white38,
            labelStyle: GoogleFonts.amiri(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(icon: Icon(Icons.system_update_rounded), text: 'التحديثات'),
              Tab(icon: Icon(Icons.campaign_rounded), text: 'الرسائل'),
              Tab(icon: Icon(Icons.history_rounded), text: 'السجل'),
            ],
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              controller: _tabs,
              children: [
                RepaintBoundary(child: _buildUpdateTab()),
                RepaintBoundary(child: _buildBroadcastTab()),
                RepaintBoundary(child: _buildHistoryTab()),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Updates ────────────────────────────────────────────────────────
  Widget _buildUpdateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentConfig != null) _buildStatusCard(),
          const SizedBox(height: 20),
          _buildSection('🚀 إعدادات التحديث', [
            _buildField(
              _versionCtrl,
              'رقم الإصدار الجديد (المثبَّت ${AppVersion.version})',
              Icons.tag,
            ),
            _buildField(_updateTitleCtrl, 'عنوان التحديث', Icons.title),
            _buildField(
              _updateMsgCtrl,
              'تفاصيل التحديث',
              Icons.description_rounded,
              maxLines: 3,
            ),
            _buildField(_updateUrlCtrl, 'رابط التحميل', Icons.link),
            SwitchListTile(
              activeColor: Colors.amber,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'تحديث إجباري',
                style: GoogleFonts.amiri(color: Colors.white),
              ),
              subtitle: Text(
                'يمنع المستخدم من الإغلاق دون تحديث',
                style: GoogleFonts.amiri(color: Colors.white38, fontSize: 12),
              ),
              value: _forceUpdate,
              onChanged: (v) => setState(() => _forceUpdate = v),
            ),
          ]),
          const SizedBox(height: 20),
          _buildSection('🤲 إعدادات إشعار ما قبل الأذان', [
            SwitchListTile(
              activeColor: Colors.amber,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'تفعيل الإشعار (15 دقيقة)',
                style: GoogleFonts.amiri(color: Colors.white),
              ),
              value: _duaEnabled,
              onChanged: (v) => setState(() => _duaEnabled = v),
            ),
            _buildField(
              _duaMsgCtrl,
              'نص الإشعار (آية قرآنية أو دعاء)',
              Icons.auto_awesome,
              maxLines: 4,
            ),
            Row(
              children: [
                Text(
                  'التوقيت: ',
                  style: GoogleFonts.amiri(color: Colors.white70),
                ),
                Text(
                  '15 دقيقة قبل الأذان',
                  style: GoogleFonts.amiri(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 30),
          _buildPublishBtn('نشر جميع الإعدادات إلى Supabase', _publishUpdate),
          const SizedBox(height: 12),
          _buildPublishBtn(
            'مسح بيانات التحديث نهائياً',
            _clearUpdateSettings,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 12),
          _buildPublishBtn(
            'مسح إشعار ما قبل الأذان نهائياً',
            _clearDuaSettings,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 30),
          _buildPostPrayerDuaSection(),
          const SizedBox(height: 30),
        ],
      ),
    );
  } // ══════════════════════════════════════════════════════════════════════════

  // قسم: دعاء ما بعد الأذان
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPostPrayerDuaSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC0D1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withOpacity(0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.05),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── رأس القسم ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.teal.withOpacity(0.15)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.mosque_rounded,
                    color: Colors.teal,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '🤲 دعاء ما بعد الأذان',
                  style: GoogleFonts.amiri(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── تفعيل/تعطيل ──────────────────────────────────────
                SwitchListTile(
                  activeColor: Colors.teal,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'تفعيل دعاء ما بعد الأذان',
                    style: GoogleFonts.amiri(color: Colors.white, fontSize: 13),
                  ),
                  value: _postPrayerDuaEnabled,
                  onChanged: (v) => setState(() => _postPrayerDuaEnabled = v),
                ),
                const SizedBox(height: 16),

                // ── توقيت الظهور ────────────────────────────────────
                Text(
                  '⏱ توقيت الظهور: $_postPrayerDuaOffset دقيقة بعد الأذان',
                  style: GoogleFonts.amiri(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Slider(
                  value: _postPrayerDuaOffset.toDouble(),
                  min: 1,
                  max: 60,
                  divisions: 59,
                  activeColor: Colors.teal,
                  inactiveColor: Colors.teal.withOpacity(0.2),
                  label: '$_postPrayerDuaOffset دقيقة',
                  onChanged: (v) =>
                      setState(() => _postPrayerDuaOffset = v.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '1 دقيقة',
                      style: GoogleFonts.amiri(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      '60 دقيقة',
                      style: GoogleFonts.amiri(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── نص مخصص ─────────────────────────────────────────
                Text(
                  '📝 نص دعاء مخصص (اختياري)',
                  style: GoogleFonts.amiri(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC050812),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.withOpacity(0.2)),
                  ),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _postPrayerDuaTextCtrl,
                    builder: (context, value, _) {
                      final txt = value.text;
                      return Text(
                        txt.isNotEmpty
                            ? (txt.length > 100
                                  ? '${txt.substring(0, 100)}...'
                                  : txt)
                            : '— النص الافتراضي (أدعية من القرآن) —',
                        style: GoogleFonts.amiri(
                          color: txt.isNotEmpty
                              ? Colors.white70
                              : Colors.white24,
                          fontSize: 12,
                        ),
                        textDirection: TextDirection.rtl,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                _buildField(
                  _postPrayerDuaTextCtrl,
                  'أدخل نص الدعاء المخصص (كل سطر = دعاء مختلف لوضع التكرار)',
                  Icons.auto_awesome_rounded,
                  maxLines: 4,
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.teal.shade200,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'اتركه فارغاً لاستخدام الأدعية الافتراضية من القرآن (تختلف حسب اليوم والصلاة)',
                          style: GoogleFonts.amiri(
                            color: Colors.teal.shade200.withOpacity(0.8),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── وضع التكرار ─────────────────────────────────────
                SwitchListTile(
                  activeColor: Colors.teal,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '🔄 وضع التكرار (Loop)',
                    style: GoogleFonts.amiri(color: Colors.white, fontSize: 13),
                  ),
                  subtitle: Text(
                    'يتنقل بين الأسطر في كل صلاة حسب اليوم (فجر→ظهر→عصر→مغرب→عشاء)',
                    style: GoogleFonts.amiri(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                  value: _postPrayerDuaLoop,
                  onChanged: (v) => setState(() => _postPrayerDuaLoop = v),
                ),
                const SizedBox(height: 20),

                // ── أزرار التحكم ────────────────────────────────────
                // زر نشر الإعدادات
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.save_rounded, size: 20),
                    label: Text(
                      '💾 حفظ إعدادات دعاء ما بعد الأذان',
                      style: GoogleFonts.amiri(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: _publishUpdate,
                  ),
                ),
                const SizedBox(height: 10),

                // صف: استعادة الافتراضي + حذف
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blueGrey,
                          side: BorderSide(
                            color: Colors.blueGrey.withOpacity(0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.restore_rounded, size: 18),
                        label: Text(
                          'استعادة الافتراضي',
                          style: GoogleFonts.amiri(fontSize: 12),
                        ),
                        onPressed: _resetPostPrayerDuaToDefault,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: BorderSide(
                            color: Colors.redAccent.withOpacity(0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          size: 18,
                        ),
                        label: Text(
                          'حذف الدعاء',
                          style: GoogleFonts.amiri(fontSize: 12),
                        ),
                        onPressed: _deletePostPrayerDua,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Broadcast ──────────────────────────────────────────────────────
  Widget _buildBroadcastTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── فاصل ─────────────────────────────────────────────────────────
          Divider(color: Colors.white12, thickness: 1),
          const SizedBox(height: 16),
          // ── الرقم السري الذي يفتح الغرفة ─────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xCC0D1220),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.05),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Colors.amber,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '🔑 الرقم السري للغرفة',
                      style: GoogleFonts.amiri(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _roomPasscodeCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 17,
                    letterSpacing: 4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'مثال: 1959',
                    hintStyle: GoogleFonts.cairo(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.password_rounded,
                      color: Colors.amber,
                    ),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.amber),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'المستخدمون يفتحون الغرفة (المراسلة بين المستخدمين بمعرّف الجهاز) بهذا الرقم. '
                  'اتركه فارغاً للعودة إلى الرقم المضمَّن في التطبيق.',
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    color: Colors.white60,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _publishRoomPasscode,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      'حفظ الرقم السري',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── النص المتحرك في شاشة الإعدادات ──────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xCC0D1220),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.amber.withOpacity(0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.05),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── رأس القسم ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.08),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.amber.withOpacity(0.15)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.text_fields_rounded,
                          color: Colors.amber,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '📜 النص المتحرك – شاشة الإعدادات',
                        style: GoogleFonts.amiri(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── معاينة النص الحالي ──────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _marqueeMessages.length > 1
                                  ? '👁 معاينة أول حديث — والتقليب كل '
                                      '${(_settingsMarqueeIntervalMs / 1000).toStringAsFixed(1)} ثانية '
                                      '(${_marqueeMessages.length} أحاديث):'
                                  : '👁 معاينة النص:',
                              style: GoogleFonts.amiri(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _marqueeTextCtrl.text.isNotEmpty
                                  ? (_marqueeTextCtrl.text.length > 80
                                        ? '${_marqueeTextCtrl.text.substring(0, 80)}...'
                                        : _marqueeTextCtrl.text)
                                  : '— لا يوجد نص —',
                              style: GoogleFonts.amiri(
                                color: _marqueeTextCtrl.text.isNotEmpty
                                    ? Colors.white70
                                    : Colors.white24,
                                fontSize: 12,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── محرّر الأحاديث + وقت الظهور ──────────────────
                      _buildSettingsMarqueeEditor(),
                      const SizedBox(height: 16),
                      // ── تنسيق النص: اللون + نوع الخط + حجم الخط ────────
                      _buildSettingsMarqueeStyleControls(),
                      const SizedBox(height: 10),
                      // ── ملاحظة ─────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.lightBlueAccent,
                              size: 15,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'يظهر النص متحركاً في أعلى شاشة الإعدادات بجانب سهم الرجوع، باللون ونوع الخط والحجم المختارين أدناه (تُحفظ مع النص عند النشر)',
                                style: GoogleFonts.amiri(
                                  color: Colors.lightBlueAccent.withOpacity(
                                    0.8,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── أزرار الإجراءات ─────────────────────────────────
                      // زر النشر
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.upload_rounded, size: 20),
                          label: Text(
                            'نشر النص المتحرك للجميع',
                            style: GoogleFonts.amiri(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          onPressed: _publishMarqueeText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // صف: استعادة الافتراضي + حذف
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blueGrey,
                                side: BorderSide(
                                  color: Colors.blueGrey.withOpacity(0.5),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.restore_rounded, size: 18),
                              label: Text(
                                'استعادة الافتراضي',
                                style: GoogleFonts.amiri(fontSize: 12),
                              ),
                              onPressed: _resetMarqueeTextToDefault,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: BorderSide(
                                  color: Colors.redAccent.withOpacity(0.5),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.delete_forever_rounded,
                                size: 18,
                              ),
                              label: Text(
                                'حذف النص',
                                style: GoogleFonts.amiri(fontSize: 12),
                              ),
                              onPressed: _deleteMarqueeText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // ── فاصل ─────────────────────────────────────────────────────────
          Divider(color: Colors.white12, thickness: 1),
          const SizedBox(height: 16),
          // ── رسالة بث جديدة ───────────────────────────────────────────────
          _buildSection('📢 رسالة بث جديدة للمستخدمين', [
            _buildField(
              _broadcastIdCtrl,
              'معرف الرسالة (فريد)',
              Icons.fingerprint,
            ),
            _buildField(_broadcastTitleCtrl, 'عنوان الرسالة', Icons.title),
            _buildField(
              _broadcastMsgCtrl,
              'نص الرسالة',
              Icons.message_rounded,
              maxLines: 4,
            ),
            _buildField(
              _broadcastBtnTextCtrl,
              'نص الزر',
              Icons.smart_button_rounded,
            ),
            _buildField(
              _broadcastBtnUrlCtrl,
              'رابط الزر (اختياري)',
              Icons.link,
            ),
            _buildField(
              _broadcastTargetUserIdCtrl,
              'الرقم التسلسلي للمستخدم (اتركه فارغاً للجميع)',
              Icons.fingerprint,
            ),
          ]),
          const SizedBox(height: 30),
          _buildPublishBtn(
            'إرسال رسالة البث إلى المستخدمين',
            _publishBroadcast,
            color: Colors.teal,
          ),
          const SizedBox(height: 12),
          _buildPublishBtn(
            'مسح وحذف جميع رسائل البث نهائياً',
            _clearBroadcasts,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 24),
          // ── فاصل ─────────────────────────────────────────────────────────
          Divider(color: Colors.white12, thickness: 1),
          const SizedBox(height: 16),
          // ── النص المتحرك الشاشة الرئيسية ─────────────────────────────────
          _buildHomeDuaSection(),
          const SizedBox(height: 30),
          // ── فاصل ─────────────────────────────────────────────────────────
          Divider(color: Colors.white12, thickness: 1),
          const SizedBox(height: 16),
          // ── شاشة عن الموبايل (إدارة المحتوى العام) ────────────────────────
          _buildAboutMobileSection(),
          const SizedBox(height: 30),
          // ── زر اختبار الإشعارات (داخل السكرول) ────────────────────────────
          Divider(color: Colors.white12, thickness: 1),
          const SizedBox(height: 16),
          _buildTestBroadcastItem(),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildTestBroadcastItem() {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        await _sendTestBroadcast();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xCC0D1220),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF7C4DFF).withOpacity(0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C4DFF).withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.send_to_mobile_rounded,
                color: Color(0xFF7C4DFF),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'اختبار إرسال رسالة بث للجهاز الحالي',
                    style: GoogleFonts.amiri(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'يرسل رسالة اختبار إلى رقمك التسلسلي للتحقق من النظام',
                    style: GoogleFonts.amiri(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'إرسال',
                    style: GoogleFonts.amiri(
                      color: const Color(0xFF7C4DFF),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF7C4DFF),
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutMobileSection() {
    final List<int> availableColors = [
      0xFFDFBA6B, // ذهبي
      0xFFFFFFFF, // أبيض
      0xFF4CAF50, // أخضر
      0xFF00BCD4, // سماوي
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC0D1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.05),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.amber.withOpacity(0.15)),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.phone_android_rounded,
                  color: Colors.amber,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  '📱 شاشة عن الموبايل (إدارة المحتوى العام)',
                  style: GoogleFonts.amiri(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. التحكم في أسماء الله الحسنى والحاديث (الشريط العلوي)
                _buildSettingsMarqueeEditor(),
                _buildPublishBtn(
                  'نشر شريط أسماء الله الحسنى',
                  _publishMarqueeText,
                  color: Colors.amber[800]!,
                ),

                const SizedBox(height: 24),
                Divider(color: Colors.white10),
                const SizedBox(height: 16),

                // 2. التحكم في الأدعية (تحت العداد)
                _buildField(
                  _duaUnderCounterCtrl,
                  'تعديل نص الأدعية (تحت العداد) في الشاشة الرئيسية',
                  Icons.auto_awesome,
                  maxLines: 3,
                ),

                Text(
                  '🎨 لون نص الأدعية:',
                  style: GoogleFonts.amiri(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: availableColors.map((colorVal) {
                    final bool isSelected = _duaUnderCounterColor == colorVal;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _duaUnderCounterColor = colorVal),
                      child: Container(
                        margin: const EdgeInsets.only(left: 10),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          backgroundColor: Color(colorVal),
                          radius: 14,
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.black,
                                  size: 14,
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                _buildPublishBtn(
                  'نشر نص الأدعية (تحت العداد)',
                  _publishDuaUnderCounter,
                  color: Colors.amber[800]!,
                ),
                const SizedBox(height: 10),
                _buildPublishBtn(
                  'استعادة النص الافتراضي',
                  _restoreDefaultDuaUnderCounter,
                  color: Colors.blueGrey,
                ),

                const SizedBox(height: 24),
                Divider(color: Colors.white10),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeDuaSection() {
    final List<int> availableColors = [
      0xFFDFBA6B, // ذهبي افتراضي
      0xFFFFFFFF, // أبيض
      0xFF00E5FF, // سماوي برّاق
      0xFF00E676, // أخضر ناصع
      0xFFFFEA00, // أصفر برّاق
      0xFFFF4081, // وردي مبهج
      0xFFFF9100, // برتقالي زاهي
      0xFFE040FB, // بنفسجي
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC0D1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.05),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── رأس القسم ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.amber.withOpacity(0.15)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.touch_app_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'النص المتحرك الشاشة الرئيسية',
                  style: GoogleFonts.amiri(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── معاينة لون الخط والنص ────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Color(_homeDuaColor).withOpacity(0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '👁 معاينة الدعاء ولون الخط المختار:',
                        style: GoogleFonts.amiri(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _homeDuaTextCtrl.text.isNotEmpty
                            ? (_homeDuaTextCtrl.text.length > 80
                                  ? '${_homeDuaTextCtrl.text.substring(0, 80)}...'
                                  : _homeDuaTextCtrl.text)
                            : '• النص الافتراضي الأصلي (الأدعية والأذكار القديمة)',
                        // المعاينة بالخط والحجم واللون المختارين فعلاً (بحد أدنى
                        // 12 للقراءة على شاشة اللوحة نفسها)
                        style: _homeMarqueeFromFields().textStyle().copyWith(
                          fontSize: (_homeDuaFontSize < 12
                                  ? 12
                                  : _homeDuaFontSize)
                              .toDouble(),
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'الخط: $_homeDuaFont  •  الحجم: $_homeDuaFontSize  •  '
                        'السرعة: ${(_homeDuaIntervalMs / 1000).toStringAsFixed(1)} ثانية  •  '
                        '${_homeDuaEnabled ? (_homeDuaAfterMinutes == 0 ? "يظهر دائماً" : "بعد $_homeDuaAfterMinutes دقيقة") : "مُعطَّل"}',
                        style: GoogleFonts.amiri(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── لون الخط: يتبع أوقات الصلاة أو لون ثابت ──────────
                Text(
                  '🎨 لون الخط:',
                  style: GoogleFonts.amiri(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // الخيار المميّز: يتبع ألوان أوقات الصلاة
                GestureDetector(
                  onTap: () => setState(
                    () => _homeDuaColor =
                        HomeMarqueeSettings.followPrayerColorsValue,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _homeDuaColor ==
                              HomeMarqueeSettings.followPrayerColorsValue
                          ? const Color(0xFFDFBA6B).withOpacity(0.18)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _homeDuaColor ==
                                HomeMarqueeSettings.followPrayerColorsValue
                            ? const Color(0xFFDFBA6B)
                            : Colors.white.withOpacity(0.2),
                        width: _homeDuaColor ==
                                HomeMarqueeSettings.followPrayerColorsValue
                            ? 1.4
                            : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFFDFBA6B),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'تتبع ألوان أوقات الصلاة (الأفضل)',
                          style: GoogleFonts.amiri(
                            color: const Color(0xFFDFBA6B),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'أو اختر لوناً ثابتاً:',
                  style: GoogleFonts.amiri(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: availableColors.map((colorVal) {
                      final bool isSelected = _homeDuaColor == colorVal;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _homeDuaColor = colorVal;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 10),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            backgroundColor: Color(colorVal),
                            radius: 14,
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.black,
                                    size: 14,
                                  )
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── التحكم الكامل: التفعيل + الخط + الحجم + السرعة ────
                _buildMarqueeControls(),
                const SizedBox(height: 16),

                // ── مساحة لكتابة الدعاء الجديد ────────────────────────
                _buildField(
                  _homeDuaTextCtrl,
                  'مساحة لكتابة الدعاء الجديد (اتركها فارغة للأدعية الافتراضية — سطر لكل عبارة أو افصل بـ •)',
                  Icons.edit_note_rounded,
                  maxLines: 4,
                ),
                const SizedBox(height: 14),

                // ── أزرار التحكم ─────────────────────────────────
                // 1. زر إرسال الدعاء الجديد
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      'حفظ ونشر الإعدادات (لجميع الأجهزة)',
                      style: GoogleFonts.amiri(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: _publishHomeDua,
                  ),
                ),
                const SizedBox(height: 10),

                // 2 & 3. صف: زر العودة للوضع الأصلي + زر حذف الدعاء
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.lightBlueAccent,
                          side: BorderSide(
                            color: Colors.lightBlueAccent.withOpacity(0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.restore_rounded, size: 18),
                        label: Text(
                          'العودة للوضع الأصلي',
                          style: GoogleFonts.amiri(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _resetHomeDuaToDefault,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: BorderSide(
                            color: Colors.redAccent.withOpacity(0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.delete_forever_rounded,
                          size: 18,
                        ),
                        label: Text(
                          'حذف الدعاء',
                          style: GoogleFonts.amiri(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _deleteHomeDua,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ضوابط تنسيق النص المتحرك في هيدر شاشة الإعدادات:
  /// ── محرّر أحاديث الشريط العلوي في شاشة الإعدادات — مكوّن واحد مُنظَّم ──
  ///
  /// قائمة الأحاديث (إضافة/حذف) + **وقت الظهور** لكل حديث، ويُستعمل في
  /// تبويب «الرسائل» وفي «شاشة عن الموبايل» معاً (مصدر واحد لا نسختان).
  Widget _buildSettingsMarqueeEditor() {
    TextStyle labelStyle() => GoogleFonts.amiri(
      color: Colors.white70,
      fontSize: 13,
      fontWeight: FontWeight.bold,
    );

    final List<String> messages = _marqueeMessages;
    final bool canAdd =
        _marqueeCtrls.length < SettingsMarqueeSettings.maxMessages;
    final String firstPreview = messages.isEmpty
        ? ''
        : (messages.first.length > 50
              ? '${messages.first.substring(0, 50)}...'
              : messages.first);

    InputDecoration fieldDecoration(String label, IconData icon) =>
        InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.amiri(color: Colors.white38, fontSize: 13),
          prefixIcon: Icon(
            icon,
            color: Colors.amber.withOpacity(0.6),
            size: 20,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.amber),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.03),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📜 أحاديث/رسائل الشريط العلوي (تتقلّب واحداً بعد الآخر):',
          style: labelStyle(),
        ),
        const SizedBox(height: 4),
        Text(
          'كل حقل = حديث يظهر وحده في هيدر شاشة الإعدادات، ثم ينتقل إلى التالي.',
          style: GoogleFonts.amiri(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _marqueeCtrls.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _marqueeCtrls[i],
                  maxLines: 3,
                  style: GoogleFonts.amiri(color: Colors.white, fontSize: 14),
                  decoration: fieldDecoration(
                    i == 0
                        ? 'الحديث الأول (يظهر أولاً)'
                        : 'الحديث ${i + 1}',
                    i == 0 ? Icons.edit_rounded : Icons.menu_book_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _marqueeCtrls.length > 1
                    ? () => _removeMarqueeHadith(i)
                    : null,
                tooltip: 'حذف هذا الحديث',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canAdd ? _addMarqueeHadith : null,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'إضافة حديث',
                  style: GoogleFonts.amiri(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: BorderSide(color: Colors.amber.withOpacity(0.4)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_marqueeCtrls.length}/${SettingsMarqueeSettings.maxMessages}',
                style: GoogleFonts.amiri(color: Colors.white54, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── وقت الظهور بين حديث وآخر ────────────────────────────────
        Row(
          children: <Widget>[
            Text('⏱ وقت ظهور كل حديث:', style: labelStyle()),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _settingsMarqueeIntervalLabel,
                style: GoogleFonts.amiri(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: _settingsMarqueeIntervalMs.toDouble(),
          min: SettingsMarqueeSettings.minIntervalMs.toDouble(),
          max: SettingsMarqueeSettings.maxIntervalMs.toDouble(),
          divisions:
              (SettingsMarqueeSettings.maxIntervalMs -
                  SettingsMarqueeSettings.minIntervalMs) ~/
              500,
          label: _settingsMarqueeIntervalLabel,
          activeColor: Colors.amber,
          inactiveColor: Colors.white24,
          onChanged: (double v) => setState(
            () => _settingsMarqueeIntervalMs =
                SettingsMarqueeSettings.clampInterval(v.round()),
          ),
        ),
        if (messages.length > 1)
          Text(
            'يبدأ بـ«$firstPreview» ثم يتقلّب على ${messages.length - 1} حديثاً آخر.',
            style: GoogleFonts.amiri(color: Colors.white38, fontSize: 11),
            textDirection: TextDirection.rtl,
          ),
      ],
    );
  }

  /// «وقت الظهور» كما يُعرض في اللوحة.
  String get _settingsMarqueeIntervalLabel =>
      '${(_settingsMarqueeIntervalMs / 1000).toStringAsFixed(1)} ثانية';

  /// اللون + نوع الخط + حجم الخط (تُنشر مع النص عند الضغط على «نشر»).
  Widget _buildSettingsMarqueeStyleControls() {
    const List<int> colors = <int>[
      0xFFFFFFFF, // أبيض — الافتراضي فوق الهيدر الداكن
      0xFFDFBA6B, // ذهبي
      0xFF7FD4FF, // سماوي
      0xFF9FE870, // أخضر
    ];

    TextStyle labelStyle() => GoogleFonts.amiri(
      color: Colors.white70,
      fontSize: 13,
      fontWeight: FontWeight.bold,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── المعاينة الفعلية: النص بالخط والحجم واللون المختارين ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1220),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Color(_settingsMarqueeColor).withOpacity(0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '👁 معاينة الهيدر بالتنسيق المختار:',
                style: GoogleFonts.amiri(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _marqueeTextCtrl.text.isNotEmpty
                    ? ((_marqueeTextCtrl.text.length > 60)
                          ? '${_marqueeTextCtrl.text.substring(0, 60)}...'
                          : _marqueeTextCtrl.text)
                    : _defaultAllahNames,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
                // بحد أدنى 12 للقراءة على شاشة اللوحة نفسها
                style: SettingsMarqueeSettings(
                  color: _settingsMarqueeColor,
                  fontFamily: _settingsMarqueeFont,
                  fontSize: _settingsMarqueeFontSize < 12
                      ? 12
                      : _settingsMarqueeFontSize,
                ).textStyle(),
              ),
              const SizedBox(height: 6),
              Text(
                'الخط: $_settingsMarqueeFont  •  الحجم: $_settingsMarqueeFontSize',
                style: GoogleFonts.amiri(
                  color: Colors.white54,
                  fontSize: 11,
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── اللون ──
        Text('🎨 لون النص في الهيدر:', style: labelStyle()),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: colors.map((int colorVal) {
              final bool isSelected = _settingsMarqueeColor == colorVal;
              return GestureDetector(
                onTap: () => setState(() => _settingsMarqueeColor = colorVal),
                child: Container(
                  margin: const EdgeInsets.only(left: 10),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundColor: Color(colorVal),
                    radius: 14,
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.black, size: 14)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // ── نوع الخط ──
        Text('🔤 نوع الخط:', style: labelStyle()),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _settingsMarqueeFont,
              isExpanded: true,
              dropdownColor: const Color(0xFF12192B),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
              items: RemoteMessagingService.homeDuaFonts.map((String f) {
                return DropdownMenuItem<String>(
                  value: f,
                  child: Text(
                    f == 'Amiri' ? 'أميري (Amiri) — الافتراضي' : f,
                    style: HomeMarqueeSettings.googleFontStyle(f).copyWith(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? v) {
                if (v != null) setState(() => _settingsMarqueeFont = v);
              },
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── حجم الخط ──
        Row(
          children: [
            Text('📏 حجم الخط:', style: labelStyle()),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_settingsMarqueeFontSize',
                style: GoogleFonts.amiri(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: _settingsMarqueeFontSize.toDouble(),
          min: SettingsMarqueeSettings.minFontSize.toDouble(),
          max: SettingsMarqueeSettings.maxFontSize.toDouble(),
          divisions:
              SettingsMarqueeSettings.maxFontSize -
              SettingsMarqueeSettings.minFontSize,
          label: '$_settingsMarqueeFontSize',
          activeColor: Colors.amber,
          inactiveColor: Colors.white24,
          onChanged: (v) =>
              setState(() => _settingsMarqueeFontSize = v.round()),
        ),
      ],
    );
  }

  /// ضوابط النص المتحرك الكاملة: التفعيل + نوع الخط (أميري وغيره) + الحجم
  /// + سرعة التقليب + الخط العريض + وقت بداية الظهور بعد الأذان.
  Widget _buildMarqueeControls() {
    const List<int> baseAfterOptions = <int>[0, 5, 10, 15, 20, 30, 45, 60, 120];
    final List<int> afterOptions = <int>[...baseAfterOptions];
    if (!afterOptions.contains(_homeDuaAfterMinutes)) {
      afterOptions.add(_homeDuaAfterMinutes);
      afterOptions.sort();
    }

    TextStyle labelStyle() => GoogleFonts.amiri(
      color: Colors.white70,
      fontSize: 13,
      fontWeight: FontWeight.bold,
    );

    Widget boxed({required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );

    Widget sliderRow({
      required String title,
      required String valueLabel,
      required Widget slider,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: labelStyle()),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  valueLabel,
                  style: GoogleFonts.amiri(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          slider,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. تشغيل/إيقاف النص المتحرك ─────────────────────────────
        boxed(
          child: Row(
            children: [
              const Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.amber,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تشغيل النص المتحرك في الشاشة الرئيسية',
                  style: GoogleFonts.amiri(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Switch(
                value: _homeDuaEnabled,
                activeColor: Colors.amber,
                onChanged: (v) => setState(() => _homeDuaEnabled = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── 2. نوع الخط (أميري افتراضياً) ────────────────────────────
        Text('🔤 نوع الخط:', style: labelStyle()),
        const SizedBox(height: 6),
        boxed(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _homeDuaFont,
              isExpanded: true,
              dropdownColor: const Color(0xFF12192B),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
              items: RemoteMessagingService.homeDuaFonts.map((String f) {
                return DropdownMenuItem<String>(
                  value: f,
                  child: Text(
                    f == 'Amiri' ? 'أميري (Amiri) — الافتراضي' : f,
                    style: HomeMarqueeSettings.googleFontStyle(f).copyWith(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? v) {
                if (v != null) setState(() => _homeDuaFont = v);
              },
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── 3. حجم الخط ─────────────────────────────────────────────
        sliderRow(
          title: '📏 حجم الخط:',
          valueLabel: '$_homeDuaFontSize',
          slider: Slider(
            value: _homeDuaFontSize.toDouble(),
            min: HomeMarqueeSettings.minFontSize.toDouble(),
            max: HomeMarqueeSettings.maxFontSize.toDouble(),
            divisions:
                HomeMarqueeSettings.maxFontSize -
                HomeMarqueeSettings.minFontSize,
            label: '$_homeDuaFontSize',
            activeColor: Colors.amber,
            inactiveColor: Colors.white24,
            onChanged: (v) => setState(() => _homeDuaFontSize = v.round()),
          ),
        ),
        const SizedBox(height: 6),

        // ── 4. سرعة تقليب العبارات ──────────────────────────────────
        sliderRow(
          title: '⏱ سرعة التقليب:',
          valueLabel: '${(_homeDuaIntervalMs / 1000).toStringAsFixed(1)} ثانية',
          slider: Slider(
            value: _homeDuaIntervalMs.toDouble(),
            min: HomeMarqueeSettings.minIntervalMs.toDouble(),
            max: HomeMarqueeSettings.maxIntervalMs.toDouble(),
            divisions:
                (HomeMarqueeSettings.maxIntervalMs -
                    HomeMarqueeSettings.minIntervalMs) ~/
                200,
            label: '${(_homeDuaIntervalMs / 1000).toStringAsFixed(1)} ث',
            activeColor: Colors.amber,
            inactiveColor: Colors.white24,
            onChanged: (v) => setState(
              () => _homeDuaIntervalMs = HomeMarqueeSettings.clampInterval(
                v.round(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // ── 5. خط عريض ─────────────────────────────────────────────
        boxed(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'خط عريض (Bold)',
                  style: GoogleFonts.amiri(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Switch(
                value: _homeDuaBold,
                activeColor: Colors.amber,
                onChanged: (v) => setState(() => _homeDuaBold = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── 6. وقت بداية الظهور بعد الأذان ─────────────────────────
        Text('🕐 يبدأ الظهور بعد الأذان بـ:', style: labelStyle()),
        const SizedBox(height: 6),
        boxed(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _homeDuaAfterMinutes,
              isExpanded: true,
              dropdownColor: const Color(0xFF12192B),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
              items: afterOptions.map((int m) {
                return DropdownMenuItem<int>(
                  value: m,
                  child: Text(
                    m == 0 ? 'يظهر دائماً (بلا انتظار)' : '$m دقيقة',
                    style: GoogleFonts.amiri(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (int? v) {
                if (v != null) setState(() => _homeDuaAfterMinutes = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Tab 3: History ────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: _loadFromSupabase,
      color: Colors.amber,
      child: _recentBroadcasts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, color: Colors.white24, size: 60),
                  const SizedBox(height: 12),
                  Text(
                    'لا توجد رسائل بعد',
                    style: GoogleFonts.amiri(color: Colors.white38),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loadFromSupabase,
                    child: Text(
                      'تحميل من Supabase',
                      style: GoogleFonts.amiri(color: Colors.amber),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _recentBroadcasts.length,
              itemBuilder: (ctx, i) {
                final b = _recentBroadcasts[i];
                final createdAt = b['created_at'] != null
                    ? DateTime.tryParse(b['created_at'].toString())
                    : null;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.campaign_rounded,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              () {
                                String t = (b['title'] ?? '').toString().trim();
                                t = t
                                    .replaceAll(
                                      RegExp(r'^تنبيه(\s+هام)?[:\- ]*'),
                                      '',
                                    )
                                    .replaceAll('تنبيه', '')
                                    .trim();
                                return t.isNotEmpty ? t : 'رسالة بدون عنوان';
                              }(),
                              style: GoogleFonts.amiri(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () =>
                                _deleteBroadcast(b['id'].toString()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        b['message']?.toString() ?? '',
                        style: GoogleFonts.amiri(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          if ((b['target_city'] ?? '').toString().isNotEmpty)
                            _chip(
                              Icons.location_city_rounded,
                              b['target_city'].toString(),
                            ),
                          if ((b['target_uid'] ?? '').toString().isNotEmpty)
                            _chip(
                              Icons.person_pin_rounded,
                              b['target_uid'].toString(),
                            ),
                          // عداد المشاهدة
                          _chip(
                            Icons.visibility_rounded,
                            '${(b['views'] ?? 0).toString()} مشاهدة',
                          ),
                          if (createdAt != null)
                            _chip(
                              Icons.access_time_rounded,
                              '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.amber),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.amiri(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.15),
            Colors.teal.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_done_rounded,
            color: Colors.greenAccent,
            size: 28,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'متصل بـ Supabase ✓',
                style: GoogleFonts.amiri(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'الإصدار الحالي: ${_currentConfig?['latest_version'] ?? '-'}',
                style: GoogleFonts.amiri(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.amiri(
            color: Colors.amber,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: GoogleFonts.amiri(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.amiri(color: Colors.white38, fontSize: 13),
          prefixIcon: Icon(
            icon,
            color: Colors.amber.withOpacity(0.6),
            size: 20,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.amber),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.03),
        ),
      ),
    );
  }

  Widget _buildPublishBtn(
    String label,
    VoidCallback onPressed, {
    Color color = Colors.amber,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: color == Colors.amber ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 6,
        ),
        onPressed: _isLoading ? null : onPressed,
        icon: const Icon(Icons.cloud_upload_rounded),
        label: Text(
          label,
          style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  // ── Passcode screen ───────────────────────────────────────────────────────
  Widget _buildPasscodeScreen() {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.opaque,
      child: GlassScaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.amber,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'لوحة تحكم المسؤول',
                  style: GoogleFonts.amiri(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'أدخل الرمز السري للدخول',
                  style: GoogleFonts.amiri(fontSize: 14, color: Colors.white38),
                ),
                const SizedBox(height: 36),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: TextField(
                    autofocus: true,
                    controller: _passcodeCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••',
                      hintStyle: const TextStyle(
                        color: Colors.white24,
                        letterSpacing: 8,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Colors.amber,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                    ),
                    // إرسال تلقائي عند اكتمال 4 أرقام بدون setState
                    onChanged: (val) {
                      if (val.length == 4 && !_isAuthenticated) _tryLogin();
                    },
                    onSubmitted: (_) => _tryLogin(),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _tryLogin,
                      child: Text(
                        'دخول',
                        style: GoogleFonts.amiri(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _tryLogin() {
    if (_isLoading || _isAuthenticated) return;

    if (_correctPasscodes.contains(_passcodeCtrl.text)) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _isAuthenticated = true;
        _isLoading = true;
      });
      Future.microtask(() {
        _loadFromSupabase();
      });
    } else {
      _passcodeCtrl.clear();
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'الرقم السري خطأ!',
            style: GoogleFonts.amiri(),
            textAlign: TextAlign.center,
          ),
          backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        ),
      );
    }
  }
}
