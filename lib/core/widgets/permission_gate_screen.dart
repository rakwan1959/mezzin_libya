import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'glass_scaffold.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// شاشة تفعيل الصلاحيات عند تثبيت وتشغيل التطبيق — شاشة واحدة موحّدة.
///
/// تظهر عند فتح التطبيق لأول مرة أو عند وجود صلاحيات مفقودة، وتلخّص كل
/// الصلاحيات المطلوبة (الإشعارات والأذان، الموقع، المنبهات الدقيقة، شاشة
/// الأذان فوق القفل، استثناء تحسين البطارية) في قائمة واحدة مرتبة.
///
/// لا تُظهر أي نوافذ نظام تلقائياً؛ المستخدم هو من يضغط زر «تفعيل جميع
/// الصلاحيات» مرة واحدة، ثم تُفتح نوافذ النظام بالتتابع فوق هذه الشاشة
/// نفسها مع تحديث الحالة مباشرة.
/// ─────────────────────────────────────────────────────────────────────────────
class PermissionGateScreen extends StatefulWidget {
  final Widget child;
  final bool isAlreadyDone;
  final VoidCallback? onCompleted;
  const PermissionGateScreen({
    super.key,
    required this.child,
    this.isAlreadyDone = false,
    this.onCompleted,
  });

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen>
    with WidgetsBindingObserver {
  static const _adhanChannel =
      MethodChannel('com.example.muezzin_libya_app/adhan');
  static const _batteryChannel =
      MethodChannel('com.example.muezzin_libya_app/battery');

  /// مفتاح تذكر إتمام شاشة الصلاحيات — بعد إتمامها مرة واحدة لا تظهر مجدداً
  static const _doneKey = 'permissionGateDone';

  // ── لوحة الألوان الإسلامية الفاخرة (الأسود والذهبي) ──
  static const _gold = Color(0xFFDFBA6B);
  static const _goldDeep = Color(0xFFB8860B);
  static const _bgBlack = Colors.black;
  static const _cardBg = Color(0xFF141414);
  static const _greenSuccess = Color(0xFF2ECC71);

  bool _checking = true;
  bool _notifGranted = false;
  bool _locationGranted = false;
  bool _alarmGranted = false;
  bool _batteryGranted = false;
  bool _fsiGranted = false;

  /// المستخدم أتم شاشة الصلاحيات سابقاً → ندخل التطبيق مباشرة دون أي وميض
  bool _skipGate = false;
  bool _initialCheckDone = false;
  bool _isCheckingPermissions = false;

  @override
  void initState() {
    super.initState();
    _skipGate = widget.isAlreadyDone;
    if (_skipGate) {
      _initialCheckDone = true;
      _checking = false;
    }
    WidgetsBinding.instance.addObserver(this);
    if (!_skipGate) {
      _loadSkipFlag();
    }
    // فحص الصلاحيات بأمان بعد رسم الواجهة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_skipGate) {
        _checkAllPermissions();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_skipGate) {
      _checkAllPermissions();
    }
  }

  bool get _allGranted =>
      _notifGranted &&
      _locationGranted &&
      _alarmGranted &&
      _batteryGranted &&
      _fsiGranted;

  /// عدد الصلاحيات المفعّلة حالياً (من أصل 5)
  int get _grantedCount =>
      (_notifGranted ? 1 : 0) +
      (_locationGranted ? 1 : 0) +
      (_alarmGranted ? 1 : 0) +
      (_batteryGranted ? 1 : 0) +
      (_fsiGranted ? 1 : 0);

