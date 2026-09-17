import 'dart:ui' as ui;

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';
import 'aurora_background.dart';

/// ════════════════════════════════════════════════════════════════════════════
///  الهيكل الزجاجي الموحّد لكل شاشات التطبيق.
///
///  ```dart
///  GlassScaffold(
///    themeMode: 'navy',
///    appBar: const GlassAppBar(title: Text('العلامات المرجعية')),
///    body: ListView(children: [...]),
///  )
///  ```
///
///  • يرسم الخلفية الأورورا النابضة من [GlassPalette] حسب وضع العرض.
///  • يجعل خلفية الـ Scaffold شفافة حتى يظهر الزجاج فوق الأورورا.
///  • لا يحتاج أي شاشة لتكرار تعريف التدرّج أو الألوان.
/// ════════════════════════════════════════════════════════════════════════════
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    required this.body,
    this.themeMode,
    this.nextPrayer,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBodyBehindAppBar = false,
    this.extendBody = false,
    this.animated = true,
    this.intensity = GlassSpec.auroraMotion,
    this.resizeToAvoidBottomInset = true,
    this.safeArea = false,
    this.gradientColors,
    this.glowColors,
    this.backgroundColor,
    this.overlay,
  });

  final Widget body;

  /// وضع العرض؛ إذا لم يُحدَّد يُستخدم الوضع الحالي للتطبيق ([GlassRuntime]).
  final String? themeMode;
  final Prayer? nextPrayer;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool extendBodyBehindAppBar;
  final bool extendBody;
  final bool animated;
  final double intensity;
  final bool resizeToAvoidBottomInset;
  final bool safeArea;

  /// تجاوز التدرّج الافتراضي (لشاشات تريد لوناً خاصاً).
  final List<Color>? gradientColors;
  final List<Color>? glowColors;

  /// طبقة فوق الخلفية وتحت المحتوى (تدرّج تعتيم، صورة، …).
  final Color? backgroundColor;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final mode = themeMode ?? GlassRuntime.themeMode;
    final prayer = nextPrayer ?? GlassRuntime.nextPrayer;
    final colors = gradientColors ?? GlassPalette.gradientFor(mode, nextPrayer: prayer);
    final glows = glowColors ?? GlassPalette.auroraGlowFor(mode, nextPrayer: prayer);
    // حركة الخلفية وقوّة التوهّج تتبعان اختيار المستخدم من الإعدادات
    final animate = animated && GlassRuntime.motion;
    final glowStrength = intensity * GlassRuntime.glowScale;

    Widget content = body;
    if (safeArea) content = SafeArea(child: content);

    return AuroraBackground(
      colors: colors,
      glowColors: glows,
      animated: animate,
      intensity: glowStrength,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundColor != null) ColoredBox(color: backgroundColor!),
          ?overlay,
          Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: resizeToAvoidBottomInset,
            extendBodyBehindAppBar: extendBodyBehindAppBar,
            extendBody: extendBody,
            appBar: appBar,
            body: content,
            bottomNavigationBar: bottomNavigationBar,
            floatingActionButton: floatingActionButton,
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  شريط علوي زجاجي — بديل موحّد لـ AppBar.
///  يدعم الحافة السفلية المضيئة والضبابية القابلة للضبط.
/// ─────────────────────────────────────────────────────────────────────────────
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.height = kToolbarHeight,
    this.blur = GlassSpec.blurHeavy,
    this.accent,
    this.centerTitle = true,
    this.automaticallyImplyLeading = true,
    this.borderBottom = true,
    this.toolbarOpacity,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double height;
  final double blur;
  final Color? accent;
  final bool centerTitle;
  final bool automaticallyImplyLeading;
  final bool borderBottom;

  /// شفافية الشريط؛ الافتراضي زجاج فائق الشفافية.
  final double? toolbarOpacity;

  @override
  Size get preferredSize => Size.fromHeight(height + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final glow = accent ?? GlassPalette.gold;

    final effectiveBlur = blur * GlassRuntime.blurScale;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: toolbarOpacity ?? 0.06),
                Colors.white.withValues(alpha: (toolbarOpacity ?? 0.06) * 0.25),
              ],
            ),
            border: borderBottom
                ? Border(
                    bottom: BorderSide(color: glow.withValues(alpha: 0.28), width: 1),
                  )
                : null,
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: height,
                  child: Row(
                    children: [
                      if (automaticallyImplyLeading && leading == null)
                        _GlassBackButton(onTap: () => Navigator.maybePop(context)),
                      ?leading,
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Align(
                            alignment: centerTitle ? Alignment.center : AlignmentDirectional.centerStart,
                            child: DefaultTextStyle(
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                              child: title ?? const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                      if (actions != null)
                        ...actions!.map(
                          (a) => IconTheme(
                            data: const IconThemeData(color: Colors.white),
                            child: a,
                          ),
                        ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                ?bottom,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBackButton extends StatelessWidget {
  const _GlassBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
      tooltip: 'رجوع',
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  ترويسة قسم زجاجية (عنوان قسم داخل الصفحة).
/// ─────────────────────────────────────────────────────────────────────────────
class GlassSectionHeader extends StatelessWidget {
  const GlassSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.accent,
    this.trailing,
    this.margin = const EdgeInsets.fromLTRB(16, 20, 16, 10),
  });

  final String title;
  final IconData? icon;
  final Color? accent;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? GlassPalette.gold;

    return Padding(
      padding: margin,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color, color.withValues(alpha: 0.20)],
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          if (icon != null) ...[
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                shadows: [
                  Shadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 8),
                ],
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
