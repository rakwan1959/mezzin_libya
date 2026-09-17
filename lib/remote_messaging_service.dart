import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'notification_service.dart';
import 'main.dart' show navigatorKey;
import 'core/config/app_version.dart';
import 'core/theme/glass_theme.dart';
import 'core/widgets/glass_widgets.dart';
import 'core/widgets/greeting_card.dart';
import 'greeting_card_settings.dart';

// ──────────────────────────────────────────────────────────────────────────────
// إعدادات Supabase – غيّر هذه القيم بقيم مشروعك
// ──────────────────────────────────────────────────────────────────────────────
class SupabaseConfig {
  static const String url = 'https://ccdvvlwlzpikodcffley.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNjZHZ2bHdsenBpa29kY2ZmbGV5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI3NDY3MTEsImV4cCI6MjA5ODMyMjcxMX0.qaOqxx_SkXG12qYpVG3vnCduUdAjNw7f3O_3l7PRmxM';
}
// ──────────────────────────────────────────────────────────────────────────────

/// تفاصيل التحديث المنشور على سوباباز (من صف `app_config` رقم 1).
///
/// لا تُبنى إلا عندما يكون المنشور أحدث فعلاً من الإصدار المثبَّت، فوجود
/// القيمة يعني «يوجد تحديث» — وهي مصدر سطر «يتوفر إصدار أحدث» في الشاشات.
class AppUpdateInfo {
  /// الإصدار المنشور بعد التنظيف (بلا `+بناء` ولا مسافات).
  final String latestVersion;
  final String title;
  final String message;
  final String url;
  final bool force;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.title,
    required this.message,
    required this.url,
    required this.force,
  });

  bool get hasUrl => url.trim().isNotEmpty;

  /// يقرأ صف `app_config` ويعيد التحديث المتوفر، أو null إن لم يوجد تحديث.
  ///
  /// دالّة نقية (بلا شبكة) ليكون تحليل ما ينشره المدير قابلاً للاختبار وحده.
  static AppUpdateInfo? fromConfig(Map<String, dynamic>? data) {
    if (data == null) return null;
    final String latest = AppVersion.normalize(
      (data['latest_version'] ?? '').toString(),
    );
    if (latest.isEmpty) return null;
    // المقارنة دائماً مع الإصدار المثبَّت على هذا الجهاز
    if (!AppVersion.isNewer(latest)) return null;
    final String title = (data['update_title'] ?? '').toString().trim();
    final String message = (data['update_message'] ?? '').toString().trim();
    return AppUpdateInfo(
      latestVersion: latest,
      title: title.isEmpty ? 'تحديث جديد متوفر' : title,
      message: message.isEmpty
          ? 'يرجى تحديث التطبيق للحصول على آخر الميزات.'
          : message,
      url: (data['update_url'] ?? '').toString().trim(),
      force: data['force_update'] == true,
    );
  }
}

class RemoteMessagingService {
  /// الإصدار المثبَّت فعلاً — يُقرأ من المصدر الواحد `AppVersion`
  /// حتى لا يبقى رقم مكتوب هنا ويتخلّف عن pubspec.yaml.
  static String get currentVersion => AppVersion.version;

  /// التحديث المتوفر حالياً (null = لا يوجد) — تستمع إليه الشاشات
  /// لتعرض «يتوفر إصدار أحدث» بلا إعادة تشغيل.
  static final ValueNotifier<AppUpdateInfo?> availableUpdate =
      ValueNotifier<AppUpdateInfo?>(null);

  /// يُحفظ فيه الإصدار الذي عُرضت نافذته — **بعد** العرض لا قبله.
  static const String _kUpdateShownVersionKey = 'last_shown_update_version';

  static SupabaseClient get _db => Supabase.instance.client;
  static RealtimeChannel? _realtimeChannel;
  static RealtimeChannel? _appConfigChannel;

  /// فحص دوري لرسائل البث — يضمن وصول الرسالة فوراً حتى لو تعطل Realtime
  static Timer? _pollTimer;

  /// الرسائل التي عُرضت في هذه الجلسة (لمنع التكرار بين Realtime والفحص الدوري)
  static final Set<String> _shownBroadcastIds = {};

  /// منع تكرار نافذة السلام داخل نفس الجلسة (يُستخدم من Realtime وبدء التشغيل معاً)
  static bool _greetingShownThisSession = false;

  /// مُخبر رسالة التهنئة — تُحدَّث فور وصول رسالة من لوحة التحكم
  /// حتى تظهر في شاشة «عن التطبيق» مباشرة بدون إعادة تشغيل.
  static final ValueNotifier<String> congratsNotifier =
      ValueNotifier<String>('');

  /// تهيئة الاستماع للرسائل الفورية (Realtime)
  static void initRealtimeListener() async {
    if (_realtimeChannel != null) {
      await _realtimeChannel!.unsubscribe();
      _realtimeChannel = null;
    }

    _realtimeChannel = _db.channel('public:broadcasts');

    _realtimeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all, // الاستماع للإضافات والتعديلات فورياً
          schema: 'public',
          table: 'broadcasts',
          callback: (payload) async {
            try {
              final data = payload.newRecord;
              if (data.isEmpty) return;
              await _handleBroadcastData(data);
            } catch (e) {
              debugPrint(
                'RemoteMessagingService: realtime broadcast error: $e',
              );
            }
          },
        )
        .subscribe((status, error) {
          debugPrint(
            'RemoteMessagingService: Realtime status: $status${error != null ? ', error: $error' : ''}',
          );
        });

    // ── فحص دوري احتياطي ────────────────────────────────────────────
    // يضمن وصول رسائل البث فوراً حتى لو لم يعمل Realtime (كل 15 ثانية)
    _startBroadcastPolling();

