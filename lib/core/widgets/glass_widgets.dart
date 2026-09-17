import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';

/// ════════════════════════════════════════════════════════════════════════════
///  مكتبة المكوّنات الزجاجية المشتركة.
///
///  كل عنصر هنا يستمد ألوانه ومقاييسه من [GlassPalette] و [GlassSpec]، لذا
///  يكفي تغيير قيمة واحدة هناك ليتغيّر المظهر في التطبيق بأكمله.
/// ════════════════════════════════════════════════════════════════════════════

/// ─────────────────────────────────────────────────────────────────────────────
///  اللوحة الزجاجية الأساسية (Glass Panel)
///  الأساس البصري لكل بطاقة/حاوية في التطبيق: ضبابية + شفافية عالية +
///  حافة بلورية متدرّجة + لمعان داخلي + توهّج اختياري.
/// ─────────────────────────────────────────────────────────────────────────────
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.blur = GlassSpec.blurRegular,
    this.tint,
    this.accent,
    this.active = false,
    this.gradientColors,
    this.border,
    this.shadows,
    this.onTap,
    this.showSheen = true,
    this.showBorder = true,
    this.showInnerEdge = true,
    this.vibrancy = 1.32,
    this.fillOpacity,
    this.baseColor,
    this.baseOpacity = 0.92,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  /// شدّة الضبابية — استخدم قيم [GlassSpec].
  final double blur;

  /// لون الصبغة الملوّنة للزجاج (يمنح شفافية ملوّنة).
  final Color? tint;

  /// لون التمييز عند التفعيل.
  final Color? accent;

  /// الحالة النشطة: تعبئة أقوى + حدود مضيئة + توهّج.
  final bool active;

  /// تجاوز كامل لتدرّج التعبئة.
  final List<Color>? gradientColors;

  /// تجاوز الحدود (يُرسم فوق الضبابية ليبقى حاداً).
  final BoxBorder? border;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final bool showSheen;
  final bool showBorder;

  /// الحافة الداخلية اللامعة الثانية التي تُرسم داخل الحدّ الخارجي.
  ///
  /// جعلها `false` يجعل الحدّ **خطّاً واحداً** — وهو المطلوب لأسطح الرسائل
  /// (الحوارات والإشعارات والأزرار وكاردات المراسلة) لأن الخطّين المتوازيين
  /// كانا يظهران كخطّين تحت كلمات الرسالة.
  final bool showInnerEdge;

  /// زيادة تشبّع ما خلف الزجاج — تمنح الألوان نقاءً أعلى (iOS Vibrancy).
  final double vibrancy;

  /// مضاعف شفافية التعبئة (1.0 = الافتراضي).
  final double? fillOpacity;

  /// طبقة لون أساسية تُرسم أسفل تدرّج الزجاج — تُستخدم لصبغ سطح الرسائل
  /// بالكحلي الملكي فتبقى كل الإشعارات والتنبيهات بلون واحد.
  final Color? baseColor;

  /// شفافية الطبقة الأساسية.
  final double baseOpacity;

  ui.ImageFilter get _filter {
    // شدّة الضبابية تتبع اختيار المستخدم لشدّة الشفافية
    final effectiveBlur = blur * GlassRuntime.blurScale;
    final blurFilter = ui.ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur);
    if (vibrancy <= 1.0) return blurFilter;
    final v = vibrancy;
    final t = (1 - v) * 128.0;
    final saturation = ui.ColorFilter.matrix(<double>[
      v, 0, 0, 0, t,
      0, v, 0, 0, t,
      0, 0, v, 0, t,
      0, 0, 0, 1, 0,
    ]);
    return ui.ImageFilter.compose(outer: blurFilter, inner: saturation);
  }

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(GlassSpec.radiusLg);
    final glow = accent ?? tint ?? GlassPalette.gold;
    // مضاعف شفافية التعبئة = طلب العنصر × اختيار المستخدم لشدّة الشفافية
    final k = (fillOpacity ?? 1.0) * GlassRuntime.fillScale;

    final fill = gradientColors != null
        ? LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: gradientColors!
                .map((c) => c.withValues(alpha: (c.a * k).clamp(0.0, 1.0)))
                .toList(),
            // لا نمرّر نقاط توقّف إلا عندما يكون عددها مطابقاً لعدد الألوان
            stops: gradientColors!.length == 3 ? const [0.0, 0.5, 1.0] : null,
          )
        : tint != null
            ? GlassSpec.tintedGlassGradient(tint!, active: active)
            : GlassSpec.glassGradient(active: active);

    final defaultBorder = Border.all(
      color: active
          ? glow.withValues(alpha: GlassSpec.borderOpacityActive)
          : Colors.white.withValues(alpha: GlassSpec.borderOpacity),
      width: active ? GlassSpec.borderWidthActive : GlassSpec.borderWidth,
    );

    final panel = ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: _filter,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // 0) الطبقة اللونية الأساسية (سطح الرسالة) — أسفل الزجاج الملوّن
            if (baseColor != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: baseColor!.withValues(alpha: (baseOpacity * k).clamp(0.0, 1.0)),
                  ),
                ),
              ),

            // 1) تعبئة الزجاج
            Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(gradient: fill)),
            ),

            // 2) لمعان علوي دقيق (Specular Sheen)
            if (showSheen)
              Positioned(
                top: 0,
                left: 16,
                right: 16,
                height: 1.2,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(
                            alpha: active ? GlassSpec.sheenOpacityActive : GlassSpec.sheenOpacity,
                          ),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // 3) المحتوى
            Padding(padding: padding ?? const EdgeInsets.all(16), child: child),

            // 4) الحدود الكريستالية — تُرسم فوق الضبابية لتبقى حدّة تماماً
            if (showBorder && border == null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _GlassBorderPainter(
                      radius: br.topLeft.x,
                      color: active ? glow.withValues(alpha: 0.72) : Colors.white.withValues(alpha: 0.30),
                      secondary: active ? glow.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06),
                      width: active ? GlassSpec.borderWidthActive : GlassSpec.borderWidth,
                      // خطّ واحد فقط عندما يُطلب ذلك: بلا حافة داخلية ثانية
                      innerEdge: Colors.white.withValues(
                        alpha: showInnerEdge ? GlassSpec.innerEdgeOpacity : 0.0,
                      ),
                    ),
                  ),
                ),
              ),
            if (showBorder && border != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(borderRadius: br, border: border ?? defaultBorder),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    Widget wrapped = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: shadows ??
            (active
                ? GlassSpec.glowShadow(glow)
                : GlassSpec.softShadow()),
      ),
      child: panel,
    );

    if (onTap != null) {
      wrapped = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: wrapped,
      );
    }
    return wrapped;
  }
}

