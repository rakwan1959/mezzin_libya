import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/glass_theme.dart';

/// ─────────────────────────────────────────────────────────────────────────────
///  أيقونة تبويب **ثلاثية الأبعاد** لشريط المهام السفلي (التاسك بار).
///
///  الزر ليس أيقونة مسطّحة تُلوَّن عند الاختيار، بل جسم له سماكة ووجه ومنظور:
///
///    1. **الجدار الجانبي** — نسخة داكنة من اللوح تنزاح للأسفل بمقدار
///       [GlassNavSpec.plateDepth]، فتُقرأ كسماكة للزر لا كخطّ.
///    2. **الوجه العلوي** — زجاج متدرّج بلون الصلاة النشطة + حافة بيضاء
///       + لمعة زجاجية أعلى الوجه (انعكاس الضوء).
///    3. **الحرف المجسّم** — عدة نسخ متراكمة للأسفل ([GlassNavSpec.extrudeLayers])
///       ثم النسخة المضيئة في الأعلى، فيبدو الحرف بارزاً عن وجه الزر.
///    4. **المنظور** — `setEntry(3, 2, …)` + ميل حول المحور الأفقي، فينكبّ
///       الزر عند الضغط ويغوص في السطح بدل أن يبقى ملصقاً على الشاشة.
///    5. **التنفّس** — التبويب النشط يطفو حركةً بطيئة، وتُحترم فيها
///       [GlassRuntime.motion] فيتوقّف كل شيء إذا أوقف المستخدم الحركة.
///
///  الحركة كلها مشتقّة من رقمين فقط: [sink] (مقدار الغوص) و[pop] (مقدار
///  الظهور/الاختيار)، فلا يوجد تأثير جزئي يُنسى أو يتعارض مع غيره.
/// ─────────────────────────────────────────────────────────────────────────────
class GlassNavIcon extends StatefulWidget {
  const GlassNavIcon({
    super.key,
    required this.selected,
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.accent,
    this.onTap,
  });

  /// هل هذا التبويب هو المختار الآن؟
  final bool selected;

  /// الأيقونة الممتلئة (تُعرض عند الاختيار).
  final IconData selectedIcon;

  /// الأيقونة المفرغة (تُعرض في بقية الأحوال).
  final IconData unselectedIcon;

  /// لون الصلاة النشطة في التطبيق — منه يُبنى **كل** لون في الزر.
  final Color accent;

  final VoidCallback? onTap;

  @override
  State<GlassNavIcon> createState() => _GlassNavIconState();
}

