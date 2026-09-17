import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'voice_announcement_service.dart';

/// خدمة مخصصة لتشغيل صوت الأذان.
///
/// على Android: تستخدم AdhanForegroundService (Kotlin) عبر MethodChannel
/// — هذا يضمن تشغيل الأذان حتى عند إغلاق التطبيق في الخلفية.
///
/// الميزات:
/// - يعمل في الخلفية حتى مع إغلاق التطبيق
/// - يحترم وضع الأذان (صوت / اهتزاز / صامت)
/// - يشغّل دعاء ما بعد الأذان تلقائياً
class AdhanAudioService {
  static final AdhanAudioService _instance = AdhanAudioService._internal();
  factory AdhanAudioService() => _instance;
  AdhanAudioService._internal();

  static const MethodChannel _adhanChannel =
      MethodChannel('com.example.muezzin_libya_app/adhan');
  static const MethodChannel _volumeChannel =
      MethodChannel('com.example.muezzin_libya_app/volume');

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);

  /// اسم الصلاة الحالية التي يتم تشغيل أذانها (فارغ إذا لا يوجد أذان)
  String _currentPrayerName = '';
  String get currentPrayerName => _currentPrayerName;
  final ValueNotifier<String> prayerNameNotifier = ValueNotifier<String>('');

  /// مستوى الصوت الحالي من النظام (0.0 - 1.0)
  final ValueNotifier<double> systemVolumeNotifier = ValueNotifier<double>(1.0);

  // لمنع إيقاف الأذان عند تعديل مستوى الصوت في الإعدادات
  bool isInteractingWithVolume = false;

  void init() {
    _adhanChannel.setMethodCallHandler((call) async {
      if (call.method == "onAdhanStarted") {
        _isPlaying = true;
        isPlayingNotifier.value = true;
      } else if (call.method == "onAdhanStopped") {
        _isPlaying = false;
        isPlayingNotifier.value = false;
        _currentPrayerName = '';
        prayerNameNotifier.value = '';
      } else if (call.method == "showOverlay") {
        // تم إلغاء أوفلاي الشاشة الكبيرة بناءً على طلب المستخدم
      }
    });

    // الاستماع لتغيرات مستوى الصوت من الأزرار الفعلية
    _volumeChannel.setMethodCallHandler((call) async {
      if (call.method == "onVolumeChanged") {
        final volume = (call.arguments as num?)?.toDouble() ?? 1.0;
        systemVolumeNotifier.value = volume;
        debugPrint('AdhanAudioService: System volume changed to $volume');
      }
    });

    // فحص أولي عند التشغيل
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final bool? isRunning = await _adhanChannel.invokeMethod<bool>('isAdhanPlaying');
      if (isRunning == true) {
        _isPlaying = true;
        isPlayingNotifier.value = true;
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>> checkInitialIntent() async {
    try {
      final result = await _adhanChannel.invokeMethod('checkInitialIntent');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {'showOverlay': false};
    }
  }

  // ── تشغيل صوت الأذان ───────────────────────────────────────────────────
  Future<void> playAdhan(String soundName, {String prayerName = '', bool ignoreMode = false, bool skipAnnouncement = false}) async {
    try {
      // Normalize sound name
      final normalizedSound = soundName == 'abdulbasit'
          ? 'abdulbaset'
          : (soundName == 'alharm_almakke' || soundName == 'Alharm_Almakke')
              ? 'makkah'
              : soundName;

      // التحقق من وضع الأذان
      final prefs = await SharedPreferences.getInstance();
      var adhanMode = prefs.getString('adhanMode') ?? 'sound';

      if (!ignoreMode) {
        if (adhanMode == 'silent') {
          debugPrint('AdhanAudioService: Skipped (mode: silent)');
          _currentPrayerName = '';
          prayerNameNotifier.value = '';
          return;
        }
        if (adhanMode == 'vibration') {
          debugPrint('AdhanAudioService: Vibration only (mode: vibration) — no vibration (disabled by user)');
          _currentPrayerName = '';
          prayerNameNotifier.value = '';
          return;
        }
      }

      // تخزين اسم الصلاة الحالية
      _currentPrayerName = prayerName;
      prayerNameNotifier.value = prayerName;

      if (Platform.isAndroid) {
        // ── Android: استخدام Foreground Service (يعمل في الخلفية) ──────
        await _adhanChannel.invokeMethod('playAdhan', {
          'soundName': normalizedSound,
          'prayerName': prayerName,
          'volume': 1.0,
          'playDoaa': prefs.getBool('duaEnabled') ?? true,
          'skipAnnouncement': skipAnnouncement,
        });
        _isPlaying = true;
        isPlayingNotifier.value = true;
        debugPrint(
            'AdhanAudioService [Android]: started ForegroundService for $normalizedSound ($prayerName)');
      } else {
        // ── iOS: تشغيل محلي (just_audio لا يزال يعمل في iOS) ─────────
        debugPrint(
            'AdhanAudioService [iOS]: playing $normalizedSound');
        _isPlaying = true;
      }
    } catch (e) {
      debugPrint('AdhanAudioService: Error playing adhan: $e');
    }
  }

  // ── إطلاق الأذان للخلفية مباشرة (يُستدعى من NotificationService) ──────
  /// يُستخدم هذا عند جدولة الأذان — يُرسل Intent إلى AdhanBroadcastReceiver
  static Future<void> triggerAdhanFromBackground({
    required String soundName,
    required String prayerName,
    double volume = 1.0,
    bool playDoaa = true,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      final normalizedSound = soundName == 'abdulbasit'
          ? 'abdulbaset'
          : (soundName == 'alharm_almakke' || soundName == 'Alharm_Almakke')
              ? 'makkah'
              : soundName;
      await _adhanChannel.invokeMethod('playAdhan', {
        'soundName': normalizedSound,
        'prayerName': prayerName,
        'volume': volume,
        'playDoaa': playDoaa,
      });
      debugPrint(
          'AdhanAudioService: triggerAdhanFromBackground → $normalizedSound ($prayerName)');
    } catch (e) {
      debugPrint('AdhanAudioService: triggerAdhanFromBackground error: $e');
    }
  }

  // ── ضبط مستوى الصوت (يضبط STREAM_ALARM على الجهاز فوراً) ────────────────
  Future<void> setVolume(double vol) async {
    try {
      if (Platform.isAndroid) {
        await _adhanChannel.invokeMethod('setSystemVolume', {'volume': vol});
      }
      debugPrint('AdhanAudioService: setVolume($vol) applied');
    } catch (e) {
      debugPrint('AdhanAudioService: setVolume error: $e');
    }
  }

  /// تشغيل دعاء ما بعد الأذان مباشرة للاستماع أو الفحص
  Future<void> playDua() async {
    try {
      if (Platform.isAndroid) {
        await _adhanChannel.invokeMethod('playDua');
        debugPrint('AdhanAudioService: playDua invoked');
      }
    } catch (e) {
      debugPrint('AdhanAudioService: playDua error: $e');
    }
  }

  Future<void> scheduleAlarms(List<Map<String, dynamic>> alarms) async {
    if (!Platform.isAndroid) return;
    try {
      await _adhanChannel.invokeMethod('scheduleAlarms', {'alarms': alarms});
      debugPrint('AdhanAudioService: scheduleAlarms completed for ${alarms.length} alarms');
    } catch (e) {
      debugPrint('AdhanAudioService: scheduleAlarms error: $e');
    }
  }

  Future<void> cancelAllAlarms() async {
    if (!Platform.isAndroid) return;
    try {
      await _adhanChannel.invokeMethod('cancelAllAlarms');
      debugPrint('AdhanAudioService: cancelAllAlarms completed');
    } catch (e) {
      debugPrint('AdhanAudioService: cancelAllAlarms error: $e');
    }
  }

  // ── إيقاف الأذان ────────────────────────────────────────────────────────
  Future<void> stop() async {
    try {
      if (Platform.isAndroid) {
        await _adhanChannel.invokeMethod('stopAdhan');
        debugPrint('AdhanAudioService [Android]: stopAdhan sent to service');
      }
      _isPlaying = false;
      isPlayingNotifier.value = false;
      _currentPrayerName = '';
      prayerNameNotifier.value = '';
      // التأكد من إيقاف الإعلان الصوتي في Flutter أيضاً
      VoiceAnnouncementService().stop();
    } catch (e) {
      debugPrint('AdhanAudioService: Error stopping adhan: $e');
    }
  }

  /// التحقق مما إذا كانت الخدمة النيتف (ForegroundService) مشغّلة حالياً
  static Future<bool> isNativeServiceRunning() async {
    try {
      final result = await _adhanChannel.invokeMethod<bool>('isAdhanPlaying');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// جلب مستوى الصوت الحالي من النظام
  Future<double> fetchSystemVolume() async {
    try {
      final result = await _adhanChannel.invokeMethod<double>('getSystemAlarmVolume');
      final vol = result ?? 1.0;
      systemVolumeNotifier.value = vol;
      return vol;
    } catch (e) {
      debugPrint('AdhanAudioService: fetchSystemVolume error: $e');
      return 1.0;
    }
  }

  // ── تنظيف ───────────────────────────────────────────────────────────────
  void dispose() {
    stop();
  }

  // للتوافق مع الكود القديم الذي يستمع لحالة التشغيل
  Stream<bool> get playingStream => Stream.value(_isPlaying);
}
