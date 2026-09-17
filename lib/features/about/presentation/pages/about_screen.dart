import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:muezzin_libya_app/admin_panel_screen.dart';
import 'package:muezzin_libya_app/remote_messaging_service.dart';
import 'package:muezzin_libya_app/user_messaging_screen.dart';
import 'package:muezzin_libya_app/greeting_card_settings.dart';
import '../../../../core/config/app_version.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/greeting_card.dart';
import '../../../../core/theme/glass_theme.dart';
import '../../../../main.dart' show AlMaathenTheme;

class AboutAppScreen extends StatefulWidget {
  final VoidCallback onBack;
  final String userName;
  final String themeMode;
  const AboutAppScreen({
    super.key,
    required this.onBack,
    required this.userName,
    required this.themeMode,
  });

  @override
  State<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends State<AboutAppScreen>
    with TickerProviderStateMixin {
  int _tapCount = 0;
  DateTime? _lastTapTime;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _hiddenPasscodeController =
      TextEditingController();
  // كلمة سر اللوحة الأولى (الرسالة المخفية): 1916 — تفتح بالضغط المطول على نص الإصدار
  final String _firstPanelPasscode = '1916';
  // كلمة سر اللوحة الثانية (لوحة السيطرة والتحكم): 1918 (مع قبول 1619 كاحتياط)
  final String _secondPanelPasscode = '1918';
  final String _secondPanelPasscodeOld = '1619';

  // ── حقول رسالة السلام (ضمن اللوحة الأولى) ──────────────
  // الحقل فارغ افتراضياً — لا تُملأ كلمة «السلام عليكم» تلقائياً.
  final TextEditingController _greetingMsgCtrl = TextEditingController();
  bool _greetingEnabled = false;
  /// لون كارد الرسالة المختار من اللوحة (نمط جاهز).
  String _greetingColorId = GreetingCardStyle.defaultId;
  /// النغمة المصاحبة للكارد (ملف صوتي مضمّن في التطبيق).
  String _greetingToneId = GreetingTone.defaultId;

  // ── حقول اللوحة الأولى (رسالة التحديث) ──────────────────
  final TextEditingController _hiddenBroadcastTitleCtrl = TextEditingController(
    text: 'تحديث جديد للتطبيق',
  );
  final TextEditingController _hiddenBroadcastMsgCtrl = TextEditingController(
    text: 'تم إطلاق تحديث جديد، يرجى فتح التطبيق للاطلاع على الميزات الجديدة.',
  );
  final TextEditingController _hiddenBroadcastBtnTextCtrl =
      TextEditingController(text: 'حسنا');
  final TextEditingController _hiddenBroadcastBtnUrlCtrl =
      TextEditingController();
  final TextEditingController _hiddenBroadcastVersionCtrl =
      TextEditingController(text: '2.0.0');
  final TextEditingController _hiddenTargetUserIdCtrl = TextEditingController();

  // ── حقول رسالة التهنئة (ضمن اللوحة الأولى) ──────────────
  // تُرسل لجميع المستخدمين بدون رقم تسلسلي
  final TextEditingController _congratsMsgCtrl = TextEditingController();
  // تفعيل رسالة التهنئة — مفتاح صريح يُحفظ ويُنشر
  bool _congratsEnabled = false;
  // رسالة التهنئة النشطة المعروضة في المساحة الفاضية
  String _activeCongrats = '';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    // الاستماع لرسائل التهنئة القادمة من لوحة التحكم (Realtime)
    RemoteMessagingService.congratsNotifier.addListener(_onCongratsChanged);
    _loadCongrats();

    // حالة التحديث المنشور على سوباباز: فحص عند فتح الشاشة + استماع لما يأتي
    // عبر Realtime، فيظهر «يتوفر إصدار أحدث» بلا إعادة تشغيل.
    RemoteMessagingService.availableUpdate.addListener(_onUpdateChanged);
    RemoteMessagingService.refreshAvailableUpdate();
  }