    // ── قناة Realtime للإعدادات العامة (app_config) ─────────────────────
    // تستقبل فوراً أي تغيير في رسالة السلام أو الإعدادات من لوحة التحكم
    await _appConfigChannel?.unsubscribe();
    _appConfigChannel = _db.channel('public:app_config');
    _appConfigChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'app_config',
          callback: (payload) async {
            final data = payload.newRecord;
            if (data.isEmpty) return;
            try {
              final prefs = await SharedPreferences.getInstance();

              // ── رسالة السلام (تفعيل + نص + لون + نغمة) ───────────────────
              await _applyGreetingFromConfig(data);

              // ── رسالة التهنئة ────────────────────────────────────────────
              // تُخزَّن في عمود dedication_msg (الموجود في الجدول) بصيغة JSON
              // لأن أعمدة التهنئة المنفصلة غير مضافة في قاعدة البيانات.
              if (data.containsKey('dedication_msg')) {
                await applyCongratsPayload(data['dedication_msg']);
              }
              // تحديث شاشة «عن التطبيق» فوراً إذا كانت مفتوحة + نغمة التهنئة
              congratsNotifier.value = await getActiveCongrats();
              await showCongratsIfNeeded();

              // ── الرقم السري للغرفة (يُحدَّث فوراً عند تغييره من اللوحة) ──
              await _applyRoomPasscodeFromConfig(data);

              // ── إعدادات النص المتحرك في الشاشة الرئيسية ─────────────────
              await _applyHomeMarqueeFromConfig(data);

              // ── إعدادات نص هيدر شاشة الإعدادات (اللون والخط والحجم) ─────
              await _applySettingsMarqueeFromConfig(data);

              // ── دعاء ما بعد الأذان ──────────────────────────────────────
              if (data.containsKey('post_prayer_dua_enabled')) {
                await prefs.setBool(
                  'postPrayerDuaEnabled',
                  data['post_prayer_dua_enabled'] == true,
                );
              }
              if (data.containsKey('post_prayer_dua_offset')) {
                await prefs.setInt(
                  'postPrayerDuaOffset',
                  (data['post_prayer_dua_offset'] as int?) ?? 20,
                );
              }
              if (data.containsKey('post_prayer_dua_text')) {
                final dText = (data['post_prayer_dua_text'] ?? '')
                    .toString()
                    .trim();
                if (dText.isEmpty) {
                  await prefs.remove('remote_post_prayer_dua_text');
                } else {
                  await prefs.setString('remote_post_prayer_dua_text', dText);
                }
              }
              if (data.containsKey('post_prayer_dua_loop')) {
                await prefs.setBool(
                  'postPrayerDuaLoop',
                  data['post_prayer_dua_loop'] == true,
                );
              }

              // ── إعدادات أخرى تُحدَّث فوراً ───────────────────────────────
              if (data.containsKey('dua_enabled')) {
                await prefs.setBool('duaEnabled', data['dua_enabled'] == true);
              }
              if (data.containsKey('dua_offset')) {
                await prefs.setInt(
                  'duaOffsetMinutes',
                  (data['dua_offset'] as int?) ?? 4,
                );
              }
              if (data.containsKey('dua_message') &&
                  (data['dua_message'] ?? '').toString().isNotEmpty) {
                await prefs.setString(
                  'remote_dua_custom_text',
                  data['dua_message'].toString(),
                );
              }
              if (data.containsKey('marquee_text')) {
                final mText = (data['marquee_text'] ?? '').toString().trim();
                if (mText.isEmpty) {
                  await prefs.remove('remote_marquee_text');
                } else {
                  await prefs.setString('remote_marquee_text', mText);
                }
              }
              if (data.containsKey('home_dua_text')) {
                final hText = (data['home_dua_text'] ?? '').toString().trim();
                if (hText.isEmpty) {
                  await prefs.remove('remote_home_dua_text');
                } else {
                  await prefs.setString('remote_home_dua_text', hText);
                }
              }
              if (data.containsKey('home_dua_color') &&
                  data['home_dua_color'] != null) {
                await prefs.setInt(
                  'remote_home_dua_color',
                  (data['home_dua_color'] as int?) ?? 0xFFDFBA6B,
                );
              }
              if (data.containsKey('dua_text')) {
                await prefs.setString(
                  'remote_dua_text',
                  (data['dua_text'] ?? '').toString(),
                );
              }
            } catch (e) {
              debugPrint(
                'RemoteMessagingService: app_config realtime error: $e',
              );
            }
          },
        )
        .subscribe((status, error) {
          debugPrint(
            'RemoteMessagingService: app_config Realtime status: $status${error != null ? ', error: $error' : ''}',
          );
        });

    debugPrint('RemoteMessagingService: Realtime listener started');
  }

  /// بدء الفحص الدوري لرسائل البث (كل 15 ثانية) — مضمون حتى بدون Realtime
  static void _startBroadcastPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _pollBroadcasts();
      // إعادة محاولة تسليم رسالة التهنئة إذا لم تُعرض بعد (مثلاً كان التطبيق
      // في الخلفية لحظة وصولها) — بدون أي تكرار لأنها تُحفظ بعد التسليم الناجح.
      try {
        await showCongratsIfNeeded();
      } catch (_) {}
    });
    // فحص فوري عند بدء التشغيل
    _pollBroadcasts();
    showCongratsIfNeeded();
  }

  /// فحص مباشر لجدول broadcasts — يعرض أحدث رسالة غير مقروءة فوراً (إشعار + نغمة + نافذة)
  static Future<void> _pollBroadcasts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final myUserId = await getOrCreateUserId();
      final userCity = prefs.getString('city') ?? 'بنغازي';
      final lastSeenId = prefs.getString('last_seen_broadcast_id') ?? '';

      final List rows = await _db
          .from('broadcasts')
          .select()
          .order('created_at', ascending: false)
          .limit(5);

      for (final row in rows) {
        final data = row as Map<String, dynamic>;
        final broadcastId = (data['id'] ?? '').toString();
        final broadcastMsg = (data['message'] ?? '').toString();
        if (broadcastId.isEmpty || broadcastMsg.isEmpty) continue;
        if (broadcastId == lastSeenId) continue;
        if (_shownBroadcastIds.contains(broadcastId)) continue;

        // تصفية حسب المدينة / المستخدم
        final bTargetCity = (data['target_city'] ?? '').toString().trim();
        final bTargetUid = (data['target_uid'] ?? '').toString().trim();
        if (bTargetCity.isNotEmpty && bTargetCity != userCity) continue;
        if (bTargetUid.isNotEmpty) {
          final List<String> targetIds = bTargetUid
              .split(',')
              .map((e) => e.trim())
              .toList();
          if (!targetIds.contains(myUserId)) continue;
        }

        // عرض أحدث رسالة غير مقروءة فقط
        await _handleBroadcastData(data);
        break;
      }
    } catch (e) {
      debugPrint('RemoteMessagingService: Broadcast poll error: $e');
    }
  }

  /// معالجة رسالة بث واحدة (إشعار فوري بالنغمة + نافذة الحوار إذا كان التطبيق مفتوحاً)
  /// تُستخدم من Realtime والفحص الدوري معاً — مع منع التكرار
  static Future<void> _handleBroadcastData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final myUserId = await getOrCreateUserId();
    final userCity = prefs.getString('city') ?? 'بنغازي';

    final bTargetCity = (data['target_city'] ?? '').toString().trim();
    final bTargetUid = (data['target_uid'] ?? '').toString().trim();
    if (bTargetCity.isNotEmpty && bTargetCity != userCity) return;
    if (bTargetUid.isNotEmpty) {
      final List<String> targetIds = bTargetUid
          .split(',')
          .map((e) => e.trim())
          .toList();
      if (!targetIds.contains(myUserId)) return;
    }

    final broadcastId = (data['id'] ?? '').toString();
    final message = (data['message'] ?? '').toString().trim();
    if (message.isEmpty) return;

    // منع التكرار: سبق عرضها أو مقروءة سابقاً
    final lastSeenId = prefs.getString('last_seen_broadcast_id') ?? '';
    if (broadcastId.isNotEmpty && broadcastId == lastSeenId) return;
    if (broadcastId.isNotEmpty && _shownBroadcastIds.contains(broadcastId))
      return;
    if (broadcastId.isNotEmpty) _shownBroadcastIds.add(broadcastId);

    // لا يُعرض إشعار نظام علوي لرسائل البث — يُعرض الكارد (نافذة الحوار)
    // فقط داخل التطبيق حسب طلب الإدارة: بدون نغمة وبدون إشعار يتكرر.

    // إذا كان التطبيق مفتوحاً، أظهر نافذة الحوار مباشرة
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      _showBroadcastDialog(
        context,
        broadcastId,
        message,
        (data['btn_text'] ?? 'حسنا').toString(),
        (data['btn_url'] ?? '').toString(),
        title: _dialogTitleFor(broadcastId, data),
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // معرّف المستخدم الفريد
  // ──────────────────────────────────────────────────────────────────────
  static Future<String> getOrCreateUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('my_unique_user_id');
    if (userId == null) {
      final rand = math.Random();
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      userId =
          'USR-' +
          List.generate(6, (i) => chars[rand.nextInt(chars.length)]).join();
      await prefs.setString('my_unique_user_id', userId);
    }
    return userId;
  }

  // ──────────────────────────────────────────────────────────────────────
  // فحص الإشعارات والتحديثات من Supabase
  // ──────────────────────────────────────────────────────────────────────
  static Future<void> checkRemoteConfig(
    BuildContext context, {
    bool showUI = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userCity = prefs.getString('city') ?? 'بنغازي';
    final myUserId = await getOrCreateUserId();

    try {
      final configResponse = await _db
          .from('app_config')
          .select()
          .eq('id', 1)
          .maybeSingle();

      if (configResponse != null) {
        final data = configResponse;

        // ── فلترة الرسائل حسب المستخدم / المدينة / الإصدار ─────────────
        final targetUid = (data['target_user_id'] ?? '').toString().trim();
        final targetCity = (data['target_city'] ?? '').toString().trim();
        final targetVer = (data['target_version'] ?? '').toString().trim();

        if (targetUid.isNotEmpty && targetUid != myUserId) return;
        if (targetCity.isNotEmpty && targetCity != userCity) return;
        if (targetVer.isNotEmpty && targetVer != currentVersion) return;

        if (data.containsKey('dua_enabled')) {
          await prefs.setBool('duaEnabled', data['dua_enabled'] == true);
        }
        if (data.containsKey('dua_offset')) {
          await prefs.setInt(
            'duaOffsetMinutes',
            (data['dua_offset'] as int?) ?? 4,
          );
        }
        if (data.containsKey('dua_message') &&
            (data['dua_message'] ?? '').toString().isNotEmpty) {
          await prefs.setString(
            'remote_dua_custom_text',
            data['dua_message'].toString(),
          );
        }

        if (data.containsKey('marquee_text')) {
          final mText = (data['marquee_text'] ?? '').toString().trim();
          if (mText.isEmpty) {
            await prefs.remove('remote_marquee_text');
          } else {
            await prefs.setString('remote_marquee_text', mText);
          }
        }

        if (data.containsKey('home_dua_text')) {
          final hText = (data['home_dua_text'] ?? '').toString().trim();
          if (hText.isEmpty) {
            await prefs.remove('remote_home_dua_text');
          } else {
            await prefs.setString('remote_home_dua_text', hText);
          }
        }
        if (data.containsKey('home_dua_color') &&
            data['home_dua_color'] != null) {
          final colorVal = (data['home_dua_color'] as int?) ?? 0xFFDFBA6B;
          await prefs.setInt('remote_home_dua_color', colorVal);
        }

        // ── رسالة السلام عند فتح التطبيق (تفعيل + نص + لون + نغمة) ──
        await _applyGreetingFromConfig(data);

        // ── رسالة التهنئة (تظهر في المساحة الفاضية بشاشة عن التطبيق) ──
        if (data.containsKey('dedication_msg')) {
          await applyCongratsPayload(data['dedication_msg']);
        }
        congratsNotifier.value = await getActiveCongrats();
        // تسليم رسالة الإهداء للمستخدم (إشعار + نغمة) عند فتح التطبيق أيضاً
        // — وليس فقط عبر Realtime أثناء تشغيله — مع منع التكرار عبر المفتاح
        // المحفوظ لكل رسالة، فيستلمها المستخدم حتى لو كان التطبيق مغلقاً
        // لحظة الإرسال من لوحة التحكم.
        await showCongratsIfNeeded();

        // ── الرقم السري الذي يفتح الغرفة (يُضبط من لوحة التحكم) ──────
        await _applyRoomPasscodeFromConfig(data);

        // ── إعدادات النص المتحرك في الشاشة الرئيسية ─────────────────
        await _applyHomeMarqueeFromConfig(data);

        // ── إعدادات نص هيدر شاشة الإعدادات (اللون والخط والحجم) ─────
        await _applySettingsMarqueeFromConfig(data);

        // ── دعاء ما بعد الأذان ───────────────────────────────────────
        if (data.containsKey('post_prayer_dua_enabled')) {
          await prefs.setBool(
            'postPrayerDuaEnabled',
            data['post_prayer_dua_enabled'] == true,
          );
        }
        if (data.containsKey('post_prayer_dua_offset')) {
          await prefs.setInt(
            'postPrayerDuaOffset',
            (data['post_prayer_dua_offset'] as int?) ?? 20,
          );
        }
        if (data.containsKey('post_prayer_dua_text')) {
          final dText = (data['post_prayer_dua_text'] ?? '').toString().trim();
          if (dText.isEmpty) {
            await prefs.remove('remote_post_prayer_dua_text');
          } else {
            await prefs.setString('remote_post_prayer_dua_text', dText);
          }
        }
        if (data.containsKey('post_prayer_dua_loop')) {
          await prefs.setBool(
            'postPrayerDuaLoop',
            data['post_prayer_dua_loop'] == true,
          );
        }

        // ── التحديث المنشور: يُقارَن مع الإصدار المثبَّت على هذا الجهاز ──
        // (المقارنة الرقمية في AppVersion: 3.4.10 أحدث من 3.4.9، ورقم
        // البناء بعد + يُهمل، والقيم غير القابلة للقراءة لا تُنبّه).
        availableUpdate.value = AppUpdateInfo.fromConfig(data);

        if (showUI && availableUpdate.value != null) {
          // نافذة التحديث تظهر مرة واحدة لكل إصدار منشور (والإجباري يبقى
          // يظهر حتى يحدّث المستخدم). البصمة تُحفظ بعد العرض الفعلي فقط
          // فلا تُحرق لو لم تكن الواجهة جاهزة بعد.
          await showAvailableUpdate();
          return;
        }
      }
    } catch (e) {
      debugPrint('RemoteMessagingService: Error in app_config: $e');
    }

    if (!showUI) return;
    try {
      final lastSeenId = prefs.getString('last_seen_broadcast_id') ?? '';
      final List rows = await _db
          .from('broadcasts')
          .select()
          .order('created_at', ascending: false)
          .limit(10);

      for (final row in rows) {
        final data = row as Map<String, dynamic>;
        final broadcastId = (data['id'] ?? '').toString();
        final broadcastMsg = (data['message'] ?? '').toString();

        if (broadcastId.isEmpty || broadcastMsg.isEmpty) continue;
        if (broadcastId == lastSeenId) break;
        // منع التكرار: عُرضت بالفعل في هذه الجلسة (من الفحص الدوري أو Realtime)
        if (_shownBroadcastIds.contains(broadcastId)) continue;

        final bTargetCity = (data['target_city'] ?? '').toString().trim();
        final bTargetUid = (data['target_uid'] ?? '').toString().trim();
        if (bTargetCity.isNotEmpty && bTargetCity != userCity) continue;

        // دعم الإرسال لعدة مستخدمين عند الفحص الدوري
        if (bTargetUid.isNotEmpty) {
          final List<String> targetIds = bTargetUid
              .split(',')
              .map((e) => e.trim())
              .toList();
          if (!targetIds.contains(myUserId)) continue;
        }

        if (context.mounted) {
          _shownBroadcastIds.add(broadcastId);
          _showBroadcastDialog(
            context,
            broadcastId,
            broadcastMsg,
            (data['btn_text'] ?? 'حسنا').toString(),
            (data['btn_url'] ?? '').toString(),
            title: _dialogTitleFor(broadcastId, data),
          );
        }
        break;
      }
    } catch (e) {
      debugPrint('RemoteMessagingService: Error in broadcasts: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // نافذة رسالة السلام (تُستخدم من Realtime ومن بدء التشغيل معاً)
  // ──────────────────────────────────────────────────────────────────────

  /// حذف رسالة السلام نهائياً من الخادم — يستخدم نفس آلية upsert الناجحة
  /// في النشر (بعض قواعد RLS تمنع update المباشر بينما تسمح بـ upsert)
  /// مع الحفاظ على باقي إعدادات التطبيق
  static Future<bool> deleteGreeting() async {
    try {
      // قراءة الإعدادات الحالية كاملة حتى لا نفقد بقية الحقول
      final current = await _db
          .from('app_config')
          .select()
          .eq('id', 1)
          .maybeSingle();
      final payload = <String, dynamic>{'id': 1};
      if (current != null) {
        current.forEach((k, v) {
          if (k != 'id' && v != null) payload[k] = v;
        });
      }
      // تعطيل رسالة السلام ومسح نصها
      payload['greeting_enabled'] = false;
      payload['greeting_message'] = '';
      await _db.from('app_config').upsert(payload);
      debugPrint('RemoteMessagingService: Greeting deleted via upsert');
      return true;
    } catch (e) {
      debugPrint('RemoteMessagingService: deleteGreeting upsert Error: $e');
      // محاولة أخيرة: تحديث مباشر
      try {
        await _db
            .from('app_config')
            .update({'greeting_enabled': false, 'greeting_message': ''})
            .eq('id', 1);
        return true;
      } catch (e2) {
        debugPrint(
          'RemoteMessagingService: deleteGreeting fallback failed: $e2',
        );
        return false;
      }
    }
  }

  /// حذف رسالة السلام **من التطبيق ومن قاعدة البيانات** (لكل الأجهزة).
  ///
  /// يُستدعى من أيقونة الحذف على كارد الرسالة: يُعطّل الرسالة ويمسح نصّها
  /// محلياً فوراً (فتختفي من هذا الجهاز بلا انتظار شبكة)، ثم يمحوها من
  /// `app_config` فتختفي من جميع الأجهزة. وتُنسى بصمة التسليم حتى لو أُعيد
  /// نشر رسالة جديدة لاحقاً.
  static Future<bool> deleteGreetingEverywhere() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // الإعدادات الافتراضية = مُعطّلة وبلا نص، فتُمسح الرسالة من الجهاز فوراً
      await const GreetingSettings().saveLocally(prefs);
      await prefs.remove(_kLastShownGreetingMsgKey);
      _greetingShownThisSession = true;
    } catch (e) {
      debugPrint('RemoteMessagingService: deleteGreetingEverywhere local: $e');
    }
    return deleteGreeting();
  }

  /// قراءة رسالة التهنئة من عمود dedication_msg (JSON) وتحديث الكاش المحلي
  /// الصيغة: {"t":"congrats","enabled":true,"msg":"...","target":"..."}
  /// تدعم الحقل كنص JSON أو ككائن JSON (jsonb) مباشرة من Supabase.
  static Future<void> applyCongratsPayload(dynamic raw) async {
    await saveCongratsLocally(CongratsSettings.decode(raw));
  }

  /// قراءة حالة رسالة التهنئة المحفوظة على هذا الجهاز.
  static Future<CongratsSettings> readCongratsSettings() async =>
      CongratsSettings.fromPrefs(await SharedPreferences.getInstance());

  /// حفظ رسالة التهنئة محلياً (بلا إنترنت وبلا انتظار للخادم).
  ///
  /// هذا ما يجعل «التفعيل» مضموناً: كانت الرسالة تُحفظ **بعد** نجاح النشر
  /// فقط، فإن تعثّر الاتصال أو رفض الخادم الكتابة لا يُفعَّل شيء على الإطلاق.
  static Future<void> saveCongratsLocally(CongratsSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final String msg = settings.message.trim();
    if (msg.isEmpty) {
      await prefs.setBool(CongratsSettings.enabledKey, false);
      await prefs.remove(CongratsSettings.messageKey);
      await prefs.remove(CongratsSettings.targetKey);
    } else {
      await prefs.setBool(CongratsSettings.enabledKey, settings.enabled);
      await prefs.setString(CongratsSettings.messageKey, msg);
      final String target = settings.target.trim();
      if (target.isEmpty) {
        await prefs.remove(CongratsSettings.targetKey);
      } else {
        await prefs.setString(CongratsSettings.targetKey, target);
      }
    }
    congratsNotifier.value = await getActiveCongrats();
  }

  /// نشر رسالة التهنئة لكل الأجهزة عبر عمود `dedication_msg` الموجود أصلاً.
  ///
  /// تُرسل **عمودان فقط** (`id` و `dedication_msg`) فلا يعتمد النجاح على باقي
  /// أعمدة الجدول، وإن رفض الخادم هذا الشكل يُعاد المحاولة بنسخ الصف كاملاً
  /// (السلوك القديم) — فلا تبقى الرسالة بلا نشر.
  static Future<bool> publishCongrats(CongratsSettings settings) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'id': 1,
      'dedication_msg': jsonEncode(settings.toEnvelope()),
    };
    try {
      await _db.from('app_config').upsert(payload);
      return true;
    } catch (e) {
      debugPrint('RemoteMessagingService: publishCongrats thin failed: $e');
    }
    try {
      final current = await _db
          .from('app_config')
          .select()
          .eq('id', 1)
          .maybeSingle();
      final Map<String, dynamic> full = <String, dynamic>{'id': 1};
      if (current != null) {
        current.forEach((k, v) {
          if (k != 'id' && v != null) full[k] = v;
        });
      }
      full['dedication_msg'] = jsonEncode(settings.toEnvelope());
      await _db.from('app_config').upsert(full);
      return true;
    } catch (e2) {
      debugPrint('RemoteMessagingService: publishCongrats full failed: $e2');
      return false;
    }
  }

  /// عرض كارد التهنئة فقط (بلا نغمة) — يُستعمل في المعاينة والاختبارات.
  static Future<void> showCongratsCard(
    BuildContext context,
    String message,
  ) async {
    if (message.trim().isEmpty) return;
    await _showCongratsDialog(context, message);
  }

  /// معاينة رسالة التهنئة كما يراها المستخدم (نفس الكارد والنغمة).
  /// يُستخدمها زر الاختبار في اللوحة الأولى (1916).
  static Future<void> previewCongrats(
    BuildContext context,
    String message,
  ) async {
    if (message.trim().isEmpty) return;
    await _playCongratsTone();
    await _showCongratsDialog(context, message);
  }

  /// إرجاع رسالة التهنئة النشطة لهذا الجهاز — تراعي الرقم التسلسلي:
  /// إذا حُدد رقم تسلسلي وليس رقم هذا الجهاز تُرجع نصاً فارغاً.
  static Future<String> getActiveCongrats() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('remote_congrats_enabled') ?? false;
    final msg = prefs.getString('remote_congrats_message') ?? '';
    if (!enabled || msg.trim().isEmpty) return '';

    final target = (prefs.getString('remote_congrats_target') ?? '')
        .trim();
    if (target.isNotEmpty) {
      final myUserId = await getOrCreateUserId();
      final targets =
          target.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (!targets.contains(myUserId)) return '';
    }
    return msg.trim();
  }

  /// منع تكرار عرض نافذة رسالة التهنئة في نفس الجلسة
  static String _lastShownCongratsMsg = '';

  /// منع تكرار تشغيل نغمة رسالة التهنئة في نفس الجلسة
  static String _lastPlayedCongratsToneMsg = '';

  /// مفتاح حفظ آخر رسالة عُرضت نافذتها (دائم) — حتى لا تتكرر النافذة في كل
  /// مرة يُفتح فيها التطبيق لنفس الرسالة القديمة.
  static const String _kLastShownCongratsMsgKey = 'last_congrats_msg_shown';

  /// مفتاح حفظ آخر رسالة شُغِّلت نغمتها (دائم) — حتى لا تتكرر النغمة.
  static const String _kLastPlayedCongratsToneKey =
      'last_congrats_tone_played';

  /// قناة التشغيل الأصلي على أندرويد (نفس قناة الأذان)
  static const MethodChannel _nativeChannel =
      MethodChannel('com.example.muezzin_libya_app/adhan');

  /// مشغل نغمة التنبيه الاحتياطي (يُستخدم فقط إذا فشل التشغيل الأصلي)
  static final AudioPlayer _congratsTonePlayer = AudioPlayer();

  /// تشغيل نغمة التنبيه عند وصول رسالة تهنئة — نغمة نظيفة (admin_notification)
  /// وليست لحناً موسيقياً، مناسبة لتطبيق إسلامي. تُشغَّل عبر MediaPlayer
  /// الأصلي أولاً لضمان سماعها على جميع الأجهزة، مع احتياط عبر just_audio.
  /// تُرجع true إذا نجح التشغيل فعلياً — وإلا false حتى تُعاد المحاولة لاحقاً
  /// ولا تُحفظ كمُسلَّمة وهي لم تُشغَّل.
  static Future<bool> _playCongratsTone() async {
    try {
      await _nativeChannel
          .invokeMethod('playCongratsTone')
          .timeout(_kToneTimeout);
      return true;
    } catch (e) {
      debugPrint(
          'RemoteMessagingService: native congrats tone failed, falling back: $e');
    }
    try {
      await _congratsTonePlayer.stop().timeout(_kToneTimeout);
      await _congratsTonePlayer
          .setAsset('assets/audio/admin_notification.wav')
          .timeout(_kToneTimeout);
      await _congratsTonePlayer.play().timeout(_kToneTimeout);
      return true;
    } catch (e2) {
      debugPrint('RemoteMessagingService: congrats tone fallback error: $e2');
      return false;
    }
  }

  /// أقصى انتظار لطبقة الصوت — فلا تُجمّد النغمة الواجهة إن تعطّلت.
  static const Duration _kToneTimeout = Duration(seconds: 3);

  static Future<void> showCongratsIfNeeded() async {
    final msg = await getActiveCongrats();
    if (msg.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    // ── النافذة: مرة واحدة فقط لكل رسالة جديدة ──
    // يُحفظ المفتاح بعد نجاح العرض الفعلي فقط — إذا لم تكن الشاشة جاهزة
    // (تطبيق في الخلفية أو واجهة لم تُبنَ بعد) لا تُحفظ الرسالة كمُسلَّمة
    // وتُعاد المحاولة تلقائياً لاحقاً بدل أن تُفقد نهائياً.
    if (msg != _lastShownCongratsMsg &&
        msg != prefs.getString(_kLastShownCongratsMsgKey)) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        _lastShownCongratsMsg = msg;
        await _showCongratsDialog(context, msg);
        await prefs.setString(_kLastShownCongratsMsgKey, msg);
      }
    }

    // ── النغمة: تُشغَّل مرة واحدة لكل رسالة — حتى على جهاز المُرسِل نفسه ──
    // لا يُحفظ المفتاح إلا بعد نجاح التشغيل فعلياً حتى لا تُفقد النغمة إذا
    // فشل التشغيل لحظياً (انشغال الصوت أو خطأ مؤقت).
    if (msg != _lastPlayedCongratsToneMsg &&
        msg != prefs.getString(_kLastPlayedCongratsToneKey)) {
      _lastPlayedCongratsToneMsg = msg;
      final played = await _playCongratsTone();
      if (played) {
        await prefs.setString(_kLastPlayedCongratsToneKey, msg);
      } else {
        // فشل — أعد المحاولة في الدورة القادمة ولا تُحفظ كمُسلَّمة
        _lastPlayedCongratsToneMsg = '';
      }
    }
  }

  /// تعلّم رسالة الإهداء الحالية كمُسلَّمة على هذا الجهاز (جهاز المُرسِل):
  /// تُوقف نافذة الرسالة فقط حتى لا تظهر على جهازه عند الإرسال — أما النغمة
  /// فتُشغَّل فوراً عليه لتأكيد وصول الرسالة.
  static Future<void> markCongratsDeliveredOnThisDevice() async {
    final msg = await getActiveCongrats();
    if (msg.isEmpty) return;
    _lastShownCongratsMsg = msg;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastShownCongratsMsgKey, msg);
    // تشغيل النغمة على جهاز المُرسِل فور الإرسال (مرة واحدة لكل رسالة)
    // — لا يُحفظ المفتاح إلا بعد نجاح التشغيل فعلياً.
    if (msg != _lastPlayedCongratsToneMsg &&
        msg != prefs.getString(_kLastPlayedCongratsToneKey)) {
      _lastPlayedCongratsToneMsg = msg;
      final played = await _playCongratsTone();
      if (played) {
        await prefs.setString(_kLastPlayedCongratsToneKey, msg);
      } else {
        _lastPlayedCongratsToneMsg = '';
      }
    }
  }

  /// نافذة عرض رسالة الإهداء داخل التطبيق — نص كامل مع لمسة احتفالية
  /// (مثل نافذة رسالة السلام، بدون أي إشعار نظام).
  static Future<void> _showCongratsDialog(
    BuildContext context,
    String message,
  ) async {
    if (!context.mounted) return;
    await showGlassDialog(
      context: context,
      kind: GlassNoticeKind.celebration,
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Amiri',
          color: GlassNoticeSpec.titleColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          height: 2.0,
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: GlassButton(
            label: 'تقبل الله طاعتكم',
            icon: Icons.done_all_rounded,
            expand: true,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  /// حذف رسالة التهنئة نهائياً من الخادم (نفس آلية upsert الناجحة)
  static Future<bool> deleteCongrats() async {
    try {
      final current = await _db
          .from('app_config')
          .select()
          .eq('id', 1)
          .maybeSingle();
      final payload = <String, dynamic>{'id': 1};
      if (current != null) {
        current.forEach((k, v) {
          if (k != 'id' && v != null) payload[k] = v;
        });
      }
      // تعطيل رسالة التهنئة ومسحها (dedication_msg موجود في الجدول)
      payload['dedication_msg'] = '';
      await _db.from('app_config').upsert(payload);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remote_congrats_enabled', false);
      await prefs.remove('remote_congrats_message');
      await prefs.remove('remote_congrats_target');
      await prefs.remove(_kLastShownCongratsMsgKey);
      await prefs.remove(_kLastPlayedCongratsToneKey);
      congratsNotifier.value = '';
      debugPrint('RemoteMessagingService: Congrats deleted via upsert');
      return true;
    } catch (e) {
      debugPrint('RemoteMessagingService: deleteCongrats upsert Error: $e');
      try {
        await _db
            .from('app_config')
            .update({'dedication_msg': ''})
            .eq('id', 1);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('remote_congrats_enabled', false);
        await prefs.remove('remote_congrats_message');
        await prefs.remove('remote_congrats_target');
        await prefs.remove(_kLastShownCongratsMsgKey);
        await prefs.remove(_kLastPlayedCongratsToneKey);
        congratsNotifier.value = '';
        return true;
      } catch (e2) {
        debugPrint(
          'RemoteMessagingService: deleteCongrats fallback failed: $e2',
        );
        return false;
      }
    }
  }

  /// مفتاح حفظ بصمة آخر إعدادات سلام عُرضت على هذا الجهاز (دائم) — حتى لا
  /// تتكرر النافذة في كل فتحة، وتُستعاد عبر النسخ الاحتياطي للنظام حتى بعد
  /// إعادة تثبيت التطبيق. البصمة تشمل: النص + اللون + النغمة.
  static const String _kLastShownGreetingMsgKey = 'last_greeting_msg_seen';

  /// مشغّل النغمة الاحتياطي (just_audio) — يُستخدم فقط إذا فشل التشغيل
  /// الأصلي عبر MediaPlayer في أندرويد.
  static final AudioPlayer _greetingTonePlayer = AudioPlayer();

  /// تشغيل النغمة المصاحبة لكارد الرسالة.
  ///
  /// تُشغَّل من الجانب الأصلي أولاً (كما نغمة رسالة التهنئة) لِتُسمع على كل
  /// الأجهزة، ثم احتياطاً من أصول التطبيق عبر just_audio.
  /// «بدون نغمة» نجاح مقصود لا فشل.
  static Future<bool> playGreetingTone(String toneId) async {
    final GreetingTone tone = GreetingTone.byId(toneId);
    if (tone.isSilent) return true;

    try {
      await _nativeChannel
          .invokeMethod('playNoticeTone', <String, dynamic>{'tone': tone.id})
          .timeout(_kToneTimeout);
      return true;
    } catch (e) {
      debugPrint('RemoteMessagingService: native greeting tone failed: $e');
    }

    if (tone.asset.isEmpty) return false;
    try {
      await _greetingTonePlayer.stop().timeout(_kToneTimeout);
      await _greetingTonePlayer.setAsset(tone.asset).timeout(_kToneTimeout);
      await _greetingTonePlayer.play().timeout(_kToneTimeout);
      return true;
    } catch (e2) {
      debugPrint('RemoteMessagingService: greeting tone fallback error: $e2');
      return false;
    }
  }

  /// حفظ إعدادات الرسالة محلياً (بلا إنترنت وبلا انتظار الخادم).
  static Future<void> saveGreetingLocal(GreetingSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await settings.saveLocally(prefs);
  }

  /// تطبيق إعدادات الرسالة الواردة من `app_config` (عبر Realtime أو عند
  /// فتح التطبيق).
  ///
  /// النص واللون والنغمة تسافر كلها داخل عمود `greeting_message` الموجود
  /// أصلاً بصيغة JSON، فتُفكّ هنا وتُحفظ محلياً ثم يُعرض الكارد فوراً إن كان
  /// مُفعَّلاً.
  static Future<void> _applyGreetingFromConfig(
    Map<String, dynamic> data,
  ) async {
    final bool hasEnabled = data.containsKey('greeting_enabled');
    final bool hasMessage = data.containsKey('greeting_message');
    if (!hasEnabled && !hasMessage) return;

    final prefs = await SharedPreferences.getInstance();
    final GreetingSettings current = GreetingSettings.fromPrefs(prefs);
    final GreetingSettings incoming = hasMessage
        ? GreetingSettings.decode(data['greeting_message']?.toString())
        : current;

    await GreetingSettings(
      enabled: hasEnabled ? data['greeting_enabled'] == true : current.enabled,
      message: incoming.message,
      colorId: incoming.colorId,
      toneId: incoming.toneId,
    ).saveLocally(prefs);

    await showGreetingIfNeeded();
  }

  /// منع ظهور كارد الرسالة على جهاز المُرسِل نفسه لحظة نشرها من اللوحة الأولى
  /// (1916) — حتى لا ينبثق فوق اللوحة أثناء الكتابة.
  /// يُمنع فقط في الجلسة الحالية، **وتُشغَّل النغمة فوراً على جهازه** لتأكيد
  /// الإرسال وسماع النغمة المختارة قبل أن تصل لبقية الأجهزة.
  static Future<void> markGreetingDeliveredOnThisDevice() async {
    _greetingShownThisSession = true;
    final prefs = await SharedPreferences.getInstance();
    final GreetingSettings s = GreetingSettings.fromPrefs(prefs);
    await prefs.setString(_kLastShownGreetingMsgKey, s.deliveryKey);
    await playGreetingTone(s.toneId);
  }

  /// عرض كارد الرسالة عند فتح التطبيق (مرة واحدة لكل إعدادات جديدة).
  ///
  /// الكارد يعرض **نصّ الرسالة الذي كتبه المدير** في اللوحة الأولى بلون النمط
  /// المختار وزر إغلاق صغير، ومعه النغمة المختارة. (وإن لم يُكتب أي نصّ يبقى
  /// كارد لون فقط كما كان — فلا كارد بلا كتابة إلا إذا كان ذلك مقصوداً.)
  ///
  /// يعيد `true` إذا انتهى الأمر بلا شيء معلَّق (لا رسالة، أو عُرضت فعلاً)،
  /// و`false` إذا كانت الواجهة لسا غير جاهزة — فيُعاد النداء لاحقاً.
  static Future<bool> showGreetingIfNeeded() async {
    if (_greetingShownThisSession) return true;
    final prefs = await SharedPreferences.getInstance();
    final GreetingSettings s = GreetingSettings.fromPrefs(prefs);
    if (!s.enabled) return true;

    // منع التكرار: أي تغيير في (النص/اللون/النغمة) يُعدّ رسالة جديدة تظهر مرة
    // واحدة، وما عُرض سابقاً — ولو بعد إعادة التثبيت عبر النسخ الاحتياطي —
    // لا يتكرر.
    final String lastShown =
        prefs.getString(_kLastShownGreetingMsgKey) ?? '';
    if (s.deliveryKey == lastShown) return true;

    // ⚠️ بصمة التسليم لا تُستهلك إلا بعد التأكد من وجود واجهة جاهزة للعرض:
    // لو جاء النداء قبل بناء الـNavigator (بدء التشغيل أو Realtime مبكر)
    // كان الكارد يُعلَّم «مُسلَّماً» وهو لم يظهر أبداً — فلا يراه المستخدم
    // مطلقاً. الآن يبقى معلّقاً حتى تصير الواجهة جاهزة.
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return false;

    _greetingShownThisSession = true;
    // يُحفظ المفتاح قبل العرض حتى لا يتكرر حتى لو أُغلق التطبيق والكارد مفتوح.
    await prefs.setString(_kLastShownGreetingMsgKey, s.deliveryKey);

    // النغمة الخاصة المصاحبة للرسالة — تُشغَّل مع ظهور الكارد.
    await playGreetingTone(s.toneId);

    if (!context.mounted) return true;
    // النصّ نفسه يُمرَّر إلى الكارد — هو ما كُتب في اللوحة الأولى
    await showGreetingCard(
      context: context,
      style: s.style,
      message: s.message,
      // زر الحذف على الكارد: يمسح الرسالة من التطبيق ومن قاعدة البيانات
      onDelete: deleteGreetingEverywhere,
    );
    return true;
  }

  /// نشر رسالة السلام إلى `app_config` بعموديها فقط
  /// (`greeting_enabled` و`greeting_message`).
  ///
  /// لا تمرّ عبر `publishConfig` لأنها كانت تسقط بصمت إلى الحمولة الأساسية
  /// عند فشل الكتابة الكاملة، فيُقال للمدير «تم النشر» والرسالة لم تصل.
  /// هنا الكتابة مفصلة على عمودَي الرسالة فقط، والنتيجة صادقة.
  static Future<bool> publishGreeting(GreetingSettings settings) async {
    try {
      await _db.from('app_config').upsert(<String, dynamic>{
        'id': 1,
        ...settings.toRemotePayload(),
      });
      debugPrint('RemoteMessagingService: Greeting published');
      return true;
    } catch (e) {
      debugPrint('RemoteMessagingService: publishGreeting failed: $e');
      // محاولة ثانية: كتابة الأعمدة على الصف الموجود مباشرة
      try {
        await _db
            .from('app_config')
            .update(settings.toRemotePayload())
            .eq('id', 1);
        return true;
      } catch (e2) {
        debugPrint('RemoteMessagingService: publishGreeting update failed: $e2');
        return false;
      }
    }
  }

  /// إرسال رسالة بث (Broadcast) للمستخدمين
  /// حذف الرسائل القديمة (أقدم من 30 يوماً)
  static Future<int> cleanOldBroadcasts() async {
    try {
      final thirtyDaysAgo = DateTime.now()
          .subtract(const Duration(days: 30))
          .toIso8601String();
      // ملاحظة: نفترض وجود عمود created_at في الجدول
      final response = await _db
          .from('broadcasts')
          .delete()
          .lt('created_at', thirtyDaysAgo)
          .select();

      return (response as List).length;
    } catch (e) {
      debugPrint('RemoteMessagingService: cleanOldBroadcasts Error: $e');
      return 0;
    }
  }

  static Future<bool> sendBroadcast({
    required String id,
    required String title,
    required String message,
    required String btnText,
    required String btnUrl,
    String targetUserId = '',
    String targetCity = '',
  }) async {
    try {
      final payload = <String, dynamic>{
        'id': id,
        'title': title,
        'message': message,
        'btn_text': btnText.isEmpty ? 'حسنا' : btnText,
        'btn_url': btnUrl,
        'target_uid': targetUserId,
        'target_city': targetCity,
      };

      await _db.from('broadcasts').upsert(payload);
      return true;
    } catch (e) {
      debugPrint('RemoteMessagingService: sendBroadcast Error: $e');
      // محاولة الإرسال بدون الأعمدة الجديدة في حال لم تكن موجودة في السوباباز
      try {
        await _db.from('broadcasts').upsert({
          'id': id,
          'title': title,
          'message': message,
          'btn_text': btnText.isEmpty ? 'حسنا' : btnText,
          'btn_url': btnUrl,
        });
        return true;
      } catch (innerE) {
        debugPrint(
          'RemoteMessagingService: Basic sendBroadcast also failed: $innerE',
        );
        return false;
      }
    }
  }

  /// حذف آخر رسالة تحديث مخفية (hidden_update_*) من جدول البث
  /// — تُستخدم من اللوحة الأولى (1916) لحذف رسالة التحديث المرسلة سابقاً.
  static Future<bool> deleteLastHiddenUpdate() async {
    try {
      final rows = await _db
          .from('broadcasts')
          .select()
          .like('id', 'hidden_update_%')
          .order('created_at', ascending: false)
          .limit(1);
      if (rows == null || rows.isEmpty) return false;
      final id = rows.first['id'];
      await _db.from('broadcasts').delete().eq('id', id);
      debugPrint('RemoteMessagingService: deleted last hidden update: $id');
      return true;
    } catch (e) {
      debugPrint('RemoteMessagingService: deleteLastHiddenUpdate Error: $e');
      return false;
    }
  }

  static Future<bool> publishConfig({
    required String latestVersion,
    required String updateTitle,
    required String updateMessage,
    required String updateUrl,
    required bool forceUpdate,
    String targetUserId = '',
    String targetCity = '',
    String? targetVersion,
    bool? remoteDuaEnabled,
    String? remoteDuaMessage,
    int? remoteDuaOffset,
    String? remoteMarqueeText,
    // ── نص هيدر شاشة الإعدادات: اللون ونوع الخط وحجم الخط ──
    int? remoteMarqueeColor,
    String? remoteMarqueeFont,
    int? remoteMarqueeFontSize,
    String? remoteHomeDuaText,
    int? remoteHomeDuaColor,
    String? remoteDuaUnderCounterText,
    int? remoteDuaUnderCounterColor,
    // ── إعدادات دعاء ما بعد الأذان ──
    bool? remotePostPrayerDuaEnabled,
    int? remotePostPrayerDuaOffset,
    String? remotePostPrayerDuaText,
    bool? remotePostPrayerDuaLoop,
    // ── رسالة السلام عند فتح التطبيق ──
    bool? remoteGreetingEnabled,
    String? remoteGreetingMessage,
    // ── رسالة التهنئة (شاشة عن التطبيق) ──
    bool? remoteCongratsEnabled,
    String? remoteCongratsMessage,
    String? remoteCongratsTarget,
  }) async {
    try {
      // 1. المحاولة الكاملة (بكل الأعمدة الجديدة)
      final fullPayload = <String, dynamic>{
        'id': 1,
        'latest_version': latestVersion,
        'force_update': forceUpdate,
        'update_url': updateUrl,
        'update_title': updateTitle,
        'update_message': updateMessage,
        'target_user_id': targetUserId,
        'target_city': targetCity,
        'target_version': targetVersion ?? '',
      };

      if (remoteDuaEnabled != null)
        fullPayload['dua_enabled'] = remoteDuaEnabled;
      if (remoteDuaOffset != null) fullPayload['dua_offset'] = remoteDuaOffset;
      if (remoteDuaMessage != null)
        fullPayload['dua_message'] = remoteDuaMessage;
      if (remoteMarqueeText != null)
        fullPayload['marquee_text'] = remoteMarqueeText;
      if (remoteMarqueeColor != null)
        fullPayload['marquee_color'] = remoteMarqueeColor;
      if (remoteMarqueeFont != null)
        fullPayload['marquee_font'] = remoteMarqueeFont;
      if (remoteMarqueeFontSize != null)
        fullPayload['marquee_font_size'] = remoteMarqueeFontSize;
      if (remoteHomeDuaText != null)
        fullPayload['home_dua_text'] = remoteHomeDuaText;
      if (remoteHomeDuaColor != null)
        fullPayload['home_dua_color'] = remoteHomeDuaColor;
      if (remoteDuaUnderCounterText != null)
        fullPayload['dua_text'] = remoteDuaUnderCounterText;
      if (remoteDuaUnderCounterColor != null)
        fullPayload['dua_text_color'] = remoteDuaUnderCounterColor;
      if (remotePostPrayerDuaEnabled != null)
        fullPayload['post_prayer_dua_enabled'] = remotePostPrayerDuaEnabled;
      if (remotePostPrayerDuaOffset != null)
        fullPayload['post_prayer_dua_offset'] = remotePostPrayerDuaOffset;
      if (remotePostPrayerDuaText != null)
        fullPayload['post_prayer_dua_text'] = remotePostPrayerDuaText;
      if (remotePostPrayerDuaLoop != null)
        fullPayload['post_prayer_dua_loop'] = remotePostPrayerDuaLoop;
      if (remoteGreetingEnabled != null)
        fullPayload['greeting_enabled'] = remoteGreetingEnabled;
      if (remoteGreetingMessage != null)
        fullPayload['greeting_message'] = remoteGreetingMessage;
      if (remoteCongratsEnabled != null)
        fullPayload['congrats_enabled'] = remoteCongratsEnabled;
      if (remoteCongratsMessage != null)
        fullPayload['congrats_message'] = remoteCongratsMessage;
      if (remoteCongratsTarget != null)
        fullPayload['congrats_target'] = remoteCongratsTarget;

      await _db.from('app_config').upsert(fullPayload);
      return true;
    } catch (e) {
      debugPrint(
        'RemoteMessagingService: Full publishConfig failed, trying basic: $e',
      );

      try {
        // 2. المحاولة الأساسية (الأعمدة التي كانت موجودة يقيناً في الإصدار السابق)
        final basicPayload = <String, dynamic>{
          'id': 1,
          'latest_version': latestVersion,
          'force_update': forceUpdate,
          'update_url': updateUrl,
          'update_title': updateTitle,
          'update_message': updateMessage,
        };

        if (remoteDuaEnabled != null)
          basicPayload['dua_enabled'] = remoteDuaEnabled;
        if (remoteDuaOffset != null)
          basicPayload['dua_offset'] = remoteDuaOffset;
        if (remoteDuaMessage != null)
          basicPayload['dua_message'] = remoteDuaMessage;
        if (remoteMarqueeText != null)
          basicPayload['marquee_text'] = remoteMarqueeText;
        if (remoteCongratsEnabled != null)
          basicPayload['congrats_enabled'] = remoteCongratsEnabled;
        if (remoteCongratsMessage != null)
          basicPayload['congrats_message'] = remoteCongratsMessage;
        if (remoteCongratsTarget != null)
          basicPayload['congrats_target'] = remoteCongratsTarget;

        await _db.from('app_config').upsert(basicPayload);
        return true;
      } catch (innerE) {
        debugPrint(
          'RemoteMessagingService: Basic publishConfig also failed: $innerE',
        );
        return false;
      }
    }
  }

  /// هل صارت الواجهة جاهزة لعرض نافذة؟ (Navigator/Overlay مبنيّ فعلاً)
  static bool _uiReady() => navigatorKey.currentState?.overlay != null;

  /// فحص إصدار التطبيق المنشور على سوباباز **بلا واجهة** — يُستدعى عند فتح
  /// شاشة «عن التطبيق» فتظهر حالة التحديث فوراً.
  static Future<void> refreshAvailableUpdate() async {
    try {
      final Map<String, dynamic>? data = await _db
          .from('app_config')
          .select(
            'latest_version, force_update, update_url, update_title, update_message',
          )
          .eq('id', 1)
          .maybeSingle();
      availableUpdate.value = AppUpdateInfo.fromConfig(data);
    } catch (e) {
      // بلا إنترنت أو بلا أعمدة التحديث: نُبقي الحالة كما هي ولا نُزعج المستخدم
      debugPrint('RemoteMessagingService: update check failed: $e');
    }
  }

  /// يعرض نافذة التحديث المتوفر (بعد أن يملأ الفحص `availableUpdate`).
  ///
  /// يعيد true في حالة «لا شيء مطلوب» (لا تحديث، أو سبق عرضه لنفس الإصدار)
  /// حتى تُنهي حلقة إعادة المحاولة في الإقلاع، وfalse فقط عندما يكون
  /// التحديث مطلوباً والواجهة لم تجهز — فتُعاد المحاولة بلا حرق للبصمة.
  ///
  /// [ignoreDismissed] يُستخدم عند ضغط المستخدم على سطر «يتوفر إصدار أحدث»
  /// فيُعاد فتح النافذة رغم أنه أغلقها سابقاً.
  static Future<bool> showAvailableUpdate({bool ignoreDismissed = false}) async {
    final AppUpdateInfo? info = availableUpdate.value;
    if (info == null) return true;

    final prefs = await SharedPreferences.getInstance();
    if (!ignoreDismissed && !info.force) {
      if (prefs.getString(_kUpdateShownVersionKey) == info.latestVersion) {
        return true;
      }
    }
    return _showUpdateDialogNow(info, prefs);
  }

  /// العرض نفسه — دالّة **متزامنة** يأخذ فيها السياق مباشرة من `navigatorKey`
  /// بعد انتهاء الانتظار، فلا يُستخدم سياق عبر فجوة زمنية.
  ///
  /// البصمة تُحفظ مع العرض لا قبله: لا تُحرق لو لم تظهر النافذة، والكتابة
  /// لا ننتظرها لأن ذاكرة SharedPreferences المحلية تُحدَّث فوراً.
  static bool _showUpdateDialogNow(
    AppUpdateInfo info,
    SharedPreferences prefs,
  ) {
    final BuildContext? ctx = navigatorKey.currentContext;
    if (ctx == null || !_uiReady()) return false;
    if (!info.force) {
      unawaited(prefs.setString(_kUpdateShownVersionKey, info.latestVersion));
    }
    unawaited(_showUpdateDialog(ctx, info));
    return true;
  }

  static Future<void> _showUpdateDialog(
    BuildContext context,
    AppUpdateInfo info,
  ) {
    return showGlassDialog<void>(
      context: context,
      kind: GlassNoticeKind.update,
      title: info.title,
      barrierDismissible: !info.force,
      canPop: !info.force,
      content: Text(
        info.message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Amiri',
          color: GlassNoticeSpec.bodyColor,
          fontSize: 15,
          height: 1.8,
        ),
      ),
      actions: [
        if (!info.force)
          GlassButton(
            label: 'لاحقاً',
            filled: false,
            accent: GlassPalette.info,
            onPressed: () => Navigator.pop(context),
          ),
        // بلا رابط منشور لا نضع زرّاً يُوقع المستخدم في خطأ تشغيل
        if (info.hasUrl)
          GlassButton(
            label: 'تحديث الآن',
            icon: Icons.download_rounded,
            accent: GlassPalette.info,
            onPressed: () => launchUrl(
              Uri.parse(info.url),
              mode: LaunchMode.externalApplication,
            ),
          )
        else
          GlassButton(
            label: 'حسناً',
            icon: Icons.check_rounded,
            accent: GlassPalette.info,
            onPressed: () => Navigator.pop(context),
          ),
      ],
    );
  }

  /// زيادة عداد مشاهدة رسالة البث (يُستدعى عندما يفتح المستخدم الرسالة)
  ///
  /// ملاحظة: يجب إنشاء دالة PostgreSQL التالية في لوحة تحكم Supabase (SQL Editor):
  /// ```sql
  /// CREATE OR REPLACE FUNCTION increment_broadcast_views(p_broadcast_id TEXT)
  /// RETURNS void AS $$
  /// BEGIN
  ///   UPDATE broadcasts SET views = COALESCE(views, 0) + 1 WHERE id = p_broadcast_id;
  /// END;
  /// $$ LANGUAGE plpgsql;
  /// ```
  static Future<void> incrementBroadcastViews(String broadcastId) async {
    try {
      // استدعاء دالة RPC في Supabase لزيادة العداد بشكل ذري
      await _db.rpc(
        'increment_broadcast_views',
        params: {'p_broadcast_id': broadcastId},
      );
      debugPrint('RemoteMessagingService: incremented views for $broadcastId');
    } catch (e) {
      debugPrint(
        'RemoteMessagingService: failed to increment views for $broadcastId: $e',
      );
    }
  }

  static void _showBroadcastDialog(
    BuildContext context,
    String id,
    String message,
    String btnText,
    String btnUrl, {
    String title = '',
  }) {
    // اعتبار الرسالة مقروءة فور عرضها — حتى لا تتكرر حتى لو أُغلق التطبيق
    // والنافذة ما زالت مفتوحة (يُحفظ آخر معرف معروض في كل الأحوال).
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('last_seen_broadcast_id', id);
    });

    showGlassDialog(
      context: context,
      kind: GlassNoticeKind.info,
      // الكارد يعرض نص الرسالة فقط — بدون شعار ولا عنوان إداري،
      // ويُضاف عنوان (اسم المُرسل) لرسائل المستخدمين وحدها.
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                // معرّف الجهاز المُرسِل — بخط أميري صغير (12) في أعلى الرسالة
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Amiri',
                  fontWeight: FontWeight.bold,
                  color: GlassNoticeSpec.mutedColor,
                  fontSize: 12,
                ),
              ),
            ),
          Text(
            // نص رسالة الإدارة/المستخدمين — أميري بحجم 12
            message,
            style: const TextStyle(
              fontFamily: 'Amiri',
              color: GlassNoticeSpec.titleColor,
              fontSize: 12,
              height: 1.8,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: GlassButton(
            label: btnText,
            icon: Icons.open_in_new_rounded,
            expand: true,
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('last_seen_broadcast_id', id);
              // زيادة عداد المشاهدة
              await incrementBroadcastViews(id);
              Navigator.pop(context);
              if (btnUrl.isNotEmpty)
                launchUrl(
                  Uri.parse(btnUrl),
                  mode: LaunchMode.externalApplication,
                );
            },
          ),
        ),
      ],
    ).then((_) async {
      // اعتبار الرسالة مقروءة فور إغلاق النافذة بأي طريقة (زر التأكيد أو
      // النقر خارجها) حتى لا تتكرر الرسالة مع نغمتها في كل مرة يُفتح فيها
      // التطبيق.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_seen_broadcast_id', id);
    });
  }

  /// عنوان النافذة: رسائل المستخدمين وحدها تُظهر عنواناً (اسم المُرسِل)،
  /// فتبقى رسائل الإدارة الحالية بلا عنوان كما كانت.
  static String _dialogTitleFor(String broadcastId, Map<String, dynamic> data) {
    if (!isUserMessageId(broadcastId)) return '';
    // معرّف المُرسِل وحده — بلا «رسالة من» حتى في الرسائل المخزَّنة قديماً
    return senderFromTitle((data['title'] ?? '').toString());
  }

  // ──────────────────────────────────────────────────────────────────────
  // المراسلة بين المستخدمين — بمعرّف الجهاز فقط (USR-XXXXXX)
  //
  // تُخزَّن الرسائل في نفس جدول `broadcasts` مع:
  //   id         = dm_<وقت>_<رمز المُرسِل>  → يُميّز رسائل المستخدمين ويحمل المُرسِل
  //   title      = رسالة من USR-XXXXXX       → اسم المُرسِل كما يظهر للمستلم
  //   target_uid = USR-XXXXXX (أو أكثر مفصولة بفواصل، أو فارغ = للجميع)
  // وبذلك تصل فوراً عبر نفس قناة Realtime القائمة بلا أي تعديل في Supabase.
  // ──────────────────────────────────────────────────────────────────────
  static const String userMessagePrefix = 'dm_';

  /// معرّف هذا الجهاز (يُنشأ ويُحفظ عند أول استخدام)
  static Future<String> myDeviceId() => getOrCreateUserId();

  /// تنظيف ما يُكتب في حقل معرّف الجهاز: بلا مسافات وبحروف كبيرة
  static String normalizeDeviceId(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  /// رمز الجهاز بلا شرطة — يُستخدم داخل معرّف الرسالة
  static String deviceTag(String deviceId) =>
      normalizeDeviceId(deviceId).replaceAll('-', '');

  /// معرّف رسالة مستخدم→مستخدم: فريد بالوقت + **بصمة عشوائية** (دقة الساعة في
  /// بعض الأنظمة منخفضة فيتساوى الطابع الزمني لرسالتين متتاليتين فتُستبدل
  /// إحداهما بالأخرى في `upsert`) + رمز المُرسِل في النهاية ليُعرف المُرسِل.
  static String buildUserMessageId(String senderId) {
    final int stamp = DateTime.now().microsecondsSinceEpoch;
    final String salt = math.Random().nextInt(1679616).toRadixString(36);
    return '$userMessagePrefix${stamp}_${salt}_${deviceTag(senderId)}';
  }

  /// هل هذا المعرّف معرّف رسالة بين مستخدمين؟
  static bool isUserMessageId(String id) => id.startsWith(userMessagePrefix);

  /// اسم المُرسِل من عنوان الرسالة ('رسالة من USR-XXXXXX' ← USR-XXXXXX)
  static String senderFromTitle(String title) {
    const String marker = 'رسالة من';
    final String t = title.trim();
    if (!t.startsWith(marker)) return t;
    return t.substring(marker.length).trim();
  }

  /// إرسال رسالة إلى جهاز آخر بمعرّفه فقط.
  /// معرّف فارغ = رسالة إلى جميع الأجهزة.
  static Future<bool> sendUserMessage({
    required String toDeviceId,
    required String body,
  }) async {
    final String text = body.trim();
    if (text.isEmpty) return false;

    final String myId = await getOrCreateUserId();
    // يُخزَّن معرّف المُرسِل وحده في العمود `title` — بلا عبارة «رسالة من»
    // فيظهر للمستلم رقم معرّف الجهاز فقط بخط صغير أعلى الرسالة.
    return sendBroadcast(
      id: buildUserMessageId(myId),
      title: myId,
      message: text,
      btnText: 'حسنا',
      btnUrl: '',
      targetUserId: normalizeDeviceId(toDeviceId),
    );
  }

  /// كل رسائل المستخدمين الخاصة بهذا الجهاز (الواردة والصادرة) بالأحدث أولاً.
  static Future<List<UserMessage>> fetchUserMessages({int limit = 100}) async {
    final String myId = await getOrCreateUserId();
    final Set<String> hidden = await hiddenUserMessageIds();
    final List<UserMessage> messages = <UserMessage>[];

    // ── الواردة: رسائل مستخدمين موجّهة لمعرّفي ──
    try {
      final List<dynamic> received = await _db
          .from('broadcasts')
          .select()
          .like('id', '$userMessagePrefix%')
          .like('target_uid', '%$myId%')
          .order('created_at', ascending: false)
          .limit(limit);

      for (final row in received) {
        final data = Map<String, dynamic>.from(row as Map);
        if (hidden.contains((data['id'] ?? '').toString())) continue;
        messages.add(
          UserMessage(
            id: (data['id'] ?? '').toString(),
            body: (data['message'] ?? '').toString(),
            otherDeviceId: senderFromTitle((data['title'] ?? '').toString()),
            outgoing: false,
            createdAt: (data['created_at'] ?? '').toString(),
          ),
        );
      }
    } catch (e) {
      debugPrint('RemoteMessagingService: fetch received messages error: $e');
    }

    // ── الصادرة: معرّفات الرسائل المنتهية برمز هذا الجهاز ──
    try {
      final List<dynamic> sent = await _db
          .from('broadcasts')
          .select()
          .like('id', '$userMessagePrefix%${deviceTag(myId)}')
          .order('created_at', ascending: false)
          .limit(limit);

      for (final row in sent) {
        final data = Map<String, dynamic>.from(row as Map);
        if (hidden.contains((data['id'] ?? '').toString())) continue;
        messages.add(
          UserMessage(
            id: (data['id'] ?? '').toString(),
            body: (data['message'] ?? '').toString(),
            otherDeviceId: normalizeDeviceId(
              (data['target_uid'] ?? '').toString(),
            ),
            outgoing: true,
            createdAt: (data['created_at'] ?? '').toString(),
          ),
        );
      }
    } catch (e) {
      debugPrint('RemoteMessagingService: fetch sent messages error: $e');
    }

    messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return messages;
  }

  // ──────────────────────────────────────────────────────────────────────
  // حذف الرسائل المستلمة
  //
  // الرسالة المحذوفة تُسجَّل في قائمة مخفية على هذا الجهاز أولاً (فتختفي
  // فوراً ولا تعود حتى لو منعت سياسات Supabase الحذف)، ثم تُحذف من السحابة.
  // ──────────────────────────────────────────────────────────────────────
  static const String hiddenUserMessagesKey = 'hidden_user_messages';

  /// معرّفات الرسائل التي حذفها صاحب هذا الجهاز.
  static Future<Set<String>> hiddenUserMessageIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(hiddenUserMessagesKey) ?? <String>[]).toSet();
  }

  /// إخفاء رسائل على هذا الجهاز (بلا شبكة) — تُستدعى من الحذف ومن الاختبارات.
  static Future<void> hideUserMessagesLocally(Iterable<String> ids) async {
    final List<String> list = ids
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (list.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final Set<String> hidden =
        (prefs.getStringList(hiddenUserMessagesKey) ?? <String>[]).toSet()
          ..addAll(list);
    await prefs.setStringList(hiddenUserMessagesKey, hidden.toList());
  }

  /// حذف رسالة مستلمة واحدة: إخفاء على الجهاز + حذف من السحابة.
  static Future<bool> deleteUserMessage(String id) =>
      deleteUserMessages(<String>[id]);

  /// حذف مجموعة رسائل مستلمة (من جهازنا) — يخفيها على الجهاز دائماً،
  /// ويحاول حذفها من السحابة، ويُرجع هل نجح الحذف من الخادم.
  static Future<bool> deleteUserMessages(Iterable<String> ids) async {
    final List<String> list = ids
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (list.isEmpty) return false;

    await hideUserMessagesLocally(list);

    bool allDeleted = true;
    for (final String id in list) {
      try {
        await _db.from('broadcasts').delete().eq('id', id);
      } catch (e) {
        debugPrint('RemoteMessagingService: delete user message $id error: $e');
        allDeleted = false;
      }
    }
    debugPrint(
      'RemoteMessagingService: deleted ${list.length} received message(s) — server: $allDeleted',
    );
    return allDeleted;
  }

  /// معرّفات **كل** رسائل المستخدمين المخزّنة على السحابة لهذا الجهاز:
  /// الواردة الموجّهة إلى معرّفي، والصادرة مني.
  ///
  /// لا تُستثنى الرسائل المخفية محلياً: المخفية قد تكون بقيت على السحابة لأن
  /// سياسة RLS منعت حذفها سابقاً، فلا بدّ أن يشمل «حذف الكل» تنضيفها.
  /// (المعرّفات الموجودة على السحابة، وهل نجحت قراءتها كلها).
  ///
  /// الفصل ضروري حتى لا يُقال «تم الحذف» بينما القائمة لم تُقرأ أصلاً
  /// (بلا إنترنت) — فتظل الرسائل على السحابة وتعود لاحقاً.
  static Future<(List<String>, bool)> _allUserMessageIdsWithStatus() async {
    final String myId = await getOrCreateUserId();
    final Set<String> ids = <String>{};
    bool queriedOk = true;

    try {
      final List<dynamic> received = await _db
          .from('broadcasts')
          .select('id')
          .like('id', '$userMessagePrefix%')
          .like('target_uid', '%$myId%');
      for (final row in received) {
        final String id = ((row as Map)['id'] ?? '').toString().trim();
        if (id.isNotEmpty) ids.add(id);
      }
    } catch (e) {
      queriedOk = false;
      debugPrint('RemoteMessagingService: allUserMessageIds received: $e');
    }

    try {
      final List<dynamic> sent = await _db
          .from('broadcasts')
          .select('id')
          .like('id', '$userMessagePrefix%${deviceTag(myId)}');
      for (final row in sent) {
        final String id = ((row as Map)['id'] ?? '').toString().trim();
        if (id.isNotEmpty) ids.add(id);
      }
    } catch (e) {
      queriedOk = false;
      debugPrint('RemoteMessagingService: allUserMessageIds sent: $e');
    }

    return (ids.toList(), queriedOk);
  }

  /// معرّفات **كل** رسائل هذا الجهاز على السحابة (الواردة والصادرة).
  static Future<List<String>> allUserMessageIds() async =>
      (await _allUserMessageIdsWithStatus()).$1;

  /// حذف **جميع** رسائل هذا الجهاز (الواردة والصادرة) من التطبيق ومن السحابة.
  ///
  /// الإخفاء المحلي يحدث فوراً فلا تعود أي رسالة للظهور حتى لو منعت سياسات
  /// Supabase الحذف، ويُرجع هل نجح الحذف من الخادم فعلاً.
  static Future<bool> deleteAllUserMessages() async {
    final (List<String> ids, bool queriedOk) =
        await _allUserMessageIdsWithStatus();
    // لا رسائل: النجاح مرهون بنجاح الاستعلام نفسه — لا بتعذّره.
    if (ids.isEmpty) return queriedOk;
    final bool deleted = await deleteUserMessages(ids);
    return deleted && queriedOk;
  }

  // ──────────────────────────────────────────────────────────────────────
  // الرقم السري الذي يفتح الغرفة — يُضبط من لوحة التحكم (بلا إعادة بناء)
  //
  // يُقرأ من عمود `room_passcode` في جدول `app_config`، ويُحفظ محلياً فيصل
  // للجهاز فوراً عبر قناة Realtime أو عند فتح التطبيق. وإن لم يُضبط على
  // السيرفر (أو لم يكن العمود موجوداً) يعود التطبيق للرقم المضمَّن داخله.
  // ──────────────────────────────────────────────────────────────────────
  static const String roomPasscodePrefKey = 'room_passcode_remote';

  /// الرقم السري للغرفة القادم من السيرفر، أو null إن لم يُضبط بعد
  /// (حينها يستعمل التطبيق الرقم المضمَّن).
  static Future<String?> getRemoteRoomPasscode({bool refresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (refresh) {
      await _fetchRoomPasscodeFromServer(prefs);
    }

    final String cached = (prefs.getString(roomPasscodePrefKey) ?? '').trim();
    return cached.isEmpty ? null : cached;
  }

  /// نشر الرقم السري للغرفة إلى إعدادات السيرفر.
  /// يُرجع false إذا تعذّر الحفظ (غالباً لأن عمود `room_passcode` غير مضاف
  /// في جدول app_config).
  static Future<bool> publishRoomPasscode(String code) async {
    final String value = code.trim();
    try {
      await _db.from('app_config').upsert({
        'id': 1,
        'room_passcode': value,
      });

      final prefs = await SharedPreferences.getInstance();
      if (value.isEmpty) {
        await prefs.remove(roomPasscodePrefKey);
      } else {
        await prefs.setString(roomPasscodePrefKey, value);
      }
      return true;
    } catch (e) {
      debugPrint('RemoteMessagingService: publishRoomPasscode error: $e');
      return false;
    }
  }

  /// قراءة الرقم من السيرفر وحفظه محلياً (يُستدعى عند الحاجة لتحديث فوري)
  static Future<void> _fetchRoomPasscodeFromServer(
    SharedPreferences prefs,
  ) async {
    try {
      final config = await _db
          .from('app_config')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (config == null) return;
      final data = Map<String, dynamic>.from(config);
      await _applyRoomPasscodeFromConfig(data);
      await _applyHomeMarqueeFromConfig(data);
      await _applySettingsMarqueeFromConfig(data);
    } catch (e) {
      debugPrint('RemoteMessagingService: fetchRoomPasscode error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // النص المتحرك في الشاشة الرئيسية — إعداداته كلها من لوحة التحكم (1918)
  //
  // تُخزَّن في جدول `app_config` بالأعمدة:
  //   home_dua_enabled · home_dua_text · home_dua_color · home_dua_font
  //   home_dua_font_size · home_dua_interval_ms · home_dua_bold
  //   home_dua_after_minutes (0 = يظهر دائماً)
  // وتُحفَظ محلياً بنفس المفاتيح بمقدمة `remote_` ليستعملها التطبيق فوراً.
  // ──────────────────────────────────────────────────────────────────────
  static const String homeDuaEnabledKey = 'remote_home_dua_enabled';
  static const String homeDuaTextKey = 'remote_home_dua_text';
  static const String homeDuaColorKey = 'remote_home_dua_color';
  static const String homeDuaFontKey = 'remote_home_dua_font';
  static const String homeDuaFontSizeKey = 'remote_home_dua_font_size';
  static const String homeDuaIntervalKey = 'remote_home_dua_interval_ms';
  static const String homeDuaBoldKey = 'remote_home_dua_bold';
  static const String homeDuaAfterMinutesKey = 'remote_home_dua_after_minutes';

  /// الخطوط المتاحة للنص المتحرك في لوحة التحكم
  static const List<String> homeDuaFonts = <String>[
    'Cairo',
    'Amiri',
    'Amiri Quran',
    'Tajawal',
    'Noto Kufi Arabic',
    'Almarai',
  ];

  // ──────────────────────────────────────────────────────────────────────
  // النص المتحرك في هيدر شاشة الإعدادات (أسماء الله الحسنى)
  //
  // تُخزَّن في جدول `app_config` بالأعمدة:
  //   marquee_text (موجود) · marquee_color · marquee_font · marquee_font_size
  // وتُحفَظ محلياً بمفاتيح `remote_` ليقرأها الهيدر فوراً.
  // ──────────────────────────────────────────────────────────────────────
  static const String settingsMarqueeTextKey = 'remote_marquee_text';
  static const String settingsMarqueeColorKey = 'remote_marquee_color';
  static const String settingsMarqueeFontKey = 'remote_marquee_font';
  static const String settingsMarqueeFontSizeKey = 'remote_marquee_font_size';

  /// الأحاديث/الرسائل المتقلّبة في الهيدر (حديث لكل سطر) و**وقت ظهور** كل
  /// حديث — تُخزَّن محلياً هنا، وفي `app_config` بعمودَي `marquee_messages`
  /// و`marquee_interval_ms` (انظر
  /// `database/supabase_app_config_and_broadcasts.sql`).
  static const String settingsMarqueeMessagesKey = 'remote_marquee_messages';
  static const String settingsMarqueeIntervalKey = 'remote_marquee_interval_ms';

  /// إعدادات نص هيدر شاشة الإعدادات كما هي محفوظة على هذا الجهاز.
  static Future<SettingsMarqueeSettings> readSettingsMarqueeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsMarqueeSettings.fromPrefs(prefs);
  }

  /// حفظ إعدادات نص الهيدر محلياً ونشرها لبقية الأجهزة.
  ///
  /// يُرجع false إذا تعذّر النشر (غالباً لأن أعمدة `marquee_*` الجديدة غير
  /// مضافة في جدول app_config) — والحفظ المحلي يكون قد تمّ فعلاً.
  static Future<bool> publishSettingsMarquee(
    SettingsMarqueeSettings settings,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await settings.saveLocally(prefs);
    } catch (e) {
      debugPrint('RemoteMessagingService: publishSettingsMarquee(local): $e');
      return false;
    }

    try {
      await _db.from('app_config').upsert(<String, dynamic>{
        'id': 1,
        ...settings.toRemotePayload(),
      });
      return true;
    } catch (e) {
      debugPrint('RemoteMessagingService: publishSettingsMarquee error: $e');
      return false;
    }
  }

  /// إعادة نص الهيدر إلى وضعه الأصلي (أسماء الله الحسنى + الافتراضيات).
  static Future<bool> resetSettingsMarquee() =>
      publishSettingsMarquee(const SettingsMarqueeSettings());

  /// تطبيق أعمدة `marquee_*` الواردة من app_config على التخزين المحلي
  /// (فيتغيّر الهيدر على كل الأجهزة بلا تحديث التطبيق).
  static Future<void> _applySettingsMarqueeFromConfig(
    Map<String, dynamic> data,
  ) async {
    if (!data.containsKey('marquee_text') &&
        !data.containsKey('marquee_color') &&
        !data.containsKey('marquee_font') &&
        !data.containsKey('marquee_font_size') &&
        !data.containsKey('marquee_messages') &&
        !data.containsKey('marquee_interval_ms')) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    if (data.containsKey('marquee_text')) {
      final String t = (data['marquee_text'] ?? '').toString().trim();
      if (t.isEmpty) {
        await prefs.remove(settingsMarqueeTextKey);
      } else {
        await prefs.setString(settingsMarqueeTextKey, t);
      }
    }
    if (data.containsKey('marquee_color') && data['marquee_color'] != null) {
      final c = data['marquee_color'];
      final int color = c is num
          ? c.round()
          : (int.tryParse('${c ?? ''}') ?? SettingsMarqueeSettings.defaultColor);
      await prefs.setInt(settingsMarqueeColorKey, color);
    }
    if (data.containsKey('marquee_font')) {
      final String f = (data['marquee_font'] ?? '').toString().trim();
      if (f.isEmpty) {
        await prefs.remove(settingsMarqueeFontKey);
      } else {
        await prefs.setString(
          settingsMarqueeFontKey,
          SettingsMarqueeSettings.normalizeFont(f),
        );
      }
    }
    if (data.containsKey('marquee_font_size')) {
      final s = data['marquee_font_size'];
      final int size = s is num
          ? s.round()
          : (int.tryParse('${s ?? ''}') ??
                SettingsMarqueeSettings.defaultFontSize);
      await prefs.setInt(
        settingsMarqueeFontSizeKey,
        SettingsMarqueeSettings.clampFontSize(size),
      );
    }
    // ── الأحاديث المتقلّبة: قيمة فارغة = حذف المخصص (فيعود النص الواحد) ──
    if (data.containsKey('marquee_messages')) {
      final List<String> list = SettingsMarqueeSettings.parseMessages(
        (data['marquee_messages'] ?? '').toString(),
      );
      if (list.isEmpty) {
        await prefs.remove(settingsMarqueeMessagesKey);
      } else {
        await prefs.setString(settingsMarqueeMessagesKey, list.join('\n'));
      }
    }
    if (data.containsKey('marquee_interval_ms') &&
        data['marquee_interval_ms'] != null) {
      final v = data['marquee_interval_ms'];
      final int ms = v is num
          ? v.round()
          : (int.tryParse('${v ?? ''}') ??
                SettingsMarqueeSettings.defaultIntervalMs);
      await prefs.setInt(
        settingsMarqueeIntervalKey,
        SettingsMarqueeSettings.clampInterval(ms),
      );
    }
  }

  /// تطبيق إعدادات الهيدر من صف app_config جاهز، ويُرجع الإعدادات الناتجة
  /// (تستعملها شاشة الإعدادات بعد قراءتها المباشرة من السيرفر).
  static Future<SettingsMarqueeSettings> applySettingsMarqueeConfig(
    Map<String, dynamic>? data,
  ) async {
    if (data != null) await _applySettingsMarqueeFromConfig(data);
    return readSettingsMarqueeSettings();
  }

  /// إعدادات النص المتحرك كما هي محفوظة على هذا الجهاز (مع الافتراضيات).
  static Future<HomeMarqueeSettings> readHomeMarqueeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return HomeMarqueeSettings.fromPrefs(prefs);
  }

  /// حفظ كل إعدادات النص المتحرك ونشرها لجميع الأجهزة.
  /// يُرجع false إذا تعذّر الحفظ (غالباً لأن الأعمدة الجديدة غير مضافة في
  /// جدول app_config).
  static Future<bool> publishHomeMarquee(HomeMarqueeSettings settings) async {
    // 1. الحفظ المحلي أولاً — فيظهر التأثير على هذا الجهاز فوراً حتى
    //    لو تعذّر الاتصال بالسيرفر (أو كانت أعمدة app_config ناقصة).
    try {
      final prefs = await SharedPreferences.getInstance();
      await settings.saveLocally(prefs);
    } catch (e) {
      debugPrint('RemoteMessagingService: publishHomeMarquee(local) error: $e');
      return false;
    }

    // 2. ثم النشر لبقية الأجهزة عبر app_config
    try {
      await _db.from('app_config').upsert(<String, dynamic>{
        'id': 1,
        ...settings.toRemotePayload(),
      });
      return true;
    } catch (e) {
      debugPrint('RemoteMessagingService: publishHomeMarquee error: $e');
      return false;
    }
  }

  /// إعادة النص المتحرك إلى وضعه الأصلي (يحذف الإعدادات المخصصة)
  static Future<bool> resetHomeMarquee() async {
    return publishHomeMarquee(const HomeMarqueeSettings());
  }

  /// تطبيق إعدادات النص المتحرك الواردة من app_config على التخزين المحلي
  static Future<void> _applyHomeMarqueeFromConfig(
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    if (data.containsKey('home_dua_enabled')) {
      await prefs.setBool(homeDuaEnabledKey, data['home_dua_enabled'] == true);
    }
    if (data.containsKey('home_dua_text')) {
      final t = (data['home_dua_text'] ?? '').toString().trim();
      if (t.isEmpty) {
        await prefs.remove(homeDuaTextKey);
      } else {
        await prefs.setString(homeDuaTextKey, t);
      }
    }
    if (data.containsKey('home_dua_color') && data['home_dua_color'] != null) {
      final c = data['home_dua_color'];
      final int color = c is num
          ? c.round()
          : (int.tryParse('${c ?? ''}') ?? HomeMarqueeSettings.defaultColor);
      await prefs.setInt(homeDuaColorKey, color);
    }
    if (data.containsKey('home_dua_font')) {
      final f = (data['home_dua_font'] ?? '').toString().trim();
      if (f.isEmpty) {
        await prefs.remove(homeDuaFontKey);
      } else {
        await prefs.setString(homeDuaFontKey, HomeMarqueeSettings.normalizeFont(f));
      }
    }
    if (data.containsKey('home_dua_font_size')) {
      final s = data['home_dua_font_size'];
      final int size = s is num
          ? s.round()
          : (int.tryParse('${s ?? ''}') ?? HomeMarqueeSettings.defaultFontSize);
      await prefs.setInt(homeDuaFontSizeKey, HomeMarqueeSettings.clampFontSize(size));
    }
    if (data.containsKey('home_dua_interval_ms')) {
      final i = data['home_dua_interval_ms'];
      final int ms = i is num
          ? i.round()
          : (int.tryParse('${i ?? ''}') ?? HomeMarqueeSettings.defaultIntervalMs);
      await prefs.setInt(homeDuaIntervalKey, HomeMarqueeSettings.clampInterval(ms));
    }
    if (data.containsKey('home_dua_bold')) {
      await prefs.setBool(homeDuaBoldKey, data['home_dua_bold'] == true);
    }
    if (data.containsKey('home_dua_after_minutes')) {
      final a = data['home_dua_after_minutes'];
      final int m = a is num
          ? a.round()
          : (int.tryParse('${a ?? ''}') ?? HomeMarqueeSettings.defaultAfterMinutes);
      await prefs.setInt(
        homeDuaAfterMinutesKey,
        HomeMarqueeSettings.clampAfterMinutes(m),
      );
    }
  }

  /// تطبيق قيمة `room_passcode` الواردة من إعدادات السيرفر (فارغة = مسح).
  static Future<void> _applyRoomPasscodeFromConfig(
    Map<String, dynamic> data,
  ) async {
    if (!data.containsKey('room_passcode')) return;

    final prefs = await SharedPreferences.getInstance();
    final String value = (data['room_passcode'] ?? '').toString().trim();

    if (value.isEmpty) {
      await prefs.remove(roomPasscodePrefKey);
    } else {
      await prefs.setString(roomPasscodePrefKey, value);
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// النص المتحرك في الشاشة الرئيسية — إعداداته كلها
//
// تُحفظ في جدول `app_config` وفي التخزين المحلي بنفس المفاتيح:
//   home_dua_enabled · home_dua_text · home_dua_color · home_dua_font
//   home_dua_font_size · home_dua_interval_ms · home_dua_bold
//   home_dua_after_minutes (0 = يظهر دائماً)
// ──────────────────────────────────────────────────────────────────────────────
class HomeMarqueeSettings {
  /// هل النص المتحرك مُفعَّل في الشاشة الرئيسية؟
  final bool enabled;

  /// النص المخصص (فارغ = النصوص الافتراضية المضمّنة في التطبيق)
  final String text;

  /// لون الخط (ARGB).
  ///
  /// والقيمة [followPrayerColorsValue] (صفر) تعني **يتبع ألوان أوقات الصلاة**:
  /// يأخذ النص المتحرك لون الصلاة الحالية (مُفتَّحاً ليكون مقروءاً).
  /// لم نُضف عموداً جديداً في قاعدة البيانات — القيمة تسافر في عمود
  /// `home_dua_color` الموجود أصلاً.
  final int color;

  /// اسم الخط: Amiri · Amiri Quran · Cairo · Tajawal · Noto Kufi Arabic · Almarai
  final String fontFamily;

  /// حجم الخط بالبكسل (8 – 30)
  final int fontSize;

  /// مدة بقاء كل عبارة على الشاشة بالمللي ثانية (600 – 20000)
  final int intervalMs;

  /// خط عريض؟
  final bool bold;

  /// بداية الظهور بعد الأذان بالدقائق (0 = يظهر دائماً)
  final int afterMinutes;

  static const bool defaultEnabled = true;
  static const int defaultColor = 0xFFDFBA6B;

  /// الخط الافتراضي: كايرو (عادي) — وليس غليظاً.
  static const String defaultFontFamilyValue = 'Cairo';

  /// لون «يتبع أوقات الصلاة» — القيمة المحفوظة في `home_dua_color`.
  static const int followPrayerColorsValue = 0;

  /// الافتراضي: يتبع ألوان أوقات الصلاة.
  static const bool defaultFollowPrayerColors = true;

  /// هل النص المتحرك يتبع ألوان أوقات الصلاة؟
  bool get followsPrayerColors => color == followPrayerColorsValue;

  /// المفتاح الذي يُسجَّل أنه تمّت ترحيل اللون القديم افتراضياً (مرة واحدة).
  static const String followPrayerMigratedKey =
      'home_dua_color_follow_migrated';
  static const String defaultFontFamily = defaultFontFamilyValue;
  static const int defaultFontSize = 10;
  static const int defaultIntervalMs = 2800;

  /// غير غليظ افتراضياً (كايرو عادي: w400).
  static const bool defaultBold = false;
  static const int defaultAfterMinutes = 15;

  /// حدود مقبولة لكل قيمة رقمية (تُستعمل عند القراءة والحفظ معاً)
  static const int minFontSize = 8;
  static const int maxFontSize = 30;
  static const int minIntervalMs = 600;
  static const int maxIntervalMs = 20000;
  static const int maxAfterMinutes = 240;

  const HomeMarqueeSettings({
    this.enabled = defaultEnabled,
    this.text = '',
    // الافتراضي: يتبع ألوان أوقات الصلاة في الشاشة الرئيسية
    this.color = followPrayerColorsValue,
    this.fontFamily = defaultFontFamily,
    this.fontSize = defaultFontSize,
    this.intervalMs = defaultIntervalMs,
    this.bold = defaultBold,
    this.afterMinutes = defaultAfterMinutes,
  });

  /// قراءة الإعدادات المحفوظة على هذا الجهاز (مع الافتراضيات عند غيابها).
  ///
  /// **اللون:** إن لم يكن محفوظاً شيء → «يتبع ألوان الصلاة».
  /// وإن كان المحفوظ هو اللون الافتراضي القديم (الذهبي) — وهو ما لم يختره
  /// المستخدم بنفسه بل كُتب تلقائياً — يُحوَّل مرة واحدة إلى «يتبع ألوان
  /// الصلاة» حتى يرى الجميع السلوك الجديد بلا إعادة تثبيت.
  static HomeMarqueeSettings fromPrefs(SharedPreferences p) {
    return HomeMarqueeSettings(
      enabled:
          p.getBool(RemoteMessagingService.homeDuaEnabledKey) ?? defaultEnabled,
      text: p.getString(RemoteMessagingService.homeDuaTextKey) ?? '',
      color: _resolveMarqueeColor(p.getInt(RemoteMessagingService.homeDuaColorKey)),
      fontFamily: normalizeFont(
        p.getString(RemoteMessagingService.homeDuaFontKey),
      ),
      fontSize: clampFontSize(
        p.getInt(RemoteMessagingService.homeDuaFontSizeKey),
      ),
      intervalMs: clampInterval(
        p.getInt(RemoteMessagingService.homeDuaIntervalKey),
      ),
      bold: p.getBool(RemoteMessagingService.homeDuaBoldKey) ?? defaultBold,
      afterMinutes: clampAfterMinutes(
        p.getInt(RemoteMessagingService.homeDuaAfterMinutesKey),
      ),
    );
  }

  /// حفظ الإعدادات محلياً (الشاشة الرئيسية تقرأ من هنا مباشرة).
  Future<void> saveLocally(SharedPreferences p) async {
    await p.setBool(RemoteMessagingService.homeDuaEnabledKey, enabled);
    if (text.trim().isEmpty) {
      await p.remove(RemoteMessagingService.homeDuaTextKey);
    } else {
      await p.setString(RemoteMessagingService.homeDuaTextKey, text.trim());
    }
    await p.setInt(RemoteMessagingService.homeDuaColorKey, color);
    await p.setString(RemoteMessagingService.homeDuaFontKey, fontFamily);
    await p.setInt(RemoteMessagingService.homeDuaFontSizeKey, fontSize);
    await p.setInt(RemoteMessagingService.homeDuaIntervalKey, intervalMs);
    await p.setBool(RemoteMessagingService.homeDuaBoldKey, bold);
    await p.setInt(RemoteMessagingService.homeDuaAfterMinutesKey, afterMinutes);
  }

  /// الحمولة التي تُرفع إلى `app_config` (كل إعدادات النص المتحرك).
  Map<String, dynamic> toRemotePayload() => <String, dynamic>{
    'home_dua_enabled': enabled,
    'home_dua_text': text.trim(),
    'home_dua_color': color,
    'home_dua_font': fontFamily,
    'home_dua_font_size': fontSize,
    'home_dua_interval_ms': intervalMs,
    'home_dua_bold': bold,
    'home_dua_after_minutes': afterMinutes,
  };

  HomeMarqueeSettings copyWith({
    bool? enabled,
    String? text,
    int? color,
    String? fontFamily,
    int? fontSize,
    int? intervalMs,
    bool? bold,
    int? afterMinutes,
    bool? followPrayerColors,
  }) {
    // أولوية اللون: لون صريح → تشغيل/إيقاف التتبّع → اللون الحالي
    final int nextColor;
    if (color != null) {
      nextColor = color;
    } else if (followPrayerColors == true) {
      nextColor = followPrayerColorsValue;
    } else if (followPrayerColors == false &&
        this.color == followPrayerColorsValue) {
      // أُوقف التتبّع بلا لون بديل → اللون الذهبي الافتراضي
      nextColor = defaultColor;
    } else {
      nextColor = this.color;
    }
    return HomeMarqueeSettings(
      enabled: enabled ?? this.enabled,
      text: text ?? this.text,
      color: nextColor,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      intervalMs: intervalMs ?? this.intervalMs,
      bold: bold ?? this.bold,
      afterMinutes: afterMinutes ?? this.afterMinutes,
    );
  }

  /// ضبط اسم الخط على أحد الخطوط المتاحة (وأي اسم مجهول يعود إلى «أميري»).
  static String normalizeFont(String? name) {
    final String n = (name ?? '').trim();
    if (n.isEmpty) return defaultFontFamily;
    for (final String f in RemoteMessagingService.homeDuaFonts) {
      if (f.toLowerCase() == n.toLowerCase()) return f;
    }
    return defaultFontFamily;
  }

  static int clampFontSize(int? v) {
    final int size = v ?? defaultFontSize;
    if (size < minFontSize) return minFontSize;
    if (size > maxFontSize) return maxFontSize;
    return size;
  }

  static int clampInterval(int? v) {
    final int ms = v ?? defaultIntervalMs;
    if (ms < minIntervalMs) return minIntervalMs;
    if (ms > maxIntervalMs) return maxIntervalMs;
    return ms;
  }

  static int clampAfterMinutes(int? v) {
    final int m = v ?? defaultAfterMinutes;
    if (m < 0) return 0;
    if (m > maxAfterMinutes) return maxAfterMinutes;
    return m;
  }

  /// مدة بقاء كل عبارة على الشاشة.
  Duration get interval => Duration(milliseconds: intervalMs);

  /// سرعة التقليب كما تُعرض في لوحة التحكم (ثوانٍ لكل عبارة).
  double get intervalSeconds => intervalMs / 1000.0;

  /// أوقات الظهور كما تُعرض في لوحة التحكم.
  String get afterLabel =>
      afterMinutes == 0 ? 'يظهر دائماً' : 'بعد $afterMinutes دقيقة من الأذان';

  /// العبارات المخصصة (سطر لكل عبارة، أو مفصولة بـ •). فارغة = النص الافتراضي.
  List<String> get phrases {
    final String t = text.trim();
    if (t.isEmpty) return const <String>[];
    if (t.contains('\n')) {
      return t
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (t.contains('•')) {
      return t
          .split('•')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return <String>[t];
  }

  /// هل يظهر النص الآن؟ (معطَّل = لا، أو مضت المدة المطلوبة من الأذان السابق)
  bool shouldShow({required int minutesSincePrevPrayer}) {
    if (!enabled) return false;
    if (afterMinutes <= 0) return true;
    return minutesSincePrevPrayer >= afterMinutes;
  }

  /// ترحيل لون النص المتحرك مرة واحدة: اللون الذهبي الافتراضي القديم يصير
  /// «يتبع ألوان أوقات الصلاة». أي لون اختاره المدير بنفسه (غير الذهبي)
  /// يبقى كما هو، وباقي الاختيارات متاحة كما هي في اللوحة.
  static int _resolveMarqueeColor(int? stored) {
    if (stored == null) return followPrayerColorsValue;
    if (stored == followPrayerColorsValue) return stored;
    return stored;
  }

  /// مفتاح ترحيل خط النص المتحرك (كايرو عادي).
  static const String fontMigratedKey = 'home_dua_font_cairo_migrated';

  /// يُنفَّذ مرة واحدة: الخط الافتراضي القديم (أميري) → «كايرو»، والخط
  /// الغليظ الافتراضي القديم → عادي. أي خط أو وزن اختاره المدير بنفسه غير
  /// الأميري/الغليظ يبقى كما هو، والمفتاحان باقيان في اللوحة للتغيير.
  static Future<void> migrateMarqueeFontToCairoRegular(
    SharedPreferences p,
  ) async {
    if (p.getBool(fontMigratedKey) ?? false) return;

    final String? stored = p.getString(RemoteMessagingService.homeDuaFontKey);
    if (stored == null || normalizeFont(stored) == 'Amiri') {
      await p.setString(
        RemoteMessagingService.homeDuaFontKey,
        defaultFontFamilyValue,
      );
    }
    final bool? storedBold = p.getBool(RemoteMessagingService.homeDuaBoldKey);
    if (storedBold == null || storedBold) {
      await p.setBool(RemoteMessagingService.homeDuaBoldKey, false);
    }
    await p.setBool(fontMigratedKey, true);
  }

  /// يُنفَّذ مرة واحدة عند فتح التطبيق: يحوّل الذهبي الافتراضي القديم إلى
  /// «يتبع ألوان الصلاة» ويُعلِّم الترحيل كمُنفَّذ.
  static Future<void> migrateMarqueeColorFollowPrayer(
    SharedPreferences p,
  ) async {
    if (p.getBool(followPrayerMigratedKey) ?? false) return;
    final int? stored = p.getInt(RemoteMessagingService.homeDuaColorKey);
    if (stored == null || stored == defaultColor) {
      await p.setInt(
        RemoteMessagingService.homeDuaColorKey,
        followPrayerColorsValue,
      );
    }
    await p.setBool(followPrayerMigratedKey, true);
  }

  /// الخط المقابل للاسم المختار من قائمة خطوط لوحة التحكم.
  static TextStyle googleFontStyle(String fontFamily) {
    switch (normalizeFont(fontFamily)) {
      case 'Amiri Quran':
        return GoogleFonts.amiriQuran();
      case 'Cairo':
        return GoogleFonts.cairo();
      case 'Tajawal':
        return GoogleFonts.tajawal();
      case 'Noto Kufi Arabic':
        return GoogleFonts.notoKufiArabic();
      case 'Almarai':
        return GoogleFonts.almarai();
      case 'Amiri':
      default:
        return GoogleFonts.amiri();
    }
  }

  /// نمط العرض النهائي للنص المتحرك (الخط + الحجم + الوزن + اللون).
  /// نمط النص المتحرك.
  ///
  /// [prayerColor] هو لون الصلاة الحالية — يُستعمل فقط عندما يكون الوضع
  /// «يتبع ألوان أوقات الصلاة» ([followsPrayerColors]). وإن لم يُمرَّر
  /// (كمعاينة اللوحة) يعود إلى اللون الذهبي حتى تبقى المعاينة مقروءة.
  TextStyle textStyle({Color? prayerColor}) {
    final Color resolved = followsPrayerColors
        ? (prayerColor ?? Color(defaultColor))
        : Color(color);
    return googleFontStyle(fontFamily).copyWith(
      fontSize: fontSize.toDouble(),
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: resolved,
      shadows: <Shadow>[
        Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 4),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// النص المتحرك في هيدر شاشة الإعدادات (أسماء الله الحسنى)
//
// يُتحكَّم فيه كاملاً من لوحة التحكم (تبويب الرسائل ← قسم «النص المتحرك –
// شاشة الإعدادات»): النص واللون ونوع الخط وحجم الخط.
//
// تُحفظ في جدول `app_config` وفي التخزين المحلي بنفس الأسماء:
//   marquee_text · marquee_color · marquee_font · marquee_font_size
// ──────────────────────────────────────────────────────────────────────────────
class SettingsMarqueeSettings {
  /// النص المعروض في الهيدر (فارغ = أسماء الله الحسنى المضمّنة في التطبيق).
  ///
  /// يبقى للنص **الواحد**: فإن أُضيفت أحاديث ([messages]) كان هذا هو الحديث
  /// الأول — فتظلّ النسخ المثبَّتة القديمة (التي تقرأ النص الواحد) تعرض شيئاً
  /// صحيحاً.
  final String text;

  /// لون الخط (ARGB) — أبيض افتراضياً لأنه فوق هيدر داكن.
  final int color;

  /// اسم الخط: Amiri · Amiri Quran · Cairo · Tajawal · Noto Kufi Arabic · Almarai
  final String fontFamily;

  /// حجم الخط بالبكسل (9 – 24).
  final int fontSize;

  /// الأحاديث/الرسائل المتقلّبة في هيدر شاشة الإعدادات — **حديث لكل عنصر**.
  ///
  /// فارغة = يُعرض [text] وحده، وإن كان فارغاً فأسماء الله الحسنى المضمّنة.
  final List<String> messages;

  /// **وقت الظهور**: مدة بقاء كل حديث في الهيدر قبل الانتقال إلى التالي
  /// (مللي ثانية).
  final int intervalMs;

  static const int defaultColor = 0xFFFFFFFF; // أبيض
  static const String defaultFontFamilyValue = 'Amiri';
  static const String defaultFontFamily = defaultFontFamilyValue;
  static const int defaultFontSize = 12;
  static const int minFontSize = 9;
  static const int maxFontSize = 24;

  /// وقت الظهور: 1.5 ثانية كحد أدنى كي تُقرأ العبارة، و60 ثانية كأقصى.
  static const int defaultIntervalMs = 6000;
  static const int minIntervalMs = 1500;
  static const int maxIntervalMs = 60000;

  /// سقف عدد الأحاديث وسقف طول الحديث — حماية من صف ضخم في `app_config`
  /// يبطئ القراءة على المدى الطويل.
  static const int maxMessages = 40;
  static const int maxMessageLength = 300;

  const SettingsMarqueeSettings({
    this.text = '',
    this.color = defaultColor,
    this.fontFamily = defaultFontFamily,
    this.fontSize = defaultFontSize,
    this.messages = const <String>[],
    this.intervalMs = defaultIntervalMs,
  });

  /// الأحاديث الفعلية التي يتقلّبها الهيدر.
  ///
  /// الأولوية: [messages] → [text] → **فارغة** (وحينها تعرض الشاشة أسماء
  /// الله الحسنى المضمّنة). فصف قديم فيه `marquee_text` وحده يبقى يعمل.
  List<String> get effectiveMessages {
    if (messages.isNotEmpty) return messages;
    final String t = text.trim();
    return t.isEmpty ? const <String>[] : <String>[t];
  }

  /// عدد الأحاديث المعروضة (0 = أسماء الله الحسنى المضمّنة في الشاشة).
  int get messagesCount => effectiveMessages.length;

  /// الحديث رقم [index] مع الدوران على القائمة (لا يخرج عن الحدود أبداً).
  String messageAt(int index) {
    final List<String> list = effectiveMessages;
    if (list.isEmpty) return '';
    final int i = index % list.length;
    return list[i < 0 ? i + list.length : i];
  }

  /// وقت ظهور كل حديث.
  Duration get interval => Duration(milliseconds: intervalMs);

  /// وقت الظهور كما يُعرض في لوحة التحكم (ثوانٍ).
  double get intervalSeconds => intervalMs / 1000.0;

  /// نص «وقت الظهور» للعرض في اللوحة: 6.0 ثانية · 1.5 ثانية ...
  String get intervalLabel => '${intervalSeconds.toStringAsFixed(1)} ثانية';

  /// قراءة الإعدادات المحفوظة على هذا الجهاز (مع الافتراضيات عند غيابها).
  static SettingsMarqueeSettings fromPrefs(SharedPreferences p) =>
      SettingsMarqueeSettings(
        text: p.getString(RemoteMessagingService.settingsMarqueeTextKey) ?? '',
        color:
            p.getInt(RemoteMessagingService.settingsMarqueeColorKey) ??
            defaultColor,
        fontFamily: normalizeFont(
          p.getString(RemoteMessagingService.settingsMarqueeFontKey),
        ),
        fontSize: clampFontSize(
          p.getInt(RemoteMessagingService.settingsMarqueeFontSizeKey),
        ),
        messages: parseMessages(
          p.getString(RemoteMessagingService.settingsMarqueeMessagesKey),
        ),
        intervalMs: clampInterval(
          p.getInt(RemoteMessagingService.settingsMarqueeIntervalKey),
        ),
      );

  /// حفظ الإعدادات محلياً (هيدر شاشة الإعدادات يقرأ من هنا مباشرة).
  Future<void> saveLocally(SharedPreferences p) async {
    final String t = text.trim();
    if (t.isEmpty) {
      await p.remove(RemoteMessagingService.settingsMarqueeTextKey);
    } else {
      await p.setString(RemoteMessagingService.settingsMarqueeTextKey, t);
    }

    final List<String> list = normalizeMessages(messages);
    if (list.isEmpty) {
      await p.remove(RemoteMessagingService.settingsMarqueeMessagesKey);
    } else {
      await p.setString(
        RemoteMessagingService.settingsMarqueeMessagesKey,
        list.join('\n'),
      );
    }

    await p.setInt(
      RemoteMessagingService.settingsMarqueeIntervalKey,
      clampInterval(intervalMs),
    );
    await p.setInt(RemoteMessagingService.settingsMarqueeColorKey, color);
    await p.setString(
      RemoteMessagingService.settingsMarqueeFontKey,
      normalizeFont(fontFamily),
    );
    await p.setInt(
      RemoteMessagingService.settingsMarqueeFontSizeKey,
      clampFontSize(fontSize),
    );
  }

  /// الحمولة التي تُرفع إلى `app_config` (أعمدة marquee_*).
  ///
  /// `marquee_messages` = حديث لكل سطر، و`marquee_text` = الحديث الأول —
  /// فالنسخ القديمة التي تقرأ النص الواحد تعرض أول حديث أيضاً.
  Map<String, dynamic> toRemotePayload() {
    final List<String> list = normalizeMessages(messages);
    return <String, dynamic>{
      'marquee_text': list.isEmpty ? text.trim() : list.first,
      'marquee_messages': list.isEmpty ? '' : list.join('\n'),
      'marquee_interval_ms': clampInterval(intervalMs),
      'marquee_color': color,
      'marquee_font': normalizeFont(fontFamily),
      'marquee_font_size': clampFontSize(fontSize),
    };
  }

  SettingsMarqueeSettings copyWith({
    String? text,
    int? color,
    String? fontFamily,
    int? fontSize,
    List<String>? messages,
    int? intervalMs,
  }) => SettingsMarqueeSettings(
    text: text ?? this.text,
    color: color ?? this.color,
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
    messages: messages ?? this.messages,
    intervalMs: intervalMs ?? this.intervalMs,
  );

  /// فكّ الأحاديث من القيمة القادمة من السيرفر أو من التخزين المحلي:
  /// نص فيه حديث لكل سطر، **أو مصفوفة JSON** (لو أُنشئ العمود jsonb).
  static List<String> parseMessages(String? raw) {
    final String s = (raw ?? '').trim();
    if (s.isEmpty) return const <String>[];

    if (s.startsWith('[')) {
      try {
        final dynamic decoded = jsonDecode(s);
        if (decoded is List) {
          return normalizeMessages(
            decoded.map((dynamic e) => '$e').toList(growable: false),
          );
        }
      } catch (_) {
        // نص عادي يبدأ بـ[ — نُكمله كأسطر أدناه
      }
    }
    return normalizeMessages(s.split('\n'));
  }

  /// تنظيف قائمة الأحاديث: بلا فراغات ولا تكرار، وبسقف عدد وطول.
  ///
  /// **سطر واحد = حديث واحد**: السطر الجديد هو الفاصل في `marquee_messages`،
  /// فحديث ملصوق بأسطر متعددة كان يصير عدة أحاديث لكل منها وقت ظهور مستقل بلا
  /// أن يدري المدير (ثلاثة بدل اثنين). لذلك يُطوى كل فراغ داخلي — ومنه السطر
  /// الجديد — إلى مسافة واحدة، فيبقى عدد الأحاديث مطابقاً لما يراه في اللوحة.
  static List<String> normalizeMessages(List<String> raw) {
    final List<String> out = <String>[];
    for (final String item in raw) {
      final String t = item.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (t.isEmpty) continue;
      final String capped = t.length > maxMessageLength
          ? t.substring(0, maxMessageLength).trim()
          : t;
      if (out.contains(capped)) continue;
      out.add(capped);
      if (out.length >= maxMessages) break;
    }
    return out;
  }

  static int clampInterval(int? v) {
    final int ms = v ?? defaultIntervalMs;
    if (ms < minIntervalMs) return minIntervalMs;
    if (ms > maxIntervalMs) return maxIntervalMs;
    return ms;
  }

  /// الخط الافتراضي هنا **أميري** (لا كايرو كما في نص الشاشة الرئيسية).
  static String normalizeFont(String? name) {
    final String n = (name ?? '').trim();
    if (n.isEmpty) return defaultFontFamily;
    for (final String f in RemoteMessagingService.homeDuaFonts) {
      if (f.toLowerCase() == n.toLowerCase()) return f;
    }
    return defaultFontFamily;
  }

  static int clampFontSize(int? v) {
    final int size = v ?? defaultFontSize;
    if (size < minFontSize) return minFontSize;
    if (size > maxFontSize) return maxFontSize;
    return size;
  }

  /// نمط العرض النهائي: نوع الخط + الحجم + اللون (مع هالة خفيفة للقراءة).
  TextStyle textStyle({bool bold = true}) =>
      HomeMarqueeSettings.googleFontStyle(fontFamily).copyWith(
        fontSize: fontSize.toDouble(),
        fontWeight: bold ? FontWeight.bold : FontWeight.w400,
        color: Color(color),
        shadows: <Shadow>[
          Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6),
        ],
      );
}

/// رسالة بين مستخدمَين، عنوانها معرّف الجهاز فقط.
class UserMessage {
  final String id;
  final String body;

  /// معرّف الجهاز الآخر (المُرسِل للواردة، والمستلم للصادرة)
  final String otherDeviceId;

  /// true = أرسلتها من هذا الجهاز
  final bool outgoing;

  /// وقت الإنشاء كما يصل من السيرفر (UTC ISO)
  final String createdAt;

  const UserMessage({
    required this.id,
    required this.body,
    required this.otherDeviceId,
    required this.outgoing,
    required this.createdAt,
  });

  /// الوقت بالتوقيت المحلي للجهاز
  DateTime? get time => DateTime.tryParse(createdAt)?.toLocal();

  /// وقت مختصر للعرض: 2026-09-14  14:37
  String get displayTime {
    final DateTime? t = time;
    if (t == null) return createdAt;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}  ${two(t.hour)}:${two(t.minute)}';
  }

  /// الطرف الآخر كما يُعرض: «الجميع» إن كانت الرسالة عامة
  String get otherLabel => otherDeviceId.isEmpty ? 'الجميع' : otherDeviceId;
}

// ──────────────────────────────────────────────────────────────────────────────
// رسالة التهنئة (اللوحة الأولى 1916 ← «الرسالة الخفية»)
//
// تظهر في المساحة الفاضية بشاشة «عن التطبيق»، وتصل لكل الأجهزة ككارد ونغمة.
// تُخزَّن في عمود `dedication_msg` الموجود أصلاً بصيغة:
//   {"t":"congrats","enabled":true,"msg":"...","target":"..."}
// فيصل التفعيل والنص والرقم التسلسلي بلا أي عمود جديد ولا تعديل SQL.
// ──────────────────────────────────────────────────────────────────────────────
class CongratsSettings {
  const CongratsSettings({
    this.enabled = false,
    this.message = '',
    this.target = '',
  });

  /// هل الرسالة مُفعَّلة؟
  final bool enabled;

  /// نص رسالة التهنئة.
  final String message;

  /// الرقم التسلسلي للمستخدم (فارغ = للجميع).
  final String target;

  static const String enabledKey = 'remote_congrats_enabled';
  static const String messageKey = 'remote_congrats_message';
  static const String targetKey = 'remote_congrats_target';

  /// مُفعَّلة فعلاً (مفعّلة ولها نص) — وهي الحالة التي تظهر للمستخدمين.
  bool get isActive => enabled && message.trim().isNotEmpty;

  static CongratsSettings fromPrefs(SharedPreferences p) => CongratsSettings(
    enabled: p.getBool(enabledKey) ?? false,
    message: p.getString(messageKey) ?? '',
    target: p.getString(targetKey) ?? '',
  );

  CongratsSettings copyWith({bool? enabled, String? message, String? target}) =>
      CongratsSettings(
        enabled: enabled ?? this.enabled,
        message: message ?? this.message,
        target: target ?? this.target,
      );

  /// الحمولة المُغلَّفة كما تُكتب في `dedication_msg`.
  Map<String, dynamic> toEnvelope() => <String, dynamic>{
    't': 'congrats',
    'enabled': enabled,
    'msg': message.trim(),
    'target': target.trim(),
  };

  /// فك التغليف (يقبل نص JSON أو كائن JSON من Supabase).
  /// أي قيمة أخرى أو تالفة → رسالة غير مفعّلة (فلا يظهر شيء).
  static CongratsSettings decode(dynamic raw) {
    try {
      dynamic decoded = raw;
      if (raw is String) {
        final String s = raw.trim();
        if (s.isEmpty) return const CongratsSettings();
        decoded = jsonDecode(s);
      }
      if (decoded is Map) {
        if (decoded['t'] != 'congrats') return const CongratsSettings();
        return CongratsSettings(
          enabled: decoded['enabled'] == true,
          message: (decoded['msg'] ?? '').toString().trim(),
          target: (decoded['target'] ?? '').toString().trim(),
        );
      }
    } catch (_) {}
    return const CongratsSettings();
  }
}
