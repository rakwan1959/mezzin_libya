import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'adhan_audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/glass_theme.dart';

/// لون التطبيق الرسمي (الذهبي) — يُستخدم لتمييز الإشعارات في شريط النظام
/// حتى تتطابق هوية الإشعارات مع هوية الواجهة نفسها.
const Color _kBrandGold = Color(0xFFDFBA6B);

/// خلفية بطاقة الإشعار في شريط النظام — **أسود**.
///
/// ⚠️ مهم: `color` وحده لا يُغيّر خلفية الإشعار إطلاقاً — إنه لون التمييز فقط.
/// تغيير الخلفية يحتاج `colorized: true` معه، وهو ما تفعله كل الإشعارات هنا،
/// ثم يُمرَّر هذا اللون إلى بطاقة RemoteViews المخصّصة فيكون خلفيةً فعليّة.
///
/// (والكحلي الملكي `#002855` باقٍ هوية التطبيق في الحوارات والتنبيهات داخل
/// الواجهة — التغيير هنا مقصور على بطاقة شريط الإشعارات.)
const Color _kNotifBlack = Color(0xFF000000);

/// ⏱ الحدّ الأدنى لمدة بقاء أي إشعار في شريط النظام — **4 دقائق** (240000ms).
///
/// القيمة تمرّ إلى `timeoutAfter` في الإضافة (وتُترجم إلى `setTimeoutAfter`
/// في أندرويد) فتُزيل الإشعار تلقائياً بعدها، وتُستخدم في **كل** مولّدات
/// الإشعارات هنا من هذا الثابت الواحد حتى لا يُكتب رقم أقلّ في أي إشعار جديد
/// بالخطأ. (إشعار الأذان في المسار الأصلي `AdhanForegroundService` مضبوط على
/// 10 دقائق، وهو أعلى من الحدّ فلا يصحّ عليه القيد.)
const int _kMinNotifTimeoutMs = 240000;

// ─── Channel IDs ──────────────────────────────────────────────────────────
// v9: إيقاف تشغيل الصوت من نظام الإشعارات لمنع الازدواجية مع AdhanForegroundService
const String _kAdhanAbdulbasetChannelId = 'muezzin_adhan_abdulbaset_v9';
const String _kAdhanMinshawiChannelId   = 'muezzin_adhan_minshawi_v9';
const String _kAdhanAlLuhaidanChannelId = 'muezzin_adhan_alluhaidan_v9';
const String _kAdhanMakkahChannelId     = 'muezzin_adhan_makkah_v9';
const String _kAdhanMadinahChannelId    = 'muezzin_adhan_madinah_v9';
const String _kAdhanSherifMostafaChannelId = 'muezzin_adhan_sherif_mostafa_v9';
const String _kAdhanHamdDeghrerChannelId = 'muezzin_adhan_hamd_deghrer_v9';
const String _kAdhanMohamedDokaleChannelId = 'muezzin_adhan_mohamed_dokale_v9';
const String _kAdhanSilentChannelId    = 'muezzin_adhan_silent_v8';
const String _kAdhanVibChannelId       = 'muezzin_adhan_vib_v8';
const String _kAlertsWithSoundChannelId = 'muezzin_alerts_sound_v8';
  const String _kRemindersChannelId      = 'muezzin_reminders_chan_v2';
const String _kBroadcastsChannelId     = 'muezzin_broadcasts_chan_v2';

/// معرّف إشعار «تجربة إشعار الصلاة» — ثابت حتى لا تتراكم إشعارات تجريبية
/// مكررة في شريط النظام عند تكرار الضغط على زر التجربة.
/// ─── بطاقة الإشعار المخصّصة (RemoteViews) ─────────────────────────────────
///
/// هذه الأسماء تشير إلى تخطيطات حقيقية في وحدة أندرويد:
/// `android/app/src/main/res/layout/notification_prayer_collapsed.xml`
/// و`..._expanded.xml`. الإضافة تصل إليها بالاسم وقت التشغيل (`getIdentifier`)
/// وتنفخها داخل عملية SystemUI، فترسم البطاقة الملوّنة بأنفسنا ولا يمكن للنظام
/// تجاهلها — بخلاف `colorized` وحده الذي لا يغيّر الخلفية بلا تخطيط مخصّص.
///
/// ⚠️ محميّة من تقليص الموارد في `res/raw/keep.xml`، فلا تُحذف في بناء release.
const String _kNotifLayoutCollapsed = 'notification_prayer_collapsed';
const String _kNotifLayoutExpanded = 'notification_prayer_expanded';
const String _kNotifLayoutIcon = 'ic_notif_mosque';