/// رسّام الحدود الكريستالية المتدرّجة + الحافة الداخلية اللامعة.
class _GlassBorderPainter extends CustomPainter {
  _GlassBorderPainter({
    required this.radius,
    required this.color,
    required this.secondary,
    required this.width,
    required this.innerEdge,
  });

  final double radius;
  final Color color;
  final Color secondary;
  final double width;
  final Color innerEdge;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = width / 2;
    final rect = Rect.fromLTWH(inset, inset, size.width - width, size.height - width);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // الحافة الخارجية المتدرّجة (أعلى-يمين ساطعة → أسفل-يسار خافتة)
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [color, secondary, color.withValues(alpha: color.a * 0.45)],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // حافة داخلية رقيقة تمنح الإحساس بسماكة الزجاج — ولا تُرسم إن كان
    // السطح بخطّ واحد (innerEdge شفّافة تماماً).
    if (innerEdge.a > 0) {
      final innerRect = rect.deflate(width);
      canvas.drawRRect(
        RRect.fromRectAndRadius(innerRect, Radius.circular((radius - width).clamp(0, radius))),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = innerEdge,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlassBorderPainter old) =>
      old.color != color ||
      old.secondary != secondary ||
      old.width != width ||
      old.radius != radius ||
      old.innerEdge != innerEdge;
}

/// ─────────────────────────────────────────────────────────────────────────────
///  عنصر قائمة زجاجي موحّد.
/// ─────────────────────────────────────────────────────────────────────────────
class GlassListTile extends StatelessWidget {
  const GlassListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.icon,
    this.onTap,
    this.accent,
    this.margin = const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.borderRadius,
    this.blur = GlassSpec.blurRegular,
    this.isThreeLine = false,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? accent;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double blur;
  final bool isThreeLine;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? GlassPalette.gold;

