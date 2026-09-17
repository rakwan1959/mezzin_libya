import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../greeting_card_settings.dart';
import '../theme/glass_theme.dart';
import 'glass_widgets.dart';

/// كارد الرسالة الذي يراه المستخدم عند فتح التطبيق.
///
/// كارد عادي هادئ: **نصّ الرسالة الذي كتبه المدير في اللوحة الأولى (1916)**
/// في المنتصف بلون النمط المختار، وزر إغلاق صغير (X) في الزاوية. ولا عنوان
/// ولا دائرة أيقونة ولا زر عريض — كما كان التصميم.
///
/// [message] مطلوب صراحةً (لا قيمة افتراضية) حتى لا يُبنى كاردٌ بلا كتابة
/// سهواً من أي مسار جديد — وهو العطل الذي كان يحدث: الكارد يظهر ولا يظهر
/// فيه نصّ ما كُتب. والنصّ يُسطَّر تلقائياً على عرض الكارد، فإن طال أكثر من
/// ارتفاعه تصغر الكتلة كلها بالتناسب (FittedBox) بدل القصّ أو الأوفرفلو.
class GreetingCard extends StatelessWidget {
  const GreetingCard({
    super.key,
    required this.style,
    required this.onClose,
    required this.message,
    this.onDelete,
    this.width = 264,
    this.height = 176,
  });

  final GreetingCardStyle style;
  final VoidCallback onClose;

  /// حذف الرسالة من التطبيق ومن قاعدة البيانات — إن كان null لا يُرسم الزر.
  final VoidCallback? onDelete;

  /// نصّ الرسالة كما كتبه المدير (يُعرض في منتصف الكارد).
  final String message;

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      width: width,
      height: height,
      blur: GlassSpec.blurUltra,
      vibrancy: 1.35,
      accent: style.accent,
      tint: style.accent,
      // سطح الرسالة بلون النمط المختار من اللوحة
      baseColor: style.surface,
      baseOpacity: 0.97,
      showSheen: false,
      shadows: <BoxShadow>[
        BoxShadow(
          color: style.accent.withValues(alpha: 0.28),
          blurRadius: 34,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.45),
          blurRadius: 26,
          offset: const Offset(0, 10),
        ),
      ],
      // بلا حدود زجاجية مستقيمة: الإطار الإسلامي المرسوم أدناه هو الحدّ الوحيد
      showBorder: false,
      padding: const EdgeInsets.all(4),
      child: Stack(
        children: <Widget>[
          // ── الإطار الإسلامي: خطّان وزخارف ركنية ونجمتان وحبّات جانبية ──
          Positioned.fill(
            child: IgnorePointer(child: IslamicFrame(color: style.accent)),
          ),
          // ── نصّ الرسالة: في المنتصف داخل الإطار ──
          if (message.trim().isNotEmpty)
            Positioned.fill(
              // حشو داخليّ يبعد الكتابة عن الإطار ويترك زر الإغلاق في الزاوية
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 22),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return Center(
                      child: FittedBox(
                        // يصغّر الكتلة عند اللزوم فقط (نصّ طويل جداً)
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          // عرض محدود حتى يُسطَّر النصّ بدل أن يمتدّ سطراً واحداً
                          width: constraints.maxWidth.isFinite
                              ? constraints.maxWidth
                              : width,
                          child: Text(
                            message.trim(),
                            textAlign: TextAlign.center,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              color: style.accent,
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              shadows: <Shadow>[
                                Shadow(
                                  color: style.accent.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          // زر الإغلاق في الزاوية العليا — فوق الإطار بلا تداخل مشوّش
          Positioned(
            top: 2,
            left: 2,
            child: _CardCornerButton(
              color: style.accent,
              background: style.surface,
              onTap: onClose,
            ),
          ),
          // زر حذف الرسالة (الزاوية المقابلة): يُوقفها ويمحوها من التطبيق
          // ومن قاعدة البيانات فتختفي من جميع الأجهزة.
          if (onDelete != null)
            Positioned(
              top: 2,
              right: 2,
              child: _CardCornerButton(
                color: style.accent,
                background: style.surface,
                icon: Icons.delete_outline_rounded,
                tooltip: 'حذف الرسالة من التطبيق ومن قاعدة البيانات',
                onTap: onDelete!,
              ),
            ),
        ],
      ),
    );
  }
}

/// الإطار الإسلامي للرسالة — يُرسم في كارد الرسالة بألوان النمط المختار.
/// عامّ ليمكن اختباره واستعماله في أي رسالة أخرى.
class IslamicFrame extends StatelessWidget {
  const IslamicFrame({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _IslamicFramePainter(color: color));
}

/// إطار إسلامي مرسوم داخل كارد الرسالة: **خطّ واحد فقط**، ومعينات في الأركان،
/// ونجمتان ثمانيتان في منتصف الضلعين الأعلى والأسفل، وسلسلة حبّات دقيقة على
/// الجانبين — كلّه بالرسم لا بصور ولا ملفات خارجية، فيبقى خفيفاً ويتلوّن بلون
/// الكارد المختار.
///
/// حُذفت الأقواس الركنية الثانية التي كانت تُرسم مع الخطّ: هي التي كانت تظهر
/// كخطّين أصفرَّين حول كلمات الرسالة.
class _IslamicFramePainter extends CustomPainter {
  const _IslamicFramePainter({required this.color});

  final Color color;

  /// هامش الإطار الخارجي ومسافة العناصر الداخلية عنه.
  static const double _outerInset = 4;
  static const double _gap = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 40 || h <= 40) return;

    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.78);

    final Paint ornament = Paint()..color = color.withValues(alpha: 0.55);
    final Paint bead = Paint()..color = color.withValues(alpha: 0.40);

    final RRect outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        _outerInset,
        _outerInset,
        w - _outerInset * 2,
        h - _outerInset * 2,
      ),
      const Radius.circular(15),
    );
    final RRect inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        _outerInset + _gap,
        _outerInset + _gap,
        w - (_outerInset + _gap) * 2,
        h - (_outerInset + _gap) * 2,
      ),
      const Radius.circular(10),
    );

    // خطّ **واحد** هو إطار الكارد: حُذف الخطّ الثاني (الحافة الداخلية الرقيقة)
    // فلم يبقَ تحت كلمات الرسالة سوى خطّ واحد أنيق.
    canvas.drawRRect(outer, line);

    // ── معينات صغيرة في الأركان على الخطّ الداخلي
    for (final Offset c in <Offset>[
      Offset(inner.left + 6, inner.top + 6),
      Offset(inner.right - 6, inner.top + 6),
      Offset(inner.right - 6, inner.bottom - 6),
      Offset(inner.left + 6, inner.bottom - 6),
    ]) {
      _diamond(canvas, c, 3.2, ornament);
    }

    // ── نجمة ثمانية في منتصف الضلعين الأعلى والأسفل
    _star8(
      canvas,
      Offset(w / 2, _outerInset + _gap / 2),
      4.4,
      ornament,
    );
    _star8(
      canvas,
      Offset(w / 2, h - _outerInset - _gap / 2),
      4.4,
      ornament,
    );

    // ── سلسلة حبّات دقيقة على الجانبين
    for (final double f in <double>[0.32, 0.5, 0.68]) {
      canvas.drawCircle(
        Offset(_outerInset + _gap / 2, h * f),
        1.6,
        bead,
      );
      canvas.drawCircle(
        Offset(w - _outerInset - _gap / 2, h * f),
        1.6,
        bead,
      );
    }
  }

  /// نجمة ثمانية = مربّعان متراكبان أحدهما مُدار 45°.
  void _star8(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawPath(_square(center, radius, 0), paint);
    canvas.drawPath(_square(center, radius * 0.68, math.pi / 4), paint);
  }

  void _diamond(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawPath(_square(center, radius, math.pi / 4), paint);
  }

  Path _square(Offset center, double radius, double rotation) {
    final Path path = Path();
    for (int i = 0; i < 4; i++) {
      final double a = rotation + i * (math.pi / 2) + math.pi / 4;
      final Offset p = Offset(
        center.dx + radius * math.cos(a),
        center.dy + radius * math.sin(a),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_IslamicFramePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// زر صغير في زاوية الكارد: الإغلاق، أو الحذف.
class _CardCornerButton extends StatelessWidget {
  const _CardCornerButton({
    required this.color,
    required this.background,
    required this.onTap,
    this.icon = Icons.close_rounded,
    this.tooltip = 'إغلاق',
  });

  final Color color;

  /// لون سطح الكارد — يُغطّى به الإطار خلف الزر فلا تتقاطع الخطوط معه.
  final Color background;
  final VoidCallback onTap;

  /// أيقونة الزر (إغلاق افتراضاً، أو حذف).
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // سطح معتم يغطّي الإطار خلف الزر فيبقى الإطار ممتدّاً بلا تقاطع
              color: background.withValues(alpha: 0.96),
              border: Border.all(color: color.withValues(alpha: 0.65), width: 1.2),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
        ),
      ),
    );
  }
}

