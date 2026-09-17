import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/glass_theme.dart';
import 'core/widgets/glass_scaffold.dart';
import 'core/widgets/glass_widgets.dart';
import 'remote_messaging_service.dart';

/// حجم الخط الموحّد لكل نصوص الغرفة — **أميري 12**.
const double _kRoomFontSize = 12;

/// خط هذه الشاشة: **أميري** بحجم 12 (مصدر واحد فلا يبقى نص بخط آخر).
TextStyle _amiri({
  double size = _kRoomFontSize,
  Color color = Colors.white,
  FontWeight weight = FontWeight.w500,
  double? height,
  double? letterSpacing,
}) => GoogleFonts.amiri(
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: height,
  letterSpacing: letterSpacing,
);

/// غرفة **مراسلة المستخدمين** — بمعرّف الجهاز فقط.
///
/// تعرض معرّف هذا الجهاز (USR-XXXXXX)، وترسل رسالة إلى جهاز آخر بكتابة معرّفه،
/// وتعرض كل الرسائل الواردة والصادرة في صندوق واحد مرتّب بالأحدث، مع أيقونة
/// حذف للرسائل المستلمة.
///
/// الرسائل تمرّ عبر نفس قناة Supabase القائمة (جدول `broadcasts`) فتُخزَّن في
/// السحابة وتصل للطرف الآخر فوراً (نافذة منبثقة + إشعار) بلا أي تعديل على السيرفر.
class UserMessagingScreen extends StatefulWidget {
  const UserMessagingScreen({super.key});

  // ────────────────────────────────────────────────────────────────────────
  // أرقام الغرفة السرية
  // ────────────────────────────────────────────────────────────────────────
  /// الرقم الافتراضي المضمَّن في التطبيق الذي يفتح الغرفة — يُستعمل حين لا
  /// يُضبط رقم آخر من لوحة التحكم (وغيّر هذا السطر وحده ليتغيّر الاحتياطي).
  static const String roomPasscode = '1959';

  /// الرقم السري الذي يمنح **المدير وحده** صلاحية الإرسال لجميع المستخدمين.
  static const String adminBroadcastPasscode = '1508';

  /// الرقم السري الفعلي للغرفة: ما هو مضبوط من لوحة التحكم (جدول app_config)،
  /// وإن لم يُضبط فَالرقم المضمَّن في التطبيق.
  static Future<String> resolveRoomPasscode() async =>
      await RemoteMessagingService.getRemoteRoomPasscode() ?? roomPasscode;

  /// يفتح الغرفة بعد سؤال الرقم السري.
  static Future<void> openWithPasscode(BuildContext context) async {
    // يُقرأ الرقم من الإعدادات المحفوظة (بلا انتظار شبكة)
    final String expected = await resolveRoomPasscode();
    if (!context.mounted) return;

    final TextEditingController codeCtrl = TextEditingController();

    final bool? confirmed = await showGlassDialog<bool>(
      context: context,
      title: 'مراسلة المستخدمين',
      kind: GlassNoticeKind.info,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'أدخل الرقم السري لفتح مراسلة المستخدمين',
            textAlign: TextAlign.center,
            style: _amiri(color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: codeCtrl,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: _amiri(size: 16, letterSpacing: 6),
            cursorColor: GlassPalette.gold,
            decoration: InputDecoration(
              hintText: '••••',
              hintStyle: _amiri(color: Colors.white.withValues(alpha: 0.35)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: GlassPalette.gold,
                  width: 1.4,
                ),
              ),
            ),
            onSubmitted: (_) => Navigator.pop(context, true),
          ),
        ],
      ),
      actions: [
        GlassButton(
          label: 'دخول',
          icon: Icons.login_rounded,
          expand: true,
          fontSize: _kRoomFontSize,
          fontFamily: 'Amiri',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    final String entered = codeCtrl.text;
    codeCtrl.dispose();

    if (confirmed != true || !context.mounted) return;

    if (!isRoomPasscodeCorrect(entered, expected: expected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'الرقم السري خطأ!',
            textAlign: TextAlign.center,
            style: _amiri(weight: FontWeight.bold),
          ),
          backgroundColor: GlassPalette.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserMessagingScreen()),
    );
  }

  /// هل الرقم المُدخل مطابق لرقم الغرفة؟ يتجاهل المسافات ويقبل الأرقام العربية
  /// والهندية (٠١٢… و ۰۱۲…)، فيعمل الرقم من أي لوحة مفاتيح. والمرجع هو [expected]
  /// إن مُرّر، وإلا الرقم المضمَّن في التطبيق.
  static bool isRoomPasscodeCorrect(String input, {String? expected}) =>
      _normalizeDigits(input) == _normalizeDigits(expected ?? roomPasscode);

  /// هل الرقم المُدخل هو رقم صلاحية المدير (1508)؟ نفس التسامح مع المسافات
  /// والأرقام العربية/الهندية.
  static bool isAdminBroadcastPasscodeCorrect(String input) =>
      _normalizeDigits(input) == _normalizeDigits(adminBroadcastPasscode);

  static String _normalizeDigits(String raw) {
    const String arabic = '٠١٢٣٤٥٦٧٨٩';
    const String persian = '۰۱۲۳۴۵۶۷۸۹';
    String out = raw.trim().replaceAll(RegExp(r'\s+'), '');
    for (int i = 0; i < 10; i++) {
      out = out.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
    }
    return out;
  }

  @override
  State<UserMessagingScreen> createState() => _UserMessagingScreenState();
}