  Future<void> _checkAllPermissions() async {
    if (_isCheckingPermissions) return;
    _isCheckingPermissions = true;
    try {
      bool notif = true;
      if (Platform.isAndroid) {
        try {
          notif = await Permission.notification.isGranted.timeout(
            const Duration(seconds: 2),
            onTimeout: () => false,
          );
        } catch (_) {}
      }

      bool loc = false;
      try {
        loc = await Permission.location.isGranted.timeout(
          const Duration(seconds: 2),
          onTimeout: () => false,
        );
      } catch (_) {}

      bool alarm = true;
      if (Platform.isAndroid) {
        try {
          alarm = await Permission.scheduleExactAlarm.isGranted.timeout(
            const Duration(seconds: 2),
            onTimeout: () => false,
          );
        } catch (_) {}
      }

      bool battery = false;
      try {
        battery = await _batteryChannel
                .invokeMethod<bool>('isIgnoringBatteryOptimizations')
                .timeout(const Duration(seconds: 2), onTimeout: () => false) ??
            false;
      } catch (_) {
        try {
          battery = await Permission.ignoreBatteryOptimizations.isGranted.timeout(
            const Duration(seconds: 2),
            onTimeout: () => false,
          );
        } catch (_) {}
      }

      bool fsi = true;
      try {
        fsi = await _adhanChannel
                .invokeMethod<bool>('canUseFullScreenIntent')
                .timeout(const Duration(seconds: 2), onTimeout: () => true) ??
            true;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _notifGranted = notif;
        _locationGranted = loc;
        _alarmGranted = alarm;
        _batteryGranted = battery;
        _fsiGranted = fsi;
        _checking = false;
        _initialCheckDone = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _checking = false;
          _initialCheckDone = true;
        });
      }
    } finally {
      _isCheckingPermissions = false;
    }
  }

  /// فحص ما إذا كان المستخدم أتم شاشة الصلاحيات سابقاً
  Future<void> _loadSkipFlag() async {
    try {
      final p = await SharedPreferences.getInstance();
      final done = p.getBool(_doneKey) ?? false;
      if (mounted && done) {
        setState(() => _skipGate = true);
      }
    } catch (_) {}
  }

  /// طلب كل الصلاحيات بالتتابع
  Future<void> _requestAllPermissions() async {
    if (mounted) setState(() => _checking = true);
    try {
      if (Platform.isAndroid && !_notifGranted) {
        final status = await Permission.notification.request();
        _notifGranted = status.isGranted;
      }
      if (!_locationGranted) {
        final status = await Permission.location.request();
        _locationGranted = status.isGranted;
      }
      if (Platform.isAndroid && !_alarmGranted) {
        try {
          final status = await Permission.scheduleExactAlarm.request();
          _alarmGranted = status.isGranted;
        } catch (_) {}
      }
      // ── طلب صلاحية شاشة الأذان فوق القفل (Full Screen Intent) ──
      if (Platform.isAndroid && !_fsiGranted) {
        try {
          await _adhanChannel.invokeMethod('requestFullScreenIntentPermission');
        } catch (_) {}
      }
      await _checkAllPermissions();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _proceedToApp() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_doneKey, true);
    } catch (_) {}
    widget.onCompleted?.call();
    if (!mounted) return;
    setState(() => _skipGate = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_skipGate) {
      return widget.child;
    }
    return _buildGate();
  }

  // ─────────────────────────────── تصميم البوابة ──────────────────────────────────
  Widget _buildGate() {
    return GlassScaffold(
      body: Container(
        color: _bgBlack.withValues(alpha: 0.62),
        child: Stack(
          children: [
            // نقش هندسي إسلامي خفيف في الخلفية
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _IslamicPatternPainter()),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _ornament(),
                    const SizedBox(height: 12),
                    Text(
                      'تفعيل صلاحيات الأذان',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'منح هذه الصلاحيات يضمن وصول الأذان والتنبيهات في موعدها بدقة، حتى مع قفل الشاشة',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _progressSummary(),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _permissionTile(
                            icon: Icons.notifications_active_rounded,
                            title: 'الإشعارات والأذان',
                            subtitle: 'إشعارات الصلوات والتذكيرات اليومية في وقتها',
                            isGranted: _notifGranted,
                            onTap: () async {
                              if (Platform.isAndroid) {
                                await Permission.notification.request();
                                await _checkAllPermissions();
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          _permissionTile(
                            icon: Icons.location_on_rounded,
                            title: 'تحديد الموقع',
                            subtitle: 'حساب مواقيت الصلاة واتجاه القبلة بدقة',
                            isGranted: _locationGranted,
                            onTap: () async {
                              await Permission.location.request();
                              await _checkAllPermissions();
                            },
                          ),
                          const SizedBox(height: 10),
                          _permissionTile(
                            icon: Icons.alarm_on_rounded,
                            title: 'المنبهات الدقيقة',
                            subtitle: 'تشغيل الأذان في موعده حتى في وضع «عدم الإزعاج»',
                            isGranted: _alarmGranted,
                            onTap: () async {
                              try {
                                final status =
                                    await Permission.scheduleExactAlarm.request();
                                _alarmGranted = status.isGranted;
                              } catch (_) {}
                              await _checkAllPermissions();
                            },
                          ),
                          const SizedBox(height: 10),
                          _permissionTile(
                            icon: Icons.screen_lock_portrait_rounded,
                            title: 'شاشة الأذان فوق القفل',
                            subtitle: 'إظهار شاشة إيقاف الأذان عند قفل الهاتف (أندرويد 14+)',
                            isGranted: _fsiGranted,
                            onTap: () async {
                              try {
                                await _adhanChannel.invokeMethod('openStartupPermission');
                              } catch (_) {}
                              await _checkAllPermissions();
                            },
                          ),
                          const SizedBox(height: 10),
                          _permissionTile(
                            icon: Icons.battery_charging_full_rounded,
                            title: 'استثناء تحسين البطارية',
                            subtitle: 'منع النظام من إيقاف الأذان والتنبيهات في الخلفية',
                            isGranted: _batteryGranted,
                            onTap: () async {
                              try {
                                await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
                              } catch (_) {
                                await Permission.ignoreBatteryOptimizations.request();
                              }
                              await _checkAllPermissions();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _mainActionButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ملخّص تقدّم التفعيل — عدد الصلاحيات الممنوحة من الإجمالي
  Widget _progressSummary() {
    final int granted = _grantedCount;
    final double ratio = granted / 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _gold.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            granted == 5 ? Icons.verified_rounded : Icons.task_alt_rounded,
            color: granted == 5 ? _greenSuccess : _gold,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              granted == 5
                  ? 'تم تفعيل جميع الصلاحيات ✓'
                  : 'تم تفعيل $granted من 5 صلاحيات',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 90,
            height: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(
                  granted == 5 ? _greenSuccess : _gold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بطاقة عرض حالة الإذن
  Widget _permissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? _greenSuccess.withValues(alpha: 0.5) : _gold.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isGranted ? _greenSuccess.withValues(alpha: 0.15) : _gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isGranted ? _greenSuccess : _gold,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    color: Colors.white60,
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: isGranted ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isGranted
                    ? _greenSuccess.withValues(alpha: 0.15)
                    : _gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isGranted ? _greenSuccess : _gold,
                  width: 1,
                ),
              ),
              child: Text(
                isGranted ? 'مفعّل ✓' : 'تفعيل',
                style: GoogleFonts.cairo(
                  color: isGranted ? _greenSuccess : _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// لوقو التطبيق في الأعلى
  Widget _ornament() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _gold.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.25),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: Image.asset(
          'assets/app_logo_clean.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  /// أزرار القرار: «موافق» لتفعيل الصلاحيات والمتابعة، أو «لا» للمتابعة وتفعيلها بنفسه
  Widget _mainActionButton() {
    return Row(
      children: [
        // زر "لا" — يتابع المستخدم ويفعل الصلاحيات بنفسه لاحقاً
        Expanded(
          flex: 1,
          child: GestureDetector(
            onTap: _proceedToApp,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white24,
                  width: 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  'لا',
                  style: GoogleFonts.cairo(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // زر "موافق" — تفعيل الصلاحيات ثم المتابعة إلى التطبيق
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _checking
                ? null
                : () async {
                    await _requestAllPermissions();
                    await _proceedToApp();
                  },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_gold, _goldDeep],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _gold.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: _checking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1A1304),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.check_rounded,
                            color: Color(0xFF1A1304),
                            size: 20,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'موافق',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              color: Color(0xFF1A1304),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// نقش هندسي إسلامي خفيف (نجمة ثمانية) للخلفية
class _IslamicPatternPainter extends CustomPainter {
  const _IslamicPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDFBA6B).withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    const cell = 56.0;
    for (double x = -cell; x < size.width + cell; x += cell) {
      for (double y = -cell; y < size.height + cell; y += cell) {
        final cx = x + cell / 2;
        final cy = y + cell / 2;
        final r = cell * 0.28;
        final path = Path();
        for (int i = 0; i < 8; i++) {
          final a1 = i * math.pi / 4;
          final a2 = a1 + math.pi / 8;
          final p1 = Offset(cx + r * math.cos(a1), cy + r * math.sin(a1));
          final p2 = Offset(
              cx + r * 0.45 * math.cos(a2), cy + r * 0.45 * math.sin(a2));
          if (i == 0) {
            path.moveTo(p1.dx, p1.dy);
          } else {
            path.lineTo(p1.dx, p1.dy);
          }
          path.lineTo(p2.dx, p2.dy);
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IslamicPatternPainter oldDelegate) => false;
}