    Widget? lead = leading;
    if (lead == null && icon != null) {
      lead = Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.26),
              color.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(GlassSpec.radiusXs + 2),
          border: Border.all(color: color.withValues(alpha: 0.30)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.20), blurRadius: 12, spreadRadius: -2),
          ],
        ),
        child: Icon(icon, color: color, size: 19),
      );
    }

    return GlassPanel(
      margin: margin,
      padding: padding,
      blur: blur,
      borderRadius: borderRadius ?? BorderRadius.circular(GlassSpec.radiusMd),
      onTap: onTap,
      child: Row(
        children: [
          if (lead != null) ...[lead, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: dense ? 13.5 : 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: isThreeLine ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: dense ? 11.5 : 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  زر زجاجي موحّد (ممتلئ / مفرّغ).
/// ─────────────────────────────────────────────────────────────────────────────
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.accent,
    this.filled = true,
    this.expand = false,
    this.height = 46,
    this.borderRadius,
    this.fontSize = 14,
    this.fontFamily,
    this.enabled = true,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? accent;
  final bool filled;
  final bool expand;
  final double height;
  final BorderRadius? borderRadius;
  final double fontSize;

  /// خط الوسم — يُترك `null` لخط النظام الافتراضي في بقية الشاشات.
  final String? fontFamily;
  final bool enabled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? GlassPalette.gold;
    final active = enabled && onPressed != null;

    final borderRadiusValue = borderRadius ?? BorderRadius.circular(GlassSpec.radiusMd);

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: filled && active ? const Color(0xFF1A1206) : color),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: filled && active ? const Color(0xFF1A1206) : Colors.white,
              fontSize: fontSize,
              fontFamily: fontFamily,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );

    return Opacity(
      opacity: active ? 1.0 : 0.45,
      child: SizedBox(
        height: height,
        width: expand ? double.infinity : null,
        child: GlassPanel(
          padding: EdgeInsets.symmetric(horizontal: expand ? 16 : 20),
          borderRadius: borderRadiusValue,
          blur: GlassSpec.blurThin,
          vibrancy: 1.15,
          accent: color,
          active: filled,
          gradientColors: filled
              ? [
                  color.withValues(alpha: 0.92),
                  color.withValues(alpha: 0.72),
                ]
              : null,
          tint: filled ? null : color,
          shadows: filled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.34),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ]
              : GlassSpec.softShadow(),
          onTap: active ? onPressed : null,
          showSheen: !filled,
          // حدّ واحد حول الزر — بلا خطّ ثانٍ داخل حدوده
          showInnerEdge: false,
          child: Center(child: content),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  زر أيقونة زجاجي.
/// ─────────────────────────────────────────────────────────────────────────────
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.accent,
    this.size = 42,
    this.iconSize = 20,
    this.active = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? accent;
  final double size;
  final double iconSize;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? GlassPalette.gold;

    final button = GlassPanel(
      width: size,
      height: size,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(GlassSpec.radiusSm),
      blur: GlassSpec.blurThin,
      vibrancy: 1.15,
      accent: color,
      active: active,
      tint: active ? color : null,
      onTap: onTap,
      child: Center(child: Icon(icon, size: iconSize, color: active ? color : Colors.white)),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  رقاقة زجاجية (Chip) — للتصنيفات والخيارات.
/// ─────────────────────────────────────────────────────────────────────────────
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.selected = false,
    this.accent,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;
  final Color? accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? GlassPalette.gold;

    return GlassPanel(
      padding: padding,
      borderRadius: BorderRadius.circular(GlassSpec.radiusXl),
      blur: GlassSpec.blurThin,
      vibrancy: 1.2,
      accent: color,
      active: selected,
      tint: selected ? color : null,
      onTap: onTap,
      showSheen: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: selected ? color : Colors.white.withValues(alpha: 0.8)),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: selected ? color : Colors.white.withValues(alpha: 0.90),
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  حوار زجاجي موحّد — بديل أنيق لـ AlertDialog.
///
/// يعتمد [GlassNoticeKind] لتحديد اللون والأيقونة تلقائياً، فتأخذ كل رسالة
/// ترميزها اللوني الصحيح (تحذير كهرماني، خطأ أحمر، نجاح أخضر، معلومة ذهبية)
/// على خلفية زجاجية مصبوغة بلون النوع نفسه — مع نص أبيض عالي الوضوح.
/// ─────────────────────────────────────────────────────────────────────────────
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  String? title,
  Widget? content,
  String? message,
  IconData? icon,
  Color? accent,
  GlassNoticeKind? kind,
  List<Widget>? actions,
  bool barrierDismissible = true,
  /// السماح بإغلاق الحوار بزر الرجوع في النظام (للرسائل الإلزامية اجعلها false).
  bool canPop = true,
}) {
  final color = accent ?? GlassNoticeSpec.accentOf(kind);
  final leadIcon = icon ?? GlassNoticeSpec.iconOf(kind);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'إغلاق',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: GlassNoticeSpec.duration,
    pageBuilder: (ctx, _, _) => const SizedBox.shrink(),
    transitionBuilder: (ctx, animation, _, _) {
      final curved = CurvedAnimation(parent: animation, curve: GlassNoticeSpec.curve);
      return PopScope(
        canPop: canPop,
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: GlassPanel(
                  width: GlassNoticeSpec.cardWidth,
                  blur: GlassSpec.blurUltra,
                  vibrancy: 1.35,
                  accent: color,
                  tint: color,
                  // سطح موحّد: الكحلي الملكي لكل رسائل التنبيه
                  baseColor: GlassNoticeSpec.surface,
                  baseOpacity: GlassNoticeSpec.dialogSurfaceAlpha,
                  // حدّ واحد حول الرسالة — بلا خطّ ثانٍ تحت كلمات الرسالة
                  showInnerEdge: false,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: GlassNoticeSpec.iconHalo(color),
                            border: Border.all(color: color.withValues(alpha: 0.40)),
                          ),
                          child: Icon(leadIcon, color: color, size: GlassNoticeSpec.iconSize),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (title != null) ...[
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: GlassNoticeSpec.titleColor,
                            fontFamily: GlassNoticeSpec.fontFamily,
                            fontSize: GlassNoticeSpec.titleSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (content != null)
                        content
                      else if (message != null)
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: GlassNoticeSpec.bodyColor
                                .withValues(alpha: GlassNoticeSpec.bodyAlpha),
                            fontFamily: GlassNoticeSpec.fontFamily,
                            fontSize: GlassNoticeSpec.bodySize,
                            height: GlassNoticeSpec.bodyHeight,
                          ),
                        ),
                      if (actions != null && actions.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: actions,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// ─────────────────────────────────────────────────────────────────────────────
///  قائمة سفلية زجاجية موحّدة.
/// ─────────────────────────────────────────────────────────────────────────────
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool isDismissible = true,
  Color? accent,
  double topRadius = GlassSpec.radiusXl,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    isDismissible: isDismissible,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => GlassPanel(
      blur: GlassSpec.blurUltra,
      vibrancy: 1.3,
      accent: accent ?? GlassPalette.gold,
      borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
      padding: EdgeInsets.zero,
      fillOpacity: 1.6,
      showInnerEdge: false,
      child: child,
    ),
  );
}

/// ─────────────────────────────────────────────────────────────────────────────
///  إشعار سريع زجاجي (Snack) — يتبع نفس ترميز [GlassNoticeKind] اللوني.
/// ─────────────────────────────────────────────────────────────────────────────
void showGlassSnack(
  BuildContext context,
  String message, {
  IconData? icon,
  Color? accent,
  GlassNoticeKind? kind,
  Duration duration = const Duration(seconds: 3),
}) {
  final color = accent ?? GlassNoticeSpec.accentOf(kind);
  final leadIcon = icon ?? GlassNoticeSpec.iconOf(kind);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        content: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          borderRadius: BorderRadius.circular(GlassSpec.radiusMd),
          blur: GlassSpec.blurHeavy,
          accent: color,
          tint: color,
          // نفس سطح الحوارات: كحلي ملكي
          baseColor: GlassNoticeSpec.surface,
          baseOpacity: GlassNoticeSpec.snackSurfaceAlpha,
          fillOpacity: 1.5,
          shadows: const [],
          showSheen: false,
          // حدّ واحد فقط — بلا خطّ ثانٍ تحت كلمات الإشعار
          showInnerEdge: false,
          child: Row(
            children: [
              // أيقونة النوع داخل قرص ملوّن — وضوح فوري لنوع الرسالة
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.16),
                  border: Border.all(color: color.withValues(alpha: 0.42)),
                ),
                child: Icon(leadIcon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: GlassNoticeSpec.bodyColor,
                    fontFamily: GlassNoticeSpec.fontFamily,
                    fontSize: GlassNoticeSpec.snackFontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // شريط تمييز بلون النوع على الطرف — ترميز لوني ثابت لا يعتمد على الإضاءة
              Container(
                width: 3,
                height: 26,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
}