  void _onUpdateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    RemoteMessagingService.congratsNotifier.removeListener(_onCongratsChanged);
    RemoteMessagingService.availableUpdate.removeListener(_onUpdateChanged);
    _animationController.dispose();
    _hiddenPasscodeController.dispose();
    _hiddenBroadcastTitleCtrl.dispose();
    _hiddenBroadcastMsgCtrl.dispose();
    _hiddenBroadcastBtnTextCtrl.dispose();
    _hiddenBroadcastBtnUrlCtrl.dispose();
    _hiddenBroadcastVersionCtrl.dispose();
    _hiddenTargetUserIdCtrl.dispose();
    _greetingMsgCtrl.dispose();
    _congratsMsgCtrl.dispose();
    super.dispose();
  }

  void _onCongratsChanged() {
    if (mounted) {
      setState(() {
        _activeCongrats = RemoteMessagingService.congratsNotifier.value;
      });
    }
  }

  /// تحميل رسالة التهنئة الحالية من الجهاز (النص + التفعيل)
  Future<void> _loadCongrats() async {
    try {
      final CongratsSettings saved =
          await RemoteMessagingService.readCongratsSettings();
      final active = await RemoteMessagingService.getActiveCongrats();
      if (mounted) {
        setState(() {
          _congratsMsgCtrl.text = saved.message;
          _congratsEnabled = saved.enabled;
          _activeCongrats = active;
        });
      }
    } catch (_) {}
  }

  void _handleTap() async {
    final now = DateTime.now();
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    _lastTapTime = now;

    if (_tapCount >= 5) {
      _tapCount = 0;
      // 5 ضغطات → كلمة السر مرة واحدة (1918) ثم اللوحة الثانية (لوحة السيطرة والتحكم)
      _showHiddenBroadcastDialog(openFirstPanel: false);
    }
  }

  /// نافذة كلمة السر — اللوحة الأولى (1916) أو الثانية (1918).
  ///
  /// إدخال **مرة واحدة** فقط: بمجرد صحة الرمز يُفتح المستوى المطلوب مباشرة،
  /// فلا حاجة لإعادة إدخاله للتأكيد.
  void _showHiddenBroadcastDialog({bool openFirstPanel = false}) async {
    final expected = openFirstPanel
        ? _firstPanelPasscode
        : _secondPanelPasscode;

    // ── إدخال الرمز السري (مرة واحدة) ─────────────────────────────
    final firstCtrl = TextEditingController();
    final firstResult = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _buildGlassDialog(
          title: openFirstPanel
              ? 'اللوحة الأولى (الرسالة المخفية)'
              : 'لوحة السيطرة والتحكم',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                openFirstPanel
                    ? 'أدخل الرمز السري للوصول إلى اللوحة الأولى.'
                    : 'أدخل الرمز السري للوصول إلى لوحة السيطرة والتحكم.',
                style: GoogleFonts.cairo(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: firstCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'الرمز السري',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.38)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.pop(context, false);
              },
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(color: Colors.white.withOpacity(0.54)),
              ),
            ),
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                final entered = firstCtrl.text.trim();
                final valid = entered == expected ||
                    (!openFirstPanel && entered == _secondPanelPasscodeOld);
                if (valid) {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'رمز سري خاطئ.',
                        style: GoogleFonts.cairo(),
                      ),
                      backgroundColor: GlassNoticeSpec.surface,
                    ),
                  );
                }
              },
              child: Text(
                'فتح',
                style: GoogleFonts.cairo(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    firstCtrl.dispose();

    if (firstResult != true) return;
    if (!mounted) return;

    // ── فتح اللوحة بعد إدخال الرمز صحيحاً (مرة واحدة) ─────────────
    if (openFirstPanel) {
      await _showHiddenBroadcastComposer();
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AdminPanelScreen(),
        ),
      );
    }
  }

  /// اللوحة الأولى: رسالة التحديث + الرقم التسلسلي + رسالة السلام
  /// (تفتح بالضغط المطول على نص الإصدار + كلمة السر 1916)
  Future<void> _showHiddenBroadcastComposer() async {
    // تحميل حالة رسالة التهنئة (النص + التفعيل) عند فتح اللوحة نفسها، لا
    // عند بناء الشاشة فقط — فتظهر الحالة الحقيقية دائماً.
    await _loadCongrats();
    // تحميل الحالة الحالية لرسالة السلام من الجهاز حتى يظهر المفتاح
    // والنص بحالتهما الصحيحة عند فتح اللوحة
    try {
      final prefs = await SharedPreferences.getInstance();
      final GreetingSettings saved = GreetingSettings.fromPrefs(prefs);
      if (mounted) {
        setState(() {
          _greetingEnabled = saved.enabled;
          _greetingColorId = saved.colorId;
          _greetingToneId = saved.toneId;
          if (saved.message.isNotEmpty) {
            _greetingMsgCtrl.text = saved.message;
          }
        });
      }
    } catch (_) {}
    await showDialog(
      context: context,
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: _buildGlassDialog(
            title: 'إرسال رسالة تحديث مخفية',
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHiddenField(_hiddenBroadcastTitleCtrl, 'عنوان الرسالة'),
                  _buildHiddenField(
                    _hiddenBroadcastMsgCtrl,
                    'نص الرسالة',
                    maxLines: 3,
                  ),
                  _buildHiddenField(
                    _hiddenBroadcastBtnTextCtrl,
                    'نص زر التأكيد',
                  ),
                  _buildHiddenField(
                    _hiddenBroadcastBtnUrlCtrl,
                    'رابط الزر (اختياري)',
                  ),
                  _buildHiddenField(
                    _hiddenBroadcastVersionCtrl,
                    'الإصدار المستهدف (مثلاً 2.0.0)',
                  ),
                  _buildHiddenField(
                    _hiddenTargetUserIdCtrl,
                    'الرقم التسلسلي للمستخدم (اتركه فارغاً للجميع)',
                  ),
                  const SizedBox(height: 10),
                  _buildActionButton(
                    label: 'حذف آخر رسالة تحديث',
                    icon: Icons.delete_forever_rounded,
                    color: Colors.redAccent,
                    onTap: () async {
                      FocusManager.instance.primaryFocus?.unfocus();
                      final deleted =
                          await RemoteMessagingService.deleteLastHiddenUpdate();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            deleted
                                ? '✅ تم حذف آخر رسالة تحديث.'
                                : 'لا توجد رسالة تحديث سابقة للحذف.',
                            style: GoogleFonts.cairo(),
                          ),
                          backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  // ── رسالة السلام عليكم ────────────────────────────
                  Row(
                    children: [
                      const Icon(
                        Icons.waving_hand_rounded,
                        color: Colors.tealAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'رسالة السلام عليكم عند فتح التطبيق',
                          style: GoogleFonts.cairo(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ملاحظة: StatefulBuilder ضروري لأن setState خارج نافذة الحوار
                  // لا يُعيد بناء محتواها — بدونها لا يتحرك مفتاح التفعيل
                  StatefulBuilder(
                    builder: (dialogContext, setDialogState) {
                      return SwitchListTile(
                        activeColor: Colors.tealAccent,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'تفعيل رسالة السلام',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          'تظهر نافذة ترحيبية عند فتح التطبيق',
                          style: GoogleFonts.cairo(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                          ),
                        ),
                        value: _greetingEnabled,
                        onChanged: (v) =>
                            setDialogState(() => _greetingEnabled = v),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildHiddenField(
                    _greetingMsgCtrl,
                    'نص الرسالة (يظهر في منتصف الكارد)',
                    maxLines: 2,
                  ),
                  // ── لون الكارد: أنماط جاهزة تصل لكل الأجهزة ──────────
                  _buildGreetingColorPicker(),
                  const SizedBox(height: 12),
                  // ── النغمة المصاحبة للرسالة ────────────────────────
                  _buildGreetingTonePicker(),
                  const SizedBox(height: 12),
                  // ── زر اختبار: يريك الكارد ويخبرك بالحالة ────────────
                  _buildActionButton(
                    label: 'اختبار الكارد الآن (هل الرسالة مفعّلة؟)',
                    icon: Icons.play_circle_fill_rounded,
                    color: const Color(0xFF7BE0D0),
                    onTap: _testGreetingCard,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: 'نشر رسالة السلام',
                          icon: Icons.send_rounded,
                          color: Colors.tealAccent,
                          onTap: _publishGreeting,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildActionButton(
                          label: 'حذف رسالة السلام',
                          icon: Icons.delete_forever_rounded,
                          color: Colors.redAccent,
                          onTap: _deleteGreeting,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // ── رسالة التهنئة ────────────────────────────────
                  Row(
                    children: [
                      const Icon(
                        Icons.celebration_rounded,
                        color: Color(0xFFDFBA6B),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'رسالة التهنئة (تظهر في المساحة الفاضية بشاشة عن التطبيق)',
                          style: GoogleFonts.cairo(
                            color: const Color(0xFFDFBA6B),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ملاحظة: StatefulBuilder ضروري حتى تتحدث المعاينة وحالة زر
                  // المسح داخل نافذة الحوار دون الحاجة لإغلاقها.
                  StatefulBuilder(
                    builder: (dialogContext, setDialogState) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHiddenField(
                            _congratsMsgCtrl,
                            'نص رسالة التهنئة',
                            maxLines: 3,
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          // ── مفتاح التفعيل الصريح: يُحفظ ويُنشر مع الرسالة ──
                          SwitchListTile(
                            activeColor: const Color(0xFFDFBA6B),
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'تفعيل رسالة التهنئة',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              _congratsEnabled
                                  ? 'مُفعّلة — تظهر للمستخدمين في شاشة «عن التطبيق»'
                                  : 'غير مُفعّلة — لن تظهر حتى تُفعّلها وتُرسلها',
                              style: GoogleFonts.cairo(
                                color: _congratsEnabled
                                    ? Colors.greenAccent
                                    : Colors.white.withOpacity(0.4),
                                fontSize: 11,
                              ),
                            ),
                            value: _congratsEnabled,
                            onChanged: (v) =>
                                setDialogState(() => _congratsEnabled = v),
                          ),
                          const SizedBox(height: 6),
                          // ── زر تحقّق: يخبرك بالحالة ويعرض الرسالة كما يراها
                          // المستخدم (نفس الكارد والنغمة) ──
                          _buildActionButton(
                            label: 'اختبار: هل الرسالة مُفعّلة؟',
                            icon: Icons.verified_rounded,
                            color: const Color(0xFF9AD9FF),
                            onTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              _testCongrats(dialogContext);
                            },
                          ),
                          // ── تُرسل لجميع المستخدمين بدون رقم تسلسلي ──
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionButton(
                                  label: 'إرسال التهنئة',
                                  icon: Icons.send_rounded,
                                  color: const Color(0xFFDFBA6B),
                                  onTap: () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    _publishCongrats();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildActionButton(
                                  label: 'حذف التهنئة',
                                  icon: Icons.delete_forever_rounded,
                                  color: Colors.redAccent,
                                  onTap: _deleteCongrats,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.pop(context);
                },
                child: Text(
                  'إلغاء',
                  style: GoogleFonts.cairo(
                    color: Colors.white.withOpacity(0.54),
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final targetId = _hiddenTargetUserIdCtrl.text.trim();

                  // إرسال الرسالة كبث (Broadcast)
                  final success = await RemoteMessagingService.sendBroadcast(
                    id: 'hidden_update_${DateTime.now().millisecondsSinceEpoch}',
                    title: _hiddenBroadcastTitleCtrl.text.trim(),
                    message: _hiddenBroadcastMsgCtrl.text.trim(),
                    btnText: _hiddenBroadcastBtnTextCtrl.text.trim(),
                    btnUrl: _hiddenBroadcastBtnUrlCtrl.text.trim(),
                    targetUserId: targetId,
                  );

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? (targetId.isEmpty
                                  ? 'تم إرسال رسالة التحديث للجميع.'
                                  : 'تم إرسال رسالة التحديث للمستخدم المحدد.')
                            : 'فشل إرسال رسالة التحديث.',
                        style: GoogleFonts.cairo(),
                      ),
                      backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
                    ),
                  );
                },
                child: Text(
                  'إرسال',
                  style: GoogleFonts.cairo(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// لوحة ألوان كارد الرسالة — أنماط جاهزة يختار منها المدير.
  ///
  /// تُحفظ محلياً وتُنشر داخل عمود `greeting_message` بصيغة JSON، فتصل
  /// لكل الأجهزة بلا أي عمود جديد في قاعدة البيانات.
  Widget _buildGreetingColorPicker() {
    return StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final GreetingCardStyle selected =
            GreetingCardStyle.byId(_greetingColorId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.palette_rounded,
                  color: Color(0xFFDFBA6B),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'لون الكارد',
                  style: GoogleFonts.cairo(
                    color: const Color(0xFFDFBA6B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'المختار: ${selected.labelAr}',
                  style: GoogleFonts.cairo(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: GreetingCardStyle.all.map((GreetingCardStyle style) {
                final bool isSelected = style.id == selected.id;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setDialogState(() => _greetingColorId = style.id);
                  },
                  child: Tooltip(
                    message: style.labelAr,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: style.surface,
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : style.accent.withOpacity(0.7),
                          width: isSelected ? 2.4 : 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: style.accent.withOpacity(isSelected ? 0.5 : 0.18),
                            blurRadius: isSelected ? 12 : 6,
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  /// اختيار النغمة المصاحبة للرسالة + سماعها فوراً بلمسة.
  Widget _buildGreetingTonePicker() {
    return StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final GreetingTone selected = GreetingTone.byId(_greetingToneId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.music_note_rounded,
                  color: Color(0xFF7BE0D0),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'نغمة الرسالة (تُشغَّل مع ظهور الكارد)',
                  style: GoogleFonts.cairo(
                    color: const Color(0xFF7BE0D0),
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!selected.isSilent)
                  InkWell(
                    onTap: () => RemoteMessagingService.playGreetingTone(
                      selected.id,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.volume_up_rounded,
                          color: Color(0xFF7BE0D0),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'تجربة',
                          style: GoogleFonts.cairo(
                            color: const Color(0xFF7BE0D0),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GreetingTone.all.map((GreetingTone tone) {
                final bool isSelected = tone.id == selected.id;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setDialogState(() => _greetingToneId = tone.id);
                    // يُسمعك النغمة فور اختيارها لتقرّر قبل النشر
                    RemoteMessagingService.playGreetingTone(tone.id);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF7BE0D0).withOpacity(0.18)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF7BE0D0)
                            : Colors.white.withOpacity(0.2),
                        width: isSelected ? 1.4 : 1,
                      ),
                    ),
                    child: Text(
                      tone.labelAr,
                      style: GoogleFonts.cairo(
                        color: isSelected
                            ? const Color(0xFF7BE0D0)
                            : Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  /// زر اختبار الكارد: يعرضه بالشكل واللون والنغمة المختارة، ويخبر بالحالة
  /// (مُفعّلة / غير مُفعّلة) وهل وصلت لبقية الأجهزة أم ما زالت محلية.
  Future<void> _testGreetingCard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final GreetingCardStyle style = GreetingCardStyle.byId(_greetingColorId);
    final GreetingTone tone = GreetingTone.byId(_greetingToneId);
    final bool enabled = _greetingEnabled;

    final prefs = await SharedPreferences.getInstance();
    final GreetingSettings saved = GreetingSettings.fromPrefs(prefs);

    // يُشغَّل النغمة أولاً ثم يظهر الكارد — مثل ما سيحدث عند فتح التطبيق
    await RemoteMessagingService.playGreetingTone(tone.id);
    if (!mounted) return;

    // الكارد يُعرض بالنصّ المكتوب الآن في الحقل — كما سيظهر على الأجهزة
    await showGreetingCard(
      context: context,
      style: style,
      message: _greetingMsgCtrl.text,
    );
    if (!mounted) return;

    final String stateLine = enabled
        ? 'الرسالة مُفعّلة — ستظهر عند فتح التطبيق'
        : 'الرسالة غير مُفعّلة الآن — فعّل المفتاح ثم انشر';
    final String publishLine = (saved.enabled == enabled)
        ? 'محفوظة على الجهاز'
        : 'الحالة الحالية لم تُحفظ بعد — اضغط «نشر رسالة السلام»';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'اختبار الكارد:\n$stateLine\n$publishLine\nاللون: ${style.labelAr} · النغمة: ${tone.labelAr}',
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// نشر رسالة السلام (تفعيل + نص + لون + نغمة) للمستخدمين
  Future<void> _publishGreeting() async {
    final msg = _greetingMsgCtrl.text.trim();
    final GreetingSettings settings = GreetingSettings(
      enabled: _greetingEnabled,
      message: msg,
      colorId: _greetingColorId,
      toneId: _greetingToneId,
    );

    // ── الحفظ المحلي أولاً ─────────────────────────────────────────────
    // الكارد واللون والنغمة تعمل على هذا الجهاز فوراً بلا انتظار الخادم،
    // فحتى لو تعذّر النشر (انقطاع إنترنت) لا يبقى الزر بلا أثر.
    await RemoteMessagingService.saveGreetingLocal(settings);

    try {
      // ── النشر إلى Supabase بعمودَي الرسالة فقط ───────────────────────
      // مسار مستقل (`publishGreeting`) بدل `publishConfig`: ذاك كان يسقط
      // بصمت إلى حمولة لا تحمل أعمدة الرسالة فيقول للمدير «تم النشر» وهي
      // لم تصل. هنا الكتابة مفصّلة على `greeting_enabled` و`greeting_message`
      // (النص + اللون + النغمة داخل عمود JSON واحد) والنتيجة صادقة.
      final bool success =
          await RemoteMessagingService.publishGreeting(settings);
      if (success) {
        // لا يظهر الكارد على جهاز المُرسِل نفسه أثناء النشر (فقط لهذه الجلسة
        // — سيظهر عند فتح التطبيق لاحقاً للتأكد من وصوله)، لكن تُشغَّل
        // النغمة فوراً لتأكيد الإرسال.
        await RemoteMessagingService.markGreetingDeliveredOnThisDevice();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ تم نشر رسالة السلام لجميع الأجهزة\n'
                'اللون: ${settings.style.labelAr} · النغمة: ${settings.tone.labelAr}',
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ حُفظت الإعدادات على هذا الجهاز، لكن تعذّر النشر — تأكد من اتصال الإنترنت ثم أعد النشر لتصل لبقية الأجهزة.',
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: $e', style: GoogleFonts.cairo()),
            backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
          ),
        );
      }
    }
  }

  /// حذف رسالة السلام نهائياً (تعطيل + مسح النص)
  Future<void> _deleteGreeting() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white, width: 1.0),
        ),
        title: Text(
          'حذف رسالة السلام',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'سيتم إيقاف رسالة السلام وإزالتها من جميع الأجهزة.\nيمكنك إعادة تفعيلها لاحقاً.',
          style: GoogleFonts.cairo(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(color: Colors.white38),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(
              Icons.delete_forever_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: Text(
              'حذف نهائياً',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // 1. حذف من الخادم عبر نفس آلية upsert الناجحة في النشر
      final deleted = await RemoteMessagingService.deleteGreeting();

      // 2. مسح الكاش المحلي نهائياً من الجهاز (مع إبقاء اللون والنغمة
      // مختارين حتى لا تُعاد للافتراضي إذا أُعيد التفعيل لاحقاً)
      await RemoteMessagingService.saveGreetingLocal(
        GreetingSettings(
          enabled: false,
          colorId: _greetingColorId,
          toneId: _greetingToneId,
        ),
      );

      if (mounted) {
        setState(() {
          _greetingEnabled = false;
          _greetingMsgCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deleted
                  ? '✅ تم حذف رسالة السلام نهائياً!'
                  : '⚠️ تم تعطيلها محلياً، لكن فشل الحذف من الخادم. تحقق من الإنترنت.',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ في الحذف: $e', style: GoogleFonts.cairo()),
            backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
          ),
        );
      }
    }
  }

  /// نشر رسالة التهنئة (إرسال) — تُعرض في المساحة الفاضية بشاشة عن التطبيق
  Future<void> _publishCongrats() async {
    final msg = _congratsMsgCtrl.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(              'الرجاء إدخال نص رسالة التهنئة',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        ),
      );
      return;
    }
    // تأكيد قبل الإرسال — تُرسل لجميع المستخدمين بدون رقم تسلسلي
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white, width: 1.0),
        ),
        title: Text(
          'تأكيد إرسال رسالة التهنئة',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'سيتم إرسال رسالة التهنئة لجميع المستخدمين. هل أنت متأكد؟',
          style: GoogleFonts.cairo(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'إرسال',
              style: GoogleFonts.cairo(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final CongratsSettings settings = CongratsSettings(
      enabled: _congratsEnabled,
      message: msg,
      target: '',
    );

    // ── الحفظ المحلي أولاً (التفعيل والنص) ───────────────────────────────
    // كان الحفظ مربوطاً بنجاح النشر: إن تعذّر الاتصال لا يُفعَّل شيء إطلاقاً
    // (وهو ما يجعل الرسالة تبدو غير مفعّلة). الآن يُحفظ ويُفعَّل على هذا
    // الجهاز فوراً، ثم يُنشر لبقية الأجهزة.
    await RemoteMessagingService.saveCongratsLocally(settings);
    if (mounted) {
      setState(() => _activeCongrats = msg);
    }

    final bool published =
        await RemoteMessagingService.publishCongrats(settings);

    // لا تظهر نافذة الإهداء على جهاز المُرسِل نفسه — تُسلَّم للمستخدمين فقط
    // (عبر Realtime أو عند فتح التطبيق)، أما النغمة فتُشغَّل عليه فوراً.
    await RemoteMessagingService.markCongratsDeliveredOnThisDevice();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          published
              ? ('✅ تم إرسال رسالة التهنئة لجميع المستخدمين!\n'
                  'الحالة: ${_congratsEnabled ? "مُفعّلة" : "غير مُفعّلة — فعّلها من المفتاح ثم أعد الإرسال"}')
              : '⚠️ حُفظت وفُعِّلت على هذا الجهاز، لكن تعذّر النشر — تأكد من الإنترنت ثم أعد الإرسال لتصل للمستخدمين.',
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// زر التحقّق من رسالة التهنئة: يخبرك بحالتها الفعلية، ويعرضها كما يراها
  /// المستخدم تماماً (نفس الكارد ونفس النغمة) فالتحقّق بصري وسمعي لا كلامي.
  Future<void> _testCongrats(BuildContext dialogContext) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final CongratsSettings saved =
        await RemoteMessagingService.readCongratsSettings();
    final String active = await RemoteMessagingService.getActiveCongrats();
    final String typed = _congratsMsgCtrl.text.trim();

    final bool activeNow = active.isNotEmpty;
    final String stateLine = activeNow
        ? 'مُفعّلة فعلاً — يراها المستخدمون الآن في شاشة «عن التطبيق»'
        : (saved.message.trim().isEmpty
            ? 'لا توجد رسالة محفوظة بعد'
            : (saved.enabled
                ? 'محفوظة ومُفعّلة لكن بلا نص'
                : 'محفوظة لكن **غير مُفعّلة** — فعّل المفتاح ثم أرسل'));
    final String switchLine = _congratsEnabled == saved.enabled
        ? 'المفتاح مطابق للحالة المحفوظة'
        : 'المفتاح في اللوحة مختلف عن المحفوظ — اضغط «إرسال التهنئة» ليُحفظ';

    if (typed.isNotEmpty && mounted) {
      await RemoteMessagingService.previewCongrats(context, typed);
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'اختبار رسالة التهنئة:\n$stateLine\n$switchLine',
          style: GoogleFonts.cairo(),
        ),
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        duration: const Duration(seconds: 7),
      ),
    );
    if (dialogContext.mounted) setState(() {});
  }

  /// حذف رسالة التهنئة نهائياً
  Future<void> _deleteCongrats() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white, width: 1.0),
        ),
        title: Text(
          'حذف رسالة التهنئة',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'هل أنت متأكد من حذف رسالة التهنئة نهائياً؟',
          style: GoogleFonts.cairo(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('حذف', style: GoogleFonts.cairo(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // التعطيل والمسح محلياً أولاً، ثم الحذف من الخادم
    await RemoteMessagingService.saveCongratsLocally(
      const CongratsSettings(),
    );
    final deleted = await RemoteMessagingService.deleteCongrats();
    if (mounted) {
      setState(() {
        _congratsMsgCtrl.clear();
        _congratsEnabled = false;
        _activeCongrats = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted
                ? '✅ تم حذف رسالة التهنئة نهائياً!'
                : '⚠️ تم التعطيل محلياً، لكن فشل الحذف من الخادم.',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
        ),
      );
    }
  }

  /// زر إجراء داخل اللوحة الأولى
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.cairo(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHiddenField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.38)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassDialog({
    required String title,
    required Widget content,
    required List<Widget> actions,
  }) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: Text(
          title,
          style: GoogleFonts.cairo(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: content,
        actions: actions,
      ),
    );
  }

  /// نص رسالة التهنئة الظاهر في المساحة الفاضية بخط أميري
  /// (بدون كارد وبدون كلمة «تهنئة»)
  Widget _buildCongratsMessage(
    String message,
    List<Color> background,
    Color ink,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.amiri(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          // تتبع لون الصلاة القادمة مثل باقي كتابة الشاشة
          color: ink,
          height: 2.0,
          shadows: GlassEngraveSpec.shadows(background, strength: 0.85),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── الخلفية موحّدة مع الشاشة الرئيسية **لحظياً**: نفس التدرّج ونفس بقع
    // التوهّج، ومنها لون الصلاة القادمة (تضبطه الشاشة الرئيسية في
    // GlassRuntime.nextPrayer عند كل بناء)، فيتغيّر لون هذه الصفحة مع لون
    // خلفية التطبيق فوراً. وكل نصوص الشاشة وأيقوناتها تُشتقّ ظلالها المحفورة
    // من هذه الألوان نفسها (WYSIWYG للحفر على أي تدرّج).
    final List<Color> background = AlMaathenTheme.appScreenGradient(
      widget.themeMode,
      nextPrayer: GlassRuntime.nextPrayer,
    );
    final List<Color> glow = AlMaathenTheme.glowFor(
      widget.themeMode,
      nextPrayer: GlassRuntime.nextPrayer,
    );
    // ── لون الكتابة والأيقونات في هذه الشاشة يتبع **ألوان أوقات الصلاة** ──
    // نفس لون الصلاة النشطة الذي تُلوَّن به أيقونات الشاشة الرئيسية وكاردات
    // المواقيت (وضبطته الشاشة الرئيسية في GlassRuntime.activePrayerName)،
    // فيتطابق لون هذه الشاشة مع لون المواقيت تماماً. وإن لم يُضبط بعد (فتح
    // الشاشة قبل الشاشة الرئيسية) يرجع إلى لون الصلاة القادمة.
    final Color ink = GlassRuntime.activePrayerName.isNotEmpty
        ? GlassPalette.prayerTextColor(GlassRuntime.activePrayerName)
        : GlassPalette.prayerTextColorFor(GlassRuntime.nextPrayer);

    return Stack(
      children: [
        Positioned.fill(
          child: AuroraBackground(
            colors: background,
            glowColors: glow,
            animated: GlassRuntime.motion,
            intensity: GlassRuntime.glowScale,
            child: const SizedBox.shrink(),
          ),
        ),

        Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // ── المحتوى الرئيسي الزجاجي ─────────────────────────
              Positioned.fill(
                child: SafeArea(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: GestureDetector(
                        onTap: _handleTap,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Column(
                            children: [
                              // مسافة علوية كافية للشريط العلوي الثابت
                              const SizedBox(height: 52),

                              // ── عنوان التطبيق مباشرة على الخلفية ──
                              _buildAppHeader(background, ink),

                              // ── سطر التحديث (يظهر فقط لو المنشور أحدث) ──
                              _buildUpdateNotice(background, ink),

                              // ── المساحة الفاضية: رسالة التهنئة ──
                              Expanded(
                                child: Center(
                                  child: _activeCongrats.isNotEmpty
                                      ? SingleChildScrollView(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          child: _buildCongratsMessage(
                                            _activeCongrats,
                                            background,
                                            ink,
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),

                              // ── بيانات المطور والتطبيق مباشرة على الخلفية بدون كاردات ──
                              _buildDeveloperInfo(background, ink),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── زر الرجوع في الأعلى فقط ──
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: _buildBackIcon(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: widget.onBack,
                      background: background,
                      ink: ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }



  /// عنوان التطبيق مباشرة على الخلفية — أبيض محفور في التدرّج
  Widget _buildAppHeader(List<Color> background, Color ink) {
    return GestureDetector(
      onLongPress: () => _showHiddenBroadcastDialog(openFirstPanel: true),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'أوقات الصلاة',
            style: GoogleFonts.cairo(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: ink,
              // حفر أعمق للخط الكبير (الحروف الكبيرة تحتمله بلا تلخبط)
              shadows: GlassEngraveSpec.shadows(background, strength: 1.3),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            // الرقم من المصدر الواحد AppVersion — لا يُكتب هنا يدوياً أبداً
            'رقم الإصدار ${AppVersion.display}',
            style: GoogleFonts.cairo(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: ink,
              letterSpacing: 0.4,
              // حفر أهدأ للخط الصغير حتى تبقى حروفه واضحة
              shadows: GlassEngraveSpec.shadows(background, strength: 0.75),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// سطر «يتوفر إصدار أحدث» — يظهر فقط عندما يكون المنشور على سوباباز أحدث
  /// من الإصدار المثبَّت، وبنفس أسلوب الشاشة (كتابة محفورة بلا كاردات).
  ///
  /// الضغط عليه يفتح نافذة التحديث بتفاصيلها وزر «تحديث الآن» — حتى لو كان
  /// المستخدم قد أغلقها سابقاً.
  Widget _buildUpdateNotice(List<Color> background, Color ink) {
    final AppUpdateInfo? update = RemoteMessagingService.availableUpdate.value;
    if (update == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: () => RemoteMessagingService.showAvailableUpdate(
          ignoreDismissed: true,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.system_update_alt_rounded, size: 16, color: ink),
            const SizedBox(width: 6),
            Text(
              'يتوفر إصدار أحدث ${update.latestVersion} — اضغط للتحديث',
              style: GoogleFonts.cairo(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: ink,
                shadows: GlassEngraveSpec.shadows(background, strength: 0.75),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// بيانات المطور والتطبيق مباشرة على الخلفية بدون كاردات.
  ///
  /// كل ما فيها — الكتابة والأيقونات — بلون الصلاة القادمة ومحفور في نفس
  /// ألوان الخلفية، والصفوف على إيقاع واحد وعمود أيقونات ثابت العرض فتبدو
  /// الصفحة مرتّبة.
  Widget _buildDeveloperInfo(List<Color> background, Color ink) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // اللوقو
        GestureDetector(
          onLongPress: () => _showHiddenBroadcastDialog(openFirstPanel: true),
          child: Image.asset(
            'assets/app_logo_clean.png',
            width: 76,
            height: 76,
          ),
        ),
        const SizedBox(height: 8),

        // تصميم و برمجة
        Text(
          'تصميم و برمجة',
          style: GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ink,
            letterSpacing: 0.3,
            shadows: GlassEngraveSpec.shadows(background, strength: 0.7),
          ),
        ),
        const SizedBox(height: 3),

        // الاسم
        Text(
          'رزق الله عطيه العريبي',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ink,
            shadows: GlassEngraveSpec.shadows(background, strength: 1.2),
          ),
          textAlign: TextAlign.center,
        ),

        // ── فاصل رقيق بلون الخلفية: يفصل الهوية أعلى عن بيانات التواصل ──
        const SizedBox(height: 10),
        Container(
          width: 56,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.28),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),

        // المدينة
        _infoRow(
          icon: Icons.location_city_rounded,
          text: 'بنغازي / ليبيا',
          background: background,
          ink: ink,
          fontSize: 13,
        ),

        // الجيميل — يُنسخ بلمسة
        _infoRow(
          icon: Icons.mail_outline_rounded,
          text: 'rezgallahattya@gmail.com',
          background: background,
          ink: ink,
          onTap: () => _copyToClipboard(
            'rezgallahattya@gmail.com',
            'تم نسخ البريد الإلكتروني',
          ),
        ),

        // معرف الجهاز — يُنسخ بلمسة
        FutureBuilder<String>(
          future: RemoteMessagingService.getOrCreateUserId(),
          builder: (context, snapshot) {
            final uid = snapshot.data ?? '...';
            return _infoRow(
              icon: Icons.fingerprint_rounded,
              text: 'معرف الجهاز: $uid',
              background: background,
              ink: ink,
              fontSize: 11.5,
              onTap: () => _copyToClipboard(uid, 'تم نسخ الرقم التسلسلي'),
            );
          },
        ),

        const SizedBox(height: 6),

        // ── مراسلة المستخدمين — بمعرّف الجهاز + رقم سري ──
        _infoRow(
          icon: Icons.forum_rounded,
          text: 'مراسلة المستخدمين',
          background: background,
          ink: ink,
          fontSize: 12,
          onTap: _openUserMessaging,
        ),
      ],
    );
  }

  /// فتح الغرفة (لوحة المراسلة بين المستخدمين) بعد التحقق من الرقم السري
  Future<void> _openUserMessaging() async {
    await UserMessagingScreen.openWithPasscode(context);
  }

  /// صفّ معلومات محفور ومنسّق.
  ///
  /// عمود الأيقونة ثابت العرض (‏20) فتصطفّ بدايات كل النصوص على خط واحد،
  /// والنص بلون الصلاة القادمة ([ink]) محفور بظلال مشتقّة من خلفية الشاشة.
  Widget _infoRow({
    required IconData icon,
    required String text,
    required List<Color> background,
    required Color ink,
    VoidCallback? onTap,
    double fontSize = 12.5,
  }) {
    final List<Shadow> shadows = GlassEngraveSpec.shadows(
      background,
      strength: 0.85,
    );

    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            child: Icon(icon, color: ink, size: 15, shadows: shadows),
          ),
          const SizedBox(width: 6),
          // Flexible + قص بالثلاث نقاط: البريد ومعرف الجهاز لا يخرجان عن
          // عرض الشاشة على أي مقاس أو أي حجم خط نظام
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                fontSize: fontSize,
                color: ink,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                shadows: shadows,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: row,
    );
  }

  /// نسخ نص إلى الحافظة مع نفس تنبيهات التطبيق الزجاجية.
  void _copyToClipboard(String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.cairo(),
          textAlign: TextAlign.center,
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: GlassNoticeSpec.surface, // كحلي ملكي
      ),
    );
  }

  /// زر الرجوع — **بلا كارد ولا زجاج**: أيقونة بلون الصلاة محفورة على
  /// الخلفية مباشرة، مع مساحة لمس مريحة شفافة حولها (بلا خلفية ولا إطار).
  Widget _buildBackIcon({
    required IconData icon,
    required VoidCallback onTap,
    required List<Color> background,
    required Color ink,
  }) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: ink,
            size: 24,
            shadows: GlassEngraveSpec.shadows(background, strength: 1.0),
          ),
        ),
      ),
    );
  }
}
