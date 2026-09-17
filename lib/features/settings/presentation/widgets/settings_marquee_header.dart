import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../remote_messaging_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
///  هيدر شاشة الإعدادات — **حديث/عبارة متقلّبة**.
///
///  كان هذا المكوّن مكتوباً داخل شاشة الإعدادات (widget خاص)، فصار ملفاً
///  مستقلاً ليُنظَّم المكوّن ويُختبر وحده:
///    • **وقت الظهور**: يبقى كل حديث [SettingsMarqueeSettings.intervalMs] ثم
///      ينتقل إلى الحديث التالي (تقلّب دائري على القائمة).
///    • كل حديث يتحرّك أفقياً بسلاسة كما كان الشريط سابقاً، وموضعه يبدأ من
///      أول الحديث عند كل تقليب.
///    • التنسيق (اللون · نوع الخط · الحجم) يأتي كله من لوحة التحكم (1918).
///    • بحديث واحد لا يوجد أي مؤقّت ولا تقليب — نفس سلوك النسخ السابقة.
///
///  لا يعرف هذا المكوّن شيئاً عن Supabase: يستقبل الأحاديث جاهزة، فيبقى
///  قابلاً للاختبار وحده بلا شبكة.
/// ─────────────────────────────────────────────────────────────────────────────
class SettingsMarqueeHeader extends StatefulWidget {
  /// الأحاديث المعروضة على الترتيب. فارغة = لا يُعرض شيء (يُحفظ الارتفاع).
  final List<String> messages;

  /// إعدادات العرض: اللون + نوع الخط + الحجم + **وقت الظهور**.
  final SettingsMarqueeSettings settings;

  const SettingsMarqueeHeader({
    super.key,
    required this.messages,
    required this.settings,
  });

  /// نص الحديث رقم [index] مع الدوران — دالّة نقية تُختبر وحدها.
  static String messageFor(List<String> messages, int index) {
    if (messages.isEmpty) return '';
    final int i = index % messages.length;
    return messages[i < 0 ? i + messages.length : i];
  }

  @override
  State<SettingsMarqueeHeader> createState() => _SettingsMarqueeHeaderState();
}

class _SettingsMarqueeHeaderState extends State<SettingsMarqueeHeader>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  AnimationController? _animController;
  Timer? _timer;

  /// رقم الحديث المعروض حالياً.
  int _index = 0;

  /// سرعة التحرّك الأفقي (بكسل/ثانية) — نفس سلوك الشريط السابق.
  static const double _pixelsPerSecond = 30.0;

  String get _currentMessage =>
      SettingsMarqueeHeader.messageFor(widget.messages, _index);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _restartTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAnimation());
  }

  /// يضبط مؤقّت التقليب: بلا مؤقّت إن كان حديث واحد أو أقل.
  void _restartTimer() {
    _timer?.cancel();
    if (widget.messages.length < 2) return;
    _timer = Timer.periodic(widget.settings.interval, (_) {
      if (!mounted || widget.messages.length < 2) return;
      setState(() {
        _index = (_index + 1) % widget.messages.length;
      });
      _resetScrollAndAnimate();
    });
  }

  /// عند التقليب: يعود الشريط إلى بداية الحديث الجديد ثم يُحرَّك من جديد.
  void _resetScrollAndAnimate() {
    _animController?.stop();
    _animController?.value = 0;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAnimation());
  }

  /// يحسب مدة التحرّك من طول النص، ثم يجعل الشريط يتحرّك بلا توقف.
  ///
  /// **متحرّك واحد يُعاد استعماله** لا متحرّك جديد لكل تقليب: هذا المكوّن
  /// يخلط `SingleTickerProviderStateMixin` الذي يسمح بمؤقّت (ticker) واحد
  /// لهذه الحالة — فإعادة الإنشاء تُسقط الواجهة في وضع التصحيح، وفي الإصدار
  /// تُسرّب مؤقّتاً قديماً يظلّ يحرّك الشريط. وتغيير `duration` وإعادة التشغيل
  /// يحقق نفس المطلوب بلا إنشاء جديد.
  void _initAnimation() {
    if (!mounted || !_scrollController.hasClients) return;
    if (!_scrollController.position.hasContentDimensions) return;
    final double maxScroll = _scrollController.position.maxScrollExtent;

    final int durationMs = maxScroll <= 0
        ? 0
        : ((maxScroll / _pixelsPerSecond) * 1000).toInt();
    if (durationMs <= 0) {
      // نص أقصر من عرض الشريط: لا شيء يُحرَّك، فنوقف المتحرّك بلا استهلاك إطارات.
      _animController?.stop();
      return;
    }

    final AnimationController controller =
        _animController ??= AnimationController(vsync: this)
          ..addListener(_onAnimationTick);
    controller.duration = Duration(milliseconds: durationMs);
    controller.value = 0;
    controller.repeat();
  }

  /// تحريك الشريط بنسبة تقدّم المتحرّك (نفس سلوك الشريط السابق).
  void _onAnimationTick() {
    final AnimationController? controller = _animController;
    if (controller == null || !mounted || !_scrollController.hasClients) return;
    if (!_scrollController.position.hasContentDimensions) return;
    final double maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent > 0) {
      _scrollController.jumpTo(controller.value * maxExtent);
    }
  }

  @override
  void didUpdateWidget(SettingsMarqueeHeader oldWidget) {
    super.didUpdateWidget(oldWidget);

    final List<String> oldMessages = oldWidget.messages;
    final List<String> nowMessages = widget.messages;
    final bool messagesChanged =
        oldMessages.length != nowMessages.length ||
        !_sameList(oldMessages, nowMessages);

    final SettingsMarqueeSettings old = oldWidget.settings;
    final SettingsMarqueeSettings now = widget.settings;
    final bool styleChanged =
        old.color != now.color ||
        old.fontFamily != now.fontFamily ||
        old.fontSize != now.fontSize;

    if (messagesChanged) {
      // قائمة جديدة: نبدأ من أول حديث ونُعيد المؤقّت (فوقت الظهور الجديد
      // يُطبَّق فوراً).
      _index = 0;
      _restartTimer();
      _resetScrollAndAnimate();
      return;
    }

    if (old.intervalMs != now.intervalMs) {
      _restartTimer();
    }
    if (styleChanged) {
      // الحجم الجديد يغيّر عرض النص ومدة التحرّك معاً.
      _resetScrollAndAnimate();
    }
  }

  static bool _sameList(List<String> a, List<String> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // النمط (اللون ونوع الخط والحجم) يأتي كله من لوحة التحكم.
    final TextStyle style = widget.settings.textStyle();
    final double height = widget.settings.fontSize + 14.0;
    final double boxHeight = height < 26 ? 26 : height;

    final String text = _currentMessage;
    if (text.isEmpty) return SizedBox(height: boxHeight);

    return SizedBox(
      // الارتفاع يتبع حجم الخط المختار فلا يُقتطع النص المرتفع.
      height: boxHeight,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: style),
            const SizedBox(width: 50),
            Text(text, style: style),
            const SizedBox(width: 50),
          ],
        ),
      ),
    );
  }
}
