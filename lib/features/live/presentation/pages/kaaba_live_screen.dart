import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../core/services/screen_wake_service.dart';
import '../../../../core/widgets/glass_scaffold.dart';

/// شاشة البث المباشر للحرمين الشريفين:
/// — مكة المكرمة (المسجد الحرام / الكعبة المشرفة)
/// — المدينة المنورة (المسجد النبوي الشريف)
///
/// تشغّل بثاً مباشراً (HLS) على مدار الساعة من قناة القرآن الكريم
/// والسنة (الهيئة العامة للإذاعة والتلفزيون السعودية) مع تبديل يدوي.
class KaabaLiveScreen extends StatefulWidget {
  const KaabaLiveScreen({super.key});

  @override
  State<KaabaLiveScreen> createState() => _KaabaLiveScreenState();
}

class _KaabaLiveScreenState extends State<KaabaLiveScreen> {
  /// القنوات المتاحة — روابط أساسية عالية الاعتمادية ورابط احتياط لعدم التعطل
  static const List<Map<String, dynamic>> _channels = [
    {
      'name': 'مكة المكرمة',
      'subname': 'المسجد الحرام',
      'icon': '🕋',
      'title': 'بث مباشر الكعبة المشرفة',
      'subtitle': 'المسجد الحرام — مكة المكرمة',
      'info': 'مباشرة من المسجد الحرام حول الكعبة المشرفة،\nالمصدر: قناة القرآن الكريم (رسمية).',
      'urls': <String>[
        'https://cdn-globecast.akamaized.net/live/eds/saudi_quran/hls_roku/index.m3u8',
        'https://al-ekhbaria-prod-dub.shahid.net/out/v1/9885cab0a3ec4008b53bae57a27ca76b/index.m3u8',
        'https://win.holylive.net:1936/holylive/quran/playlist.m3u8',
        'https://stream.sauditv.sa/hls/quran.m3u8',
        'http://m.live.net.sa:1935/live/quran/playlist.m3u8',
      ],
    },
    {
      'name': 'المدينة المنورة',
      'subname': 'المسجد النبوي الشريف',
      'icon': '🕌',
      'title': 'بث مباشر المسجد النبوي',
      'subtitle': 'المدينة المنورة — طيبة الطيبة',
      'info': 'مباشرة من المسجد النبوي الشريف بالمدينة المنورة،\nالمصدر: قناة السنة (رسمية).',
      'urls': <String>[
        'https://cdn-globecast.akamaized.net/live/eds/saudi_sunnah/hls_roku/index.m3u8',
        'https://sbc-prod-dub-enc.edgenextcdn.net/out/v1/b09bbb8d9b684763be4211b088168de7/index.m3u8',
        'https://win.holylive.net:1936/holylive/sunnah/playlist.m3u8',
        'https://stream.sauditv.sa/hls/sunnah.m3u8',
        'http://m.live.net.sa:1935/live/sunnah/playlist.m3u8',
      ],
    },
  ];

  int _selectedChannel = 0;
  List<String> get _currentSources =>
      (_channels[_selectedChannel]['urls'] as List<String>);

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  int _currentSourceIndex = 0;
  int _attemptGeneration = 0; // يمنع انتهاء محاولة قديمة بعد تبديل سريع للقناة
  bool _isLoading = true;
  bool _hasError = false;
  bool _switchingSource = false;