/// شريط التمييز داخل البطاقة — ذهبي التطبيق.
const Color _kNotifAccent = _kBrandGold;

/// بصمة بناء بطاقة الإشعار — تُعرض في الإعدادات **وداخل** إشعار التجربة
/// (في تذييل البطاقة الموسّعة)، فتثبت في نظرة واحدة أيّ بناء مثبّت على
/// الجهاز فعلاً. وُجدت لأن إشكالات الإشعارات السابقة كان يختلط فيها البناء
/// المثبَّت بالبناء المبني. تُحدَّث يدوياً مع كل تغيير في شكل البطاقة.
const String kNotificationCardStamp =
    'بطاقة مخصصة · targetSdk 30 · خلفية سوداء · إطار أبيض · مسجد جديد';

const int _kTestNotificationId = 990099;

/// دورة ألوان زر التجربة — نفس ترتيب شاشة المواقيت تماماً.
/// كل ضغطة تُطلق إشعار الصلاة التالية في هذا الترتيب بلونها الخاص.
const List<String> _kTestPrayerCycle = <String>[
  'الفجر',
  'الشروق',
  'الظهر',
  'العصر',
  'المغرب',
  'العشاء',
];

/// معالج استجابة الإشعارات في الخلفية (top-level إلزامي)
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) async {
  debugPrint('NotificationService [BG]: actionId=${response.actionId}, payload=${response.payload}');
  
  if (response.actionId == 'stop_adhan') {
    // نوقف المشغل الصوتي
    await AdhanAudioService().stop();
    
    final ns = NotificationService();
    if (response.id != null) {
      final int id = response.id!;
      // حساب المعرف الأساسي (للأذان) سواء كان الإشعار الحالي أذان أو تذكير
      int baseId;
      int subId = id % 1000;
      if (subId >= 100) {
        baseId = (id ~/ 1000) * 1000 + (subId % 100);
      } else {
        baseId = id;
      }

      // إلغاء باقة الإشعارات المرتبطة بهذه الصلاة
      await ns.cancelNotification(id: baseId);       // الأذان
      await ns.cancelNotification(id: baseId + 100); // تذكير 5 د
      await ns.cancelNotification(id: baseId + 145); // تذكير صلاة الجمعة 45 د
      await ns.cancelNotification(id: baseId + 200); // دعاء 10 د
      await ns.cancelNotification(id: baseId + 300); // تذكير بعد
      await ns.cancelNotification(id: baseId + 400); // تنبيه حان وقت الصلاة
      await ns.cancelNotification(id: baseId + 500); // إعلان صوتي
      await ns.cancelNotification(id: baseId + 600); // دعاء ما بعد الأذان
    }
    // إيقاف أي أذان نشط آخر (احتياطاً)
    await ns.stopActiveAdhan();
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // يتتبع آخر ID أذان نُجدوِل (لإيقافه عند الضغط)
  final Map<int, DateTime> _scheduledPrayerTimes = {};

  /// مؤشر دورة ألوان الصلوات في زر التجربة — يتقدّم مع كل ضغطة.
  int _testCycleIndex = 0;

  // ──────────────────────────────────────────────────────────────────────────
  // التهيئة
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Tripoli'));
    }

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notif_mosque'), // مسجد أبيض نقّي — لا شعار ملوّن
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onForeground,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    if (Platform.isAndroid) {
      final impl = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (impl != null) {
        await impl.requestExactAlarmsPermission();
        await _createChannels(impl);
      }
    }

    // ── تنظيف فوري عند فتح التطبيق ────────────────────────────────────────
    // أندرويد يُبقي الإشعارات/المنبهات المجدولة من النسخ السابقة حيّة في النظام
    // حتى بعد تثبيت التحديث. نمسحها هنا لحظة فتح التطبيق فيُعاد جدولتها
    // بالتصميم الجديد فقط (بلا إشعارات قديمة عالقة بالشكل القديم).
    try {
      await _plugin.cancelAll();
      _scheduledPrayerTimes.clear();
      debugPrint('NotificationService: cleared stale notifications on init');
    } catch (e) {
      debugPrint('NotificationService: could not clear stale notifications: $e');
    }

    debugPrint('NotificationService: initialized');
  }

  Future<void> _createChannels(AndroidFlutterLocalNotificationsPlugin impl) async {
    // حذف القنوات القديمة لمنع تداخل الصوت القديم المجدول في نظام الأندرويد
    try {
      await impl.deleteNotificationChannel(channelId: 'muezzin_adhan_abdulbaset_v8');
      await impl.deleteNotificationChannel(channelId: 'muezzin_adhan_minshawi_v8');
      await impl.deleteNotificationChannel(channelId: 'muezzin_adhan_alluhaidan_v1');
      await impl.deleteNotificationChannel(channelId: 'muezzin_adhan_makkah_v1');
      await impl.deleteNotificationChannel(channelId: 'muezzin_adhan_madinah_v1');
    } catch (_) {}

    // Channel الأذان: صوت عبد الباسط (إشعار بصري فقط - الصوت يُشغّل حصراً عبر AdhanForegroundService)
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      _kAdhanAbdulbasetChannelId,
      'الأذان (عبد الباسط)',
      description: 'إشعارات الأذان (عبد الباسط)',
      importance: Importance.max,
      playSound: false,
      enableVibration: false,
      enableLights: true,
      showBadge: true,
    ));

    // Channel الأذان: صوت المنشاوي
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      _kAdhanMinshawiChannelId,
      'الأذان (المنشاوي)',
      description: 'إشعارات الأذان (المنشاوي)',
      importance: Importance.max,
      playSound: false,
      enableVibration: false,
      enableLights: true,
      showBadge: true,
    ));

    // Channel الأذان: صوت محمد اللحيدان
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      _kAdhanAlLuhaidanChannelId,
      'الأذان (محمد اللحيدان)',
      description: 'إشعارات الأذان (محمد اللحيدان)',
      importance: Importance.max,
      playSound: false,
      enableVibration: false,
      enableLights: true,
      showBadge: true,
    ));

    // Channel الأذان: أذان الحرم المكي
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      _kAdhanMakkahChannelId,
      'الأذان (الحرم المكي)',
      description: 'إشعارات الأذان (الحرم المكي)',
      importance: Importance.max,
      playSound: false,
      enableVibration: false,
      enableLights: true,
      showBadge: true,
    ));

    // Channel الأذان: أذان المدينة المنورة
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      _kAdhanMadinahChannelId,
      'الأذان (المدينة المنورة)',
      description: 'إشعارات الأذان (المدينة المنورة)',
      importance: Importance.max,
      playSound: false,
      enableVibration: false,
      enableLights: true,
      showBadge: true,
    ));

    // Channel الأذان: حمد دغرير
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      _kAdhanHamdDeghrerChannelId,
      'الأذان (حمد دغرير)',
      description: 'إشعارات الأذان (حمد دغرير)',
      importance: Importance.max,
      playSound: false,
      enableVibration: false,
      enableLights: true,
      showBadge: true,
    ));

    // Channel الأذان: شريف مصطفى
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      _kAdhanSherifMostafaChannelId,
      'الأذان (شريف مصطفى)',
      description: 'إشعارات الأذان (شريف مصطفى)',
      importance: Importance.max,
      playSound: false,
      enableVibration: false,
      enableLights: true,
      showBadge: true,
    ));

    // Channel الأذان: محمد الدوكالي
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      _kAdhanMohamedDokaleChannelId,
      'الأذان (محمد الدوكالي)',
      description: 'إشعارات الأذان (محمد الدوكالي)',
      importance: Importance.max,
      playSound: false,
      enableVibration: false,
      enableLights: true,
      showBadge: true,
    ));

    // Channel الأذان: اهتزاز فقط
    await impl.createNotificationChannel(AndroidNotificationChannel(
      _kAdhanVibChannelId,
      'الأذان (اهتزاز)',
      description: 'إشعارات الأذان (مع اهتزاز)',
      importance: Importance.max,
      playSound: false,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]),
      enableLights: true,
      showBadge: true,
    ));

    // Channel الأذان: صامت
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      _kAdhanSilentChannelId,
      'الأذان (صامت)',
      description: 'إشعارات الأذان (صامت)',
      importance: Importance.max,
      playSound: false,
      enableVibration: false,
      enableLights: true,
      showBadge: true,
    ));

    // Channel التنبيهات الصوتية: (حان وقت صلاة...)
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      _kAlertsWithSoundChannelId,
      'الأذان (صوت)',
      description: 'تنبيهات "حان وقت الصلاة" والرسائل الصوتية',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));

    // ترقية لمرة واحدة: حذف قناة التذكيرات القديمة التي كانت تحمل اسم
    // "أوقات الصلاة" (سبب تكرار العبارة في إشعارات قبل/بعد الأذان)
    // وإعادة إنشائها بالاسم الصحيح حتى يظهر العنوان مرة واحدة فقط.
    try {
      final prefs = await SharedPreferences.getInstance();
      final channelRenamed = prefs.getBool('reminders_channel_renamed_v3') ?? false;
      if (!channelRenamed) {
        await impl.deleteNotificationChannel(channelId: _kRemindersChannelId);
        await prefs.setBool('reminders_channel_renamed_v3', true);
      }
    } catch (_) {}

    // ترقية لمرة واحدة: حذف قنوات الأذان القديمة التي كانت تحمل اسم
    // "أوقات الصلاة" في رأس الإشعار (سبب تكرار العبارة في إشعار "حان الآن
    // موعد أذان صلاة") وإعادة إنشائها بالاسم الصحيح "الأذان (المؤذن)".
    try {
      final prefs = await SharedPreferences.getInstance();
      final adhanRenamed = prefs.getBool('adhan_channels_renamed_v4') ?? false;
      if (!adhanRenamed) {
        await impl.deleteNotificationChannel(channelId: _kAdhanAbdulbasetChannelId);
        await impl.deleteNotificationChannel(channelId: _kAdhanMinshawiChannelId);
        await impl.deleteNotificationChannel(channelId: _kAdhanAlLuhaidanChannelId);
        await impl.deleteNotificationChannel(channelId: _kAdhanMakkahChannelId);
        await impl.deleteNotificationChannel(channelId: _kAdhanMadinahChannelId);
        await impl.deleteNotificationChannel(channelId: _kAdhanVibChannelId);
        await impl.deleteNotificationChannel(channelId: _kAdhanSilentChannelId);
        await impl.deleteNotificationChannel(channelId: _kAlertsWithSoundChannelId);
        await prefs.setBool('adhan_channels_renamed_v4', true);
      }
    } catch (_) {}

    // Channel التذكيرات: أولوية عالية، صوت افتراضي
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      _kRemindersChannelId,
      'تذكيرات إسلامية',
      description: 'تذكيرات الأذكار والصيام والمناسبات',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    ));

    // Channel الرسائل الإدارية: صوت مخصص، أولوية قصوى
    await impl.createNotificationChannel(const AndroidNotificationChannel(
      _kBroadcastsChannelId,
      'رسائل الإدارة',
      description: 'أخبار وتحديثات هامة من إدارة التطبيق',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('admin_notification'),
      enableVibration: true,
      enableLights: true,
      showBadge: true,
    ));

    debugPrint('NotificationService: channels created');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // معالج الإشعارات في المقدمة
  // ──────────────────────────────────────────────────────────────────────────
  void _onForeground(NotificationResponse response) async {
    debugPrint('NotificationService [FG]: actionId=${response.actionId}');
    if (response.actionId == 'stop_adhan') {
      await stopActiveAdhan();
      if (response.id != null) {
        await _plugin.cancel(id: response.id!);
        await _plugin.cancel(id: response.id! + 100);
        await _plugin.cancel(id: response.id! + 145);
        await _plugin.cancel(id: response.id! + 200);
        await _plugin.cancel(id: response.id! + 300);
        await _plugin.cancel(id: response.id! + 400);
        await _plugin.cancel(id: response.id! + 500);
        await _plugin.cancel(id: response.id! + 600);
        await _plugin.cancel(id: response.id! + 700);
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // الصلاحيات
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> requestPermissions() async {
    if (!Platform.isAndroid) return;
    await Permission.notification.request();
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // جدولة الإشعارات
  // ──────────────────────────────────────────────────────────────────────────

  /// جدولة إشعار أذان (بصري + صوت/اهتزاز عبر نظام التشغيل)
  Future<void> schedulePrayerNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? prayerName, // أضفنا اسم الصلاة كمعامل صريح
    String? sound,
    String adhanMode = 'sound',
    bool duaEnabled = true,
    int duaOffsetMinutes = 5,
    bool remBeforeAdhan = false,
    int beforeAdhanOffset = 5,
    bool remAfterAdhan = true,
    int afterAdhanOffset = 10,
    bool showVisual = true,
  }) async {
    // ملاحظة مهمة: لا نُرجع مبكراً إذا كان وقت الأذان قد مضى — تذكير
    // «مضى على أذان صلاة ... 10 دقائق» قد يكون لا يزال في المستقبل
    // ويجب إعادة جدولته عند إعادة الجدولة وإلا فُقد للأبد.
    if (adhanMode == 'silent' && !showVisual) return;

    final bool vibrate = adhanMode == 'vibration';
    final bool silent = adhanMode == 'silent';
    final String normalizedSound = (sound == 'abdulbasit' || sound == null)
        ? 'abdulbaset'
        : (sound == 'alharm_almakke' || sound == 'Alharm_Almakke')
            ? 'makkah'
            : sound;
    final String soundName = ['abdulbaset', 'minshawi', 'al_luhaidan', 'makkah', 'madinah', 'sherif_mostafa', 'hamd_deghrer', 'mohamed_dokale'].contains(normalizedSound)
        ? normalizedSound 
        : 'abdulbaset';


    String targetChannelId;
    if (silent) {
      targetChannelId = _kAdhanSilentChannelId;
    } else if (vibrate) {
      targetChannelId = _kAdhanVibChannelId;
    } else {
      if (soundName == 'minshawi') targetChannelId = _kAdhanMinshawiChannelId;
      else if (soundName == 'al_luhaidan') targetChannelId = _kAdhanAlLuhaidanChannelId;
      else if (soundName == 'makkah') targetChannelId = _kAdhanMakkahChannelId;
      else if (soundName == 'madinah') targetChannelId = _kAdhanMadinahChannelId;
      else if (soundName == 'sherif_mostafa') targetChannelId = _kAdhanSherifMostafaChannelId;
      else if (soundName == 'hamd_deghrer') targetChannelId = _kAdhanHamdDeghrerChannelId;
      else if (soundName == 'mohamed_dokale') targetChannelId = _kAdhanMohamedDokaleChannelId;
      else targetChannelId = _kAdhanAbdulbasetChannelId;
    }

    final String cleanPrayerName = prayerName ?? 
        (body.contains('صلاة ') ? body.split('صلاة ').last.trim() : (title.contains('صلاة ') ? title.split('صلاة ').last.trim() : ''));
    final String adhanBody = cleanPrayerName.isNotEmpty
        ? 'حان الآن موعد أذان صلاة $cleanPrayerName'
        : (body.isNotEmpty ? body : 'حان الآن موعد أذان الصلاة');

    // ── الإشعار الرئيسي (بصري + اهتزاز) ──────────────────────────────────
    // على Android عند وضع الصوت، AdhanForegroundService يتكفل بإظهار الإشعار الأمامي المفرد لمنع التكرار والازدواجية
    // (يُجدوَل فقط إذا كان وقت الأذان لم يحن بعد)
    if (scheduledTime.isAfter(DateTime.now()) &&
        (showVisual || vibrate) && !(Platform.isAndroid && adhanMode == 'sound')) {
      await _safeSchedule(
        id: id,
        title: cleanPrayerName.isNotEmpty ? 'صلاة $cleanPrayerName' : 'أوقات الصلاة',
        body: adhanBody,
        scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
        details: NotificationDetails(
          android: AndroidNotificationDetails(
            targetChannelId,
            'الأذان',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            fullScreenIntent: true,
            ticker: 'أذان',
            // ── خلفية الإشعار: كحلي ملكي (Royal Navy) ──
            // `colorized: true` يجعل اللون أعلاه **خلفية الإشعار نفسها** في شريط
            // النظام، لا مجرد لون تمييز — فبهذا فقط يطابق الإشعار هوية التطبيق.
            color: _kNotifBlack,
            colorized: true,
            ledColor: _getPrayerColor(cleanPrayerName), // وميض بلون وقت الصلاة
            // ── البطاقة المخصّصة: هي التي تُلوّن خلفية الإشعار فعلاً ──
            customLayout: _kNotifLayoutCollapsed,
            customBigLayout: _kNotifLayoutExpanded,
            customLayoutIcon: _kNotifLayoutIcon,
            customLayoutAccent: _kNotifAccent,
            customLayoutBadge: _formatClock(scheduledTime),
            // لا تذييل هنا عن قصد: هذا الإشعار (وضع الاهتزاز/الصامت) بلا أي
            // إجراء مربوط، فلا نوعد المستخدم بزر إيقاف غير موجود. بطاقة الأذان
            // الحقيقية بزرّها تُبنى في مسار AdhanForegroundService الأصلي.
            ledOnMs: 1000,
            ledOffMs: 500,
            playSound: false,
            sound: null,
            enableVibration: false,
            visibility: NotificationVisibility.public,
            ongoing: true, // تبقى في أعلى الإشعارات
            timeoutAfter: _kMinNotifTimeoutMs, // 4 دقائق كحدّ أدنى
            actions: adhanMode == 'sound' ? [
              const AndroidNotificationAction(
                'stop_adhan',
                'إيقاف الأذان',
                showsUserInterface: true,
                cancelNotification: true,
              ),
            ] : null,
            styleInformation: BigTextStyleInformation(
              adhanBody,
              htmlFormatBigText: false,
              summaryText: null,
              htmlFormatSummaryText: false,
            ),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: !silent && !vibrate,
            sound: (!silent && !vibrate) ? '$soundName.caf' : null,
            interruptionLevel: InterruptionLevel.critical,
          ),
        ),
        payload: 'adhan:$soundName',
      );
      if (id % 1000 >= 1 && id % 1000 <= 5) _scheduledPrayerTimes[id] = scheduledTime;
    }

    // ── تذكير قبل الأذان بـ 5 دقائق ───────────────────────────────────
    if (remBeforeAdhan) {
      final beforeTime = scheduledTime.subtract(Duration(minutes: beforeAdhanOffset));
      if (beforeTime.isAfter(DateTime.now())) {
        final displayBody = 'بقي على أذان صلاة $cleanPrayerName $beforeAdhanOffset دقائق';
        final notifTitle = cleanPrayerName.isNotEmpty ? 'صلاة $cleanPrayerName' : 'تذكير قبل الأذان';
        await _safeSchedule(
          id: id + 100,
          title: notifTitle,
          body: displayBody,
          scheduledDate: tz.TZDateTime.from(beforeTime, tz.local),
          details: _beforeAdhanReminderDetails(
            displayBody,
            title: notifTitle,
            badge: _formatClock(beforeTime),
            footer: 'قبل الأذان بـ $beforeAdhanOffset دقائق',
          ),
        );
      }
    }

    // ── تذكير صلاة الجمعة قبل الأذان بـ 45 دقيقة (يوم الجمعة فقط لصلاة الظهر/الجمعة) ──
    if (scheduledTime.weekday == DateTime.friday && (cleanPrayerName == 'الظهر' || (id % 1000) == 2)) {
      final prefs = await SharedPreferences.getInstance();
      final bool remFriday = prefs.getBool('rem_friday_prayer') ?? true;
      if (remFriday) {
        final fridayTime = scheduledTime.subtract(const Duration(minutes: 45));
        if (fridayTime.isAfter(DateTime.now())) {
          const fridayBody = 'بقي على صلاة الجمعة 45 دقيقة';
          await _safeSchedule(
            id: id + 145,
            title: 'صلاة الجمعة',
            body: fridayBody,
            scheduledDate: tz.TZDateTime.from(fridayTime, tz.local),
            details: _reminderDetails(
              fridayBody,
              'صلاة الجمعة',
              badge: _formatClock(fridayTime),
              footer: 'قبل صلاة الجمعة 45 دقيقة',
            ),
          );
        }
      }
    }

    // ── إشعار الآية القرآنية/النص المخصص قبل الأذان بـ15 دقيقة ─────────
    final memorialTime = scheduledTime.subtract(const Duration(minutes: 15));
    if (memorialTime.isAfter(DateTime.now())) {
      final prefs = await SharedPreferences.getInstance();
      final customText = prefs.getString('remote_dua_custom_text');
      
      // تم إزالة رسالة الإهداء الافتراضية بناءً على طلب المستخدم
      if (customText != null && customText.isNotEmpty) {
        await _safeSchedule(
          id: id + 200,
          title: '',
          body: customText,
          scheduledDate: tz.TZDateTime.from(memorialTime, tz.local),
          details: _memorialDuaDetails(
            customText,
            '',
            badge: _formatClock(memorialTime),
            footer: 'قبل الأذان بـ 15 دقيقة',
          ),
        );
      }
    }

    // ── تذكير بعد الأذان ──────────────────────────────────────────────────
    if (remAfterAdhan) {
      final afterTime = scheduledTime.add(Duration(minutes: afterAdhanOffset));
      if (afterTime.isAfter(DateTime.now())) {
        final msg = 'مضى على أذان صلاة $cleanPrayerName $afterAdhanOffset دقائق';
        final notifTitle = cleanPrayerName.isNotEmpty ? 'صلاة $cleanPrayerName' : 'تذكير بعد الأذان';
        await _safeSchedule(
          id: id + 300,
          title: notifTitle,
          body: msg,
          scheduledDate: tz.TZDateTime.from(afterTime, tz.local),
          details: _afterAdhanReminderDetails(
            msg,
            title: notifTitle,
            badge: _formatClock(afterTime),
            footer: 'بعد الأذان بـ $afterAdhanOffset دقائق',
          ),
        );
      }
    }

  }

  /// جدولة تذكير عام (أذكار / صيام / مناسبات)
  Future<void> scheduleGeneralReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) return;
    await _safeSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
      details: _reminderDetails(
        body,
        title,
        timeoutMs: _kMinNotifTimeoutMs,
        badge: _formatClock(scheduledTime),
      ),
    );
  }

  /// ── إشعار صلاة تجريبي فوري (دورة ألوان المواقيت الست) ────────────────
  /// كل ضغطة تُطلق إشعار الصلاة **التالية** في ترتيب المواقيت
  /// (الفجر ← الشروق ← الظهر ← العصر ← المغرب ← العشاء ← الفجر…)، فيرى
  /// المستخدم كل لون صلاة في سياقه الحقيقي داخل شريط النظام بلا انتظار.
  ///
  /// يستخدم نفس قناة الأذان ونفس المقاييس ونفس البطاقة المخصّصة، وبتصميم
  /// موحّد مع بقيّة الإشعارات: خلفية **كحلية ملكية** ونص أبيض بخط أميري في
  /// كل الصلوات — بلا استثناء. ويبقى وميض الـ LED بلون الصلاة ليتميّز كل وقت.
  ///
  /// بلا صوت وبلا اهتزاز وبلا شاشة كاملة عن قصد: معاينة بصرية بحتة، ويقفل
  /// نفسه بعد دقيقة إن لم يمسحه المستخدم.
  ///
  /// تُرجع اسم الصلاة التي عُرضت ليُعلنها الزر للمستخدم.
  Future<String> showTestPrayerNotification({String? prayerName}) async {
    final String name = prayerName ??
        _kTestPrayerCycle[_testCycleIndex % _kTestPrayerCycle.length];
    _testCycleIndex = (_testCycleIndex + 1) % _kTestPrayerCycle.length;

    final Color prayerColor = GlassPalette.forPrayerName(name);
    final String body = 'حان الآن موعد أذان صلاة $name';

    await _plugin.show(
      id: _kTestNotificationId,
      title: 'صلاة $name',
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _kAdhanAbdulbasetChannelId,
          'الأذان',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          ticker: 'أذان',
          // التجربة **بنفس** بطاقة الإشعارات الحقيقية: خلفية سوداء موحّدة،
          // فيرى المستخدم تماماً ما سيصل وقت الصلاة بلا أي مفاجأة.
          color: _kNotifBlack,
          colorized: true,
          ledColor: prayerColor, // وميض بلون الصلاة يبقى للتمييز بين الأوقات
          customLayout: _kNotifLayoutCollapsed,
          customBigLayout: _kNotifLayoutExpanded,
          customLayoutIcon: _kNotifLayoutIcon,
          customLayoutAccent: _kNotifAccent,
          customLayoutBadge: _formatClock(DateTime.now()),
          customLayoutFooter: kNotificationCardStamp,
          ledOnMs: 1000,
          ledOffMs: 500,
          playSound: false,
          sound: null,
          enableVibration: false,
          visibility: NotificationVisibility.public,
          ongoing: false,
          timeoutAfter: _kMinNotifTimeoutMs, // 4 دقائق كحدّ أدنى (كانت دقيقة)
          styleInformation: BigTextStyleInformation(
            body,
            htmlFormatBigText: false,
            summaryText: null,
            htmlFormatSummaryText: false,
          ),
        ),
      ),
    );
    return name;
  }

  NotificationDetails _reminderDetails(String body, String title,
      {int timeoutMs = _kMinNotifTimeoutMs, String? badge, String? footer}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _kRemindersChannelId,
        'تذكيرات إسلامية',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        enableVibration: true,
        ongoing: false,
        timeoutAfter: timeoutMs,
        color: _kNotifBlack, // خلفية سوداء موحّدة لكل رسائل التذكير
        colorized: true, // يجعل اللون خلفية الإشعار لا لون تمييز فقط
        customLayout: _kNotifLayoutCollapsed,
        customBigLayout: _kNotifLayoutExpanded,
        customLayoutIcon: _kNotifLayoutIcon,
        customLayoutAccent: _kNotifAccent,
        customLayoutBadge: badge,
        customLayoutFooter: footer,
        // شعار التطبيق يظهر في إشعارات التذكيرات (ومنها أذكار الصباح والمساء)
        // كما يظهر في إشعارات الأذان — نفس notif_logo.png
        largeIcon: const DrawableResourceAndroidBitmap('notif_logo'),
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          summaryText: null,
          htmlFormatSummaryText: false,
        ),
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );
  }

  // ── تذكير قبل الأذان بـ 5 دقائق ──────────────────────────────────────
  NotificationDetails _beforeAdhanReminderDetails(String body,
      {String title = 'تذكير قبل الأذان', String? badge, String? footer}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _kRemindersChannelId,
        'تذكيرات إسلامية',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        enableVibration: true,
        ongoing: true,
        timeoutAfter: _kMinNotifTimeoutMs,
        color: _kNotifBlack,
        colorized: true, // خلفية كحلية ملكية
        customLayout: _kNotifLayoutCollapsed,
        customBigLayout: _kNotifLayoutExpanded,
        customLayoutIcon: _kNotifLayoutIcon,
        customLayoutAccent: _kNotifAccent,
        customLayoutBadge: badge,
        customLayoutFooter: footer,
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          summaryText: null,
          htmlFormatSummaryText: false,
        ),
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );
  }

  // ── تذكير بعد الأذان ──────────────────────────────────────────────────
  NotificationDetails _afterAdhanReminderDetails(String body,
      {String title = 'تذكير بعد الأذان', String? badge, String? footer}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _kRemindersChannelId,
        'دعاء',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        enableVibration: true,
        ongoing: true,
        timeoutAfter: _kMinNotifTimeoutMs,
        color: _kNotifBlack,
        colorized: true, // خلفية كحلية ملكية
        customLayout: _kNotifLayoutCollapsed,
        customBigLayout: _kNotifLayoutExpanded,
        customLayoutIcon: _kNotifLayoutIcon,
        customLayoutAccent: _kNotifAccent,
        customLayoutBadge: badge,
        customLayoutFooter: footer,
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          summaryText: null,
          htmlFormatSummaryText: false,
        ),
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );
  }

  NotificationDetails _memorialDuaDetails(String body, String title,
      {String? badge, String? footer}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _kRemindersChannelId,
        'دعاء',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        enableVibration: true,
        ongoing: true,
        timeoutAfter: _kMinNotifTimeoutMs,
        color: _kNotifBlack,
        colorized: true, // خلفية كحلية ملكية
        customLayout: _kNotifLayoutCollapsed,
        customBigLayout: _kNotifLayoutExpanded,
        customLayoutIcon: _kNotifLayoutIcon,
        customLayoutAccent: _kNotifAccent,
        customLayoutBadge: badge,
        customLayoutFooter: footer,
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          summaryText: null,
          htmlFormatSummaryText: false,
        ),
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // دوال مساعدة
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _safeSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    String? payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      debugPrint('NotificationService: scheduled id=$id at $scheduledDate');
    } catch (e) {
      debugPrint('NotificationService: exact failed id=$id, trying inexact: $e');
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      } catch (e2) {
        debugPrint('NotificationService: inexact also failed id=$id: $e2');
      }
    }
  }

  Future<void> cancelNotification({required int id}) async {
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
    _scheduledPrayerTimes.clear();
  }

  /// عدد الإشعارات المجدولة حالياً في نظام التشغيل — قراءة فقط.
  ///
  /// تُستهلك في أداة التشخيص المخفية في الإعدادات، فتُظهر للمطوّر فوراً هل
  /// ما زالت إشعارات المواقيت مُجدولة في النظام أم لا (وهو أول ما يُفقده
  /// الجهاز بعد قتل التطبيق أو تغيير إعدادات البطارية).
  Future<int> pendingNotificationsCount() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (e) {
      debugPrint('NotificationService: pendingNotificationsCount error: $e');
      return 0;
    }
  }

  /// إيقاف الأذان النشط (صوت + إشعار)
  Future<void> stopActiveAdhan() async {
    AdhanAudioService().stop();
    final now = DateTime.now();
    final toCancel = <int>[];
    _scheduledPrayerTimes.forEach((id, time) {
      if (now.difference(time).inMinutes >= 0 && now.difference(time).inMinutes <= 10) {
        toCancel.add(id);
      }
    });
    for (final id in toCancel) {
      await cancelNotification(id: id);
      _scheduledPrayerTimes.remove(id);
    }
  }

  /// إظهار إشعار تجريبي للتحقق من الوقت والبقاء والإخفاء التلقائي
  /// يظهر بعد 5 ثوانٍ من الضغط ويختفي بعد 4 دقائق تلقائياً
