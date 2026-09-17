import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ويدجت لعرض اسم السورة محاطاً من الجانبين بزخارف إسلامية خفيفة وأنيقة
/// بلون أبيض يميل قليلاً للرمادي (Off-white / Soft Silver Grey)
class IslamicSurahName extends StatelessWidget {
  final String surahName;
  final TextStyle? style;
  final Color? ornamentColor;
  final double ornamentWidth;
  final double ornamentHeight;
  final double spacing;
  final MainAxisSize mainAxisSize;
  final MainAxisAlignment mainAxisAlignment;
  final bool prefixSurah;

  const IslamicSurahName({
    super.key,
    required this.surahName,
    this.style,
    this.ornamentColor,
    this.ornamentWidth = 28.0,
    this.ornamentHeight = 14.0,
    this.spacing = 8.0,
    this.mainAxisSize = MainAxisSize.min,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.prefixSurah = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String displayName = prefixSurah && !surahName.trim().startsWith('سورة')
        ? 'سورة $surahName'
        : surahName;

    final TextStyle effectiveStyle = style ??
        GoogleFonts.amiri(
          fontSize: 21,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFFAF7F2) : const Color(0xFF1F242C),
        );

    final TextAlign align = (mainAxisAlignment == MainAxisAlignment.start)
        ? TextAlign.start
        : (mainAxisAlignment == MainAxisAlignment.end
            ? TextAlign.end
            : TextAlign.center);

    return Text(
      displayName,
      style: effectiveStyle,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// رسم الزخرفة الجانبية الإسلامية الدقيقة المتقنة
class IslamicSurahSideOrnament extends StatelessWidget {
  final Color color;
  final double width;
  final double height;
  final bool isLeft;

  const IslamicSurahSideOrnament({
    super.key,
    required this.color,
    this.width = 28.0,
    this.height = 14.0,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _SurahSideOrnamentPainter(
        color: color,
        isLeft: isLeft,
      ),
    );
  }
}

class _SurahSideOrnamentPainter extends CustomPainter {
  final Color color;
  final bool isLeft;

  _SurahSideOrnamentPainter({
    required this.color,
    required this.isLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cy = h / 2;

    canvas.save();

    // نتحكم في الاتجاه (مرآة للجانب الأيمن ليصبح كلاهما متناظراً بدقة تامة)
    if (!isLeft) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }

    final Paint strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint thinStroke = Paint()
      ..color = color.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;

    final Paint fillPaint = Paint()
      ..color = color.withOpacity(0.22)
      ..style = PaintingStyle.fill;

    final Paint solidDot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 1. الخط الانسيابي المتموج الأساسي الممتد نحو الخارج
    final Path mainWave = Path();
    mainWave.moveTo(w, cy);
    mainWave.cubicTo(
      w * 0.72, cy + h * 0.12,
      w * 0.48, cy - h * 0.22,
      w * 0.22, cy,
    );
    mainWave.lineTo(w * 0.12, cy);
    canvas.drawPath(mainWave, strokePaint);

    // 2. القوس الزخرفي العلوي النباتي (Floral arch)
    final Path upperPetal = Path();
    upperPetal.moveTo(w * 0.78, cy);
    upperPetal.cubicTo(
      w * 0.65, cy - h * 0.46,
      w * 0.38, cy - h * 0.42,
      w * 0.34, cy - h * 0.08,
    );
    canvas.drawPath(upperPetal, thinStroke);

    // 3. القوس الزخرفي السفلي المتوازن (Lower balance curve)
    final Path lowerPetal = Path();
    lowerPetal.moveTo(w * 0.78, cy);
    lowerPetal.cubicTo(
      w * 0.65, cy + h * 0.38,
      w * 0.44, cy + h * 0.36,
      w * 0.40, cy + h * 0.05,
    );
    canvas.drawPath(lowerPetal, thinStroke);

    // 4. تعبئة شفافة رقيقة خفيفة داخل القوس العلوي لإعطاء لمسة فخامة
    final Path fillPetal = Path();
    fillPetal.moveTo(w * 0.74, cy);
    fillPetal.cubicTo(
      w * 0.62, cy - h * 0.38,
      w * 0.42, cy - h * 0.34,
      w * 0.36, cy - h * 0.06,
    );
    fillPetal.close();
    canvas.drawPath(fillPetal, fillPaint);

    // 5. النجمة / الماسة الزخرفية الدقيقة عند الطرف الخارجي
    final double starCx = w * 0.10;
    final double starCy = cy;
    final double starR = math.min(w * 0.09, h * 0.32);

    final Path star = Path();
    const int pts = 4;
    final double innerR = starR * 0.38;
    for (int i = 0; i < pts * 2; i++) {
      final double r = (i % 2 == 0) ? starR : innerR;
      final double angle = (i * math.pi / pts) - (math.pi / 2);
      final double px = starCx + r * math.cos(angle);
      final double py = starCy + r * math.sin(angle);
      if (i == 0) {
        star.moveTo(px, py);
      } else {
        star.lineTo(px, py);
      }
    }
    star.close();
    canvas.drawPath(star, fillPaint);
    canvas.drawPath(star, strokePaint);

    // 6. نقاط زخرفية دقيقة متناسقة
    canvas.drawCircle(Offset(starCx, starCy), 1.0, solidDot);
    canvas.drawCircle(Offset(w * 0.88, cy), 1.1, solidDot);
    canvas.drawCircle(Offset(w * 0.52, cy - h * 0.35), 0.9, solidDot);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SurahSideOrnamentPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isLeft != isLeft;
  }
}