  // ── دورة الحياة ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _attemptPlay(0);
  }

  @override
  void dispose() {
    ScreenWakeService.applyCurrentState();
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  /// محاولة تشغيل المصدر المحدد للقناة الحالية، وإن فشل ننتقل للمصدر التالي
  /// باستعمال التحكم الشرطي (if ... else if ... else) للتحكم بالروابط الأساسية والاحتياطية
  Future<void> _attemptPlay(int index) async {
    final gen = _attemptGeneration;
    if (!mounted) return;

    // ── هيكلية التحكم الشرطية (if / else if / else) للتنقل بين الروابط ──
    if (index == 0) {
      debugPrint('KaabaLive: محاولة تشغيل الرابط الأساسي القوي (المصدر 1)...');
    } else if (index == 1) {
      debugPrint('KaabaLive: تعطل الرابط الأساسي! جاري التحويل التلقائي إلى الرابط الاحتياطي الأول (المصدر 2)...');
    } else if (index == 2) {
      debugPrint('KaabaLive: تعطل الرابط الاحتياطي الأول! جاري التحويل إلى الرابط الاحتياطي الثاني (المصدر 3)...');
    } else if (index < _currentSources.length) {
      debugPrint('KaabaLive: جاري التبديل للمصدر الاحتياطي رقم ${index + 1}...');
    } else {
      // تعذر التشغيل على كافة الروابط الأساسية والاحتياطية
      ScreenWakeService.applyCurrentState();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _currentSourceIndex = index;
    });

    try {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(_currentSources[index]));
      // مهلة الاتصال 15 ثانية للتنقل السريع للرابط الاحتياطي في حال التعطل
      await controller
          .initialize()
          .timeout(const Duration(seconds: 15));
      if (!mounted || gen != _attemptGeneration) {
        controller.dispose();
        return;
      }

      // مراقبة أخطاء البث بعد التشغيل → التحويل التلقائي للرابط الاحتياطي التالي
      controller.addListener(() {
        if (!mounted || gen != _attemptGeneration) return;
        if (controller.value.hasError && !_switchingSource) {
          debugPrint(
              'KaabaLive: stream error on source $index -> ${controller.value.errorDescription}');
          _switchingSource = true;
          _disposeControllers();
          _attemptPlay(index + 1).whenComplete(() => _switchingSource = false);
        }
      });

      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        aspectRatio: 16 / 9,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFDFBA6B),
          handleColor: const Color(0xFFDFBA6B),
          bufferedColor: Colors.white24,
          backgroundColor: Colors.white12,
        ),
        errorBuilder: (context, errorMessage) =>
            _buildStreamError(errorMessage),
      );

      if (!mounted || gen != _attemptGeneration) {
        controller.dispose();
        chewie.dispose();
        return;
      }

      _disposeControllers();
      setState(() {
        _videoController = controller;
        _chewieController = chewie;
        _isLoading = false;
        _hasError = false;
      });
      // إبقاء الشاشة مضيئة أثناء المشاهدة
      WakelockPlus.enable();
    } catch (e) {
      debugPrint('KaabaLive: source $index init failed -> $e');
      if (mounted && gen == _attemptGeneration) {
        await _attemptPlay(index + 1);
      }
    }
  }

  /// تبديل القناة يدوياً بين مكة والمدينة
  void _switchChannel(int channel) {
    if (channel == _selectedChannel || _switchingSource) return;
    HapticFeedback.mediumImpact();
    _attemptGeneration++; // إبطال أي محاولة تشغيل سابقة معلّقة
    _disposeControllers();
    ScreenWakeService.applyCurrentState();
    setState(() {
      _selectedChannel = channel;
      _currentSourceIndex = 0;
    });
    _attemptPlay(0);
  }

  void _retry() {
    if (_switchingSource) return;
    _attemptGeneration++;
    ScreenWakeService.applyCurrentState();
    _disposeControllers();
    _attemptPlay(0);
  }

  // ── البناء ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      // بث فيديو مباشر — خلفية ثابتة (بدون حركة) للحفاظ على أداء التشغيل
      animated: false,
      body: Container(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  // ── الترويسة + مفتاح القنوات ────────────────────────────────────────────
  Widget _buildHeader() {
    final channel = _channels[_selectedChannel];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        channel['title'] as String,
                        style: GoogleFonts.tajawal(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: const [
                            Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        channel['subtitle'] as String,
                        maxLines: 1,
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          color: Colors.white60,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // شارة مباشر
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'مباشر',
                      style: GoogleFonts.tajawal(
                        color: Colors.redAccent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // ── كاردات القنوات المميزة: مكة المكرمة / المدينة المنورة ───────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(child: _buildChannelChip(0)),
              const SizedBox(width: 12),
              Expanded(child: _buildChannelChip(1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChannelChip(int index) {
    final channel = _channels[index];
    final selected = _selectedChannel == index;
    return GestureDetector(
      onTap: () => _switchChannel(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFFDF7D), Color(0xFFDFBA6B), Color(0xFFB8860B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFFFFECB3)
                : Colors.white.withValues(alpha: 0.12),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFDFBA6B).withValues(alpha: 0.38),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            // أيقونة المحطة في دائرة فاخرة
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF0F172A).withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF0F172A).withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.14),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  channel['icon'] as String,
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ),
            const SizedBox(width: 9),
            // العنوان الرئيسي والفرعي
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      channel['name'] as String,
                      maxLines: 1,
                      style: GoogleFonts.tajawal(
                        color: selected ? const Color(0xFF0B132B) : Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      channel['subname'] as String? ?? '',
                      maxLines: 1,
                      style: GoogleFonts.tajawal(
                        color: selected
                            ? const Color(0xFF1E293B).withValues(alpha: 0.85)
                            : Colors.white60,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // مؤشر التفعيل
            if (selected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B132B).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5.5,
                      height: 5.5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3.5),
                    Text(
                      'نشط',
                      style: GoogleFonts.tajawal(
                        color: const Color(0xFF0B132B),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── المحتوى ─────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) return _buildLoading();
    if (_hasError) return _buildError();
    if (_chewieController != null) {
      return _buildPlayer();
    }
    return _buildLoading();
  }

  Widget _buildLoading() {
    String statusText;
    if (_currentSourceIndex == 0) {
      statusText = 'جاري الاتصال بالبث المباشر (الرابط الأساسي)...';
    } else if (_currentSourceIndex == 1) {
      statusText = 'تعطل الرابط الأول! جاري التحويل للرابط الاحتياطي (1)...';
    } else if (_currentSourceIndex == 2) {
      statusText = 'جاري التحويل للرابط الاحتياطي الثاني (2)...';
    } else {
      statusText = 'جاري التحويل للرابط الاحتياطي رقم ${_currentSourceIndex + 1}...';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFDFBA6B).withOpacity(0.08),
              border: Border.all(
                color: const Color(0xFFDFBA6B).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Text(
              _channels[_selectedChannel]['icon'] as String,
              style: const TextStyle(fontSize: 52),
            ),
          ),
          const SizedBox(height: 28),
          const CircularProgressIndicator(
            color: Color(0xFFDFBA6B),
            strokeWidth: 3,
          ),
          const SizedBox(height: 18),
          Text(
            statusText,
            textAlign: TextAlign.center,
            style: GoogleFonts.tajawal(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_currentSources.length > 1) ...[
            const SizedBox(height: 6),
            Text(
              'المصدر ${_currentSourceIndex + 1} من ${_currentSources.length}',
              style: GoogleFonts.tajawal(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Colors.redAccent,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'تعذر تشغيل البث المباشر',
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'تأكد من اتصالك بالإنترنت ثم أعد المحاولة.\nقد يكون البث مشغولاً مؤقتاً.',
              textAlign: TextAlign.center,
              style: GoogleFonts.tajawal(
                color: Colors.white60,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 26),
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _retry();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 34, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDFBA6B), Color(0xFFB8860B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDFBA6B).withOpacity(0.35),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'إعادة المحاولة',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    final channel = _channels[_selectedChannel];
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── مشغل الفيديو الفاخر ─────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFDFBA6B).withValues(alpha: 0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFFDFBA6B).withValues(alpha: 0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Chewie(controller: _chewieController!),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ── بطاقة معلومات البث بتصميم زجاجي احترافي ─────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFDFBA6B).withValues(alpha: 0.28),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFFDFBA6B),
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        channel['info'] as String,
                        style: GoogleFonts.tajawal(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12.5,
                          height: 1.6,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── بطاقة الدعاء الإيماني ──────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFDFBA6B).withValues(alpha: 0.12),
                  const Color(0xFFDFBA6B).withValues(alpha: 0.04),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFDFBA6B).withValues(alpha: 0.3),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFDFBA6B),
                  size: 16,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    _selectedChannel == 0
                        ? 'اللهم اجعل هذا البيت آمناً وسائر بلاد المسلمين'
                        : 'اللهم صلِّ وسلم وبارك على نبينا محمد وعلى آله وصحبه',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.amiri(
                      color: const Color(0xFFFFE082),
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFDFBA6B),
                  size: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamError(String? errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 40),
            const SizedBox(height: 10),
            Text(
              'انقطع البث',
              style: GoogleFonts.tajawal(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              errorMessage ?? 'خطأ في تشغيل البث',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.tajawal(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _retry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'إعادة المحاولة',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
