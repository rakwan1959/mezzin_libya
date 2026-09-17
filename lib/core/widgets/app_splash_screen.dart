import 'dart:async';

import 'package:flutter/material.dart';

import 'glass_scaffold.dart';

/// شاشة البداية — تعرض لوقو التطبيق بخلفية سوداء فاخرة لمدة 5 ثوانٍ
/// ثم تنتقل بسلاسة إلى المحتوى الفعلي للتطبيق.
class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({super.key, required this.child});

  /// المحتوى الذي يظهر بعد انتهاء مدة العرض.
  final Widget child;

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen> {
  static bool _hasShownSplash = false;
  Timer? _timer;
  late bool _showSplash;

  @override
  void initState() {
    super.initState();
    _showSplash = !_hasShownSplash;
    if (_showSplash) {
      _startTimer();
    }
  }

  void _startTimer() {
    // شاشة البداية باللون الأسود تبقى لمدة 5 ثوانٍ كما طُلب
    _timer = Timer(const Duration(seconds: 5), () {
      _hasShownSplash = true;
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _showSplash ? const _SplashView() : widget.child,
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      body: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Image.asset(
              'assets/app_logo_clean.png',
              width: 220,
              height: 220,
            ),
          ),
        ),
      ),
    );
  }
}