class _GlassNavIconState extends State<GlassNavIcon>
    with TickerProviderStateMixin {
  /// الغوص: 1 = مضغوط للأسفل، وقد يصبح سالباً قليلاً لحظة الارتداد.
  late final AnimationController _press;

  /// الاختيار: 0 = تبويب عادي، 1 = التبويب النشط (بمنحنى نابض).
  late final AnimationController _select;

  /// تنفّس التبويب النشط (يُشغَّل فقط إذا كانت الحركة مفعّلة).
  late final AnimationController _bob;

  late final Animation<double> _sink;
  late final Animation<double> _pop;
  late final Listenable _repaint;

  @override
  void initState() {
    super.initState();

    _press = AnimationController(
      vsync: this,
      duration: GlassNavSpec.pressIn,
      reverseDuration: GlassNavSpec.pressOut,
    );
    _select = AnimationController(
      vsync: this,
      duration: GlassNavSpec.duration,
      value: widget.selected ? 1.0 : 0.0,
    );
    _bob = AnimationController(vsync: this, duration: GlassNavSpec.bobDuration);

    // النزول: سريع كلمسة إصبع. الارتداد: منحنى easeIn على القيمة المقلوبة
    // يعني ارتداداً فورياً مع تجاوز طفيف للأعلى (sink سالب) ثم استقراراً —
    // وهو نفسه إحساس الزنبرك، بلا مؤثّر ثالث يُدار.
    _sink = CurvedAnimation(
      parent: _press,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInBack,
    );
    _pop = CurvedAnimation(parent: _select, curve: GlassNavSpec.curve);

    _repaint = Listenable.merge(<Listenable>[_sink, _pop, _bob]);
    _syncBreathe();
  }

  @override
  void didUpdateWidget(covariant GlassNavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      if (widget.selected) {
        _select.forward();
      } else {
        _select.reverse();
      }
      _syncBreathe();
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _select.dispose();
    _bob.dispose();
    super.dispose();
  }

  /// التنفّس يعمل للتبويب النشط وحده، وفقط إذا كانت الحركة مفعّلة في المظهر.
  void _syncBreathe() {
    final bool wanted = widget.selected && GlassRuntime.motion;
    if (wanted && !_bob.isAnimating) {
      _bob.repeat(reverse: true);
    } else if (!wanted && _bob.isAnimating) {
      _bob.stop();
      _bob.value = 0.0;
    }
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    // إعادة تشغيل النبضة لو ضُغط التبويب النشط نفسه، فيرتدّ بدل أن يبقى ساكناً.
    if (widget.selected) _select.forward(from: 0.0);
    widget.onTap?.call();
  }

  void _release() {
    if (_press.status == AnimationStatus.forward || _press.value > 0) {
      _press.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press.forward(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        onTap: _handleTap,
        // حدّ **أدنى** لا مقاس ثابت: داخل شريط المهام يتوزّع التبويبات على
        // عرض الشاشة (Expanded)، وهذا يضمن ألّا يقلّ هدف اللمس عن الحدّ
        // المريح للإصبع عند الوقوف وحدها، وألّا يرتفع الشريط أو ينقص أبداً.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: GlassNavSpec.touchWidth,
            minHeight: GlassNavSpec.itemHeight,
          ),
          child: AnimatedBuilder(
            animation: _repaint,
            builder: (BuildContext context, Widget? child) => _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final double sink = _sink.value.clamp(-0.30, 1.25);
    final double pop = _pop.value.clamp(0.0, 1.25);
    final bool active = widget.selected;
    final Color accent = widget.accent;

    // ظهور اللوح يتبع قيمة الاختيار لا حالة الويدجت، فيتلاشى بنعومة عند المغادرة.
    final double appear = pop.clamp(0.0, 1.0);

    // ── العمق: النشط يرتفع، والضغط يغوص، والتنفّس يطفو ──
    final double lift = GlassNavSpec.activeLift * appear -
        GlassNavSpec.pressTravel * sink -
        GlassNavSpec.bobAmplitude * _bob.value * appear;

    final double scale =
        (1 - (1 - GlassNavSpec.pressScale) * sink).clamp(0.70, 1.20);

    final double tilt = GlassNavSpec.tiltIdle +
        GlassNavSpec.tiltActive * appear +
        GlassNavSpec.tiltPressed * sink;

    // حجم الحرف ينتقل بين المقاسين بقيمة الاختيار لا بقفزة عند التبديل.
    final double size = active
        ? _lerp(GlassNavSpec.iconInactive, GlassNavSpec.iconActive, appear)
        : _lerp(GlassNavSpec.iconActive, GlassNavSpec.iconInactive, 1 - appear);

    final Matrix4 transform = Matrix4.identity()
      ..setEntry(3, 2, GlassNavSpec.perspective)
      ..translateByDouble(0.0, lift, 0.0, 1.0)
      ..rotateX(tilt)
      ..scaleByDouble(scale, scale, scale, 1.0);

    return Transform(
      alignment: Alignment.center,
      transform: transform,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _buildPlate(accent: accent, appear: appear, sink: sink, size: size),
          const SizedBox(height: 3),
          _buildIndicator(accent: accent, appear: appear, sink: sink),
        ],
      ),
    );
  }

  /// اللوح: جدار جانبي داكن (السماكة) + وجه زجاجي + لمعة، وفوقه الحرف المجسّم.
  Widget _buildPlate({
    required Color accent,
    required double appear,
    required double sink,
    required double size,
  }) {
    const double plate = GlassNavSpec.plateSize;
    final double depth = GlassNavSpec.plateDepth * (1 - 0.55 * sink);

    return SizedBox(
      width: plate,
      height: plate,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (appear > 0.01) ...<Widget>[
            // 1) الجدار الجانبي: سماكة الزر.
            Transform.translate(
              offset: Offset(0, depth),
              child: Container(
                width: plate,
                height: plate,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: GlassNavSpec.plateWall(accent, appear),
                ),
              ),
            ),
            // 2) الوجه العلوي: زجاج ملوّن + حافة بلورية + ظل وتوهّج.
            Container(
              width: plate,
              height: plate,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: GlassNavSpec.plateFace(accent, appear),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.32 * appear),
                  width: 1,
                ),
                boxShadow: GlassNavSpec.plateShadow(accent, appear, sink),
              ),
            ),
            // 3) لمعة الضوء أعلى الوجه — سرّ الإحساس بالزجاج المصقول.
            Align(
              alignment: const Alignment(0, -0.62),
              child: Container(
                width: plate * 0.46,
                height: plate * 0.20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(plate),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.52 * appear),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
          // 4) الحرف المجسّم.
          _buildGlyph(
            accent: accent,
            appear: appear,
            sink: sink,
            size: size,
          ),
        ],
      ),
    );
  }

  /// الحرف: طبقات سماكة متراكمة للأسفل ثم الوجه المضيء في الأعلى.
  Widget _buildGlyph({
    required Color accent,
    required double appear,
    required double sink,
    required double size,
  }) {
    final IconData glyph =
        widget.selected ? widget.selectedIcon : widget.unselectedIcon;
    final Color ink = widget.selected
        ? GlassNavSpec.activeIconColor(accent)
        : GlassNavSpec.inactiveIconColor(accent);
    final Color side = GlassNavSpec.extrudeColor(accent);

    // النشط أبرز، والضغط يُسطّح الحرف فيبدو غائراً في وجه الزر.
    final double depth = GlassNavSpec.extrudeStep *
        GlassNavSpec.extrudeLayers *
        (0.45 + 0.55 * appear) *
        (1 - 0.70 * sink);

    final double glow = (appear * (1 - 0.55 * sink)).clamp(0.0, 1.0);

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        for (int i = GlassNavSpec.extrudeLayers; i >= 1; i--)
          Transform.translate(
            offset: Offset(
              0,
              depth * i / GlassNavSpec.extrudeLayers,
            ),
            child: Icon(
              glyph,
              size: size,
              color: side.withValues(alpha: 0.22 + 0.13 * i),
            ),
          ),
        Icon(
          glyph,
          size: size,
          color: ink,
          shadows: glow > 0.02
              ? <Shadow>[
                  Shadow(
                    color: accent.withValues(alpha: 0.85 * glow),
                    blurRadius:
                        GlassNavSpec.iconGlowBlur * (1 - 0.35 * sink),
                  ),
                ]
              : null,
        ),
      ],
    );
  }

  /// المؤشر الصغير أسفل الأيقونة — خرزة مضيئة بلون الصلاة.
  Widget _buildIndicator({
    required Color accent,
    required double appear,
    required double sink,
  }) {
    final double d = GlassNavSpec.indicatorSize * appear;
    // العرض مثبّت على عرض اللوح: `Center` يتمدد بأقصى عرض متاح، وتثبيته هنا
    // يمنع العنصر من سحب عرض الشريط كله على الشاشات العريضة.
    return SizedBox(
      width: GlassNavSpec.plateSize,
      height: GlassNavSpec.indicatorSize,
      child: Center(
        child: d <= 0.2
            ? const SizedBox.shrink()
            : Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accent
                          .withValues(alpha: (0.85 * (1 - 0.40 * sink)).clamp(0.0, 1.0)),
                      blurRadius: 6 * (1 - 0.30 * sink),
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  static double _lerp(double a, double b, double t) =>
      a + (b - a) * t.clamp(0.0, 1.0);
}