void clearScheduledTimes() => _scheduledPrayerTimes.clear();
  /// لون وقت الصلاة — يُقرأ من [GlassPalette] نفسه المستخدم في الواجهة،
  /// فتأتي إشعارات النظام بلون الصلاة الموافق تماماً لِلونها داخل التطبيق
  /// (كانت هناك ألوان مستقلة هنا تختلف عن ألوان الشاشة).
  /// تنسيق الساعة بالعربية 12 ساعة — يُعرض في طرف بطاقة الإشعار.
  /// مثال: `5:42 م` — بلا أي اعتماد على حزمة إضافية.
  String _formatClock(DateTime time) {
    final int hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final String minute = time.minute.toString().padLeft(2, '0');
    final String period = time.hour < 12 ? 'ص' : 'م';
    return '$hour12:$minute $period';
  }

  Color _getPrayerColor(String? prayerName) {
    if (prayerName == null || prayerName.trim().isEmpty) return _kBrandGold;
    final color = GlassPalette.forPrayerName(prayerName.trim());
    // الأبيض هو القيمة الاحتياطية للواجهة، لكنه غير مناسب لأيقونة إشعار
    // في شريط النظام — نستبدله بذهبي التطبيق.
    if (color == Colors.white) return _kBrandGold;
    return color;
  }
}
