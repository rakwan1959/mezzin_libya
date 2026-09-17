import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';
import 'glass_widgets.dart';

/// ════════════════════════════════════════════════════════════════════════════
///  واجهات زجاجية قديمة — أُعيد بناؤها على نظام التصميم الموحّد.
///
///  كلا الويدجتين يحتفظان بنفس الواجهة البرمجية السابقة حتى لا تتأثر أي شاشة
///  تستخدمهما، لكن الشكل البصري أصبح مدفوعاً بالكامل من [GlassPalette]
///  و [GlassSpec] (زجاج شفاف فائق + حافة كريستالية + توهّج ملوّن).
///
///  للشيفرة الجديدة استخدم [GlassPanel] مباشرة.
/// ════════════════════════════════════════════════════════════════════════════

/// @Deprecated استخدم [GlassPanel] بدلاً منه.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final double blur;
  final double opacity;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.border,
    this.blur = GlassSpec.blurThin,
    this.opacity = 0.05,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      blur: blur,
      border: border,
      tint: null,
      fillOpacity: (opacity / 0.05).clamp(0.5, 2.0),
      child: child,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  البطاقة الزجاجية الأورورا — النسخة المحسّنة.
///
///  نفس الواجهة البرمجية السابقة، لكن الشكل الآن:
///    • شفافية فائقة تُظهر تدرّج الأورورا من خلفها
///    • حافة كريستالية متدرّجة + حافة داخلية لامعة (سماكة زجاجية)
///    • زيادة تشبّع تلقائية لما خلف الزجاج (Vibrancy)
///    • توهّج ملوّن عند التفعيل
/// ─────────────────────────────────────────────────────────────────────────────
class AuroraGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blur;
  final double opacity;
  final bool isActive;
  final Color? glowColor;
  final List<Color>? gradientColors;
  final BoxBorder? border;
  final VoidCallback? onTap;

  /// ألوان أوضح للزجاج فوق الخلفيات الفاتحة/الصور.
  final Color? tint;

  /// إيقاف زيادة التشبّع (مفيد فوق الفيديو).
  final bool vibrancy;

  const AuroraGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur = GlassSpec.blurRegular,
    this.opacity = 0.07,
    this.isActive = false,
    this.glowColor,
    this.gradientColors,
    this.border,
    this.onTap,
    this.tint,
    this.vibrancy = true,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius ?? BorderRadius.circular(GlassSpec.radiusLg),
      blur: blur,
      accent: glowColor,
      active: isActive,
      tint: tint,
      gradientColors: gradientColors,
      border: border,
      onTap: onTap,
      vibrancy: vibrancy ? 1.32 : 1.0,
      fillOpacity: (opacity / 0.07).clamp(0.5, 2.0),
      child: child,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  شريط زجاجي أفقي (للأزرار والشرائط) — يوفّر ضبابية مع حافة مضيئة.
/// ─────────────────────────────────────────────────────────────────────────────
class AuroraGlassBar extends StatelessWidget {
  const AuroraGlassBar({
    super.key,
    required this.child,
    this.padding,
    this.blur = GlassSpec.blurHeavy,
    this.accent,
    this.radius = GlassSpec.radiusXl,
    this.borderSide = true,
    this.fillOpacity,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final Color? accent;
  final double radius;
  final bool borderSide;
  final double? fillOpacity;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: padding,
      borderRadius: BorderRadius.circular(radius),
      blur: blur,
      accent: accent,
      fillOpacity: fillOpacity,
      child: child,
    );
  }
}