class _UserMessagingScreenState extends State<UserMessagingScreen> {
  final TextEditingController _toCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();

  String _myId = '';
  bool _isLoading = true;
  bool _isSending = false;

  /// وضع المدير: يُفتح بالرقم السري 1508 وحده، وبعده يُسمح بالإرسال للجميع.
  bool _adminUnlocked = false;

  List<UserMessage> _messages = <UserMessage>[];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final String id = await RemoteMessagingService.myDeviceId();
    if (mounted) setState(() => _myId = id);
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final List<UserMessage> messages =
        await RemoteMessagingService.fetchUserMessages();
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _isLoading = false;
    });
  }

  Future<void> _copyMyId() async {
    await Clipboard.setData(ClipboardData(text: _myId));
    _notify('تم نسخ معرّف الجهاز: $_myId');
  }

  // ── الإرسال: بمعرّف الجهاز فقط ──────────────────────────────────────────
  Future<void> _send() async {
    final String to = _toCtrl.text.trim();
    final String body = _bodyCtrl.text.trim();

    if (body.isEmpty) {
      _notify('اكتب نص الرسالة أولاً', isError: true);
      return;
    }
    // المستخدم العادي يُرسل بمعرّف الجهاز فقط — الإرسال للجميع صلاحية مدير.
    if (to.isEmpty) {
      _notify(
        'اكتب معرّف جهاز المستلم (USR-XXXXXX) — الإرسال للجميع خاص بالمدير',
        isError: true,
      );
      return;
    }
    if (!to.toUpperCase().startsWith('USR-')) {
      _notify('معرّف الجهاز يبدأ بـ USR- مثال: USR-R7UMAW', isError: true);
      return;
    }

    setState(() => _isSending = true);
    final bool ok = await RemoteMessagingService.sendUserMessage(
      toDeviceId: to,
      body: body,
    );
    if (!mounted) return;
    setState(() => _isSending = false);

    if (!ok) {
      _notify('تعذّر إرسال الرسالة — تأكد من الاتصال بالإنترنت', isError: true);
      return;
    }

    _bodyCtrl.clear();
    _notify(
      'تم إرسال الرسالة إلى ${RemoteMessagingService.normalizeDeviceId(to)}',
    );
    await _loadMessages();
  }

  // ── وضع المدير: الإرسال لجميع المستخدمين بالرقم السري 1508 ──────────────
  Future<void> _unlockAdminBroadcast() async {
    final TextEditingController codeCtrl = TextEditingController();

    final bool? ok = await showGlassDialog<bool>(
      context: context,
      title: 'صلاحية الإرسال للجميع',
      kind: GlassNoticeKind.info,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'هذه الصلاحية للمدير فقط — أدخل الرقم السري.',
            textAlign: TextAlign.center,
            style: _amiri(color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: codeCtrl,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: _amiri(size: 16, letterSpacing: 6),
            cursorColor: GlassPalette.gold,
            decoration: InputDecoration(
              hintText: '••••',
              hintStyle: _amiri(color: Colors.white.withValues(alpha: 0.35)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: GlassPalette.gold,
                  width: 1.4,
                ),
              ),
            ),
            onSubmitted: (_) => Navigator.pop(context, true),
          ),
        ],
      ),
      actions: [
        GlassButton(
          label: 'تأكيد',
          icon: Icons.lock_open_rounded,
          expand: true,
          fontSize: _kRoomFontSize,
          fontFamily: 'Amiri',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );

    final String entered = codeCtrl.text;
    codeCtrl.dispose();

    if (ok != true || !mounted) return;

    if (!UserMessagingScreen.isAdminBroadcastPasscodeCorrect(entered)) {
      _notify('الرقم السري خطأ!', isError: true);
      return;
    }

    setState(() => _adminUnlocked = true);
    _notify('تم تفعيل الإرسال لجميع المستخدمين (وضع المدير)');
  }

  /// إرسال الرسالة المكتوبة إلى **جميع** الأجهزة — بعد فتح وضع المدير فقط.
  Future<void> _sendToAll() async {
    final String body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      _notify('اكتب نص الرسالة أولاً', isError: true);
      return;
    }

    final bool confirmed = await _confirm(
      title: 'إرسال لجميع المستخدمين',
      message:
          'ستُرسل الرسالة من معرّف جهازك ($_myId) إلى جميع المستخدمين. هل أنت متأكد؟',
      confirmLabel: 'إرسال للجميع',
    );
    if (!confirmed) return;

    setState(() => _isSending = true);
    final bool ok = await RemoteMessagingService.sendUserMessage(
      toDeviceId: '',
      body: body,
    );
    if (!mounted) return;
    setState(() => _isSending = false);

    if (!ok) {
      _notify('تعذّر إرسال الرسالة — تأكد من الاتصال بالإنترنت', isError: true);
      return;
    }
    _bodyCtrl.clear();
    _notify('تم إرسال الرسالة إلى جميع المستخدمين');
    await _loadMessages();
  }

  // ── حذف الرسائل المستلمة ────────────────────────────────────────────────
  Future<void> _deleteReceived(UserMessage m) async {
    final bool confirmed = await _confirm(
      title: 'حذف الرسالة المستلمة',
      message: 'سيتم حذف الرسالة الواردة من ${m.otherLabel}.',
      confirmLabel: 'حذف',
    );
    if (!confirmed) return;

    final bool deletedFromServer =
        await RemoteMessagingService.deleteUserMessage(m.id);
    if (!mounted) return;

    setState(() {
      _messages =
          _messages.where((UserMessage e) => e.id != m.id).toList();
    });
    _notify(
      deletedFromServer
          ? 'تم حذف الرسالة المستلمة'
          : 'حُذفت الرسالة من جهازك، لكن تعذّر حذفها من الخادم',
      isError: !deletedFromServer,
    );
  }

  /// حذف **جميع** الرسائل (الواردة والصادرة) من التطبيق ومن قاعدة البيانات.
  ///
  /// الحذف يشمل ما حُذف سابقاً على هذا الجهاز وتوسّط على السحابة لأن سياسة
  /// الحذف منعت إزالته، فلا تبقى له بقية تُعاد إليه لاحقاً.
  Future<void> _deleteAllMessages() async {
    if (_messages.isEmpty) {
      _notify('لا توجد رسائل للحذف', isError: true);
      return;
    }

    final bool confirmed = await _confirm(
      title: 'حذف جميع الرسائل',
      message:
          'سيتم حذف ${_messages.length} رسالة (الواردة والصادرة) من التطبيق ومن قاعدة البيانات. هل أنت متأكد؟',
      confirmLabel: 'حذف الكل',
    );
    if (!confirmed) return;

    final bool deletedFromServer =
        await RemoteMessagingService.deleteAllUserMessages();
    if (!mounted) return;

    setState(() => _messages = <UserMessage>[]);
    _notify(
      deletedFromServer
          ? 'تم حذف جميع الرسائل من التطبيق ومن قاعدة البيانات'
          : 'حُذفت الرسائل من التطبيق، لكن تعذّر حذفها من قاعدة البيانات',
      isError: !deletedFromServer,
    );
  }

  /// حوار تأكيد زجاجي موحّد (نعم/إلغاء).
  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final bool? ok = await showGlassDialog<bool>(
      context: context,
      title: title,
      kind: GlassNoticeKind.info,
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: _amiri(
          color: Colors.white.withValues(alpha: 0.85),
          height: 1.8,
        ),
      ),
      actions: [
        GlassButton(
          label: 'إلغاء',
          icon: Icons.close_rounded,
          filled: false,
          fontSize: _kRoomFontSize,
          fontFamily: 'Amiri',
          onPressed: () => Navigator.pop(context, false),
        ),
        GlassButton(
          label: confirmLabel,
          icon: Icons.check_rounded,
          fontSize: _kRoomFontSize,
          fontFamily: 'Amiri',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    return ok == true;
  }

  void _notify(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: _amiri(weight: FontWeight.bold),
        ),
        backgroundColor:
            isError ? GlassPalette.danger : const Color(0xFF0B1F3D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      appBar: GlassAppBar(
        title: Text(
          'مراسلة المستخدمين',
          style: _amiri(
            size: 16,
            weight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        accent: GlassPalette.gold,
        actions: [
          IconButton(
            tooltip: 'تحديث الرسائل',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadMessages,
          ),
          // أيقونة حذف جميع الرسائل (الواردة والصادرة) من التطبيق ومن قاعدة
          // البيانات — تظهر عند وجود رسائل
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'حذف جميع الرسائل',
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.redAccent,
              ),
              onPressed: _deleteAllMessages,
            ),
        ],
      ),
      body: RefreshIndicator(
        color: GlassPalette.gold,
        onRefresh: _loadMessages,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildMyIdCard(),
            const SizedBox(height: 12),
            _buildComposeCard(),
            const SizedBox(height: 18),
            _buildMessagesHeader(),
            const SizedBox(height: 8),
            ..._buildMessagesList(),
          ],
        ),
      ),
    );
  }

  // ── كارد معرّف هذا الجهاز ───────────────────────────────────────────────
  Widget _buildMyIdCard() {
    return GlassPanel(
      accent: GlassPalette.gold,
      borderRadius: BorderRadius.circular(16),
      // حدّ واحد حول الكارد — بلا خطّ ثانٍ تحت نصوصه
      showInnerEdge: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.fingerprint_rounded,
            color: GlassPalette.gold,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'معرّف جهازي',
                  style: _amiri(
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _myId.isEmpty ? '...' : _myId,
                  style: _amiri(
                    weight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'نسخ المعرّف',
            icon: const Icon(Icons.copy_rounded, color: GlassPalette.gold),
            onPressed: _myId.isEmpty ? null : _copyMyId,
          ),
        ],
      ),
    );
  }

  // ── كارد كتابة رسالة جديدة ──────────────────────────────────────────────
  Widget _buildComposeCard() {
    return GlassPanel(
      accent: GlassPalette.gold,
      borderRadius: BorderRadius.circular(16),
      showInnerEdge: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'رسالة جديدة',
            style: _amiri(size: 14, weight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildField(
            controller: _toCtrl,
            hint: 'معرّف جهاز المستلم  USR-XXXXXX',
            icon: Icons.alternate_email_rounded,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 8),
          Text(
            // المستخدم يُرسل بمعرّف الجهاز فقط — لا إرسال للجميع هنا
            'الإرسال بمعرّف جهاز المستلم فقط (مثال: USR-R7UMAW)',
            style: _amiri(color: Colors.white.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _bodyCtrl,
            hint: 'نص الرسالة...',
            icon: Icons.chat_bubble_outline_rounded,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          GlassButton(
            label: _isSending ? 'جارٍ الإرسال...' : 'إرسال الرسالة',
            icon: Icons.send_rounded,
            expand: true,
            enabled: !_isSending,
            fontSize: _kRoomFontSize,
            fontFamily: 'Amiri',
            onPressed: _isSending ? null : _send,
          ),
          const SizedBox(height: 8),
          _buildAdminBroadcastBar(),
        ],
      ),
    );
  }

  /// شريط صلاحية المدير — الإرسال لجميع المستخدمين مربوط بالرقم السري 1508.
  Widget _buildAdminBroadcastBar() {
    if (!_adminUnlocked) {
      return InkWell(
        onTap: _isSending ? null : _unlockAdminBroadcast,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: GlassPalette.gold.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'الإرسال لجميع المستخدمين — للمدير فقط',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _amiri(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassButton(
          label: 'إرسال إلى جميع المستخدمين',
          icon: Icons.campaign_rounded,
          accent: GlassPalette.info,
          expand: true,
          enabled: !_isSending,
          fontSize: _kRoomFontSize,
          fontFamily: 'Amiri',
          onPressed: _isSending ? null : _sendToAll,
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: _isSending
                ? null
                : () => setState(() => _adminUnlocked = false),
            child: Text(
              'إلغاء وضع المدير',
              style: _amiri(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      textDirection: TextDirection.rtl,
      style: _amiri(),
      cursorColor: GlassPalette.gold,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _amiri(color: Colors.white.withValues(alpha: 0.42)),
        prefixIcon: Icon(icon, color: GlassPalette.gold, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: GlassPalette.gold, width: 1.4),
        ),
      ),
    );
  }

  // ── رأس قائمة الرسائل ──────────────────────────────────────────────────
  Widget _buildMessagesHeader() {
    return Row(
      children: [
        const Icon(Icons.forum_rounded, color: GlassPalette.gold, size: 18),
        const SizedBox(width: 8),
        Text(
          'الرسائل',
          style: _amiri(weight: FontWeight.bold),
        ),
        const SizedBox(width: 6),
        Text(
          '(${_messages.length})',
          style: _amiri(color: Colors.white.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  List<Widget> _buildMessagesList() {
    if (_isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 26),
          child: Center(
            child: CircularProgressIndicator(color: GlassPalette.gold),
          ),
        ),
      ];
    }

    if (_messages.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: Column(
            children: [
              Icon(
                Icons.mark_chat_unread_outlined,
                size: 46,
                color: GlassPalette.gold.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 10),
              Text(
                'لا توجد رسائل بعد',
                style: _amiri(color: Colors.white.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 4),
              Text(
                'شارك معرّف جهازك، أو اكتب معرّف جهاز صديقك لتُراسله',
                textAlign: TextAlign.center,
                style: _amiri(color: Colors.white.withValues(alpha: 0.45)),
              ),
            ],
          ),
        ),
      ];
    }

    return _messages
        .map<Widget>((UserMessage m) => _buildMessageCard(m))
        .toList();
  }

  Widget _buildMessageCard(UserMessage m) {
    final Color accent =
        m.outgoing ? GlassPalette.gold : const Color(0xFF6BB6FF);

    return GlassPanel(
      accent: accent,
      margin: const EdgeInsets.only(bottom: 10),
      borderRadius: BorderRadius.circular(14),
      // حدّ واحد بلون الرسالة — بدل الحدّ المزدوج (خط ملوّن + حافة داخلية
      // لامعة) الذي كان يظهر كخطّين تحت كلمات الرسالة
      border: Border.all(
        color: accent.withValues(alpha: 0.5),
        width: 1.0,
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── أعلى الرسالة: معرّف الجهاز بخط صغير + الوقت + أيقونة الحذف ──
          // لا تُكتب عبارة «رسالة من» — معرّف الجهاز وحده.
          Row(
            children: [
              Icon(
                m.outgoing
                    ? Icons.call_made_rounded
                    : Icons.call_received_rounded,
                size: 13,
                color: accent,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  m.otherLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _amiri(
                    color: accent.withValues(alpha: 0.92),
                    weight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                m.displayTime,
                style: _amiri(color: Colors.white.withValues(alpha: 0.45)),
              ),
              // حذف الرسالة المستلمة وحدها — الصادرة تبقى للطرفين
              if (!m.outgoing)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    tooltip: 'حذف الرسالة المستلمة',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 17,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _deleteReceived(m),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            m.body,
            textDirection: TextDirection.rtl,
            style: _amiri(height: 1.7),
          ),
        ],
      ),
    );
  }
}
