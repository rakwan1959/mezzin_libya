import 'package:flutter/material.dart';

/// مقدار الزيادة الافتراضية (بالبكسل لا بالنسبة) على حجم كل نص في الشاشة.
///
/// **إضافة** لا **ضرب**: الخط 12 يصبح 13.5، والخط 18 يصبح 19.5، بلا أن
/// تتضاعف الزيادة على الخطوط الكبيرة كما يحدث في المعامل الضربي.
const double kScreenTextBoost = 1.5;

/// مقياس نصّي **إضافي** يبني فوق مقياس خط النظام الذي اختاره المستخدم.
///
/// الترتيب مقصود: يُطبَّق مقياس النظام أولاً (احتراماً لإعداد إمكانية الوصول
/// في الجهاز) ثم تُضاف الزيادة بالبكسل، فيبقى كل مستخدم يرى خطّه المفضّل
/// مكبَّراً بنفس المقدار.
class BoostedTextScaler extends TextScaler {
  const BoostedTextScaler(this.base, {this.extra = kScreenTextBoost});

  /// مقياس الخط الأصلي (من النظام/النافذة) الذي نزيد فوقه.
  final TextScaler base;

  /// مقدار الزيادة بالبكسل.
  final double extra;

  @override
  double scale(double fontSize) {
    final double scaled = base.scale(fontSize);
    return scaled.isFinite ? scaled + extra : scaled;
  }

  /// تقدير المتعاملين القدامى (منهم `MediaQuery.textScaleFactorOf`) — نُمرّره
  /// من الأساس كما هو، والسلوك الفعلي يأتي من [scale]. العضو مُهمَل في
  /// Flutter لكن [TextScaler] يفرض تنفيذه.
  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor;

  @override
  bool operator ==(Object other) =>
      other is BoostedTextScaler && other.base == base && other.extra == extra;

  @override
  int get hashCode => Object.hash(base, extra);

  @override
  String toString() => 'BoostedTextScaler($base + ${extra}px)';
}

/// يكبر كل نص ورقم داخل [child] بمقدار [extra] بكسل.
///
/// يُستدعى **مرة واحدة** في جذر الشاشة المطلوب تكبيرها؛ فلا تُعدَّل أحجام
/// الخطوط واحداً واحداً في الكود (وهو ما يجعل التعديل المستقبلي مطلباً واحداً
/// في مكان واحد). ولو تكرّر الغلاف في الشجرة لا تتضاعف الزيادة: نُعيد بناء
/// المقياس فوق [BoostedTextScaler.base] الأصلي.
class TextScaleBoost extends StatelessWidget {
  const TextScaleBoost({
    super.key,
    required this.child,
    this.extra = kScreenTextBoost,
  });

  final Widget child;
  final double extra;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final TextScaler ambient = media.textScaler;
    final TextScaler base =
        ambient is BoostedTextScaler ? ambient.base : ambient;

    return MediaQuery(
      data: media.copyWith(
        textScaler: BoostedTextScaler(base, extra: extra),
      ),
      child: child,
    );
  }
}