/// عرض الكارد كنافذة فوق التطبيق: نصّ الرسالة + زر إغلاق (+ زر حذف إن مُرَّر).
///
/// [onDelete] يُنفّذ الحذف الفعلي ويُرجع هل نجح، ثم يُغلق الكارد ويُبلَّغ
/// المستخدم بالنتيجة — ويسأل عن التأكيد أولاً لأن الحذف يشمل قاعدة البيانات
/// فتختفي الرسالة من جميع الأجهزة.
Future<void> showGreetingCard({
  required BuildContext context,
  required GreetingCardStyle style,
  required String message,
  Future<bool> Function()? onDelete,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'إغلاق',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
    transitionBuilder: (ctx, animation, _, _) {
      final CurvedAnimation curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      Future<void> handleDelete() async {
        final bool? confirmed = await showGlassDialog<bool>(
          context: ctx,
          title: 'حذف رسالة السلام',
          kind: GlassNoticeKind.danger,
          content: Text(
            'سيتم إيقاف الرسالة ومسحها من التطبيق ومن قاعدة البيانات، فتختفي من جميع الأجهزة.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.7,
            ),
          ),
          actions: <Widget>[
            GlassButton(
              label: 'إلغاء',
              icon: Icons.close_rounded,
              filled: false,
              fontFamily: 'Amiri',
              onPressed: () => Navigator.pop(ctx, false),
            ),
            GlassButton(
              label: 'حذف',
              icon: Icons.delete_outline_rounded,
              fontFamily: 'Amiri',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
        if (confirmed != true || onDelete == null) return;

        final bool ok = await onDelete();
        if (ctx.mounted) Navigator.of(ctx).pop();

        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'تم حذف رسالة السلام من التطبيق ومن قاعدة البيانات'
                  : 'حُذفت الرسالة من التطبيق، لكن تعذّر حذفها من قاعدة البيانات',
              textAlign: TextAlign.center,
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: ok ? const Color(0xFF0B1F3D) : GlassPalette.danger,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return PopScope(
        canPop: true,
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: Center(
              child: GreetingCard(
                style: style,
                message: message,
                onClose: () => Navigator.of(ctx).pop(),
                onDelete: onDelete == null ? null : handleDelete,
              ),
            ),
          ),
        ),
      );
    },
  );
}
