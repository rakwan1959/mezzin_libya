import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';

/// ════════════════════════════════════════════════════════════════════════════
///  الخلفية الأورورا النابضة — الأساس الذي يمنح الزجاج عمقه وشفافيته الملوّنة.
///
///  تُرسم طبقتان: تدرّج أساسي ملوّن + ثلاث بقع ضوئية (Aurora Blobs) تتحرّك
///  ببطء شديد. لأن الرسم يتم عبر [CustomPainter] واحد، فإن الشاشة الزجاجية
///  فوقها (BackdropFilter) تُعيد المعالجة دون أي إعادة بناء للويدجتات.
/// ════════════════════════════════════════════════════════════════════════════
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    super.key,
    required this.child,
    required this.colors,
    this.glowColors,
    this.animated = true,
    this.intensity = GlassSpec.auroraMotion,
    this.vignette = true,
    this.duration = GlassSpec.backgroundCycle,
  });

  final Widget child;

  /// ألوان التدرّج الأساسي (من [GlassPalette.gradientFor]).
  final List<Color> colors;

  /// ألوان بقع الأورورا (من [GlassPalette.auroraGlowFor]).
  final List<Color>? glowColors;

  /// إيقاف الحركة (مفيد في الشاشات الثقيلة مثل الفيديو والقرآن).
  final bool animated;

  /// شدّة الأورورا (0 = طبقة مسطّحة).
  final double intensity;

  /// تعتيم الحواف لإبراز المحتوى المركزي.
  final bool vignette;

  final Duration duration;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animated) _start();
  }

  void _start() {
    _controller ??= AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant AuroraBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated && !oldWidget.animated) {
      _start();
    } else if (!widget.animated && oldWidget.animated) {
      _controller?.stop();
    }
    if (widget.duration != oldWidget.duration) {
      _controller?.duration = widget.duration;
      if (widget.animated) _controller?.repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glows = widget.glowColors ?? const [GlassPalette.auroraCyan, GlassPalette.auroraViolet, GlassPalette.gold];

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _AuroraPainter(
              colors: widget.colors,
              glowColors: glows,
              intensity: widget.intensity,
              vignette: widget.vignette,
              animation: _controller ?? const AlwaysStoppedAnimation<double>(0.0),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.colors,
    required this.glowColors,
    required this.intensity,
    required this.vignette,
    required this.animation,
  }) : super(repaint: animation);

  final List<Color> colors;
  final List<Color> glowColors;
  final double intensity;
  final bool vignette;
  final Animation<double> animation;

  /// مواضع بقع الأورورا الثلاث في فضاء [-1, 1] مع نصف قطر وشدّة لكل بقعة.
  static const List<_GlowSpec> _specs = [
    _GlowSpec(ax: -0.78, ay: -0.72, bx: 0.30, by: 0.22, r: 0.88, i: 0.58),
    _GlowSpec(ax: 0.82, ay: -0.28, bx: 0.26, by: 0.34, r: 0.72, i: 0.46),
    _GlowSpec(ax: -0.26, ay: 0.86, bx: 0.32, by: 0.24, r: 0.98, i: 0.42),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // ── 1) التدرّج الأساسي ──────────────────────────────────────────────
    final baseColors = colors.length >= 2 ? colors : [colors.first, colors.first];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: baseColors,
        ).createShader(rect),
    );

    if (intensity <= 0) {
      _paintVignette(canvas, size, rect);
      return;
    }

    // ── 2) بقع الأورورا النابضة ─────────────────────────────────────────
    final t = animation.value;
    final phase = t * 2 * math.pi;

    for (var index = 0; index < _specs.length; index++) {
      final spec = _specs[index];
      final color = glowColors[index % glowColors.length];

      final dx = spec.ax + spec.bx * math.sin(phase * (1.0 + index * 0.25) + index);
      final dy = spec.ay + spec.by * math.cos(phase * (0.85 + index * 0.2) + index);

      final center = Offset(
        size.width * (0.5 + dx * 0.5),
        size.height * (0.5 + dy * 0.5),
      );
      final radius = size.shortestSide * spec.r;

      // البقعة الملوّنة
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.42 * spec.i * intensity),
              color.withValues(alpha: 0.16 * spec.i * intensity),
              color.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // ── 3) وميض علوي خفيف يمنح الإحساس بالعمق ──────────────────────────
    // على تدرّج أسود صافٍ (وضع «أسود») يُلغى الوميض: أي طبقة بيضاء فوق
    // الأسود تُقرأ رمادياً وتُذهب سواد الشاشة على شاشات OLED.
    final brightestBase = baseColors
        .map((Color c) => c.computeLuminance())
        .reduce((double a, double b) => a > b ? a : b);
    if (brightestBase > 0.01) {
      final topSheen = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.06 * intensity),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.42));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.42), topSheen);
    }

    _paintVignette(canvas, size, rect);
  }

  void _paintVignette(Canvas canvas, Size size, Rect rect) {
    if (!vignette || intensity <= 0) return;
    final center = rect.center;
    final radius = size.longestSide * 0.78;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: radius / size.width,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.10),
            Colors.black.withValues(alpha: 0.34),
          ],
          stops: const [0.45, 0.78, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.colors != colors ||
      old.glowColors != glowColors ||
      old.intensity != intensity ||
      old.vignette != vignette;
}

class _GlowSpec {
  const _GlowSpec({
    required this.ax,
    required this.ay,
    required this.bx,
    required this.by,
    required this.r,
    required this.i,
  });

  /// نقطة الارتكاز
  final double ax;
  final double ay;

  /// نصف قطر الحركة
  final double bx;
  final double by;

  /// نصف قطر البقعة نسبةً لأصغر ضلع في الشاشة
  final double r;

  /// شدّة السطوع
  final double i;
}
